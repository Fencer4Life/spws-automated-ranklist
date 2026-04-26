-- =============================================================================
-- Migration: Register FK engine in carry-over dispatchers
-- =============================================================================
-- Phase 1B step 7 — replace the 'RAISE EXCEPTION ... not yet implemented'
-- placeholder in the EVENT_FK_MATCHING branch with an actual call to the new
-- FK engine functions added in 20260425000008.
--
-- Default season engine remains 'EVENT_CODE_MATCHING' — no behavior change
-- until an admin explicitly flips a season to 'EVENT_FK_MATCHING' via:
--   UPDATE tbl_season SET enum_carryover_engine = 'EVENT_FK_MATCHING'
--     WHERE id_season = X;
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_ranking_ppw(
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
      RETURN QUERY SELECT * FROM fn_ranking_ppw_event_fk_matching(
        p_weapon, p_gender, p_category, p_season, p_rolling
      );
    ELSE
      RAISE EXCEPTION 'Unknown carryover engine: % for season %', v_engine, v_resolved_season;
  END CASE;
END;
$$;

CREATE OR REPLACE FUNCTION fn_ranking_kadra(
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
      RETURN QUERY SELECT * FROM fn_ranking_kadra_event_fk_matching(
        p_weapon, p_gender, p_category, p_season, p_rolling
      );
    ELSE
      RAISE EXCEPTION 'Unknown carryover engine: % for season %', v_engine, v_resolved_season;
  END CASE;
END;
$$;

CREATE OR REPLACE FUNCTION fn_fencer_scores_rolling(
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
      RETURN QUERY SELECT * FROM fn_fencer_scores_rolling_event_fk_matching(
        p_fencer_id, p_weapon, p_gender, p_category, p_season
      );
    ELSE
      RAISE EXCEPTION 'Unknown carryover engine: % for season %', v_engine, v_resolved_season;
  END CASE;
END;
$$;
