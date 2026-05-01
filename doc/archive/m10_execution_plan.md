# M10 Rolling Score — Execution Plan

**Created:** 2026-03-29
**Purpose:** Compaction-resilient execution tracker. Read this file after context compaction to resume exactly where work stopped.

## Pre-requisites (COMPLETED)

- [x] Plan approved (`.claude/plans/rosy-bouncing-kitten.md`)
- [x] Mockups written: `doc/mockups/m10_calendar_rolling.html`, `doc/mockups/m10_drilldown_rolling.html`
- [x] ADR-018 written: `doc/adr/018-rolling-score.md`
- [x] Spec RTM updated: FR-65, FR-66 added; FR-15, FR-16 modified; ADR-018 in Appendix C
- [x] Spec §9.4 updated: `p_rolling` parameter documented on all functions
- [x] MVP dev plan updated: M10 milestone section with tasks, tests, deployment notes
- [x] MEMORY.md updated: ADR-018 in registry, MVP status updated

## Task Execution Order

Execute sequentially. Each task follows TDD: write tests → RED → implement → GREEN → refactor.

### R1: ADR-018 + Position Helper Function
- **Status:** COMPLETED
- **Migration file:** `supabase/migrations/YYYYMMDD_fn_event_position.sql`
- **Test file:** `supabase/tests/09_rolling_score.sql` (new file, plan(N) where N grows per task)
- **Tests:** R.1, R.2, R.3 — verify `fn_event_position` extracts correct prefix
- **Implementation:**
  ```sql
  CREATE OR REPLACE FUNCTION fn_event_position(p_code TEXT) RETURNS TEXT
  LANGUAGE sql IMMUTABLE AS $$ SELECT split_part(p_code, '-', 1) $$;
  ```
- **After:** `supabase test db` — 3 new assertions pass

### R2: Modify fn_ranking_ppw — Add p_rolling Parameter
- **Status:** COMPLETED
- **Critical source:** `supabase/migrations/20250306000002_exclude_zero_domestic.sql` lines 14-210 (current fn_ranking_ppw)
- **Migration file:** `supabase/migrations/YYYYMMDD_ranking_ppw_rolling.sql`
- **Must DROP + recreate** (return type changes: adds `bool_has_carryover`)
- **Test file:** `supabase/tests/09_rolling_score.sql` (append to same file)
- **Tests:** R.4-R.12 (9 assertions)
  - R.4: `p_rolling=FALSE` regression — identical to pre-change results
  - R.5: `p_rolling=TRUE`, no previous season → same as non-rolling
  - R.6: `p_rolling=TRUE`, all current completed → no carry-over
  - R.7: `p_rolling=TRUE`, partial → current + carried-over in eligible pool
  - R.8: `p_rolling=TRUE`, best-K operates on merged pool
  - R.9: `p_rolling=TRUE`, category crossing V2→V3
  - R.10: `p_rolling=TRUE`, new fencer → zero carryover
  - R.11: `p_rolling=TRUE`, no counterpart (PP5 not declared) → not carried
  - R.12: `p_rolling=TRUE`, event deleted → carry-over drops
- **Key logic changes (JSONB path only):**
  1. Resolve `v_prev_season_id` (previous season by `dt_end < current.dt_start`)
  2. `declared_positions` CTE: `SELECT DISTINCT fn_event_position(txt_code) FROM tbl_event WHERE id_season = current`
  3. `completed_positions` CTE: subset where status = 'COMPLETED'
  4. `eligible` CTE: UNION ALL of current results + previous results WHERE position IN declared AND NOT IN completed
  5. Category crossing: `fn_age_category(birth_year, current_season_end_year)` for carried-over rows
  6. `bool_has_carryover`: TRUE if fencer has any carried-over score in their total
- **Depends on:** R1 (fn_event_position must exist), R5 (seed data for testing)
- **After:** `supabase test db` — R.1-R.12 pass (12 assertions)

### R3: Modify fn_ranking_kadra — Same Treatment
- **Status:** COMPLETED
- **Critical source:** `supabase/migrations/20250306000002_exclude_zero_domestic.sql` lines 225-463 (current fn_ranking_kadra)
- **Migration file:** same as R2 or separate
- **Tests:** R.13 (rolling domestic + international carry-over), R.14 (regression)
- **Same pattern as R2** but handles both domestic AND international positions (PEW, MEW, MSW)
- **After:** `supabase test db` — R.1-R.14 pass (14 assertions)

### R4: fn_fencer_scores_rolling — Drilldown Data
- **Status:** COMPLETED
- **Migration file:** `supabase/migrations/YYYYMMDD_fencer_scores_rolling.sql`
- **Tests:** R.15-R.18 (4 assertions)
  - R.15: `bool_carried_over=TRUE` for previous-season rows
  - R.16: `bool_carried_over=FALSE` for current rows
  - R.17: Position match — current replaces previous
  - R.18: No counterpart → previous excluded
- **Returns:** All `vw_score` columns + `bool_carried_over BOOLEAN` + `txt_source_season_code TEXT`
- **Same declared/completed logic as R2**
- **After:** `supabase test db` — R.1-R.18 pass (18 assertions)

### R5: Seed Data Augmentation
- **Status:** COMPLETED
- **NOTE:** Must be done BEFORE R2 tests can work (tests need PP4+PP5 data)
- **Files to modify:**
  - `supabase/data/2024_25/v2_m_epee.sql` — add PP4 + PP5 events (COMPLETED) with results
  - Create `supabase/data/2025_26/` directory if needed — add PP4 (PLANNED) + PP5 (PLANNED) events
- **Verify:** `supabase db reset` loads without error
- **Key seed requirements:**
  - PP4-2024-2025, PP5-2024-2025: COMPLETED events with tournament results for V2 M EPEE fencers
  - PP4-2025-2026, PP5-2025-2026: PLANNED/SCHEDULED events (no tournaments, no results — just declared)
  - Optional: scenario where PP5 is NOT declared in active season (test R.11)

### R6: Frontend — Types + API
- **Status:** COMPLETED
- **Files:**
  - `frontend/src/lib/types.ts`: Add `bool_carried_over?: boolean`, `txt_source_season_code?: string` to `ScoreRow`; add `bool_has_carryover?: boolean` to `RankingPpwRow` and `RankingKadraRow`
  - `frontend/src/lib/api.ts`: `fetchRankingPpw`/`fetchRankingKadra` pass `p_rolling: true` when season is active; add `fetchFencerScoresRolling()` function
  - `frontend/src/App.svelte`: Use rolling API calls when `season.bool_active === true`
- **No tests for this task** (wiring only — tested via R7/R8)

### R7: DrilldownModal — Visual Distinction
- **Status:** COMPLETED
- **File:** `frontend/src/components/DrilldownModal.svelte` (743 lines)
- **Mockup reference:** `doc/mockups/m10_drilldown_rolling.html`
- **Tests:** R.19-R.22 (4 vitest assertions in `frontend/tests/DrilldownModal.test.ts`)
  - R.19: `.carried-row` class on carried-over table rows
  - R.20: `↩` marker on carried-over chart items
  - R.21: `.rolling-info` banner visible when any `bool_carried_over=true`
  - R.22: Non-carried scores render normally (regression)
- **Visual changes:**
  - Chart bars: `.chart-bar.domestic-carried` / `.chart-bar.international-carried` with striped pattern
  - `↩` marker alongside `★`/`✓`
  - `.carried-row` grey text on table rows
  - `.carried-badge` showing source season code
  - `.rolling-info` amber banner at top of modal body
  - Legend extended with carried-over swatch
- **CRITICAL:** Do NOT modify or remove existing UI elements. Only ADD rolling-specific elements.

### R8: CalendarView — Rolling Progress Indicator
- **Status:** COMPLETED
- **File:** `frontend/src/components/CalendarView.svelte` (343 lines)
- **Mockup reference:** `doc/mockups/m10_calendar_rolling.html`
- **Tests:** R.23-R.25 (3 vitest assertions in `frontend/tests/CalendarView.test.ts`)
  - R.23: `.rolling-progress` with `.slot` elements for active season
  - R.24: No `.rolling-progress` for non-active season
  - R.25: Correct slot states (`.slot.completed`, `.slot.carried`, `.slot.missing`)
- **Visual changes:**
  - Progress slot bar between filter controls and timeline (only for active season)
  - Slots: green ✓ = completed, amber ↩ = carried from previous, grey — = empty
  - Summary text: "3/5 PPW bieżących · 2 przeniesione z 2024-2025"
- **Needs:** Previous season events data (passed as prop or fetched)
- **CRITICAL:** Do NOT modify or remove existing UI elements. Only ADD progress indicator.

### R9: i18n + Documentation
- **Status:** COMPLETED
- **Files:**
  - `frontend/src/lib/locales/pl.json` — add keys: `rolling_carried_over`, `rolling_progress`, `rolling_from_season`, `rolling_banner_text`
  - `frontend/src/lib/locales/en.json` — same keys in English
  - `doc/archive/MVP_development_plan.md` — mark M10 as COMPLETED, add implementation notes + final test counts
  - `doc/Project Specification. SPWS Automated Ranklist System.md` — update FR-65/FR-66 status from Planned → Covered
- **After:** Run all 3 test suites to confirm final green state

## Verification Checklist (run after all tasks)

```bash
# 1. DB reset with augmented seed data
supabase db reset

# 2. pgTAP — expect 189 total (171 + 18 new)
supabase test db

# 3. pytest — expect 104 (unchanged)
source .venv/bin/activate && python -m pytest python/tests/ -v

# 4. vitest — expect 166 total (159 + 7 new)
cd frontend && npm test

# 5. Manual: open web UI, select active season
#    - Ranking table shows carried-over totals
#    - Click fencer → drilldown shows grey/striped bars + ↩ markers
#    - Calendar shows rolling progress indicator
```

## Critical Files Reference

| File | What to read | Why |
|------|-------------|-----|
| `supabase/migrations/20250306000002_exclude_zero_domestic.sql` L14-210 | Current `fn_ranking_ppw` | Base for R2 modification |
| `supabase/migrations/20250306000002_exclude_zero_domestic.sql` L225-463 | Current `fn_ranking_kadra` | Base for R3 modification |
| `frontend/src/components/DrilldownModal.svelte` | Current drilldown UI (743 lines) | Base for R7 |
| `frontend/src/components/CalendarView.svelte` | Current calendar UI (343 lines) | Base for R8 |
| `frontend/src/lib/api.ts` | API functions | Base for R6 |
| `frontend/src/lib/types.ts` | TypeScript interfaces | Base for R6 |
| `doc/mockups/m10_drilldown_rolling.html` | Approved drilldown mockup | Visual reference for R7 |
| `doc/mockups/m10_calendar_rolling.html` | Approved calendar mockup | Visual reference for R8 |
| `doc/adr/018-rolling-score.md` | Full ADR with test table | Design reference |
| `supabase/data/2024_25/v2_m_epee.sql` | Current seed data | Base for R5 |

## Resumption Instructions

After context compaction, read this file + the plan at `.claude/plans/rosy-bouncing-kitten.md`. Check which tasks above are marked as completed (the status field will be updated as work progresses). Start from the first NOT STARTED task. Follow TDD strictly: tests first, RED, implement, GREEN.
