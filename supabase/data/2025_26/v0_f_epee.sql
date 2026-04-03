-- =========================================================================
-- Season 2025-2026 — V0 F EPEE — generated from SZPADA-K0-2025-2026.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- ---- PP1: I Puchar Polski Weteranów (Szpada kobiet Weterani 0) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW1-2025-2026',
    'I Puchar Polski Weteranów',
    'Szpada kobiet Weterani 0',
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
    'PPW1-V0-F-EPEE-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'F', 'V0',
    NULL, 2, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    337,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-F-EPEE-2025-2026'),
    1,
    'PĘCZEK Sandra'
); -- matched: PĘCZEK Sandra (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    111,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-F-EPEE-2025-2026'),
    2,
    'KOCÓR Agata'
); -- matched: KOCÓR Agata (score=100.0)
-- Compute scores for PPW1-V0-F-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-F-EPEE-2025-2026')
);

-- ---- PP2: II Puchar Polski Weteranów (SZPADA KOBIETY 0 WETERANI) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW2-2025-2026',
    'II Puchar Polski Weteranów',
    'SZPADA KOBIETY 0 WETERANI',
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
    'PPW2-V0-F-EPEE-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'F', 'V0',
    NULL, 2, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    304,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-F-EPEE-2025-2026'),
    1,
    'KRUJALSKIENE Julija'
); -- matched: KRUJALSKIENE Julija (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    111,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-F-EPEE-2025-2026'),
    2,
    'KOCÓR Agata'
); -- matched: KOCÓR Agata (score=100.0)
-- Compute scores for PPW2-V0-F-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-F-EPEE-2025-2026')
);

-- ---- PP3: III Puchar Polski Weteranów (Szpada Kobiet kat. 0) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW3-2025-2026',
    'III Puchar Polski Weteranów',
    'Szpada Kobiet kat. 0',
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
    'PPW3-V0-F-EPEE-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'F', 'V0',
    NULL, 5, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    337,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-F-EPEE-2025-2026'),
    1,
    'PĘCZEK Sandra'
); -- matched: PĘCZEK Sandra (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    359,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-F-EPEE-2025-2026'),
    2,
    'SZMAJDZIŃSKA - BOŁDYS Katarzyna'
); -- matched: SZMAJDZIŃSKA - BOŁDYS Katarzyna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    89,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-F-EPEE-2025-2026'),
    3,
    'IRZYK Sabina'
); -- matched: IRZYK Sabina (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    43,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-F-EPEE-2025-2026'),
    4,
    'DRAPELLA Magdalena'
); -- matched: DRAPELLA Magdalena (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-F-EPEE-2025-2026'),
    5,
    'GÓRNA Karolina'
); -- matched: GÓRNA Karolina (score=100.0)
-- Compute scores for PPW3-V0-F-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-F-EPEE-2025-2026')
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
    'PPW4-V0-F-EPEE-2025-2026',
    'IV Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'F', 'V0',
    '2026-02-21', 3, 'https://fencingtimelive.com/events/results/48791095BA20459E8C815D9CA6070097',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    359,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-F-EPEE-2025-2026'),
    1,
    'SZMAJDZIŃSKA - BOŁDYS Katarzyna'
); -- matched: SZMAJDZIŃSKA - BOŁDYS Katarzyna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-F-EPEE-2025-2026'),
    2,
    'GÓRNA Karolina'
); -- matched: GÓRNA Karolina (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    43,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-F-EPEE-2025-2026'),
    3,
    'DRAPELLA Magdalena'
); -- matched: DRAPELLA Magdalena (score=100.0)
-- Compute scores for PPW4-V0-F-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-F-EPEE-2025-2026')
);

-- SKIP PP5: event not yet held (SCHEDULED) — results are rolling carry-over from previous season

-- SKIP MPW: event not yet held (SCHEDULED) — results are rolling carry-over from previous season

-- Summary
-- Total results matched:   16
-- Total results unmatched: 0
