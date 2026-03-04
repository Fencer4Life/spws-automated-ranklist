"""
Identity resolution — fuzzy name matching.

Compares scraped fencer names against the master fencer list (tbl_fencer)
using RapidFuzz for fuzzy string matching.

Thresholds:
  ≥95  → AUTO_MATCHED  (confident match)
  ≥50  → PENDING       (needs admin review)
  <50  → UNMATCHED     (no viable candidate)

Duplicate name disambiguation:
  When multiple fencers share the same name and tie at the same score,
  the tournament's age category is used to pick the correct fencer by
  checking whose birth year falls within the category's age range
  (age = season_end_year - birth_year).
  If disambiguation fails (neither or both fit), the match is forced
  to PENDING for admin review.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

from rapidfuzz import fuzz

AUTO_MATCH_THRESHOLD = 95
PENDING_THRESHOLD = 50

# Age category → (min_age, max_age) inclusive
_CATEGORY_AGE_RANGE = {
    "V0": (30, 39),
    "V1": (40, 49),
    "V2": (50, 59),
    "V3": (60, 69),
    "V4": (70, 999),
}


@dataclass
class MatchResult:
    """Result of matching a scraped name against the fencer database."""

    scraped_name: str
    id_fencer: int | None
    confidence: float
    status: str  # AUTO_MATCHED, PENDING, UNMATCHED
    matched_name: str | None = None


def normalize_name(name: str) -> str:
    """Normalize a name for comparison: lowercase, collapse whitespace."""
    return re.sub(r"\s+", " ", name.strip()).lower()


def parse_scraped_name(name: str) -> tuple[str, str]:
    """Parse 'SURNAME FirstName' into (surname, first_name).

    Single-word names (aliases like 'TK') return (word, '').
    Compound surnames with hyphens are preserved.
    """
    parts = name.strip().split(None, 1)
    if len(parts) == 1:
        return parts[0], ""
    return parts[0], parts[1]


def _build_full_name(fencer: dict) -> str:
    """Build 'SURNAME FirstName' from a fencer record."""
    surname = fencer["txt_surname"]
    first = fencer["txt_first_name"]
    if first:
        return f"{surname} {first}"
    return surname


def birth_year_matches_category(
    birth_year: int | None,
    category: str,
    season_end_year: int,
) -> bool:
    """Check if a fencer's birth year is compatible with an age category.

    Age is determined by the season's end year: a fencer "turns X during
    the end year" means age = season_end_year - birth_year.

    Args:
        birth_year: Fencer's birth year (None → can't verify → False)
        category: Tournament age category (V0–V4)
        season_end_year: End year of the season (e.g., 2025 for SPWS-2024-2025)

    Returns:
        True if the fencer's age falls within the category's range
    """
    if birth_year is None:
        return False
    age_range = _CATEGORY_AGE_RANGE.get(category)
    if age_range is None:
        return False
    age = season_end_year - birth_year
    return age_range[0] <= age <= age_range[1]


def _score_against_fencer(scraped: str, fencer: dict) -> float:
    """Compute best match score between scraped name and a fencer.

    Checks:
    1. Full name match (token_sort_ratio for word-order independence)
    2. Alias match (exact match against json_name_aliases)
    """
    scraped_norm = normalize_name(scraped)

    # Check aliases first (exact match = 100)
    aliases = fencer.get("json_name_aliases") or []
    for alias in aliases:
        if normalize_name(alias) == scraped_norm:
            return 100.0

    # Full name fuzzy comparison
    full_name = _build_full_name(fencer)
    full_name_norm = normalize_name(full_name)

    # Use token_sort_ratio: order-independent, handles "Jan KOWALSKI" vs "KOWALSKI Jan"
    score = fuzz.token_sort_ratio(scraped_norm, full_name_norm)

    return score


def find_best_match(
    scraped_name: str,
    fencer_db: list[dict],
    age_category: str | None = None,
    season_end_year: int | None = None,
) -> MatchResult:
    """Find the best matching fencer for a scraped name.

    When multiple fencers tie at the same score (e.g., duplicate names like
    KRAWCZYK Paweł born 1954 vs 1989), the tournament's age category is used
    to disambiguate by checking whose birth year fits the category's age range
    (age = season_end_year - birth_year).

    If disambiguation fails (neither or both candidates fit), the match is
    forced to PENDING for admin review regardless of the name score.

    Args:
        scraped_name: Name as extracted by scraper (e.g., "KOWALSKI Jan")
        fencer_db: List of fencer dicts with keys:
            id_fencer, txt_surname, txt_first_name, json_name_aliases,
            int_birth_year (optional, used for disambiguation)
        age_category: Tournament age category (V0–V4), optional
        season_end_year: End year of the season (e.g., 2025 for
            SPWS-2024-2025), optional

    Returns:
        MatchResult with status AUTO_MATCHED, PENDING, or UNMATCHED
    """
    if not fencer_db:
        return MatchResult(
            scraped_name=scraped_name,
            id_fencer=None,
            confidence=0,
            status="UNMATCHED",
        )

    # Score all fencers
    scored = []
    for fencer in fencer_db:
        score = _score_against_fencer(scraped_name, fencer)
        scored.append((score, fencer))

    # Find the best score
    best_score = max(s for s, _ in scored)

    # Collect all candidates tied at the best score
    tied = [(s, f) for s, f in scored if s == best_score]

    # Disambiguation: if multiple candidates tie, use age category
    force_pending = False
    if len(tied) == 1:
        best_fencer = tied[0][1]
    elif age_category is not None and season_end_year is not None:
        # Filter by age category compatibility
        matching = [
            (s, f) for s, f in tied
            if birth_year_matches_category(
                f.get("int_birth_year"), age_category, season_end_year
            )
        ]
        if len(matching) == 1:
            # Exactly one fits → disambiguated
            best_fencer = matching[0][1]
        else:
            # 0 or 2+ fit → can't disambiguate → force PENDING
            best_fencer = tied[0][1]
            force_pending = True
    else:
        # No age category info → can't disambiguate → force PENDING
        best_fencer = tied[0][1]
        force_pending = True

    best_fencer_id = best_fencer["id_fencer"]
    best_name = _build_full_name(best_fencer)

    # Determine status
    if force_pending:
        return MatchResult(
            scraped_name=scraped_name,
            id_fencer=best_fencer_id,
            confidence=best_score,
            status="PENDING",
            matched_name=best_name,
        )
    elif best_score >= AUTO_MATCH_THRESHOLD:
        return MatchResult(
            scraped_name=scraped_name,
            id_fencer=best_fencer_id,
            confidence=best_score,
            status="AUTO_MATCHED",
            matched_name=best_name,
        )
    elif best_score >= PENDING_THRESHOLD:
        return MatchResult(
            scraped_name=scraped_name,
            id_fencer=best_fencer_id,
            confidence=best_score,
            status="PENDING",
            matched_name=best_name,
        )
    else:
        return MatchResult(
            scraped_name=scraped_name,
            id_fencer=None,
            confidence=best_score,
            status="UNMATCHED",
        )
