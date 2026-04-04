-- =========================================================================
-- Season 2024-2025 — V3 F FOIL — generated from FLORET-K3-2024-2025.xlsx
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
    'PPW1-V3-F-FOIL-2024-2025',
    'I Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'F', 'V3',
    '2024-09-29', 2, 'https://www.fencingtimelive.com/events/results/45A8E050DF5F43BEA56D3507A9E22CFF',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    23,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-F-FOIL-2024-2025'),
    1,
    'BORKOWSKA Halina'
); -- matched: BORKOWSKA Halina (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    198,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-F-FOIL-2024-2025'),
    2,
    'OWCZAREK Elżbieta'
); -- matched: OWCZAREK Elżbieta (score=100.0)
-- Compute scores for PPW1-V3-F-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-F-FOIL-2024-2025')
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
    'PPW2-V3-F-FOIL-2024-2025',
    'II Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'F', 'V3',
    '2024-10-27', 2, 'https://www.fencingtimelive.com/events/results/1467EB778171493AA4308B598EF2C52C',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    198,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-F-FOIL-2024-2025'),
    1,
    'OWCZAREK Elżbieta'
); -- matched: OWCZAREK Elżbieta (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    182,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-F-FOIL-2024-2025'),
    2,
    'MULSON Irena'
); -- matched: MULSON Irena (score=100.0)
-- Compute scores for PPW2-V3-F-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-F-FOIL-2024-2025')
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
    'PPW3-V3-F-FOIL-2024-2025',
    'III Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'F', 'V3',
    '2024-12-01', 3, 'https://www.fencingtimelive.com/events/results/8E245574508E443C8F07E199FD5495FE',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    182,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-F-FOIL-2024-2025'),
    1,
    'MULSON Irena'
); -- matched: MULSON Irena (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    198,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-F-FOIL-2024-2025'),
    2,
    'OWCZAREK ELŻBIETA'
); -- matched: OWCZAREK Elżbieta (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    180,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-F-FOIL-2024-2025'),
    3,
    'MILOVA Tatiana'
); -- matched: MILOVA Tatiana (score=100.0)
-- Compute scores for PPW3-V3-F-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-F-FOIL-2024-2025')
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
    'PPW4-V3-F-FOIL-2024-2025',
    'IV Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'F', 'V3',
    '2025-02-23', 3, 'https://www.fencingtimelive.com/events/results/C5B5588A431C42F0BF9FDB049B051A50',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    182,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-F-FOIL-2024-2025'),
    1,
    'MULSON Irena'
); -- matched: MULSON Irena (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    198,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-F-FOIL-2024-2025'),
    2,
    'OWCZAREK ELŻBIETA'
); -- matched: OWCZAREK Elżbieta (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    23,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-F-FOIL-2024-2025'),
    3,
    'BORKOWSKA Halina'
); -- matched: BORKOWSKA Halina (score=100.0)
-- Compute scores for PPW4-V3-F-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-F-FOIL-2024-2025')
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
    'PPW5-V3-F-FOIL-2024-2025',
    'V Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'F', 'V3',
    '2025-04-27', 1, 'https://www.fencingtimelive.com/events/results/1B2C70B599F547299014C7E42AE198E6',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    198,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V3-F-FOIL-2024-2025'),
    1,
    'OWCZAREK Elżbieta'
); -- matched: OWCZAREK Elżbieta (score=100.0)
-- Compute scores for PPW5-V3-F-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V3-F-FOIL-2024-2025')
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
    'MPW-V3-F-FOIL-2024-2025',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'FOIL', 'F', 'V3',
    '2025-06-08', 2, 'https://www.fencingtimelive.com/events/results/FD370EE42A1A4E88AEAC909EDD1EC3DA',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    198,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-F-FOIL-2024-2025'),
    1,
    'OWCZAREK Elżbieta'
); -- matched: OWCZAREK Elżbieta (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    182,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-F-FOIL-2024-2025'),
    2,
    'MULSON Irena'
); -- matched: MULSON Irena (score=100.0)
-- Compute scores for MPW-V3-F-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-F-FOIL-2024-2025')
);

-- SKIP PEW1 (EVF Grand Prix 1 — Budapeszt): 0 matched fencers in DB — tournament not created

-- SKIP PEW2 (EVF Grand Prix 2 — Madryt): N=0 — tournament had no participants

-- SKIP PEW3 (EVF Grand Prix 3): N=0 — tournament had no participants

-- SKIP PEW4 (EVF Grand Prix 4): N=0 — tournament had no participants

-- SKIP PEW5 (EVF Grand Prix 5): N=0 — tournament had no participants

-- SKIP PEW6 (EVF Grand Prix 6): N=0 — tournament had no participants

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): N=0 — tournament had no participants

-- SKIP PEW8 (EVF Grand Prix 8 — Guildford): N=0 — tournament had no participants

-- SKIP PS (Puchar Świata): N=0 — tournament had no participants

-- SKIP IMEW (Indywidualne Mistrzostwa Europy Weteranów): N=0 — tournament had no participants

-- Summary
-- Total results matched:   13
-- Total results unmatched: 0
-- Total auto-created:      0
