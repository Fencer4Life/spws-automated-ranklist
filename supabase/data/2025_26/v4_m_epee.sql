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
    229,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2025-2026'),
    1,
    'SZYMKOWIAK Krzysztof'
); -- matched: SZYMKOWIAK Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    221,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2025-2026'),
    2,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    211,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2025-2026'),
    3,
    'SOBIERAJ Wojciech'
); -- matched: SOBIERAJ Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2025-2026'),
    4,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    376,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2025-2026'),
    5,
    'ZYLKA Henryk'
); -- matched: ZYLKA Henryk (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    98,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2025-2026'),
    6,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    57,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2025-2026'),
    7,
    'FURMANIAK Andrzej'
); -- matched: FURMANIAK Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    166,
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
    221,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V4-M-EPEE-2025-2026'),
    1,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    211,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V4-M-EPEE-2025-2026'),
    2,
    'SOBIERAJ Wojciech'
); -- matched: SOBIERAJ Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
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
    57,
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
    211,
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
    221,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V4-M-EPEE-2025-2026'),
    3,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V4-M-EPEE-2025-2026'),
    4,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    281,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V4-M-EPEE-2025-2026'),
    5,
    'DONKE Ryszard'
); -- matched: DONKE Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    20,
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
    221,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-EPEE-2025-2026'),
    2,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    211,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-EPEE-2025-2026'),
    3,
    'SOBIERAJ Wojciech'
); -- matched: SOBIERAJ Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-EPEE-2025-2026'),
    4,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    57,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-EPEE-2025-2026'),
    5,
    'FURMANIAK Andrzej'
); -- matched: FURMANIAK Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    166,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-EPEE-2025-2026'),
    6,
    'NOWAKOWSKI Andrzej'
); -- matched: NOWAKOWSKI Andrzej (score=100.0)
-- Compute scores for PPW4-V4-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-EPEE-2025-2026')
);

-- SKIP PP5: event not yet held (SCHEDULED) — results are rolling carry-over from previous season

-- SKIP MPW: event not yet held (SCHEDULED) — results are rolling carry-over from previous season

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
-- UNMATCHED (score<80): 'ELFVERSON Göran' place=1
-- UNMATCHED (score<80): 'STOCK Jean' place=2
-- UNMATCHED (score<80): 'PARISI PASQUALE' place=3
-- UNMATCHED (score<80): 'RUBINO Salvatore' place=4
-- UNMATCHED (score<80): 'PIANCA Giuliano' place=5
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    221,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V4-M-EPEE-2025-2026'),
    6,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
-- UNMATCHED (score<80): 'HORVÁTH Gábor György' place=7
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    211,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V4-M-EPEE-2025-2026'),
    8,
    'SOBIERAJ Wojciech'
); -- matched: SOBIERAJ Wojciech (score=100.0)
-- UNMATCHED (score<80): 'JUGAN Bruce' place=9
-- UNMATCHED (score<80): 'IMREH László' place=10
-- UNMATCHED (score<80): 'GALE Milan' place=11
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    113,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V4-M-EPEE-2025-2026'),
    12,
    'KOLLAR Gabriel'
); -- matched: KOLLAR Gabriel (score=100.0)
-- UNMATCHED (score<80): 'MARCZALI László' place=13
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    314,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V4-M-EPEE-2025-2026'),
    14,
    'LYNCH Patrick'
); -- matched: LYNCH Pat (score=81.81818181818181)
-- UNMATCHED (score<80): 'GRABNER Karol' place=15
-- UNMATCHED (score<80): 'KESZTHELYI László Dr.' place=16
-- UNMATCHED (score<80): 'WERLING Thomas' place=17
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
-- UNMATCHED (score<80): 'BADE' place=1
-- UNMATCHED (score<80): 'BARDI' place=2
-- UNMATCHED (score<80): 'DRAHUSAK' place=3
-- UNMATCHED (score<80): 'DOUSSE' place=4
-- UNMATCHED (score<80): 'SCHÜLER' place=5
-- UNMATCHED (score<80): 'CICHOSZ' place=6
-- UNMATCHED (score<80): 'GUTIÉRREZ-DÁVILA' place=7
-- UNMATCHED (score<80): 'KATZLBERGER' place=8
-- UNMATCHED (score<80): 'FASCI' place=9
-- UNMATCHED (score<80): 'WHITLEY' place=10
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    121,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V4-M-EPEE-2025-2026'),
    11,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
-- UNMATCHED (score<80): 'TOLEDO ISAAC' place=12
-- UNMATCHED (score<80): 'MULLER' place=13
-- UNMATCHED (score<80): 'LÖRINCZI' place=14
-- UNMATCHED (score<80): 'OLIVARES' place=15
-- UNMATCHED (score<80): 'BAKER' place=16
-- UNMATCHED (score<80): 'BALCÁZAR NAVARRO' place=17
-- UNMATCHED (score<80): 'PELLUZ QUIRANTE' place=18
-- UNMATCHED (score<80): 'DAMAS FLORES' place=19
-- UNMATCHED (score<80): 'CSIKOS' place=20
-- UNMATCHED (score<80): 'GURI LOPEZ' place=21
-- UNMATCHED (score<80): 'DI LORETO DI PAOLANTONIO' place=22
-- UNMATCHED (score<80): 'PINK' place=23
-- UNMATCHED (score<80): 'PARISI' place=24
-- UNMATCHED (score<80): 'EZAMA' place=25
-- UNMATCHED (score<80): 'DUFAU' place=26
-- UNMATCHED (score<80): 'OHRABLO' place=27
-- UNMATCHED (score<80): 'BRANDIS' place=28
-- UNMATCHED (score<80): 'ZAGO' place=29
-- UNMATCHED (score<80): 'PARRA' place=30
-- UNMATCHED (score<80): 'ARTEAGA QUINTANA' place=31
-- UNMATCHED (score<80): 'CALDERON' place=32
-- UNMATCHED (score<80): 'DEL BUSTO FANO' place=33
-- UNMATCHED (score<80): 'FORNASERI' place=34
-- UNMATCHED (score<80): 'LYNCH' place=35
-- UNMATCHED (score<80): 'BREDDO' place=36
-- UNMATCHED (score<80): 'KESZTHELYI' place=37
-- UNMATCHED (score<80): 'RODRÍGUEZ CALVO' place=38
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
    211,
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
-- UNMATCHED (score<80): 'PIANCA GIULIANO' place=1
-- UNMATCHED (score<80): 'PORA VALENTIN' place=2
-- UNMATCHED (score<80): 'NIGON GABRIEL' place=3
-- UNMATCHED (score<80): 'BOTTINO GIOVANNI' place=4
-- UNMATCHED (score<80): 'MACCARONI ANGELO' place=5
-- UNMATCHED (score<80): 'DI MATTEO ROBERTO' place=6
-- UNMATCHED (score<80): 'FERRARIO DAVIDE' place=7
-- UNMATCHED (score<80): 'MARINO GIUSEPPE AMEDEO' place=8
-- UNMATCHED (score<80): 'CAMPOFREDA LUIGI' place=9
-- UNMATCHED (score<80): 'BENEDETTI MASSIMO' place=10
-- UNMATCHED (score<80): 'CUOMO BRUNO' place=11
-- UNMATCHED (score<80): 'FABIANO LEONARDO' place=12
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    211,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V4-M-EPEE-2025-2026'),
    13,
    'SOBIERAJ WOJCIECH'
); -- matched: SOBIERAJ Wojciech (score=100.0)
-- UNMATCHED (score<80): 'PATTI LEONARDO DONATO' place=14
-- UNMATCHED (score<80): 'RUBINO SALVATORE' place=15
-- UNMATCHED (score<80): 'PARISI PASQUALE' place=16
-- UNMATCHED (score<80): 'DIONISIO GIORGIO' place=17
-- UNMATCHED (score<80): 'TRAMBAJOLO AMEDEO' place=18
-- UNMATCHED (score<80): 'MARCHINI BERARDO' place=19
-- UNMATCHED (score<80): 'KESZTHELYI LASZLO' place=20
-- UNMATCHED (score<80): 'CRIVELLI MAURIZIO' place=21
-- UNMATCHED (score<80): 'CIRILLO GIUSEPPE' place=22
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
-- UNMATCHED (score<80): 'NIGON Gabriel' place=1
-- UNMATCHED (score<80): 'BARVESTAD Peter' place=2
-- UNMATCHED (score<80): 'ELFVERSON Goran' place=3
-- UNMATCHED (score<80): 'GRUNDLEHNER Michael' place=4
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    113,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V4-M-EPEE-2025-2026'),
    5,
    'KOLLAR Gabriel'
); -- matched: KOLLAR Gabriel (score=100.0)
-- UNMATCHED (score<80): 'RUBINO Salvatore' place=6
-- UNMATCHED (score<80): 'PRUSAKIEWICZ Michal' place=7
-- UNMATCHED (score<80): 'MULLER Paul' place=8
-- UNMATCHED (score<80): 'SKAR Tore' place=9
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
    376,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2025-2026'),
    2,
    'ZYLKA 4 Henryk'
); -- matched: ZYLKA Henryk (score=92.3076923076923)
-- UNMATCHED (score<80): 'FARIA João Pedro' place=3
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    211,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2025-2026'),
    4,
    'SOBIERAJ Wojciech'
); -- matched: SOBIERAJ Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    113,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2025-2026'),
    5,
    'KOLLÁR Gabriel'
); -- matched: KOLLAR Gabriel (score=92.85714285714286)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    20,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2025-2026'),
    6,
    'BORKOWSKI Andrzej'
); -- matched: BORKOWSKI Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    314,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2025-2026'),
    7,
    'LYNCH Patrick'
); -- matched: LYNCH Pat (score=81.81818181818181)
-- UNMATCHED (score<80): 'MCLEAN Robert' place=8
-- UNMATCHED (score<80): 'MOREIRA Artur' place=9
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    133,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2025-2026'),
    10,
    'KRAWCZYK Paweł'
); -- matched: KRAWCZYK Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2025-2026'),
    11,
    'KIERSZNICKI Ryszard'
); -- matched: KIERSZNICKI Ryszard (score=100.0)
-- UNMATCHED (score<80): 'RUBINO Salvatore' place=12
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    166,
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

-- SKIP IMEW: event not yet held (SCHEDULED) — results are rolling carry-over from previous season

-- Summary
-- Total results matched:   54
-- Total results unmatched: 83
