# ADR-019: Domestic-Only Fencer Seed

**Status:** Accepted
**Date:** 2026-04-04 (M9)

## Context

`seed_tbl_fencer.sql` contained 361 fencers. Only 232 had PPW/MPW/GPW results in the SQL data files (`supabase/data/**/*.sql`, covering seasons 2023-24 through 2025-26). An additional 51 fencers had domestic results in earlier seasons (2021, 2022) available only as Excel files in `doc/external_files/`. The remaining 75 were either international-only (PEW/MEW/MSW/PSW only) or zero-result (no data anywhere).

The live pipeline (`pipeline.py`) already enforces this boundary: international unmatched fencers are SKIPPED, never auto-created (tests 4.17, 4.18). The seed was the only place where this rule was not enforced.

## Decision

`tbl_fencer` seed contains **only** fencers with at least one domestic (PPW/MPW/GPW) result. Domestic participation is derived from two sources:

1. **SQL data files** (`supabase/data/**/*.sql`) — fencer IDs appearing in PPW/MPW/GPW result blocks
2. **Excel-only seasons** (`doc/external_files/Sezon 2021`, `Sezon 2022`) — fencer names from domestic GP/MP sheets, fuzzy-matched against the seed using `rapidfuzz` + diacritic folding (threshold ≥90)

International-only and zero-result fencers are excluded. When a fencer is removed from the seed, their result blocks in international tournament data (PEW/MEW/MSW/PSW) are also deleted from the SQL data files.

## Alternatives Considered

1. **Keep all fencers, mark with comments** (status quo) — 75+ dead entries pollute master data, IDs waste autoincrement space, violates "no garbage in" principle.
2. **Remove only international-only, keep zero-result** — zero-result fencers contribute nothing to rankings; keeping them provides no benefit and creates confusion about membership status.
3. **Hardcoded removal set** (previous `NO_PPW_MPW_IDS`) — goes stale as data files change; already proven incorrect (82 IDs vs 129 actual).
4. **SQL-only scan** (no Excel) — would incorrectly remove 51 fencers who competed domestically in 2021/2022 but have no SQL data file results yet.

## Consequences

- Fencer count drops from 361 to 280 — all remaining fencers have domestic tournament participation
- All fencer IDs shift (autoincrement resets after sort) — pgTAP tests with hardcoded IDs updated accordingly
- Fencers who later join SPWS domestically will be auto-created by the pipeline on their first PPW/MPW appearance; re-running `generate_season_seed.py` picks up their prior international results retroactively
- `tbl_fencer` becomes the authoritative SPWS domestic member pool
