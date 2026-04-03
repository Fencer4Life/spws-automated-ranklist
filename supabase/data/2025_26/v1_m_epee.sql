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
    208,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2025-2026'),
    1,
    'SĘKOWSKI Maciej'
); -- matched: SĘKOWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    17,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2025-2026'),
    2,
    'BOBUSIA Jarosław'
); -- matched: BOBUSIA Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    365,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2025-2026'),
    3,
    'TATCHYN Andriy'
); -- matched: TATCHYN Andriy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    216,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2025-2026'),
    4,
    'STOCKI Piotr'
); -- matched: STOCKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2025-2026'),
    5,
    'KORNAŚ Jarosław'
); -- matched: KORNAŚ Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    40,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2025-2026'),
    6,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    78,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2025-2026'),
    7,
    'GROMADA Roland'
); -- matched: GROMADA Roland (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    276,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2025-2026'),
    8,
    'BOROWIEC Maciej'
); -- matched: BOROWIEC Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    184,
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
    208,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2025-2026'),
    1,
    'SĘKOWSKI Maciej'
); -- matched: SĘKOWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    138,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2025-2026'),
    2,
    'KULKA Dawid'
); -- matched: KULKA Dawid (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    78,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2025-2026'),
    3,
    'GROMADA Roland'
); -- matched: GROMADA Roland (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    216,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2025-2026'),
    4,
    'STOCKI Piotr'
); -- matched: STOCKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    184,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2025-2026'),
    5,
    'POKRYWA Bartosz'
); -- matched: POKRYWA Bartosz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    177,
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
    301,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    1,
    'KORONA Radosław'
); -- matched: KORONA Radosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    208,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    2,
    'SĘKOWSKI Maciej'
); -- matched: SĘKOWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    125,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    3,
    'KOWALCZYK Piotr'
); -- matched: KOWALCZYK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    216,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    4,
    'STOCKI Piotr'
); -- matched: STOCKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    40,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    5,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    132,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    6,
    'KRAMARZ Konrad'
); -- matched: KRAMARZ Konrad (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    365,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    7,
    'TATCHYN Andriy'
); -- matched: TATCHYN Andriy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    299,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    8,
    'KLEPACKI Denis'
); -- matched: KLEPACKI Denis (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    184,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    9,
    'POKRYWA Bartosz'
); -- matched: POKRYWA Bartosz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    177,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    10,
    'PAWŁOWSKI Łukasz'
); -- matched: PAWŁOWSKI Łukasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    280,
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
    208,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2025-2026'),
    1,
    'SĘKOWSKI Maciej'
); -- matched: SĘKOWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    40,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2025-2026'),
    2,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    216,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2025-2026'),
    3,
    'STOCKI Piotr'
); -- matched: STOCKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    365,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2025-2026'),
    4,
    'TATCHYN Andriy'
); -- matched: TATCHYN Andriy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    280,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2025-2026'),
    5,
    'CHUDY Tomasz'
); -- matched: CHUDY Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    353,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2025-2026'),
    6,
    'STAŃCZYK Marcin'
); -- matched: STAŃCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    177,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2025-2026'),
    7,
    'PAWŁOWSKI Łukasz'
); -- matched: PAWŁOWSKI Łukasz (score=100.0)
-- Compute scores for PPW4-V1-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2025-2026')
);

-- SKIP PP5: event not yet held (SCHEDULED) — results are rolling carry-over from previous season

-- SKIP MPW: event not yet held (SCHEDULED) — results are rolling carry-over from previous season

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
    17,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-M-EPEE-2025-2026'),
    5,
    'BOBUSIA Jarosław'
); -- matched: BOBUSIA Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    138,
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
-- UNMATCHED (score<80): 'KORONA' place=1
-- UNMATCHED (score<80): 'REYNOSO' place=2
-- UNMATCHED (score<80): 'VARONE' place=3
-- UNMATCHED (score<80): 'PLAZZERIANO' place=4
-- UNMATCHED (score<80): 'RUSEV' place=5
-- UNMATCHED (score<80): 'RÁMILA GUTIÉRREZ' place=6
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    216,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-M-EPEE-2025-2026'),
    7,
    'STOCKI Piotr'
); -- matched: STOCKI Piotr (score=100.0)
-- UNMATCHED (score<80): 'VIDAL SAYAS' place=8
-- UNMATCHED (score<80): 'ALONSO ESCOBAR' place=9
-- UNMATCHED (score<80): 'CASSAI' place=10
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    138,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-M-EPEE-2025-2026'),
    11,
    'KULKA Dawid'
); -- matched: KULKA Dawid (score=100.0)
-- UNMATCHED (score<80): 'BAROGLIO' place=12
-- UNMATCHED (score<80): 'TOKOLA' place=13
-- UNMATCHED (score<80): 'PENA' place=14
-- UNMATCHED (score<80): 'RIGO' place=15
-- UNMATCHED (score<80): 'SERNA MUÑOZ' place=16
-- UNMATCHED (score<80): 'FARKAS' place=17
-- UNMATCHED (score<80): 'ALCSER' place=18
-- UNMATCHED (score<80): 'STOLARIK' place=19
-- UNMATCHED (score<80): 'GARDE' place=20
-- UNMATCHED (score<80): 'GÓMEZ SÁNCHEZ' place=21
-- UNMATCHED (score<80): 'FALERNO' place=22
-- UNMATCHED (score<80): 'SOMORA' place=23
-- UNMATCHED (score<80): 'SEÑÍS' place=24
-- UNMATCHED (score<80): 'BOURDONCLE' place=25
-- UNMATCHED (score<80): 'ALVEAR' place=26
-- UNMATCHED (score<80): 'LAICH' place=27
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
-- UNMATCHED (score<80): 'BAROGLIO 1 Simone' place=1
-- UNMATCHED (score<80): 'BOSSER 1 Pierre-Julien' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    16,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2025-2026'),
    3,
    'BOBUSIA Dariusz'
); -- matched: BOBUSIA Dariusz (score=100.0)
-- UNMATCHED (score<80): 'AJZENSTADT 1 Ido' place=4
-- UNMATCHED (score<80): 'SQUEO 1 Benedetto' place=5
-- UNMATCHED (score<80): 'PEDONE 1 Mattia' place=6
-- UNMATCHED (score<80): 'BULLWARD 1 Alistair' place=7
-- UNMATCHED (score<80): 'WILS 1 Joppe' place=8
-- UNMATCHED (score<80): 'RUSEV 1 Rosislav' place=9
-- UNMATCHED (score<80): 'AGRENICH 1 Alex' place=10
-- UNMATCHED (score<80): 'KAZIK 1 Tomas' place=11
-- UNMATCHED (score<80): 'BURKHALTER 1 Marc' place=12
-- UNMATCHED (score<80): 'BARBASIEWICZ 1 Philippe' place=13
-- UNMATCHED (score<80): 'PARTICS 1 Peter' place=14
-- UNMATCHED (score<80): 'MEASURES 1 Ben' place=15
-- UNMATCHED (score<80): 'ROWE-HAYNES 1 Maxwell' place=16
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    216,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2025-2026'),
    17,
    'STOCKI Piotr'
); -- matched: STOCKI Piotr (score=100.0)
-- UNMATCHED (score<80): 'BATEMAN 1 Steven' place=18
-- UNMATCHED (score<80): 'COTUGNO 1 Giuseppe' place=19
-- UNMATCHED (score<80): 'MASSEY 1 Oliver' place=20
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    272,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2025-2026'),
    21,
    'ALCSER 1 Norbert'
); -- matched: ALCSER Norbert (score=93.33333333333333)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    138,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2025-2026'),
    22,
    'KULKA 1 Dawid'
); -- matched: KULKA Dawid (score=91.66666666666666)
-- UNMATCHED (score<80): 'MORRIS 1 Gaz' place=23
-- UNMATCHED (score<80): 'LEWIS 1 Joash' place=24
-- UNMATCHED (score<80): 'ROSEBLADE 1 Richard' place=25
-- UNMATCHED (score<80): 'VALATKA 1 Paulius' place=26
-- UNMATCHED (score<80): 'FARKAS 1 Mark' place=27
-- UNMATCHED (score<80): 'STEPHENS 1 Tim' place=28
-- UNMATCHED (score<80): 'MAKKOULIS 1 Georgios' place=29
-- UNMATCHED (score<80): 'RIOUX 1 Frederic' place=30
-- UNMATCHED (score<80): 'MURPHY 1 Nicholas' place=31
-- UNMATCHED (score<80): 'TOURNIER 1 Gwenc\''hlan' place=32
-- UNMATCHED (score<80): 'MCKAY 1 David' place=33
-- UNMATCHED (score<80): 'METIUNAS 1 Regimantas' place=34
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
-- UNMATCHED (score<80): 'CARRILLO AYALA ANDRES MARCEL' place=1
-- UNMATCHED (score<80): 'FENZI CARLO' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    301,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-EPEE-2025-2026'),
    3,
    'KORONA RADOSLAW'
); -- matched: KORONA Radosław (score=93.33333333333333)
-- UNMATCHED (score<80): 'SQUEO BENEDETTO' place=4
-- UNMATCHED (score<80): 'BOTTACIN ENRICO' place=5
-- UNMATCHED (score<80): 'ROBECCHI MAJNAR ANTONIO' place=6
-- UNMATCHED (score<80): 'BOLLATI FEDERICO' place=7
-- UNMATCHED (score<80): 'BAROGLIO SIMONE' place=8
-- UNMATCHED (score<80): 'CASSAI GIULIO' place=9
-- UNMATCHED (score<80): 'ZANNA CARLO' place=10
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    272,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-EPEE-2025-2026'),
    11,
    'ALCSER NORBERT'
); -- matched: ALCSER Norbert (score=100.0)
-- UNMATCHED (score<80): 'SPEZZAFERRO ALBERTO MARIA' place=12
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    216,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-EPEE-2025-2026'),
    13,
    'STOCKI PIOTR'
); -- matched: STOCKI Piotr (score=100.0)
-- UNMATCHED (score<80): 'VARONE FRANCESCO' place=14
-- UNMATCHED (score<80): 'ALONSO ESCOBAR JAVIER' place=15
-- UNMATCHED (score<80): 'DI GIORGIO VINCENZO' place=16
-- UNMATCHED (score<80): 'PEDONE MATTIA' place=17
-- UNMATCHED (score<80): 'FALERNO SIMONE' place=18
-- UNMATCHED (score<80): 'SCHMAUZER JUERGEN' place=19
-- UNMATCHED (score<80): 'PERRI MATTEO' place=20
-- UNMATCHED (score<80): 'LORENZETTI GIAMMARIO' place=21
-- UNMATCHED (score<80): 'SOMORA MARTIN' place=22
-- UNMATCHED (score<80): 'PANIZZA SIMONE' place=23
-- UNMATCHED (score<80): 'FONTE MARCO' place=24
-- UNMATCHED (score<80): 'VAIRA GIUSEPPE' place=25
-- UNMATCHED (score<80): 'PIAZZA DAVIDE' place=26
-- UNMATCHED (score<80): 'GHITTI MICHELE' place=27
-- UNMATCHED (score<80): 'LILLO RAFFAELE' place=28
-- UNMATCHED (score<80): 'SCARFÌ RENATO' place=29
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-EPEE-2025-2026'),
    30,
    'KORNAŚ Jarosław'
); -- matched: KORNAŚ Jarosław (score=100.0)
-- UNMATCHED (score<80): 'CARACCIOLO DI B GIORGIO' place=31
-- UNMATCHED (score<80): 'BACCHILEGA FABIO' place=32
-- UNMATCHED (score<80): 'PTASHNIK ALEKSI' place=33
-- UNMATCHED (score<80): 'JOSHUA FEDERICO-OLADAP' place=34
-- UNMATCHED (score<80): 'VOZZA TOMMASO MARIA' place=35
-- UNMATCHED (score<80): 'BALSAMO LUCA CARMELO' place=36
-- UNMATCHED (score<80): 'METIUNAS REGIMANTAS' place=37
-- UNMATCHED (score<80): 'CALTAGIRONE ALFONSO' place=38
-- UNMATCHED (score<80): 'MAKKOULIS GEORGIOS' place=39
-- UNMATCHED (score<80): 'TEBALDI MARCO' place=40
-- UNMATCHED (score<80): 'ARENA MARCO' place=41
-- UNMATCHED (score<80): 'DE STASIO GIUSEPPE' place=42
-- UNMATCHED (score<80): 'MORGHESE ENZO' place=43
-- UNMATCHED (score<80): 'COLUCCI SIMONE' place=44
-- UNMATCHED (score<80): 'LA REGINA FRANCESCO' place=45
-- UNMATCHED (score<80): 'MUNOZ CARLOS IGNACIO' place=46
-- UNMATCHED (score<80): 'PARLATO ANDREA' place=47
-- UNMATCHED (score<80): 'D''ELIA MICHELE' place=48
-- UNMATCHED (score<80): 'DAL FIOR MARCO' place=49
-- UNMATCHED (score<80): 'PERRI PIERPAOLO' place=50
-- UNMATCHED (score<80): 'ANDOLINA SALVATORE' place=51
-- UNMATCHED (score<80): 'VITUCCI ANDREA' place=52
-- UNMATCHED (score<80): 'ANNONI EMANUELE' place=53
-- UNMATCHED (score<80): 'LO GRANDE IVAN' place=54
-- UNMATCHED (score<80): 'PIRRO SALVATORE' place=55
-- UNMATCHED (score<80): 'MURANO FABRIZIO' place=56
-- UNMATCHED (score<80): 'MEGA MARCO' place=57
-- UNMATCHED (score<80): 'RIZZO ANTONIO' place=58
-- UNMATCHED (score<80): 'FAZIO SALVATORE SAYED' place=59
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
-- UNMATCHED (score<80): 'VARONE Francesco' place=1
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    301,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V1-M-EPEE-2025-2026'),
    2,
    'KORONA Radoslaw'
); -- matched: KORONA Radosław (score=93.33333333333333)
-- UNMATCHED (score<80): 'BARVESTAD Rickard' place=3
-- UNMATCHED (score<80): 'REZNICHENKO Alexander' place=4
-- UNMATCHED (score<80): 'PANTALONE Stefano' place=5
-- UNMATCHED (score<80): 'TOURNIER Gwenc''Hlan' place=6
-- UNMATCHED (score<80): 'HERNBACK Jerker' place=7
-- UNMATCHED (score<80): 'OBERG Gustav' place=8
-- UNMATCHED (score<80): 'MCKAY David' place=9
-- UNMATCHED (score<80): 'HU Feng' place=10
-- UNMATCHED (score<80): 'STANGBERG-RICE Tim' place=11
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    272,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V1-M-EPEE-2025-2026'),
    12,
    'ALCSER Norbert'
); -- matched: ALCSER Norbert (score=100.0)
-- UNMATCHED (score<80): 'REINERT Erik' place=13
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
    208,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    1,
    'SĘKOWSKI Maciej'
); -- matched: SĘKOWSKI Maciej (score=100.0)
-- UNMATCHED (score<80): 'TARDI Ottó' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    216,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    3,
    'STOCKI Piotr'
); -- matched: STOCKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    17,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    4,
    'BOBUSIA Jarosław'
); -- matched: BOBUSIA Jarosław (score=100.0)
-- UNMATCHED (score<80): 'PARTICS Peter' place=5
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    301,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    6,
    'KORONA Radoslaw'
); -- matched: KORONA Radosław (score=93.33333333333333)
-- UNMATCHED (score<80): 'REZNICHENKO Alexander' place=7
-- UNMATCHED (score<80): 'SAFAR Laszlo' place=8
-- UNMATCHED (score<80): 'PASZTOR Attila' place=9
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    125,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    10,
    'KOWALCZYK Piotr'
); -- matched: KOWALCZYK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    365,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    11,
    'TATCHYN Andriy'
); -- matched: TATCHYN Andriy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    12,
    'KORNAŚ Jarosław'
); -- matched: KORNAŚ Jarosław (score=100.0)
-- UNMATCHED (score<80): 'ŁOJAK Szymon' place=13
-- UNMATCHED (score<80): 'KATSINIS Nikolaos' place=14
-- UNMATCHED (score<80): 'RINCON Alberto' place=15
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    40,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    16,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
-- UNMATCHED (score<80): 'WIEDEMANN Karsten' place=17
-- UNMATCHED (score<80): 'WIECZOREK Janusz' place=18
-- UNMATCHED (score<80): 'RIOUX Frederic' place=19
-- UNMATCHED (score<80): 'MAKKOULIS Georgios' place=20
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    68,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    21,
    'GOLA Maciej'
); -- matched: GOLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    141,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    22,
    'LELONEK Tomasz'
); -- matched: LELONEK Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    353,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    23,
    'STAŃCZYK MARCIN'
); -- matched: STAŃCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    177,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    24,
    'PAWŁOWSKI Łukasz'
); -- matched: PAWŁOWSKI Łukasz (score=100.0)
-- Compute scores for PEW6-V1-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026')
);

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): N=0 — tournament had no participants

-- ---- PS: Puchar Świata (Paryż) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PS-2025-2026',
    'Puchar Świata',
    'Paryż',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PS-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PS-2025-2026'),
    'PS-V1-M-EPEE-2025-2026',
    'Puchar Świata',
    'PSW',
    'EPEE', 'M', 'V1',
    '2025-07-05', 31, 'https://engarde-service.com/competition/fencingaddict/crit25/ehv1',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PS-V1-M-EPEE-2025-2026'),
    8,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
-- Compute scores for PS-V1-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PS-V1-M-EPEE-2025-2026')
);

-- SKIP IMEW: event not yet held (SCHEDULED) — results are rolling carry-over from previous season

-- Summary
-- Total results matched:   81
-- Total results unmatched: 133
