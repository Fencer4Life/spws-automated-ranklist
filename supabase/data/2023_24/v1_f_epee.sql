-- =========================================================================
-- Season 2023-2024 — V1 F EPEE — generated from SZPADA-K1-2023-2024.xlsx
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
    'GP1-V1-F-EPEE-2023-2024',
    'Grand Prix (runda 1)',
    'PPW',
    'EPEE', 'F', 'V1',
    '2023-01-14', 6, 'https://www.fencingtimelive.com/events/results/D5F0053E96D54A7981A5D432EEF17132',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    202,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-F-EPEE-2023-2024'),
    1,
    'SADOWSKA Małgorzata'
); -- matched: SADOWSKA Małgorzata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-F-EPEE-2023-2024'),
    2,
    'KAMIŃSKA Gabriela'
); -- matched: KAMIŃSKA Gabriela (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    101,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-F-EPEE-2023-2024'),
    3,
    'KASPRZYK-KUŹNIAK Michalina'
); -- matched: KASPRZYK-KUŹNIAK Michalina (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    227,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-F-EPEE-2023-2024'),
    4,
    'SZURLEJ Agata'
); -- matched: SZURLEJ Agata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    164,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-F-EPEE-2023-2024'),
    5,
    'NOWAK Marta'
); -- matched: NOWAK Marta (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    244,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-F-EPEE-2023-2024'),
    6,
    'WALENCIUK Urszula'
); -- matched: WALENCIUK Urszula (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    127,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-F-EPEE-2023-2024'),
    8,
    'KOWALSKA Milena'
); -- matched: KOWALSKA Milena (score=100.0)
-- Compute scores for GP1-V1-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP1-V1-F-EPEE-2023-2024')
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
    'GP2-V1-F-EPEE-2023-2024',
    'Grand Prix (runda 2)',
    'PPW',
    'EPEE', 'F', 'V1',
    '2023-03-04', 4, 'https://www.fencingtimelive.com/events/results/FE114AD3AE124CD4802B257A04DE4F7A',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    227,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-F-EPEE-2023-2024'),
    1,
    'SZURLEJ Agata'
); -- matched: SZURLEJ Agata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    180,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-F-EPEE-2023-2024'),
    2,
    'PILARSKA Barbara'
); -- matched: PILARSKA Barbara (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    101,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-F-EPEE-2023-2024'),
    3,
    'KASPRZYK-KUŹNIAK Michalina'
); -- matched: KASPRZYK-KUŹNIAK Michalina (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    202,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-F-EPEE-2023-2024'),
    4,
    'SADOWSKA Małgorzata'
); -- matched: SADOWSKA Małgorzata (score=100.0)
-- Compute scores for GP2-V1-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP2-V1-F-EPEE-2023-2024')
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
    'GP3-V1-F-EPEE-2023-2024',
    'Grand Prix (runda 3)',
    'PPW',
    'EPEE', 'F', 'V1',
    '2023-06-17', 6, 'https://www.fencingtimelive.com/events/results/44EEEF6869924866830132F2591EB315',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-F-EPEE-2023-2024'),
    1,
    'KAMIŃSKA Gabriela'
); -- matched: KAMIŃSKA Gabriela (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    180,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-F-EPEE-2023-2024'),
    2,
    'PILARSKA Barbara'
); -- matched: PILARSKA Barbara (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    227,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-F-EPEE-2023-2024'),
    3,
    'SZURLEJ Agata'
); -- matched: SZURLEJ Agata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    349,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-F-EPEE-2023-2024'),
    4,
    'SPIRINA Ekaterina'
); -- matched: SPIRINA Ekaterina (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    101,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-F-EPEE-2023-2024'),
    5,
    'KASPRZYK-KUŹNIAK Michalina'
); -- matched: KASPRZYK-KUŹNIAK Michalina (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    164,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-F-EPEE-2023-2024'),
    6,
    'NOWAK Marta'
); -- matched: NOWAK Marta (score=100.0)
-- Compute scores for GP3-V1-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP3-V1-F-EPEE-2023-2024')
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
    'GP4-V1-F-EPEE-2023-2024',
    'Grand Prix (runda 4)',
    'PPW',
    'EPEE', 'F', 'V1',
    '2023-10-23', 3, 'https://www.fencingtimelive.com/events/results/2DCF2867DB904B869049683C92F63369',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    108,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V1-F-EPEE-2023-2024'),
    1,
    'KŁOS Iwona'
); -- matched: KŁOS Iwona (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    101,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V1-F-EPEE-2023-2024'),
    2,
    'KASPRZYK-KUŹNIAK Michalina'
); -- matched: KASPRZYK-KUŹNIAK Michalina (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    227,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V1-F-EPEE-2023-2024'),
    3,
    'SZURLEJ Agata'
); -- matched: SZURLEJ Agata (score=100.0)
-- Compute scores for GP4-V1-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP4-V1-F-EPEE-2023-2024')
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
    'GP5-V1-F-EPEE-2023-2024',
    'Grand Prix (runda 5)',
    'PPW',
    'EPEE', 'F', 'V1',
    '2023-10-28', 4, 'https://www.fencingtimelive.com/events/results/43BA8AF7E2A842D29A509341ACE7659A',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V1-F-EPEE-2023-2024'),
    1,
    'KAMIŃSKA Gabriela'
); -- matched: KAMIŃSKA Gabriela (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    127,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V1-F-EPEE-2023-2024'),
    2,
    'KOWALSKA Milena'
); -- matched: KOWALSKA Milena (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    202,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V1-F-EPEE-2023-2024'),
    3,
    'SADOWSKA Małgorzata'
); -- matched: SADOWSKA Małgorzata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    101,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V1-F-EPEE-2023-2024'),
    4,
    'KASPRZYK-KUŹNIAK Michalina'
); -- matched: KASPRZYK-KUŹNIAK Michalina (score=100.0)
-- Compute scores for GP5-V1-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP5-V1-F-EPEE-2023-2024')
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
    'GP6-V1-F-EPEE-2023-2024',
    'Grand Prix (runda 6)',
    'PPW',
    'EPEE', 'F', 'V1',
    '2023-11-18', 4, 'https://www.fencingtimelive.com/events/results/A7DFE688BD214A7C974CB84E879C5BA9',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V1-F-EPEE-2023-2024'),
    1,
    'KAMIŃSKA Gabriela'
); -- matched: KAMIŃSKA Gabriela (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    202,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V1-F-EPEE-2023-2024'),
    2,
    'SADOWSKA Małgorzata'
); -- matched: SADOWSKA Małgorzata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    108,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V1-F-EPEE-2023-2024'),
    3,
    'KŁOS Iwona'
); -- matched: KŁOS Iwona (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    227,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V1-F-EPEE-2023-2024'),
    4,
    'SZURLEJ Agata'
); -- matched: SZURLEJ Agata (score=100.0)
-- Compute scores for GP6-V1-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP6-V1-F-EPEE-2023-2024')
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
    'GP7-V1-F-EPEE-2023-2024',
    'Grand Prix (runda 7)',
    'PPW',
    'EPEE', 'F', 'V1',
    '2024-01-27', 4, 'https://www.fencingtimelive.com/events/results/15D820D5BA9A442AA26E2B4B816F091F',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    227,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-F-EPEE-2023-2024'),
    1,
    'SZURLEJ Agata'
); -- matched: SZURLEJ Agata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    108,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-F-EPEE-2023-2024'),
    2,
    'KŁOS Iwona'
); -- matched: KŁOS Iwona (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-F-EPEE-2023-2024'),
    3,
    'KAMIŃSKA Gabriela'
); -- matched: KAMIŃSKA Gabriela (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    164,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-F-EPEE-2023-2024'),
    4,
    'NOWAK Marta'
); -- matched: NOWAK Marta (score=100.0)
-- Compute scores for GP7-V1-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'GP7-V1-F-EPEE-2023-2024')
);

-- SKIP GP8 (Grand Prix (runda 8)): N=0 — tournament had no participants

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
    'MPW-V1-F-EPEE-2023-2024',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'EPEE', 'F', 'V1',
    '2024-03-02', 4, 'https://www.fencingtimelive.com/events/results/51602A5C205A48F1A0CCE625BEFEFD1E',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-F-EPEE-2023-2024'),
    1,
    'KAMIŃSKA Gabriela'
); -- matched: KAMIŃSKA Gabriela (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    202,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-F-EPEE-2023-2024'),
    2,
    'SADOWSKA Małgorzata'
); -- matched: SADOWSKA Małgorzata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    127,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-F-EPEE-2023-2024'),
    3,
    'KOWALSKA Milena'
); -- matched: KOWALSKA Milena (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    227,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-F-EPEE-2023-2024'),
    4,
    'SZURLEJ Agata'
); -- matched: SZURLEJ Agata (score=100.0)
-- Compute scores for MPW-V1-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V1-F-EPEE-2023-2024')
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
    'PEW1-V1-F-EPEE-2023-2024',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'EPEE', 'F', 'V1',
    '2023-01-07', 19, 'https://www.fencingtimelive.com/events/results/696F56DF89DA4A0CB023806DCB615D97',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-F-EPEE-2023-2024'),
    8,
    'KAMIŃSKA Gabriela'
); -- matched: KAMIŃSKA Gabriela (score=100.0)
-- Compute scores for PEW1-V1-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-F-EPEE-2023-2024')
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
    'PEW2-V1-F-EPEE-2023-2024',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'EPEE', 'F', 'V1',
    '2023-02-25', 6, 'https://engarde-service.com/index.php?lang=en&Organisme=santanderfencing&Event=evf_epee_circuit_santander&Compe=w_epee_v1',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-F-EPEE-2023-2024'),
    2,
    'KAMIŃSKA Gabriela'
); -- matched: KAMIŃSKA Gabriela (score=100.0)
-- Compute scores for PEW2-V1-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-F-EPEE-2023-2024')
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
    'PEW3-V1-F-EPEE-2023-2024',
    'EVF Grand Prix 3',
    'PEW',
    'EPEE', 'F', 'V1',
    '2023-04-15', 9, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    202,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-F-EPEE-2023-2024'),
    5,
    'SADOWSKA Małgorzata'
); -- matched: SADOWSKA Małgorzata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    180,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-F-EPEE-2023-2024'),
    6,
    'PILARSKA Barbara'
); -- matched: PILARSKA Barbara (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    227,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-F-EPEE-2023-2024'),
    8,
    'SZURLEJ Agata'
); -- matched: SZURLEJ Agata (score=100.0)
-- Compute scores for PEW3-V1-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-F-EPEE-2023-2024')
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
    'PEW4-V1-F-EPEE-2023-2024',
    'EVF Grand Prix 4',
    'PEW',
    'EPEE', 'F', 'V1',
    '2023-09-16', 14, 'https://engarde-service.com/?fbclid=IwAR1q8b20973WNdhLRYbl3vdP-rPK0cilvuHZi37KFNf-Dodoicffb3YOQeM',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-F-EPEE-2023-2024'),
    9,
    'KAMIŃSKA Gabriela'
); -- matched: KAMIŃSKA Gabriela (score=100.0)
-- Compute scores for PEW4-V1-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-F-EPEE-2023-2024')
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
    'PEW5-V1-F-EPEE-2023-2024',
    'EVF Grand Prix 5',
    'PEW',
    'EPEE', 'F', 'V1',
    '2023-09-24', 9, 'https://www.fencingtimelive.com/events/results/B287CD289AC54EFCB581067FAA32F555',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V1-F-EPEE-2023-2024'),
    2,
    'KAMIŃSKA Gabriela'
); -- matched: KAMIŃSKA Gabriela (score=100.0)
-- Compute scores for PEW5-V1-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V1-F-EPEE-2023-2024')
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
    'PEW6-V1-F-EPEE-2023-2024',
    'EVF Grand Prix 6',
    'PEW',
    'EPEE', 'F', 'V1',
    '2023-11-11', 21, 'https://engarde-service.com/competition/aeve_esgrima/evf_madrid_2023/ef_1',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-F-EPEE-2023-2024'),
    3,
    'KAMIŃSKA Gabriela'
); -- matched: KAMIŃSKA Gabriela (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    202,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-F-EPEE-2023-2024'),
    21,
    'SADOWSKA Małgorzata'
); -- matched: SADOWSKA Małgorzata (score=100.0)
-- Compute scores for PEW6-V1-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-F-EPEE-2023-2024')
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
    'PEW7-V1-F-EPEE-2023-2024',
    'EVF Grand Prix 7 — Terni',
    'PEW',
    'EPEE', 'F', 'V1',
    '2023-12-16', 21, 'https://www.4fence.it/FIS/Risultati/2023-12-17-16_Terni_(TR)_-_3_Prova_Circuito_Naz.le_Master/index.php?a=SP&s=F&c=6&f=clafinale',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-F-EPEE-2023-2024'),
    11,
    'KAMIŃSKA Gabriela'
); -- matched: KAMIŃSKA Gabriela (score=100.0)
-- Compute scores for PEW7-V1-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-F-EPEE-2023-2024')
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
    'PEW8-V1-F-EPEE-2023-2024',
    'EVF Grand Prix 8 — Guildford',
    'PEW',
    'EPEE', 'F', 'V1',
    '2024-01-06', 24, 'https://www.fencingtimelive.com/events/results/FCAA4BAD1428497A83A3A91B24C23432',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V1-F-EPEE-2023-2024'),
    3,
    'KAMIŃSKA Gabriela'
); -- matched: KAMIŃSKA Gabriela (score=100.0)
-- Compute scores for PEW8-V1-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V1-F-EPEE-2023-2024')
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
    'PEW9-V1-F-EPEE-2023-2024',
    'EVF Grand Prix 9 — Sztokholm',
    'PEW',
    'EPEE', 'F', 'V1',
    '2024-02-24', 10, 'https://engarde-service.com/competition/sthlm/efv2024/ewv1',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW9-V1-F-EPEE-2023-2024'),
    5,
    'KAMIŃSKA Gabriela'
); -- matched: KAMIŃSKA Gabriela (score=100.0)
-- Compute scores for PEW9-V1-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW9-V1-F-EPEE-2023-2024')
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
    'PEW11-V1-F-EPEE-2023-2024',
    'EVF Grand Prix 11 — Gdańsk',
    'PEW',
    'EPEE', 'F', 'V1',
    '2024-04-06', 10, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V1-F-EPEE-2023-2024'),
    2,
    'KAMIŃSKA Gabriela'
); -- matched: KAMIŃSKA Gabriela (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    127,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V1-F-EPEE-2023-2024'),
    5,
    'KOWALSKA Milena'
); -- matched: KOWALSKA Milena (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    202,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V1-F-EPEE-2023-2024'),
    8,
    'SADOWSKA Małgorzata'
); -- matched: SADOWSKA Małgorzata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    108,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V1-F-EPEE-2023-2024'),
    9,
    'KŁOS Iwona'
); -- matched: KŁOS Iwona (score=100.0)
-- Compute scores for PEW11-V1-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW11-V1-F-EPEE-2023-2024')
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
    'IMEW-V1-F-EPEE-2023-2024',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'EPEE', 'F', 'V1',
    '2023-01-01', 82, 'https://engarde-service.com/competition/e3f/efcv/womenepeev1',
    'SCORED'
);
-- UNMATCHED (score<80): 'DUMOULIN' place=1
-- UNMATCHED (score<80): 'ERGAND' place=2
-- UNMATCHED (score<80): 'HYVONEN' place=3
-- UNMATCHED (score<80): 'RODRIGUEZ GARCIA' place=3
-- UNMATCHED (score<80): 'TERZANI' place=5
-- UNMATCHED (score<80): 'FEYTIE BRAVAIS' place=6
-- UNMATCHED (score<80): 'CHEVALIER' place=7
-- UNMATCHED (score<80): 'SZINI' place=8
-- UNMATCHED (score<80): 'SAPIN-DORNACHER' place=9
-- UNMATCHED (score<80): 'MULLER-BRAKER' place=10
-- UNMATCHED (score<80): 'CUSCINI' place=11
-- UNMATCHED (score<80): 'ENRIGHT' place=12
-- UNMATCHED (score<80): 'BRIANCHON' place=13
-- UNMATCHED (score<80): 'BARCLAY' place=14
-- UNMATCHED (score<80): 'MODIN' place=15
-- UNMATCHED (score<80): 'SOLDAI' place=16
-- UNMATCHED (score<80): 'REUMUELLER' place=17
-- UNMATCHED (score<80): 'PETROVSKA' place=18
-- UNMATCHED (score<80): 'MAJOREL' place=19
-- UNMATCHED (score<80): 'HERCZEG' place=20
-- UNMATCHED (score<80): 'PURICELLI' place=21
-- UNMATCHED (score<80): 'LAHAUT' place=22
-- UNMATCHED (score<80): 'PREISSLER' place=23
-- UNMATCHED (score<80): 'HARGINA' place=24
-- UNMATCHED (score<80): 'EGYUD' place=25
-- UNMATCHED (score<80): 'MADER' place=26
-- UNMATCHED (score<80): 'PELA' place=27
-- UNMATCHED (score<80): 'MAJERUS' place=28
-- UNMATCHED (score<80): 'VITALYOS' place=29
-- UNMATCHED (score<80): 'BRESSER' place=30
-- UNMATCHED (score<80): 'THEUNISSSEN' place=31
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    202,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-F-EPEE-2023-2024'),
    32,
    'SADOWSKA Małgorzata'
); -- matched: SADOWSKA Małgorzata (score=100.0)
-- UNMATCHED (score<80): 'LOWACK' place=33
-- UNMATCHED (score<80): 'ZMAIC' place=34
-- UNMATCHED (score<80): 'HUPFER' place=35
-- UNMATCHED (score<80): 'REED' place=36
-- UNMATCHED (score<80): 'VALORZI' place=37
-- UNMATCHED (score<80): 'GOMEZ MARTIN' place=38
-- UNMATCHED (score<80): 'NICOLAY' place=39
-- UNMATCHED (score<80): 'SCHREUER' place=40
-- UNMATCHED (score<80): 'DANLOUP' place=41
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-F-EPEE-2023-2024'),
    42,
    'KAMIŃSKA Gabriela'
); -- matched: KAMIŃSKA Gabriela (score=100.0)
-- UNMATCHED (score<80): 'BORS' place=43
-- UNMATCHED (score<80): 'DERETIC' place=44
-- UNMATCHED (score<80): 'GUILLEMINOT ROUX' place=45
-- UNMATCHED (score<80): 'ROSENBERG' place=46
-- UNMATCHED (score<80): 'BOTEZ-HULUDET' place=47
-- UNMATCHED (score<80): 'HECKEBERG' place=48
-- UNMATCHED (score<80): 'COUTISSON' place=49
-- UNMATCHED (score<80): 'DOEMELAND' place=50
-- UNMATCHED (score<80): 'WITTING' place=51
-- UNMATCHED (score<80): 'PUKLIN VUCELIC' place=52
-- UNMATCHED (score<80): 'GLASER' place=53
-- UNMATCHED (score<80): 'WACQUEZ' place=54
-- UNMATCHED (score<80): 'CRUSTEWITZ' place=55
-- UNMATCHED (score<80): 'LASMOLLES' place=56
-- UNMATCHED (score<80): 'HEITMANN' place=57
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    227,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-F-EPEE-2023-2024'),
    58,
    'SZURLEJ Agata'
); -- matched: SZURLEJ Agata (score=100.0)
-- UNMATCHED (score<80): 'MICHEL' place=59
-- UNMATCHED (score<80): 'STANDISH-LEIGH' place=60
-- UNMATCHED (score<80): 'MORONI' place=61
-- UNMATCHED (score<80): 'TRAPANESE' place=62
-- UNMATCHED (score<80): 'HELDMANN' place=63
-- UNMATCHED (score<80): 'CHEMOUILLI' place=64
-- UNMATCHED (score<80): 'MOSCA' place=65
-- UNMATCHED (score<80): 'BERARD' place=66
-- UNMATCHED (score<80): 'ANDERSEN' place=67
-- UNMATCHED (score<80): 'HIRSCHAUER' place=68
-- UNMATCHED (score<80): 'ESTIOT' place=69
-- UNMATCHED (score<80): 'BONJEAN' place=70
-- UNMATCHED (score<80): 'HERENDA' place=71
-- UNMATCHED (score<80): 'MADER' place=72
-- UNMATCHED (score<80): 'MENG' place=73
-- UNMATCHED (score<80): 'LEMMER' place=74
-- UNMATCHED (score<80): 'GIOVANNETTI' place=75
-- UNMATCHED (score<80): 'TERRYN' place=76
-- UNMATCHED (score<80): 'PILARD' place=77
-- UNMATCHED (score<80): 'NAGEL' place=78
-- UNMATCHED (score<80): 'OEHLER' place=79
-- UNMATCHED (score<80): 'CLARKE' place=80
-- UNMATCHED (score<80): 'STABER' place=81
-- UNMATCHED (score<80): 'HIRSCHFELD' place=82
-- Compute scores for IMEW-V1-F-EPEE-2023-2024
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V1-F-EPEE-2023-2024')
);

-- Summary
-- Total results matched:   55
-- Total results unmatched: 79
