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

At an FIE event (MSW, PSW, the IMSW code; amendment of 17 October 2026) a
national federation enters its fencers, so two things change: a row printed
POL that is exactly one roster fencer is stored without an SPWS start, and a
user-confirmed, unrevoked alias counts as identity. A merely recorded alias
does not: the stage-time flush records every pair it writes, the doubtful ones
too. EVF events are unchanged.

The federation the source printed is the result's evidence
(``tbl_result.txt_entered_for``), folded to three letters.
"""

from __future__ import annotations

import json
import re
from collections.abc import Iterable
from dataclasses import dataclass

from python.matcher.fuzzy_match import (
    birth_year_matches_category,
    canonicalize_scraped_name,
    find_best_match,
    fold_diacritics,
)
from python.pipeline import organizers as _organizers

STORED = "STORED"
PENDING = "PENDING"
REJECTED = "REJECTED"

# Why a row is not stored. None names a fencer, so a refusal's public summary
# counts them (ADR-119 G60 A).
NO_SPWS_START = "identity, no SPWS start"
TWO_FIT = "two roster fencers fit"
NO_MATCH = "no identity match"
REASONS = (TWO_FIT, NO_MATCH, NO_SPWS_START)

_FEDERATION_FOLD = {"PL": "POL"}
_FEDERATION = re.compile(r"[A-Z]{3}")

# The FIE's tournament types (MSW, the IMSW code included, and PSW, ADR-008),
# from the organizer registry (ADR-119 §2). Their entries come from the
# national federations, at most 4 per individual bracket.
FIE_TYPES = _organizers.fie_like_types()
FIE_MAX_PER_FEDERATION = 4


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


def _alias_list(value: object) -> list[str]:
    """A fencer's alias column as a list of names (JSONB arrives as a list, a
    JSON string or nothing)."""
    if isinstance(value, str):
        try:
            value = json.loads(value)
        except ValueError:
            return []
    return [a for a in value if isinstance(a, str)] if isinstance(value, list) else []


def alias_matches(
    name: str, category: str | None, season_end_year: int, roster: Iterable[dict]
) -> list[int]:
    """The roster fencers one of whose user-confirmed, unrevoked aliases is
    this source row's name (whole words, Polish letters folded, a further
    given name in the source dropped), with a birth year in the bracket's
    category."""
    words = _words(name)
    hits: list[int] = []
    for f in roster:
        revoked = {tuple(_words(a)) for a in _alias_list(f.get("json_revoked_aliases"))}
        for alias in _alias_list(f.get("json_user_confirmed_aliases")):
            aw = _words(alias)
            if len(aw) < 2 or tuple(aw) in revoked or words[: len(aw)] != aw:
                continue
            if _fits(f.get("int_birth_year"), category, season_end_year):
                hits.append(f["id_fencer"])
            break
    return hits


def is_fie_type(tournament_type: str | None) -> bool:
    """True for an FIE-like organizer's tournament type (MSW, PSW), read from
    the organizer registry at the call (ADR-119 §2)."""
    return _organizers.fie_like_type(tournament_type)


def admit(
    name: str,
    printed_country: str | None,
    *,
    category: str | None,
    season_end_year: int,
    roster: list[dict],
    spws_starters: set[int] | frozenset[int],
    tournament_type: str | None = None,
    readings: tuple[str, ...] = (),
) -> Admission:
    """Decide one international row (ADR-106 §1, and its FIE amendment).

    ``tournament_type`` is the event's type (the IMSW code derives to MSW).
    Without one the row is decided as at an EVF event, which never stores
    more than ADR-106 §1 does. ``readings`` are the "SURNAME First" readings
    of a row whose source repeats the name in both name cells (G41 A): every
    fencer one of them names counts as a fit, and the rule is otherwise the
    same, so exactly one fit is needed to store the row. A fencer found more
    than once (by identity and by alias, or by two readings) is one fit (G59)."""
    entered_for = fold_federation(printed_country)
    fie = is_fie_type(tournament_type)
    hits: list[int] = []
    for text in (name, *readings):
        found = identity_matches(text, category, season_end_year, roster)
        if fie:
            found += alias_matches(text, category, season_end_year, roster)
        for h in found:
            if h not in hits:
                hits.append(h)
    read = " (read past the name the source repeats in both name cells)" if readings else ""
    if len(hits) == 1 and hits[0] in spws_starters:
        return Admission(STORED, hits[0], 100.0, entered_for, f"identity, SPWS start{read}")
    if fie and len(hits) == 1 and entered_for == "POL":
        return Admission(
            STORED, hits[0], 100.0, entered_for, f"identity, entered by POL at an FIE event{read}"
        )
    if len(hits) == 1:
        reason = NO_SPWS_START
    elif len(hits) > 1:
        reason = TWO_FIT
    else:
        reason = NO_MATCH
    if entered_for == "POL":
        if len(hits) == 1:
            return Admission(PENDING, hits[0], 100.0, entered_for, reason)
        best = find_best_match(name, roster, age_category=category, season_end_year=season_end_year)
        return Admission(PENDING, best.id_fencer, best.confidence, entered_for, reason)
    return Admission(REJECTED, None, 0.0, entered_for, reason)
