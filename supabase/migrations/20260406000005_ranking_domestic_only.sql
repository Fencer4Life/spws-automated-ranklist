-- =============================================================================
-- Fix fn_category_ranking to show domestic (PPW/MPW) points only
-- Add tournament type info to fn_season_overview for carry-over display
-- =============================================================================

-- ---------------------------------------------------------------------------
-- fn_category_ranking: domestic points only (PPW/MPW)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_category_ranking(
  p_weapon   enum_weapon_type,
  p_gender   enum_gender_type,
  p_category enum_age_category
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_active_season INT;
BEGIN
  SELECT id_season INTO v_active_season FROM tbl_season WHERE bool_active = TRUE;
  IF v_active_season IS NULL THEN
    RAISE EXCEPTION 'No active season';
  END IF;

  RETURN (
    SELECT COALESCE(jsonb_agg(row_data ORDER BY total_score DESC), '[]'::JSONB)
    FROM (
      SELECT jsonb_build_object(
        'fencer', f.txt_surname || ' ' || f.txt_first_name,
        'total_score', ROUND(SUM(r.num_final_score), 2)
      ) AS row_data,
      SUM(r.num_final_score) AS total_score
      FROM tbl_result r
      JOIN tbl_fencer f ON r.id_fencer = f.id_fencer
      JOIN tbl_tournament t ON r.id_tournament = t.id_tournament
      JOIN tbl_event e ON t.id_event = e.id_event
      WHERE e.id_season = v_active_season
        AND t.enum_weapon = p_weapon
        AND t.enum_gender = p_gender
        AND t.enum_age_category = p_category
        AND t.enum_type IN ('PPW', 'MPW')  -- domestic only
      GROUP BY f.id_fencer, f.txt_surname, f.txt_first_name
      ORDER BY total_score DESC
      LIMIT 5
    ) ranked
  );
END;
$$;


-- ---------------------------------------------------------------------------
-- fn_season_overview: add has_international flag per event
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_season_overview()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_active_season INT;
BEGIN
  SELECT id_season INTO v_active_season FROM tbl_season WHERE bool_active = TRUE;
  IF v_active_season IS NULL THEN
    RAISE EXCEPTION 'No active season';
  END IF;

  RETURN (
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'event_code', e.txt_code,
      'event_name', e.txt_name,
      'status', e.enum_status,
      'dt_start', e.dt_start,
      'tournament_count', (SELECT COUNT(*) FROM tbl_tournament t WHERE t.id_event = e.id_event),
      'result_count', (SELECT COUNT(*) FROM tbl_result r JOIN tbl_tournament t ON r.id_tournament = t.id_tournament WHERE t.id_event = e.id_event),
      'is_international', (SELECT EXISTS(SELECT 1 FROM tbl_tournament t WHERE t.id_event = e.id_event AND t.enum_type IN ('PEW', 'MEW', 'MSW')))
    ) ORDER BY e.dt_start), '[]'::JSONB)
    FROM tbl_event e
    WHERE e.id_season = v_active_season
  );
END;
$$;
