-- =============================================================================
-- View: vw_match_candidates (Identity Resolution UI)
-- =============================================================================
-- Joins match_candidate + result + tournament + fencer for the admin UI.
-- =============================================================================

CREATE OR REPLACE VIEW vw_match_candidates AS
SELECT
  mc.id_match,
  mc.id_result,
  mc.txt_scraped_name,
  mc.id_fencer,
  mc.num_confidence,
  mc.enum_status,
  mc.txt_admin_note,
  f.txt_surname || ' ' || f.txt_first_name AS txt_fencer_name,
  t.txt_code AS txt_tournament_code,
  t.enum_type
FROM tbl_match_candidate mc
JOIN tbl_result r ON mc.id_result = r.id_result
JOIN tbl_tournament t ON r.id_tournament = t.id_tournament
LEFT JOIN tbl_fencer f ON mc.id_fencer = f.id_fencer;
