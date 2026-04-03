-- =========================================================================
-- Season 2023-2024 — V3 M SABRE — generated from SZABLA-3-2023-2024.xlsx
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
    'GP1-V3-M-SABRE-2023-2024',
    'Grand Prix (runda 1)',
    'PPW',
    'SABRE', 'M', 'V3',
    '2023-01-15', 4, 'https://www.fencingtimelive.com/events/results/7301178A42EF4C4D91A0F0E32716FE2D',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    170,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-SABRE-2023-2024'),
    1,
    'OSSOWSKI Wojciech'
); -- matched: OSSOWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    70,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-SABRE-2023-2024'),
    2,
    'GRABOWSKI Romuald'
); -- matched: GRABOWSKI Romuald (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    98,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-SABRE-2023-2024'),
    3,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-SABRE-2023-2024'),
    4,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
-- Compute scores for GP1-V3-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V3-M-SABRE-2023-2024')
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
    'GP2-V3-M-SABRE-2023-2024',
    'Grand Prix (runda 2)',
    'PPW',
    'SABRE', 'M', 'V3',
    '2023-03-05', 3, 'https://www.fencingtimelive.com/events/results/3AC0F37F1E5F457A97120D2447D341B1',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    170,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-SABRE-2023-2024'),
    1,
    'OSSOWSKI Wojciech'
); -- matched: OSSOWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    98,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-SABRE-2023-2024'),
    2,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    70,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-SABRE-2023-2024'),
    3,
    'GRABOWSKI Romuald'
); -- matched: GRABOWSKI Romuald (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-SABRE-2023-2024'),
    5,
    'BARAŃSKI Wacław'
); -- matched: BARAŃSKI Wacław (score=100.0)
-- Compute scores for GP2-V3-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V3-M-SABRE-2023-2024')
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
    'GP3-V3-M-SABRE-2023-2024',
    'Grand Prix (runda 3)',
    'PPW',
    'SABRE', 'M', 'V3',
    '2023-06-18', 3, 'https://www.fencingtimelive.com/events/results/F912391B85DC4EFCADCF81578E60B7AD',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    163,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-SABRE-2023-2024'),
    1,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    170,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-SABRE-2023-2024'),
    2,
    'OSSOWSKI Wojciech'
); -- matched: OSSOWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    31,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-SABRE-2023-2024'),
    3,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    262,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-SABRE-2023-2024'),
    6,
    'ZABŁOCKI Michał'
); -- matched: ZABŁOCKI Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-SABRE-2023-2024'),
    7,
    'BARAŃSKI Wacław'
); -- matched: BARAŃSKI Wacław (score=100.0)
-- Compute scores for GP3-V3-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V3-M-SABRE-2023-2024')
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
    'GP4-V3-M-SABRE-2023-2024',
    'Grand Prix (runda 4)',
    'PPW',
    'SABRE', 'M', 'V3',
    '2023-10-23', 4, 'https://www.fencingtimelive.com/events/results/50FCF9C3417C4E99BDF48E6B9BD9A5A8',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    262,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V3-M-SABRE-2023-2024'),
    1,
    'ZABŁOCKI Michał'
); -- matched: ZABŁOCKI Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    168,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V3-M-SABRE-2023-2024'),
    2,
    'NOWICKI Wiesław'
); -- matched: NOWICKI Wiesław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V3-M-SABRE-2023-2024'),
    3,
    'BARAŃSKI Wacław'
); -- matched: BARAŃSKI Wacław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V3-M-SABRE-2023-2024'),
    4,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
-- Compute scores for GP4-V3-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V3-M-SABRE-2023-2024')
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
    'GP5-V3-M-SABRE-2023-2024',
    'Grand Prix (runda 5)',
    'PPW',
    'SABRE', 'M', 'V3',
    '2023-10-28', 2, 'https://www.fencingtimelive.com/events/results/9F634F806CE54F0F9F539A52CB034B29',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    262,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V3-M-SABRE-2023-2024'),
    1,
    'ZABŁOCKI Michał'
); -- matched: ZABŁOCKI Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V3-M-SABRE-2023-2024'),
    2,
    'BARAŃSKI Wacław'
); -- matched: BARAŃSKI Wacław (score=100.0)
-- Compute scores for GP5-V3-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V3-M-SABRE-2023-2024')
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
    'GP6-V3-M-SABRE-2023-2024',
    'Grand Prix (runda 6)',
    'PPW',
    'SABRE', 'M', 'V3',
    '2023-11-18', 5, 'https://www.fencingtimelive.com/events/results/8652CA83471542E2A6F4EEF73C854E33',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    262,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-SABRE-2023-2024'),
    1,
    'ZABŁOCKI Michał'
); -- matched: ZABŁOCKI Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    170,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-SABRE-2023-2024'),
    2,
    'OSSOWSKI Wojciech'
); -- matched: OSSOWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    31,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-SABRE-2023-2024'),
    3,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-SABRE-2023-2024'),
    4,
    'BARAŃSKI Wacław'
); -- matched: BARAŃSKI Wacław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-SABRE-2023-2024'),
    5,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
-- Compute scores for GP6-V3-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V3-M-SABRE-2023-2024')
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
    'GP7-V3-M-SABRE-2023-2024',
    'Grand Prix (runda 7)',
    'PPW',
    'SABRE', 'M', 'V3',
    '2024-01-28', 2, 'https://www.fencingtimelive.com/events/results/7CE1DC7ACC484DF9B37E067638C32C38',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    262,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V3-M-SABRE-2023-2024'),
    1,
    'ZABŁOCKI Michał'
); -- matched: ZABŁOCKI Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V3-M-SABRE-2023-2024'),
    2,
    'BARAŃSKI Wacław'
); -- matched: BARAŃSKI Wacław (score=100.0)
-- Compute scores for GP7-V3-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V3-M-SABRE-2023-2024')
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
    'GP8-V3-M-SABRE-2023-2024',
    'Grand Prix (runda 8)',
    'PPW',
    'SABRE', 'M', 'V3',
    '2024-06-23', 2, 'https://www.fencingtimelive.com/events/results/630DE247210948C19312EDDC80AEB59C',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    31,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-SABRE-2023-2024'),
    1,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    284,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-SABRE-2023-2024'),
    2,
    'FARAGO József'
); -- matched: FARAGO József (score=100.0)
-- Compute scores for GP8-V3-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V3-M-SABRE-2023-2024')
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
    'MPW-V3-M-SABRE-2023-2024',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'SABRE', 'M', 'V3',
    '2024-03-02', 4, 'https://www.fencingtimelive.com/events/results/A2482623A480483CB53D9B87F8DB0A94',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    262,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-SABRE-2023-2024'),
    1,
    'ZABŁOCKI Michał'
); -- matched: ZABŁOCKI Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    31,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-SABRE-2023-2024'),
    2,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-SABRE-2023-2024'),
    3,
    'BARAŃSKI Wacław'
); -- matched: BARAŃSKI Wacław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-SABRE-2023-2024'),
    4,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
-- Compute scores for MPW-V3-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-SABRE-2023-2024')
);

-- SKIP PEW1 (EVF Grand Prix 1 — Budapeszt): N=0 — tournament had no participants

-- SKIP PEW2 (EVF Grand Prix 2 — Madryt): N=0 — tournament had no participants

-- SKIP PEW3 (EVF Grand Prix 3): N=0 — tournament had no participants

-- SKIP PEW4 (EVF Grand Prix 4): N=0 — tournament had no participants

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
    'PEW5-V3-M-SABRE-2023-2024',
    'EVF Grand Prix 5',
    'PEW',
    'SABRE', 'M', 'V3',
    '2023-09-16', 21, 'https://engarde-service.com/?fbclid=IwAR1q8b20973WNdhLRYbl3vdP-rPK0cilvuHZi37KFNf-Dodoicffb3YOQeM',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    262,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V3-M-SABRE-2023-2024'),
    2,
    'ZABŁOCKI Michał'
); -- matched: ZABŁOCKI Michał (score=100.0)
-- Compute scores for PEW5-V3-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V3-M-SABRE-2023-2024')
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
    'PEW6-V3-M-SABRE-2023-2024',
    'EVF Grand Prix 6',
    'PEW',
    'SABRE', 'M', 'V3',
    '2023-11-11', 13, 'https://engarde-service.com/competition/aeve_esgrima/evf_madrid_2023/sm_3_4',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    262,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-SABRE-2023-2024'),
    1,
    'ZABŁOCKI Michał'
); -- matched: ZABŁOCKI Michał (score=100.0)
-- Compute scores for PEW6-V3-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-SABRE-2023-2024')
);

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): N=0 — tournament had no participants

-- SKIP PEW8 (EVF Grand Prix 8 — Guildford): N=0 — tournament had no participants

-- SKIP PEW9 (EVF Grand Prix 9 — Sztokholm): 0 matched fencers in DB — tournament not created

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
    'IMEW-V3-M-SABRE-2023-2024',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'SABRE', 'M', 'V3',
    '2023-01-01', 46, 'https://engarde-service.com/competition/e3f/efcv/mensabrev4',
    'SCORED'
);
-- UNMATCHED (score<80): 'ANTINORO' place=1
-- UNMATCHED (score<80): 'BEM' place=2
-- UNMATCHED (score<80): 'KAS' place=3
-- UNMATCHED (score<80): 'PIMENAU' place=3
-- UNMATCHED (score<80): 'TAKACSY' place=5
-- UNMATCHED (score<80): 'ROSEN' place=6
-- UNMATCHED (score<80): 'BRANDT' place=7
-- UNMATCHED (score<80): 'FEIRA CHIOS' place=8
-- UNMATCHED (score<80): 'RAMIER' place=9
-- UNMATCHED (score<80): 'TAILLANDIER' place=10
-- UNMATCHED (score<80): 'FALASCHI' place=11
-- UNMATCHED (score<80): 'GHOSH' place=12
-- UNMATCHED (score<80): 'ZELIKOVICS' place=13
-- UNMATCHED (score<80): 'LUZZO' place=14
-- UNMATCHED (score<80): 'ARPASI' place=15
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    170,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-SABRE-2023-2024'),
    16,
    'OSSOWSKI Wojciech'
); -- matched: OSSOWSKI Wojciech (score=100.0)
-- UNMATCHED (score<80): 'BOTTECCHIA' place=17
-- UNMATCHED (score<80): 'VAN DER WEIDE' place=18
-- UNMATCHED (score<80): 'PREIS' place=19
-- UNMATCHED (score<80): 'ZIEBELL' place=20
-- UNMATCHED (score<80): 'ZANELLATO' place=21
-- UNMATCHED (score<80): 'TALLARICO' place=22
-- UNMATCHED (score<80): 'DUBOS' place=23
-- UNMATCHED (score<80): 'BENARD' place=24
-- UNMATCHED (score<80): 'SILVER' place=25
-- UNMATCHED (score<80): 'BALONUSKOVS' place=26
-- UNMATCHED (score<80): 'ROSADO OLARÁN' place=27
-- UNMATCHED (score<80): 'PRIJATELJ' place=28
-- UNMATCHED (score<80): 'VARJU' place=29
-- UNMATCHED (score<80): 'KOBYAKOV' place=30
-- UNMATCHED (score<80): 'NAGY' place=31
-- UNMATCHED (score<80): 'CIUFFREDA' place=32
-- UNMATCHED (score<80): 'PREVETT' place=33
-- UNMATCHED (score<80): 'NAGY' place=34
-- UNMATCHED (score<80): 'VAROTTO' place=35
-- UNMATCHED (score<80): 'MARACZ' place=36
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    98,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-SABRE-2023-2024'),
    37,
    'JUSZKIEWICZ PIOTR'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
-- UNMATCHED (score<80): 'DAWKINS' place=38
-- UNMATCHED (score<80): 'BOHMER' place=39
-- UNMATCHED (score<80): 'CHIKHRADZE' place=40
-- UNMATCHED (score<80): 'ROHR AGUIRRE' place=41
-- UNMATCHED (score<80): 'KAINZ' place=42
-- UNMATCHED (score<80): 'CRANSTON-SELBY' place=43
-- UNMATCHED (score<80): 'O''FARRELL' place=44
-- UNMATCHED (score<80): 'SCHRANS' place=45
-- UNMATCHED (score<80): 'BURGHARDT' place=46
-- Compute scores for IMEW-V3-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-SABRE-2023-2024')
);

-- Summary
-- Total results matched:   36
-- Total results unmatched: 45
