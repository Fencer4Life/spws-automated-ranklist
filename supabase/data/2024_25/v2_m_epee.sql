-- =========================================================================
-- Season 2024-2025 — V2 M EPEE — sourced from SZPADA-2-2024-2025.xlsx
--                               + SZPADA-2-2025-2026.xlsx (early 2025 rounds)
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- Note: Events from 2025-26 source retain '-2024-2025' suffix in event codes.
-- =========================================================================

-- ---- PP1: I Puchar Polski Weteranów (KONIN) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
VALUES (
    'PP1-2024-2025',
    'I Puchar Polski Weteranów',
    'KONIN',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
);
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PP1-2024-2025'),
    'PP1-V2-M-EPEE-2024-2025',
    'I Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V2',
    '2024-09-28', 10, 'https://www.fencingtimelive.com/events/results/0EFF7807CB3942EE87C74E02F521AA2F',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V2-M-EPEE-2024-2025'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    95,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V2-M-EPEE-2024-2025'),
    2,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    266,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V2-M-EPEE-2024-2025'),
    3,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V2-M-EPEE-2024-2025'),
    4,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    64,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V2-M-EPEE-2024-2025'),
    5,
    'GĄSIOROWSKI Maciej'
); -- matched: GĄSIOROWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    96,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V2-M-EPEE-2024-2025'),
    6,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    86,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V2-M-EPEE-2024-2025'),
    7,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    236,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V2-M-EPEE-2024-2025'),
    8,
    'TRACZ Jerzy'
); -- matched: TRACZ Jerzy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    269,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V2-M-EPEE-2024-2025'),
    9,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V2-M-EPEE-2024-2025'),
    10,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    181,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V2-M-EPEE-2024-2025'),
    13,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
-- Compute scores for PP1-V2-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V2-M-EPEE-2024-2025')
);

-- ---- PP2: II Puchar Polski Weteranów (BYTOM) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
VALUES (
    'PP2-2024-2025',
    'II Puchar Polski Weteranów',
    'BYTOM',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
);
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PP2-2024-2025'),
    'PP2-V2-M-EPEE-2024-2025',
    'II Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V2',
    '2024-10-26', 9, 'https://www.fencingtimelive.com/events/results/9A0573623F6846018B437E544293FDFC',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    266,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V2-M-EPEE-2024-2025'),
    1,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V2-M-EPEE-2024-2025'),
    2,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    95,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V2-M-EPEE-2024-2025'),
    3,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    181,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V2-M-EPEE-2024-2025'),
    4,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    86,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V2-M-EPEE-2024-2025'),
    5,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    269,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V2-M-EPEE-2024-2025'),
    6,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100.0)
-- UNMATCHED (score<80): 'RUSEK Roman' place=7
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V2-M-EPEE-2024-2025'),
    8,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V2-M-EPEE-2024-2025'),
    9,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
-- Compute scores for PP2-V2-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V2-M-EPEE-2024-2025')
);

-- ---- PP3: III Puchar Polski Weteranów (KRAKÓW) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
VALUES (
    'PP3-2024-2025',
    'III Puchar Polski Weteranów',
    'KRAKÓW',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
);
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PP3-2024-2025'),
    'PP3-V2-M-EPEE-2024-2025',
    'III Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V2',
    '2024-11-30', 10, 'https://www.fencingtimelive.com/events/results/E9C2969C8ED0414CB291196B8FA0E28C',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-M-EPEE-2024-2025'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    266,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-M-EPEE-2024-2025'),
    2,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    95,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-M-EPEE-2024-2025'),
    3,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    181,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-M-EPEE-2024-2025'),
    4,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    269,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-M-EPEE-2024-2025'),
    5,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    64,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-M-EPEE-2024-2025'),
    6,
    'GĄSIOROWSKI Maciej'
); -- matched: GĄSIOROWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    86,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-M-EPEE-2024-2025'),
    7,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-M-EPEE-2024-2025'),
    8,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    236,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-M-EPEE-2024-2025'),
    9,
    'TRACZ Jerzy'
); -- matched: TRACZ Jerzy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-M-EPEE-2024-2025'),
    10,
    'WIERZBICKI JACEK'
); -- matched: WIERZBICKI Jacek (score=100.0)
-- Compute scores for PP3-V2-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-M-EPEE-2024-2025')
);

-- ---- PP4: IV Puchar Polski Weteranów — Szpada M (WARSZAWA) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
VALUES (
    'PP4-2024-2025',
    'IV Puchar Polski Weteranów — Szpada M',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
);
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PP4-2024-2025'),
    'PP4-V2-M-EPEE-2024-2025',
    'IV Puchar Polski Weteranów — Szpada M',
    'PPW',
    'EPEE', 'M', 'V2',
    '2025-02-22', 8, 'https://www.fencingtimelive.com/events/results/2277992D25F6460485EE1A52BBFCB132',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP4-V2-M-EPEE-2024-2025'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    266,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP4-V2-M-EPEE-2024-2025'),
    2,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    181,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP4-V2-M-EPEE-2024-2025'),
    3,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    95,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP4-V2-M-EPEE-2024-2025'),
    4,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP4-V2-M-EPEE-2024-2025'),
    5,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100)
-- UNMATCHED (<80): 'ODOLAK Jarosław' place=6
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    210,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP4-V2-M-EPEE-2024-2025'),
    7,
    'SKOCZEK Artur'
); -- matched: SKOCZEK Artur (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP4-V2-M-EPEE-2024-2025'),
    8,
    'WIERZBICKI JACEK'
); -- matched: WIERZBICKI Jacek (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP4-V2-M-EPEE-2024-2025'),
    11,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    110,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP4-V2-M-EPEE-2024-2025'),
    12,
    'KOBIERSKI Krzysztof'
); -- matched: KOBIERSKI Krzysztof (score=100)
-- Compute scores for PP4-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP4-V2-M-EPEE-2024-2025')
);

-- ---- PP5: V Puchar Polski Weteranów — Szpada M (SZCZECIN) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
VALUES (
    'PP5-2024-2025',
    'V Puchar Polski Weteranów — Szpada M',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
);
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PP5-2024-2025'),
    'PP5-V2-M-EPEE-2024-2025',
    'V Puchar Polski Weteranów — Szpada M',
    'PPW',
    'EPEE', 'M', 'V2',
    '2025-04-26', 4, 'https://www.fencingtimelive.com/events/results/993817953DF94EE2BD3A86CEEF94CEF5',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    45,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP5-V2-M-EPEE-2024-2025'),
    1,
    'DROBIŃSKI Leszek'
); -- matched: DROBIŃSKI Leszek (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    269,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP5-V2-M-EPEE-2024-2025'),
    2,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    181,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP5-V2-M-EPEE-2024-2025'),
    3,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP5-V2-M-EPEE-2024-2025'),
    4,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    247,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP5-V2-M-EPEE-2024-2025'),
    6,
    'WASIOŁKA Sebastian'
); -- matched: WASIOŁKA Sebastian (score=100)
-- Compute scores for PP5-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP5-V2-M-EPEE-2024-2025')
);

-- ---- MPW: Mistrzostwa Polski Weteranów — Szpada M (PABIANICE) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
VALUES (
    'MPW-2024-2025',
    'Mistrzostwa Polski Weteranów — Szpada M',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
);
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'MPW-2024-2025'),
    'MPW-V2-M-EPEE-2024-2025',
    'Mistrzostwa Polski Weteranów — Szpada M',
    'MPW',
    'EPEE', 'M', 'V2',
    '2025-06-07', 6, 'https://www.fencingtimelive.com/events/results/8F6BDF11C6344222A0DCEBCA8D22EFA7',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    266,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2024-2025'),
    1,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    96,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2024-2025'),
    2,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100)
-- UNMATCHED (<80): 'WOJTAS Bogusław' place=3
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    269,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2024-2025'),
    4,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    236,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2024-2025'),
    5,
    'TRACZ Jerzy'
); -- matched: TRACZ Jerzy (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2024-2025'),
    6,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    247,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2024-2025'),
    8,
    'WASIOŁKA Sebastian'
); -- matched: WASIOŁKA Sebastian (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2024-2025'),
    9,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
-- Compute scores for MPW-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2024-2025')
);

-- ---- PEW1: EVF Grand Prix 1 — Budapeszt (Budapeszt) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
VALUES (
    'PEW1-2024-2025',
    'EVF Grand Prix 1 — Budapeszt',
    'Budapeszt',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
);
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
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-EPEE-2024-2025'),
    2,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    95,
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
VALUES (
    'PEW2-2024-2025',
    'EVF Grand Prix 2 — Madryt',
    'Madrid',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
);
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
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-EPEE-2024-2025'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    95,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-EPEE-2024-2025'),
    31,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-EPEE-2024-2025'),
    32,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
-- Compute scores for PEW2-V2-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-EPEE-2024-2025')
);

-- ---- PEW3: EVF Grand Prix 3 — Guildford (Guildford) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
VALUES (
    'PEW3-2024-2025',
    'EVF Grand Prix 3 — Guildford',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
);
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW3-2024-2025'),
    'PEW3-V2-M-EPEE-2024-2025',
    'EVF Grand Prix 3 — Guildford',
    'PEW',
    'EPEE', 'M', 'V2',
    '2025-01-04', 53, 'https://www.fencingtimelive.com/events/results/EEC7379682834E588E5B267447C7266A',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2024-2025'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    95,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2024-2025'),
    22,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2024-2025'),
    39,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2024-2025'),
    56,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
-- Compute scores for PEW3-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2024-2025')
);

-- ---- PEW4: EVF Grand Prix 4 — Terni (Terni) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
VALUES (
    'PEW4-2024-2025',
    'EVF Grand Prix 4 — Terni',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
);
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW4-2024-2025'),
    'PEW4-V2-M-EPEE-2024-2025',
    'EVF Grand Prix 4 — Terni',
    'PEW',
    'EPEE', 'M', 'V2',
    '2025-02-01', 64, 'https://www.4fence.it/FIS/Risultati/2025-02-02-01_Terni_(TR)_-_4_Prova_Naz.le_Master_-_EVF_Circuit/index.php?a=SP&s=M&c=7&f=clafinale',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-EPEE-2024-2025'),
    2,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-EPEE-2024-2025'),
    31,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-EPEE-2024-2025'),
    66,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
-- Compute scores for PEW4-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-EPEE-2024-2025')
);

-- ---- PEW5: EVF Grand Prix 5 — Sztokholm (Stockholm (SWE)) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
VALUES (
    'PEW5-2024-2025',
    'EVF Grand Prix 5 — Sztokholm',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
);
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW5-2024-2025'),
    'PEW5-V2-M-EPEE-2024-2025',
    'EVF Grand Prix 5 — Sztokholm',
    'PEW',
    'EPEE', 'M', 'V2',
    '2025-03-15', 31, 'https://fencing.ophardt.online/en/search/results/30279',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V2-M-EPEE-2024-2025'),
    22,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V2-M-EPEE-2024-2025'),
    34,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
-- Compute scores for PEW5-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V2-M-EPEE-2024-2025')
);

-- ---- PEW6: EVF Grand Prix 6 — Warszawa (WARSZAWA) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
VALUES (
    'PEW6-2024-2025',
    'EVF Grand Prix 6 — Warszawa',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
);
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW6-2024-2025'),
    'PEW6-V2-M-EPEE-2024-2025',
    'EVF Grand Prix 6 — Warszawa',
    'PEW',
    'EPEE', 'M', 'V2',
    '2025-03-29', 45, 'https://www.fencingtimelive.com/events/results/1DAD5541330547AC9204125523A0C1A9',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100)
-- UNMATCHED (<80): 'MAGHON Hans' place=2
-- UNMATCHED (<80): 'LESNE Ludovic' place=3
-- UNMATCHED (<80): 'LAMOTHE Olivier' place=3
-- UNMATCHED (<80): 'PEYRET LACOMBE Emmanuel' place=5
-- UNMATCHED (<80): 'KOUTSOUFLAKIS Stamatios' place=6
-- UNMATCHED (<80): 'KOEMETS Sven' place=7
-- UNMATCHED (<80): 'PULEGA Roberto' place=8
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    266,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    9,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    96,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    10,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100)
-- UNMATCHED (<80): 'TULUMELLO Carmelo' place=11
-- UNMATCHED (<80): 'GRAVES SMITH Geoffrey' place=12
-- UNMATCHED (<80): 'LEAHEY John' place=13
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    86,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    14,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100)
-- UNMATCHED (<80): 'BABKA Taras' place=15
-- UNMATCHED (<80): 'LE DEVEHAT Yannick' place=16
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    269,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    17,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100)
-- UNMATCHED (<80): 'LEE Ambrose' place=18
-- UNMATCHED (<80): 'RODARY Emmanuel' place=19
-- UNMATCHED (<80): 'ÓCSAI János' place=20
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    236,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    21,
    'TRACZ Jerzy'
); -- matched: TRACZ Jerzy (score=100)
-- UNMATCHED (<80): 'BENITAH Eliahu' place=22
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    169,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    23,
    'OLSZEWSKI Mikołaj'
); -- matched: OLSZEWSKI Mikołaj (score=100)
-- UNMATCHED (<80): 'NILISK Kenno' place=24
-- UNMATCHED (<80): 'SWENNING Joar' place=25
-- UNMATCHED (<80): 'TRAKHTENBERG Valeri' place=26
-- UNMATCHED (<80): 'GRAEBE David' place=27
-- UNMATCHED (<80): 'DE BURGH Etienne' place=28
-- UNMATCHED (<80): 'MESTER György' place=29
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    210,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    30,
    'SKOCZEK Artur'
); -- matched: SKOCZEK Artur (score=100)
-- UNMATCHED (<80): 'CARRÉ DE MALBERG Alexandre' place=31
-- UNMATCHED (<80): 'MÜLLER Ferenc' place=32
-- UNMATCHED (<80): 'KANASHENKOV Pavel' place=33
-- UNMATCHED (<80): 'GERTSMAN Alex' place=34
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    35,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    27,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    36,
    'CANIARD Herve'
); -- matched: CANIARD Henry (score=85)
-- UNMATCHED (<80): 'TRIMMEL Johannes' place=37
-- UNMATCHED (<80): 'GOLD Oleg' place=38
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    39,
    'DUDEK Mariusz'
); -- matched: DUDEK Mariusz (score=100)
-- UNMATCHED (<80): 'STUDENY Frantisek' place=40
-- UNMATCHED (<80): 'SZKODA Marek' place=41
-- UNMATCHED (<80): 'AÇIKEL Uğur' place=42
-- UNMATCHED (<80): 'ODOLAK Jarosław' place=43
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    44,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100)
-- UNMATCHED (<80): 'BISKUPSKI Marek' place=45
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    48,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    247,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    49,
    'WASIOŁKA Sebastian'
); -- matched: WASIOŁKA Sebastian (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    110,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025'),
    50,
    'KOBIERSKI Krzysztof'
); -- matched: KOBIERSKI Krzysztof (score=100)
-- Compute scores for PEW6-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2024-2025')
);

-- SKIP PEW7 (EVF Grand Prix 7 — Chania): N=None — tournament skipped

-- ---- PS: Puchar Świata Weteranów — Paryż (Paryż) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
VALUES (
    'PS-2024-2025',
    'Puchar Świata Weteranów — Paryż',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
);
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PS-2024-2025'),
    'PS-V2-M-EPEE-2024-2025',
    'Puchar Świata Weteranów — Paryż',
    'PEW',
    'EPEE', 'M', 'V2',
    '2025-07-05', 75, 'https://engarde-service.com/competition/fencingaddict/crit25/ehv2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PS-V2-M-EPEE-2024-2025'),
    41,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PS-V2-M-EPEE-2024-2025'),
    77,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
-- Compute scores for PS-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PS-V2-M-EPEE-2024-2025')
);

-- ---- IMEW: Indywidualne Mistrzostwa Europy Weteranów — Płowdiw (Płowdiw) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
VALUES (
    'IMEW-2024-2025',
    'Indywidualne Mistrzostwa Europy Weteranów — Płowdiw',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
);
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'IMEW-2024-2025'),
    'IMEW-V2-M-EPEE-2024-2025',
    'Indywidualne Mistrzostwa Europy Weteranów — Płowdiw',
    'MEW',
    'EPEE', 'M', 'V2',
    '2025-05-29', 110, 'https://www.fencingtimelive.com/events/results/F335344201F74762AED57ADC339F65EF',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    266,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2024-2025'),
    6,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2024-2025'),
    19,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2024-2025'),
    78,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2024-2025'),
    114,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
-- Compute scores for IMEW-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2024-2025')
);


-- Backfill txt_location for events moved from 2025-26 source
UPDATE tbl_event SET txt_location = 'Warszawa'  WHERE txt_code = 'PP4-2024-2025';
UPDATE tbl_event SET txt_location = 'Szczecin'  WHERE txt_code = 'PP5-2024-2025';
UPDATE tbl_event SET txt_location = 'Pabianice' WHERE txt_code = 'MPW-2024-2025';
UPDATE tbl_event SET txt_location = 'Guildford' WHERE txt_code = 'PEW3-2024-2025';
UPDATE tbl_event SET txt_location = 'Terni'     WHERE txt_code = 'PEW4-2024-2025';
UPDATE tbl_event SET txt_location = 'Sztokholm' WHERE txt_code = 'PEW5-2024-2025';
UPDATE tbl_event SET txt_location = 'Warszawa'  WHERE txt_code = 'PEW6-2024-2025';
UPDATE tbl_event SET txt_location = 'Paryż'     WHERE txt_code = 'PS-2024-2025';
UPDATE tbl_event SET txt_location = 'Płowdiw'   WHERE txt_code = 'IMEW-2024-2025';

-- Summary
-- Domestic:     PP1-PP3 (2024 autumn), PP4-PP5+MPW (2025 spring, from 2025-26 source)
-- International: PEW1-PEW2 (2024 autumn), PEW2-PEW6+PS+IMEW (2025 spring, from 2025-26 source)
