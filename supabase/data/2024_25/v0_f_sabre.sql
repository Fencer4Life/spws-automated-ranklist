-- =========================================================================
-- Season 2024-2025 — V0 F SABRE — generated from SZABLA-K0-2024-2025.xlsx
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
    'PPW1-V0-F-SABRE-2024-2025',
    'I Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'F', 'V0',
    '2024-09-29', 3, 'https://www.fencingtimelive.com/events/results/18DE54D93E744EE0AE8A3EA9F3695D1D',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    199,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-F-SABRE-2024-2025'),
    1,
    'OWCZAREK Ewelina'
); -- matched: OWCZAREK Ewelina (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    90,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-F-SABRE-2024-2025'),
    2,
    'HAJDAS Martyna'
); -- matched: HAJDAS Martyna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    137,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-F-SABRE-2024-2025'),
    3,
    'KOZAK Marta'
); -- matched: KOZAK Marta (score=100.0)
-- Compute scores for PPW1-V0-F-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-F-SABRE-2024-2025')
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
    'PPW2-V0-F-SABRE-2024-2025',
    'II Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'F', 'V0',
    '2024-10-27', 3, 'https://www.fencingtimelive.com/events/results/2D4BB7F8144A441C89EB7968A2AAF622',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    90,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-F-SABRE-2024-2025'),
    1,
    'HAJDAS Martyna'
); -- matched: HAJDAS Martyna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    199,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-F-SABRE-2024-2025'),
    2,
    'OWCZAREK Ewelina'
); -- matched: OWCZAREK Ewelina (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    110,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-F-SABRE-2024-2025'),
    3,
    'KARWAT Aleksandra'
); -- matched: KARWAT Aleksandra (score=100.0)
-- Compute scores for PPW2-V0-F-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-F-SABRE-2024-2025')
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
    'PPW3-V0-F-SABRE-2024-2025',
    'III Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'F', 'V0',
    '2024-12-01', 2, 'https://www.fencingtimelive.com/events/results/BDA01BA67FE3481998EF770A16A1FAED',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    199,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-F-SABRE-2024-2025'),
    1,
    'OWCZAREK Ewelina'
); -- matched: OWCZAREK Ewelina (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    110,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-F-SABRE-2024-2025'),
    2,
    'KARWAT ALEKSANDRA'
); -- matched: KARWAT Aleksandra (score=100.0)
-- Compute scores for PPW3-V0-F-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-F-SABRE-2024-2025')
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
    'PPW4-V0-F-SABRE-2024-2025',
    'IV Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'F', 'V0',
    '2025-02-23', 4, 'https://www.fencingtimelive.com/events/results/148C86FD0FB14C4BADC5ACE268EB364A',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    90,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-F-SABRE-2024-2025'),
    1,
    'HAJDAS Martyna'
); -- matched: HAJDAS Martyna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    292,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-F-SABRE-2024-2025'),
    2,
    'WIERZBA Weronika'
); -- matched: WIERZBA Weronika (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    199,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-F-SABRE-2024-2025'),
    3,
    'OWCZAREK Ewelina'
); -- matched: OWCZAREK Ewelina (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    110,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-F-SABRE-2024-2025'),
    4,
    'KARWAT ALEKSANDRA'
); -- matched: KARWAT Aleksandra (score=100.0)
-- Compute scores for PPW4-V0-F-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-F-SABRE-2024-2025')
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
    'PPW5-V0-F-SABRE-2024-2025',
    'V Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'F', 'V0',
    '2025-04-27', 1, 'https://www.fencingtimelive.com/events/results/3BEAF65911D44FCE9B7739AFBBB9EC99',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    199,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V0-F-SABRE-2024-2025'),
    1,
    'OWCZAREK Ewelina'
); -- matched: OWCZAREK Ewelina (score=100.0)
-- Compute scores for PPW5-V0-F-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V0-F-SABRE-2024-2025')
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
    'MPW-V0-F-SABRE-2024-2025',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'SABRE', 'F', 'V0',
    '2025-06-08', 2, 'https://www.fencingtimelive.com/events/results/CF111F026D3D4B778F791112A113642C',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    199,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-F-SABRE-2024-2025'),
    1,
    'OWCZAREK Ewelina'
); -- matched: OWCZAREK Ewelina (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    90,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-F-SABRE-2024-2025'),
    2,
    'HAJDAS Martyna'
); -- matched: HAJDAS Martyna (score=100.0)
-- Compute scores for MPW-V0-F-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-F-SABRE-2024-2025')
);

-- Summary
-- Total results matched:   15
-- Total results unmatched: 0
-- Total auto-created:      0
