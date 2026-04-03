-- =========================================================================
-- Season 2023-2024 — V0 F FOIL — generated from FLORET-K0-2023-2024.xlsx
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
    'GP1-V0-F-FOIL-2023-2024',
    'Grand Prix (runda 1)',
    'PPW',
    'FOIL', 'F', 'V0',
    '2023-01-15', 2, 'https://www.fencingtimelive.com/events/results/554039D141534F1B8217F2A2DD3BF02E',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    142,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-F-FOIL-2023-2024'),
    1,
    'LIPKOWSKA Dominika'
); -- matched: LIPKOWSKA Dominika (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    127,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-F-FOIL-2023-2024'),
    2,
    'KOWALSKA Milena'
); -- matched: KOWALSKA Milena (score=100.0)
-- Compute scores for GP1-V0-F-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-F-FOIL-2023-2024')
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
    'GP2-V0-F-FOIL-2023-2024',
    'Grand Prix (runda 2)',
    'PPW',
    'FOIL', 'F', 'V0',
    '2023-03-05', 3, 'https://www.fencingtimelive.com/events/results/A87DEFCD43D04717B461012F70847343',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    18,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V0-F-FOIL-2023-2024'),
    1,
    'BONIK-NINARD Agata'
); -- matched: BONIK-NINARD Agata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    142,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V0-F-FOIL-2023-2024'),
    2,
    'LIPKOWSKA Dominika'
); -- matched: LIPKOWSKA Dominika (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    197,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V0-F-FOIL-2023-2024'),
    3,
    'RUT Agnieszka'
); -- matched: RUT Agnieszka (score=100.0)
-- Compute scores for GP2-V0-F-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V0-F-FOIL-2023-2024')
);

-- SKIP GP3 (Grand Prix (runda 3)): N=0 — tournament had no participants

-- SKIP GP4 (Grand Prix (runda 4)): N=0 — tournament had no participants

-- SKIP GP5 (Grand Prix (runda 5)): N=0 — tournament had no participants

-- SKIP GP6 (Grand Prix (runda 6)): N=0 — tournament had no participants

-- SKIP GP7 (Grand Prix (runda 7)): N=0 — tournament had no participants

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
    'GP8-V0-F-FOIL-2023-2024',
    'Grand Prix (runda 8)',
    'PPW',
    'FOIL', 'F', 'V0',
    '2024-06-23', 1, 'https://www.fencingtimelive.com/events/results/B9AA426AE74441C2B2DBBCBA0F711B44',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    204,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V0-F-FOIL-2023-2024'),
    1,
    'SAMECKA-NACZYŃSKA Martyna'
); -- matched: SAMECKA-NACZYŃSKA Martyna (score=100.0)
-- Compute scores for GP8-V0-F-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V0-F-FOIL-2023-2024')
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
    'MPW-V0-F-FOIL-2023-2024',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'FOIL', 'F', 'V0',
    '2024-03-02', 3, 'https://www.fencingtimelive.com/events/results/9363D09585964BBAA3B1F97F262035D5',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-F-FOIL-2023-2024'),
    1,
    'SAJEWICZ Izabela'
); -- matched: SAJEWICZ Izabela (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    364,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-F-FOIL-2023-2024'),
    2,
    'SZYPUŁOWSKA-GRZYŚ Joanna'
); -- matched: SZYPUŁOWSKA-GRZYŚ Joanna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    204,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-F-FOIL-2023-2024'),
    3,
    'SAMECKA-NACZYŃSKA Martyna'
); -- matched: SAMECKA-NACZYŃSKA Martyna (score=100.0)
-- Compute scores for MPW-V0-F-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-F-FOIL-2023-2024')
);

-- Summary
-- Total results matched:   9
-- Total results unmatched: 0
