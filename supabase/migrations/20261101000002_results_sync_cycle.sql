-- =============================================================================
-- ADR-119 §4 (G47 A): one scheduled results-sync cycle at a time
-- =============================================================================
-- GitHub starts this repository's crons hours late or not at all, so the
-- Telegram bot's hourly time trigger dispatches results-sync.yml as a
-- scheduled cycle, and GitHub's two cron lines stay as a backstop. Both may
-- start a cycle for one hour. Each scheduled select records its start here
-- first: a start within 20 minutes of the last one is refused, and its cycle
-- ends at the select; the day's ☀ line goes to the first morning cycle only,
-- so GitHub's morning run arriving hours after the bot's sends no second one.
--
-- One row per scheduled cycle begun: when, started by whom (cron or bot), the
-- Warsaw day it works on, and whether it sends that day's ☀ line. No person,
-- no event. A manual or dry run records nothing. Starts older than 30 days are
-- pruned by the next start. Written on CERT (and LOCAL) only: the PROD seed
-- export never names a results_sync table (SYNC.SEED.01).
--
-- Plan: doc/plans/partial-ingest-promote-results-sync-2026-10-31.html (G47).
-- Tests: supabase/tests/124_results_sync_cycle.sql (SYNC.DEDUP).
-- =============================================================================

CREATE TABLE IF NOT EXISTS tbl_results_sync_cycle (
  id_cycle          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  ts_begun_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  txt_trigger       TEXT NOT NULL CONSTRAINT ck_results_sync_cycle_trigger
                      CHECK (txt_trigger IN ('cron', 'bot')),
  dt_day            DATE NOT NULL,
  bool_morning_line BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS ix_results_sync_cycle_begun ON tbl_results_sync_cycle (ts_begun_at DESC);

COMMENT ON TABLE tbl_results_sync_cycle IS
  'ADR-119 §4 (G47 A): the starts of scheduled results-sync cycles (bot or cron), so one cycle runs at a time and the day''s morning line is sent once. CERT only; no person, no event.';

ALTER TABLE tbl_results_sync_cycle ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON tbl_results_sync_cycle FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT, INSERT, DELETE ON tbl_results_sync_cycle TO service_role;

-- Begins a scheduled cycle, or refuses one within 20 minutes of the last.
CREATE OR REPLACE FUNCTION fn_results_sync_begin(
  p_trigger TEXT,
  p_morning BOOLEAN,
  p_day     DATE)
RETURNS JSONB
LANGUAGE plpgsql VOLATILE
SET search_path = public
AS $$
DECLARE
  v_last    TIMESTAMPTZ;
  v_morning BOOLEAN;
BEGIN
  IF p_trigger IS NULL OR p_trigger NOT IN ('cron', 'bot') THEN
    RAISE EXCEPTION 'RESULTS_SYNC_TRIGGER: a scheduled cycle is started by cron or bot, not %',
      COALESCE(p_trigger, 'nobody');
  END IF;

  -- Two starts at once (the bot and an on-time cron) are told apart in order.
  PERFORM pg_advisory_xact_lock(hashtext('fn_results_sync_begin'));

  SELECT max(ts_begun_at) INTO v_last FROM tbl_results_sync_cycle;
  IF v_last IS NOT NULL AND v_last > now() - interval '20 minutes' THEN
    RETURN jsonb_build_object(
      'begun', FALSE,
      'minutes', floor(extract(epoch FROM now() - v_last) / 60)::int);
  END IF;

  v_morning := COALESCE(p_morning, FALSE) AND NOT EXISTS (
    SELECT 1 FROM tbl_results_sync_cycle WHERE dt_day = p_day AND bool_morning_line);

  INSERT INTO tbl_results_sync_cycle (txt_trigger, dt_day, bool_morning_line)
  VALUES (p_trigger, p_day, v_morning);

  DELETE FROM tbl_results_sync_cycle WHERE ts_begun_at < now() - interval '30 days';

  RETURN jsonb_build_object('begun', TRUE, 'morning_line', v_morning);
END;
$$;

COMMENT ON FUNCTION fn_results_sync_begin(TEXT, BOOLEAN, DATE) IS
  'ADR-119 §4 (G47 A): begin a scheduled results-sync cycle ({"begun": true, "morning_line": …}), or refuse one within 20 minutes of the last ({"begun": false, "minutes": …}).';

REVOKE ALL ON FUNCTION fn_results_sync_begin(TEXT, BOOLEAN, DATE) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_results_sync_begin(TEXT, BOOLEAN, DATE) TO service_role;
