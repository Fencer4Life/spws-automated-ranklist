"""
Age-category splitting for combined-pool tournaments.

Single source of truth for how a combined-pool result list (V0+V1, V1+V2,
etc.) is split into per-V-cat sub-rankings. Used by every ingestion path
(XML, FTL JSON, Engarde HTML, 4Fence, Dartagnan, CSV/xlsx/JSON file
imports) so all paths agree on the rule:

  V-cat = fn_age_category(int_birth_year, season_end_year)

The marker that some sources embed (FTL "(1)" suffix, mid-name digit) is
NOT the source of truth — it's just a hint useful when fencer DOB is
unknown. tbl_fencer.int_birth_year is authoritative; markers are
cross-checked but not trusted over birth year.

History: this module was extracted from python/scrapers/fencingtime_xml.py
(2026-04-29). The XML path has had a correct splitter since ADR-024; every
other ingestion path was missing it, causing the 162 corrupted PPW/MPW
groups discovered in the audit. The fix is to move the logic here and
have all paths call it via split_and_ingest().
"""

from __future__ import annotations

from dataclasses import dataclass, field


# Age category → (min_age, max_age) inclusive.
# V0 minimum is 30 because veteran competitions don't accept under-30s in
# practice; we keep the floor here as documentation, not enforcement.
_CATEGORY_AGE_RANGE = {
    "V0": (30, 39),
    "V1": (40, 49),
    "V2": (50, 59),
    "V3": (60, 69),
    "V4": (70, 999),
}


def _birth_year_from_dob(dob_iso: str | None) -> int | None:
    """Extract year from ISO date string, or None."""
    if not dob_iso:
        return None
    return int(dob_iso[:4])


def birth_year_to_vcat(birth_year: int | None, season_end_year: int) -> str | None:
    """Return the SPWS V-cat ("V0".."V4") for a given birth year, or None.

    Single source of truth for BY → V-cat — used by the combined-pool
    splitter AND by per-category ingestion paths (e.g. EVF) that want to
    cross-check the source's category against SPWS rules.
    """
    if birth_year is None:
        return None
    age = season_end_year - birth_year
    for cat, (lo, hi) in _CATEGORY_AGE_RANGE.items():
        if lo <= age <= hi:
            return cat
    return None


@dataclass
class SplitResult:
    """Result of splitting combined-category results (ADR-024)."""

    buckets: dict[str, list[dict]] = field(default_factory=dict)
    unresolved: list[dict] = field(default_factory=list)


def split_combined_results(
    enriched_results: list[dict],
    categories: list[str],
    fencer_db: list[dict],
    season_end_year: int,
) -> SplitResult:
    """Split combined-category results into per-category ranked lists.

    For each fencer:
    1. Use birth_date from source if available
    2. Cross-reference fencer_db by name if DOB missing
    3. If still unknown → add to unresolved AND assign to lowest category
       (ADR-024: flag PENDING for admin review, don't silently assign)

    Re-ranks within each split: place 1..N per category.

    Args:
        enriched_results: Parsed rows; must include 'fencer_name' and 'place';
            optionally 'birth_date' (ISO).
        categories: List of categories to split into (e.g., ["V0", "V1"]).
        fencer_db: Master fencer list for DOB cross-reference (rows with
            'txt_surname', 'txt_first_name', 'int_birth_year').
        season_end_year: End year for age calculation.

    Returns:
        SplitResult with buckets (category → results) and unresolved list.
    """
    db_lookup: dict[str, int] = {}
    for f in fencer_db:
        surname = f.get("txt_surname", "")
        first_name = f.get("txt_first_name", "")
        name = f"{surname} {first_name}".strip() if first_name else surname
        by = f.get("int_birth_year")
        if by is not None:
            db_lookup[name.upper()] = by

    buckets: dict[str, list[dict]] = {cat: [] for cat in categories}
    unresolved: list[dict] = []
    lowest_cat = categories[0]

    sorted_results = sorted(enriched_results, key=lambda r: r["place"])

    for result in sorted_results:
        birth_year = _birth_year_from_dob(result.get("birth_date"))

        if birth_year is None:
            birth_year = db_lookup.get(result["fencer_name"].upper())

        assigned_cat = birth_year_to_vcat(birth_year, season_end_year)
        if assigned_cat is not None and assigned_cat not in categories:
            assigned_cat = None

        if assigned_cat is None:
            assigned_cat = lowest_cat
            unresolved.append(dict(result))

        buckets[assigned_cat].append(dict(result))

    for cat, fencers in buckets.items():
        for i, fencer in enumerate(fencers, 1):
            fencer["place"] = i

    return SplitResult(buckets=buckets, unresolved=unresolved)


# split_and_ingest() will be added in Stage 1C/1D once DbConnector exposes
# find_sibling_tournaments_by_url(). Keeping this module focused on the
# pure splitter logic for now — no DB coupling.
