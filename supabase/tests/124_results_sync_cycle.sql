-- =============================================================================
-- pgTAP — SYNC.DEDUP: one scheduled results-sync cycle at a time (ADR-119 §4, G47 A)
-- =============================================================================
-- Verifies migration 20261101000002_results_sync_cycle.sql. The Telegram bot's
-- hourly trigger and GitHub's two cron lines (the backstop) both start
-- scheduled cycles; each select records its start first. A start within 20
-- minutes of the last one is refused and its cycle ends at the select; the
-- day's ☀ line goes to the first morning cycle only. Starts older than 30 days
-- are pruned. The store is service_role only. Everything rolls back; now() is
-- the transaction's start, so earlier starts are made by moving rows back.
-- =============================================================================

BEGIN;

SELECT plan(13);

-- fn_results_sync_begin reads the latest of every start: clear those recorded before this test.
DELETE FROM tbl_results_sync_cycle WHERE ts_begun_at <= now();

-- 124.1 — service_role only (ADR-083)
SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE relname = 'tbl_results_sync_cycle'),
  '124.1a — RLS is on'
);
SELECT ok(
  NOT has_table_privilege('anon', 'tbl_results_sync_cycle', 'SELECT')
  AND NOT has_table_privilege('authenticated', 'tbl_results_sync_cycle', 'SELECT'),
  '124.1b — anon and authenticated cannot read the starts'
);
SELECT ok(
  NOT has_function_privilege('anon', 'fn_results_sync_begin(text, boolean, date)', 'EXECUTE')
  AND NOT has_function_privilege('authenticated', 'fn_results_sync_begin(text, boolean, date)', 'EXECUTE'),
  '124.1c — anon and authenticated cannot start a cycle'
);

-- 124.2 — the first start of the day begins, and a morning start sends the ☀ line
SELECT is(
  fn_results_sync_begin('bot', TRUE, DATE '2087-11-14'),
  '{"begun": true, "morning_line": true}'::jsonb,
  '124.2 — the first morning start begins and sends the morning line'
);

-- 124.3 — within 20 minutes of the last start, a second one ends at its select
SELECT is(
  fn_results_sync_begin('cron', TRUE, DATE '2087-11-14'),
  '{"begun": false, "minutes": 0}'::jsonb,
  '124.3a — a start in the same minute is refused'
);
SELECT is(
  (SELECT count(*)::int FROM tbl_results_sync_cycle),
  1,
  '124.3b — a refused start is not recorded'
);
UPDATE tbl_results_sync_cycle SET ts_begun_at = now() - interval '19 minutes 59 seconds' WHERE dt_day >= DATE '2087-11-14';
SELECT is(
  fn_results_sync_begin('cron', FALSE, DATE '2087-11-14'),
  '{"begun": false, "minutes": 19}'::jsonb,
  '124.3c — 19 minutes 59 seconds later it is still refused, and says how long ago'
);

-- 124.4 — 20 minutes later a start begins; the day's ☀ line is not sent again
UPDATE tbl_results_sync_cycle SET ts_begun_at = now() - interval '20 minutes' WHERE dt_day >= DATE '2087-11-14';
SELECT is(
  fn_results_sync_begin('cron', TRUE, DATE '2087-11-14'),
  '{"begun": true, "morning_line": false}'::jsonb,
  '124.4a — GitHub''s late morning run still syncs, and sends no second ☀ line'
);
UPDATE tbl_results_sync_cycle SET ts_begun_at = ts_begun_at - interval '1 hour' WHERE dt_day >= DATE '2087-11-14';
SELECT is(
  fn_results_sync_begin('bot', FALSE, DATE '2087-11-14'),
  '{"begun": true, "morning_line": false}'::jsonb,
  '124.4b — an hourly start sends no ☀ line'
);
UPDATE tbl_results_sync_cycle SET ts_begun_at = ts_begun_at - interval '1 day' WHERE dt_day >= DATE '2087-11-14';
SELECT is(
  fn_results_sync_begin('bot', TRUE, DATE '2087-11-15'),
  '{"begun": true, "morning_line": true}'::jsonb,
  '124.4c — the next day''s first morning start sends its ☀ line'
);

-- 124.5 — a start says who started it
SELECT throws_ok(
  $$SELECT fn_results_sync_begin('manual', FALSE, DATE '2087-11-15')$$,
  'P0001',
  'RESULTS_SYNC_TRIGGER: a scheduled cycle is started by cron or bot, not manual',
  '124.5 — only cron and bot start a scheduled cycle'
);

-- 124.6 — starts older than 30 days are pruned by the next start
UPDATE tbl_results_sync_cycle SET ts_begun_at = now() - interval '31 days' WHERE dt_day >= DATE '2087-11-14';
SELECT is(
  (fn_results_sync_begin('cron', FALSE, DATE '2087-12-16') ->> 'begun')::boolean,
  TRUE,
  '124.6a — a start after a month begins'
);
SELECT is(
  (SELECT count(*)::int FROM tbl_results_sync_cycle),
  1,
  '124.6b — only that start is left'
);

SELECT * FROM finish();
ROLLBACK;
