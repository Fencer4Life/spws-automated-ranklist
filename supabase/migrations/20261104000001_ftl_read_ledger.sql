-- =============================================================================
-- ADR-120 §1: the day's FencingTimeLive allowance
-- =============================================================================
-- FTL blocked the pipeline's account after one day of about 700 requests and
-- 13 sign-ins (1 Nov 2026), and nothing counted them. Every FTL request and
-- sign-in is now drawn from this ledger before it is sent: one row per day in
-- Warsaw, a draw granted up to the cap the caller names (the code holds the
-- cap, ADR-120 F1), a sign-in all or nothing, and what a run did not use given
-- back when its client closes. CI and LOCAL draw from the same row (F2), so the
-- count is the account's. Rows older than 90 days are pruned by the next draw.
--
-- Counts only: no person, no event, no credential. Written on CERT (and LOCAL)
-- only; the PROD seed export names its tables one by one and never this one.
--
-- Plan: doc/plans/ftl-daily-read-budget-2026-11-04.html (S1).
-- Tests: supabase/tests/125_ftl_read_ledger.sql (FTL.LEDGER).
-- =============================================================================

CREATE TABLE IF NOT EXISTS tbl_ftl_read_ledger (
  dt_day         DATE PRIMARY KEY,
  int_requests   INTEGER NOT NULL DEFAULT 0 CONSTRAINT ck_ftl_read_ledger_requests CHECK (int_requests >= 0),
  int_sign_ins   INTEGER NOT NULL DEFAULT 0 CONSTRAINT ck_ftl_read_ledger_sign_ins CHECK (int_sign_ins >= 0),
  ts_updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE tbl_ftl_read_ledger IS
  'ADR-120 §1: FencingTimeLive requests and sign-ins drawn per Warsaw day, CI and LOCAL alike, against the cap the code names. Counts only; CERT only.';

ALTER TABLE tbl_ftl_read_ledger ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON tbl_ftl_read_ledger FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON tbl_ftl_read_ledger TO service_role;

-- Draws requests (up to the cap) and sign-ins (whole or none) for a day.
CREATE OR REPLACE FUNCTION fn_ftl_ledger_take(
  p_day          DATE,
  p_requests     INTEGER,
  p_sign_ins     INTEGER,
  p_cap_requests INTEGER,
  p_cap_sign_ins INTEGER)
RETURNS JSONB
LANGUAGE plpgsql VOLATILE
SET search_path = public
AS $$
DECLARE
  v_row       tbl_ftl_read_ledger;
  v_requests  INTEGER;
  v_sign_ins  INTEGER;
BEGIN
  IF p_day IS NULL
     OR p_requests IS NULL OR p_requests < 0
     OR p_sign_ins IS NULL OR p_sign_ins < 0
     OR p_cap_requests IS NULL OR p_cap_requests < 0
     OR p_cap_sign_ins IS NULL OR p_cap_sign_ins < 0 THEN
    RAISE EXCEPTION 'FTL_LEDGER: a draw takes no negative or missing amounts, and names its caps';
  END IF;

  -- Two runs drawing at once are counted in order.
  PERFORM pg_advisory_xact_lock(hashtext('fn_ftl_ledger'));

  INSERT INTO tbl_ftl_read_ledger (dt_day) VALUES (p_day) ON CONFLICT (dt_day) DO NOTHING;
  SELECT * INTO v_row FROM tbl_ftl_read_ledger WHERE dt_day = p_day;

  v_requests := LEAST(p_requests, GREATEST(p_cap_requests - v_row.int_requests, 0));
  v_sign_ins := CASE WHEN v_row.int_sign_ins + p_sign_ins <= p_cap_sign_ins THEN p_sign_ins ELSE 0 END;

  UPDATE tbl_ftl_read_ledger
     SET int_requests = int_requests + v_requests,
         int_sign_ins = int_sign_ins + v_sign_ins,
         ts_updated_at = now()
   WHERE dt_day = p_day
  RETURNING * INTO v_row;

  DELETE FROM tbl_ftl_read_ledger WHERE dt_day < current_date - 90;

  RETURN jsonb_build_object(
    'requests', v_requests,
    'sign_ins', v_sign_ins,
    'used_requests', v_row.int_requests,
    'used_sign_ins', v_row.int_sign_ins,
    'cap_requests', p_cap_requests,
    'cap_sign_ins', p_cap_sign_ins);
END;
$$;

COMMENT ON FUNCTION fn_ftl_ledger_take(DATE, INTEGER, INTEGER, INTEGER, INTEGER) IS
  'ADR-120 §1: draw FTL requests (granted up to the cap) and sign-ins (whole or none) for a Warsaw day; returns what was granted and the day''s totals.';

REVOKE ALL ON FUNCTION fn_ftl_ledger_take(DATE, INTEGER, INTEGER, INTEGER, INTEGER) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_ftl_ledger_take(DATE, INTEGER, INTEGER, INTEGER, INTEGER) TO service_role;

-- Gives back requests a run drew and did not use.
CREATE OR REPLACE FUNCTION fn_ftl_ledger_give_back(
  p_day      DATE,
  p_requests INTEGER)
RETURNS JSONB
LANGUAGE plpgsql VOLATILE
SET search_path = public
AS $$
DECLARE
  v_used INTEGER;
BEGIN
  IF p_day IS NULL OR p_requests IS NULL OR p_requests < 0 THEN
    RAISE EXCEPTION 'FTL_LEDGER: a give-back takes no negative or missing amount';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('fn_ftl_ledger'));

  UPDATE tbl_ftl_read_ledger
     SET int_requests = GREATEST(int_requests - p_requests, 0),
         ts_updated_at = now()
   WHERE dt_day = p_day
  RETURNING int_requests INTO v_used;

  RETURN jsonb_build_object('used_requests', COALESCE(v_used, 0));
END;
$$;

COMMENT ON FUNCTION fn_ftl_ledger_give_back(DATE, INTEGER) IS
  'ADR-120 §1: give back FTL requests a run drew and did not use; never below zero.';

REVOKE ALL ON FUNCTION fn_ftl_ledger_give_back(DATE, INTEGER) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_ftl_ledger_give_back(DATE, INTEGER) TO service_role;
