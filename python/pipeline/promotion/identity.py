"""Compare two environments' rows by who people are, never by id (PROMO.ID).

ADR-108 compares CERT with PROD in the refresh's dry run, in the input check
before promote, when a result fingerprint differs, and in the full results
comparison after the first fencer-id alignment. Fencer ids cannot key any of
these: before the alignment they differ for most fencers, and a report a person
reads must name people anyway.

Every row is therefore keyed by an `Identity`: the surname and first name folded
exactly as the ingestion's exact-name step folds them (`normalize_name` with
diacritic folding), plus the birth year. A birth-year difference is two people,
one on each side, never a changed field of one person; that is what the namesake
rule needs. Two rows sharing one identity within a set are never collapsed into
one: they are reported as ambiguous, because nothing is guessed.

The canonical result fingerprint that decides a promote is computed in SQL
(`fn_event_result_fingerprint`), never here. This module explains differences;
it does not decide them.
"""

from __future__ import annotations

from collections.abc import Callable, Hashable, Iterable, Mapping
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
from typing import Any

from python.matcher.fuzzy_match import normalize_name

Row = Mapping[str, Any]

# What each kind of row is compared on. The identity columns (names and birth
# year) form the key, so only the spelling of the names is compared again.
RESULT_FIELDS: tuple[str, ...] = ("int_place", "num_final_score", "enum_match_method")
TOURNAMENT_FIELDS: tuple[str, ...] = ("int_participant_count", "txt_joined_order")
ROSTER_FIELDS: tuple[str, ...] = (
    "txt_surname",
    "txt_first_name",
    "bool_birth_year_estimated",
    "enum_gender",
    "txt_nationality",
    "json_name_aliases",
)
# What the ingestion reads from a registration. The e-mail hash, the edit token
# and the consent stamp are never copied to CERT (ADR-108 §2), so never compared.
REGISTRATION_FIELDS: tuple[str, ...] = (
    "txt_surname",
    "txt_first_name",
    "enum_gender",
    "arr_weapons",
    "txt_ftl_name",
    "txt_club",
)


def fold(name: str | None) -> str:
    """The exact-name step's fold: markers stripped, lower case, diacritics folded."""
    return normalize_name(name or "", use_diacritic_folding=True)


@dataclass(frozen=True)
class Identity:
    """Who a row is about: folded surname, folded first name, birth year."""

    surname: str
    first_name: str
    birth_year: int | None

    @classmethod
    def of(cls, surname: str | None, first_name: str | None, birth_year: int | None) -> Identity:
        return cls(fold(surname), fold(first_name), None if birth_year is None else int(birth_year))

    @classmethod
    def from_row(cls, row: Row) -> Identity:
        return cls.of(row.get("txt_surname"), row.get("txt_first_name"), row.get("int_birth_year"))

    def label(self) -> str:
        year = "?" if self.birth_year is None else str(self.birth_year)
        return f"{self.surname} {self.first_name} ({year})"


@dataclass(frozen=True)
class Normalised:
    """One environment's rows, keyed by identity.

    `rows` holds each key that occurs once, with its compared fields in
    canonical form. `ambiguous` holds each key that occurs more than once, with
    its count; those rows take no part in the comparison.
    """

    rows: dict[Hashable, dict[str, Any]]
    ambiguous: dict[Hashable, int]


@dataclass(frozen=True)
class FieldChange:
    key: Hashable
    field: str
    left: Any
    right: Any


@dataclass(frozen=True)
class IdentityDiff:
    """Everything that differs between two normalised sets, in a stable order."""

    only_left: tuple[Hashable, ...]
    only_right: tuple[Hashable, ...]
    changed: tuple[FieldChange, ...]
    ambiguous_left: tuple[Hashable, ...]
    ambiguous_right: tuple[Hashable, ...]

    @property
    def equal(self) -> bool:
        return not (
            self.only_left
            or self.only_right
            or self.changed
            or self.ambiguous_left
            or self.ambiguous_right
        )

    def lines(self, left: str = "left", right: str = "right") -> list[str]:
        """One readable line per difference, naming people and both values."""
        out: list[str] = []
        out += [f"{_label(k)} · only on {left}" for k in self.only_left]
        out += [f"{_label(k)} · only on {right}" for k in self.only_right]
        out += [
            f"{_label(c.key)} · {c.field}: {left} {_show(c.left)}, {right} {_show(c.right)}"
            for c in self.changed
        ]
        out += [
            f"{_label(k)} · several rows share this identity on {left}" for k in self.ambiguous_left
        ]
        out += [
            f"{_label(k)} · several rows share this identity on {right}"
            for k in self.ambiguous_right
        ]
        return out


def normalise(
    rows: Iterable[Row], key: Callable[[Row], Hashable], fields: tuple[str, ...]
) -> Normalised:
    """Key `rows` with `key` and keep `fields` in canonical form."""
    grouped: dict[Hashable, list[dict[str, Any]]] = {}
    for row in rows:
        grouped.setdefault(key(row), []).append({f: _canon(f, row.get(f)) for f in fields})
    return Normalised(
        rows={k: v[0] for k, v in grouped.items() if len(v) == 1},
        ambiguous={k: len(v) for k, v in grouped.items() if len(v) > 1},
    )


def normalise_results(rows: Iterable[Row]) -> Normalised:
    """Result rows keyed by tournament code and the fencer's identity."""
    return normalise(
        rows, lambda r: (r["txt_tournament_code"], Identity.from_row(r)), RESULT_FIELDS
    )


def normalise_tournaments(rows: Iterable[Row]) -> Normalised:
    """Tournament rows keyed by code: N and the joined-bracket category order."""
    return normalise(rows, lambda r: r["txt_code"], TOURNAMENT_FIELDS)


def normalise_roster(rows: Iterable[Row]) -> Normalised:
    """Fencer rows keyed by identity."""
    return normalise(rows, Identity.from_row, ROSTER_FIELDS)


def normalise_registrations(rows: Iterable[Row]) -> Normalised:
    """Registration rows keyed by identity, with the declared birth year in the key."""
    return normalise(rows, Identity.from_row, REGISTRATION_FIELDS)


def diff(left: Normalised, right: Normalised) -> IdentityDiff:
    """Compare two normalised sets field by field."""
    changed = [
        FieldChange(k, f, left.rows[k][f], right.rows[k][f])
        for k in left.rows.keys() & right.rows.keys()
        for f in sorted(left.rows[k].keys() | right.rows[k].keys())
        if left.rows[k].get(f) != right.rows[k].get(f)
    ]
    return IdentityDiff(
        only_left=_sorted(left.rows.keys() - right.rows.keys() - right.ambiguous.keys()),
        only_right=_sorted(right.rows.keys() - left.rows.keys() - left.ambiguous.keys()),
        changed=tuple(sorted(changed, key=lambda c: (_sort_key(c.key), c.field))),
        ambiguous_left=_sorted(left.ambiguous.keys()),
        ambiguous_right=_sorted(right.ambiguous.keys()),
    )


def _canon(field: str, value: Any) -> Any:
    """One form per value.

    The column decides what a value is, never its text: a `num_*` column is an
    exact decimal however the driver delivered it (59.16, "59.160"), while a
    digit string such as a joined order ("023") stays text, leading zero kept.
    Arrays compare as sorted tuples, strings without surrounding whitespace.
    """
    if value is None or isinstance(value, bool):
        return value
    if field.startswith("num_"):
        try:
            return _decimal(value)
        except (InvalidOperation, ValueError):
            return value
    if isinstance(value, list | tuple):
        return tuple(sorted(_canon("", v) for v in value))
    if isinstance(value, str):
        return value.strip()
    return value


def _decimal(value: float | Decimal | str | int) -> Decimal:
    d = Decimal(str(value))
    # normalize() would print 40 as 4E+1; keep integers integral and strip only
    # trailing zeros after a decimal point.
    return d.quantize(Decimal(1)) if d == d.to_integral_value() else d.normalize()


def _sort_key(key: Any) -> Any:
    if isinstance(key, Identity):
        return (key.surname, key.first_name, -1 if key.birth_year is None else key.birth_year)
    if isinstance(key, tuple):
        return tuple(_sort_key(part) for part in key)
    return key


def _sorted(keys: Iterable[Hashable]) -> tuple[Hashable, ...]:
    return tuple(sorted(keys, key=_sort_key))


def _label(key: Any) -> str:
    if isinstance(key, Identity):
        return key.label()
    if isinstance(key, tuple):
        return " · ".join(_label(part) for part in key)
    return str(key)


def _show(value: Any) -> str:
    if value is None:
        return "—"
    if isinstance(value, Decimal):
        return format(value, "f")
    if isinstance(value, tuple):
        return ",".join(_show(v) for v in value) if value else "[]"
    return str(value)
