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
    ('EVF',  'European Veterans Fencing');

-- Master fencer list (270 members) loaded from seed_tbl_fencer.sql via config.toml
-- Sample events/tournaments removed; real data auto-loaded from data/**/
