-- =========================================================================
-- Season 2023-2024 — V1 M EPEE — generated from SZPADA-1-2023-2024.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- =========================================================================
-- Auto-created fencers (domestic unmatched — ADR-020)
-- =========================================================================
INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, bool_birth_year_estimated)
SELECT 'FRYDRYCKI', 'Mariusz', 1984, TRUE
WHERE NOT EXISTS (
    SELECT 1 FROM tbl_fencer WHERE txt_surname = 'FRYDRYCKI' AND txt_first_name = 'Mariusz'
);

-- ---- GP1: Grand Prix (runda 1) (PABIANICE) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'GP1-2023-2024',
    'Grand Prix (runda 1)',
    'PABIANICE',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'GP1-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'GP1-2023-2024'),
    'GP1-V1-M-EPEE-2023-2024',
    'Grand Prix (runda 1)',
    'PPW',
    'EPEE', 'M', 'V1',
    '2023-01-14', 7, 'https://www.fencingtimelive.com/events/results/2D5103B0307E4B318098472DF41C3E7C',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-EPEE-2023-2024'),
    1,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    273,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-EPEE-2023-2024'),
    2,
    'SĘKOWSKI Maciej'
); -- matched: SĘKOWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    18,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-EPEE-2023-2024'),
    3,
    'BETLEJ Daniel'
); -- matched: BETLEJ Daniel (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    43,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-EPEE-2023-2024'),
    4,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    312,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-EPEE-2023-2024'),
    5,
    'ZIEMECKI Grzegorz'
); -- matched: ZIEMECKI Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    118,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-EPEE-2023-2024'),
    6,
    'KOBIERSKI Krzysztof'
); -- matched: KOBIERSKI Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    200,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-EPEE-2023-2024'),
    7,
    'OWCZAREK Hubert'
); -- matched: OWCZAREK Hubert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    78,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-EPEE-2023-2024'),
    10,
    'GRIPAS Artiom'
); -- matched: GRIPAS Artiom (score=100.0)
-- Compute scores for GP1-V1-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-EPEE-2023-2024')
);

-- ---- GP2: Grand Prix (runda 2) (TORUŃ) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'GP2-2023-2024',
    'Grand Prix (runda 2)',
    'TORUŃ',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'GP2-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'GP2-2023-2024'),
    'GP2-V1-M-EPEE-2023-2024',
    'Grand Prix (runda 2)',
    'PPW',
    'EPEE', 'M', 'V1',
    '2023-04-03', 10, 'https://www.fencingtimelive.com/events/results/630DF24E491149189ED7BA39317822FA',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    273,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-EPEE-2023-2024'),
    1,
    'SĘKOWSKI Maciej'
); -- matched: SĘKOWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-EPEE-2023-2024'),
    2,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    40,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-EPEE-2023-2024'),
    3,
    'CZAJKOWSKI Marcin'
); -- matched: CZAJKOWSKI Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    43,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-EPEE-2023-2024'),
    4,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    207,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-EPEE-2023-2024'),
    5,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-EPEE-2023-2024'),
    6,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    126,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-EPEE-2023-2024'),
    7,
    'KORZH Valery'
); -- matched: KORZH Valery (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    118,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-EPEE-2023-2024'),
    8,
    'KOBIERSKI Krzysztof'
); -- matched: KOBIERSKI Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    164,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-EPEE-2023-2024'),
    9,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    156,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-EPEE-2023-2024'),
    10,
    'LELONEK Tomasz'
); -- matched: LELONEK Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    78,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-EPEE-2023-2024'),
    12,
    'GRIPAS Artiom'
); -- matched: GRIPAS Artiom (score=100.0)
-- Compute scores for GP2-V1-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-EPEE-2023-2024')
);

-- ---- GP3: Grand Prix (runda 3) (NIEPOŁOMICE) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'GP3-2023-2024',
    'Grand Prix (runda 3)',
    'NIEPOŁOMICE',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'GP3-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'GP3-2023-2024'),
    'GP3-V1-M-EPEE-2023-2024',
    'Grand Prix (runda 3)',
    'PPW',
    'EPEE', 'M', 'V1',
    '2023-06-17', 13, 'https://www.fencingtimelive.com/events/results/DEF62E66DAF54D2D88C0AAFBA9C136B5',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-EPEE-2023-2024'),
    1,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    104,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-EPEE-2023-2024'),
    2,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    242,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-EPEE-2023-2024'),
    3,
    'SIDOR Marek'
); -- matched: SIDOR Marek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    112,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-EPEE-2023-2024'),
    4,
    'KAZIK Martin'
); -- matched: KAZIK Martin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    246,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-EPEE-2023-2024'),
    5,
    'SOKOL Vratislav'
); -- matched: SOKOL Vratislav (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-EPEE-2023-2024'),
    6,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    40,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-EPEE-2023-2024'),
    7,
    'CZAJKOWSKI Marcin'
); -- matched: CZAJKOWSKI Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    43,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-EPEE-2023-2024'),
    8,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    164,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-EPEE-2023-2024'),
    9,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    156,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-EPEE-2023-2024'),
    10,
    'LELONEK Tomasz'
); -- matched: LELONEK Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    207,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-EPEE-2023-2024'),
    11,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    200,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-EPEE-2023-2024'),
    12,
    'OWCZAREK Hubert'
); -- matched: OWCZAREK Hubert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    118,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-EPEE-2023-2024'),
    13,
    'KOBIERSKI Krzysztof'
); -- matched: KOBIERSKI Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    78,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-EPEE-2023-2024'),
    16,
    'GRIPAS Artiom'
); -- matched: GRIPAS Artiom (score=100.0)
-- Compute scores for GP3-V1-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-EPEE-2023-2024')
);

-- ---- GP4: Grand Prix (runda 4) (OPOLE) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'GP4-2023-2024',
    'Grand Prix (runda 4)',
    'OPOLE',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'GP4-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'GP4-2023-2024'),
    'GP4-V1-M-EPEE-2023-2024',
    'Grand Prix (runda 4)',
    'PPW',
    'EPEE', 'M', 'V1',
    '2023-10-23', 7, 'https://www.fencingtimelive.com/events/results/BC806A0FB52C4E99A2ABDDC4AF4D6462',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    78,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V1-M-EPEE-2023-2024'),
    1,
    'GRIPAS Artiom'
); -- matched: GRIPAS Artiom (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    18,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V1-M-EPEE-2023-2024'),
    2,
    'BETLEJ Daniel'
); -- matched: BETLEJ Daniel (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    312,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V1-M-EPEE-2023-2024'),
    3,
    'ZIEMECKI Grzegorz'
); -- matched: ZIEMECKI Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    164,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V1-M-EPEE-2023-2024'),
    4,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    43,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V1-M-EPEE-2023-2024'),
    5,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    40,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V1-M-EPEE-2023-2024'),
    6,
    'CZAJKOWSKI Marcin'
); -- matched: CZAJKOWSKI Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    207,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V1-M-EPEE-2023-2024'),
    7,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
-- Compute scores for GP4-V1-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V1-M-EPEE-2023-2024')
);

-- ---- GP5: Grand Prix (runda 5) (GDAŃSK) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'GP5-2023-2024',
    'Grand Prix (runda 5)',
    'GDAŃSK',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'GP5-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'GP5-2023-2024'),
    'GP5-V1-M-EPEE-2023-2024',
    'Grand Prix (runda 5)',
    'PPW',
    'EPEE', 'M', 'V1',
    '2023-10-28', 6, 'https://www.fencingtimelive.com/events/results/313DA944AC3845A18ABA072E7A6E4F58',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    78,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V1-M-EPEE-2023-2024'),
    1,
    'GRIPAS Artiom'
); -- matched: GRIPAS Artiom (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    148,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V1-M-EPEE-2023-2024'),
    2,
    'KULKA Dawid'
); -- matched: KULKA Dawid (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V1-M-EPEE-2023-2024'),
    3,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    43,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V1-M-EPEE-2023-2024'),
    4,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    156,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V1-M-EPEE-2023-2024'),
    5,
    'LELONEK Tomasz'
); -- matched: LELONEK Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    164,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V1-M-EPEE-2023-2024'),
    6,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
-- Compute scores for GP5-V1-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V1-M-EPEE-2023-2024')
);

-- ---- GP6: Grand Prix (runda 6) (KRAKÓW) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'GP6-2023-2024',
    'Grand Prix (runda 6)',
    'KRAKÓW',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'GP6-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'GP6-2023-2024'),
    'GP6-V1-M-EPEE-2023-2024',
    'Grand Prix (runda 6)',
    'PPW',
    'EPEE', 'M', 'V1',
    '2023-11-18', 8, 'https://www.fencingtimelive.com/events/results/E7707595D2F34E87A1855B18DDBA1D32',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V1-M-EPEE-2023-2024'),
    1,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    118,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V1-M-EPEE-2023-2024'),
    2,
    'KOBIERSKI Krzysztof'
); -- matched: KOBIERSKI Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    43,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V1-M-EPEE-2023-2024'),
    3,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    312,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V1-M-EPEE-2023-2024'),
    4,
    'ZIEMECKI Grzegorz'
); -- matched: ZIEMECKI Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'FRYDRYCKI' AND txt_first_name = 'Mariusz'),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V1-M-EPEE-2023-2024'),
    5,
    'FRYDRYCKI Mariusz'
); -- auto-created domestic fencer
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    256,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V1-M-EPEE-2023-2024'),
    6,
    'STOLARIK Peter'
); -- matched: STOLARIK Peter (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    200,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V1-M-EPEE-2023-2024'),
    7,
    'OWCZAREK Hubert'
); -- matched: OWCZAREK Hubert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    164,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V1-M-EPEE-2023-2024'),
    8,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
-- Compute scores for GP6-V1-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V1-M-EPEE-2023-2024')
);

-- ---- GP7: Grand Prix (runda 7) (SPAŁA) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'GP7-2023-2024',
    'Grand Prix (runda 7)',
    'SPAŁA',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'GP7-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'GP7-2023-2024'),
    'GP7-V1-M-EPEE-2023-2024',
    'Grand Prix (runda 7)',
    'PPW',
    'EPEE', 'M', 'V1',
    '2024-01-27', 9, 'https://www.fencingtimelive.com/events/results/052B74D636554BC9A70CDED4E1678706',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    78,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-EPEE-2023-2024'),
    1,
    'GRIPAS Artiom'
); -- matched: GRIPAS Artiom (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-EPEE-2023-2024'),
    2,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    207,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-EPEE-2023-2024'),
    3,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    43,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-EPEE-2023-2024'),
    4,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    40,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-EPEE-2023-2024'),
    5,
    'CZAJKOWSKI Marcin'
); -- matched: CZAJKOWSKI Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    118,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-EPEE-2023-2024'),
    6,
    'KOBIERSKI Krzysztof'
); -- matched: KOBIERSKI Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    164,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-EPEE-2023-2024'),
    7,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    312,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-EPEE-2023-2024'),
    8,
    'ZIEMECKI Grzegorz'
); -- matched: ZIEMECKI Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    85,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-EPEE-2023-2024'),
    9,
    'GUZY Adrian'
); -- matched: GUZY Adrian (score=100.0)
-- Compute scores for GP7-V1-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-EPEE-2023-2024')
);

-- ---- GP8: Grand Prix (runda 8) (NIEPOŁOMICE) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'GP8-2023-2024',
    'Grand Prix (runda 8)',
    'NIEPOŁOMICE',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'GP8-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'GP8-2023-2024'),
    'GP8-V1-M-EPEE-2023-2024',
    'Grand Prix (runda 8)',
    'PPW',
    'EPEE', 'M', 'V1',
    '2024-06-22', 12, 'https://www.fencingtimelive.com/events/results/15D820D5BA9A442AA26E2B4B816F091F',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-EPEE-2023-2024'),
    1,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    78,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-EPEE-2023-2024'),
    2,
    'GRIPAS Artiom'
); -- matched: GRIPAS Artiom (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    255,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-EPEE-2023-2024'),
    3,
    'STOCKI Piotr'
); -- matched: STOCKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    148,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-EPEE-2023-2024'),
    4,
    'KULKA Dawid'
); -- matched: KULKA Dawid (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    207,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-EPEE-2023-2024'),
    5,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    43,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-EPEE-2023-2024'),
    6,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    164,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-EPEE-2023-2024'),
    7,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    118,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-EPEE-2023-2024'),
    8,
    'KOBIERSKI Krzysztof'
); -- matched: KOBIERSKI Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    242,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-EPEE-2023-2024'),
    9,
    'SIDOR Marek'
); -- matched: SIDOR Marek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    312,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-EPEE-2023-2024'),
    10,
    'ZIEMECKI Grzegorz'
); -- matched: ZIEMECKI Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    85,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-EPEE-2023-2024'),
    11,
    'GUZY Adrian'
); -- matched: GUZY Adrian (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    178,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-EPEE-2023-2024'),
    12,
    'MIKULICKI Arkadiusz'
); -- matched: MIKULICKI Arkadiusz (score=100.0)
-- Compute scores for GP8-V1-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-EPEE-2023-2024')
);

-- ---- MPW: Mistrzostwa Polski Weteranów (WARSZAWA) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'MPW-2023-2024',
    'Mistrzostwa Polski Weteranów',
    'WARSZAWA',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'MPW-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'MPW-2023-2024'),
    'MPW-V1-M-EPEE-2023-2024',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'EPEE', 'M', 'V1',
    '2024-03-02', 14, 'https://www.fencingtimelive.com/events/results/F3430EF7B4C74522B2B654191957DA6C',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    78,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2023-2024'),
    1,
    'GRIPAS Artiom'
); -- matched: GRIPAS Artiom (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    148,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2023-2024'),
    2,
    'KULKA Dawid'
); -- matched: KULKA Dawid (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2023-2024'),
    3,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    43,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2023-2024'),
    4,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    138,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2023-2024'),
    5,
    'KOZIEJOWSKI Sebastian'
); -- matched: KOZIEJOWSKI Sebastian (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    40,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2023-2024'),
    6,
    'CZAJKOWSKI Marcin'
); -- matched: CZAJKOWSKI Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    118,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2023-2024'),
    7,
    'KOBIERSKI Krzysztof'
); -- matched: KOBIERSKI Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    258,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2023-2024'),
    8,
    'STYŚ Jan'
); -- matched: STYŚ Jan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    98,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2023-2024'),
    9,
    'JADCZUK Wojciech'
); -- matched: JADCZUK Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    207,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2023-2024'),
    10,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    164,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2023-2024'),
    11,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    141,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2023-2024'),
    12,
    'KOŃCZYŃSKI Adam'
); -- matched: KOŃCZYŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    156,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2023-2024'),
    13,
    'LELONEK Tomasz'
); -- matched: LELONEK Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    178,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2023-2024'),
    14,
    'MIKULICKI Arkadiusz'
); -- matched: MIKULICKI Arkadiusz (score=100.0)
-- Compute scores for MPW-V1-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2023-2024')
);

-- ---- PEW1: EVF Grand Prix 1 — Budapeszt (Guildford) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW1-2023-2024',
    'EVF Grand Prix 1 — Budapeszt',
    'Guildford',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW1-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1-2023-2024'),
    'PEW1-V1-M-EPEE-2023-2024',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'EPEE', 'M', 'V1',
    '2023-01-07', 16, 'https://www.fencingtimelive.com/events/results/D32B710F3381435782C788CBABC675BE',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-M-EPEE-2023-2024'),
    8,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    148,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-M-EPEE-2023-2024'),
    15,
    'KULKA Dawid'
); -- matched: KULKA Dawid (score=100.0)
-- Compute scores for PEW1-V1-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-M-EPEE-2023-2024')
);

-- ---- PEW2: EVF Grand Prix 2 — Madryt (Kiev/Santander) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW2-2023-2024',
    'EVF Grand Prix 2 — Madryt',
    'Kiev/Santander',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW2-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW2-2023-2024'),
    'PEW2-V1-M-EPEE-2023-2024',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'EPEE', 'M', 'V1',
    '2022-02-25', 19, 'https://engarde-service.com/index.php?lang=en&Organisme=santanderfencing&Event=evf_epee_circuit_santander&Compe=m_epee_v1',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-M-EPEE-2023-2024'),
    1,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
-- Compute scores for PEW2-V1-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-M-EPEE-2023-2024')
);

-- ---- PEW3: EVF Grand Prix 3 (Gdańsk) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW3-2023-2024',
    'EVF Grand Prix 3',
    'Gdańsk',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW3-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW3-2023-2024'),
    'PEW3-V1-M-EPEE-2023-2024',
    'EVF Grand Prix 3',
    'PEW',
    'EPEE', 'M', 'V1',
    '2023-04-14', 19, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    273,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2023-2024'),
    2,
    'SĘKOWSKI Maciej'
); -- matched: SĘKOWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    148,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2023-2024'),
    3,
    'KULKA Dawid'
); -- matched: KULKA Dawid (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2023-2024'),
    5,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    40,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2023-2024'),
    7,
    'CZAJKOWSKI Marcin'
); -- matched: CZAJKOWSKI Marcin (score=100.0)
-- SKIPPED (international, no master data): 'GORCZYCA Marcin' place=9
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    43,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2023-2024'),
    11,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2023-2024'),
    12,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    238,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2023-2024'),
    13,
    'SAMSONOWICZ Maciej'
); -- matched: SAMSONOWICZ Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    200,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2023-2024'),
    14,
    'OWCZAREK Hubert'
); -- matched: OWCZAREK Hubert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    207,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2023-2024'),
    15,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    118,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2023-2024'),
    17,
    'KOBIERSKI Krzysztof'
); -- matched: KOBIERSKI Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    178,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2023-2024'),
    19,
    'MIKULICKI Arkadiusz'
); -- matched: MIKULICKI Arkadiusz (score=100.0)
-- Compute scores for PEW3-V1-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2023-2024')
);

-- ---- PEW4: EVF Grand Prix 4 (Budapest) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW4-2023-2024',
    'EVF Grand Prix 4',
    'Budapest',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW4-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW4-2023-2024'),
    'PEW4-V1-M-EPEE-2023-2024',
    'EVF Grand Prix 4',
    'PEW',
    'EPEE', 'M', 'V1',
    '2023-09-16', 30, 'https://engarde-service.com/?fbclid=IwAR1q8b20973WNdhLRYbl3vdP-rPK0cilvuHZi37KFNf-Dodoicffb3YOQeM',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-EPEE-2023-2024'),
    3,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
-- Compute scores for PEW4-V1-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-EPEE-2023-2024')
);

-- ---- PEW5: EVF Grand Prix 5 (Turku) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW5-2023-2024',
    'EVF Grand Prix 5',
    'Turku',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW5-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW5-2023-2024'),
    'PEW5-V1-M-EPEE-2023-2024',
    'EVF Grand Prix 5',
    'PEW',
    'EPEE', 'M', 'V1',
    '2023-09-24', 17, 'https://www.fencingtimelive.com/events/results/B287CD289AC54EFCB581067FAA32F555',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V1-M-EPEE-2023-2024'),
    2,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
-- Compute scores for PEW5-V1-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V1-M-EPEE-2023-2024')
);

-- ---- PEW6: EVF Grand Prix 6 (Madrid) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW6-2023-2024',
    'EVF Grand Prix 6',
    'Madrid',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW6-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW6-2023-2024'),
    'PEW6-V1-M-EPEE-2023-2024',
    'EVF Grand Prix 6',
    'PEW',
    'EPEE', 'M', 'V1',
    '2023-11-11', 28, 'https://engarde-service.com/competition/aeve_esgrima/evf_madrid_2023/em_1',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2023-2024'),
    1,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    148,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2023-2024'),
    3,
    'KULKA Dawid'
); -- matched: KULKA Dawid (score=100.0)
-- Compute scores for PEW6-V1-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2023-2024')
);

-- ---- PEW7: EVF Grand Prix 7 — Terni (Terni) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW7-2023-2024',
    'EVF Grand Prix 7 — Terni',
    'Terni',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW7-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW7-2023-2024'),
    'PEW7-V1-M-EPEE-2023-2024',
    'EVF Grand Prix 7 — Terni',
    'PEW',
    'EPEE', 'M', 'V1',
    '2023-12-16', 44, 'https://www.4fence.it/FIS/Risultati/2023-12-17-16_Terni_(TR)_-_3_Prova_Circuito_Naz.le_Master/index.php?a=SP&s=M&c=6&f=clafinale',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-M-EPEE-2023-2024'),
    3,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
-- Compute scores for PEW7-V1-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-M-EPEE-2023-2024')
);

-- ---- PEW8: EVF Grand Prix 8 — Guildford (Guildford) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW8-2023-2024',
    'EVF Grand Prix 8 — Guildford',
    'Guildford',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW8-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW8-2023-2024'),
    'PEW8-V1-M-EPEE-2023-2024',
    'EVF Grand Prix 8 — Guildford',
    'PEW',
    'EPEE', 'M', 'V1',
    '2024-01-06', 19, 'https://www.fencingtimelive.com/events/results/BB1E0BB24AEC48D7A0390EC60387A4B4',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V1-M-EPEE-2023-2024'),
    2,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    148,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V1-M-EPEE-2023-2024'),
    12,
    'KULKA Dawid'
); -- matched: KULKA Dawid (score=100.0)
-- SKIPPED (international, no master data): 'BOBUSIA DARIUSZ' place=14
-- Compute scores for PEW8-V1-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V1-M-EPEE-2023-2024')
);

-- ---- PEW9: EVF Grand Prix 9 — Sztokholm (Stockholm (SWE)) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW9-2023-2024',
    'EVF Grand Prix 9 — Sztokholm',
    'Stockholm (SWE)',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW9-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW9-2023-2024'),
    'PEW9-V1-M-EPEE-2023-2024',
    'EVF Grand Prix 9 — Sztokholm',
    'PEW',
    'EPEE', 'M', 'V1',
    '2024-02-24', 10, 'https://engarde-service.com/competition/sthlm/efv2024/mev1',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW9-V1-M-EPEE-2023-2024'),
    6,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    78,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW9-V1-M-EPEE-2023-2024'),
    8,
    'GRIPAS Artiom'
); -- matched: GRIPAS Artiom (score=100.0)
-- Compute scores for PEW9-V1-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW9-V1-M-EPEE-2023-2024')
);

-- SKIP PEW10 (EVF Grand Prix 10 — Graz): N=0 — tournament had no participants

-- ---- PEW11: EVF Grand Prix 11 — Gdańsk (Gdańsk (POL)) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW11-2023-2024',
    'EVF Grand Prix 11 — Gdańsk',
    'Gdańsk (POL)',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW11-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW11-2023-2024'),
    'PEW11-V1-M-EPEE-2023-2024',
    'EVF Grand Prix 11 — Gdańsk',
    'PEW',
    'EPEE', 'M', 'V1',
    '2024-04-06', 17, 'https://www.veteransfencing.eu/fencing/rankings/',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V1-M-EPEE-2023-2024'),
    2,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    43,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V1-M-EPEE-2023-2024'),
    8,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    207,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V1-M-EPEE-2023-2024'),
    10,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    118,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V1-M-EPEE-2023-2024'),
    11,
    'KOBIERSKI Krzysztof'
); -- matched: KOBIERSKI Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    148,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V1-M-EPEE-2023-2024'),
    12,
    'KULKA Dawid'
); -- matched: KULKA Dawid (score=100.0)
-- SKIPPED (international, no master data): 'GORCZYCA Marcin' place=13
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    156,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V1-M-EPEE-2023-2024'),
    14,
    'LELONEK Tomasz'
); -- matched: LELONEK Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    178,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V1-M-EPEE-2023-2024'),
    17,
    'MIKULICKI Arkadiusz'
); -- matched: MIKULICKI Arkadiusz (score=100.0)
-- Compute scores for PEW11-V1-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V1-M-EPEE-2023-2024')
);

-- ---- PEW12: EVF Grand Prix 12 — Ateny (Ateny (GRE)) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW12-2023-2024',
    'EVF Grand Prix 12 — Ateny',
    'Ateny (GRE)',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW12-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW12-2023-2024'),
    'PEW12-V1-M-EPEE-2023-2024',
    'EVF Grand Prix 12 — Ateny',
    'PEW',
    'EPEE', 'M', 'V1',
    '2024-04-27', 24, 'https://www.veteransfencing.eu/fencing/rankings/',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW12-V1-M-EPEE-2023-2024'),
    2,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
-- Compute scores for PEW12-V1-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW12-V1-M-EPEE-2023-2024')
);

-- ---- IMEW: Indywidualne Mistrzostwa Europy Weteranów (Thionville) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'IMEW-2023-2024',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'Thionville',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'IMEW-2023-2024');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'IMEW-2023-2024'),
    'IMEW-V1-M-EPEE-2023-2024',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'EPEE', 'M', 'V1',
    '2023-01-01', 138, 'https://engarde-service.com/competition/e3f/efcv/menepeev1',
    'SCORED'
);
-- SKIPPED (international, no master data): 'DELATTRE' place=1
-- SKIPPED (international, no master data): 'BOLLATI' place=2
-- SKIPPED (international, no master data): 'GOETZ' place=3
-- SKIPPED (international, no master data): 'PAWLACZYK' place=3
-- SKIPPED (international, no master data): 'JANIN' place=5
-- SKIPPED (international, no master data): 'RUDENKO' place=6
-- SKIPPED (international, no master data): 'CORUBLE' place=7
-- SKIPPED (international, no master data): 'PASZTOR' place=8
-- SKIPPED (international, no master data): 'LOMBARD' place=9
-- SKIPPED (international, no master data): 'DUCOIN' place=10
-- SKIPPED (international, no master data): 'PEDONE' place=11
-- SKIPPED (international, no master data): 'PETRICK' place=12
-- SKIPPED (international, no master data): 'LENOIR' place=13
-- SKIPPED (international, no master data): 'UHLIG' place=14
-- SKIPPED (international, no master data): 'WIRTH' place=15
-- SKIPPED (international, no master data): 'DE STASIO' place=16
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    273,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-EPEE-2023-2024'),
    17,
    'SĘKOWSKI Maciej'
); -- matched: SĘKOWSKI Maciej (score=100.0)
-- SKIPPED (international, no master data): 'RAUCH' place=18
-- SKIPPED (international, no master data): 'LAUGA' place=19
-- SKIPPED (international, no master data): 'FAURE' place=20
-- SKIPPED (international, no master data): 'TISON' place=21
-- SKIPPED (international, no master data): 'BLANDIN' place=22
-- SKIPPED (international, no master data): 'PARTICS' place=23
-- SKIPPED (international, no master data): 'VARONE' place=24
-- SKIPPED (international, no master data): 'ADAM' place=25
-- SKIPPED (international, no master data): 'OSSOWSKI' place=26
-- SKIPPED (international, no master data): 'SOLAND' place=27
-- SKIPPED (international, no master data): 'VIENNE' place=28
-- SKIPPED (international, no master data): 'MOIS' place=29
-- SKIPPED (international, no master data): 'DEAK' place=30
-- SKIPPED (international, no master data): 'POUSSEL' place=31
-- SKIPPED (international, no master data): 'BERNERON' place=32
-- SKIPPED (international, no master data): 'OHANESSIAN' place=33
-- SKIPPED (international, no master data): 'BUNETEL' place=34
-- SKIPPED (international, no master data): 'ZWICKER' place=35
-- SKIPPED (international, no master data): 'HARSANYI' place=36
-- SKIPPED (international, no master data): 'WILS' place=37
-- SKIPPED (international, no master data): 'BROWN' place=38
-- SKIPPED (international, no master data): 'SCHMIT' place=39
-- SKIPPED (international, no master data): 'DOMAINE' place=40
-- SKIPPED (international, no master data): 'REYNOSO RAFEL' place=41
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-EPEE-2023-2024'),
    42,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA Przemysław (score=100)
-- SKIPPED (international, no master data): 'WIRTH' place=43
-- SKIPPED (international, no master data): 'DALSACE' place=44
-- SKIPPED (international, no master data): 'ABALOS FELIPE' place=45
-- SKIPPED (international, no master data): 'CHAUMOND' place=46
-- SKIPPED (international, no master data): 'TOKOLA' place=47
-- SKIPPED (international, no master data): 'GARNIER' place=48
-- SKIPPED (international, no master data): 'AMSTUTZ' place=49
-- SKIPPED (international, no master data): 'FENZI' place=50
-- SKIPPED (international, no master data): 'VON DER TRENCK' place=51
-- SKIPPED (international, no master data): 'ALONSO ESCOBAR' place=52
-- SKIPPED (international, no master data): 'SOUDAN' place=53
-- SKIPPED (international, no master data): 'JEUNET-MANCY' place=54
-- SKIPPED (international, no master data): 'KRELL' place=55
-- SKIPPED (international, no master data): 'DUBESSY' place=56
-- SKIPPED (international, no master data): 'HEGEMANN' place=57
-- SKIPPED (international, no master data): 'WEISE' place=58
-- SKIPPED (international, no master data): 'ROPOSTE' place=59
-- SKIPPED (international, no master data): 'KASSNER' place=60
-- SKIPPED (international, no master data): 'HUGO' place=61
-- SKIPPED (international, no master data): 'RIGO' place=62
-- SKIPPED (international, no master data): 'AUGER' place=63
-- SKIPPED (international, no master data): 'GRATHE' place=64
-- SKIPPED (international, no master data): 'GIRARDET' place=65
-- SKIPPED (international, no master data): 'PLAZZERIANO' place=66
-- SKIPPED (international, no master data): 'GOSSWILLER' place=67
-- SKIPPED (international, no master data): 'LECHNER' place=68
-- SKIPPED (international, no master data): 'SALAMANDRA' place=69
-- SKIPPED (international, no master data): 'GUEBELLAOUI' place=70
-- SKIPPED (international, no master data): 'BOROSAK' place=71
-- SKIPPED (international, no master data): 'LE CALVEZ' place=72
-- SKIPPED (international, no master data): 'FISCHER' place=73
-- SKIPPED (international, no master data): 'RUOFF' place=74
-- SKIPPED (international, no master data): 'ACIKEL' place=75
-- SKIPPED (international, no master data): 'RAUSZ' place=76
-- SKIPPED (international, no master data): 'DUMOULIN' place=77
-- SKIPPED (international, no master data): 'STRAKA' place=78
-- SKIPPED (international, no master data): 'VITEZY' place=79
-- SKIPPED (international, no master data): 'CADET' place=80
-- SKIPPED (international, no master data): 'FOREST' place=81
-- SKIPPED (international, no master data): 'PAROCHE' place=82
-- SKIPPED (international, no master data): 'REPIQUET' place=83
-- SKIPPED (international, no master data): 'PERU' place=84
-- SKIPPED (international, no master data): 'LACROIX' place=85
-- SKIPPED (international, no master data): 'VIGNE' place=86
-- SKIPPED (international, no master data): 'ZONNO' place=87
-- SKIPPED (international, no master data): 'DRAEGER' place=88
-- SKIPPED (international, no master data): 'LALLEMENT' place=89
-- SKIPPED (international, no master data): 'BUGARI' place=90
-- SKIPPED (international, no master data): 'BICHASCLE' place=91
-- SKIPPED (international, no master data): 'FONTECHA MARTIN' place=92
-- SKIPPED (international, no master data): 'EUSKIRCHEN' place=93
-- SKIPPED (international, no master data): 'GARCIA FERNANDEZ' place=94
-- SKIPPED (international, no master data): 'FARKAS' place=95
-- SKIPPED (international, no master data): 'ARVIUS' place=96
-- SKIPPED (international, no master data): 'GOURDIN' place=97
-- SKIPPED (international, no master data): 'MCKAY' place=98
-- SKIPPED (international, no master data): 'KORZH' place=99
-- SKIPPED (international, no master data): 'MAYER' place=100
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    256,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-EPEE-2023-2024'),
    101,
    'STOLARIK'
); -- matched: STOLARIK Peter (score=72.72727272727273)
-- SKIPPED (international, no master data): 'SENIS LOPEZ' place=102
-- SKIPPED (international, no master data): 'PETITFILS' place=103
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    43,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-EPEE-2023-2024'),
    104,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
-- SKIPPED (international, no master data): 'MAHIEU' place=105
-- SKIPPED (international, no master data): 'RASMUSSEN' place=106
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    48,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-EPEE-2023-2024'),
    107,
    'DROBCZYK Paweł'
); -- matched: DROBCZYK Paweł (score=100.0)
-- SKIPPED (international, no master data): 'CORNET CARMONA' place=108
-- SKIPPED (international, no master data): 'DE FREITAS' place=109
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    40,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-EPEE-2023-2024'),
    110,
    'CZAJKOWSKI Marcin'
); -- matched: CZAJKOWSKI Marcin (score=100.0)
-- SKIPPED (international, no master data): 'AFANASSIEV' place=111
-- SKIPPED (international, no master data): 'FERNANDEZ DEL CASTILLO GARCIA' place=112
-- SKIPPED (international, no master data): 'ALLAIRE' place=113
-- SKIPPED (international, no master data): 'JEANPIERRE-COUSSET' place=114
-- SKIPPED (international, no master data): 'SUOKAS' place=115
-- SKIPPED (international, no master data): 'ISRAEL' place=116
-- SKIPPED (international, no master data): 'LAGARDE' place=117
-- SKIPPED (international, no master data): 'FUCHS' place=118
-- SKIPPED (international, no master data): 'GALLE' place=119
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    56,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-EPEE-2023-2024'),
    120,
    'FORAJTER Roman'
); -- matched: FORAJTER Roman (score=100.0)
-- SKIPPED (international, no master data): 'THIERS' place=121
-- SKIPPED (international, no master data): 'BOTTACIN' place=122
-- SKIPPED (international, no master data): 'AAVIKKO' place=123
-- SKIPPED (international, no master data): 'LOWACK' place=124
-- SKIPPED (international, no master data): 'WOTLING' place=125
-- SKIPPED (international, no master data): 'MASSEY' place=126
-- SKIPPED (international, no master data): 'FALCIONI' place=127
-- SKIPPED (international, no master data): 'LONCIN' place=128
-- SKIPPED (international, no master data): 'MAURY' place=129
-- SKIPPED (international, no master data): 'LIZERAY' place=130
-- SKIPPED (international, no master data): 'NYEKI' place=131
-- SKIPPED (international, no master data): 'JOOSSENS' place=132
-- SKIPPED (international, no master data): 'BRINKHOFF' place=133
-- SKIPPED (international, no master data): 'WEINHOLD' place=134
-- SKIPPED (international, no master data): 'MAGLIOZZI' place=135
-- SKIPPED (international, no master data): 'KRUEGER' place=136
-- SKIPPED (international, no master data): 'BIESSNER' place=137
-- SKIPPED (international, no master data): 'MÄNNISTO' place=138
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    238,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-EPEE-2023-2024'),
    164,
    'SAMSONOWICZ Maciej'
); -- matched: SAMSONOWICZ Maciej (score=100.0)
-- Compute scores for IMEW-V1-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-EPEE-2023-2024')
);

-- Summary
-- Total results matched:   127
-- Total results unmatched: 135
-- Total auto-created:      1
