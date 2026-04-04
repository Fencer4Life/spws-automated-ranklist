"""
Identity resolution — fuzzy name matching.

Compares scraped fencer names against the master fencer list (tbl_fencer)
using RapidFuzz for fuzzy string matching.

Thresholds (configurable):
  ≥95  → AUTO_MATCHED  (confident match)
  ≥50  → PENDING       (needs admin review)
  <50  → UNMATCHED     (no viable candidate)

Enhancements for staging spreadsheet pipeline:
  - Diacritic folding: BARAŃSKI → BARANSKI for cross-source matching
  - Token set ratio: handles name subsets (NEYMAN vs SPŁAWA-NEYMAN)
  - Configurable thresholds via function parameters

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
import unicodedata
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


def fold_diacritics(text: str) -> str:
    """Strip diacritical marks from text: ą→a, ł→l, ü→u, etc.

    Uses Unicode NFD decomposition to split base characters from
    combining marks, then removes the combining marks.
    Special-cases ł/Ł which don't decompose via NFD.
    """
    # ł/Ł are not decomposed by NFD — handle explicitly
    text = text.replace("ł", "l").replace("Ł", "L")
    # NFD decompose, then strip combining marks (category 'Mn')
    nfd = unicodedata.normalize("NFD", text)
    return "".join(c for c in nfd if unicodedata.category(c) != "Mn")


def strip_category_markers(name: str) -> str:
    """Remove FTL category markers like (0), (1), (kat 1), (V1) from names."""
    return re.sub(r"\s*\((?:kat\s*)?V?\d+\)\s*", " ", name).strip()


def normalize_name(name: str, use_diacritic_folding: bool = False) -> str:
    """Normalize a name for comparison: strip markers, lowercase, collapse whitespace.

    Args:
        name: Raw name string
        use_diacritic_folding: If True, strip diacritics before normalizing
    """
    result = strip_category_markers(name)
    result = re.sub(r"\s+", " ", result.strip()).lower()
    if use_diacritic_folding:
        result = fold_diacritics(result)
    return result


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


def _score_against_fencer(
    scraped: str,
    fencer: dict,
    use_diacritic_folding: bool = False,
    use_token_set_ratio: bool = False,
) -> float:
    """Compute best match score between scraped name and a fencer.

    Checks:
    1. Alias match (exact match against json_name_aliases) → 100
    2. Full name fuzzy comparison (token_sort_ratio, optionally token_set_ratio)
    """
    scraped_norm = normalize_name(scraped, use_diacritic_folding)

    # Check aliases first (exact match = 100)
    aliases = fencer.get("json_name_aliases") or []
    for alias in aliases:
        if normalize_name(alias, use_diacritic_folding) == scraped_norm:
            return 100.0

    # Full name fuzzy comparison
    full_name = _build_full_name(fencer)
    full_name_norm = normalize_name(full_name, use_diacritic_folding)

    # Use token_sort_ratio: order-independent, handles "Jan KOWALSKI" vs "KOWALSKI Jan"
    score = fuzz.token_sort_ratio(scraped_norm, full_name_norm)

    # Optionally use token_set_ratio (handles name subsets) and take the max
    if use_token_set_ratio:
        set_score = fuzz.token_set_ratio(scraped_norm, full_name_norm)
        score = max(score, set_score)

    # Component-level scoring: compare surname and first_name separately
    # Catches typos where one component is exact and the other has 1-2 char differences
    scraped_surname, scraped_first = parse_scraped_name(scraped)
    fencer_first = fencer["txt_first_name"] or ""
    if scraped_first and fencer_first:
        s_sur = normalize_name(scraped_surname, use_diacritic_folding)
        s_fst = normalize_name(scraped_first, use_diacritic_folding)
        f_sur = normalize_name(fencer["txt_surname"], use_diacritic_folding)
        f_fst = normalize_name(fencer_first, use_diacritic_folding)
        sur_best = fuzz.ratio(s_sur, f_sur)
        fst_best = max(fuzz.ratio(s_fst, f_fst), fuzz.partial_ratio(s_fst, f_fst))
        # Require first name similarity ≥55 to avoid matching brothers/unrelated.
        # 55 (not 50) because partial_ratio inflates short name pairs to ~50
        # even for clearly different names (e.g., "dariusz" vs "jarosław").
        if fst_best >= 55:
            component_score = 0.75 * sur_best + 0.25 * fst_best
            score = max(score, component_score)

        # Penalty: if surname matches well but first name is very different,
        # cap the score to prevent false matches on shared surnames (brothers).
        # Uses 55 threshold (not 50) because partial_ratio can inflate short
        # name pairs to exactly 50 (e.g., "dariusz" vs "jarosław").
        if sur_best >= 90 and fst_best < 55:
            score = min(score, 60)
        elif sur_best < 50 and fst_best >= 90:
            score = min(score, 60)

    return score


def find_best_match(
    scraped_name: str,
    fencer_db: list[dict],
    age_category: str | None = None,
    season_end_year: int | None = None,
    *,
    auto_match_threshold: float | None = None,
    pending_threshold: float | None = None,
    use_diacritic_folding: bool = False,
    use_token_set_ratio: bool = False,
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
        auto_match_threshold: Score threshold for AUTO_MATCHED (default: 95)
        pending_threshold: Score threshold for PENDING (default: 50)
        use_diacritic_folding: Strip diacritics before comparing (default: False)
        use_token_set_ratio: Use max(token_sort, token_set) (default: False)

    Returns:
        MatchResult with status AUTO_MATCHED, PENDING, or UNMATCHED
    """
    auto_thresh = auto_match_threshold if auto_match_threshold is not None else AUTO_MATCH_THRESHOLD
    pend_thresh = pending_threshold if pending_threshold is not None else PENDING_THRESHOLD

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
        score = _score_against_fencer(
            scraped_name, fencer,
            use_diacritic_folding=use_diacritic_folding,
            use_token_set_ratio=use_token_set_ratio,
        )
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
    elif best_score >= auto_thresh:
        return MatchResult(
            scraped_name=scraped_name,
            id_fencer=best_fencer_id,
            confidence=best_score,
            status="AUTO_MATCHED",
            matched_name=best_name,
        )
    elif best_score >= pend_thresh:
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
