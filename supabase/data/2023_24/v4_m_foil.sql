-- =========================================================================
-- Season 2023-2024 — V4 M FOIL — generated from FLORET-4-2023-2024.xlsx
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
    'GP1-V4-M-FOIL-2023-2024',
    'Grand Prix (runda 1)',
    'PPW',
    'FOIL', 'M', 'V4',
    '2023-01-15', 1, 'https://www.fencingtimelive.com/events/results/D0EB68D0C36A4ED18698E79FFEF906D9',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    24,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V4-M-FOIL-2023-2024'),
    1,
    'BORKOWSKI Andrzej'
); -- matched: BORKOWSKI Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V4-M-FOIL-2023-2024'),
    3,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
-- Compute scores for GP1-V4-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V4-M-FOIL-2023-2024')
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
    'GP2-V4-M-FOIL-2023-2024',
    'Grand Prix (runda 2)',
    'PPW',
    'FOIL', 'M', 'V4',
    '2023-03-05', 2, 'https://www.fencingtimelive.com/events/results/CED6E6F660FF4EAEAF7595BEE5F9D74B',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    305,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V4-M-FOIL-2023-2024'),
    1,
    'WYLĘGAŁA Jerzy'
); -- matched: WYLĘGAŁA Jerzy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    24,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V4-M-FOIL-2023-2024'),
    2,
    'BORKOWSKI Andrzej'
); -- matched: BORKOWSKI Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V4-M-FOIL-2023-2024'),
    5,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
-- Compute scores for GP2-V4-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V4-M-FOIL-2023-2024')
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
    'GP3-V4-M-FOIL-2023-2024',
    'Grand Prix (runda 3)',
    'PPW',
    'FOIL', 'M', 'V4',
    '2023-06-18', 1, 'https://www.fencingtimelive.com/events/results/0BEDA2182C2B4BCF9694B7CB471A3976',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    24,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V4-M-FOIL-2023-2024'),
    1,
    'BORKOWSKI Andrzej'
); -- matched: BORKOWSKI Andrzej (score=100.0)
-- Compute scores for GP3-V4-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V4-M-FOIL-2023-2024')
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
    'GP4-V4-M-FOIL-2023-2024',
    'Grand Prix (runda 4)',
    'PPW',
    'FOIL', 'M', 'V4',
    '2023-10-23', 3, 'https://www.fencingtimelive.com/events/results/15CFDD0FE7594322BC9E1692AB769F51',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    24,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V4-M-FOIL-2023-2024'),
    1,
    'BORKOWSKI Andrzej'
); -- matched: BORKOWSKI Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V4-M-FOIL-2023-2024'),
    2,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    305,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V4-M-FOIL-2023-2024'),
    3,
    'WYLĘGAŁA Jerzy'
); -- matched: WYLĘGAŁA Jerzy (score=100.0)
-- Compute scores for GP4-V4-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V4-M-FOIL-2023-2024')
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
    'GP5-V4-M-FOIL-2023-2024',
    'Grand Prix (runda 5)',
    'PPW',
    'FOIL', 'M', 'V4',
    '2023-10-28', 1, 'https://www.fencingtimelive.com/events/results/EC28FF8573C6413F90CD4E218E7A53C3',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    24,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V4-M-FOIL-2023-2024'),
    1,
    'BORKOWSKI Andrzej'
); -- matched: BORKOWSKI Andrzej (score=100.0)
-- Compute scores for GP5-V4-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V4-M-FOIL-2023-2024')
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
    'GP6-V4-M-FOIL-2023-2024',
    'Grand Prix (runda 6)',
    'PPW',
    'FOIL', 'M', 'V4',
    '2023-11-18', 2, 'https://www.fencingtimelive.com/events/results/9267EFB97377411FA48172BE8F1A8FF4',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    24,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V4-M-FOIL-2023-2024'),
    1,
    'BORKOWSKI Andrzej'
); -- matched: BORKOWSKI Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V4-M-FOIL-2023-2024'),
    2,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
-- Compute scores for GP6-V4-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V4-M-FOIL-2023-2024')
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
    'GP7-V4-M-FOIL-2023-2024',
    'Grand Prix (runda 7)',
    'PPW',
    'FOIL', 'M', 'V4',
    '2024-01-27', 1, 'https://www.fencingtimelive.com/events/results/15D820D5BA9A442AA26E2B4B816F091F',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V4-M-FOIL-2023-2024'),
    1,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
-- Compute scores for GP7-V4-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V4-M-FOIL-2023-2024')
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
    'MPW-V4-M-FOIL-2023-2024',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'FOIL', 'M', 'V4',
    '2024-03-02', 2, 'https://www.fencingtimelive.com/events/results/049F6F983ACE4D76B4471120D31F05F2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    1,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-FOIL-2023-2024'),
    1,
    'ADAMCZEWSKI Wojciech'
); -- matched: ADAMCZEWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-FOIL-2023-2024'),
    2,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
-- Compute scores for MPW-V4-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-FOIL-2023-2024')
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
    'IMEW-V4-M-FOIL-2023-2024',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'FOIL', 'M', 'V4',
    '2023-01-01', 32, 'https://engarde-service.com/competition/e3f/efcv/menfoilv4',
    'SCORED'
);
-- SKIPPED (international, no master data): 'SHAPIRA' place=1
-- SKIPPED (international, no master data): 'PAUL' place=2
-- SKIPPED (international, no master data): 'PRECHTL' place=3
-- SKIPPED (international, no master data): 'SCHAUM' place=3
-- SKIPPED (international, no master data): 'SOUMAGNE' place=5
-- SKIPPED (international, no master data): 'LOWEN' place=6
-- SKIPPED (international, no master data): 'LE MONNIER' place=7
-- SKIPPED (international, no master data): 'LIPTAK' place=8
-- SKIPPED (international, no master data): 'IMREH' place=9
-- SKIPPED (international, no master data): 'CAUSTON' place=10
-- SKIPPED (international, no master data): 'BRADBURY' place=11
-- SKIPPED (international, no master data): 'OSWALD' place=12
-- SKIPPED (international, no master data): 'CARMINA' place=13
-- SKIPPED (international, no master data): 'SZENTKIRALYI' place=14
-- SKIPPED (international, no master data): 'RAGG' place=15
-- SKIPPED (international, no master data): 'BOROS' place=16
-- SKIPPED (international, no master data): 'KACHUR' place=17
-- SKIPPED (international, no master data): 'DELACOUR' place=18
-- SKIPPED (international, no master data): 'ZULIANI' place=19
-- SKIPPED (international, no master data): 'MILLET' place=20
-- SKIPPED (international, no master data): 'NIZARD' place=21
-- SKIPPED (international, no master data): 'BERTHET' place=22
-- SKIPPED (international, no master data): 'TROUBLAIEWITCH' place=23
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    24,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V4-M-FOIL-2023-2024'),
    24,
    'BORKOWSKI Andrzej'
); -- matched: BORKOWSKI Andrzej (score=100.0)
-- SKIPPED (international, no master data): 'FONTANA' place=25
-- SKIPPED (international, no master data): 'HARDEN' place=26
-- SKIPPED (international, no master data): 'KONNES' place=27
-- SKIPPED (international, no master data): 'CUNEO' place=28
-- SKIPPED (international, no master data): 'HENSEL' place=29
-- SKIPPED (international, no master data): 'SCHOLZ' place=30
-- SKIPPED (international, no master data): 'MULLER' place=31
-- SKIPPED (international, no master data): 'MENCK' place=32
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V4-M-FOIL-2023-2024'),
    35,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
-- Compute scores for IMEW-V4-M-FOIL-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V4-M-FOIL-2023-2024')
);

-- Summary
-- Total results matched:   17
-- Total results unmatched: 31
-- Total auto-created:      0
