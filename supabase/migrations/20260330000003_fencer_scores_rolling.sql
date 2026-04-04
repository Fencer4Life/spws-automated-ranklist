-- =============================================================================
-- Migration: fn_fencer_scores_rolling (ADR-018)
-- =============================================================================
-- Returns vw_score-like rows for a specific fencer with rolling carry-over.
-- Current-season scores: bool_carried_over = FALSE
-- Previous-season scores at declared-but-uncompleted positions: bool_carried_over = TRUE
-- Previous-season scores with no counterpart in current season: EXCLUDED
-- =============================================================================

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
  v_season_id      INT;
  v_prev_season_id INT;
  v_season_end_yr  INT;
BEGIN
  v_season_id := COALESCE(
    p_season,
    (SELECT s.id_season FROM tbl_season s WHERE s.bool_active LIMIT 1)
  );

  SELECT EXTRACT(YEAR FROM s.dt_end)::INT INTO v_season_end_yr
    FROM tbl_season s WHERE s.id_season = v_season_id;

  SELECT s.id_season INTO v_prev_season_id
    FROM tbl_season s
   WHERE s.dt_end < (SELECT s2.dt_start FROM tbl_season s2 WHERE s2.id_season = v_season_id)
   ORDER BY s.dt_end DESC
   LIMIT 1;

  RETURN QUERY
  WITH
    -- Positions declared in current season
    declared_positions AS (
      SELECT DISTINCT fn_event_position(ev.txt_code) AS pos
        FROM tbl_event ev
       WHERE ev.id_season = v_season_id
    ),
    -- Positions where at least one event is COMPLETED
    completed_positions AS (
      SELECT DISTINCT fn_event_position(ev.txt_code) AS pos
        FROM tbl_event ev
       WHERE ev.id_season = v_season_id
         AND ev.enum_status = 'COMPLETED'
    ),
    -- Current-season scores
    current_scores AS (
      SELECT
        r.id_result, r.id_fencer,
        f.txt_surname || ' ' || f.txt_first_name AS fencer_name,
        f.int_birth_year,
        t.id_tournament, t.txt_code AS txt_tournament_code, t.txt_name AS txt_tournament_name,
        t.dt_tournament, t.enum_type, t.enum_weapon, t.enum_gender, t.enum_age_category,
        t.int_participant_count, t.num_multiplier,
        r.int_place, r.num_place_pts, r.num_de_bonus, r.num_podium_bonus,
        r.num_final_score, r.ts_points_calc,
        s.id_season, s.txt_code AS txt_season_code,
        t.url_results, ev.txt_location,
        FALSE AS bool_carried_over,
        s.txt_code AS txt_source_season_code
      FROM tbl_result r
      JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
      JOIN tbl_event ev     ON ev.id_event = t.id_event
      JOIN tbl_season s     ON s.id_season = ev.id_season
      JOIN tbl_fencer f     ON f.id_fencer = r.id_fencer
      WHERE r.id_fencer = p_fencer_id
        AND ev.id_season = v_season_id
        AND t.enum_weapon = p_weapon
        AND t.enum_gender = p_gender
        AND r.num_final_score IS NOT NULL
    ),
    -- Carried-over scores from previous season
    carried_scores AS (
      SELECT
        r.id_result, r.id_fencer,
        f.txt_surname || ' ' || f.txt_first_name AS fencer_name,
        f.int_birth_year,
        t.id_tournament, t.txt_code AS txt_tournament_code, t.txt_name AS txt_tournament_name,
        t.dt_tournament, t.enum_type, t.enum_weapon, t.enum_gender, t.enum_age_category,
        t.int_participant_count, t.num_multiplier,
        r.int_place, r.num_place_pts, r.num_de_bonus, r.num_podium_bonus,
        r.num_final_score, r.ts_points_calc,
        prev_s.id_season, prev_s.txt_code AS txt_season_code,
        t.url_results, ev.txt_location,
        TRUE AS bool_carried_over,
        prev_s.txt_code AS txt_source_season_code
      FROM tbl_result r
      JOIN tbl_tournament t  ON t.id_tournament = r.id_tournament
      JOIN tbl_event ev      ON ev.id_event = t.id_event
      JOIN tbl_season prev_s ON prev_s.id_season = ev.id_season
      JOIN tbl_fencer f      ON f.id_fencer = r.id_fencer
      WHERE v_prev_season_id IS NOT NULL
        AND r.id_fencer = p_fencer_id
        AND ev.id_season = v_prev_season_id
        AND t.enum_weapon = p_weapon
        AND t.enum_gender = p_gender
        AND COALESCE(fn_age_category(f.int_birth_year, v_season_end_yr), t.enum_age_category) = p_category
        AND r.num_final_score IS NOT NULL
        -- Position must be declared in current season but NOT completed
        AND fn_event_position(ev.txt_code) IN (SELECT pos FROM declared_positions)
        AND fn_event_position(ev.txt_code) NOT IN (SELECT pos FROM completed_positions)
    )
  SELECT * FROM current_scores
  UNION ALL
  SELECT * FROM carried_scores
  ORDER BY num_final_score DESC;
END;
$$;

COMMENT ON FUNCTION fn_fencer_scores_rolling IS
  'Fencer score drilldown with rolling carry-over (ADR-018). '
  'Returns current-season scores (bool_carried_over=FALSE) plus '
  'previous-season scores for declared-but-uncompleted positions (bool_carried_over=TRUE). '
  'Category crossing: fn_age_category evaluated against current season end year.';
