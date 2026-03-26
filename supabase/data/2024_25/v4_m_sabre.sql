-- =========================================================================
-- Season 2024-2025 — V4 M SABRE — generated from SZABLA-4-2024-2025.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- ---- PP1: I Puchar Polski Weteranów (KONIN) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PP1-2024-2025',
    'I Puchar Polski Weteranów',
    'KONIN',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PP1-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PP1-2024-2025'),
    'PP1-V4-M-SABRE-2024-2025',
    'I Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V4',
    '2024-09-29', 4, 'https://www.fencingtimelive.com/events/results/639D5324101342C088D10ECAC11EA0E6',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    144,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V4-M-SABRE-2024-2025'),
    1,
    'MAINKA Andrzej'
); -- matched: MAINKA Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    156,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V4-M-SABRE-2024-2025'),
    2,
    'MŁYNEK Janusz'
); -- matched: MŁYNEK Janusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    98,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V4-M-SABRE-2024-2025'),
    3,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    188,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V4-M-SABRE-2024-2025'),
    4,
    'PRĘGOWSKI Jerzy'
); -- matched: PRĘGOWSKI Jerzy (score=100.0)
-- Compute scores for PP1-V4-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V4-M-SABRE-2024-2025')
);

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
    'PP2-V4-M-SABRE-2024-2025',
    'II Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V4',
    '2024-10-27', 3, 'https://www.fencingtimelive.com/events/results/02B4F3507D454FC3A0B0A1C170E7C57F',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    144,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V4-M-SABRE-2024-2025'),
    1,
    'MAINKA Andrzej'
); -- matched: MAINKA Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    156,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V4-M-SABRE-2024-2025'),
    2,
    'MŁYNEK Janusz'
); -- matched: MŁYNEK Janusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    188,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V4-M-SABRE-2024-2025'),
    3,
    'PRĘGOWSKI Jerzy'
); -- matched: PRĘGOWSKI Jerzy (score=100.0)
-- Compute scores for PP2-V4-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V4-M-SABRE-2024-2025')
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
    'PP3-V4-M-SABRE-2024-2025',
    'III Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V4',
    '2024-12-01', 4, 'https://www.fencingtimelive.com/events/results/8447FE5BD87E4980BCA4C32AAFDDC016',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    156,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V4-M-SABRE-2024-2025'),
    1,
    'MŁYNEK Janusz'
); -- matched: MŁYNEK Janusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    144,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V4-M-SABRE-2024-2025'),
    2,
    'MAINKA Andrzej'
); -- matched: MAINKA Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    98,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V4-M-SABRE-2024-2025'),
    3,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    188,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V4-M-SABRE-2024-2025'),
    4,
    'PRĘGOWSKI Jerzy'
); -- matched: PRĘGOWSKI Jerzy (score=100.0)
-- Compute scores for PP3-V4-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V4-M-SABRE-2024-2025')
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
    'MPW-V4-M-SABRE-2024-2025',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'SABRE', 'M', 'V4',
    '2025-06-08', 5, 'https://www.fencingtimelive.com/events/results/38136E7331D841BEACAB94A6F1543BA0',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    156,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-SABRE-2024-2025'),
    1,
    'MŁYNEK Janusz'
); -- matched: MŁYNEK Janusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    144,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-SABRE-2024-2025'),
    2,
    'MAINKA Andrzej'
); -- matched: MAINKA Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    21,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-SABRE-2024-2025'),
    3,
    'BORYSIUK Zbigniew'
); -- matched: BORYSIUK Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    98,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-SABRE-2024-2025'),
    4,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-SABRE-2024-2025'),
    5,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
-- Compute scores for MPW-V4-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-SABRE-2024-2025')
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
    'PEW1-V4-M-SABRE-2024-2025',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'SABRE', 'M', 'V4',
    '2024-09-22', 8, 'https://engarde-service.com/app.php?id=4211E4',
    'SCORED'
);
-- Compute scores for PEW1-V4-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V4-M-SABRE-2024-2025')
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
    'PEW7-V4-M-SABRE-2024-2025',
    'EVF Grand Prix 7 — Terni',
    'PEW',
    'SABRE', 'M', 'V4',
    '2025-03-29', 12, 'https://www.fencingtimelive.com/events/results/93E1D18E952F4F03A01F1B5494EB995C',
    'SCORED'
);
-- UNMATCHED (score<80): 'PAROLI Giulio' place=1
-- UNMATCHED (score<80): 'BOCCONI Andrea' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    156,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V4-M-SABRE-2024-2025'),
    3,
    'MŁYNEK Janusz'
); -- matched: MŁYNEK Janusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    21,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V4-M-SABRE-2024-2025'),
    3,
    'BORYSIUK Zbigniew'
); -- matched: BORYSIUK Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    188,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V4-M-SABRE-2024-2025'),
    5,
    'PRĘGOWSKI Jerzy'
); -- matched: PRĘGOWSKI Jerzy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    144,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V4-M-SABRE-2024-2025'),
    6,
    'MAINKA Andrzej'
); -- matched: MAINKA Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    98,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V4-M-SABRE-2024-2025'),
    7,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V4-M-SABRE-2024-2025'),
    8,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
-- UNMATCHED (score<80): 'ARANY-TÓTH Lajos' place=9
-- UNMATCHED (score<80): 'BARON Peter' place=10
-- UNMATCHED (score<80): 'AUSSEDAT Bernard' place=11
-- UNMATCHED (score<80): 'VERDE Antonio' place=12
-- Compute scores for PEW7-V4-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V4-M-SABRE-2024-2025')
);

-- SKIP PEW8 (EVF Grand Prix 8 — Guildford): N=0 — tournament had no participants

-- SKIP PEW9 (EVF Grand Prix 9 — Sztokholm): N=0 — tournament had no participants

-- ---- IMEW: Indywidualne Mistrzostwa Europy Weteranów (Płowdiw) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'IMEW-2024-2025',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'Płowdiw',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'IMEW-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'IMEW-2024-2025'),
    'IMEW-V4-M-SABRE-2024-2025',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'SABRE', 'M', 'V4',
    '2025-05-29', 25, 'https://www.fencingtimelive.com/events/results/95CCDD20BC8048E1B818268C4750C1D6',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    188,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V4-M-SABRE-2024-2025'),
    11,
    'PRĘGOWSKI Jerzy'
); -- matched: PRĘGOWSKI Jerzy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    144,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V4-M-SABRE-2024-2025'),
    16,
    'MAINKA Andrzej'
); -- matched: MAINKA Andrzej (score=100.0)
-- Compute scores for IMEW-V4-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V4-M-SABRE-2024-2025')
);

-- Summary
-- Total results matched:   24
-- Total results unmatched: 6
