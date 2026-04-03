-- =========================================================================
-- Season 2023-2024 — V1 M FOIL — generated from FLORET-1-2023-2024.xlsx
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
    'GP1-V1-M-FOIL-2023-2024',
    'Grand Prix (runda 1)',
    'PPW',
    'FOIL', 'M', 'V1',
    '2023-01-15', 4, 'https://www.fencingtimelive.com/events/results/74D1D9E66D3D4D2A84EC3B51E2E2D387',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    11,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-FOIL-2023-2024'),
    1,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    91,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-FOIL-2023-2024'),
    2,
    'JADCZUK Wojciech'
); -- matched: JADCZUK Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    302,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-FOIL-2023-2024'),
    3,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    151,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-FOIL-2023-2024'),
    4,
    'MENCWAL Adam'
); -- matched: MENCWAL Adam (score=100.0)
-- Compute scores for GP1-V1-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-FOIL-2023-2024')
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
    'GP2-V1-M-FOIL-2023-2024',
    'Grand Prix (runda 2)',
    'PPW',
    'FOIL', 'M', 'V1',
    '2023-03-05', 7, 'https://www.fencingtimelive.com/events/results/6EE6DECD62BB480C823CB1E00796F9A1',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    145,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-FOIL-2023-2024'),
    1,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    91,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-FOIL-2023-2024'),
    2,
    'JADCZUK Wojciech'
); -- matched: JADCZUK Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    302,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-FOIL-2023-2024'),
    3,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    11,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-FOIL-2023-2024'),
    4,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    86,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-FOIL-2023-2024'),
    5,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    174,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-FOIL-2023-2024'),
    6,
    'PAKUŁA Łukasz'
); -- matched: PAKUŁA Łukasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    151,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-FOIL-2023-2024'),
    7,
    'MENCWAL Adam'
); -- matched: MENCWAL Adam (score=100.0)
-- Compute scores for GP2-V1-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-FOIL-2023-2024')
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
    'GP3-V1-M-FOIL-2023-2024',
    'Grand Prix (runda 3)',
    'PPW',
    'FOIL', 'M', 'V1',
    '2023-06-18', 5, 'https://www.fencingtimelive.com/events/results/BB532B188EE14DDCA029907190941784',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    145,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-FOIL-2023-2024'),
    1,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    91,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-FOIL-2023-2024'),
    2,
    'JADCZUK Wojciech'
); -- matched: JADCZUK Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    302,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-FOIL-2023-2024'),
    3,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    174,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-FOIL-2023-2024'),
    4,
    'PAKUŁA Łukasz'
); -- matched: PAKUŁA Łukasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    86,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-FOIL-2023-2024'),
    5,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    200,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-FOIL-2023-2024'),
    8,
    'RZESZUTKO Jakub'
); -- matched: RZESZUTKO Jakub (score=100.0)
-- Compute scores for GP3-V1-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-FOIL-2023-2024')
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
    'GP4-V1-M-FOIL-2023-2024',
    'Grand Prix (runda 4)',
    'PPW',
    'FOIL', 'M', 'V1',
    '2023-10-23', 2, 'https://www.fencingtimelive.com/events/results/03C77C820E5A4A82B4A510DA641C2474',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    67,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V1-M-FOIL-2023-2024'),
    1,
    'GINZERY Tomas'
); -- matched: GINZERY Tomas (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    145,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V1-M-FOIL-2023-2024'),
    2,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
-- Compute scores for GP4-V1-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V1-M-FOIL-2023-2024')
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
    'GP5-V1-M-FOIL-2023-2024',
    'Grand Prix (runda 5)',
    'PPW',
    'FOIL', 'M', 'V1',
    '2023-10-28', 2, 'https://www.fencingtimelive.com/events/results/0CC2C91478474AF1B0F4E8EF994F25A3',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    145,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V1-M-FOIL-2023-2024'),
    1,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    174,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V1-M-FOIL-2023-2024'),
    2,
    'PAKUŁA Łukasz'
); -- matched: PAKUŁA Łukasz (score=100.0)
-- Compute scores for GP5-V1-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V1-M-FOIL-2023-2024')
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
    'GP6-V1-M-FOIL-2023-2024',
    'Grand Prix (runda 6)',
    'PPW',
    'FOIL', 'M', 'V1',
    '2023-11-18', 3, 'https://www.fencingtimelive.com/events/results/41AE4EC0F9954F259EC24A709B66CCA2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    91,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V1-M-FOIL-2023-2024'),
    1,
    'JADCZUK Wojciech'
); -- matched: JADCZUK Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    302,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V1-M-FOIL-2023-2024'),
    2,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    145,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V1-M-FOIL-2023-2024'),
    3,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
-- Compute scores for GP6-V1-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V1-M-FOIL-2023-2024')
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
    'GP7-V1-M-FOIL-2023-2024',
    'Grand Prix (runda 7)',
    'PPW',
    'FOIL', 'M', 'V1',
    '2024-01-28', 3, 'https://www.fencingtimelive.com/events/results/15D820D5BA9A442AA26E2B4B816F091F',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    91,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-FOIL-2023-2024'),
    1,
    'JADCZUK Wojciech'
); -- matched: JADCZUK Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    145,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-FOIL-2023-2024'),
    2,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    302,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-FOIL-2023-2024'),
    3,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
-- Compute scores for GP7-V1-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-FOIL-2023-2024')
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
    'GP8-V1-M-FOIL-2023-2024',
    'Grand Prix (runda 8)',
    'PPW',
    'FOIL', 'M', 'V1',
    '2024-06-23', 3, 'https://www.fencingtimelive.com/events/results/7D2BA42AD5DE4CCF8741AE820B7BE7D7',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    145,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-FOIL-2023-2024'),
    1,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    91,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-FOIL-2023-2024'),
    2,
    'JADCZUK Wojciech'
); -- matched: JADCZUK Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    302,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-FOIL-2023-2024'),
    3,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
-- Compute scores for GP8-V1-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-FOIL-2023-2024')
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
    'MPW-V1-M-FOIL-2023-2024',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'FOIL', 'M', 'V1',
    '2024-03-02', 5, 'https://www.fencingtimelive.com/events/results/09163F1D25C3417984E126BC677640D6',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    345,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-FOIL-2023-2024'),
    1,
    'SERAFIN Błażej'
); -- matched: SERAFIN Błażej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    131,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-FOIL-2023-2024'),
    2,
    'KOZIEJOWSKI Sebastian'
); -- matched: KOZIEJOWSKI Sebastian (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    302,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-FOIL-2023-2024'),
    3,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    91,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-FOIL-2023-2024'),
    4,
    'JADCZUK Wojciech'
); -- matched: JADCZUK Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    145,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-FOIL-2023-2024'),
    5,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
-- Compute scores for MPW-V1-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-FOIL-2023-2024')
);

-- SKIP PEW1 (EVF Grand Prix 1 — Budapeszt): 0 matched fencers in DB — tournament not created

-- ---- PEW2: EVF Grand Prix 2 — Madryt (Faches-Thumesnil) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW2-2023-2024',
    'EVF Grand Prix 2 — Madryt',
    'Faches-Thumesnil',
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
    'PEW2-V1-M-FOIL-2023-2024',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'FOIL', 'M', 'V1',
    '2023-01-21', 28, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    11,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-M-FOIL-2023-2024'),
    22,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
-- Compute scores for PEW2-V1-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-M-FOIL-2023-2024')
);

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
    'PEW4-V1-M-FOIL-2023-2024',
    'EVF Grand Prix 4',
    'PEW',
    'FOIL', 'M', 'V1',
    '2023-03-18', 14, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    174,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-FOIL-2023-2024'),
    14,
    'PAKUŁA Łukasz'
); -- matched: PAKUŁA Łukasz (score=100.0)
-- Compute scores for PEW4-V1-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-FOIL-2023-2024')
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
    'PEW5-V1-M-FOIL-2023-2024',
    'EVF Grand Prix 5',
    'PEW',
    'FOIL', 'M', 'V1',
    '2023-09-16', 19, 'https://engarde-service.com/?fbclid=IwAR1q8b20973WNdhLRYbl3vdP-rPK0cilvuHZi37KFNf-Dodoicffb3YOQeM',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    302,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V1-M-FOIL-2023-2024'),
    18,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
-- Compute scores for PEW5-V1-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V1-M-FOIL-2023-2024')
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
    'PEW6-V1-M-FOIL-2023-2024',
    'EVF Grand Prix 6',
    'PEW',
    'FOIL', 'M', 'V1',
    '2023-11-11', 10, 'https://engarde-service.com/competition/aeve_esgrima/evf_madrid_2023/t_fm_1',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    302,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-FOIL-2023-2024'),
    3,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
-- Compute scores for PEW6-V1-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-FOIL-2023-2024')
);

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): N=0 — tournament had no participants

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
    'PEW8-V1-M-FOIL-2023-2024',
    'EVF Grand Prix 8 — Guildford',
    'PEW',
    'FOIL', 'M', 'V1',
    '2023-12-16', 11, 'https://www.4fence.it/FIS/Risultati/2023-12-17-16_Terni_(TR)_-_3_Prova_Circuito_Naz.le_Master/index.php?a=F&s=M&c=6&f=clafinale',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    302,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V1-M-FOIL-2023-2024'),
    6,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
-- Compute scores for PEW8-V1-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V1-M-FOIL-2023-2024')
);

-- SKIP PEW9 (EVF Grand Prix 9 — Sztokholm): N=0 — tournament had no participants

-- SKIP PEW10 (EVF Grand Prix 10 — Graz): N=0 — tournament had no participants

-- ---- PEW11: EVF Grand Prix 11 — Gdańsk (Stockholm) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW11-2023-2024',
    'EVF Grand Prix 11 — Gdańsk',
    'Stockholm',
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
    'PEW11-V1-M-FOIL-2023-2024',
    'EVF Grand Prix 11 — Gdańsk',
    'PEW',
    'FOIL', 'M', 'V1',
    '2024-02-24', 7, 'https://engarde-service.com/competition/sthlm/efv2024/fmv1',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    302,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V1-M-FOIL-2023-2024'),
    3,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
-- Compute scores for PEW11-V1-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V1-M-FOIL-2023-2024')
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
    'IMEW-V1-M-FOIL-2023-2024',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'FOIL', 'M', 'V1',
    '2023-01-01', 64, 'https://engarde-service.com/competition/e3f/efcv/menfoilv1',
    'SCORED'
);
-- UNMATCHED (score<80): 'BOULLIAT' place=1
-- UNMATCHED (score<80): 'LE QUEMENT' place=2
-- UNMATCHED (score<80): 'BAIR' place=3
-- UNMATCHED (score<80): 'TREPO' place=3
-- UNMATCHED (score<80): 'GERZANICS' place=5
-- UNMATCHED (score<80): 'SEEGER' place=6
-- UNMATCHED (score<80): 'LEROUGE' place=7
-- UNMATCHED (score<80): 'TOKOLA' place=8
-- UNMATCHED (score<80): 'STANEK' place=9
-- UNMATCHED (score<80): 'STISSI' place=10
-- UNMATCHED (score<80): 'ALI' place=11
-- UNMATCHED (score<80): 'CAZILHAC' place=12
-- UNMATCHED (score<80): 'GINZERY' place=13
-- UNMATCHED (score<80): 'GLATT' place=14
-- UNMATCHED (score<80): 'KASSNER' place=15
-- UNMATCHED (score<80): 'VON DER TRENCK' place=16
-- UNMATCHED (score<80): 'GOMES' place=17
-- UNMATCHED (score<80): 'PATARD' place=18
-- UNMATCHED (score<80): 'SAGHY' place=19
-- UNMATCHED (score<80): 'RICHIARDI' place=20
-- UNMATCHED (score<80): 'BESSET' place=21
-- UNMATCHED (score<80): 'RICHAUD' place=22
-- UNMATCHED (score<80): 'DE JOUX' place=23
-- UNMATCHED (score<80): 'ALONSO ESCOBAR' place=24
-- UNMATCHED (score<80): 'STOCKHAUSEN' place=25
-- UNMATCHED (score<80): 'ILYASHEV' place=26
-- UNMATCHED (score<80): 'BENTZ' place=27
-- UNMATCHED (score<80): 'STANBRIDGE' place=28
-- UNMATCHED (score<80): 'COPY' place=29
-- UNMATCHED (score<80): 'LUSCAN' place=30
-- UNMATCHED (score<80): 'MINET' place=31
-- UNMATCHED (score<80): 'MEVEL' place=32
-- UNMATCHED (score<80): 'MANCHERON' place=33
-- UNMATCHED (score<80): 'BESLIER' place=34
-- UNMATCHED (score<80): 'HERRANZ FERREROS' place=35
-- UNMATCHED (score<80): 'FROMBAUM' place=36
-- UNMATCHED (score<80): 'NONHEBEL' place=37
-- UNMATCHED (score<80): 'LOMBARD' place=38
-- UNMATCHED (score<80): 'VEAZEY' place=39
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    302,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-FOIL-2023-2024'),
    40,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
-- UNMATCHED (score<80): 'DELAISSE' place=41
-- UNMATCHED (score<80): 'NIZARD' place=42
-- UNMATCHED (score<80): 'BEAUVAIS' place=43
-- UNMATCHED (score<80): 'VASYLETS' place=44
-- UNMATCHED (score<80): 'TJARKS' place=45
-- UNMATCHED (score<80): 'KOZAKIVSKYI' place=46
-- UNMATCHED (score<80): 'PLECHINGER' place=47
-- UNMATCHED (score<80): 'GHITTI' place=48
-- UNMATCHED (score<80): 'KONIG' place=49
-- UNMATCHED (score<80): 'HUGO' place=50
-- UNMATCHED (score<80): 'BUHLAN' place=51
-- UNMATCHED (score<80): 'MELITA' place=52
-- UNMATCHED (score<80): 'VARADI' place=53
-- UNMATCHED (score<80): 'VERBYTSKYI' place=54
-- UNMATCHED (score<80): 'GMEREK' place=55
-- UNMATCHED (score<80): 'FARKAS' place=56
-- UNMATCHED (score<80): 'GLADIEUX' place=57
-- UNMATCHED (score<80): 'VINCENT' place=58
-- UNMATCHED (score<80): 'GIBSON' place=59
-- UNMATCHED (score<80): 'PIERRE' place=60
-- UNMATCHED (score<80): 'LUTJENS' place=61
-- UNMATCHED (score<80): 'CADET' place=62
-- UNMATCHED (score<80): 'RUFFIOT' place=63
-- UNMATCHED (score<80): 'HAFFNER' place=64
-- Compute scores for IMEW-V1-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-FOIL-2023-2024')
);

-- Summary
-- Total results matched:   42
-- Total results unmatched: 63
