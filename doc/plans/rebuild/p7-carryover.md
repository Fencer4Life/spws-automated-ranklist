# Phase 7 — Carry-over completion (post-rebuild) (M)

**Prerequisites:** Phase 6 ([p6-finalize.md](p6-finalize.md)) — rebuild complete, LOCAL/CERT/PROD all promoted.

## Goal

Complete the carry-over migration deferred from Phase 1A/1B/3a. Activate the FK engine. Enforce the 366-day cap (ADR-054). Ship the admin UI for engine selection.

## Context

Per [memory: project_phase3_status.md](/Users/aleks/.claude/projects/-Users-aleks-coding-SPWSranklist/memory/project_phase3_status.md):

- Phase 1A+1B carry-over engine deployed CERT 2026-04-26.
- FK engine ready, every season still defaults to legacy `EVENT_CODE_MATCHING`.
- Phase 3a backend (6 RPCs + default-flip) pushed to main 2026-04-26.
- Phase 3b/3c admin UI is what's pending.

The rebuild left LOCAL with **clean** data, so `tbl_event.id_prior_event` backfill can proceed without the noise of the old splitter bugs.

## Deliverables

### Backfill

- Backfill `tbl_event.id_prior_event` against the clean rebuilt data (run carry-over admin runbook SQL — see [memory: project_carryover_admin_runbook.md](/Users/aleks/.claude/projects/-Users-aleks-coding-SPWSranklist/memory/project_carryover_admin_runbook.md)).

### Engine activation

- Activate `EVENT_FK_MATCHING` engine on a **per-season basis** (admin choice).

### 366-day cap enforcement (ADR-054)

- Enforce 366-day cap in scoring functions.
- `tbl_season.int_carryover_days` (default 366) becomes load-bearing.

### Admin UI

- Phase 3b/3c admin UI work to expose engine selection.
- Builds on the existing carry-over engine RPCs already shipped to main 2026-04-26.

## Risk gate

- All scoring tests pass with the FK engine active.
- 366-day cap returns expected results in pgTAP coverage.
- Admin can flip the engine per-season via UI without touching SQL.
- `fn_compare_carryover_engines` shows expected divergence between legacy and FK on selected seasons (proves engines are in fact different and FK is doing what's intended).

## Cross-references

- Master plan: [now-we-have-a-precious-wren.md](/Users/aleks/.claude/plans/now-we-have-a-precious-wren.md)
- Predecessor: [p6-finalize.md](p6-finalize.md)
- Implements rules: R007 (366-day cap), R008 (carry-over FK linkage)
- ADR-054 finalized in this phase (stub was committed in Phase 0)
- Existing carry-over project memory (continues to apply): `project_carryover_phase1_status.md`, `project_phase3_status.md`, `project_carryover_admin_runbook.md`, `project_carryover_phase23_roadmap.md`
