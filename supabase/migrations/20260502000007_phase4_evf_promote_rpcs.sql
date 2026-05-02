-- =============================================================================
-- Phase 4 (ADR-053) — EVF parity promotion + annotation RPCs
--
-- Two SECURITY DEFINER RPCs called by the orchestrator (review_cli post-commit
-- hook + evf_parity_sweep cron):
--
--   fn_promote_evf_published(p_id_event, p_evf_scores)
--     Overwrites tbl_result.num_final_score for every (event, fencer)
--     pair listed in the JSONB array; flips tbl_event.txt_source_status
--     to EVF_PUBLISHED; appends an audit-log row. The trigger from
--     migration ...000002 enforces that this is only valid for EVF
--     events; non-EVF events raise.
--
--   fn_annotate_parity_fail(p_id_event, p_notes)
--     Sets tbl_event.txt_parity_notes (idempotent); audit-log row.
--     Status stays ENGINE_COMPUTED.
--
--   fn_event_results_for_parity(p_id_event)
--     Helper view-as-RPC: returns one row per POL fencer at this event
--     with (fencer_name, int_place, num_final_score) — the input shape
--     the Python parity gate expects on the "local" side.
--
--   fn_evf_events_pending_parity(p_max_age_days)
--     Daily-sweep helper: returns event rows where organizer=EVF and
--     status=ENGINE_COMPUTED and dt_end ≥ today - p_max_age_days.
--
-- Tests: supabase/tests/32_evf_promote_rpcs.sql.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. fn_event_results_for_parity — POL-only local rows for parity gate
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_event_results_for_parity(p_id_event INT)
RETURNS TABLE (
  fencer_name      TEXT,
  int_place        INT,
  num_final_score  NUMERIC,
  id_fencer        INT,
  id_result        INT
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT
    (f.txt_first_name || ' ' || f.txt_surname) AS fencer_name,
    r.int_place,
    r.num_final_score,
    f.id_fencer,
    r.id_result
  FROM tbl_result r
  JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
  JOIN tbl_fencer f     ON f.id_fencer = r.id_fencer
  WHERE t.id_event = p_id_event
    AND f.txt_nationality = 'PL'
  ORDER BY r.int_place, f.txt_surname, f.txt_first_name;
$$;

REVOKE EXECUTE ON FUNCTION fn_event_results_for_parity(INT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_event_results_for_parity(INT) TO authenticated, service_role;

COMMENT ON FUNCTION fn_event_results_for_parity(INT) IS
  'Returns POL fencer rows for the event, shaped for the Python EVF parity '
  'gate (Phase 4 ADR-053). One row per fencer; column names match the '
  'check_parity() local_results contract.';


-- ---------------------------------------------------------------------------
-- 2. fn_promote_evf_published — overwrite scores + flip status atomically
-- p_evf_scores: jsonb array of {fencer_id_or_name, int_place, num_final_score}
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_promote_evf_published(
  p_id_event   INT,
  p_evf_scores JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_organizer_code TEXT;
  v_old_status     enum_source_status;
  v_overwritten    INT := 0;
  v_score          JSONB;
  v_id_fencer      INT;
  v_int_place      INT;
  v_num_score      NUMERIC;
  v_old_score      NUMERIC;
BEGIN
  IF jsonb_typeof(p_evf_scores) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'fn_promote_evf_published: p_evf_scores must be JSONB array';
  END IF;

  -- Validate organizer (defensive — trigger also enforces but we want a clear error here)
  SELECT o.txt_code, e.txt_source_status
    INTO v_organizer_code, v_old_status
    FROM tbl_event e
    JOIN tbl_organizer o ON o.id_organizer = e.id_organizer
    WHERE e.id_event = p_id_event;

  IF v_organizer_code IS NULL THEN
    RAISE EXCEPTION 'fn_promote_evf_published: event % not found', p_id_event;
  END IF;
  IF v_organizer_code IS DISTINCT FROM 'EVF' THEN
    RAISE EXCEPTION
      'fn_promote_evf_published: only EVF-organized events may be promoted '
      '(event %, organizer=%)', p_id_event, v_organizer_code;
  END IF;

  -- Overwrite scores fencer-by-fencer
  FOR v_score IN SELECT * FROM jsonb_array_elements(p_evf_scores) LOOP
    v_id_fencer := (v_score ->> 'id_fencer')::INT;
    v_int_place := (v_score ->> 'int_place')::INT;
    v_num_score := (v_score ->> 'num_final_score')::NUMERIC;

    IF v_id_fencer IS NULL OR v_num_score IS NULL THEN
      CONTINUE;
    END IF;

    -- Capture old for audit
    SELECT r.num_final_score INTO v_old_score
      FROM tbl_result r
      JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
      WHERE t.id_event = p_id_event
        AND r.id_fencer = v_id_fencer
      LIMIT 1;

    UPDATE tbl_result
       SET num_final_score = v_num_score,
           ts_points_calc  = NOW(),
           ts_updated      = NOW()
     WHERE id_fencer = v_id_fencer
       AND id_tournament IN (
         SELECT id_tournament FROM tbl_tournament WHERE id_event = p_id_event
       );

    IF FOUND THEN
      v_overwritten := v_overwritten + 1;
    END IF;
  END LOOP;

  -- Flip status (trigger validates EVF-only invariant)
  UPDATE tbl_event
     SET txt_source_status = 'EVF_PUBLISHED',
         txt_parity_notes  = NULL,
         ts_updated        = NOW()
   WHERE id_event = p_id_event;

  -- Audit log
  INSERT INTO tbl_audit_log (txt_table_name, id_row, txt_action, jsonb_old_values, jsonb_new_values)
  VALUES (
    'tbl_event', p_id_event, 'evf_parity_promote',
    jsonb_build_object('txt_source_status', v_old_status::TEXT),
    jsonb_build_object(
      'txt_source_status', 'EVF_PUBLISHED',
      'fencers_overwritten', v_overwritten
    )
  );

  RETURN jsonb_build_object(
    'id_event',           p_id_event,
    'fencers_overwritten', v_overwritten,
    'old_status',         v_old_status::TEXT,
    'new_status',         'EVF_PUBLISHED'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_promote_evf_published(INT, JSONB) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_promote_evf_published(INT, JSONB) TO authenticated, service_role;

COMMENT ON FUNCTION fn_promote_evf_published(INT, JSONB) IS
  'Phase 4 (ADR-053) atomic EVF parity promotion: overwrite each fencer''s '
  'num_final_score with EVF authoritative value, flip txt_source_status '
  'to EVF_PUBLISHED, audit-log. Raises if organizer != EVF.';


-- ---------------------------------------------------------------------------
-- 3. fn_annotate_parity_fail — record txt_parity_notes (status unchanged)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_annotate_parity_fail(
  p_id_event INT,
  p_notes    TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_old TEXT;
BEGIN
  IF p_notes IS NULL OR length(trim(p_notes)) = 0 THEN
    RAISE EXCEPTION 'fn_annotate_parity_fail: p_notes is empty';
  END IF;

  SELECT txt_parity_notes INTO v_old FROM tbl_event WHERE id_event = p_id_event;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'fn_annotate_parity_fail: event % not found', p_id_event;
  END IF;

  UPDATE tbl_event
     SET txt_parity_notes = p_notes, ts_updated = NOW()
   WHERE id_event = p_id_event;

  INSERT INTO tbl_audit_log (txt_table_name, id_row, txt_action, jsonb_old_values, jsonb_new_values)
  VALUES (
    'tbl_event', p_id_event, 'evf_parity_annotate',
    jsonb_build_object('txt_parity_notes', v_old),
    jsonb_build_object('txt_parity_notes', p_notes)
  );

  RETURN jsonb_build_object('id_event', p_id_event, 'txt_parity_notes', p_notes);
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_annotate_parity_fail(INT, TEXT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_annotate_parity_fail(INT, TEXT) TO authenticated, service_role;

COMMENT ON FUNCTION fn_annotate_parity_fail(INT, TEXT) IS
  'Phase 4 (ADR-053) parity-fail annotation: write txt_parity_notes, '
  'audit-log. Status stays ENGINE_COMPUTED.';


-- ---------------------------------------------------------------------------
-- 4. fn_evf_events_pending_parity — daily sweep target list
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_evf_events_pending_parity(
  p_max_age_days INT DEFAULT 60
)
RETURNS TABLE (
  id_event       INT,
  txt_code       TEXT,
  txt_name       TEXT,
  dt_start       DATE,
  dt_end         DATE,
  url_event      TEXT,
  ts_last_update TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT
    e.id_event, e.txt_code, e.txt_name,
    e.dt_start, e.dt_end, e.url_event,
    e.ts_updated
  FROM tbl_event e
  JOIN tbl_organizer o ON o.id_organizer = e.id_organizer
  WHERE o.txt_code = 'EVF'
    AND e.txt_source_status = 'ENGINE_COMPUTED'
    AND e.dt_end >= CURRENT_DATE - p_max_age_days
  ORDER BY e.dt_end DESC;
$$;

REVOKE EXECUTE ON FUNCTION fn_evf_events_pending_parity(INT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_evf_events_pending_parity(INT) TO authenticated, service_role;

COMMENT ON FUNCTION fn_evf_events_pending_parity(INT) IS
  'Phase 4 (ADR-053) daily sweep target list: EVF-organized events still '
  'at ENGINE_COMPUTED whose dt_end is within p_max_age_days.';

COMMIT;
