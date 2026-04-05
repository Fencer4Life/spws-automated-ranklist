-- =========================================================================
-- Season 2025-2026 — V1 M EPEE — generated from SZPADA-1-2025-2026.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- ---- PP1: I Puchar Polski Weteranów (Szpada mężczyzn Weterani 1) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW1-2025-2026',
    'I Puchar Polski Weteranów',
    'Szpada mężczyzn Weterani 1',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW1-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW1-2025-2026'),
    'PPW1-V1-M-EPEE-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V1',
    NULL, 9, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    273,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2025-2026'),
    1,
    'SĘKOWSKI Maciej'
); -- matched: SĘKOWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    20,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2025-2026'),
    2,
    'BOBUSIA Jarosław'
); -- matched: BOBUSIA Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    275,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2025-2026'),
    3,
    'TATCHYN Andriy'
); -- matched: TATCHYN Andriy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    255,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2025-2026'),
    4,
    'STOCKI Piotr'
); -- matched: STOCKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    122,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2025-2026'),
    5,
    'KORNAŚ Jarosław'
); -- matched: KORNAŚ Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    43,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2025-2026'),
    6,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    80,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2025-2026'),
    7,
    'GROMADA Roland'
); -- matched: GROMADA Roland (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    25,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2025-2026'),
    8,
    'BOROWIEC Maciej'
); -- matched: BOROWIEC Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    210,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2025-2026'),
    9,
    'POKRYWA Bartosz'
); -- matched: POKRYWA Bartosz (score=100.0)
-- Compute scores for PPW1-V1-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2025-2026')
);

-- ---- PP2: II Puchar Polski Weteranów (SZPADA MĘŻCZYZN 1 WETERANI) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW2-2025-2026',
    'II Puchar Polski Weteranów',
    'SZPADA MĘŻCZYZN 1 WETERANI',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW2-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW2-2025-2026'),
    'PPW2-V1-M-EPEE-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V1',
    NULL, 6, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    273,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2025-2026'),
    1,
    'SĘKOWSKI Maciej'
); -- matched: SĘKOWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    148,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2025-2026'),
    2,
    'KULKA Dawid'
); -- matched: KULKA Dawid (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    80,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2025-2026'),
    3,
    'GROMADA Roland'
); -- matched: GROMADA Roland (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    255,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2025-2026'),
    4,
    'STOCKI Piotr'
); -- matched: STOCKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    210,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2025-2026'),
    5,
    'POKRYWA Bartosz'
); -- matched: POKRYWA Bartosz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    205,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2025-2026'),
    6,
    'PAWŁOWSKI Łukasz'
); -- matched: PAWŁOWSKI Łukasz (score=100.0)
-- Compute scores for PPW2-V1-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2025-2026')
);

-- ---- PP3: III Puchar Polski Weteranów (Szpada Mężczyzn kat. 1) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW3-2025-2026',
    'III Puchar Polski Weteranów',
    'Szpada Mężczyzn kat. 1',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW3-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW3-2025-2026'),
    'PPW3-V1-M-EPEE-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V1',
    NULL, 11, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    124,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    1,
    'KORONA Radosław'
); -- matched: KORONA Radosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    273,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    2,
    'SĘKOWSKI Maciej'
); -- matched: SĘKOWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    132,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    3,
    'KOWALCZYK Piotr'
); -- matched: KOWALCZYK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    255,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    4,
    'STOCKI Piotr'
); -- matched: STOCKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    43,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    5,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    142,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    6,
    'KRAMARZ Konrad'
); -- matched: KRAMARZ Konrad (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    275,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    7,
    'TATCHYN Andriy'
); -- matched: TATCHYN Andriy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    115,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    8,
    'KLEPACKI Denis'
); -- matched: KLEPACKI Denis (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    210,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    9,
    'POKRYWA Bartosz'
); -- matched: POKRYWA Bartosz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    205,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    10,
    'PAWŁOWSKI Łukasz'
); -- matched: PAWŁOWSKI Łukasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    37,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    11,
    'CHUDY Tomasz'
); -- matched: CHUDY Tomasz (score=100.0)
-- Compute scores for PPW3-V1-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026')
);

-- ---- PP4: IV Puchar Polski Weteranów (SZPADA MĘŻCZYZN v0v1) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW4-2025-2026',
    'IV Puchar Polski Weteranów',
    'SZPADA MĘŻCZYZN v0v1',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW4-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW4-2025-2026'),
    'PPW4-V1-M-EPEE-2025-2026',
    'IV Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V1',
    NULL, 7, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    273,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2025-2026'),
    1,
    'SĘKOWSKI Maciej'
); -- matched: SĘKOWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    43,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2025-2026'),
    2,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    255,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2025-2026'),
    3,
    'STOCKI Piotr'
); -- matched: STOCKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    275,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2025-2026'),
    4,
    'TATCHYN Andriy'
); -- matched: TATCHYN Andriy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    37,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2025-2026'),
    5,
    'CHUDY Tomasz'
); -- matched: CHUDY Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    254,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2025-2026'),
    6,
    'STAŃCZYK Marcin'
); -- matched: STAŃCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    205,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2025-2026'),
    7,
    'PAWŁOWSKI Łukasz'
); -- matched: PAWŁOWSKI Łukasz (score=100.0)
-- Compute scores for PPW4-V1-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2025-2026')
);
-- ---- PEW1: EVF Grand Prix 1 — Budapeszt (INTERNATIONAL VETERAN CHAMPIONSHIPS) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW1-2025-2026',
    'EVF Grand Prix 1 — Budapeszt',
    'INTERNATIONAL VETERAN CHAMPIONSHIPS',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW1-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1-2025-2026'),
    'PEW1-V1-M-EPEE-2025-2026',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'EPEE', 'M', 'V1',
    NULL, 33, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    20,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-M-EPEE-2025-2026'),
    5,
    'BOBUSIA Jarosław'
); -- matched: BOBUSIA Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    148,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-M-EPEE-2025-2026'),
    6,
    'KULKA Dawid'
); -- matched: KULKA Dawid (score=100.0)
-- Compute scores for PEW1-V1-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-M-EPEE-2025-2026')
);

-- ---- PEW2: EVF Grand Prix 2 — Madryt (VI Ciudad de Madrid CUP VETERANS FENCING) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW2-2025-2026',
    'EVF Grand Prix 2 — Madryt',
    'VI Ciudad de Madrid CUP VETERANS FENCING',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW2-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW2-2025-2026'),
    'PEW2-V1-M-EPEE-2025-2026',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'EPEE', 'M', 'V1',
    NULL, 27, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'KORONA' place=1
-- SKIPPED (international, no master data): 'REYNOSO' place=2
-- SKIPPED (international, no master data): 'VARONE' place=3
-- SKIPPED (international, no master data): 'PLAZZERIANO' place=4
-- SKIPPED (international, no master data): 'RUSEV' place=5
-- SKIPPED (international, no master data): 'RÁMILA GUTIÉRREZ' place=6
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    255,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-M-EPEE-2025-2026'),
    7,
    'STOCKI Piotr'
); -- matched: STOCKI Piotr (score=100.0)
-- SKIPPED (international, no master data): 'VIDAL SAYAS' place=8
-- SKIPPED (international, no master data): 'ALONSO ESCOBAR' place=9
-- SKIPPED (international, no master data): 'CASSAI' place=10
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    148,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-M-EPEE-2025-2026'),
    11,
    'KULKA Dawid'
); -- matched: KULKA Dawid (score=100.0)
-- SKIPPED (international, no master data): 'BAROGLIO' place=12
-- SKIPPED (international, no master data): 'TOKOLA' place=13
-- SKIPPED (international, no master data): 'PENA' place=14
-- SKIPPED (international, no master data): 'RIGO' place=15
-- SKIPPED (international, no master data): 'SERNA MUÑOZ' place=16
-- SKIPPED (international, no master data): 'FARKAS' place=17
-- SKIPPED (international, no master data): 'ALCSER' place=18
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    256,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-M-EPEE-2025-2026'),
    19,
    'STOLARIK'
); -- matched: STOLARIK Peter (score=72.72727272727273)
-- SKIPPED (international, no master data): 'GARDE' place=20
-- SKIPPED (international, no master data): 'GÓMEZ SÁNCHEZ' place=21
-- SKIPPED (international, no master data): 'FALERNO' place=22
-- SKIPPED (international, no master data): 'SOMORA' place=23
-- SKIPPED (international, no master data): 'SEÑÍS' place=24
-- SKIPPED (international, no master data): 'BOURDONCLE' place=25
-- SKIPPED (international, no master data): 'ALVEAR' place=26
-- SKIPPED (international, no master data): 'LAICH' place=27
-- Compute scores for PEW2-V1-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-M-EPEE-2025-2026')
);

-- ---- PEW3: EVF Grand Prix 3 (Men's Epee Category 1) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW3-2025-2026',
    'EVF Grand Prix 3',
    'Men''s Epee Category 1',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW3-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW3-2025-2026'),
    'PEW3-V1-M-EPEE-2025-2026',
    'EVF Grand Prix 3',
    'PEW',
    'EPEE', 'M', 'V1',
    NULL, 34, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'BAROGLIO 1 Simone' place=1
-- SKIPPED (international, no master data): 'BOSSER 1 Pierre-Julien' place=2
-- SKIPPED (international, no master data): 'BOBUSIA Dariusz' place=3
-- SKIPPED (international, no master data): 'AJZENSTADT 1 Ido' place=4
-- SKIPPED (international, no master data): 'SQUEO 1 Benedetto' place=5
-- SKIPPED (international, no master data): 'PEDONE 1 Mattia' place=6
-- SKIPPED (international, no master data): 'BULLWARD 1 Alistair' place=7
-- SKIPPED (international, no master data): 'WILS 1 Joppe' place=8
-- SKIPPED (international, no master data): 'RUSEV 1 Rosislav' place=9
-- SKIPPED (international, no master data): 'AGRENICH 1 Alex' place=10
-- SKIPPED (international, no master data): 'KAZIK 1 Tomas' place=11
-- SKIPPED (international, no master data): 'BURKHALTER 1 Marc' place=12
-- SKIPPED (international, no master data): 'BARBASIEWICZ 1 Philippe' place=13
-- SKIPPED (international, no master data): 'PARTICS 1 Peter' place=14
-- SKIPPED (international, no master data): 'MEASURES 1 Ben' place=15
-- SKIPPED (international, no master data): 'ROWE-HAYNES 1 Maxwell' place=16
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    255,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2025-2026'),
    17,
    'STOCKI Piotr'
); -- matched: STOCKI Piotr (score=100.0)
-- SKIPPED (international, no master data): 'BATEMAN 1 Steven' place=18
-- SKIPPED (international, no master data): 'COTUGNO 1 Giuseppe' place=19
-- SKIPPED (international, no master data): 'MASSEY 1 Oliver' place=20
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2025-2026'),
    21,
    'ALCSER 1 Norbert'
); -- matched: ALCSER Norbert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    148,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2025-2026'),
    22,
    'KULKA 1 Dawid'
); -- matched: KULKA Dawid (score=100.0)
-- SKIPPED (international, no master data): 'MORRIS 1 Gaz' place=23
-- SKIPPED (international, no master data): 'LEWIS 1 Joash' place=24
-- SKIPPED (international, no master data): 'ROSEBLADE 1 Richard' place=25
-- SKIPPED (international, no master data): 'VALATKA 1 Paulius' place=26
-- SKIPPED (international, no master data): 'FARKAS 1 Mark' place=27
-- SKIPPED (international, no master data): 'STEPHENS 1 Tim' place=28
-- SKIPPED (international, no master data): 'MAKKOULIS 1 Georgios' place=29
-- SKIPPED (international, no master data): 'RIOUX 1 Frederic' place=30
-- SKIPPED (international, no master data): 'MURPHY 1 Nicholas' place=31
-- SKIPPED (international, no master data): 'TOURNIER 1 Gwenc\''hlan' place=32
-- SKIPPED (international, no master data): 'MCKAY 1 David' place=33
-- SKIPPED (international, no master data): 'METIUNAS 1 Regimantas' place=34
-- Compute scores for PEW3-V1-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2025-2026')
);

-- ---- PEW4: EVF Grand Prix 4 (2026-03-08-07 Napoli - 4 Prova Circuito Nazionale Master 2025-2 - Spada Maschile ) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW4-2025-2026',
    'EVF Grand Prix 4',
    '2026-03-08-07 Napoli - 4 Prova Circuito Nazionale Master 2025-2 - Spada Maschile ',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW4-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW4-2025-2026'),
    'PEW4-V1-M-EPEE-2025-2026',
    'EVF Grand Prix 4',
    'PEW',
    'EPEE', 'M', 'V1',
    NULL, 59, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'CARRILLO AYALA ANDRES MARCEL' place=1
-- SKIPPED (international, no master data): 'FENZI CARLO' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    124,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-EPEE-2025-2026'),
    3,
    'KORONA RADOSLAW'
); -- matched: KORONA Radosław (score=96.875)
-- SKIPPED (international, no master data): 'SQUEO BENEDETTO' place=4
-- SKIPPED (international, no master data): 'BOTTACIN ENRICO' place=5
-- SKIPPED (international, no master data): 'ROBECCHI MAJNAR ANTONIO' place=6
-- SKIPPED (international, no master data): 'BOLLATI FEDERICO' place=7
-- SKIPPED (international, no master data): 'BAROGLIO SIMONE' place=8
-- SKIPPED (international, no master data): 'CASSAI GIULIO' place=9
-- SKIPPED (international, no master data): 'ZANNA CARLO' place=10
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-EPEE-2025-2026'),
    11,
    'ALCSER NORBERT'
); -- matched: ALCSER Norbert (score=100.0)
-- SKIPPED (international, no master data): 'SPEZZAFERRO ALBERTO MARIA' place=12
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    255,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-EPEE-2025-2026'),
    13,
    'STOCKI PIOTR'
); -- matched: STOCKI Piotr (score=100.0)
-- SKIPPED (international, no master data): 'VARONE FRANCESCO' place=14
-- SKIPPED (international, no master data): 'ALONSO ESCOBAR JAVIER' place=15
-- SKIPPED (international, no master data): 'DI GIORGIO VINCENZO' place=16
-- SKIPPED (international, no master data): 'PEDONE MATTIA' place=17
-- SKIPPED (international, no master data): 'FALERNO SIMONE' place=18
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    239,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-EPEE-2025-2026'),
    19,
    'SCHMAUZER JUERGEN'
); -- matched: SCHOLZ Jurgen (score=73.33333333333334)
-- SKIPPED (international, no master data): 'PERRI MATTEO' place=20
-- SKIPPED (international, no master data): 'LORENZETTI GIAMMARIO' place=21
-- SKIPPED (international, no master data): 'SOMORA MARTIN' place=22
-- SKIPPED (international, no master data): 'PANIZZA SIMONE' place=23
-- SKIPPED (international, no master data): 'FONTE MARCO' place=24
-- SKIPPED (international, no master data): 'VAIRA GIUSEPPE' place=25
-- SKIPPED (international, no master data): 'PIAZZA DAVIDE' place=26
-- SKIPPED (international, no master data): 'GHITTI MICHELE' place=27
-- SKIPPED (international, no master data): 'LILLO RAFFAELE' place=28
-- SKIPPED (international, no master data): 'SCARFÌ RENATO' place=29
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    122,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-EPEE-2025-2026'),
    30,
    'KORNAŚ Jarosław'
); -- matched: KORNAŚ Jarosław (score=100.0)
-- SKIPPED (international, no master data): 'CARACCIOLO DI B GIORGIO' place=31
-- SKIPPED (international, no master data): 'BACCHILEGA FABIO' place=32
-- SKIPPED (international, no master data): 'PTASHNIK ALEKSI' place=33
-- SKIPPED (international, no master data): 'JOSHUA FEDERICO-OLADAP' place=34
-- SKIPPED (international, no master data): 'VOZZA TOMMASO MARIA' place=35
-- SKIPPED (international, no master data): 'BALSAMO LUCA CARMELO' place=36
-- SKIPPED (international, no master data): 'METIUNAS REGIMANTAS' place=37
-- SKIPPED (international, no master data): 'CALTAGIRONE ALFONSO' place=38
-- SKIPPED (international, no master data): 'MAKKOULIS GEORGIOS' place=39
-- SKIPPED (international, no master data): 'TEBALDI MARCO' place=40
-- SKIPPED (international, no master data): 'ARENA MARCO' place=41
-- SKIPPED (international, no master data): 'DE STASIO GIUSEPPE' place=42
-- SKIPPED (international, no master data): 'MORGHESE ENZO' place=43
-- SKIPPED (international, no master data): 'COLUCCI SIMONE' place=44
-- SKIPPED (international, no master data): 'LA REGINA FRANCESCO' place=45
-- SKIPPED (international, no master data): 'MUNOZ CARLOS IGNACIO' place=46
-- SKIPPED (international, no master data): 'PARLATO ANDREA' place=47
-- SKIPPED (international, no master data): 'D''ELIA MICHELE' place=48
-- SKIPPED (international, no master data): 'DAL FIOR MARCO' place=49
-- SKIPPED (international, no master data): 'PERRI PIERPAOLO' place=50
-- SKIPPED (international, no master data): 'ANDOLINA SALVATORE' place=51
-- SKIPPED (international, no master data): 'VITUCCI ANDREA' place=52
-- SKIPPED (international, no master data): 'ANNONI EMANUELE' place=53
-- SKIPPED (international, no master data): 'LO GRANDE IVAN' place=54
-- SKIPPED (international, no master data): 'PIRRO SALVATORE' place=55
-- SKIPPED (international, no master data): 'MURANO FABRIZIO' place=56
-- SKIPPED (international, no master data): 'MEGA MARCO' place=57
-- SKIPPED (international, no master data): 'RIZZO ANTONIO' place=58
-- SKIPPED (international, no master data): 'FAZIO SALVATORE SAYED' place=59
-- Compute scores for PEW4-V1-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-EPEE-2025-2026')
);

-- ---- PEW5: EVF Grand Prix 5 (https://engarde-service.com/competition/sthlm/vet2026/me1) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW5-2025-2026',
    'EVF Grand Prix 5',
    'https://engarde-service.com/competition/sthlm/vet2026/me1',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW5-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW5-2025-2026'),
    'PEW5-V1-M-EPEE-2025-2026',
    'EVF Grand Prix 5',
    'PEW',
    'EPEE', 'M', 'V1',
    NULL, 13, 'https://engarde-service.com/competition/sthlm/vet2026/me1',
    'SCORED'
);
-- SKIPPED (international, no master data): 'VARONE Francesco' place=1
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    124,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V1-M-EPEE-2025-2026'),
    2,
    'KORONA Radoslaw'
); -- matched: KORONA Radosław (score=96.875)
-- SKIPPED (international, no master data): 'BARVESTAD Rickard' place=3
-- SKIPPED (international, no master data): 'REZNICHENKO Alexander' place=4
-- SKIPPED (international, no master data): 'PANTALONE Stefano' place=5
-- SKIPPED (international, no master data): 'TOURNIER Gwenc''Hlan' place=6
-- SKIPPED (international, no master data): 'HERNBACK Jerker' place=7
-- SKIPPED (international, no master data): 'OBERG Gustav' place=8
-- SKIPPED (international, no master data): 'MCKAY David' place=9
-- SKIPPED (international, no master data): 'HU Feng' place=10
-- SKIPPED (international, no master data): 'STANGBERG-RICE Tim' place=11
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V1-M-EPEE-2025-2026'),
    12,
    'ALCSER Norbert'
); -- matched: ALCSER Norbert (score=100.0)
-- SKIPPED (international, no master data): 'REINERT Erik' place=13
-- Compute scores for PEW5-V1-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V1-M-EPEE-2025-2026')
);

-- ---- PEW6: EVF Grand Prix 6 (Szpada Mężczyzn V1) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW6-2025-2026',
    'EVF Grand Prix 6',
    'Szpada Mężczyzn V1',
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
    'PEW6-V1-M-EPEE-2025-2026',
    'EVF Grand Prix 6',
    'PEW',
    'EPEE', 'M', 'V1',
    NULL, 24, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    273,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    1,
    'SĘKOWSKI Maciej'
); -- matched: SĘKOWSKI Maciej (score=100.0)
-- SKIPPED (international, no master data): 'TARDI Ottó' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    255,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    3,
    'STOCKI Piotr'
); -- matched: STOCKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    20,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    4,
    'BOBUSIA Jarosław'
); -- matched: BOBUSIA Jarosław (score=100.0)
-- SKIPPED (international, no master data): 'PARTICS Peter' place=5
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    124,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    6,
    'KORONA Radoslaw'
); -- matched: KORONA Radosław (score=96.875)
-- SKIPPED (international, no master data): 'REZNICHENKO Alexander' place=7
-- SKIPPED (international, no master data): 'SAFAR Laszlo' place=8
-- SKIPPED (international, no master data): 'PASZTOR Attila' place=9
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    132,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    10,
    'KOWALCZYK Piotr'
); -- matched: KOWALCZYK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    275,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    11,
    'TATCHYN Andriy'
); -- matched: TATCHYN Andriy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    122,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    12,
    'KORNAŚ Jarosław'
); -- matched: KORNAŚ Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    189,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    13,
    'ŁOJAK Szymon'
); -- matched: NOWAK Szymon (score=70.0)
-- SKIPPED (international, no master data): 'KATSINIS Nikolaos' place=14
-- SKIPPED (international, no master data): 'RINCON Alberto' place=15
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    43,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    16,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
-- SKIPPED (international, no master data): 'WIEDEMANN Karsten' place=17
-- SKIPPED (international, no master data): 'WIECZOREK Janusz' place=18
-- SKIPPED (international, no master data): 'RIOUX Frederic' place=19
-- SKIPPED (international, no master data): 'MAKKOULIS Georgios' place=20
-- SKIPPED (international, no master data): 'GOLA Maciej' place=21
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    156,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    22,
    'LELONEK Tomasz'
); -- matched: LELONEK Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    254,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    23,
    'STAŃCZYK MARCIN'
); -- matched: STAŃCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    205,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    24,
    'PAWŁOWSKI Łukasz'
); -- matched: PAWŁOWSKI Łukasz (score=100.0)
-- Compute scores for PEW6-V1-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026')
);

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): N=0 — tournament had no participants

-- ---- PEW10: EVF Criterium Mondial Vétérans (Paryż) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW10-2025-2026',
    'EVF Criterium Mondial Vétérans 2025',
    'Paryż',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW10-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW10-2025-2026'),
    'PEW10-V1-M-EPEE-2025-2026',
    'EVF Criterium Mondial Vétérans 2025',
    'PEW',
    'EPEE', 'M', 'V1',
    '2025-07-05', 31, 'https://engarde-service.com/competition/fencingaddict/crit25/ehv1',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW10-V1-M-EPEE-2025-2026'),
    8,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
-- Compute scores for PEW10-V1-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW10-V1-M-EPEE-2025-2026')
);

-- Summary
-- Total results matched:   82
-- Total results unmatched: 132
-- Total auto-created:      0
