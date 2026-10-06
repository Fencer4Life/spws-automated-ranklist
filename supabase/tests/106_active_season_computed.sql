-- =============================================================================
-- The active season is computed on read (ADR-031 amendment 2026-10-06)
-- =============================================================================
-- Tests 106.1–106.13. "Active" is a pure function of the season dates and
-- today, so the database derives it on every read and stores nothing:
-- nothing has to refresh it, and an anonymous visitor only ever reads.
--
-- Tests choose "today" with set_config('spws.today', <date>, true), which
-- fn_today() reads before CURRENT_DATE. The two seasons below sit far in the
-- future so no real season can overlap them, and the transaction rolls back.
-- Plan: doc/plans/active-season-computed-on-read-2026-10-06.html (option V).
-- =============================================================================

BEGIN;
SELECT plan(13);

-- 106.1 — the stored flag is gone
SELECT hasnt_column('public', 'tbl_season', 'bool_active',
  '106.1: tbl_season stores no bool_active column');

-- 106.2 — without a test date, today is the database's date
SELECT is(fn_today(), CURRENT_DATE,
  '106.2: fn_today() is CURRENT_DATE when spws.today is unset');

-- 106.3 — a test date wins
SELECT set_config('spws.today', '2031-02-03', true);
SELECT is(fn_today(), '2031-02-03'::date,
  '106.3: fn_today() returns spws.today when a test sets it');

INSERT INTO tbl_season (txt_code, dt_start, dt_end) VALUES
  ('AS-A', '2081-07-01', '2082-06-30'),
  ('AS-B', '2082-07-15', '2083-06-30');

-- 106.4 — a date inside a season makes that season active
SELECT set_config('spws.today', '2081-10-01', true);
SELECT is(fn_active_season_id(), (SELECT id_season FROM tbl_season WHERE txt_code = 'AS-A'),
  '106.4: fn_active_season_id() is the season whose dates contain today');

-- 106.5 — s.bool_active marks exactly that season, and nothing stores it
SELECT is(ARRAY(SELECT s.txt_code::text FROM tbl_season s WHERE s.bool_active ORDER BY 1),
  ARRAY['AS-A'],
  '106.5: s.bool_active is true for that season only');

-- 106.6 — between two seasons, the nearest future one is active
SELECT set_config('spws.today', '2082-07-05', true);
SELECT is(fn_active_season_id(), (SELECT id_season FROM tbl_season WHERE txt_code = 'AS-B'),
  '106.6: between seasons, the nearest future season is active');

-- 106.7 — after the last season, none is active
SELECT set_config('spws.today', '2090-01-01', true);
SELECT is(ARRAY(SELECT s.txt_code::text FROM tbl_season s WHERE s.bool_active),
  ARRAY[]::text[],
  '106.7: after the last season, no season is active');

-- 106.8 — nothing rewrites a flag: adding seasons and moving today leave no
-- tbl_season audit row in this transaction (the old trigger wrote two per
-- refresh: the active row set false, then true again).
SELECT is(
  (SELECT count(*) FROM tbl_audit_log WHERE txt_table_name = 'tbl_season'
     AND ts_created >= now()),
  0::bigint,
  '106.8: adding seasons and moving today write no tbl_season audit row');

-- 106.9 — the writer is gone
SELECT hasnt_function('public', 'fn_refresh_active_season', ARRAY[]::text[],
  '106.9: fn_refresh_active_season() no longer exists');

-- 106.10 — and so is the trigger that called it
SELECT hasnt_trigger('public', 'tbl_season', 'trg_season_refresh_active',
  '106.10: trg_season_refresh_active no longer exists');

-- 106.11 — an anonymous visitor can read the active season
SELECT ok(
  has_function_privilege('anon', 'public.fn_today()', 'EXECUTE')
  AND has_function_privilege('anon', 'public.fn_active_season_id()', 'EXECUTE')
  AND has_function_privilege('anon', 'public.bool_active(public.tbl_season)', 'EXECUTE'),
  '106.11: anon can EXECUTE fn_today(), fn_active_season_id() and bool_active(tbl_season)');

-- 106.12 — a reader that names the season without an alias follows today
SELECT set_config('spws.today', '2081-10-01', true);
SELECT is(fn_season_summary() ->> 'season_code', 'AS-A',
  '106.12: fn_season_summary() reports the season active on the test date');

-- 106.13 — and reports none after the last season
SELECT set_config('spws.today', '2090-01-01', true);
SELECT throws_ok('SELECT fn_season_summary()', 'P0001', 'No active season',
  '106.13: fn_season_summary() raises "No active season" after the last season');

SELECT * FROM finish();
ROLLBACK;
