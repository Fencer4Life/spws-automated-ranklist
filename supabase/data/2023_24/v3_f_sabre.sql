-- =========================================================================
-- Season 2023-2024 — V3 F SABRE — generated from SZABLA-K3-2023-2024.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- SKIP GP1 (Grand Prix (runda 1)): N=0 — tournament had no participants

-- ---- GP2: Grand Prix (runda 2) (TORUŃ) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'GP2-2023-2024',
    'Grand Prix (runda 2)',
    'TORUŃ',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'GP2-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'GP2-2023-2024'),
    'GP2-V3-F-SABRE-2023-2024',
    'Grand Prix (runda 2)',
    'PPW',
    'SABRE', 'F', 'V3',
    '2023-03-05', 1, 'https://www.fencingtimelive.com/events/results/F3325D7247534BFCAD156E0C685D4020',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    287,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-F-SABRE-2023-2024'),
    1,
    'FUHRMANN Ulrike'
); -- matched: FUHRMANN Ulrike (score=100.0)
-- Compute scores for GP2-V3-F-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-F-SABRE-2023-2024')
);

-- SKIP GP3 (Grand Prix (runda 3)): N=0 — tournament had no participants

-- SKIP GP4 (Grand Prix (runda 4)): N=0 — tournament had no participants

-- SKIP GP5 (Grand Prix (runda 5)): N=0 — tournament had no participants

-- ---- GP6: Grand Prix (runda 6) (KRAKÓW) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'GP6-2023-2024',
    'Grand Prix (runda 6)',
    'KRAKÓW',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'GP6-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'GP6-2023-2024'),
    'GP6-V3-F-SABRE-2023-2024',
    'Grand Prix (runda 6)',
    'PPW',
    'SABRE', 'F', 'V3',
    '2023-11-18', 1, 'https://www.fencingtimelive.com/events/results/8652CA83471542E2A6F4EEF73C854E33',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    287,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-F-SABRE-2023-2024'),
    1,
    'FUHRMANN Ulrike'
); -- matched: FUHRMANN Ulrike (score=100.0)
-- Compute scores for GP6-V3-F-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-F-SABRE-2023-2024')
);

-- ---- GP7: Grand Prix (runda 7) (SPAŁA) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'GP7-2023-2024',
    'Grand Prix (runda 7)',
    'SPAŁA',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'GP7-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'GP7-2023-2024'),
    'GP7-V3-F-SABRE-2023-2024',
    'Grand Prix (runda 7)',
    'PPW',
    'SABRE', 'F', 'V3',
    '2024-01-28', 1, 'https://www.fencingtimelive.com/events/results/1A29168AB3284C228E01F0EDE9D8A138',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    287,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V3-F-SABRE-2023-2024'),
    1,
    'FUHRMANN Ulrike'
); -- matched: FUHRMANN Ulrike (score=100.0)
-- Compute scores for GP7-V3-F-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V3-F-SABRE-2023-2024')
);

-- SKIP GP8 (Grand Prix (runda 8)): N=0 — tournament had no participants

-- ---- MPW: Mistrzostwa Polski Weteranów (WARSZAWA) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'MPW-2023-2024',
    'Mistrzostwa Polski Weteranów',
    'WARSZAWA',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'MPW-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'MPW-2023-2024'),
    'MPW-V3-F-SABRE-2023-2024',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'SABRE', 'F', 'V3',
    '2024-03-02', 1, 'https://www.fencingtimelive.com/events/results/F2E70A712A9A4ED5AEA1E05CDC71272E',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    287,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-F-SABRE-2023-2024'),
    1,
    'FUHRMANN Ulrike'
); -- matched: FUHRMANN Ulrike (score=100.0)
-- Compute scores for MPW-V3-F-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-F-SABRE-2023-2024')
);

-- SKIP PEW1 (EVF Grand Prix 1 — Budapeszt): N=0 — tournament had no participants

-- SKIP PEW2 (EVF Grand Prix 2 — Madryt): N=0 — tournament had no participants

-- SKIP PEW3 (EVF Grand Prix 3): N=0 — tournament had no participants

-- ---- PEW4: EVF Grand Prix 4 (Liege) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW4-2023-2024',
    'EVF Grand Prix 4',
    'Liege',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW4-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW4-2023-2024'),
    'PEW4-V3-F-SABRE-2023-2024',
    'EVF Grand Prix 4',
    'PEW',
    'SABRE', 'F', 'V3',
    '2023-04-01', 3, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    287,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V3-F-SABRE-2023-2024'),
    2,
    'FUHRMANN Ulrike'
); -- matched: FUHRMANN Ulrike (score=100.0)
-- Compute scores for PEW4-V3-F-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V3-F-SABRE-2023-2024')
);

-- SKIP PEW5 (EVF Grand Prix 5): N=0 — tournament had no participants

-- SKIP PEW6 (EVF Grand Prix 6): N=0 — tournament had no participants

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): N=0 — tournament had no participants

-- SKIP PEW8 (EVF Grand Prix 8 — Guildford): N=0 — tournament had no participants

-- SKIP PEW9 (EVF Grand Prix 9 — Sztokholm): N=0 — tournament had no participants

-- SKIP PEW10 (EVF Grand Prix 10 — Graz): N=0 — tournament had no participants

-- SKIP PEW11 (EVF Grand Prix 11 — Gdańsk): N=0 — tournament had no participants

-- ---- PEW12: EVF Grand Prix 12 — Ateny (Liège) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW12-2023-2024',
    'EVF Grand Prix 12 — Ateny',
    'Liège',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW12-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW12-2023-2024'),
    'PEW12-V3-F-SABRE-2023-2024',
    'EVF Grand Prix 12 — Ateny',
    'PEW',
    'SABRE', 'F', 'V3',
    '2024-04-06', 5, 'https://www.veteransfencing.eu/fencing/rankings/',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    287,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW12-V3-F-SABRE-2023-2024'),
    1,
    'FUHRMANN Ulrike'
); -- matched: FUHRMANN Ulrike (score=100.0)
-- Compute scores for PEW12-V3-F-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW12-V3-F-SABRE-2023-2024')
);

-- ---- IMEW: Indywidualne Mistrzostwa Europy Weteranów (Thionville) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'IMEW-2023-2024',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'Thionville',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'IMEW-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'IMEW-2023-2024'),
    'IMEW-V3-F-SABRE-2023-2024',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'SABRE', 'F', 'V3',
    '2023-01-01', 15, 'https://engarde-service.com/competition/e3f/efcv/womensabrev3',
    'SCORED'
);
-- UNMATCHED (score<80): 'HUTCHISON' place=1
-- UNMATCHED (score<80): 'ZINI' place=2
-- UNMATCHED (score<80): 'CONCONI' place=3
-- UNMATCHED (score<80): 'SELTENHAMMER' place=3
-- UNMATCHED (score<80): 'CAMERIN' place=5
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    287,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-F-SABRE-2023-2024'),
    6,
    'FUHRMANN Ulrike'
); -- matched: FUHRMANN Ulrike (score=100.0)
-- UNMATCHED (score<80): 'REGUIGNE' place=7
-- UNMATCHED (score<80): 'WEIMAR' place=8
-- UNMATCHED (score<80): 'HENDRA' place=9
-- UNMATCHED (score<80): 'MARTIN CID' place=10
-- UNMATCHED (score<80): 'MORRIS' place=11
-- UNMATCHED (score<80): 'AEBI' place=12
-- UNMATCHED (score<80): 'BUENO DIEZ' place=13
-- UNMATCHED (score<80): 'KENNETT' place=14
-- UNMATCHED (score<80): 'FINDLAY' place=15
-- Compute scores for IMEW-V3-F-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-F-SABRE-2023-2024')
);

-- Summary
-- Total results matched:   7
-- Total results unmatched: 14
