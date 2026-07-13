# ADR-072: Master-data-change-triggered idempotent recompute (CDC queue + debounce)

**Status:** Accepted (implemented 2026-06-15, NEW pipeline build M1–M5). Design in
[archive/legacy-2026-07/ingestion_pipeline_NEW_design.md](../archive/legacy-2026-07/ingestion_pipeline_NEW_design.md) §6 / §8. **Implemented** — see [development_history](../archive/legacy-2026-07/development_history.md).
**Date:** 2026-06-14
**Relates to:** ADR-014 (delete + re-import), ADR-022 (atomic commit), ADR-056 (V-cat from BY),
ADR-070 (identity) / ADR-071 (dedup) — the change *sources*; ADR-041 (edge-function dispatch),
ADR-074 (no-halt recompute). This ADR builds the **self-healing** half of the pipeline.

## Context

Birth years will be wrong on first ingest and corrected repeatedly during cleanup; merges (ADR-071) move
results between fencers. A correction must propagate to the live ranking **automatically**, or
"self-healing" is just a slogan. Critically, a V-cat change is structurally a **re-bracketing**, not
merely a re-score — a fencer's result *relocates* between an event's V-cat brackets (e.g. V2 → V3).

## Decision

A master-data change auto-triggers **`RECOMPUTE_DOMESTIC`**, which re-derives V-cats and re-scores the
affected event(s) **from stored, FK-linked results — no source fetch, no re-match**
(`LoadCommitted → AssignFinalVcat → ValidateCounts → Commit`).

- **Event-granular (not tournament-granular).** The recompute unit is the *event*: a single bracket cannot
  absorb a relocation because the moving result is stored under its **OLD** bracket. `LoadCommitted` loads
  *all* of an event's brackets; `Commit` re-partitions results by derived V-cat (creating/dropping bracket
  rows), recounts (honouring stored joint-pool flags, ADR-049), and re-scores.
- **CDC trigger, column-aware.** `trg_fencer_change_enqueue` enqueues the affected `id_event`s into
  `tbl_recompute_queue` on **BY / merge / nationality** changes; **name/alias edits enqueue nothing**
  (the FK is durable).
- **Debounced worker.** Edits land in `tbl_fencer` immediately and bump a watermark; the worker drains
  only when quiet ≥ `DEBOUNCE_WINDOW`, dedups by `id_event`, and recomputes each affected event **once**
  against the fully-corrected roster.
- **Convergent (fixpoint).** `Commit` declares `effects: live` (not `master_data`), so a recompute never
  re-fires the trigger; a change-gated trigger + idempotent recompute ⇒ the loop settles.
- **Source retention (BR-13).** `ParseSource` persists `source_artifact_path` so a dead-URL event can be
  *re-ingested* (a fresh-ingest flow with `source=retained`) — this is distinct from recompute, which
  never touches source.

## Alternatives considered

- **Tournament-granular recompute.** Rejected: cannot absorb a cross-bracket relocation — the destination
  bracket has no stored copy of the moving result.
- **Full re-ingest on every edit.** Rejected: needless source fetch + re-match; recompute works from
  durable FK-linked rows (ADR-003) and is cheaper and deterministic.
- **Synchronous recompute on every edit (no debounce).** Rejected: a `DEDUP_SWEEP` touching many fencers
  would re-score the same event dozens of times; debounce coalesces to one rerun per event.
- **LISTEN/NOTIFY daemon vs pg_cron drain.** pg_cron recommended first (simpler, reuses ADR-041 dispatch);
  LISTEN/NOTIFY is a latency knob (design §11).

## Consequences

- Corrections heal the ranking with **no operator action**; `DEDUP_SWEEP` (ADR-071) + recompute is a
  closed, convergent loop.
- New DB objects: `tbl_recompute_queue`, `trg_fencer_change_enqueue`, `fn_enqueue_affected_events`, and a
  debounced `python/pipeline/recompute/worker.py`.
- `ValidateCounts` on recompute is **no-halt** (ADR-074): a relocation that drops a bracket below min
  auto-drops it and the heal still completes — a correction is never blockable.
- **Scheduler realization (Step C, 2026-06-16).** The drain runs as a **GitHub Actions cron**
  (`recompute-drain.yml`, every 15 min against CERT, `python -m python.pipeline.recompute.worker
  --drain`) — the repo's established scheduler pattern (cf. `evf-sync.yml`) — rather than the
  pg_cron→Edge-Function sketch above. This drops the pg_cron / edge-runtime dependency (neither is
  enabled on LOCAL); the worker's 120 s `DEBOUNCE_WINDOW` does the coalescing the cron cadence does not.
  LOCAL stays manual. pg_cron / LISTEN-NOTIFY remain available as a later latency knob (design §11).
- **RECOMPUTE write-back partition key (Step C).** `Commit` re-persists by **(weapon, gender,
  governed-V-cat)**, not V-cat alone — an event spans many weapon/gender brackets — and **clears** a
  bracket a relocation empties. The recompute reader (`fetch_event_results`) reads the V-cat / weapon /
  gender off `tbl_tournament` (where they live), not `tbl_result`.

## Tests (implemented — design §10, RED first)

trigger fires only on real change + enqueues the correct events (pgTAP); debounce / claim / coalesce;
recompute-twice == once (idempotence); a boundary-crossing BY change re-partitions to the correct bracket;
recompute-to-quiescence.

## Amendment (2026-06-26) — deterministic CLAIMED recovery (no time heuristic)

The `PENDING → CLAIMED → DONE` lifecycle had no recovery for a worker killed **mid-drain**:
`claim_recompute_batch` only looked at PENDING, so rows already flipped to CLAIMED were
stranded forever (invisible to the next run and the cron). This bit live — a drain killed
during the SAMECKA-NACZYŃSKA repair left 39 rows stuck CLAIMED.

A first fix added a 10-minute `STALE_CLAIM_SECONDS` timeout; it was rejected as a fragile
heuristic (a legitimate recompute running longer would be double-claimed) and an unwanted
permanent "guess whether the worker died" mechanism.

**Decision (deterministic):** CERT drains are **serialized** — the `recompute-drain`
workflow's `cert-recompute` concurrency group (`cancel-in-progress: false`) plus the
worker's 120s debounce mean **one drain at a time**. Under that single-writer model, any
row still CLAIMED when a new drain *starts* is provably an orphan from a worker that died
mid-run — no live worker owns it. So `claim_recompute_batch` now claims **every not-DONE
row (PENDING AND CLAIMED)** in one CLAIMED flip — deterministic crash recovery, no clock.
Claiming straight to CLAIMED (never resetting to PENDING) keeps the one-PENDING-per-event
partial unique index safe even when a fresh PENDING coexists with an orphaned CLAIMED for
the same event; recompute is idempotent, so the queue converges to DONE.

Verified live: re-draining CERT reclaimed the 39 stranded rows (20 distinct events
recomputed) → queue all DONE. Test: `python/tests/test_db_connector.py`
(`test_claim_recompute_batch_reclaims_orphaned_claimed`).
