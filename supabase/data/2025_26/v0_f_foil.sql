-- =========================================================================
-- Season 2025-2026 — V0 F FOIL — generated from FLORET-K0-2025-2026.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- SKIP PP1 (I Puchar Polski Weteranów): N=0 — tournament had no participants

-- ---- PP2: II Puchar Polski Weteranów (POZNAŃ) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW2-2025-2026',
    'II Puchar Polski Weteranów',
    'POZNAŃ',
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
    'PPW2-V0-F-FOIL-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'F', 'V0',
    '2025-10-25', 1, 'https://www.fencingtimelive.com/events/results/D8131FF685714FCD9BCE050A79E2EEE0',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    231,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-F-FOIL-2025-2026'),
    1,
    'RZEPECKA Martyna'
); -- matched: RZEPECKA Martyna (score=100.0)
-- Compute scores for PPW2-V0-F-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-F-FOIL-2025-2026')
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
    'PPW3-V0-F-FOIL-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'F', 'V0',
    '2025-12-13', 2, 'https://www.fencingtimelive.com/events/results/8C9EB0FFE48241D6ABB5FB0E54475042',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    231,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-F-FOIL-2025-2026'),
    1,
    'RZEPECKA Martyna'
); -- matched: RZEPECKA Martyna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    47,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-F-FOIL-2025-2026'),
    2,
    'DRAPELLA Magdalena'
); -- matched: DRAPELLA Magdalena (score=100.0)
-- Compute scores for PPW3-V0-F-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-F-FOIL-2025-2026')
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
    'PPW4-V0-F-FOIL-2025-2026',
    'IV Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'F', 'V0',
    '2026-02-21', 2, 'https://fencingtimelive.com/events/results/BA2A40142D714F9E97E298CCBF43AE12',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    47,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-F-FOIL-2025-2026'),
    1,
    'DRAPELLA Magdalena'
); -- matched: DRAPELLA Magdalena (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    231,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-F-FOIL-2025-2026'),
    2,
    'RZEPECKA Martyna'
); -- matched: RZEPECKA Martyna (score=100.0)
-- Compute scores for PPW4-V0-F-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-F-FOIL-2025-2026')
);

-- SKIP PP5 (V Puchar Polski Weteranów): N=0 — tournament had no participants

-- SKIP MPW (Mistrzostwa Polski Weteranów): N=0 — tournament had no participants

-- Summary
-- Total results matched:   5
-- Total results unmatched: 0
-- Total auto-created:      0
