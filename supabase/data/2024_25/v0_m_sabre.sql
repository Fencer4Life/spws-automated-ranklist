-- =========================================================================
-- Season 2024-2025 — V0 M SABRE — generated from SZABLA-0-2024-2025.xlsx
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
    'PP1-V0-M-SABRE-2024-2025',
    'I Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V0',
    '2023-10-23', 4, 'https://www.fencingtimelive.com/events/results/6287FD541EB54557A2D1E2B0AE1D86B5',
    'SCORED'
);
-- UNMATCHED (score<80): 'KOTSEV Ivan' place=1
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V0-M-SABRE-2024-2025'),
    2,
    'GĘZIKIEWICZ Marcin'
); -- matched: GĘZIKIEWICZ Marcin (score=100.0)
-- UNMATCHED (score<80): 'REDZIŃSKI Michał' place=3
-- UNMATCHED (score<80): 'MIKOŁAJCZUK Norbert' place=4
-- Compute scores for PP1-V0-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V0-M-SABRE-2024-2025')
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
    'PP2-V0-M-SABRE-2024-2025',
    'II Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V0',
    '2024-10-27', 5, 'https://www.fencingtimelive.com/events/results/C4272CCB419B42D48F19713296E0B887',
    'SCORED'
);
-- UNMATCHED (score<80): 'ROMANOWICZ Aleksiej' place=1
-- UNMATCHED (score<80): 'REDZIŃSKI Michał' place=2
-- UNMATCHED (score<80): 'MIKOŁAJCZUK Norbert' place=3
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    105,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V0-M-SABRE-2024-2025'),
    4,
    'KIEROŃSKI Tomasz'
); -- matched: KIEROŃSKI Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    10,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V0-M-SABRE-2024-2025'),
    5,
    'BARTUSIK Grzegorz'
); -- matched: BARTUSIK Grzegorz (score=100.0)
-- Compute scores for PP2-V0-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V0-M-SABRE-2024-2025')
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
    'PP3-V0-M-SABRE-2024-2025',
    'III Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V0',
    '2024-12-01', 4, 'https://www.fencingtimelive.com/events/results/B51CBF7971F3469C9DC57AF0E550CF71',
    'SCORED'
);
-- UNMATCHED (score<80): 'ROMANOWICZ Aleksiej' place=1
-- UNMATCHED (score<80): 'REDZIŃSKI MICHAŁ' place=2
-- UNMATCHED (score<80): 'MIKOŁAJCZUK Norbert' place=3
-- UNMATCHED (score<80): 'SPŁAWA-NEYMAN MACIEJ' place=4
-- Compute scores for PP3-V0-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V0-M-SABRE-2024-2025')
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
    'MPW-V0-M-SABRE-2024-2025',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'SABRE', 'M', 'V0',
    '2025-06-08', 4, 'https://www.fencingtimelive.com/events/results/F9D8E8B813504A5BA2CA1F2D9F5C814B',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    109,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-SABRE-2024-2025'),
    1,
    'KMIECIK Adam'
); -- matched: KMIECIK Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-SABRE-2024-2025'),
    2,
    'GĘZIKIEWICZ Marcin'
); -- matched: GĘZIKIEWICZ Marcin (score=100.0)
-- UNMATCHED (score<80): 'REDZIŃSKI Michał' place=3
-- UNMATCHED (score<80): 'STANISŁAWSKI Albert' place=4
-- Compute scores for MPW-V0-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-SABRE-2024-2025')
);

-- Summary
-- Total results matched:   5
-- Total results unmatched: 12
