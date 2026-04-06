-- =========================================================================
-- Season 2024-2025 — V3 M FOIL — generated from FLORET-3-2024-2025.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- =========================================================================
-- Auto-created fencers (domestic unmatched — ADR-020)
-- =========================================================================
INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, bool_birth_year_estimated)
SELECT 'ŻYCZKOWSKI', 'KAROL', 1965, TRUE
WHERE NOT EXISTS (
    SELECT 1 FROM tbl_fencer WHERE txt_surname = 'ŻYCZKOWSKI' AND txt_first_name = 'KAROL'
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
    'PPW1-V3-M-FOIL-2024-2025',
    'I Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V3',
    '2024-09-29', 2, 'https://www.fencingtimelive.com/events/results/2965FA91D33D4CFDBC61E02F6BCC3356',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NIKALAICHUK' AND txt_first_name = 'Aliaksandr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-FOIL-2024-2025'),
    1,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'POKRZYWA' AND txt_first_name = 'Mariusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-FOIL-2024-2025'),
    2,
    'POKRZYWA Mariusz'
); -- matched: POKRZYWA Mariusz (score=100.0)
-- Compute scores for PPW1-V3-M-FOIL-2024-2025
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
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NIKALAICHUK' AND txt_first_name = 'Aliaksandr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-FOIL-2024-2025'),
    1,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'POKRZYWA' AND txt_first_name = 'Mariusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-FOIL-2024-2025'),
    2,
    'POKRZYWA Mariusz'
); -- matched: POKRZYWA Mariusz (score=100.0)
-- Compute scores for PPW2-V3-M-FOIL-2024-2025
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
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NIKALAICHUK' AND txt_first_name = 'Aliaksandr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-FOIL-2024-2025'),
    1,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'POKRZYWA' AND txt_first_name = 'Mariusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-FOIL-2024-2025'),
    2,
    'POKRZYWA MARIUSZ'
); -- matched: POKRZYWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'MAŁASIŃSKI' AND txt_first_name = 'Adam' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-FOIL-2024-2025'),
    3,
    'MAŁASIŃSKI Adam'
); -- matched: MAŁASIŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ŻYCZKOWSKI' AND txt_first_name = 'KAROL'),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-FOIL-2024-2025'),
    4,
    'ŻYCZKOWSKI KAROL'
); -- auto-created domestic fencer
-- Compute scores for PPW3-V3-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-FOIL-2024-2025')
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
    'PPW4-V3-M-FOIL-2024-2025',
    'IV Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V3',
    '2025-02-23', 2, 'https://www.fencingtimelive.com/events/results/9A4078FDE2E24B2AA822505B81B96D9E',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NIKALAICHUK' AND txt_first_name = 'Aliaksandr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-FOIL-2024-2025'),
    1,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'MAŁASIŃSKI' AND txt_first_name = 'Adam' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-FOIL-2024-2025'),
    2,
    'MAŁASIŃSKI Adam'
); -- matched: MAŁASIŃSKI Adam (score=100.0)
-- Compute scores for PPW4-V3-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-FOIL-2024-2025')
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
    'PPW5-V3-M-FOIL-2024-2025',
    'V Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V3',
    '2025-04-27', 1, 'https://www.fencingtimelive.com/events/results/7F63F67E2FD94C02A454586BC5F7F72E',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NIKALAICHUK' AND txt_first_name = 'Aliaksandr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V3-M-FOIL-2024-2025'),
    1,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
-- Compute scores for PPW5-V3-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V3-M-FOIL-2024-2025')
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
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DRAPELLA' AND txt_first_name = 'Maciej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-FOIL-2024-2025'),
    1,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'POKRZYWA' AND txt_first_name = 'Mariusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-FOIL-2024-2025'),
    2,
    'POKRZYWA Mariusz'
); -- matched: POKRZYWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'MAŁASIŃSKI' AND txt_first_name = 'Adam' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-FOIL-2024-2025'),
    3,
    'MAŁASIŃSKI Adam'
); -- matched: MAŁASIŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'PYZIK' AND txt_first_name = 'Zdzisław' LIMIT 1),
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
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DRAPELLA' AND txt_first_name = 'Maciej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-FOIL-2024-2025'),
    10,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ĆWIORO' AND txt_first_name = 'Krzysztof' LIMIT 1),
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
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DRAPELLA' AND txt_first_name = 'Maciej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V3-M-FOIL-2024-2025'),
    1,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
-- Compute scores for PEW2-V3-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V3-M-FOIL-2024-2025')
);

-- ---- PEW3: EVF Grand Prix 3 (Munich) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW3-2024-2025',
    'EVF Grand Prix 3',
    'Munich',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW3-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW3-2024-2025'),
    'PEW3-V3-M-FOIL-2024-2025',
    'EVF Grand Prix 3',
    'PEW',
    'FOIL', 'M', 'V3',
    '2024-12-07', 33, 'https://www.fencingworldwide.com/en/903541-2024/results/',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NIKALAICHUK' AND txt_first_name = 'Aliaksandr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-FOIL-2024-2025'),
    15,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'POKRZYWA' AND txt_first_name = 'Mariusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-FOIL-2024-2025'),
    16,
    'POKRZYWA Mariusz'
); -- matched: POKRZYWA Mariusz (score=100.0)
-- Compute scores for PEW3-V3-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-FOIL-2024-2025')
);

-- SKIP PEW4 (EVF Grand Prix 4): N=0 — tournament had no participants

-- SKIP PEW5 (EVF Grand Prix 5): N=0 — tournament had no participants

-- SKIP PEW6 (EVF Grand Prix 6): N=0 — tournament had no participants

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
-- SKIPPED (international, no master data): 'CSÁK Attila' place=1
-- SKIPPED (international, no master data): 'RIJSENBRIJ Hans' place=2
-- SKIPPED (international, no master data): 'MÉSZÁROS András' place=3
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DRAPELLA' AND txt_first_name = 'Maciej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V3-M-FOIL-2024-2025'),
    3,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
-- SKIPPED (international, no master data): 'RAEKER Hans Martin' place=5
-- SKIPPED (international, no master data): 'MONDT Bas' place=6
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NIKALAICHUK' AND txt_first_name = 'Aliaksandr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V3-M-FOIL-2024-2025'),
    7,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
-- SKIPPED (international, no master data): 'SÁRDI Tamás' place=8
-- SKIPPED (international, no master data): 'POSTHUMA Frans' place=9
-- SKIPPED (international, no master data): 'LEE Philip' place=10
-- SKIPPED (international, no master data): 'PÉNTEK Tamás' place=11
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'MAŁASIŃSKI' AND txt_first_name = 'Adam' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V3-M-FOIL-2024-2025'),
    12,
    'MAŁASIŃSKI Adam'
); -- matched: MAŁASIŃSKI Adam (score=100.0)
-- SKIPPED (international, no master data): 'WATTENBERG Dirk' place=13
-- SKIPPED (international, no master data): 'SZABÓ Imre' place=14
-- Compute scores for PEW8-V3-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V3-M-FOIL-2024-2025')
);

-- SKIP PS (Puchar Świata): N=0 — tournament had no participants

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
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NIKALAICHUK' AND txt_first_name = 'Aliaksandr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-FOIL-2024-2025'),
    24,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
-- Compute scores for IMEW-V3-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-FOIL-2024-2025')
);

-- Summary
-- Total results matched:   23
-- Total results unmatched: 12
-- Total auto-created:      1
