-- =============================================================================
-- ADR-049 (joint-pool split, 2026-04-30):
-- bool_joint_pool_split column coverage; fn_backfill_joint_pool_split() retired.
--
-- Tests 25.1-25.2: column + index shape (lock-in for migration
--                  20260430000003_joint_pool_split.sql).
-- Test  25.3:      the one-shot backfill is retired (migration
--                  20261001000001_retire_fn_backfill_joint_pool_split.sql;
--                  ADR-049 amendment 2026-10-01).
-- =============================================================================

BEGIN;
SELECT plan(3);


-- ===== 25.1 — column shape =====
SELECT col_type_is(
  'tbl_tournament', 'bool_joint_pool_split', 'boolean',
  '25.1: bool_joint_pool_split is BOOLEAN NOT NULL DEFAULT FALSE'
);


-- ===== 25.2 — partial index exists =====
SELECT is(
  (SELECT COUNT(*)::INT FROM pg_indexes
    WHERE tablename = 'tbl_tournament'
      AND indexname = 'idx_tbl_tournament_joint_split'),
  1,
  '25.2: idx_tbl_tournament_joint_split partial index exists'
);


-- ===== 25.3 — the one-shot backfill is retired =====
-- ADR-049 amendment 2026-10-01: fn_backfill_joint_pool_split() ran once on
-- LOCAL, CERT and PROD (2026-04-30). Run again across the database it rewrites
-- N wrongly for international events (full-field N, ADR-038) and for 2026/27
-- joined brackets (whole-bracket N, ADR-104), so it is dropped rather than
-- kept callable. Its semantics tests (former 25.4–25.7) go with it.
SELECT hasnt_function(
  'fn_backfill_joint_pool_split',
  '25.3: fn_backfill_joint_pool_split() is retired (ADR-049 amendment 2026-10-01)'
);


ROLLBACK;
