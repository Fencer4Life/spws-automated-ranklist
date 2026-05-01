-- =============================================================================
-- T9.0: Admin Auth Migration — REVOKE/GRANT Tests
-- =============================================================================
-- Tests 9.01–9.05 from doc/archive/MVP_development_plan.md §T9.0.
-- Verifies that write functions are revoked from anon/PUBLIC and granted
-- to authenticated only. Read-only fn_export_scoring_config stays anon.
-- =============================================================================

BEGIN;
-- Layer 6 (2026-04-30): targeted bypass of trg_assert_result_vcat for
-- legacy test fixtures whose dummy V-cats predate the FATAL invariant
-- guard. Targeted (not session_replication_role) so audit + status-
-- transition triggers stay live.
ALTER TABLE tbl_result DISABLE TRIGGER trg_assert_result_vcat;
SELECT plan(5);

-- ===== SETUP: Switch to anon role to test permission denied =====

-- 9.01 — fn_import_scoring_config permission denied as anon
SET LOCAL ROLE anon;
SELECT throws_ok(
  $$SELECT fn_import_scoring_config('{"id_season":1}'::JSONB)$$,
  '42501',
  NULL,
  '9.01: fn_import_scoring_config permission denied as anon'
);
RESET ROLE;

-- 9.02 — fn_calc_tournament_scores permission denied as anon
SET LOCAL ROLE anon;
SELECT throws_ok(
  $$SELECT fn_calc_tournament_scores(1)$$,
  '42501',
  NULL,
  '9.02: fn_calc_tournament_scores permission denied as anon'
);
RESET ROLE;

-- 9.03 — fn_export_scoring_config succeeds as anon (read-only)
SET LOCAL ROLE anon;
SELECT lives_ok(
  $$SELECT fn_export_scoring_config(1)$$,
  '9.03: fn_export_scoring_config succeeds as anon (read-only)'
);
RESET ROLE;

-- 9.04 — fn_import_scoring_config succeeds as authenticated
SET LOCAL ROLE authenticated;
-- Use a valid season ID from seed data (season 1)
SELECT lives_ok(
  $$SELECT fn_import_scoring_config('{"id_season":1,"num_mp_value":1.0}'::JSONB)$$,
  '9.04: fn_import_scoring_config succeeds as authenticated'
);
RESET ROLE;

-- 9.05 — fn_calc_tournament_scores succeeds as authenticated
-- Use GP1-V0-F-EPEE-2023-2024 — historical-season seed row that always has
-- results. (Looked up by txt_code; auto-generated id_tournament shifts when
-- splitter / cleanup migrations alter the seed.)
SET LOCAL ROLE authenticated;
SELECT lives_ok(
  format(
    $$SELECT fn_calc_tournament_scores(%s)$$,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-F-EPEE-2023-2024')
  ),
  '9.05: fn_calc_tournament_scores succeeds as authenticated'
);
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
