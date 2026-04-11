# ADR-031: Auto-Active Season by Date

**Status:** Accepted
**Date:** 2026-04-11

## Context

`bool_active` on `tbl_season` was manually set — hardcoded in seed data or toggled by admin. This caused two problems:

1. **Empty ranklist for new seasons:** Creating a future season via admin UI left `bool_active = FALSE`. Without it, rolling carry-over (ADR-018) never activated because the frontend only passes `p_rolling=TRUE` for the active season.
2. **Admin overhead:** Season transitions required remembering to flip the flag — once a year, easy to forget.

Additionally, nothing prevented overlapping season date ranges, which could make the "active season" ambiguous.

## Decision

**Auto-derive `bool_active` from season dates** using a trigger + refresh-on-load pattern:

### Activation Rules

1. **Primary:** Season where `dt_start <= TODAY <= dt_end`
2. **Fallback:** Nearest future season (smallest `dt_start` where `dt_start > TODAY`)
3. **None:** If all seasons are in the past, no season is active

### Implementation

- **`fn_refresh_active_season()`** — applies the rules above, updates `bool_active` column
- **Trigger `trg_season_refresh_active`** — fires `AFTER INSERT OR UPDATE OF dt_start, dt_end OR DELETE` on `tbl_season` (statement-level, avoids recursion since it doesn't fire on `bool_active` changes)
- **Frontend refresh** — `init()` calls `fn_refresh_active_season()` on app load to handle the time-passing case (midnight boundary)
- **Exclusion constraint `excl_season_date_overlap`** — prevents overlapping date ranges using `btree_gist` extension + `daterange` exclusion

### `bool_active` column retained

The column remains as a cached, trigger-managed value. All 19 existing references (`WHERE bool_active = TRUE`) continue to work unchanged. No function signatures modified.

## Alternatives Considered

1. **Manual toggle via admin UI** — full control but relies on human memory once a year. Risk of forgotten transitions.
2. **Computed view/function (no stored column)** — always correct but requires updating 19 function references. High migration effort.
3. **Hybrid (date-derived + manual override)** — most flexible but most complex. Unnecessary given the auto-rules cover all practical cases.

## Consequences

- **Zero admin overhead** for season transitions — create the season with correct dates, activation is automatic
- **Rolling carry-over (ADR-018)** activates automatically for new seasons via the fallback rule
- **Overlapping dates rejected** at DB level — self-correcting: admin edits dates, trigger recalculates
- **Summer gap handled:** Between seasons, the fallback activates the nearest future season
- **Punktacja (scoring config)** moved from separate menu item into season row — gear button opens ScoringConfigEditor inline, making the season-config relationship explicit
- **No impact on Telegram/ingestion** — they resolve active season via `WHERE bool_active = TRUE` which is now auto-managed
- **Future seasons show empty ranklist** — rolling carry-over only kicks in when the season actually becomes active. A future season that is not yet active intentionally shows an empty ranklist; this is by design, not a bug
- **CERT/PROD safe** — migration runs on existing databases without reset (non-overlapping seed dates guaranteed)

## Related ADRs

- **ADR-018** (Rolling Score) — "active season" is now auto-derived; rolling carry-over activates automatically for fallback-active seasons
- **ADR-025** (Event-Centric Ingestion) — Telegram commands scope to active season, now auto-managed
- **ADR-027** (Full-Season Seed Export) — seed export scope unchanged, season derived from event's `id_season`
