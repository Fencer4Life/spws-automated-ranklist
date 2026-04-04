-- =========================================================================
-- Season 2024-2025 — V3 M EPEE — generated from SZPADA-3-2024-2025.xlsx
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
    'PPW1-V3-M-EPEE-2024-2025',
    'I Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V3',
    '2024-09-28', 10, 'https://www.fencingtimelive.com/events/results/516F915B21C14B96A2C5CD7F896BBDFD',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2024-2025'),
    1,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2024-2025'),
    2,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2024-2025'),
    3,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2024-2025'),
    4,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2024-2025'),
    5,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    211,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2024-2025'),
    6,
    'POKRZYWA Mariusz'
); -- matched: POKRZYWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    10,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2024-2025'),
    7,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    315,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2024-2025'),
    8,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    291,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2024-2025'),
    9,
    'WHITLEY Gary'
); -- matched: WHITLEY Gary (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    38,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2024-2025'),
    10,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
-- Compute scores for PPW1-V3-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2024-2025')
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
    'PPW2-V3-M-EPEE-2024-2025',
    'II Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V3',
    '2024-10-26', 9, 'https://www.fencingtimelive.com/events/results/FBECB845CF32422FA731D14C8EC361D9',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-EPEE-2024-2025'),
    1,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-EPEE-2024-2025'),
    2,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-EPEE-2024-2025'),
    3,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-EPEE-2024-2025'),
    4,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-EPEE-2024-2025'),
    5,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    213,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-EPEE-2024-2025'),
    6,
    'POPRAWA Mariusz'
); -- matched: POPRAWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    10,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-EPEE-2024-2025'),
    7,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    211,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-EPEE-2024-2025'),
    8,
    'POKRZYWA Mariusz'
); -- matched: POKRZYWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    291,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-EPEE-2024-2025'),
    9,
    'WHITLEY Gary'
); -- matched: WHITLEY Gary (score=100.0)
-- Compute scores for PPW2-V3-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-EPEE-2024-2025')
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
    'PPW3-V3-M-EPEE-2024-2025',
    'III Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V3',
    '2024-11-30', 11, 'https://www.fencingtimelive.com/events/results/E46F5BE84AC64AF490233C314BFB1968',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2024-2025'),
    1,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2024-2025'),
    2,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    10,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2024-2025'),
    3,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    211,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2024-2025'),
    4,
    'POKRZYWA MARIUSZ'
); -- matched: POKRZYWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2024-2025'),
    5,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    213,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2024-2025'),
    6,
    'POPRAWA Mariusz'
); -- matched: POPRAWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    38,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2024-2025'),
    7,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    169,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2024-2025'),
    8,
    'MAŁASIŃSKI Adam'
); -- matched: MAŁASIŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2024-2025'),
    9,
    'NIKALAICHUK Aliaksandr'
); -- matched: NIKALAICHUK Aliaksandr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    302,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2024-2025'),
    10,
    'WRONA Grzegorz'
); -- matched: WRONA Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    219,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2024-2025'),
    11,
    'PYZIK Zdzisław'
); -- matched: PYZIK Zdzisław (score=100.0)
-- Compute scores for PPW3-V3-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2024-2025')
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
    'PPW4-V3-M-EPEE-2024-2025',
    'IV Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V3',
    '2025-02-22', 9, 'https://www.fencingtimelive.com/events/results/B86AF930EA434E59B7B86ED06B43B17E',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2024-2025'),
    1,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    10,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2024-2025'),
    2,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2024-2025'),
    3,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2024-2025'),
    4,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    262,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2024-2025'),
    5,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    169,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2024-2025'),
    6,
    'MAŁASIŃSKI Adam'
); -- matched: MAŁASIŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    213,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2024-2025'),
    7,
    'POPRAWA Mariusz'
); -- matched: POPRAWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    38,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2024-2025'),
    8,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    291,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2024-2025'),
    9,
    'WHITLEY Gary'
); -- matched: WHITLEY Gary (score=100.0)
-- Compute scores for PPW4-V3-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2024-2025')
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
    'PPW5-V3-M-EPEE-2024-2025',
    'V Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V3',
    '2025-04-26', 6, 'https://www.fencingtimelive.com/events/results/958D6D51663A4F7E9464BCBC3167FF47',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    10,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V3-M-EPEE-2024-2025'),
    1,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V3-M-EPEE-2024-2025'),
    2,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    271,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V3-M-EPEE-2024-2025'),
    3,
    'SZYMKOWIAK Krzysztof'
); -- matched: SZYMKOWIAK Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V3-M-EPEE-2024-2025'),
    4,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    291,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V3-M-EPEE-2024-2025'),
    5,
    'WHITLEY Gary'
); -- matched: WHITLEY Gary (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    257,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V3-M-EPEE-2024-2025'),
    6,
    'STOŁOWSKI Mariusz'
); -- matched: STOŁOWSKI Mariusz (score=100.0)
-- Compute scores for PPW5-V3-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V3-M-EPEE-2024-2025')
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
    'MPW-V3-M-EPEE-2024-2025',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'EPEE', 'M', 'V3',
    '2025-06-07', 12, 'https://www.fencingtimelive.com/events/results/D8DD0A640C80402DAE9ED5AD416A5AA1',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2024-2025'),
    1,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    271,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2024-2025'),
    2,
    'SZYMKOWIAK Krzysztof'
); -- matched: SZYMKOWIAK Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    10,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2024-2025'),
    3,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2024-2025'),
    4,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2024-2025'),
    5,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    262,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2024-2025'),
    6,
    'SZCZĘSNY Jacek'
); -- matched: SZCZĘSNY Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    169,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2024-2025'),
    7,
    'MAŁASIŃSKI Adam'
); -- matched: MAŁASIŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2024-2025'),
    8,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    213,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2024-2025'),
    9,
    'POPRAWA Mariusz'
); -- matched: POPRAWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    211,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2024-2025'),
    10,
    'POKRZYWA Mariusz'
); -- matched: POKRZYWA Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    38,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2024-2025'),
    11,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    219,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2024-2025'),
    12,
    'PYZIK Zdzisław'
); -- matched: PYZIK Zdzisław (score=100.0)
-- Compute scores for MPW-V3-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V3-M-EPEE-2024-2025')
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
    'PEW1-V3-M-EPEE-2024-2025',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'EPEE', 'M', 'V3',
    '2024-09-21', 41, 'https://engarde-service.com/app.php?id=4207L3',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-EPEE-2024-2025'),
    1,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-EPEE-2024-2025'),
    5,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-EPEE-2024-2025'),
    13,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    315,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-EPEE-2024-2025'),
    39,
    'ĆWIORO Krzysztof'
); -- matched: ĆWIORO Krzysztof (score=100.0)
-- Compute scores for PEW1-V3-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-EPEE-2024-2025')
);

-- ---- PEW2: EVF Grand Prix 2 — Madryt (Madrid) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW2-2024-2025',
    'EVF Grand Prix 2 — Madryt',
    'Madrid',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW2-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW2-2024-2025'),
    'PEW2-V3-M-EPEE-2024-2025',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'EPEE', 'M', 'V3',
    '2024-11-16', 32, 'https://engarde-service.com/competition/aeve_esgrima/evf_madrid_2024/t-em-3',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V3-M-EPEE-2024-2025'),
    2,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V3-M-EPEE-2024-2025'),
    3,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V3-M-EPEE-2024-2025'),
    10,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
-- SKIPPED (international, no master data): 'KARATHANASIS  Athanasios' place=32
-- Compute scores for PEW2-V3-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V3-M-EPEE-2024-2025')
);

-- ---- PEW3: EVF Grand Prix 3 (Guildford) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW3-2024-2025',
    'EVF Grand Prix 3',
    'Guildford',
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
    'PEW3-V3-M-EPEE-2024-2025',
    'EVF Grand Prix 3',
    'PEW',
    'EPEE', 'M', 'V3',
    '2025-01-04', 55, 'https://www.fencingtimelive.com/tableaus/scores/74CD098F00D64ECBBA17CDC1AA600F1A/1750472FFBF344C3AE0709BE48C67476',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2024-2025'),
    5,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
-- Compute scores for PEW3-V3-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2024-2025')
);

-- ---- PEW4: EVF Grand Prix 4 (Terni) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW4-2024-2025',
    'EVF Grand Prix 4',
    'Terni',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW4-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW4-2024-2025'),
    'PEW4-V3-M-EPEE-2024-2025',
    'EVF Grand Prix 4',
    'PEW',
    'EPEE', 'M', 'V3',
    '2025-02-01', 71, 'https://www.4fence.it/FIS/Risultati/2025-02-02-01_Terni_(TR)_-_4_Prova_Naz.le_Master_-_EVF_Circuit/index.php?a=SP&s=M&c=8&f=clafinale',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V3-M-EPEE-2024-2025'),
    6,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
-- Compute scores for PEW4-V3-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V3-M-EPEE-2024-2025')
);

-- ---- PEW5: EVF Grand Prix 5 (Stockholm (SWE)) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW5-2024-2025',
    'EVF Grand Prix 5',
    'Stockholm (SWE)',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW5-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW5-2024-2025'),
    'PEW5-V3-M-EPEE-2024-2025',
    'EVF Grand Prix 5',
    'PEW',
    'EPEE', 'M', 'V3',
    '2025-03-15', 36, 'https://fencing.ophardt.online/en/search/results/30279',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V3-M-EPEE-2024-2025'),
    3,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
-- Compute scores for PEW5-V3-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V3-M-EPEE-2024-2025')
);

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
    'PEW6-V3-M-EPEE-2024-2025',
    'EVF Grand Prix 6',
    'PEW',
    'EPEE', 'M', 'V3',
    '2025-03-29', 27, 'https://www.fencingtimelive.com/events/results/2B95F7EF0EEE41EA8CD7D483B9EAB62C',
    'SCORED'
);
-- SKIPPED (international, no master data): 'HINZ Gerald' place=1
-- SKIPPED (international, no master data): 'BÁRDI Robert' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2024-2025'),
    3,
    'KRZEMINSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=94.44444444444444)
-- SKIPPED (international, no master data): 'FALCK-YTTER Jan' place=3
-- SKIPPED (international, no master data): 'VAN DEN BERG Paul' place=5
-- SKIPPED (international, no master data): 'SJÖDAHL Fredrik' place=6
-- SKIPPED (international, no master data): 'BAKER Jeremy' place=7
-- SKIPPED (international, no master data): 'KOVÁCS László Csaba' place=8
-- SKIPPED (international, no master data): 'PINK Simon' place=9
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2024-2025'),
    10,
    'HERONIMEK Leszek'
); -- matched: HERONIMEK Leszek (score=100.0)
-- SKIPPED (international, no master data): 'DESCHAMPS Michel' place=11
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    10,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2024-2025'),
    12,
    'AUGUSTOWSKI Waldemar'
); -- matched: AUGUSTOWSKI Waldemar (score=100.0)
-- SKIPPED (international, no master data): 'LIPTON Michael' place=13
-- SKIPPED (international, no master data): 'WATTENBERG Dirk' place=14
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2024-2025'),
    15,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
-- SKIPPED (international, no master data): 'DE LEPORINI Livio' place=16
-- SKIPPED (international, no master data): 'MANGIAROTTI Alberto' place=17
-- SKIPPED (international, no master data): 'MELNIKOV Sergei' place=18
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    221,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2024-2025'),
    19,
    'QUEVRAIN Michel'
); -- matched: QUEVRAIN Michel (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    291,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2024-2025'),
    20,
    'WHITLEY Gary'
); -- matched: WHITLEY Gary (score=100.0)
-- SKIPPED (international, no master data): 'VOLK Rainer' place=21
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    38,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2024-2025'),
    22,
    'CHUDYCKI Artur'
); -- matched: CHUDYCKI Artur (score=100.0)
-- SKIPPED (international, no master data): 'SUBTIRICA Doru' place=23
-- SKIPPED (international, no master data): 'BECKER Detlef' place=24
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    169,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2024-2025'),
    25,
    'MAŁASIŃSKI Adam'
); -- matched: MAŁASIŃSKI Adam (score=100.0)
-- SKIPPED (international, no master data): 'KARATHANASIS  Athanasios' place=26
-- SKIPPED (international, no master data): 'KAISER Wolfgang' place=27
-- Compute scores for PEW6-V3-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2024-2025')
);

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): 0 matched fencers in DB — tournament not created

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
    'IMEW-V3-M-EPEE-2024-2025',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'EPEE', 'M', 'V3',
    '2025-05-29', 76, 'https://www.fencingtimelive.com/events/results/C69C69911739436BA0CF9AAB269623D0',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-EPEE-2024-2025'),
    16,
    'KRZEMIŃSKI Mariusz'
); -- matched: KRZEMIŃSKI Mariusz (score=100.0)
-- Compute scores for IMEW-V3-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V3-M-EPEE-2024-2025')
);

-- Summary
-- Total results matched:   76
-- Total results unmatched: 21
-- Total auto-created:      0
