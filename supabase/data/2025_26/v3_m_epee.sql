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
    42,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2025-2026'),
    1,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    136,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2025-2026'),
    2,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    6,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2025-2026'),
    3,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    236,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2025-2026'),
    4,
    'TRACZ Jerzy'
); -- matched: TRACZ Jerzy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    88,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2025-2026'),
    5,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    218,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2025-2026'),
    6,
    'STOŁOWSKI Mariusz'
); -- matched: STOŁOWSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    31,
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
    121,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-EPEE-2025-2026'),
    1,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    6,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-EPEE-2025-2026'),
    2,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    42,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-EPEE-2025-2026'),
    3,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    136,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-EPEE-2025-2026'),
    4,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    218,
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
    136,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2025-2026'),
    1,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    121,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2025-2026'),
    2,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    42,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2025-2026'),
    3,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    6,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2025-2026'),
    4,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    218,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2025-2026'),
    5,
    'STOŁOWSKI Mariusz'
); -- matched: STOŁOWSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    88,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2025-2026'),
    6,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    236,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2025-2026'),
    7,
    'TRACZ Jerzy'
); -- matched: TRACZ Jerzy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    31,
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
    136,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2025-2026'),
    1,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2025-2026'),
    2,
    'MAŁASIŃSKI Adam'
); -- matched: MAŁASIŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    42,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2025-2026'),
    3,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    121,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2025-2026'),
    4,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    218,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2025-2026'),
    5,
    'STOŁOWSKI Mariusz'
); -- matched: STOŁOWSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    88,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2025-2026'),
    6,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    31,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2025-2026'),
    7,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
-- Compute scores for PPW4-V3-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2025-2026')
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
    'PEW1-V3-M-EPEE-2025-2026',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'EPEE', 'M', 'V3',
    NULL, 34, NULL,
    'SCORED'
);
-- UNMATCHED (score<80): 'BÁRDI Artur Róbert' place=1
-- UNMATCHED (score<80): 'MELNIKOV Sergei' place=2
-- UNMATCHED (score<80): 'RAB Attila' place=3
-- UNMATCHED (score<80): 'AKERBERG Thomas' place=4
-- UNMATCHED (score<80): 'HAJTMAN Olaf' place=5
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    136,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-EPEE-2025-2026'),
    6,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
-- UNMATCHED (score<80): 'VÖLCSEI György Ferenc' place=7
-- UNMATCHED (score<80): 'SZALAY ID. Károly' place=8
-- UNMATCHED (score<80): 'CSIKÓS Attila' place=9
-- UNMATCHED (score<80): 'OHRABLO Branislav' place=10
-- UNMATCHED (score<80): 'DRAHUSAK Boris' place=11
-- UNMATCHED (score<80): 'CICHOSZ Matthias' place=12
-- UNMATCHED (score<80): 'RESCHKO Leonid' place=13
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    42,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-EPEE-2025-2026'),
    14,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    88,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-EPEE-2025-2026'),
    15,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
-- UNMATCHED (score<80): 'BOUTIN Thierry' place=16
-- UNMATCHED (score<80): 'MUNN Stephan' place=17
-- UNMATCHED (score<80): 'KOLB Tamás' place=18
-- UNMATCHED (score<80): 'KOICHI Yamada' place=19
-- UNMATCHED (score<80): 'TÖLGYESI Ákos Antal' place=20
-- UNMATCHED (score<80): 'SJÖDAHL Fredrik' place=21
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    35,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-EPEE-2025-2026'),
    22,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
-- UNMATCHED (score<80): 'PLEVNIK Janko' place=23
-- UNMATCHED (score<80): 'BOKUCHAVA Zurab' place=24
-- UNMATCHED (score<80): 'HALMOS András' place=25
-- UNMATCHED (score<80): 'LŐRINCZI Leó Ervin' place=26
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    249,
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
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V3-M-EPEE-2025-2026'),
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
-- UNMATCHED (score<80): 'ALIPPI 3 Stefano' place=1
-- UNMATCHED (score<80): 'BAKER 3 Jeremy' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    121,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2025-2026'),
    3,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
-- UNMATCHED (score<80): 'SJODAHL 3 Fredrik' place=4
-- UNMATCHED (score<80): 'PINK 3 Simon' place=5
-- UNMATCHED (score<80): 'BARDI 3 Robert' place=6
-- UNMATCHED (score<80): 'ROSS 3 Will' place=7
-- UNMATCHED (score<80): 'MARTIN 3 Steve' place=8
-- UNMATCHED (score<80): 'AKERBERG 3 Thomas' place=9
-- UNMATCHED (score<80): 'FRANK 3 Fred' place=10
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    136,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2025-2026'),
    11,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
-- UNMATCHED (score<80): 'MILLER 3 Will' place=12
-- UNMATCHED (score<80): 'TRIBUZIO 3 Riccardo' place=13
-- UNMATCHED (score<80): 'GOUGH 3 Robert' place=14
-- UNMATCHED (score<80): 'DICKINSON 3 Paul' place=15
-- UNMATCHED (score<80): 'ZIEGLER 3 Udo' place=16
-- UNMATCHED (score<80): 'BOUTIN 3 Thierry' place=17
-- UNMATCHED (score<80): 'VAN DEN BERG 3 Paul' place=18
-- UNMATCHED (score<80): 'FROELICH 3 Theo' place=19
-- UNMATCHED (score<80): 'THOMAS 3 Neale' place=20
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    348,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2025-2026'),
    21,
    'SOMERS 3 Jan'
); -- matched: SOMERS Jan (score=90.9090909090909)
-- UNMATCHED (score<80): 'RUSEV 3 Hristo' place=22
-- UNMATCHED (score<80): 'CSIKOS 3 Attila' place=23
-- UNMATCHED (score<80): 'LUCKMAN 3 Andrew' place=24
-- UNMATCHED (score<80): 'SPANO 3 Umberto' place=25
-- UNMATCHED (score<80): 'JORDAN 3 Philip' place=26
-- UNMATCHED (score<80): 'MUNN 3 Stephan' place=27
-- UNMATCHED (score<80): 'HYDE 3 John' place=28
-- UNMATCHED (score<80): 'KIDD 3 John' place=29
-- UNMATCHED (score<80): 'BULLOCK 3 Ian' place=30
-- UNMATCHED (score<80): 'LAKELAND 3 Nicholas' place=31
-- UNMATCHED (score<80): 'BRANDWOOD 3 Christopher' place=32
-- UNMATCHED (score<80): 'BALBONTIN 3 Roberto' place=33
-- UNMATCHED (score<80): 'BISSELL 3 Tim' place=34
-- UNMATCHED (score<80): 'CALLERI 3 Michele' place=35
-- UNMATCHED (score<80): 'MASSA 3 Maurizio' place=36
-- UNMATCHED (score<80): 'BROCK 3 Simon' place=37
-- UNMATCHED (score<80): 'EMMANOUIL 3 Dimitrios' place=38
-- UNMATCHED (score<80): 'FLEMING-FIDO 3 James' place=39
-- UNMATCHED (score<80): 'CHELL 3 Matthew' place=40
-- UNMATCHED (score<80): 'MONCRIEFF 3 Erik' place=41
-- UNMATCHED (score<80): 'ROBINSON 3 Michael' place=42
-- UNMATCHED (score<80): 'MIDDLETON 3 Nigel' place=43
-- UNMATCHED (score<80): 'CISLER 3 Pavel' place=44
-- UNMATCHED (score<80): 'SJODAHL 3 Fredrik' place=47
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
-- UNMATCHED (score<80): 'CARACCIOLO STEFANO ANTONIO' place=1
-- UNMATCHED (score<80): 'MAGNI LUCA' place=2
-- UNMATCHED (score<80): 'ALIPPI STEFANO CARLO C' place=3
-- UNMATCHED (score<80): 'MARKOV PHILIPPE' place=4
-- UNMATCHED (score<80): 'TULUMELLO GIOVANNI' place=5
-- UNMATCHED (score<80): 'SEGUIN MARC' place=6
-- UNMATCHED (score<80): 'ZICARI ALBERTO' place=7
-- UNMATCHED (score<80): 'KNECHT ROLF' place=8
-- UNMATCHED (score<80): 'GUY HUBERT' place=9
-- UNMATCHED (score<80): 'FERRO COSIMO ANTONIO' place=10
-- UNMATCHED (score<80): 'DRAHUSAK BORIS' place=11
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    136,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V3-M-EPEE-2025-2026'),
    12,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
-- UNMATCHED (score<80): 'COZZI GIOVANNI' place=13
-- UNMATCHED (score<80): 'VANNUCCI ANTONIO' place=14
-- UNMATCHED (score<80): 'BATTIGALLI PIERPAOLO LOREN' place=15
-- UNMATCHED (score<80): 'TESTOR SCHNELL TOMAS' place=16
-- UNMATCHED (score<80): 'SCHUELER THOMAS' place=17
-- UNMATCHED (score<80): 'OHRABLO BRANISLAV' place=18
-- UNMATCHED (score<80): 'FASCÌ ANTONIO MAURO' place=19
-- UNMATCHED (score<80): 'WAELLE PHILIPPE' place=20
-- UNMATCHED (score<80): 'KAZMER JOBST' place=21
-- UNMATCHED (score<80): 'VAN DEN BERG PAUL' place=22
-- UNMATCHED (score<80): 'CANNAS DINO' place=23
-- UNMATCHED (score<80): 'FROELICH THEO' place=24
-- UNMATCHED (score<80): 'SPANÒ UMBERTO' place=25
-- UNMATCHED (score<80): 'ALLIEVI GIANLUCA' place=26
-- UNMATCHED (score<80): 'BOUTIN THIERRY' place=27
-- UNMATCHED (score<80): 'BELLOMO FRANCESCO' place=28
-- UNMATCHED (score<80): 'BOSIO MARCO' place=29
-- UNMATCHED (score<80): 'PERUCHETTI FABIO' place=30
-- UNMATCHED (score<80): 'STRANO FEDERICO' place=31
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    348,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V3-M-EPEE-2025-2026'),
    32,
    'SOMERS JAN'
); -- matched: SOMERS Jan (score=100.0)
-- UNMATCHED (score<80): 'BELLI PAOLO' place=33
-- UNMATCHED (score<80): 'RUSSO EUGENIO ATTILIO' place=34
-- UNMATCHED (score<80): 'DOUSSE CHRISTIAN' place=35
-- UNMATCHED (score<80): 'SERANGELI CLAUDIO' place=36
-- UNMATCHED (score<80): 'LANA MASSIMO' place=37
-- UNMATCHED (score<80): 'EMMENEGGER JURGEN GERHARD' place=38
-- UNMATCHED (score<80): 'ARTHURS DAVID' place=39
-- UNMATCHED (score<80): 'PAIANO ROBERTO' place=40
-- UNMATCHED (score<80): 'SCHMITT JEAN NICOLAS' place=41
-- UNMATCHED (score<80): 'DI LORETO MARCO' place=42
-- UNMATCHED (score<80): 'MANGIAROTTI ALBERTO' place=43
-- UNMATCHED (score<80): 'BARIONOVI MAURO' place=44
-- UNMATCHED (score<80): 'VADASZ GABOR' place=45
-- UNMATCHED (score<80): 'FARCI FABIO' place=46
-- UNMATCHED (score<80): 'EMMANOUIL DIMITRIS' place=47
-- UNMATCHED (score<80): 'MARCUCCIO AUGUSTO' place=48
-- UNMATCHED (score<80): 'CALLERI MICHELE' place=49
-- UNMATCHED (score<80): 'BRAVI STEFANO' place=50
-- UNMATCHED (score<80): 'BERTOLLA ANTONELLO' place=51
-- UNMATCHED (score<80): 'KAPIANIDZE SOSO' place=52
-- UNMATCHED (score<80): 'BREDDO UGO' place=53
-- UNMATCHED (score<80): 'BRAMBILLA MARCO' place=54
-- UNMATCHED (score<80): 'LA SCALA PIER GALILEO' place=55
-- UNMATCHED (score<80): 'GUARDIA CARLO' place=56
-- UNMATCHED (score<80): 'THALMEINER ZOLTAN' place=57
-- UNMATCHED (score<80): 'CALLERI MARCO' place=58
-- UNMATCHED (score<80): 'CORDUA FRANCESCO' place=59
-- UNMATCHED (score<80): 'MANCA SEBASTIANO' place=60
-- UNMATCHED (score<80): 'MAGLIE VITO' place=61
-- UNMATCHED (score<80): 'SICA VINCENZO' place=62
-- UNMATCHED (score<80): 'ZAGO LINO' place=63
-- UNMATCHED (score<80): 'CAMPANILE ENRICO' place=64
-- UNMATCHED (score<80): 'SUBTIRICA DORU' place=65
-- UNMATCHED (score<80): 'RENINO CIRO' place=66
-- UNMATCHED (score<80): 'D''AGOSTINO ALESSANDRO' place=67
-- UNMATCHED (score<80): 'MONTEFORTE MAURO' place=68
-- UNMATCHED (score<80): 'CALITERNA PIERO' place=69
-- UNMATCHED (score<80): 'LANZILLO MASSIMO' place=70
-- UNMATCHED (score<80): 'LORINCZI LEO ERVIN' place=71
-- UNMATCHED (score<80): 'ROSSI ANDREA' place=72
-- UNMATCHED (score<80): 'VITALE GENNARO' place=73
-- UNMATCHED (score<80): 'CASAZZA PAOLO' place=74
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
-- UNMATCHED (score<80): 'FALCK-YTTER Jan' place=1
-- UNMATCHED (score<80): 'BARDI Robert' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    121,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2025-2026'),
    3,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
-- UNMATCHED (score<80): 'BAKER Jeremy' place=4
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    42,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2025-2026'),
    5,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
-- UNMATCHED (score<80): 'FRED Arnold' place=6
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    136,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2025-2026'),
    7,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
-- UNMATCHED (score<80): 'MELNIKOV Sergei' place=8
-- UNMATCHED (score<80): 'PINK Simon' place=9
-- UNMATCHED (score<80): 'WATTENBERG 3 Dirk' place=10
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    249,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2025-2026'),
    11,
    'WHITLEY Gary'
); -- matched: WHITLEY Gary (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    88,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2025-2026'),
    12,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2025-2026'),
    13,
    'MAŁASIŃSKI Adam'
); -- matched: MAŁASIŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    236,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2025-2026'),
    14,
    'TRACZ Jerzy'
); -- matched: TRACZ Jerzy (score=100.0)
-- UNMATCHED (score<80): 'BENNETT Craig' place=15
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    31,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2025-2026'),
    16,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
-- UNMATCHED (score<80): 'KAISER Wolfgang' place=17
-- UNMATCHED (score<80): 'KARATHANASIS Athanasios' place=18
-- Compute scores for PEW6-V3-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2025-2026')
);

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): 0 matched fencers in DB — tournament not created

-- SKIP PS (Puchar Świata): N=0 — tournament had no participants

-- SKIP IMEW: event not yet held (SCHEDULED) — results are rolling carry-over from previous season

-- Summary
-- Total results matched:   66
-- Total results unmatched: 214
