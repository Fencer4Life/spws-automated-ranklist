# ADR-018: Rolling Score for Active Season

**Status:** Accepted
**Date:** 2026-03-29 (M10)

## Context

At the start of each active season the ranking is empty — no events have been completed yet. Stakeholders want **ranking continuity**: the previous season's results serve as a starting baseline that is progressively replaced as current-season events complete. By season end, all results are current and rolling has no effect.

The rolling mechanism must:

1. Be **position-matched** — PP1-current replaces PP1-previous (not arbitrary substitution)
2. Require a **declared counterpart** — previous-season results only carry over if the active season has a declared event at the same position (any status except COMPLETED)
3. Support **category crossing** — a fencer aging V2→V3 gets previous V2 results placed into the V3 ranking
4. Preserve **Best-K selection** — bucket rules operate on the merged pool (current + carried-over)
5. Use carried-over `num_final_score` as-is (multiplier already baked in at scoring time)
6. Only affect the **active season** — past seasons are never modified

**Verified with real data (2026-03-30):** V1 M Epee seed data added for 2024-25 season (14 tournaments, 97 matched results from `SZPADA-1-2024-2025.xlsx`). Korona (born 1976) was V1 in 2024-25 and aged to V2 in 2025-26. Rolling carry-over correctly includes PP4-V1 (12.08 pts), MPW-V1 (32.53 pts), and IMEW-V1 (119.38 pts) in the V2 ranking — confirmed by pgTAP test R.13 (kadra total 535.93).

### Three-State Position Logic

| Active-season event at position N | Previous-season result at position N | Effect |
|---|---|---|
| Does not exist (not declared) | Exists | **Dropped** — not in ranking |
| Exists, NOT yet completed | Exists | **Carried over** — previous result used |
| Exists, COMPLETED | Exists | **Replaced** — current result used |
| Exists, NOT completed | Does not exist | **Empty slot** — nothing to carry |

### Position Extraction

Event position is the tournament-type prefix extracted from `txt_code`: `split_part(txt_code, '-', 1)`.

Examples: `PP1-2024-2025` → `PP1`, `MPW-2024-2025` → `MPW`, `PEW1-2025-2026` → `PEW1`.

## Decision

**Option C: Parameter Extension** — add `p_rolling BOOLEAN DEFAULT FALSE` to existing `fn_ranking_ppw` and `fn_ranking_kadra`. When TRUE, the `eligible` CTE expands to include previous-season carry-over results. Return type extended with `bool_has_carryover BOOLEAN`.

### Implementation Mechanics

1. **Position helper:** New `fn_event_position(txt_code TEXT) RETURNS TEXT` extracts the position prefix
2. **Previous season resolution:** `SELECT id_season FROM tbl_season WHERE dt_end < current.dt_start ORDER BY dt_end DESC LIMIT 1`
3. **Declared positions CTE:** `SELECT DISTINCT fn_event_position(e.txt_code) FROM tbl_event WHERE id_season = active_season`
4. **Completed positions CTE:** Subset of declared where at least one event at that position has status `COMPLETED`
5. **Eligible CTE expansion:** UNION ALL of:
   - Current-season results (unchanged)
   - Previous-season results WHERE position IN declared AND position NOT IN completed
6. **Category crossing:** Carried-over results evaluated with `fn_age_category(birth_year, current_season_end_year)` — NOT previous season's end year
7. **`bool_has_carryover`:** TRUE in final SELECT if any carried-over scores contributed to the fencer's total

### New Drilldown Function

`fn_fencer_scores_rolling(p_fencer, p_weapon, p_gender, p_category, p_season)` returns `ScoreRow` columns plus:
- `bool_carried_over BOOLEAN` — TRUE for previous-season rows
- `txt_source_season_code TEXT` — source season code for carried-over rows

Same declared/completed position logic as the ranking functions.

## Alternatives Considered

1. **Option A: Modify existing functions in-place (rolling always on for active season)**
   - Effort: HIGH (3-4 days). Risk: MEDIUM-HIGH.
   - Rolling always on — no toggle. Changes return type for all callers. Hard to regression-test since behavior changes implicitly.

2. **Option B: New wrapper functions (`fn_ranking_ppw_rolling`)**
   - Effort: MEDIUM-HIGH (2-3 days). Risk: MEDIUM.
   - Existing functions untouched but **duplicates bucket selection logic** — divergence risk over time. Frontend must know which function to call.

3. **Option C: Parameter extension (`p_rolling BOOLEAN DEFAULT FALSE`)** — CHOSEN
   - Effort: MEDIUM (2-3 days). Risk: MEDIUM.
   - Single function per ranking type. Backward compatible. Clean API. Testable for both modes.

4. **Option D: Frontend-only merge (fetch both seasons client-side)**
   - Effort: LOW (1 day). Risk: **VERY HIGH**.
   - **FATAL:** Ranking totals would be wrong — `fn_ranking_ppw` still sees only current season, so ranking table shows different totals than drilldown. Must recompute Best-K in JS (logic duplication). Category crossing broken. 2x API calls.

### Why Option C

- **Correctness** — ranking totals MUST include carried-over scores (eliminates D)
- **No duplication** — single function per ranking type (eliminates B)
- **Backward compatibility** — `p_rolling=FALSE` default preserves all existing behavior (better than A)
- **Legacy path unchanged** — active season always has JSONB rules, so only the JSONB path needs rolling logic
- **Testable** — call with `p_rolling := TRUE/FALSE` to verify both behaviors independently

## Visual Distinction

Carried-over scores are visually distinguished from current-season results:

- **Chart bars:** Grey striped pattern (not solid blue/gold)
- **Marker:** `↩` for carried-over items (alongside existing `★` / `✓`)
- **Tournament table:** Carried-over rows in grey text with badge showing source season
- **Rolling info banner:** Amber banner at top of drilldown when carried-over scores present
- **Calendar progress:** Slot bar above timeline for active season — green ✓ = completed, amber ↩ = carried, grey — = empty

Mockups: `doc/mockups/m10_drilldown_rolling.html`, `doc/mockups/m10_calendar_rolling.html`

## DB Schema

No new columns on existing tables. Changes:

```sql
-- New helper function
CREATE FUNCTION fn_event_position(p_code TEXT) RETURNS TEXT
  AS $$ SELECT split_part(p_code, '-', 1) $$;

-- Modified function signatures (DROP + recreate)
fn_ranking_ppw(p_weapon, p_gender, p_category, p_season, p_rolling BOOLEAN DEFAULT FALSE)
  RETURNS TABLE(rank, id_fencer, fencer_name, ppw_score, mpw_score, total_score, bool_has_carryover)

fn_ranking_kadra(p_weapon, p_gender, p_category, p_season, p_rolling BOOLEAN DEFAULT FALSE)
  RETURNS TABLE(rank, id_fencer, fencer_name, ppw_total, pew_total, total_score, bool_has_carryover)

-- New function
fn_fencer_scores_rolling(p_fencer, p_weapon, p_gender, p_category, p_season)
  RETURNS TABLE(... ScoreRow columns ..., bool_carried_over, txt_source_season_code)
```

## Consequences

- `fn_ranking_ppw` and `fn_ranking_kadra` must be DROPped and recreated (return type change) — migration discipline required
- All existing callers unchanged (`p_rolling` defaults to FALSE)
- Frontend passes `p_rolling: true` when season is active — API layer change
- New frontend types: `bool_carried_over` on `ScoreRow`, `bool_has_carryover` on ranking rows
- DrilldownModal gains carried-over visual styling (grey striped bars, `↩` markers, info banner)
- CalendarView gains rolling progress indicator (slot bar for active season)
- Seed data augmented: PP4+PP5 events added to previous season, declared (not completed) in active season
- ~18 pgTAP + ~7 vitest new test assertions

## Test Coverage

| Test ID | Suite | What it verifies |
|---------|-------|-----------------|
| R.1 | pgTAP | `fn_event_position('PP1-2024-2025')` → `'PP1'` |
| R.2 | pgTAP | `fn_event_position('MPW-2024-2025')` → `'MPW'` |
| R.3 | pgTAP | `fn_event_position('PEW1-2025-2026')` → `'PEW1'` |
| R.4 | pgTAP | `fn_ranking_ppw(rolling:=FALSE)` regression — same results as before |
| R.5 | pgTAP | `fn_ranking_ppw(rolling:=TRUE)` no previous season → same as non-rolling |
| R.6 | pgTAP | `fn_ranking_ppw(rolling:=TRUE)` all current events completed → no carry-over |
| R.7 | pgTAP | `fn_ranking_ppw(rolling:=TRUE)` partial: current + carried-over in pool |
| R.8 | pgTAP | `fn_ranking_ppw(rolling:=TRUE)` best-K selection on merged pool |
| R.9 | pgTAP | `fn_ranking_ppw(rolling:=TRUE)` category crossing: V2→V3 |
| R.10 | pgTAP | `fn_ranking_ppw(rolling:=TRUE)` new fencer (not in prev season) → zero carryover |
| R.11 | pgTAP | `fn_ranking_ppw(rolling:=TRUE)` no counterpart: prev PP5 not carried when PP5 not declared |
| R.12 | pgTAP | `fn_ranking_ppw(rolling:=TRUE)` event deleted → carry-over for that position drops |
| R.13 | pgTAP | `fn_ranking_kadra(rolling:=TRUE)` domestic + international carry-over |
| R.14 | pgTAP | `fn_ranking_kadra(rolling:=FALSE)` regression |
| R.15 | pgTAP | `fn_fencer_scores_rolling` returns `bool_carried_over=TRUE` for prev-season rows |
| R.16 | pgTAP | `fn_fencer_scores_rolling` returns `bool_carried_over=FALSE` for current rows |
| R.17 | pgTAP | `fn_fencer_scores_rolling` position match: current replaces previous |
| R.18 | pgTAP | `fn_fencer_scores_rolling` no counterpart: prev PP5 excluded when not declared |
| R.19 | vitest | DrilldownModal: carried-over rows have `.carried-row` class |
| R.20 | vitest | DrilldownModal: chart items for carried-over have `↩` marker |
| R.21 | vitest | DrilldownModal: rolling info banner shows when carried-over present |
| R.22 | vitest | DrilldownModal: non-carried scores render normally (regression) |
| R.23 | vitest | CalendarView: progress slots render for active season |
| R.24 | vitest | CalendarView: progress hidden for non-active season |
| R.25 | vitest | CalendarView: correct slot states (completed/carried/missing) |
