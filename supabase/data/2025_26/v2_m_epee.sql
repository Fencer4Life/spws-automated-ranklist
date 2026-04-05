-- =========================================================================
-- Season 2025-2026 — V2 M EPEE — generated from SZPADA-2-2025-2026.xlsx
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
    'PPW1-V2-M-EPEE-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V2',
    '2025-09-28', 8, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    311,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2025-2026'),
    1,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2025-2026'),
    2,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    104,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2025-2026'),
    3,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2025-2026'),
    4,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    49,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2025-2026'),
    5,
    'DROBIŃSKI Leszek'
); -- matched: DROBIŃSKI Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2025-2026'),
    6,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2025-2026'),
    7,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    94,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2025-2026'),
    8,
    'HEŁKA Jacek'
); -- matched: HEŁKA Jacek (score=100.0)
-- Compute scores for PPW1-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2025-2026')
);

-- ---- PP2: II Puchar Polski Weteranów (SZPADA MĘŻCZYZN 2 WETERANI) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW2-2025-2026',
    'II Puchar Polski Weteranów',
    'SZPADA MĘŻCZYZN 2 WETERANI',
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
    'PPW2-V2-M-EPEE-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V2',
    NULL, 8, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2025-2026'),
    1,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    49,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2025-2026'),
    2,
    'DROBIŃSKI Leszek'
); -- matched: DROBIŃSKI Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    318,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2025-2026'),
    3,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    251,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2025-2026'),
    4,
    'STANIEWICZ Witold'
); -- matched: STANIEWICZ Witold (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2025-2026'),
    5,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2025-2026'),
    6,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    94,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2025-2026'),
    7,
    'HEŁKA Jacek'
); -- matched: HEŁKA Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    278,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2025-2026'),
    8,
    'TOMCZAK Ireneusz'
); -- matched: TOMCZAK Ireneusz (score=100.0)
-- Compute scores for PPW2-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2025-2026')
);

-- ---- PP3: III Puchar Polski Weteranów (Szpada Mężczyzn kat. 2) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW3-2025-2026',
    'III Puchar Polski Weteranów',
    'Szpada Mężczyzn kat. 2',
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
    'PPW3-V2-M-EPEE-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V2',
    NULL, 19, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    104,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    2,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    3,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    155,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    4,
    'LEAHEY John'
); -- matched: LEAHEY John (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    311,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    5,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    103,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    6,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    195,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    7,
    'OLSZEWSKI Mikołaj'
); -- matched: OLSZEWSKI Mikołaj (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    207,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    8,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    49,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    9,
    'DROBIŃSKI Leszek'
); -- matched: DROBIŃSKI Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    318,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    10,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    67,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    11,
    'GERTSMAN Alex'
); -- matched: GERTSMAN Alex (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    12,
    'SKOCZEK Artur'
); -- matched: SKOCZEK Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    193,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    13,
    'ODOLAK Jarosław'
); -- matched: ODOLAK Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    278,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    14,
    'TOMCZAK Ireneusz'
); -- matched: TOMCZAK Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    241,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    15,
    'SERWATKA Marek'
); -- matched: SERWATKA Marek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    16,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    17,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    172,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    18,
    'MCQUEEN Andy'
); -- matched: MCQUEEN Andy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    71,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    19,
    'GOLD Oleg'
); -- matched: GOLD Oleg (score=100.0)
-- Compute scores for PPW3-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026')
);

-- ---- PP4: IV Puchar Polski Weteranów (SZPADA MĘŻCZYZN v2) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW4-2025-2026',
    'IV Puchar Polski Weteranów',
    'SZPADA MĘŻCZYZN v2',
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
    'PPW4-V2-M-EPEE-2025-2026',
    'IV Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V2',
    NULL, 11, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2025-2026'),
    1,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2025-2026'),
    2,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    104,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2025-2026'),
    3,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    50,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2025-2026'),
    4,
    'DUDEK Mariusz'
); -- matched: DUDEK Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    290,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2025-2026'),
    5,
    'WASIOŁKA Sebastian'
); -- matched: WASIOŁKA Sebastian (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    49,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2025-2026'),
    6,
    'DROBIŃSKI Leszek'
); -- matched: DROBIŃSKI Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2025-2026'),
    7,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2025-2026'),
    8,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    278,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2025-2026'),
    9,
    'TOMCZAK Ireneusz'
); -- matched: TOMCZAK Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    207,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2025-2026'),
    10,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    94,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2025-2026'),
    11,
    'HEŁKA Jacek'
); -- matched: HEŁKA Jacek (score=100.0)
-- Compute scores for PPW4-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2025-2026')
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
    'PEW1-V2-M-EPEE-2025-2026',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'EPEE', 'M', 'V2',
    NULL, 57, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-EPEE-2025-2026'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
-- SKIPPED (international, no master data): 'GOETZ Gregory' place=2
-- SKIPPED (international, no master data): 'ASHRAFI Ehsan' place=3
-- SKIPPED (international, no master data): 'PÖNISCH Thomas' place=4
-- SKIPPED (international, no master data): 'LYONS Michael James' place=5
-- SKIPPED (international, no master data): 'HIRNER Wolfgang' place=6
-- SKIPPED (international, no master data): 'SCHATTENFROH Sebastian Dr.' place=7
-- SKIPPED (international, no master data): 'STRAKA Tomas' place=8
-- SKIPPED (international, no master data): 'BERGER Matthias' place=9
-- SKIPPED (international, no master data): 'DEGAUQUE Gilles' place=10
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    246,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-EPEE-2025-2026'),
    11,
    'SOKOL Vratislav'
); -- matched: SOKOL Vratislav (score=100.0)
-- SKIPPED (international, no master data): 'HAYEK Günter' place=12
-- SKIPPED (international, no master data): 'PILHÁL Zsolt' place=13
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-EPEE-2025-2026'),
    14,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
-- SKIPPED (international, no master data): 'GOETTMANN Jean-Julien' place=15
-- SKIPPED (international, no master data): 'KÁMÁNY Roland' place=16
-- SKIPPED (international, no master data): 'KÁLLAI Ákos' place=17
-- SKIPPED (international, no master data): 'GACSAL Károly' place=18
-- SKIPPED (international, no master data): 'FEZARD Julien' place=19
-- SKIPPED (international, no master data): 'KOEMETS Sven' place=20
-- SKIPPED (international, no master data): 'CICOIRA Mario' place=21
-- SKIPPED (international, no master data): 'KOUTSOUFLAKIS Stamatios' place=22
-- SKIPPED (international, no master data): 'RODARY Emmanuel' place=23
-- SKIPPED (international, no master data): 'KENESEI János' place=24
-- SKIPPED (international, no master data): 'LEE Ambrose' place=25
-- SKIPPED (international, no master data): 'GYÖRGY Attila' place=26
-- SKIPPED (international, no master data): 'ROTA Carlo' place=27
-- SKIPPED (international, no master data): 'SZAKMÁRY Sándor' place=28
-- SKIPPED (international, no master data): 'LESNE Ludovic' place=29
-- SKIPPED (international, no master data): 'DR VITÉZY Péter László' place=30
-- SKIPPED (international, no master data): 'AUTZEN Olaf' place=31
-- SKIPPED (international, no master data): 'BERMAN Robert' place=32
-- SKIPPED (international, no master data): 'MÁTYÁS Pál' place=33
-- SKIPPED (international, no master data): 'FERKE Norbert' place=34
-- SKIPPED (international, no master data): 'TULUMELLO Carmelo' place=35
-- SKIPPED (international, no master data): 'PULEGA Roberto' place=36
-- SKIPPED (international, no master data): 'DEÁK István' place=37
-- SKIPPED (international, no master data): 'MAGHON Hans' place=38
-- SKIPPED (international, no master data): 'VICHI Tommaso' place=39
-- SKIPPED (international, no master data): 'ÓCSAI János' place=40
-- SKIPPED (international, no master data): 'ACIKEL Ugur' place=41
-- SKIPPED (international, no master data): 'FÁBIÁN Gábor' place=42
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-EPEE-2025-2026'),
    43,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
-- SKIPPED (international, no master data): 'ERTÜN Müjdat' place=44
-- SKIPPED (international, no master data): 'BALLA Ádám' place=45
-- SKIPPED (international, no master data): 'MESTER György' place=46
-- SKIPPED (international, no master data): 'STUDENY Frantisek' place=47
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    67,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-EPEE-2025-2026'),
    48,
    'GERTSMAN Alexandr'
); -- matched: GERTSMAN Alex (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    71,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-EPEE-2025-2026'),
    49,
    'GOLD Oleg'
); -- matched: GOLD Oleg (score=100.0)
-- SKIPPED (international, no master data): 'MÜLLER Ferenc' place=50
-- SKIPPED (international, no master data): 'SZABÓ Péter' place=51
-- SKIPPED (international, no master data): 'RUSIN Serghei' place=52
-- SKIPPED (international, no master data): 'MAGLIOZZI Roberto' place=53
-- SKIPPED (international, no master data): 'NYÉKI Zsolt' place=54
-- SKIPPED (international, no master data): 'CSISZÁR Zoltán' place=55
-- SKIPPED (international, no master data): 'SÓS Csaba' place=56
-- SKIPPED (international, no master data): 'VARGA Gergely' place=57
-- Compute scores for PEW1-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-EPEE-2025-2026')
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
    'PEW2-V2-M-EPEE-2025-2026',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'EPEE', 'M', 'V2',
    NULL, 33, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-EPEE-2025-2026'),
    1,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
-- SKIPPED (international, no master data): 'ASHRAFI' place=2
-- SKIPPED (international, no master data): 'LAUGA' place=3
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    155,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-EPEE-2025-2026'),
    4,
    'LEAHEY'
); -- matched: LEAHEY John (score=70.58823529411764)
-- SKIPPED (international, no master data): 'BERGER' place=5
-- SKIPPED (international, no master data): 'GARCIA CALDERON' place=6
-- SKIPPED (international, no master data): 'AUTZEN' place=7
-- SKIPPED (international, no master data): 'DE BURGH' place=8
-- SKIPPED (international, no master data): 'GOETTMANN' place=9
-- SKIPPED (international, no master data): 'PULEGA' place=10
-- SKIPPED (international, no master data): 'MOYA FERNÁNDEZ' place=11
-- SKIPPED (international, no master data): 'ALCÁZAR ROLDÁN' place=12
-- SKIPPED (international, no master data): 'DE BERNARDI' place=13
-- SKIPPED (international, no master data): 'SWENNING' place=14
-- SKIPPED (international, no master data): 'ZONNO' place=15
-- SKIPPED (international, no master data): 'NYÉKI' place=16
-- SKIPPED (international, no master data): 'JANET' place=17
-- SKIPPED (international, no master data): 'GARCIA FERNANDEZ' place=18
-- SKIPPED (international, no master data): 'ERTÜN' place=19
-- SKIPPED (international, no master data): 'AÇIKEL' place=20
-- SKIPPED (international, no master data): 'GÓMEZ PAZ' place=21
-- SKIPPED (international, no master data): 'POMELL' place=22
-- SKIPPED (international, no master data): 'FERNANDEZ RAMOS' place=23
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-EPEE-2025-2026'),
    24,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
-- SKIPPED (international, no master data): 'VARGA' place=25
-- SKIPPED (international, no master data): 'KAMANY' place=26
-- SKIPPED (international, no master data): 'DOMINGUEZ' place=27
-- SKIPPED (international, no master data): 'BERNEIS' place=28
-- SKIPPED (international, no master data): 'GONZÁLEZ DÍAZ' place=29
-- SKIPPED (international, no master data): 'RODRÍGUEZ' place=30
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    172,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-EPEE-2025-2026'),
    31,
    'MCQUEEN'
); -- matched: MCQUEEN Andy (score=73.6842105263158)
-- SKIPPED (international, no master data): 'GALÁN ROCILLO' place=32
-- SKIPPED (international, no master data): 'SALCEDO PLAZA' place=33
-- Compute scores for PEW2-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-EPEE-2025-2026')
);

-- ---- PEW3: EVF Grand Prix 3 (Men's Epee Category 2) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW3-2025-2026',
    'EVF Grand Prix 3',
    'Men''s Epee Category 2',
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
    'PEW3-V2-M-EPEE-2025-2026',
    'EVF Grand Prix 3',
    'PEW',
    'EPEE', 'M', 'V2',
    NULL, 42, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'GOETZ 2 Gregory' place=1
-- SKIPPED (international, no master data): 'POENISCH 2 Thomas' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2025-2026'),
    3,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
-- SKIPPED (international, no master data): 'EGGERMONT 2 Markus' place=4
-- SKIPPED (international, no master data): 'ELLISON 2 Alexander' place=5
-- SKIPPED (international, no master data): 'DONNELLY 2 Paul' place=6
-- SKIPPED (international, no master data): 'SCHATTENFROH 2 Sebastian' place=7
-- SKIPPED (international, no master data): 'CHRISP 2 Tom' place=8
-- SKIPPED (international, no master data): 'RIAHI 2 Farhad' place=9
-- SKIPPED (international, no master data): 'LAUGA 2 Eric' place=10
-- SKIPPED (international, no master data): 'ROTA 2 Carlo' place=11
-- SKIPPED (international, no master data): 'BUZWELL 2 Timothy' place=12
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    155,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2025-2026'),
    13,
    'LEAHEY 2 John'
); -- matched: LEAHEY John (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2025-2026'),
    14,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
-- SKIPPED (international, no master data): 'BULLEN 2 Edward' place=15
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    103,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2025-2026'),
    16,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100.0)
-- SKIPPED (international, no master data): 'ADRIAN VIRGIL 2 Stanciu' place=17
-- SKIPPED (international, no master data): 'DEGAUQUE 2 Gilles' place=18
-- SKIPPED (international, no master data): 'RODARY 2 Emmanuel' place=19
-- SKIPPED (international, no master data): 'BARNETSON 2 John' place=20
-- SKIPPED (international, no master data): 'MACDONALD 2 Leslie' place=21
-- SKIPPED (international, no master data): 'JANET 2 Jean-Luc' place=22
-- SKIPPED (international, no master data): 'DISHMAN 2 Ben' place=23
-- SKIPPED (international, no master data): 'VITEZY 2 Peter Laszlo' place=24
-- SKIPPED (international, no master data): 'SLINGSBY 2 Wyc' place=25
-- SKIPPED (international, no master data): 'BERNEIS 2 Christian' place=26
-- SKIPPED (international, no master data): 'STEINER 2 Roberto' place=27
-- SKIPPED (international, no master data): 'LOCKYER 2 James' place=28
-- SKIPPED (international, no master data): 'PRIME 2 John' place=29
-- SKIPPED (international, no master data): 'HO 2 Chuen Tak Douglas' place=30
-- SKIPPED (international, no master data): 'HOGARTH-SCOTT 2 Jolyon' place=31
-- SKIPPED (international, no master data): 'BOARDMAN 2 Colin' place=32
-- SKIPPED (international, no master data): 'PULEGA 2 Roberto' place=33
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2025-2026'),
    34,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    172,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2025-2026'),
    35,
    'MCQUEEN 2 Andrew'
); -- matched: MCQUEEN Andy (score=93.75)
-- SKIPPED (international, no master data): 'WILLMOTT 2 Paul' place=36
-- SKIPPED (international, no master data): 'DEBURGH 2 Etienne' place=37
-- SKIPPED (international, no master data): 'KENNY 2 Nick' place=38
-- SKIPPED (international, no master data): 'VICTORY 2 David' place=39
-- SKIPPED (international, no master data): 'BARDELOT 2 Loic' place=40
-- SKIPPED (international, no master data): 'CRYER 2 Nicholas' place=41
-- SKIPPED (international, no master data): 'RODGERS 2 Lindsay' place=42
-- Compute scores for PEW3-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2025-2026')
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
    'PEW4-V2-M-EPEE-2025-2026',
    'EVF Grand Prix 4',
    'PEW',
    'EPEE', 'M', 'V2',
    NULL, 79, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'LESNE LUDOVIC' place=1
-- SKIPPED (international, no master data): 'PIRANI CLAUDIO' place=2
-- SKIPPED (international, no master data): 'GOETZ GREGORY' place=3
-- SKIPPED (international, no master data): 'VINCENZI GABRIELE' place=4
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-EPEE-2025-2026'),
    5,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
-- SKIPPED (international, no master data): 'GRAVES SMITH GEOFFREY' place=6
-- SKIPPED (international, no master data): 'LARATO FABRIZIO NICOLA' place=7
-- SKIPPED (international, no master data): 'DEGAUQUE GILLES' place=8
-- SKIPPED (international, no master data): 'PALTINISEANU SORIN' place=9
-- SKIPPED (international, no master data): 'TOZZI FRANCESCO' place=10
-- SKIPPED (international, no master data): 'DI GIORGIO DOMENICO' place=11
-- SKIPPED (international, no master data): 'ASHRAFI EHSAN' place=12
-- SKIPPED (international, no master data): 'KAMANY ROLAND' place=13
-- SKIPPED (international, no master data): 'PIETROPINTO VITTORIO' place=14
-- SKIPPED (international, no master data): 'PUCCINELLI CRISTIANO' place=15
-- SKIPPED (international, no master data): 'DE BERNARDI GIOVANNI ANTONI' place=16
-- SKIPPED (international, no master data): 'LEE AMBROSE' place=17
-- SKIPPED (international, no master data): 'MAZALAIGUE STEPHANE' place=18
-- SKIPPED (international, no master data): 'MAY JOZSEF' place=19
-- SKIPPED (international, no master data): 'FASOLI ARRIGO' place=20
-- SKIPPED (international, no master data): 'PINOTTI ANDREA' place=21
-- SKIPPED (international, no master data): 'VICHI TOMMASO' place=22
-- SKIPPED (international, no master data): 'UHLIG ANDREAS' place=23
-- SKIPPED (international, no master data): 'CICOIRA MARIO' place=24
-- SKIPPED (international, no master data): 'VOLPI JHONATHAN' place=25
-- SKIPPED (international, no master data): 'LEAL CARLOS MARTIN' place=26
-- SKIPPED (international, no master data): 'RIAHI FARHAD' place=27
-- SKIPPED (international, no master data): 'MASSIMINO CRISTIAN' place=28
-- SKIPPED (international, no master data): 'BERNEIS CHRISTIAN' place=29
-- SKIPPED (international, no master data): 'OSSOWSKI RADOSLAW' place=30
-- SKIPPED (international, no master data): 'PILHAL ZSOLT' place=31
-- SKIPPED (international, no master data): 'GOETTMANN JEAN-JULIEN' place=32
-- SKIPPED (international, no master data): 'SALAMANDRA PAOLO' place=33
-- SKIPPED (international, no master data): 'BRUSINI EMANUELE' place=34
-- SKIPPED (international, no master data): 'AYALA RODRIGO' place=35
-- SKIPPED (international, no master data): 'CAMILLERI MATTHIEU' place=36
-- SKIPPED (international, no master data): 'PEDERZOLLI NICOLA' place=37
-- SKIPPED (international, no master data): 'RODARY EMMANUEL' place=38
-- SKIPPED (international, no master data): 'CHIARAMONTE ANDREA' place=39
-- SKIPPED (international, no master data): 'MAGLIOZZI ROBERTO' place=40
-- SKIPPED (international, no master data): 'MULLER FERENC' place=41
-- SKIPPED (international, no master data): 'ALTOBELLO ANTONELLO' place=42
-- SKIPPED (international, no master data): 'BENZI ROBERTO' place=43
-- SKIPPED (international, no master data): 'BONAGURA SALVATORE' place=44
-- SKIPPED (international, no master data): 'PULEGA ROBERTO ANDREA' place=45
-- SKIPPED (international, no master data): 'BOVIS MARIO RICCARDO' place=46
-- SKIPPED (international, no master data): 'MOCCI VINICIO' place=47
-- SKIPPED (international, no master data): 'BARDELOT LOIC' place=48
-- SKIPPED (international, no master data): 'TULUMELLO CARMELO' place=49
-- SKIPPED (international, no master data): 'NANI MAURIZIO' place=50
-- SKIPPED (international, no master data): 'BROCVILLE PIERRE' place=51
-- SKIPPED (international, no master data): 'PADRICHELLI LORENZO' place=52
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    160,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-EPEE-2025-2026'),
    53,
    'LIPPOLIS ROBERTO'
); -- matched: LISOWSKI Robert (score=70.96774193548387)
-- SKIPPED (international, no master data): 'DE BURGH ETIENNE' place=54
-- SKIPPED (international, no master data): 'GERLI PAOLO' place=55
-- SKIPPED (international, no master data): 'DI BERNARDO GIUSEPPE' place=56
-- SKIPPED (international, no master data): 'ZONNO MICHELE' place=57
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-EPEE-2025-2026'),
    58,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
-- SKIPPED (international, no master data): 'CELLI EMILIANO MARIO' place=59
-- SKIPPED (international, no master data): 'MESTER GYORGY' place=60
-- SKIPPED (international, no master data): 'BENETTI LUCA' place=61
-- SKIPPED (international, no master data): 'ANASTASIA LUIGI' place=62
-- SKIPPED (international, no master data): 'PAPI GIANLUCA' place=63
-- SKIPPED (international, no master data): 'PURPORA GIUSEPPE' place=64
-- SKIPPED (international, no master data): 'CSISZAR ZOLTAN' place=65
-- SKIPPED (international, no master data): 'MANISCALCO ROSARIO SERGIO' place=66
-- SKIPPED (international, no master data): 'LI CASTRI PIETRO' place=67
-- SKIPPED (international, no master data): 'MUSSI SERGIO' place=68
-- SKIPPED (international, no master data): 'DRAGO GUGLIELMO GIULI' place=69
-- SKIPPED (international, no master data): 'MICELI FABRIZIO' place=70
-- SKIPPED (international, no master data): 'MORRA GIUSEPPE' place=71
-- SKIPPED (international, no master data): 'BORELLI LUIGI FEDERICO' place=72
-- SKIPPED (international, no master data): 'ROSATO DAMIANO' place=73
-- SKIPPED (international, no master data): 'GAMBA VALTER' place=74
-- SKIPPED (international, no master data): 'GERMANO RAVINA CARLO' place=75
-- SKIPPED (international, no master data): 'DI GIORGIO COSIMO DANILO' place=76
-- SKIPPED (international, no master data): 'PERRONE PIERPAOLO' place=77
-- SKIPPED (international, no master data): 'LA ROSA RODOLFO GHERARD' place=78
-- SKIPPED (international, no master data): 'MAZZONI MARCO ETTORE' place=79
-- Compute scores for PEW4-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-EPEE-2025-2026')
);

-- ---- PEW5: EVF Grand Prix 5 ( Mens Epee Cat 2 - Stockholm International Veteran Open 2026 ) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW5-2025-2026',
    'EVF Grand Prix 5',
    ' Mens Epee Cat 2 - Stockholm International Veteran Open 2026 ',
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
    'PEW5-V2-M-EPEE-2025-2026',
    'EVF Grand Prix 5',
    'PEW',
    'EPEE', 'M', 'V2',
    NULL, 50, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V2-M-EPEE-2025-2026'),
    1,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
-- SKIPPED (international, no master data): 'LAUGA Eric' place=2
-- SKIPPED (international, no master data): 'ELMFELDT Mathias' place=3
-- SKIPPED (international, no master data): 'STANCIU Adrian' place=4
-- SKIPPED (international, no master data): 'PIRANI Claudio' place=5
-- SKIPPED (international, no master data): 'UHLIG Andreas' place=6
-- SKIPPED (international, no master data): 'VON GEIJER Jonas' place=7
-- SKIPPED (international, no master data): 'AUTZEN Olaf' place=8
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    155,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V2-M-EPEE-2025-2026'),
    9,
    'LEAHEY John'
); -- matched: LEAHEY John (score=100.0)
-- SKIPPED (international, no master data): 'GRAND Eric' place=10
-- SKIPPED (international, no master data): 'DEGAUQUE Gilles' place=11
-- SKIPPED (international, no master data): 'DE BURGH Etienne' place=12
-- SKIPPED (international, no master data): 'BULLEN Edward' place=13
-- SKIPPED (international, no master data): 'AFANASSIEV Igor' place=14
-- SKIPPED (international, no master data): 'SCHIOELER Thomas' place=15
-- SKIPPED (international, no master data): 'BERGER Matthias' place=16
-- SKIPPED (international, no master data): 'FORSSE Tor' place=17
-- SKIPPED (international, no master data): 'KRETSCHMER Jan' place=18
-- SKIPPED (international, no master data): 'SWENNING Joar' place=19
-- SKIPPED (international, no master data): 'ZANELLA Mauro Cesar' place=20
-- SKIPPED (international, no master data): 'MOISI Mihai' place=21
-- SKIPPED (international, no master data): 'ROTA Carlo' place=22
-- SKIPPED (international, no master data): 'ARVIUS Fredrik' place=23
-- SKIPPED (international, no master data): 'GRAVES SMITH Geoffrey' place=24
-- SKIPPED (international, no master data): 'MAY Jozsef' place=25
-- SKIPPED (international, no master data): 'WIMAN Carl-Johan' place=26
-- SKIPPED (international, no master data): 'OHANESSIAN Sarkis' place=27
-- SKIPPED (international, no master data): 'ROZKOV Aleksei' place=28
-- SKIPPED (international, no master data): 'GRIFFIN Adrian' place=29
-- SKIPPED (international, no master data): 'ADOLFSSON Stefan' place=30
-- SKIPPED (international, no master data): 'PULEGA Roberto Andrea Enzo' place=31
-- SKIPPED (international, no master data): 'SANDELL Johan' place=32
-- SKIPPED (international, no master data): 'KOLBJORNSEN Endre' place=33
-- SKIPPED (international, no master data): 'SAHLQVIST Johan' place=34
-- SKIPPED (international, no master data): 'DAHLSTEN Peter' place=35
-- SKIPPED (international, no master data): 'PERTOFT Jens' place=36
-- SKIPPED (international, no master data): 'ACIKEL Ugur' place=37
-- SKIPPED (international, no master data): 'HANSEN Michael' place=38
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    172,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V2-M-EPEE-2025-2026'),
    39,
    'MCQUEEN Andrew'
); -- matched: MCQUEEN Andy (score=96.42857142857143)
-- SKIPPED (international, no master data): 'CSISZAR Zoltan' place=40
-- SKIPPED (international, no master data): 'RANDO Pablo' place=41
-- SKIPPED (international, no master data): 'DETTNER Fredrik' place=42
-- SKIPPED (international, no master data): 'WERNER Martin' place=43
-- SKIPPED (international, no master data): 'MALHOTRA Dev' place=44
-- SKIPPED (international, no master data): 'BORICS Gabor' place=45
-- SKIPPED (international, no master data): 'MANCOSU Antonio' place=46
-- SKIPPED (international, no master data): 'FLEMMER Henrik' place=47
-- SKIPPED (international, no master data): 'VICTORY David' place=48
-- SKIPPED (international, no master data): 'KLEVEBRING John' place=49
-- SKIPPED (international, no master data): 'HELLSTROEM Johan' place=50
-- Compute scores for PEW5-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V2-M-EPEE-2025-2026')
);

-- ---- PEW6: EVF Grand Prix 6 (Szpada Mężczyzn V2) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW6-2025-2026',
    'EVF Grand Prix 6',
    'Szpada Mężczyzn V2',
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
    'PEW6-V2-M-EPEE-2025-2026',
    'EVF Grand Prix 6',
    'PEW',
    'EPEE', 'M', 'V2',
    NULL, 38, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'GOETZ Grégory' place=1
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
    2,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    104,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
    3,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
    4,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
-- SKIPPED (international, no master data): 'VAULIN Serhiy' place=5
-- SKIPPED (international, no master data): 'BABKA Taras' place=6
-- SKIPPED (international, no master data): 'KAMANY Roland' place=7
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    290,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
    8,
    'WASIOŁKA Sebastian'
); -- matched: WASIOŁKA Sebastian (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    155,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
    9,
    'LEAHEY John'
); -- matched: LEAHEY John (score=100.0)
-- SKIPPED (international, no master data): 'PULEGA Roberto' place=10
-- SKIPPED (international, no master data): 'KOEMETS Sven' place=11
-- SKIPPED (international, no master data): 'DEÁK István' place=12
-- SKIPPED (international, no master data): 'BULLEN Edward' place=13
-- SKIPPED (international, no master data): 'STANCIU Adrian Virgil' place=14
-- SKIPPED (international, no master data): 'GRAVES SMITH Geoffrey' place=15
-- SKIPPED (international, no master data): 'ÓCSAI János' place=16
-- SKIPPED (international, no master data): 'MAY József' place=17
-- SKIPPED (international, no master data): 'DEBURGH Etienne' place=18
-- SKIPPED (international, no master data): 'BERNEIS Christian' place=19
-- SKIPPED (international, no master data): 'SZAKMÁRY Sándor' place=20
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
    21,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    246,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
    22,
    'SOKOL Vratislav'
); -- matched: SOKOL Vratislav (score=100.0)
-- SKIPPED (international, no master data): 'PILHAL Zsolt' place=23
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    103,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
    24,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100.0)
-- SKIPPED (international, no master data): 'CSISZÁR Zoltán' place=25
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    318,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
    26,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100.0)
-- SKIPPED (international, no master data): 'GRAEBE David' place=27
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    195,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
    28,
    'OLSZEWSKI Mikołaj'
); -- matched: OLSZEWSKI Mikołaj (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    50,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
    29,
    'DUDEK Mariusz'
); -- matched: DUDEK Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    118,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
    30,
    'KOBIERSKI Krzysztof'
); -- matched: KOBIERSKI Krzysztof (score=100.0)
-- SKIPPED (international, no master data): 'AÇIKEL Uğur' place=31
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
    32,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
    33,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
    34,
    'SKOCZEK Artur'
); -- matched: SKOCZEK Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    264,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
    35,
    'SZKODA Marek'
); -- matched: SZKODA Marek Tomasz (score=100.0)
-- SKIPPED (international, no master data): 'MANISCALCO Rosario Sergio' place=36
-- SKIPPED (international, no master data): 'KURUTZ Balázs' place=37
-- SKIPPED (international, no master data): 'TOMAS ROLDAN Alejandro' place=38
-- Compute scores for PEW6-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026')
);

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): N=0 — tournament had no participants

-- ---- PEW10: EVF Criterium Mondial Vétérans (Paryż) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW10-2025-2026',
    'EVF Criterium Mondial Vétérans 2025',
    'Paryż',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW10-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW10-2025-2026'),
    'PEW10-V2-M-EPEE-2025-2026',
    'EVF Criterium Mondial Vétérans 2025',
    'PEW',
    'EPEE', 'M', 'V2',
    '2025-07-05', 75, 'https://engarde-service.com/competition/fencingaddict/crit25/ehv2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW10-V2-M-EPEE-2025-2026'),
    41,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW10-V2-M-EPEE-2025-2026'),
    77,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
-- Compute scores for PEW10-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW10-V2-M-EPEE-2025-2026')
);

-- Summary
-- Total results matched:   103
-- Total results unmatched: 261
-- Total auto-created:      0
