-- =========================================================================
-- Season 2023-2024 — V0 F EPEE — generated from SZPADA-K0-2023-2024.xlsx
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
    'GP1-V0-F-EPEE-2023-2024',
    'Grand Prix (runda 1)',
    'PPW',
    'EPEE', 'F', 'V0',
    '2023-01-14', 4, 'https://www.fencingtimelive.com/events/results/152F55D9994447F496948969942E530C',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    224,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-F-EPEE-2023-2024'),
    1,
    'REMIAN Paulina'
); -- matched: REMIAN Paulina (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    134,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-F-EPEE-2023-2024'),
    2,
    'KOWALSKA Milena'
); -- matched: KOWALSKA Milena (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    237,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-F-EPEE-2023-2024'),
    3,
    'SAMECKA-NACZYŃSKA Martyna'
); -- matched: SAMECKA-NACZYŃSKA Martyna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    284,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-F-EPEE-2023-2024'),
    4,
    'WALAS Zuzanna'
); -- matched: WALAS Zuzanna (score=100.0)
-- Compute scores for GP1-V0-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V0-F-EPEE-2023-2024')
);

-- SKIP GP2 (Grand Prix (runda 2)): N=0 — tournament had no participants

-- SKIP GP3 (Grand Prix (runda 3)): N=0 — tournament had no participants

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
    'GP4-V0-F-EPEE-2023-2024',
    'Grand Prix (runda 4)',
    'PPW',
    'EPEE', 'F', 'V0',
    '2023-10-23', 1, 'https://www.fencingtimelive.com/events/results/2DCF2867DB904B869049683C92F63369',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    12,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V0-F-EPEE-2023-2024'),
    1,
    'BARAN Agata'
); -- matched: BARAN Agata (score=100.0)
-- Compute scores for GP4-V0-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V0-F-EPEE-2023-2024')
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
    'GP5-V0-F-EPEE-2023-2024',
    'Grand Prix (runda 5)',
    'PPW',
    'EPEE', 'F', 'V0',
    '2023-10-28', 2, 'https://www.fencingtimelive.com/events/results/43BA8AF7E2A842D29A509341ACE7659A',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    237,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V0-F-EPEE-2023-2024'),
    1,
    'SAMECKA-NACZYŃSKA Martyna'
); -- matched: SAMECKA-NACZYŃSKA Martyna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    119,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V0-F-EPEE-2023-2024'),
    2,
    'KOCÓR Agata'
); -- matched: KOCÓR Agata (score=100.0)
-- Compute scores for GP5-V0-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V0-F-EPEE-2023-2024')
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
    'GP6-V0-F-EPEE-2023-2024',
    'Grand Prix (runda 6)',
    'PPW',
    'EPEE', 'F', 'V0',
    '2023-11-18', 5, 'https://www.fencingtimelive.com/events/results/0A50EC5BFA57423588A9174435C5C843',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    12,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V0-F-EPEE-2023-2024'),
    1,
    'BARAN Agata'
); -- matched: BARAN Agata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    237,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V0-F-EPEE-2023-2024'),
    2,
    'SAMECKA-NACZYŃSKA Martyna'
); -- matched: SAMECKA-NACZYŃSKA Martyna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    95,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V0-F-EPEE-2023-2024'),
    3,
    'IRZYK Sabina'
); -- matched: IRZYK Sabina (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    119,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V0-F-EPEE-2023-2024'),
    4,
    'KOCÓR Agata'
); -- matched: KOCÓR Agata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    284,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V0-F-EPEE-2023-2024'),
    5,
    'WALAS Zuzanna'
); -- matched: WALAS Zuzanna (score=100.0)
-- Compute scores for GP6-V0-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V0-F-EPEE-2023-2024')
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
    'GP7-V0-F-EPEE-2023-2024',
    'Grand Prix (runda 7)',
    'PPW',
    'EPEE', 'F', 'V0',
    '2024-01-27', 4, 'https://www.fencingtimelive.com/events/results/15D820D5BA9A442AA26E2B4B816F091F',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    237,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V0-F-EPEE-2023-2024'),
    1,
    'SAMECKA-NACZYŃSKA Martyna'
); -- matched: SAMECKA-NACZYŃSKA Martyna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    249,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V0-F-EPEE-2023-2024'),
    2,
    'SPIRINA Ekaterina'
); -- matched: SPIRINA Ekaterina (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    12,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V0-F-EPEE-2023-2024'),
    3,
    'BARAN Agata'
); -- matched: BARAN Agata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    95,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V0-F-EPEE-2023-2024'),
    4,
    'IRZYK Sabina'
); -- matched: IRZYK Sabina (score=100.0)
-- Compute scores for GP7-V0-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V0-F-EPEE-2023-2024')
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
    'GP8-V0-F-EPEE-2023-2024',
    'Grand Prix (runda 8)',
    'PPW',
    'EPEE', 'F', 'V0',
    '2024-06-22', 3, 'https://www.fencingtimelive.com/events/results/559322B9374C44AF8CFB6F9ED5D737DC',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    237,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V0-F-EPEE-2023-2024'),
    1,
    'SAMECKA-NACZYŃSKA Martyna'
); -- matched: SAMECKA-NACZYŃSKA Martyna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    95,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V0-F-EPEE-2023-2024'),
    2,
    'IRZYK Sabina'
); -- matched: IRZYK Sabina (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    119,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V0-F-EPEE-2023-2024'),
    3,
    'KOCÓR Agata'
); -- matched: KOCÓR Agata (score=100.0)
-- Compute scores for GP8-V0-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP8-V0-F-EPEE-2023-2024')
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
    'MPW-V0-F-EPEE-2023-2024',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'EPEE', 'F', 'V0',
    '2024-03-02', 1, 'https://www.fencingtimelive.com/events/results/51602A5C205A48F1A0CCE625BEFEFD1E',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    237,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-F-EPEE-2023-2024'),
    1,
    'SAMECKA-NACZYŃSKA Martyna'
); -- matched: SAMECKA-NACZYŃSKA Martyna (score=100.0)
-- Compute scores for MPW-V0-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V0-F-EPEE-2023-2024')
);

-- Summary
-- Total results matched:   20
-- Total results unmatched: 0
-- Total auto-created:      0
