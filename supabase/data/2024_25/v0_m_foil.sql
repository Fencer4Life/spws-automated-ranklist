-- =========================================================================
-- Season 2024-2025 — V0 M FOIL — generated from FLORET-0-2024-2025.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- ---- PP1: I Puchar Polski Weteranów (KONIN) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW1-2024-2025',
    'I Puchar Polski Weteranów',
    'KONIN',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW1-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW1-2024-2025'),
    'PPW1-V0-M-FOIL-2024-2025',
    'I Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V0',
    '2024-09-29', 2, 'https://www.fencingtimelive.com/events/results/9CCBFFBAAD2F4D97B13E1CB414FD9D4D',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    2,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-FOIL-2024-2025'),
    1,
    'ADAMCZYK Grzegorz'
); -- matched: ADAMCZYK Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    59,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-FOIL-2024-2025'),
    2,
    'FRYDRYCH Szymon'
); -- matched: FRYDRYCH Szymon (score=100.0)
-- Compute scores for PPW1-V0-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-FOIL-2024-2025')
);

-- ---- PP2: II Puchar Polski Weteranów (BYTOM) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW2-2024-2025',
    'II Puchar Polski Weteranów',
    'BYTOM',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW2-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW2-2024-2025'),
    'PPW2-V0-M-FOIL-2024-2025',
    'II Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V0',
    '2024-10-27', 1, 'https://www.fencingtimelive.com/events/results/B322C8D0DA8E405F86082A16BA020B10',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    41,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-FOIL-2024-2025'),
    1,
    'KLAMAN Mateusz'
); -- matched: DAMIAN Mateusz (score=85.71428571428572)
-- Compute scores for PPW2-V0-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-FOIL-2024-2025')
);

-- ---- PP3: III Puchar Polski Weteranów (KRAKÓW) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW3-2024-2025',
    'III Puchar Polski Weteranów',
    'KRAKÓW',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW3-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW3-2024-2025'),
    'PPW3-V0-M-FOIL-2024-2025',
    'III Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V0',
    '2024-12-01', 3, 'https://www.fencingtimelive.com/events/results/D062FFAED68C4577BF8F8D0554E151B0',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    189,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-FOIL-2024-2025'),
    1,
    'NOWAK Szymon'
); -- matched: NOWAK Szymon (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-FOIL-2024-2025'),
    2,
    'SPŁAWA-NEYMAN MACIEJ'
); -- matched: SPŁAWA-NEYMAN MACIEJ (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    2,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-FOIL-2024-2025'),
    3,
    'ADAMCZYK Grzegorz'
); -- matched: ADAMCZYK Grzegorz (score=100.0)
-- Compute scores for PPW3-V0-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-FOIL-2024-2025')
);

-- ---- PP4: IV Puchar Polski Weteranów (WARSZAWA) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW4-2024-2025',
    'IV Puchar Polski Weteranów',
    'WARSZAWA',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW4-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW4-2024-2025'),
    'PPW4-V0-M-FOIL-2024-2025',
    'IV Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V0',
    '2025-02-23', 1, 'https://www.fencingtimelive.com/events/results/C169D5BBCBD043D4AC5EF76B06458D21',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-FOIL-2024-2025'),
    1,
    'SPŁAWA-NEYMAN MACIEJ'
); -- matched: SPŁAWA-NEYMAN MACIEJ (score=100.0)
-- Compute scores for PPW4-V0-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-FOIL-2024-2025')
);

-- ---- PP5: V Puchar Polski Weteranów (SZCZECIN) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW5-2024-2025',
    'V Puchar Polski Weteranów',
    'SZCZECIN',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW5-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW5-2024-2025'),
    'PPW5-V0-M-FOIL-2024-2025',
    'V Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V0',
    '2025-04-27', 1, 'https://www.fencingtimelive.com/events/results/57954AFC771743C995EB757C1B4E8AF7',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    174,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V0-M-FOIL-2024-2025'),
    1,
    'METZA Oskar'
); -- matched: METZA Oskar (score=100.0)
-- Compute scores for PPW5-V0-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V0-M-FOIL-2024-2025')
);

-- SKIP MPW (Mistrzostwa Polski Weteranów): N=0 — tournament had no participants

-- Summary
-- Total results matched:   8
-- Total results unmatched: 0
-- Total auto-created:      0
