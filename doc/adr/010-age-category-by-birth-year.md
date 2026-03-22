# ADR-010: Age Category by Birth Year (Cross-Category Carryover)

**Status:** Accepted
**Date:** 2025-03-03 (M5)

## Context

Fencers compete in age categories (V0–V4) based on their age. A fencer may transition between categories across seasons (e.g., V2 → V3 when turning 60). Tournament results are tagged with the tournament's `enum_age_category`, but a fencer's "home" category for ranking purposes depends on their birth year relative to the season's end date.

The ranking function `fn_ranking_ppw` must decide: rank fencers by the tournament's category, or by the fencer's birth-year-derived category?

## Decision

Rank fencers by their birth-year-derived category using `fn_age_category(birth_year, season_end_year)`, not by the tournament's `enum_age_category`. This enables cross-category carryover: a V3 fencer's results from V2 tournaments appear in the V3 ranking.

## Alternatives Considered

1. **Use tournament category as-is** — simpler SQL (just filter `WHERE t.enum_age_category = p_category`), but a fencer who transitions from V2 to V3 mid-season would lose all their V2 results from the ranking. This contradicts SPWS rules where fencers carry results forward.
2. **Dual ranking** — show fencer in both V2 and V3 rankings. Rejected: inflates rankings and double-counts points.

## Consequences

- `fn_age_category(birth_year, season_end_year)` — IMMUTABLE SQL helper computing V0–V4 from birth year and season end year.
- Migration: `20250303000002_age_category_by_season.sql`.
- NULL birth year fallback: `COALESCE(fn_age_category(...), t.enum_age_category)` — uses tournament category when birth year is unknown. This is a safe default since most fencers compete in their actual category.
- Cross-category carryover: BARAŃSKI (born 1964, V3 by birth year) with V2 tournament results appears in V3 ranking but NOT in V2 ranking (tests 5.14–5.15).
- Python matcher: `season_end_year` (not `tournament_year`) used throughout `fuzzy_match.py` and `pipeline.py` for consistency.
- Identity resolution: `birth_year_matches_category()` uses the same age ranges for duplicate name disambiguation (ADR cross-ref: no conflict with ADR-003 Identity by FK).
