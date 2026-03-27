-- =============================================================================
-- Add entry fee currency column to tbl_event
-- =============================================================================
-- Adds txt_entry_fee_currency (TEXT, default 'PLN') for multi-currency support.
-- Recreates vw_calendar to expose the new column.
-- =============================================================================

ALTER TABLE tbl_event ADD COLUMN IF NOT EXISTS txt_entry_fee_currency TEXT DEFAULT 'PLN';

-- Recreate vw_calendar to include currency column
-- Must DROP + CREATE (not CREATE OR REPLACE) because new column is not appended at the end
DROP VIEW IF EXISTS vw_calendar;
CREATE VIEW vw_calendar AS
SELECT
  e.id_event, e.txt_code, e.txt_name, e.id_season,
  s.txt_code AS txt_season_code,
  e.id_organizer, o.txt_name AS txt_organizer_name,
  e.txt_location, e.txt_country, e.txt_venue_address,
  e.url_invitation, e.num_entry_fee, e.txt_entry_fee_currency,
  e.dt_start, e.dt_end, e.url_event, e.enum_status,
  COUNT(t.id_tournament)::INT AS num_tournaments,
  COALESCE(BOOL_OR(t.enum_type IN ('PEW','MEW','MSW','PSW')), FALSE) AS bool_has_international
FROM tbl_event e
JOIN tbl_season s ON s.id_season = e.id_season
LEFT JOIN tbl_organizer o ON o.id_organizer = e.id_organizer
LEFT JOIN tbl_tournament t ON t.id_event = e.id_event
GROUP BY e.id_event, s.txt_code, o.txt_name
ORDER BY e.dt_start ASC;

GRANT SELECT ON vw_calendar TO anon;
GRANT SELECT ON vw_calendar TO authenticated;
