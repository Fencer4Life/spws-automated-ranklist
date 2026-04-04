-- =========================================================================
-- Season 2023-2024 — V0 M SABRE — generated from SZABLA-0-2023-2024.xlsx
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
    'GP1-V0-M-SABRE-2023-2024',
    'Grand Prix (runda 1)',
    'PPW',
    'SABRE', 'M', 'V0',
    '2023-01-15', 6, 'https://www.fencingtimelive.com/events/results/878E0270C9EB4A18937074AED947DB59',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    72,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-M-SABRE-2023-2024'),
    1,
    'GRACZYK Bogdan'
); -- matched: GRACZYK Bogdan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    64,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-M-SABRE-2023-2024'),
    2,
    'GĘZIKIEWICZ Marcin'
); -- matched: GĘZIKIEWICZ Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    234,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-M-SABRE-2023-2024'),
    3,
    'SZEPIETOWSKI Rafał'
); -- matched: SZEPIETOWSKI Rafał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    70,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-M-SABRE-2023-2024'),
    5,
    'GRABOWSKI Sebastian'
); -- matched: GRABOWSKI Sebastian (score=100.0)
-- Compute scores for GP1-V0-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-M-SABRE-2023-2024')
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
    'GP2-V0-M-SABRE-2023-2024',
    'Grand Prix (runda 2)',
    'PPW',
    'SABRE', 'M', 'V0',
    '2023-03-05', 6, 'https://www.fencingtimelive.com/events/results/78C7BB566AAB4459AE36655F17C9812E',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    64,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V0-M-SABRE-2023-2024'),
    1,
    'GĘZIKIEWICZ Marcin'
); -- matched: GĘZIKIEWICZ Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    234,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V0-M-SABRE-2023-2024'),
    2,
    'SZEPIETOWSKI Rafał'
); -- matched: SZEPIETOWSKI Rafał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    72,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V0-M-SABRE-2023-2024'),
    3,
    'GRACZYK Bogdan'
); -- matched: GRACZYK Bogdan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    70,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V0-M-SABRE-2023-2024'),
    6,
    'GRABOWSKI Sebastian'
); -- matched: GRABOWSKI Sebastian (score=100.0)
-- Compute scores for GP2-V0-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V0-M-SABRE-2023-2024')
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
    'GP3-V0-M-SABRE-2023-2024',
    'Grand Prix (runda 3)',
    'PPW',
    'SABRE', 'M', 'V0',
    '2023-06-18', 1, 'https://www.fencingtimelive.com/tableaus/scores/FB01CDD473D548A19FE8F4B57002C8D9/33A3776D98A145B09084E6E833479582',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    234,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V0-M-SABRE-2023-2024'),
    1,
    'SZEPIETOWSKI Rafał'
); -- matched: SZEPIETOWSKI Rafał (score=100.0)
-- Compute scores for GP3-V0-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V0-M-SABRE-2023-2024')
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
    'GP4-V0-M-SABRE-2023-2024',
    'Grand Prix (runda 4)',
    'PPW',
    'SABRE', 'M', 'V0',
    '2023-10-23', 5, 'https://www.fencingtimelive.com/events/results/0B91406135D44E358053557044B7DD3C',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    234,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V0-M-SABRE-2023-2024'),
    1,
    'SZEPIETOWSKI Rafał'
); -- matched: SZEPIETOWSKI Rafał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    64,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V0-M-SABRE-2023-2024'),
    2,
    'GĘZIKIEWICZ Marcin'
); -- matched: GĘZIKIEWICZ Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    29,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V0-M-SABRE-2023-2024'),
    3,
    'CHOJNACKI Tomasz'
); -- matched: CHOJNACKI Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    40,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V0-M-SABRE-2023-2024'),
    4,
    'DOMAŃSKI Sławomir'
); -- matched: DOMAŃSKI Sławomir (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    101,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V0-M-SABRE-2023-2024'),
    5,
    'KIEROŃSKI Tomasz'
); -- matched: KIEROŃSKI Tomasz (score=100.0)
-- Compute scores for GP4-V0-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V0-M-SABRE-2023-2024')
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
    'GP5-V0-M-SABRE-2023-2024',
    'Grand Prix (runda 5)',
    'PPW',
    'SABRE', 'M', 'V0',
    '2023-10-28', 1, 'https://www.fencingtimelive.com/events/results/9F634F806CE54F0F9F539A52CB034B29',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    234,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V0-M-SABRE-2023-2024'),
    1,
    'SZEPIETOWSKI Rafał'
); -- matched: SZEPIETOWSKI Rafał (score=100.0)
-- Compute scores for GP5-V0-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V0-M-SABRE-2023-2024')
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
    'GP6-V0-M-SABRE-2023-2024',
    'Grand Prix (runda 6)',
    'PPW',
    'SABRE', 'M', 'V0',
    '2023-11-18', 1, 'https://www.fencingtimelive.com/events/results/238873A8A3C442448DDB954D2EFD9715',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    234,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V0-M-SABRE-2023-2024'),
    1,
    'SZEPIETOWSKI Rafał'
); -- matched: SZEPIETOWSKI Rafał (score=100.0)
-- Compute scores for GP6-V0-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V0-M-SABRE-2023-2024')
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
    'GP7-V0-M-SABRE-2023-2024',
    'Grand Prix (runda 7)',
    'PPW',
    'SABRE', 'M', 'V0',
    NULL, 2, 'https://www.fencingtimelive.com/events/results/31555C21023245118EDAD028E32F8E86',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    234,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V0-M-SABRE-2023-2024'),
    1,
    'SZEPIETOWSKI Rafał'
); -- matched: SZEPIETOWSKI Rafał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    101,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V0-M-SABRE-2023-2024'),
    2,
    'KIEROŃSKI Tomasz'
); -- matched: KIEROŃSKI Tomasz (score=100.0)
-- Compute scores for GP7-V0-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V0-M-SABRE-2023-2024')
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
    'GP8-V0-M-SABRE-2023-2024',
    'Grand Prix (runda 8)',
    'PPW',
    'SABRE', 'M', 'V0',
    '2024-06-23', 2, 'https://www.fencingtimelive.com/events/results/BE43486F815F4453994A7A2B0EAB1945',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    107,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V0-M-SABRE-2023-2024'),
    1,
    'KMIECIK Adam'
); -- matched: KMIECIK Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    101,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V0-M-SABRE-2023-2024'),
    2,
    'KIEROŃSKI Tomasz'
); -- matched: KIEROŃSKI Tomasz (score=100.0)
-- Compute scores for GP8-V0-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V0-M-SABRE-2023-2024')
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
    'MPW-V0-M-SABRE-2023-2024',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'SABRE', 'M', 'V0',
    '2024-03-02', 4, 'https://www.fencingtimelive.com/events/results/125EBF1B137C44CC838B496DEF9DF590',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    64,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-SABRE-2023-2024'),
    1,
    'GĘZIKIEWICZ Marcin'
); -- matched: GĘZIKIEWICZ Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    234,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-SABRE-2023-2024'),
    2,
    'SZEPIETOWSKI Rafał'
); -- matched: SZEPIETOWSKI Rafał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    101,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-SABRE-2023-2024'),
    3,
    'KIEROŃSKI Tomasz'
); -- matched: KIEROŃSKI Tomasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    230,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-SABRE-2023-2024'),
    4,
    'SULŻYC Piotr'
); -- matched: SULŻYC Piotr (score=100.0)
-- Compute scores for MPW-V0-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-M-SABRE-2023-2024')
);

-- Summary
-- Total results matched:   28
-- Total results unmatched: 0
