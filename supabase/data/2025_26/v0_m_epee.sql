-- =========================================================================
-- Season 2025-2026 — V0 M EPEE — generated from SZPADA-0-2025-2026.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- ---- PP1: I Puchar Polski Weteranów (Szpada mężczyzn wetgerani 0) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW1-2025-2026',
    'I Puchar Polski Weteranów',
    'Szpada mężczyzn wetgerani 0',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW1-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW1-2025-2026'),
    'PPW1-V0-M-EPEE-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V0',
    NULL, 5, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    106,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-EPEE-2025-2026'),
    1,
    'KŁUSEK Damian'
); -- matched: KŁUSEK Damian (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    49,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-EPEE-2025-2026'),
    2,
    'DZIUBIŃSKI Mateusz'
); -- matched: DZIUBIŃSKI Mateusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    138,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-EPEE-2025-2026'),
    3,
    'KURBATSKYI Stepan'
); -- matched: KURBATSKYI Stepan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    90,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-EPEE-2025-2026'),
    4,
    'JASIELCZUK Igor'
); -- matched: JASIELCZUK Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    146,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-EPEE-2025-2026'),
    5,
    'ŁĘCKI Krzysztof'
); -- matched: ŁĘCKI Krzysztof (score=100.0)
-- Compute scores for PPW1-V0-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-EPEE-2025-2026')
);

-- ---- PP2: II Puchar Polski Weteranów (SZPADA MĘŻCZYZN O WETERANI) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW2-2025-2026',
    'II Puchar Polski Weteranów',
    'SZPADA MĘŻCZYZN O WETERANI',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW2-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW2-2025-2026'),
    'PPW2-V0-M-EPEE-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V0',
    NULL, 3, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    135,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-EPEE-2025-2026'),
    1,
    'KRUJASKIS Gotfridas'
); -- matched: KRUJASKIS Gotfridas (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    237,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-EPEE-2025-2026'),
    2,
    'SZMELC Łukasz'
); -- matched: SZMELC Łukasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    49,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-EPEE-2025-2026'),
    3,
    'DZIUBIŃSKI Mateusz'
); -- matched: DZIUBIŃSKI Mateusz (score=100.0)
-- Compute scores for PPW2-V0-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-EPEE-2025-2026')
);

-- ---- PP3: III Puchar Polski Weteranów (Szpada Mężczyzn kat. 0) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW3-2025-2026',
    'III Puchar Polski Weteranów',
    'Szpada Mężczyzn kat. 0',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW3-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW3-2025-2026'),
    'PPW3-V0-M-EPEE-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V0',
    NULL, 12, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    222,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2025-2026'),
    1,
    'SPŁAWA-NEYMAN MACIEJ'
); -- matched: SPŁAWA-NEYMAN MACIEJ (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    239,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2025-2026'),
    2,
    'SZTYBER Michał'
); -- matched: SZTYBER Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    90,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2025-2026'),
    3,
    'JASIELCZUK Igor'
); -- matched: JASIELCZUK Igor (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    3,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2025-2026'),
    4,
    'ADAMS Richard'
); -- matched: ADAMS Richard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    118,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2025-2026'),
    5,
    'KORYGA Bartłomiej'
); -- matched: KORYGA Bartłomiej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    147,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2025-2026'),
    6,
    'MADDEN Gerard'
); -- matched: MADDEN Gerard (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    49,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2025-2026'),
    7,
    'DZIUBIŃSKI Mateusz'
); -- matched: DZIUBIŃSKI Mateusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    112,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2025-2026'),
    8,
    'KONARSKI Marcin'
); -- matched: KONARSKI Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    128,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2025-2026'),
    9,
    'KOWALSKI Bartosz'
); -- matched: KOWALSKI Bartosz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    218,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2025-2026'),
    10,
    'SKRYPKA Glib'
); -- matched: SKRYPKA Glib (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    8,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2025-2026'),
    11,
    'AUGUSTYN Kajetan'
); -- matched: AUGUSTYN Kajetan (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    53,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2025-2026'),
    12,
    'FORNAL Mateusz'
); -- matched: FORNAL Mateusz (score=100.0)
-- Compute scores for PPW3-V0-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-EPEE-2025-2026')
);

-- ---- PP4: IV Puchar Polski Weteranów (GDAŃSK) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW4-2025-2026',
    'IV Puchar Polski Weteranów',
    'GDAŃSK',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW4-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW4-2025-2026'),
    'PPW4-V0-M-EPEE-2025-2026',
    'IV Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V0',
    '2026-01-21', 3, 'https://fencingtimelive.com/events/results/DA1C01B16745448E9716CE2AD252F9A2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    222,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-EPEE-2025-2026'),
    1,
    'SPŁAWA-NEYMAN Maciej'
); -- matched: SPŁAWA-NEYMAN MACIEJ (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    49,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-EPEE-2025-2026'),
    2,
    'DZIUBIŃSKI Mateusz'
); -- matched: DZIUBIŃSKI Mateusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    183,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-EPEE-2025-2026'),
    3,
    'PARELL Mikołaj'
); -- matched: PARELL Mikołaj (score=100.0)
-- Compute scores for PPW4-V0-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-EPEE-2025-2026')
);

-- SKIP PP5: event not yet held (SCHEDULED) — results are rolling carry-over from previous season

-- SKIP MPW: event not yet held (SCHEDULED) — results are rolling carry-over from previous season

-- Summary
-- Total results matched:   36
-- Total results unmatched: 0
