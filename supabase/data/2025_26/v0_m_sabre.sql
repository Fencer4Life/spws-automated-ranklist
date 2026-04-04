-- =========================================================================
-- Season 2025-2026 — V0 M SABRE — generated from SZABLA-0-2025-2026.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- ---- PP1: I Puchar Polski Weteranów (Szabla Weterani Mężczyzn 0) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW1-2025-2026',
    'I Puchar Polski Weteranów',
    'Szabla Weterani Mężczyzn 0',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW1-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW1-2025-2026'),
    'PPW1-V0-M-SABRE-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V0',
    NULL, 3, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    225,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-SABRE-2025-2026'),
    1,
    'ROMANOWICZ Aleksiej'
); -- matched: ROMANOWICZ Aleksiej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    32,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-SABRE-2025-2026'),
    2,
    'CHARKIEWICZ Paweł'
); -- matched: CHARKIEWICZ Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    44,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-SABRE-2025-2026'),
    3,
    'DOMAŃSKI Sławomir'
); -- matched: DOMAŃSKI Sławomir (score=100.0)
-- Compute scores for PPW1-V0-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-SABRE-2025-2026')
);

-- ---- PP2: II Puchar Polski Weteranów (SZABLA WETERANI MĘŻCZYZNI 0) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW2-2025-2026',
    'II Puchar Polski Weteranów',
    'SZABLA WETERANI MĘŻCZYZNI 0',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW2-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW2-2025-2026'),
    'PPW2-V0-M-SABRE-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V0',
    NULL, 3, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    252,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-SABRE-2025-2026'),
    1,
    'STANISŁAWSKI Albert'
); -- matched: STANISŁAWSKI Albert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    89,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-SABRE-2025-2026'),
    2,
    'GĘZIKIEWICZ Marcin'
); -- matched: GĘZIKIEWICZ Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    35,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-SABRE-2025-2026'),
    3,
    'CHOJNACKI Tomasz'
); -- matched: CHOJNACKI Tomasz (score=100.0)
-- Compute scores for PPW2-V0-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-SABRE-2025-2026')
);

-- ---- PP3: III Puchar Polski Weteranów (ŁOMIANKI) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW3-2025-2026',
    'III Puchar Polski Weteranów',
    'ŁOMIANKI',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW3-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW3-2025-2026'),
    'PPW3-V0-M-SABRE-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V0',
    '2025-12-14', 3, 'https://www.fencingtimelive.com/events/results/C8BF5C742C174649BA00F319CE2B3A58',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    252,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-SABRE-2025-2026'),
    1,
    'STANISŁAWSKI Albert'
); -- matched: STANISŁAWSKI Albert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    276,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-SABRE-2025-2026'),
    2,
    'TECŁAW (1) Robert'
); -- matched: TECŁAW Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    307,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-SABRE-2025-2026'),
    3,
    'ZAJĄC (1) Michał'
); -- matched: ZAJĄC Michał (score=100.0)
-- Compute scores for PPW3-V0-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-SABRE-2025-2026')
);

-- ---- PP4: IV Puchar Polski Weteranów (GDAŃSK) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW4-2025-2026',
    'IV Puchar Polski Weteranów',
    'GDAŃSK',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW4-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW4-2025-2026'),
    'PPW4-V0-M-SABRE-2025-2026',
    'IV Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V0',
    '2026-02-21', 1, 'https://fencingtimelive.com/events/results/4793BEF489D848EDB24851784C0AC6D0',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    159,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-SABRE-2025-2026'),
    1,
    'LISOWSKI Igor'
); -- matched: LISOWSKI Igor (score=100.0)
-- Compute scores for PPW4-V0-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-SABRE-2025-2026')
);
-- Summary
-- Total results matched:   18
-- Total results unmatched: 0
-- Total auto-created:      0
