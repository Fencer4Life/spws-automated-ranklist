"""
Identity resolution — pipeline and admin actions.

Orchestrates matching for tournament results and provides
admin review functions (approve, dismiss, create new fencer).
"""

from __future__ import annotations

from python.matcher.fuzzy_match import MatchResult, find_best_match


def resolve_results(
    scraped_names: list[str],
    fencer_db: list[dict],
) -> list[MatchResult]:
    """Match a list of scraped names against the fencer database.

    Args:
        scraped_names: Names as extracted by scrapers
        fencer_db: Master fencer list (id_fencer, txt_surname, txt_first_name, json_name_aliases)

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
