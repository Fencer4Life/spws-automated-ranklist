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
    59,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-SABRE-2023-2024'),
    1,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    99,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-SABRE-2023-2024'),
    2,
    'KACZMAREK Paweł'
); -- matched: KACZMAREK Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    167,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-SABRE-2023-2024'),
    3,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    150,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-SABRE-2023-2024'),
    4,
    'MAZIK Aleksander'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    60,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-SABRE-2023-2024'),
    5,
    'GAJDA Zbigniew'
); -- matched: GAJDA Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    251,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-SABRE-2023-2024'),
    6,
    'WINGROWICZ Mariusz'
); -- matched: WINGROWICZ Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-SABRE-2023-2024'),
    7,
    'JAROSZEK Zbigniew'
); -- matched: JAROSZEK Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-SABRE-2023-2024'),
    8,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    265,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-SABRE-2023-2024'),
    9,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
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
    195,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-SABRE-2023-2024'),
    1,
    'RUDY Andrzej'
); -- matched: RUDY Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    59,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-SABRE-2023-2024'),
    2,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    251,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-SABRE-2023-2024'),
    3,
    'WINGROWICZ Mariusz'
); -- matched: WINGROWICZ Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    167,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-SABRE-2023-2024'),
    4,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    99,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-SABRE-2023-2024'),
    5,
    'KACZMAREK Paweł'
); -- matched: KACZMAREK Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    150,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-SABRE-2023-2024'),
    6,
    'MAZIK Aleksander'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    79,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-SABRE-2023-2024'),
    7,
    'GRZEGOREK Norbert'
); -- matched: GRZEGOREK Norbert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-SABRE-2023-2024'),
    8,
    'JAROSZEK Zbigniew'
); -- matched: JAROSZEK Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-SABRE-2023-2024'),
    9,
    'BARAŃSKI Wacław'
); -- matched: BARAŃSKI Wacław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    193,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-SABRE-2023-2024'),
    10,
    'REBONOK Andrzej'
); -- matched: REBONOK Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
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
    167,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-SABRE-2023-2024'),
    1,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    262,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-SABRE-2023-2024'),
    2,
    'ZABŁOCKI Michał'
); -- matched: ZABŁOCKI Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    59,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-SABRE-2023-2024'),
    3,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    99,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-SABRE-2023-2024'),
    4,
    'KACZMAREK Paweł'
); -- matched: KACZMAREK Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    150,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-SABRE-2023-2024'),
    5,
    'MAZIK Aleksander'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-SABRE-2023-2024'),
    6,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-SABRE-2023-2024'),
    7,
    'BARAŃSKI Wacław'
); -- matched: BARAŃSKI Wacław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-SABRE-2023-2024'),
    10,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    265,
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
    195,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-SABRE-2023-2024'),
    1,
    'RUDY Andrzej'
); -- matched: RUDY Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-SABRE-2023-2024'),
    2,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    265,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-SABRE-2023-2024'),
    3,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    251,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-SABRE-2023-2024'),
    4,
    'WINGROWICZ Mariusz'
); -- matched: WINGROWICZ Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    59,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-SABRE-2023-2024'),
    5,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    167,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-SABRE-2023-2024'),
    6,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    99,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-SABRE-2023-2024'),
    7,
    'KACZMAREK Paweł'
); -- matched: KACZMAREK Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    60,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-SABRE-2023-2024'),
    8,
    'GAJDA Zbigniew'
); -- matched: GAJDA Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    150,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-SABRE-2023-2024'),
    9,
    'MAZIK Aleksander'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-SABRE-2023-2024'),
    10,
    'JAROSZEK Zbigniew'
); -- matched: JAROSZEK Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-SABRE-2023-2024'),
    11,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    23,
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
    265,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-M-SABRE-2023-2024'),
    1,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-M-SABRE-2023-2024'),
    2,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
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
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-SABRE-2023-2024'),
    1,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    167,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-SABRE-2023-2024'),
    2,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    265,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-SABRE-2023-2024'),
    3,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    59,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-SABRE-2023-2024'),
    4,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    60,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-SABRE-2023-2024'),
    5,
    'GAJDA Zbigniew'
); -- matched: GAJDA Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    251,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-SABRE-2023-2024'),
    6,
    'WINGROWICZ Mariusz'
); -- matched: WINGROWICZ Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    99,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-SABRE-2023-2024'),
    7,
    'KACZMAREK Paweł'
); -- matched: KACZMAREK Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    150,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-SABRE-2023-2024'),
    8,
    'MAZIK Aleksander'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-SABRE-2023-2024'),
    9,
    'JAROSZEK Zbigniew'
); -- matched: JAROSZEK Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
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
    265,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-SABRE-2023-2024'),
    1,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    195,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-SABRE-2023-2024'),
    2,
    'RUDY Andrzej'
); -- matched: RUDY Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    167,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-SABRE-2023-2024'),
    3,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-SABRE-2023-2024'),
    4,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    99,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-SABRE-2023-2024'),
    5,
    'KACZMAREK Paweł'
); -- matched: KACZMAREK Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    251,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-SABRE-2023-2024'),
    6,
    'WINGROWICZ Mariusz'
); -- matched: WINGROWICZ Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    150,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-SABRE-2023-2024'),
    7,
    'MAZIK ALEKSANDER'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    59,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-SABRE-2023-2024'),
    8,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    60,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-SABRE-2023-2024'),
    9,
    'GAJDA Zbigniew'
); -- matched: GAJDA Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-SABRE-2023-2024'),
    10,
    'JAROSZEK Zbigniew'
); -- matched: JAROSZEK Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-SABRE-2023-2024'),
    11,
    'WIERZBICKI JACEK'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    124,
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
    167,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-SABRE-2023-2024'),
    1,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    265,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-SABRE-2023-2024'),
    2,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-SABRE-2023-2024'),
    3,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    59,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-SABRE-2023-2024'),
    4,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    251,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-SABRE-2023-2024'),
    5,
    'WINGROWICZ Mariusz'
); -- matched: WINGROWICZ Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-SABRE-2023-2024'),
    6,
    'WIERZBICKI JACEK'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    23,
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
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2023-2024'),
    1,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    167,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2023-2024'),
    2,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    59,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2023-2024'),
    3,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    99,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2023-2024'),
    4,
    'KACZMAREK Paweł'
); -- matched: KACZMAREK Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    265,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2023-2024'),
    5,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    195,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2023-2024'),
    6,
    'RUDY Andrzej'
); -- matched: RUDY Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    251,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2023-2024'),
    7,
    'WINGROWICZ Mariusz'
); -- matched: WINGROWICZ Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    150,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2023-2024'),
    8,
    'MAZIK ALEKSANDER'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2023-2024'),
    9,
    'JAROSZEK Zbigniew'
); -- matched: JAROSZEK Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-SABRE-2023-2024'),
    10,
    'WIERZBICKI JACEK'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    124,
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
    150,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-SABRE-2023-2024'),
    6,
    'MAZIK Aleksander'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
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
    150,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-SABRE-2023-2024'),
    6,
    'MAZIK Aleksander'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
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
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V2-M-SABRE-2023-2024'),
    1,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V2-M-SABRE-2023-2024'),
    3,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    265,
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
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-SABRE-2023-2024'),
    1,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    265,
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
    62,
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
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-SABRE-2023-2024'),
    1,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    150,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-SABRE-2023-2024'),
    10,
    'MAZIK Aleksander'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
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
    193,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW10-V2-M-SABRE-2023-2024'),
    17,
    'REBONOK Andrzej'
); -- matched: REBONOK Andrzej (score=100.0)
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
-- UNMATCHED (score<80): 'LANCIOTTI' place=1
-- UNMATCHED (score<80): 'POIZAT' place=2
-- UNMATCHED (score<80): 'GASCON BLANCO' place=3
-- UNMATCHED (score<80): 'PISKUNOVS' place=3
-- UNMATCHED (score<80): 'ESQUERRE' place=5
-- UNMATCHED (score<80): 'THEROND' place=6
-- UNMATCHED (score<80): 'BERGER' place=7
-- UNMATCHED (score<80): 'TORI' place=8
-- UNMATCHED (score<80): 'MALDONADO MARTIN' place=9
-- UNMATCHED (score<80): 'KREISCHER' place=10
-- UNMATCHED (score<80): 'ELLISON' place=11
-- UNMATCHED (score<80): 'QUEGUINER' place=12
-- UNMATCHED (score<80): 'GUIGNAT' place=13
-- UNMATCHED (score<80): 'MARGETICH' place=14
-- UNMATCHED (score<80): 'NICASTRO' place=15
-- UNMATCHED (score<80): 'OSKAMP' place=16
-- UNMATCHED (score<80): 'FLETCHER' place=17
-- UNMATCHED (score<80): 'CASTAGNER' place=18
-- UNMATCHED (score<80): 'MATRIGALI' place=19
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-SABRE-2023-2024'),
    20,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
-- UNMATCHED (score<80): 'THIELEMANS' place=21
-- UNMATCHED (score<80): 'EMMERICH' place=22
-- UNMATCHED (score<80): 'HALBACH' place=23
-- UNMATCHED (score<80): 'LEORAT' place=24
-- UNMATCHED (score<80): 'QUENTIN' place=25
-- UNMATCHED (score<80): 'ADINOLFI' place=26
-- UNMATCHED (score<80): 'WICHITILL' place=27
-- UNMATCHED (score<80): 'GIORGIANI' place=28
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    167,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-SABRE-2023-2024'),
    29,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
-- UNMATCHED (score<80): 'DE FRANCISCO GONZÁLEZ' place=30
-- UNMATCHED (score<80): 'MORRETTA' place=31
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    150,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-SABRE-2023-2024'),
    32,
    'MAZIK Aleksander'
); -- matched: MAZIK Aleksander (score=100.0)
-- UNMATCHED (score<80): 'NEVEUX' place=33
-- UNMATCHED (score<80): 'THOMAS' place=34
-- UNMATCHED (score<80): 'WRASE' place=35
-- UNMATCHED (score<80): 'AYDAROV' place=36
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    99,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-SABRE-2023-2024'),
    37,
    'KACZMAREK Paweł'
); -- matched: KACZMAREK Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    59,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-SABRE-2023-2024'),
    38,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
-- UNMATCHED (score<80): 'REDONDO BERMEJO' place=39
-- UNMATCHED (score<80): 'VICO GÓMEZ' place=40
-- UNMATCHED (score<80): 'KESKINIVA' place=41
-- UNMATCHED (score<80): 'JOUANNET' place=42
-- UNMATCHED (score<80): 'BOLODAR' place=43
-- UNMATCHED (score<80): 'ULRICH' place=44
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    239,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-SABRE-2023-2024'),
    45,
    'TRZENSIOK Bernard'
); -- matched: TRZENSIOK Bernard (score=100.0)
-- UNMATCHED (score<80): 'HANS' place=46
-- UNMATCHED (score<80): 'RODGERS' place=47
-- UNMATCHED (score<80): 'KNEZ' place=48
-- UNMATCHED (score<80): 'DAVITIDZE' place=49
-- UNMATCHED (score<80): 'TAATILA' place=50
-- UNMATCHED (score<80): 'SEIMANIS' place=51
-- UNMATCHED (score<80): 'PALYI' place=52
-- UNMATCHED (score<80): 'VAN STERKENBURG' place=53
-- UNMATCHED (score<80): 'LUCREZI' place=54
-- UNMATCHED (score<80): 'ESTEVES' place=55
-- UNMATCHED (score<80): 'TROUTOT' place=56
-- UNMATCHED (score<80): 'BOURGOGNE' place=57
-- UNMATCHED (score<80): 'GIRRBACH' place=58
-- UNMATCHED (score<80): 'DEMRY' place=59
-- UNMATCHED (score<80): 'FARAGO' place=60
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
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
