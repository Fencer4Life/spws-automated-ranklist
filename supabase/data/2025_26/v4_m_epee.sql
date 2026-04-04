-- =========================================================================
-- Season 2025-2026 — V4 M EPEE — generated from SZPADA-4-2025-2026.xlsx
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
    'PPW1-V4-M-EPEE-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V4',
    '2025-09-28', 8, 'https://www.fencingtimelive.com/events/results/3973305CA70D41198416FC32777A066D',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    271,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2025-2026'),
    1,
    'SZYMKOWIAK Krzysztof'
); -- matched: SZYMKOWIAK Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    262,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2025-2026'),
    2,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    245,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2025-2026'),
    3,
    'SOBIERAJ Wojciech'
); -- matched: SOBIERAJ Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    114,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2025-2026'),
    4,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    314,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2025-2026'),
    5,
    'ZYLKA Henryk'
); -- matched: ZYLKA Henryk (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2025-2026'),
    6,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2025-2026'),
    7,
    'FURMANIAK Andrzej'
); -- matched: FURMANIAK Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    190,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2025-2026'),
    8,
    'NOWAKOWSKI Andrzej'
); -- matched: NOWAKOWSKI Andrzej (score=100.0)
-- Compute scores for PPW1-V4-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2025-2026')
);

-- ---- PP2: II Puchar Polski Weteranów (SZPADA MĘŻCZYZN 4 WETERANI) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW2-2025-2026',
    'II Puchar Polski Weteranów',
    'SZPADA MĘŻCZYZN 4 WETERANI',
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
    'PPW2-V4-M-EPEE-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V4',
    NULL, 5, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    262,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V4-M-EPEE-2025-2026'),
    1,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    245,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V4-M-EPEE-2025-2026'),
    2,
    'SOBIERAJ Wojciech'
); -- matched: SOBIERAJ Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    114,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V4-M-EPEE-2025-2026'),
    3,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    1,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V4-M-EPEE-2025-2026'),
    4,
    'ADAMCZEWSKI Wojciech'
); -- matched: ADAMCZEWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V4-M-EPEE-2025-2026'),
    5,
    'FURMANIAK Andrzej'
); -- matched: FURMANIAK Andrzej (score=100.0)
-- Compute scores for PPW2-V4-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V4-M-EPEE-2025-2026')
);

-- ---- PP3: III Puchar Polski Weteranów (Szpada Mężczyzn kat. 4) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW3-2025-2026',
    'III Puchar Polski Weteranów',
    'Szpada Mężczyzn kat. 4',
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
    'PPW3-V4-M-EPEE-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V4',
    NULL, 6, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    245,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V4-M-EPEE-2025-2026'),
    1,
    'SOBIERAJ Wojciech'
); -- matched: SOBIERAJ Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    1,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V4-M-EPEE-2025-2026'),
    2,
    'ADAMCZEWSKI Wojciech'
); -- matched: ADAMCZEWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    262,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V4-M-EPEE-2025-2026'),
    3,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    114,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V4-M-EPEE-2025-2026'),
    4,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    45,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V4-M-EPEE-2025-2026'),
    5,
    'DONKE Ryszard'
); -- matched: DONKE Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    24,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V4-M-EPEE-2025-2026'),
    6,
    'BORKOWSKI Andrzej'
); -- matched: BORKOWSKI Andrzej (score=100.0)
-- Compute scores for PPW3-V4-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V4-M-EPEE-2025-2026')
);

-- ---- PP4: IV Puchar Polski Weteranów (SZPADA MĘŻCZYZN v4) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW4-2025-2026',
    'IV Puchar Polski Weteranów',
    'SZPADA MĘŻCZYZN v4',
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
    'PPW4-V4-M-EPEE-2025-2026',
    'IV Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V4',
    NULL, 6, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    1,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-EPEE-2025-2026'),
    1,
    'ADAMCZEWSKI Wojciech'
); -- matched: ADAMCZEWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    262,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-EPEE-2025-2026'),
    2,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    245,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-EPEE-2025-2026'),
    3,
    'SOBIERAJ Wojciech'
); -- matched: SOBIERAJ Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    114,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-EPEE-2025-2026'),
    4,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-EPEE-2025-2026'),
    5,
    'FURMANIAK Andrzej'
); -- matched: FURMANIAK Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    190,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-EPEE-2025-2026'),
    6,
    'NOWAKOWSKI Andrzej'
); -- matched: NOWAKOWSKI Andrzej (score=100.0)
-- Compute scores for PPW4-V4-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-EPEE-2025-2026')
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
    'PEW1-V4-M-EPEE-2025-2026',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'EPEE', 'M', 'V4',
    NULL, 17, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'ELFVERSON Göran' place=1
-- SKIPPED (international, no master data): 'STOCK Jean' place=2
-- SKIPPED (international, no master data): 'PARISI PASQUALE' place=3
-- SKIPPED (international, no master data): 'RUBINO Salvatore' place=4
-- SKIPPED (international, no master data): 'PIANCA Giuliano' place=5
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    262,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V4-M-EPEE-2025-2026'),
    6,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
-- SKIPPED (international, no master data): 'HORVÁTH Gábor György' place=7
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    245,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V4-M-EPEE-2025-2026'),
    8,
    'SOBIERAJ Wojciech'
); -- matched: SOBIERAJ Wojciech (score=100.0)
-- SKIPPED (international, no master data): 'JUGAN Bruce' place=9
-- SKIPPED (international, no master data): 'IMREH László' place=10
-- SKIPPED (international, no master data): 'GALE Milan' place=11
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    120,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V4-M-EPEE-2025-2026'),
    12,
    'KOLLAR Gabriel'
); -- matched: KOLLAR Gabriel (score=100.0)
-- SKIPPED (international, no master data): 'MARCZALI László' place=13
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    161,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V4-M-EPEE-2025-2026'),
    14,
    'LYNCH Patrick'
); -- matched: LYNCH Pat (score=100.0)
-- SKIPPED (international, no master data): 'GRABNER Karol' place=15
-- SKIPPED (international, no master data): 'KESZTHELYI László Dr.' place=16
-- SKIPPED (international, no master data): 'WERLING Thomas' place=17
-- Compute scores for PEW1-V4-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V4-M-EPEE-2025-2026')
);

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
    'PEW2-V4-M-EPEE-2025-2026',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'EPEE', 'M', 'V4',
    NULL, 38, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'BADE' place=1
-- SKIPPED (international, no master data): 'BARDI' place=2
-- SKIPPED (international, no master data): 'DRAHUSAK' place=3
-- SKIPPED (international, no master data): 'DOUSSE' place=4
-- SKIPPED (international, no master data): 'SCHÜLER' place=5
-- SKIPPED (international, no master data): 'CICHOSZ' place=6
-- SKIPPED (international, no master data): 'GUTIÉRREZ-DÁVILA' place=7
-- SKIPPED (international, no master data): 'KATZLBERGER' place=8
-- SKIPPED (international, no master data): 'FASCI' place=9
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    291,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V4-M-EPEE-2025-2026'),
    10,
    'WHITLEY'
); -- matched: WHITLEY Gary (score=73.6842105263158)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V4-M-EPEE-2025-2026'),
    11,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
-- SKIPPED (international, no master data): 'TOLEDO ISAAC' place=12
-- SKIPPED (international, no master data): 'MULLER' place=13
-- SKIPPED (international, no master data): 'LÖRINCZI' place=14
-- SKIPPED (international, no master data): 'OLIVARES' place=15
-- SKIPPED (international, no master data): 'BAKER' place=16
-- SKIPPED (international, no master data): 'BALCÁZAR NAVARRO' place=17
-- SKIPPED (international, no master data): 'PELLUZ QUIRANTE' place=18
-- SKIPPED (international, no master data): 'DAMAS FLORES' place=19
-- SKIPPED (international, no master data): 'CSIKOS' place=20
-- SKIPPED (international, no master data): 'GURI LOPEZ' place=21
-- SKIPPED (international, no master data): 'DI LORETO DI PAOLANTONIO' place=22
-- SKIPPED (international, no master data): 'PINK' place=23
-- SKIPPED (international, no master data): 'PARISI' place=24
-- SKIPPED (international, no master data): 'EZAMA' place=25
-- SKIPPED (international, no master data): 'DUFAU' place=26
-- SKIPPED (international, no master data): 'OHRABLO' place=27
-- SKIPPED (international, no master data): 'BRANDIS' place=28
-- SKIPPED (international, no master data): 'ZAGO' place=29
-- SKIPPED (international, no master data): 'PARRA' place=30
-- SKIPPED (international, no master data): 'ARTEAGA QUINTANA' place=31
-- SKIPPED (international, no master data): 'CALDERON' place=32
-- SKIPPED (international, no master data): 'DEL BUSTO FANO' place=33
-- SKIPPED (international, no master data): 'FORNASERI' place=34
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    161,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V4-M-EPEE-2025-2026'),
    35,
    'LYNCH'
); -- matched: LYNCH Pat (score=71.42857142857143)
-- SKIPPED (international, no master data): 'BREDDO' place=36
-- SKIPPED (international, no master data): 'KESZTHELYI' place=37
-- SKIPPED (international, no master data): 'RODRÍGUEZ CALVO' place=38
-- Compute scores for PEW2-V4-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V4-M-EPEE-2025-2026')
);

-- ---- PEW3: EVF Grand Prix 3 (Guildford) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW3-2025-2026',
    'EVF Grand Prix 3',
    'Guildford',
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
    'PEW3-V4-M-EPEE-2025-2026',
    'EVF Grand Prix 3',
    'PEW',
    'EPEE', 'M', 'V4',
    '2026-10-01', 19, 'https://www.fencingtimelive.com/events/results/220C587A8C854C6C85EB62D26D62F6C9',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    245,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V4-M-EPEE-2025-2026'),
    11,
    'SOBIERAJ Wojciech'
); -- matched: SOBIERAJ Wojciech (score=100.0)
-- Compute scores for PEW3-V4-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V4-M-EPEE-2025-2026')
);

-- ---- PEW4: EVF Grand Prix 4 (2026-03-08-07 Napoli - 4 Prova Circuito Nazionale Master 2025-2 - Spada Maschile ) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW4-2025-2026',
    'EVF Grand Prix 4',
    '2026-03-08-07 Napoli - 4 Prova Circuito Nazionale Master 2025-2 - Spada Maschile ',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW4-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW4-2025-2026'),
    'PEW4-V4-M-EPEE-2025-2026',
    'EVF Grand Prix 4',
    'PEW',
    'EPEE', 'M', 'V4',
    NULL, 22, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'PIANCA GIULIANO' place=1
-- SKIPPED (international, no master data): 'PORA VALENTIN' place=2
-- SKIPPED (international, no master data): 'NIGON GABRIEL' place=3
-- SKIPPED (international, no master data): 'BOTTINO GIOVANNI' place=4
-- SKIPPED (international, no master data): 'MACCARONI ANGELO' place=5
-- SKIPPED (international, no master data): 'DI MATTEO ROBERTO' place=6
-- SKIPPED (international, no master data): 'FERRARIO DAVIDE' place=7
-- SKIPPED (international, no master data): 'MARINO GIUSEPPE AMEDEO' place=8
-- SKIPPED (international, no master data): 'CAMPOFREDA LUIGI' place=9
-- SKIPPED (international, no master data): 'BENEDETTI MASSIMO' place=10
-- SKIPPED (international, no master data): 'CUOMO BRUNO' place=11
-- SKIPPED (international, no master data): 'FABIANO LEONARDO' place=12
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    245,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V4-M-EPEE-2025-2026'),
    13,
    'SOBIERAJ WOJCIECH'
); -- matched: SOBIERAJ Wojciech (score=100.0)
-- SKIPPED (international, no master data): 'PATTI LEONARDO DONATO' place=14
-- SKIPPED (international, no master data): 'RUBINO SALVATORE' place=15
-- SKIPPED (international, no master data): 'PARISI PASQUALE' place=16
-- SKIPPED (international, no master data): 'DIONISIO GIORGIO' place=17
-- SKIPPED (international, no master data): 'TRAMBAJOLO AMEDEO' place=18
-- SKIPPED (international, no master data): 'MARCHINI BERARDO' place=19
-- SKIPPED (international, no master data): 'KESZTHELYI LASZLO' place=20
-- SKIPPED (international, no master data): 'CRIVELLI MAURIZIO' place=21
-- SKIPPED (international, no master data): 'CIRILLO GIUSEPPE' place=22
-- Compute scores for PEW4-V4-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V4-M-EPEE-2025-2026')
);

-- ---- PEW5: EVF Grand Prix 5 ( Mens Epee Cat 4 - Stockholm International Veteran Open 20 ) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW5-2025-2026',
    'EVF Grand Prix 5',
    ' Mens Epee Cat 4 - Stockholm International Veteran Open 20 ',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW5-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW5-2025-2026'),
    'PEW5-V4-M-EPEE-2025-2026',
    'EVF Grand Prix 5',
    'PEW',
    'EPEE', 'M', 'V4',
    NULL, 9, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'NIGON Gabriel' place=1
-- SKIPPED (international, no master data): 'BARVESTAD Peter' place=2
-- SKIPPED (international, no master data): 'ELFVERSON Goran' place=3
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    79,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V4-M-EPEE-2025-2026'),
    4,
    'GRUNDLEHNER Michael'
); -- matched: GRODNER Michał (score=72.72727272727273)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    120,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V4-M-EPEE-2025-2026'),
    5,
    'KOLLAR Gabriel'
); -- matched: KOLLAR Gabriel (score=100.0)
-- SKIPPED (international, no master data): 'RUBINO Salvatore' place=6
-- SKIPPED (international, no master data): 'PRUSAKIEWICZ Michal' place=7
-- SKIPPED (international, no master data): 'MULLER Paul' place=8
-- SKIPPED (international, no master data): 'SKAR Tore' place=9
-- Compute scores for PEW5-V4-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V4-M-EPEE-2025-2026')
);

-- ---- PEW6: EVF Grand Prix 6 (Szpada Mężczyzn V4) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW6-2025-2026',
    'EVF Grand Prix 6',
    'Szpada Mężczyzn V4',
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
    'PEW6-V4-M-EPEE-2025-2026',
    'EVF Grand Prix 6',
    'PEW',
    'EPEE', 'M', 'V4',
    NULL, 13, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    1,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2025-2026'),
    1,
    'ADAMCZEWSKI Wojciech'
); -- matched: ADAMCZEWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    314,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2025-2026'),
    2,
    'ZYLKA 4 Henryk'
); -- matched: ZYLKA Henryk (score=100.0)
-- SKIPPED (international, no master data): 'FARIA João Pedro' place=3
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    245,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2025-2026'),
    4,
    'SOBIERAJ Wojciech'
); -- matched: SOBIERAJ Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    120,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2025-2026'),
    5,
    'KOLLÁR Gabriel'
); -- matched: KOLLAR Gabriel (score=92.85714285714286)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    24,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2025-2026'),
    6,
    'BORKOWSKI Andrzej'
); -- matched: BORKOWSKI Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    161,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2025-2026'),
    7,
    'LYNCH Patrick'
); -- matched: LYNCH Pat (score=100.0)
-- SKIPPED (international, no master data): 'MCLEAN Robert' place=8
-- SKIPPED (international, no master data): 'MOREIRA Artur' place=9
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    48,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2025-2026'),
    10,
    'KRAWCZYK Paweł'
); -- matched: DROBCZYK Paweł (score=78.57142857142857)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    114,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2025-2026'),
    11,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
-- SKIPPED (international, no master data): 'RUBINO Salvatore' place=12
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    190,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2025-2026'),
    13,
    'NOWAKOWSKI Andrzej'
); -- matched: NOWAKOWSKI Andrzej (score=100.0)
-- Compute scores for PEW6-V4-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2025-2026')
);

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): N=0 — tournament had no participants

-- SKIP PS (Puchar Świata): N=0 — tournament had no participants

-- Summary
-- Total results matched:   57
-- Total results unmatched: 80
-- Total auto-created:      0
