# ADR-037: Derived Display Status — "Awaiting Results"

**Status:** Implemented
**Date:** 2026-04-20
**Related:** ADR-018 (Rolling Score for Active Season), ADR-025 (Event-Centric Ingestion), ADR-028 (EVF Calendar + Results Import)

## Context

`tbl_event.enum_status` has six values — `PLANNED`, `SCHEDULED`, `CHANGED`, `IN_PROGRESS`, `COMPLETED`, `CANCELLED` — and the transition `PLANNED → IN_PROGRESS` is driven by *results ingestion*, not by calendar date. The transition fires automatically inside `fn_ingest_tournament_results` the moment the first tournament result arrives.

This leaves a visible gap: EVF events whose `dt_end` has already passed but whose results haven't been ingested yet (normal for EVF circuit — results lag by ~2 days per ADR-028) show as `PLANNED` in the Calendar UI, which misleads users into thinking the event is still upcoming.

An obvious fix — auto-flipping `PLANNED → IN_PROGRESS` at `dt_start < today` — would break ADR-018. The rolling carry-over query explicitly drops the previous-season score when the current-season equivalent becomes `IN_PROGRESS` ([migration 20260406000006](../../supabase/migrations/20260406000006_fix_carryover_in_progress.sql)). The invariant is: *a new event replaces the old carry-over only when the new event has actual data*. An `IN_PROGRESS` event with no results would silently wipe the prior-season score and leave the ranklist slot empty.

## Decision

Do not couple `enum_status` to the calendar. Instead, introduce a **view-layer derived display status** computed at render time.

- New helper [frontend/src/lib/eventStatus.ts](../../frontend/src/lib/eventStatus.ts) exposes `getEventDisplayStatus(status, dt_end, dt_start?, today?)` → `{ cssClass, labelKey }`.
- PLANNED + `dt_end < today` (fallback `dt_start` when `dt_end` is null) → **`status_awaiting_results`** with `.status-awaiting` (amber `#fef3c7` bg / `#92400e` text). All other rows pass through unchanged.
- Two i18n keys added (EN / PL): `status_awaiting_results` ("Awaiting results" / "Oczekiwanie na wyniki"), `status_changed` ("Changed" / "Zmienione").
- Consumers: [CalendarView.svelte](../../frontend/src/components/CalendarView.svelte) and [EventManager.svelte](../../frontend/src/components/EventManager.svelte) — both replaced their local `statusClass` / `statusLabel` functions with a single shared helper call.
- The comparison uses ISO-string comparison against `new Date().toISOString().slice(0, 10)` — all DB `dt_*` columns are `DATE` (no time component), no timezone handling needed.

**Truth table:**

| `enum_status` | `dt_end` vs today | `labelKey` | `cssClass` |
|---|---|---|---|
| `PLANNED` | future / unknown | `status_planned` | `status-planned` |
| `PLANNED` | **past** | **`status_awaiting_results`** | **`status-awaiting`** |
| `SCHEDULED` | any | `status_scheduled` | `status-scheduled` |
| `CHANGED` | any | `status_changed` | `status-changed` |
| `IN_PROGRESS` | any | `status_in_progress` | `status-inprogress` |
| `COMPLETED` | any | `status_completed` | `status-completed` |
| `CANCELLED` | any | `status_cancelled` | `status-cancelled` |

## Alternatives Considered

1. **Auto-transition `PLANNED → IN_PROGRESS` at `dt_start < today` via cron or DB trigger.** Rejected — breaks ADR-018 rolling carry-over invariant. Past-date events without results would wipe prior-season scores from the ranklist.
2. **New enum value `AWAITING_RESULTS`.** Rejected — schema change, new transitions to define in `fn_validate_event_transition`, new columns exposed in views, no functional benefit over the pure-view solution.
3. **Auto-transition with grace period (e.g. `dt_end + 14 days`).** Rejected as overkill for today's need — requires nightly job, new column, new ADR on "when to give up waiting". Could be revisited if we ever want the ranklist to proactively discard stale carry-over.
4. **Do nothing.** Rejected — "Planowany" on an elapsed event is misleading to end users, and fixing it at the view layer costs nothing.

## Consequences

- **Zero DB / enum / trigger / scoring impact.** `enum_status` values, transitions, `fn_validate_event_transition`, `fn_ingest_tournament_results`, `fn_complete_event`, `fn_rollback_event`, and `vw_calendar` are all untouched. ADR-018 rolling carry-over invariant holds.
- **Self-healing.** When results are ingested, `fn_ingest_tournament_results` flips `enum_status` to `IN_PROGRESS` and the badge changes automatically on next render — no cron, no manual cleanup, no state drift.
- **Single source of truth for the label.** The helper is used by Calendar and EventManager; any future consumer (admin drill-down, Telegram rendering, email templates) imports the same function. No per-component switch statements to drift out of sync.
- **Bonus fix.** EventManager was previously rendering the raw enum string (`"PLANNED"`, `"SCHEDULED"`) instead of the i18n label. Adopting the helper closed that pre-existing bug.
- **Not stored in DB.** Consumers that bypass the frontend (Telegram bot, server-side email digest, future BI dashboards) will see raw `enum_status`. If/when those consumers need the "awaiting" distinction, port `getEventDisplayStatus` to SQL or Python — the logic is a single `CASE` expression.
- **Test coverage.** +11 vitest unit tests in `frontend/tests/eventStatus.test.ts` (ES.1–ES.11) covering every row of the truth table, including the null-both-dates edge and same-day grace. +1 vitest integration test in `frontend/tests/CalendarView.test.ts` (8.41b) asserting the amber badge renders. vitest total: 255 → 267.
