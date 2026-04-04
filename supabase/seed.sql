-- =============================================================================
-- Bootstrap Seed: Seasons and Organizers
-- =============================================================================
-- This file creates the minimum bootstrap data required before season data loads.
-- Load order (controlled by config.toml sql_paths):
--   1. seed.sql            — seasons, organizers (this file)
--   2. seed_tbl_fencer.sql — SPWS master fencer list (270 members)
--   3. data/**/*.sql       — season data files, one per age category per season
-- Needed for:
--   - Test assertions (1.12 seed data exists)
--   - Tests that need FK targets (1.4, 1.5, 1.11, etc.)
--   - Identity resolution in M4/M5
-- =============================================================================

-- Seasons (each auto-creates scoring config via trigger)
INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
VALUES ('SPWS-2023-2024', '2023-08-15', '2024-07-15', FALSE);  -- historical

INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
VALUES ('SPWS-2024-2025', '2024-08-15', '2025-07-15', FALSE);  -- historical

INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
VALUES ('SPWS-2025-2026', '2025-08-01', '2026-07-15', TRUE);   -- active (no tournaments yet)

-- Organizers
INSERT INTO tbl_organizer (txt_code, txt_name) VALUES
    ('SPWS', 'Stowarzyszenie Polskich Weteranów Szermierki'),
    ('EVF',  'European Veterans Fencing'),
    ('FIE',  'Fédération Internationale d''Escrime');

-- Master fencer list (270 members) loaded from seed_tbl_fencer.sql via config.toml
-- Sample events/tournaments removed; real data auto-loaded from data/**/

-- =========================================================================
-- Future events in active season (SCHEDULED, no results yet)
-- Needed for rolling score carry-over: fn_ranking_ppw(p_rolling:=TRUE)
-- identifies positions with SCHEDULED counterparts and carries previous
-- season scores forward.
-- =========================================================================
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, txt_location, txt_country)
SELECT 'PPW5-2025-2026', 'V Puchar Polski Weteranów',
       s.id_season, o.id_organizer, 'SCHEDULED', '2026-05-23', 'TBD', 'Polska'
FROM tbl_season s, tbl_organizer o
WHERE s.txt_code = 'SPWS-2025-2026' AND o.txt_code = 'SPWS'
  AND NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW5-2025-2026');

INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, txt_location, txt_country)
SELECT 'MPW-2025-2026', 'Mistrzostwa Polski Weteranów',
       s.id_season, o.id_organizer, 'SCHEDULED', '2026-06-13', 'TBD', 'Polska'
FROM tbl_season s, tbl_organizer o
WHERE s.txt_code = 'SPWS-2025-2026' AND o.txt_code = 'SPWS'
  AND NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'MPW-2025-2026');
