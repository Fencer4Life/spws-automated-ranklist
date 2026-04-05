-- =============================================================================
-- Identity Resolution Admin RPCs (ADR-025, Phase 7)
-- =============================================================================
-- fn_approve_match       — Link match candidate to fencer, update result
-- fn_dismiss_match       — Set candidate status to DISMISSED with note
-- fn_create_fencer_from_match — Create new fencer and link to result
-- =============================================================================


-- ---------------------------------------------------------------------------
-- fn_approve_match: approve a PENDING match candidate
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_approve_match(p_match_id INT, p_fencer_id INT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result_id INT;
  v_status    enum_match_status;
BEGIN
  -- Validate candidate exists and is PENDING
  SELECT mc.id_result, mc.enum_status INTO v_result_id, v_status
  FROM tbl_match_candidate mc WHERE mc.id_match = p_match_id;

  IF v_result_id IS NULL THEN
    RAISE EXCEPTION 'Match candidate % not found', p_match_id;
  END IF;

  IF v_status != 'PENDING' THEN
    RAISE EXCEPTION 'Only PENDING candidates can be approved (current: %)', v_status;
  END IF;

  -- Validate fencer exists
  IF NOT EXISTS (SELECT 1 FROM tbl_fencer WHERE id_fencer = p_fencer_id) THEN
    RAISE EXCEPTION 'Fencer % not found', p_fencer_id;
  END IF;

  -- Update match candidate
  UPDATE tbl_match_candidate
  SET id_fencer = p_fencer_id, enum_status = 'APPROVED', ts_updated = NOW()
  WHERE id_match = p_match_id;

  -- Update result to link to the approved fencer
  UPDATE tbl_result
  SET id_fencer = p_fencer_id, ts_updated = NOW()
  WHERE id_result = v_result_id;

  RETURN jsonb_build_object('id_match', p_match_id, 'id_fencer', p_fencer_id, 'status', 'APPROVED');
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_approve_match(INT, INT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_approve_match(INT, INT) TO authenticated;


-- ---------------------------------------------------------------------------
-- fn_dismiss_match: dismiss a PENDING or UNMATCHED candidate
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_dismiss_match(p_match_id INT, p_note TEXT DEFAULT NULL)
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

  IF v_status NOT IN ('PENDING', 'UNMATCHED') THEN
    RAISE EXCEPTION 'Only PENDING or UNMATCHED candidates can be dismissed (current: %)', v_status;
  END IF;

  UPDATE tbl_match_candidate
  SET enum_status = 'DISMISSED', txt_admin_note = p_note, ts_updated = NOW()
  WHERE id_match = p_match_id;

  RETURN jsonb_build_object('id_match', p_match_id, 'status', 'DISMISSED');
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_dismiss_match(INT, TEXT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_dismiss_match(INT, TEXT) TO authenticated;


-- ---------------------------------------------------------------------------
-- fn_create_fencer_from_match: create new fencer and link to result
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_create_fencer_from_match(
  p_match_id   INT,
  p_surname    TEXT,
  p_first_name TEXT,
  p_birth_year INT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result_id  INT;
  v_status     enum_match_status;
  v_fencer_id  INT;
BEGIN
  -- Validate candidate
  SELECT mc.id_result, mc.enum_status INTO v_result_id, v_status
  FROM tbl_match_candidate mc WHERE mc.id_match = p_match_id;

  IF v_result_id IS NULL THEN
    RAISE EXCEPTION 'Match candidate % not found', p_match_id;
  END IF;

  IF v_status NOT IN ('PENDING', 'UNMATCHED') THEN
    RAISE EXCEPTION 'Only PENDING or UNMATCHED candidates can create new fencers (current: %)', v_status;
  END IF;

  -- Create fencer
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, bool_birth_year_estimated)
  VALUES (p_surname, p_first_name, p_birth_year, p_birth_year IS NOT NULL)
  RETURNING id_fencer INTO v_fencer_id;

  -- Update match candidate
  UPDATE tbl_match_candidate
  SET id_fencer = v_fencer_id, enum_status = 'NEW_FENCER', ts_updated = NOW()
  WHERE id_match = p_match_id;

  -- Update result to link to new fencer
  UPDATE tbl_result
  SET id_fencer = v_fencer_id, ts_updated = NOW()
  WHERE id_result = v_result_id;

  RETURN jsonb_build_object(
    'id_match', p_match_id,
    'id_fencer', v_fencer_id,
    'status', 'NEW_FENCER'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_create_fencer_from_match(INT, TEXT, TEXT, INT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_create_fencer_from_match(INT, TEXT, TEXT, INT) TO authenticated;
