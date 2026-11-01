-- =============================================================================
-- pgTAP — SYNC.PAUSE: the results sync's pause and last cycle (ADR-119 §4, D8)
-- =============================================================================
-- Verifies migration 20261101000001_results_sync_event.sql. A failed cycle of
-- the hourly results sync pauses its event, with the failure's reason and the
-- Actions run; sync <code> or a finished manual ingest lifts it. Every cycle
-- records its time and verdict on the same row. The store is service_role
-- only, one row per event, never deleted. Everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(16);

INSERT INTO tbl_season (txt_code, dt_start, dt_end) VALUES ('SPWS-2087-2088', DATE '2087-09-01', DATE '2088-06-30');
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, enum_status)
SELECT 'PPW7-2087-2088', 'SYNC fixture', id_season, (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
       DATE '2087-10-10', DATE '2087-10-11', 'PLANNED'
  FROM tbl_season WHERE txt_code = 'SPWS-2087-2088';

-- 123.1 — service_role only (ADR-083)
SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE relname = 'tbl_results_sync_event'),
  '123.1a — RLS is on'
);
SELECT ok(
  NOT has_table_privilege('anon', 'tbl_results_sync_event', 'SELECT')
  AND NOT has_table_privilege('authenticated', 'tbl_results_sync_event', 'SELECT'),
  '123.1b — anon and authenticated cannot read a pause'
);
SELECT ok(
  NOT has_function_privilege('anon', 'fn_results_sync_pause(text, text, text)', 'EXECUTE')
  AND NOT has_function_privilege('authenticated', 'fn_results_sync_pause(text, text, text)', 'EXECUTE')
  AND NOT has_function_privilege('anon', 'fn_results_sync_resume(text)', 'EXECUTE')
  AND NOT has_function_privilege('authenticated', 'fn_results_sync_resume(text)', 'EXECUTE')
  AND NOT has_function_privilege('anon', 'fn_results_sync_cycle(text, text)', 'EXECUTE')
  AND NOT has_function_privilege('authenticated', 'fn_results_sync_cycle(text, text)', 'EXECUTE'),
  '123.1c — anon and authenticated cannot pause, resume or record a cycle'
);
SELECT ok(
  has_function_privilege('service_role', 'fn_results_sync_pause(text, text, text)', 'EXECUTE')
  AND has_function_privilege('service_role', 'fn_results_sync_resume(text)', 'EXECUTE')
  AND has_function_privilege('service_role', 'fn_results_sync_cycle(text, text)', 'EXECUTE')
  AND has_table_privilege('service_role', 'tbl_results_sync_event', 'SELECT'),
  '123.1d — service_role pauses, resumes, records cycles and reads the pauses'
);
SELECT ok(
  NOT has_table_privilege('service_role', 'tbl_results_sync_event', 'DELETE'),
  '123.1e — a row is never deleted'
);

-- 123.2 — a failed cycle pauses the event
SELECT fn_results_sync_pause('PPW7-2087-2088', 'identity, Women''s Foil V1',
                             'https://github.com/Fencer4Life/SPWSranklist/actions/runs/77');
SELECT ok(
  (SELECT ts_paused_at = now()
          AND txt_paused_reason = 'identity, Women''s Foil V1'
          AND url_paused_by_run = 'https://github.com/Fencer4Life/SPWSranklist/actions/runs/77'
     FROM tbl_results_sync_event WHERE txt_event_code = 'PPW7-2087-2088'),
  '123.2a — the pause holds its time, reason and Actions run'
);
SELECT throws_like(
  $$SELECT fn_results_sync_pause('PPW7-2087-2088', '  ', NULL)$$,
  'RESULTS_SYNC_PAUSE_REASON%',
  '123.2b — a pause without a reason is refused'
);
SELECT throws_ok(
  $$SELECT fn_results_sync_pause('PPW7-2087-2088', 'x', 'https://example.org/runs/1')$$,
  '23514',
  NULL,
  '123.2c — a run URL that is not an Actions run is refused'
);
SELECT throws_like(
  $$SELECT fn_results_sync_pause('PPW8-2087-2088', 'x', NULL)$$,
  'RESULTS_SYNC_EVENT_NOT_FOUND%',
  '123.2d — an event that does not exist cannot be paused'
);

-- 123.3 — every cycle records its time and verdict on the same row
SELECT fn_results_sync_cycle('PPW7-2087-2088', 'failed');
SELECT ok(
  (SELECT ts_last_cycle_at = now() AND txt_last_verdict = 'failed' AND ts_paused_at IS NOT NULL
     FROM tbl_results_sync_event WHERE txt_event_code = 'PPW7-2087-2088'),
  '123.3a — the cycle is recorded and the pause stays'
);
SELECT throws_ok(
  $$SELECT fn_results_sync_cycle('PPW7-2087-2088', 'maybe')$$,
  '23514',
  NULL,
  '123.3b — an unknown verdict is refused'
);
SELECT is(
  (SELECT count(*)::INT FROM tbl_results_sync_event WHERE txt_event_code = 'PPW7-2087-2088'),
  1,
  '123.3c — one row per event'
);

-- 123.4 — sync <code> or a finished manual ingest lifts the pause
SELECT is(fn_results_sync_resume('PPW7-2087-2088'), TRUE, '123.4a — a paused event is resumed');
SELECT ok(
  (SELECT ts_paused_at IS NULL AND txt_paused_reason IS NULL AND url_paused_by_run IS NULL
          AND txt_last_verdict = 'failed'
     FROM tbl_results_sync_event WHERE txt_event_code = 'PPW7-2087-2088'),
  '123.4b — the pause is gone and the last cycle stays'
);
SELECT is(fn_results_sync_resume('PPW7-2087-2088'), FALSE, '123.4c — an event not paused stays as it is');

-- 123.5 — a pause is whole: a time and a reason, or neither
SELECT throws_ok(
  $$UPDATE tbl_results_sync_event SET ts_paused_at = now() WHERE txt_event_code = 'PPW7-2087-2088'$$,
  '23514',
  NULL,
  '123.5 — a pause without its reason cannot be stored'
);

SELECT * FROM finish();
ROLLBACK;
