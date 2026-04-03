-- =========================================================================
-- Season 2024-2025 — V2 F EPEE — generated from SZPADA-K2-2024-2025.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- ---- PP1: I Puchar Polski Weteranów (KONIN) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW1-2024-2025',
    'I Puchar Polski Weteranów',
    'KONIN',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW1-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW1-2024-2025'),
    'PPW1-V2-F-EPEE-2024-2025',
    'I Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'F', 'V2',
    '2024-09-28', 5, 'https://onedrive.live.com/?id=7038EB1D96BF1AB%21684&cid=07038EB1D96BF1AB',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    246,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-F-EPEE-2024-2025'),
    1,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-F-EPEE-2024-2025'),
    2,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
-- UNMATCHED (score<80): 'ANNA-LISE Mion' place=3
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    227,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-F-EPEE-2024-2025'),
    4,
    'SZURLEJ Agata'
); -- matched: SZURLEJ Agata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-F-EPEE-2024-2025'),
    5,
    'WALECKA Wanda'
); -- matched: WALECKA Wanda (score=100.0)
-- Compute scores for PP1-V2-F-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-F-EPEE-2024-2025')
);

-- ---- PP2: II Puchar Polski Weteranów (BYTOM) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW2-2024-2025',
    'II Puchar Polski Weteranów',
    'BYTOM',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW2-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW2-2024-2025'),
    'PPW2-V2-F-EPEE-2024-2025',
    'II Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'F', 'V2',
    '2024-10-26', 5, 'https://www.fencingtimelive.com/events/results/33F5A948D6B7468DB683993AB31F40AD',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    246,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-F-EPEE-2024-2025'),
    1,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    215,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-F-EPEE-2024-2025'),
    2,
    'STAŃCZYK Agnieszka'
); -- matched: STAŃCZYK Agnieszka (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    227,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-F-EPEE-2024-2025'),
    3,
    'SZURLEJ Agata'
); -- matched: SZURLEJ Agata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-F-EPEE-2024-2025'),
    4,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-F-EPEE-2024-2025'),
    5,
    'WALECKA Wanda'
); -- matched: WALECKA Wanda (score=100.0)
-- Compute scores for PP2-V2-F-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-F-EPEE-2024-2025')
);

-- ---- PP3: III Puchar Polski Weteranów (KRAKÓW) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW3-2024-2025',
    'III Puchar Polski Weteranów',
    'KRAKÓW',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW3-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW3-2024-2025'),
    'PPW3-V2-F-EPEE-2024-2025',
    'III Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'F', 'V2',
    '2024-11-30', 6, 'https://www.fencingtimelive.com/events/results/0A7A4E1415FB499FAF50C192DB294D41',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    246,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-F-EPEE-2024-2025'),
    1,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    215,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-F-EPEE-2024-2025'),
    2,
    'STAŃCZYK Agnieszka'
); -- matched: STAŃCZYK Agnieszka (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-F-EPEE-2024-2025'),
    3,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    227,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-F-EPEE-2024-2025'),
    4,
    'SZURLEJ Agata'
); -- matched: SZURLEJ Agata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    201,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-F-EPEE-2024-2025'),
    5,
    'SADOWIŃSKA Adriana'
); -- matched: SADOWIŃSKA Adrianna (score=97.2972972972973)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    140,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-F-EPEE-2024-2025'),
    6,
    'LASKUS KRYSTYNA'
); -- matched: LASKUS Krystyna (score=100.0)
-- Compute scores for PP3-V2-F-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-F-EPEE-2024-2025')
);

-- ---- MPW: Mistrzostwa Polski Weteranów (PABIANICE) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'MPW-2024-2025',
    'Mistrzostwa Polski Weteranów',
    'PABIANICE',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'MPW-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'MPW-2024-2025'),
    'MPW-V2-F-EPEE-2024-2025',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'EPEE', 'F', 'V2',
    '2025-06-07', 4, 'https://www.fencingtimelive.com/events/results/95A177163F134F2689CECDA26D752406',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    246,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-F-EPEE-2024-2025'),
    1,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-F-EPEE-2024-2025'),
    2,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    201,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-F-EPEE-2024-2025'),
    3,
    'SADOWIŃSKA Adriana'
); -- matched: SADOWIŃSKA Adrianna (score=97.2972972972973)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    243,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-F-EPEE-2024-2025'),
    4,
    'WALECKA Wanda'
); -- matched: WALECKA Wanda (score=100.0)
-- Compute scores for MPW-V2-F-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-F-EPEE-2024-2025')
);

-- ---- PEW1: EVF Grand Prix 1 — Budapeszt (Budapeszt) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW1-2024-2025',
    'EVF Grand Prix 1 — Budapeszt',
    'Budapeszt',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW1-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1-2024-2025'),
    'PEW1-V2-F-EPEE-2024-2025',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'EPEE', 'F', 'V2',
    '2024-09-21', 19, 'https://engarde-service.com/app.php?id=4208L2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    246,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-F-EPEE-2024-2025'),
    8,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-F-EPEE-2024-2025'),
    17,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
-- Compute scores for PEW1-V2-F-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-F-EPEE-2024-2025')
);

-- ---- PEW2: EVF Grand Prix 2 — Madryt (Madrid) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW2-2024-2025',
    'EVF Grand Prix 2 — Madryt',
    'Madrid',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW2-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW2-2024-2025'),
    'PEW2-V2-F-EPEE-2024-2025',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'EPEE', 'F', 'V2',
    '2024-11-16', 30, 'https://engarde-service.com/competition/aeve_esgrima/evf_madrid_2024/ef-2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-F-EPEE-2024-2025'),
    22,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    227,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-F-EPEE-2024-2025'),
    27,
    'SZURLEJ Agata'
); -- matched: SZURLEJ Agata (score=100.0)
-- Compute scores for PEW2-V2-F-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-F-EPEE-2024-2025')
);

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): N=0 — tournament had no participants

-- ---- IMEW: Indywidualne Mistrzostwa Europy Weteranów (Płowdiw) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'IMEW-2024-2025',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'Płowdiw',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'IMEW-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'IMEW-2024-2025'),
    'IMEW-V2-F-EPEE-2024-2025',
    'Indywidualne Mistrzostwa Europy Weteranów',
    'MEW',
    'EPEE', 'F', 'V2',
    '2025-05-29', 83, 'https://www.fencingtimelive.com/events/results/4FB275ABB46B48C48DC4BB4A43C48198',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    61,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-F-EPEE-2024-2025'),
    49,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
-- Compute scores for IMEW-V2-F-EPEE-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-F-EPEE-2024-2025')
);

-- Summary
-- Total results matched:   24
-- Total results unmatched: 1
