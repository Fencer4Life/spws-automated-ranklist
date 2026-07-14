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

## Amendment (2026-07-14) — extend the scheduled drain to PROD

**Context.** Every prior drain of this loop ran against CERT only (Step C, 2026-06-16); PROD
carried the trigger and the queue table (same schema, same migrations) but nothing ever
invoked the worker there — `recompute-drain.yml`'s own header says so: "CERT only. LOCAL
stays manual." That gap was survivable while master-data corrections originated on CERT and
reached PROD only through the normal event/results promotion path (environments doc,
promotion-contracts table — no "fencer master data" row). The organizer master-list birth-year
reconciliation (`doc/plans/fencer-birth-year-master-list-2026-07.html`) changes that: it writes
`int_birth_year` corrections directly to `tbl_fencer` on LOCAL, CERT, **and** PROD in one
migration, per the organizer's explicit ask, rather than staging the correction on CERT and
waiting for a later promotion cycle to carry it over. One correction in that batch
(SAMECKA-NACZYŃSKA Martyna, BY 1986→1985) genuinely re-brackets a past season
(SPWS-2024-2025, V0→V1) — a real `RECOMPUTE_DOMESTIC` case, not a formality — so a PROD queue
entry that never drains is no longer a theoretical gap; see the investigation record,
[`doc/audits/prod-recompute-drain-gap-2026-07-14.html`](../audits/prod-recompute-drain-gap-2026-07-14.html).

**Decision.** Add `recompute-drain-prod.yml`, structurally identical to `recompute-drain.yml`
(same 15-minute cron, same `--drain` worker invocation, same manual-dispatch `debounce` input,
same Telegram-on-failure step) but pointed at `secrets.SUPABASE_PROD_URL` /
`secrets.SUPABASE_PROD_SERVICE_ROLE_KEY` (both already-provisioned secrets — no new credential).
CERT's dedicated job, cadence and concurrency group are untouched.

- **Concurrency group is `prod-write`, not a new `prod-recompute` group.** CERT's job owns its
  own `cert-recompute` group because nothing else writes to CERT on a schedule that would
  collide with it. PROD is different: `promote-season.yml`, `evf-sync.yml` and `promote.yml`
  already share one group, `prod-write`, precisely so season/calendar/event-result promotion
  never runs concurrently with itself. The recompute drain is one more PROD writer and joins
  the same group — a dedicated group would let a recompute run mid-write during a season or
  results promotion touching the same rows, which `prod-write` exists to prevent.
- **No new escalation path needed.** A below-minimum-bracket auto-drop during recompute
  (ADR-074, no-halt) already surfaces via the `POST_COMMIT` reactor's `ON_LOSS` Telegram
  escalation whenever `RECOMPUTE_DOMESTIC` reaches `Commit` — this fires identically regardless
  of which environment's database the flow ran against, so PROD gets the same "a bracket was
  dropped" alert CERT already gets, with no additional code.
- **Same cadence, same debounce.** 15-minute cron, worker's existing 120s `DEBOUNCE_WINDOW` —
  consistent with CERT rather than inventing a different rhythm for PROD.

**Alternatives considered.**
- **Hold PROD's queue undrained, rely on a human to notice.** Rejected: defeats the entire
  point of "self-healing" for the one environment operators and the public actually see;
  already-known to bite (this exact batch has a real re-bracket, not a hypothetical one).
- **A dedicated `prod-recompute` concurrency group, mirroring CERT's `cert-recompute`.**
  Rejected: PROD already has a shared-writer serialization point (`prod-write`); a second,
  independent group would not actually prevent a recompute from racing a live promotion job,
  since two different concurrency groups run concurrently with each other by definition.
- **Fold PROD's drain into the existing `recompute-drain.yml` as a second job in the same
  file.** Considered for brevity; rejected in favor of a separate file to keep one
  workflow = one concurrency domain = one catalog row, matching how `promote.yml` /
  `promote-season.yml` / `evf-sync.yml` are already split rather than combined.

**Consequences.**
- PROD is now a second automated drain target; LOCAL remains manual, unchanged.
- New workflow `recompute-drain-prod.yml`, cataloged in
  [workflow catalog](../handbook/reference/workflow-catalog.html) and
  [operator runbooks](../handbook/operations/operator-runbooks.html).
- No new secrets, no schema change, no new pgTAP surface — this amendment is entirely a
  scheduling/operational change reusing existing, already-tested mechanics.
- Direct-to-PROD master-data edits (rather than CERT-then-promote) are now operationally
  supported by the self-heal loop, not just schema-permitted — worth naming so future sessions
  don't assume the CERT-centric framing in the original 2026-06-14 Decision is still the whole
  story.
