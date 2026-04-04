-- =========================================================================
-- Season 2023-2024 — V0 M EPEE — generated from SZPADA-0-2023-2024.xlsx
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
    'GP1-V0-M-EPEE-2023-2024',
    'Grand Prix (runda 1)',
    'PPW',
    'EPEE', 'M', 'V0',
    '2023-01-14', 12, 'https://www.fencingtimelive.com/events/results/22488366AC2E4DA9A7A7828054EB230C',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    132,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-M-EPEE-2023-2024'),
    1,
    'KRAMARZ Konrad'
); -- matched: KRAMARZ Konrad (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    17,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-M-EPEE-2023-2024'),
    2,
    'BOBUSIA Jarosław'
); -- matched: BOBUSIA Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    125,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-M-EPEE-2023-2024'),
    3,
    'KOWALCZYK Piotr'
); -- matched: KOWALCZYK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    73,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-M-EPEE-2023-2024'),
    4,
    'GRIPAS Artiom'
); -- matched: GRIPAS Artiom (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    164,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-M-EPEE-2023-2024'),
    5,
    'MORDEL Adam'
); -- matched: MORDEL Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    90,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-M-EPEE-2023-2024'),
    6,
    'JASIELCZUK Igor'
); -- matched: JASIELCZUK Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    68,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-M-EPEE-2023-2024'),
    7,
    'GRABOWSKI Alan'
); -- matched: GRABOWSKI Alan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    70,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-M-EPEE-2023-2024'),
    8,
    'GRABOWSKI Sebastian'
); -- matched: GRABOWSKI Sebastian (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    115,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-M-EPEE-2023-2024'),
    9,
    'KORNAŚ Jarosław'
); -- matched: KORNAŚ Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    49,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-M-EPEE-2023-2024'),
    10,
    'DZIUBIŃSKI Mateusz'
); -- matched: DZIUBIŃSKI Mateusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    36,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-M-EPEE-2023-2024'),
    11,
    'ĆWIORO Tomasz'
); -- matched: ĆWIORO Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    253,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-M-EPEE-2023-2024'),
    12,
    'WALCZEWSKI Konrad'
); -- matched: WALCZEWSKI Konrad (score=100.0)
-- Compute scores for GP1-V0-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-M-EPEE-2023-2024')
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
    'GP2-V0-M-EPEE-2023-2024',
    'Grand Prix (runda 2)',
    'PPW',
    'EPEE', 'M', 'V0',
    '2023-04-03', 8, 'https://www.fencingtimelive.com/events/results/3B5390E064E942818772BB1D5D481C1B',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    132,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V0-M-EPEE-2023-2024'),
    1,
    'KRAMARZ Konrad'
); -- matched: KRAMARZ Konrad (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    68,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V0-M-EPEE-2023-2024'),
    2,
    'GRABOWSKI Alan'
); -- matched: GRABOWSKI Alan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    73,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V0-M-EPEE-2023-2024'),
    3,
    'GRIPAS Artiom'
); -- matched: GRIPAS Artiom (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    17,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V0-M-EPEE-2023-2024'),
    4,
    'BOBUSIA Jarosław'
); -- matched: BOBUSIA Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    125,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V0-M-EPEE-2023-2024'),
    5,
    'KOWALCZYK Piotr'
); -- matched: KOWALCZYK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    70,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V0-M-EPEE-2023-2024'),
    6,
    'GRABOWSKI Sebastian'
); -- matched: GRABOWSKI Sebastian (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    49,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V0-M-EPEE-2023-2024'),
    7,
    'DZIUBIŃSKI Mateusz'
); -- matched: DZIUBIŃSKI Mateusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    253,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V0-M-EPEE-2023-2024'),
    8,
    'WALCZEWSKI Konrad'
); -- matched: WALCZEWSKI Konrad (score=100.0)
-- Compute scores for GP2-V0-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V0-M-EPEE-2023-2024')
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
    'GP3-V0-M-EPEE-2023-2024',
    'Grand Prix (runda 3)',
    'PPW',
    'EPEE', 'M', 'V0',
    '2023-06-17', 8, 'https://www.fencingtimelive.com/events/results/CA70FB1D4D6F4129B151CAD52058E364',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    125,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V0-M-EPEE-2023-2024'),
    1,
    'KOWALCZYK Piotr'
); -- matched: KOWALCZYK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    17,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V0-M-EPEE-2023-2024'),
    2,
    'BOBUSIA Jarosław'
); -- matched: BOBUSIA Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    73,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V0-M-EPEE-2023-2024'),
    3,
    'GRIPAS Artiom'
); -- matched: GRIPAS Artiom (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    68,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V0-M-EPEE-2023-2024'),
    4,
    'GRABOWSKI Alan'
); -- matched: GRABOWSKI Alan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    90,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V0-M-EPEE-2023-2024'),
    6,
    'JASIELCZUK Igor'
); -- matched: JASIELCZUK Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    253,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V0-M-EPEE-2023-2024'),
    7,
    'WALCZEWSKI Konrad'
); -- matched: WALCZEWSKI Konrad (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    49,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V0-M-EPEE-2023-2024'),
    8,
    'DZIUBIŃSKI Mateusz'
); -- matched: DZIUBIŃSKI Mateusz (score=100.0)
-- Compute scores for GP3-V0-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V0-M-EPEE-2023-2024')
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
    'GP4-V0-M-EPEE-2023-2024',
    'Grand Prix (runda 4)',
    'PPW',
    'EPEE', 'M', 'V0',
    '2023-10-23', 9, 'https://www.fencingtimelive.com/events/results/B3E1CEF3290A4D49A0828690F67EC285',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    17,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V0-M-EPEE-2023-2024'),
    2,
    'BOBUSIA Jarosław'
); -- matched: BOBUSIA Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    132,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V0-M-EPEE-2023-2024'),
    3,
    'KRAMARZ Konrad'
); -- matched: KRAMARZ Konrad (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    68,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V0-M-EPEE-2023-2024'),
    4,
    'GRABOWSKI Alan'
); -- matched: GRABOWSKI Alan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    90,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V0-M-EPEE-2023-2024'),
    5,
    'JASIELCZUK Igor'
); -- matched: JASIELCZUK Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    253,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V0-M-EPEE-2023-2024'),
    6,
    'WALCZEWSKI Konrad'
); -- matched: WALCZEWSKI Konrad (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    36,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V0-M-EPEE-2023-2024'),
    8,
    'ĆWIORO Tomasz'
); -- matched: ĆWIORO Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    49,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V0-M-EPEE-2023-2024'),
    9,
    'DZIUBIŃSKI Mateusz'
); -- matched: DZIUBIŃSKI Mateusz (score=100.0)
-- Compute scores for GP4-V0-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V0-M-EPEE-2023-2024')
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
    'GP5-V0-M-EPEE-2023-2024',
    'Grand Prix (runda 5)',
    'PPW',
    'EPEE', 'M', 'V0',
    '2023-10-28', 5, 'https://www.fencingtimelive.com/events/results/B918B8F1FB654D7DB6BAB0B9F80A3897',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    17,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V0-M-EPEE-2023-2024'),
    1,
    'BOBUSIA Jarosław'
); -- matched: BOBUSIA Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    48,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V0-M-EPEE-2023-2024'),
    2,
    'DYNAREK Aleksander'
); -- matched: DYNAREK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    125,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V0-M-EPEE-2023-2024'),
    3,
    'KOWALCZYK Piotr'
); -- matched: KOWALCZYK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    49,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V0-M-EPEE-2023-2024'),
    4,
    'DZIUBIŃSKI Mateusz'
); -- matched: DZIUBIŃSKI Mateusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    253,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V0-M-EPEE-2023-2024'),
    5,
    'WALCZEWSKI Konrad'
); -- matched: WALCZEWSKI Konrad (score=100.0)
-- Compute scores for GP5-V0-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V0-M-EPEE-2023-2024')
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
    'GP6-V0-M-EPEE-2023-2024',
    'Grand Prix (runda 6)',
    'PPW',
    'EPEE', 'M', 'V0',
    '2023-11-18', 6, 'https://www.fencingtimelive.com/events/results/3E0BABDBE9FB44AC9E176168A689DBE0',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    115,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V0-M-EPEE-2023-2024'),
    1,
    'KORNAŚ Jarosław'
); -- matched: KORNAŚ Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    54,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V0-M-EPEE-2023-2024'),
    2,
    'FRAŚ Felix'
); -- matched: FRAŚ Felix (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    17,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V0-M-EPEE-2023-2024'),
    3,
    'BOBUSIA Jarosław'
); -- matched: BOBUSIA Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    49,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V0-M-EPEE-2023-2024'),
    4,
    'DZIUBIŃSKI Mateusz'
); -- matched: DZIUBIŃSKI Mateusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    90,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V0-M-EPEE-2023-2024'),
    5,
    'JASIELCZUK Igor'
); -- matched: JASIELCZUK Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    36,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V0-M-EPEE-2023-2024'),
    6,
    'ĆWIORO Tomasz'
); -- matched: ĆWIORO Tomasz (score=100.0)
-- Compute scores for GP6-V0-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V0-M-EPEE-2023-2024')
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
    'GP7-V0-M-EPEE-2023-2024',
    'Grand Prix (runda 7)',
    'PPW',
    'EPEE', 'M', 'V0',
    '2024-01-27', 6, 'https://www.fencingtimelive.com/events/results/15D820D5BA9A442AA26E2B4B816F091F',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    17,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V0-M-EPEE-2023-2024'),
    1,
    'BOBUSIA Jarosław'
); -- matched: BOBUSIA Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    125,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V0-M-EPEE-2023-2024'),
    2,
    'KOWALCZYK Piotr'
); -- matched: KOWALCZYK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    90,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V0-M-EPEE-2023-2024'),
    3,
    'JASIELCZUK Igor'
); -- matched: JASIELCZUK Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    132,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V0-M-EPEE-2023-2024'),
    4,
    'KRAMARZ Konrad'
); -- matched: KRAMARZ Konrad (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    49,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V0-M-EPEE-2023-2024'),
    5,
    'DZIUBIŃSKI Mateusz'
); -- matched: DZIUBIŃSKI Mateusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    36,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V0-M-EPEE-2023-2024'),
    6,
    'ĆWIORO Tomasz'
); -- matched: ĆWIORO Tomasz (score=100.0)
-- Compute scores for GP7-V0-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V0-M-EPEE-2023-2024')
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
    'GP8-V0-M-EPEE-2023-2024',
    'Grand Prix (runda 8)',
    'PPW',
    'EPEE', 'M', 'V0',
    '2024-06-22', 9, 'https://www.fencingtimelive.com/events/results/15D820D5BA9A442AA26E2B4B816F091F',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    90,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V0-M-EPEE-2023-2024'),
    2,
    'JASIELCZUK Igor'
); -- matched: JASIELCZUK Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    17,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V0-M-EPEE-2023-2024'),
    3,
    'BOBUSIA Jarosław'
); -- matched: BOBUSIA Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    135,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V0-M-EPEE-2023-2024'),
    4,
    'KRUJALSKIS Gotfridas'
); -- matched: KRUJALSKIS Gotfridas (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    253,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V0-M-EPEE-2023-2024'),
    5,
    'WALCZEWSKI Konrad'
); -- matched: WALCZEWSKI Konrad (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    68,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V0-M-EPEE-2023-2024'),
    6,
    'GRABOWSKI Alan'
); -- matched: GRABOWSKI Alan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    49,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V0-M-EPEE-2023-2024'),
    7,
    'DZIUBIŃSKI Mateusz'
); -- matched: DZIUBIŃSKI Mateusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    8,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V0-M-EPEE-2023-2024'),
    8,
    'AUGUSTYN Kajetan'
); -- matched: AUGUSTYN Kajetan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    36,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V0-M-EPEE-2023-2024'),
    9,
    'ĆWIORO Tomasz'
); -- matched: ĆWIORO Tomasz (score=100.0)
-- Compute scores for GP8-V0-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V0-M-EPEE-2023-2024')
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
    'MPW-V0-M-EPEE-2023-2024',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'EPEE', 'M', 'V0',
    '2024-03-02', 10, 'https://www.fencingtimelive.com/events/results/F3430EF7B4C74522B2B654191957DA6C',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    54,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-EPEE-2023-2024'),
    1,
    'FRAŚ Felix'
); -- matched: FRAŚ Felix (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    132,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-EPEE-2023-2024'),
    2,
    'KRAMARZ Konrad'
); -- matched: KRAMARZ Konrad (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    125,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-EPEE-2023-2024'),
    3,
    'KOWALCZYK Piotr'
); -- matched: KOWALCZYK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    115,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-EPEE-2023-2024'),
    4,
    'KORNAŚ Jarosław'
); -- matched: KORNAŚ Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    17,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-EPEE-2023-2024'),
    5,
    'BOBUSIA Jarosław'
); -- matched: BOBUSIA Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    118,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-EPEE-2023-2024'),
    6,
    'KORYGA Bartłomiej'
); -- matched: KORYGA Bartłomiej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    49,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-EPEE-2023-2024'),
    7,
    'DZIUBIŃSKI Mateusz'
); -- matched: DZIUBIŃSKI Mateusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    255,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-EPEE-2023-2024'),
    8,
    'WALESIAK Stanisław'
); -- matched: WALESIAK Stanisław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    253,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-EPEE-2023-2024'),
    9,
    'WALCZEWSKI Konrad'
); -- matched: WALCZEWSKI Konrad (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    184,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-EPEE-2023-2024'),
    10,
    'PAWŁOWSKI Łukasz'
); -- matched: PAWŁOWSKI Łukasz (score=100.0)
-- Compute scores for MPW-V0-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-EPEE-2023-2024')
);

-- Summary
-- Total results matched:   73
-- Total results unmatched: 0
