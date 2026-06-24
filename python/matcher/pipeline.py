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

# Age category → minimum age (youngest boundary). Retained for any caller
# that needs the band's lower edge; the *estimate* now uses the midpoint.
_CATEGORY_MIN_AGE = {
    "V0": 30,
    "V1": 40,
    "V2": 50,
    "V3": 60,
    "V4": 70,
}

# Age category → MIDPOINT anchor age (ADR-056, Stage-0 reconciliation 2026-06-13).
# Bounded bands (V1-V3) use the true band centre; the open-ended V0 (<40) and
# V4 (≥70) bands use a deliberate convention anchor (35 / 75). The estimated
# birth year is `season_end_year - anchor_age`. Ranking-neutral vs. the old
# youngest-edge estimate: both map to the same V-cat band, so changing the
# convention (and backfilling existing estimated fencers) never moves anyone
# between rankings — it only shifts the year within the band.
# This is the SINGLE source of truth for the midpoint; the frontend mirror is
# frontend/src/lib/birthYearEstimate.ts (kept in lockstep via vitest 5.1).
_CATEGORY_MIDPOINT_AGE = {
    "V0": 35,
    "V1": 45,
    "V2": 55,
    "V3": 65,
    "V4": 75,
}


@dataclass
class ResolvedTournament:
    """Result of resolving all scraped names for a single tournament."""

    matched: list[MatchResult] = field(default_factory=list)
    auto_created: list[dict] = field(default_factory=list)
    skipped: list[str] = field(default_factory=list)


def estimate_birth_year(category: str, season_end_year: int) -> int:
    """Estimate birth year from age category using the band MIDPOINT.

    ADR-056 (Stage-0 reconciliation, 2026-06-13): uses the midpoint anchor
    age for the category — a fencer in V2 (50-59) in a season ending 2025 is
    assumed born in 2025-55 = 1970 (band centre), not the youngest edge.
    Ranking-neutral: the estimate still lands in the same V-cat band.

    Args:
        category: Age category (V0, V1, V2, V3, V4)
        season_end_year: End year of the season (e.g., 2025 for SPWS-2024-2025)

    Returns:
        Estimated birth year

    Raises:
        ValueError: If category is not recognized
    """
    anchor_age = _CATEGORY_MIDPOINT_AGE.get(category)
    if anchor_age is None:
        raise ValueError(f"Unknown age category: {category}")
    return season_end_year - anchor_age


def auto_create_fencer(
    scraped_name: str,
    category: str,
    season_end_year: int,
    gender_default: str | None = None,
) -> dict:
    """Build a new fencer dict from a scraped name for auto-creation.

    Used when a PPW/MPW result has no match in the master data.
    Birth year is estimated from the season's age category.

    Args:
        scraped_name: Name as extracted by scraper (e.g., "SMITH John")
        category: Tournament age category (V0–V4)
        season_end_year: End year of the season (e.g., 2025 for SPWS-2024-2025)
        gender_default: Optional bracket-inherited gender (ADR-064). When the
            matcher's asymmetric F-bracket filter rejects all M candidates
            and falls through to this auto-create path, the new fencer
            inherits the bracket's gender (always 'F' in the ADR-064 path).
            Omitted by legacy callers that don't carry bracket gender.

    Returns:
        Dict with fields for tbl_fencer insertion
    """
    surname, first_name = parse_scraped_name(scraped_name)
    record = {
        "txt_surname": surname,
        "txt_first_name": first_name,
        "int_birth_year": estimate_birth_year(category, season_end_year),
        "bool_birth_year_estimated": True,
    }
    if gender_default is not None:
        record["enum_gender"] = gender_default
    return record


def resolve_tournament_results(
    scraped_names: list[str],
    fencer_db: list[dict],
    tournament_type: str,
    age_category: str,
    season_end_year: int,
    scraped_countries: list[str | None] | None = None,
    bracket_gender: str | None = None,
) -> ResolvedTournament:
    """Match scraped names against master data with tournament-type rules.

    Args:
        scraped_names: Names as extracted by scrapers
        fencer_db: Master fencer list (id_fencer, txt_surname, txt_first_name,
                   json_name_aliases, enum_gender)
        tournament_type: PPW, MPW, PEW, MEW, or MSW
        age_category: V0, V1, V2, V3, or V4
        season_end_year: End year of the season (e.g., 2025 for SPWS-2024-2025)
        scraped_countries: Optional parallel list of 3-letter ISO codes per row.
            When provided for EVF-organized (international) tournaments, rows
            whose country != "POL" are dismissed before matching — no match,
            no auto-create, no queue entry (ADR-038). Missing/None country
            at an international tournament also dismisses the row
            (fail-closed). SPWS-organized (domestic) tournaments ignore this
            parameter; all rows pass to the matcher.
        bracket_gender: Bracket gender for ADR-064 asymmetric filter. Forwarded
            to find_best_match ONLY for domestic events (PPW/MPW). When 'F'
            in a domestic bracket, M-gender candidates are dropped from the
            matcher's candidate set; rows that fall through to UNMATCHED are
            auto-created with enum_gender='F' inherited from the bracket.
            International tournaments ignore this parameter (out of scope per
            ADR-064; international intake follows ADR-038's POL-only rule).

    Returns:
        ResolvedTournament with matched, auto_created, and skipped lists
    """
    result = ResolvedTournament()
    is_domestic = tournament_type in DOMESTIC_TYPES
    # ADR-064: filter is domestic-only. International intake out of scope.
    effective_bracket_gender = bracket_gender if is_domestic else None

    for idx, name in enumerate(scraped_names):
        # ADR-038: EVF events — drop non-POL rows before matching.
        if not is_domestic and scraped_countries is not None:
            country = scraped_countries[idx] if idx < len(scraped_countries) else None
            if country != "POL":
                result.skipped.append(name)
                continue

        match = find_best_match(
            name,
            fencer_db,
            age_category,
            season_end_year,
            bracket_gender=effective_bracket_gender,
        )

        if match.status == "AUTO_MATCHED":
            result.matched.append(match)

        elif match.status == "PENDING":
            # Provisionally link to best match for both domestic and international
            result.matched.append(match)

        elif match.status == "UNMATCHED":
            if is_domestic:
                # Auto-create new fencer for domestic tournaments
                new_fencer = auto_create_fencer(
                    name,
                    age_category,
                    season_end_year,
                    gender_default=effective_bracket_gender,
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
        raise ValueError(f"Only PENDING candidates can be approved, got {candidate['enum_status']}")

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
            f"Only PENDING or UNMATCHED candidates can be dismissed, got {candidate['enum_status']}"
        )

    result = {
        **candidate,
        "enum_status": "DISMISSED",
    }
    if note:
        result["txt_admin_note"] = note
    return result
