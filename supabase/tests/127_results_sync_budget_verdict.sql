-- =============================================================================
-- pgTAP — SYNC.BUDGET: a cycle stopped by FTL's daily cap is recorded as such (ADR-120 §3)
-- =============================================================================
-- Verifies migration 20261104000003_results_sync_budget_verdict.sql. When the
-- day's FTL allowance is spent, a cycle reads and writes nothing and pauses
-- nothing; its verdict "budget" is recorded on the event's row like any other.
-- An unknown verdict is still refused. Everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(3);

INSERT INTO tbl_season (txt_code, dt_start, dt_end) VALUES ('SPWS-2087-2088', DATE '2087-09-01', DATE '2088-06-30');
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, enum_status)
SELECT 'PPW7-2087-2088', 'SYNC fixture', id_season, (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
       DATE '2087-10-10', DATE '2087-10-11', 'PLANNED'
  FROM tbl_season WHERE txt_code = 'SPWS-2087-2088';

SELECT lives_ok(
  $$SELECT fn_results_sync_cycle('PPW7-2087-2088', 'budget')$$,
  '127.1a — a cycle stopped by the cap is recorded'
);
SELECT is(
  (SELECT txt_last_verdict FROM tbl_results_sync_event WHERE txt_event_code = 'PPW7-2087-2088'),
  'budget',
  '127.1b — with the verdict budget, and no pause'
);
SELECT throws_ok(
  $$SELECT fn_results_sync_cycle('PPW7-2087-2088', 'over_budget')$$,
  '23514',
  NULL,
  '127.2 — an unknown verdict is still refused'
);

SELECT * FROM finish();
ROLLBACK;
