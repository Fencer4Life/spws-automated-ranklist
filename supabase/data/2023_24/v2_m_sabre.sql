-- =========================================================================
-- Season 2023-2024 — V2 M SABRE — generated from SZABLA-2-2023-2024.xlsx
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
    'GP1-V2-M-SABRE-2023-2024',
    'Grand Prix (runda 1)',
    'PPW',
    'SABRE', 'M', 'V2',
    '2023-01-15', 8, 'https://www.fencingtimelive.com/events/results/1B7847E738D94ECF81C4EAA666F72494',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-SABRE-2023-2024'),
    1,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    107,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-SABRE-2023-2024'),
    2,
    'KACZMAREK Paweł'
); -- matched: KACZMAREK Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    191,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-SABRE-2023-2024'),
    3,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    168,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-SABRE-2023-2024'),
    4,
    'MAZIK Aleksander'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    63,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-SABRE-2023-2024'),
    5,
    'GAJDA Zbigniew'
); -- matched: GAJDA Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    294,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-SABRE-2023-2024'),
    6,
    'WINGROWICZ Mariusz'
); -- matched: WINGROWICZ Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-SABRE-2023-2024'),
    7,
    'JAROSZEK Zbigniew'
); -- matched: JAROSZEK Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-SABRE-2023-2024'),
    8,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    310,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-SABRE-2023-2024'),
    9,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-SABRE-2023-2024'),
    10,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
-- Compute scores for GP1-V2-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-SABRE-2023-2024')
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
    'GP2-V2-M-SABRE-2023-2024',
    'Grand Prix (runda 2)',
    'PPW',
    'SABRE', 'M', 'V2',
    '2023-03-05', 10, 'https://www.fencingtimelive.com/events/results/7BF46A80B6F54D70BC72E92B8372DBE6',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    226,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-SABRE-2023-2024'),
    1,
    'RUDY Andrzej'
); -- matched: RUDY Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-SABRE-2023-2024'),
    2,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    294,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-SABRE-2023-2024'),
    3,
    'WINGROWICZ Mariusz'
); -- matched: WINGROWICZ Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    191,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-SABRE-2023-2024'),
    4,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    107,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-SABRE-2023-2024'),
    5,
    'KACZMAREK Paweł'
); -- matched: KACZMAREK Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    168,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-SABRE-2023-2024'),
    6,
    'MAZIK Aleksander'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    81,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-SABRE-2023-2024'),
    7,
    'GRZEGOREK Norbert'
); -- matched: GRZEGOREK Norbert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-SABRE-2023-2024'),
    8,
    'JAROSZEK Zbigniew'
); -- matched: JAROSZEK Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    13,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-SABRE-2023-2024'),
    9,
    'BARAŃSKI Wacław'
); -- matched: BARAŃSKI Wacław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    24,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-SABRE-2023-2024'),
    10,
    'REBONOK Andrzej'
); -- matched: BORKOWSKI Andrzej (score=75.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-SABRE-2023-2024'),
    12,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
-- Compute scores for GP2-V2-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-SABRE-2023-2024')
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
    'GP3-V2-M-SABRE-2023-2024',
    'Grand Prix (runda 3)',
    'PPW',
    'SABRE', 'M', 'V2',
    '2023-06-18', 7, 'https://www.fencingtimelive.com/tableaus/scores/1AC4D12B29C44E2F87CACEDE92FB7F1E/4F4CEF653E8E48779C9C65A58C867358',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    191,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-SABRE-2023-2024'),
    1,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    306,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-SABRE-2023-2024'),
    2,
    'ZABŁOCKI Michał'
); -- matched: ZABŁOCKI Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-SABRE-2023-2024'),
    3,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    107,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-SABRE-2023-2024'),
    4,
    'KACZMAREK Paweł'
); -- matched: KACZMAREK Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    168,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-SABRE-2023-2024'),
    5,
    'MAZIK Aleksander'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-SABRE-2023-2024'),
    6,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    13,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-SABRE-2023-2024'),
    7,
    'BARAŃSKI Wacław'
); -- matched: BARAŃSKI Wacław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-SABRE-2023-2024'),
    10,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    310,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-SABRE-2023-2024'),
    11,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
-- Compute scores for GP3-V2-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-SABRE-2023-2024')
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
    'GP4-V2-M-SABRE-2023-2024',
    'Grand Prix (runda 4)',
    'PPW',
    'SABRE', 'M', 'V2',
    '2023-10-23', 12, 'https://www.fencingtimelive.com/events/results/F2E032A7448E42A3BFA22FD04F1C9521',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    226,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-SABRE-2023-2024'),
    1,
    'RUDY Andrzej'
); -- matched: RUDY Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-SABRE-2023-2024'),
    2,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    310,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-SABRE-2023-2024'),
    3,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    294,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-SABRE-2023-2024'),
    4,
    'WINGROWICZ Mariusz'
); -- matched: WINGROWICZ Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-SABRE-2023-2024'),
    5,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    191,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-SABRE-2023-2024'),
    6,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    107,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-SABRE-2023-2024'),
    7,
    'KACZMAREK Paweł'
); -- matched: KACZMAREK Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    63,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-SABRE-2023-2024'),
    8,
    'GAJDA Zbigniew'
); -- matched: GAJDA Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    168,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-SABRE-2023-2024'),
    9,
    'MAZIK Aleksander'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-SABRE-2023-2024'),
    10,
    'JAROSZEK Zbigniew'
); -- matched: JAROSZEK Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-SABRE-2023-2024'),
    11,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    28,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-SABRE-2023-2024'),
    12,
    'BROSCH Artur'
); -- matched: BROSCH Artur (score=100.0)
-- Compute scores for GP4-V2-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-SABRE-2023-2024')
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
    'GP5-V2-M-SABRE-2023-2024',
    'Grand Prix (runda 5)',
    'PPW',
    'SABRE', 'M', 'V2',
    '2023-10-28', 3, 'https://www.fencingtimelive.com/events/results/9F634F806CE54F0F9F539A52CB034B29',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    310,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-M-SABRE-2023-2024'),
    1,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-M-SABRE-2023-2024'),
    2,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-M-SABRE-2023-2024'),
    3,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
-- Compute scores for GP5-V2-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-M-SABRE-2023-2024')
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
    'GP6-V2-M-SABRE-2023-2024',
    'Grand Prix (runda 6)',
    'PPW',
    'SABRE', 'M', 'V2',
    '2023-11-18', 10, 'https://www.fencingtimelive.com/events/results/1DFD78A24F804FED859780D1F095C526',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-SABRE-2023-2024'),
    1,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    191,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-SABRE-2023-2024'),
    2,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    310,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-SABRE-2023-2024'),
    3,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-SABRE-2023-2024'),
    4,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    63,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-SABRE-2023-2024'),
    5,
    'GAJDA Zbigniew'
); -- matched: GAJDA Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    294,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-SABRE-2023-2024'),
    6,
    'WINGROWICZ Mariusz'
); -- matched: WINGROWICZ Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    107,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-SABRE-2023-2024'),
    7,
    'KACZMAREK Paweł'
); -- matched: KACZMAREK Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    168,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-SABRE-2023-2024'),
    8,
    'MAZIK Aleksander'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-SABRE-2023-2024'),
    9,
    'JAROSZEK Zbigniew'
); -- matched: JAROSZEK Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-SABRE-2023-2024'),
    10,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
-- Compute scores for GP6-V2-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-SABRE-2023-2024')
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
    'GP7-V2-M-SABRE-2023-2024',
    'Grand Prix (runda 7)',
    'PPW',
    'SABRE', 'M', 'V2',
    '2024-01-28', 12, 'https://www.fencingtimelive.com/events/results/56B70427E99D46C5BE4CC3B76CDB0E66',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    310,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-SABRE-2023-2024'),
    1,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    226,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-SABRE-2023-2024'),
    2,
    'RUDY Andrzej'
); -- matched: RUDY Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    191,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-SABRE-2023-2024'),
    3,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-SABRE-2023-2024'),
    4,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    107,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-SABRE-2023-2024'),
    5,
    'KACZMAREK Paweł'
); -- matched: KACZMAREK Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    294,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-SABRE-2023-2024'),
    6,
    'WINGROWICZ Mariusz'
); -- matched: WINGROWICZ Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    168,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-SABRE-2023-2024'),
    7,
    'MAZIK ALEKSANDER'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-SABRE-2023-2024'),
    8,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    63,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-SABRE-2023-2024'),
    9,
    'GAJDA Zbigniew'
); -- matched: GAJDA Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-SABRE-2023-2024'),
    10,
    'JAROSZEK Zbigniew'
); -- matched: JAROSZEK Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-SABRE-2023-2024'),
    11,
    'WIERZBICKI JACEK'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    131,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-SABRE-2023-2024'),
    12,
    'KOTTS Radosław'
); -- matched: KOTTS Radosław (score=100.0)
-- Compute scores for GP7-V2-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-SABRE-2023-2024')
);

-- ---- GP8: Grand Prix (runda 8) (NIEPOŁOMICE) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'GP8-2023-2024',
    'Grand Prix (runda 8)',
    'NIEPOŁOMICE',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'GP8-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'GP8-2023-2024'),
    'GP8-V2-M-SABRE-2023-2024',
    'Grand Prix (runda 8)',
    'PPW',
    'SABRE', 'M', 'V2',
    '2024-06-23', 7, 'https://www.fencingtimelive.com/events/results/F158AFE3ECB5426EBBC4507AF013DCDB',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    191,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-SABRE-2023-2024'),
    1,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    310,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-SABRE-2023-2024'),
    2,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-SABRE-2023-2024'),
    3,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-SABRE-2023-2024'),
    4,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    294,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-SABRE-2023-2024'),
    5,
    'WINGROWICZ Mariusz'
); -- matched: WINGROWICZ Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-SABRE-2023-2024'),
    6,
    'WIERZBICKI JACEK'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    28,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-SABRE-2023-2024'),
    7,
    'BROSCH Artur'
); -- matched: BROSCH Artur (score=100.0)
-- Compute scores for GP8-V2-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-SABRE-2023-2024')
);

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
    'MPW-V2-M-SABRE-2023-2024',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'SABRE', 'M', 'V2',
    '2024-03-02', 11, 'https://www.fencingtimelive.com/events/results/18C456BDB6704E4DA372CAE7ED9B5400',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2023-2024'),
    1,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    191,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2023-2024'),
    2,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2023-2024'),
    3,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    107,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2023-2024'),
    4,
    'KACZMAREK Paweł'
); -- matched: KACZMAREK Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    310,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2023-2024'),
    5,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    226,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2023-2024'),
    6,
    'RUDY Andrzej'
); -- matched: RUDY Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    294,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2023-2024'),
    7,
    'WINGROWICZ Mariusz'
); -- matched: WINGROWICZ Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    168,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2023-2024'),
    8,
    'MAZIK ALEKSANDER'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2023-2024'),
    9,
    'JAROSZEK Zbigniew'
); -- matched: JAROSZEK Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2023-2024'),
    10,
    'WIERZBICKI JACEK'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    131,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2023-2024'),
    11,
    'KOTTS Radosław'
); -- matched: KOTTS Radosław (score=100.0)
-- Compute scores for MPW-V2-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2023-2024')
);

-- SKIP PEW1 (EVF Grand Prix 1 — Budapeszt): N=0 — tournament had no participants

-- SKIP PEW2 (EVF Grand Prix 2 — Madryt): N=0 — tournament had no participants

-- ---- PEW3: EVF Grand Prix 3 (Terni) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW3-2023-2024',
    'EVF Grand Prix 3',
    'Terni',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW3-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW3-2023-2024'),
    'PEW3-V2-M-SABRE-2023-2024',
    'EVF Grand Prix 3',
    'PEW',
    'SABRE', 'M', 'V2',
    '2023-02-12', 27, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    168,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-SABRE-2023-2024'),
    6,
    'MAZIK Aleksander'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-SABRE-2023-2024'),
    26,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
-- Compute scores for PEW3-V2-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-SABRE-2023-2024')
);

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
    'PEW4-V2-M-SABRE-2023-2024',
    'EVF Grand Prix 4',
    'PEW',
    'SABRE', 'M', 'V2',
    '2023-04-01', 13, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    168,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-SABRE-2023-2024'),
    6,
    'MAZIK Aleksander'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-SABRE-2023-2024'),
    16,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
-- Compute scores for PEW4-V2-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-SABRE-2023-2024')
);

-- ---- PEW5: EVF Grand Prix 5 (Budapest) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW5-2023-2024',
    'EVF Grand Prix 5',
    'Budapest',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW5-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW5-2023-2024'),
    'PEW5-V2-M-SABRE-2023-2024',
    'EVF Grand Prix 5',
    'PEW',
    'SABRE', 'M', 'V2',
    '2023-09-16', 18, 'https://engarde-service.com/?fbclid=IwAR1q8b20973WNdhLRYbl3vdP-rPK0cilvuHZi37KFNf-Dodoicffb3YOQeM',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    140,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V2-M-SABRE-2023-2024'),
    1,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V2-M-SABRE-2023-2024'),
    3,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    310,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V2-M-SABRE-2023-2024'),
    5,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
-- Compute scores for PEW5-V2-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V2-M-SABRE-2023-2024')
);

-- ---- PEW6: EVF Grand Prix 6 (Madrid) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW6-2023-2024',
    'EVF Grand Prix 6',
    'Madrid',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW6-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW6-2023-2024'),
    'PEW6-V2-M-SABRE-2023-2024',
    'EVF Grand Prix 6',
    'PEW',
    'SABRE', 'M', 'V2',
    '2023-11-11', 13, 'https://engarde-service.com/competition/aeve_esgrima/evf_madrid_2023/t_sm_2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-SABRE-2023-2024'),
    1,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    310,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-SABRE-2023-2024'),
    7,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
-- Compute scores for PEW6-V2-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-SABRE-2023-2024')
);

-- ---- PEW7: EVF Grand Prix 7 — Terni (Munich) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW7-2023-2024',
    'EVF Grand Prix 7 — Terni',
    'Munich',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW7-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW7-2023-2024'),
    'PEW7-V2-M-SABRE-2023-2024',
    'EVF Grand Prix 7 — Terni',
    'PEW',
    'SABRE', 'M', 'V2',
    '2023-10-09', 14, 'https://fencing.ophardt.online/en/search/results/27166',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2023-2024'),
    12,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
-- Compute scores for PEW7-V2-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2023-2024')
);

-- ---- PEW8: EVF Grand Prix 8 — Guildford (Terni) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW8-2023-2024',
    'EVF Grand Prix 8 — Guildford',
    'Terni',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW8-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW8-2023-2024'),
    'PEW8-V2-M-SABRE-2023-2024',
    'EVF Grand Prix 8 — Guildford',
    'PEW',
    'SABRE', 'M', 'V2',
    '2023-12-16', 16, 'https://www.4fence.it/FIS/Risultati/2023-12-17-16_Terni_(TR)_-_3_Prova_Circuito_Naz.le_Master/index.php?a=SC&s=M&c=7&f=clafinale',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-SABRE-2023-2024'),
    1,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    168,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-SABRE-2023-2024'),
    10,
    'MAZIK Aleksander'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-SABRE-2023-2024'),
    16,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
-- Compute scores for PEW8-V2-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-SABRE-2023-2024')
);

-- SKIP PEW9 (EVF Grand Prix 9 — Sztokholm): N=0 — tournament had no participants

-- ---- PEW10: EVF Grand Prix 10 — Graz (Faches-Thumesnil) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW10-2023-2024',
    'EVF Grand Prix 10 — Graz',
    'Faches-Thumesnil',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW10-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW10-2023-2024'),
    'PEW10-V2-M-SABRE-2023-2024',
    'EVF Grand Prix 10 — Graz',
    'PEW',
    'SABRE', 'M', 'V2',
    '2024-01-20', 27, 'https://www.veteransfencing.eu/fencing/rankings/',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    24,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW10-V2-M-SABRE-2023-2024'),
    17,
    'REBONOK Andrzej'
); -- matched: BORKOWSKI Andrzej (score=75.0)
-- Compute scores for PEW10-V2-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW10-V2-M-SABRE-2023-2024')
);

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
    'IMEW-V2-M-SABRE-2023-2024',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'SABRE', 'M', 'V2',
    '2023-01-01', 60, 'https://engarde-service.com/competition/e3f/efcv/mensabrev2',
    'SCORED'
);
-- SKIPPED (international, no master data): 'LANCIOTTI' place=1
-- SKIPPED (international, no master data): 'POIZAT' place=2
-- SKIPPED (international, no master data): 'GASCON BLANCO' place=3
-- SKIPPED (international, no master data): 'PISKUNOVS' place=3
-- SKIPPED (international, no master data): 'ESQUERRE' place=5
-- SKIPPED (international, no master data): 'THEROND' place=6
-- SKIPPED (international, no master data): 'BERGER' place=7
-- SKIPPED (international, no master data): 'TORI' place=8
-- SKIPPED (international, no master data): 'MALDONADO MARTIN' place=9
-- SKIPPED (international, no master data): 'KREISCHER' place=10
-- SKIPPED (international, no master data): 'ELLISON' place=11
-- SKIPPED (international, no master data): 'QUEGUINER' place=12
-- SKIPPED (international, no master data): 'GUIGNAT' place=13
-- SKIPPED (international, no master data): 'MARGETICH' place=14
-- SKIPPED (international, no master data): 'NICASTRO' place=15
-- SKIPPED (international, no master data): 'OSKAMP' place=16
-- SKIPPED (international, no master data): 'FLETCHER' place=17
-- SKIPPED (international, no master data): 'CASTAGNER' place=18
-- SKIPPED (international, no master data): 'MATRIGALI' place=19
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    140,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-SABRE-2023-2024'),
    20,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
-- SKIPPED (international, no master data): 'THIELEMANS' place=21
-- SKIPPED (international, no master data): 'EMMERICH' place=22
-- SKIPPED (international, no master data): 'HALBACH' place=23
-- SKIPPED (international, no master data): 'LEORAT' place=24
-- SKIPPED (international, no master data): 'QUENTIN' place=25
-- SKIPPED (international, no master data): 'ADINOLFI' place=26
-- SKIPPED (international, no master data): 'WICHITILL' place=27
-- SKIPPED (international, no master data): 'GIORGIANI' place=28
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    191,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-SABRE-2023-2024'),
    29,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
-- SKIPPED (international, no master data): 'DE FRANCISCO GONZÁLEZ' place=30
-- SKIPPED (international, no master data): 'MORRETTA' place=31
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    168,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-SABRE-2023-2024'),
    32,
    'MAZIK Aleksander'
); -- matched: MAZIK Aleksander (score=100.0)
-- SKIPPED (international, no master data): 'NEVEUX' place=33
-- SKIPPED (international, no master data): 'THOMAS' place=34
-- SKIPPED (international, no master data): 'WRASE' place=35
-- SKIPPED (international, no master data): 'AYDAROV' place=36
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    107,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-SABRE-2023-2024'),
    37,
    'KACZMAREK Paweł'
); -- matched: KACZMAREK Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-SABRE-2023-2024'),
    38,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
-- SKIPPED (international, no master data): 'REDONDO BERMEJO' place=39
-- SKIPPED (international, no master data): 'VICO GÓMEZ' place=40
-- SKIPPED (international, no master data): 'KESKINIVA' place=41
-- SKIPPED (international, no master data): 'JOUANNET' place=42
-- SKIPPED (international, no master data): 'BOLODAR' place=43
-- SKIPPED (international, no master data): 'ULRICH' place=44
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    281,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-SABRE-2023-2024'),
    45,
    'TRZENSIOK Bernard'
); -- matched: TRZENSIOK Bernard (score=100.0)
-- SKIPPED (international, no master data): 'HANS' place=46
-- SKIPPED (international, no master data): 'RODGERS' place=47
-- SKIPPED (international, no master data): 'KNEZ' place=48
-- SKIPPED (international, no master data): 'DAVITIDZE' place=49
-- SKIPPED (international, no master data): 'TAATILA' place=50
-- SKIPPED (international, no master data): 'SEIMANIS' place=51
-- SKIPPED (international, no master data): 'PALYI' place=52
-- SKIPPED (international, no master data): 'VAN STERKENBURG' place=53
-- SKIPPED (international, no master data): 'LUCREZI' place=54
-- SKIPPED (international, no master data): 'ESTEVES' place=55
-- SKIPPED (international, no master data): 'TROUTOT' place=56
-- SKIPPED (international, no master data): 'BOURGOGNE' place=57
-- SKIPPED (international, no master data): 'GIRRBACH' place=58
-- SKIPPED (international, no master data): 'DEMRY' place=59
-- SKIPPED (international, no master data): 'FARAGO' place=60
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-SABRE-2023-2024'),
    62,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
-- Compute scores for IMEW-V2-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-SABRE-2023-2024')
);

-- Summary
-- Total results matched:   106
-- Total results unmatched: 54
-- Total auto-created:      0
