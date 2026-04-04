-- =========================================================================
-- Season 2024-2025 — V0 M SABRE — generated from SZABLA-0-2024-2025.xlsx
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
    'PPW1-V0-M-SABRE-2024-2025',
    'I Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V0',
    '2023-10-23', 4, 'https://www.fencingtimelive.com/events/results/6287FD541EB54557A2D1E2B0AE1D86B5',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    130,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-SABRE-2024-2025'),
    1,
    'KOTSEV Ivan'
); -- matched: KOTSEV Ivan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    89,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-SABRE-2024-2025'),
    2,
    'GĘZIKIEWICZ Marcin'
); -- matched: GĘZIKIEWICZ Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    223,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-SABRE-2024-2025'),
    3,
    'REDZIŃSKI Michał'
); -- matched: REDZIŃSKI Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-SABRE-2024-2025'),
    4,
    'MIKOŁAJCZUK Norbert'
); -- matched: MIKOŁAJCZUK Norbert (score=100.0)
-- Compute scores for PPW1-V0-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-SABRE-2024-2025')
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
    'PPW2-V0-M-SABRE-2024-2025',
    'II Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V0',
    '2024-10-27', 5, 'https://www.fencingtimelive.com/events/results/C4272CCB419B42D48F19713296E0B887',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    225,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-SABRE-2024-2025'),
    1,
    'ROMANOWICZ Aleksiej'
); -- matched: ROMANOWICZ Aleksiej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    223,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-SABRE-2024-2025'),
    2,
    'REDZIŃSKI Michał'
); -- matched: REDZIŃSKI Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-SABRE-2024-2025'),
    3,
    'MIKOŁAJCZUK Norbert'
); -- matched: MIKOŁAJCZUK Norbert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    113,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-SABRE-2024-2025'),
    4,
    'KIEROŃSKI Tomasz'
); -- matched: KIEROŃSKI Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    14,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-SABRE-2024-2025'),
    5,
    'BARTUSIK Grzegorz'
); -- matched: BARTUSIK Grzegorz (score=100.0)
-- Compute scores for PPW2-V0-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-SABRE-2024-2025')
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
    'PPW3-V0-M-SABRE-2024-2025',
    'III Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V0',
    '2024-12-01', 4, 'https://www.fencingtimelive.com/events/results/B51CBF7971F3469C9DC57AF0E550CF71',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    225,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-SABRE-2024-2025'),
    1,
    'ROMANOWICZ Aleksiej'
); -- matched: ROMANOWICZ Aleksiej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    223,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-SABRE-2024-2025'),
    2,
    'REDZIŃSKI MICHAŁ'
); -- matched: REDZIŃSKI Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-SABRE-2024-2025'),
    3,
    'MIKOŁAJCZUK Norbert'
); -- matched: MIKOŁAJCZUK Norbert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-SABRE-2024-2025'),
    4,
    'SPŁAWA-NEYMAN MACIEJ'
); -- matched: SPŁAWA-NEYMAN MACIEJ (score=100.0)
-- Compute scores for PPW3-V0-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-SABRE-2024-2025')
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
    'PPW4-V0-M-SABRE-2024-2025',
    'IV Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V0',
    '2025-02-23', 6, 'https://www.fencingtimelive.com/events/results/6229E543DB1945CC809596269EC07F68',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    194,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-SABRE-2024-2025'),
    1,
    'OLBRYCHSKI Antoni'
); -- matched: OLBRYCHSKI Antoni (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    225,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-SABRE-2024-2025'),
    2,
    'ROMANOWICZ Aleksiej'
); -- matched: ROMANOWICZ Aleksiej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-SABRE-2024-2025'),
    3,
    'KMIECIK Adam'
); -- matched: KMIECIK Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-SABRE-2024-2025'),
    4,
    'MIKOŁAJCZUK Norbert'
); -- matched: MIKOŁAJCZUK Norbert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    113,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-SABRE-2024-2025'),
    5,
    'KIEROŃSKI Tomasz'
); -- matched: KIEROŃSKI Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    223,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-SABRE-2024-2025'),
    6,
    'REDZIŃSKI MICHAŁ'
); -- matched: REDZIŃSKI Michał (score=100.0)
-- Compute scores for PPW4-V0-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-SABRE-2024-2025')
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
    'PPW5-V0-M-SABRE-2024-2025',
    'V Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V0',
    '2025-04-26', 4, 'https://www.fencingtimelive.com/events/results/344176CFFBD34C8684BD67F6D63BC4CE',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    130,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V0-M-SABRE-2024-2025'),
    1,
    'KOTSEV Ivan'
); -- matched: KOTSEV Ivan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    225,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V0-M-SABRE-2024-2025'),
    2,
    'ROMANOWICZ Aleksiej'
); -- matched: ROMANOWICZ Aleksiej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    223,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V0-M-SABRE-2024-2025'),
    3,
    'REDZIŃSKI Michał'
); -- matched: REDZIŃSKI Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    301,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V0-M-SABRE-2024-2025'),
    4,
    'WOLAŃSKI Adam'
); -- matched: WOLAŃSKI Adam (score=100.0)
-- Compute scores for PPW5-V0-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V0-M-SABRE-2024-2025')
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
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-SABRE-2024-2025'),
    1,
    'KMIECIK Adam'
); -- matched: KMIECIK Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    89,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-SABRE-2024-2025'),
    2,
    'GĘZIKIEWICZ Marcin'
); -- matched: GĘZIKIEWICZ Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    223,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-SABRE-2024-2025'),
    3,
    'REDZIŃSKI Michał'
); -- matched: REDZIŃSKI Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    252,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-SABRE-2024-2025'),
    4,
    'STANISŁAWSKI Albert'
); -- matched: STANISŁAWSKI Albert (score=100.0)
-- Compute scores for MPW-V0-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-SABRE-2024-2025')
);

-- Summary
-- Total results matched:   27
-- Total results unmatched: 0
-- Total auto-created:      0
