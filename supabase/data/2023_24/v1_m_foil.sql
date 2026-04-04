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
    15,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-FOIL-2023-2024'),
    1,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    98,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-FOIL-2023-2024'),
    2,
    'JADCZUK Wojciech'
); -- matched: JADCZUK Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-FOIL-2023-2024'),
    3,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    173,
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
    164,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-FOIL-2023-2024'),
    1,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    98,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-FOIL-2023-2024'),
    2,
    'JADCZUK Wojciech'
); -- matched: JADCZUK Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-FOIL-2023-2024'),
    3,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    15,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-FOIL-2023-2024'),
    4,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-FOIL-2023-2024'),
    5,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    201,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-FOIL-2023-2024'),
    6,
    'PAKUŁA Łukasz'
); -- matched: PAKUŁA Łukasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    173,
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
    164,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-FOIL-2023-2024'),
    1,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    98,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-FOIL-2023-2024'),
    2,
    'JADCZUK Wojciech'
); -- matched: JADCZUK Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-FOIL-2023-2024'),
    3,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    201,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-FOIL-2023-2024'),
    4,
    'PAKUŁA Łukasz'
); -- matched: PAKUŁA Łukasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-FOIL-2023-2024'),
    5,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    232,
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
    70,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V1-M-FOIL-2023-2024'),
    1,
    'GINZERY Tomas'
); -- matched: GINZERY Tomas (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    164,
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
    164,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V1-M-FOIL-2023-2024'),
    1,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    201,
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
    98,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V1-M-FOIL-2023-2024'),
    1,
    'JADCZUK Wojciech'
); -- matched: JADCZUK Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V1-M-FOIL-2023-2024'),
    2,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    164,
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
    98,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-FOIL-2023-2024'),
    1,
    'JADCZUK Wojciech'
); -- matched: JADCZUK Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    164,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-FOIL-2023-2024'),
    2,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-FOIL-2023-2024'),
    3,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
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
    164,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-FOIL-2023-2024'),
    1,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    98,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-FOIL-2023-2024'),
    2,
    'JADCZUK Wojciech'
); -- matched: JADCZUK Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-FOIL-2023-2024'),
    3,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
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
    240,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-FOIL-2023-2024'),
    1,
    'SERAFIN Błażej'
); -- matched: SERAFIN Błażej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    138,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-FOIL-2023-2024'),
    2,
    'KOZIEJOWSKI Sebastian'
); -- matched: KOZIEJOWSKI Sebastian (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-FOIL-2023-2024'),
    3,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    98,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-FOIL-2023-2024'),
    4,
    'JADCZUK Wojciech'
); -- matched: JADCZUK Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    164,
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
    15,
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
    201,
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
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V1-M-FOIL-2023-2024'),
    18,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
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
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-FOIL-2023-2024'),
    3,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
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
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V1-M-FOIL-2023-2024'),
    6,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
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
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V1-M-FOIL-2023-2024'),
    3,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
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
-- SKIPPED (international, no master data): 'BOULLIAT' place=1
-- SKIPPED (international, no master data): 'LE QUEMENT' place=2
-- SKIPPED (international, no master data): 'BAIR' place=3
-- SKIPPED (international, no master data): 'TREPO' place=3
-- SKIPPED (international, no master data): 'GERZANICS' place=5
-- SKIPPED (international, no master data): 'SEEGER' place=6
-- SKIPPED (international, no master data): 'LEROUGE' place=7
-- SKIPPED (international, no master data): 'TOKOLA' place=8
-- SKIPPED (international, no master data): 'STANEK' place=9
-- SKIPPED (international, no master data): 'STISSI' place=10
-- SKIPPED (international, no master data): 'ALI' place=11
-- SKIPPED (international, no master data): 'CAZILHAC' place=12
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    70,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-FOIL-2023-2024'),
    13,
    'GINZERY'
); -- matched: GINZERY Tomas (score=70.0)
-- SKIPPED (international, no master data): 'GLATT' place=14
-- SKIPPED (international, no master data): 'KASSNER' place=15
-- SKIPPED (international, no master data): 'VON DER TRENCK' place=16
-- SKIPPED (international, no master data): 'GOMES' place=17
-- SKIPPED (international, no master data): 'PATARD' place=18
-- SKIPPED (international, no master data): 'SAGHY' place=19
-- SKIPPED (international, no master data): 'RICHIARDI' place=20
-- SKIPPED (international, no master data): 'BESSET' place=21
-- SKIPPED (international, no master data): 'RICHAUD' place=22
-- SKIPPED (international, no master data): 'DE JOUX' place=23
-- SKIPPED (international, no master data): 'ALONSO ESCOBAR' place=24
-- SKIPPED (international, no master data): 'STOCKHAUSEN' place=25
-- SKIPPED (international, no master data): 'ILYASHEV' place=26
-- SKIPPED (international, no master data): 'BENTZ' place=27
-- SKIPPED (international, no master data): 'STANBRIDGE' place=28
-- SKIPPED (international, no master data): 'COPY' place=29
-- SKIPPED (international, no master data): 'LUSCAN' place=30
-- SKIPPED (international, no master data): 'MINET' place=31
-- SKIPPED (international, no master data): 'MEVEL' place=32
-- SKIPPED (international, no master data): 'MANCHERON' place=33
-- SKIPPED (international, no master data): 'BESLIER' place=34
-- SKIPPED (international, no master data): 'HERRANZ FERREROS' place=35
-- SKIPPED (international, no master data): 'FROMBAUM' place=36
-- SKIPPED (international, no master data): 'NONHEBEL' place=37
-- SKIPPED (international, no master data): 'LOMBARD' place=38
-- SKIPPED (international, no master data): 'VEAZEY' place=39
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-FOIL-2023-2024'),
    40,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
-- SKIPPED (international, no master data): 'DELAISSE' place=41
-- SKIPPED (international, no master data): 'NIZARD' place=42
-- SKIPPED (international, no master data): 'BEAUVAIS' place=43
-- SKIPPED (international, no master data): 'VASYLETS' place=44
-- SKIPPED (international, no master data): 'TJARKS' place=45
-- SKIPPED (international, no master data): 'KOZAKIVSKYI' place=46
-- SKIPPED (international, no master data): 'PLECHINGER' place=47
-- SKIPPED (international, no master data): 'GHITTI' place=48
-- SKIPPED (international, no master data): 'KONIG' place=49
-- SKIPPED (international, no master data): 'HUGO' place=50
-- SKIPPED (international, no master data): 'BUHLAN' place=51
-- SKIPPED (international, no master data): 'MELITA' place=52
-- SKIPPED (international, no master data): 'VARADI' place=53
-- SKIPPED (international, no master data): 'VERBYTSKYI' place=54
-- SKIPPED (international, no master data): 'GMEREK' place=55
-- SKIPPED (international, no master data): 'FARKAS' place=56
-- SKIPPED (international, no master data): 'GLADIEUX' place=57
-- SKIPPED (international, no master data): 'VINCENT' place=58
-- SKIPPED (international, no master data): 'GIBSON' place=59
-- SKIPPED (international, no master data): 'PIERRE' place=60
-- SKIPPED (international, no master data): 'LUTJENS' place=61
-- SKIPPED (international, no master data): 'CADET' place=62
-- SKIPPED (international, no master data): 'RUFFIOT' place=63
-- SKIPPED (international, no master data): 'HAFFNER' place=64
-- Compute scores for IMEW-V1-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-FOIL-2023-2024')
);

-- Summary
-- Total results matched:   43
-- Total results unmatched: 62
-- Total auto-created:      0
