-- =============================================================================
-- EVF source-of-truth FK columns
-- =============================================================================
-- Adds two integer columns linking our DB to the EVF API
-- (api.veteransfencing.eu):
--
--   tbl_event.id_evf_event             — EVF event id (e.g. 87 for Jablonna 2026)
--   tbl_tournament.id_evf_competition  — EVF competition id (e.g. 1249 for V2-M-SABRE)
--
-- These are NULL for non-EVF rows (PPW/MPW domestic, IMEW-2023-2024 Engarde
-- legacy, Ophardt-only PEW15f-2024-2025). Populated by the EVF scraper at
-- ingest time; backfilled for already-ingested PEW + IMEW rows by
-- python/tools/backfill_evf_fks.py. Domestic FTL/XML/Engarde scrapers must
-- never write to these columns.
-- =============================================================================

ALTER TABLE tbl_event
  ADD COLUMN IF NOT EXISTS id_evf_event INTEGER;

ALTER TABLE tbl_tournament
  ADD COLUMN IF NOT EXISTS id_evf_competition INTEGER;

COMMENT ON COLUMN tbl_event.id_evf_event IS
  'EVF API event id from api.veteransfencing.eu. NULL for non-EVF events (PPW/MPW/Engarde-legacy).';
COMMENT ON COLUMN tbl_tournament.id_evf_competition IS
  'EVF API competition id (per-event/weapon/gender/category). NULL for non-EVF tournaments.';

CREATE INDEX IF NOT EXISTS idx_tbl_event_evf
  ON tbl_event (id_evf_event)
  WHERE id_evf_event IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_tbl_tournament_evf
  ON tbl_tournament (id_evf_competition)
  WHERE id_evf_competition IS NOT NULL;


-- -----------------------------------------------------------------------------
-- Rebuild vw_calendar to expose id_evf_event so admin form round-trip stays
-- consistent (per feedback_view_rebuild_on_tbl_event memory).
-- -----------------------------------------------------------------------------
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
  e.url_event_2, e.url_event_3, e.url_event_4, e.url_event_5,
  e.id_evf_event,
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
