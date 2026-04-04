-- =========================================================================
-- Season 2025-2026 — V3 M EPEE — generated from SZPADA-3-2025-2026.xlsx
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
    'PPW1-V3-M-EPEE-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V3',
    '2025-09-28', 7, 'https://www.fencingtimelive.com/events/results/516F915B21C14B96A2C5CD7F896BBDFD',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2025-2026'),
    1,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2025-2026'),
    2,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    10,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2025-2026'),
    3,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    279,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2025-2026'),
    4,
    'TRACZ Jerzy'
); -- matched: TRACZ Jerzy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2025-2026'),
    5,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    257,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2025-2026'),
    6,
    'STOŁOWSKI Mariusz'
); -- matched: STOŁOWSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    38,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2025-2026'),
    7,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
-- Compute scores for PPW1-V3-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2025-2026')
);

-- ---- PP2: II Puchar Polski Weteranów (SZPADA MĘŻCZYZN 3 WETERANI) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW2-2025-2026',
    'II Puchar Polski Weteranów',
    'SZPADA MĘŻCZYZN 3 WETERANI',
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
    'PPW2-V3-M-EPEE-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V3',
    NULL, 5, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-EPEE-2025-2026'),
    1,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    10,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-EPEE-2025-2026'),
    2,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-EPEE-2025-2026'),
    3,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-EPEE-2025-2026'),
    4,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    257,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-EPEE-2025-2026'),
    5,
    'STOŁOWSKI Mariusz'
); -- matched: STOŁOWSKI Mariusz (score=100.0)
-- Compute scores for PPW2-V3-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-EPEE-2025-2026')
);

-- ---- PP3: III Puchar Polski Weteranów (Szpada Mężczyzn kat. 3) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW3-2025-2026',
    'III Puchar Polski Weteranów',
    'Szpada Mężczyzn kat. 3',
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
    'PPW3-V3-M-EPEE-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V3',
    NULL, 8, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2025-2026'),
    1,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2025-2026'),
    2,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2025-2026'),
    3,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    10,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2025-2026'),
    4,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    257,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2025-2026'),
    5,
    'STOŁOWSKI Mariusz'
); -- matched: STOŁOWSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2025-2026'),
    6,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    279,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2025-2026'),
    7,
    'TRACZ Jerzy'
); -- matched: TRACZ Jerzy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    38,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2025-2026'),
    8,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
-- Compute scores for PPW3-V3-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2025-2026')
);

-- ---- PP4: IV Puchar Polski Weteranów (SZPADA MĘŻCZYZN v3) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW4-2025-2026',
    'IV Puchar Polski Weteranów',
    'SZPADA MĘŻCZYZN v3',
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
    'PPW4-V3-M-EPEE-2025-2026',
    'IV Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V3',
    NULL, 7, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2025-2026'),
    1,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    169,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2025-2026'),
    2,
    'MAŁASIŃSKI Adam'
); -- matched: MAŁASIŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2025-2026'),
    3,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2025-2026'),
    4,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    257,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2025-2026'),
    5,
    'STOŁOWSKI Mariusz'
); -- matched: STOŁOWSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2025-2026'),
    6,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    38,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2025-2026'),
    7,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
-- Compute scores for PPW4-V3-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2025-2026')
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
    'PEW1-V3-M-EPEE-2025-2026',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'EPEE', 'M', 'V3',
    NULL, 34, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'BÁRDI Artur Róbert' place=1
-- SKIPPED (international, no master data): 'MELNIKOV Sergei' place=2
-- SKIPPED (international, no master data): 'RAB Attila' place=3
-- SKIPPED (international, no master data): 'AKERBERG Thomas' place=4
-- SKIPPED (international, no master data): 'HAJTMAN Olaf' place=5
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-EPEE-2025-2026'),
    6,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
-- SKIPPED (international, no master data): 'VÖLCSEI György Ferenc' place=7
-- SKIPPED (international, no master data): 'SZALAY ID. Károly' place=8
-- SKIPPED (international, no master data): 'CSIKÓS Attila' place=9
-- SKIPPED (international, no master data): 'OHRABLO Branislav' place=10
-- SKIPPED (international, no master data): 'DRAHUSAK Boris' place=11
-- SKIPPED (international, no master data): 'CICHOSZ Matthias' place=12
-- SKIPPED (international, no master data): 'RESCHKO Leonid' place=13
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-EPEE-2025-2026'),
    14,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-EPEE-2025-2026'),
    15,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
-- SKIPPED (international, no master data): 'BOUTIN Thierry' place=16
-- SKIPPED (international, no master data): 'MUNN Stephan' place=17
-- SKIPPED (international, no master data): 'KOLB Tamás' place=18
-- SKIPPED (international, no master data): 'KOICHI Yamada' place=19
-- SKIPPED (international, no master data): 'TÖLGYESI Ákos Antal' place=20
-- SKIPPED (international, no master data): 'SJÖDAHL Fredrik' place=21
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    315,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-EPEE-2025-2026'),
    22,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
-- SKIPPED (international, no master data): 'PLEVNIK Janko' place=23
-- SKIPPED (international, no master data): 'BOKUCHAVA Zurab' place=24
-- SKIPPED (international, no master data): 'HALMOS András' place=25
-- SKIPPED (international, no master data): 'LŐRINCZI Leó Ervin' place=26
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    291,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-EPEE-2025-2026'),
    27,
    'WHITLEY Gary'
); -- matched: WHITLEY Gary (score=100.0)
-- Compute scores for PEW1-V3-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-EPEE-2025-2026')
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
    'PEW2-V3-M-EPEE-2025-2026',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'EPEE', 'M', 'V3',
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
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V3-M-EPEE-2025-2026'),
    10,
    'WHITLEY'
); -- matched: WHITLEY Gary (score=73.6842105263158)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V3-M-EPEE-2025-2026'),
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
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V3-M-EPEE-2025-2026'),
    35,
    'LYNCH'
); -- matched: LYNCH Pat (score=71.42857142857143)
-- SKIPPED (international, no master data): 'BREDDO' place=36
-- SKIPPED (international, no master data): 'KESZTHELYI' place=37
-- SKIPPED (international, no master data): 'RODRÍGUEZ CALVO' place=38
-- Compute scores for PEW2-V3-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V3-M-EPEE-2025-2026')
);

-- ---- PEW3: EVF Grand Prix 3 (Men's Epee Category 3) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW3-2025-2026',
    'EVF Grand Prix 3',
    'Men''s Epee Category 3',
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
    'PEW3-V3-M-EPEE-2025-2026',
    'EVF Grand Prix 3',
    'PEW',
    'EPEE', 'M', 'V3',
    NULL, 44, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'ALIPPI 3 Stefano' place=1
-- SKIPPED (international, no master data): 'BAKER 3 Jeremy' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2025-2026'),
    3,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
-- SKIPPED (international, no master data): 'SJODAHL 3 Fredrik' place=4
-- SKIPPED (international, no master data): 'PINK 3 Simon' place=5
-- SKIPPED (international, no master data): 'BARDI 3 Robert' place=6
-- SKIPPED (international, no master data): 'ROSS 3 Will' place=7
-- SKIPPED (international, no master data): 'MARTIN 3 Steve' place=8
-- SKIPPED (international, no master data): 'AKERBERG 3 Thomas' place=9
-- SKIPPED (international, no master data): 'FRANK 3 Fred' place=10
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2025-2026'),
    11,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
-- SKIPPED (international, no master data): 'MILLER 3 Will' place=12
-- SKIPPED (international, no master data): 'TRIBUZIO 3 Riccardo' place=13
-- SKIPPED (international, no master data): 'GOUGH 3 Robert' place=14
-- SKIPPED (international, no master data): 'DICKINSON 3 Paul' place=15
-- SKIPPED (international, no master data): 'ZIEGLER 3 Udo' place=16
-- SKIPPED (international, no master data): 'BOUTIN 3 Thierry' place=17
-- SKIPPED (international, no master data): 'VAN DEN BERG 3 Paul' place=18
-- SKIPPED (international, no master data): 'FROELICH 3 Theo' place=19
-- SKIPPED (international, no master data): 'THOMAS 3 Neale' place=20
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    247,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2025-2026'),
    21,
    'SOMERS 3 Jan'
); -- matched: SOMERS Jan (score=100.0)
-- SKIPPED (international, no master data): 'RUSEV 3 Hristo' place=22
-- SKIPPED (international, no master data): 'CSIKOS 3 Attila' place=23
-- SKIPPED (international, no master data): 'LUCKMAN 3 Andrew' place=24
-- SKIPPED (international, no master data): 'SPANO 3 Umberto' place=25
-- SKIPPED (international, no master data): 'JORDAN 3 Philip' place=26
-- SKIPPED (international, no master data): 'MUNN 3 Stephan' place=27
-- SKIPPED (international, no master data): 'HYDE 3 John' place=28
-- SKIPPED (international, no master data): 'KIDD 3 John' place=29
-- SKIPPED (international, no master data): 'BULLOCK 3 Ian' place=30
-- SKIPPED (international, no master data): 'LAKELAND 3 Nicholas' place=31
-- SKIPPED (international, no master data): 'BRANDWOOD 3 Christopher' place=32
-- SKIPPED (international, no master data): 'BALBONTIN 3 Roberto' place=33
-- SKIPPED (international, no master data): 'BISSELL 3 Tim' place=34
-- SKIPPED (international, no master data): 'CALLERI 3 Michele' place=35
-- SKIPPED (international, no master data): 'MASSA 3 Maurizio' place=36
-- SKIPPED (international, no master data): 'BROCK 3 Simon' place=37
-- SKIPPED (international, no master data): 'EMMANOUIL 3 Dimitrios' place=38
-- SKIPPED (international, no master data): 'FLEMING-FIDO 3 James' place=39
-- SKIPPED (international, no master data): 'CHELL 3 Matthew' place=40
-- SKIPPED (international, no master data): 'MONCRIEFF 3 Erik' place=41
-- SKIPPED (international, no master data): 'ROBINSON 3 Michael' place=42
-- SKIPPED (international, no master data): 'MIDDLETON 3 Nigel' place=43
-- SKIPPED (international, no master data): 'CISLER 3 Pavel' place=44
-- SKIPPED (international, no master data): 'SJODAHL 3 Fredrik' place=47
-- Compute scores for PEW3-V3-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2025-2026')
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
    'PEW4-V3-M-EPEE-2025-2026',
    'EVF Grand Prix 4',
    'PEW',
    'EPEE', 'M', 'V3',
    NULL, 74, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'CARACCIOLO STEFANO ANTONIO' place=1
-- SKIPPED (international, no master data): 'MAGNI LUCA' place=2
-- SKIPPED (international, no master data): 'ALIPPI STEFANO CARLO C' place=3
-- SKIPPED (international, no master data): 'MARKOV PHILIPPE' place=4
-- SKIPPED (international, no master data): 'TULUMELLO GIOVANNI' place=5
-- SKIPPED (international, no master data): 'SEGUIN MARC' place=6
-- SKIPPED (international, no master data): 'ZICARI ALBERTO' place=7
-- SKIPPED (international, no master data): 'KNECHT ROLF' place=8
-- SKIPPED (international, no master data): 'GUY HUBERT' place=9
-- SKIPPED (international, no master data): 'FERRO COSIMO ANTONIO' place=10
-- SKIPPED (international, no master data): 'DRAHUSAK BORIS' place=11
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V3-M-EPEE-2025-2026'),
    12,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
-- SKIPPED (international, no master data): 'COZZI GIOVANNI' place=13
-- SKIPPED (international, no master data): 'VANNUCCI ANTONIO' place=14
-- SKIPPED (international, no master data): 'BATTIGALLI PIERPAOLO LOREN' place=15
-- SKIPPED (international, no master data): 'TESTOR SCHNELL TOMAS' place=16
-- SKIPPED (international, no master data): 'SCHUELER THOMAS' place=17
-- SKIPPED (international, no master data): 'OHRABLO BRANISLAV' place=18
-- SKIPPED (international, no master data): 'FASCÌ ANTONIO MAURO' place=19
-- SKIPPED (international, no master data): 'WAELLE PHILIPPE' place=20
-- SKIPPED (international, no master data): 'KAZMER JOBST' place=21
-- SKIPPED (international, no master data): 'VAN DEN BERG PAUL' place=22
-- SKIPPED (international, no master data): 'CANNAS DINO' place=23
-- SKIPPED (international, no master data): 'FROELICH THEO' place=24
-- SKIPPED (international, no master data): 'SPANÒ UMBERTO' place=25
-- SKIPPED (international, no master data): 'ALLIEVI GIANLUCA' place=26
-- SKIPPED (international, no master data): 'BOUTIN THIERRY' place=27
-- SKIPPED (international, no master data): 'BELLOMO FRANCESCO' place=28
-- SKIPPED (international, no master data): 'BOSIO MARCO' place=29
-- SKIPPED (international, no master data): 'PERUCHETTI FABIO' place=30
-- SKIPPED (international, no master data): 'STRANO FEDERICO' place=31
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    247,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V3-M-EPEE-2025-2026'),
    32,
    'SOMERS JAN'
); -- matched: SOMERS Jan (score=100.0)
-- SKIPPED (international, no master data): 'BELLI PAOLO' place=33
-- SKIPPED (international, no master data): 'RUSSO EUGENIO ATTILIO' place=34
-- SKIPPED (international, no master data): 'DOUSSE CHRISTIAN' place=35
-- SKIPPED (international, no master data): 'SERANGELI CLAUDIO' place=36
-- SKIPPED (international, no master data): 'LANA MASSIMO' place=37
-- SKIPPED (international, no master data): 'EMMENEGGER JURGEN GERHARD' place=38
-- SKIPPED (international, no master data): 'ARTHURS DAVID' place=39
-- SKIPPED (international, no master data): 'PAIANO ROBERTO' place=40
-- SKIPPED (international, no master data): 'SCHMITT JEAN NICOLAS' place=41
-- SKIPPED (international, no master data): 'DI LORETO MARCO' place=42
-- SKIPPED (international, no master data): 'MANGIAROTTI ALBERTO' place=43
-- SKIPPED (international, no master data): 'BARIONOVI MAURO' place=44
-- SKIPPED (international, no master data): 'VADASZ GABOR' place=45
-- SKIPPED (international, no master data): 'FARCI FABIO' place=46
-- SKIPPED (international, no master data): 'EMMANOUIL DIMITRIS' place=47
-- SKIPPED (international, no master data): 'MARCUCCIO AUGUSTO' place=48
-- SKIPPED (international, no master data): 'CALLERI MICHELE' place=49
-- SKIPPED (international, no master data): 'BRAVI STEFANO' place=50
-- SKIPPED (international, no master data): 'BERTOLLA ANTONELLO' place=51
-- SKIPPED (international, no master data): 'KAPIANIDZE SOSO' place=52
-- SKIPPED (international, no master data): 'BREDDO UGO' place=53
-- SKIPPED (international, no master data): 'BRAMBILLA MARCO' place=54
-- SKIPPED (international, no master data): 'LA SCALA PIER GALILEO' place=55
-- SKIPPED (international, no master data): 'GUARDIA CARLO' place=56
-- SKIPPED (international, no master data): 'THALMEINER ZOLTAN' place=57
-- SKIPPED (international, no master data): 'CALLERI MARCO' place=58
-- SKIPPED (international, no master data): 'CORDUA FRANCESCO' place=59
-- SKIPPED (international, no master data): 'MANCA SEBASTIANO' place=60
-- SKIPPED (international, no master data): 'MAGLIE VITO' place=61
-- SKIPPED (international, no master data): 'SICA VINCENZO' place=62
-- SKIPPED (international, no master data): 'ZAGO LINO' place=63
-- SKIPPED (international, no master data): 'CAMPANILE ENRICO' place=64
-- SKIPPED (international, no master data): 'SUBTIRICA DORU' place=65
-- SKIPPED (international, no master data): 'RENINO CIRO' place=66
-- SKIPPED (international, no master data): 'D''AGOSTINO ALESSANDRO' place=67
-- SKIPPED (international, no master data): 'MONTEFORTE MAURO' place=68
-- SKIPPED (international, no master data): 'CALITERNA PIERO' place=69
-- SKIPPED (international, no master data): 'LANZILLO MASSIMO' place=70
-- SKIPPED (international, no master data): 'LORINCZI LEO ERVIN' place=71
-- SKIPPED (international, no master data): 'ROSSI ANDREA' place=72
-- SKIPPED (international, no master data): 'VITALE GENNARO' place=73
-- SKIPPED (international, no master data): 'CASAZZA PAOLO' place=74
-- Compute scores for PEW4-V3-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V3-M-EPEE-2025-2026')
);

-- SKIP PEW5 (EVF Grand Prix 5): 0 matched fencers in DB — tournament not created

-- ---- PEW6: EVF Grand Prix 6 (Szpada Mężczyzn V3) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW6-2025-2026',
    'EVF Grand Prix 6',
    'Szpada Mężczyzn V3',
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
    'PEW6-V3-M-EPEE-2025-2026',
    'EVF Grand Prix 6',
    'PEW',
    'EPEE', 'M', 'V3',
    NULL, 18, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'FALCK-YTTER Jan' place=1
-- SKIPPED (international, no master data): 'BARDI Robert' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2025-2026'),
    3,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
-- SKIPPED (international, no master data): 'BAKER Jeremy' place=4
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2025-2026'),
    5,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
-- SKIPPED (international, no master data): 'FRED Arnold' place=6
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2025-2026'),
    7,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
-- SKIPPED (international, no master data): 'MELNIKOV Sergei' place=8
-- SKIPPED (international, no master data): 'PINK Simon' place=9
-- SKIPPED (international, no master data): 'WATTENBERG 3 Dirk' place=10
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    291,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2025-2026'),
    11,
    'WHITLEY Gary'
); -- matched: WHITLEY Gary (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2025-2026'),
    12,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    169,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2025-2026'),
    13,
    'MAŁASIŃSKI Adam'
); -- matched: MAŁASIŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    279,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2025-2026'),
    14,
    'TRACZ Jerzy'
); -- matched: TRACZ Jerzy (score=100.0)
-- SKIPPED (international, no master data): 'BENNETT Craig' place=15
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    38,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2025-2026'),
    16,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
-- SKIPPED (international, no master data): 'KAISER Wolfgang' place=17
-- SKIPPED (international, no master data): 'KARATHANASIS Athanasios' place=18
-- Compute scores for PEW6-V3-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2025-2026')
);

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): 0 matched fencers in DB — tournament not created

-- SKIP PS (Puchar Świata): N=0 — tournament had no participants

-- Summary
-- Total results matched:   68
-- Total results unmatched: 212
-- Total auto-created:      0
