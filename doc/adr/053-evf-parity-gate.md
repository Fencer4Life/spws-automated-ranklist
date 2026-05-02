# ADR-053: EVF backup-source + parity gate + EVF_PUBLISHED promotion lifecycle

**Status:** Accepted
**Date:** 2026-05-02
**Relates to:** ADR-028 (EVF calendar/results import — amended), ADR-038 (EVF intake POL-only — affirmed and clarified), ADR-050 (unified ingestion pipeline — complemented), ADR-052 (URL→data validation — runs at Stage 7, complementary)

## Context

The scoring engine implements EVF's algorithm and is battle-proven across years of operation — engine output for EVF-organized events agrees with EVF's published rankings within rounding. Two structurally different cross-check situations exist:

- **SPWS-organized events.** No external authority exists. Engine output is the only output. Errors can only be caught by user observation.
- **EVF-organized events.** EVF publishes authoritative results via the EVF API. Engine output is verifiable against EVF's numbers.
- **FIE-organized events.** International events; no FIE-side API equivalent. Engine output is final, like SPWS.

For EVF events specifically, the temporal availability of authoritative data matters: in the days/weeks immediately following a tournament, only vendor systems (FTL/Engarde/Ophardt/etc.) have results; the EVF API has nothing. Once EVF publishes, EVF data becomes authoritative — at which point we want **100% alignment** between our DB and EVF's published numbers, not just engine-computed equivalence.

The architectural decision required is: how does an event transition from "engine-computed (provisional)" to "EVF-aligned (authoritative)" once EVF publishes, and how do we verify that transition is safe.

## Decision

Two orthogonal axes track an event's data state:

- **`tbl_event.enum_status`** — operational state. Existing axis. `CREATED → PLANNED → IN_PROGRESS → SCORED → COMPLETED`. At commit, every event regardless of organizer transitions to `COMPLETED`.
- **`tbl_event.txt_source_status` (NEW)** — data-provenance state. Two values:
  - `ENGINE_COMPUTED` — points in `tbl_result` are output of our scoring engine.
  - `EVF_PUBLISHED` — points have been overwritten with EVF's authoritative published numbers.

### Status × organizer invariant (enforced at DB level)

| Organizer | Allowed `txt_source_status` values |
|---|---|
| `SPWS` | `{ENGINE_COMPUTED}` only |
| `FIE` | `{ENGINE_COMPUTED}` only |
| `EVF` | `{ENGINE_COMPUTED, EVF_PUBLISHED}` |

Enforced via CHECK constraint on `tbl_event` referencing `txt_organizer`. Violations are write-time errors, not test-time discoveries.

### Parity gate

EVF-organized events get a parity check **automatically** post-commit. Two trigger paths:

1. **In-pipeline (synchronous):** if EVF API has data at commit time, parity runs in the same pipeline pass. Single combined Telegram notification.
2. **Cron sweep (asynchronous):** daily cron `python -m pipeline.evf_parity_sweep` walks `tbl_event` rows where `txt_organizer = 'EVF' AND txt_source_status = 'ENGINE_COMPUTED'`, probes EVF API per event, runs parity for those with fresh data.

Three sub-checks per event:

1. **POL count** — `count(tbl_result rows for event)` equals POL-fencer count from EVF API per-category page.
2. **Placements** — for each POL fencer, `tbl_result.int_place` equals EVF API's `Pos` for that fencer (absolute position in field, foreigners ahead included as gaps in our place sequence).
3. **Score within ±0.5** — for each POL fencer, `tbl_result.num_final_score` (engine output) is within ±0.5 of EVF API's `Points` for that fencer.

Tolerance ±0.5 = the half-point of displayable scoring precision; covers float-arithmetic differences between our engine and EVF's. **Exact equality is not required** because both engines may round differently in their final output.

### On parity PASS — auto-promotion

No operator confirmation. Pipeline performs:

1. UPDATE each `tbl_result.num_final_score` to EVF API's `Points` value verbatim (also `num_place_pts` / `num_de_bonus` / `num_podium_bonus` if EVF exposes them).
2. UPDATE `tbl_event.txt_source_status = 'EVF_PUBLISHED'`.
3. Audit log row recording the engine-vs-EVF deltas.
4. Telegram notification: `✅ {event_code} promoted to EVF_PUBLISHED`.

Engine output is not preserved. The audit log captures the diff. If a future investigation needs the engine's pre-promotion values, they're recoverable from the audit log.

### On parity FAIL

No state mutation beyond annotation:

1. SET `tbl_event.txt_parity_notes` with a structured failure summary (which sub-check, which fencers, deltas).
2. `txt_source_status` stays `ENGINE_COMPUTED`.
3. Telegram notification: `🚨 {event_code} parity FAIL` with all failing fencers listed.
4. Operator investigates via review CLI; can re-ingest from a different source, edit the override YAML, fix data, then retry parity.

### EVF API empty for an event

Some EVF events have no API data available — older events, events EVF never imported, technical issues. Cron behavior:

- For 30 days post-commit: cron retries parity check daily.
- Day 31: SET `tbl_event.txt_parity_notes = 'EVF API empty after 30 days; presumed unavailable'`. Cron stops retrying for that event. Telegram notification: `ℹ️ {event_code} — EVF API empty after 30 days`.
- Operator can manually re-trigger parity check if data later appears (review CLI action).

### Operator-initiated parity check

Review CLI gets a new action `[parity]` allowing operator to force a parity check on demand for any EVF event in `ENGINE_COMPUTED` state. Useful during Phase 5 rebuild walk where operator wants immediate verification rather than waiting for cron.

## Alternatives considered

### Alt 1 — EVF API as the canonical source for EVF events; vendor URL fallback only

Rejected. Vendor URLs carry richer roster information (clubs, given-name spelling) and are the live record of the day-of-event. EVF API is a downstream copy, sometimes incomplete for older events. Forcing EVF API as canonical loses vendor data and breaks the cross-source verification model.

### Alt 2 — Vendor URL canonical; EVF API for parity only (never the source)

Rejected as too rigid. Some events have clean EVF API data and vendor URLs that have rotted (404, paywalled, restructured). Operator must be allowed to choose EVF API as source when needed; the parity gate then becomes a self-check (still useful for catching engine drift).

### Alt 3 — Operator chooses source per event; auto-parity gate post-commit regardless

**Selected.** The review CLI's `[1]/[2]/[3]/[4]/[5]` source menu (already shipped in Phase 3) preserves operator flexibility. Parity gate fires automatically for EVF events post-commit; its meaning depends on which source was used, but the gate logic is uniform.

### Alt 4 — Operator-confirmed promotion (manual click after parity pass)

Rejected. Parity passing within ±0.5 is itself the verification; requiring an additional human click is theatre. Audit log + Telegram give visibility without requiring operator action.

### Alt 5 — Single-axis status enum encoding both operational and provenance state

Rejected. Mixing `enum_status` (operational lifecycle) with parity outcome creates "what does SCORED mean again" ambiguity six months out. Two orthogonal axes with clean per-axis semantics is sustainable.

### Alt 6 — Score-parity as exact equality rather than ±0.5

Rejected. Engine and EVF arithmetic may differ in last-decimal rounding. Exact equality would false-fail on rounding alone. ±0.5 is well below the displayable half-point and far below any score difference that would matter for ranking.

## Consequences

### Schema changes

New migration `2026MMDD_evf_parity_lifecycle.sql`:

- Add `tbl_event.txt_source_status` column. Default `'ENGINE_COMPUTED'`. NOT NULL.
- Add `tbl_event.txt_parity_notes` column. Nullable text.
- CHECK constraint:
  ```sql
  CHECK (
    (txt_organizer IN ('SPWS','FIE') AND txt_source_status = 'ENGINE_COMPUTED')
    OR (txt_organizer = 'EVF' AND txt_source_status IN ('ENGINE_COMPUTED','EVF_PUBLISHED'))
  )
  ```
- Backfill: existing rows get `txt_source_status = 'ENGINE_COMPUTED'`. EVF events promoted to `EVF_PUBLISHED` only when re-ingested via Phase 5 rebuild walk + parity-pass.

### New Python modules

- `python/pipeline/evf_parity.py` — parity-gate logic. Three sub-checks, returns `ParityResult`.
- `python/pipeline/evf_parity_sweep.py` — cron entry point. Walks pending events, runs parity per event.

### Existing code touched

- `python/pipeline/orchestrator.py` — post-commit hook calls `evf_parity` synchronously when source is EVF API or vendor URL with EVF event organizer.
- `python/pipeline/notifications.py` — three new message templates: parity-pass, parity-fail, EVF-empty.
- `python/pipeline/review_cli.py` — new `[parity]` action.

### Cron registration

Daily run via GitHub Actions workflow (or internal scheduler if one exists). Workflow file: `.github/workflows/evf_parity_sweep.yml`. Runs `python -m pipeline.evf_parity_sweep` at 04:00 UTC.

### Test coverage

- pgTAP — parity PASS path (promotes), parity FAIL path (annotates), CHECK constraint rejects invalid status×organizer combinations.
- pytest — `evf_parity` unit tests with mocked EVF API (3 sub-checks individually + integration), `evf_parity_sweep` cron logic with mocked DB.
- vitest — UI changes are minimal; existing event-row display surfaces `txt_source_status` and `txt_parity_notes` (added to `EventManager.svelte` or equivalent).

### Notifications

Telegram notifications fire on every state transition:
- 📨 Routine commit (every event)
- ✅ Promotion to `EVF_PUBLISHED` (parity pass)
- 🚨 Parity FAIL (with all failing fencers listed)
- ℹ️ EVF API empty after 30 days
- 📊 Daily cron sweep summary

Single channel, English, plain text with emoji severity prefix, within-event batching (commit + parity in same pipeline run = one message).

### Audit trail

Every promotion, FAIL annotation, and EVF-empty annotation produces an audit log row in the existing audit table. Schema TBD if a new column is needed; otherwise existing audit infrastructure suffices.

## Out of scope

- **FIE parity gate.** No FIE API exists; FIE events stay `ENGINE_COMPUTED` permanently. No automatic verification possible.
- **Manual force-promotion to `EVF_PUBLISHED`.** Operators with DB access can update the column directly with audit; no UI affordance for this. By design — parity should be the only path.
- **Bulk parity sweep across multiple events in one operation.** Cron is per-event, daily. No "run parity on all events now" RPC; if needed later, can be added.
- **Re-running parity after the 30-day annotation.** Operator must explicitly trigger via review CLI `[parity]` action; no auto-retry.
- **Carrying engine-computed values forward after EVF promotion.** Engine output is replaced by EVF values verbatim. Audit log preserves the deltas for forensic recovery.
