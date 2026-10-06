"""International admission — who an international result belongs to (ADR-106).

One module decides every row of an international event (PEW, MEW, MSW, PSW,
the IMEW and IMSW codes included), for every ingestion path: the Phase 5
pipeline (``s6_resolve_identity``), the plugin pipeline (``ResolveFencers``),
the Admin per-tournament scrape (``resolve_tournament_results``) and the daily
EVF sync. The rule, decided by the user on 2 October 2026:

1. **Identity.** SURNAME, first given name and age category: exactly one roster
   fencer whose surname and first given name equal the source's (Polish letters
   folded, a second given name dropped) and whose birth year fits the bracket's
   category — **and** who has a PPW or MPW result in any season. Stored,
   whatever country the source prints. Not a fuzzy score: a typo or another
   first name is not the same person.
2. **Fallback.** Otherwise, a row the source printed POL is PENDING: never
   stored automatically; a person resolves it.
3. **Rejected.** Everything else, never PENDING. No fencer is ever created
   for an international event (ADR-020).

The federation the source printed is the result's evidence
(``tbl_result.txt_entered_for``), folded to three letters.
"""

from __future__ import annotations

import re
from collections.abc import Iterable
from dataclasses import dataclass

from python.matcher.fuzzy_match import (
    birth_year_matches_category,
    canonicalize_scraped_name,
    find_best_match,
    fold_diacritics,
)

STORED = "STORED"
PENDING = "PENDING"
REJECTED = "REJECTED"

_FEDERATION_FOLD = {"PL": "POL"}
_FEDERATION = re.compile(r"[A-Z]{3}")


@dataclass(frozen=True)
class Admission:
    """One row's decision: the fencer stored (STORED), the candidate a person
    reviews (PENDING, possibly none), or nobody (REJECTED)."""

    decision: str
    id_fencer: int | None
    confidence: float
    entered_for: str | None
    reason: str


def fold_federation(country: str | None) -> str | None:
    """The three-letter federation a source printed, upper case, PL → POL;
    None for an empty cell or anything that is not three letters (the
    stored ``txt_entered_for`` admits nothing else)."""
    code = (country or "").strip().upper()
    code = _FEDERATION_FOLD.get(code, code)
    return code if _FEDERATION.fullmatch(code) else None


def _words(text: str) -> list[str]:
    return fold_diacritics(canonicalize_scraped_name(text)).upper().split()


def _fits(birth_year: int | None, category: str | None, season_end_year: int) -> bool:
    """The birth year fits the bracket's category. EVF categories go by
    calendar year, so the year before the season's end year is accepted too
    (an autumn event). An unknown birth year cannot confirm the category."""
    if birth_year is None or category is None:
        return False
    return any(
        birth_year_matches_category(birth_year, category, y)
        for y in (season_end_year, season_end_year - 1)
    )


def identity_matches(
    name: str, category: str | None, season_end_year: int, roster: Iterable[dict]
) -> list[int]:
    """The roster fencers who are this source row: the same surname, the same
    first given name, and a birth year in the bracket's category."""
    words = _words(name)
    hits: list[int] = []
    for f in roster:
        surname = _words(f.get("txt_surname") or "")
        first = _words(f.get("txt_first_name") or "")[:1]
        if not surname or not first:
            continue
        n = len(surname)
        if words[:n] != surname or words[n : n + 1] != first:
            continue
        if _fits(f.get("int_birth_year"), category, season_end_year):
            hits.append(f["id_fencer"])
    return hits


def admit(
    name: str,
    printed_country: str | None,
    *,
    category: str | None,
    season_end_year: int,
    roster: list[dict],
    spws_starters: set[int] | frozenset[int],
) -> Admission:
    """Decide one international row (ADR-106 §1)."""
    entered_for = fold_federation(printed_country)
    hits = identity_matches(name, category, season_end_year, roster)
    if len(hits) == 1 and hits[0] in spws_starters:
        return Admission(STORED, hits[0], 100.0, entered_for, "identity, SPWS start")
    if len(hits) == 1:
        reason = "identity, no SPWS start"
    elif len(hits) > 1:
        reason = "two roster fencers fit"
    else:
        reason = "no identity match"
    if entered_for == "POL":
        if len(hits) == 1:
            return Admission(PENDING, hits[0], 100.0, entered_for, reason)
        best = find_best_match(name, roster, age_category=category, season_end_year=season_end_year)
        return Admission(PENDING, best.id_fencer, best.confidence, entered_for, reason)
    return Admission(REJECTED, None, 0.0, entered_for, reason)
