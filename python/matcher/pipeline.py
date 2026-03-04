"""
Identity resolution — pipeline and admin actions.

Orchestrates matching for tournament results with tournament-type-based
intake rules:

  PPW/MPW (domestic): ALL results enter the ranklist.
    - AUTO_MATCHED: link to existing fencer
    - PENDING: provisionally link to best match, flag for admin
    - UNMATCHED: auto-create new fencer in master data

  PEW/MEW (international): only results for existing master data fencers.
    - AUTO_MATCHED: link to existing fencer
    - PENDING: provisionally link to best match, flag for admin
    - UNMATCHED: skip entirely (result not imported)

Admin review functions (approve, dismiss, create new fencer) remain
unchanged for manual corrections.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from python.matcher.fuzzy_match import MatchResult, find_best_match, parse_scraped_name

DOMESTIC_TYPES = {"PPW", "MPW"}
INTERNATIONAL_TYPES = {"PEW", "MEW", "MSW"}

# Age category → minimum age (youngest boundary)
_CATEGORY_MIN_AGE = {
    "V0": 30,
    "V1": 40,
    "V2": 50,
    "V3": 60,
    "V4": 70,
}


@dataclass
class ResolvedTournament:
    """Result of resolving all scraped names for a single tournament."""

    matched: list[MatchResult] = field(default_factory=list)
    auto_created: list[dict] = field(default_factory=list)
    skipped: list[str] = field(default_factory=list)


def estimate_birth_year(category: str, season_end_year: int) -> int:
    """Estimate birth year from age category using youngest boundary.

    Uses the minimum age for the category: a fencer in V2 (50-59) in a
    season ending 2025 is assumed born in 2025-50 = 1975.

    Args:
        category: Age category (V0, V1, V2, V3, V4)
        season_end_year: End year of the season (e.g., 2025 for SPWS-2024-2025)

    Returns:
        Estimated birth year

    Raises:
        ValueError: If category is not recognized
    """
    min_age = _CATEGORY_MIN_AGE.get(category)
    if min_age is None:
        raise ValueError(f"Unknown age category: {category}")
    return season_end_year - min_age


def auto_create_fencer(
    scraped_name: str,
    category: str,
    season_end_year: int,
) -> dict:
    """Build a new fencer dict from a scraped name for auto-creation.

    Used when a PPW/MPW result has no match in the master data.
    Birth year is estimated from the season's age category.

    Args:
        scraped_name: Name as extracted by scraper (e.g., "SMITH John")
        category: Tournament age category (V0–V4)
        season_end_year: End year of the season (e.g., 2025 for SPWS-2024-2025)

    Returns:
        Dict with fields for tbl_fencer insertion
    """
    surname, first_name = parse_scraped_name(scraped_name)
    return {
        "txt_surname": surname,
        "txt_first_name": first_name,
        "int_birth_year": estimate_birth_year(category, season_end_year),
        "bool_birth_year_estimated": True,
    }


def resolve_tournament_results(
    scraped_names: list[str],
    fencer_db: list[dict],
    tournament_type: str,
    age_category: str,
    season_end_year: int,
) -> ResolvedTournament:
    """Match scraped names against master data with tournament-type rules.

    Args:
        scraped_names: Names as extracted by scrapers
        fencer_db: Master fencer list (id_fencer, txt_surname, txt_first_name,
                   json_name_aliases)
        tournament_type: PPW, MPW, PEW, MEW, or MSW
        age_category: V0, V1, V2, V3, or V4
        season_end_year: End year of the season (e.g., 2025 for SPWS-2024-2025)

    Returns:
        ResolvedTournament with matched, auto_created, and skipped lists
    """
    result = ResolvedTournament()
    is_domestic = tournament_type in DOMESTIC_TYPES

    for name in scraped_names:
        match = find_best_match(name, fencer_db, age_category, season_end_year)

        if match.status == "AUTO_MATCHED":
            result.matched.append(match)

        elif match.status == "PENDING":
            # Provisionally link to best match for both domestic and international
            result.matched.append(match)

        elif match.status == "UNMATCHED":
            if is_domestic:
                # Auto-create new fencer for domestic tournaments
                new_fencer = auto_create_fencer(
                    name, age_category, season_end_year
                )
                result.auto_created.append(new_fencer)
                result.matched.append(
                    MatchResult(
                        scraped_name=name,
                        id_fencer=None,
                        confidence=0,
                        status="NEW_FENCER",
                        matched_name=None,
                    )
                )
            else:
                # Skip unknown fencers in international tournaments
                result.skipped.append(name)

    return result


# ---------------------------------------------------------------------------
# Legacy convenience wrapper (backwards-compatible)
# ---------------------------------------------------------------------------
def resolve_results(
    scraped_names: list[str],
    fencer_db: list[dict],
) -> list[MatchResult]:
    """Match a list of scraped names against the fencer database.

    Legacy wrapper — does not apply tournament-type intake rules.
    Use resolve_tournament_results() for the full pipeline.

    Args:
        scraped_names: Names as extracted by scrapers
        fencer_db: Master fencer list

    Returns:
        List of MatchResult objects, one per scraped name
    """
    return [find_best_match(name, fencer_db) for name in scraped_names]


def approve_match(candidate: dict, fencer_id: int) -> dict:
    """Admin approves a PENDING match candidate.

    Links the result to the specified fencer and sets status to APPROVED.

    Args:
        candidate: Match candidate dict (from tbl_match_candidate)
        fencer_id: The fencer to link to

    Returns:
        Updated candidate dict

    Raises:
        ValueError: If candidate is not in PENDING status
    """
    if candidate["enum_status"] != "PENDING":
        raise ValueError(
            f"Only PENDING candidates can be approved, "
            f"got {candidate['enum_status']}"
        )

    return {
        **candidate,
        "enum_status": "APPROVED",
        "id_fencer": fencer_id,
    }


def create_new_fencer_from_match(
    candidate: dict,
    surname: str,
    first_name: str,
    birth_year: int | None = None,
) -> dict:
    """Admin creates a new fencer from an unmatched/pending candidate.

    Sets status to NEW_FENCER and includes the new fencer data
    to be inserted into tbl_fencer.

    Args:
        candidate: Match candidate dict
        surname: New fencer surname
        first_name: New fencer first name
        birth_year: Optional birth year

    Returns:
        Dict with updated candidate and new_fencer data
    """
    if candidate["enum_status"] not in ("PENDING", "UNMATCHED"):
        raise ValueError(
            f"Only PENDING or UNMATCHED candidates can create new fencers, "
            f"got {candidate['enum_status']}"
        )

    return {
        **candidate,
        "enum_status": "NEW_FENCER",
        "new_fencer": {
            "txt_surname": surname,
            "txt_first_name": first_name,
            "int_birth_year": birth_year,
        },
    }


def dismiss_match(candidate: dict, note: str | None = None) -> dict:
    """Admin dismisses a match candidate.

    Args:
        candidate: Match candidate dict
        note: Optional admin note explaining the dismissal

    Returns:
        Updated candidate dict with DISMISSED status
    """
    if candidate["enum_status"] not in ("PENDING", "UNMATCHED"):
        raise ValueError(
            f"Only PENDING or UNMATCHED candidates can be dismissed, "
            f"got {candidate['enum_status']}"
        )

    result = {
        **candidate,
        "enum_status": "DISMISSED",
    }
    if note:
        result["txt_admin_note"] = note
    return result
