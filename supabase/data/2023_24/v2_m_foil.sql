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
    225,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-FOIL-2023-2024'),
    1,
    'SZMIDT Grzegorz'
); -- matched: SZMIDT Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    83,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-FOIL-2023-2024'),
    2,
    'GWIAZDA Paweł'
); -- matched: GWIAZDA Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-FOIL-2023-2024'),
    3,
    'BARAŃSKI Wacław'
); -- matched: BARAŃSKI Wacław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    258,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-FOIL-2023-2024'),
    4,
    'WOJTAS Bogdan'
); -- matched: WOJTAS Bogdan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    11,
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
    225,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-FOIL-2023-2024'),
    1,
    'SZMIDT Grzegorz'
); -- matched: SZMIDT Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-FOIL-2023-2024'),
    2,
    'POŚPIESZNY Sławomir'
); -- matched: POŚPIESZNY Sławomir (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    83,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-FOIL-2023-2024'),
    3,
    'GWIAZDA Paweł'
); -- matched: GWIAZDA Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-FOIL-2023-2024'),
    4,
    'BARAŃSKI Wacław'
); -- matched: BARAŃSKI Wacław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    102,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-FOIL-2023-2024'),
    5,
    'KASZTELOWICZ Piotr'
); -- matched: KASZTELOWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    11,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-FOIL-2023-2024'),
    8,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    86,
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
    225,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-FOIL-2023-2024'),
    1,
    'SZMIDT Grzegorz'
); -- matched: SZMIDT Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    83,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-FOIL-2023-2024'),
    2,
    'GWIAZDA Paweł'
); -- matched: GWIAZDA Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-FOIL-2023-2024'),
    3,
    'POŚPIESZNY Sławomir'
); -- matched: POŚPIESZNY Sławomir (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    258,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-FOIL-2023-2024'),
    4,
    'WOJTAS Bogdan'
); -- matched: WOJTAS Bogdan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-FOIL-2023-2024'),
    5,
    'BARAŃSKI Wacław'
); -- matched: BARAŃSKI Wacław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    86,
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
    11,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-FOIL-2023-2024'),
    1,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    225,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-FOIL-2023-2024'),
    2,
    'SZMIDT Grzegorz'
); -- matched: SZMIDT Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-FOIL-2023-2024'),
    3,
    'POŚPIESZNY Sławomir'
); -- matched: POŚPIESZNY Sławomir (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    86,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-FOIL-2023-2024'),
    4,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    83,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-FOIL-2023-2024'),
    5,
    'GWIAZDA Paweł'
); -- matched: GWIAZDA Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    258,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-FOIL-2023-2024'),
    6,
    'WOJTAS Bogdan'
); -- matched: WOJTAS Bogdan (score=100.0)
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
    86,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-M-FOIL-2023-2024'),
    1,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-M-FOIL-2023-2024'),
    2,
    'POŚPIESZNY Sławomir'
); -- matched: POŚPIESZNY Sławomir (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    11,
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
    225,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-FOIL-2023-2024'),
    1,
    'SZMIDT Grzegorz'
); -- matched: SZMIDT Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-FOIL-2023-2024'),
    2,
    'POŚPIESZNY Sławomir'
); -- matched: POŚPIESZNY Sławomir (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    86,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-FOIL-2023-2024'),
    3,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    83,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-FOIL-2023-2024'),
    4,
    'GWIAZDA Paweł'
); -- matched: GWIAZDA Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    259,
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
    11,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-FOIL-2023-2024'),
    1,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    83,
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
    86,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-FOIL-2023-2024'),
    1,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    11,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-FOIL-2023-2024'),
    2,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    269,
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
    225,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-FOIL-2023-2024'),
    1,
    'SZMIDT Grzegorz'
); -- matched: SZMIDT Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    86,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-FOIL-2023-2024'),
    2,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    11,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-FOIL-2023-2024'),
    3,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-FOIL-2023-2024'),
    4,
    'POŚPIESZNY Sławomir'
); -- matched: POŚPIESZNY Sławomir (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    258,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-FOIL-2023-2024'),
    5,
    'WOJTAS Bogdan'
); -- matched: WOJTAS Bogdan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    358,
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
    233,
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
    233,
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
    233,
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
-- UNMATCHED (score<80): 'LIMOV' place=1
-- UNMATCHED (score<80): 'CHRISTEN' place=2
-- UNMATCHED (score<80): 'CAMBON' place=3
-- UNMATCHED (score<80): 'LACROIX' place=3
-- UNMATCHED (score<80): 'BEAURENAULT' place=5
-- UNMATCHED (score<80): 'PETERS' place=6
-- UNMATCHED (score<80): 'PERSICHETTI' place=7
-- UNMATCHED (score<80): 'PULEGA' place=8
-- UNMATCHED (score<80): 'MCKAY' place=9
-- UNMATCHED (score<80): 'DI RUSSO' place=10
-- UNMATCHED (score<80): 'ISSARTIER' place=11
-- UNMATCHED (score<80): 'MARCAILLOU' place=12
-- UNMATCHED (score<80): 'PIOFRET' place=13
-- UNMATCHED (score<80): 'MASSET' place=14
-- UNMATCHED (score<80): 'WUNDERLICH' place=15
-- UNMATCHED (score<80): 'CHAZAUD' place=16
-- UNMATCHED (score<80): 'HELLSTROM' place=17
-- UNMATCHED (score<80): 'ELLISON' place=18
-- UNMATCHED (score<80): 'ASSELOT' place=19
-- UNMATCHED (score<80): 'ABIDOGUN' place=20
-- UNMATCHED (score<80): 'SIRIU' place=21
-- UNMATCHED (score<80): 'HELLER' place=22
-- UNMATCHED (score<80): 'REID' place=23
-- UNMATCHED (score<80): 'GEORGES' place=24
-- UNMATCHED (score<80): 'HEGEDUS' place=25
-- UNMATCHED (score<80): 'RAEKER' place=26
-- UNMATCHED (score<80): 'PESCE' place=27
-- UNMATCHED (score<80): 'NICOLI' place=28
-- UNMATCHED (score<80): 'HAYAT' place=29
-- UNMATCHED (score<80): 'SZABO' place=30
-- UNMATCHED (score<80): 'PAYNE' place=31
-- UNMATCHED (score<80): 'JACOBY' place=32
-- UNMATCHED (score<80): 'MEYER' place=33
-- UNMATCHED (score<80): 'MORT' place=34
-- UNMATCHED (score<80): 'LIMER' place=35
-- UNMATCHED (score<80): 'GAUDIN' place=36
-- UNMATCHED (score<80): 'PIETROMARCHI' place=37
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-FOIL-2023-2024'),
    38,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
-- UNMATCHED (score<80): 'SUNG' place=39
-- UNMATCHED (score<80): 'ELMFELDT' place=40
-- UNMATCHED (score<80): 'GRIFFIN' place=41
-- UNMATCHED (score<80): 'DEBURGH' place=42
-- UNMATCHED (score<80): 'VOSSENBERG' place=43
-- UNMATCHED (score<80): 'COLLINS' place=44
-- UNMATCHED (score<80): 'BAILLACHE' place=45
-- UNMATCHED (score<80): 'CARRE DE MALBERG' place=46
-- UNMATCHED (score<80): 'BICANIC' place=47
-- UNMATCHED (score<80): 'CASSORET' place=48
-- UNMATCHED (score<80): 'LIENART' place=49
-- UNMATCHED (score<80): 'BIERLAIRE' place=50
-- UNMATCHED (score<80): 'CARON' place=51
-- UNMATCHED (score<80): 'SZALAY' place=52
-- UNMATCHED (score<80): 'NGUYEN QUANG' place=53
-- UNMATCHED (score<80): 'DONOVAN' place=54
-- UNMATCHED (score<80): 'HASSINGER' place=55
-- UNMATCHED (score<80): 'PETERSTRAND' place=56
-- UNMATCHED (score<80): 'FARKAS' place=57
-- UNMATCHED (score<80): 'CICOIRA' place=58
-- UNMATCHED (score<80): 'KIY' place=59
-- UNMATCHED (score<80): 'WEBER' place=60
-- UNMATCHED (score<80): 'GANGI' place=61
-- UNMATCHED (score<80): 'SCHMOLKE' place=62
-- UNMATCHED (score<80): 'MULLER' place=63
-- UNMATCHED (score<80): 'KESKINIVA' place=64
-- UNMATCHED (score<80): 'GOEMAERE' place=65
-- UNMATCHED (score<80): 'VICTORY' place=66
-- UNMATCHED (score<80): 'BENASSI' place=67
-- UNMATCHED (score<80): 'ZHUKOVSKYI' place=68
-- UNMATCHED (score<80): 'GARCIA' place=69
-- UNMATCHED (score<80): 'SCHUHFRIED' place=70
-- UNMATCHED (score<80): 'KRAEMER' place=71
-- UNMATCHED (score<80): 'MOISI' place=72
-- UNMATCHED (score<80): 'IWERSEN' place=73
-- UNMATCHED (score<80): 'CWIKLA' place=74
-- UNMATCHED (score<80): 'GIOVINE' place=75
-- UNMATCHED (score<80): 'LUCREZI' place=76
-- UNMATCHED (score<80): 'SAOUZANET' place=77
-- Compute scores for IMEW-V2-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-FOIL-2023-2024')
);

-- Summary
-- Total results matched:   47
-- Total results unmatched: 76
