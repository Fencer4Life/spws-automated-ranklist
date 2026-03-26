-- =========================================================================
-- Season 2024-2025 — V0 F EPEE — generated from SZPADA-K0-2024-2025.xlsx
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
    'PP1-V0-F-EPEE-2024-2025',
    'I Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'F', 'V0',
    '2024-09-28', 1, 'https://www.fencingtimelive.com/events/results/9633DE4F5D8A41D7AB9E647E48F959EF',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    111,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V0-F-EPEE-2024-2025'),
    1,
    'KOCÓR Agata'
); -- matched: KOCÓR Agata (score=100.0)
-- Compute scores for PP1-V0-F-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V0-F-EPEE-2024-2025')
);

-- ---- PP2: II Puchar Polski Weteranów (BYTOM) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PP2-2024-2025',
    'II Puchar Polski Weteranów',
    'BYTOM',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PP2-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PP2-2024-2025'),
    'PP2-V0-F-EPEE-2024-2025',
    'II Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'F', 'V0',
    '2024-10-24', 5, 'https://www.fencingtimelive.com/events/results/9D638370FF84447180C2431376B06A62',
    'SCORED'
);
-- UNMATCHED (score<80): 'SZMAJDZIŃSKA Katarzyna' place=1
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    8,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V0-F-EPEE-2024-2025'),
    2,
    'BARAN Agata'
); -- matched: BARAN Agata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    89,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V0-F-EPEE-2024-2025'),
    3,
    'IRZYK Sabina'
); -- matched: IRZYK Sabina (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    111,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V0-F-EPEE-2024-2025'),
    4,
    'KOCÓR Agata'
); -- matched: KOCÓR Agata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    28,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V0-F-EPEE-2024-2025'),
    5,
    'CHMIELEWSKA Emilia'
); -- matched: CHMIELEWSKA Emilia (score=100.0)
-- Compute scores for PP2-V0-F-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V0-F-EPEE-2024-2025')
);

-- ---- PP3: III Puchar Polski Weteranów (KRAKÓW) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PP3-2024-2025',
    'III Puchar Polski Weteranów',
    'KRAKÓW',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PP3-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PP3-2024-2025'),
    'PP3-V0-F-EPEE-2024-2025',
    'III Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'F', 'V0',
    '2024-11-30', 6, 'https://www.fencingtimelive.com/events/results/2450998AA89F479DBA3FE7285E3DC41F',
    'SCORED'
);
-- UNMATCHED (score<80): 'SPIRINA Ekaterina' place=1
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    8,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V0-F-EPEE-2024-2025'),
    2,
    'BARAN Agata'
); -- matched: BARAN Agata (score=100.0)
-- UNMATCHED (score<80): 'PĘCZEK Sandra' place=3
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    89,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V0-F-EPEE-2024-2025'),
    4,
    'IRZYK Sabina'
); -- matched: IRZYK Sabina (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    111,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V0-F-EPEE-2024-2025'),
    5,
    'KOCÓR Agata'
); -- matched: KOCÓR Agata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    28,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V0-F-EPEE-2024-2025'),
    6,
    'CHMIELEWSKA Emilia'
); -- matched: CHMIELEWSKA Emilia (score=100.0)
-- Compute scores for PP3-V0-F-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V0-F-EPEE-2024-2025')
);

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
    'MPW-V0-F-EPEE-2024-2025',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'EPEE', 'F', 'V0',
    '2025-06-07', 3, 'https://www.fencingtimelive.com/events/results/0C897F4B78BE41288DC9EE257CCE4398',
    'SCORED'
);
-- UNMATCHED (score<80): 'GÓRNA Karolina' place=1
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    89,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-F-EPEE-2024-2025'),
    2,
    'IRZYK Sabina'
); -- matched: IRZYK Sabina (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    28,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-F-EPEE-2024-2025'),
    3,
    'CHMIELEWSKA Emilia'
); -- matched: CHMIELEWSKA Emilia (score=100.0)
-- Compute scores for MPW-V0-F-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-F-EPEE-2024-2025')
);

-- Summary
-- Total results matched:   11
-- Total results unmatched: 4
