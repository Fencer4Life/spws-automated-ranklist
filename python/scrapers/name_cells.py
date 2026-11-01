"""Name cells — a source that prints a surname cell and a first-name cell (G41 A).

Engarde, d'Artagnan, 4fence and FencingTime XML (``Nom``/``Prenom``) print a
fencer's name in two cells, which each parser joins into one printed name.
The norm, read on every row of the ten Engarde events of the last 30 months
(2,735 of 2,740 rows): one cell holds the surname, the other the given names,
and neither repeats the other. A row where every word of one cell is in the
other is a *source exception*: the organiser keyed the whole name twice
("ANNA GANSZCZYK" / "Anna Ganszczyk", PEW Madrid 2026), or the whole name in
the first-name cell ("GONZALEZ" / "Patricia Gonzalez"). A shared particle is
not one ("DE VARGAS HILLA" / "Cristina De Lourdes").

An exception keeps its printed name, so a listing's hash is unchanged; the
parser records it on the bracket (``ParsedTournament.source_exceptions``) with
the readings the whole name allows, each "SURNAME First". The identity step
tries them by the same rule as every other row, and every exception is
reported. A bracket where more than one row breaks the norm, and more than one
row in ten, has changed its layout: it is refused, never read by guesswork.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from python.matcher.fuzzy_match import fold_diacritics

REPEATED = "name_cells_repeated"


class SourceNotUnderstood(ValueError):
    """A bracket the reader will not read: its table no longer keeps the norm
    its engine's parser relies on. The message names the bracket and the
    counts, never a fencer (ADR-119 D12), so a public log may show it."""


def _fold(word: str) -> str:
    """Polish letters folded as the identity rule folds them (Ł too)."""
    return fold_diacritics(word).upper()


def _words(cell: str) -> list[str]:
    return [w for w in (cell or "").split() if w]


def repeats(surname: str, first: str) -> bool:
    """True when one name cell repeats the other: every word of one is in it."""
    s = {_fold(w) for w in _words(surname)}
    f = {_fold(w) for w in _words(first)}
    return bool(s) and bool(f) and (s <= f or f <= s)


def readings(surname: str, first: str) -> tuple[str, ...]:
    """Every "SURNAME First" the whole name allows: its words (the cell that
    holds more of them, then any the other adds) split once, the surname
    before or after the first given name. None for a single word."""
    a, b = _words(first), _words(surname)
    whole = a if len(a) >= len(b) else b
    seen = {_fold(w) for w in whole}
    whole = [*whole, *(w for w in (b if whole is a else a) if _fold(w) not in seen)]
    out: list[str] = []
    for i in range(1, len(whole)):
        for sur, given in ((whole[:i], whole[i]), (whole[i:], whole[0])):
            text = " ".join(w.upper() for w in sur) + " " + given[:1].upper() + given[1:].lower()
            if text not in out:
                out.append(text)
    return tuple(out)


@dataclass
class NameCellCheck:
    """A bracket's exceptions, collected row by row as its parser reads them."""

    items: list[dict] = field(default_factory=list)

    def row(self, surname: str, first: str, *, printed: str, place: int | None) -> None:
        if repeats(surname, first):
            self.items.append(
                {
                    "kind": REPEATED,
                    "place": place,
                    "printed": printed,
                    "readings": list(readings(surname, first)),
                }
            )

    def checked(self, rows: int, where: str | None) -> list[dict]:
        """The exceptions, once the guard has passed the bracket."""
        n = len(self.items)
        if n > 1 and n * 10 > rows:
            raise SourceNotUnderstood(
                f"{where or 'a bracket'}: {n} of {rows} rows repeat the name in both name "
                "cells; the source's table no longer keeps the norm, so the bracket is not "
                "read (G41 A). Look at the source, then ingest again."
            )
        return self.items


def readings_for(parsed: Any, row: Any) -> tuple[str, ...]:
    """The readings of a row its bracket recorded as a source exception."""
    for e in getattr(parsed, "source_exceptions", None) or []:
        if e.get("printed") == row.fencer_name and e.get("place") == row.place:
            return tuple(e.get("readings") or ())
    return ()
