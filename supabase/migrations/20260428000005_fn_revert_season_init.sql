-- =============================================================================
-- Phase 3a — fn_revert_season_init: full revert of a season's wizard output
-- =============================================================================
-- Used by the EDIT form's "↶ Cofnij całość" link. Refuses if any skeleton has
-- advanced past CREATED (admin must revert each one to CREATED first via the
-- universal Phase 1B rollback). On success, deletes children → events →
-- scoring_config → season in a single transaction. ON DELETE SET NULL on
-- id_prior_event handles incoming references from later seasons gracefully.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_revert_season_init(p_id_season INT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM tbl_season WHERE id_season = p_id_season) THEN
    RAISE EXCEPTION 'fn_revert_season_init: season % not found', p_id_season;
  END IF;

  IF EXISTS (
    SELECT 1 FROM tbl_event
     WHERE id_season = p_id_season AND enum_status <> 'CREATED'
  ) THEN
    RAISE EXCEPTION
      'fn_revert_season_init: season % has events past CREATED state — revert each to CREATED first',
      p_id_season;
  END IF;

  DELETE FROM tbl_tournament
   WHERE id_event IN (SELECT id_event FROM tbl_event WHERE id_season = p_id_season);

  DELETE FROM tbl_event       WHERE id_season = p_id_season;
  DELETE FROM tbl_scoring_config WHERE id_season = p_id_season;
  DELETE FROM tbl_season      WHERE id_season = p_id_season;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_revert_season_init(INT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_revert_season_init(INT) TO authenticated;
