# ADR-020: Seed Generator Auto-Creates Fencers for Domestic Tournaments

**Status:** Accepted
**Date:** 2026-04-04 (M9)

## Context

`generate_season_seed.py` generates static SQL data files from Excel workbooks. When a scraped fencer name doesn't match the master fencer list (fuzzy score < threshold), the tool writes an SQL comment and drops the result entirely — regardless of tournament type.

This caused 5 fencers to be missing from the PPW3 2025-26 ranklist:
- **ODOLAK Jarosław** — present in seed but data generated before his entry existed (timing bug; re-run fixes it)
- **LEAHEY John, GERTSMAN Alex, MCQUEEN Andy, GOLD Oleg** — international fencers who participated in a domestic PPW tournament; not in master data, results silently dropped

The live pipeline (`pipeline.py`, M9) already distinguishes domestic vs international: domestic PPW/MPW unmatched fencers are auto-created, international PEW/MEW/MSW unmatched fencers are skipped. The seed generator lacked this same logic, creating an asymmetry between the two intake paths.

## Decision

`generate_season_seed.py` applies the same domestic/international intake rules as the live pipeline:

1. **Domestic (PPW, MPW) unmatched:** Auto-create fencer entry with estimated birth year. Emit `INSERT INTO tbl_fencer ... WHERE NOT EXISTS` at the top of the SQL file, and reference the new fencer by subquery in `tbl_result`.

2. **International (PEW, MEW, PSW, MSW) unmatched:** Skip with a `-- SKIPPED (international, no master data)` comment. No fencer creation, no result insertion.

Reuses `parse_scraped_name()` from `fuzzy_match.py` and `estimate_birth_year()` + `DOMESTIC_TYPES` from `pipeline.py` — no logic duplication.

## Alternatives Considered

1. **Manual seed management only** — require the operator to add missing fencers to `seed_tbl_fencer.sql` before re-running the generator. Brittle, error-prone, doesn't scale as new domestic participants appear each season.

2. **Auto-create in data file without WHERE NOT EXISTS** — risks duplicate fencer rows on re-runs. Rejected in favor of idempotent INSERT pattern.

3. **Unify generate_season_seed.py with pipeline.py** — the two systems serve different purposes (batch Excel import vs live scraper intake) and have different matching thresholds and interfaces. Unification would be a large refactor for marginal benefit.

## Consequences

- Every domestic PPW/MPW participant gets a result in the ranklist, matching live pipeline behavior
- Auto-created fencers have `bool_birth_year_estimated = TRUE` and birth year derived from age category
- The operator should run `sort_and_clean_fencers.py` after generation to absorb auto-created fencers into the canonical seed
- International unmatched fencers are clearly labeled as `-- SKIPPED` rather than the ambiguous `-- UNMATCHED`
- Same fencer appearing in multiple domestic tournaments gets only one `tbl_fencer` INSERT (deduplication by surname + first_name)
