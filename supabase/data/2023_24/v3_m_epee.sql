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
    262,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-EPEE-2023-2024'),
    1,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-EPEE-2023-2024'),
    2,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    213,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-EPEE-2023-2024'),
    3,
    'POPRAWA Mariusz'
); -- matched: POPRAWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    211,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-EPEE-2023-2024'),
    4,
    'POKRZYWA Mariusz'
); -- matched: POKRZYWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    315,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-EPEE-2023-2024'),
    5,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    10,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-EPEE-2023-2024'),
    6,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    114,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-EPEE-2023-2024'),
    7,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    79,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-EPEE-2023-2024'),
    8,
    'GRODNER Michał'
); -- matched: GRODNER Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-EPEE-2023-2024'),
    9,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
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
    262,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-EPEE-2023-2024'),
    1,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-EPEE-2023-2024'),
    2,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-EPEE-2023-2024'),
    3,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    315,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-EPEE-2023-2024'),
    4,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    79,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-EPEE-2023-2024'),
    5,
    'GRODNER Michał'
); -- matched: GRODNER Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    114,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-EPEE-2023-2024'),
    6,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    213,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-EPEE-2023-2024'),
    7,
    'POPRAWA Mariusz'
); -- matched: POPRAWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    291,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-EPEE-2023-2024'),
    8,
    'WHITLEY Gary'
); -- matched: WHITLEY Gary (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-EPEE-2023-2024'),
    9,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
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
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-EPEE-2023-2024'),
    1,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    10,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-EPEE-2023-2024'),
    2,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    8,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-EPEE-2023-2024'),
    3,
    'ARONOWITSCH Niklas'
); -- matched: ARONOWITSCH Niklas (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    247,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-EPEE-2023-2024'),
    4,
    'SOMERS Jan'
); -- matched: SOMERS Jan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    211,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-EPEE-2023-2024'),
    5,
    'POKRZYWA Mariusz'
); -- matched: POKRZYWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    114,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-EPEE-2023-2024'),
    6,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-EPEE-2023-2024'),
    7,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    291,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-EPEE-2023-2024'),
    8,
    'WHITLEY Gary'
); -- matched: WHITLEY Gary (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    169,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-EPEE-2023-2024'),
    9,
    'MAŁASIŃSKI Adam'
); -- matched: MAŁASIŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    38,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-EPEE-2023-2024'),
    10,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
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
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V3-M-EPEE-2023-2024'),
    1,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    262,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V3-M-EPEE-2023-2024'),
    2,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    10,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V3-M-EPEE-2023-2024'),
    3,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    315,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V3-M-EPEE-2023-2024'),
    4,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    79,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V3-M-EPEE-2023-2024'),
    5,
    'GRODNER Michał'
); -- matched: GRODNER Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    213,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V3-M-EPEE-2023-2024'),
    6,
    'POPRAWA Mariusz'
); -- matched: POPRAWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    114,
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
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V3-M-EPEE-2023-2024'),
    1,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    315,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V3-M-EPEE-2023-2024'),
    2,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    245,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V3-M-EPEE-2023-2024'),
    3,
    'SOBIERAJ Wojciech'
); -- matched: SOBIERAJ Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V3-M-EPEE-2023-2024'),
    4,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    114,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V3-M-EPEE-2023-2024'),
    5,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    10,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V3-M-EPEE-2023-2024'),
    6,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    79,
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
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-EPEE-2023-2024'),
    1,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-EPEE-2023-2024'),
    2,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    262,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-EPEE-2023-2024'),
    3,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    213,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-EPEE-2023-2024'),
    4,
    'POPRAWA Mariusz'
); -- matched: POPRAWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    211,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-EPEE-2023-2024'),
    5,
    'POKRZYWA Mariusz'
); -- matched: POKRZYWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    169,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-EPEE-2023-2024'),
    6,
    'MAŁASIŃSKI Adam'
); -- matched: MAŁASIŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-EPEE-2023-2024'),
    7,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    315,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-EPEE-2023-2024'),
    8,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    10,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-EPEE-2023-2024'),
    9,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    114,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-EPEE-2023-2024'),
    10,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    79,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-EPEE-2023-2024'),
    11,
    'GRODNER Michał'
); -- matched: GRODNER Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    38,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-EPEE-2023-2024'),
    12,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    291,
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
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V3-M-EPEE-2023-2024'),
    1,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V3-M-EPEE-2023-2024'),
    2,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    10,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V3-M-EPEE-2023-2024'),
    3,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V3-M-EPEE-2023-2024'),
    4,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    79,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V3-M-EPEE-2023-2024'),
    5,
    'GRODNER Michał'
); -- matched: GRODNER Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    315,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V3-M-EPEE-2023-2024'),
    6,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    262,
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
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-EPEE-2023-2024'),
    1,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    10,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-EPEE-2023-2024'),
    2,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    213,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-EPEE-2023-2024'),
    3,
    'POPRAWA Mariusz'
); -- matched: POPRAWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    211,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-EPEE-2023-2024'),
    4,
    'POKRZYWA MARIUSZ'
); -- matched: POKRZYWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    315,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-EPEE-2023-2024'),
    5,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    114,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-EPEE-2023-2024'),
    6,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    221,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-EPEE-2023-2024'),
    7,
    'QUEVRAIN Michel'
); -- matched: QUEVRAIN Michel (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    169,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-EPEE-2023-2024'),
    8,
    'MAŁASIŃSKI Adam'
); -- matched: MAŁASIŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    38,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-EPEE-2023-2024'),
    9,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-EPEE-2023-2024'),
    10,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    219,
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
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2023-2024'),
    1,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    10,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2023-2024'),
    2,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2023-2024'),
    3,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    315,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2023-2024'),
    4,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    114,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2023-2024'),
    5,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    213,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2023-2024'),
    6,
    'POPRAWA Mariusz'
); -- matched: POPRAWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    79,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2023-2024'),
    7,
    'GRODNER Michał'
); -- matched: GRODNER Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2023-2024'),
    8,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    38,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2023-2024'),
    9,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    211,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2023-2024'),
    10,
    'POKRZYWA MARIUSZ'
); -- matched: POKRZYWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    219,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2023-2024'),
    11,
    'PYZIK Zdzisław'
); -- matched: PYZIK Zdzisław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    304,
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
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-EPEE-2023-2024'),
    2,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
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
    146,
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
-- SKIPPED (international, no master data): '`' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    262,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2023-2024'),
    3,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2023-2024'),
    6,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    315,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2023-2024'),
    9,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    10,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2023-2024'),
    12,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    245,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2023-2024'),
    13,
    'SOBIERAJ Wojciech'
); -- matched: SOBIERAJ Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    211,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2023-2024'),
    16,
    'POKRZYWA Mariusz'
); -- matched: POKRZYWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    79,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2023-2024'),
    20,
    'GRODNER Michał'
); -- matched: GRODNER Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
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
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V3-M-EPEE-2023-2024'),
    2,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    262,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V3-M-EPEE-2023-2024'),
    11,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    315,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V3-M-EPEE-2023-2024'),
    19,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V3-M-EPEE-2023-2024'),
    23,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    245,
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
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2023-2024'),
    3,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    262,
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
    146,
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
    146,
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
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW9-V3-M-EPEE-2023-2024'),
    1,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    262,
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
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V3-M-EPEE-2023-2024'),
    1,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    10,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V3-M-EPEE-2023-2024'),
    3,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    79,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V3-M-EPEE-2023-2024'),
    11,
    'GRODNER Michał'
); -- matched: GRODNER Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    262,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V3-M-EPEE-2023-2024'),
    13,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V3-M-EPEE-2023-2024'),
    15,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    38,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V3-M-EPEE-2023-2024'),
    19,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V3-M-EPEE-2023-2024'),
    20,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    315,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V3-M-EPEE-2023-2024'),
    21,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    114,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V3-M-EPEE-2023-2024'),
    22,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    219,
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
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW12-V3-M-EPEE-2023-2024'),
    1,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
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
-- SKIPPED (international, no master data): 'TIVENIUS' place=1
-- SKIPPED (international, no master data): 'BELLMANN' place=2
-- SKIPPED (international, no master data): 'CONY' place=3
-- SKIPPED (international, no master data): 'KERNOHAN' place=3
-- SKIPPED (international, no master data): 'AKERBERG' place=5
-- SKIPPED (international, no master data): 'BOIRON' place=6
-- SKIPPED (international, no master data): 'GOURSAUD' place=7
-- SKIPPED (international, no master data): 'BAGARD' place=8
-- SKIPPED (international, no master data): 'BONTHOUX' place=9
-- SKIPPED (international, no master data): 'SPANO' place=10
-- SKIPPED (international, no master data): 'WAGNER' place=11
-- SKIPPED (international, no master data): 'OSTERBERG' place=12
-- SKIPPED (international, no master data): 'DRAHUSAK' place=13
-- SKIPPED (international, no master data): 'FALCK-YTTER' place=14
-- SKIPPED (international, no master data): 'BARTLING' place=15
-- SKIPPED (international, no master data): 'MENG' place=16
-- SKIPPED (international, no master data): 'ARNOLD' place=17
-- SKIPPED (international, no master data): 'KATZLBERGER' place=18
-- SKIPPED (international, no master data): 'CHARTIER' place=19
-- SKIPPED (international, no master data): 'DOUSSE' place=20
-- SKIPPED (international, no master data): 'VAN DEN BERG' place=21
-- SKIPPED (international, no master data): 'BIRKENMAIER' place=22
-- SKIPPED (international, no master data): 'RAB' place=23
-- SKIPPED (international, no master data): 'DE GROOT' place=24
-- SKIPPED (international, no master data): 'LE BARBIER' place=25
-- SKIPPED (international, no master data): 'GERBER' place=26
-- SKIPPED (international, no master data): 'VAN ERVEN' place=27
-- SKIPPED (international, no master data): 'SEGUIN' place=28
-- SKIPPED (international, no master data): 'BACKER' place=29
-- SKIPPED (international, no master data): 'SAUTERON' place=30
-- SKIPPED (international, no master data): 'ZAGO' place=31
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-EPEE-2023-2024'),
    32,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
-- SKIPPED (international, no master data): 'LASSON' place=33
-- SKIPPED (international, no master data): 'BURKARDT' place=34
-- SKIPPED (international, no master data): 'STOCK' place=35
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-EPEE-2023-2024'),
    36,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
-- SKIPPED (international, no master data): 'SICOT' place=37
-- SKIPPED (international, no master data): 'STADTER' place=38
-- SKIPPED (international, no master data): 'BONNOT' place=39
-- SKIPPED (international, no master data): 'ALEKSANDROVSKI' place=40
-- SKIPPED (international, no master data): 'JINDRA' place=41
-- SKIPPED (international, no master data): 'L''ORPHELIN' place=42
-- SKIPPED (international, no master data): 'MASQUET' place=43
-- SKIPPED (international, no master data): 'TISSERAND' place=44
-- SKIPPED (international, no master data): 'POLIKARPOV' place=45
-- SKIPPED (international, no master data): 'FABIANO' place=46
-- SKIPPED (international, no master data): 'WAGNER' place=47
-- SKIPPED (international, no master data): 'SALGE' place=48
-- SKIPPED (international, no master data): 'BETOUT' place=49
-- SKIPPED (international, no master data): 'LIPTON' place=50
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    8,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-EPEE-2023-2024'),
    51,
    'ARONOWITSCH'
); -- matched: ARONOWITSCH Niklas (score=75.86206896551724)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    211,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-EPEE-2023-2024'),
    52,
    'POKRZYWA Mariusz'
); -- matched: POKRZYWA Mariusz (score=100.0)
-- SKIPPED (international, no master data): 'SCHAEDELE' place=53
-- SKIPPED (international, no master data): 'DAUENDORFFER' place=54
-- SKIPPED (international, no master data): 'BALCAZAR NAVARRO' place=55
-- SKIPPED (international, no master data): 'CHARTIER' place=56
-- SKIPPED (international, no master data): 'MULLER' place=57
-- SKIPPED (international, no master data): 'KLOTZ' place=58
-- SKIPPED (international, no master data): 'LE CLEAC''H' place=59
-- SKIPPED (international, no master data): 'PIANCA' place=60
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    262,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-EPEE-2023-2024'),
    61,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
-- SKIPPED (international, no master data): 'BILHAUT' place=62
-- SKIPPED (international, no master data): 'PORA' place=63
-- SKIPPED (international, no master data): 'GRUNDLEHNER' place=64
-- SKIPPED (international, no master data): 'SJODAHL' place=65
-- SKIPPED (international, no master data): 'CARNEC' place=66
-- SKIPPED (international, no master data): 'GUY' place=67
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    247,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-EPEE-2023-2024'),
    68,
    'SOMERS'
); -- matched: SOMERS Jan (score=75.0)
-- SKIPPED (international, no master data): 'ALLAIN' place=69
-- SKIPPED (international, no master data): 'JAENISCH' place=70
-- SKIPPED (international, no master data): 'DI LORETO' place=71
-- SKIPPED (international, no master data): 'BENOIST' place=72
-- SKIPPED (international, no master data): 'ALAVIDZE' place=73
-- SKIPPED (international, no master data): 'DESCHAMPS' place=74
-- SKIPPED (international, no master data): 'VAN HEERDE' place=75
-- SKIPPED (international, no master data): 'CICHOSZ' place=76
-- SKIPPED (international, no master data): 'EAMES' place=77
-- SKIPPED (international, no master data): 'HRUBRESCH' place=78
-- SKIPPED (international, no master data): 'MANTEAU' place=79
-- SKIPPED (international, no master data): 'MUNN' place=80
-- SKIPPED (international, no master data): 'SCHWARZE' place=81
-- SKIPPED (international, no master data): 'POLLARD' place=82
-- SKIPPED (international, no master data): 'TORTEROTOT' place=83
-- SKIPPED (international, no master data): 'HEYL' place=84
-- SKIPPED (international, no master data): 'ZIMMERMANN' place=85
-- SKIPPED (international, no master data): 'DE CONTI' place=86
-- SKIPPED (international, no master data): 'ANTONIOLI' place=87
-- SKIPPED (international, no master data): 'NOTTINGHAM' place=88
-- SKIPPED (international, no master data): 'SOICHET' place=89
-- SKIPPED (international, no master data): 'LEPINOIS' place=90
-- SKIPPED (international, no master data): 'GENEVEY' place=91
-- SKIPPED (international, no master data): 'BAUWELINCK' place=92
-- SKIPPED (international, no master data): 'REIMER' place=93
-- SKIPPED (international, no master data): 'STRUCK' place=94
-- SKIPPED (international, no master data): 'LANSÅKER' place=95
-- SKIPPED (international, no master data): 'FARIA' place=96
-- SKIPPED (international, no master data): 'SVOBODA' place=97
-- SKIPPED (international, no master data): 'MATZ' place=98
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    315,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-EPEE-2023-2024'),
    99,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
-- SKIPPED (international, no master data): 'MCCARRON' place=100
-- SKIPPED (international, no master data): 'GOUBIN' place=101
-- SKIPPED (international, no master data): 'SANS' place=102
-- SKIPPED (international, no master data): 'GALLAUZIAUX' place=103
-- SKIPPED (international, no master data): 'DUNAEVSKY' place=104
-- SKIPPED (international, no master data): 'KITTLER' place=105
-- SKIPPED (international, no master data): 'BOKUCHAVA' place=106
-- SKIPPED (international, no master data): 'HAMILTON' place=107
-- SKIPPED (international, no master data): 'PANNER' place=108
-- SKIPPED (international, no master data): 'FALLWICKL' place=109
-- SKIPPED (international, no master data): 'MAY' place=110
-- SKIPPED (international, no master data): 'KLUGE' place=111
-- SKIPPED (international, no master data): 'LE BAIL' place=112
-- SKIPPED (international, no master data): 'ELFVERSON' place=113
-- SKIPPED (international, no master data): 'EMCH' place=114
-- SKIPPED (international, no master data): 'POUPON' place=115
-- SKIPPED (international, no master data): 'MASSE' place=116
-- SKIPPED (international, no master data): 'GAMMA' place=117
-- SKIPPED (international, no master data): 'VAN COSTER' place=118
-- SKIPPED (international, no master data): 'SARKISOV' place=119
-- SKIPPED (international, no master data): 'MAYER' place=120
-- SKIPPED (international, no master data): 'DEFRANCE' place=121
-- SKIPPED (international, no master data): 'BOTTINO' place=122
-- SKIPPED (international, no master data): 'PISSOT' place=123
-- SKIPPED (international, no master data): 'CAMUS' place=124
-- SKIPPED (international, no master data): 'VALKOVIC' place=125
-- SKIPPED (international, no master data): 'GAGGIA' place=126
-- SKIPPED (international, no master data): 'RUSEV' place=127
-- SKIPPED (international, no master data): 'DECORDE' place=128
-- SKIPPED (international, no master data): 'LE CORRE' place=129
-- SKIPPED (international, no master data): 'VOLK' place=130
-- SKIPPED (international, no master data): 'LUEDERS' place=131
-- SKIPPED (international, no master data): 'PATTI' place=132
-- SKIPPED (international, no master data): 'RONDE' place=133
-- SKIPPED (international, no master data): 'FLAMENT' place=134
-- SKIPPED (international, no master data): 'SAERVOLL' place=135
-- SKIPPED (international, no master data): 'BENARD' place=136
-- SKIPPED (international, no master data): 'HYDE' place=137
-- SKIPPED (international, no master data): 'RUSZKAI' place=138
-- SKIPPED (international, no master data): 'GAY' place=139
-- SKIPPED (international, no master data): 'MONTEIL' place=140
-- SKIPPED (international, no master data): 'LEVY' place=141
-- SKIPPED (international, no master data): 'SHELAMOV' place=142
-- SKIPPED (international, no master data): 'DE LEPORINI' place=143
-- SKIPPED (international, no master data): 'HENNING' place=144
-- SKIPPED (international, no master data): 'KAINZ' place=145
-- SKIPPED (international, no master data): 'EMMANOUIL' place=146
-- SKIPPED (international, no master data): 'BURKHARD' place=147
-- SKIPPED (international, no master data): 'KAISER' place=148
-- SKIPPED (international, no master data): 'BIGEY' place=149
-- SKIPPED (international, no master data): 'ZYLKA' place=150
-- SKIPPED (international, no master data): 'KRISTENSEN' place=151
-- SKIPPED (international, no master data): 'BONEV' place=152
-- SKIPPED (international, no master data): 'EICHBERG' place=153
-- SKIPPED (international, no master data): 'KESZTHELYI' place=154
-- SKIPPED (international, no master data): 'SCHUELER' place=155
-- SKIPPED (international, no master data): 'FRANCESCHINI' place=156
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-EPEE-2023-2024'),
    159,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
-- Compute scores for IMEW-V3-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-EPEE-2023-2024')
);

-- Summary
-- Total results matched:   130
-- Total results unmatched: 150
-- Total auto-created:      0
