-- =========================================================================
-- Season 2023-2024 — V3 F FOIL — generated from FLORET-K3-2023-2024.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- ---- GP1: Grand Prix (runda 1) (PABIANICE) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'GP1-2023-2024',
    'Grand Prix (runda 1)',
    'PABIANICE',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'GP1-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'GP1-2023-2024'),
    'GP1-V3-F-FOIL-2023-2024',
    'Grand Prix (runda 1)',
    'PPW',
    'FOIL', 'F', 'V3',
    '2023-01-15', 2, 'https://www.fencingtimelive.com/events/results/BC88CDA795034C5580B13ABF90497493',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    23,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-F-FOIL-2023-2024'),
    1,
    'BORKOWSKA Halina'
); -- matched: BORKOWSKA Halina (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    182,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-F-FOIL-2023-2024'),
    2,
    'MULSON Irena'
); -- matched: MULSON Irena (score=100.0)
-- Compute scores for GP1-V3-F-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-F-FOIL-2023-2024')
);

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
    'GP2-V3-F-FOIL-2023-2024',
    'Grand Prix (runda 2)',
    'PPW',
    'FOIL', 'F', 'V3',
    '2023-03-05', 1, 'https://www.fencingtimelive.com/events/results/398DDAEEC00B4D94A99AFBE220A5E57D',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    182,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-F-FOIL-2023-2024'),
    1,
    'MULSON Irena'
); -- matched: MULSON Irena (score=100.0)
-- Compute scores for GP2-V3-F-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-F-FOIL-2023-2024')
);

-- ---- GP3: Grand Prix (runda 3) (NIEPOŁOMICE) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'GP3-2023-2024',
    'Grand Prix (runda 3)',
    'NIEPOŁOMICE',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'GP3-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'GP3-2023-2024'),
    'GP3-V3-F-FOIL-2023-2024',
    'Grand Prix (runda 3)',
    'PPW',
    'FOIL', 'F', 'V3',
    '2023-06-18', 2, 'https://www.fencingtimelive.com/events/results/98BD669190E148C9BD47636A247239D6',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    23,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-F-FOIL-2023-2024'),
    1,
    'BORKOWSKA Halina'
); -- matched: BORKOWSKA Halina (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    182,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-F-FOIL-2023-2024'),
    2,
    'MULSON Irena'
); -- matched: MULSON Irena (score=100.0)
-- Compute scores for GP3-V3-F-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-F-FOIL-2023-2024')
);

-- ---- GP4: Grand Prix (runda 4) (OPOLE) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'GP4-2023-2024',
    'Grand Prix (runda 4)',
    'OPOLE',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'GP4-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'GP4-2023-2024'),
    'GP4-V3-F-FOIL-2023-2024',
    'Grand Prix (runda 4)',
    'PPW',
    'FOIL', 'F', 'V3',
    '2023-10-23', 1, 'https://www.fencingtimelive.com/events/results/E7472153EC684DA8BAEC60C626D19B11',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    23,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V3-F-FOIL-2023-2024'),
    1,
    'BORKOWSKA Halina'
); -- matched: BORKOWSKA Halina (score=100.0)
-- Compute scores for GP4-V3-F-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V3-F-FOIL-2023-2024')
);

-- ---- GP5: Grand Prix (runda 5) (GDAŃSK) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'GP5-2023-2024',
    'Grand Prix (runda 5)',
    'GDAŃSK',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'GP5-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'GP5-2023-2024'),
    'GP5-V3-F-FOIL-2023-2024',
    'Grand Prix (runda 5)',
    'PPW',
    'FOIL', 'F', 'V3',
    '2023-10-28', 2, 'https://www.fencingtimelive.com/events/results/6DDEF73613864C3689CEE17CF5F2A317',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    23,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V3-F-FOIL-2023-2024'),
    1,
    'BORKOWSKA Halina'
); -- matched: BORKOWSKA Halina (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    182,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V3-F-FOIL-2023-2024'),
    2,
    'MULSON Irena'
); -- matched: MULSON Irena (score=100.0)
-- Compute scores for GP5-V3-F-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V3-F-FOIL-2023-2024')
);

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
    'GP6-V3-F-FOIL-2023-2024',
    'Grand Prix (runda 6)',
    'PPW',
    'FOIL', 'F', 'V3',
    '2023-11-18', 1, 'https://www.fencingtimelive.com/tournaments/eventSchedule/D70668CEB8754915920393A22468C3AB',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    23,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-F-FOIL-2023-2024'),
    1,
    'BORKOWSKA Halina'
); -- matched: BORKOWSKA Halina (score=100.0)
-- Compute scores for GP6-V3-F-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-F-FOIL-2023-2024')
);

-- SKIP GP7 (Grand Prix (runda 7)): N=0 — tournament had no participants

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
    'MPW-V3-F-FOIL-2023-2024',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'FOIL', 'F', 'V3',
    '2024-03-02', 1, 'https://www.fencingtimelive.com/events/results/558B693ECA074884937402307A9A6066',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    277,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-F-FOIL-2023-2024'),
    1,
    'TOMASZEWSKA Hanna'
); -- matched: TOMASZEWSKA Hanna (score=100.0)
-- Compute scores for MPW-V3-F-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-F-FOIL-2023-2024')
);

-- SKIP PEW1 (EVF Grand Prix 1 — Budapeszt): N=0 — tournament had no participants

-- SKIP PEW2 (EVF Grand Prix 2 — Madryt): N=0 — tournament had no participants

-- SKIP PEW3 (EVF Grand Prix 3): N=0 — tournament had no participants

-- SKIP PEW4 (EVF Grand Prix 4): N=0 — tournament had no participants

-- SKIP PEW5 (EVF Grand Prix 5): N=0 — tournament had no participants

-- SKIP PEW6 (EVF Grand Prix 6): N=0 — tournament had no participants

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): N=0 — tournament had no participants

-- SKIP PEW8 (EVF Grand Prix 8 — Guildford): N=0 — tournament had no participants

-- SKIP PEW9 (EVF Grand Prix 9 — Sztokholm): N=0 — tournament had no participants

-- SKIP PEW10 (EVF Grand Prix 10 — Graz): N=0 — tournament had no participants

-- SKIP PEW11 (EVF Grand Prix 11 — Gdańsk): N=0 — tournament had no participants

-- SKIP PEW12 (EVF Grand Prix 12 — Ateny): N=0 — tournament had no participants

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
    'IMEW-V3-F-FOIL-2023-2024',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'FOIL', 'F', 'V3',
    '2023-01-01', 24, 'https://engarde-service.com/competition/e3f/efcv/womenfoilv3',
    'SCORED'
);
-- SKIPPED (international, no master data): 'HILGERS' place=1
-- SKIPPED (international, no master data): 'CIRILLO' place=2
-- SKIPPED (international, no master data): 'CLAYTON' place=3
-- SKIPPED (international, no master data): 'KIRCHEIS' place=3
-- SKIPPED (international, no master data): 'WORMAN' place=5
-- SKIPPED (international, no master data): 'MORRIS' place=6
-- SKIPPED (international, no master data): 'AUBAILLY' place=7
-- SKIPPED (international, no master data): 'SZEREDAY' place=8
-- SKIPPED (international, no master data): 'SARACINO' place=9
-- SKIPPED (international, no master data): 'ROSENHAMMER' place=10
-- SKIPPED (international, no master data): 'MARTINOT' place=11
-- SKIPPED (international, no master data): 'DRESEN-KUCHALSKI' place=12
-- SKIPPED (international, no master data): 'DE GRAAF-STOEL' place=13
-- SKIPPED (international, no master data): 'TURNBULL' place=14
-- SKIPPED (international, no master data): 'WEI' place=15
-- SKIPPED (international, no master data): 'ARCHER' place=16
-- SKIPPED (international, no master data): 'HINTERSEER' place=17
-- SKIPPED (international, no master data): 'KOLCZONAY ERNONE' place=18
-- SKIPPED (international, no master data): 'FLEISCHER' place=19
-- SKIPPED (international, no master data): 'KENNETT' place=20
-- SKIPPED (international, no master data): 'ULM' place=21
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    23,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-F-FOIL-2023-2024'),
    22,
    'BORKOWSKA Halina'
); -- matched: BORKOWSKA Halina (score=100.0)
-- SKIPPED (international, no master data): 'KESSLING' place=23
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    182,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-F-FOIL-2023-2024'),
    24,
    'MULSON Irena'
); -- matched: MULSON Irena (score=100.0)
-- Compute scores for IMEW-V3-F-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-F-FOIL-2023-2024')
);

-- Summary
-- Total results matched:   12
-- Total results unmatched: 22
-- Total auto-created:      0
