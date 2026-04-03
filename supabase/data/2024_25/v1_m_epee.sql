-- =========================================================================
-- Season 2024-2025 — V1 M EPEE — generated from SZPADA-1-2024-2025.xlsx
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
    'PPW1-V1-M-EPEE-2024-2025',
    'I Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V1',
    '2024-09-28', 13, 'https://www.fencingtimelive.com/events/results/E9A1887974E8446391D4FBE7660BC331',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    78,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2024-2025'),
    1,
    'GROMADA Roland'
); -- matched: GROMADA Roland (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    17,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2024-2025'),
    2,
    'BOBUSIA Jarosław'
); -- matched: BOBUSIA Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    208,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2024-2025'),
    3,
    'SĘKOWSKI Maciej'
); -- matched: SĘKOWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2024-2025'),
    4,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    216,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2024-2025'),
    5,
    'STOCKI Piotr'
); -- matched: STOCKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    138,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2024-2025'),
    6,
    'KULKA Dawid'
); -- matched: KULKA Dawid (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    36,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2024-2025'),
    7,
    'ĆWIORO Tomasz'
); -- matched: ĆWIORO Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    40,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2024-2025'),
    8,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    34,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2024-2025'),
    9,
    'CZAJKOWSKI Marcin'
); -- matched: CZAJKOWSKI Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    145,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2024-2025'),
    10,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    181,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2024-2025'),
    11,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    184,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2024-2025'),
    12,
    'POKRYWA Bartosz'
); -- matched: POKRYWA Bartosz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    115,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2024-2025'),
    13,
    'KOŃCZYŃSKI Adam'
); -- matched: KOŃCZYŃSKI Adam (score=100.0)
-- Compute scores for PP1-V1-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2024-2025')
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
    'PPW2-V1-M-EPEE-2024-2025',
    'II Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V1',
    '2024-10-26', 12, 'https://www.fencingtimelive.com/events/results/60CD7E924CA84BE0961D4402021B720A',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    78,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2024-2025'),
    1,
    'GROMADA Roland'
); -- matched: GROMADA Roland (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    34,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2024-2025'),
    2,
    'CZAJKOWSKI Marcin'
); -- matched: CZAJKOWSKI Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    17,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2024-2025'),
    3,
    'BOBUSIA Jarosław'
); -- matched: BOBUSIA Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2024-2025'),
    4,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    208,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2024-2025'),
    5,
    'SĘKOWSKI Maciej'
); -- matched: SĘKOWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    76,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2024-2025'),
    6,
    'GRIPAS Artiom'
); -- matched: GRIPAS Artiom (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    216,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2024-2025'),
    7,
    'STOCKI Piotr'
); -- matched: STOCKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    40,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2024-2025'),
    8,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    110,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2024-2025'),
    9,
    'KOBIERSKI Krzysztof'
); -- matched: KOBIERSKI Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    15,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2024-2025'),
    8,
    'BETLEJA Artur'
); -- matched: BETLEJA Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    36,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2024-2025'),
    11,
    'ĆWIORO Tomasz'
); -- matched: ĆWIORO Tomasz (score=100.0)
-- UNMATCHED (score<80): 'BOROWIEC Maciej' place=12
-- Compute scores for PP2-V1-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2024-2025')
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
    'PPW3-V1-M-EPEE-2024-2025',
    'III Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V1',
    '2024-11-30', 14, 'https://www.fencingtimelive.com/events/results/7E15D4D1024747039870AA36B95DB32F',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    17,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2024-2025'),
    1,
    'BOBUSIA Jarosław'
); -- matched: BOBUSIA Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    208,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2024-2025'),
    2,
    'SĘKOWSKI Maciej'
); -- matched: SĘKOWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    216,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2024-2025'),
    3,
    'STOCKI Piotr'
); -- matched: STOCKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    76,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2024-2025'),
    4,
    'GRIPAS Artiom'
); -- matched: GRIPAS Artiom (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    40,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2024-2025'),
    5,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    265,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2024-2025'),
    6,
    'ZAWROTNIAK Radosław'
); -- matched: ZAWROTNIAK Przemysław (score=80.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    78,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2024-2025'),
    7,
    'GROMADA Roland'
); -- matched: GROMADA Roland (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2024-2025'),
    8,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2024-2025'),
    9,
    'KORNAŚ Jarosław'
); -- matched: KORNAŚ Jarosław (score=100.0)
-- UNMATCHED (score<80): 'ALCSER Norbert' place=10
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    36,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2024-2025'),
    11,
    'ĆWIORO Tomasz'
); -- matched: ĆWIORO Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    145,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2024-2025'),
    12,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    110,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2024-2025'),
    13,
    'KOBIERSKI Krzysztof'
); -- matched: KOBIERSKI Krzysztof (score=100.0)
-- UNMATCHED (score<80): 'LEVY EMMANUEL' place=14
-- Compute scores for PP3-V1-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2024-2025')
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
    'PPW4-V1-M-EPEE-2024-2025',
    'IV Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V1',
    '2025-02-22', 8, 'https://www.fencingtimelive.com/events/results/052B74D636554BC9A70CDED4E1678706',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    208,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2024-2025'),
    1,
    'SĘKOWSKI Maciej'
); -- matched: SĘKOWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    78,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2024-2025'),
    2,
    'GROMADA Roland'
); -- matched: GROMADA Roland (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    17,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2024-2025'),
    3,
    'BOBUSIA Jarosław'
); -- matched: BOBUSIA Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2024-2025'),
    4,
    'KORNAŚ Jarosław'
); -- matched: KORNAŚ Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2024-2025'),
    5,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    110,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2024-2025'),
    6,
    'KOBIERSKI Krzysztof'
); -- matched: KOBIERSKI Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    184,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2024-2025'),
    7,
    'POKRYWA Bartosz'
); -- matched: POKRYWA Bartosz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    145,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2024-2025'),
    8,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
-- Compute scores for PP4-V1-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2024-2025')
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
    'PPW5-V1-M-EPEE-2024-2025',
    'V Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V1',
    '2025-04-26', 6, 'https://www.fencingtimelive.com/events/results/577C8999CAD84E11AA8F65186E61F86A',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    208,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V1-M-EPEE-2024-2025'),
    1,
    'SĘKOWSKI Maciej'
); -- matched: SĘKOWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    247,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V1-M-EPEE-2024-2025'),
    2,
    'WASIOŁKA Sebastian'
); -- matched: WASIOŁKA Sebastian (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    78,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V1-M-EPEE-2024-2025'),
    3,
    'GROMADA Roland'
); -- matched: GROMADA Roland (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    40,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V1-M-EPEE-2024-2025'),
    4,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    184,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V1-M-EPEE-2024-2025'),
    5,
    'POKRYWA Bartosz'
); -- matched: POKRYWA Bartosz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    145,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V1-M-EPEE-2024-2025'),
    6,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
-- Compute scores for PP5-V1-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW5-V1-M-EPEE-2024-2025')
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
    'MPW-V1-M-EPEE-2024-2025',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'EPEE', 'M', 'V1',
    '2025-06-07', 11, 'https://www.fencingtimelive.com/events/results/8F6BDF11C6344222A0DCEBCA8D22EFA7',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    208,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2024-2025'),
    1,
    'SĘKOWSKI Maciej'
); -- matched: SĘKOWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    247,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2024-2025'),
    2,
    'WASIOŁKA Sebastian'
); -- matched: WASIOŁKA Sebastian (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    78,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2024-2025'),
    3,
    'GROMADA Roland'
); -- matched: GROMADA Roland (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    17,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2024-2025'),
    4,
    'BOBUSIA Jarosław'
); -- matched: BOBUSIA Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2024-2025'),
    5,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    145,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2024-2025'),
    6,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    267,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2024-2025'),
    7,
    'ZIEMECKI Grzegorz'
); -- matched: ZIEMECKI Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    40,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2024-2025'),
    8,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    85,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2024-2025'),
    9,
    'HAŁOŃ Bartłomiej'
); -- matched: HAŁOŃ Bartłomiej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    36,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2024-2025'),
    10,
    'ĆWIORO Tomasz'
); -- matched: ĆWIORO Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    13,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2024-2025'),
    11,
    'BEDNARZ Przemysław'
); -- matched: BEDNARZ Przemysław (score=100.0)
-- Compute scores for MPW-V1-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2024-2025')
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
    'PEW1-V1-M-EPEE-2024-2025',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'EPEE', 'M', 'V1',
    '2024-09-21', 41, 'https://engarde-service.com/app.php?id=4207L1',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    17,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-M-EPEE-2024-2025'),
    2,
    'BOBUSIA Jarosław'
); -- matched: BOBUSIA Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-M-EPEE-2024-2025'),
    3,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    76,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-M-EPEE-2024-2025'),
    12,
    'GRIPAS Artiom'
); -- matched: GRIPAS Artiom (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    216,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-M-EPEE-2024-2025'),
    14,
    'STOCKI Piotr'
); -- matched: STOCKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    184,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-M-EPEE-2024-2025'),
    20,
    'POKRYWA Bartosz'
); -- matched: POKRYWA Bartosz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    145,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-M-EPEE-2024-2025'),
    35,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
-- Compute scores for PEW1-V1-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-M-EPEE-2024-2025')
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
    'PEW2-V1-M-EPEE-2024-2025',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'EPEE', 'M', 'V1',
    '2024-11-16', 31, 'https://engarde-service.com/competition/aeve_esgrima/evf_madrid_2024/em-1',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-M-EPEE-2024-2025'),
    7,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    184,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-M-EPEE-2024-2025'),
    31,
    'POKRYWA Bartosz'
); -- matched: POKRYWA Bartosz (score=100.0)
-- Compute scores for PEW2-V1-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-M-EPEE-2024-2025')
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
    'PEW3-V1-M-EPEE-2024-2025',
    'EVF Grand Prix 3',
    'PEW',
    'EPEE', 'M', 'V1',
    '2025-01-04', 22, 'https://www.fencingtimelive.com/events/results/64FF0E7E9F504D8EA3516C393CAF1708',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    17,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2024-2025'),
    3,
    'BOBUSIA Jarosław'
); -- matched: BOBUSIA Jarosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2024-2025'),
    3,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    16,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2024-2025'),
    6,
    'BOBUSIA DARIUSZ'
); -- matched: BOBUSIA Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    138,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2024-2025'),
    14,
    'KULKA Dawid'
); -- matched: KULKA Dawid (score=100.0)
-- Compute scores for PEW3-V1-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2024-2025')
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
    'PEW4-V1-M-EPEE-2024-2025',
    'EVF Grand Prix 4',
    'PEW',
    'EPEE', 'M', 'V1',
    '2025-02-01', 50, 'https://www.4fence.it/FIS/Risultati/2025-02-02-01_Terni_(TR)_-_4_Prova_Naz.le_Master_-_EVF_Circuit/index.php?a=SP&s=M&c=6&f=clafinale',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-EPEE-2024-2025'),
    2,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    78,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-EPEE-2024-2025'),
    7,
    'GROMADA Roland'
); -- matched: GROMADA Roland (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    76,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-EPEE-2024-2025'),
    8,
    'GRIPAS Artiom'
); -- matched: GRIPAS Artiom (score=100.0)
-- Compute scores for PEW4-V1-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-EPEE-2024-2025')
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
    'PEW5-V1-M-EPEE-2024-2025',
    'EVF Grand Prix 5',
    'PEW',
    'EPEE', 'M', 'V1',
    '2025-03-15', 20, 'https://fencing.ophardt.online/en/search/results/30279',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    76,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V1-M-EPEE-2024-2025'),
    8,
    'GRIPAS Artiom'
); -- matched: GRIPAS Artiom (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V1-M-EPEE-2024-2025'),
    11,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
-- Compute scores for PEW5-V1-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V1-M-EPEE-2024-2025')
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
    'PEW6-V1-M-EPEE-2024-2025',
    'EVF Grand Prix 6',
    'PEW',
    'EPEE', 'M', 'V1',
    '2025-03-29', 29, 'https://www.fencingtimelive.com/events/results/5C033AF560674DEC9BC99F55EC588567',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    208,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2024-2025'),
    1,
    'SĘKOWSKI Maciej'
); -- matched: SĘKOWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    216,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2024-2025'),
    2,
    'STOCKI Piotr'
); -- matched: STOCKI Piotr (score=100.0)
-- UNMATCHED (score<80): 'PASZTOR Attila' place=3
-- UNMATCHED (score<80): 'PARTICS Peter' place=3
-- UNMATCHED (score<80): 'PEDONE Mattia' place=5
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2024-2025'),
    6,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    78,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2024-2025'),
    7,
    'GROMADA Roland'
); -- matched: GROMADA Roland (score=100.0)
-- UNMATCHED (score<80): 'KORONA Radoslaw' place=8
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    212,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2024-2025'),
    9,
    'SOKOL Vratislav'
); -- matched: SOKOL Vratislav (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    247,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2024-2025'),
    10,
    'WASIOŁKA Sebastian'
); -- matched: WASIOŁKA Sebastian (score=100.0)
-- UNMATCHED (score<80): 'MAXIMOV Boris' place=11
-- UNMATCHED (score<80): 'CARTER Rodney' place=12
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    17,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2024-2025'),
    13,
    'BOBUSIA Jarosław'
); -- matched: BOBUSIA Jarosław (score=100.0)
-- UNMATCHED (score<80): 'TOKOLA Teemu' place=14
-- UNMATCHED (score<80): 'PAPP György' place=15
-- UNMATCHED (score<80): 'MAKKOULIS Georgios' place=16
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    145,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2024-2025'),
    17,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
-- UNMATCHED (score<80): 'PLAZZERIANO Gabor' place=18
-- UNMATCHED (score<80): 'BERCHTEYN Leonid' place=19
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    15,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2024-2025'),
    20,
    'BETLEJA Artur'
); -- matched: BETLEJA Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    110,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2024-2025'),
    21,
    'KOBIERSKI Krzysztof'
); -- matched: KOBIERSKI Krzysztof (score=100.0)
-- UNMATCHED (score<80): 'GACSAL Karoly' place=22
-- UNMATCHED (score<80): 'RINCON Alberto' place=23
-- UNMATCHED (score<80): 'SCHMAUZER Juergen' place=24
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    40,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2024-2025'),
    25,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
-- UNMATCHED (score<80): 'WIEDEMANN Karsten' place=26
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    184,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2024-2025'),
    27,
    'POKRYWA Bartosz'
); -- matched: POKRYWA Bartosz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    68,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2024-2025'),
    28,
    'GOLA Maciej'
); -- matched: GOLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    141,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2024-2025'),
    29,
    'LELONEK Tomasz'
); -- matched: LELONEK Tomasz (score=100.0)
-- Compute scores for PEW6-V1-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2024-2025')
);

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): N=0 — tournament had no participants

-- ---- PS: Puchar Świata (Paryż) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PS-2024-2025',
    'Puchar Świata',
    'Paryż',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PS-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PS-2024-2025'),
    'PS-V1-M-EPEE-2024-2025',
    'Puchar Świata',
    'PSW',
    'EPEE', 'M', 'V1',
    '2025-07-05', 31, 'https://engarde-service.com/competition/fencingaddict/crit25/ehv1',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PS-V1-M-EPEE-2024-2025'),
    8,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
-- Compute scores for PS-V1-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PS-V1-M-EPEE-2024-2025')
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
    'IMEW-V1-M-EPEE-2024-2025',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'EPEE', 'M', 'V1',
    '2025-05-29', 68, 'https://www.fencingtimelive.com/events/results/F2FD5C1C2D4D4006B0C606F11FB721EB',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    117,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-EPEE-2024-2025'),
    3,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    208,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-EPEE-2024-2025'),
    17,
    'SĘKOWSKI Maciej'
); -- matched: SĘKOWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    40,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-EPEE-2024-2025'),
    28,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    205,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-EPEE-2024-2025'),
    164,
    'SAMSONOWICZ Maciej'
); -- matched: SAMSONOWICZ Maciej (score=100.0)
-- Compute scores for IMEW-V1-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-EPEE-2024-2025')
);

-- Summary
-- Total results matched:   97
-- Total results unmatched: 18
