# ADR-097: Scoring configuration locks on first score; a privileged, audited procedure is the only way to revise a locked season

**Status:** Accepted (drafted in [doc/plans/scoring-governance-lock-2026-09-19.html](../plans/scoring-governance-lock-2026-09-19.html) §04, signed off 2026-09-19). Implemented and verified on LOCAL: SS26.LOCK.01–12 (`supabase/migrations/20260919000005_scoring_governance_lock.sql`) and SS26.REVISION.01–08 (`supabase/migrations/20260919000006_scoring_privileged_revision.sql`) both land, 1086 pgTAP assertions and the full frontend suite pass, and a manual `fn_revise_and_rescore_season` run against a LOCAL fixture moved a stored score end to end.
**Date:** 2026-09-19
**Extends:** [ADR-042](042-carryover-engine-dispatcher.md), [ADR-045](045-engine-selector-default-flip.md) (the dispatcher pattern those two established for carry-over, extended here to the scoring engine)
**Relates to:** [ADR-083](083-server-enforced-authorization.md) (deny-by-default grants; `tbl_scoring_engine`'s RLS policy and this ADR's own new functions follow the same explicit-grant discipline), the design doc's own [§12 "Proposed ADR A"](../plans/versioned-season-scoring-and-pzsz-ranking-design.html)
**Source:** `supabase/migrations/20260919000005_scoring_governance_lock.sql`, `supabase/migrations/20260919000006_scoring_privileged_revision.sql`

## Context

Versioned scoring engines (steps 1–2 of the design) let a season's formula survive a future rule change without rewriting history — but nothing stopped an admin from editing a season's *configuration* (base value, podium coefficients, multipliers, thresholds, ranking buckets) after results were already scored under it. A mutable configuration on a scored season is the same defect the engine versioning fixed one layer up: editing `tbl_scoring_config` in place after scoring silently changes what already-published results *meant*, with no record that it happened.

The board must retain authority to correct a season's rules — a genuine data-entry mistake, a late rule clarification — and rescore it coherently. Those two needs are in tension: ordinary Admin editing has to stop being able to touch a scored season's configuration at all, while an authorized correction still has to be possible, deliberately, audited, and without ever publishing a partially rescored season.

## Decision

### 1 · A season's scoring configuration locks itself on its first scored result

`tbl_season.ts_scoring_locked_at` is set exactly once, transactionally, by `fn_calc_tournament_scores` the moment it scores a season's first tournament (`fn_ensure_active_scoring_revision`, called from inside the scoring path). Nothing clears it, including the privileged revision below. The trigger is the scored result, never a season date: a season with `dt_end` in the past and zero scores stays editable, and a season with `dt_end` in the future and one score is locked (SS26.LOCK.03).

### 2 · The guard is field-level, inside `fn_import_scoring_config`, not a whole-function gate

A whole-function guard was tried conceptually and rejected: `App.svelte`'s `handleUpdateSeason` resends the *entire* scoring config, unmodified, every time an operator flips the +EVF/Kadra toggle — a legitimate, always-permitted write. `fn_import_scoring_config` instead applies its existing `COALESCE(new, stored)` resolution first, then compares the *resolved* value against the *currently stored* one per governed field (base value, all three podium coefficients, all eight type multipliers, both participant thresholds, ranking rules, and the new `engine_code` key) — an unchanged resend of a locked field is not a violation. `show_evf_toggle`, `show_evf_toggle_calendar` and `json_extra` apply unconditionally regardless of lock state, which is what keeps the toggle-only save working forever (SS26.LOCK.07).

### 3 · Role-based trigger backstops, not a session flag

A `BEFORE UPDATE` trigger on `tbl_scoring_config` repeats the same comparison for any writer bypassing the RPC; a second trigger on `tbl_scoring_type_config` rejects every direct `INSERT`/`UPDATE` unconditionally — that table has been trigger-owned (projected from `tbl_scoring_config`) since the normalized-type-policy step and was never a write surface of its own, locked or not. Both guards check `current_user <> 'authenticated'`, not a session-local flag: every write path that legitimately needs to pass through them — `fn_import_scoring_config`, `fn_apply_scoring_config_write`, the five pre-existing `SECURITY DEFINER` cascade-deletes, pgTAP fixtures running as `postgres`, and `fn_revise_and_rescore_season` below — already executes as the function owner or as `postgres` directly, so the check passes with nothing to set and nothing to remember to reset. A session GUC (`app.privileged_revision`, considered first) would have needed sequencing discipline that a role check does not.

### 4 · One shared write path, not two drifting copies

`fn_import_scoring_config`'s actual write — a ~20-field `COALESCE`-over-current `UPSERT` into `tbl_scoring_config` plus `engine_code` resolution onto `tbl_season` — is extracted into `fn_apply_scoring_config_write`, which carries no lock check of its own. `fn_import_scoring_config` calls it only after its own guard passes; `fn_revise_and_rescore_season` calls it directly, skipping the guard by design, since it *is* the authorized exception. This codebase already hit and fixed exactly this class of drift once ([ADR-096](096-no-bracket-stubs-before-results.md) §2, two independently-drifting copies of the tournament-code formula) — a locked-out field that only one of two hand-maintained copies remembers to accept would be a silent, security-relevant gap. `fn_apply_scoring_config_write` is revoked from `authenticated` as well as `PUBLIC`/`anon`, defense in depth against it ever becoming directly reachable.

### 5 · `fn_revise_and_rescore_season` — reachable only outside the Admin session

```
fn_revise_and_rescore_season(
  p_id_season   INT,
  p_new_config  JSONB,  -- fn_import_scoring_config's shape, governed fields only
  p_new_engine  TEXT,   -- NULL keeps the current engine
  p_reason      TEXT,   -- NOT NULL, non-empty
  p_actor       TEXT,   -- NOT NULL, non-empty -- no session identity exists to infer this from
  p_board_ref   TEXT    -- nullable, a real decision reference is expected in practice
) RETURNS TABLE(id_revision INT, rescored_count INT)
```

Validates the season exists and `p_reason`/`p_actor` are non-empty before touching anything. Resolves `p_new_engine` to an *existing* `tbl_scoring_engine` row only — this function never creates one; a new formula is a code change (a new released engine version), not something a data revision can conjure. Applies the config through `fn_apply_scoring_config_write` with no lock check, deactivates the season's current revision and inserts the new one **as two sequential statements**, not one combined `WITH`-CTE — Postgres does not guarantee a data-modifying CTE's effects are visible to the main statement's own constraint checks within that same statement, and the partial unique index on `(id_season) WHERE bool_active` reproducibly raised a duplicate-key violation when both were combined during implementation. Rescoring loops every `SCORED` tournament in the season, calling `fn_calc_tournament_scores` for each, which stamps every touched result with whichever revision is *currently* active — the new one, since activation happened first. Before returning, it asserts inline that every result in the season now references the new revision id and nothing else; a mismatch raises, and the whole call — including the revision row's own `INSERT` and the activation — rolls back atomically, by ordinary PostgreSQL single-statement transaction semantics, no explicit savepoint needed.

Revoked from `authenticated` as well as `PUBLIC`/`anon` — the one function in this codebase revoked from that role. Reachable only as `postgres`/`service_role`: `docker exec -i supabase_db_SPWSranklist psql` on LOCAL, `scripts/cloud-sql.sh <cert|prod>` on CERT/PROD — the existing, established privileged-write path per the `cloud-db-ops` skill, no new access mechanism invented. This is the concrete meaning of "an operator procedure outside Admin": not a UI affordance behind an extra permission check, but a function the web session's role cannot call at all.

### 6 · Existing scored seasons are backfilled as locked

`fn_backfill_scoring_lock()` locks every season that already has scored results, with `ts_scoring_locked_at` set from the **earliest surviving `ts_points_calc`** in that season, not `NOW()` — the audit trail reflects when scoring actually happened, not when this migration ran. Idempotent and split from the migration transaction the same way `fn_backfill_scoring_engines` is, because `supabase db reset` applies migrations before the seed dump loads.

## Alternatives considered

1. **One growing `IF` tree holding the arithmetic inline**, or **dispatch through a function reference stored in a table.** Both rejected at the engine-dispatcher stage (ADR-042's own precedent extended here): a stored function reference needs dynamic `EXECUTE` inside `SECURITY DEFINER`, defeats Postgres dependency tracking, and hides the call edge from static analysis.
2. **A partial lock leaving ranking buckets editable.** Rejected: buckets silently reordering the published ranklist with no rescore and no audit trail is the exact defect this ADR closes, just moved one field over.
3. **A whole-function guard on `fn_import_scoring_config`.** Verified necessary to reject: it breaks the legitimate EVF-toggle save path on any scored season, since that caller always resends the full config object.
4. **A session GUC (`app.privileged_revision`) for the trigger bypass**, and **scoping the bypass to `authenticated` generally.** Both tried first and abandoned for the role-based `current_user <> 'authenticated'` check (§3) — no flag to set, nothing sequencing-dependent to get wrong, and it uniformly serves every legitimate internal writer already in the codebase.
5. **Deriving "actor" from Supabase Auth identity.** This system has none for a `docker exec`/`cloud-sql.sh` session; `p_actor` is an explicit, required parameter instead.
6. **Season-code inference of lock state, or UI-only enforcement.** Both rejected: the lock is a server fact (`ts_scoring_locked_at`), read by the frontend, never inferred by it or from a date.
7. **Permanently forbidding authorized corrections, or overwriting released engine bodies/configuration history.** Both rejected — the whole point is a correction path that is possible, deliberate, and permanently recorded, never a silent overwrite.

## Consequences

Configuration audit history becomes mandatory going forward: every scored season carries at least one `tbl_scoring_config_revision` row, and the row is never deleted or overwritten (only deactivated). A formula change still requires a new released engine version (a code change); this procedure only re-points a season at an already-released engine or edits its data-only parameters. Exceptional revision remains an operator procedure outside Admin and can never publish a partially rescored season, by construction of the transaction — proven both by SS26.REVISION.07's injected-failure test and, during implementation, by a real pre-existing data defect (a LOCAL seed tournament with a NULL participant count) that a manual revision attempt on `SPWS-2023-2024` hit and rolled back from cleanly, leaving the season's configuration, active revision and every sampled score completely unchanged.

**New:**

- `supabase/migrations/20260919000005_scoring_governance_lock.sql` — `tbl_scoring_config_revision`, `tbl_season.ts_scoring_locked_at`/`id_active_scoring_revision`, `tbl_result.id_scoring_revision`, `fn_backfill_scoring_lock`, `fn_ensure_active_scoring_revision`, the field-level guard in `fn_import_scoring_config`, `fn_raise_scoring_locked`, the two trigger guards, `engine_code` on `fn_export_scoring_config`/`fn_import_scoring_config`, an RLS policy + explicit `GRANT` on `tbl_scoring_engine` (created after ADR-083, so its default-revoke applies), and the minimal engine selector in `ScoringConfigEditor.svelte`.
- `supabase/migrations/20260919000006_scoring_privileged_revision.sql` — `fn_apply_scoring_config_write`, `fn_revise_and_rescore_season`.
- `supabase/tests/80_season_scoring_contract.sql` — SS26.LOCK.01–12 and SS26.REVISION.01–08, 21 new assertions total (39 → 50 → 59), plan-tests written before either migration per the design's own §10.
- `frontend/tests/ScoringConfigEditor.test.ts`, `SeasonManager.test.ts`, `SeasonManagerWizard.test.ts` — the lock at the UI layer: every field disabled and the Polish explanation shown on a guarded save click with no RPC fired; `readonly` deriving from `scoring_admin_locked`, never a season date.

**Changed:**

- `frontend/src/lib/api.ts` — `fetchScoringEngines()`, called once at app init, feeding the engine selector rather than a hardcoded list.
- `frontend/src/lib/types.ts` — `ScoringConfig` gains `scoring_admin_locked?`, `scoring_locked_at?`, `engine_code?`.
- `frontend/src/App.svelte`, `SeasonManager.svelte`, `SeasonManagerWizard.svelte` — `readonly` now reads `scoringConfig?.scoring_admin_locked ?? false` instead of a season-date comparison; `scoringEngines` threaded down to every `ScoringConfigEditor` mount.
- `supabase/tests/02_scoring_engine.sql` — two pre-existing tests (2.14, 2.15) switched from the shared active season (now locked by the LOCK migration's own fixture scoring) to isolated scratch seasons.

**Test impact.** pgTAP 1066 → 1086 assertions (21 new, all passing on a database rebuilt from scratch via `./scripts/reset-dev.sh`). Full frontend suite (899 tests, 55 files) and `svelte-check` (0 errors) unaffected. `postgrestools check` reports 0 findings on both new migrations.

**Verified on LOCAL (2026-09-19).** A manually-dispatched `fn_revise_and_rescore_season` against a fresh scratch season (`podium_gold` 3 → 500) moved the gold-place result's stored `num_final_score` from 78.00 to 3060.00 and re-stamped both results to the new revision, while the silver-place result (unaffected by the changed field) kept its original score — confirming the rescore is real, not a no-op, and that it discriminates by what actually changed. Not yet run against CERT or PROD.
