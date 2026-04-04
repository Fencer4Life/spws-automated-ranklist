-- =========================================================================
-- Season 2023-2024 — V3 M EPEE — generated from SZPADA-3-2023-2024.xlsx
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
    'GP1-V3-M-EPEE-2023-2024',
    'Grand Prix (runda 1)',
    'PPW',
    'EPEE', 'M', 'V3',
    '2023-01-14', 10, 'https://www.fencingtimelive.com/events/results/6B059EC0E5CB411CA1ED88CC9484F4B4',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-EPEE-2023-2024'),
    1,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    84,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-EPEE-2023-2024'),
    2,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    191,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-EPEE-2023-2024'),
    3,
    'POPRAWA Mariusz'
); -- matched: POPRAWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    190,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-EPEE-2023-2024'),
    4,
    'POKRZYWA Mariusz'
); -- matched: POKRZYWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    35,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-EPEE-2023-2024'),
    5,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    7,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-EPEE-2023-2024'),
    6,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    102,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-EPEE-2023-2024'),
    7,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    74,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-EPEE-2023-2024'),
    8,
    'GRODNER Michał'
); -- matched: GRODNER Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    95,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-EPEE-2023-2024'),
    9,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    168,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-EPEE-2023-2024'),
    10,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
-- Compute scores for GP1-V3-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-EPEE-2023-2024')
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
    'GP2-V3-M-EPEE-2023-2024',
    'Grand Prix (runda 2)',
    'PPW',
    'EPEE', 'M', 'V3',
    '2023-04-03', 9, 'https://www.fencingtimelive.com/events/results/E87FB962FC1F494EAECF662B7630C3EB',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-EPEE-2023-2024'),
    1,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    136,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-EPEE-2023-2024'),
    2,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    84,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-EPEE-2023-2024'),
    3,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    35,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-EPEE-2023-2024'),
    4,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    74,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-EPEE-2023-2024'),
    5,
    'GRODNER Michał'
); -- matched: GRODNER Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    102,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-EPEE-2023-2024'),
    6,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    191,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-EPEE-2023-2024'),
    7,
    'POPRAWA Mariusz'
); -- matched: POPRAWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    258,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-EPEE-2023-2024'),
    8,
    'WHITLEY Gary'
); -- matched: WHITLEY Gary (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    95,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-EPEE-2023-2024'),
    9,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    42,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-EPEE-2023-2024'),
    11,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
-- Compute scores for GP2-V3-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-EPEE-2023-2024')
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
    'GP3-V3-M-EPEE-2023-2024',
    'Grand Prix (runda 3)',
    'PPW',
    'EPEE', 'M', 'V3',
    '2023-06-17', 10, 'https://www.fencingtimelive.com/events/results/B28E0C0CEBE64FBE9933572541247D21',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    136,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-EPEE-2023-2024'),
    1,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    7,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-EPEE-2023-2024'),
    2,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    190,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-EPEE-2023-2024'),
    5,
    'POKRZYWA Mariusz'
); -- matched: POKRZYWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    102,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-EPEE-2023-2024'),
    6,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    168,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-EPEE-2023-2024'),
    7,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    258,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-EPEE-2023-2024'),
    8,
    'WHITLEY Gary'
); -- matched: WHITLEY Gary (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    150,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-EPEE-2023-2024'),
    9,
    'MAŁASIŃSKI Adam'
); -- matched: MAŁASIŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    32,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-EPEE-2023-2024'),
    10,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    42,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-EPEE-2023-2024'),
    12,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
-- Compute scores for GP3-V3-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-EPEE-2023-2024')
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
    'GP4-V3-M-EPEE-2023-2024',
    'Grand Prix (runda 4)',
    'PPW',
    'EPEE', 'M', 'V3',
    '2023-10-23', 7, 'https://www.fencingtimelive.com/events/results/3CACF859960F474E9F7159180E870CF0',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    42,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V3-M-EPEE-2023-2024'),
    1,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V3-M-EPEE-2023-2024'),
    2,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    7,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V3-M-EPEE-2023-2024'),
    3,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    35,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V3-M-EPEE-2023-2024'),
    4,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    74,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V3-M-EPEE-2023-2024'),
    5,
    'GRODNER Michał'
); -- matched: GRODNER Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    191,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V3-M-EPEE-2023-2024'),
    6,
    'POPRAWA Mariusz'
); -- matched: POPRAWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    102,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V3-M-EPEE-2023-2024'),
    7,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
-- Compute scores for GP4-V3-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V3-M-EPEE-2023-2024')
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
    'GP5-V3-M-EPEE-2023-2024',
    'Grand Prix (runda 5)',
    'PPW',
    'EPEE', 'M', 'V3',
    '2023-10-28', 7, 'https://www.fencingtimelive.com/events/results/65D87BA9DF1B41229D5D671DC761310C',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    42,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V3-M-EPEE-2023-2024'),
    1,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    35,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V3-M-EPEE-2023-2024'),
    2,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    219,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V3-M-EPEE-2023-2024'),
    3,
    'SOBIERAJ Wojciech'
); -- matched: SOBIERAJ Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    84,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V3-M-EPEE-2023-2024'),
    4,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    102,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V3-M-EPEE-2023-2024'),
    5,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    7,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V3-M-EPEE-2023-2024'),
    6,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    74,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V3-M-EPEE-2023-2024'),
    7,
    'GRODNER Michał'
); -- matched: GRODNER Michał (score=100.0)
-- Compute scores for GP5-V3-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V3-M-EPEE-2023-2024')
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
    'GP6-V3-M-EPEE-2023-2024',
    'Grand Prix (runda 6)',
    'PPW',
    'EPEE', 'M', 'V3',
    '2023-11-18', 13, 'https://www.fencingtimelive.com/events/results/E1F302084F104A59BDE5E72F56CD7D10',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    136,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-EPEE-2023-2024'),
    1,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    42,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-EPEE-2023-2024'),
    2,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-EPEE-2023-2024'),
    3,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    191,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-EPEE-2023-2024'),
    4,
    'POPRAWA Mariusz'
); -- matched: POPRAWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    190,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-EPEE-2023-2024'),
    5,
    'POKRZYWA Mariusz'
); -- matched: POKRZYWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    150,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-EPEE-2023-2024'),
    6,
    'MAŁASIŃSKI Adam'
); -- matched: MAŁASIŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    84,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-EPEE-2023-2024'),
    7,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    35,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-EPEE-2023-2024'),
    8,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    7,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-EPEE-2023-2024'),
    9,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    102,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-EPEE-2023-2024'),
    10,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    74,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-EPEE-2023-2024'),
    11,
    'GRODNER Michał'
); -- matched: GRODNER Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    32,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-EPEE-2023-2024'),
    12,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    258,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-EPEE-2023-2024'),
    13,
    'WHITLEY Gary'
); -- matched: WHITLEY Gary (score=100.0)
-- Compute scores for GP6-V3-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-EPEE-2023-2024')
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
    'GP7-V3-M-EPEE-2023-2024',
    'Grand Prix (runda 7)',
    'PPW',
    'EPEE', 'M', 'V3',
    '2024-01-27', 7, 'https://www.fencingtimelive.com/events/results/B86AF930EA434E59B7B86ED06B43B17E',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    136,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V3-M-EPEE-2023-2024'),
    1,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    42,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V3-M-EPEE-2023-2024'),
    2,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    7,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V3-M-EPEE-2023-2024'),
    3,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    84,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V3-M-EPEE-2023-2024'),
    4,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    74,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V3-M-EPEE-2023-2024'),
    5,
    'GRODNER Michał'
); -- matched: GRODNER Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    35,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V3-M-EPEE-2023-2024'),
    6,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V3-M-EPEE-2023-2024'),
    7,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
-- Compute scores for GP7-V3-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V3-M-EPEE-2023-2024')
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
    'GP8-V3-M-EPEE-2023-2024',
    'Grand Prix (runda 8)',
    'PPW',
    'EPEE', 'M', 'V3',
    '2026-06-22', 11, 'https://www.fencingtimelive.com/events/results/E12EAF17078E464DBF888ABF11E48D7A',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    136,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-EPEE-2023-2024'),
    1,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    7,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-EPEE-2023-2024'),
    2,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    191,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-EPEE-2023-2024'),
    3,
    'POPRAWA Mariusz'
); -- matched: POPRAWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    190,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-EPEE-2023-2024'),
    4,
    'POKRZYWA MARIUSZ'
); -- matched: POKRZYWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    35,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-EPEE-2023-2024'),
    5,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    102,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-EPEE-2023-2024'),
    6,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    150,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-EPEE-2023-2024'),
    8,
    'MAŁASIŃSKI Adam'
); -- matched: MAŁASIŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    32,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-EPEE-2023-2024'),
    9,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    84,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-EPEE-2023-2024'),
    10,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    196,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-EPEE-2023-2024'),
    11,
    'PYZIK Zdzisław'
); -- matched: PYZIK Zdzisław (score=100.0)
-- Compute scores for GP8-V3-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-EPEE-2023-2024')
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
    'MPW-V3-M-EPEE-2023-2024',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'EPEE', 'M', 'V3',
    '2024-03-02', 12, 'https://www.fencingtimelive.com/events/results/E5683C2E943B4419B667200A370CB5B0',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    42,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2023-2024'),
    1,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    7,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2023-2024'),
    2,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    84,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2023-2024'),
    3,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    35,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2023-2024'),
    4,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    102,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2023-2024'),
    5,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    191,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2023-2024'),
    6,
    'POPRAWA Mariusz'
); -- matched: POPRAWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    74,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2023-2024'),
    7,
    'GRODNER Michał'
); -- matched: GRODNER Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    136,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2023-2024'),
    8,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    32,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2023-2024'),
    9,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    190,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2023-2024'),
    10,
    'POKRZYWA MARIUSZ'
); -- matched: POKRZYWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    196,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2023-2024'),
    11,
    'PYZIK Zdzisław'
); -- matched: PYZIK Zdzisław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    269,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2023-2024'),
    12,
    'WUJEK Dariusz'
); -- matched: WUJEK Dariusz (score=100.0)
-- Compute scores for MPW-V3-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2023-2024')
);

-- ---- PEW1: EVF Grand Prix 1 — Budapeszt (Guildford) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW1-2023-2024',
    'EVF Grand Prix 1 — Budapeszt',
    'Guildford',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW1-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1-2023-2024'),
    'PEW1-V3-M-EPEE-2023-2024',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'EPEE', 'M', 'V3',
    '2023-01-07', 42, 'https://www.fencingtimelive.com/events/results/F297EA5ADEE64AE193154C825D10F683',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    136,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-EPEE-2023-2024'),
    2,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    84,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-EPEE-2023-2024'),
    39,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
-- Compute scores for PEW1-V3-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-EPEE-2023-2024')
);

-- ---- PEW2: EVF Grand Prix 2 — Madryt (Kiev/Santander) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW2-2023-2024',
    'EVF Grand Prix 2 — Madryt',
    'Kiev/Santander',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW2-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW2-2023-2024'),
    'PEW2-V3-M-EPEE-2023-2024',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'EPEE', 'M', 'V3',
    '2022-01-08', 10, 'https://engarde-service.com/index.php?lang=en&Organisme=santanderfencing&Event=evf_epee_circuit_santander&Compe=m_tf_v3',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    136,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V3-M-EPEE-2023-2024'),
    2,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
-- Compute scores for PEW2-V3-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V3-M-EPEE-2023-2024')
);

-- ---- PEW3: EVF Grand Prix 3 (Gdańsk) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW3-2023-2024',
    'EVF Grand Prix 3',
    'Gdańsk',
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
    'PEW3-V3-M-EPEE-2023-2024',
    'EVF Grand Prix 3',
    'PEW',
    'EPEE', 'M', 'V3',
    '2023-04-14', 21, NULL,
    'SCORED'
);
-- UNMATCHED (score<80): '`' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2023-2024'),
    3,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    84,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2023-2024'),
    6,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    35,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2023-2024'),
    9,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    7,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2023-2024'),
    12,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    219,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2023-2024'),
    13,
    'SOBIERAJ Wojciech'
); -- matched: SOBIERAJ Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    190,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2023-2024'),
    16,
    'POKRZYWA Mariusz'
); -- matched: POKRZYWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    74,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2023-2024'),
    20,
    'GRODNER Michał'
); -- matched: GRODNER Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    42,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2023-2024'),
    24,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
-- Compute scores for PEW3-V3-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2023-2024')
);

-- ---- PEW4: EVF Grand Prix 4 (Budapest) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW4-2023-2024',
    'EVF Grand Prix 4',
    'Budapest',
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
    'PEW4-V3-M-EPEE-2023-2024',
    'EVF Grand Prix 4',
    'PEW',
    'EPEE', 'M', 'V3',
    '2023-09-16', 33, 'https://engarde-service.com/?fbclid=IwAR1q8b20973WNdhLRYbl3vdP-rPK0cilvuHZi37KFNf-Dodoicffb3YOQeM',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    136,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V3-M-EPEE-2023-2024'),
    2,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V3-M-EPEE-2023-2024'),
    11,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    35,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V3-M-EPEE-2023-2024'),
    19,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    42,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V3-M-EPEE-2023-2024'),
    23,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    219,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V3-M-EPEE-2023-2024'),
    30,
    'SOBIERAJ Wojciech'
); -- matched: SOBIERAJ Wojciech (score=100.0)
-- Compute scores for PEW4-V3-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V3-M-EPEE-2023-2024')
);

-- SKIP PEW5 (EVF Grand Prix 5): N=0 — tournament had no participants

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
    'PEW6-V3-M-EPEE-2023-2024',
    'EVF Grand Prix 6',
    'PEW',
    'EPEE', 'M', 'V3',
    '2023-11-11', 32, 'https://engarde-service.com/competition/aeve_esgrima/evf_madrid_2023/t_em_3',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    136,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2023-2024'),
    3,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2023-2024'),
    6,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
-- Compute scores for PEW6-V3-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2023-2024')
);

-- ---- PEW7: EVF Grand Prix 7 — Terni (Terni) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW7-2023-2024',
    'EVF Grand Prix 7 — Terni',
    'Terni',
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
    'PEW7-V3-M-EPEE-2023-2024',
    'EVF Grand Prix 7 — Terni',
    'PEW',
    'EPEE', 'M', 'V3',
    '2023-12-16', 59, 'https://www.4fence.it/FIS/Risultati/2023-12-17-16_Terni_(TR)_-_3_Prova_Circuito_Naz.le_Master/index.php?a=SP&s=M&c=8&f=clafinale',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    136,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V3-M-EPEE-2023-2024'),
    7,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
-- Compute scores for PEW7-V3-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V3-M-EPEE-2023-2024')
);

-- ---- PEW8: EVF Grand Prix 8 — Guildford (Guildford) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW8-2023-2024',
    'EVF Grand Prix 8 — Guildford',
    'Guildford',
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
    'PEW8-V3-M-EPEE-2023-2024',
    'EVF Grand Prix 8 — Guildford',
    'PEW',
    'EPEE', 'M', 'V3',
    '2024-01-06', 45, 'https://www.fencingtimelive.com/events/results/326B5C888D044FF0A0DE72C441459778',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    136,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V3-M-EPEE-2023-2024'),
    3,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
-- Compute scores for PEW8-V3-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V3-M-EPEE-2023-2024')
);

-- ---- PEW9: EVF Grand Prix 9 — Sztokholm (Stockholm (SWE)) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW9-2023-2024',
    'EVF Grand Prix 9 — Sztokholm',
    'Stockholm (SWE)',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW9-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW9-2023-2024'),
    'PEW9-V3-M-EPEE-2023-2024',
    'EVF Grand Prix 9 — Sztokholm',
    'PEW',
    'EPEE', 'M', 'V3',
    '2024-02-24', 26, 'https://engarde-service.com/competition/sthlm/efv2024/emv3',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    136,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW9-V3-M-EPEE-2023-2024'),
    1,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW9-V3-M-EPEE-2023-2024'),
    19,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
-- Compute scores for PEW9-V3-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW9-V3-M-EPEE-2023-2024')
);

-- SKIP PEW10 (EVF Grand Prix 10 — Graz): N=0 — tournament had no participants

-- ---- PEW11: EVF Grand Prix 11 — Gdańsk (Gdańsk (POL)) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW11-2023-2024',
    'EVF Grand Prix 11 — Gdańsk',
    'Gdańsk (POL)',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW11-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW11-2023-2024'),
    'PEW11-V3-M-EPEE-2023-2024',
    'EVF Grand Prix 11 — Gdańsk',
    'PEW',
    'EPEE', 'M', 'V3',
    '2024-04-06', 24, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    136,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V3-M-EPEE-2023-2024'),
    1,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    7,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V3-M-EPEE-2023-2024'),
    3,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    74,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V3-M-EPEE-2023-2024'),
    11,
    'GRODNER Michał'
); -- matched: GRODNER Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V3-M-EPEE-2023-2024'),
    13,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    84,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V3-M-EPEE-2023-2024'),
    15,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    32,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V3-M-EPEE-2023-2024'),
    19,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    42,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V3-M-EPEE-2023-2024'),
    20,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    35,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V3-M-EPEE-2023-2024'),
    21,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    102,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V3-M-EPEE-2023-2024'),
    22,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    196,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V3-M-EPEE-2023-2024'),
    23,
    'PYZIK Zdzisław'
); -- matched: PYZIK Zdzisław (score=100.0)
-- Compute scores for PEW11-V3-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V3-M-EPEE-2023-2024')
);

-- ---- PEW12: EVF Grand Prix 12 — Ateny (Ateny (GRE)) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW12-2023-2024',
    'EVF Grand Prix 12 — Ateny',
    'Ateny (GRE)',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW12-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW12-2023-2024'),
    'PEW12-V3-M-EPEE-2023-2024',
    'EVF Grand Prix 12 — Ateny',
    'PEW',
    'EPEE', 'M', 'V3',
    '2024-04-27', 22, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    136,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW12-V3-M-EPEE-2023-2024'),
    1,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    84,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW12-V3-M-EPEE-2023-2024'),
    14,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
-- Compute scores for PEW12-V3-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW12-V3-M-EPEE-2023-2024')
);

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
    'IMEW-V3-M-EPEE-2023-2024',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'EPEE', 'M', 'V3',
    '2023-01-01', 156, 'https://engarde-service.com/competition/e3f/efcv/menepeev3',
    'SCORED'
);
-- UNMATCHED (score<80): 'TIVENIUS' place=1
-- UNMATCHED (score<80): 'BELLMANN' place=2
-- UNMATCHED (score<80): 'CONY' place=3
-- UNMATCHED (score<80): 'KERNOHAN' place=3
-- UNMATCHED (score<80): 'AKERBERG' place=5
-- UNMATCHED (score<80): 'BOIRON' place=6
-- UNMATCHED (score<80): 'GOURSAUD' place=7
-- UNMATCHED (score<80): 'BAGARD' place=8
-- UNMATCHED (score<80): 'BONTHOUX' place=9
-- UNMATCHED (score<80): 'SPANO' place=10
-- UNMATCHED (score<80): 'WAGNER' place=11
-- UNMATCHED (score<80): 'OSTERBERG' place=12
-- UNMATCHED (score<80): 'DRAHUSAK' place=13
-- UNMATCHED (score<80): 'FALCK-YTTER' place=14
-- UNMATCHED (score<80): 'BARTLING' place=15
-- UNMATCHED (score<80): 'MENG' place=16
-- UNMATCHED (score<80): 'ARNOLD' place=17
-- UNMATCHED (score<80): 'KATZLBERGER' place=18
-- UNMATCHED (score<80): 'CHARTIER' place=19
-- UNMATCHED (score<80): 'DOUSSE' place=20
-- UNMATCHED (score<80): 'VAN DEN BERG' place=21
-- UNMATCHED (score<80): 'BIRKENMAIER' place=22
-- UNMATCHED (score<80): 'RAB' place=23
-- UNMATCHED (score<80): 'DE GROOT' place=24
-- UNMATCHED (score<80): 'LE BARBIER' place=25
-- UNMATCHED (score<80): 'GERBER' place=26
-- UNMATCHED (score<80): 'VAN ERVEN' place=27
-- UNMATCHED (score<80): 'SEGUIN' place=28
-- UNMATCHED (score<80): 'BACKER' place=29
-- UNMATCHED (score<80): 'SAUTERON' place=30
-- UNMATCHED (score<80): 'ZAGO' place=31
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    84,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-EPEE-2023-2024'),
    32,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
-- UNMATCHED (score<80): 'LASSON' place=33
-- UNMATCHED (score<80): 'BURKARDT' place=34
-- UNMATCHED (score<80): 'STOCK' place=35
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    136,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-EPEE-2023-2024'),
    36,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
-- UNMATCHED (score<80): 'SICOT' place=37
-- UNMATCHED (score<80): 'STADTER' place=38
-- UNMATCHED (score<80): 'BONNOT' place=39
-- UNMATCHED (score<80): 'ALEKSANDROVSKI' place=40
-- UNMATCHED (score<80): 'JINDRA' place=41
-- UNMATCHED (score<80): 'L''ORPHELIN' place=42
-- UNMATCHED (score<80): 'MASQUET' place=43
-- UNMATCHED (score<80): 'TISSERAND' place=44
-- UNMATCHED (score<80): 'POLIKARPOV' place=45
-- UNMATCHED (score<80): 'FABIANO' place=46
-- UNMATCHED (score<80): 'WAGNER' place=47
-- UNMATCHED (score<80): 'SALGE' place=48
-- UNMATCHED (score<80): 'BETOUT' place=49
-- UNMATCHED (score<80): 'LIPTON' place=50
-- UNMATCHED (score<80): 'ARONOWITSCH' place=51
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    190,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-EPEE-2023-2024'),
    52,
    'POKRZYWA Mariusz'
); -- matched: POKRZYWA Mariusz (score=100.0)
-- UNMATCHED (score<80): 'SCHAEDELE' place=53
-- UNMATCHED (score<80): 'DAUENDORFFER' place=54
-- UNMATCHED (score<80): 'BALCAZAR NAVARRO' place=55
-- UNMATCHED (score<80): 'CHARTIER' place=56
-- UNMATCHED (score<80): 'MULLER' place=57
-- UNMATCHED (score<80): 'KLOTZ' place=58
-- UNMATCHED (score<80): 'LE CLEAC''H' place=59
-- UNMATCHED (score<80): 'PIANCA' place=60
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-EPEE-2023-2024'),
    61,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
-- UNMATCHED (score<80): 'BILHAUT' place=62
-- UNMATCHED (score<80): 'PORA' place=63
-- UNMATCHED (score<80): 'GRUNDLEHNER' place=64
-- UNMATCHED (score<80): 'SJODAHL' place=65
-- UNMATCHED (score<80): 'CARNEC' place=66
-- UNMATCHED (score<80): 'GUY' place=67
-- UNMATCHED (score<80): 'SOMERS' place=68
-- UNMATCHED (score<80): 'ALLAIN' place=69
-- UNMATCHED (score<80): 'JAENISCH' place=70
-- UNMATCHED (score<80): 'DI LORETO' place=71
-- UNMATCHED (score<80): 'BENOIST' place=72
-- UNMATCHED (score<80): 'ALAVIDZE' place=73
-- UNMATCHED (score<80): 'DESCHAMPS' place=74
-- UNMATCHED (score<80): 'VAN HEERDE' place=75
-- UNMATCHED (score<80): 'CICHOSZ' place=76
-- UNMATCHED (score<80): 'EAMES' place=77
-- UNMATCHED (score<80): 'HRUBRESCH' place=78
-- UNMATCHED (score<80): 'MANTEAU' place=79
-- UNMATCHED (score<80): 'MUNN' place=80
-- UNMATCHED (score<80): 'SCHWARZE' place=81
-- UNMATCHED (score<80): 'POLLARD' place=82
-- UNMATCHED (score<80): 'TORTEROTOT' place=83
-- UNMATCHED (score<80): 'HEYL' place=84
-- UNMATCHED (score<80): 'ZIMMERMANN' place=85
-- UNMATCHED (score<80): 'DE CONTI' place=86
-- UNMATCHED (score<80): 'ANTONIOLI' place=87
-- UNMATCHED (score<80): 'NOTTINGHAM' place=88
-- UNMATCHED (score<80): 'SOICHET' place=89
-- UNMATCHED (score<80): 'LEPINOIS' place=90
-- UNMATCHED (score<80): 'GENEVEY' place=91
-- UNMATCHED (score<80): 'BAUWELINCK' place=92
-- UNMATCHED (score<80): 'REIMER' place=93
-- UNMATCHED (score<80): 'STRUCK' place=94
-- UNMATCHED (score<80): 'LANSÅKER' place=95
-- UNMATCHED (score<80): 'FARIA' place=96
-- UNMATCHED (score<80): 'SVOBODA' place=97
-- UNMATCHED (score<80): 'MATZ' place=98
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    35,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-EPEE-2023-2024'),
    99,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
-- UNMATCHED (score<80): 'MCCARRON' place=100
-- UNMATCHED (score<80): 'GOUBIN' place=101
-- UNMATCHED (score<80): 'SANS' place=102
-- UNMATCHED (score<80): 'GALLAUZIAUX' place=103
-- UNMATCHED (score<80): 'DUNAEVSKY' place=104
-- UNMATCHED (score<80): 'KITTLER' place=105
-- UNMATCHED (score<80): 'BOKUCHAVA' place=106
-- UNMATCHED (score<80): 'HAMILTON' place=107
-- UNMATCHED (score<80): 'PANNER' place=108
-- UNMATCHED (score<80): 'FALLWICKL' place=109
-- UNMATCHED (score<80): 'MAY' place=110
-- UNMATCHED (score<80): 'KLUGE' place=111
-- UNMATCHED (score<80): 'LE BAIL' place=112
-- UNMATCHED (score<80): 'ELFVERSON' place=113
-- UNMATCHED (score<80): 'EMCH' place=114
-- UNMATCHED (score<80): 'POUPON' place=115
-- UNMATCHED (score<80): 'MASSE' place=116
-- UNMATCHED (score<80): 'GAMMA' place=117
-- UNMATCHED (score<80): 'VAN COSTER' place=118
-- UNMATCHED (score<80): 'SARKISOV' place=119
-- UNMATCHED (score<80): 'MAYER' place=120
-- UNMATCHED (score<80): 'DEFRANCE' place=121
-- UNMATCHED (score<80): 'BOTTINO' place=122
-- UNMATCHED (score<80): 'PISSOT' place=123
-- UNMATCHED (score<80): 'CAMUS' place=124
-- UNMATCHED (score<80): 'VALKOVIC' place=125
-- UNMATCHED (score<80): 'GAGGIA' place=126
-- UNMATCHED (score<80): 'RUSEV' place=127
-- UNMATCHED (score<80): 'DECORDE' place=128
-- UNMATCHED (score<80): 'LE CORRE' place=129
-- UNMATCHED (score<80): 'VOLK' place=130
-- UNMATCHED (score<80): 'LUEDERS' place=131
-- UNMATCHED (score<80): 'PATTI' place=132
-- UNMATCHED (score<80): 'RONDE' place=133
-- UNMATCHED (score<80): 'FLAMENT' place=134
-- UNMATCHED (score<80): 'SAERVOLL' place=135
-- UNMATCHED (score<80): 'BENARD' place=136
-- UNMATCHED (score<80): 'HYDE' place=137
-- UNMATCHED (score<80): 'RUSZKAI' place=138
-- UNMATCHED (score<80): 'GAY' place=139
-- UNMATCHED (score<80): 'MONTEIL' place=140
-- UNMATCHED (score<80): 'LEVY' place=141
-- UNMATCHED (score<80): 'SHELAMOV' place=142
-- UNMATCHED (score<80): 'DE LEPORINI' place=143
-- UNMATCHED (score<80): 'HENNING' place=144
-- UNMATCHED (score<80): 'KAINZ' place=145
-- UNMATCHED (score<80): 'EMMANOUIL' place=146
-- UNMATCHED (score<80): 'BURKHARD' place=147
-- UNMATCHED (score<80): 'KAISER' place=148
-- UNMATCHED (score<80): 'BIGEY' place=149
-- UNMATCHED (score<80): 'ZYLKA' place=150
-- UNMATCHED (score<80): 'KRISTENSEN' place=151
-- UNMATCHED (score<80): 'BONEV' place=152
-- UNMATCHED (score<80): 'EICHBERG' place=153
-- UNMATCHED (score<80): 'KESZTHELYI' place=154
-- UNMATCHED (score<80): 'SCHUELER' place=155
-- UNMATCHED (score<80): 'FRANCESCHINI' place=156
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    42,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-EPEE-2023-2024'),
    159,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
-- Compute scores for IMEW-V3-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-EPEE-2023-2024')
);

-- Summary
-- Total results matched:   128
-- Total results unmatched: 152
