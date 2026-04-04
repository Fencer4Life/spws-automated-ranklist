-- =========================================================================
-- Season 2023-2024 — V2 F EPEE — generated from SZPADA-K2-2023-2024.xlsx
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
    'GP1-V2-F-EPEE-2023-2024',
    'Grand Prix (runda 1)',
    'PPW',
    'EPEE', 'F', 'V2',
    '2023-01-14', 3, 'https://www.fencingtimelive.com/events/results/BDCC997B6E8B40508D1A77492201A9CA',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    64,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-F-EPEE-2023-2024'),
    1,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    265,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-F-EPEE-2023-2024'),
    2,
    'POJMAŃSKA Katarzyna'
); -- matched: SZMAJDZIŃSKA Katarzyna (score=78.04878048780488)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    286,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-F-EPEE-2023-2024'),
    3,
    'WALECKA Wanda'
); -- matched: WALECKA Wanda (score=100.0)
-- Compute scores for GP1-V2-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-F-EPEE-2023-2024')
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
    'GP2-V2-F-EPEE-2023-2024',
    'Grand Prix (runda 2)',
    'PPW',
    'EPEE', 'F', 'V2',
    '2023-03-04', 3, 'https://www.fencingtimelive.com/events/results/EA766E9B52164B49B9EE28559B7FE60B',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    64,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-F-EPEE-2023-2024'),
    1,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    289,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-F-EPEE-2023-2024'),
    2,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    286,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-F-EPEE-2023-2024'),
    3,
    'WALECKA Wanda'
); -- matched: WALECKA Wanda (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    206,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-F-EPEE-2023-2024'),
    6,
    'PILARSKA Barbara'
); -- matched: PILARSKA Barbara (score=100.0)
-- Compute scores for GP2-V2-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-F-EPEE-2023-2024')
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
    'GP3-V2-F-EPEE-2023-2024',
    'Grand Prix (runda 3)',
    'PPW',
    'EPEE', 'F', 'V2',
    '2023-06-17', 6, 'https://www.fencingtimelive.com/events/results/9B6ADC78FC974063BB079D6F68261E4E',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    64,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-F-EPEE-2023-2024'),
    1,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    289,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-F-EPEE-2023-2024'),
    2,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    180,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-F-EPEE-2023-2024'),
    3,
    'MILOVA Tatiana'
); -- matched: MILOVA Tatiana (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-F-EPEE-2023-2024'),
    4,
    'SADOWIŃSKA Adriana'
); -- matched: SADOWIŃSKA Adriana (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    286,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-F-EPEE-2023-2024'),
    5,
    'WALECKA Wanda'
); -- matched: WALECKA Wanda (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    23,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-F-EPEE-2023-2024'),
    6,
    'BORKOWSKA Halina'
); -- matched: BORKOWSKA Halina (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    206,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-F-EPEE-2023-2024'),
    8,
    'PILARSKA Barbara'
); -- matched: PILARSKA Barbara (score=100.0)
-- Compute scores for GP3-V2-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-F-EPEE-2023-2024')
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
    'GP4-V2-F-EPEE-2023-2024',
    'Grand Prix (runda 4)',
    'PPW',
    'EPEE', 'F', 'V2',
    '2023-10-23', 4, 'https://www.fencingtimelive.com/events/results/78E3E708971446B5BF2AE4A2AD39396F',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    289,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-F-EPEE-2023-2024'),
    1,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    64,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-F-EPEE-2023-2024'),
    2,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    180,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-F-EPEE-2023-2024'),
    3,
    'MILOVA Tatiana'
); -- matched: MILOVA Tatiana (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    286,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-F-EPEE-2023-2024'),
    4,
    'WALECKA Wanda'
); -- matched: WALECKA Wanda (score=100.0)
-- Compute scores for GP4-V2-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-F-EPEE-2023-2024')
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
    'GP5-V2-F-EPEE-2023-2024',
    'Grand Prix (runda 5)',
    'PPW',
    'EPEE', 'F', 'V2',
    '2023-10-28', 3, 'https://www.fencingtimelive.com/events/results/43BA8AF7E2A842D29A509341ACE7659A',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    64,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-F-EPEE-2023-2024'),
    1,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    289,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-F-EPEE-2023-2024'),
    2,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    286,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-F-EPEE-2023-2024'),
    3,
    'WALECKA Wanda'
); -- matched: WALECKA Wanda (score=100.0)
-- Compute scores for GP5-V2-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-F-EPEE-2023-2024')
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
    'GP6-V2-F-EPEE-2023-2024',
    'Grand Prix (runda 6)',
    'PPW',
    'EPEE', 'F', 'V2',
    '2023-11-18', 5, 'https://www.fencingtimelive.com/events/results/7A6EA79869D348DE8245D3DA71455C75',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    253,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-F-EPEE-2023-2024'),
    1,
    'STAŃCZYK Agnieszka'
); -- matched: STAŃCZYK Agnieszka (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    64,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-F-EPEE-2023-2024'),
    2,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    180,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-F-EPEE-2023-2024'),
    3,
    'MILOVA Tatiana'
); -- matched: MILOVA Tatiana (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-F-EPEE-2023-2024'),
    4,
    'SADOWIŃSKA Adriana'
); -- matched: SADOWIŃSKA Adriana (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    286,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-F-EPEE-2023-2024'),
    5,
    'WALECKA Wanda'
); -- matched: WALECKA Wanda (score=100.0)
-- Compute scores for GP6-V2-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-F-EPEE-2023-2024')
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
    'GP7-V2-F-EPEE-2023-2024',
    'Grand Prix (runda 7)',
    'PPW',
    'EPEE', 'F', 'V2',
    '2024-01-27', 4, 'https://www.fencingtimelive.com/events/results/15D820D5BA9A442AA26E2B4B816F091F',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    253,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-F-EPEE-2023-2024'),
    1,
    'STAŃCZYK Agnieszka'
); -- matched: STAŃCZYK Agnieszka (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    289,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-F-EPEE-2023-2024'),
    2,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    64,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-F-EPEE-2023-2024'),
    3,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    286,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-F-EPEE-2023-2024'),
    4,
    'WALECKA Wanda'
); -- matched: WALECKA Wanda (score=100.0)
-- Compute scores for GP7-V2-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-F-EPEE-2023-2024')
);

-- ---- GP8: Grand Prix (runda 8) (TBD) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'GP8-2023-2024',
    'Grand Prix (runda 8)',
    'TBD',
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
    'GP8-V2-F-EPEE-2023-2024',
    'Grand Prix (runda 8)',
    'PPW',
    'EPEE', 'F', 'V2',
    NULL, 4, 'https://www.fencingtimelive.com/events/results/15D820D5BA9A442AA26E2B4B816F091F',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    64,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-F-EPEE-2023-2024'),
    1,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    109,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-F-EPEE-2023-2024'),
    2,
    'KARMAN Irene'
); -- matched: KARMAN Irene (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    206,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-F-EPEE-2023-2024'),
    3,
    'PILARSKA Barbara'
); -- matched: PILARSKA Barbara (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    286,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-F-EPEE-2023-2024'),
    4,
    'WALECKA Wanda'
); -- matched: WALECKA Wanda (score=100.0)
-- Compute scores for GP8-V2-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-F-EPEE-2023-2024')
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
    'MPW-V2-F-EPEE-2023-2024',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'EPEE', 'F', 'V2',
    '2024-03-02', 2, 'https://www.fencingtimelive.com/events/results/51602A5C205A48F1A0CCE625BEFEFD1E',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    289,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-F-EPEE-2023-2024'),
    1,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    286,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-F-EPEE-2023-2024'),
    2,
    'WALECKA Wanda'
); -- matched: WALECKA Wanda (score=100.0)
-- Compute scores for MPW-V2-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-F-EPEE-2023-2024')
);

-- SKIP PEW1 (EVF Grand Prix 1 — Budapeszt): N=0 — tournament had no participants

-- SKIP PEW2 (EVF Grand Prix 2 — Madryt): N=0 — tournament had no participants

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
    'PEW3-V2-F-EPEE-2023-2024',
    'EVF Grand Prix 3',
    'PEW',
    'EPEE', 'F', 'V2',
    '2023-04-15', 5, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    289,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-F-EPEE-2023-2024'),
    3,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    64,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-F-EPEE-2023-2024'),
    3,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    286,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-F-EPEE-2023-2024'),
    5,
    'WALECKA Wanda'
); -- matched: WALECKA Wanda (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    206,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-F-EPEE-2023-2024'),
    8,
    'PILARSKA Barbara'
); -- matched: PILARSKA Barbara (score=100.0)
-- Compute scores for PEW3-V2-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-F-EPEE-2023-2024')
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
    'PEW4-V2-F-EPEE-2023-2024',
    'EVF Grand Prix 4',
    'PEW',
    'EPEE', 'F', 'V2',
    '2023-09-16', 14, 'https://engarde-service.com/?fbclid=IwAR1q8b20973WNdhLRYbl3vdP-rPK0cilvuHZi37KFNf-Dodoicffb3YOQeM',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    289,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-F-EPEE-2023-2024'),
    3,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    64,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-F-EPEE-2023-2024'),
    11,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
-- Compute scores for PEW4-V2-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-F-EPEE-2023-2024')
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
    'PEW6-V2-F-EPEE-2023-2024',
    'EVF Grand Prix 6',
    'PEW',
    'EPEE', 'F', 'V2',
    '2023-11-11', 19, 'https://engarde-service.com/competition/aeve_esgrima/evf_madrid_2023/t_ef_2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    64,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-F-EPEE-2023-2024'),
    8,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
-- Compute scores for PEW6-V2-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-F-EPEE-2023-2024')
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
    'PEW7-V2-F-EPEE-2023-2024',
    'EVF Grand Prix 7 — Terni',
    'PEW',
    'EPEE', 'F', 'V2',
    '2023-12-16', 34, 'https://www.4fence.it/FIS/Risultati/2023-12-17-16_Terni_(TR)_-_3_Prova_Circuito_Naz.le_Master/index.php?a=SP&s=F&c=7&f=clafinale',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    64,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-F-EPEE-2023-2024'),
    3,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
-- Compute scores for PEW7-V2-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-F-EPEE-2023-2024')
);

-- SKIP PEW8 (EVF Grand Prix 8 — Guildford): N=0 — tournament had no participants

-- SKIP PEW9 (EVF Grand Prix 9 — Sztokholm): N=0 — tournament had no participants

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
    'PEW11-V2-F-EPEE-2023-2024',
    'EVF Grand Prix 11 — Gdańsk',
    'PEW',
    'EPEE', 'F', 'V2',
    '2024-04-06', 11, 'https://www.veteransfencing.eu/fencing/rankings/',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    289,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-F-EPEE-2023-2024'),
    3,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    253,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-F-EPEE-2023-2024'),
    3,
    'STAŃCZYK Agnieszka'
); -- matched: STAŃCZYK Agnieszka (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    64,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-F-EPEE-2023-2024'),
    8,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    286,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-F-EPEE-2023-2024'),
    9,
    'WALECKA Wanda'
); -- matched: WALECKA Wanda (score=100.0)
-- Compute scores for PEW11-V2-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-F-EPEE-2023-2024')
);

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
    'IMEW-V2-F-EPEE-2023-2024',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'EPEE', 'F', 'V2',
    '2023-01-01', 105, 'https://engarde-service.com/competition/e3f/efcv/womenepeev2',
    'SCORED'
);
-- SKIPPED (international, no master data): 'USHER' place=1
-- SKIPPED (international, no master data): 'DE VARGAS HILLA' place=2
-- SKIPPED (international, no master data): 'KERVEADOU' place=3
-- SKIPPED (international, no master data): 'LORENZ' place=3
-- SKIPPED (international, no master data): 'LAISNEY' place=5
-- SKIPPED (international, no master data): 'PREAUX' place=6
-- SKIPPED (international, no master data): 'CHARROY' place=7
-- SKIPPED (international, no master data): 'TANZMEISTER' place=8
-- SKIPPED (international, no master data): 'DE GROOTE' place=9
-- SKIPPED (international, no master data): 'DUCHNOWSKI' place=10
-- SKIPPED (international, no master data): 'BOUQUET' place=11
-- SKIPPED (international, no master data): 'GURWIC' place=12
-- SKIPPED (international, no master data): 'FLEURY' place=13
-- SKIPPED (international, no master data): 'STIHL' place=14
-- SKIPPED (international, no master data): 'THOULESS' place=15
-- SKIPPED (international, no master data): 'CANO DIOSA' place=16
-- SKIPPED (international, no master data): 'GRAF' place=17
-- SKIPPED (international, no master data): 'VANDEWALLE' place=18
-- SKIPPED (international, no master data): 'HAUTERVILLE' place=19
-- SKIPPED (international, no master data): 'BUGALLO OTERO' place=20
-- SKIPPED (international, no master data): 'TIPPELT' place=21
-- SKIPPED (international, no master data): 'STROHMEYER' place=22
-- SKIPPED (international, no master data): 'EHLERMANN' place=23
-- SKIPPED (international, no master data): 'VAN DER VEEN' place=24
-- SKIPPED (international, no master data): 'APPAVOUPOULLE' place=25
-- SKIPPED (international, no master data): 'FICHTEL' place=26
-- SKIPPED (international, no master data): 'MARHEINEKE' place=27
-- SKIPPED (international, no master data): 'PAGNY' place=28
-- SKIPPED (international, no master data): 'ONIYE' place=29
-- SKIPPED (international, no master data): 'VALAR' place=30
-- SKIPPED (international, no master data): 'VAN DEN BERG' place=31
-- SKIPPED (international, no master data): 'MAYER' place=32
-- SKIPPED (international, no master data): 'VALERA SANCHEZ' place=33
-- SKIPPED (international, no master data): 'CHALON' place=34
-- SKIPPED (international, no master data): 'BOYKO' place=35
-- SKIPPED (international, no master data): 'BJORK' place=36
-- SKIPPED (international, no master data): 'SKAALID' place=37
-- SKIPPED (international, no master data): 'KOJO' place=38
-- SKIPPED (international, no master data): 'BONATO' place=39
-- SKIPPED (international, no master data): 'NOVOSELSKA' place=40
-- SKIPPED (international, no master data): 'TROLL' place=41
-- SKIPPED (international, no master data): 'HULL' place=42
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    215,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-F-EPEE-2023-2024'),
    43,
    'PRAHA-TSAREHRADSKA'
); -- matched: PRAHA-TSAREHRADSKA Nadiia (score=83.72093023255813)
-- SKIPPED (international, no master data): 'SCHMID-PFAUS' place=44
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    64,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-F-EPEE-2023-2024'),
    45,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
-- SKIPPED (international, no master data): 'POUBLANC-LEDUN' place=46
-- SKIPPED (international, no master data): 'REIMERS' place=47
-- SKIPPED (international, no master data): 'HESKETA' place=48
-- SKIPPED (international, no master data): 'HOM' place=49
-- SKIPPED (international, no master data): 'GRANT' place=50
-- SKIPPED (international, no master data): 'STRAUB' place=51
-- SKIPPED (international, no master data): 'PRESSE' place=52
-- SKIPPED (international, no master data): 'ALBERTSON' place=53
-- SKIPPED (international, no master data): 'VAZQUEZ CORBACHO' place=54
-- SKIPPED (international, no master data): 'BUDDEN' place=55
-- SKIPPED (international, no master data): 'VILLEMONT' place=56
-- SKIPPED (international, no master data): 'STRAUB' place=57
-- SKIPPED (international, no master data): 'CALAMBE' place=58
-- SKIPPED (international, no master data): 'ALTKEMPER' place=59
-- SKIPPED (international, no master data): 'SKOKANOVA' place=60
-- SKIPPED (international, no master data): 'SPEER' place=61
-- SKIPPED (international, no master data): 'HORI' place=62
-- SKIPPED (international, no master data): 'EICHNER-BRUNING' place=63
-- SKIPPED (international, no master data): 'VINCENT VELGHE' place=64
-- SKIPPED (international, no master data): 'CLAVOT' place=65
-- SKIPPED (international, no master data): 'KOS' place=66
-- SKIPPED (international, no master data): 'MION' place=67
-- SKIPPED (international, no master data): 'WEINHOLTZ' place=68
-- SKIPPED (international, no master data): 'ARNOLD' place=69
-- SKIPPED (international, no master data): 'KYMALAINEN' place=70
-- SKIPPED (international, no master data): 'CAVO' place=71
-- SKIPPED (international, no master data): 'AUERBACH' place=72
-- SKIPPED (international, no master data): 'VAN BERGEN' place=73
-- SKIPPED (international, no master data): 'BRUNET' place=74
-- SKIPPED (international, no master data): 'OLIER' place=75
-- SKIPPED (international, no master data): 'VIITA' place=76
-- SKIPPED (international, no master data): 'JEDAMZIK' place=77
-- SKIPPED (international, no master data): 'WAELLE' place=78
-- SKIPPED (international, no master data): 'TORDA' place=79
-- SKIPPED (international, no master data): 'NIEDERMEIER' place=80
-- SKIPPED (international, no master data): 'KARMAN' place=81
-- SKIPPED (international, no master data): 'ASQUINI' place=82
-- SKIPPED (international, no master data): 'ROUSSELOT' place=83
-- SKIPPED (international, no master data): 'PARK-BHASIN' place=84
-- SKIPPED (international, no master data): 'WOLFF' place=85
-- SKIPPED (international, no master data): 'FOLZ' place=86
-- SKIPPED (international, no master data): 'SCHOBER' place=87
-- SKIPPED (international, no master data): 'GRABHER-RHOMBERG' place=88
-- SKIPPED (international, no master data): 'KASOLYNE DEKANY' place=89
-- SKIPPED (international, no master data): 'SCHNEIDEWIND' place=90
-- SKIPPED (international, no master data): 'LIULCHENKO' place=91
-- SKIPPED (international, no master data): 'BRAUN' place=92
-- SKIPPED (international, no master data): 'DITHMAR' place=93
-- SKIPPED (international, no master data): 'GRUNOW' place=94
-- SKIPPED (international, no master data): 'LIVENAIS' place=95
-- SKIPPED (international, no master data): 'MUNNICH' place=96
-- SKIPPED (international, no master data): 'ONCOY DE FANASCH' place=97
-- SKIPPED (international, no master data): 'CHAUVAT' place=98
-- SKIPPED (international, no master data): 'WIESMULLER' place=99
-- SKIPPED (international, no master data): 'KIRCHHOF' place=100
-- SKIPPED (international, no master data): 'LOEHLER' place=101
-- SKIPPED (international, no master data): 'NEUMANN' place=102
-- SKIPPED (international, no master data): 'SCHULZ' place=103
-- SKIPPED (international, no master data): 'SEIDEL' place=104
-- SKIPPED (international, no master data): 'VAN DER SCHUEREN' place=105
-- Compute scores for IMEW-V2-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-F-EPEE-2023-2024')
);

-- Summary
-- Total results matched:   50
-- Total results unmatched: 103
-- Total auto-created:      0
