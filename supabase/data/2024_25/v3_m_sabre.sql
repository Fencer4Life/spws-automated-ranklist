-- =========================================================================
-- Season 2024-2025 — V3 M SABRE — generated from SZABLA-3-2024-2025.xlsx
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
    'PPW1-V3-M-SABRE-2024-2025',
    'I Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V3',
    '2024-09-29', 2, 'https://www.fencingtimelive.com/events/results/DC3A91FCABDA4AA19D494237AD071EB6',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    270,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-SABRE-2024-2025'),
    1,
    'ZABŁOCKI Michał'
); -- matched: ZABŁOCKI Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    32,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-SABRE-2024-2025'),
    2,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
-- Compute scores for PPW1-V3-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-SABRE-2024-2025')
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
    'PPW2-V3-M-SABRE-2024-2025',
    'II Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V3',
    '2024-10-27', 1, 'https://www.fencingtimelive.com/events/results/02B4F3507D454FC3A0B0A1C170E7C57F',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    58,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-SABRE-2024-2025'),
    1,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
-- Compute scores for PPW2-V3-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-SABRE-2024-2025')
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
    'PPW3-V3-M-SABRE-2024-2025',
    'III Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V3',
    '2024-12-01', 4, 'https://www.fencingtimelive.com/events/results/1BB173A3F24A4DCAB6D363BFB851C158',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    270,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-SABRE-2024-2025'),
    1,
    'ZABŁOCKI Michał'
); -- matched: ZABŁOCKI Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    58,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-SABRE-2024-2025'),
    2,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    32,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-SABRE-2024-2025'),
    3,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    264,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-SABRE-2024-2025'),
    4,
    'WOJCIECHOWSKI Marek'
); -- matched: WOJCIECHOWSKI Marek (score=100.0)
-- Compute scores for PPW3-V3-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-SABRE-2024-2025')
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
    'PPW4-V3-M-SABRE-2024-2025',
    'IV Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V3',
    '2025-02-23', 3, 'https://www.fencingtimelive.com/events/results/DF16046C29204C769C289F19BB1967D2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    270,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-SABRE-2024-2025'),
    1,
    'ZABŁOCKI Michał'
); -- matched: ZABŁOCKI Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    58,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-SABRE-2024-2025'),
    2,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    32,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-SABRE-2024-2025'),
    3,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
-- Compute scores for PPW4-V3-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-SABRE-2024-2025')
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
    'PPW5-V3-M-SABRE-2024-2025',
    'V Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V3',
    '2025-04-26', 2, 'https://www.fencingtimelive.com/events/results/E81CCA279A6C47A09FDC7DA996157EA1',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    58,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V3-M-SABRE-2024-2025'),
    1,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    32,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V3-M-SABRE-2024-2025'),
    2,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
-- Compute scores for PPW5-V3-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V3-M-SABRE-2024-2025')
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
    'MPW-V3-M-SABRE-2024-2025',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'SABRE', 'M', 'V3',
    '2025-06-08', 4, 'https://www.fencingtimelive.com/events/results/69C728DB58584FFC85FA31A9043DFE65',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-SABRE-2024-2025'),
    1,
    'OSSOWSKI Wojciech'
); -- matched: OSSOWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    58,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-SABRE-2024-2025'),
    2,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    32,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-SABRE-2024-2025'),
    3,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    264,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-SABRE-2024-2025'),
    4,
    'WOJCIECHOWSKI Marek'
); -- matched: WOJCIECHOWSKI Marek (score=100.0)
-- Compute scores for MPW-V3-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-SABRE-2024-2025')
);

-- SKIP PEW1 (EVF Grand Prix 1 — Budapeszt): 0 matched fencers in DB — tournament not created

-- SKIP PEW2 (EVF Grand Prix 2 — Madryt): N=0 — tournament had no participants

-- ---- PEW3: EVF Grand Prix 3 (Munich) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW3-2024-2025',
    'EVF Grand Prix 3',
    'Munich',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW3-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW3-2024-2025'),
    'PEW3-V3-M-SABRE-2024-2025',
    'EVF Grand Prix 3',
    'PEW',
    'SABRE', 'M', 'V3',
    '2024-12-08', 21, 'https://www.fencingworldwide.com/en/912307-2024/results/',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    58,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-SABRE-2024-2025'),
    3,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
-- Compute scores for PEW3-V3-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-SABRE-2024-2025')
);

-- SKIP PEW4 (EVF Grand Prix 4): N=0 — tournament had no participants

-- SKIP PEW5 (EVF Grand Prix 5): N=0 — tournament had no participants

-- ---- PEW6: EVF Grand Prix 6 (Terni) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW6-2024-2025',
    'EVF Grand Prix 6',
    'Terni',
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
    'PEW6-V3-M-SABRE-2024-2025',
    'EVF Grand Prix 6',
    'PEW',
    'SABRE', 'M', 'V3',
    '2025-02-02', 17, 'https://www.4fence.it/FIS/Risultati/2025-02-02-01_Terni_(TR)_-_4_Prova_Naz.le_Master_-_EVF_Circuit/index.php?a=SC&s=M&c=8&f=clafinale',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    270,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-SABRE-2024-2025'),
    9,
    'ZABŁOCKI Michał'
); -- matched: ZABŁOCKI Michał (score=100.0)
-- Compute scores for PEW6-V3-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-SABRE-2024-2025')
);

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
    'PEW7-V3-M-SABRE-2024-2025',
    'EVF Grand Prix 7 — Terni',
    'PEW',
    'SABRE', 'M', 'V3',
    '2025-03-29', 14, 'https://www.fencingtimelive.com/events/results/3EFA46E3EB5B46F6B4BF2A95B5758847',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    270,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V3-M-SABRE-2024-2025'),
    1,
    'ZABŁOCKI Michał'
); -- matched: ZABŁOCKI Michał (score=100.0)
-- UNMATCHED (score<80): 'FALASCHI Luca' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    58,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V3-M-SABRE-2024-2025'),
    3,
    'GAJDA LESZEK'
); -- matched: GAJDA Leszek (score=100.0)
-- UNMATCHED (score<80): 'BEM Michel' place=3
-- UNMATCHED (score<80): 'FEIRA CHIOS Alberto' place=5
-- UNMATCHED (score<80): 'KREISCHER Viktor' place=6
-- UNMATCHED (score<80): 'DUBROUKIN Oleg' place=7
-- UNMATCHED (score<80): 'MYERS Brent' place=8
-- UNMATCHED (score<80): 'BALONUSKOVS Jurijs' place=9
-- UNMATCHED (score<80): 'TAKÁCSY László' place=10
-- UNMATCHED (score<80): 'CIUFFREDA Luigi Salvatore' place=11
-- UNMATCHED (score<80): 'ZIEGLER Udo' place=12
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    32,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V3-M-SABRE-2024-2025'),
    13,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
-- UNMATCHED (score<80): 'NAGY András' place=14
-- Compute scores for PEW7-V3-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V3-M-SABRE-2024-2025')
);

-- SKIP PEW8 (EVF Grand Prix 8 — Guildford): N=0 — tournament had no participants

-- SKIP PEW9 (EVF Grand Prix 9 — Sztokholm): N=0 — tournament had no participants

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
    'IMEW-V3-M-SABRE-2024-2025',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'SABRE', 'M', 'V3',
    '2025-05-29', 39, 'https://www.fencingtimelive.com/events/results/9BDF4028E9F6424C990692BA104C6C82',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    270,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-SABRE-2024-2025'),
    3,
    'ZABŁOCKI Michał'
); -- matched: ZABŁOCKI Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    58,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-SABRE-2024-2025'),
    22,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
-- Compute scores for IMEW-V3-M-SABRE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-SABRE-2024-2025')
);

-- Summary
-- Total results matched:   23
-- Total results unmatched: 11
