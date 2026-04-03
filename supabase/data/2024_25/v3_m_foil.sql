-- =========================================================================
-- Season 2024-2025 — V3 M FOIL — generated from FLORET-3-2024-2025.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- ---- PP1: I Puchar Polski Weteranów (KONIN) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW1-2024-2025',
    'I Puchar Polski Weteranów',
    'KONIN',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW1-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW1-2024-2025'),
    'PPW1-V3-M-FOIL-2024-2025',
    'I Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V3',
    '2024-09-29', 2, 'https://www.fencingtimelive.com/events/results/2965FA91D33D4CFDBC61E02F6BCC3356',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    163,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-FOIL-2024-2025'),
    1,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    185,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-FOIL-2024-2025'),
    2,
    'POKRZYWA Mariusz'
); -- matched: POKRZYWA Mariusz (score=100.0)
-- Compute scores for PP1-V3-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-FOIL-2024-2025')
);

-- ---- PP2: II Puchar Polski Weteranów (BYTOM) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW2-2024-2025',
    'II Puchar Polski Weteranów',
    'BYTOM',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW2-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW2-2024-2025'),
    'PPW2-V3-M-FOIL-2024-2025',
    'II Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V3',
    '2024-10-27', 2, 'https://www.fencingtimelive.com/events/results/BB46C864D2EE498A96C27152A07AE1AE',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    163,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-FOIL-2024-2025'),
    1,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    185,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-FOIL-2024-2025'),
    2,
    'POKRZYWA Mariusz'
); -- matched: POKRZYWA Mariusz (score=100.0)
-- Compute scores for PP2-V3-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-FOIL-2024-2025')
);

-- ---- PP3: III Puchar Polski Weteranów (KRAKÓW) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW3-2024-2025',
    'III Puchar Polski Weteranów',
    'KRAKÓW',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW3-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW3-2024-2025'),
    'PPW3-V3-M-FOIL-2024-2025',
    'III Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V3',
    '2024-12-01', 4, 'https://www.fencingtimelive.com/events/results/BC7C07A585A04CF88EF7430AD0528091',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    163,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-FOIL-2024-2025'),
    1,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    185,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-FOIL-2024-2025'),
    2,
    'POKRZYWA MARIUSZ'
); -- matched: POKRZYWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-FOIL-2024-2025'),
    3,
    'MAŁASIŃSKI Adam'
); -- matched: MAŁASIŃSKI Adam (score=100.0)
-- UNMATCHED (score<80): 'ŻYCZKOWSKI KAROL' place=4
-- Compute scores for PP3-V3-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-FOIL-2024-2025')
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
    'MPW-V3-M-FOIL-2024-2025',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'FOIL', 'M', 'V3',
    '2025-06-08', 4, 'https://www.fencingtimelive.com/tournaments/eventSchedule/B2C615704AB84D0F85BBFF395C07BA41',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    42,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-FOIL-2024-2025'),
    1,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    185,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-FOIL-2024-2025'),
    2,
    'POKRZYWA Mariusz'
); -- matched: POKRZYWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-FOIL-2024-2025'),
    3,
    'MAŁASIŃSKI Adam'
); -- matched: MAŁASIŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    191,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-FOIL-2024-2025'),
    4,
    'PYZIK Zdzisław'
); -- matched: PYZIK Zdzisław (score=100.0)
-- Compute scores for MPW-V3-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-FOIL-2024-2025')
);

-- ---- PEW1: EVF Grand Prix 1 — Budapeszt (Budapest) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW1-2024-2025',
    'EVF Grand Prix 1 — Budapeszt',
    'Budapest',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW1-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1-2024-2025'),
    'PEW1-V3-M-FOIL-2024-2025',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'FOIL', 'M', 'V3',
    '2024-09-22', 16, 'https://engarde-service.com/app.php?id=4209S3',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    42,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-FOIL-2024-2025'),
    10,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    35,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-FOIL-2024-2025'),
    16,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
-- Compute scores for PEW1-V3-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-FOIL-2024-2025')
);

-- ---- PEW2: EVF Grand Prix 2 — Madryt (Madrid) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW2-2024-2025',
    'EVF Grand Prix 2 — Madryt',
    'Madrid',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW2-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW2-2024-2025'),
    'PEW2-V3-M-FOIL-2024-2025',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'FOIL', 'M', 'V3',
    '2024-11-17', 16, 'https://engarde-service.com/competition/aeve_esgrima/evf_madrid_2024/t-fm-3',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    42,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V3-M-FOIL-2024-2025'),
    1,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
-- Compute scores for PEW2-V3-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V3-M-FOIL-2024-2025')
);

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): N=0 — tournament had no participants

-- ---- PEW8: EVF Grand Prix 8 — Guildford (WARSZAWA) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW8-2024-2025',
    'EVF Grand Prix 8 — Guildford',
    'WARSZAWA',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW8-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW8-2024-2025'),
    'PEW8-V3-M-FOIL-2024-2025',
    'EVF Grand Prix 8 — Guildford',
    'PEW',
    'FOIL', 'M', 'V3',
    '2025-03-30', 14, 'https://www.fencingtimelive.com/events/results/D18CF3A475804DB0883332925DC05620',
    'SCORED'
);
-- UNMATCHED (score<80): 'CSÁK Attila' place=1
-- UNMATCHED (score<80): 'RIJSENBRIJ Hans' place=2
-- UNMATCHED (score<80): 'MÉSZÁROS András' place=3
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    42,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V3-M-FOIL-2024-2025'),
    3,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
-- UNMATCHED (score<80): 'RAEKER Hans Martin' place=5
-- UNMATCHED (score<80): 'MONDT Bas' place=6
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    163,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V3-M-FOIL-2024-2025'),
    7,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
-- UNMATCHED (score<80): 'SÁRDI Tamás' place=8
-- UNMATCHED (score<80): 'POSTHUMA Frans' place=9
-- UNMATCHED (score<80): 'LEE Philip' place=10
-- UNMATCHED (score<80): 'PÉNTEK Tamás' place=11
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V3-M-FOIL-2024-2025'),
    12,
    'MAŁASIŃSKI Adam'
); -- matched: MAŁASIŃSKI Adam (score=100.0)
-- UNMATCHED (score<80): 'WATTENBERG Dirk' place=13
-- UNMATCHED (score<80): 'SZABÓ Imre' place=14
-- Compute scores for PEW8-V3-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V3-M-FOIL-2024-2025')
);

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
    'IMEW-V3-M-FOIL-2024-2025',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'FOIL', 'M', 'V3',
    '2025-05-29', 48, 'https://www.fencingtimelive.com/events/results/37042CA781E0442AAA098E167531B971',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    163,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-FOIL-2024-2025'),
    24,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
-- Compute scores for IMEW-V3-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-FOIL-2024-2025')
);

-- Summary
-- Total results matched:   18
-- Total results unmatched: 12
