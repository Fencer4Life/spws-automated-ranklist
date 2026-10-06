# ADR-031: Auto-Active Season by Date

**Status:** Accepted. **Amended 2026-10-06:** the active season is computed on read — this ADR's own alternative 2 is adopted. The stored `tbl_season.bool_active` column, the trigger `trg_season_refresh_active` and `fn_refresh_active_season()` are removed; the activation rules are unchanged.
**Date:** 2026-04-11
**Amends:** [ADR-083](083-server-enforced-authorization.md) §4 (three read-only functions join the anon allowlist; amended 2026-10-06)
**Source:** `supabase/migrations/20261006000001_active_season_computed.sql`, `supabase/tests/106_active_season_computed.sql`, `doc/plans/active-season-computed-on-read-2026-10-06.html` (decision), `doc/plans/active-season-401-2026-10-06.html` (the incident)

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

## Amendment (2026-10-06) — the active season is computed on read

### Context

The design above kept a stored flag and refreshed it from two places: the trigger, on any change to a season row, and the browser, on every page load, to catch a date that passes with nothing written. ADR-083 removed the second on 23 July 2026: `fn_refresh_active_season()` is a `SECURITY DEFINER` write that moves the whole system's active season, so anonymous `EXECUTE` was revoked (`20260723000001_adr083_deny_by_default_grants.sql:186`). `App.svelte` kept calling it in `init()` and discarded the failure, so every public page load since then logged a `401` in the browser console. This was observed on PROD, CERT and LOCAL on 6 October 2026. The refresh itself had stopped: nothing moved the flag when a season's first day arrived unless someone wrote a season row. On 16 July 2027 the flag would have stayed on the finished season on both environments.

The flag is a function of the season dates and today. Today changes without a write, so a stored copy always needs a writer at midnight. That writer was the cause of the incident, the revoked grant and the stale-flag risk.

### Decision

1. **`fn_today()`** (`STABLE`) returns the session setting `spws.today` when it is set, and `CURRENT_DATE` otherwise. It is the only clock the rules read.
2. **`fn_active_season_id()`** (`STABLE`) applies the activation rules above, unchanged: the season whose dates contain today, else the nearest future season, else none (`NULL`).
3. **`bool_active(tbl_season)`** is a computed field: it is true for the row whose id is `fn_active_season_id()`. With no stored column, PostgreSQL reads `s.bool_active` as the call `bool_active(s)` (attribute notation), and PostgREST exposes the function as a computed field. So `select=…,bool_active` and the filter `bool_active=eq.true` keep working unchanged for the frontend. An unqualified `bool_active` no longer resolves, so every reader names the table alias: `FROM tbl_season s WHERE s.bool_active`.
4. **Removed:** the column, the trigger `trg_season_refresh_active`, `fn_trg_refresh_active_season()`, `fn_refresh_active_season()` and the browser's `refreshActiveSeason()`. Nothing writes the active season any more.
5. **Grants:** the three functions are read-only and anon-callable, added to the ADR-083 §4 allowlist (pgTAP 52.7 and `scripts/check-security-posture.sh`).
6. **Tests choose today.** A fixture makes a season active by setting today, not the flag: `PERFORM set_config('spws.today', '<a date inside the season>', false)`. Fixtures do not depend on the calendar year.

### Why alternative 2 is now cheap

Alternative 2 was rejected because it "requires updating 19 function references". Attribute notation removes most of that cost: 16 functions already read `s.bool_active` and resolve to the computed field unchanged. The migration rewrites six bodies, taken from the live definitions:

- `_resolve_event_prefix`, `fn_category_ranking`, `fn_season_overview` and `fn_season_summary` read `fn_active_season_id()`.
- `fn_delete_season_skeleton` qualifies its read.
- `fn_create_season` stops writing the column.

Five Python queries are qualified. The seed's four `tbl_season` INSERTs lose the column. The exporter needs no change, because it discovers columns from `information_schema.columns`.

`bool_active` remains a column of `tbl_scoring_config_revision` and `tbl_scoring_engine`. Those are different tables, and they are untouched.

### Alternatives considered (2026-10-06)

1. **Re-grant anon `EXECUTE` on the refresh.** Rejected. It reverses an ADR-083 finding that names this function, and every public page view would again write two `tbl_season` updates and two audit rows.
2. **Call the refresh only for a signed-in admin.** Rejected. A roll-over would wait for an admin to sign in on each environment, and a sign-in on only one makes CERT and PROD disagree, which `promote_calendar` refuses.
3. **Drop the browser call and refresh daily on the server** (option D of the 401 note). Rejected in favour of this amendment. It fixes the incident but keeps a stored copy and a scheduled writer to forget, and the roll-over lands hours after midnight.
4. **Serve anon the computed value but keep the stored flag** for the server (option R). Rejected. It creates two copies of the truth, which disagree for hours once a year.

### Consequences

- The active season is right at every minute on every environment, with no job, no visitor and no admin action. ADR-031's "zero admin overhead" holds again.
- Anonymous visitors only read. No public call writes `tbl_season`, and the `401` is gone. A call to the removed RPC returns `404 PGRST202`.
- CERT and PROD agree whenever their season dates agree. `promote_calendar`'s active-season check compares the computed values.
- "Today" is the database's date (UTC), as before.
- `bool_active(s)` evaluates `fn_active_season_id()` for each row it reads. `tbl_season` holds one row per season, so the cost is negligible. A filter on it cannot use an index, which does not matter at this size.
- **Deploy order is safe both ways.** The new page against the old database still finds the stored column. The old page against the new database reads the computed value; its leftover refresh call fails (`404` instead of `401`) and is discarded, as before. The qualified Python queries read the stored column and the computed field alike.

### Verification

- pgTAP `106_active_season_computed.sql`:
  - 106.1: the column is gone.
  - 106.2–106.3: `fn_today()` with and without the setting.
  - 106.4–106.7: the three rules, and the computed field marking one season.
  - 106.8: no audit rows.
  - 106.9–106.10: the refresh function and the trigger are gone.
  - 106.11: anon may execute the three functions.
  - 106.12–106.13: `fn_season_summary()` follows today, and raises when no season is active.
- pgTAP 9.41–9.46, rewritten to read the computed field and to set today.
- Vitest AS.UI.01: the app never calls the removed RPC.
- pytest AS.PY.01: no Python query names the flag without a table alias.
