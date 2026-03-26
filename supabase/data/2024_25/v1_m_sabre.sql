-- =========================================================================
-- Season 2024-2025 — V1 M SABRE — generated from SZABLA-1-2024-2025.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- ---- PP1: I Puchar Polski Weteranów (KONIN) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PP1-2024-2025',
    'I Puchar Polski Weteranów',
    'KONIN',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PP1-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PP1-2024-2025'),
    'PP1-V1-M-SABRE-2024-2025',
    'I Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V1',
    '2024-09-29', 8, 'https://www.fencingtimelive.com/events/results/88D7892597C44D6B8CF310D852E6E62C',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    135,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V1-M-SABRE-2024-2025'),
    1,
    'KROCHMALSKI Jakub'
); -- matched: KROCHMALSKI Jakub (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    189,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V1-M-SABRE-2024-2025'),
    2,
    'PRZYSTAJKO Daniel'
); -- matched: PRZYSTAJKO Daniel (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    120,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V1-M-SABRE-2024-2025'),
    3,
    'KOSIŃSKI Łukasz'
); -- matched: KOSIŃSKI Łukasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    199,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V1-M-SABRE-2024-2025'),
    4,
    'RUTECKI Paweł'
); -- matched: RUTECKI Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    38,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V1-M-SABRE-2024-2025'),
    5,
    'DARUL Tomasz'
); -- matched: DARUL Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    152,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V1-M-SABRE-2024-2025'),
    6,
    'MIECZYŃSKI Adam'
); -- matched: MIECZYŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    232,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V1-M-SABRE-2024-2025'),
    7,
    'TECŁAW Robert'
); -- matched: TECŁAW Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    192,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V1-M-SABRE-2024-2025'),
    8,
    'RAJKIEWICZ Radosław'
); -- matched: RAJKIEWICZ Radosław (score=100.0)
-- Compute scores for PP1-V1-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V1-M-SABRE-2024-2025')
);

-- ---- PP2: II Puchar Polski Weteranów (BYTOM) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PP2-2024-2025',
    'II Puchar Polski Weteranów',
    'BYTOM',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PP2-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PP2-2024-2025'),
    'PP2-V1-M-SABRE-2024-2025',
    'II Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V1',
    '2024-10-27', 7, 'https://www.fencingtimelive.com/events/results/B7707DA5497F44EBA878FF535A6AA736',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    137,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V1-M-SABRE-2024-2025'),
    1,
    'KUCIĘBA Piotr'
); -- matched: KUCIĘBA Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    120,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V1-M-SABRE-2024-2025'),
    2,
    'KOSIŃSKI Łukasz'
); -- matched: KOSIŃSKI Łukasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    189,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V1-M-SABRE-2024-2025'),
    3,
    'PRZYSTAJKO Daniel'
); -- matched: PRZYSTAJKO Daniel (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    126,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V1-M-SABRE-2024-2025'),
    4,
    'KOWALEWSKI Rafał'
); -- matched: KOWALEWSKI Rafał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    135,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V1-M-SABRE-2024-2025'),
    5,
    'KROCHMALSKI Jakub'
); -- matched: KROCHMALSKI Jakub (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    73,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V1-M-SABRE-2024-2025'),
    6,
    'GRACZYK Bogdan'
); -- matched: GRACZYK Bogdan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    232,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V1-M-SABRE-2024-2025'),
    7,
    'TECŁAW Robert'
); -- matched: TECŁAW Robert (score=100.0)
-- Compute scores for PP2-V1-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V1-M-SABRE-2024-2025')
);

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
    'PP3-V1-M-SABRE-2024-2025',
    'III Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V1',
    '2024-12-01', 5, 'https://www.fencingtimelive.com/events/results/5D5E76FEE3074C1A9032E1F3B74952AC',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    137,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V1-M-SABRE-2024-2025'),
    1,
    'KUCIĘBA PIOTR'
); -- matched: KUCIĘBA Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    135,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V1-M-SABRE-2024-2025'),
    2,
    'KROCHMALSKI Jakub'
); -- matched: KROCHMALSKI Jakub (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    73,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V1-M-SABRE-2024-2025'),
    3,
    'GRACZYK Bogdan'
); -- matched: GRACZYK Bogdan (score=100.0)
-- UNMATCHED (score<80): 'KORONA-TRZEBSKI Przemysław' place=4
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    232,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V1-M-SABRE-2024-2025'),
    5,
    'TECŁAW Robert'
); -- matched: TECŁAW Robert (score=100.0)
-- Compute scores for PP3-V1-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V1-M-SABRE-2024-2025')
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
    'MPW-V1-M-SABRE-2024-2025',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'SABRE', 'M', 'V1',
    '2025-06-08', 6, 'https://www.fencingtimelive.com/events/results/0C897F4B78BE41288DC9EE257CCE4398',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    120,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-SABRE-2024-2025'),
    1,
    'KOSIŃSKI Łukasz'
); -- matched: KOSIŃSKI Łukasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    135,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-SABRE-2024-2025'),
    2,
    'KROCHMALSKI Jakub'
); -- matched: KROCHMALSKI Jakub (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    137,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-SABRE-2024-2025'),
    3,
    'KUCIĘBA Piotr'
); -- matched: KUCIĘBA Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    73,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-SABRE-2024-2025'),
    4,
    'GRACZYK Bogdan'
); -- matched: GRACZYK Bogdan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    232,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-SABRE-2024-2025'),
    5,
    'TECŁAW Robert'
); -- matched: TECŁAW Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    105,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-SABRE-2024-2025'),
    6,
    'KIEROŃSKI Tomasz'
); -- matched: KIEROŃSKI Tomasz (score=100.0)
-- Compute scores for MPW-V1-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-SABRE-2024-2025')
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
    'PEW1-V1-M-SABRE-2024-2025',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'SABRE', 'M', 'V1',
    '2024-09-22', 11, 'https://engarde-service.com/app.php?id=4211E1',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    189,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-M-SABRE-2024-2025'),
    5,
    'PRZYSTAJKO Daniel'
); -- matched: PRZYSTAJKO Daniel (score=100.0)
-- Compute scores for PEW1-V1-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-M-SABRE-2024-2025')
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
    'PEW2-V1-M-SABRE-2024-2025',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'SABRE', 'M', 'V1',
    '2024-11-17', 11, 'https://engarde-service.com/competition/aeve_esgrima/evf_madrid_2024/t-sm-1',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    189,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-M-SABRE-2024-2025'),
    7,
    'PRZYSTAJKO Daniel'
); -- matched: PRZYSTAJKO Daniel (score=100.0)
-- Compute scores for PEW2-V1-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-M-SABRE-2024-2025')
);

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
    'PEW7-V1-M-SABRE-2024-2025',
    'EVF Grand Prix 7 — Terni',
    'PEW',
    'SABRE', 'M', 'V1',
    '2025-03-29', 10, 'https://www.fencingtimelive.com/events/results/FEF9970EA4A34A95A7E0F0AFD73989E0',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    137,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-M-SABRE-2024-2025'),
    1,
    'KUCIĘBA Piotr'
); -- matched: KUCIĘBA Piotr (score=100.0)
-- UNMATCHED (score<80): 'ANDREU DEDEU Marc' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    135,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-M-SABRE-2024-2025'),
    3,
    'KROCHMALSKI Jakub'
); -- matched: KROCHMALSKI Jakub (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    189,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-M-SABRE-2024-2025'),
    3,
    'PRZYSTAJKO Daniel'
); -- matched: PRZYSTAJKO Daniel (score=100.0)
-- UNMATCHED (score<80): 'REY HERMIDA Juan' place=5
-- UNMATCHED (score<80): 'GALLAVOTTI Francesco' place=6
-- UNMATCHED (score<80): 'SPILIMBERGO Jacopo' place=7
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    126,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-M-SABRE-2024-2025'),
    8,
    'KOWALEWSKI Rafał'
); -- matched: KOWALEWSKI Rafał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    120,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-M-SABRE-2024-2025'),
    9,
    'KOSIŃSKI Łukasz'
); -- matched: KOSIŃSKI Łukasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    232,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-M-SABRE-2024-2025'),
    10,
    'TECŁAW Robert'
); -- matched: TECŁAW Robert (score=100.0)
-- Compute scores for PEW7-V1-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-M-SABRE-2024-2025')
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
    'IMEW-V1-M-SABRE-2024-2025',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'SABRE', 'M', 'V1',
    '2025-05-29', 29, 'https://www.fencingtimelive.com/events/results/9064B0E4761D47579831B6C4E284A8B0',
    'SCORED'
);
-- Compute scores for IMEW-V1-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-SABRE-2024-2025')
);

-- Summary
-- Total results matched:   33
-- Total results unmatched: 5
