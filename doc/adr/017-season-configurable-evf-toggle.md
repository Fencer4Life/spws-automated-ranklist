# ADR-017: Season-Configurable EVF Toggle

**Status:** Accepted
**Date:** 2026-03-29 (M9)

## Context

The web UI includes PPW/+EVF (Kadra) toggle buttons in three places:

1. **FilterBar** (Ranklist view) — switches between PPW-only and Kadra ranking modes
2. **CalendarView** — scope filter showing PPW-only or all (including international) events
3. **DrilldownModal** — fencer detail toggle between domestic and domestic+international results

International ranking data (PEW, MEW, MSW, PSW tournaments) is not yet populated for any season. Showing the +EVF toggle when there is no international data is confusing for users. However, removing the toggle code entirely would require re-implementing it when international data becomes available.

## Decision

Add a boolean flag `bool_show_evf_toggle` (DEFAULT FALSE) to `tbl_scoring_config`. This flag controls whether the PPW/+EVF toggle is visible in the web UI for the associated season.

## UI Behavior Matrix

### Admin Control

The `show_evf_toggle` flag is managed through the **SeasonManager edit form** (not ScoringConfigEditor):

| Action | Checkbox visible? | Notes |
|--------|-------------------|-------|
| Create new season | No | Flag defaults to FALSE in DB via trigger-created `tbl_scoring_config` row |
| Edit existing season | Yes | Checkbox reflects current DB value; saves via `fn_import_scoring_config` |

**Data flow:** SeasonManager → `onfetchevf(seasonId)` fetches current value → checkbox bound to `draftShowEvf` → on save, `onupdate` passes value to App.svelte → `handleUpdateSeason` calls `saveScoringConfig` with updated flag → `refreshEvfToggle()` updates UI state.

### Toggle Visibility (3 components)

| `show_evf_toggle` | FilterBar | CalendarView | DrilldownModal |
|--------------------|-----------|--------------|----------------|
| `FALSE` (default) | PPW/Kadra toggle **hidden**; mode locked to PPW | Scope filter buttons **hidden** | PPW/Kadra toggle **hidden**; mode locked to PPW |
| `TRUE` | PPW/Kadra toggle **visible**; PPW selected by default | Scope filter buttons **visible**; PPW selected by default | PPW/Kadra toggle **visible**; PPW selected by default |

Implementation: each component receives a `showEvfToggle` boolean prop; toggles wrapped in `{#if showEvfToggle}`.

### Default Mode on State Transitions

PPW is **always** the default mode. The mode resets to PPW on every state transition to prevent stale KADRA/+EVF views:

| Trigger | What happens |
|---------|--------------|
| Page load | `refreshEvfToggle()` → mode forced to PPW |
| Season change | `handleSeasonChange()` → `refreshEvfToggle()` → mode forced to PPW |
| Admin saves scoring config | `handleSaveScoringConfig()` → `refreshEvfToggle()` → mode forced to PPW |
| Admin saves season (with toggle change) | `handleUpdateSeason()` → `refreshEvfToggle()` → mode forced to PPW |
| Toggle disabled while user is on KADRA | `refreshEvfToggle()` → mode forced to PPW (toggle disappears) |
| Toggle enabled while user is on PPW | Toggle appears, PPW remains selected |

Implementation in `App.svelte`:
```typescript
async function refreshEvfToggle() {
  // ... fetch config, set showEvfToggle ...
  if (filters.mode === 'KADRA') {
    filters = { ...filters, mode: 'PPW' }
  }
}
```

### CalendarView Scope Filter Logic

The CalendarView has its own local `scopeFilter` state (`'ppw' | 'all'`), independent of the Ranklist `filters.mode`. Filtering logic:

| `showEvfToggle` | `scopeFilter` | Events shown |
|-----------------|---------------|--------------|
| `FALSE` | (any — buttons hidden) | **PPW-only** — international events (`bool_has_international=true`) filtered out |
| `TRUE` | `'ppw'` (default) | **PPW-only** — international events filtered out |
| `TRUE` | `'all'` (user clicks +EVF) | **All events** — including international |

Implementation:
```typescript
if (!showEvfToggle || scopeFilter === 'ppw') {
  result = result.filter((e) => !e.bool_has_international)
}
```

Key: when the toggle is hidden, the calendar **never** shows international events regardless of internal state. This prevents data leakage when the admin has intentionally disabled the toggle.

### V0 Category Guard

When `showEvfToggle=TRUE` and the user selects the V0 age category (youngest), the +EVF option is disabled in FilterBar and DrilldownModal because V0 has no international events. This guard is independent of the season config flag.

## DB Schema

```sql
ALTER TABLE tbl_scoring_config
  ADD COLUMN bool_show_evf_toggle BOOLEAN NOT NULL DEFAULT FALSE;
```

Exposed via:
- `fn_export_scoring_config(p_id_season)` → `{ ..., "show_evf_toggle": false }`
- `fn_import_scoring_config(p_config)` → reads `show_evf_toggle` key, defaults to FALSE if absent

Migration: `20260329000002_evf_toggle_config.sql`

## Alternatives Considered

1. **Remove toggle code entirely** — Simplifies UI but loses working code. Re-implementation required later. Reduces test coverage surface.
2. **Environment variable / feature flag** — Not per-season granular. A global flag would hide the toggle even for seasons that have international data.
3. **Auto-detect from data** — Show toggle when `bool_has_international = TRUE` exists for any event in the season. Elegant but fragile (depends on data state, not admin intent).
4. **Checkbox in ScoringConfigEditor** — Initially implemented there, but relocated to SeasonManager edit form because the toggle is a season-level visibility concern, not a scoring parameter. Keeps the scoring config editor focused on formula tuning.

## Consequences

- SQL backend (`fn_ranking_kadra`, `vw_ranking_kadra`) remains untouched — no scoring logic changes
- Frontend toggle rendering gated by `{#if showEvfToggle}` — minimal code change, all paths preserved
- Existing toggle tests adapted to pass `showEvfToggle: true` prop — coverage unchanged
- New pgTAP tests (9.37–9.39) verify column existence + export/import round-trip
- New vitest tests (8.79–8.83) verify toggle visibility gating + SeasonManager checkbox behavior
- CalendarView always defaults to PPW scope — international events never leak when toggle is disabled

## Test Coverage

| Test ID | Suite | What it verifies |
|---------|-------|-----------------|
| 9.37 | pgTAP | Column exists, default is FALSE |
| 9.38 | pgTAP | `fn_export_scoring_config` includes `show_evf_toggle` key |
| 9.39 | pgTAP | `fn_import_scoring_config` round-trips `show_evf_toggle=true` |
| 8.79 | vitest | CalendarView: `showEvfToggle=false` → no scope filter buttons |
| 8.80 | vitest | CalendarView: `showEvfToggle=true` → scope filter buttons present |
| 8.81 | vitest | SeasonManager: checkbox in edit form only (not create), unchecked by default |
| 8.82 | vitest | SeasonManager: checkbox checked when `onfetchevf` returns true |
| 8.83 | vitest | SeasonManager: save calls `onupdate` with `showEvf=true` after toggle |
| 6.10 | vitest | FilterBar: toggle hidden when `showEvfToggle=false`, visible when true |
| 6.12 | vitest | DrilldownModal: toggle hidden when `showEvfToggle=false` |
