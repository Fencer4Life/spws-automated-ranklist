-- =============================================================================
-- M6 patch: extend vw_score with url_results and txt_location
-- =============================================================================
-- Adds two nullable columns to vw_score:
--   url_results  — from tbl_tournament (link to official results page)
--   txt_location — from tbl_event (city/venue where the event was held)
-- Both sources are already joined in the view; this is a column addition only.
-- =============================================================================

CREATE OR REPLACE VIEW vw_score AS
SELECT
  r.id_result,
  r.id_fencer,
  f.txt_surname || ' ' || f.txt_first_name AS fencer_name,
  t.id_tournament,
  t.txt_code             AS txt_tournament_code,
  t.txt_name             AS txt_tournament_name,
  t.dt_tournament,
  t.enum_type,
  t.enum_weapon,
  t.enum_gender,
  t.enum_age_category,
  t.int_participant_count,
  t.num_multiplier,
  r.int_place,
  r.num_place_pts,
  r.num_de_bonus,
  r.num_podium_bonus,
  r.num_final_score,
  r.ts_points_calc,
  s.id_season,
  s.txt_code             AS txt_season_code,
  t.url_results,
  e.txt_location
FROM tbl_result r
JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
JOIN tbl_event e      ON e.id_event = t.id_event
JOIN tbl_season s     ON s.id_season = e.id_season
LEFT JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
WHERE r.id_fencer IS NOT NULL;
