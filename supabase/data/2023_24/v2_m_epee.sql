-- =========================================================================
-- Season 2023-2024 — V2 M EPEE — generated from SZPADA-2-2023-2024.xlsx
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
    'GP1-V2-M-EPEE-2023-2024',
    'Grand Prix (runda 1)',
    'PPW',
    'EPEE', 'M', 'V2',
    '2023-01-14', 11, 'https://www.fencingtimelive.com/events/results/1D84C2D35F9E4C3DA89F0EB7F4668612',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-EPEE-2023-2024'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    311,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-EPEE-2023-2024'),
    2,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-EPEE-2023-2024'),
    3,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    135,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-EPEE-2023-2024'),
    4,
    'BURLIKOWSKI Bartosz'
); -- matched: KOWALSKI Bartosz (score=80.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-EPEE-2023-2024'),
    5,
    'SKOCZEK Artur'
); -- matched: SKOCZEK Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    103,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-EPEE-2023-2024'),
    6,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    129,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-EPEE-2023-2024'),
    7,
    'KOTERSKI Paweł'
); -- matched: KOTERSKI Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    300,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-EPEE-2023-2024'),
    8,
    'WOJTAS Bogdan'
); -- matched: WOJTAS Bogusław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    83,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-EPEE-2023-2024'),
    9,
    'GRZYWACZ Mirosław'
); -- matched: GRZYWACZ Mirosław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-EPEE-2023-2024'),
    10,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-EPEE-2023-2024'),
    11,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
-- Compute scores for GP1-V2-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-M-EPEE-2023-2024')
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
    'GP2-V2-M-EPEE-2023-2024',
    'Grand Prix (runda 2)',
    'PPW',
    'EPEE', 'M', 'V2',
    '2023-04-03', 11, 'https://www.fencingtimelive.com/events/results/526CDE0F02E74CE89A10C566FEEA05B7',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-EPEE-2023-2024'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    311,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-EPEE-2023-2024'),
    2,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-EPEE-2023-2024'),
    3,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    88,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-EPEE-2023-2024'),
    4,
    'GĄSIOROWSKI Maciej'
); -- matched: GĄSIOROWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    129,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-EPEE-2023-2024'),
    5,
    'KOTERSKI Paweł'
); -- matched: KOTERSKI Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-EPEE-2023-2024'),
    6,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-EPEE-2023-2024'),
    7,
    'SKOCZEK Artur'
); -- matched: SKOCZEK Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    50,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-EPEE-2023-2024'),
    8,
    'DUDEK Mariusz'
); -- matched: DUDEK Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-EPEE-2023-2024'),
    9,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-EPEE-2023-2024'),
    10,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-EPEE-2023-2024'),
    11,
    'KASZTELOWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=74.28571428571429)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-EPEE-2023-2024'),
    14,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
-- Compute scores for GP2-V2-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-M-EPEE-2023-2024')
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
    'GP3-V2-M-EPEE-2023-2024',
    'Grand Prix (runda 3)',
    'PPW',
    'EPEE', 'M', 'V2',
    '2023-06-17', 9, 'https://www.fencingtimelive.com/events/results/2A305C5745BC4A55B83A221B1DB5A238',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-EPEE-2023-2024'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-EPEE-2023-2024'),
    2,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    311,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-EPEE-2023-2024'),
    3,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-EPEE-2023-2024'),
    4,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    129,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-EPEE-2023-2024'),
    5,
    'KOTERSKI Paweł'
); -- matched: KOTERSKI Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    300,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-EPEE-2023-2024'),
    6,
    'WOJTAS Bogdan'
); -- matched: WOJTAS Bogusław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-EPEE-2023-2024'),
    7,
    'SKOCZEK Artur'
); -- matched: SKOCZEK Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-EPEE-2023-2024'),
    8,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-EPEE-2023-2024'),
    9,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    104,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-EPEE-2023-2024'),
    11,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-EPEE-2023-2024'),
    12,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
-- Compute scores for GP3-V2-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-M-EPEE-2023-2024')
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
    'GP4-V2-M-EPEE-2023-2024',
    'Grand Prix (runda 4)',
    'PPW',
    'EPEE', 'M', 'V2',
    '2023-10-23', 11, 'https://www.fencingtimelive.com/events/results/BC806A0FB52C4E99A2ABDDC4AF4D6462',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-EPEE-2023-2024'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    104,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-EPEE-2023-2024'),
    2,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-EPEE-2023-2024'),
    3,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    311,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-EPEE-2023-2024'),
    4,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-EPEE-2023-2024'),
    5,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-EPEE-2023-2024'),
    6,
    'SKOCZEK Artur'
); -- matched: SKOCZEK Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    300,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-EPEE-2023-2024'),
    7,
    'WOJTAS Bogdan'
); -- matched: WOJTAS Bogusław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-EPEE-2023-2024'),
    8,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    50,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-EPEE-2023-2024'),
    9,
    'DUDEK Mariusz'
); -- matched: DUDEK Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    279,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-EPEE-2023-2024'),
    10,
    'TRACZ Jerzy'
); -- matched: TRACZ Jerzy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-EPEE-2023-2024'),
    11,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
-- Compute scores for GP4-V2-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-M-EPEE-2023-2024')
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
    'GP5-V2-M-EPEE-2023-2024',
    'Grand Prix (runda 5)',
    'PPW',
    'EPEE', 'M', 'V2',
    '2023-10-28', 9, 'https://www.fencingtimelive.com/events/results/A62375ABB1D742A59E6F54AD212093F5',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-M-EPEE-2023-2024'),
    1,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-M-EPEE-2023-2024'),
    2,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    135,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-M-EPEE-2023-2024'),
    3,
    'BURLIKOWSKI Bartosz'
); -- matched: KOWALSKI Bartosz (score=80.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    103,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-M-EPEE-2023-2024'),
    4,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-M-EPEE-2023-2024'),
    5,
    'SKOCZEK Artur'
); -- matched: SKOCZEK Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    50,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-M-EPEE-2023-2024'),
    6,
    'DUDEK Mariusz'
); -- matched: DUDEK Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-M-EPEE-2023-2024'),
    7,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-M-EPEE-2023-2024'),
    8,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    279,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-M-EPEE-2023-2024'),
    9,
    'TRACZ Jerzy'
); -- matched: TRACZ Jerzy (score=100.0)
-- Compute scores for GP5-V2-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-M-EPEE-2023-2024')
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
    'GP6-V2-M-EPEE-2023-2024',
    'Grand Prix (runda 6)',
    'PPW',
    'EPEE', 'M', 'V2',
    '2023-11-18', 12, 'https://www.fencingtimelive.com/events/results/10D132CBD4F94596B378F51BDF250041',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    311,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-EPEE-2023-2024'),
    1,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-EPEE-2023-2024'),
    2,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-EPEE-2023-2024'),
    3,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-EPEE-2023-2024'),
    4,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    300,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-EPEE-2023-2024'),
    5,
    'WOJTAS Bogdan'
); -- matched: WOJTAS Bogusław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    135,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-EPEE-2023-2024'),
    6,
    'BURLIKOWSKI Bartosz'
); -- matched: KOWALSKI Bartosz (score=80.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    129,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-EPEE-2023-2024'),
    7,
    'KOTERSKI Paweł'
); -- matched: KOTERSKI Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    249,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-EPEE-2023-2024'),
    8,
    'PURGINA Marian'
); -- matched: SPIRINA Ekaterina (score=70.23809523809524)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-EPEE-2023-2024'),
    9,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    50,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-EPEE-2023-2024'),
    10,
    'DUDEK Mariusz'
); -- matched: DUDEK Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-EPEE-2023-2024'),
    11,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    302,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-EPEE-2023-2024'),
    12,
    'WRONA Grzegorz'
); -- matched: WRONA Grzegorz (score=100.0)
-- Compute scores for GP6-V2-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-M-EPEE-2023-2024')
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
    'GP7-V2-M-EPEE-2023-2024',
    'Grand Prix (runda 7)',
    'PPW',
    'EPEE', 'M', 'V2',
    '2024-01-27', 12, 'https://www.fencingtimelive.com/events/results/15D820D5BA9A442AA26E2B4B816F091F',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-EPEE-2023-2024'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    104,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-EPEE-2023-2024'),
    2,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    311,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-EPEE-2023-2024'),
    3,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-EPEE-2023-2024'),
    4,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    103,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-EPEE-2023-2024'),
    5,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-EPEE-2023-2024'),
    6,
    'WIERZBICKI JACEK'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    300,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-EPEE-2023-2024'),
    7,
    'WOJTAS Bogdan'
); -- matched: WOJTAS Bogusław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-EPEE-2023-2024'),
    8,
    'SKOCZEK Artur'
); -- matched: SKOCZEK Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    129,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-EPEE-2023-2024'),
    9,
    'KOTERSKI Paweł'
); -- matched: KOTERSKI Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-EPEE-2023-2024'),
    10,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    279,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-EPEE-2023-2024'),
    11,
    'TRACZ Jerzy'
); -- matched: TRACZ Jerzy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    318,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-EPEE-2023-2024'),
    12,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100.0)
-- Compute scores for GP7-V2-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-EPEE-2023-2024')
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
    'GP8-V2-M-EPEE-2023-2024',
    'Grand Prix (runda 8)',
    'PPW',
    'EPEE', 'M', 'V2',
    '2024-06-22', 9, 'https://www.fencingtimelive.com/events/results/1CE9E480C97E4E7A8156F36B08407F3F',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    104,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-EPEE-2023-2024'),
    1,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    311,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-EPEE-2023-2024'),
    2,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-EPEE-2023-2024'),
    3,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-EPEE-2023-2024'),
    4,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-EPEE-2023-2024'),
    5,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    86,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-EPEE-2023-2024'),
    6,
    'GWIAZDA Paweł'
); -- matched: GWIAZDA Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-EPEE-2023-2024'),
    7,
    'SKOCZEK Artur'
); -- matched: SKOCZEK Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    318,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-EPEE-2023-2024'),
    8,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-EPEE-2023-2024'),
    9,
    'WIERZBICKI JACEK'
); -- matched: WIERZBICKI Jacek (score=100.0)
-- Compute scores for GP8-V2-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-EPEE-2023-2024')
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
    'MPW-V2-M-EPEE-2023-2024',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'EPEE', 'M', 'V2',
    '2024-03-02', 13, 'https://www.fencingtimelive.com/events/results/5FB199770880472EB2FF1D3CBBF0E907',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    104,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024'),
    2,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    311,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024'),
    3,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024'),
    4,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    195,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024'),
    5,
    'OLSZEWSKI Mikołaj'
); -- matched: OLSZEWSKI Mikołaj (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024'),
    6,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    300,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024'),
    7,
    'WOJTAS Bogdan'
); -- matched: WOJTAS Bogusław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    50,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024'),
    8,
    'DUDEK Mariusz'
); -- matched: DUDEK Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    264,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024'),
    9,
    'SZKODA Marek Tomasz'
); -- matched: SZKODA Marek Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024'),
    10,
    'WIERZBICKI JACEK'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    279,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024'),
    11,
    'TRACZ Jerzy'
); -- matched: TRACZ Jerzy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024'),
    12,
    'SKOCZEK Artur'
); -- matched: SKOCZEK Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024'),
    13,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
-- Compute scores for MPW-V2-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024')
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
    'PEW1-V2-M-EPEE-2023-2024',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'EPEE', 'M', 'V2',
    '2023-01-07', 51, 'https://www.fencingtimelive.com/events/results/807189A3AEA64E09A3F3545109C57FD9',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-EPEE-2023-2024'),
    20,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-EPEE-2023-2024'),
    50,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
-- Compute scores for PEW1-V2-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-EPEE-2023-2024')
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
    'PEW2-V2-M-EPEE-2023-2024',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'EPEE', 'M', 'V2',
    '2023-02-25', 24, 'https://engarde-service.com/index.php?lang=en&Organisme=santanderfencing&Event=evf_epee_circuit_santander&Compe=m_epee_v2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-EPEE-2023-2024'),
    5,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
-- Compute scores for PEW2-V2-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-EPEE-2023-2024')
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
    'PEW3-V2-M-EPEE-2023-2024',
    'EVF Grand Prix 3',
    'PEW',
    'EPEE', 'M', 'V2',
    '2023-04-14', 21, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    311,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2023-2024'),
    1,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2023-2024'),
    3,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    309,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2023-2024'),
    6,
    'ZAWALICH Leszek'
); -- matched: ZAWALICH Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    129,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2023-2024'),
    8,
    'KOTERSKI Paweł'
); -- matched: KOTERSKI Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2023-2024'),
    9,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2023-2024'),
    11,
    'SKOCZEK Artur'
); -- matched: SKOCZEK Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2023-2024'),
    12,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    88,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2023-2024'),
    14,
    'GĄSIOROWSKI Maciej'
); -- matched: GĄSIOROWSKI Maciej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    103,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2023-2024'),
    15,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    50,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2023-2024'),
    17,
    'DUDEK Mariusz'
); -- matched: DUDEK Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    135,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2023-2024'),
    18,
    'BURLIKOWSKI Bartosz'
); -- matched: KOWALSKI Bartosz (score=80.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2023-2024'),
    19,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2023-2024'),
    20,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2023-2024'),
    24,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
-- Compute scores for PEW3-V2-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-EPEE-2023-2024')
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
    'PEW4-V2-M-EPEE-2023-2024',
    'EVF Grand Prix 4',
    'PEW',
    'EPEE', 'M', 'V2',
    '2023-09-16', 38, 'https://engarde-service.com/?fbclid=IwAR1q8b20973WNdhLRYbl3vdP-rPK0cilvuHZi37KFNf-Dodoicffb3YOQeM',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-EPEE-2023-2024'),
    3,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    311,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-EPEE-2023-2024'),
    5,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    103,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-EPEE-2023-2024'),
    12,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-EPEE-2023-2024'),
    14,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-EPEE-2023-2024'),
    35,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-EPEE-2023-2024'),
    37,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
-- Compute scores for PEW4-V2-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-EPEE-2023-2024')
);

-- SKIP PEW5 (EVF Grand Prix 5): N=0 — tournament had no participants

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
    'PEW6-V2-M-EPEE-2023-2024',
    'EVF Grand Prix 6',
    'PEW',
    'EPEE', 'M', 'V2',
    '2023-11-11', 43, 'https://engarde-service.com/competition/aeve_esgrima/evf_madrid_2023/em_2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2023-2024'),
    3,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2023-2024'),
    9,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    103,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2023-2024'),
    22,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2023-2024'),
    32,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
-- Compute scores for PEW6-V2-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-EPEE-2023-2024')
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
    'PEW7-V2-M-EPEE-2023-2024',
    'EVF Grand Prix 7 — Terni',
    'PEW',
    'EPEE', 'M', 'V2',
    '2023-12-16', 60, 'https://www.4fence.it/FIS/Risultati/2023-12-17-16_Terni_(TR)_-_3_Prova_Circuito_Naz.le_Master/index.php?a=SP&s=M&c=7&f=clafinale',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    311,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-EPEE-2023-2024'),
    7,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-EPEE-2023-2024'),
    11,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-EPEE-2023-2024'),
    51,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
-- Compute scores for PEW7-V2-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-EPEE-2023-2024')
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
    'PEW8-V2-M-EPEE-2023-2024',
    'EVF Grand Prix 8 — Guildford',
    'PEW',
    'EPEE', 'M', 'V2',
    '2024-01-06', 48, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-EPEE-2023-2024'),
    3,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-EPEE-2023-2024'),
    19,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-EPEE-2023-2024'),
    32,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
-- Compute scores for PEW8-V2-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-EPEE-2023-2024')
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
    'PEW9-V2-M-EPEE-2023-2024',
    'EVF Grand Prix 9 — Sztokholm',
    'PEW',
    'EPEE', 'M', 'V2',
    '2024-02-24', 24, 'https://engarde-service.com/competition/sthlm/efv2024/emv2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW9-V2-M-EPEE-2023-2024'),
    1,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW9-V2-M-EPEE-2023-2024'),
    16,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW9-V2-M-EPEE-2023-2024'),
    19,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
-- Compute scores for PEW9-V2-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW9-V2-M-EPEE-2023-2024')
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
    'PEW11-V2-M-EPEE-2023-2024',
    'EVF Grand Prix 11 — Gdańsk',
    'PEW',
    'EPEE', 'M', 'V2',
    '2024-04-06', 25, 'https://www.veteransfencing.eu/fencing/rankings/',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    104,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-M-EPEE-2023-2024'),
    1,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-M-EPEE-2023-2024'),
    2,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-M-EPEE-2023-2024'),
    3,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    311,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-M-EPEE-2023-2024'),
    5,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    309,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-M-EPEE-2023-2024'),
    11,
    'ZAWALICH Leszek'
); -- matched: ZAWALICH Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    103,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-M-EPEE-2023-2024'),
    13,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    50,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-M-EPEE-2023-2024'),
    14,
    'DUDEK Mariusz'
); -- matched: DUDEK Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-M-EPEE-2023-2024'),
    16,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-M-EPEE-2023-2024'),
    18,
    'SKOCZEK Artur'
); -- matched: SKOCZEK Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    264,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-M-EPEE-2023-2024'),
    19,
    'SZKODA Marek Tomasz'
); -- matched: SZKODA Marek Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-M-EPEE-2023-2024'),
    21,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-M-EPEE-2023-2024'),
    24,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
-- Compute scores for PEW11-V2-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-M-EPEE-2023-2024')
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
    'PEW12-V2-M-EPEE-2023-2024',
    'EVF Grand Prix 12 — Ateny',
    'PEW',
    'EPEE', 'M', 'V2',
    '2024-04-27', 27, 'https://www.veteransfencing.eu/fencing/rankings/',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW12-V2-M-EPEE-2023-2024'),
    2,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    103,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW12-V2-M-EPEE-2023-2024'),
    12,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW12-V2-M-EPEE-2023-2024'),
    15,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW12-V2-M-EPEE-2023-2024'),
    23,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
-- Compute scores for PEW12-V2-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW12-V2-M-EPEE-2023-2024')
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
    'IMEW-V2-M-EPEE-2023-2024',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'EPEE', 'M', 'V2',
    '2023-01-01', 224, 'https://engarde-service.com/competition/e3f/efcv/menepeev2',
    'SCORED'
);
-- SKIPPED (international, no master data): 'PEYRET LACOMBE' place=1
-- SKIPPED (international, no master data): 'VICHI' place=2
-- SKIPPED (international, no master data): 'CRESPELLE' place=3
-- SKIPPED (international, no master data): 'MARCHET' place=3
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    311,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2023-2024'),
    5,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    9,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2023-2024'),
    6,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
-- SKIPPED (international, no master data): 'SERGUN' place=7
-- SKIPPED (international, no master data): 'TRUETZSCHLER' place=8
-- SKIPPED (international, no master data): 'FRITSCH' place=9
-- SKIPPED (international, no master data): 'WACQUEZ' place=10
-- SKIPPED (international, no master data): 'JOUVE' place=11
-- SKIPPED (international, no master data): 'AYANWALE' place=12
-- SKIPPED (international, no master data): 'CONRAD' place=13
-- SKIPPED (international, no master data): 'GRAND D''HAUTEVILLE' place=14
-- SKIPPED (international, no master data): 'HAYEK' place=15
-- SKIPPED (international, no master data): 'HOWSER' place=16
-- SKIPPED (international, no master data): 'HESS' place=17
-- SKIPPED (international, no master data): 'ALLEN' place=18
-- SKIPPED (international, no master data): 'LESNE' place=19
-- SKIPPED (international, no master data): 'ZURABISHVILI' place=20
-- SKIPPED (international, no master data): 'ELMFELDT' place=21
-- SKIPPED (international, no master data): 'RONDIN' place=22
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2023-2024'),
    23,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
-- SKIPPED (international, no master data): 'PRADON' place=24
-- SKIPPED (international, no master data): 'COLLING' place=25
-- SKIPPED (international, no master data): 'CICOIRA' place=26
-- SKIPPED (international, no master data): 'GIRIN' place=27
-- SKIPPED (international, no master data): 'CHAUVAT' place=28
-- SKIPPED (international, no master data): 'WÄLLE' place=29
-- SKIPPED (international, no master data): 'SZAKMARY' place=30
-- SKIPPED (international, no master data): 'KAEMPER' place=31
-- SKIPPED (international, no master data): 'MAGHON' place=32
-- SKIPPED (international, no master data): 'BAHLKE' place=33
-- SKIPPED (international, no master data): 'BRUDY-ZIPPELIUS' place=34
-- SKIPPED (international, no master data): 'FEZARD' place=35
-- SKIPPED (international, no master data): 'GRANJON' place=36
-- SKIPPED (international, no master data): 'CARACCIOLO' place=37
-- SKIPPED (international, no master data): 'WALLE' place=38
-- SKIPPED (international, no master data): 'FREMALLE' place=39
-- SKIPPED (international, no master data): 'PULEGA' place=40
-- SKIPPED (international, no master data): 'LE TREUT' place=41
-- SKIPPED (international, no master data): 'RUMETSCH' place=42
-- SKIPPED (international, no master data): 'WENDT' place=43
-- SKIPPED (international, no master data): 'EYQUEM' place=44
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    155,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2023-2024'),
    45,
    'LEAHEY'
); -- matched: LEAHEY John (score=70.58823529411764)
-- SKIPPED (international, no master data): 'DELMAS' place=46
-- SKIPPED (international, no master data): 'LAMOTHE' place=47
-- SKIPPED (international, no master data): 'SMEYERS' place=48
-- SKIPPED (international, no master data): 'GUY' place=49
-- SKIPPED (international, no master data): 'SZALAY' place=50
-- SKIPPED (international, no master data): 'TSIMERINOV' place=51
-- SKIPPED (international, no master data): 'KLASS' place=52
-- SKIPPED (international, no master data): 'PIRANI' place=53
-- SKIPPED (international, no master data): 'ELLISON' place=54
-- SKIPPED (international, no master data): 'CHRISTENSEN' place=55
-- SKIPPED (international, no master data): 'LARSSON' place=56
-- SKIPPED (international, no master data): 'GOETTMANN' place=57
-- SKIPPED (international, no master data): 'LINOW' place=58
-- SKIPPED (international, no master data): 'MARHEINEKE' place=59
-- SKIPPED (international, no master data): 'WAFFELAERT' place=60
-- SKIPPED (international, no master data): 'PIRA' place=61
-- SKIPPED (international, no master data): 'LAHTI' place=62
-- SKIPPED (international, no master data): 'GUILLEMIER' place=63
-- SKIPPED (international, no master data): 'PORTMANN' place=64
-- SKIPPED (international, no master data): 'DUCROCQ' place=65
-- SKIPPED (international, no master data): 'SCHUELER' place=66
-- SKIPPED (international, no master data): 'LOUE' place=67
-- SKIPPED (international, no master data): 'NANI' place=68
-- SKIPPED (international, no master data): 'JILEK' place=69
-- SKIPPED (international, no master data): 'FARGEOT' place=70
-- SKIPPED (international, no master data): 'SPADARO' place=71
-- SKIPPED (international, no master data): 'FOUCO' place=72
-- SKIPPED (international, no master data): 'HINZ' place=73
-- SKIPPED (international, no master data): 'BOYKOV' place=74
-- SKIPPED (international, no master data): 'JARSETZ' place=75
-- SKIPPED (international, no master data): 'STRICKER' place=76
-- SKIPPED (international, no master data): 'BUSSY' place=77
-- SKIPPED (international, no master data): 'MELNIKOV' place=78
-- SKIPPED (international, no master data): 'CALAMBE' place=79
-- SKIPPED (international, no master data): 'GARCIA' place=80
-- SKIPPED (international, no master data): 'DANIELSON' place=81
-- SKIPPED (international, no master data): 'LE CHEVALLIER' place=82
-- SKIPPED (international, no master data): 'DALLA GIOVANNA' place=83
-- SKIPPED (international, no master data): 'HIRNER' place=84
-- SKIPPED (international, no master data): 'GOMEZ PAZ' place=85
-- SKIPPED (international, no master data): 'HOYER' place=86
-- SKIPPED (international, no master data): 'STANCIU' place=87
-- SKIPPED (international, no master data): 'MAIWALD' place=88
-- SKIPPED (international, no master data): 'BOUGEARD' place=89
-- SKIPPED (international, no master data): 'GARCIA CALDERON' place=90
-- SKIPPED (international, no master data): 'MARBEUF' place=91
-- SKIPPED (international, no master data): 'BESSEMOULIN' place=92
-- SKIPPED (international, no master data): 'LECORRE' place=93
-- SKIPPED (international, no master data): 'BIJKER' place=94
-- SKIPPED (international, no master data): 'KAMANY' place=95
-- SKIPPED (international, no master data): 'EVERTZ' place=96
-- SKIPPED (international, no master data): 'EGGERMONT' place=97
-- SKIPPED (international, no master data): 'DELIEGE' place=98
-- SKIPPED (international, no master data): 'KANASHENKOV' place=99
-- SKIPPED (international, no master data): 'FOTH' place=100
-- SKIPPED (international, no master data): 'PRIME' place=101
-- SKIPPED (international, no master data): 'BERNARD' place=102
-- SKIPPED (international, no master data): 'CARADANT' place=103
-- SKIPPED (international, no master data): 'BROCVIELLE' place=104
-- SKIPPED (international, no master data): 'ABASSI' place=105
-- SKIPPED (international, no master data): 'VANDIEKEN' place=106
-- SKIPPED (international, no master data): 'REZE' place=107
-- SKIPPED (international, no master data): 'KOEMETS' place=108
-- SKIPPED (international, no master data): 'DIDASKALOU' place=109
-- SKIPPED (international, no master data): 'PINK' place=110
-- SKIPPED (international, no master data): 'FOURTAUX' place=111
-- SKIPPED (international, no master data): 'DEBURGH' place=112
-- SKIPPED (international, no master data): 'WOITAS' place=113
-- SKIPPED (international, no master data): 'NGUYEN QUANG' place=114
-- SKIPPED (international, no master data): 'VAN LAECKE' place=115
-- SKIPPED (international, no master data): 'KLIMKIN' place=116
-- SKIPPED (international, no master data): 'BILLING' place=117
-- SKIPPED (international, no master data): 'BERNERON' place=118
-- SKIPPED (international, no master data): 'HUNDERTMARK' place=119
-- SKIPPED (international, no master data): 'GROSSE' place=120
-- SKIPPED (international, no master data): 'JANET' place=121
-- SKIPPED (international, no master data): 'BENITAH' place=122
-- SKIPPED (international, no master data): 'MOISI' place=123
-- SKIPPED (international, no master data): 'GRASSET' place=124
-- SKIPPED (international, no master data): 'BOSSI' place=125
-- SKIPPED (international, no master data): 'KUJAWA' place=126
-- SKIPPED (international, no master data): 'GUERIN' place=127
-- SKIPPED (international, no master data): 'MAYSAMI' place=128
-- SKIPPED (international, no master data): 'BERGER' place=129
-- SKIPPED (international, no master data): 'AUTZEN' place=130
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2023-2024'),
    131,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
-- SKIPPED (international, no master data): 'TULUMELLO' place=132
-- SKIPPED (international, no master data): 'MATYAS' place=133
-- SKIPPED (international, no master data): 'DAHLSTEN' place=134
-- SKIPPED (international, no master data): 'TISSIER' place=135
-- SKIPPED (international, no master data): 'TRAKHTENBERG' place=136
-- SKIPPED (international, no master data): 'MELO' place=137
-- SKIPPED (international, no master data): 'ESSNER' place=138
-- SKIPPED (international, no master data): 'TRUET' place=139
-- SKIPPED (international, no master data): 'HILSE' place=140
-- SKIPPED (international, no master data): 'KIRNBAUER' place=141
-- SKIPPED (international, no master data): 'BRENDLE' place=142
-- SKIPPED (international, no master data): 'KNOBELSDORF' place=143
-- SKIPPED (international, no master data): 'THIELEMANS' place=144
-- SKIPPED (international, no master data): 'MARCHAL' place=145
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    140,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2023-2024'),
    146,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
-- SKIPPED (international, no master data): 'BAKER' place=147
-- SKIPPED (international, no master data): 'WEBERG' place=148
-- SKIPPED (international, no master data): 'SWENNING' place=149
-- SKIPPED (international, no master data): 'VALLETTE VIALLARD' place=150
-- SKIPPED (international, no master data): 'BEHR' place=151
-- SKIPPED (international, no master data): 'RODARY' place=152
-- SKIPPED (international, no master data): 'SPICER' place=153
-- SKIPPED (international, no master data): 'TELLIER' place=154
-- SKIPPED (international, no master data): 'ZOSEL' place=155
-- SKIPPED (international, no master data): 'BARDELOT' place=156
-- SKIPPED (international, no master data): 'IWERSEN' place=157
-- SKIPPED (international, no master data): 'LEDENT' place=158
-- SKIPPED (international, no master data): 'AUERBACH' place=159
-- SKIPPED (international, no master data): 'LEONCINI BARTOLI' place=160
-- SKIPPED (international, no master data): 'VOSSENBERG' place=161
-- SKIPPED (international, no master data): 'WILLMOTT' place=162
-- SKIPPED (international, no master data): 'ROUL' place=163
-- SKIPPED (international, no master data): 'AIRPACH' place=164
-- SKIPPED (international, no master data): 'FLAMME' place=165
-- SKIPPED (international, no master data): 'GOUFFE' place=166
-- SKIPPED (international, no master data): 'DEUTSCH' place=167
-- SKIPPED (international, no master data): 'SANDGREN' place=168
-- SKIPPED (international, no master data): 'HELL' place=169
-- SKIPPED (international, no master data): 'KORZH' place=170
-- SKIPPED (international, no master data): 'HAZLEWOOD' place=171
-- SKIPPED (international, no master data): 'KESKINIVA' place=172
-- SKIPPED (international, no master data): 'SALONIKIDIS' place=173
-- SKIPPED (international, no master data): 'VETILLARD' place=174
-- SKIPPED (international, no master data): 'DEMARLY' place=175
-- SKIPPED (international, no master data): 'KLOBES' place=176
-- SKIPPED (international, no master data): 'WINTER' place=177
-- SKIPPED (international, no master data): 'MARCAILLOU' place=178
-- SKIPPED (international, no master data): 'QUINON' place=179
-- SKIPPED (international, no master data): 'AKSONOV' place=180
-- SKIPPED (international, no master data): 'STRAT' place=181
-- SKIPPED (international, no master data): 'VON GEIJER' place=182
-- SKIPPED (international, no master data): 'EZAMA TOLEDO' place=183
-- SKIPPED (international, no master data): 'FLOCH' place=184
-- SKIPPED (international, no master data): 'VICTORY' place=185
-- SKIPPED (international, no master data): 'OCSAI' place=186
-- SKIPPED (international, no master data): 'HELSPER' place=187
-- SKIPPED (international, no master data): 'ARTEAGA QUINTANA' place=188
-- SKIPPED (international, no master data): 'ORLANDO' place=189
-- SKIPPED (international, no master data): 'HOUDEBERT' place=190
-- SKIPPED (international, no master data): 'ZINAI' place=191
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2023-2024'),
    192,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
-- SKIPPED (international, no master data): 'GAUTIER' place=193
-- SKIPPED (international, no master data): 'RANKL' place=194
-- SKIPPED (international, no master data): 'SOUCHOIS' place=195
-- SKIPPED (international, no master data): 'WIMAN' place=196
-- SKIPPED (international, no master data): 'BEZARD FALGAS' place=197
-- SKIPPED (international, no master data): 'HAEMMERLE' place=198
-- SKIPPED (international, no master data): 'SICART' place=199
-- SKIPPED (international, no master data): 'MILDE' place=200
-- SKIPPED (international, no master data): 'BADEA' place=201
-- SKIPPED (international, no master data): 'SEFRIN' place=202
-- SKIPPED (international, no master data): 'SHUQAIR' place=203
-- SKIPPED (international, no master data): 'GROSSETETE' place=204
-- SKIPPED (international, no master data): 'RESCHKO' place=205
-- SKIPPED (international, no master data): 'RODRIGUEZ SANCHEZ' place=206
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    203,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2023-2024'),
    207,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
-- SKIPPED (international, no master data): 'GARNIER' place=208
-- SKIPPED (international, no master data): 'GARCIA' place=209
-- SKIPPED (international, no master data): 'HASSINGER' place=210
-- SKIPPED (international, no master data): 'PURGINA' place=211
-- SKIPPED (international, no master data): 'MULLER' place=212
-- SKIPPED (international, no master data): 'GUILLOIR' place=213
-- SKIPPED (international, no master data): 'CWIKLA' place=214
-- SKIPPED (international, no master data): 'BRAMBILLA' place=215
-- SKIPPED (international, no master data): 'FELLMANN' place=216
-- SKIPPED (international, no master data): 'FOUILLARD' place=217
-- SKIPPED (international, no master data): 'GHIGLIANI' place=218
-- SKIPPED (international, no master data): 'LEGRAND' place=219
-- SKIPPED (international, no master data): 'GURI LOPEZ' place=220
-- SKIPPED (international, no master data): 'LUCREZI' place=221
-- SKIPPED (international, no master data): 'NORRBY' place=222
-- SKIPPED (international, no master data): 'SIMON' place=223
-- SKIPPED (international, no master data): 'MAZZONI' place=224
-- Compute scores for IMEW-V2-M-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2023-2024')
);

-- Summary
-- Total results matched:   160
-- Total results unmatched: 216
-- Total auto-created:      0
