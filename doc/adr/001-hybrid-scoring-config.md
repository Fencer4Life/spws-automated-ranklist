# ADR-001: Hybrid Scoring Configuration (Table + JSON Export/Import)

**Status:** Accepted
**Date:** 2025-03-01 (M2)

## Context

The scoring engine needs configurable parameters (MP value, multipliers, podium bonuses, best-K counts, etc.) that the admin can tune during calibration. The question was where to store these parameters: purely in the database, or in a JSON config file.

## Decision

Use a **hybrid** approach: production truth lives in `tbl_scoring_config` (typed columns, FK to season, RLS-protected, ts_updated tracking), while local editing is enabled via `fn_export_scoring_config` / `fn_import_scoring_config` SQL functions that convert the row to/from JSON.

## Alternatives Considered

**Pure JSON file:**
- Not queryable by SQL — the scoring engine can't `SELECT` it
- Two sources of truth (file + DB) inevitably drift
- The deployed app can't read a local file
- No schema validation unless custom-built

**Pure database table (edit via Supabase UI only):**
- Supabase Table Editor is clunky for rapid iteration during calibration
- Every tweak requires a browser round-trip
- No local diff/history in editor

## Consequences

- Calibration workflow is fast: export → edit in VS Code → import → re-score → compare
- Python helpers (`calibrate_config.py`, `calibrate_compare.py`) wrap the RPC calls
- Exported JSON is diffable and committable to Git
- The single source of truth is always the database — JSON files are ephemeral working copies
