# ADR-024: Combined Category Splitting Strategy

**Status:** Accepted
**Date:** 2026-04-05 (Go-to-PROD)

## Context

Some Polish domestic tournaments combine age categories — e.g., V0 and V1 fencers compete together in a single pool. The FencingTime Live XML file has `AltName="SZPADA MĘŻCZYZN v0v1"` and contains all fencers mixed. However, the ranking system needs per-category results (separate `tbl_tournament` records for V0 and V1), each with independent placement (1st, 2nd, 3rd within V0; 1st, 2nd, 3rd within V1).

The `split_combined_results()` function already exists in `python/scrapers/fencingtime_xml.py` (tested: 9.126–9.127). This ADR documents the strategy and edge case handling.

## Decision

Use **birth date (`DateNaissance`) from the XML** as the primary mechanism to assign fencers to their correct age category within a combined tournament. The splitting logic:

1. Parse `AltName` to detect combined categories (e.g., `v0v1` → `[V0, V1]`)
2. For each `<Tireur>`:
   a. If `DateNaissance` is present → calculate age → `birth_year_matches_category()` assigns category
   b. If `DateNaissance` is missing → cross-reference `fencer_db` by name for known birth year
   c. If neither resolves → **flag as PENDING for admin review** (do not silently assign)
3. Group fencers by resolved category
4. Re-rank within each category: place 1, 2, 3, ... preserving relative order from the combined results

### Edge Case: Unresolvable Fencers

When a fencer's category cannot be determined (no DOB in XML, not found in `fencer_db`), the system:
- Creates the result with `tbl_match_candidate.enum_status = 'PENDING'`
- Sends a Telegram notification: "⚠️ N fencers without birth date in v0v1 file — can't split. Review needed."
- Admin resolves by assigning the correct category in the Identity Manager UI

This differs from the current fallback implementation which silently assigns to the lowest category. The ADR mandates explicit admin review for ambiguous cases.

## Alternatives Considered

1. **Silent fallback to lowest category** — The current `split_combined_results()` implementation assigns unresolvable fencers to the lowest category (e.g., V0 in a V0V1 split). Simple but can place a V1 fencer in V0 results, corrupting rankings. Acceptable for seed data generation where admin reviews output, but not for automated ingestion.

2. **Skip unresolvable fencers entirely** — Don't import results for fencers whose category can't be determined. Loses data; the fencer participated and has a valid result.

3. **Treat combined category as a single tournament** — Don't split at all; create a single V0V1 tournament. Breaks the ranking model which requires per-category tournaments for scoring.

## Consequences

- Combined category files produce multiple tournament imports (one per detected category)
- Birth date coverage in XML files determines how many fencers can be auto-split
- Fencers without DOB and not in `fencer_db` require manual admin intervention
- The existing `split_combined_results()` function needs a minor change: instead of fallback to lowest category, mark unresolvable fencers for admin review
- Telegram notifications ensure admin is aware of pending splits immediately
- As the `tbl_fencer` master data grows (more birth years known), fewer fencers will be unresolvable over time
