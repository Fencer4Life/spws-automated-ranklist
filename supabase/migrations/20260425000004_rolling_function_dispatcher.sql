-- =============================================================================
-- Migration: Rolling-function dispatcher (rename engines + create dispatchers)
-- =============================================================================
-- Phase 1A — strangler-fig pattern.
--
-- Step 1: rename the existing 3 rolling-score functions, appending the
--         '_event_code_matching' suffix. Function bodies are unchanged.
-- Step 2: create new functions with the original public names. They read
--         tbl_season.enum_carryover_engine for the requested season and
--         dispatch to the appropriate engine. The EVENT_FK_MATCHING branch
--         raises (engine arrives in Phase 1B).
--
-- Existing pgTAP suite 09_rolling_score.sql calls the public names — its
-- 21 assertions act as the regression gate for this refactor.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Rename current engines
-- ---------------------------------------------------------------------------
ALTER FUNCTION fn_ranking_ppw(enum_weapon_type, enum_gender_type, enum_age_category, INT, BOOLEAN)
  RENAME TO fn_ranking_ppw_event_code_matching;

ALTER FUNCTION fn_ranking_kadra(enum_weapon_type, enum_gender_type, enum_age_category, INT, BOOLEAN)
  RENAME TO fn_ranking_kadra_event_code_matching;

ALTER FUNCTION fn_fencer_scores_rolling(INT, enum_weapon_type, enum_gender_type, enum_age_category, INT)
  RENAME TO fn_fencer_scores_rolling_event_code_matching;

-- ---------------------------------------------------------------------------
-- 2. Create dispatcher functions with original public names
-- ---------------------------------------------------------------------------

CREATE FUNCTION fn_ranking_ppw(
  p_weapon   enum_weapon_type,
  p_gender   enum_gender_type,
  p_category enum_age_category,
  p_season   INT DEFAULT NULL,
  p_rolling  BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
  rank              INT,
  id_fencer         INT,
  fencer_name       TEXT,
  ppw_score         NUMERIC,
  mpw_score         NUMERIC,
  total_score       NUMERIC,
  bool_has_carryover BOOLEAN
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
AS $$
DECLARE
  v_engine          enum_event_carryover_engine;
  v_resolved_season INT;
BEGIN
  v_resolved_season := COALESCE(
    p_season,
    (SELECT s.id_season FROM tbl_season s WHERE s.bool_active LIMIT 1)
  );

  SELECT s.enum_carryover_engine INTO v_engine
    FROM tbl_season s WHERE s.id_season = v_resolved_season;

  CASE v_engine
    WHEN 'EVENT_CODE_MATCHING' THEN
      RETURN QUERY SELECT * FROM fn_ranking_ppw_event_code_matching(
        p_weapon, p_gender, p_category, p_season, p_rolling
      );
    WHEN 'EVENT_FK_MATCHING' THEN
      RAISE EXCEPTION 'Carryover engine EVENT_FK_MATCHING is not yet implemented for season %', v_resolved_season;
    ELSE
      RAISE EXCEPTION 'Unknown carryover engine: % for season %', v_engine, v_resolved_season;
  END CASE;
END;
$$;

CREATE FUNCTION fn_ranking_kadra(
  p_weapon   enum_weapon_type,
  p_gender   enum_gender_type,
  p_category enum_age_category,
  p_season   INT DEFAULT NULL,
  p_rolling  BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
  rank              INT,
  id_fencer         INT,
  fencer_name       TEXT,
  ppw_total         NUMERIC,
  pew_total         NUMERIC,
  total_score       NUMERIC,
  bool_has_carryover BOOLEAN
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
AS $$
DECLARE
  v_engine          enum_event_carryover_engine;
  v_resolved_season INT;
BEGIN
  v_resolved_season := COALESCE(
    p_season,
    (SELECT s.id_season FROM tbl_season s WHERE s.bool_active LIMIT 1)
  );

  SELECT s.enum_carryover_engine INTO v_engine
    FROM tbl_season s WHERE s.id_season = v_resolved_season;

  CASE v_engine
    WHEN 'EVENT_CODE_MATCHING' THEN
      RETURN QUERY SELECT * FROM fn_ranking_kadra_event_code_matching(
        p_weapon, p_gender, p_category, p_season, p_rolling
      );
    WHEN 'EVENT_FK_MATCHING' THEN
      RAISE EXCEPTION 'Carryover engine EVENT_FK_MATCHING is not yet implemented for season %', v_resolved_season;
    ELSE
      RAISE EXCEPTION 'Unknown carryover engine: % for season %', v_engine, v_resolved_season;
  END CASE;
END;
$$;

CREATE FUNCTION fn_fencer_scores_rolling(
  p_fencer_id INT,
  p_weapon    enum_weapon_type,
  p_gender    enum_gender_type,
  p_category  enum_age_category,
  p_season    INT DEFAULT NULL
)
RETURNS TABLE (
  id_result             INT,
  id_fencer             INT,
  fencer_name           TEXT,
  int_birth_year        SMALLINT,
  id_tournament         INT,
  txt_tournament_code   TEXT,
  txt_tournament_name   TEXT,
  dt_tournament         DATE,
  enum_type             enum_tournament_type,
  enum_weapon           enum_weapon_type,
  enum_gender           enum_gender_type,
  enum_age_category     enum_age_category,
  int_participant_count INT,
  num_multiplier        NUMERIC,
  int_place             INT,
  num_place_pts         NUMERIC,
  num_de_bonus          NUMERIC,
  num_podium_bonus      NUMERIC,
  num_final_score       NUMERIC,
  ts_points_calc        TIMESTAMPTZ,
  id_season             INT,
  txt_season_code       TEXT,
  url_results           TEXT,
  txt_location          TEXT,
  bool_carried_over     BOOLEAN,
  txt_source_season_code TEXT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
AS $$
DECLARE
  v_engine          enum_event_carryover_engine;
  v_resolved_season INT;
BEGIN
  v_resolved_season := COALESCE(
    p_season,
    (SELECT s.id_season FROM tbl_season s WHERE s.bool_active LIMIT 1)
  );

  SELECT s.enum_carryover_engine INTO v_engine
    FROM tbl_season s WHERE s.id_season = v_resolved_season;

  CASE v_engine
    WHEN 'EVENT_CODE_MATCHING' THEN
      RETURN QUERY SELECT * FROM fn_fencer_scores_rolling_event_code_matching(
        p_fencer_id, p_weapon, p_gender, p_category, p_season
      );
    WHEN 'EVENT_FK_MATCHING' THEN
      RAISE EXCEPTION 'Carryover engine EVENT_FK_MATCHING is not yet implemented for season %', v_resolved_season;
    ELSE
      RAISE EXCEPTION 'Unknown carryover engine: % for season %', v_engine, v_resolved_season;
  END CASE;
END;
$$;
