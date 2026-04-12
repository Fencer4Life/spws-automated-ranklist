-- =============================================================================
-- fn_update_fencer_birth_year: admin edits birth year + estimated flag
-- =============================================================================
-- ADR-035: Birth year review tab in Fencers view
-- Pattern follows fn_update_fencer_gender (ADR-033)
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_update_fencer_birth_year(
  p_fencer_id  INT,
  p_birth_year INT,
  p_estimated  BOOLEAN DEFAULT FALSE
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE tbl_fencer
  SET int_birth_year = p_birth_year,
      bool_birth_year_estimated = COALESCE(p_estimated, FALSE),
      ts_updated = NOW()
  WHERE id_fencer = p_fencer_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Fencer % not found', p_fencer_id;
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_update_fencer_birth_year(INT, INT, BOOLEAN) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_update_fencer_birth_year(INT, INT, BOOLEAN) TO authenticated;
