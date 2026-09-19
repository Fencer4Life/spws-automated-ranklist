# ADR-099: An immutable per-season publication capability, checked once, in one function

**Status:** Accepted (drafted in [doc/plans/publication-boundary-2026-09-19.html](../plans/publication-boundary-2026-09-19.html) §03, signed off 2026-09-19). Implemented and verified on LOCAL: `tbl_season.enum_ranking_publication`, `fn_guard_season_publication_immutable`, and the `fn_ranking_full` boundary check (`supabase/migrations/20260919000009_ranking_publication_boundary.sql`). 1110 pgTAP assertions pass, and the real `SPWS-2025-2026` season is confirmed live on LOCAL to raise the exact boundary message from `fn_ranking_full` while `fn_ranking_kadra`/`fn_ranking_ppw` continue returning results for it unchanged.
**Date:** 2026-09-19
**Extends:** [ADR-098](098-ranking-schema-v2-and-generalized-ranking-rpc.md) (adds a check to the same `fn_ranking_full` that ADR-098 introduced)
**Supersedes:** [ADR-017](017-season-configurable-evf-toggle.md)'s historical PPW/+EVF presentation rule, per the design's own [§12](../plans/versioned-season-scoring-and-pzsz-ranking-design.html#adrs) note
**Relates to:** [ADR-097](097-scoring-governance-lock-and-privileged-revision.md) (a stricter mechanism than the scoring lock, deliberately — see Alternatives), [ADR-036](036-prod-export-local-mirror.md) as amended 2026-07-14 (migrations run before the seed dump — the reason this ADR's own backfill needed a second home; see Consequences)
**Source:** `supabase/migrations/20260919000009_ranking_publication_boundary.sql`

## Context

The three spreadsheet-derived seasons (`SPWS-2023-2024` through `SPWS-2025-2026`) reproduce what the association's Excel workbooks already published — PPW-only material that never represented an official combined ranking. `SPWS-2026-2027` is the first season with a real, database-computed EVF+ total (ADR-098). Design §06 requires this distinction to be a stored, permanent fact rather than something inferred from a date comparison against "the active season," which would silently flip once `SPWS-2026-2027` itself becomes historical.

## Decision

### 1 · `tbl_season.enum_ranking_publication` (`PPW_ONLY` | `FULL`), `NOT NULL DEFAULT 'FULL'`

The three historical seasons are backfilled to `PPW_ONLY`; `SPWS-2026-2027` stays at its default, `FULL`. Every season created after this migration — through `fn_create_season` or `fn_create_season_with_skeletons`, neither of which needs to change — is `FULL` by construction, the same "column default alone does the work" pattern `enum_carryover_engine`'s own default (ADR-045) and `enum_default_ranking_mode`'s default (ADR-098) already use.

### 2 · Immutable by a column-scoped `BEFORE UPDATE` trigger, with no role exemption

`fn_guard_season_publication_immutable()` rejects `UPDATE tbl_season SET enum_ranking_publication = ...` whenever the new value differs from the old one — checked column-by-column like `fn_guard_scoring_config_write` already does for the scoring lock, not a blanket freeze on the row, so every other `tbl_season` column (dates, active flag, carry-over engine, scoring engine, lock timestamp) passes through untouched. Unlike the scoring lock's guards, this trigger carries **no** `current_user <> 'authenticated'` role exemption: nothing should ever change this value, including a future migration correcting a mistake, which is an explicit, reviewed `DROP TRIGGER`/`ALTER`/`CREATE TRIGGER` sequence in its own migration, not a bypass built in ahead of time.

### 3 · `fn_ranking_full` reads the capability first and raises before any aggregation runs

One lookup and one guard, added to the dispatcher (not each per-engine body — the check belongs where the season is first resolved, before the carry-over engine is even read):

```sql
SELECT enum_carryover_engine, enum_ranking_publication INTO v_engine, v_publication
  FROM tbl_season WHERE id_season = v_resolved_season;

IF v_publication = 'PPW_ONLY' THEN
  RAISE EXCEPTION 'Season % is PPW_ONLY and does not publish the full (SPWS+EVF+) ranking -- historical ranking publication boundary', v_resolved_season;
END IF;
```

The exact phrase **"historical ranking publication boundary"** is embedded in the error text deliberately — design §13 requires it to be the one searchable phrase used consistently across implementation, docs and the error message itself. Every other ranking function (`fn_ranking_ppw`, `fn_ranking_kadra`, `fn_fencer_scores_rolling`) and both of `fn_ranking_full`'s own per-engine bodies are untouched: a `PPW_ONLY` season's plain PPW ranking keeps working exactly as it does today, and no EVF/FIE result data is deleted or hidden from any other read path — only the combined-view RPC is restricted.

### 4 · The backfill needed a second home: the ADR-036 seed dump, not just the migration

Verified live during implementation: on a fresh `./scripts/reset-dev.sh` bootstrap, migrations run *before* the ADR-036 monolithic seed dump (`supabase/seed_prod_2026-09-12.sql`, loaded via `db.seed.sql_paths`) — so this migration's own `UPDATE tbl_season SET enum_ranking_publication = 'PPW_ONLY' WHERE txt_code IN (...)` runs against an empty table (correct and necessary for CERT/PROD, where the season rows already exist) and is then silently overwritten when the seed dump's `INSERT INTO tbl_season` statements recreate all four real seasons from scratch, defaulting the new column to `FULL`. A follow-up `UPDATE` inside the seed file itself would fare no better — it would trip the immutability trigger this same migration just created, the identical "migration blocks its own backfill" shape ADR-086/089/091/096 already document for this codebase's migrations-before-seed ordering. The only correct fix is baking the value directly into the seed's four `INSERT` statements (`enum_ranking_publication` added to the column list, `'PPW_ONLY'` for the three historical rows and `'FULL'` for `SPWS-2026-2027`), since `INSERT` never fires a `BEFORE UPDATE` trigger. Recorded here so it is not silently re-discovered.

## Alternatives considered

1. **"Older than the active season" logic.** Rejected per design §06: this would silently reclassify `SPWS-2026-2027` as PPW-only the moment a later season becomes active, when design explicitly requires it to "retain Ranking/PPW forever."
2. **A hardcoded date cutoff duplicated at each call site.** Rejected: one stored, queried fact is what makes the boundary a database invariant instead of a convention every new caller has to remember.
3. **Inferring publication from the assigned scoring engine.** Rejected: engine and publication are orthogonal facts (a season could in principle reuse an old engine while still being a first-class published season), and conflating them would make a future engine reuse silently change publication too.
4. **Enforcing only in the UI.** Rejected on the same grounds as every other governance decision in this codebase (ADR-097): a disabled button is presentation, not a guarantee.
5. **Governing this column through the existing scoring-config lock** (the same mechanism as `default_ranking_mode`). Rejected: publication capability is not something an administrator ever legitimately changes after the fact, even before a season scores its first result, whereas every field the scoring lock governs is ordinarily editable until that point. A different, stricter mechanism (permanent immutability, not "editable until first score") matches what the value actually means.

## Consequences

A historical season's underlying EVF/FIE result data is never deleted or hidden from other read paths (`fn_ranking_kadra`, raw queries, audit, future carry-over) — only the new combined-view RPC is restricted. A future season wanting to launch as `PPW_ONLY` (unlikely, but not impossible) needs an explicit migration statement, matching "migration/season-creation policy only" in design §06 literally. The frontend cannot yet observe or react to this column — that wiring, and the UI-level restriction design §06 also describes (season selection normalizing to PPW, the Ranking/PPW switch disappearing, drilldown/export/deep-link constraints), is design step 7, the same step that wires the live frontend onto `fn_ranking_full` in the first place.

Two pgTAP fixtures (`SS26.PUBLISH.03/07/08`'s `SS26-PUBLISH-PPWONLY` season) initially used a `schema_version: 2` `json_ranking_rules` shape and a birth year that computed to the wrong age category for that season's end year; both were fixture bugs, not product bugs — caught by `fn_assert_result_vcat`'s existing age-category trigger and by `fn_ranking_kadra`/`fn_ranking_ppw` legitimately returning nothing for a schema they do not read (those two functions are frozen to schema v1 per ADR-098 §4). Fixed by moving the fixture to the legacy shape those functions actually understand — matching what a real `PPW_ONLY` season looks like today — and correcting the birth year.

**New:**

- `supabase/migrations/20260919000009_ranking_publication_boundary.sql` — `enum_ranking_publication`, `tbl_season.enum_ranking_publication`, the historical backfill, `fn_guard_season_publication_immutable` + trigger, the `fn_ranking_full` boundary check.
- `supabase/seed_prod_2026-09-12.sql` — `enum_ranking_publication` added to the four `tbl_season` `INSERT` statements (see Decision §4).
- `supabase/tests/80_season_scoring_contract.sql` — `SS26.PUBLISH.01–10`, 10 new assertions (73 → 83), plan-tests written before the migration per the design's own §09.

**Test impact.** pgTAP 1100 → 1110 assertions (10 new, all passing on a database rebuilt from scratch via `./scripts/reset-dev.sh`). `postgrestools check` on `20260919000009_ranking_publication_boundary.sql`: the same `runningStatementWhileHoldingAccessExclusive`/`lockTimeoutWarning` advisories (9) already present, unaddressed, in the immediately-preceding schema-v2 migration (`20260919000007`) — a pre-existing, accepted pattern for this codebase's single-transaction schema+function migrations, not a new regression.

**Verified on LOCAL (2026-09-19).** All four real seasons carry the correct `enum_ranking_publication` after a from-scratch bootstrap. `fn_ranking_full` raises `... historical ranking publication boundary` for `SPWS-2025-2026` (a real `PPW_ONLY` season) and returns normally (zero rows, no error — the real `SPWS-2026-2027` season has no results yet for every combination checked) for `SPWS-2026-2027`. `fn_ranking_kadra`/`fn_ranking_ppw` against `SPWS-2025-2026` return their usual 24 rows each, confirming the restriction touches only `fn_ranking_full`.
