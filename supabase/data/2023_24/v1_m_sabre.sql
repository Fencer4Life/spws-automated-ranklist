-- =========================================================================
-- Season 2023-2024 — V1 M SABRE — generated from SZABLA-1-2023-2024.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- =========================================================================
-- Auto-created fencers (domestic unmatched — ADR-020)
-- =========================================================================
INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, bool_birth_year_estimated)
SELECT 'FRYDRYCH', 'Aleksander', 1984, TRUE
WHERE NOT EXISTS (
    SELECT 1 FROM tbl_fencer WHERE txt_surname = 'FRYDRYCH' AND txt_first_name = 'Aleksander'
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
    'GP1-V1-M-SABRE-2023-2024',
    'Grand Prix (runda 1)',
    'PPW',
    'SABRE', 'M', 'V1',
    '2023-01-15', 7, 'https://www.fencingtimelive.com/events/results/680F602982164EB9AE4607F6639973E7',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    143,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-SABRE-2023-2024'),
    1,
    'KROCHMALSKI Jakub'
); -- matched: KROCHMALSKI Jakub (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    127,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-SABRE-2023-2024'),
    2,
    'KOSIŃSKI Łukasz'
); -- matched: KOSIŃSKI Łukasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    310,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-SABRE-2023-2024'),
    3,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-SABRE-2023-2024'),
    4,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'FRYDRYCH' AND txt_first_name = 'Aleksander'),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-SABRE-2023-2024'),
    5,
    'FRYDRYCH Aleksander'
); -- auto-created domestic fencer
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    270,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-SABRE-2023-2024'),
    6,
    'SZYMAŃSKI Adam'
); -- matched: SZYMAŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    166,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-SABRE-2023-2024'),
    7,
    'MARASEK Tomasz'
); -- matched: MARASEK Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    76,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-SABRE-2023-2024'),
    9,
    'GRACZYK Bogdan'
); -- matched: GRACZYK Bogdan (score=100.0)
-- Compute scores for GP1-V1-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-M-SABRE-2023-2024')
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
    'GP2-V1-M-SABRE-2023-2024',
    'Grand Prix (runda 2)',
    'PPW',
    'SABRE', 'M', 'V1',
    '2023-03-05', 6, 'https://www.fencingtimelive.com/events/results/FBE9EB0882B44510BC2D01DC754E0A7E',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-SABRE-2023-2024'),
    1,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    127,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-SABRE-2023-2024'),
    2,
    'KOSIŃSKI Łukasz'
); -- matched: KOSIŃSKI Łukasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    143,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-SABRE-2023-2024'),
    3,
    'KROCHMALSKI Jakub'
); -- matched: KROCHMALSKI Jakub (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    270,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-SABRE-2023-2024'),
    4,
    'SZYMAŃSKI Adam'
); -- matched: SZYMAŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'FRYDRYCH' AND txt_first_name = 'Aleksander'),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-SABRE-2023-2024'),
    5,
    'FRYDRYCH Aleksander'
); -- auto-created domestic fencer
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    166,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-SABRE-2023-2024'),
    6,
    'MARASEK Tomasz'
); -- matched: MARASEK Tomasz (score=100.0)
-- Compute scores for GP2-V1-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-M-SABRE-2023-2024')
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
    'GP3-V1-M-SABRE-2023-2024',
    'Grand Prix (runda 3)',
    'PPW',
    'SABRE', 'M', 'V1',
    '2023-06-18', 6, 'https://www.fencingtimelive.com/tableaus/scores/FB01CDD473D548A19FE8F4B57002C8D9/33A3776D98A145B09084E6E833479582',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    127,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-SABRE-2023-2024'),
    1,
    'KOSIŃSKI Łukasz'
); -- matched: KOSIŃSKI Łukasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-SABRE-2023-2024'),
    2,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    310,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-SABRE-2023-2024'),
    3,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    263,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-SABRE-2023-2024'),
    4,
    'SZEPIETOWSKI Rafał (kat 0)'
); -- matched: SZEPIETOWSKI Rafał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    270,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-SABRE-2023-2024'),
    5,
    'SZYMAŃSKI Adam'
); -- matched: SZYMAŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    139,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-SABRE-2023-2024'),
    6,
    'KOŁUCKI Michał'
); -- matched: KOŁUCKI Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    76,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-SABRE-2023-2024'),
    9,
    'GRACZYK Bogdan'
); -- matched: GRACZYK Bogdan (score=100.0)
-- Compute scores for GP3-V1-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-M-SABRE-2023-2024')
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
    'GP4-V1-M-SABRE-2023-2024',
    'Grand Prix (runda 4)',
    'PPW',
    'SABRE', 'M', 'V1',
    '2023-10-23', 4, 'https://www.fencingtimelive.com/events/results/F392BE14FFE748F8863E582EEFCCC7E3',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    139,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V1-M-SABRE-2023-2024'),
    1,
    'KOŁUCKI Michał'
); -- matched: KOŁUCKI Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    127,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V1-M-SABRE-2023-2024'),
    2,
    'KOSIŃSKI Łukasz'
); -- matched: KOSIŃSKI Łukasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    143,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V1-M-SABRE-2023-2024'),
    3,
    'KROCHMALSKI Jakub'
); -- matched: KROCHMALSKI Jakub (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    270,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V1-M-SABRE-2023-2024'),
    4,
    'SZYMAŃSKI Adam'
); -- matched: SZYMAŃSKI Adam (score=100.0)
-- Compute scores for GP4-V1-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V1-M-SABRE-2023-2024')
);

-- SKIP GP5 (Grand Prix (runda 5)): N=0 — tournament had no participants

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
    'GP6-V1-M-SABRE-2023-2024',
    'Grand Prix (runda 6)',
    'PPW',
    'SABRE', 'M', 'V1',
    '2023-11-18', 1, 'https://www.fencingtimelive.com/events/results/238873A8A3C442448DDB954D2EFD9715',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    143,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V1-M-SABRE-2023-2024'),
    1,
    'KROCHMALSKI Jakub'
); -- matched: KROCHMALSKI Jakub (score=100.0)
-- Compute scores for GP6-V1-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V1-M-SABRE-2023-2024')
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
    'GP7-V1-M-SABRE-2023-2024',
    'Grand Prix (runda 7)',
    'PPW',
    'SABRE', 'M', 'V1',
    '2024-01-28', 2, 'https://www.fencingtimelive.com/events/results/31555C21023245118EDAD028E32F8E86',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    143,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-SABRE-2023-2024'),
    1,
    'KROCHMALSKI Jakub'
); -- matched: KROCHMALSKI Jakub (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    127,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-SABRE-2023-2024'),
    2,
    'KOSIŃSKI Łukasz'
); -- matched: KOSIŃSKI Łukasz (score=100.0)
-- Compute scores for GP7-V1-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-M-SABRE-2023-2024')
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
    'GP8-V1-M-SABRE-2023-2024',
    'Grand Prix (runda 8)',
    'PPW',
    'SABRE', 'M', 'V1',
    NULL, 3, 'https://www.fencingtimelive.com/events/results/BE43486F815F4453994A7A2B0EAB1945',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    76,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-SABRE-2023-2024'),
    1,
    'GRACZYK Bogdan'
); -- matched: GRACZYK Bogdan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    270,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-SABRE-2023-2024'),
    2,
    'SZYMAŃSKI Adam'
); -- matched: SZYMAŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    276,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-SABRE-2023-2024'),
    3,
    'TECŁAW Robert'
); -- matched: TECŁAW Robert (score=100.0)
-- Compute scores for GP8-V1-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V1-M-SABRE-2023-2024')
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
    'MPW-V1-M-SABRE-2023-2024',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'SABRE', 'M', 'V1',
    '2024-03-02', 4, 'https://www.fencingtimelive.com/events/results/125EBF1B137C44CC838B496DEF9DF590',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    143,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-SABRE-2023-2024'),
    1,
    'KROCHMALSKI Jakub'
); -- matched: KROCHMALSKI Jakub (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    270,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-SABRE-2023-2024'),
    2,
    'SZYMAŃSKI Adam'
); -- matched: SZYMAŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    127,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-SABRE-2023-2024'),
    3,
    'KOSIŃSKI Łukasz'
); -- matched: KOSIŃSKI Łukasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    76,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-SABRE-2023-2024'),
    4,
    'GRACZYK Bogdan'
); -- matched: GRACZYK Bogdan (score=100.0)
-- Compute scores for MPW-V1-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-M-SABRE-2023-2024')
);

-- SKIP PEW1 (EVF Grand Prix 1 — Budapeszt): 0 matched fencers in DB — tournament not created

-- SKIP PEW2 (EVF Grand Prix 2 — Madryt): N=0 — tournament had no participants

-- ---- PEW3: EVF Grand Prix 3 (Terni) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW3-2023-2024',
    'EVF Grand Prix 3',
    'Terni',
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
    'PEW3-V1-M-SABRE-2023-2024',
    'EVF Grand Prix 3',
    'PEW',
    'SABRE', 'M', 'V1',
    '2023-02-12', 17, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    127,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-SABRE-2023-2024'),
    9,
    'KOSIŃSKI Łukasz'
); -- matched: KOSIŃSKI Łukasz (score=100.0)
-- Compute scores for PEW3-V1-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-SABRE-2023-2024')
);

-- ---- PEW4: EVF Grand Prix 4 (Liege) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW4-2023-2024',
    'EVF Grand Prix 4',
    'Liege',
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
    'PEW4-V1-M-SABRE-2023-2024',
    'EVF Grand Prix 4',
    'PEW',
    'SABRE', 'M', 'V1',
    '2023-04-01', 4, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-SABRE-2023-2024'),
    2,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
-- Compute scores for PEW4-V1-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-SABRE-2023-2024')
);

-- SKIP PEW5 (EVF Grand Prix 5): N=0 — tournament had no participants

-- SKIP PEW6 (EVF Grand Prix 6): N=0 — tournament had no participants

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): N=0 — tournament had no participants

-- SKIP PEW8 (EVF Grand Prix 8 — Guildford): N=0 — tournament had no participants

-- SKIP PEW9 (EVF Grand Prix 9 — Sztokholm): N=0 — tournament had no participants

-- SKIP PEW10 (EVF Grand Prix 10 — Graz): N=0 — tournament had no participants

-- SKIP PEW11 (EVF Grand Prix 11 — Gdańsk): N=0 — tournament had no participants

-- SKIP PEW12 (EVF Grand Prix 12 — Ateny): N=0 — tournament had no participants

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
    'IMEW-V1-M-SABRE-2023-2024',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'SABRE', 'M', 'V1',
    '2023-01-01', 40, 'https://engarde-service.com/competition/e3f/efcv/mensabrev1',
    'SCORED'
);
-- SKIPPED (international, no master data): 'TURLIER' place=1
-- SKIPPED (international, no master data): 'NAGY' place=2
-- SKIPPED (international, no master data): 'HERM' place=3
-- SKIPPED (international, no master data): 'HIEN' place=3
-- SKIPPED (international, no master data): 'SCHULEMANN' place=5
-- SKIPPED (international, no master data): 'GAY' place=6
-- SKIPPED (international, no master data): 'ANDREU DEDEU' place=7
-- SKIPPED (international, no master data): 'GOIKHMAN' place=8
-- SKIPPED (international, no master data): 'WEBER' place=9
-- SKIPPED (international, no master data): 'BODAY' place=10
-- SKIPPED (international, no master data): 'FREMONT' place=11
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-SABRE-2023-2024'),
    12,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
-- SKIPPED (international, no master data): 'PARISE' place=13
-- SKIPPED (international, no master data): 'HUGO' place=14
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    127,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-SABRE-2023-2024'),
    15,
    'KOSIŃSKI Łukasz'
); -- matched: KOSIŃSKI Łukasz (score=100.0)
-- SKIPPED (international, no master data): 'REY HERMIDA' place=16
-- SKIPPED (international, no master data): 'TYPL' place=17
-- SKIPPED (international, no master data): 'ZANELLATO' place=18
-- SKIPPED (international, no master data): 'WRIGHT' place=19
-- SKIPPED (international, no master data): 'NASH' place=20
-- SKIPPED (international, no master data): 'MATHIS' place=21
-- SKIPPED (international, no master data): 'BELLET' place=22
-- SKIPPED (international, no master data): 'BLATZ' place=23
-- SKIPPED (international, no master data): 'BROCK' place=24
-- SKIPPED (international, no master data): 'MAHLAMAKI' place=25
-- SKIPPED (international, no master data): 'CSALLO' place=26
-- SKIPPED (international, no master data): 'BELLET' place=27
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    143,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-SABRE-2023-2024'),
    28,
    'KROCHMALSKI Jakub'
); -- matched: KROCHMALSKI Jakub (score=100.0)
-- SKIPPED (international, no master data): 'SENATORE' place=29
-- SKIPPED (international, no master data): 'RUSAK' place=30
-- SKIPPED (international, no master data): 'CASADESUS SOLE' place=31
-- SKIPPED (international, no master data): 'MOULINIER' place=32
-- SKIPPED (international, no master data): 'PETRONE' place=33
-- SKIPPED (international, no master data): 'ANTONIS' place=34
-- SKIPPED (international, no master data): 'MCDOUGALL' place=35
-- SKIPPED (international, no master data): 'SMOLEJ' place=36
-- SKIPPED (international, no master data): 'DIOP' place=37
-- SKIPPED (international, no master data): 'BARTH' place=38
-- SKIPPED (international, no master data): 'SZABO' place=39
-- SKIPPED (international, no master data): 'CHITISHVILI' place=40
-- Compute scores for IMEW-V1-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-M-SABRE-2023-2024')
);

-- Summary
-- Total results matched:   38
-- Total results unmatched: 39
-- Total auto-created:      1
