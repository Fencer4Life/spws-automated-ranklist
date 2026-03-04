-- =========================================================================
-- Season 2025/26 real data — generated from SZPADA-2-2025-2026.xlsx
-- Run AFTER seed.sql (which creates the season and organizers).
-- =========================================================================

-- Expand season start to cover EVF rounds from early 2025
UPDATE tbl_season
   SET dt_start = '2025-01-01'
 WHERE txt_code = 'SPWS-2025-2026';

-- Remove the placeholder sample event/tournament from seed.sql
DELETE FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2025';
DELETE FROM tbl_event WHERE txt_code = 'PPW1-KRAKOW-2025';

-- ---- PP1: I Puchar Polski Weteranów — Szpada M (OPOLE) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
VALUES (
    'PP1-2025-2026',
    'I Puchar Polski Weteranów — Szpada M',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
);
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PP1-2025-2026'),
    'PP1-V2-M-EPEE-2025-2026',
    'I Puchar Polski Weteranów — Szpada M',
    'PPW',
    'EPEE', 'M', 'V2',
    '2025-09-28', 8, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    266,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V2-M-EPEE-2025-2026'),
    1,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V2-M-EPEE-2025-2026'),
    2,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    96,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V2-M-EPEE-2025-2026'),
    3,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V2-M-EPEE-2025-2026'),
    4,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    45,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V2-M-EPEE-2025-2026'),
    5,
    'DROBIŃSKI Leszek'
); -- matched: DROBIŃSKI Leszek (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V2-M-EPEE-2025-2026'),
    6,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V2-M-EPEE-2025-2026'),
    7,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    87,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V2-M-EPEE-2025-2026'),
    8,
    'HEŁKA Jacek'
); -- matched: HEŁKA Jacek (score=100)
-- Compute scores for PP1-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP1-V2-M-EPEE-2025-2026')
);

-- ---- PP2: II Puchar Polski Weteranów — Szpada M (II Puchar Weteranów Poznań) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
VALUES (
    'PP2-2025-2026',
    'II Puchar Polski Weteranów — Szpada M',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
);
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PP2-2025-2026'),
    'PP2-V2-M-EPEE-2025-2026',
    'II Puchar Polski Weteranów — Szpada M',
    'PPW',
    'EPEE', 'M', 'V2',
    '2025-10-26', 8, 'httPS://www.fencingtimelive.com/events/results/download/0387CC20A25B4EBA9BDAFAB148E8C12B',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V2-M-EPEE-2025-2026'),
    1,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    45,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V2-M-EPEE-2025-2026'),
    2,
    'DROBIŃSKI Leszek'
); -- matched: DROBIŃSKI Leszek (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    269,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V2-M-EPEE-2025-2026'),
    3,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    214,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V2-M-EPEE-2025-2026'),
    4,
    'STANIEWICZ Witold'
); -- matched: STANIEWICZ Witold (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V2-M-EPEE-2025-2026'),
    5,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V2-M-EPEE-2025-2026'),
    6,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    87,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V2-M-EPEE-2025-2026'),
    7,
    'HEŁKA Jacek'
); -- matched: HEŁKA Jacek (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    235,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V2-M-EPEE-2025-2026'),
    8,
    'TOMCZAK Ireneusz'
); -- matched: TOMCZAK Ireneusz (score=100)
-- Compute scores for PP2-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP2-V2-M-EPEE-2025-2026')
);

-- ---- PP3: III Puchar Polski Weteranów — Szpada M (Warsaw Epee Open) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
VALUES (
    'PP3-2025-2026',
    'III Puchar Polski Weteranów — Szpada M',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
);
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PP3-2025-2026'),
    'PP3-V2-M-EPEE-2025-2026',
    'III Puchar Polski Weteranów — Szpada M',
    'PPW',
    'EPEE', 'M', 'V2',
    '2025-12-13', 19, 'https://www.fencingtimelive.com/events/results/download/2034F718AC554C8D89A639B0EC0984DD',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-M-EPEE-2025-2026'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    96,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-M-EPEE-2025-2026'),
    2,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-M-EPEE-2025-2026'),
    3,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
-- UNMATCHED (<80): 'LEAHEY John' place=4
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    266,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-M-EPEE-2025-2026'),
    5,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    95,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-M-EPEE-2025-2026'),
    6,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    169,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-M-EPEE-2025-2026'),
    7,
    'OLSZEWSKI Mikołaj'
); -- matched: OLSZEWSKI Mikołaj (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    181,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-M-EPEE-2025-2026'),
    8,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    45,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-M-EPEE-2025-2026'),
    9,
    'DROBIŃSKI Leszek'
); -- matched: DROBIŃSKI Leszek (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    269,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-M-EPEE-2025-2026'),
    10,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100)
-- UNMATCHED (<80): 'GERTSMAN Alex' place=11
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    210,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-M-EPEE-2025-2026'),
    12,
    'SKOCZEK Artur'
); -- matched: SKOCZEK Artur (score=100)
-- UNMATCHED (<80): 'ODOLAK Jarosław' place=13
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    235,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-M-EPEE-2025-2026'),
    14,
    'TOMCZAK Ireneusz'
); -- matched: TOMCZAK Ireneusz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    207,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-M-EPEE-2025-2026'),
    15,
    'SERWATKA Marek'
); -- matched: SERWATKA Marek (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-M-EPEE-2025-2026'),
    16,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-M-EPEE-2025-2026'),
    17,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100)
-- UNMATCHED (<80): 'MCQUEEN Andy' place=18
-- UNMATCHED (<80): 'GOLD Oleg' place=19
-- Compute scores for PP3-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP3-V2-M-EPEE-2025-2026')
);

-- ---- PP4: IV Puchar Polski Weteranów — Szpada M (WARSZAWA) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
VALUES (
    'PP4-2025-2026',
    'IV Puchar Polski Weteranów — Szpada M',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
);
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PP4-2025-2026'),
    'PP4-V2-M-EPEE-2025-2026',
    'IV Puchar Polski Weteranów — Szpada M',
    'PPW',
    'EPEE', 'M', 'V2',
    '2025-02-22', 8, 'https://www.fencingtimelive.com/events/results/2277992D25F6460485EE1A52BBFCB132',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP4-V2-M-EPEE-2025-2026'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    266,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP4-V2-M-EPEE-2025-2026'),
    2,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    181,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP4-V2-M-EPEE-2025-2026'),
    3,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    95,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP4-V2-M-EPEE-2025-2026'),
    4,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP4-V2-M-EPEE-2025-2026'),
    5,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100)
-- UNMATCHED (<80): 'ODOLAK Jarosław' place=6
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    210,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP4-V2-M-EPEE-2025-2026'),
    7,
    'SKOCZEK Artur'
); -- matched: SKOCZEK Artur (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP4-V2-M-EPEE-2025-2026'),
    8,
    'WIERZBICKI JACEK'
); -- matched: WIERZBICKI Jacek (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP4-V2-M-EPEE-2025-2026'),
    11,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    110,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP4-V2-M-EPEE-2025-2026'),
    12,
    'KOBIERSKI Krzysztof'
); -- matched: KOBIERSKI Krzysztof (score=100)
-- Compute scores for PP4-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP4-V2-M-EPEE-2025-2026')
);

-- ---- PP5: V Puchar Polski Weteranów — Szpada M (SZCZECIN) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
VALUES (
    'PP5-2025-2026',
    'V Puchar Polski Weteranów — Szpada M',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
);
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PP5-2025-2026'),
    'PP5-V2-M-EPEE-2025-2026',
    'V Puchar Polski Weteranów — Szpada M',
    'PPW',
    'EPEE', 'M', 'V2',
    '2025-04-26', 4, 'https://www.fencingtimelive.com/events/results/993817953DF94EE2BD3A86CEEF94CEF5',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    45,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP5-V2-M-EPEE-2025-2026'),
    1,
    'DROBIŃSKI Leszek'
); -- matched: DROBIŃSKI Leszek (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    269,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP5-V2-M-EPEE-2025-2026'),
    2,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    181,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP5-V2-M-EPEE-2025-2026'),
    3,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP5-V2-M-EPEE-2025-2026'),
    4,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    247,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP5-V2-M-EPEE-2025-2026'),
    6,
    'WASIOŁKA Sebastian'
); -- matched: WASIOŁKA Sebastian (score=100)
-- Compute scores for PP5-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PP5-V2-M-EPEE-2025-2026')
);

-- ---- MPW: Mistrzostwa Polski Weteranów — Szpada M (PABIANICE) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
VALUES (
    'MPW-2025-2026',
    'Mistrzostwa Polski Weteranów — Szpada M',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
);
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'MPW-2025-2026'),
    'MPW-V2-M-EPEE-2025-2026',
    'Mistrzostwa Polski Weteranów — Szpada M',
    'MPW',
    'EPEE', 'M', 'V2',
    '2025-06-07', 6, 'https://www.fencingtimelive.com/events/results/8F6BDF11C6344222A0DCEBCA8D22EFA7',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    266,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2025-2026'),
    1,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    96,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2025-2026'),
    2,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100)
-- UNMATCHED (<80): 'WOJTAS Bogusław' place=3
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    269,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2025-2026'),
    4,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    236,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2025-2026'),
    5,
    'TRACZ Jerzy'
); -- matched: TRACZ Jerzy (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2025-2026'),
    6,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    247,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2025-2026'),
    8,
    'WASIOŁKA Sebastian'
); -- matched: WASIOŁKA Sebastian (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2025-2026'),
    9,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
-- Compute scores for MPW-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2025-2026')
);

-- ---- PEW1: EVF Grand Prix 1 — Budapeszt (BUDAPEST CUP 2025.09.20) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
VALUES (
    'PEW1-2025-2026',
    'EVF Grand Prix 1 — Budapeszt',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
);
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
    NULL, 57, 'httPS://www.fencingtimelive.com/events/results/download/F335344201F74762AED57ADC339F65EF',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-EPEE-2025-2026'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100)
-- UNMATCHED (<80): 'GOETZ Gregory' place=2
-- UNMATCHED (<80): 'ASHRAFI Ehsan' place=3
-- UNMATCHED (<80): 'PÖNISCH Thomas' place=4
-- UNMATCHED (<80): 'LYONS Michael James' place=5
-- UNMATCHED (<80): 'HIRNER Wolfgang' place=6
-- UNMATCHED (<80): 'SCHATTENFROH Sebastian Dr.' place=7
-- UNMATCHED (<80): 'STRAKA Tomas' place=8
-- UNMATCHED (<80): 'BERGER Matthias' place=9
-- UNMATCHED (<80): 'DEGAUQUE Gilles' place=10
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    212,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-EPEE-2025-2026'),
    11,
    'SOKOL Vratislav'
); -- matched: SOKOL Vratislav (score=100)
-- UNMATCHED (<80): 'HAYEK Günter' place=12
-- UNMATCHED (<80): 'PILHÁL Zsolt' place=13
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-EPEE-2025-2026'),
    14,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
-- UNMATCHED (<80): 'GOETTMANN Jean-Julien' place=15
-- UNMATCHED (<80): 'KÁMÁNY Roland' place=16
-- UNMATCHED (<80): 'KÁLLAI Ákos' place=17
-- UNMATCHED (<80): 'GACSAL Károly' place=18
-- UNMATCHED (<80): 'FEZARD Julien' place=19
-- UNMATCHED (<80): 'KOEMETS Sven' place=20
-- UNMATCHED (<80): 'CICOIRA Mario' place=21
-- UNMATCHED (<80): 'KOUTSOUFLAKIS Stamatios' place=22
-- UNMATCHED (<80): 'RODARY Emmanuel' place=23
-- UNMATCHED (<80): 'KENESEI János' place=24
-- UNMATCHED (<80): 'LEE Ambrose' place=25
-- UNMATCHED (<80): 'GYÖRGY Attila' place=26
-- UNMATCHED (<80): 'ROTA Carlo' place=27
-- UNMATCHED (<80): 'SZAKMÁRY Sándor' place=28
-- UNMATCHED (<80): 'LESNE Ludovic' place=29
-- UNMATCHED (<80): 'DR VITÉZY Péter László' place=30
-- UNMATCHED (<80): 'AUTZEN Olaf' place=31
-- UNMATCHED (<80): 'BERMAN Robert' place=32
-- UNMATCHED (<80): 'MÁTYÁS Pál' place=33
-- UNMATCHED (<80): 'FERKE Norbert' place=34
-- UNMATCHED (<80): 'TULUMELLO Carmelo' place=35
-- UNMATCHED (<80): 'PULEGA Roberto' place=36
-- UNMATCHED (<80): 'DEÁK István' place=37
-- UNMATCHED (<80): 'MAGHON Hans' place=38
-- UNMATCHED (<80): 'VICHI Tommaso' place=39
-- UNMATCHED (<80): 'ÓCSAI János' place=40
-- UNMATCHED (<80): 'ACIKEL Ugur' place=41
-- UNMATCHED (<80): 'FÁBIÁN Gábor' place=42
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-EPEE-2025-2026'),
    43,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100)
-- UNMATCHED (<80): 'ERTÜN Müjdat' place=44
-- UNMATCHED (<80): 'BALLA Ádám' place=45
-- UNMATCHED (<80): 'MESTER György' place=46
-- UNMATCHED (<80): 'STUDENY Frantisek' place=47
-- UNMATCHED (<80): 'GERTSMAN Alexandr' place=48
-- UNMATCHED (<80): 'GOLD Oleg' place=49
-- UNMATCHED (<80): 'MÜLLER Ferenc' place=50
-- UNMATCHED (<80): 'SZABÓ Péter' place=51
-- UNMATCHED (<80): 'RUSIN Serghei' place=52
-- UNMATCHED (<80): 'MAGLIOZZI Roberto' place=53
-- UNMATCHED (<80): 'NYÉKI Zsolt' place=54
-- UNMATCHED (<80): 'CSISZÁR Zoltán' place=55
-- UNMATCHED (<80): 'SÓS Csaba' place=56
-- UNMATCHED (<80): 'VARGA Gergely' place=57
-- Compute scores for PEW1-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-EPEE-2025-2026')
);

-- ---- PEW2: EVF Grand Prix 2 — Madryt (MADRID _x000D_) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
VALUES (
    'PEW2-2025-2026',
    'EVF Grand Prix 2 — Madryt',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
);
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
    '2025-11-02', 33, 'httPS://www.fencingtimelive.com/events/results/download/B62D97116A9A459796E0C76A590415A3',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-EPEE-2025-2026'),
    1,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
-- UNMATCHED (<80): 'ASHRAFI' place=2
-- UNMATCHED (<80): 'LAUGA' place=3
-- UNMATCHED (<80): 'LEAHEY' place=4
-- UNMATCHED (<80): 'BERGER' place=5
-- UNMATCHED (<80): 'GARCIA CALDERON' place=6
-- UNMATCHED (<80): 'AUTZEN' place=7
-- UNMATCHED (<80): 'DE BURGH' place=8
-- UNMATCHED (<80): 'GOETTMANN' place=9
-- UNMATCHED (<80): 'PULEGA' place=10
-- UNMATCHED (<80): 'MOYA FERNÁNDEZ' place=11
-- UNMATCHED (<80): 'ALCÁZAR ROLDÁN' place=12
-- UNMATCHED (<80): 'DE BERNARDI' place=13
-- UNMATCHED (<80): 'SWENNING' place=14
-- UNMATCHED (<80): 'ZONNO' place=15
-- UNMATCHED (<80): 'NYÉKI' place=16
-- UNMATCHED (<80): 'JANET' place=17
-- UNMATCHED (<80): 'GARCIA FERNANDEZ' place=18
-- UNMATCHED (<80): 'ERTÜN' place=19
-- UNMATCHED (<80): 'AÇIKEL' place=20
-- UNMATCHED (<80): 'GÓMEZ PAZ' place=21
-- UNMATCHED (<80): 'POMELL' place=22
-- UNMATCHED (<80): 'FERNANDEZ RAMOS' place=23
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-EPEE-2025-2026'),
    24,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100)
-- UNMATCHED (<80): 'VARGA' place=25
-- UNMATCHED (<80): 'KAMANY' place=26
-- UNMATCHED (<80): 'DOMINGUEZ' place=27
-- UNMATCHED (<80): 'BERNEIS' place=28
-- UNMATCHED (<80): 'GONZÁLEZ DÍAZ' place=29
-- UNMATCHED (<80): 'RODRÍGUEZ' place=30
-- UNMATCHED (<80): 'MCQUEEN' place=31
-- UNMATCHED (<80): 'GALÁN ROCILLO' place=32
-- UNMATCHED (<80): 'SALCEDO PLAZA' place=33
-- Compute scores for PEW2-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-EPEE-2025-2026')
);

-- ---- PEW3: EVF Grand Prix 3 — Guildford (Guildford) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
VALUES (
    'PEW3-2025-2026',
    'EVF Grand Prix 3 — Guildford',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
);
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW3-2025-2026'),
    'PEW3-V2-M-EPEE-2025-2026',
    'EVF Grand Prix 3 — Guildford',
    'PEW',
    'EPEE', 'M', 'V2',
    '2025-01-04', 53, 'https://www.fencingtimelive.com/events/results/EEC7379682834E588E5B267447C7266A',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2025-2026'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    95,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2025-2026'),
    22,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2025-2026'),
    39,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2025-2026'),
    56,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
-- Compute scores for PEW3-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2025-2026')
);

-- ---- PEW4: EVF Grand Prix 4 — Terni (Terni) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
VALUES (
    'PEW4-2025-2026',
    'EVF Grand Prix 4 — Terni',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
);
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW4-2025-2026'),
    'PEW4-V2-M-EPEE-2025-2026',
    'EVF Grand Prix 4 — Terni',
    'PEW',
    'EPEE', 'M', 'V2',
    '2025-02-01', 64, 'https://www.4fence.it/FIS/Risultati/2025-02-02-01_Terni_(TR)_-_4_Prova_Naz.le_Master_-_EVF_Circuit/index.php?a=SP&s=M&c=7&f=clafinale',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-EPEE-2025-2026'),
    2,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-EPEE-2025-2026'),
    31,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-EPEE-2025-2026'),
    66,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
-- Compute scores for PEW4-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-EPEE-2025-2026')
);

-- ---- PEW5: EVF Grand Prix 5 — Sztokholm (Stockholm (SWE)) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
VALUES (
    'PEW5-2025-2026',
    'EVF Grand Prix 5 — Sztokholm',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
);
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW5-2025-2026'),
    'PEW5-V2-M-EPEE-2025-2026',
    'EVF Grand Prix 5 — Sztokholm',
    'PEW',
    'EPEE', 'M', 'V2',
    '2025-03-15', 31, 'https://fencing.ophardt.online/en/search/results/30279',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V2-M-EPEE-2025-2026'),
    22,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V2-M-EPEE-2025-2026'),
    34,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
-- Compute scores for PEW5-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V2-M-EPEE-2025-2026')
);

-- ---- PEW6: EVF Grand Prix 6 — Warszawa (WARSZAWA) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
VALUES (
    'PEW6-2025-2026',
    'EVF Grand Prix 6 — Warszawa',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
);
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW6-2025-2026'),
    'PEW6-V2-M-EPEE-2025-2026',
    'EVF Grand Prix 6 — Warszawa',
    'PEW',
    'EPEE', 'M', 'V2',
    '2025-03-29', 45, 'https://www.fencingtimelive.com/events/results/1DAD5541330547AC9204125523A0C1A9',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
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
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
    9,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    96,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
    10,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100)
-- UNMATCHED (<80): 'TULUMELLO Carmelo' place=11
-- UNMATCHED (<80): 'GRAVES SMITH Geoffrey' place=12
-- UNMATCHED (<80): 'LEAHEY John' place=13
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    86,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
    14,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100)
-- UNMATCHED (<80): 'BABKA Taras' place=15
-- UNMATCHED (<80): 'LE DEVEHAT Yannick' place=16
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    269,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
    17,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100)
-- UNMATCHED (<80): 'LEE Ambrose' place=18
-- UNMATCHED (<80): 'RODARY Emmanuel' place=19
-- UNMATCHED (<80): 'ÓCSAI János' place=20
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    236,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
    21,
    'TRACZ Jerzy'
); -- matched: TRACZ Jerzy (score=100)
-- UNMATCHED (<80): 'BENITAH Eliahu' place=22
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    169,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
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
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
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
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
    35,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    27,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
    36,
    'CANIARD Herve'
); -- matched: CANIARD Henry (score=85)
-- UNMATCHED (<80): 'TRIMMEL Johannes' place=37
-- UNMATCHED (<80): 'GOLD Oleg' place=38
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
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
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
    44,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100)
-- UNMATCHED (<80): 'BISKUPSKI Marek' place=45
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
    48,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    247,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
    49,
    'WASIOŁKA Sebastian'
); -- matched: WASIOŁKA Sebastian (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    110,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026'),
    50,
    'KOBIERSKI Krzysztof'
); -- matched: KOBIERSKI Krzysztof (score=100)
-- Compute scores for PEW6-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2025-2026')
);

-- SKIP PEW7 (EVF Grand Prix 7 — Chania): N=None — tournament skipped

-- ---- PS: Puchar Świata Weteranów — Paryż (Paryż) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
VALUES (
    'PS-2025-2026',
    'Puchar Świata Weteranów — Paryż',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
);
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PS-2025-2026'),
    'PS-V2-M-EPEE-2025-2026',
    'Puchar Świata Weteranów — Paryż',
    'PEW',
    'EPEE', 'M', 'V2',
    '2025-07-05', 75, 'https://engarde-service.com/competition/fencingaddict/crit25/ehv2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PS-V2-M-EPEE-2025-2026'),
    41,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PS-V2-M-EPEE-2025-2026'),
    77,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
-- Compute scores for PS-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PS-V2-M-EPEE-2025-2026')
);

-- ---- IMEW: Indywidualne Mistrzostwa Europy Weteranów — Płowdiw (Płowdiw) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
VALUES (
    'IMEW-2025-2026',
    'Indywidualne Mistrzostwa Europy Weteranów — Płowdiw',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
);
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'IMEW-2025-2026'),
    'IMEW-V2-M-EPEE-2025-2026',
    'Indywidualne Mistrzostwa Europy Weteranów — Płowdiw',
    'MEW',
    'EPEE', 'M', 'V2',
    '2025-05-29', 110, 'https://www.fencingtimelive.com/events/results/F335344201F74762AED57ADC339F65EF',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    266,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2025-2026'),
    6,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2025-2026'),
    19,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2025-2026'),
    78,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2025-2026'),
    114,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
-- Compute scores for IMEW-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2025-2026')
);

-- ---- IMSW: Indywidualne Mistrzostwa Świata Weteranów (2025 Veteran World Championships) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
VALUES (
    'IMSW-2025-2026',
    'Indywidualne Mistrzostwa Świata Weteranów',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
);
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'IMSW-2025-2026'),
    'IMSW-V2-M-EPEE-2025-2026',
    'Indywidualne Mistrzostwa Świata Weteranów',
    'MSW',
    'EPEE', 'M', 'V2',
    '2025-11-13', 76, 'https://www.fencingtimelive.com/events/results/download/12C3BCD029104BA19426095D43A2233C',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMSW-V2-M-EPEE-2025-2026'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100)
-- UNMATCHED (<80): 'COVANI Carlos Enrique' place=2
-- UNMATCHED (<80): 'TRUETZSCHLER Alexander' place=3
-- UNMATCHED (<80): 'TEPEDELENLIOGLU Mehmet' place=4
-- UNMATCHED (<80): 'FEZARD Julien' place=5
-- UNMATCHED (<80): 'SCHATTENFROH Sebastian' place=6
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    266,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMSW-V2-M-EPEE-2025-2026'),
    7,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100)
-- UNMATCHED (<80): 'MARCHET Alexander' place=8
-- UNMATCHED (<80): 'ELLISON Alexander' place=9
-- UNMATCHED (<80): 'VINCENZI Gabriele' place=10
-- UNMATCHED (<80): 'DIMOV Dmitriy' place=11
-- UNMATCHED (<80): 'PRIHODKO Andrew' place=12
-- UNMATCHED (<80): 'WACQUEZ Francois' place=13
-- UNMATCHED (<80): 'KATASHIMA Akinori' place=14
-- UNMATCHED (<80): 'STRAKA Tomas' place=15
-- UNMATCHED (<80): 'ARKHIPOV Alexey' place=16
-- UNMATCHED (<80): 'LICHTEN Keith H.' place=17
-- UNMATCHED (<80): 'OHANESSIAN Sarkis' place=18
-- UNMATCHED (<80): 'SALAMANDRA Lev' place=19
-- UNMATCHED (<80): 'FERGUSON Darren' place=20
-- UNMATCHED (<80): 'LESNE Ludovic' place=21
-- UNMATCHED (<80): 'HESS Alexander' place=22
-- UNMATCHED (<80): 'ROTA Carlo' place=23
-- UNMATCHED (<80): 'ALITISZ Valentin Andres' place=24
-- UNMATCHED (<80): 'GRAVES-SMITH Geoff' place=25
-- UNMATCHED (<80): 'PIRANI Claudio' place=26
-- UNMATCHED (<80): 'AL-SUBAYEE WALEED' place=27
-- UNMATCHED (<80): 'CRANOR Erich L.' place=28
-- UNMATCHED (<80): 'LE DEVEHAT Yannick' place=29
-- UNMATCHED (<80): 'RIASKIN Andrei' place=30
-- UNMATCHED (<80): 'MIKHEIKIN Aleksei' place=31
-- UNMATCHED (<80): 'KUWAHATA Takashi' place=32
-- UNMATCHED (<80): 'ALLEN Gregory' place=33
-- UNMATCHED (<80): 'LAUGA Eric' place=34
-- UNMATCHED (<80): 'COLLING Emile' place=35
-- UNMATCHED (<80): 'DOI TAKEO' place=36
-- UNMATCHED (<80): 'GOETTMANN Jean-Julien' place=37
-- UNMATCHED (<80): 'TANTIPIRIYAPONGS Nipon' place=38
-- UNMATCHED (<80): 'SZAKMARY Sandor' place=39
-- UNMATCHED (<80): 'SALAMANDRA Paolo' place=40
-- UNMATCHED (<80): 'PENKIN Andrey' place=41
-- UNMATCHED (<80): 'LYONS Michael James' place=42
-- UNMATCHED (<80): 'VITEZY Peter Laszlo' place=43
-- UNMATCHED (<80): 'NOMURA Masahito' place=44
-- UNMATCHED (<80): 'GATES Darcy' place=45
-- UNMATCHED (<80): 'KHRIAKOV Dmitrii' place=46
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    269,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMSW-V2-M-EPEE-2025-2026'),
    47,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100)
-- UNMATCHED (<80): 'MACDONALD Leslie' place=48
-- UNMATCHED (<80): 'FENG Qiong' place=49
-- UNMATCHED (<80): 'GRABHER Gernot' place=50
-- UNMATCHED (<80): 'BERNERON Guillaume' place=51
-- UNMATCHED (<80): 'BATTAGGI Augusto' place=52
-- UNMATCHED (<80): 'SAKHRANI Naresh' place=53
-- UNMATCHED (<80): 'ABASSI Wajdi' place=54
-- UNMATCHED (<80): 'POUTSENKO Serguei' place=55
-- UNMATCHED (<80): 'KHALID ABDULRAHMAN' place=56
-- UNMATCHED (<80): 'LAHTI Taneli' place=57
-- UNMATCHED (<80): 'SANTOS Felipe' place=58
-- UNMATCHED (<80): 'WU Bing Chi Patrick' place=59
-- UNMATCHED (<80): 'KAMANY Roland' place=60
-- UNMATCHED (<80): 'ALATAWI KHALIFA' place=61
-- UNMATCHED (<80): 'PALTINISEANU Sorin' place=62
-- UNMATCHED (<80): 'TSANG Hin Kwong' place=63
-- UNMATCHED (<80): 'CHAN Wai Ching Jason' place=64
-- UNMATCHED (<80): 'MACKLEY Jay' place=65
-- UNMATCHED (<80): 'ALSABBAN Ahmed' place=66
-- UNMATCHED (<80): 'STUDENY Frantisek' place=67
-- UNMATCHED (<80): 'ALMUTAIR Tariq' place=68
-- UNMATCHED (<80): 'PATEL Manish' place=69
-- UNMATCHED (<80): 'HOYER Martin' place=70
-- UNMATCHED (<80): 'ALI SALMAN' place=71
-- UNMATCHED (<80): 'ASAAD Abdulkareem' place=72
-- UNMATCHED (<80): 'ABED Hazem' place=73
-- UNMATCHED (<80): 'ESPARZA Mario' place=74
-- UNMATCHED (<80): 'MOHAMMEDAWI MOHAMMED' place=75
-- UNMATCHED (<80): 'AL-DARRAJI RAHEEM' place=76
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMSW-V2-M-EPEE-2025-2026'),
    79,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
-- Compute scores for IMSW-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMSW-V2-M-EPEE-2025-2026')
);

-- Summary
-- Total results matched:   91
-- Total results unmatched: 197
