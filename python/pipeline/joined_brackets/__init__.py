"""Joined-bracket modules, paired one-to-one with scoring engines (ADR-103 §4,
ADR-104 §§3-4).

A joined bracket is one listing fenced by two or more age categories. How its
results are filed is decided by the engine assigned to the tournament type,
never by the listing:

- ``PER_CATEGORY_RENUMBER`` ↔ ``EVF_CLASSIC_V1_2025_2026``. Split per category,
  dense-renumber places 1..K and store the category's own size as N (ADR-049).
  This is the behaviour before ADR-103, byte for byte, and no order is stored.
- ``JOINED_BRACKET_CATEGORY_PLACE`` ↔ ``SPWS_EVF_JOINED_V1_2026_2027``. Keep the
  joined place and the joined N, file each fencer under their own category's
  tournament, and store the listing's category order — one digit per place,
  0 = V0 … 4 = V4 — on every one of them, so the database scores the whole
  bracket from it (``fn_score_joined_bracket``).

The module names are the two values ``tbl_scoring_engine.
txt_joined_bracket_module`` admits. The registry is the only place an engine
code chooses a module, and an unknown code is refused, as the SQL dispatcher
refuses it. International results never reach the joined module: EVF and FIE
publish per category (ADR-103 Context).

International types are not filed by their engine's module at all (ADR-105).
Only Polish fencers are written (ADR-038), so the rows kept are never the
bracket: ``SOURCE_FIELD_PLACE`` stores the whole source bracket as N and each
fencer's own published place, whatever engine scores them. It is chosen by
the tournament type, not registered against an engine.
"""

from __future__ import annotations

import re
from collections import Counter
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from typing import Protocol

PER_CATEGORY_RENUMBER = "PER_CATEGORY_RENUMBER"
JOINED_BRACKET_CATEGORY_PLACE = "JOINED_BRACKET_CATEGORY_PLACE"
SOURCE_FIELD_PLACE = "SOURCE_FIELD_PLACE"

MODULE_BY_ENGINE: dict[str, str] = {
    "EVF_CLASSIC_V1_2025_2026": PER_CATEGORY_RENUMBER,
    "SPWS_EVF_JOINED_V1_2026_2027": JOINED_BRACKET_CATEGORY_PLACE,
}

INTERNATIONAL_TYPES = frozenset({"PEW", "MEW", "MSW", "PSW"})


class UnknownScoringEngine(ValueError):
    """The engine assigned to a tournament type has no joined-bracket module."""


class JoinedBracketNotAllowed(ValueError):
    """An international tournament type was assigned the joined module."""


@dataclass(frozen=True)
class RowPlan:
    """What one written result stores: the place the module decided on."""

    place: int


@dataclass(frozen=True)
class CategoryPlan:
    """One category's tournament: its stored N and a row per kept fencer."""

    participant_count: int
    rows: tuple[RowPlan, ...]


@dataclass(frozen=True)
class BracketField:
    """The whole bracket as the engine sees it: its size N and its places."""

    size: int
    places: tuple[int, ...]

    @classmethod
    def from_places(cls, places: Iterable[int]) -> BracketField:
        """Ingestion: every listed fencer's place, matched or not."""
        ps = tuple(places)
        return cls(size=len(ps), places=ps)

    @classmethod
    def source(cls, places: Iterable[int], recorded_size: int | None) -> BracketField:
        """Ingestion of an international bracket: the size the parser recorded
        for the whole source bracket (``raw_pool_size``), which a POL filter
        cannot shrink; the listed places when no size was recorded."""
        ps = tuple(places)
        return cls(size=max(recorded_size or 0, len(ps)), places=ps)

    @classmethod
    def stored(cls, size: int, places: Iterable[int]) -> BracketField:
        """Recompute: N as stored at ingestion, which counts fencers who were
        never stored, so it is read back rather than recounted."""
        return cls(size=size, places=tuple(places))


class JoinedBracketModule(Protocol):
    name: str

    def plan_category(
        self, kept: Sequence[int], category: Sequence[int], field: BracketField
    ) -> CategoryPlan:
        """Plan one category's tournament.

        ``kept`` are the places of the fencers to write, in write order;
        ``category`` the places of every fencer of that category in the
        bracket, written or not; ``field`` the whole bracket.
        """
        ...

    def listing_order(
        self, categories: Sequence[tuple[int, str]], listing: Sequence[int]
    ) -> str | None:
        """The category order to store with every category of the listing, or
        None when the module stores none.

        ``categories`` holds (place, V-cat) for every fencer of the listing who
        has a category, written or not; ``listing`` every listed place.
        """
        ...


def dense_rank(places: Sequence[int | None]) -> list[int]:
    """Dense-rank places, aligned to the input order: overall {1,4,4,7} ->
    {1,2,2,3}. Moved unchanged from ``plugins.ingest._rerank_places``
    (ADR-049 amend / ADR-014/022)."""
    order = sorted(range(len(places)), key=lambda i: (places[i] is None, places[i]))
    out = [0] * len(places)
    rank = 0
    prev = None
    for pos, i in enumerate(order):
        p = places[i]
        if pos == 0 or p != prev:
            rank += 1
            prev = p
        out[i] = rank
    return out


_VCAT = re.compile(r"^V([0-4])$")


def category_digit(vcat: str) -> str:
    """'V2' -> '2': the digit a category takes in a stored order."""
    m = _VCAT.match(vcat or "")
    if m is None:
        raise ValueError(f"{vcat!r} is not a veterans category V0-V4; it has no digit in an order.")
    return m.group(1)


def listing_order(categories: Sequence[tuple[int, str]], listing: Sequence[int]) -> str:
    """The listing's category order, best place first (ADR-104 §§3-4).

    Refuses what cannot be scored: a listed place with no category (a pending
    match, or no birth year) and, in a joined listing, a repeated place, since
    nothing then says which fencer fenced ahead. A tie inside one category is
    accepted: that category's digit stands at every place, as EVF classic
    always scored it.
    """
    missing = sorted((Counter(listing) - Counter(p for p, _ in categories)).elements())
    if missing:
        raise ValueError(
            f"Place(s) {missing} of the listing have no category (a pending match or no "
            "birth year): the category order cannot be written, so the listing waits "
            "until each is resolved."
        )
    size = len(listing)
    digits = {category_digit(v) for _, v in categories}
    if len(digits) == 1:
        return digits.pop() * size
    counts = Counter(p for p, _ in categories)
    repeated = sorted(p for p, c in counts.items() if c > 1)
    if repeated:
        raise ValueError(
            f"A joined listing repeats place(s) {repeated}: nothing says which fencer "
            "fenced ahead. Ask the organiser for the fenced order."
        )
    by_place = dict(categories)
    if sorted(by_place) != list(range(1, size + 1)):
        raise ValueError(
            f"A joined listing's places {sorted(by_place)} are not 1..{size}. "
            "Ask the organiser for the fenced order."
        )
    return "".join(category_digit(by_place[p]) for p in range(1, size + 1))


def patch_order(order: str, placed: Iterable[tuple[int, str]]) -> str:
    """Recompute (ADR-104 §3): rewrite the digit of every stored place to its
    fencer's current category; places never stored keep their digit."""
    digits = list(order)
    seen: dict[int, str] = {}
    for place, vcat in placed:
        if not 1 <= place <= len(digits):
            raise ValueError(f"Place {place} is outside the stored order {order!r}.")
        digit = category_digit(vcat)
        if seen.setdefault(place, digit) != digit:
            raise ValueError(
                f"Place {place} holds two categories after the recompute of {order!r}: "
                "a joined listing needs the fenced order."
            )
        digits[place - 1] = digit
    return "".join(digits)


class PerCategoryRenumber:
    """EVF classic: each category is its own bracket of its written fencers."""

    name = PER_CATEGORY_RENUMBER

    def plan_category(
        self, kept: Sequence[int], category: Sequence[int], field: BracketField
    ) -> CategoryPlan:
        del category, field  # a split category is scored on its own rows alone
        return CategoryPlan(
            participant_count=len(kept),
            rows=tuple(RowPlan(place=p) for p in dense_rank(list(kept))),
        )

    def listing_order(
        self, categories: Sequence[tuple[int, str]], listing: Sequence[int]
    ) -> str | None:
        del categories, listing  # EVF classic scores each category on its own
        return None


class JoinedBracketCategoryPlace:
    """A joined bracket kept whole: every category keeps the joined place and N."""

    name = JOINED_BRACKET_CATEGORY_PLACE

    def plan_category(
        self, kept: Sequence[int], category: Sequence[int], field: BracketField
    ) -> CategoryPlan:
        del category  # the joined place is the fencer's own; nothing is recounted
        for place in kept:
            if place < 1 or place > field.size:
                raise ValueError(
                    f"Joined place {place} exceeds the bracket of {field.size}; "
                    "a place outside the listing is corrupt input, not a weak result."
                )
        return CategoryPlan(
            participant_count=field.size, rows=tuple(RowPlan(place=p) for p in kept)
        )

    def listing_order(
        self, categories: Sequence[tuple[int, str]], listing: Sequence[int]
    ) -> str | None:
        return listing_order(categories, listing) if listing else None


class SourceFieldPlace:
    """An international result (ADR-105): the whole source bracket as N and the
    fencer's own published place. Only Polish rows are written (ADR-038), so the
    rows kept are a sample of the bracket, never the bracket."""

    name = SOURCE_FIELD_PLACE

    def plan_category(
        self, kept: Sequence[int], category: Sequence[int], field: BracketField
    ) -> CategoryPlan:
        del category  # the place is the fencer's own; nothing is recounted
        for place in kept:
            if place < 1 or place > field.size:
                raise ValueError(
                    f"Place {place} exceeds the source bracket of {field.size}; "
                    "a place outside the bracket is corrupt input."
                )
        return CategoryPlan(
            participant_count=field.size, rows=tuple(RowPlan(place=p) for p in kept)
        )

    def listing_order(
        self, categories: Sequence[tuple[int, str]], listing: Sequence[int]
    ) -> str | None:
        del categories, listing  # scored per tournament on its N and place
        return None


_MODULES: dict[str, JoinedBracketModule] = {
    PER_CATEGORY_RENUMBER: PerCategoryRenumber(),
    JOINED_BRACKET_CATEGORY_PLACE: JoinedBracketCategoryPlace(),
    SOURCE_FIELD_PLACE: SourceFieldPlace(),
}


def module_for(engine_code: str | None, tourn_type: str | None) -> JoinedBracketModule:
    """The module paired with the engine assigned to a tournament type; for an
    international type, the source-field module (ADR-105).

    Raises ``UnknownScoringEngine`` for a code the pipeline does not know, and
    ``JoinedBracketNotAllowed`` for an international type assigned the joined
    module.
    """
    name = MODULE_BY_ENGINE.get(engine_code) if isinstance(engine_code, str) else None
    if name is None:
        raise UnknownScoringEngine(
            f"Unknown scoring engine: {engine_code!r} has no joined-bracket module. "
            "An engine is assigned deliberately, never inferred."
        )
    if name == JOINED_BRACKET_CATEGORY_PLACE and tourn_type in INTERNATIONAL_TYPES:
        raise JoinedBracketNotAllowed(
            f"{tourn_type} is international and is published per category; it cannot "
            f"be filed by {JOINED_BRACKET_CATEGORY_PLACE} (engine {engine_code})."
        )
    if tourn_type in INTERNATIONAL_TYPES:
        return _MODULES[SOURCE_FIELD_PLACE]
    return _MODULES[name]


__all__ = [
    "INTERNATIONAL_TYPES",
    "JOINED_BRACKET_CATEGORY_PLACE",
    "MODULE_BY_ENGINE",
    "PER_CATEGORY_RENUMBER",
    "SOURCE_FIELD_PLACE",
    "BracketField",
    "CategoryPlan",
    "JoinedBracketModule",
    "JoinedBracketNotAllowed",
    "RowPlan",
    "UnknownScoringEngine",
    "category_digit",
    "dense_rank",
    "listing_order",
    "module_for",
    "patch_order",
]
