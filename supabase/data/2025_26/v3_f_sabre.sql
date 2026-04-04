-- =========================================================================
-- Season 2025-2026 — V3 F SABRE — generated from SZABLA-K3-2025-2026.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- ---- PP1: I Puchar Polski Weteranów (Szabla kobiet 1+2+3 + 4) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW1-2025-2026',
    'I Puchar Polski Weteranów',
    'Szabla kobiet 1+2+3 + 4',
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
    'PPW1-V3-F-SABRE-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'F', 'V3',
    NULL, 1, 'https://www.fencingtimelive.com/events/results/4BFB941753FB48A0852F9DDAF07B5284',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    198,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-F-SABRE-2025-2026'),
    1,
    'OWCZAREK Elżbieta'
); -- matched: OWCZAREK Elżbieta (score=100.0)
-- Compute scores for PPW1-V3-F-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-F-SABRE-2025-2026')
);

-- ---- PP2: II Puchar Polski Weteranów (SZABLA WETERANI KOBIET 3) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW2-2025-2026',
    'II Puchar Polski Weteranów',
    'SZABLA WETERANI KOBIET 3',
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
    'PPW2-V3-F-SABRE-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'F', 'V3',
    NULL, 1, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    198,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-F-SABRE-2025-2026'),
    1,
    'OWCZAREK ELŻBIETA'
); -- matched: OWCZAREK Elżbieta (score=100.0)
-- Compute scores for PPW2-V3-F-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-F-SABRE-2025-2026')
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
    'PPW3-V3-F-SABRE-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'F', 'V3',
    '2024-12-14', 1, 'https://www.fencingtimelive.com/events/results/EE1ED81AF6FE4D09B5C522D310B163B0',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    60,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-F-SABRE-2025-2026'),
    1,
    'FUHRMANN Ulrike'
); -- matched: FUHRMANN Ulrike (score=100.0)
-- Compute scores for PPW3-V3-F-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-F-SABRE-2025-2026')
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
    'PPW4-V3-F-SABRE-2025-2026',
    'IV Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'F', 'V3',
    '2026-02-21', 2, 'https://fencingtimelive.com/events/results/F74D5C426B2542B0A81FC7EA51BECDA8',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    60,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-F-SABRE-2025-2026'),
    1,
    'FUHRMANN Ulrike'
); -- matched: FUHRMANN Ulrike (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    198,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-F-SABRE-2025-2026'),
    2,
    'OWCZAREK Elżbieta'
); -- matched: OWCZAREK Elżbieta (score=100.0)
-- Compute scores for PPW4-V3-F-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-F-SABRE-2025-2026')
);
-- ---- PEW2: EVF Grand Prix 2 — Madryt (VI Ciudad de Madrid CUP VETERANS FENCING) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW2-2025-2026',
    'EVF Grand Prix 2 — Madryt',
    'VI Ciudad de Madrid CUP VETERANS FENCING',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW2-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW2-2025-2026'),
    'PEW2-V3-F-SABRE-2025-2026',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'SABRE', 'F', 'V3',
    NULL, 22, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'HORI' place=1
-- SKIPPED (international, no master data): 'DI MARTINO' place=2
-- SKIPPED (international, no master data): 'YANO' place=3
-- SKIPPED (international, no master data): 'ALBINI' place=4
-- SKIPPED (international, no master data): 'COLAIACOMO' place=5
-- SKIPPED (international, no master data): 'MORENO BLASCO' place=6
-- SKIPPED (international, no master data): 'URBANO PRADA' place=7
-- SKIPPED (international, no master data): 'DE RIOJA MEDIAVILLA' place=8
-- SKIPPED (international, no master data): 'MELGAREJO QUIRÓS' place=9
-- SKIPPED (international, no master data): 'SIRACUSANO' place=10
-- SKIPPED (international, no master data): 'ROUSSELOT' place=11
-- SKIPPED (international, no master data): 'PADURA MUGICA' place=12
-- SKIPPED (international, no master data): 'RAINER' place=13
-- SKIPPED (international, no master data): 'LUJAN' place=14
-- SKIPPED (international, no master data): 'TRAPANESE' place=15
-- SKIPPED (international, no master data): 'VILLARRUBIA' place=16
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    112,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V3-F-SABRE-2025-2026'),
    17,
    'MARTIN CID'
); -- matched: KAZIK Martin (score=72.72727272727273)
-- SKIPPED (international, no master data): 'BERNARDO DA SILVA FRANCA' place=18
-- SKIPPED (international, no master data): 'STOKKERMANS' place=19
-- SKIPPED (international, no master data): 'AYUSO PEÑAS' place=20
-- SKIPPED (international, no master data): 'BUENO DIEZ' place=21
-- SKIPPED (international, no master data): 'GREEN' place=22
-- Compute scores for PEW2-V3-F-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V3-F-SABRE-2025-2026')
);

-- ---- PEW3: EVF Grand Prix 3 (Munich) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW3-2025-2026',
    'EVF Grand Prix 3',
    'Munich',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW3-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW3-2025-2026'),
    'PEW3-V3-F-SABRE-2025-2026',
    'EVF Grand Prix 3',
    'PEW',
    'SABRE', 'F', 'V3',
    '2025-12-06', 11, 'https://www.fencingworldwide.com/en/912303-2025/results/',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    60,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-F-SABRE-2025-2026'),
    5,
    'FUHRMANN Ulrike'
); -- matched: FUHRMANN Ulrike (score=100.0)
-- Compute scores for PEW3-V3-F-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-F-SABRE-2025-2026')
);

-- SKIP PEW4 (EVF Grand Prix 4): N=0 — tournament had no participants

-- SKIP PEW5 (EVF Grand Prix 5): N=0 — tournament had no participants

-- SKIP PEW6 (EVF Grand Prix 6): N=0 — tournament had no participants

-- ---- PEW7: EVF Grand Prix 7 — Terni (Warszawa) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW7-2025-2026',
    'EVF Grand Prix 7 — Terni',
    'Warszawa',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW7-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW7-2025-2026'),
    'PEW7-V3-F-SABRE-2025-2026',
    'EVF Grand Prix 7 — Terni',
    'PEW',
    'SABRE', 'F', 'V3',
    '2026-03-29', 6, 'https://www.fencingtimelive.com/events/results/995A71DD9D7C41A188598CB4766D651B',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    198,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V3-F-SABRE-2025-2026'),
    6,
    'OWCZAREK Elżbieta'
); -- matched: OWCZAREK Elżbieta (score=100.0)
-- Compute scores for PEW7-V3-F-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V3-F-SABRE-2025-2026')
);

-- SKIP PEW8 (EVF Grand Prix 8 — Guildford): N=0 — tournament had no participants

-- SKIP PEW9 (EVF Grand Prix 9 — Sztokholm): N=0 — tournament had no participants

-- SKIP PS (Puchar Świata): N=0 — tournament had no participants

-- Summary
-- Total results matched:   13
-- Total results unmatched: 21
-- Total auto-created:      0
