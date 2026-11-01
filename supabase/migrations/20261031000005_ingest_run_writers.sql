-- ============================================================================
-- The run row's writers: the promote ledger and the prior (ADR-119 §3: D10, G17)
-- ============================================================================
-- tbl_ingest_run.jsonb_promote (added by 20261031000004) holds the outcome of
-- the latest promote of a CERT run on PROD: applied, skipped or refused, the
-- fingerprint PROD holds, the reason, the Actions run, and the database's
-- time. Promote writes it through fn_ingest_run_promote (service role only)
-- with a writable Management-API transport used for this one write; a failed
-- ledger write never fails a promote. The daily close quotes it.
--
-- tbl_ingest_run.txt_prior_fingerprint (added by 20261031000004) is the result
-- fingerprint the event held when the run began (B3), or NULL. The recorded
-- ingest reads it before the run opens, and fn_ingest_run_open stores it. The
-- open gains it as a last parameter with a default, so the code before
-- release 2, which calls by name without it, keeps working; the old signature
-- is dropped so PostgREST never sees two overloads.
--
-- pgTAP: supabase/tests/121_ingest_run_promote.sql (LEDGER.01),
-- 122_ingest_run_prior.sql (RUN.PRIOR.01-04).
-- ============================================================================

COMMENT ON COLUMN tbl_ingest_run.jsonb_promote IS
  'ADR-119 §3 (D10): the latest promote of this CERT run on PROD: {outcome: applied|skipped|refused, fingerprint, reason, run_url, ts}. Written by fn_ingest_run_promote; the daily close quotes it.';

COMMENT ON COLUMN tbl_ingest_run.txt_prior_fingerprint IS
  'ADR-119 §3 (G17): the result fingerprint the event held when the run began (B3), or NULL when it held none. Written by fn_ingest_run_open; promote accepts PROD holding exactly it.';

CREATE OR REPLACE FUNCTION fn_ingest_run_promote(p_id BIGINT, p_promote JSONB)
RETURNS VOID
LANGUAGE plpgsql VOLATILE
SET search_path = public
AS $$
DECLARE
  v_outcome TEXT := p_promote->>'outcome';
  v_fp      TEXT := p_promote->>'fingerprint';
  v_reason  TEXT := NULLIF(btrim(COALESCE(p_promote->>'reason', '')), '');
  v_url     TEXT := p_promote->>'run_url';
BEGIN
  IF v_outcome IS NULL OR v_outcome NOT IN ('applied', 'skipped', 'refused') THEN
    RAISE EXCEPTION 'INGEST_RUN_PROMOTE_OUTCOME: % is not applied, skipped or refused', v_outcome;
  END IF;
  IF v_outcome = 'refused' AND v_reason IS NULL THEN
    RAISE EXCEPTION 'INGEST_RUN_PROMOTE_REASON: a refusal names its reason';
  END IF;
  IF v_outcome IN ('applied', 'skipped') AND (v_fp IS NULL OR v_fp !~ '^[0-9a-f]{64}$') THEN
    RAISE EXCEPTION 'INGEST_RUN_PROMOTE_FINGERPRINT: % is not the fingerprint PROD holds', v_fp;
  END IF;
  IF v_url IS NOT NULL AND v_url !~ '^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/actions/runs/[0-9]+$' THEN
    RAISE EXCEPTION 'INGEST_RUN_PROMOTE_URL: % is not an Actions run', v_url;
  END IF;

  UPDATE tbl_ingest_run
     SET jsonb_promote = jsonb_build_object('outcome', v_outcome, 'fingerprint', v_fp, 'reason', v_reason,
                                            'run_url', v_url, 'ts', now())
   WHERE id_ingest_run = p_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'INGEST_RUN_NOT_FOUND: %', p_id;
  END IF;
END;
$$;

COMMENT ON FUNCTION fn_ingest_run_promote(BIGINT, JSONB) IS
  'ADR-119 §3 (D10): record the outcome of the latest promote of a CERT run on PROD on its row (the ledger); the time is the database''s.';

REVOKE ALL ON FUNCTION fn_ingest_run_promote(BIGINT, JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_ingest_run_promote(BIGINT, JSONB) TO service_role;

-- ---------------------------------------------------------------------------
-- fn_ingest_run_open records the prior (G17); the definition of
-- 20261003000014_ingest_run.sql otherwise unchanged.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ingest_run_open(TEXT, TEXT, TEXT, INT, TEXT, TEXT, TEXT);

CREATE FUNCTION fn_ingest_run_open(
  p_event_code        TEXT,
  p_environment       TEXT,
  p_git_commit        TEXT,
  p_season_end_year   INT,
  p_url_event         TEXT,
  p_run_url           TEXT DEFAULT NULL,
  p_override_sha256   TEXT DEFAULT NULL,
  p_prior_fingerprint TEXT DEFAULT NULL)
RETURNS BIGINT
LANGUAGE plpgsql VOLATILE
SET search_path = public
AS $$
DECLARE
  v_input JSONB;
  v_id    BIGINT;
BEGIN
  v_input := fn_event_input_fingerprint(p_event_code);

  INSERT INTO tbl_ingest_run (txt_event_code, txt_environment, txt_git_commit, txt_run_url, int_season_end_year,
                              url_event, txt_override_sha256, txt_input_fingerprint, jsonb_input_parts,
                              jsonb_roster_before, txt_prior_fingerprint)
  VALUES (p_event_code, p_environment, p_git_commit, p_run_url, p_season_end_year,
          p_url_event, p_override_sha256, v_input->>'fingerprint', v_input->'parts',
          fn_roster_snapshot(), p_prior_fingerprint)
  RETURNING id_ingest_run INTO v_id;

  UPDATE tbl_ingest_run
     SET txt_status = 'ABANDONED', ts_finished = now(),
         txt_error = format('run %s of the same event started before this one finished', v_id)
   WHERE txt_event_code = p_event_code AND txt_environment = p_environment
     AND txt_status = 'RUNNING' AND id_ingest_run <> v_id;

  RETURN v_id;
END;
$$;

COMMENT ON FUNCTION fn_ingest_run_open(TEXT, TEXT, TEXT, INT, TEXT, TEXT, TEXT, TEXT) IS
  'ADR-108 §4, ADR-119 §3 (G17): open a RUNNING tbl_ingest_run row before the ingestion writes, with the prior the run starts from; abandons an older RUNNING row of the same event and environment. Returns its id.';

REVOKE ALL ON FUNCTION fn_ingest_run_open(TEXT, TEXT, TEXT, INT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_ingest_run_open(TEXT, TEXT, TEXT, INT, TEXT, TEXT, TEXT, TEXT) TO service_role;
