-- =========================================================================
-- Season 2024-2025 — V4 M EPEE — generated from SZPADA-4-2024-2025.xlsx
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
    'PPW1-V4-M-EPEE-2024-2025',
    'I Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V4',
    '2024-09-28', 6, 'https://www.fencingtimelive.com/events/results/3973305CA70D41198416FC32777A066D',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KIERSZNICKI' AND txt_first_name = 'Ryszard' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2024-2025'),
    1,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ADAMCZEWSKI' AND txt_first_name = 'Wojciech' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2024-2025'),
    2,
    'ADAMCZEWSKI Wojciech'
); -- matched: ADAMCZEWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'JUSZKIEWICZ' AND txt_first_name = 'Piotr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2024-2025'),
    3,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'LYNCH' AND txt_first_name = 'Pat' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2024-2025'),
    4,
    'LYNCH Pat'
); -- matched: LYNCH Pat (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'FURMANIAK' AND txt_first_name = 'Andrzej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2024-2025'),
    5,
    'FURMANIAK Andrzej'
); -- matched: FURMANIAK Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NOWAKOWSKI' AND txt_first_name = 'Andrzej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2024-2025'),
    6,
    'NOWAKOWSKI Andrzej'
); -- matched: NOWAKOWSKI Andrzej (score=100.0)
-- Compute scores for PPW1-V4-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2024-2025')
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
    'PPW2-V4-M-EPEE-2024-2025',
    'II Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V4',
    '2024-10-26', 4, 'https://www.fencingtimelive.com/events/results/6512D783F4C64F0A87E97DCA51DE7B08',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KIERSZNICKI' AND txt_first_name = 'Ryszard' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V4-M-EPEE-2024-2025'),
    1,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ADAMCZEWSKI' AND txt_first_name = 'Wojciech' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V4-M-EPEE-2024-2025'),
    2,
    'ADAMCZEWSKI Wojciech'
); -- matched: ADAMCZEWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'FURMANIAK' AND txt_first_name = 'Andrzej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V4-M-EPEE-2024-2025'),
    3,
    'FURMANIAK Andrzej'
); -- matched: FURMANIAK Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NOWAKOWSKI' AND txt_first_name = 'Andrzej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V4-M-EPEE-2024-2025'),
    4,
    'NOWAKOWSKI Andrzej'
); -- matched: NOWAKOWSKI Andrzej (score=100.0)
-- Compute scores for PPW2-V4-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V4-M-EPEE-2024-2025')
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
    'PPW3-V4-M-EPEE-2024-2025',
    'III Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V4',
    '2024-11-30', 4, 'https://www.fencingtimelive.com/events/results/355ED748D5AE44CEAE32751997E01EF2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ADAMCZEWSKI' AND txt_first_name = 'Wojciech' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V4-M-EPEE-2024-2025'),
    1,
    'ADAMCZEWSKI Wojciech'
); -- matched: ADAMCZEWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'JUSZKIEWICZ' AND txt_first_name = 'Piotr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V4-M-EPEE-2024-2025'),
    2,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'FURMANIAK' AND txt_first_name = 'Andrzej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V4-M-EPEE-2024-2025'),
    3,
    'FURMANIAK Andrzej'
); -- matched: FURMANIAK Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NOWAKOWSKI' AND txt_first_name = 'Andrzej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V4-M-EPEE-2024-2025'),
    4,
    'NOWAKOWSKI Andrzej'
); -- matched: NOWAKOWSKI Andrzej (score=100.0)
-- Compute scores for PPW3-V4-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V4-M-EPEE-2024-2025')
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
    'PPW4-V4-M-EPEE-2024-2025',
    'IV Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V4',
    '2025-02-22', 5, 'https://www.fencingtimelive.com/events/results/3D3B8E1324F34FDCB5A6AA9D7A0D2A5F',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ADAMCZEWSKI' AND txt_first_name = 'Wojciech' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-EPEE-2024-2025'),
    1,
    'ADAMCZEWSKI Wojciech'
); -- matched: ADAMCZEWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KIERSZNICKI' AND txt_first_name = 'Ryszard' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-EPEE-2024-2025'),
    2,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'BORKOWSKI' AND txt_first_name = 'Andrzej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-EPEE-2024-2025'),
    3,
    'BORKOWSKI Andrzej'
); -- matched: BORKOWSKI Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'JUSZKIEWICZ' AND txt_first_name = 'Piotr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-EPEE-2024-2025'),
    4,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NOWAKOWSKI' AND txt_first_name = 'Andrzej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-EPEE-2024-2025'),
    5,
    'NOWAKOWSKI Andrzej'
); -- matched: NOWAKOWSKI Andrzej (score=100.0)
-- Compute scores for PPW4-V4-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-EPEE-2024-2025')
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
    'PPW5-V4-M-EPEE-2024-2025',
    'V Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V4',
    '2025-04-26', 4, 'https://www.fencingtimelive.com/events/results/97261C8C2E0C4F5F91410EF344D7AC82',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KIERSZNICKI' AND txt_first_name = 'Ryszard' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V4-M-EPEE-2024-2025'),
    1,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'JUSZKIEWICZ' AND txt_first_name = 'Piotr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V4-M-EPEE-2024-2025'),
    2,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'FURMANIAK' AND txt_first_name = 'Andrzej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V4-M-EPEE-2024-2025'),
    3,
    'FURMANIAK Andrzej'
); -- matched: FURMANIAK Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NOWAKOWSKI' AND txt_first_name = 'Andrzej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V4-M-EPEE-2024-2025'),
    4,
    'NOWAKOWSKI Andrzej'
); -- matched: NOWAKOWSKI Andrzej (score=100.0)
-- Compute scores for PPW5-V4-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V4-M-EPEE-2024-2025')
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
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ADAMCZEWSKI' AND txt_first_name = 'Wojciech' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-EPEE-2024-2025'),
    1,
    'ADAMCZEWSKI Wojciech'
); -- matched: ADAMCZEWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SOBIERAJ' AND txt_first_name = 'Wojciech' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-EPEE-2024-2025'),
    2,
    'SOBIERAJ Wojciech'
); -- matched: SOBIERAJ Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KIERSZNICKI' AND txt_first_name = 'Ryszard' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-EPEE-2024-2025'),
    3,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'JUSZKIEWICZ' AND txt_first_name = 'Piotr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-EPEE-2024-2025'),
    4,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'FURMANIAK' AND txt_first_name = 'Andrzej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-EPEE-2024-2025'),
    5,
    'FURMANIAK Andrzej'
); -- matched: FURMANIAK Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NOWAKOWSKI' AND txt_first_name = 'Andrzej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-EPEE-2024-2025'),
    6,
    'NOWAKOWSKI Andrzej'
); -- matched: NOWAKOWSKI Andrzej (score=100.0)
-- Compute scores for MPW-V4-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-EPEE-2024-2025')
);

-- SKIP PEW1 (EVF Grand Prix 1 — Budapeszt): 0 matched fencers in DB — tournament not created

-- SKIP PEW2 (EVF Grand Prix 2 — Madryt): N=0 — tournament had no participants

-- SKIP PEW3 (EVF Grand Prix 3): N=0 — tournament had no participants

-- SKIP PEW4 (EVF Grand Prix 4): N=0 — tournament had no participants

-- SKIP PEW5 (EVF Grand Prix 5): N=0 — tournament had no participants

-- ---- PEW6: EVF Grand Prix 6 (WARSZAWA) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW6-2024-2025',
    'EVF Grand Prix 6',
    'WARSZAWA',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW6-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW6-2024-2025'),
    'PEW6-V4-M-EPEE-2024-2025',
    'EVF Grand Prix 6',
    'PEW',
    'EPEE', 'M', 'V4',
    '2025-03-29', 12, 'https://www.fencingtimelive.com/events/results/CD53FBD4296C443B90EEAF57EE676C3F',
    'SCORED'
);
-- SKIPPED (international, no master data): 'STOCK Jean' place=1
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOLLAR' AND txt_first_name = 'Gabriel' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2024-2025'),
    2,
    'KOLLÁR Gabriel'
); -- matched: KOLLAR Gabriel (score=92.85714285714286)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ADAMCZEWSKI' AND txt_first_name = 'Wojciech' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2024-2025'),
    3,
    'ADAMCZEWSKI Wojciech'
); -- matched: ADAMCZEWSKI Wojciech (score=100.0)
-- SKIPPED (international, no master data): 'PINCEMAILLE Benoit' place=3
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ZYLKA' AND txt_first_name = 'Henryk' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2024-2025'),
    5,
    'ZYLKA Henryk'
); -- matched: ZYLKA Henryk (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'JUSZKIEWICZ' AND txt_first_name = 'Piotr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2024-2025'),
    6,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
-- SKIPPED (international, no master data): 'AUSSEDAT Bernard' place=7
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KIERSZNICKI' AND txt_first_name = 'Ryszard' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2024-2025'),
    8,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
-- SKIPPED (international, no master data): 'MOREIRA Artur' place=9
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NOWAKOWSKI' AND txt_first_name = 'Andrzej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2024-2025'),
    10,
    'NOWAKOWSKI Andrzej'
); -- matched: NOWAKOWSKI Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'FURMANIAK' AND txt_first_name = 'Andrzej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2024-2025'),
    11,
    'FURMANIAK Andrzej'
); -- matched: FURMANIAK Andrzej (score=100.0)
-- SKIPPED (international, no master data): 'GELLER Giora' place=12
-- Compute scores for PEW6-V4-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2024-2025')
);

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): N=0 — tournament had no participants

-- SKIP PS (Puchar Świata): N=0 — tournament had no participants

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
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'BORKOWSKI' AND txt_first_name = 'Andrzej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V4-M-EPEE-2024-2025'),
    40,
    'BORKOWSKI Andrzej'
); -- matched: BORKOWSKI Andrzej (score=100.0)
-- Compute scores for IMEW-V4-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V4-M-EPEE-2024-2025')
);

-- Summary
-- Total results matched:   37
-- Total results unmatched: 5
-- Total auto-created:      0
