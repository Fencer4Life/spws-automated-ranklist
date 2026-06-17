-- N13.4 — overlap-clobber fix: discovered ingest sources + admin overrides on tbl_event.
--
-- The from-URL keep-rule (one source per gender·weapon·age_category) auto-picks and
-- flags duplicates. The set-aside / dropped (pools-only) rounds are NOT scored — they
-- live as display-only JSONB on the event and are rendered as greyed rows in the event
-- accordion, where an admin can toggle skip/process and re-ingest. No separate table,
-- and these JSONBs never enter tbl_result or any ranking view (no scored-data pollution).
--
-- Relates to: ADR-067 (pools-only skip), ADR-006 (JSONB-in-DB config precedent),
-- ADR-041 (re-ingest dispatch from the UI).

ALTER TABLE tbl_event
  ADD COLUMN IF NOT EXISTS json_ingest_sources   JSONB,
  ADD COLUMN IF NOT EXISTS json_source_overrides JSONB;

COMMENT ON COLUMN tbl_event.json_ingest_sources IS
  'Display-only (N13.4): FTL rounds discovered at the last ingest + status '
  '(committed/dropped/skipped) + duplicate flags. Never scored; rendered in the accordion.';
COMMENT ON COLUMN tbl_event.json_source_overrides IS
  'Admin per-source skip/process choices, e.g. {"skip":[url],"process":[url]}. '
  'Read by the next from-URL ingest to override the default keep-rule.';

-- UI write path: the accordion saves the admin''s skip/process choice via this RPC.
CREATE OR REPLACE FUNCTION fn_set_event_source_override(
  p_event_id   INT,
  p_overrides  JSONB
) RETURNS VOID
LANGUAGE sql AS $$
  UPDATE tbl_event SET json_source_overrides = p_overrides WHERE id_event = p_event_id;
$$;

-- Expose both columns on vw_calendar so the admin form round-trips (the
-- tbl_event-new-column → rebuild-vw_calendar rule). Recreate the view verbatim + 2 cols.
DROP VIEW IF EXISTS vw_calendar;
CREATE VIEW vw_calendar AS
SELECT
  e.id_event, e.txt_code, e.txt_name, e.id_season,
  s.txt_code AS txt_season_code,
  e.id_organizer, o.txt_name AS txt_organizer_name,
  e.txt_location, e.txt_country, e.txt_venue_address,
  e.url_invitation, e.num_entry_fee, e.txt_entry_fee_currency,
  e.arr_weapons,
  e.dt_start, e.dt_end, e.url_event, e.enum_status,
  e.url_registration, e.dt_registration_deadline,
  COUNT(t.id_tournament)::INT AS num_tournaments,
  COALESCE(BOOL_OR(t.enum_type IN ('PEW','MEW','MSW','PSW')), FALSE) AS bool_has_international,
  e.json_ingest_sources, e.json_source_overrides
FROM tbl_event e
JOIN tbl_season s ON s.id_season = e.id_season
LEFT JOIN tbl_organizer o ON o.id_organizer = e.id_organizer
LEFT JOIN tbl_tournament t ON t.id_event = e.id_event
GROUP BY e.id_event, s.txt_code, o.txt_name
ORDER BY e.dt_start ASC;

GRANT SELECT ON vw_calendar TO anon;
GRANT SELECT ON vw_calendar TO authenticated;
