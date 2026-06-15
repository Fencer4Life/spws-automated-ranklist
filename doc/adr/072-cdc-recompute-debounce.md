# ADR-072: Master-data-change-triggered idempotent recompute (CDC queue + debounce)

**Status:** Accepted (implemented 2026-06-15, NEW pipeline build M1–M5). Design in
[ingestion_pipeline_NEW_design.md](../ingestion_pipeline_NEW_design.md) §6 / §8. **Implemented** — see [development_history](../development_history.md).
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

## Tests (implemented — design §10, RED first)

trigger fires only on real change + enqueues the correct events (pgTAP); debounce / claim / coalesce;
recompute-twice == once (idempotence); a boundary-crossing BY change re-partitions to the correct bracket;
recompute-to-quiescence.
