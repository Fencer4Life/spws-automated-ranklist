-- =============================================================================
-- Phase 3a — fn_create_season_with_skeletons: atomic wizard RPC
-- =============================================================================
-- Single transaction:
--   1. INSERT tbl_season (txt_code, dates, carry-over fields, engine)
--   2. trg_season_auto_config trigger inserts default tbl_scoring_config row
--   3. Overwrite scoring_config from p_scoring_config JSONB (uses
--      fn_import_scoring_config — its INSERT ON CONFLICT idempotently merges).
--      An empty JSONB ('{}') keeps the trigger defaults; a populated one fills
--      what the wizard's step-2 ScoringConfigEditor produced.
--   4. fn_init_season pre-allocates skeletons.
--
-- Any failure (duplicate code, scoring schema drift, init exception) raises and
-- the implicit transaction rollback removes the partially-built season —
-- matches the wizard's "cancel = nothing persists" requirement.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_create_season_with_skeletons(
  p_code              TEXT,
  p_dt_start          DATE,
  p_dt_end            DATE,
  p_carryover_days    INT,
  p_european_type     TEXT,
  p_carryover_engine  enum_event_carryover_engine,
  p_scoring_config    JSONB,
  p_show_evf          BOOLEAN
)
RETURNS TABLE(id_season INT, skeletons_created INT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_id    INT;
  v_count INT;
BEGIN
  INSERT INTO tbl_season (
    txt_code, dt_start, dt_end,
    int_carryover_days, enum_european_event_type, enum_carryover_engine
  ) VALUES (
    p_code, p_dt_start, p_dt_end,
    COALESCE(p_carryover_days, 366), p_european_type, p_carryover_engine
  ) RETURNING tbl_season.id_season INTO v_id;

  -- Overwrite the trigger-inserted defaults with wizard payload + show_evf.
  PERFORM fn_import_scoring_config(
    COALESCE(p_scoring_config, '{}'::JSONB)
      || jsonb_build_object('id_season', v_id, 'show_evf_toggle', p_show_evf)
  );

  SELECT (fn_init_season(v_id)).skeletons_created INTO v_count;

  RETURN QUERY SELECT v_id, v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_create_season_with_skeletons(
  TEXT, DATE, DATE, INT, TEXT, enum_event_carryover_engine, JSONB, BOOLEAN
) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION fn_create_season_with_skeletons(
  TEXT, DATE, DATE, INT, TEXT, enum_event_carryover_engine, JSONB, BOOLEAN
) TO authenticated;
