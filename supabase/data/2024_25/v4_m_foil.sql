-- =========================================================================
-- Season 2024-2025 — V4 M FOIL — generated from FLORET-4-2024-2025.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- ---- PP1: I Puchar Polski Weteranów (KONIN) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PP1-2024-2025',
    'I Puchar Polski Weteranów',
    'KONIN',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PP1-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PP1-2024-2025'),
    'PP1-V4-M-FOIL-2024-2025',
    'I Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V4',
    '2024-09-29', 3, 'https://www.fencingtimelive.com/events/results/2965FA91D33D4CFDBC61E02F6BCC3356',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V4-M-FOIL-2024-2025'),
    1,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    98,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V4-M-FOIL-2024-2025'),
    2,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
-- UNMATCHED (score<80): 'VETULANI Zygmunt' place=3
-- Compute scores for PP1-V4-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V4-M-FOIL-2024-2025')
);

-- SKIP PP2 (II Puchar Polski Weteranów): N=0 — tournament had no participants

-- SKIP PP3 (III Puchar Polski Weteranów): N=0 — tournament had no participants

-- ---- MPW: Mistrzostwa Polski Weteranów (PABIANICE) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'MPW-2024-2025',
    'Mistrzostwa Polski Weteranów',
    'PABIANICE',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'MPW-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'MPW-2024-2025'),
    'MPW-V4-M-FOIL-2024-2025',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'FOIL', 'M', 'V4',
    '2025-06-08', 3, 'https://www.fencingtimelive.com/tournaments/eventSchedule/B2C615704AB84D0F85BBFF395C07BA41',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-FOIL-2024-2025'),
    1,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    1,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-FOIL-2024-2025'),
    2,
    'ADAMCZEWSKI Wojciech'
); -- matched: ADAMCZEWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    98,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-FOIL-2024-2025'),
    3,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
-- Compute scores for MPW-V4-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-FOIL-2024-2025')
);

-- ---- PEW1: EVF Grand Prix 1 — Budapeszt (Budapest) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW1-2024-2025',
    'EVF Grand Prix 1 — Budapeszt',
    'Budapest',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW1-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1-2024-2025'),
    'PEW1-V4-M-FOIL-2024-2025',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'FOIL', 'M', 'V4',
    '2024-09-22', 8, 'https://engarde-service.com/app.php?id=4209S4',
    'SCORED'
);
-- Compute scores for PEW1-V4-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V4-M-FOIL-2024-2025')
);

-- SKIP PEW2 (EVF Grand Prix 2 — Madryt): N=0 — tournament had no participants

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): N=0 — tournament had no participants

-- ---- PEW8: EVF Grand Prix 8 — Guildford (WARSZAWA) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW8-2024-2025',
    'EVF Grand Prix 8 — Guildford',
    'WARSZAWA',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW8-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW8-2024-2025'),
    'PEW8-V4-M-FOIL-2024-2025',
    'EVF Grand Prix 8 — Guildford',
    'PEW',
    'FOIL', 'M', 'V4',
    '2025-03-30', 5, 'https://www.fencingtimelive.com/events/results/0A9DFBBD80E444A2B2E37212E194B863',
    'SCORED'
);
-- UNMATCHED (score<80): 'LIPTÁK György' place=1
-- UNMATCHED (score<80): 'PINCEMAILLE Benoit' place=2
-- UNMATCHED (score<80): 'ZYLKA Henryk' place=3
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    98,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V4-M-FOIL-2024-2025'),
    3,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V4-M-FOIL-2024-2025'),
    5,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
-- Compute scores for PEW8-V4-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V4-M-FOIL-2024-2025')
);

-- ---- IMEW: Indywidualne Mistrzostwa Europy Weteranów (Płowdiw) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'IMEW-2024-2025',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'Płowdiw',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'IMEW-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'IMEW-2024-2025'),
    'IMEW-V4-M-FOIL-2024-2025',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'FOIL', 'M', 'V4',
    '2025-05-29', 23, 'https://www.fencingtimelive.com/events/results/BAFB78C5C59649D5BD897C7593E7FE01',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    20,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V4-M-FOIL-2024-2025'),
    8,
    'BORKOWSKI Andrzej'
); -- matched: BORKOWSKI Andrzej (score=100.0)
-- Compute scores for IMEW-V4-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V4-M-FOIL-2024-2025')
);

-- Summary
-- Total results matched:   8
-- Total results unmatched: 4
