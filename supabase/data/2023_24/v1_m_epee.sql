-- =========================================================================
-- Season 2023-2024 — V1 M EPEE — generated from SZPADA-1-2023-2024.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

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
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-EPEE-2023-2024'),
    1,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    216,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-EPEE-2023-2024'),
    2,
    'SĘKOWSKI Maciej'
); -- matched: SĘKOWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    15,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-EPEE-2023-2024'),
    3,
    'BETLEJ Daniel'
); -- matched: BETLEJ Daniel (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    39,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-EPEE-2023-2024'),
    4,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    276,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-EPEE-2023-2024'),
    5,
    'ZIEMECKI Grzegorz'
); -- matched: ZIEMECKI Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    108,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-EPEE-2023-2024'),
    6,
    'KOBIERSKI Krzysztof'
); -- matched: KOBIERSKI Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    179,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-EPEE-2023-2024'),
    7,
    'OWCZAREK Hubert'
); -- matched: OWCZAREK Hubert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    73,
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
    216,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-EPEE-2023-2024'),
    1,
    'SĘKOWSKI Maciej'
); -- matched: SĘKOWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-EPEE-2023-2024'),
    2,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    34,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-EPEE-2023-2024'),
    3,
    'CZAJKOWSKI Marcin'
); -- matched: CZAJKOWSKI Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    39,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-EPEE-2023-2024'),
    4,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-EPEE-2023-2024'),
    5,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    82,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-EPEE-2023-2024'),
    6,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    119,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-EPEE-2023-2024'),
    7,
    'KORZH Valery'
); -- matched: KORZH Valery (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    108,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-EPEE-2023-2024'),
    8,
    'KOBIERSKI Krzysztof'
); -- matched: KOBIERSKI Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    149,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-EPEE-2023-2024'),
    9,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    141,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-EPEE-2023-2024'),
    10,
    'LELONEK Tomasz'
); -- matched: LELONEK Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    73,
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
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-EPEE-2023-2024'),
    1,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-EPEE-2023-2024'),
    2,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    220,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-EPEE-2023-2024'),
    5,
    'SOKOL Vratislav'
); -- matched: SOKOL Vratislav (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    82,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-EPEE-2023-2024'),
    6,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    34,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-EPEE-2023-2024'),
    7,
    'CZAJKOWSKI Marcin'
); -- matched: CZAJKOWSKI Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    39,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-EPEE-2023-2024'),
    8,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    149,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-EPEE-2023-2024'),
    9,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    141,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-EPEE-2023-2024'),
    10,
    'LELONEK Tomasz'
); -- matched: LELONEK Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-EPEE-2023-2024'),
    11,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    179,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-EPEE-2023-2024'),
    12,
    'OWCZAREK Hubert'
); -- matched: OWCZAREK Hubert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    108,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-EPEE-2023-2024'),
    13,
    'KOBIERSKI Krzysztof'
); -- matched: KOBIERSKI Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    73,
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
    73,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V1-M-EPEE-2023-2024'),
    1,
    'GRIPAS Artiom'
); -- matched: GRIPAS Artiom (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    15,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V1-M-EPEE-2023-2024'),
    2,
    'BETLEJ Daniel'
); -- matched: BETLEJ Daniel (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    276,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V1-M-EPEE-2023-2024'),
    3,
    'ZIEMECKI Grzegorz'
); -- matched: ZIEMECKI Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    149,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V1-M-EPEE-2023-2024'),
    4,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    39,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V1-M-EPEE-2023-2024'),
    5,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    34,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V1-M-EPEE-2023-2024'),
    6,
    'CZAJKOWSKI Marcin'
); -- matched: CZAJKOWSKI Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
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
    73,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V1-M-EPEE-2023-2024'),
    1,
    'GRIPAS Artiom'
); -- matched: GRIPAS Artiom (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V1-M-EPEE-2023-2024'),
    3,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    39,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V1-M-EPEE-2023-2024'),
    4,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    141,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V1-M-EPEE-2023-2024'),
    5,
    'LELONEK Tomasz'
); -- matched: LELONEK Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    149,
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
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V1-M-EPEE-2023-2024'),
    1,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    108,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V1-M-EPEE-2023-2024'),
    2,
    'KOBIERSKI Krzysztof'
); -- matched: KOBIERSKI Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    39,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V1-M-EPEE-2023-2024'),
    3,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    276,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V1-M-EPEE-2023-2024'),
    4,
    'ZIEMECKI Grzegorz'
); -- matched: ZIEMECKI Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    179,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V1-M-EPEE-2023-2024'),
    7,
    'OWCZAREK Hubert'
); -- matched: OWCZAREK Hubert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    149,
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
    73,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-EPEE-2023-2024'),
    1,
    'GRIPAS Artiom'
); -- matched: GRIPAS Artiom (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-EPEE-2023-2024'),
    2,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-EPEE-2023-2024'),
    3,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    39,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-EPEE-2023-2024'),
    4,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    34,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-EPEE-2023-2024'),
    5,
    'CZAJKOWSKI Marcin'
); -- matched: CZAJKOWSKI Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    108,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-EPEE-2023-2024'),
    6,
    'KOBIERSKI Krzysztof'
); -- matched: KOBIERSKI Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    149,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-EPEE-2023-2024'),
    7,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    276,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-EPEE-2023-2024'),
    8,
    'ZIEMECKI Grzegorz'
); -- matched: ZIEMECKI Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    78,
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
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-EPEE-2023-2024'),
    1,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    73,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-EPEE-2023-2024'),
    2,
    'GRIPAS Artiom'
); -- matched: GRIPAS Artiom (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    227,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-EPEE-2023-2024'),
    3,
    'STOCKI Piotr'
); -- matched: STOCKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-EPEE-2023-2024'),
    5,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    39,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-EPEE-2023-2024'),
    6,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    149,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-EPEE-2023-2024'),
    7,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    108,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-EPEE-2023-2024'),
    8,
    'KOBIERSKI Krzysztof'
); -- matched: KOBIERSKI Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    276,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-EPEE-2023-2024'),
    10,
    'ZIEMECKI Grzegorz'
); -- matched: ZIEMECKI Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    78,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-EPEE-2023-2024'),
    11,
    'GUZY Adrian'
); -- matched: GUZY Adrian (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    160,
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
    73,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2023-2024'),
    1,
    'GRIPAS Artiom'
); -- matched: GRIPAS Artiom (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2023-2024'),
    3,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    39,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2023-2024'),
    4,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    131,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2023-2024'),
    5,
    'KOZIEJOWSKI Sebastian'
); -- matched: KOZIEJOWSKI Sebastian (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    34,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2023-2024'),
    6,
    'CZAJKOWSKI Marcin'
); -- matched: CZAJKOWSKI Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    108,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2023-2024'),
    7,
    'KOBIERSKI Krzysztof'
); -- matched: KOBIERSKI Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    229,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2023-2024'),
    8,
    'STYŚ Jan'
); -- matched: STYŚ Jan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    87,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2023-2024'),
    9,
    'JADCZUK Wojciech'
); -- matched: JADCZUK Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2023-2024'),
    10,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    149,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2023-2024'),
    11,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    114,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2023-2024'),
    12,
    'KOŃCZYŃSKI Adam'
); -- matched: KOŃCZYŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    141,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-EPEE-2023-2024'),
    13,
    'LELONEK Tomasz'
); -- matched: LELONEK Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    160,
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
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-M-EPEE-2023-2024'),
    8,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
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
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-M-EPEE-2023-2024'),
    1,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
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
    216,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2023-2024'),
    2,
    'SĘKOWSKI Maciej'
); -- matched: SĘKOWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2023-2024'),
    5,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    34,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2023-2024'),
    7,
    'CZAJKOWSKI Marcin'
); -- matched: CZAJKOWSKI Marcin (score=100.0)
-- UNMATCHED (score<80): 'GORCZYCA Marcin' place=9
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    39,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2023-2024'),
    11,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    82,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2023-2024'),
    12,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    213,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2023-2024'),
    13,
    'SAMSONOWICZ Maciej'
); -- matched: SAMSONOWICZ Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    179,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2023-2024'),
    14,
    'OWCZAREK Hubert'
); -- matched: OWCZAREK Hubert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2023-2024'),
    15,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    108,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2023-2024'),
    17,
    'KOBIERSKI Krzysztof'
); -- matched: KOBIERSKI Krzysztof (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    160,
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
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-EPEE-2023-2024'),
    3,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
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
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V1-M-EPEE-2023-2024'),
    2,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
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
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2023-2024'),
    1,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
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
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-M-EPEE-2023-2024'),
    3,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
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
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V1-M-EPEE-2023-2024'),
    2,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
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
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW9-V1-M-EPEE-2023-2024'),
    6,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    73,
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
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V1-M-EPEE-2023-2024'),
    2,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    39,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V1-M-EPEE-2023-2024'),
    8,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V1-M-EPEE-2023-2024'),
    10,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    108,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V1-M-EPEE-2023-2024'),
    11,
    'KOBIERSKI Krzysztof'
); -- matched: KOBIERSKI Krzysztof (score=100.0)
-- UNMATCHED (score<80): 'GORCZYCA Marcin' place=13
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    141,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V1-M-EPEE-2023-2024'),
    14,
    'LELONEK Tomasz'
); -- matched: LELONEK Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    160,
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
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW12-V1-M-EPEE-2023-2024'),
    2,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
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
-- UNMATCHED (score<80): 'DELATTRE' place=1
-- UNMATCHED (score<80): 'BOLLATI' place=2
-- UNMATCHED (score<80): 'GOETZ' place=3
-- UNMATCHED (score<80): 'PAWLACZYK' place=3
-- UNMATCHED (score<80): 'JANIN' place=5
-- UNMATCHED (score<80): 'RUDENKO' place=6
-- UNMATCHED (score<80): 'CORUBLE' place=7
-- UNMATCHED (score<80): 'PASZTOR' place=8
-- UNMATCHED (score<80): 'LOMBARD' place=9
-- UNMATCHED (score<80): 'DUCOIN' place=10
-- UNMATCHED (score<80): 'PEDONE' place=11
-- UNMATCHED (score<80): 'PETRICK' place=12
-- UNMATCHED (score<80): 'LENOIR' place=13
-- UNMATCHED (score<80): 'UHLIG' place=14
-- UNMATCHED (score<80): 'WIRTH' place=15
-- UNMATCHED (score<80): 'DE STASIO' place=16
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    216,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-EPEE-2023-2024'),
    17,
    'SĘKOWSKI Maciej'
); -- matched: SĘKOWSKI Maciej (score=100.0)
-- UNMATCHED (score<80): 'RAUCH' place=18
-- UNMATCHED (score<80): 'LAUGA' place=19
-- UNMATCHED (score<80): 'FAURE' place=20
-- UNMATCHED (score<80): 'TISON' place=21
-- UNMATCHED (score<80): 'BLANDIN' place=22
-- UNMATCHED (score<80): 'PARTICS' place=23
-- UNMATCHED (score<80): 'VARONE' place=24
-- UNMATCHED (score<80): 'ADAM' place=25
-- UNMATCHED (score<80): 'OSSOWSKI' place=26
-- UNMATCHED (score<80): 'SOLAND' place=27
-- UNMATCHED (score<80): 'VIENNE' place=28
-- UNMATCHED (score<80): 'MOIS' place=29
-- UNMATCHED (score<80): 'DEAK' place=30
-- UNMATCHED (score<80): 'POUSSEL' place=31
-- UNMATCHED (score<80): 'BERNERON' place=32
-- UNMATCHED (score<80): 'OHANESSIAN' place=33
-- UNMATCHED (score<80): 'BUNETEL' place=34
-- UNMATCHED (score<80): 'ZWICKER' place=35
-- UNMATCHED (score<80): 'HARSANYI' place=36
-- UNMATCHED (score<80): 'WILS' place=37
-- UNMATCHED (score<80): 'BROWN' place=38
-- UNMATCHED (score<80): 'SCHMIT' place=39
-- UNMATCHED (score<80): 'DOMAINE' place=40
-- UNMATCHED (score<80): 'REYNOSO RAFEL' place=41
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-EPEE-2023-2024'),
    42,
    'KORONA-TRZEBSKI Przemysław'
); -- matched: KORONA-TRZEBSKI Przemysław (score=100.0)
-- UNMATCHED (score<80): 'WIRTH' place=43
-- UNMATCHED (score<80): 'DALSACE' place=44
-- UNMATCHED (score<80): 'ABALOS FELIPE' place=45
-- UNMATCHED (score<80): 'CHAUMOND' place=46
-- UNMATCHED (score<80): 'TOKOLA' place=47
-- UNMATCHED (score<80): 'GARNIER' place=48
-- UNMATCHED (score<80): 'AMSTUTZ' place=49
-- UNMATCHED (score<80): 'FENZI' place=50
-- UNMATCHED (score<80): 'VON DER TRENCK' place=51
-- UNMATCHED (score<80): 'ALONSO ESCOBAR' place=52
-- UNMATCHED (score<80): 'SOUDAN' place=53
-- UNMATCHED (score<80): 'JEUNET-MANCY' place=54
-- UNMATCHED (score<80): 'KRELL' place=55
-- UNMATCHED (score<80): 'DUBESSY' place=56
-- UNMATCHED (score<80): 'HEGEMANN' place=57
-- UNMATCHED (score<80): 'WEISE' place=58
-- UNMATCHED (score<80): 'ROPOSTE' place=59
-- UNMATCHED (score<80): 'KASSNER' place=60
-- UNMATCHED (score<80): 'HUGO' place=61
-- UNMATCHED (score<80): 'RIGO' place=62
-- UNMATCHED (score<80): 'AUGER' place=63
-- UNMATCHED (score<80): 'GRATHE' place=64
-- UNMATCHED (score<80): 'GIRARDET' place=65
-- UNMATCHED (score<80): 'PLAZZERIANO' place=66
-- UNMATCHED (score<80): 'GOSSWILLER' place=67
-- UNMATCHED (score<80): 'LECHNER' place=68
-- UNMATCHED (score<80): 'SALAMANDRA' place=69
-- UNMATCHED (score<80): 'GUEBELLAOUI' place=70
-- UNMATCHED (score<80): 'BOROSAK' place=71
-- UNMATCHED (score<80): 'LE CALVEZ' place=72
-- UNMATCHED (score<80): 'FISCHER' place=73
-- UNMATCHED (score<80): 'RUOFF' place=74
-- UNMATCHED (score<80): 'ACIKEL' place=75
-- UNMATCHED (score<80): 'RAUSZ' place=76
-- UNMATCHED (score<80): 'DUMOULIN' place=77
-- UNMATCHED (score<80): 'STRAKA' place=78
-- UNMATCHED (score<80): 'VITEZY' place=79
-- UNMATCHED (score<80): 'CADET' place=80
-- UNMATCHED (score<80): 'FOREST' place=81
-- UNMATCHED (score<80): 'PAROCHE' place=82
-- UNMATCHED (score<80): 'REPIQUET' place=83
-- UNMATCHED (score<80): 'PERU' place=84
-- UNMATCHED (score<80): 'LACROIX' place=85
-- UNMATCHED (score<80): 'VIGNE' place=86
-- UNMATCHED (score<80): 'ZONNO' place=87
-- UNMATCHED (score<80): 'DRAEGER' place=88
-- UNMATCHED (score<80): 'LALLEMENT' place=89
-- UNMATCHED (score<80): 'BUGARI' place=90
-- UNMATCHED (score<80): 'BICHASCLE' place=91
-- UNMATCHED (score<80): 'FONTECHA MARTIN' place=92
-- UNMATCHED (score<80): 'EUSKIRCHEN' place=93
-- UNMATCHED (score<80): 'GARCIA FERNANDEZ' place=94
-- UNMATCHED (score<80): 'FARKAS' place=95
-- UNMATCHED (score<80): 'ARVIUS' place=96
-- UNMATCHED (score<80): 'GOURDIN' place=97
-- UNMATCHED (score<80): 'MCKAY' place=98
-- UNMATCHED (score<80): 'KORZH' place=99
-- UNMATCHED (score<80): 'MAYER' place=100
-- UNMATCHED (score<80): 'STOLARIK' place=101
-- UNMATCHED (score<80): 'SENIS LOPEZ' place=102
-- UNMATCHED (score<80): 'PETITFILS' place=103
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    39,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-EPEE-2023-2024'),
    104,
    'DOBRZAŃSKI Maciej'
); -- matched: DOBRZAŃSKI Maciej (score=100.0)
-- UNMATCHED (score<80): 'MAHIEU' place=105
-- UNMATCHED (score<80): 'RASMUSSEN' place=106
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    44,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-EPEE-2023-2024'),
    107,
    'DROBCZYK Paweł'
); -- matched: DROBCZYK Paweł (score=100.0)
-- UNMATCHED (score<80): 'CORNET CARMONA' place=108
-- UNMATCHED (score<80): 'DE FREITAS' place=109
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    34,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-EPEE-2023-2024'),
    110,
    'CZAJKOWSKI Marcin'
); -- matched: CZAJKOWSKI Marcin (score=100.0)
-- UNMATCHED (score<80): 'AFANASSIEV' place=111
-- UNMATCHED (score<80): 'FERNANDEZ DEL CASTILLO GARCIA' place=112
-- UNMATCHED (score<80): 'ALLAIRE' place=113
-- UNMATCHED (score<80): 'JEANPIERRE-COUSSET' place=114
-- UNMATCHED (score<80): 'SUOKAS' place=115
-- UNMATCHED (score<80): 'ISRAEL' place=116
-- UNMATCHED (score<80): 'LAGARDE' place=117
-- UNMATCHED (score<80): 'FUCHS' place=118
-- UNMATCHED (score<80): 'GALLE' place=119
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    52,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-EPEE-2023-2024'),
    120,
    'FORAJTER Roman'
); -- matched: FORAJTER Roman (score=100.0)
-- UNMATCHED (score<80): 'THIERS' place=121
-- UNMATCHED (score<80): 'BOTTACIN' place=122
-- UNMATCHED (score<80): 'AAVIKKO' place=123
-- UNMATCHED (score<80): 'LOWACK' place=124
-- UNMATCHED (score<80): 'WOTLING' place=125
-- UNMATCHED (score<80): 'MASSEY' place=126
-- UNMATCHED (score<80): 'FALCIONI' place=127
-- UNMATCHED (score<80): 'LONCIN' place=128
-- UNMATCHED (score<80): 'MAURY' place=129
-- UNMATCHED (score<80): 'LIZERAY' place=130
-- UNMATCHED (score<80): 'NYEKI' place=131
-- UNMATCHED (score<80): 'JOOSSENS' place=132
-- UNMATCHED (score<80): 'BRINKHOFF' place=133
-- UNMATCHED (score<80): 'WEINHOLD' place=134
-- UNMATCHED (score<80): 'MAGLIOZZI' place=135
-- UNMATCHED (score<80): 'KRUEGER' place=136
-- UNMATCHED (score<80): 'BIESSNER' place=137
-- UNMATCHED (score<80): 'MÄNNISTO' place=138
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    213,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-EPEE-2023-2024'),
    164,
    'SAMSONOWICZ Maciej'
); -- matched: SAMSONOWICZ Maciej (score=100.0)
-- Compute scores for IMEW-V1-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-EPEE-2023-2024')
);

-- Summary
-- Total results matched:   128
-- Total results unmatched: 134
