-- =============================================================================
-- ADR-119 §4 (D8): the results sync's pause and last cycle, per event
-- =============================================================================
-- The hourly results sync (results-sync.yml) ingests an event on CERT and
-- promotes it to PROD while it runs. Any failed step of a cycle pauses the
-- event: the select skips it until an administrator sends `sync <code>` (the
-- manual dispatch lifts the pause before its cycle) or a manual ingest of it
-- finishes. A pause is never lifted by time or by the organiser publishing more.
--
-- One row per event: when it was paused, why (the failure's kind and listing,
-- never a person: the morning line and the Actions log show it, and the
-- refusal itself stays on the CERT run row, D12), by which Actions run, and
-- the last cycle's time and verdict. Written on CERT (and LOCAL) only: the PROD
-- seed export names every table it writes, and never this one (SYNC.SEED.01).
--
-- Plan: doc/plans/partial-ingest-promote-results-sync-2026-10-31.html (§03e, S5).
-- Tests: supabase/tests/123_results_sync_event.sql (SYNC.PAUSE).
-- =============================================================================

CREATE TABLE IF NOT EXISTS tbl_results_sync_event (
  txt_event_code    TEXT PRIMARY KEY,
  ts_paused_at      TIMESTAMPTZ,
  txt_paused_reason TEXT,
  url_paused_by_run TEXT CONSTRAINT ck_results_sync_paused_by_run
                      CHECK (url_paused_by_run ~ '^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/actions/runs/[0-9]+$'),
  ts_last_cycle_at  TIMESTAMPTZ,
  txt_last_verdict  TEXT CONSTRAINT ck_results_sync_last_verdict
                      CHECK (txt_last_verdict IN ('unchanged', 'promoted', 'nothing_final', 'failed',
                                                  'blocked', 'refused', 'stopped')),
  CONSTRAINT ck_results_sync_pause_whole
    CHECK ((ts_paused_at IS NULL) = (txt_paused_reason IS NULL)
           AND (ts_paused_at IS NOT NULL OR url_paused_by_run IS NULL))
);

COMMENT ON TABLE tbl_results_sync_event IS
  'ADR-119 §4 (D8): the results sync''s pause and last cycle, one row per event. A paused event is skipped until sync <code> or a finished manual ingest lifts it. CERT only; reasons name no person.';

ALTER TABLE tbl_results_sync_event ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON tbl_results_sync_event FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE ON tbl_results_sync_event TO service_role;

-- Pauses an event: its failure's reason and the Actions run that failed.
CREATE OR REPLACE FUNCTION fn_results_sync_pause(
  p_event_code TEXT,
  p_reason     TEXT,
  p_run_url    TEXT)
RETURNS VOID
LANGUAGE plpgsql VOLATILE
SET search_path = public
AS $$
DECLARE
  v_reason TEXT := NULLIF(btrim(COALESCE(p_reason, '')), '');
BEGIN
  IF NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = p_event_code) THEN
    RAISE EXCEPTION 'RESULTS_SYNC_EVENT_NOT_FOUND: %', p_event_code;
  END IF;
  IF v_reason IS NULL THEN
    RAISE EXCEPTION 'RESULTS_SYNC_PAUSE_REASON: a pause names its reason';
  END IF;

  INSERT INTO tbl_results_sync_event (txt_event_code, ts_paused_at, txt_paused_reason, url_paused_by_run)
  VALUES (p_event_code, now(), v_reason, p_run_url)
  ON CONFLICT (txt_event_code) DO UPDATE
    SET ts_paused_at = now(), txt_paused_reason = v_reason, url_paused_by_run = p_run_url;
END;
$$;

COMMENT ON FUNCTION fn_results_sync_pause(TEXT, TEXT, TEXT) IS
  'ADR-119 §4 (D8): pause the results sync of an event, with the failure''s reason (no person) and the Actions run.';

-- Lifts an event's pause; true when it was paused.
CREATE OR REPLACE FUNCTION fn_results_sync_resume(p_event_code TEXT)
RETURNS BOOLEAN
LANGUAGE sql VOLATILE
SET search_path = public
AS $$
  WITH lifted AS (
    UPDATE tbl_results_sync_event
       SET ts_paused_at = NULL, txt_paused_reason = NULL, url_paused_by_run = NULL
     WHERE txt_event_code = p_event_code AND ts_paused_at IS NOT NULL
    RETURNING 1)
  SELECT EXISTS (SELECT 1 FROM lifted);
$$;

COMMENT ON FUNCTION fn_results_sync_resume(TEXT) IS
  'ADR-119 §4 (D8): lift the results sync''s pause of an event (sync <code>, or a finished manual ingest); true when it was paused.';

-- Records a cycle of an event: the database's time and the cycle's verdict.
CREATE OR REPLACE FUNCTION fn_results_sync_cycle(p_event_code TEXT, p_verdict TEXT)
RETURNS VOID
LANGUAGE plpgsql VOLATILE
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = p_event_code) THEN
    RAISE EXCEPTION 'RESULTS_SYNC_EVENT_NOT_FOUND: %', p_event_code;
  END IF;

  INSERT INTO tbl_results_sync_event (txt_event_code, ts_last_cycle_at, txt_last_verdict)
  VALUES (p_event_code, now(), p_verdict)
  ON CONFLICT (txt_event_code) DO UPDATE
    SET ts_last_cycle_at = now(), txt_last_verdict = p_verdict;
END;
$$;

COMMENT ON FUNCTION fn_results_sync_cycle(TEXT, TEXT) IS
  'ADR-119 §4 (D7): record the time and verdict of the results sync''s latest cycle of an event.';

REVOKE ALL ON FUNCTION fn_results_sync_pause(TEXT, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_results_sync_resume(TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_results_sync_cycle(TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_results_sync_pause(TEXT, TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION fn_results_sync_resume(TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION fn_results_sync_cycle(TEXT, TEXT) TO service_role;
