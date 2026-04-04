-- =========================================================================
-- Season 2023-2024 — V0 M FOIL — generated from FLORET-0-2023-2024.xlsx
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
    'GP1-V0-M-FOIL-2023-2024',
    'Grand Prix (runda 1)',
    'PPW',
    'FOIL', 'M', 'V0',
    '2023-01-15', 1, 'https://www.fencingtimelive.com/events/results/74D1D9E66D3D4D2A84EC3B51E2E2D387',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    2,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-M-FOIL-2023-2024'),
    1,
    'ADAMCZYK Grzegorz'
); -- matched: ADAMCZYK Grzegorz (score=100.0)
-- Compute scores for GP1-V0-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-M-FOIL-2023-2024')
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
    'GP2-V0-M-FOIL-2023-2024',
    'Grand Prix (runda 2)',
    'PPW',
    'FOIL', 'M', 'V0',
    '2023-03-05', 2, 'https://www.fencingtimelive.com/events/results/1119CC6FCAC346378C004DE731497E6A',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    189,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V0-M-FOIL-2023-2024'),
    1,
    'NOWAK Szymon'
); -- matched: NOWAK Szymon (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    2,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V0-M-FOIL-2023-2024'),
    2,
    'ADAMCZYK Grzegorz'
); -- matched: ADAMCZYK Grzegorz (score=100.0)
-- Compute scores for GP2-V0-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V0-M-FOIL-2023-2024')
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
    'GP3-V0-M-FOIL-2023-2024',
    'Grand Prix (runda 3)',
    'PPW',
    'FOIL', 'M', 'V0',
    '2023-06-18', 3, 'https://www.fencingtimelive.com/events/results/3FAD8232409B4B4ABA8A916BF3FEDAF6',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    232,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V0-M-FOIL-2023-2024'),
    1,
    'RZESZUTKO Jakub'
); -- matched: RZESZUTKO Jakub (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    189,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V0-M-FOIL-2023-2024'),
    2,
    'NOWAK Szymon'
); -- matched: NOWAK Szymon (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    2,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V0-M-FOIL-2023-2024'),
    3,
    'ADAMCZYK Grzegorz'
); -- matched: ADAMCZYK Grzegorz (score=100.0)
-- Compute scores for GP3-V0-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V0-M-FOIL-2023-2024')
);

-- SKIP GP4 (Grand Prix (runda 4)): N=0 — tournament had no participants

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
    'GP5-V0-M-FOIL-2023-2024',
    'Grand Prix (runda 5)',
    'PPW',
    'FOIL', 'M', 'V0',
    '2023-10-28', 3, 'https://www.fencingtimelive.com/events/results/0CC2C91478474AF1B0F4E8EF994F25A3',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    189,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V0-M-FOIL-2023-2024'),
    1,
    'NOWAK Szymon'
); -- matched: NOWAK Szymon (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    105,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V0-M-FOIL-2023-2024'),
    2,
    'JEROZOLIMSKI Marek'
); -- matched: JEROZOLIMSKI Marek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    2,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V0-M-FOIL-2023-2024'),
    3,
    'ADAMCZYK Grzegorz'
); -- matched: ADAMCZYK Grzegorz (score=100.0)
-- Compute scores for GP5-V0-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V0-M-FOIL-2023-2024')
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
    'GP6-V0-M-FOIL-2023-2024',
    'Grand Prix (runda 6)',
    'PPW',
    'FOIL', 'M', 'V0',
    '2023-11-18', 1, 'https://www.fencingtimelive.com/events/results/41AE4EC0F9954F259EC24A709B66CCA2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    2,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V0-M-FOIL-2023-2024'),
    1,
    'ADAMCZYK Grzegorz'
); -- matched: ADAMCZYK Grzegorz (score=100.0)
-- Compute scores for GP6-V0-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V0-M-FOIL-2023-2024')
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
    'GP7-V0-M-FOIL-2023-2024',
    'Grand Prix (runda 7)',
    'PPW',
    'FOIL', 'M', 'V0',
    '2024-01-28', 2, 'https://www.fencingtimelive.com/events/results/15D820D5BA9A442AA26E2B4B816F091F',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    189,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V0-M-FOIL-2023-2024'),
    1,
    'NOWAK Szymon'
); -- matched: NOWAK Szymon (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    2,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V0-M-FOIL-2023-2024'),
    2,
    'ADAMCZYK Grzegorz'
); -- matched: ADAMCZYK Grzegorz (score=100.0)
-- Compute scores for GP7-V0-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V0-M-FOIL-2023-2024')
);

-- SKIP GP8 (Grand Prix (runda 8)): N=0 — tournament had no participants

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
    'MPW-V0-M-FOIL-2023-2024',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'FOIL', 'M', 'V0',
    '2024-03-02', 3, 'https://www.fencingtimelive.com/events/results/09163F1D25C3417984E126BC677640D6',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    189,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-FOIL-2023-2024'),
    1,
    'NOWAK Szymon'
); -- matched: NOWAK Szymon (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    2,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-FOIL-2023-2024'),
    2,
    'ADAMCZYK Grzegorz'
); -- matched: ADAMCZYK Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    59,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-FOIL-2023-2024'),
    3,
    'FRYDRYCH Szymon'
); -- matched: FRYDRYCH Szymon (score=100.0)
-- Compute scores for MPW-V0-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-FOIL-2023-2024')
);

-- Summary
-- Total results matched:   15
-- Total results unmatched: 0
-- Total auto-created:      0
