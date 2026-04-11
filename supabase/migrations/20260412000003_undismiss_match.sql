-- =============================================================================
-- fn_undismiss_match: reset DISMISSED candidate back to PENDING
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_undismiss_match(p_match_id INT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_status enum_match_status;
BEGIN
  SELECT enum_status INTO v_status
  FROM tbl_match_candidate WHERE id_match = p_match_id;

  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Match candidate % not found', p_match_id;
  END IF;

  IF v_status != 'DISMISSED' THEN
    RAISE EXCEPTION 'Only DISMISSED candidates can be undismissed (current: %)', v_status;
  END IF;

  UPDATE tbl_match_candidate
  SET enum_status = 'PENDING', txt_admin_note = NULL, ts_updated = NOW()
  WHERE id_match = p_match_id;

  RETURN jsonb_build_object('id_match', p_match_id, 'status', 'PENDING');
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_undismiss_match(INT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_undismiss_match(INT) TO authenticated;
