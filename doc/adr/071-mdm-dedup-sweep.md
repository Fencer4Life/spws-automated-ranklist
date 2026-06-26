# ADR-071: Master-data management + eventual-consistency dedup (`DEDUP_SWEEP`)

**Status:** Accepted (implemented 2026-06-15, NEW pipeline build M1–M5). Design in
[ingestion_pipeline_NEW_design.md](../ingestion_pipeline_NEW_design.md) §5.1 / §6. **Implemented** — see [development_history](../development_history.md).
**Date:** 2026-06-14
**Relates to:** ADR-070 (`ResolveFencers`), ADR-072 (recompute / self-healing), ADR-003 (FK identity),
ADR-056 (band-midpoint BY reconcile), ADR-055 (provenance).

## Context

ADR-070's asymmetric safety deliberately **creates duplicates** rather than risk a wrong link. Full
automation therefore needs a counterpart that cleans them up *without a human* — otherwise the roster
slowly accumulates duplicate fencers and conflicting birth years, and the create-then-dedup bet never
pays off.

## Decision

Govern `tbl_fencer` as a deduplicated **master-data store** maintained by an eventual-consistency sweep,
**`DEDUP_SWEEP`** — a flow that runs `ResolveFencers` in `scope=whole_roster` mode. It is the *same*
dedup + BY-reconcile logic as per-bracket ingest (ADR-070), not a separate subsystem — only the scope
differs. It:

- merges duplicate fencers via a new **`fn_merge_fencers`** RPC: re-points `tbl_result.id_fencer` to the
  survivor (identity is the FK, ADR-003) and folds aliases; and
- reconciles conflicting birth years to the **band midpoint** (ADR-056).

Every merge/reconcile emits `master_data.changed`; the `SelfHealing` reactor (ADR-072) turns each into a
`RECOMPUTE_DOMESTIC` of the affected events. **The sort *is* the rebuild** — no manual re-score.
`DEDUP_SWEEP` is schedulable (pg_cron) or operator-triggered, and is the bootstrap tool for a roster
seeded with known duplicates + wrong BYs.

## Alternatives considered

- **A separate MDM service / table.** Rejected: the resolution logic already lives in `ResolveFencers`; a
  second copy would drift. One code path, two entry points (per-bracket, whole-roster).
- **Dedup at ingestion only (no sweep).** Rejected: a duplicate is often only detectable once *both*
  spellings have been seen across different events; a roster-wide sweep catches what per-bracket
  resolution structurally cannot.
- **Merges requiring human confirmation.** Rejected: contradicts full automation. A merge is FK-repointing
  with provenance (ADR-055); a wrong merge surfaces via `Escalate` (ADR-074) and is itself reversible by a
  later sweep.

## Consequences

- The create-then-dedup asymmetry (ADR-070) is closed into a convergent loop with recompute (ADR-072).
- `fn_merge_fencers` is the one audited merge primitive.
- Bootstrapping a roster with known duplicates + wrong birth years becomes a single `DEDUP_SWEEP` run that
  fans out to per-event recomputes automatically.

## Tests (implemented — design §10, RED first)

merge re-points results + folds aliases; BY reconcile to midpoint; sweep enqueues exactly the affected
events for recompute; idempotent (a second sweep no-ops).

## Amendment (2026-06-26) — `fn_merge_fencers` clears the match_candidate FK

The original `fn_merge_fencers` re-pointed `tbl_result` to the survivor but **not**
`tbl_match_candidate.id_fencer`, which *also* FK-references `tbl_fencer`. A duplicate
carrying any non-colliding match-candidate row therefore aborted the merge on
`tbl_match_candidate_id_fencer_fkey` at the `DELETE FROM tbl_fencer` — hit live during the
SAMECKA-NACZYŃSKA dedup (the duplicate held AUTO_MATCHED / NEW_FENCER candidate rows).

**Fix:** the merge now re-points the duplicate's remaining match-candidate rows to the
survivor before deleting the dup (the audit follows the re-pointed result). Migration
`supabase/migrations/20260626000001_fn_merge_fencers_repoint_match_candidate.sql`; pgTAP
`44.12` reproduced the FK abort (RED) and passes after the fix.
