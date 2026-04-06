-- =========================================================================
-- Season 2024-2025 — V0 M EPEE — generated from SZPADA-0-2024-2025.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- =========================================================================
-- Auto-created fencers (domestic unmatched — ADR-020)
-- =========================================================================
INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, bool_birth_year_estimated)
SELECT 'SOBCZAK', 'Sławomir', 1995, TRUE
WHERE NOT EXISTS (
    SELECT 1 FROM tbl_fencer WHERE txt_surname = 'SOBCZAK' AND txt_first_name = 'Sławomir'
);
INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, bool_birth_year_estimated)
SELECT 'MACKO', 'Marcin', 1995, TRUE
WHERE NOT EXISTS (
    SELECT 1 FROM tbl_fencer WHERE txt_surname = 'MACKO' AND txt_first_name = 'Marcin'
);

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
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'FRAŚ' AND txt_first_name = 'Feliks' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-EPEE-2024-2025'),
    1,
    'FRAŚ Felix'
); -- matched: FRAŚ Feliks (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'WALCZEWSKI' AND txt_first_name = 'Konrad' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-EPEE-2024-2025'),
    2,
    'WALCZEWSKI Konrad'
); -- matched: WALCZEWSKI Konrad (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOWALSKI' AND txt_first_name = 'Bartosz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-EPEE-2024-2025'),
    3,
    'KOWALSKI Bartosz'
); -- matched: KOWALSKI Bartosz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ORIFICI' AND txt_first_name = 'Adelchi' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-EPEE-2024-2025'),
    4,
    'ORIFICI Adelchi'
); -- matched: ORIFICI Adelchi (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DYNAREK' AND txt_first_name = 'Aleksander' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-EPEE-2024-2025'),
    5,
    'DYNAREK Aleksander'
); -- matched: DYNAREK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CASSERLY' AND txt_first_name = 'Colm' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-EPEE-2024-2025'),
    6,
    'CASSERLY Colm'
); -- matched: CASSERLY Colm (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DZIUBIŃSKI' AND txt_first_name = 'Mateusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-EPEE-2024-2025'),
    7,
    'DZIUBIŃSKI Mateusz'
); -- matched: DZIUBIŃSKI Mateusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ŁĘCKI' AND txt_first_name = 'Krzysztof' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-EPEE-2024-2025'),
    8,
    'ŁĘCKI Krzysztof'
); -- matched: ŁĘCKI Krzysztof (score=100.0)
-- Compute scores for PPW1-V0-M-EPEE-2024-2025
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
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'FRAŚ' AND txt_first_name = 'Feliks' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-EPEE-2024-2025'),
    1,
    'FRAŚ Felix'
); -- matched: FRAŚ Feliks (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'JASIELCZUK' AND txt_first_name = 'Igor' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-EPEE-2024-2025'),
    2,
    'JASIELCZUK Igor'
); -- matched: JASIELCZUK Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KRAMARZ' AND txt_first_name = 'Konrad' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-EPEE-2024-2025'),
    3,
    'KRAMARZ Konrad'
); -- matched: KRAMARZ Konrad (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'WALCZEWSKI' AND txt_first_name = 'Konrad' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-EPEE-2024-2025'),
    4,
    'WALCZEWSKI Konrad'
); -- matched: WALCZEWSKI Konrad (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DZIUBIŃSKI' AND txt_first_name = 'Mateusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-EPEE-2024-2025'),
    5,
    'DZIUBIŃSKI Mateusz'
); -- matched: DZIUBIŃSKI Mateusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'AUGUSTYN' AND txt_first_name = 'Kajetan' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-EPEE-2024-2025'),
    6,
    'AUGUSTYN Kajetan'
); -- matched: AUGUSTYN Kajetan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ŁĘCKI' AND txt_first_name = 'Krzysztof' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-EPEE-2024-2025'),
    7,
    'ŁĘCKI Krzysztof'
); -- matched: ŁĘCKI Krzysztof (score=100.0)
-- Compute scores for PPW2-V0-M-EPEE-2024-2025
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
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'JASIELCZUK' AND txt_first_name = 'Igor' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2024-2025'),
    1,
    'JASIELCZUK Igor'
); -- matched: JASIELCZUK Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KRAMARZ' AND txt_first_name = 'Konrad' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2024-2025'),
    2,
    'KRAMARZ Konrad'
); -- matched: KRAMARZ Konrad (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'WALCZEWSKI' AND txt_first_name = 'Konrad' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2024-2025'),
    3,
    'WALCZEWSKI Konrad'
); -- matched: WALCZEWSKI Konrad (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SPŁAWA-NEYMAN' AND txt_first_name = 'MACIEJ' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2024-2025'),
    4,
    'SPŁAWA-NEYMAN MACIEJ'
); -- matched: SPŁAWA-NEYMAN MACIEJ (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOWALCZYK' AND txt_first_name = 'Piotr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2024-2025'),
    5,
    'KOWALCZYK Piotr'
); -- matched: KOWALCZYK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DZIUBIŃSKI' AND txt_first_name = 'Mateusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2024-2025'),
    6,
    'DZIUBIŃSKI Mateusz'
); -- matched: DZIUBIŃSKI Mateusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ŁĘCKI' AND txt_first_name = 'Krzysztof' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2024-2025'),
    7,
    'ŁĘCKI Krzysztof'
); -- matched: ŁĘCKI Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'AUGUSTYN' AND txt_first_name = 'Kajetan' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2024-2025'),
    8,
    'AUGUSTYN Kajetan'
); -- matched: AUGUSTYN Kajetan (score=100.0)
-- Compute scores for PPW3-V0-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2024-2025')
);

-- ---- PP4: IV Puchar Polski Weteranów (WARSZAWA) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW4-2024-2025',
    'IV Puchar Polski Weteranów',
    'WARSZAWA',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW4-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW4-2024-2025'),
    'PPW4-V0-M-EPEE-2024-2025',
    'IV Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V0',
    '2025-01-22', 11, 'https://www.fencingtimelive.com/events/results/949A6FA74A8A43C5B4CB69ADD9F0BDBF',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SZTYBER' AND txt_first_name = 'Michał' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-EPEE-2024-2025'),
    1,
    'SZTYBER Michał'
); -- matched: SZTYBER Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KRUJALSKIS' AND txt_first_name = 'Gotfridas' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-EPEE-2024-2025'),
    2,
    'KRUJALSKIS Gotfridas'
); -- matched: KRUJALSKIS Gotfridas (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KRAMARZ' AND txt_first_name = 'Konrad' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-EPEE-2024-2025'),
    3,
    'KRAMARZ Konrad'
); -- matched: KRAMARZ Konrad (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'PLEWIŃSKI' AND txt_first_name = 'Piotr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-EPEE-2024-2025'),
    4,
    'PLEWIŃSKI Piotr'
); -- matched: PLEWIŃSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DZIUBIŃSKI' AND txt_first_name = 'Mateusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-EPEE-2024-2025'),
    5,
    'DZIUBIŃSKI Mateusz'
); -- matched: DZIUBIŃSKI Mateusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'WALCZEWSKI' AND txt_first_name = 'Konrad' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-EPEE-2024-2025'),
    6,
    'WALCZEWSKI Konrad'
); -- matched: WALCZEWSKI Konrad (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ŁĘCKI' AND txt_first_name = 'Krzysztof' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-EPEE-2024-2025'),
    7,
    'ŁĘCKI Krzysztof'
); -- matched: ŁĘCKI Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SPŁAWA-NEYMAN' AND txt_first_name = 'MACIEJ' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-EPEE-2024-2025'),
    8,
    'SPŁAWA-NEYMAN MACIEJ'
); -- matched: SPŁAWA-NEYMAN MACIEJ (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'AUGUSTYN' AND txt_first_name = 'Kajetan' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-EPEE-2024-2025'),
    9,
    'AUGUSTYN Kajetan'
); -- matched: AUGUSTYN Kajetan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ZABŁOCKI' AND txt_first_name = 'Michał' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-EPEE-2024-2025'),
    10,
    'PRZYBYŁOWSKI Michał'
); -- matched: ZABŁOCKI Michał (score=76.47058823529412)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SKRYPKA' AND txt_first_name = 'Glib' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-EPEE-2024-2025'),
    11,
    'SKRYPKA Glib'
); -- matched: SKRYPKA Glib (score=100.0)
-- Compute scores for PPW4-V0-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-EPEE-2024-2025')
);

-- ---- PP5: V Puchar Polski Weteranów (SZCZECIN) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW5-2024-2025',
    'V Puchar Polski Weteranów',
    'SZCZECIN',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW5-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW5-2024-2025'),
    'PPW5-V0-M-EPEE-2024-2025',
    'V Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V0',
    '2025-04-26', 7, 'https://www.fencingtimelive.com/events/results/95401592AB114C2380FF0269F69DFEA5',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KORNAŚ' AND txt_first_name = 'Jarosław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V0-M-EPEE-2024-2025'),
    1,
    'KOLER Jarosław'
); -- matched: KORNAŚ Jarosław (score=82.75862068965517)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SOBCZAK' AND txt_first_name = 'Sławomir'),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V0-M-EPEE-2024-2025'),
    2,
    'SOBCZAK Sławomir'
); -- auto-created domestic fencer
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'MACKO' AND txt_first_name = 'Marcin'),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V0-M-EPEE-2024-2025'),
    3,
    'MACKO Marcin'
); -- auto-created domestic fencer
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DZIUBIŃSKI' AND txt_first_name = 'Mateusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V0-M-EPEE-2024-2025'),
    4,
    'DZIUBIŃSKI Mateusz'
); -- matched: DZIUBIŃSKI Mateusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'WALCZEWSKI' AND txt_first_name = 'Konrad' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V0-M-EPEE-2024-2025'),
    5,
    'WALCZEWSKI Konrad'
); -- matched: WALCZEWSKI Konrad (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ŁĘCKI' AND txt_first_name = 'Krzysztof' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V0-M-EPEE-2024-2025'),
    6,
    'ŁĘCKI Krzysztof'
); -- matched: ŁĘCKI Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'IWAŃCZUK' AND txt_first_name = 'Tomasz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V0-M-EPEE-2024-2025'),
    7,
    'IWAŃCZUK Tomasz'
); -- matched: IWAŃCZUK Tomasz (score=100.0)
-- Compute scores for PPW5-V0-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V0-M-EPEE-2024-2025')
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
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'JASIELCZUK' AND txt_first_name = 'Igor' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-EPEE-2024-2025'),
    1,
    'JASIELCZUK Igor'
); -- matched: JASIELCZUK Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOWALCZYK' AND txt_first_name = 'Piotr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-EPEE-2024-2025'),
    2,
    'KOWALCZYK Piotr'
); -- matched: KOWALCZYK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DZIUBIŃSKI' AND txt_first_name = 'Mateusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-EPEE-2024-2025'),
    3,
    'DZIUBIŃSKI Mateusz'
); -- matched: DZIUBIŃSKI Mateusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'WALCZEWSKI' AND txt_first_name = 'Konrad' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-EPEE-2024-2025'),
    4,
    'WALCZEWSKI Konrad'
); -- matched: WALCZEWSKI Konrad (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SKRYPKA' AND txt_first_name = 'Glib' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-EPEE-2024-2025'),
    5,
    'SKRYPKA Glib'
); -- matched: SKRYPKA Glib (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ŁĘCKI' AND txt_first_name = 'Krzysztof' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-EPEE-2024-2025'),
    6,
    'ŁĘCKI Krzysztof'
); -- matched: ŁĘCKI Krzysztof (score=100.0)
-- Compute scores for MPW-V0-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-EPEE-2024-2025')
);

-- Summary
-- Total results matched:   45
-- Total results unmatched: 2
-- Total auto-created:      2
