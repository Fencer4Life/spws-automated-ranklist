-- =========================================================================
-- Season 2023-2024 — V2 M EPEE — sourced from SZPADA-2-2024-2025.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- Note: Event codes retain original '-2023-2024' suffix; only season FK updated.
-- =========================================================================

-- ---- GP7: Grand Prix (runda 7) (SPAŁA) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
VALUES (
    'GP7-2023-2024',
    'Grand Prix (runda 7)',
    'SPAŁA',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
);
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
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-EPEE-2023-2024'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    96,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-EPEE-2023-2024'),
    2,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    266,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-EPEE-2023-2024'),
    3,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    121,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-EPEE-2023-2024'),
    4,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    95,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-EPEE-2023-2024'),
    5,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-EPEE-2023-2024'),
    6,
    'WIERZBICKI JACEK'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    258,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-EPEE-2023-2024'),
    7,
    'WOJTAS Bogdan'
); -- matched: WOJTAS Bogdan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    210,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-EPEE-2023-2024'),
    8,
    'SKOCZEK Artur'
); -- matched: SKOCZEK Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-EPEE-2023-2024'),
    9,
    'KOTERSKI Paweł'
); -- matched: KOTERSKI Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-EPEE-2023-2024'),
    10,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    236,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-EPEE-2023-2024'),
    11,
    'TRACZ Jerzy'
); -- matched: TRACZ Jerzy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    269,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-EPEE-2023-2024'),
    12,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    181,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-EPEE-2023-2024'),
    13,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
-- Compute scores for GP7-V2-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-M-EPEE-2023-2024')
);

-- ---- GP8: Grand Prix (runda 8) (NIEPOŁOMICE) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
VALUES (
    'GP8-2023-2024',
    'Grand Prix (runda 8)',
    'NIEPOŁOMICE',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
);
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
    96,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-EPEE-2023-2024'),
    1,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    266,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-EPEE-2023-2024'),
    2,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    121,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-EPEE-2023-2024'),
    3,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    86,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-EPEE-2023-2024'),
    4,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-EPEE-2023-2024'),
    5,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    83,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-EPEE-2023-2024'),
    6,
    'GWIAZDA Paweł'
); -- matched: GWIAZDA Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    210,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-EPEE-2023-2024'),
    7,
    'SKOCZEK Artur'
); -- matched: SKOCZEK Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    269,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-EPEE-2023-2024'),
    8,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-EPEE-2023-2024'),
    9,
    'WIERZBICKI JACEK'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    181,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-EPEE-2023-2024'),
    11,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
-- Compute scores for GP8-V2-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-M-EPEE-2023-2024')
);

-- ---- MPW: Mistrzostwa Polski Weteranów (WARSZAWA) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
VALUES (
    'MPW-2023-2024',
    'Mistrzostwa Polski Weteranów',
    'WARSZAWA',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
);
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
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    96,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024'),
    2,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    266,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024'),
    3,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    121,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024'),
    4,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    169,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024'),
    5,
    'OLSZEWSKI Mikołaj'
); -- matched: OLSZEWSKI Mikołaj (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    86,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024'),
    6,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    258,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024'),
    7,
    'WOJTAS Bogdan'
); -- matched: WOJTAS Bogdan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024'),
    8,
    'DUDEK Mariusz'
); -- matched: DUDEK Mariusz (score=100.0)
-- UNMATCHED (score<80): 'SZKODA Marek Tomasz' place=9
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024'),
    10,
    'WIERZBICKI JACEK'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    236,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024'),
    11,
    'TRACZ Jerzy'
); -- matched: TRACZ Jerzy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    210,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024'),
    12,
    'SKOCZEK Artur'
); -- matched: SKOCZEK Artur (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024'),
    13,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    181,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024'),
    15,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
-- Compute scores for MPW-V2-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-2023-2024')
);

-- ---- PEW7: EVF Grand Prix 7 — Terni (Terni) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
VALUES (
    'PEW7-2023-2024',
    'EVF Grand Prix 7 — Terni',
    'Terni',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
);
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
    266,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-EPEE-2023-2024'),
    7,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    121,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-EPEE-2023-2024'),
    11,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-EPEE-2023-2024'),
    51,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
-- Compute scores for PEW7-V2-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-EPEE-2023-2024')
);

-- ---- PEW8: EVF Grand Prix 8 — Guildford (Guildford) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
VALUES (
    'PEW8-2023-2024',
    'EVF Grand Prix 8 — Guildford',
    'Guildford',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
);
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
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-EPEE-2023-2024'),
    3,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    121,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-EPEE-2023-2024'),
    19,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-EPEE-2023-2024'),
    32,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
-- Compute scores for PEW8-V2-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-EPEE-2023-2024')
);

-- ---- PEW9: EVF Grand Prix 9 — Sztokholm (Stockholm (SWE)) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
VALUES (
    'PEW9-2023-2024',
    'EVF Grand Prix 9 — Sztokholm',
    'Stockholm (SWE)',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
);
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
    121,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW9-V2-M-EPEE-2023-2024'),
    1,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW9-V2-M-EPEE-2023-2024'),
    16,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW9-V2-M-EPEE-2023-2024'),
    19,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
-- Compute scores for PEW9-V2-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW9-V2-M-EPEE-2023-2024')
);

-- SKIP PEW10 (EVF Grand Prix 10 — Graz): N=0 — tournament had no participants

-- ---- PEW11: EVF Grand Prix 11 — Gdańsk (Gdańsk (POL)) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
VALUES (
    'PEW11-2023-2024',
    'EVF Grand Prix 11 — Gdańsk',
    'Gdańsk (POL)',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
);
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
    96,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-M-EPEE-2023-2024'),
    1,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-M-EPEE-2023-2024'),
    2,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    121,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-M-EPEE-2023-2024'),
    3,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    266,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-M-EPEE-2023-2024'),
    5,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    264,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-M-EPEE-2023-2024'),
    11,
    'ZAWALICH Leszek'
); -- matched: ZAWALICH Leszek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    95,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-M-EPEE-2023-2024'),
    13,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-M-EPEE-2023-2024'),
    14,
    'DUDEK Mariusz'
); -- matched: DUDEK Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    86,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-M-EPEE-2023-2024'),
    16,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    210,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-M-EPEE-2023-2024'),
    18,
    'SKOCZEK Artur'
); -- matched: SKOCZEK Artur (score=100.0)
-- UNMATCHED (score<80): 'SZKODA Marek Tomasz' place=19
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-M-EPEE-2023-2024'),
    21,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-M-EPEE-2023-2024'),
    24,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    181,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-M-EPEE-2023-2024'),
    27,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100.0)
-- Compute scores for PEW11-V2-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-M-EPEE-2023-2024')
);

-- ---- PEW12: EVF Grand Prix 12 — Ateny (Ateny (GRE)) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
VALUES (
    'PEW12-2023-2024',
    'EVF Grand Prix 12 — Ateny',
    'Ateny (GRE)',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
);
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
    121,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW12-V2-M-EPEE-2023-2024'),
    2,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    95,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW12-V2-M-EPEE-2023-2024'),
    12,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW12-V2-M-EPEE-2023-2024'),
    15,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW12-V2-M-EPEE-2023-2024'),
    23,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
-- Compute scores for PEW12-V2-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW12-V2-M-EPEE-2023-2024')
);

-- ---- IMEW: Indywidualne Mistrzostwa Europy Weteranów (Thionville) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
VALUES (
    'IMEW-2023-2024',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'Thionville',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
);
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
-- UNMATCHED (score<80): 'PEYRET LACOMBE' place=1
-- UNMATCHED (score<80): 'VICHI' place=2
-- UNMATCHED (score<80): 'CRESPELLE' place=3
-- UNMATCHED (score<80): 'MARCHET' place=3
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    266,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2023-2024'),
    5,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2023-2024'),
    6,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100.0)
-- UNMATCHED (score<80): 'SERGUN' place=7
-- UNMATCHED (score<80): 'TRUETZSCHLER' place=8
-- UNMATCHED (score<80): 'FRITSCH' place=9
-- UNMATCHED (score<80): 'WACQUEZ' place=10
-- UNMATCHED (score<80): 'JOUVE' place=11
-- UNMATCHED (score<80): 'AYANWALE' place=12
-- UNMATCHED (score<80): 'CONRAD' place=13
-- UNMATCHED (score<80): 'GRAND D''HAUTEVILLE' place=14
-- UNMATCHED (score<80): 'HAYEK' place=15
-- UNMATCHED (score<80): 'HOWSER' place=16
-- UNMATCHED (score<80): 'HESS' place=17
-- UNMATCHED (score<80): 'ALLEN' place=18
-- UNMATCHED (score<80): 'LESNE' place=19
-- UNMATCHED (score<80): 'ZURABISHVILI' place=20
-- UNMATCHED (score<80): 'ELMFELDT' place=21
-- UNMATCHED (score<80): 'RONDIN' place=22
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    121,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2023-2024'),
    23,
    'KOSTRZEWA Ireneusz'
); -- matched: KOSTRZEWA Ireneusz (score=100.0)
-- UNMATCHED (score<80): 'PRADON' place=24
-- UNMATCHED (score<80): 'COLLING' place=25
-- UNMATCHED (score<80): 'CICOIRA' place=26
-- UNMATCHED (score<80): 'GIRIN' place=27
-- UNMATCHED (score<80): 'CHAUVAT' place=28
-- UNMATCHED (score<80): 'WÄLLE' place=29
-- UNMATCHED (score<80): 'SZAKMARY' place=30
-- UNMATCHED (score<80): 'KAEMPER' place=31
-- UNMATCHED (score<80): 'MAGHON' place=32
-- UNMATCHED (score<80): 'BAHLKE' place=33
-- UNMATCHED (score<80): 'BRUDY-ZIPPELIUS' place=34
-- UNMATCHED (score<80): 'FEZARD' place=35
-- UNMATCHED (score<80): 'GRANJON' place=36
-- UNMATCHED (score<80): 'CARACCIOLO' place=37
-- UNMATCHED (score<80): 'WALLE' place=38
-- UNMATCHED (score<80): 'FREMALLE' place=39
-- UNMATCHED (score<80): 'PULEGA' place=40
-- UNMATCHED (score<80): 'LE TREUT' place=41
-- UNMATCHED (score<80): 'RUMETSCH' place=42
-- UNMATCHED (score<80): 'WENDT' place=43
-- UNMATCHED (score<80): 'EYQUEM' place=44
-- UNMATCHED (score<80): 'LEAHEY' place=45
-- UNMATCHED (score<80): 'DELMAS' place=46
-- UNMATCHED (score<80): 'LAMOTHE' place=47
-- UNMATCHED (score<80): 'SMEYERS' place=48
-- UNMATCHED (score<80): 'GUY' place=49
-- UNMATCHED (score<80): 'SZALAY' place=50
-- UNMATCHED (score<80): 'TSIMERINOV' place=51
-- UNMATCHED (score<80): 'KLASS' place=52
-- UNMATCHED (score<80): 'PIRANI' place=53
-- UNMATCHED (score<80): 'ELLISON' place=54
-- UNMATCHED (score<80): 'CHRISTENSEN' place=55
-- UNMATCHED (score<80): 'LARSSON' place=56
-- UNMATCHED (score<80): 'GOETTMANN' place=57
-- UNMATCHED (score<80): 'LINOW' place=58
-- UNMATCHED (score<80): 'MARHEINEKE' place=59
-- UNMATCHED (score<80): 'WAFFELAERT' place=60
-- UNMATCHED (score<80): 'PIRA' place=61
-- UNMATCHED (score<80): 'LAHTI' place=62
-- UNMATCHED (score<80): 'GUILLEMIER' place=63
-- UNMATCHED (score<80): 'PORTMANN' place=64
-- UNMATCHED (score<80): 'DUCROCQ' place=65
-- UNMATCHED (score<80): 'SCHUELER' place=66
-- UNMATCHED (score<80): 'LOUE' place=67
-- UNMATCHED (score<80): 'NANI' place=68
-- UNMATCHED (score<80): 'JILEK' place=69
-- UNMATCHED (score<80): 'FARGEOT' place=70
-- UNMATCHED (score<80): 'SPADARO' place=71
-- UNMATCHED (score<80): 'FOUCO' place=72
-- UNMATCHED (score<80): 'HINZ' place=73
-- UNMATCHED (score<80): 'BOYKOV' place=74
-- UNMATCHED (score<80): 'JARSETZ' place=75
-- UNMATCHED (score<80): 'STRICKER' place=76
-- UNMATCHED (score<80): 'BUSSY' place=77
-- UNMATCHED (score<80): 'MELNIKOV' place=78
-- UNMATCHED (score<80): 'CALAMBE' place=79
-- UNMATCHED (score<80): 'GARCIA' place=80
-- UNMATCHED (score<80): 'DANIELSON' place=81
-- UNMATCHED (score<80): 'LE CHEVALLIER' place=82
-- UNMATCHED (score<80): 'DALLA GIOVANNA' place=83
-- UNMATCHED (score<80): 'HIRNER' place=84
-- UNMATCHED (score<80): 'GOMEZ PAZ' place=85
-- UNMATCHED (score<80): 'HOYER' place=86
-- UNMATCHED (score<80): 'STANCIU' place=87
-- UNMATCHED (score<80): 'MAIWALD' place=88
-- UNMATCHED (score<80): 'BOUGEARD' place=89
-- UNMATCHED (score<80): 'GARCIA CALDERON' place=90
-- UNMATCHED (score<80): 'MARBEUF' place=91
-- UNMATCHED (score<80): 'BESSEMOULIN' place=92
-- UNMATCHED (score<80): 'LECORRE' place=93
-- UNMATCHED (score<80): 'BIJKER' place=94
-- UNMATCHED (score<80): 'KAMANY' place=95
-- UNMATCHED (score<80): 'EVERTZ' place=96
-- UNMATCHED (score<80): 'EGGERMONT' place=97
-- UNMATCHED (score<80): 'DELIEGE' place=98
-- UNMATCHED (score<80): 'KANASHENKOV' place=99
-- UNMATCHED (score<80): 'FOTH' place=100
-- UNMATCHED (score<80): 'PRIME' place=101
-- UNMATCHED (score<80): 'BERNARD' place=102
-- UNMATCHED (score<80): 'CARADANT' place=103
-- UNMATCHED (score<80): 'BROCVIELLE' place=104
-- UNMATCHED (score<80): 'ABASSI' place=105
-- UNMATCHED (score<80): 'VANDIEKEN' place=106
-- UNMATCHED (score<80): 'REZE' place=107
-- UNMATCHED (score<80): 'KOEMETS' place=108
-- UNMATCHED (score<80): 'DIDASKALOU' place=109
-- UNMATCHED (score<80): 'PINK' place=110
-- UNMATCHED (score<80): 'FOURTAUX' place=111
-- UNMATCHED (score<80): 'DEBURGH' place=112
-- UNMATCHED (score<80): 'WOITAS' place=113
-- UNMATCHED (score<80): 'NGUYEN QUANG' place=114
-- UNMATCHED (score<80): 'VAN LAECKE' place=115
-- UNMATCHED (score<80): 'KLIMKIN' place=116
-- UNMATCHED (score<80): 'BILLING' place=117
-- UNMATCHED (score<80): 'BERNERON' place=118
-- UNMATCHED (score<80): 'HUNDERTMARK' place=119
-- UNMATCHED (score<80): 'GROSSE' place=120
-- UNMATCHED (score<80): 'JANET' place=121
-- UNMATCHED (score<80): 'BENITAH' place=122
-- UNMATCHED (score<80): 'MOISI' place=123
-- UNMATCHED (score<80): 'GRASSET' place=124
-- UNMATCHED (score<80): 'BOSSI' place=125
-- UNMATCHED (score<80): 'KUJAWA' place=126
-- UNMATCHED (score<80): 'GUERIN' place=127
-- UNMATCHED (score<80): 'MAYSAMI' place=128
-- UNMATCHED (score<80): 'BERGER' place=129
-- UNMATCHED (score<80): 'AUTZEN' place=130
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    42,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2023-2024'),
    131,
    'DRAPELLA Maciej'
); -- matched: DRAPELLA Maciej (score=100.0)
-- UNMATCHED (score<80): 'TULUMELLO' place=132
-- UNMATCHED (score<80): 'MATYAS' place=133
-- UNMATCHED (score<80): 'DAHLSTEN' place=134
-- UNMATCHED (score<80): 'TISSIER' place=135
-- UNMATCHED (score<80): 'TRAKHTENBERG' place=136
-- UNMATCHED (score<80): 'MELO' place=137
-- UNMATCHED (score<80): 'ESSNER' place=138
-- UNMATCHED (score<80): 'TRUET' place=139
-- UNMATCHED (score<80): 'HILSE' place=140
-- UNMATCHED (score<80): 'KIRNBAUER' place=141
-- UNMATCHED (score<80): 'BRENDLE' place=142
-- UNMATCHED (score<80): 'KNOBELSDORF' place=143
-- UNMATCHED (score<80): 'THIELEMANS' place=144
-- UNMATCHED (score<80): 'MARCHAL' place=145
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2023-2024'),
    146,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
-- UNMATCHED (score<80): 'BAKER' place=147
-- UNMATCHED (score<80): 'WEBERG' place=148
-- UNMATCHED (score<80): 'SWENNING' place=149
-- UNMATCHED (score<80): 'VALLETTE VIALLARD' place=150
-- UNMATCHED (score<80): 'BEHR' place=151
-- UNMATCHED (score<80): 'RODARY' place=152
-- UNMATCHED (score<80): 'SPICER' place=153
-- UNMATCHED (score<80): 'TELLIER' place=154
-- UNMATCHED (score<80): 'ZOSEL' place=155
-- UNMATCHED (score<80): 'BARDELOT' place=156
-- UNMATCHED (score<80): 'IWERSEN' place=157
-- UNMATCHED (score<80): 'LEDENT' place=158
-- UNMATCHED (score<80): 'AUERBACH' place=159
-- UNMATCHED (score<80): 'LEONCINI BARTOLI' place=160
-- UNMATCHED (score<80): 'VOSSENBERG' place=161
-- UNMATCHED (score<80): 'WILLMOTT' place=162
-- UNMATCHED (score<80): 'ROUL' place=163
-- UNMATCHED (score<80): 'AIRPACH' place=164
-- UNMATCHED (score<80): 'FLAMME' place=165
-- UNMATCHED (score<80): 'GOUFFE' place=166
-- UNMATCHED (score<80): 'DEUTSCH' place=167
-- UNMATCHED (score<80): 'SANDGREN' place=168
-- UNMATCHED (score<80): 'HELL' place=169
-- UNMATCHED (score<80): 'KORZH' place=170
-- UNMATCHED (score<80): 'HAZLEWOOD' place=171
-- UNMATCHED (score<80): 'KESKINIVA' place=172
-- UNMATCHED (score<80): 'SALONIKIDIS' place=173
-- UNMATCHED (score<80): 'VETILLARD' place=174
-- UNMATCHED (score<80): 'DEMARLY' place=175
-- UNMATCHED (score<80): 'KLOBES' place=176
-- UNMATCHED (score<80): 'WINTER' place=177
-- UNMATCHED (score<80): 'MARCAILLOU' place=178
-- UNMATCHED (score<80): 'QUINON' place=179
-- UNMATCHED (score<80): 'AKSONOV' place=180
-- UNMATCHED (score<80): 'STRAT' place=181
-- UNMATCHED (score<80): 'VON GEIJER' place=182
-- UNMATCHED (score<80): 'EZAMA TOLEDO' place=183
-- UNMATCHED (score<80): 'FLOCH' place=184
-- UNMATCHED (score<80): 'VICTORY' place=185
-- UNMATCHED (score<80): 'OCSAI' place=186
-- UNMATCHED (score<80): 'HELSPER' place=187
-- UNMATCHED (score<80): 'ARTEAGA QUINTANA' place=188
-- UNMATCHED (score<80): 'ORLANDO' place=189
-- UNMATCHED (score<80): 'HOUDEBERT' place=190
-- UNMATCHED (score<80): 'ZINAI' place=191
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2023-2024'),
    192,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
-- UNMATCHED (score<80): 'GAUTIER' place=193
-- UNMATCHED (score<80): 'RANKL' place=194
-- UNMATCHED (score<80): 'SOUCHOIS' place=195
-- UNMATCHED (score<80): 'WIMAN' place=196
-- UNMATCHED (score<80): 'BEZARD FALGAS' place=197
-- UNMATCHED (score<80): 'HAEMMERLE' place=198
-- UNMATCHED (score<80): 'SICART' place=199
-- UNMATCHED (score<80): 'MILDE' place=200
-- UNMATCHED (score<80): 'BADEA' place=201
-- UNMATCHED (score<80): 'SEFRIN' place=202
-- UNMATCHED (score<80): 'SHUQAIR' place=203
-- UNMATCHED (score<80): 'GROSSETETE' place=204
-- UNMATCHED (score<80): 'RESCHKO' place=205
-- UNMATCHED (score<80): 'RODRIGUEZ SANCHEZ' place=206
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    176,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2023-2024'),
    207,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100.0)
-- UNMATCHED (score<80): 'GARNIER' place=208
-- UNMATCHED (score<80): 'GARCIA' place=209
-- UNMATCHED (score<80): 'HASSINGER' place=210
-- UNMATCHED (score<80): 'PURGINA' place=211
-- UNMATCHED (score<80): 'MULLER' place=212
-- UNMATCHED (score<80): 'GUILLOIR' place=213
-- UNMATCHED (score<80): 'CWIKLA' place=214
-- UNMATCHED (score<80): 'BRAMBILLA' place=215
-- UNMATCHED (score<80): 'FELLMANN' place=216
-- UNMATCHED (score<80): 'FOUILLARD' place=217
-- UNMATCHED (score<80): 'GHIGLIANI' place=218
-- UNMATCHED (score<80): 'LEGRAND' place=219
-- UNMATCHED (score<80): 'GURI LOPEZ' place=220
-- UNMATCHED (score<80): 'LUCREZI' place=221
-- UNMATCHED (score<80): 'NORRBY' place=222
-- UNMATCHED (score<80): 'SIMON' place=223
-- UNMATCHED (score<80): 'MAZZONI' place=224
-- Compute scores for IMEW-V2-M-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-2023-2024')
);


-- Summary (historical 2023-24 data, moved from 2024-25 seed)
-- Domestic: GP7, GP8, MPW
-- International: PEW7, PEW8, PEW9, PEW11, PEW12, IMEW
