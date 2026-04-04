-- =========================================================================
-- Season 2023-2024 — V4 M SABRE — generated from SZABLA-4-2023-2024.xlsx
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
    'GP1-V4-M-SABRE-2023-2024',
    'Grand Prix (runda 1)',
    'PPW',
    'SABRE', 'M', 'V4',
    '2023-01-15', 1, 'https://www.fencingtimelive.com/events/results/502A7FF80E0240E5902CDB5883CB5127',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    1,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V4-M-SABRE-2023-2024'),
    1,
    'ADAMCZEWSKI Wojciech'
); -- matched: ADAMCZEWSKI Wojciech (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    95,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V4-M-SABRE-2023-2024'),
    3,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
-- Compute scores for GP1-V4-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V4-M-SABRE-2023-2024')
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
    'GP2-V4-M-SABRE-2023-2024',
    'Grand Prix (runda 2)',
    'PPW',
    'SABRE', 'M', 'V4',
    '2023-03-05', 2, 'https://www.fencingtimelive.com/events/results/E6D318B644CF4F66855D2C5CD414600F',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    181,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V4-M-SABRE-2023-2024'),
    1,
    'PANZ Marian'
); -- matched: PANZ Marian (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    194,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V4-M-SABRE-2023-2024'),
    2,
    'PRĘGOWSKI Jerzy'
); -- matched: PRĘGOWSKI Jerzy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    95,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V4-M-SABRE-2023-2024'),
    4,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
-- Compute scores for GP2-V4-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V4-M-SABRE-2023-2024')
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
    'GP3-V4-M-SABRE-2023-2024',
    'Grand Prix (runda 3)',
    'PPW',
    'SABRE', 'M', 'V4',
    '2023-06-18', 3, 'https://www.fencingtimelive.com/events/results/A3FC8BD675A7445BB2103552F7A39F81',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    148,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V4-M-SABRE-2023-2024'),
    1,
    'MAINKA Andrzej'
); -- matched: MAINKA Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    194,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V4-M-SABRE-2023-2024'),
    2,
    'PRĘGOWSKI Jerzy'
); -- matched: PRĘGOWSKI Jerzy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    163,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V4-M-SABRE-2023-2024'),
    3,
    'MŁYNEK Janusz'
); -- matched: MŁYNEK Janusz (score=100.0)
-- Compute scores for GP3-V4-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V4-M-SABRE-2023-2024')
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
    'GP4-V4-M-SABRE-2023-2024',
    'Grand Prix (runda 4)',
    'PPW',
    'SABRE', 'M', 'V4',
    '2023-10-23', 4, 'https://www.fencingtimelive.com/events/results/B06609DA5B4F40A78350F6A0DD264EE5',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    21,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V4-M-SABRE-2023-2024'),
    1,
    'BORYSIUK Zbigniew'
); -- matched: BORYSIUK Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    163,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V4-M-SABRE-2023-2024'),
    2,
    'MŁYNEK Janusz'
); -- matched: MŁYNEK Janusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    95,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V4-M-SABRE-2023-2024'),
    3,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    244,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V4-M-SABRE-2023-2024'),
    4,
    'TARANCZEWSKI Janusz'
); -- matched: TARANCZEWSKI Janusz (score=100.0)
-- Compute scores for GP4-V4-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V4-M-SABRE-2023-2024')
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
    'GP5-V4-M-SABRE-2023-2024',
    'Grand Prix (runda 5)',
    'PPW',
    'SABRE', 'M', 'V4',
    '2023-10-28', 2, 'https://www.fencingtimelive.com/events/results/9F634F806CE54F0F9F539A52CB034B29',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    95,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V4-M-SABRE-2023-2024'),
    1,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    244,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V4-M-SABRE-2023-2024'),
    2,
    'TARANCZEWSKI Janusz'
); -- matched: TARANCZEWSKI Janusz (score=100.0)
-- Compute scores for GP5-V4-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V4-M-SABRE-2023-2024')
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
    'GP6-V4-M-SABRE-2023-2024',
    'Grand Prix (runda 6)',
    'PPW',
    'SABRE', 'M', 'V4',
    '2023-11-18', 3, 'https://www.fencingtimelive.com/events/results/71EFD0281E954EF1931BFC20BAEB9454',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    163,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V4-M-SABRE-2023-2024'),
    1,
    'MŁYNEK Janusz'
); -- matched: MŁYNEK Janusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    194,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V4-M-SABRE-2023-2024'),
    2,
    'PRĘGOWSKI Jerzy'
); -- matched: PRĘGOWSKI Jerzy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    95,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V4-M-SABRE-2023-2024'),
    3,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
-- Compute scores for GP6-V4-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V4-M-SABRE-2023-2024')
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
    'GP7-V4-M-SABRE-2023-2024',
    'Grand Prix (runda 7)',
    'PPW',
    'SABRE', 'M', 'V4',
    '2024-01-28', 4, 'https://www.fencingtimelive.com/events/results/3C0A49DCC66342B7804228836C7C6602',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    21,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V4-M-SABRE-2023-2024'),
    1,
    'BORYSIUK Zbigniew'
); -- matched: BORYSIUK Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    95,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V4-M-SABRE-2023-2024'),
    2,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    163,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V4-M-SABRE-2023-2024'),
    3,
    'MŁYNEK Janusz'
); -- matched: MŁYNEK Janusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    194,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V4-M-SABRE-2023-2024'),
    4,
    'PRĘGOWSKI Jerzy'
); -- matched: PRĘGOWSKI Jerzy (score=100.0)
-- Compute scores for GP7-V4-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V4-M-SABRE-2023-2024')
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
    'GP8-V4-M-SABRE-2023-2024',
    'Grand Prix (runda 8)',
    'PPW',
    'SABRE', 'M', 'V4',
    '2024-06-23', 4, 'https://www.fencingtimelive.com/events/results/DDF11FE69ED5416395AB11B414F0BB34',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    163,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V4-M-SABRE-2023-2024'),
    1,
    'MŁYNEK Janusz'
); -- matched: MŁYNEK Janusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    21,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V4-M-SABRE-2023-2024'),
    2,
    'BORYSIUK Zbigniew'
); -- matched: BORYSIUK Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    148,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V4-M-SABRE-2023-2024'),
    3,
    'MAINKA Andrzej'
); -- matched: MAINKA Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    194,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V4-M-SABRE-2023-2024'),
    4,
    'PRĘGOWSKI Jerzy'
); -- matched: PRĘGOWSKI Jerzy (score=100.0)
-- Compute scores for GP8-V4-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V4-M-SABRE-2023-2024')
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
    'MPW-V4-M-SABRE-2023-2024',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'SABRE', 'M', 'V4',
    '2024-03-02', 5, 'https://www.fencingtimelive.com/events/results/D22ADB683A074C13A408E3FA2D0EA4DD',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    148,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-SABRE-2023-2024'),
    1,
    'MAINKA Andrzej'
); -- matched: MAINKA Andrzej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    95,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-SABRE-2023-2024'),
    2,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    194,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-SABRE-2023-2024'),
    3,
    'PRĘGOWSKI Jerzy'
); -- matched: PRĘGOWSKI Jerzy (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    163,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-SABRE-2023-2024'),
    4,
    'MŁYNEK Janusz'
); -- matched: MŁYNEK Janusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    1,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-SABRE-2023-2024'),
    5,
    'ADAMCZEWSKI Wojciech'
); -- matched: ADAMCZEWSKI Wojciech (score=100.0)
-- Compute scores for MPW-V4-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V4-M-SABRE-2023-2024')
);

-- SKIP PEW1 (EVF Grand Prix 1 — Budapeszt): N=0 — tournament had no participants

-- ---- PEW2: EVF Grand Prix 2 — Madryt (Faches-Thumesnil) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW2-2023-2024',
    'EVF Grand Prix 2 — Madryt',
    'Faches-Thumesnil',
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
    'PEW2-V4-M-SABRE-2023-2024',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'SABRE', 'M', 'V4',
    '2023-01-21', 3, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    181,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V4-M-SABRE-2023-2024'),
    3,
    'PANZ Marian'
); -- matched: PANZ Marian (score=100.0)
-- Compute scores for PEW2-V4-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V4-M-SABRE-2023-2024')
);

-- SKIP PEW3 (EVF Grand Prix 3): N=0 — tournament had no participants

-- SKIP PEW4 (EVF Grand Prix 4): N=0 — tournament had no participants

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
    'IMEW-V4-M-SABRE-2023-2024',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'SABRE', 'M', 'V4',
    '2023-01-01', 23, 'https://engarde-service.com/competition/e3f/efcv/mensabrev4',
    'SCORED'
);
-- UNMATCHED (score<80): 'CARMINA' place=1
-- UNMATCHED (score<80): 'BOCCONI' place=2
-- UNMATCHED (score<80): 'PAROLI' place=3
-- UNMATCHED (score<80): 'PRECHTL' place=3
-- UNMATCHED (score<80): 'MORRIS' place=5
-- UNMATCHED (score<80): 'ARANY-TOTH' place=6
-- UNMATCHED (score<80): 'BELLET' place=7
-- UNMATCHED (score<80): 'FRANK' place=8
-- UNMATCHED (score<80): 'ALLAIN' place=9
-- UNMATCHED (score<80): 'PAUL' place=10
-- UNMATCHED (score<80): 'AUSSEDAT' place=11
-- UNMATCHED (score<80): 'BARON' place=12
-- UNMATCHED (score<80): 'HELFRICHT' place=13
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    194,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V4-M-SABRE-2023-2024'),
    14,
    'PRĘGOWSKI Jerzy'
); -- matched: PRĘGOWSKI Jerzy (score=100.0)
-- UNMATCHED (score<80): 'HUGET' place=15
-- UNMATCHED (score<80): 'DOLEZAL' place=16
-- UNMATCHED (score<80): 'IMREH' place=17
-- UNMATCHED (score<80): 'COMPTON' place=18
-- UNMATCHED (score<80): 'SCHNEIDER' place=19
-- UNMATCHED (score<80): 'ZINI' place=20
-- UNMATCHED (score<80): 'AMANRICH' place=21
-- UNMATCHED (score<80): 'MAGYAR' place=22
-- UNMATCHED (score<80): 'CUNEO' place=23
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    95,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V4-M-SABRE-2023-2024'),
    27,
    'JUSZKIEWICZ Piotr'
); -- matched: JUSZKIEWICZ Piotr (score=100.0)
-- Compute scores for IMEW-V4-M-SABRE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V4-M-SABRE-2023-2024')
);

-- Summary
-- Total results matched:   33
-- Total results unmatched: 22
