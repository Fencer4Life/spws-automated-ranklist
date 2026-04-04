-- =========================================================================
-- Season 2023-2024 — V3 M FOIL — generated from FLORET-3-2023-2024.xlsx
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
    'GP1-V3-M-FOIL-2023-2024',
    'Grand Prix (runda 1)',
    'PPW',
    'FOIL', 'M', 'V3',
    '2023-01-15', 5, 'https://www.fencingtimelive.com/events/results/3CC5E3814C224E01BEC000472E10C5AE',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-FOIL-2023-2024'),
    1,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    211,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-FOIL-2023-2024'),
    2,
    'POKRZYWA Mariusz'
); -- matched: POKRZYWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    114,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-FOIL-2023-2024'),
    3,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    315,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-FOIL-2023-2024'),
    4,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-FOIL-2023-2024'),
    5,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    13,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-FOIL-2023-2024'),
    7,
    'BARAŃSKI Wacław'
); -- matched: BARAŃSKI Wacław (score=100.0)
-- Compute scores for GP1-V3-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-FOIL-2023-2024')
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
    'GP2-V3-M-FOIL-2023-2024',
    'Grand Prix (runda 2)',
    'PPW',
    'FOIL', 'M', 'V3',
    '2023-03-05', 3, 'https://www.fencingtimelive.com/events/results/0C25AABBE8204E94895C34EC32FF0DB3',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-FOIL-2023-2024'),
    1,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    315,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-FOIL-2023-2024'),
    2,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-FOIL-2023-2024'),
    3,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    13,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-FOIL-2023-2024'),
    5,
    'BARAŃSKI Wacław'
); -- matched: BARAŃSKI Wacław (score=100.0)
-- Compute scores for GP2-V3-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-FOIL-2023-2024')
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
    'GP3-V3-M-FOIL-2023-2024',
    'Grand Prix (runda 3)',
    'PPW',
    'FOIL', 'M', 'V3',
    '2023-06-18', 4, 'https://www.fencingtimelive.com/events/results/0BEDA2182C2B4BCF9694B7CB471A3976',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    211,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-FOIL-2023-2024'),
    1,
    'POKRZYWA Mariusz'
); -- matched: POKRZYWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-FOIL-2023-2024'),
    2,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    169,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-FOIL-2023-2024'),
    3,
    'MAŁASIŃSKI Adam'
); -- matched: MAŁASIŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    24,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-FOIL-2023-2024'),
    4,
    'BORKOWSKI Andrzej'
); -- matched: BORKOWSKI Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    13,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-FOIL-2023-2024'),
    6,
    'BARAŃSKI Wacław'
); -- matched: BARAŃSKI Wacław (score=100.0)
-- Compute scores for GP3-V3-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-FOIL-2023-2024')
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
    'GP4-V3-M-FOIL-2023-2024',
    'Grand Prix (runda 4)',
    'PPW',
    'FOIL', 'M', 'V3',
    '2023-10-23', 4, 'https://www.fencingtimelive.com/events/results/15CFDD0FE7594322BC9E1692AB769F51',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V3-M-FOIL-2023-2024'),
    1,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    114,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V3-M-FOIL-2023-2024'),
    2,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    315,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V3-M-FOIL-2023-2024'),
    3,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    13,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V3-M-FOIL-2023-2024'),
    4,
    'BARAŃSKI Wacław'
); -- matched: BARAŃSKI Wacław (score=100.0)
-- Compute scores for GP4-V3-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V3-M-FOIL-2023-2024')
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
    'GP5-V3-M-FOIL-2023-2024',
    'Grand Prix (runda 5)',
    'PPW',
    'FOIL', 'M', 'V3',
    '2023-10-28', 5, 'https://www.fencingtimelive.com/events/results/EC28FF8573C6413F90CD4E218E7A53C3',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V3-M-FOIL-2023-2024'),
    1,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    211,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V3-M-FOIL-2023-2024'),
    2,
    'POKRZYWA Mariusz'
); -- matched: POKRZYWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V3-M-FOIL-2023-2024'),
    3,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    315,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V3-M-FOIL-2023-2024'),
    4,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    114,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V3-M-FOIL-2023-2024'),
    5,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
-- Compute scores for GP5-V3-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V3-M-FOIL-2023-2024')
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
    'GP6-V3-M-FOIL-2023-2024',
    'Grand Prix (runda 6)',
    'PPW',
    'FOIL', 'M', 'V3',
    '2023-11-18', 4, 'https://www.fencingtimelive.com/events/results/9267EFB97377411FA48172BE8F1A8FF4',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-FOIL-2023-2024'),
    1,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    211,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-FOIL-2023-2024'),
    2,
    'POKRZYWA Mariusz'
); -- matched: POKRZYWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    114,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-FOIL-2023-2024'),
    3,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    169,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-FOIL-2023-2024'),
    4,
    'MAŁASIŃSKI Adam'
); -- matched: MAŁASIŃSKI Adam (score=100.0)
-- Compute scores for GP6-V3-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-FOIL-2023-2024')
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
    'GP7-V3-M-FOIL-2023-2024',
    'Grand Prix (runda 7)',
    'PPW',
    'FOIL', 'M', 'V3',
    '2024-01-28', 1, 'https://www.fencingtimelive.com/events/results/15D820D5BA9A442AA26E2B4B816F091F',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    315,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V3-M-FOIL-2023-2024'),
    1,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
-- Compute scores for GP7-V3-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V3-M-FOIL-2023-2024')
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
    'GP8-V3-M-FOIL-2023-2024',
    'Grand Prix (runda 8)',
    'PPW',
    'FOIL', 'M', 'V3',
    '2024-06-23', 3, 'https://www.fencingtimelive.com/events/results/069BD60B24D446E18A88DAB2EC0AEDCD',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    211,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-FOIL-2023-2024'),
    1,
    'POKRZYWA MARIUSZ'
); -- matched: POKRZYWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    169,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-FOIL-2023-2024'),
    2,
    'MAŁASIŃSKI Adam'
); -- matched: MAŁASIŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    114,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-FOIL-2023-2024'),
    3,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
-- Compute scores for GP8-V3-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-FOIL-2023-2024')
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
    'MPW-V3-M-FOIL-2023-2024',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'FOIL', 'M', 'V3',
    '2024-03-02', 5, 'https://www.fencingtimelive.com/events/results/34F20C04D4614DCF85B64A7E7245AA01',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    211,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-FOIL-2023-2024'),
    1,
    'POKRZYWA MARIUSZ'
); -- matched: POKRZYWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    169,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-FOIL-2023-2024'),
    2,
    'MAŁASIŃSKI Adam'
); -- matched: MAŁASIŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    260,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-FOIL-2023-2024'),
    3,
    'SUROWIEC Tomasz'
); -- matched: SUROWIEC Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    114,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-FOIL-2023-2024'),
    4,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    315,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-FOIL-2023-2024'),
    5,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
-- Compute scores for MPW-V3-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-FOIL-2023-2024')
);

-- SKIP PEW1 (EVF Grand Prix 1 — Budapeszt): N=0 — tournament had no participants

-- SKIP PEW2 (EVF Grand Prix 2 — Madryt): N=0 — tournament had no participants

-- SKIP PEW3 (EVF Grand Prix 3): N=0 — tournament had no participants

-- ---- PEW4: EVF Grand Prix 4 (Graz) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW4-2023-2024',
    'EVF Grand Prix 4',
    'Graz',
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
    'PEW4-V3-M-FOIL-2023-2024',
    'EVF Grand Prix 4',
    'PEW',
    'FOIL', 'M', 'V3',
    '2023-03-18', 18, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V3-M-FOIL-2023-2024'),
    11,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    211,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V3-M-FOIL-2023-2024'),
    13,
    'POKRZYWA Mariusz'
); -- matched: POKRZYWA Mariusz (score=100.0)
-- Compute scores for PEW4-V3-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V3-M-FOIL-2023-2024')
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
    'PEW5-V3-M-FOIL-2023-2024',
    'EVF Grand Prix 5',
    'PEW',
    'FOIL', 'M', 'V3',
    '2023-09-16', 20, 'https://engarde-service.com/?fbclid=IwAR1q8b20973WNdhLRYbl3vdP-rPK0cilvuHZi37KFNf-Dodoicffb3YOQeM',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V3-M-FOIL-2023-2024'),
    3,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V3-M-FOIL-2023-2024'),
    13,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
-- Compute scores for PEW5-V3-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V3-M-FOIL-2023-2024')
);

-- SKIP PEW6 (EVF Grand Prix 6): N=0 — tournament had no participants

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): N=0 — tournament had no participants

-- SKIP PEW8 (EVF Grand Prix 8 — Guildford): N=0 — tournament had no participants

-- SKIP PEW9 (EVF Grand Prix 9 — Sztokholm): N=0 — tournament had no participants

-- SKIP PEW10 (EVF Grand Prix 10 — Graz): N=0 — tournament had no participants

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
    'IMEW-V3-M-FOIL-2023-2024',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'FOIL', 'M', 'V3',
    '2023-01-01', 62, 'https://engarde-service.com/competition/e3f/efcv/menfoilv3',
    'SCORED'
);
-- SKIPPED (international, no master data): 'CSAK' place=1
-- SKIPPED (international, no master data): 'HUERTO' place=2
-- SKIPPED (international, no master data): 'RIJSENBRIJ' place=3
-- SKIPPED (international, no master data): 'TROIANO' place=3
-- SKIPPED (international, no master data): 'DOUSSE' place=5
-- SKIPPED (international, no master data): 'PALM' place=6
-- SKIPPED (international, no master data): 'BOSIO' place=7
-- SKIPPED (international, no master data): 'AKERBERG' place=8
-- SKIPPED (international, no master data): 'MEDHURST' place=9
-- SKIPPED (international, no master data): 'JOLYOT' place=10
-- SKIPPED (international, no master data): 'ZIEBELL' place=11
-- SKIPPED (international, no master data): 'ROSANO' place=12
-- SKIPPED (international, no master data): 'GAJADHARSINGH' place=13
-- SKIPPED (international, no master data): 'MIRALDI' place=14
-- SKIPPED (international, no master data): 'MONDT' place=15
-- SKIPPED (international, no master data): 'APTSIAURI' place=16
-- SKIPPED (international, no master data): 'WEDGE' place=17
-- SKIPPED (international, no master data): 'PENTEK' place=18
-- SKIPPED (international, no master data): 'RIESZ' place=19
-- SKIPPED (international, no master data): 'BARTLETT' place=20
-- SKIPPED (international, no master data): 'POSTHUMA' place=21
-- SKIPPED (international, no master data): 'CONTREPOIS' place=22
-- SKIPPED (international, no master data): 'EITZ' place=23
-- SKIPPED (international, no master data): 'MAZZOTTA' place=24
-- SKIPPED (international, no master data): 'KATZLBERGER' place=25
-- SKIPPED (international, no master data): 'QUAGLIA' place=26
-- SKIPPED (international, no master data): 'BURNEY' place=27
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    211,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-FOIL-2023-2024'),
    28,
    'POKRZYWA Mariusz'
); -- matched: POKRZYWA Mariusz (score=100.0)
-- SKIPPED (international, no master data): 'JEINER' place=29
-- SKIPPED (international, no master data): 'BAUDOUIN' place=30
-- SKIPPED (international, no master data): 'SAGE' place=31
-- SKIPPED (international, no master data): 'BARTLING' place=32
-- SKIPPED (international, no master data): 'MESZAROS' place=33
-- SKIPPED (international, no master data): 'EVANS' place=34
-- SKIPPED (international, no master data): 'HRUBRESCH' place=35
-- SKIPPED (international, no master data): 'RUSZKAI' place=36
-- SKIPPED (international, no master data): 'BABOS' place=37
-- SKIPPED (international, no master data): 'BOHMER' place=38
-- SKIPPED (international, no master data): 'HYDE' place=39
-- SKIPPED (international, no master data): 'DAWKINS' place=40
-- SKIPPED (international, no master data): 'AGRANOVICH' place=41
-- SKIPPED (international, no master data): 'ZYLKA' place=42
-- SKIPPED (international, no master data): 'ALON' place=43
-- SKIPPED (international, no master data): 'SARDI' place=44
-- SKIPPED (international, no master data): 'MULDER' place=45
-- SKIPPED (international, no master data): 'BENARD' place=46
-- SKIPPED (international, no master data): 'HAMILTON' place=47
-- SKIPPED (international, no master data): 'TORTORA' place=48
-- SKIPPED (international, no master data): 'TACKENSTROM' place=49
-- SKIPPED (international, no master data): 'PFEIL' place=50
-- SKIPPED (international, no master data): 'VAN DER WEIDE' place=51
-- SKIPPED (international, no master data): 'GHILARDI' place=52
-- SKIPPED (international, no master data): 'CIBOIS' place=53
-- SKIPPED (international, no master data): 'BRASTED' place=54
-- SKIPPED (international, no master data): 'KAINZ' place=55
-- SKIPPED (international, no master data): 'NEUHAUS' place=56
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-FOIL-2023-2024'),
    57,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
-- SKIPPED (international, no master data): 'SARETTA' place=58
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    315,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-FOIL-2023-2024'),
    59,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
-- SKIPPED (international, no master data): 'COATES' place=60
-- SKIPPED (international, no master data): 'FALLWICKL' place=61
-- SKIPPED (international, no master data): 'GAGGIA' place=62
-- Compute scores for IMEW-V3-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-FOIL-2023-2024')
);

-- Summary
-- Total results matched:   44
-- Total results unmatched: 59
-- Total auto-created:      0
