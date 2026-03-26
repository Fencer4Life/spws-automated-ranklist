-- =========================================================================
-- Season 2024-2025 — V4 F SABRE — generated from SZABLA-K4-2024-2025.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- SKIP PP1 (I Puchar Polski Weteranów): N=0 — tournament had no participants

-- SKIP PP2 (II Puchar Polski Weteranów): N=0 — tournament had no participants

-- ---- PP3: III Puchar Polski Weteranów (KRAKÓW) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PP3-2024-2025',
    'III Puchar Polski Weteranów',
    'KRAKÓW',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PP3-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PP3-2024-2025'),
    'PP3-V4-F-SABRE-2024-2025',
    'III Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'F', 'V4',
    '2024-12-01', 1, 'https://www.fencingtimelive.com/events/results/BDA01BA67FE3481998EF770A16A1FAED',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    213,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V4-F-SABRE-2024-2025'),
    1,
    'SOSNOWSKA Aniela'
); -- matched: SOSNOWSKA Aniela (score=100.0)
-- Compute scores for PP3-V4-F-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V4-F-SABRE-2024-2025')
);

-- ---- MPW: Mistrzostwa Polski Weteranów (PABIANICE) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'MPW-2024-2025',
    'Mistrzostwa Polski Weteranów',
    'PABIANICE',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'MPW-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'MPW-2024-2025'),
    'MPW-V4-F-SABRE-2024-2025',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'SABRE', 'F', 'V4',
    '2025-06-08', 1, 'https://www.fencingtimelive.com/events/results/CF111F026D3D4B778F791112A113642C',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    213,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-F-SABRE-2024-2025'),
    1,
    'SOSNOWSKA Aniela'
); -- matched: SOSNOWSKA Aniela (score=100.0)
-- Compute scores for MPW-V4-F-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-F-SABRE-2024-2025')
);

-- SKIP PEW1 (EVF Grand Prix 1 — Budapeszt): N=0 — tournament had no participants

-- SKIP PEW2 (EVF Grand Prix 2 — Madryt): N=0 — tournament had no participants

-- ---- PEW7: EVF Grand Prix 7 — Terni (Warszawa) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW7-2024-2025',
    'EVF Grand Prix 7 — Terni',
    'Warszawa',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW7-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW7-2024-2025'),
    'PEW7-V4-F-SABRE-2024-2025',
    'EVF Grand Prix 7 — Terni',
    'PEW',
    'SABRE', 'F', 'V4',
    '2025-03-29', 3, 'https://www.fencingtimelive.com/events/results/FA515CDF8BF74AE8825CF038062E6384',
    'SCORED'
);
-- UNMATCHED (score<80): 'ALBINI Adriana' place=1
-- UNMATCHED (score<80): 'GREEN Linda' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    213,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V4-F-SABRE-2024-2025'),
    3,
    'SOSNOWSKA Aniela'
); -- matched: SOSNOWSKA Aniela (score=100.0)
-- Compute scores for PEW7-V4-F-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V4-F-SABRE-2024-2025')
);

-- SKIP PEW8 (EVF Grand Prix 8 — Guildford): N=0 — tournament had no participants

-- SKIP PEW9 (EVF Grand Prix 9 — Sztokholm): N=0 — tournament had no participants

-- ---- IMEW: Indywidualne Mistrzostwa Europy Weteranów (Płowdiw) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'IMEW-2024-2025',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'Płowdiw',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'IMEW-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'IMEW-2024-2025'),
    'IMEW-V4-F-SABRE-2024-2025',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'SABRE', 'F', 'V4',
    '2025-05-29', 13, 'https://www.fencingtimelive.com/events/results/E77D198F05E94EE2A33952DA989BF7DF',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    213,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V4-F-SABRE-2024-2025'),
    11,
    'SOSNOWSKA Aniela'
); -- matched: SOSNOWSKA Aniela (score=100.0)
-- Compute scores for IMEW-V4-F-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V4-F-SABRE-2024-2025')
);

-- Summary
-- Total results matched:   4
-- Total results unmatched: 2
