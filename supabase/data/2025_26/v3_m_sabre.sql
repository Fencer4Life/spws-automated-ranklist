-- =========================================================================
-- Season 2025-2026 — V3 M SABRE — generated from SZABLA-3-2025-2026.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- ---- PP1: I Puchar Polski Weteranów (Szabla Weterani Mężczyzn 3) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW1-2025-2026',
    'I Puchar Polski Weteranów',
    'Szabla Weterani Mężczyzn 3',
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
    'PPW1-V3-M-SABRE-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V3',
    NULL, 4, 'https://www.fencingtimelive.com/events/results/DC3A91FCABDA4AA19D494237AD071EB6',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    306,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-SABRE-2025-2026'),
    1,
    'ZABŁOCKI Michał'
); -- matched: ZABŁOCKI Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-SABRE-2025-2026'),
    2,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-SABRE-2025-2026'),
    3,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    38,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-SABRE-2025-2026'),
    4,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
-- Compute scores for PPW1-V3-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-SABRE-2025-2026')
);

-- ---- PP2: II Puchar Polski Weteranów (SZABLA WETERANI MĘŻCZYZNI 3) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW2-2025-2026',
    'II Puchar Polski Weteranów',
    'SZABLA WETERANI MĘŻCZYZNI 3',
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
    'PPW2-V3-M-SABRE-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V3',
    NULL, 2, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-SABRE-2025-2026'),
    1,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    38,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-SABRE-2025-2026'),
    2,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
-- Compute scores for PPW2-V3-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-SABRE-2025-2026')
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
    'PPW3-V3-M-SABRE-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V3',
    '2025-12-14', 2, 'https://www.fencingtimelive.com/events/results/27A0E37B19C3432CA4FC325EA2B5A1A8',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-SABRE-2025-2026'),
    1,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    38,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-SABRE-2025-2026'),
    2,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
-- Compute scores for PPW3-V3-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-SABRE-2025-2026')
);

-- ---- PP4: IV Puchar Polski Weteranów (WARSZAWA) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW4-2025-2026',
    'IV Puchar Polski Weteranów',
    'WARSZAWA',
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
    'PPW4-V3-M-SABRE-2025-2026',
    'IV Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V3',
    '2025-02-23', 4, 'https://www.fencingtimelive.com/events/results/DF16046C29204C769C289F19BB1967D2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-SABRE-2025-2026'),
    1,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    197,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-SABRE-2025-2026'),
    2,
    'OSSOWSKI Wojciech'
); -- matched: OSSOWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    102,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-SABRE-2025-2026'),
    3,
    'JASIŃSKI Tomasz'
); -- matched: JASIŃSKI Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    38,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-SABRE-2025-2026'),
    4,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
-- Compute scores for PPW4-V3-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-SABRE-2025-2026')
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
    'PEW3-V3-M-SABRE-2025-2026',
    'EVF Grand Prix 3',
    'PEW',
    'SABRE', 'M', 'V3',
    '2025-12-06', 22, 'https://www.fencingworldwide.com/en/912307-2025/results/',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-SABRE-2025-2026'),
    7,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
-- Compute scores for PEW3-V3-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-SABRE-2025-2026')
);

-- SKIP PEW4 (EVF Grand Prix 4): N=0 — tournament had no participants

-- SKIP PEW5 (EVF Grand Prix 5): N=0 — tournament had no participants

-- ---- PEW6: EVF Grand Prix 6 (2026-03-08-07 Napoli - 4 Prova Circuito Nazionale Master 2025-2 - Sciabola Maschile ) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW6-2025-2026',
    'EVF Grand Prix 6',
    '2026-03-08-07 Napoli - 4 Prova Circuito Nazionale Master 2025-2 - Sciabola Maschile ',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW6-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW6-2025-2026'),
    'PEW6-V3-M-SABRE-2025-2026',
    'EVF Grand Prix 6',
    'PEW',
    'SABRE', 'M', 'V3',
    NULL, 20, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    306,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-SABRE-2025-2026'),
    1,
    'ZABŁOCKI Michał'
); -- matched: ZABŁOCKI Michał (score=100.0)
-- SKIPPED (international, no master data): 'LUZZO ANTONIO' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-SABRE-2025-2026'),
    3,
    'GAJDA LESZEK'
); -- matched: GAJDA Leszek (score=100.0)
-- SKIPPED (international, no master data): 'FEIRA CHIOS ALBERTO' place=4
-- SKIPPED (international, no master data): 'LANARI ILDO' place=5
-- SKIPPED (international, no master data): 'POSTORINO ALESSANDRO' place=6
-- SKIPPED (international, no master data): 'FALASCHI LUCA' place=7
-- SKIPPED (international, no master data): 'TALLARICO VINCENZO' place=8
-- SKIPPED (international, no master data): 'ROWLANDS DUNCAN' place=9
-- SKIPPED (international, no master data): 'BAILLACHE PAUL MAXIME' place=10
-- SKIPPED (international, no master data): 'KREISCHER VIKTOR' place=11
-- SKIPPED (international, no master data): 'FERRARI ATTILIO' place=12
-- SKIPPED (international, no master data): 'CIUFFREDA LUIGI SALVATORE' place=13
-- SKIPPED (international, no master data): 'FARALLA CORRADO' place=14
-- SKIPPED (international, no master data): 'MARINI LUCA' place=15
-- SKIPPED (international, no master data): 'DE CAROLIS AURELIO' place=16
-- SKIPPED (international, no master data): 'NAGY ANDRAS' place=17
-- SKIPPED (international, no master data): 'REDONDO BERMEJO JOSÉ LUIS' place=18
-- SKIPPED (international, no master data): 'MYERS BRENT MARK' place=19
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    299,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-SABRE-2025-2026'),
    20,
    'WOJCIECHOWSKI MAREK'
); -- matched: WOJCIECHOWSKI Marek (score=100.0)
-- Compute scores for PEW6-V3-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-SABRE-2025-2026')
);

-- ---- PEW7: EVF Grand Prix 7 — Terni (Szabla Mężczyzn V3 DE) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW7-2025-2026',
    'EVF Grand Prix 7 — Terni',
    'Szabla Mężczyzn V3 DE',
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
    'PEW7-V3-M-SABRE-2025-2026',
    'EVF Grand Prix 7 — Terni',
    'PEW',
    'SABRE', 'M', 'V3',
    NULL, 12, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    306,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V3-M-SABRE-2025-2026'),
    1,
    'ZABŁOCKI Michał'
); -- matched: ZABŁOCKI Michał (score=100.0)
-- SKIPPED (international, no master data): 'FEIRA CHIOS Alberto' place=2
-- SKIPPED (international, no master data): 'DUBROUKIN Oleg' place=3
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    62,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V3-M-SABRE-2025-2026'),
    4,
    'GAJDA Leszek'
); -- matched: GAJDA Leszek (score=100.0)
-- SKIPPED (international, no master data): 'FALASCHI Luca' place=5
-- SKIPPED (international, no master data): 'ZIEGLER Udo' place=6
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    102,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V3-M-SABRE-2025-2026'),
    7,
    'JASIŃSKI Tomasz'
); -- matched: JASIŃSKI Tomasz (score=100.0)
-- SKIPPED (international, no master data): 'PAPP Gábor Zsigmond' place=8
-- SKIPPED (international, no master data): 'ROWLANDS Duncan' place=9
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    38,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V3-M-SABRE-2025-2026'),
    10,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
-- SKIPPED (international, no master data): 'MYERS Brent' place=11
-- SKIPPED (international, no master data): 'BIERLAIRE Joel' place=12
-- Compute scores for PEW7-V3-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V3-M-SABRE-2025-2026')
);

-- SKIP PEW8 (EVF Grand Prix 8 — Guildford): N=0 — tournament had no participants

-- SKIP PEW9 (EVF Grand Prix 9 — Sztokholm): N=0 — tournament had no participants

-- SKIP PS (Puchar Świata): N=0 — tournament had no participants

-- Summary
-- Total results matched:   28
-- Total results unmatched: 49
-- Total auto-created:      0
