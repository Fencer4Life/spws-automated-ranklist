"""What a source states twice, compared and reported (ADR-119 G42 A).

Organisers state a bracket's label twice, picked from a list and typed into
its title: Engarde's ``sexe`` and slug, d'Artagnan's line under the title,
FencingTime's ``Sexe``. The readers choose one statement, and that choice is
unchanged here: each disagreement is reported, on the bracket
(``ParsedTournament.source_disagreements``), in the read's log, the staging
report's gaps (Telegram) and the run record. Nothing here holds an event or
stops a write (doc/plans/partial-ingest-promote-results-sync-2026-10-31.html,
the push 2b build sheet, 2b.1–2b.6).

Every detail names the bracket's facts and places, never a fencer (D12): the
read's log is public.

Tests: python/tests/test_source_consistency.py (SRC.CONS.01–10).
"""

from __future__ import annotations

from collections.abc import Iterable
from dataclasses import replace
from typing import Any

GENDER = "gender"
CATEGORY = "category"
PLACES = "places"
COUNT = "count"
NATIONALITY = "no nationality"


def label(kind: str, title: str, titled: Any, declared: Any, chosen: Any) -> dict | None:
    """A label the title states one way and the source declares another, or
    None when either says nothing or they agree. `chosen` is the reader's
    choice, which the detail names."""
    if not titled or not declared or titled == declared:
        return None
    winner = "the title" if chosen == titled else "the declared value"
    return {
        "kind": kind,
        "detail": f"title {title!r} says {titled}; the source declared {declared}; {winner} wins",
    }


def _placed(results: Iterable[Any]) -> list[int]:
    return sorted(
        r.place for r in results if (r.place or 0) > 0 and not getattr(r, "bool_excluded", False)
    )


def places(results: Iterable[Any]) -> dict | None:
    """The placed rows of a whole bracket run 1..N with ties: a place is one
    more than the rows ahead of it (1, 2, 3, 3, 5). Unplaced and excluded rows
    are aside."""
    placed = _placed(results)
    for i, place in enumerate(placed):
        if i and place == placed[i - 1]:
            continue
        if place != i + 1:
            return {
                "kind": PLACES,
                "detail": f"places are not 1..{len(placed)}: "
                f"after {i} row(s) the next place is {place}, not {i + 1}",
            }
    return None


def printed_count(printed: int | None, listed: int) -> dict | None:
    """The count a source prints against the rows it lists, placed or not:
    the printed count includes a fencer listed without a place (ENG.EVT.05)."""
    if printed is None or printed == listed:
        return None
    return {"kind": COUNT, "detail": f"the source prints {printed} fencer(s) and lists {listed}"}


def nationality(results: Iterable[Any]) -> dict | None:
    """A bracket in which no row has a country: no nationality column, so the
    international admission decides every row by identity alone."""
    rows = list(results)
    if not rows or any((r.fencer_country or "").strip() for r in rows):
        return None
    return {
        "kind": NATIONALITY,
        "detail": f"none of the {len(rows)} rows has a country: "
        "admission decides each by identity alone",
    }


def of(parsed: Any, *, international: bool = True) -> list[dict]:
    """Every disagreement of a bracket: what its reader found, then the checks
    on its rows. EVF's results API returns the Poles of a bracket only, so its
    rows are not checked; a missing country matters only where the
    international admission decides who is ours (2b.3)."""
    if parsed is None:
        return []
    found = list(getattr(parsed, "source_disagreements", None) or [])
    if str(getattr(parsed, "source_kind", "")) == "EVF_API":
        return found
    results = list(getattr(parsed, "results", None) or [])
    checks = [places(results), nationality(results) if international else None]
    return found + [d for d in checks if d is not None]


def checked(parsed: Any, *, international: bool = True) -> Any:
    """The bracket with every disagreement on it, computed once by the reader;
    the log, the staging report and the run record read that list."""
    return replace(parsed, source_disagreements=of(parsed, international=international))


def _on(parsed: Any) -> list[dict]:
    return list(getattr(parsed, "source_disagreements", None) or [])


def lines(name: str, parsed: Any) -> list[str]:
    """The read's log lines for one bracket: its name, the kind and the detail."""
    return [f"  disagree {name!r}: {d['kind']}: {d['detail']}" for d in _on(parsed)]


def notes(parsed_list: Iterable[Any]) -> list[dict]:
    """The staging report's input: each bracket that holds a disagreement."""
    return [
        {
            "name": getattr(p, "tournament_name", None) or getattr(p, "source_url", None) or "?",
            "disagreements": found,
        }
        for p in parsed_list
        if p is not None and (found := _on(p))
    ]


def recorded(parsed: Any) -> list[dict]:
    """The run record's copy of a bracket's disagreements."""
    return _on(parsed)
