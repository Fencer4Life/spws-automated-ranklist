-- =========================================================================
-- Season 2024-2025 — V2 F SABRE — generated from SZABLA-K2-2024-2025.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- SKIP PP1 (I Puchar Polski Weteranów): N=0 — tournament had no participants

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
    'PP2-V2-F-SABRE-2024-2025',
    'II Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'F', 'V2',
    '2024-10-27', 1, 'https://www.fencingtimelive.com/events/results/2D4BB7F8144A441C89EB7968A2AAF622',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    47,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V2-F-SABRE-2024-2025'),
    1,
    'DWORAKOWSKA-BANAŚ Agnieszka'
); -- matched: DWORAKOWSKA-BANAŚ Agnieszka (score=100.0)
-- Compute scores for PP2-V2-F-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V2-F-SABRE-2024-2025')
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
    'PP3-V2-F-SABRE-2024-2025',
    'III Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'F', 'V2',
    '2024-12-01', 1, 'https://www.fencingtimelive.com/events/results/BDA01BA67FE3481998EF770A16A1FAED',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    47,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-F-SABRE-2024-2025'),
    1,
    'DWORAKOWSKA-BANAŚ AGNIESZKA'
); -- matched: DWORAKOWSKA-BANAŚ Agnieszka (score=100.0)
-- Compute scores for PP3-V2-F-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-F-SABRE-2024-2025')
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
    'MPW-V2-F-SABRE-2024-2025',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'SABRE', 'F', 'V2',
    '2025-06-08', 2, 'https://www.fencingtimelive.com/events/results/CF111F026D3D4B778F791112A113642C',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    47,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-F-SABRE-2024-2025'),
    1,
    'DWORAKOWSKA-BANAŚ Agnieszka'
); -- matched: DWORAKOWSKA-BANAŚ Agnieszka (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    154,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-F-SABRE-2024-2025'),
    2,
    'MILCZAREK Renata'
); -- matched: MILCZAREK Renata (score=100.0)
-- Compute scores for MPW-V2-F-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-F-SABRE-2024-2025')
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
    'PEW1-V2-F-SABRE-2024-2025',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'SABRE', 'F', 'V2',
    '2024-09-22', 7, 'https://engarde-service.com/app.php?id=4212R2',
    'SCORED'
);
-- Compute scores for PEW1-V2-F-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-F-SABRE-2024-2025')
);

-- SKIP PEW2 (EVF Grand Prix 2 — Madryt): N=0 — tournament had no participants

-- ---- PEW7: EVF Grand Prix 7 — Terni (Warszawa) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW7-2024-2025',
    'EVF Grand Prix 7 — Terni',
    'Warszawa',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW7-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW7-2024-2025'),
    'PEW7-V2-F-SABRE-2024-2025',
    'EVF Grand Prix 7 — Terni',
    'PEW',
    'SABRE', 'F', 'V2',
    '2025-03-29', 9, 'https://www.fencingtimelive.com/events/results/7A759B1F0E454034A2815DDDD347A5E4',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    154,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-F-SABRE-2024-2025'),
    9,
    'MILCZAREK Renata'
); -- matched: MILCZAREK Renata (score=100.0)
-- Compute scores for PEW7-V2-F-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-F-SABRE-2024-2025')
);

-- SKIP PEW8 (EVF Grand Prix 8 — Guildford): N=0 — tournament had no participants

-- SKIP PEW9 (EVF Grand Prix 9 — Sztokholm): N=0 — tournament had no participants

-- SKIP IMEW (Indywidualne Mistrzostwa Europy Weteranów): N=0 — tournament had no participants

-- Summary
-- Total results matched:   5
-- Total results unmatched: 0
