-- =========================================================================
-- Season 2025-2026 — V4 M SABRE — generated from SZABLA-4-2025-2026.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- ---- PP1: I Puchar Polski Weteranów (Szabla Weterani Mężczyzn 4) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW1-2025-2026',
    'I Puchar Polski Weteranów',
    'Szabla Weterani Mężczyzn 4',
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
    'PPW1-V4-M-SABRE-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V4',
    NULL, 5, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    185,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-SABRE-2025-2026'),
    1,
    'MŁYNEK Janusz'
); -- matched: MŁYNEK Janusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    218,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-SABRE-2025-2026'),
    2,
    'PRĘGOWSKI Jerzy'
); -- matched: PRĘGOWSKI Jerzy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    26,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-SABRE-2025-2026'),
    3,
    'BORYSIUK Zbigniew'
); -- matched: BORYSIUK Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    163,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-SABRE-2025-2026'),
    4,
    'MAINKA Andrzej'
); -- matched: MAINKA Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    114,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-SABRE-2025-2026'),
    5,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
-- Compute scores for PPW1-V4-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-SABRE-2025-2026')
);

-- ---- PP2: II Puchar Polski Weteranów (SZABLA WETERANI MĘŻCZYZNI 4) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW2-2025-2026',
    'II Puchar Polski Weteranów',
    'SZABLA WETERANI MĘŻCZYZNI 4',
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
    'PPW2-V4-M-SABRE-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V4',
    NULL, 4, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    163,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V4-M-SABRE-2025-2026'),
    1,
    'MAINKA Andrzej'
); -- matched: MAINKA Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    185,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V4-M-SABRE-2025-2026'),
    2,
    'MŁYNEK Janusz'
); -- matched: MŁYNEK Janusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V4-M-SABRE-2025-2026'),
    3,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    114,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V4-M-SABRE-2025-2026'),
    4,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
-- Compute scores for PPW2-V4-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V4-M-SABRE-2025-2026')
);

-- ---- PP3: III Puchar Polski Weteranów (Szabla Mężczyzn kat. 4) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW3-2025-2026',
    'III Puchar Polski Weteranów',
    'Szabla Mężczyzn kat. 4',
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
    'PPW3-V4-M-SABRE-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V4',
    NULL, 4, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    185,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V4-M-SABRE-2025-2026'),
    1,
    'MŁYNEK Janusz'
); -- matched: MŁYNEK Janusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V4-M-SABRE-2025-2026'),
    2,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    114,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V4-M-SABRE-2025-2026'),
    3,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    218,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V4-M-SABRE-2025-2026'),
    4,
    'PRĘGOWSKI Jerzy'
); -- matched: PRĘGOWSKI Jerzy (score=100.0)
-- Compute scores for PPW3-V4-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V4-M-SABRE-2025-2026')
);

-- ---- PP4: IV Puchar Polski Weteranów (SZABLA MĘŻCZYZN v4) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW4-2025-2026',
    'IV Puchar Polski Weteranów',
    'SZABLA MĘŻCZYZN v4',
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
    'PPW4-V4-M-SABRE-2025-2026',
    'IV Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V4',
    NULL, 4, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    185,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-SABRE-2025-2026'),
    1,
    'MŁYNEK Janusz'
); -- matched: MŁYNEK Janusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    218,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-SABRE-2025-2026'),
    2,
    'PRĘGOWSKI Jerzy'
); -- matched: PRĘGOWSKI Jerzy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-SABRE-2025-2026'),
    3,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    114,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-SABRE-2025-2026'),
    4,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
-- Compute scores for PPW4-V4-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-SABRE-2025-2026')
);
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
    'PEW6-V4-M-SABRE-2025-2026',
    'EVF Grand Prix 6',
    'PEW',
    'SABRE', 'M', 'V4',
    NULL, 16, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'PAROLI GIULIO' place=1
-- SKIPPED (international, no master data): 'CARMINA RICCARDO' place=2
-- SKIPPED (international, no master data): 'ANTINORO ENRICO' place=3
-- SKIPPED (international, no master data): 'PARISI PASQUALE' place=4
-- SKIPPED (international, no master data): 'BULGHERINI STEFANO' place=5
-- SKIPPED (international, no master data): 'DENTICE DI ACCA PAOLO' place=6
-- SKIPPED (international, no master data): 'CRANSTON-SELBY CHRISTOPHER' place=7
-- SKIPPED (international, no master data): 'ZANELLATO ACHILLE' place=8
-- SKIPPED (international, no master data): 'BOCCONI ANDREA' place=9
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    218,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-SABRE-2025-2026'),
    10,
    'PREGOWSKI JERZY'
); -- matched: PRĘGOWSKI Jerzy (score=93.33333333333333)
-- SKIPPED (international, no master data): 'VERDE ANTONIO' place=11
-- SKIPPED (international, no master data): 'VAROTTO LORENZO' place=12
-- SKIPPED (international, no master data): 'KESZTHELYI LASZLO' place=13
-- SKIPPED (international, no master data): 'BERARDI ANTONIO' place=14
-- SKIPPED (international, no master data): 'LIGUORI ANTONIO' place=15
-- SKIPPED (international, no master data): 'CIRILLO GIUSEPPE' place=16
-- Compute scores for PEW6-V4-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-SABRE-2025-2026')
);

-- ---- PEW7: EVF Grand Prix 7 — Terni (Szabla Mężczyzn V4 DE) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW7-2025-2026',
    'EVF Grand Prix 7 — Terni',
    'Szabla Mężczyzn V4 DE',
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
    'PEW7-V4-M-SABRE-2025-2026',
    'EVF Grand Prix 7 — Terni',
    'PEW',
    'SABRE', 'M', 'V4',
    NULL, 9, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'DENTICE DI ACCADIA Paolo' place=1
-- SKIPPED (international, no master data): 'VAROTTO Lorenzo' place=2
-- SKIPPED (international, no master data): 'CRANSTON-SELBY Christopher' place=3
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    163,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V4-M-SABRE-2025-2026'),
    4,
    'MAINKA Andrzej'
); -- matched: MAINKA Andrzej (score=100.0)
-- SKIPPED (international, no master data): 'VERDE Antonio' place=5
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    218,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V4-M-SABRE-2025-2026'),
    6,
    'PRĘGOWSKI Jerzy'
); -- matched: PRĘGOWSKI Jerzy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    114,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V4-M-SABRE-2025-2026'),
    7,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    185,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V4-M-SABRE-2025-2026'),
    8,
    'MŁYNEK Janusz'
); -- matched: MŁYNEK Janusz (score=100.0)
-- SKIPPED (international, no master data): 'LIGUORI Antonio' place=9
-- Compute scores for PEW7-V4-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V4-M-SABRE-2025-2026')
);

-- SKIP PEW8 (EVF Grand Prix 8 — Guildford): N=0 — tournament had no participants

-- SKIP PEW9 (EVF Grand Prix 9 — Sztokholm): N=0 — tournament had no participants

-- ---- PS: Puchar Świata (Paryż) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PS-2025-2026',
    'Puchar Świata',
    'Paryż',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PS-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PS-2025-2026'),
    'PS-V4-M-SABRE-2025-2026',
    'Puchar Świata',
    'PSW',
    'SABRE', 'M', 'V4',
    '2025-07-05', 12, 'https://engarde-service.com/competition/fencingaddict/crit25/shv4',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    202,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PS-V4-M-SABRE-2025-2026'),
    12,
    'PANZ Marian'
); -- matched: PANZ Marian (score=100.0)
-- Compute scores for PS-V4-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PS-V4-M-SABRE-2025-2026')
);

-- Summary
-- Total results matched:   33
-- Total results unmatched: 44
-- Total auto-created:      0
