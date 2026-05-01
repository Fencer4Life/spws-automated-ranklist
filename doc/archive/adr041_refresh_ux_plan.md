# ADR-041 follow-up: Refresh UX on dispatch

**Status:** Proposed (pending approval)
**Date:** 2026-04-25
**Relates to:** ADR-041 (Edge Function dispatch)

## Goal

After clicking ⬇ on an event row, the admin should see freshly-populated tournament URLs in the UI **without manually hard-refreshing the browser**. Two complementary refresh triggers; both fire `onrefresh()` (= `App.reloadAdminEvents`).

## Triggers

### Trigger A — Auto-refresh ~40s after a successful dispatch

- Workflow runs on GH Actions typically take 20-30s (queue + pip install + script execution).
- 40s gives slack so the script's `tbl_tournament` PATCHes have completed before we re-fetch.
- Implemented as `setTimeout(onrefresh, 40_000)` scheduled inside `dispatchAndTrack` after the success path.
- Per-event timer ID is tracked; a fresh dispatch on the same event clears the previous timer (latest dispatch wins; no double-fire).
- Fires once per successful dispatch. Failed dispatches do not schedule auto-refresh.

### Trigger B — Always refetch when expanding the accordion (▶ → ▼)

- The user's natural gesture for "I want to see this event's tournaments now" *is* the expand click.
- `toggleExpand(eventId)` calls `onrefresh()` when going from collapsed → expanded.
- Collapsing (▼ → ▶) does not refetch (admin is hiding, not asking for fresh data).
- Always fires regardless of whether a dispatch happened — consistent semantics, no stale-tracking state.

## Implementation

### EventManager.svelte

- New prop: `onrefresh = () => {}` with type `() => void | Promise<void>` (so caller can return a promise but it's not awaited — UI doesn't block).
- New per-event state: `dispatchTimers: Map<number, ReturnType<typeof setTimeout>>` to track auto-refresh timers and cancel them on supersede.
- `dispatchAndTrack` — on success branch, after `setDispatchStatus(...)`:
  - Clear any existing timer for this event id.
  - Schedule a new `setTimeout(() => onrefresh(), 40_000)` and store its ID.
- `toggleExpand(eventId)` — modify so that when the event transitions from absent (collapsed) to present (expanded) in `expandedIds`, fire `onrefresh()` synchronously (don't await).

### App.svelte

- Single line change: `onrefresh={reloadAdminEvents}` prop on the `<EventManager>` element.
- `reloadAdminEvents` already exists ([App.svelte:651](frontend/src/App.svelte#L651)) and re-fetches:
  - `calendarEvents`
  - `allTournaments`
  - `matchCandidates`
  Cost: 3 API calls, ~300-500 ms total on CERT. Acceptable for this admin-only flow.

## Tests (TDD — RED first, then implement)

Replace the two test stubs (`9.45g`, `9.45h`) drafted earlier for the manual-refresh-button design. The new test set:

| ID | Assertion |
|---|---|
| `9.45g` | After a successful dispatch, `onrefresh` is fired automatically after 40 seconds (use `vi.useFakeTimers` + `vi.advanceTimersByTime(40_000)`). |
| `9.45h` | A second dispatch on the same event resets the auto-refresh timer (only one `onrefresh` call after 40s of the second dispatch's clock). |
| `9.45i` | Clicking the ▶ expand triangle (collapsed → expanded) calls `onrefresh` exactly once. |
| `9.45j` | Clicking the ▼ collapse triangle (expanded → collapsed) does NOT call `onrefresh`. |
| `9.45k`–`9.45n` | See **Spinner UX** below — delayed-show, banner morph, triangle morph, error state. |

Test commands (per memory rule, before push):
```
cd frontend && npm test -- --run EventManager
cd frontend && npm test -- --run                # all vitest
bash scripts/check-coherence.sh
```

## Files modified

| File | Change |
|------|--------|
| `frontend/src/components/EventManager.svelte` | New `onrefresh` prop, `dispatchTimers` Map, auto-refresh scheduling in `dispatchAndTrack`, expand trigger in `toggleExpand` |
| `frontend/src/App.svelte` | One-line: pass `onrefresh={reloadAdminEvents}` |
| `frontend/tests/EventManager.test.ts` | Replace 2 stubs (`9.45g`, `9.45h`) with 4 new tests (`9.45g`–`9.45j`) |
| `doc/adr/041-edge-function-dispatch.md` | New "Amendment 2026-04-25 — Refresh UX" section folding this plan in once shipped |
| `doc/development_history.md` | One-line entry under the ADR-041 block referencing this followup |
| `doc/Project Specification...md` Appendix D | vitest 279 → 287 (+8: 9.45g–j refresh triggers, 9.45k–n spinner UX); total 893 → 901 |

## Edge cases

| Case | Behaviour |
|---|---|
| Admin clicks ⬇ twice in quick succession on the same event | Second dispatch's success clears the first timer; only one auto-refresh fires (40s after the second dispatch). |
| Admin expands accordion *during* the 40s auto-refresh window | `onrefresh` called twice (once on expand, once on auto-refresh). Both calls are idempotent re-fetches; harmless. |
| `onrefresh` throws (network blip) | The dispatch status banner is unchanged. User can retry by re-expanding or waiting for the next click. |
| Admin dispatches on Event A, expands Event B before A's auto-refresh fires | Both `onrefresh` calls succeed; both lists end up fresh. No interaction. |
| Component unmount before timer fires | Timer is per-component-instance; `setTimeout` is cancelled implicitly when the Map is garbage-collected. (We don't add explicit `onDestroy` cleanup — Svelte's reactivity handles it.) |

## Spinner UX (clever, not generic)

A naïve spinner ("show during fetch, hide after") would either flicker on every fast refresh or always blink for ~300 ms — both feel cheap. The clever version layers four well-known UX patterns:

### 1. Delayed-show — spinner only renders if refresh takes >200 ms

Standard "lazy-spinner" pattern: when refresh starts, schedule `setTimeout(() => setState('refreshing-visible'), 200)`. If the promise resolves before 200 ms, the timeout's setState is a no-op (state goes straight to 'success' and the spinner never renders). No flash on fast networks; on slow networks the spinner appears mid-flight and the user understands it's working.

### 2. Per-event scope — no global spinner

The refresh state lives in a `Map<eventId, RefreshState>` keyed by `id_event`. Each event renders its own indicator. A slow refresh on one event does not block, blank-out, or visually noise other events.

### 3. Banner lifecycle extension for dispatch-triggered auto-refresh

The dispatch status banner that already exists (from ADR-041) is reused — its message morphs through the full pipeline rather than being torn down and rebuilt:

```
⏳ Triggering populate-urls for PEW1…              ← phase 1 (sub-second)
✓ Triggered: PEW1 — view run on GitHub Actions ↗   ← phase 2 (persists 40s, auto-clears 5min)
🔄 Refreshing tournament data…                     ← phase 3 (only if >200 ms)
✓ Refreshed at 14:24:30                            ← phase 4 (auto-clears 1.5s)
```

The admin sees a coherent timeline instead of disconnected toasts. The banner already has CSS transitions for the colour swap (blue→green→blue→green) so the morph feels animated for free.

### 4. Expand-triggered refresh: animate the expand triangle itself

When the admin clicks ▶ to expand an event that has *no* dispatch banner, we don't create one (a transient banner for a 300 ms refresh would be visual junk). Instead, the **expand triangle morphs**:

```
▶  →  ◐ (spinner, only after 200 ms)  →  ✓ (briefly, 1s)  →  ▼ (final state, accordion expanded)
```

Zero new UI elements; the affordance the admin just clicked tells them "I'm working." If the refresh fails, the triangle becomes ⚠ and the row's banner shows the error so it's recoverable. After a few seconds the triangle reverts to ▼.

### Combined state machine (per event)

```
idle ──[refresh starts]──→ refreshing ──[<200ms resolved]──→ success-flash (1.5s) ──→ idle
                                ↘[>200ms]──→ refreshing-visible ──[done]──→ success-flash ──→ idle
                                                          ↘[error]──→ refresh-failed ──[3s]──→ idle
```

One state machine, two render targets (banner extension *or* triangle morph), depending on whether a dispatch banner already exists for this event.

### Tests added for the spinner UX

| ID | Assertion |
|---|---|
| `9.45k` | A refresh that resolves in <200 ms never sets the visible spinner state — banner/triangle stays unchanged. |
| `9.45l` | A refresh that takes >200 ms transitions the dispatch banner through `Refreshing…` → `✓ Refreshed at <time>` and auto-clears. |
| `9.45m` | An expand-triggered refresh on an event with no dispatch banner morphs the expand triangle (▶ → spinner → ▼) when refresh exceeds 200 ms. |
| `9.45n` | If `onrefresh` rejects, the failed state renders inline error and auto-clears after 3 s. |

(Implementation note: use `vi.useFakeTimers()` + a controlled-deferred promise for `onrefresh` to make the timing deterministic.)

### Why not a global "loading" overlay

- Blocks the entire admin UI for what is usually a 300 ms operation — infuriating.
- Doesn't tell the admin which event triggered the load.
- Loses the ability to interact with the rest of the calendar during the refresh.

Per-event scope wins on every dimension.

## Out of scope

- Manual "↻ Refresh now" button in the success status — explicitly not requested.
- Per-event scoped refetch (only this event's tournaments) — using full `reloadAdminEvents` is simpler and acceptable in cost.
- Tournament-level dispatch (`scrape-tournament.yml`) gets the same auto-refresh + expand behaviour for free since it shares `dispatchAndTrack` and the same accordion. The triangle-morph likewise applies to tournament rows if we later decide they need it.

## Rollback

Single small commit. If expand-on-refresh proves too heavy in practice (e.g. lots of expansions per session), revert via removing the `toggleExpand` change; the auto-refresh mechanism stands alone.

## Pre-push checklist (per memory rule, no exceptions)

1. All 3 test suites GREEN locally
2. `bash scripts/check-coherence.sh` PASS
3. Appendix D test baselines updated
4. Push triggers CI; if CI fails, fix before doing anything else.
