-- =========================================================================
-- Season 2023-2024 — V4 M EPEE — generated from SZPADA-4-2023-2024.xlsx
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
    'GP1-V4-M-EPEE-2023-2024',
    'Grand Prix (runda 1)',
    'PPW',
    'EPEE', 'M', 'V4',
    '2023-01-14', 3, 'https://www.fencingtimelive.com/events/results/97D0DD2B597A430EA39683D4F58928CB',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    1,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V4-M-EPEE-2023-2024'),
    1,
    'ADAMCZEWSKI Wojciech'
); -- matched: ADAMCZEWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    305,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V4-M-EPEE-2023-2024'),
    2,
    'WYLĘGAŁA Jerzy'
); -- matched: WYLĘGAŁA Jerzy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    24,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V4-M-EPEE-2023-2024'),
    3,
    'BORKOWSKI Andrzej'
); -- matched: BORKOWSKI Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V4-M-EPEE-2023-2024'),
    5,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
-- Compute scores for GP1-V4-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V4-M-EPEE-2023-2024')
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
    'GP2-V4-M-EPEE-2023-2024',
    'Grand Prix (runda 2)',
    'PPW',
    'EPEE', 'M', 'V4',
    '2023-04-03', 4, 'https://www.fencingtimelive.com/events/results/E1BC2C09C82E43E09BA7EED8E10BD288',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    1,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V4-M-EPEE-2023-2024'),
    1,
    'ADAMCZEWSKI Wojciech'
); -- matched: ADAMCZEWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    24,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V4-M-EPEE-2023-2024'),
    2,
    'BORKOWSKI Andrzej'
); -- matched: BORKOWSKI Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    305,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V4-M-EPEE-2023-2024'),
    3,
    'WYLĘGAŁA Jerzy'
); -- matched: WYLĘGAŁA Jerzy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V4-M-EPEE-2023-2024'),
    4,
    'FURMANIAK Andrzej'
); -- matched: FURMANIAK Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V4-M-EPEE-2023-2024'),
    5,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
-- Compute scores for GP2-V4-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V4-M-EPEE-2023-2024')
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
    'GP3-V4-M-EPEE-2023-2024',
    'Grand Prix (runda 3)',
    'PPW',
    'EPEE', 'M', 'V4',
    '2023-06-17', 4, 'https://www.fencingtimelive.com/events/results/FA5B4F930DEB457C92D3D0FD4FCCE84C',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    282,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V4-M-EPEE-2023-2024'),
    1,
    'UIJTING Henh'
); -- matched: UIJTING Henh (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    24,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V4-M-EPEE-2023-2024'),
    2,
    'BORKOWSKI Andrzej'
); -- matched: BORKOWSKI Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    239,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V4-M-EPEE-2023-2024'),
    3,
    'SCHOLZ Jurgen'
); -- matched: SCHOLZ Jurgen (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V4-M-EPEE-2023-2024'),
    4,
    'FURMANIAK Andrzej'
); -- matched: FURMANIAK Andrzej (score=100.0)
-- Compute scores for GP3-V4-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V4-M-EPEE-2023-2024')
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
    'GP4-V4-M-EPEE-2023-2024',
    'Grand Prix (runda 4)',
    'PPW',
    'EPEE', 'M', 'V4',
    '2023-10-23', 4, 'https://www.fencingtimelive.com/tournaments/eventSchedule/4E8236D593B64434A9EE99D9B5F7E65F',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    24,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V4-M-EPEE-2023-2024'),
    1,
    'BORKOWSKI Andrzej'
); -- matched: BORKOWSKI Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V4-M-EPEE-2023-2024'),
    2,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    1,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V4-M-EPEE-2023-2024'),
    3,
    'ADAMCZEWSKI Wojciech'
); -- matched: ADAMCZEWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    190,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V4-M-EPEE-2023-2024'),
    4,
    'NOWAKOWSKI Andrzej'
); -- matched: NOWAKOWSKI Andrzej (score=100.0)
-- Compute scores for GP4-V4-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V4-M-EPEE-2023-2024')
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
    'GP5-V4-M-EPEE-2023-2024',
    'Grand Prix (runda 5)',
    'PPW',
    'EPEE', 'M', 'V4',
    '2023-10-28', 4, 'https://www.fencingtimelive.com/events/results/8552A7B623A1413D915EEC858B14525A',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    24,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V4-M-EPEE-2023-2024'),
    1,
    'BORKOWSKI Andrzej'
); -- matched: BORKOWSKI Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    1,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V4-M-EPEE-2023-2024'),
    2,
    'ADAMCZEWSKI Wojciech'
); -- matched: ADAMCZEWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V4-M-EPEE-2023-2024'),
    3,
    'FURMANIAK Andrzej'
); -- matched: FURMANIAK Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    190,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V4-M-EPEE-2023-2024'),
    4,
    'NOWAKOWSKI Andrzej'
); -- matched: NOWAKOWSKI Andrzej (score=100.0)
-- Compute scores for GP5-V4-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V4-M-EPEE-2023-2024')
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
    'GP6-V4-M-EPEE-2023-2024',
    'Grand Prix (runda 6)',
    'PPW',
    'EPEE', 'M', 'V4',
    '2023-11-18', 4, 'https://www.fencingtimelive.com/events/results/F988164D07A8447C8265BA625F42A0BD',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V4-M-EPEE-2023-2024'),
    1,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    24,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V4-M-EPEE-2023-2024'),
    2,
    'BORKOWSKI Andrzej'
); -- matched: BORKOWSKI Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V4-M-EPEE-2023-2024'),
    3,
    'FURMANIAK Andrzej'
); -- matched: FURMANIAK Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    190,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V4-M-EPEE-2023-2024'),
    4,
    'NOWAKOWSKI Andrzej'
); -- matched: NOWAKOWSKI Andrzej (score=100.0)
-- Compute scores for GP6-V4-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V4-M-EPEE-2023-2024')
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
    'GP7-V4-M-EPEE-2023-2024',
    'Grand Prix (runda 7)',
    'PPW',
    'EPEE', 'M', 'V4',
    '2024-01-27', 3, 'https://www.fencingtimelive.com/events/results/AD8A3C03500A45CA84D2642F0BC6CA2D',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    1,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V4-M-EPEE-2023-2024'),
    1,
    'ADAMCZEWSKI Wojciech'
); -- matched: ADAMCZEWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V4-M-EPEE-2023-2024'),
    2,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V4-M-EPEE-2023-2024'),
    3,
    'FURMANIAK Andrzej'
); -- matched: FURMANIAK Andrzej (score=100.0)
-- Compute scores for GP7-V4-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V4-M-EPEE-2023-2024')
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
    'GP8-V4-M-EPEE-2023-2024',
    'Grand Prix (runda 8)',
    'PPW',
    'EPEE', 'M', 'V4',
    '2024-06-22', 1, 'https://www.fencingtimelive.com/events/results/E12EAF17078E464DBF888ABF11E48D7A',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    1,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V4-M-EPEE-2023-2024'),
    1,
    'ADAMCZEWSKI Wojciech'
); -- matched: ADAMCZEWSKI Wojciech (score=100.0)
-- Compute scores for GP8-V4-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V4-M-EPEE-2023-2024')
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
    'MPW-V4-M-EPEE-2023-2024',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'EPEE', 'M', 'V4',
    '2024-03-02', 4, 'https://www.fencingtimelive.com/events/results/59F66960EF884184AD8C92CC1EE55764',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    229,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-EPEE-2023-2024'),
    1,
    'RUTECKI Bogdan'
); -- matched: RUTECKI Bogdan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    1,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-EPEE-2023-2024'),
    2,
    'ADAMCZEWSKI Wojciech'
); -- matched: ADAMCZEWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-EPEE-2023-2024'),
    3,
    'FURMANIAK Andrzej'
); -- matched: FURMANIAK Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-EPEE-2023-2024'),
    4,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
-- Compute scores for MPW-V4-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-EPEE-2023-2024')
);

-- SKIP PEW1 (EVF Grand Prix 1 — Budapeszt): N=0 — tournament had no participants

-- SKIP PEW2 (EVF Grand Prix 2 — Madryt): N=0 — tournament had no participants

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
    'PEW3-V4-M-EPEE-2023-2024',
    'EVF Grand Prix 3',
    'PEW',
    'EPEE', 'M', 'V4',
    '2023-04-15', 11, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    229,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V4-M-EPEE-2023-2024'),
    3,
    'RUTECKI Bogdan'
); -- matched: RUTECKI Bogdan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    1,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V4-M-EPEE-2023-2024'),
    7,
    'ADAMCZEWSKI Wojciech'
); -- matched: ADAMCZEWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    24,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V4-M-EPEE-2023-2024'),
    8,
    'BORKOWSKI Andrzej'
); -- matched: BORKOWSKI Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V4-M-EPEE-2023-2024'),
    9,
    'FURMANIAK Andrzej'
); -- matched: FURMANIAK Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    305,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V4-M-EPEE-2023-2024'),
    11,
    'WYLĘGAŁA Jerzy'
); -- matched: WYLĘGAŁA Jerzy (score=100.0)
-- Compute scores for PEW3-V4-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V4-M-EPEE-2023-2024')
);

-- SKIP PEW4 (EVF Grand Prix 4): N=0 — tournament had no participants

-- SKIP PEW5 (EVF Grand Prix 5): N=0 — tournament had no participants

-- SKIP PEW6 (EVF Grand Prix 6): N=0 — tournament had no participants

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): N=0 — tournament had no participants

-- SKIP PEW8 (EVF Grand Prix 8 — Guildford): N=0 — tournament had no participants

-- SKIP PEW9 (EVF Grand Prix 9 — Sztokholm): N=0 — tournament had no participants

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
    'PEW11-V4-M-EPEE-2023-2024',
    'EVF Grand Prix 11 — Gdańsk',
    'PEW',
    'EPEE', 'M', 'V4',
    '2024-04-06', 6, 'https://www.veteransfencing.eu/fencing/rankings/',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    229,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V4-M-EPEE-2023-2024'),
    1,
    'RUTECKI Bogdan'
); -- matched: RUTECKI Bogdan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    1,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V4-M-EPEE-2023-2024'),
    3,
    'ADAMCZEWSKI Wojciech'
); -- matched: ADAMCZEWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V4-M-EPEE-2023-2024'),
    3,
    'FURMANIAK Andrzej'
); -- matched: FURMANIAK Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V4-M-EPEE-2023-2024'),
    5,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
-- Compute scores for PEW11-V4-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V4-M-EPEE-2023-2024')
);

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
    'IMEW-V4-M-EPEE-2023-2024',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'EPEE', 'M', 'V4',
    '2023-01-01', 83, 'https://engarde-service.com/competition/e3f/efcv/menepeev4',
    'SCORED'
);
-- SKIPPED (international, no master data): 'IMREH' place=1
-- SKIPPED (international, no master data): 'SOKOLOV' place=2
-- SKIPPED (international, no master data): 'DAMAS FLORES' place=3
-- SKIPPED (international, no master data): 'DELACOUR' place=3
-- SKIPPED (international, no master data): 'NOEL' place=5
-- SKIPPED (international, no master data): 'PFULG' place=6
-- SKIPPED (international, no master data): 'SCHOELSS' place=7
-- SKIPPED (international, no master data): 'OSWALD' place=8
-- SKIPPED (international, no master data): 'MARINO' place=9
-- SKIPPED (international, no master data): 'SCHWARTZ' place=10
-- SKIPPED (international, no master data): 'BRADBURY' place=11
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    282,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V4-M-EPEE-2023-2024'),
    12,
    'UIJTING'
); -- matched: UIJTING Henh (score=73.6842105263158)
-- SKIPPED (international, no master data): 'BEEKHUIZEN' place=13
-- SKIPPED (international, no master data): 'KUEHN' place=14
-- SKIPPED (international, no master data): 'SUCHANEK' place=15
-- SKIPPED (international, no master data): 'SCHOLZ' place=16
-- SKIPPED (international, no master data): 'RINGEISSEN' place=17
-- SKIPPED (international, no master data): 'VILLEDIEU' place=18
-- SKIPPED (international, no master data): 'DUCHENE' place=19
-- SKIPPED (international, no master data): 'OSBALDESTON' place=20
-- SKIPPED (international, no master data): 'MOREL MARECHAL' place=21
-- SKIPPED (international, no master data): 'HENSEL' place=22
-- SKIPPED (international, no master data): 'VALAR' place=23
-- SKIPPED (international, no master data): 'AMANRICH' place=24
-- SKIPPED (international, no master data): 'BREEDVELT' place=25
-- SKIPPED (international, no master data): 'VON BRANDIS' place=26
-- SKIPPED (international, no master data): 'BROWN' place=27
-- SKIPPED (international, no master data): 'CAUSTON' place=28
-- SKIPPED (international, no master data): 'LORAUX' place=29
-- SKIPPED (international, no master data): 'KUCERA' place=30
-- SKIPPED (international, no master data): 'MENCK' place=31
-- SKIPPED (international, no master data): 'SVENSSON' place=32
-- SKIPPED (international, no master data): 'PASMANS' place=33
-- SKIPPED (international, no master data): 'REETMEYER' place=34
-- SKIPPED (international, no master data): 'SCHIOCHET' place=35
-- SKIPPED (international, no master data): 'LIPTAK' place=36
-- SKIPPED (international, no master data): 'MION' place=37
-- SKIPPED (international, no master data): 'RYNES' place=38
-- SKIPPED (international, no master data): 'MERKY' place=39
-- SKIPPED (international, no master data): 'LEGROS' place=40
-- SKIPPED (international, no master data): 'FERTE' place=41
-- SKIPPED (international, no master data): 'BERHAULT MERCIER' place=42
-- SKIPPED (international, no master data): 'KOLLAR' place=43
-- SKIPPED (international, no master data): 'GUIGOT' place=44
-- SKIPPED (international, no master data): 'HERVE' place=45
-- SKIPPED (international, no master data): 'VAN DER GRINTEN' place=46
-- SKIPPED (international, no master data): 'RAGG' place=47
-- SKIPPED (international, no master data): 'VARNAY' place=48
-- SKIPPED (international, no master data): 'PFISTER' place=49
-- SKIPPED (international, no master data): 'PRECHTL' place=50
-- SKIPPED (international, no master data): 'SHAPIRA' place=51
-- SKIPPED (international, no master data): 'HEINZE' place=52
-- SKIPPED (international, no master data): 'PHELPS' place=53
-- SKIPPED (international, no master data): 'DE WIJN' place=54
-- SKIPPED (international, no master data): 'DUFAU' place=55
-- SKIPPED (international, no master data): 'MARANGES' place=56
-- SKIPPED (international, no master data): 'PRETOT' place=57
-- SKIPPED (international, no master data): 'RIFFONNEAU' place=58
-- SKIPPED (international, no master data): 'FACINA' place=59
-- SKIPPED (international, no master data): 'KACHUR' place=60
-- SKIPPED (international, no master data): 'NIZARD' place=61
-- SKIPPED (international, no master data): 'BLIN' place=62
-- SKIPPED (international, no master data): 'COUTROT' place=63
-- SKIPPED (international, no master data): 'CUNEO' place=64
-- SKIPPED (international, no master data): 'PAUL' place=65
-- SKIPPED (international, no master data): 'HARDEN' place=66
-- SKIPPED (international, no master data): 'GELLER' place=67
-- SKIPPED (international, no master data): 'VITSAS' place=68
-- SKIPPED (international, no master data): 'TOROK' place=69
-- SKIPPED (international, no master data): 'LEGALL' place=70
-- SKIPPED (international, no master data): 'PLATRET' place=71
-- SKIPPED (international, no master data): 'WOLTERSDORF' place=72
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    161,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V4-M-EPEE-2023-2024'),
    73,
    'LYNCH'
); -- matched: LYNCH Pat (score=71.42857142857143)
-- SKIPPED (international, no master data): 'AUSSEDAT' place=74
-- SKIPPED (international, no master data): 'BENEDEK' place=75
-- SKIPPED (international, no master data): 'VAN AGTMAEL' place=76
-- SKIPPED (international, no master data): 'VISSER' place=77
-- SKIPPED (international, no master data): 'MILLET' place=78
-- SKIPPED (international, no master data): 'GINESTET' place=79
-- SKIPPED (international, no master data): 'MOREIRA' place=80
-- SKIPPED (international, no master data): 'SCHOENSIEGEL' place=81
-- SKIPPED (international, no master data): 'FONSECA SANTOS' place=82
-- SKIPPED (international, no master data): 'BAIER' place=83
-- Compute scores for IMEW-V4-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V4-M-EPEE-2023-2024')
);

-- Summary
-- Total results matched:   44
-- Total results unmatched: 81
-- Total auto-created:      0
