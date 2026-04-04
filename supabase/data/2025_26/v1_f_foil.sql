-- =========================================================================
-- Season 2025-2026 — V1 F FOIL — generated from FLORET-K1-2025-2026.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- SKIP PP1 (I Puchar Polski Weteranów): N=0 — tournament had no participants

-- SKIP PP2 (II Puchar Polski Weteranów): N=0 — tournament had no participants

-- SKIP PP3 (III Puchar Polski Weteranów): N=0 — tournament had no participants

-- SKIP PP4 (IV Puchar Polski Weteranów): N=0 — tournament had no participants

-- SKIP PP5 (V Puchar Polski Weteranów): N=0 — tournament had no participants

-- SKIP MPW (Mistrzostwa Polski Weteranów): N=0 — tournament had no participants

-- ---- PEW1: EVF Grand Prix 1 — Budapeszt (Budapest) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW1-2025-2026',
    'EVF Grand Prix 1 — Budapeszt',
    'Budapest',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW1-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1-2025-2026'),
    'PEW1-V1-F-FOIL-2025-2026',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'FOIL', 'F', 'V1',
    '2025-09-21', 9, 'https://engarde-service.com/competition/hunfencing/2025_09_21_tor/wf40',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    237,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-F-FOIL-2025-2026'),
    9,
    'SAMECKA-NACZYŃSKA Martyna'
); -- matched: SAMECKA-NACZYŃSKA Martyna (score=100.0)
-- Compute scores for PEW1-V1-F-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-F-FOIL-2025-2026')
);

-- SKIP PEW2 (EVF Grand Prix 2 — Madryt): N=0 — tournament had no participants

-- SKIP PEW3 (EVF Grand Prix 3): N=0 — tournament had no participants

-- SKIP PEW4 (EVF Grand Prix 4): N=0 — tournament had no participants

-- SKIP PEW5 (EVF Grand Prix 5): N=0 — tournament had no participants

-- SKIP PEW6 (EVF Grand Prix 6): N=0 — tournament had no participants

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): N=0 — tournament had no participants

-- ---- PEW8: EVF Grand Prix 8 — Guildford (WARSZAWA) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW8-2025-2026',
    'EVF Grand Prix 8 — Guildford',
    'WARSZAWA',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW8-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW8-2025-2026'),
    'PEW8-V1-F-FOIL-2025-2026',
    'EVF Grand Prix 8 — Guildford',
    'PEW',
    'FOIL', 'F', 'V1',
    '2025-03-29', 4, 'https://www.fencingtimelive.com/events/results/0CE4ACDC019D4ECCBBF70D80D7F0B685',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    158,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V1-F-FOIL-2025-2026'),
    3,
    'LIPKOWSKA Dominika'
); -- matched: LIPKOWSKA Dominika (score=100.0)
-- Compute scores for PEW8-V1-F-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V1-F-FOIL-2025-2026')
);

-- SKIP PS (Puchar Świata): N=0 — tournament had no participants

-- Summary
-- Total results matched:   2
-- Total results unmatched: 0
-- Total auto-created:      0
