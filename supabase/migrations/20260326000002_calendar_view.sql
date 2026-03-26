-- =============================================================================
-- T8.2: Calendar API View (FR-43, FR-44)
-- =============================================================================
-- View providing events + tournament counts for the Calendar UI.
-- Past/future/all toggle is client-side. RLS inherited from tbl_event.
-- =============================================================================

CREATE OR REPLACE VIEW vw_calendar AS
SELECT
  e.id_event, e.txt_code, e.txt_name, e.id_season,
  s.txt_code AS txt_season_code,
  e.txt_location, e.txt_country, e.txt_venue_address,
  e.url_invitation, e.num_entry_fee,
  e.dt_start, e.dt_end, e.url_event, e.enum_status,
  COUNT(t.id_tournament)::INT AS num_tournaments,
  COALESCE(BOOL_OR(t.enum_type IN ('PEW','MEW','MSW','PSW')), FALSE) AS bool_has_international
FROM tbl_event e
JOIN tbl_season s ON s.id_season = e.id_season
LEFT JOIN tbl_tournament t ON t.id_event = e.id_event
GROUP BY e.id_event, s.txt_code
ORDER BY e.dt_start ASC;

-- Grant anon access (public calendar read)
GRANT SELECT ON vw_calendar TO anon;
GRANT SELECT ON vw_calendar TO authenticated;
