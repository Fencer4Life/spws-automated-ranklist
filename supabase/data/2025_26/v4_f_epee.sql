-- =========================================================================
-- Season 2025-2026 — V4 F EPEE — generated from SZPADA-K4-2025-2026.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- SKIP PP1 (I Puchar Polski Weteranów): N=0 — tournament had no participants

-- SKIP PP2 (II Puchar Polski Weteranów): N=0 — tournament had no participants

-- SKIP PP3 (III Puchar Polski Weteranów): N=0 — tournament had no participants

-- SKIP PP4 (IV Puchar Polski Weteranów): N=0 — tournament had no participants
-- ---- PEW6: EVF Grand Prix 6 (WARSZAWA) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW6-2025-2026',
    'EVF Grand Prix 6',
    'WARSZAWA',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW6-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW6-2025-2026'),
    'PEW6-V4-F-EPEE-2025-2026',
    'EVF Grand Prix 6',
    'PEW',
    'EPEE', 'F', 'V4',
    '2026-03-28', 6, 'https://www.fencingtimelive.com/events/results/E1F972B682BF4A8D855B41B752564697',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    248,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-F-EPEE-2025-2026'),
    5,
    'SOSNOWSKA Aniela'
); -- matched: SOSNOWSKA Aniela (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    23,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-F-EPEE-2025-2026'),
    6,
    'BORKOWSKA Halina'
); -- matched: BORKOWSKA Halina (score=100.0)
-- Compute scores for PEW6-V4-F-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-F-EPEE-2025-2026')
);

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): N=0 — tournament had no participants

-- SKIP PS (Puchar Świata): N=0 — tournament had no participants

-- Summary
-- Total results matched:   6
-- Total results unmatched: 0
-- Total auto-created:      0
