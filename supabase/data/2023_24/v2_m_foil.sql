-- =========================================================================
-- Season 2023-2024 — V2 M FOIL — generated from FLORET-2-2023-2024.xlsx
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
    'GP1-V2-M-FOIL-2023-2024',
    'Grand Prix (runda 1)',
    'PPW',
    'FOIL', 'M', 'V2',
    '2023-01-15', 4, 'https://www.fencingtimelive.com/events/results/5BE373F914FA4ECDA7E07BAFF9993D89',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    267,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-FOIL-2023-2024'),
    1,
    'SZMIDT Grzegorz'
); -- matched: SZMIDT Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    86,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-FOIL-2023-2024'),
    2,
    'GWIAZDA Paweł'
); -- matched: GWIAZDA Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    13,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-FOIL-2023-2024'),
    3,
    'BARAŃSKI Wacław'
); -- matched: BARAŃSKI Wacław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    300,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-FOIL-2023-2024'),
    4,
    'WOJTAS Bogdan'
); -- matched: WOJTAS Bogusław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    15,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-FOIL-2023-2024'),
    6,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
-- Compute scores for GP1-V2-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-FOIL-2023-2024')
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
    'GP2-V2-M-FOIL-2023-2024',
    'Grand Prix (runda 2)',
    'PPW',
    'FOIL', 'M', 'V2',
    '2023-03-05', 5, 'https://www.fencingtimelive.com/events/results/9410E2132E8641ED91518DE986E73AD5',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    267,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-FOIL-2023-2024'),
    1,
    'SZMIDT Grzegorz'
); -- matched: SZMIDT Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    214,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-FOIL-2023-2024'),
    2,
    'POŚPIESZNY Sławomir'
); -- matched: POŚPIESZNY Sławomir (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    86,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-FOIL-2023-2024'),
    3,
    'GWIAZDA Paweł'
); -- matched: GWIAZDA Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    13,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-FOIL-2023-2024'),
    4,
    'BARAŃSKI Wacław'
); -- matched: BARAŃSKI Wacław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-FOIL-2023-2024'),
    5,
    'KASZTELOWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=74.28571428571429)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    15,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-FOIL-2023-2024'),
    8,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-FOIL-2023-2024'),
    9,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
-- Compute scores for GP2-V2-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-FOIL-2023-2024')
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
    'GP3-V2-M-FOIL-2023-2024',
    'Grand Prix (runda 3)',
    'PPW',
    'FOIL', 'M', 'V2',
    '2023-06-18', 5, 'https://www.fencingtimelive.com/events/results/B999A49AA2E5465390AD2C628C97E3CF',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    267,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-FOIL-2023-2024'),
    1,
    'SZMIDT Grzegorz'
); -- matched: SZMIDT Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    86,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-FOIL-2023-2024'),
    2,
    'GWIAZDA Paweł'
); -- matched: GWIAZDA Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    214,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-FOIL-2023-2024'),
    3,
    'POŚPIESZNY Sławomir'
); -- matched: POŚPIESZNY Sławomir (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    300,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-FOIL-2023-2024'),
    4,
    'WOJTAS Bogdan'
); -- matched: WOJTAS Bogusław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    13,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-FOIL-2023-2024'),
    5,
    'BARAŃSKI Wacław'
); -- matched: BARAŃSKI Wacław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-FOIL-2023-2024'),
    6,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
-- Compute scores for GP3-V2-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-FOIL-2023-2024')
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
    'GP4-V2-M-FOIL-2023-2024',
    'Grand Prix (runda 4)',
    'PPW',
    'FOIL', 'M', 'V2',
    '2023-10-23', 6, 'https://www.fencingtimelive.com/events/results/C651964583C24A16B624B753D5394B58',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    15,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-FOIL-2023-2024'),
    1,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    267,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-FOIL-2023-2024'),
    2,
    'SZMIDT Grzegorz'
); -- matched: SZMIDT Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    214,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-FOIL-2023-2024'),
    3,
    'POŚPIESZNY Sławomir'
); -- matched: POŚPIESZNY Sławomir (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-FOIL-2023-2024'),
    4,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    86,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-FOIL-2023-2024'),
    5,
    'GWIAZDA Paweł'
); -- matched: GWIAZDA Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    300,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-FOIL-2023-2024'),
    6,
    'WOJTAS Bogdan'
); -- matched: WOJTAS Bogusław (score=100)
-- Compute scores for GP4-V2-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-FOIL-2023-2024')
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
    'GP5-V2-M-FOIL-2023-2024',
    'Grand Prix (runda 5)',
    'PPW',
    'FOIL', 'M', 'V2',
    '2023-10-28', 3, 'https://www.fencingtimelive.com/events/results/0CC2C91478474AF1B0F4E8EF994F25A3',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-M-FOIL-2023-2024'),
    1,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    214,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-M-FOIL-2023-2024'),
    2,
    'POŚPIESZNY Sławomir'
); -- matched: POŚPIESZNY Sławomir (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    15,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-M-FOIL-2023-2024'),
    3,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
-- Compute scores for GP5-V2-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-M-FOIL-2023-2024')
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
    'GP6-V2-M-FOIL-2023-2024',
    'Grand Prix (runda 6)',
    'PPW',
    'FOIL', 'M', 'V2',
    '2023-11-18', 5, 'https://www.fencingtimelive.com/events/results/A5E777577B204CB6A5807F733A6E7AFC',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    267,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-FOIL-2023-2024'),
    1,
    'SZMIDT Grzegorz'
); -- matched: SZMIDT Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    214,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-FOIL-2023-2024'),
    2,
    'POŚPIESZNY Sławomir'
); -- matched: POŚPIESZNY Sławomir (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-FOIL-2023-2024'),
    3,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    86,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-FOIL-2023-2024'),
    4,
    'GWIAZDA Paweł'
); -- matched: GWIAZDA Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    302,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-FOIL-2023-2024'),
    5,
    'WRONA Grzegorz'
); -- matched: WRONA Grzegorz (score=100.0)
-- Compute scores for GP6-V2-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-FOIL-2023-2024')
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
    'GP7-V2-M-FOIL-2023-2024',
    'Grand Prix (runda 7)',
    'PPW',
    'FOIL', 'M', 'V2',
    '2024-01-28', 2, 'https://www.fencingtimelive.com/events/results/15D820D5BA9A442AA26E2B4B816F091F',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    15,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-FOIL-2023-2024'),
    1,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    86,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-FOIL-2023-2024'),
    2,
    'GWIAZDA Paweł'
); -- matched: GWIAZDA Paweł (score=100.0)
-- Compute scores for GP7-V2-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-FOIL-2023-2024')
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
    'GP8-V2-M-FOIL-2023-2024',
    'Grand Prix (runda 8)',
    'PPW',
    'FOIL', 'M', 'V2',
    '2024-06-23', 3, 'https://www.fencingtimelive.com/events/results/7D2BA42AD5DE4CCF8741AE820B7BE7D7',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-FOIL-2023-2024'),
    1,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    15,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-FOIL-2023-2024'),
    2,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    318,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-FOIL-2023-2024'),
    3,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100.0)
-- Compute scores for GP8-V2-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-FOIL-2023-2024')
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
    'MPW-V2-M-FOIL-2023-2024',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'FOIL', 'M', 'V2',
    '2024-03-02', 6, 'https://www.fencingtimelive.com/events/results/03FB74210A7C4304866822B03B94FD95',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    267,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-FOIL-2023-2024'),
    1,
    'SZMIDT Grzegorz'
); -- matched: SZMIDT Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-FOIL-2023-2024'),
    2,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    15,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-FOIL-2023-2024'),
    3,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    214,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-FOIL-2023-2024'),
    4,
    'POŚPIESZNY Sławomir'
); -- matched: POŚPIESZNY Sławomir (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    300,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-FOIL-2023-2024'),
    5,
    'WOJTAS Bogdan'
); -- matched: WOJTAS Bogusław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    264,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-FOIL-2023-2024'),
    6,
    'SZKODA Marek Tomasz'
); -- matched: SZKODA Marek Tomasz (score=100.0)
-- Compute scores for MPW-V2-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-FOIL-2023-2024')
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
    'PEW4-V2-M-FOIL-2023-2024',
    'EVF Grand Prix 4',
    'PEW',
    'FOIL', 'M', 'V2',
    '2023-03-18', 17, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    140,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-FOIL-2023-2024'),
    3,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
-- Compute scores for PEW4-V2-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-FOIL-2023-2024')
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
    'PEW5-V2-M-FOIL-2023-2024',
    'EVF Grand Prix 5',
    'PEW',
    'FOIL', 'M', 'V2',
    '2023-09-16', 23, 'https://engarde-service.com/?fbclid=IwAR1q8b20973WNdhLRYbl3vdP-rPK0cilvuHZi37KFNf-Dodoicffb3YOQeM',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    140,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V2-M-FOIL-2023-2024'),
    3,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
-- Compute scores for PEW5-V2-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V2-M-FOIL-2023-2024')
);

-- SKIP PEW6 (EVF Grand Prix 6): N=0 — tournament had no participants

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): N=0 — tournament had no participants

-- SKIP PEW8 (EVF Grand Prix 8 — Guildford): N=0 — tournament had no participants

-- SKIP PEW9 (EVF Grand Prix 9 — Sztokholm): N=0 — tournament had no participants

-- SKIP PEW10 (EVF Grand Prix 10 — Graz): N=0 — tournament had no participants

-- SKIP PEW11 (EVF Grand Prix 11 — Gdańsk): N=0 — tournament had no participants

-- ---- PEW12: EVF Grand Prix 12 — Ateny (Graz) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW12-2023-2024',
    'EVF Grand Prix 12 — Ateny',
    'Graz',
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
    'PEW12-V2-M-FOIL-2023-2024',
    'EVF Grand Prix 12 — Ateny',
    'PEW',
    'FOIL', 'M', 'V2',
    '2023-03-23', 24, 'https://www.veteransfencing.eu/fencing/rankings/',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    140,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW12-V2-M-FOIL-2023-2024'),
    9,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
-- Compute scores for PEW12-V2-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW12-V2-M-FOIL-2023-2024')
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
    'IMEW-V2-M-FOIL-2023-2024',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'FOIL', 'M', 'V2',
    '2023-01-01', 77, 'https://engarde-service.com/competition/e3f/efcv/menfoilv2',
    'SCORED'
);
-- SKIPPED (international, no master data): 'LIMOV' place=1
-- SKIPPED (international, no master data): 'CHRISTEN' place=2
-- SKIPPED (international, no master data): 'CAMBON' place=3
-- SKIPPED (international, no master data): 'LACROIX' place=3
-- SKIPPED (international, no master data): 'BEAURENAULT' place=5
-- SKIPPED (international, no master data): 'PETERS' place=6
-- SKIPPED (international, no master data): 'PERSICHETTI' place=7
-- SKIPPED (international, no master data): 'PULEGA' place=8
-- SKIPPED (international, no master data): 'MCKAY' place=9
-- SKIPPED (international, no master data): 'DI RUSSO' place=10
-- SKIPPED (international, no master data): 'ISSARTIER' place=11
-- SKIPPED (international, no master data): 'MARCAILLOU' place=12
-- SKIPPED (international, no master data): 'PIOFRET' place=13
-- SKIPPED (international, no master data): 'MASSET' place=14
-- SKIPPED (international, no master data): 'WUNDERLICH' place=15
-- SKIPPED (international, no master data): 'CHAZAUD' place=16
-- SKIPPED (international, no master data): 'HELLSTROM' place=17
-- SKIPPED (international, no master data): 'ELLISON' place=18
-- SKIPPED (international, no master data): 'ASSELOT' place=19
-- SKIPPED (international, no master data): 'ABIDOGUN' place=20
-- SKIPPED (international, no master data): 'SIRIU' place=21
-- SKIPPED (international, no master data): 'HELLER' place=22
-- SKIPPED (international, no master data): 'REID' place=23
-- SKIPPED (international, no master data): 'GEORGES' place=24
-- SKIPPED (international, no master data): 'HEGEDUS' place=25
-- SKIPPED (international, no master data): 'RAEKER' place=26
-- SKIPPED (international, no master data): 'PESCE' place=27
-- SKIPPED (international, no master data): 'NICOLI' place=28
-- SKIPPED (international, no master data): 'HAYAT' place=29
-- SKIPPED (international, no master data): 'SZABO' place=30
-- SKIPPED (international, no master data): 'PAYNE' place=31
-- SKIPPED (international, no master data): 'JACOBY' place=32
-- SKIPPED (international, no master data): 'MEYER' place=33
-- SKIPPED (international, no master data): 'MORT' place=34
-- SKIPPED (international, no master data): 'LIMER' place=35
-- SKIPPED (international, no master data): 'GAUDIN' place=36
-- SKIPPED (international, no master data): 'PIETROMARCHI' place=37
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    140,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-FOIL-2023-2024'),
    38,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
-- SKIPPED (international, no master data): 'SUNG' place=39
-- SKIPPED (international, no master data): 'ELMFELDT' place=40
-- SKIPPED (international, no master data): 'GRIFFIN' place=41
-- SKIPPED (international, no master data): 'DEBURGH' place=42
-- SKIPPED (international, no master data): 'VOSSENBERG' place=43
-- SKIPPED (international, no master data): 'COLLINS' place=44
-- SKIPPED (international, no master data): 'BAILLACHE' place=45
-- SKIPPED (international, no master data): 'CARRE DE MALBERG' place=46
-- SKIPPED (international, no master data): 'BICANIC' place=47
-- SKIPPED (international, no master data): 'CASSORET' place=48
-- SKIPPED (international, no master data): 'LIENART' place=49
-- SKIPPED (international, no master data): 'BIERLAIRE' place=50
-- SKIPPED (international, no master data): 'CARON' place=51
-- SKIPPED (international, no master data): 'SZALAY' place=52
-- SKIPPED (international, no master data): 'NGUYEN QUANG' place=53
-- SKIPPED (international, no master data): 'DONOVAN' place=54
-- SKIPPED (international, no master data): 'HASSINGER' place=55
-- SKIPPED (international, no master data): 'PETERSTRAND' place=56
-- SKIPPED (international, no master data): 'FARKAS' place=57
-- SKIPPED (international, no master data): 'CICOIRA' place=58
-- SKIPPED (international, no master data): 'KIY' place=59
-- SKIPPED (international, no master data): 'WEBER' place=60
-- SKIPPED (international, no master data): 'GANGI' place=61
-- SKIPPED (international, no master data): 'SCHMOLKE' place=62
-- SKIPPED (international, no master data): 'MULLER' place=63
-- SKIPPED (international, no master data): 'KESKINIVA' place=64
-- SKIPPED (international, no master data): 'GOEMAERE' place=65
-- SKIPPED (international, no master data): 'VICTORY' place=66
-- SKIPPED (international, no master data): 'BENASSI' place=67
-- SKIPPED (international, no master data): 'ZHUKOVSKYI' place=68
-- SKIPPED (international, no master data): 'GARCIA' place=69
-- SKIPPED (international, no master data): 'SCHUHFRIED' place=70
-- SKIPPED (international, no master data): 'KRAEMER' place=71
-- SKIPPED (international, no master data): 'MOISI' place=72
-- SKIPPED (international, no master data): 'IWERSEN' place=73
-- SKIPPED (international, no master data): 'CWIKLA' place=74
-- SKIPPED (international, no master data): 'GIOVINE' place=75
-- SKIPPED (international, no master data): 'LUCREZI' place=76
-- SKIPPED (international, no master data): 'SAOUZANET' place=77
-- Compute scores for IMEW-V2-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-FOIL-2023-2024')
);

-- Summary
-- Total results matched:   47
-- Total results unmatched: 76
-- Total auto-created:      0
