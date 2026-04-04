-- =========================================================================
-- Season 2023-2024 — V1 F SABRE — generated from SZABLA-K1-2023-2024.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- SKIP GP1 (Grand Prix (runda 1)): N=0 — tournament had no participants

-- SKIP GP2 (Grand Prix (runda 2)): N=0 — tournament had no participants

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
    'GP3-V1-F-SABRE-2023-2024',
    'Grand Prix (runda 3)',
    'PPW',
    'SABRE', 'F', 'V1',
    '2023-06-18', 1, 'https://www.fencingtimelive.com/events/results/C490EA7F038D4E98BCF3DA93602AF72D',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    66,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-F-SABRE-2023-2024'),
    1,
    'GAWLE Katarzyna'
); -- matched: GAWLE Katarzyna (score=100.0)
-- Compute scores for GP3-V1-F-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-F-SABRE-2023-2024')
);

-- SKIP GP4 (Grand Prix (runda 4)): N=0 — tournament had no participants

-- SKIP GP5 (Grand Prix (runda 5)): N=0 — tournament had no participants

-- SKIP GP6 (Grand Prix (runda 6)): N=0 — tournament had no participants

-- SKIP GP7 (Grand Prix (runda 7)): N=0 — tournament had no participants

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
    'MPW-V1-F-SABRE-2023-2024',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'SABRE', 'F', 'V1',
    '2024-03-02', 3, 'https://www.fencingtimelive.com/events/results/F2E70A712A9A4ED5AEA1E05CDC71272E',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    29,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-F-SABRE-2023-2024'),
    1,
    'BUJKO Paulina'
); -- matched: BUJKO Paulina (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    66,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-F-SABRE-2023-2024'),
    2,
    'GAWLE Katarzyna'
); -- matched: GAWLE Katarzyna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    177,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-F-SABRE-2023-2024'),
    3,
    'MIKULICKA Joanna'
); -- matched: MIKULICKA Joanna (score=100.0)
-- Compute scores for MPW-V1-F-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-F-SABRE-2023-2024')
);

-- SKIP PEW1 (EVF Grand Prix 1 — Budapeszt): N=0 — tournament had no participants

-- SKIP PEW2 (EVF Grand Prix 2 — Madryt): N=0 — tournament had no participants

-- SKIP PEW3 (EVF Grand Prix 3): N=0 — tournament had no participants

-- SKIP PEW4 (EVF Grand Prix 4): N=0 — tournament had no participants

-- SKIP PEW5 (EVF Grand Prix 5): N=0 — tournament had no participants

-- SKIP PEW6 (EVF Grand Prix 6): N=0 — tournament had no participants

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): N=0 — tournament had no participants

-- SKIP PEW8 (EVF Grand Prix 8 — Guildford): N=0 — tournament had no participants

-- SKIP PEW9 (EVF Grand Prix 9 — Sztokholm): N=0 — tournament had no participants

-- SKIP PEW10 (EVF Grand Prix 10 — Graz): N=0 — tournament had no participants

-- SKIP PEW11 (EVF Grand Prix 11 — Gdańsk): N=0 — tournament had no participants

-- SKIP PEW12 (EVF Grand Prix 12 — Ateny): N=0 — tournament had no participants

-- SKIP IMEW (Indywidualne Mistrzostwa Europy Weteranów): 0 matched fencers in DB — tournament not created

-- Summary
-- Total results matched:   4
-- Total results unmatched: 20
-- Total auto-created:      0
