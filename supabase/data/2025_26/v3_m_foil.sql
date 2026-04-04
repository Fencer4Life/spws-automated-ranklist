-- =========================================================================
-- Season 2025-2026 — V3 M FOIL — generated from FLORET-3-2025-2026.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- ---- PP1: I Puchar Polski Weteranów (OPOLE) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW1-2025-2026',
    'I Puchar Polski Weteranów',
    'OPOLE',
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
    'PPW1-V3-M-FOIL-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V3',
    '2025-09-27', 2, 'https://www.fencingtimelive.com/events/results/AF92D425199140BD8F9BDE3DFCC6643C',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-FOIL-2025-2026'),
    1,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    219,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-FOIL-2025-2026'),
    2,
    'PYZIK Zdzisław'
); -- matched: PYZIK Zdzisław (score=100.0)
-- Compute scores for PPW1-V3-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-FOIL-2025-2026')
);

-- ---- PP2: II Puchar Polski Weteranów (FLORET WETERANI Mężczyzni 3) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW2-2025-2026',
    'II Puchar Polski Weteranów',
    'FLORET WETERANI Mężczyzni 3',
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
    'PPW2-V3-M-FOIL-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V3',
    NULL, 1, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    219,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-FOIL-2025-2026'),
    1,
    'PYZIK Zdzisław'
); -- matched: PYZIK Zdzisław (score=100.0)
-- Compute scores for PPW2-V3-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-FOIL-2025-2026')
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
    'PPW3-V3-M-FOIL-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V3',
    '2025-12-13', 2, 'https://www.fencingtimelive.com/events/results/6654BDFA4A1B4FCD9350C0D40E984C47',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-FOIL-2025-2026'),
    1,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    219,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-FOIL-2025-2026'),
    2,
    'PYZIK Zdzisław'
); -- matched: PYZIK Zdzisław (score=100.0)
-- Compute scores for PPW3-V3-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-FOIL-2025-2026')
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
    'PPW4-V3-M-FOIL-2025-2026',
    'IV Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V3',
    '2026-02-21', 3, 'https://fencingtimelive.com/events/results/8B902817C0914EAF89D20A296314BDE3',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-FOIL-2025-2026'),
    1,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    169,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-FOIL-2025-2026'),
    2,
    'MAŁASIŃSKI Adam'
); -- matched: MAŁASIŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-FOIL-2025-2026'),
    3,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
-- Compute scores for PPW4-V3-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-FOIL-2025-2026')
);
-- ---- PEW1: EVF Grand Prix 1 — Budapeszt (INTERNATIONAL VETERAN CHAMPIONSHIPS) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW1-2025-2026',
    'EVF Grand Prix 1 — Budapeszt',
    'INTERNATIONAL VETERAN CHAMPIONSHIPS',
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
    'PEW1-V3-M-FOIL-2025-2026',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'FOIL', 'M', 'V3',
    NULL, 21, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'CSÁK Attila' place=1
-- SKIPPED (international, no master data): 'BOSIO Marco' place=2
-- SKIPPED (international, no master data): 'RAEKER Hans-Martin' place=3
-- SKIPPED (international, no master data): 'AKERBERG Thomas' place=4
-- SKIPPED (international, no master data): 'BIERLAIRE Joel' place=5
-- SKIPPED (international, no master data): 'SZALAY ID. Károly' place=6
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-FOIL-2025-2026'),
    7,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    6,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-FOIL-2025-2026'),
    8,
    'BLASCHKA Robert'
); -- matched: ANDERSCH Robert (score=73.33333333333334)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-FOIL-2025-2026'),
    9,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
-- SKIPPED (international, no master data): 'RIESZ Gábor' place=10
-- SKIPPED (international, no master data): 'PÉNTEK Tamás' place=11
-- SKIPPED (international, no master data): 'CAPELLINI Fabrizio' place=12
-- SKIPPED (international, no master data): 'MÉSZÁROS András Gábor' place=13
-- SKIPPED (international, no master data): 'ROSANO Camillo' place=14
-- SKIPPED (international, no master data): 'SÁRDI Tamás' place=15
-- SKIPPED (international, no master data): 'RUSZKAI Frank' place=16
-- SKIPPED (international, no master data): 'OSTINO Carlo' place=17
-- SKIPPED (international, no master data): 'OJEDA CIURANA Miguel' place=18
-- SKIPPED (international, no master data): 'GRAJALES Nestor Luis' place=19
-- SKIPPED (international, no master data): 'BABOS Csaba' place=20
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    315,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-FOIL-2025-2026'),
    21,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
-- Compute scores for PEW1-V3-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-FOIL-2025-2026')
);

-- SKIP PEW2 (EVF Grand Prix 2 — Madryt): 0 matched fencers in DB — tournament not created

-- SKIP PEW3 (EVF Grand Prix 3): N=0 — tournament had no participants

-- SKIP PEW4 (EVF Grand Prix 4): N=0 — tournament had no participants

-- SKIP PEW5 (EVF Grand Prix 5): N=0 — tournament had no participants

-- SKIP PEW6 (EVF Grand Prix 6): 0 matched fencers in DB — tournament not created

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): 0 matched fencers in DB — tournament not created

-- ---- PEW8: EVF Grand Prix 8 — Guildford (Floret Mężczyzn V3 DE) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW8-2025-2026',
    'EVF Grand Prix 8 — Guildford',
    'Floret Mężczyzn V3 DE',
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
    'PEW8-V3-M-FOIL-2025-2026',
    'EVF Grand Prix 8 — Guildford',
    'PEW',
    'FOIL', 'M', 'V3',
    NULL, 11, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'RIESZ Gabor' place=1
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V3-M-FOIL-2025-2026'),
    2,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
-- SKIPPED (international, no master data): 'MÉSZÁROS András' place=3
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V3-M-FOIL-2025-2026'),
    3,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
-- SKIPPED (international, no master data): 'BIERLAIRE Joel' place=5
-- SKIPPED (international, no master data): 'SÁRDI Tamas' place=6
-- SKIPPED (international, no master data): 'WATTENBERG Dirk' place=7
-- SKIPPED (international, no master data): 'PENTEK Tamas' place=8
-- SKIPPED (international, no master data): 'BABOS Csaba' place=9
-- SKIPPED (international, no master data): 'MOSER Andreas' place=10
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    169,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V3-M-FOIL-2025-2026'),
    11,
    'MAŁASIŃSKI Adam'
); -- matched: MAŁASIŃSKI Adam (score=100.0)
-- Compute scores for PEW8-V3-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V3-M-FOIL-2025-2026')
);

-- SKIP PS (Puchar Świata): N=0 — tournament had no participants

-- Summary
-- Total results matched:   21
-- Total results unmatched: 74
-- Total auto-created:      0
