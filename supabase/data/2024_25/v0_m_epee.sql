-- =========================================================================
-- Season 2024-2025 — V0 M EPEE — generated from SZPADA-0-2024-2025.xlsx
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
    'PPW1-V0-M-EPEE-2024-2025',
    'I Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V0',
    '2024-09-28', 8, 'https://www.fencingtimelive.com/events/results/0A80E647899F469298063AF884823544',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    51,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-EPEE-2024-2025'),
    1,
    'FRAŚ Felix'
); -- matched: FRAŚ Feliks (score=85.71428571428572)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    242,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-EPEE-2024-2025'),
    2,
    'WALCZEWSKI Konrad'
); -- matched: WALCZEWSKI Konrad (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-EPEE-2024-2025'),
    3,
    'KOWALSKI Bartosz'
); -- matched: KOWALSKI Bartosz (score=100.0)
-- UNMATCHED (score<80): 'ORIFICI Adelchi' place=4
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    48,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-EPEE-2024-2025'),
    5,
    'DYNAREK Aleksander'
); -- matched: DYNAREK Aleksander (score=100.0)
-- UNMATCHED (score<80): 'CASSERLY Colm' place=6
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    49,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-EPEE-2024-2025'),
    7,
    'DZIUBIŃSKI Mateusz'
); -- matched: DZIUBIŃSKI Mateusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    143,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-EPEE-2024-2025'),
    8,
    'ŁĘCKI Krzysztof'
); -- matched: ŁĘCKI Krzysztof (score=100.0)
-- Compute scores for PP1-V0-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-EPEE-2024-2025')
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
    'PPW2-V0-M-EPEE-2024-2025',
    'II Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V0',
    '2024-10-26', 7, 'https://www.fencingtimelive.com/events/results/0D4FBFC0B3DC449A8C695679999D6405',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    51,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-EPEE-2024-2025'),
    1,
    'FRAŚ Felix'
); -- matched: FRAŚ Feliks (score=85.71428571428572)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    94,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-EPEE-2024-2025'),
    2,
    'JASIELCZUK Igor'
); -- matched: JASIELCZUK Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    132,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-EPEE-2024-2025'),
    3,
    'KRAMARZ Konrad'
); -- matched: KRAMARZ Konrad (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    242,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-EPEE-2024-2025'),
    4,
    'WALCZEWSKI Konrad'
); -- matched: WALCZEWSKI Konrad (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    49,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-EPEE-2024-2025'),
    5,
    'DZIUBIŃSKI Mateusz'
); -- matched: DZIUBIŃSKI Mateusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    7,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-EPEE-2024-2025'),
    6,
    'AUGUSTYN Kajetan'
); -- matched: AUGUSTYN Kajetan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    143,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-EPEE-2024-2025'),
    7,
    'ŁĘCKI Krzysztof'
); -- matched: ŁĘCKI Krzysztof (score=100.0)
-- Compute scores for PP2-V0-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-EPEE-2024-2025')
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
    'PPW3-V0-M-EPEE-2024-2025',
    'III Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V0',
    '2024-11-30', 8, 'https://www.fencingtimelive.com/events/results/DB810A274BFA4A0C9AE2FCAD8148E213',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    94,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2024-2025'),
    1,
    'JASIELCZUK Igor'
); -- matched: JASIELCZUK Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    132,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2024-2025'),
    2,
    'KRAMARZ Konrad'
); -- matched: KRAMARZ Konrad (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    242,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2024-2025'),
    3,
    'WALCZEWSKI Konrad'
); -- matched: WALCZEWSKI Konrad (score=100.0)
-- UNMATCHED (score<80): 'SPŁAWA-NEYMAN MACIEJ' place=4
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    125,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2024-2025'),
    5,
    'KOWALCZYK Piotr'
); -- matched: KOWALCZYK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    49,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2024-2025'),
    6,
    'DZIUBIŃSKI Mateusz'
); -- matched: DZIUBIŃSKI Mateusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    143,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2024-2025'),
    7,
    'ŁĘCKI Krzysztof'
); -- matched: ŁĘCKI Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    7,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2024-2025'),
    8,
    'AUGUSTYN Kajetan'
); -- matched: AUGUSTYN Kajetan (score=100.0)
-- Compute scores for PP3-V0-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2024-2025')
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
    'MPW-V0-M-EPEE-2024-2025',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'EPEE', 'M', 'V0',
    '2025-06-07', 6, 'https://www.fencingtimelive.com/events/results/8F6BDF11C6344222A0DCEBCA8D22EFA7',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    94,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-EPEE-2024-2025'),
    1,
    'JASIELCZUK Igor'
); -- matched: JASIELCZUK Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    125,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-EPEE-2024-2025'),
    2,
    'KOWALCZYK Piotr'
); -- matched: KOWALCZYK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    49,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-EPEE-2024-2025'),
    3,
    'DZIUBIŃSKI Mateusz'
); -- matched: DZIUBIŃSKI Mateusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    242,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-EPEE-2024-2025'),
    4,
    'WALCZEWSKI Konrad'
); -- matched: WALCZEWSKI Konrad (score=100.0)
-- UNMATCHED (score<80): 'SKRYPKA Glib' place=5
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    143,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-EPEE-2024-2025'),
    6,
    'ŁĘCKI Krzysztof'
); -- matched: ŁĘCKI Krzysztof (score=100.0)
-- Compute scores for MPW-V0-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-EPEE-2024-2025')
);

-- Summary
-- Total results matched:   25
-- Total results unmatched: 4
