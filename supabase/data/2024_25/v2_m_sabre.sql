-- =========================================================================
-- Season 2024-2025 — V2 M SABRE — generated from SZABLA-2-2024-2025.xlsx
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
    'PPW1-V2-M-SABRE-2024-2025',
    'I Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V2',
    '2024-09-29', 9, 'https://www.fencingtimelive.com/events/results/DC3A91FCABDA4AA19D494237AD071EB6',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2024-2025'),
    1,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    265,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2024-2025'),
    2,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    99,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2024-2025'),
    3,
    'KACZMAREK Paweł'
); -- matched: KACZMAREK Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    167,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2024-2025'),
    4,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    182,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2024-2025'),
    5,
    'PLUCIŃSKI Paweł'
); -- matched: PLUCIŃSKI Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2024-2025'),
    6,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    150,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2024-2025'),
    7,
    'MAZIK Aleksander'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    195,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2024-2025'),
    8,
    'RUDY Andrzej'
); -- matched: RUDY Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2024-2025'),
    9,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
-- Compute scores for PP1-V2-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2024-2025')
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
    'PPW2-V2-M-SABRE-2024-2025',
    'II Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V2',
    '2024-10-27', 9, 'https://www.fencingtimelive.com/events/results/3B76746C1B1047B894E9F340971B2CF3',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    265,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2024-2025'),
    1,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    167,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2024-2025'),
    2,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2024-2025'),
    3,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    251,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2024-2025'),
    4,
    'WINGROWICZ Mariusz'
); -- matched: WINGROWICZ Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2024-2025'),
    5,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    150,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2024-2025'),
    6,
    'MAZIK Aleksander'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    60,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2024-2025'),
    7,
    'GAJDA Zbigniew'
); -- matched: GAJDA Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2024-2025'),
    8,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2024-2025'),
    9,
    'JAROSZEK Zbigniew'
); -- matched: JAROSZEK Zbigniew (score=100.0)
-- Compute scores for PP2-V2-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2024-2025')
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
    'PPW3-V2-M-SABRE-2024-2025',
    'III Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V2',
    '2024-12-01', 11, 'https://www.fencingtimelive.com/events/results/F5836C4409B6467091B279B8C2CDF2EB',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    265,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2024-2025'),
    1,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    167,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2024-2025'),
    2,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2024-2025'),
    3,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2024-2025'),
    4,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    150,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2024-2025'),
    5,
    'MAZIK ALEKSANDER'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    251,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2024-2025'),
    6,
    'WINGROWICZ Mariusz'
); -- matched: WINGROWICZ Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    99,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2024-2025'),
    7,
    'KACZMAREK Paweł'
); -- matched: KACZMAREK Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2024-2025'),
    8,
    'JAROSZEK Zbigniew'
); -- matched: JAROSZEK Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    60,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2024-2025'),
    9,
    'GAJDA Zbigniew'
); -- matched: GAJDA Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2024-2025'),
    10,
    'WIERZBICKI JACEK'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    124,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2024-2025'),
    11,
    'KOTTS Radosław'
); -- matched: KOTTS Radosław (score=100.0)
-- Compute scores for PP3-V2-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2024-2025')
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
    'MPW-V2-M-SABRE-2024-2025',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'SABRE', 'M', 'V2',
    '2025-06-08', 9, 'https://www.fencingtimelive.com/events/results/080672FBA11041F99954655E915C39FD',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2024-2025'),
    1,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    265,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2024-2025'),
    2,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    167,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2024-2025'),
    3,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    251,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2024-2025'),
    4,
    'WINGROWICZ Mariusz'
); -- matched: WINGROWICZ Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    114,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2024-2025'),
    5,
    'KOŁUCKI Michał'
); -- matched: KOŁUCKI Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    99,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2024-2025'),
    6,
    'KACZMAREK Paweł'
); -- matched: KACZMAREK Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    60,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2024-2025'),
    7,
    'GAJDA Zbigniew'
); -- matched: GAJDA Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    150,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2024-2025'),
    8,
    'MAZIK Aleksander'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    182,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2024-2025'),
    9,
    'PLUCIŃSKI Paweł'
); -- matched: PLUCIŃSKI Paweł (score=100.0)
-- Compute scores for MPW-V2-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2024-2025')
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
    'PEW1-V2-M-SABRE-2024-2025',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'SABRE', 'M', 'V2',
    '2024-09-22', 15, 'https://engarde-service.com/app.php?id=4211E2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-SABRE-2024-2025'),
    1,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-SABRE-2024-2025'),
    6,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
-- Compute scores for PEW1-V2-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-SABRE-2024-2025')
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
    'PEW2-V2-M-SABRE-2024-2025',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'SABRE', 'M', 'V2',
    '2024-11-17', 17, 'https://engarde-service.com/competition/aeve_esgrima/evf_madrid_2024/t-sm-2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-SABRE-2024-2025'),
    1,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-SABRE-2024-2025'),
    10,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    99,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-SABRE-2024-2025'),
    13,
    'KACZMAREK Paweł'
); -- matched: KACZMAREK Paweł (score=100.0)
-- Compute scores for PEW2-V2-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-SABRE-2024-2025')
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
    'PEW7-V2-M-SABRE-2024-2025',
    'EVF Grand Prix 7 — Terni',
    'PEW',
    'SABRE', 'M', 'V2',
    '2025-03-29', 22, 'https://www.fencingtimelive.com/events/results/5C7C19CDE7414D9FA10FFBA6FDCD139D',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2024-2025'),
    1,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
-- UNMATCHED (score<80): 'LANCIOTTI Stefano' place=2
-- UNMATCHED (score<80): 'AYDAROV Alexander' place=3
-- UNMATCHED (score<80): 'ESQUERRE Eugene Olivier' place=3
-- UNMATCHED (score<80): 'CASTAGNER Diego' place=5
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2024-2025'),
    6,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    265,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2024-2025'),
    7,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    251,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2024-2025'),
    8,
    'WINGROWICZ Mariusz'
); -- matched: WINGROWICZ Mariusz (score=100.0)
-- UNMATCHED (score<80): 'NAPOLI Roberto' place=9
-- UNMATCHED (score<80): 'GASOV Kirill' place=10
-- UNMATCHED (score<80): 'CHIAROMONTE Francesco' place=11
-- UNMATCHED (score<80): 'REDONDO Jose Luis' place=12
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    167,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2024-2025'),
    13,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
-- UNMATCHED (score<80): 'BERGER Svend' place=14
-- UNMATCHED (score<80): 'MALDONADO Adolfo' place=15
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    99,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2024-2025'),
    16,
    'KACZMAREK Paweł'
); -- matched: KACZMAREK Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    60,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2024-2025'),
    17,
    'GAJDA Zbigniew'
); -- matched: GAJDA Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2024-2025'),
    18,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    124,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2024-2025'),
    19,
    'KOTTS Radosław'
); -- matched: KOTTS Radosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    150,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2024-2025'),
    20,
    'MAZIK Aleksander'
); -- matched: MAZIK Aleksander (score=100.0)
-- UNMATCHED (score<80): 'TRIMMEL Johannes' place=21
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2024-2025'),
    22,
    'JAROSZEK Zbigniew'
); -- matched: JAROSZEK Zbigniew (score=100.0)
-- Compute scores for PEW7-V2-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2024-2025')
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
    'IMEW-V2-M-SABRE-2024-2025',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'SABRE', 'M', 'V2',
    '2025-05-29', 55, 'https://www.fencingtimelive.com/events/results/4B6043F344FA4245B13F668E971A3E39',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    265,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-SABRE-2024-2025'),
    10,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    167,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-SABRE-2024-2025'),
    14,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-SABRE-2024-2025'),
    25,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    99,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-SABRE-2024-2025'),
    31,
    'KACZMAREK Paweł'
); -- matched: KACZMAREK Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    150,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-SABRE-2024-2025'),
    41,
    'MAZIK Aleksander'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-SABRE-2024-2025'),
    45,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
-- Compute scores for IMEW-V2-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-SABRE-2024-2025')
);

-- Summary
-- Total results matched:   60
-- Total results unmatched: 11
