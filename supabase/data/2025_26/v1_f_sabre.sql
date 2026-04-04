-- =========================================================================
-- Season 2025-2026 — V1 F SABRE — generated from SZABLA-K1-2025-2026.xlsx
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
    'PPW1-V1-F-SABRE-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'F', 'V1',
    NULL, 1, 'https://www.fencingtimelive.com/events/results/4BFB941753FB48A0852F9DDAF07B5284',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    66,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-F-SABRE-2025-2026'),
    1,
    'GAWLE Katarzyna'
); -- matched: GAWLE Katarzyna (score=100.0)
-- Compute scores for PPW1-V1-F-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-F-SABRE-2025-2026')
);

-- ---- PP2: II Puchar Polski Weteranów (SZABLA WETERANI KOBIETY 1) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW2-2025-2026',
    'II Puchar Polski Weteranów',
    'SZABLA WETERANI KOBIETY 1',
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
    'PPW2-V1-F-SABRE-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'F', 'V1',
    NULL, 1, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    66,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-F-SABRE-2025-2026'),
    1,
    'GAWLE Katarzyna'
); -- matched: GAWLE Katarzyna (score=100.0)
-- Compute scores for PPW2-V1-F-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-F-SABRE-2025-2026')
);

-- SKIP PP3 (III Puchar Polski Weteranów): N=0 — tournament had no participants

-- SKIP PP4 (IV Puchar Polski Weteranów): N=0 — tournament had no participants

-- SKIP PP5 (V Puchar Polski Weteranów): N=0 — tournament had no participants
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
    'PEW2-V1-F-SABRE-2025-2026',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'SABRE', 'F', 'V1',
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
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-F-SABRE-2025-2026'),
    17,
    'MARTIN CID'
); -- matched: KAZIK Martin (score=72.72727272727273)
-- SKIPPED (international, no master data): 'BERNARDO DA SILVA FRANCA' place=18
-- SKIPPED (international, no master data): 'STOKKERMANS' place=19
-- SKIPPED (international, no master data): 'AYUSO PEÑAS' place=20
-- SKIPPED (international, no master data): 'BUENO DIEZ' place=21
-- SKIPPED (international, no master data): 'GREEN' place=22
-- Compute scores for PEW2-V1-F-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-F-SABRE-2025-2026')
);

-- SKIP PEW3 (EVF Grand Prix 3): N=0 — tournament had no participants

-- SKIP PEW4 (EVF Grand Prix 4): N=0 — tournament had no participants

-- SKIP PEW5 (EVF Grand Prix 5): N=0 — tournament had no participants

-- SKIP PEW6 (EVF Grand Prix 6): N=0 — tournament had no participants

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): N=0 — tournament had no participants

-- SKIP PEW8 (EVF Grand Prix 8 — Guildford): N=0 — tournament had no participants

-- SKIP PEW9 (EVF Grand Prix 9 — Sztokholm): N=0 — tournament had no participants

-- SKIP PS (Puchar Świata): N=0 — tournament had no participants

-- Summary
-- Total results matched:   4
-- Total results unmatched: 21
-- Total auto-created:      0
