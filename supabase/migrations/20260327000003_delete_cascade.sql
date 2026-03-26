-- =============================================================================
-- T9.1: Delete cascade functions + REVOKE/GRANT for all T9.1 functions
-- =============================================================================
-- Manual cascade (not FK CASCADE) preserves audit log entries via triggers.
-- Delete order: match_candidates -> results -> tournament -> event
-- =============================================================================

-- ─── Delete Cascade Functions ────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION fn_delete_tournament_cascade(p_id INT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Delete match candidates linked to this tournament's results
  DELETE FROM tbl_match_candidate
  WHERE id_result IN (
    SELECT id_result FROM tbl_result WHERE id_tournament = p_id
  );

  -- Delete results
  DELETE FROM tbl_result WHERE id_tournament = p_id;

  -- Delete the tournament
  DELETE FROM tbl_tournament WHERE id_tournament = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tournament % not found', p_id;
  END IF;
END;
$$;


CREATE OR REPLACE FUNCTION fn_delete_event_cascade(p_id INT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tid INT;
BEGIN
  -- Cascade through each child tournament
  FOR v_tid IN SELECT id_tournament FROM tbl_tournament WHERE id_event = p_id
  LOOP
    PERFORM fn_delete_tournament_cascade(v_tid);
  END LOOP;

  -- Delete the event (audit trigger fires)
  DELETE FROM tbl_event WHERE id_event = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Event % not found', p_id;
  END IF;
END;
$$;


-- ─── REVOKE from anon/PUBLIC, GRANT to authenticated ─────────────────────────
-- All 9 T9.1 functions follow ADR-016 pattern.

REVOKE EXECUTE ON FUNCTION fn_create_season(TEXT, DATE, DATE) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_update_season(INT, TEXT, DATE, DATE) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_delete_season(INT) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_create_event(TEXT, TEXT, INT, INT, TEXT, DATE, DATE, TEXT, TEXT, TEXT, TEXT, NUMERIC) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_update_event(INT, TEXT, TEXT, DATE, DATE, TEXT, TEXT, TEXT, TEXT, NUMERIC) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_create_tournament(INT, TEXT, TEXT, enum_tournament_type, enum_weapon_type, enum_gender_type, enum_age_category, DATE, INT, TEXT) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_update_tournament(INT, TEXT, enum_import_status, TEXT) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_delete_tournament_cascade(INT) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_delete_event_cascade(INT) FROM anon, PUBLIC;

GRANT EXECUTE ON FUNCTION fn_create_season(TEXT, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION fn_update_season(INT, TEXT, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION fn_delete_season(INT) TO authenticated;
GRANT EXECUTE ON FUNCTION fn_create_event(TEXT, TEXT, INT, INT, TEXT, DATE, DATE, TEXT, TEXT, TEXT, TEXT, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION fn_update_event(INT, TEXT, TEXT, DATE, DATE, TEXT, TEXT, TEXT, TEXT, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION fn_create_tournament(INT, TEXT, TEXT, enum_tournament_type, enum_weapon_type, enum_gender_type, enum_age_category, DATE, INT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fn_update_tournament(INT, TEXT, enum_import_status, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fn_delete_tournament_cascade(INT) TO authenticated;
GRANT EXECUTE ON FUNCTION fn_delete_event_cascade(INT) TO authenticated;
