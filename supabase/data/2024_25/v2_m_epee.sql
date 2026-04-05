-- =========================================================================
-- Season 2024-2025 — V2 M EPEE — generated from SZPADA-2-2024-2025.xlsx
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
    'PPW1-V2-M-EPEE-2024-2025',
    'I Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V2',
    '2024-09-28', 10, 'https://www.fencingtimelive.com/events/results/0EFF7807CB3942EE87C74E02F521AA2F',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2024-2025'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    103,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2024-2025'),
    2,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    311,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2024-2025'),
    3,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2024-2025'),
    4,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    88,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2024-2025'),
    5,
    'GĄSIOROWSKI Maciej'
); -- matched: GĄSIOROWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    104,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2024-2025'),
    6,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2024-2025'),
    7,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    279,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2024-2025'),
    8,
    'TRACZ Jerzy'
); -- matched: TRACZ Jerzy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    318,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2024-2025'),
    9,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2024-2025'),
    10,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    207,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2024-2025'),
    13,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
-- Compute scores for PPW1-V2-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2024-2025')
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
    'PPW2-V2-M-EPEE-2024-2025',
    'II Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V2',
    '2024-10-26', 9, 'https://www.fencingtimelive.com/events/results/9A0573623F6846018B437E544293FDFC',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    311,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2024-2025'),
    1,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2024-2025'),
    2,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    103,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2024-2025'),
    3,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    207,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2024-2025'),
    4,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2024-2025'),
    5,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    318,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2024-2025'),
    6,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    227,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2024-2025'),
    7,
    'RUSEK Roman'
); -- matched: RUSEK Roman (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2024-2025'),
    8,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2024-2025'),
    9,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
-- Compute scores for PPW2-V2-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2024-2025')
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
    'PPW3-V2-M-EPEE-2024-2025',
    'III Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V2',
    '2024-11-30', 10, 'https://www.fencingtimelive.com/events/results/E9C2969C8ED0414CB291196B8FA0E28C',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2024-2025'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    311,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2024-2025'),
    2,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    103,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2024-2025'),
    3,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    207,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2024-2025'),
    4,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    318,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2024-2025'),
    5,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    88,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2024-2025'),
    6,
    'GĄSIOROWSKI Maciej'
); -- matched: GĄSIOROWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2024-2025'),
    7,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2024-2025'),
    8,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    279,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2024-2025'),
    9,
    'TRACZ Jerzy'
); -- matched: TRACZ Jerzy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2024-2025'),
    10,
    'WIERZBICKI JACEK'
); -- matched: WIERZBICKI Jacek (score=100.0)
-- Compute scores for PPW3-V2-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2024-2025')
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
    'PPW4-V2-M-EPEE-2024-2025',
    'IV Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V2',
    '2025-02-22', 8, 'https://www.fencingtimelive.com/events/results/2277992D25F6460485EE1A52BBFCB132',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2024-2025'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    311,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2024-2025'),
    2,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    207,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2024-2025'),
    3,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    103,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2024-2025'),
    4,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2024-2025'),
    5,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    193,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2024-2025'),
    6,
    'ODOLAK Jarosław'
); -- matched: ODOLAK Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2024-2025'),
    7,
    'SKOCZEK Artur'
); -- matched: SKOCZEK Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2024-2025'),
    8,
    'WIERZBICKI JACEK'
); -- matched: WIERZBICKI Jacek (score=100.0)
-- Compute scores for PPW4-V2-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2024-2025')
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
    'PPW5-V2-M-EPEE-2024-2025',
    'V Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V2',
    '2025-04-26', 4, 'https://www.fencingtimelive.com/events/results/993817953DF94EE2BD3A86CEEF94CEF5',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    49,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V2-M-EPEE-2024-2025'),
    1,
    'DROBINSKI Leszek'
); -- matched: DROBIŃSKI Leszek (score=93.75)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    318,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V2-M-EPEE-2024-2025'),
    2,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    207,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V2-M-EPEE-2024-2025'),
    3,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V2-M-EPEE-2024-2025'),
    4,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
-- Compute scores for PPW5-V2-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V2-M-EPEE-2024-2025')
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
    'MPW-V2-M-EPEE-2024-2025',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'EPEE', 'M', 'V2',
    '2025-06-07', 6, 'https://www.fencingtimelive.com/events/results/8F6BDF11C6344222A0DCEBCA8D22EFA7',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    311,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2024-2025'),
    1,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    104,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2024-2025'),
    2,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    300,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2024-2025'),
    3,
    'WOJTAS Bogusław'
); -- matched: WOJTAS Bogusław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    318,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2024-2025'),
    4,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    279,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2024-2025'),
    5,
    'TRACZ Jerzy'
); -- matched: TRACZ Jerzy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2024-2025'),
    6,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
-- Compute scores for MPW-V2-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2024-2025')
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
    'PEW1-V2-M-EPEE-2024-2025',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'EPEE', 'M', 'V2',
    '2024-09-21', 47, 'https://engarde-service.com/app.php?id=4207L2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-EPEE-2024-2025'),
    2,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    103,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-EPEE-2024-2025'),
    24,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100.0)
-- Compute scores for PEW1-V2-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-EPEE-2024-2025')
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
    'PEW2-V2-M-EPEE-2024-2025',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'EPEE', 'M', 'V2',
    '2024-11-16', 55, 'https://engarde-service.com/competition/aeve_esgrima/evf_madrid_2024/em-2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-EPEE-2024-2025'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    103,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-EPEE-2024-2025'),
    31,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-EPEE-2024-2025'),
    32,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
-- Compute scores for PEW2-V2-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-EPEE-2024-2025')
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
    'PEW3-V2-M-EPEE-2024-2025',
    'EVF Grand Prix 3',
    'PEW',
    'EPEE', 'M', 'V2',
    '2025-01-04', 53, 'https://www.fencingtimelive.com/events/results/EEC7379682834E588E5B267447C7266A',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2024-2025'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    103,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2024-2025'),
    22,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2024-2025'),
    39,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
-- Compute scores for PEW3-V2-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2024-2025')
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
    'PEW4-V2-M-EPEE-2024-2025',
    'EVF Grand Prix 4',
    'PEW',
    'EPEE', 'M', 'V2',
    '2025-02-01', 64, 'https://www.4fence.it/FIS/Risultati/2025-02-02-01_Terni_(TR)_-_4_Prova_Naz.le_Master_-_EVF_Circuit/index.php?a=SP&s=M&c=7&f=clafinale',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-EPEE-2024-2025'),
    2,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-EPEE-2024-2025'),
    31,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
-- Compute scores for PEW4-V2-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-EPEE-2024-2025')
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
    'PEW5-V2-M-EPEE-2024-2025',
    'EVF Grand Prix 5',
    'PEW',
    'EPEE', 'M', 'V2',
    '2025-03-15', 31, 'https://fencing.ophardt.online/en/search/results/30279',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V2-M-EPEE-2024-2025'),
    22,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
-- Compute scores for PEW5-V2-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V2-M-EPEE-2024-2025')
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
    'PEW6-V2-M-EPEE-2024-2025',
    'EVF Grand Prix 6',
    'PEW',
    'EPEE', 'M', 'V2',
    '2025-03-29', 45, 'https://www.fencingtimelive.com/events/results/1DAD5541330547AC9204125523A0C1A9',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
-- SKIPPED (international, no master data): 'MAGHON Hans' place=2
-- SKIPPED (international, no master data): 'LESNE Ludovic' place=3
-- SKIPPED (international, no master data): 'LAMOTHE Olivier' place=3
-- SKIPPED (international, no master data): 'PEYRET LACOMBE Emmanuel' place=5
-- SKIPPED (international, no master data): 'KOUTSOUFLAKIS Stamatios' place=6
-- SKIPPED (international, no master data): 'KOEMETS Sven' place=7
-- SKIPPED (international, no master data): 'PULEGA Roberto' place=8
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    311,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    9,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    104,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    10,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100.0)
-- SKIPPED (international, no master data): 'TULUMELLO Carmelo' place=11
-- SKIPPED (international, no master data): 'GRAVES SMITH Geoffrey' place=12
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    155,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    13,
    'LEAHEY John'
); -- matched: LEAHEY John (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    14,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
-- SKIPPED (international, no master data): 'BABKA Taras' place=15
-- SKIPPED (international, no master data): 'LE DEVEHAT Yannick' place=16
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    318,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    17,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100.0)
-- SKIPPED (international, no master data): 'LEE Ambrose' place=18
-- SKIPPED (international, no master data): 'RODARY Emmanuel' place=19
-- SKIPPED (international, no master data): 'ÓCSAI János' place=20
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    279,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    21,
    'TRACZ Jerzy'
); -- matched: TRACZ Jerzy (score=100.0)
-- SKIPPED (international, no master data): 'BENITAH Eliahu' place=22
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    195,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    23,
    'OLSZEWSKI Mikołaj'
); -- matched: OLSZEWSKI Mikołaj (score=100.0)
-- SKIPPED (international, no master data): 'NILISK Kenno' place=24
-- SKIPPED (international, no master data): 'SWENNING Joar' place=25
-- SKIPPED (international, no master data): 'TRAKHTENBERG Valeri' place=26
-- SKIPPED (international, no master data): 'GRAEBE David' place=27
-- SKIPPED (international, no master data): 'DE BURGH Etienne' place=28
-- SKIPPED (international, no master data): 'MESTER György' place=29
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    30,
    'SKOCZEK Artur'
); -- matched: SKOCZEK Artur (score=100.0)
-- SKIPPED (international, no master data): 'CARRÉ DE MALBERG Alexandre' place=31
-- SKIPPED (international, no master data): 'MÜLLER Ferenc' place=32
-- SKIPPED (international, no master data): 'KANASHENKOV Pavel' place=33
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    67,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    34,
    'GERTSMAN Alex'
); -- matched: GERTSMAN Alex (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    35,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    30,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    36,
    'CANIARD Herve'
); -- matched: CANIARD Henry (score=93.75)
-- SKIPPED (international, no master data): 'TRIMMEL Johannes' place=37
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    71,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    38,
    'GOLD Oleg'
); -- matched: GOLD Oleg (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    50,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    39,
    'DUDEK Mariusz'
); -- matched: DUDEK Mariusz (score=100.0)
-- SKIPPED (international, no master data): 'STUDENY Frantisek' place=40
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    264,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    41,
    'SZKODA Marek'
); -- matched: SZKODA Marek Tomasz (score=100.0)
-- SKIPPED (international, no master data): 'AÇIKEL Uğur' place=42
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    193,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    43,
    'ODOLAK Jarosław'
); -- matched: ODOLAK Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    44,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
-- SKIPPED (international, no master data): 'BISKUPSKI Marek' place=45
-- Compute scores for PEW6-V2-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025')
);

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): N=0 — tournament had no participants

-- ---- PEW10: EVF Criterium Mondial Vétérans (Paryż) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW10-2024-2025',
    'EVF Criterium Mondial Vétérans 2025',
    'Paryż',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW10-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW10-2024-2025'),
    'PEW10-V2-M-EPEE-2024-2025',
    'EVF Criterium Mondial Vétérans 2025',
    'PEW',
    'EPEE', 'M', 'V2',
    '2025-07-05', 75, 'https://engarde-service.com/competition/fencingaddict/crit25/ehv2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW10-V2-M-EPEE-2024-2025'),
    41,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
-- Compute scores for PS-V2-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW10-V2-M-EPEE-2024-2025')
);

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
    'IMEW-V2-M-EPEE-2024-2025',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'EPEE', 'M', 'V2',
    '2025-05-29', 110, 'https://www.fencingtimelive.com/events/results/F335344201F74762AED57ADC339F65EF',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    311,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2024-2025'),
    6,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2024-2025'),
    19,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2024-2025'),
    78,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
-- Compute scores for IMEW-V2-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2024-2025')
);

-- Summary
-- Total results matched:   80
-- Total results unmatched: 28
-- Total auto-created:      0
