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
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-F-EPEE-2023-2024'),
    1,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    183,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V2-F-EPEE-2023-2024'),
    2,
    'POJMAŃSKA Katarzyna'
); -- matched: POJMAŃSKA Katarzyna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
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
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-F-EPEE-2023-2024'),
    1,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    246,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-F-EPEE-2023-2024'),
    2,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V2-F-EPEE-2023-2024'),
    3,
    'WALECKA Wanda'
); -- matched: WALECKA Wanda (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    180,
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
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-F-EPEE-2023-2024'),
    1,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    246,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-F-EPEE-2023-2024'),
    2,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    155,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-F-EPEE-2023-2024'),
    3,
    'MILOVA Tatiana'
); -- matched: MILOVA Tatiana (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    343,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-F-EPEE-2023-2024'),
    4,
    'SADOWIŃSKA Adriana'
); -- matched: SADOWIŃSKA Adriana (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-F-EPEE-2023-2024'),
    5,
    'WALECKA Wanda'
); -- matched: WALECKA Wanda (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    19,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V2-F-EPEE-2023-2024'),
    6,
    'BORKOWSKA Halina'
); -- matched: BORKOWSKA Halina (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    180,
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
    246,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-F-EPEE-2023-2024'),
    1,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-F-EPEE-2023-2024'),
    2,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    155,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V2-F-EPEE-2023-2024'),
    3,
    'MILOVA Tatiana'
); -- matched: MILOVA Tatiana (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
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
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-F-EPEE-2023-2024'),
    1,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    246,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V2-F-EPEE-2023-2024'),
    2,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
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
    215,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-F-EPEE-2023-2024'),
    1,
    'STAŃCZYK Agnieszka'
); -- matched: STAŃCZYK Agnieszka (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-F-EPEE-2023-2024'),
    2,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    155,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-F-EPEE-2023-2024'),
    3,
    'MILOVA Tatiana'
); -- matched: MILOVA Tatiana (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    343,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V2-F-EPEE-2023-2024'),
    4,
    'SADOWIŃSKA Adriana'
); -- matched: SADOWIŃSKA Adriana (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
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
    215,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-F-EPEE-2023-2024'),
    1,
    'STAŃCZYK Agnieszka'
); -- matched: STAŃCZYK Agnieszka (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    246,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-F-EPEE-2023-2024'),
    2,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V2-F-EPEE-2023-2024'),
    3,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
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
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-F-EPEE-2023-2024'),
    1,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    296,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-F-EPEE-2023-2024'),
    2,
    'KARMAN Irene'
); -- matched: KARMAN Irene (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    180,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V2-F-EPEE-2023-2024'),
    3,
    'PILARSKA Barbara'
); -- matched: PILARSKA Barbara (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
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
    246,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-F-EPEE-2023-2024'),
    1,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
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
    246,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-F-EPEE-2023-2024'),
    3,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-F-EPEE-2023-2024'),
    3,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-F-EPEE-2023-2024'),
    5,
    'WALECKA Wanda'
); -- matched: WALECKA Wanda (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    180,
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
    246,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-F-EPEE-2023-2024'),
    3,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    61,
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
    61,
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
    61,
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
    246,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-F-EPEE-2023-2024'),
    3,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    215,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-F-EPEE-2023-2024'),
    3,
    'STAŃCZYK Agnieszka'
); -- matched: STAŃCZYK Agnieszka (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V2-F-EPEE-2023-2024'),
    8,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
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
-- UNMATCHED (score<80): 'USHER' place=1
-- UNMATCHED (score<80): 'DE VARGAS HILLA' place=2
-- UNMATCHED (score<80): 'KERVEADOU' place=3
-- UNMATCHED (score<80): 'LORENZ' place=3
-- UNMATCHED (score<80): 'LAISNEY' place=5
-- UNMATCHED (score<80): 'PREAUX' place=6
-- UNMATCHED (score<80): 'CHARROY' place=7
-- UNMATCHED (score<80): 'TANZMEISTER' place=8
-- UNMATCHED (score<80): 'DE GROOTE' place=9
-- UNMATCHED (score<80): 'DUCHNOWSKI' place=10
-- UNMATCHED (score<80): 'BOUQUET' place=11
-- UNMATCHED (score<80): 'GURWIC' place=12
-- UNMATCHED (score<80): 'FLEURY' place=13
-- UNMATCHED (score<80): 'STIHL' place=14
-- UNMATCHED (score<80): 'THOULESS' place=15
-- UNMATCHED (score<80): 'CANO DIOSA' place=16
-- UNMATCHED (score<80): 'GRAF' place=17
-- UNMATCHED (score<80): 'VANDEWALLE' place=18
-- UNMATCHED (score<80): 'HAUTERVILLE' place=19
-- UNMATCHED (score<80): 'BUGALLO OTERO' place=20
-- UNMATCHED (score<80): 'TIPPELT' place=21
-- UNMATCHED (score<80): 'STROHMEYER' place=22
-- UNMATCHED (score<80): 'EHLERMANN' place=23
-- UNMATCHED (score<80): 'VAN DER VEEN' place=24
-- UNMATCHED (score<80): 'APPAVOUPOULLE' place=25
-- UNMATCHED (score<80): 'FICHTEL' place=26
-- UNMATCHED (score<80): 'MARHEINEKE' place=27
-- UNMATCHED (score<80): 'PAGNY' place=28
-- UNMATCHED (score<80): 'ONIYE' place=29
-- UNMATCHED (score<80): 'VALAR' place=30
-- UNMATCHED (score<80): 'VAN DEN BERG' place=31
-- UNMATCHED (score<80): 'MAYER' place=32
-- UNMATCHED (score<80): 'VALERA SANCHEZ' place=33
-- UNMATCHED (score<80): 'CHALON' place=34
-- UNMATCHED (score<80): 'BOYKO' place=35
-- UNMATCHED (score<80): 'BJORK' place=36
-- UNMATCHED (score<80): 'SKAALID' place=37
-- UNMATCHED (score<80): 'KOJO' place=38
-- UNMATCHED (score<80): 'BONATO' place=39
-- UNMATCHED (score<80): 'NOVOSELSKA' place=40
-- UNMATCHED (score<80): 'TROLL' place=41
-- UNMATCHED (score<80): 'HULL' place=42
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    334,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-F-EPEE-2023-2024'),
    43,
    'PRAHA-TSAREHRADSKA'
); -- matched: PRAHA-TSAREHRADSKA Nadiia (score=83.72093023255813)
-- UNMATCHED (score<80): 'SCHMID-PFAUS' place=44
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-F-EPEE-2023-2024'),
    45,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
-- UNMATCHED (score<80): 'POUBLANC-LEDUN' place=46
-- UNMATCHED (score<80): 'REIMERS' place=47
-- UNMATCHED (score<80): 'HESKETA' place=48
-- UNMATCHED (score<80): 'HOM' place=49
-- UNMATCHED (score<80): 'GRANT' place=50
-- UNMATCHED (score<80): 'STRAUB' place=51
-- UNMATCHED (score<80): 'PRESSE' place=52
-- UNMATCHED (score<80): 'ALBERTSON' place=53
-- UNMATCHED (score<80): 'VAZQUEZ CORBACHO' place=54
-- UNMATCHED (score<80): 'BUDDEN' place=55
-- UNMATCHED (score<80): 'VILLEMONT' place=56
-- UNMATCHED (score<80): 'STRAUB' place=57
-- UNMATCHED (score<80): 'CALAMBE' place=58
-- UNMATCHED (score<80): 'ALTKEMPER' place=59
-- UNMATCHED (score<80): 'SKOKANOVA' place=60
-- UNMATCHED (score<80): 'SPEER' place=61
-- UNMATCHED (score<80): 'HORI' place=62
-- UNMATCHED (score<80): 'EICHNER-BRUNING' place=63
-- UNMATCHED (score<80): 'VINCENT VELGHE' place=64
-- UNMATCHED (score<80): 'CLAVOT' place=65
-- UNMATCHED (score<80): 'KOS' place=66
-- UNMATCHED (score<80): 'MION' place=67
-- UNMATCHED (score<80): 'WEINHOLTZ' place=68
-- UNMATCHED (score<80): 'ARNOLD' place=69
-- UNMATCHED (score<80): 'KYMALAINEN' place=70
-- UNMATCHED (score<80): 'CAVO' place=71
-- UNMATCHED (score<80): 'AUERBACH' place=72
-- UNMATCHED (score<80): 'VAN BERGEN' place=73
-- UNMATCHED (score<80): 'BRUNET' place=74
-- UNMATCHED (score<80): 'OLIER' place=75
-- UNMATCHED (score<80): 'VIITA' place=76
-- UNMATCHED (score<80): 'JEDAMZIK' place=77
-- UNMATCHED (score<80): 'WAELLE' place=78
-- UNMATCHED (score<80): 'TORDA' place=79
-- UNMATCHED (score<80): 'NIEDERMEIER' place=80
-- UNMATCHED (score<80): 'KARMAN' place=81
-- UNMATCHED (score<80): 'ASQUINI' place=82
-- UNMATCHED (score<80): 'ROUSSELOT' place=83
-- UNMATCHED (score<80): 'PARK-BHASIN' place=84
-- UNMATCHED (score<80): 'WOLFF' place=85
-- UNMATCHED (score<80): 'FOLZ' place=86
-- UNMATCHED (score<80): 'SCHOBER' place=87
-- UNMATCHED (score<80): 'GRABHER-RHOMBERG' place=88
-- UNMATCHED (score<80): 'KASOLYNE DEKANY' place=89
-- UNMATCHED (score<80): 'SCHNEIDEWIND' place=90
-- UNMATCHED (score<80): 'LIULCHENKO' place=91
-- UNMATCHED (score<80): 'BRAUN' place=92
-- UNMATCHED (score<80): 'DITHMAR' place=93
-- UNMATCHED (score<80): 'GRUNOW' place=94
-- UNMATCHED (score<80): 'LIVENAIS' place=95
-- UNMATCHED (score<80): 'MUNNICH' place=96
-- UNMATCHED (score<80): 'ONCOY DE FANASCH' place=97
-- UNMATCHED (score<80): 'CHAUVAT' place=98
-- UNMATCHED (score<80): 'WIESMULLER' place=99
-- UNMATCHED (score<80): 'KIRCHHOF' place=100
-- UNMATCHED (score<80): 'LOEHLER' place=101
-- UNMATCHED (score<80): 'NEUMANN' place=102
-- UNMATCHED (score<80): 'SCHULZ' place=103
-- UNMATCHED (score<80): 'SEIDEL' place=104
-- UNMATCHED (score<80): 'VAN DER SCHUEREN' place=105
-- Compute scores for IMEW-V2-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-F-EPEE-2023-2024')
);

-- Summary
-- Total results matched:   50
-- Total results unmatched: 103
