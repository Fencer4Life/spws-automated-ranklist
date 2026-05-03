# ADR-060: EVF parity sweep emits delta-only `.md` (no `full.md` overwrite)

**Status:** Proposed
**Date:** 2026-05-03
**Amends:** ADR-053 (EVF parity gate), ADR-058 (staging-reports bucket).

## Context

ADR-053 introduced the daily EVF parity sweep (`evf-parity-sweep.yml` cron) that compares EVF API state against DB state for EVF-organized events. When drift is detected, the sweep applies corrections via existing parity RPCs and notifies via Telegram.

ADR-058 introduced the `staging-reports` bucket where each event's verdict `.md` lives at `{event_code}/full.md`. The first ingestion (URL-based or email-based) writes `full.md` as the operator-validated baseline.

Question: when the EVF parity sweep applies corrections, what should it do with `full.md`?

Options:
- (A) Overwrite `full.md` with a freshly-rendered post-correction version.
- (B) Emit a separate delta `.md` showing only what changed; never touch `full.md`.
- (C) Both — overwrite `full.md` AND emit a delta.
- (D) Skip `.md` artefacts entirely; just notify in Telegram text.

The operator's framing: "the first vendor URL based ingestion creates the initial `.md` file, and later the EVF parity re-trigger would only add a 'delta' `.md` with the changes it made". The first-ingest verdict represents the operator's mental baseline; overwriting it from automated sweeps would erase the timeline of human decisions vs machine corrections.

## Decision

**Option B.** EVF parity sweep produces only delta `.md` files. `full.md` is never overwritten by automated sweeps. Silent (no `.md`, no Telegram) when sweep finds zero drift.

**Path:** `staging-reports/{event_code}/deltas/{yyyyMMdd_HHmmss}.md` (append-only).

**Renderer:** `python/pipeline/parity_delta.py`:

```python
def render(event_code: str, changes: list[ParityChange]) -> bytes
```

The function reads from in-memory `ParityChange` records (already produced by `evf_parity_sweep.py` for its existing log path) — no new DB queries.

**Format example:**

```markdown
# EVF parity delta — EVENT-A-2024-2025
_Sweep: 2026-06-03 03:45:12 UTC · 2 changes applied_

## Fencer corrections
| Fencer | Field | Before | After |
|---|---|---|---|
| #1042 STARK Tony | int_birth_year | 1974 | 1975 |

## Result corrections
| Tournament | Fencer | Field | Before | After |
|---|---|---|---|---|
| t#412 / V2 / EPEE / M | #88 KOWAL Jan | int_place | 7 | 5 |

_All changes auto-applied via fn_evf_apply_correction. Tournament scoring re-run for affected tournaments._
```

**Telegram delivery:** delta `.md` is sent via `notifier.send_staging_report(event_code, md_bytes, kind='delta', extras={'changes': N})` (per ADR-059) only when `len(changes) > 0`.

**`full.md` mutation policy** (orthogonal to EVF):
- First ingestion (URL or email) writes `full.md`.
- Operator alias mutation (Create / Transfer / Discard) → `regen-report.yml` re-renders `full.md` from current DB state and overwrites in place.
- EVF parity sweep does NOT touch `full.md`.

## Alternatives considered

### A. Overwrite `full.md` from sweep

Rejected: erases operator-validated baseline. Operator no longer has a frozen reference of "what the verdict looked like when I last reviewed this event".

### C. Both — overwrite `full.md` AND emit delta

Rejected: doubles `.md` files per drift event with no operator value (delta is the actionable artefact; the regenerated full would just be `full.md + delta` reapplied).

### D. Skip `.md` entirely; just notify in Telegram text

Rejected: change records belong in `staging-reports/{event}/deltas/` for archival and future cross-event analysis. Telegram text alerts are too easy to lose.

## Consequences

**Positive:**
- `full.md` semantically means "operator-validated state at last regen" — a stable baseline.
- Telegram scrollback of delta `.md` files IS the EVF change log, organised per event.
- Cross-event cascades from operator alias mutations DO update `full.md` for all touched events (separate mechanism per ADR-059) — the EVF flow doesn't compete.
- Empty sweeps stay silent — no Telegram noise on no-op overnight runs.

**Negative:**
- After many parity sweeps, `deltas/` may grow large per event. Manual cleanup eventually needed; per ADR-058 retention is "keep forever, manual delete only".
- Operator mental model: "to know current state, read `full.md` + apply each delta in `deltas/` chronologically". This is OK because `full.md` is updated whenever the operator triages aliases, so the delta backlog is bounded.
- Auto-rerun of EVF parity immediately after a cross-event alias cascade is NOT in scope (deferred to future ADR). Today's daily cron is the only trigger; the operator may see drift accumulate for up to 24 hours after they perform a cross-event mutation.

## Status — deliverables (proposed, not yet shipped)

- `python/pipeline/parity_delta.py` (renderer)
- `python/tests/test_parity_delta.py` (empty → no-md, BY-only, mixed sections)
- `python/pipeline/evf_parity_sweep.py` extension (call `parity_delta.render` + `notifier.send_staging_report`)
- Existing `evf-parity-sweep.yml` cron picks up the new behaviour automatically (no workflow YAML change needed)
