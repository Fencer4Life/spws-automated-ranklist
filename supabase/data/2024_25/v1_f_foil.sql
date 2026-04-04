-- =========================================================================
-- Season 2024-2025 — V1 F FOIL — generated from FLORET-K1-2024-2025.xlsx
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
    'PPW1-V1-F-FOIL-2024-2025',
    'I Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'F', 'V1',
    '2024-09-29', 1, 'https://www.fencingtimelive.com/events/results/D0DC6782B65A465E861CA8FBB48EFAA3',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    158,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-F-FOIL-2024-2025'),
    1,
    'LIPKOWSKA Dominika'
); -- matched: LIPKOWSKA Dominika (score=100.0)
-- Compute scores for PPW1-V1-F-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-F-FOIL-2024-2025')
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
    'PPW2-V1-F-FOIL-2024-2025',
    'II Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'F', 'V1',
    '2024-10-27', 1, 'https://www.fencingtimelive.com/events/results/6DDEF73613864C3689CEE17CF5F2A317',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    158,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-F-FOIL-2024-2025'),
    1,
    'LIPKOWSKA Dominika'
); -- matched: LIPKOWSKA Dominika (score=100.0)
-- Compute scores for PPW2-V1-F-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-F-FOIL-2024-2025')
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
    'PPW3-V1-F-FOIL-2024-2025',
    'III Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'F', 'V1',
    '2024-12-01', 1, 'https://www.fencingtimelive.com/events/results/7DEC106DAD0F4A20972E99EBD16A8C63',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    158,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-F-FOIL-2024-2025'),
    1,
    'LIPKOWSKA Dominika'
); -- matched: LIPKOWSKA Dominika (score=100.0)
-- Compute scores for PPW3-V1-F-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-F-FOIL-2024-2025')
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
    'PPW4-V1-F-FOIL-2024-2025',
    'IV Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'F', 'V1',
    '2025-02-23', 1, 'https://www.fencingtimelive.com/events/results/A0406AC94C3F43D3BDC33E3C62071D53',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    158,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-F-FOIL-2024-2025'),
    1,
    'LIPKOWSKA Dominika'
); -- matched: LIPKOWSKA Dominika (score=100.0)
-- Compute scores for PPW4-V1-F-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-F-FOIL-2024-2025')
);

-- SKIP PP5 (V Puchar Polski Weteranów): N=0 — tournament had no participants

-- SKIP MPW (Mistrzostwa Polski Weteranów): N=0 — tournament had no participants

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
    'PEW1-V1-F-FOIL-2024-2025',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'FOIL', 'F', 'V1',
    '2024-09-22', 8, 'https://engarde-service.com/app.php?id=4210H1',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    237,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-F-FOIL-2024-2025'),
    8,
    'SAMECKA-NACZYŃSKA Martyna'
); -- matched: SAMECKA-NACZYŃSKA Martyna (score=100.0)
-- Compute scores for PEW1-V1-F-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-F-FOIL-2024-2025')
);

-- ---- PEW2: EVF Grand Prix 2 — Madryt (Madrid) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW2-2024-2025',
    'EVF Grand Prix 2 — Madryt',
    'Madrid',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW2-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW2-2024-2025'),
    'PEW2-V1-F-FOIL-2024-2025',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'FOIL', 'F', 'V1',
    '2024-11-17', 9, 'https://engarde-service.com/competition/aeve_esgrima/evf_madrid_2024/t-ff-1',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    158,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-F-FOIL-2024-2025'),
    7,
    'LIPKOWSKA Dominika'
); -- matched: LIPKOWSKA Dominika (score=100.0)
-- Compute scores for PEW2-V1-F-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-F-FOIL-2024-2025')
);

-- SKIP PEW3 (EVF Grand Prix 3): N=0 — tournament had no participants

-- SKIP PEW4 (EVF Grand Prix 4): N=0 — tournament had no participants

-- SKIP PEW5 (EVF Grand Prix 5): N=0 — tournament had no participants

-- SKIP PEW6 (EVF Grand Prix 6): 0 matched fencers in DB — tournament not created

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): N=0 — tournament had no participants

-- ---- PEW8: EVF Grand Prix 8 — Guildford (WARSZAWA) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW8-2024-2025',
    'EVF Grand Prix 8 — Guildford',
    'WARSZAWA',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW8-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW8-2024-2025'),
    'PEW8-V1-F-FOIL-2024-2025',
    'EVF Grand Prix 8 — Guildford',
    'PEW',
    'FOIL', 'F', 'V1',
    '2025-03-30', 8, 'https://www.veteransfencing.eu/fencing/rankings/',
    'SCORED'
);
-- SKIPPED (international, no master data): 'QUADRI Paola' place=1
-- SKIPPED (international, no master data): 'ENRIGHT Ritva Irene' place=2
-- SKIPPED (international, no master data): 'KICKBUSCH Karin' place=3
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    158,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V1-F-FOIL-2024-2025'),
    3,
    'LIPKOWSKA Dominika'
); -- matched: LIPKOWSKA Dominika (score=100.0)
-- SKIPPED (international, no master data): 'HERCZEG Krisztina' place=5
-- SKIPPED (international, no master data): 'OSTRIKOFF Michelle' place=6
-- SKIPPED (international, no master data): 'SULLIVAN Annemarie' place=7
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    237,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V1-F-FOIL-2024-2025'),
    8,
    'SAMECKA-NACZYŃSKA Martyna'
); -- matched: SAMECKA-NACZYŃSKA Martyna (score=100.0)
-- Compute scores for PEW8-V1-F-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V1-F-FOIL-2024-2025')
);

-- SKIP PS (Puchar Świata): N=0 — tournament had no participants

-- SKIP IMEW (Indywidualne Mistrzostwa Europy Weteranów): N=0 — tournament had no participants

-- Summary
-- Total results matched:   8
-- Total results unmatched: 6
-- Total auto-created:      0
