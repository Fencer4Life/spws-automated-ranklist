-- =============================================================================
-- Add p_birth_year_estimated parameter to fn_create_fencer_from_match
-- =============================================================================
-- Allows admin to explicitly set whether the birth year is exact or estimated
-- from the age category. Previously hardcoded as (p_birth_year IS NOT NULL).
-- =============================================================================

DROP FUNCTION IF EXISTS fn_create_fencer_from_match(INT, TEXT, TEXT, INT, enum_gender_type);

CREATE OR REPLACE FUNCTION fn_create_fencer_from_match(
  p_match_id              INT,
  p_surname               TEXT,
  p_first_name            TEXT,
  p_birth_year            INT DEFAULT NULL,
  p_gender                enum_gender_type DEFAULT NULL,
  p_birth_year_estimated  BOOLEAN DEFAULT TRUE
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
  SELECT mc.id_result, mc.enum_status INTO v_result_id, v_status
  FROM tbl_match_candidate mc WHERE mc.id_match = p_match_id;

  IF v_result_id IS NULL THEN
    RAISE EXCEPTION 'Match candidate % not found', p_match_id;
  END IF;

  IF v_status NOT IN ('PENDING', 'UNMATCHED', 'AUTO_MATCHED') THEN
    RAISE EXCEPTION 'Only PENDING, UNMATCHED, or AUTO_MATCHED candidates can create new fencers (current: %)', v_status;
  END IF;

  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, bool_birth_year_estimated, enum_gender)
  VALUES (p_surname, p_first_name, p_birth_year, COALESCE(p_birth_year_estimated, p_birth_year IS NOT NULL), p_gender)
  RETURNING id_fencer INTO v_fencer_id;

  UPDATE tbl_match_candidate
  SET id_fencer = v_fencer_id, enum_status = 'NEW_FENCER', ts_updated = NOW()
  WHERE id_match = p_match_id;

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

REVOKE EXECUTE ON FUNCTION fn_create_fencer_from_match(INT, TEXT, TEXT, INT, enum_gender_type, BOOLEAN) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_create_fencer_from_match(INT, TEXT, TEXT, INT, enum_gender_type, BOOLEAN) TO authenticated;
