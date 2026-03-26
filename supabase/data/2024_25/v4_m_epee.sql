-- =========================================================================
-- Season 2024-2025 — V4 M EPEE — generated from SZPADA-4-2024-2025.xlsx
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
    'PP1-V4-M-EPEE-2024-2025',
    'I Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V4',
    '2024-09-28', 6, 'https://www.fencingtimelive.com/events/results/3973305CA70D41198416FC32777A066D',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V4-M-EPEE-2024-2025'),
    1,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    1,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V4-M-EPEE-2024-2025'),
    2,
    'ADAMCZEWSKI Wojciech'
); -- matched: ADAMCZEWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    98,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V4-M-EPEE-2024-2025'),
    3,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
-- UNMATCHED (score<80): 'LYNCH Pat' place=4
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    57,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V4-M-EPEE-2024-2025'),
    5,
    'FURMANIAK Andrzej'
); -- matched: FURMANIAK Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    166,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V4-M-EPEE-2024-2025'),
    6,
    'NOWAKOWSKI Andrzej'
); -- matched: NOWAKOWSKI Andrzej (score=100.0)
-- Compute scores for PP1-V4-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V4-M-EPEE-2024-2025')
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
    'PP2-V4-M-EPEE-2024-2025',
    'II Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V4',
    '2024-10-26', 4, 'https://www.fencingtimelive.com/events/results/6512D783F4C64F0A87E97DCA51DE7B08',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V4-M-EPEE-2024-2025'),
    1,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    1,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V4-M-EPEE-2024-2025'),
    2,
    'ADAMCZEWSKI Wojciech'
); -- matched: ADAMCZEWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    57,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V4-M-EPEE-2024-2025'),
    3,
    'FURMANIAK Andrzej'
); -- matched: FURMANIAK Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    166,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V4-M-EPEE-2024-2025'),
    4,
    'NOWAKOWSKI Andrzej'
); -- matched: NOWAKOWSKI Andrzej (score=100.0)
-- Compute scores for PP2-V4-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V4-M-EPEE-2024-2025')
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
    'PP3-V4-M-EPEE-2024-2025',
    'III Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V4',
    '2024-11-30', 4, 'https://www.fencingtimelive.com/events/results/355ED748D5AE44CEAE32751997E01EF2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    1,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V4-M-EPEE-2024-2025'),
    1,
    'ADAMCZEWSKI Wojciech'
); -- matched: ADAMCZEWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    98,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V4-M-EPEE-2024-2025'),
    2,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    57,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V4-M-EPEE-2024-2025'),
    3,
    'FURMANIAK Andrzej'
); -- matched: FURMANIAK Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    166,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V4-M-EPEE-2024-2025'),
    4,
    'NOWAKOWSKI Andrzej'
); -- matched: NOWAKOWSKI Andrzej (score=100.0)
-- Compute scores for PP3-V4-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V4-M-EPEE-2024-2025')
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
    'MPW-V4-M-EPEE-2024-2025',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'EPEE', 'M', 'V4',
    '2025-06-07', 6, 'https://www.fencingtimelive.com/events/results/9AC2035F68D346B8BDF3576DC979AE54',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    1,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-EPEE-2024-2025'),
    1,
    'ADAMCZEWSKI Wojciech'
); -- matched: ADAMCZEWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    211,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-EPEE-2024-2025'),
    2,
    'SOBIERAJ Wojciech'
); -- matched: SOBIERAJ Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-EPEE-2024-2025'),
    3,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    98,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-EPEE-2024-2025'),
    4,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    57,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-EPEE-2024-2025'),
    5,
    'FURMANIAK Andrzej'
); -- matched: FURMANIAK Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    166,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-EPEE-2024-2025'),
    6,
    'NOWAKOWSKI Andrzej'
); -- matched: NOWAKOWSKI Andrzej (score=100.0)
-- Compute scores for MPW-V4-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-EPEE-2024-2025')
);

-- ---- PEW1: EVF Grand Prix 1 — Budapeszt (Budapeszt) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW1-2024-2025',
    'EVF Grand Prix 1 — Budapeszt',
    'Budapeszt',
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
    'PEW1-V4-M-EPEE-2024-2025',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'EPEE', 'M', 'V4',
    '2024-09-21', 13, 'https://engarde-service.com/app.php?id=4207L4',
    'SCORED'
);
-- Compute scores for PEW1-V4-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V4-M-EPEE-2024-2025')
);

-- SKIP PEW2 (EVF Grand Prix 2 — Madryt): N=0 — tournament had no participants

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): N=0 — tournament had no participants

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
    'IMEW-V4-M-EPEE-2024-2025',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'EPEE', 'M', 'V4',
    '2025-05-29', 50, 'https://www.fencingtimelive.com/events/results/A40D45B76E6643F8BF4314C22474EC95',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    20,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V4-M-EPEE-2024-2025'),
    40,
    'BORKOWSKI Andrzej'
); -- matched: BORKOWSKI Andrzej (score=100.0)
-- Compute scores for IMEW-V4-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V4-M-EPEE-2024-2025')
);

-- Summary
-- Total results matched:   20
-- Total results unmatched: 1
