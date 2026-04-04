-- =========================================================================
-- Season 2025-2026 — V2 M SABRE — generated from SZABLA-2-2025-2026.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- ---- PP1: I Puchar Polski Weteranów (Szabla Mężczyzn Weterani 2) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW1-2025-2026',
    'I Puchar Polski Weteranów',
    'Szabla Mężczyzn Weterani 2',
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
    'PPW1-V2-M-SABRE-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V2',
    NULL, 11, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2025-2026'),
    1,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    143,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2025-2026'),
    2,
    'KROCHMALSKI Jakub'
); -- matched: KROCHMALSKI Jakub (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    191,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2025-2026'),
    3,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    310,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2025-2026'),
    4,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    294,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2025-2026'),
    5,
    'WINGROWICZ Mariusz'
); -- matched: WINGROWICZ Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    107,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2025-2026'),
    6,
    'KACZMAREK Paweł'
); -- matched: KACZMAREK Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    139,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2025-2026'),
    7,
    'KOŁUCKI Michał'
); -- matched: KOŁUCKI Michał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    168,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2025-2026'),
    8,
    'MAZIK ALEKSANDER'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2025-2026'),
    9,
    'JAROSZEK Zbigniew'
); -- matched: JAROSZEK Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2025-2026'),
    10,
    'WIERZBICKI JACEK'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    131,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2025-2026'),
    11,
    'KOTTS Radosław'
); -- matched: KOTTS Radosław (score=100.0)
-- Compute scores for PPW1-V2-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2025-2026')
);

-- ---- PP2: II Puchar Polski Weteranów (SZABLA WETERANI MĘŻCZYZNI 2) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW2-2025-2026',
    'II Puchar Polski Weteranów',
    'SZABLA WETERANI MĘŻCZYZNI 2',
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
    'PPW2-V2-M-SABRE-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V2',
    NULL, 9, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    143,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2025-2026'),
    1,
    'KROCHMALSKI Jakub'
); -- matched: KROCHMALSKI Jakub (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2025-2026'),
    2,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    191,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2025-2026'),
    3,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    310,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2025-2026'),
    4,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    107,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2025-2026'),
    5,
    'KACZMAREK Paweł'
); -- matched: KACZMAREK Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    168,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2025-2026'),
    6,
    'MAZIK ALEKSANDER'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    209,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2025-2026'),
    7,
    'PLUCIŃSKI Paweł'
); -- matched: PLUCIŃSKI Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2025-2026'),
    8,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    131,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2025-2026'),
    9,
    'KOTTS Radosław'
); -- matched: KOTTS Radosław (score=100.0)
-- Compute scores for PPW2-V2-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2025-2026')
);

-- ---- PP3: III Puchar Polski Weteranów (Szabla Mężczyzn kat. 2) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW3-2025-2026',
    'III Puchar Polski Weteranów',
    'Szabla Mężczyzn kat. 2',
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
    'PPW3-V2-M-SABRE-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V2',
    NULL, 12, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    143,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2025-2026'),
    1,
    'KROCHMALSKI Jakub'
); -- matched: KROCHMALSKI Jakub (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    310,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2025-2026'),
    2,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2025-2026'),
    3,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    191,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2025-2026'),
    4,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    294,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2025-2026'),
    5,
    'WINGROWICZ Mariusz'
); -- matched: WINGROWICZ Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    107,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2025-2026'),
    6,
    'KACZMAREK Paweł'
); -- matched: KACZMAREK Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    168,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2025-2026'),
    7,
    'MAZIK ALEKSANDER'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    209,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2025-2026'),
    8,
    'PLUCIŃSKI Paweł'
); -- matched: PLUCIŃSKI Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    63,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2025-2026'),
    9,
    'GAJDA Zbigniew'
); -- matched: GAJDA Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    270,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2025-2026'),
    10,
    'SZYMAŃSKI Adam'
); -- matched: SZYMAŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2025-2026'),
    11,
    'JAROSZEK Zbigniew'
); -- matched: JAROSZEK Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2025-2026'),
    12,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
-- Compute scores for PPW3-V2-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2025-2026')
);

-- ---- PP4: IV Puchar Polski Weteranów (SZABLA MĘŻCZYZN v2) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW4-2025-2026',
    'IV Puchar Polski Weteranów',
    'SZABLA MĘŻCZYZN v2',
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
    'PPW4-V2-M-SABRE-2025-2026',
    'IV Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V2',
    NULL, 10, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-SABRE-2025-2026'),
    1,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    143,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-SABRE-2025-2026'),
    2,
    'KROCHMALSKI Jakub'
); -- matched: KROCHMALSKI Jakub (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    191,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-SABRE-2025-2026'),
    3,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    168,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-SABRE-2025-2026'),
    4,
    'MAZIK Aleksander'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    33,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-SABRE-2025-2026'),
    5,
    'CHIAROMONTE Francesco'
); -- matched: CHIAROMONTE Francesco (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    294,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-SABRE-2025-2026'),
    6,
    'WINGROWICZ Mariusz'
); -- matched: WINGROWICZ Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-SABRE-2025-2026'),
    7,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-SABRE-2025-2026'),
    8,
    'JAROSZEK Zbigniew'
); -- matched: JAROSZEK Zbigniew (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    270,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-SABRE-2025-2026'),
    9,
    'SZYMAŃSKI Adam'
); -- matched: SZYMAŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    160,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-SABRE-2025-2026'),
    10,
    'LISOWSKI Robert'
); -- matched: LISOWSKI Robert (score=100.0)
-- Compute scores for PPW4-V2-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-SABRE-2025-2026')
);
-- ---- PEW1: EVF Grand Prix 1 — Budapeszt (INTERNATIONAL VETERAN CHAMPIONSHIPS) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW1-2025-2026',
    'EVF Grand Prix 1 — Budapeszt',
    'INTERNATIONAL VETERAN CHAMPIONSHIPS',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW1-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1-2025-2026'),
    'PEW1-V2-M-SABRE-2025-2026',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'SABRE', 'M', 'V2',
    NULL, 22, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'VINYALS VILARNAU Marcal' place=1
-- SKIPPED (international, no master data): 'MATRIGALI Camillo' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    140,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-SABRE-2025-2026'),
    3,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-SABRE-2025-2026'),
    4,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    33,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-SABRE-2025-2026'),
    5,
    'CHIAROMONTE Francesco'
); -- matched: CHIAROMONTE Francesco (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    310,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-SABRE-2025-2026'),
    6,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
-- SKIPPED (international, no master data): 'MARGETICH Gerhard' place=7
-- SKIPPED (international, no master data): 'TORRES Julian Santos' place=8
-- SKIPPED (international, no master data): 'FERKE Norbert' place=9
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    191,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-SABRE-2025-2026'),
    10,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
-- SKIPPED (international, no master data): 'TÉNYI Tamás' place=11
-- SKIPPED (international, no master data): 'MAJTÉNYI György' place=12
-- SKIPPED (international, no master data): 'ROBINEAUX Sebastien' place=13
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    168,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-SABRE-2025-2026'),
    14,
    'MAZIK Aleksander'
); -- matched: MAZIK Aleksander (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-SABRE-2025-2026'),
    15,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
-- SKIPPED (international, no master data): 'VARGA Gergely' place=16
-- SKIPPED (international, no master data): 'PÉNZES Zsolt' place=17
-- SKIPPED (international, no master data): 'CASADESUS SOLÉ Xavier' place=18
-- SKIPPED (international, no master data): 'ALEXANDER Kevin' place=19
-- SKIPPED (international, no master data): 'DR. TÓTH András Tamás' place=20
-- SKIPPED (international, no master data): 'MESTER György' place=21
-- SKIPPED (international, no master data): 'FÁBIÁN Gábor' place=22
-- Compute scores for PEW1-V2-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-SABRE-2025-2026')
);

-- SKIP PEW2 (EVF Grand Prix 2 — Madryt): 0 matched fencers in DB — tournament not created

-- ---- PEW3: EVF Grand Prix 3 (https://www.fencingworldwide.com/en/912306-2025/results/) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW3-2025-2026',
    'EVF Grand Prix 3',
    'https://www.fencingworldwide.com/en/912306-2025/results/',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW3-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW3-2025-2026'),
    'PEW3-V2-M-SABRE-2025-2026',
    'EVF Grand Prix 3',
    'PEW',
    'SABRE', 'M', 'V2',
    '2025-12-06', 25, 'https://www.fencingworldwide.com/en/912306-2025/results/',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-SABRE-2025-2026'),
    6,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    191,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-SABRE-2025-2026'),
    9,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
-- Compute scores for PEW3-V2-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-SABRE-2025-2026')
);

-- ---- PEW4: EVF Grand Prix 4 (Guildford) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW4-2025-2026',
    'EVF Grand Prix 4',
    'Guildford',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW4-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW4-2025-2026'),
    'PEW4-V2-M-SABRE-2025-2026',
    'EVF Grand Prix 4',
    'PEW',
    'SABRE', 'M', 'V2',
    '2026-11-11', 22, 'https://www.fencingtimelive.com/events/results/C98569BE86A64927BBDADE40A3656041',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    140,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-SABRE-2025-2026'),
    3,
    'tk'
); -- matched: KOŃCZYŁO Tomasz (score=100)
-- Compute scores for PEW4-V2-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-SABRE-2025-2026')
);

-- SKIP PEW5 (EVF Grand Prix 5): N=0 — tournament had no participants

-- ---- PEW6: EVF Grand Prix 6 (2026-03-08-07 Napoli - 4 Prova Circuito Nazionale Master 2025-2 - Sciabola Maschile ) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW6-2025-2026',
    'EVF Grand Prix 6',
    '2026-03-08-07 Napoli - 4 Prova Circuito Nazionale Master 2025-2 - Sciabola Maschile ',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW6-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW6-2025-2026'),
    'PEW6-V2-M-SABRE-2025-2026',
    'EVF Grand Prix 6',
    'PEW',
    'SABRE', 'M', 'V2',
    NULL, 32, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'EMMERICH OLIVER' place=1
-- SKIPPED (international, no master data): 'LANCIOTTI STEFANO' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    191,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-SABRE-2025-2026'),
    3,
    'NOWICKI ROBERT'
); -- matched: NOWICKI Robert (score=100.0)
-- SKIPPED (international, no master data): 'MATRIGALI CAMILLO' place=4
-- SKIPPED (international, no master data): 'MARGETICH GERHARD' place=5
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    310,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-SABRE-2025-2026'),
    6,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
-- SKIPPED (international, no master data): 'NICASTRO CARLO' place=7
-- SKIPPED (international, no master data): 'NAPOLI ROBERTO' place=8
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-SABRE-2025-2026'),
    9,
    'GANSZCZYK MARCIN'
); -- matched: GANSZCZYK Marcin (score=100.0)
-- SKIPPED (international, no master data): 'CASELLA CARMINE' place=10
-- SKIPPED (international, no master data): 'PARISE ALESSANDRO' place=11
-- SKIPPED (international, no master data): 'CASTAGNER DIEGO' place=12
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    33,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-SABRE-2025-2026'),
    13,
    'CHIAROMONTE FRANCESCO'
); -- matched: CHIAROMONTE Francesco (score=100.0)
-- SKIPPED (international, no master data): 'SZABO ZOLTAN' place=14
-- SKIPPED (international, no master data): 'ZANZOT GIANLUCA' place=15
-- SKIPPED (international, no master data): 'VARGA GERGELY' place=16
-- SKIPPED (international, no master data): 'MESTER GYORGY' place=17
-- SKIPPED (international, no master data): 'PETRONE DAVIDE' place=18
-- SKIPPED (international, no master data): 'RIZZO ALESSANDRO' place=19
-- SKIPPED (international, no master data): 'DORIO MARCO' place=20
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    168,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-SABRE-2025-2026'),
    21,
    'MAZIK ALEKSANDER'
); -- matched: MAZIK Aleksander (score=100.0)
-- SKIPPED (international, no master data): 'D''AMICO GUGLIELMO' place=22
-- SKIPPED (international, no master data): 'DI DONATO ANTONIO' place=23
-- SKIPPED (international, no master data): 'ANGONESE WALTER' place=24
-- SKIPPED (international, no master data): 'MUSCARIELLO ROBERTO' place=25
-- SKIPPED (international, no master data): 'GIZZI ARCANGELO' place=26
-- SKIPPED (international, no master data): 'SALATI FRANCESCO' place=27
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    107,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-SABRE-2025-2026'),
    28,
    'KACZMAREK Paweł'
); -- matched: KACZMAREK Paweł (score=100.0)
-- SKIPPED (international, no master data): 'MAZZONI MARCO ETTORE' place=29
-- SKIPPED (international, no master data): 'LUCREZI GINO' place=30
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-SABRE-2025-2026'),
    31,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
-- SKIPPED (international, no master data): 'RUGGIERO GENNARO' place=32
-- Compute scores for PEW6-V2-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-SABRE-2025-2026')
);

-- ---- PEW7: EVF Grand Prix 7 — Terni (Szabla Mężczyzn V2 DE) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW7-2025-2026',
    'EVF Grand Prix 7 — Terni',
    'Szabla Mężczyzn V2 DE',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW7-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW7-2025-2026'),
    'PEW7-V2-M-SABRE-2025-2026',
    'EVF Grand Prix 7 — Terni',
    'PEW',
    'SABRE', 'M', 'V2',
    NULL, 16, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'LANCIOTTI Stefano' place=1
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    65,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2025-2026'),
    2,
    'GANSZCZYK Marcin'
); -- matched: GANSZCZYK Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    310,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2025-2026'),
    3,
    'ZAWROTNIAK Przemysław'
); -- matched: ZAWROTNIAK Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    143,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2025-2026'),
    4,
    'KROCHMALSKI Jakub'
); -- matched: KROCHMALSKI Jakub (score=100.0)
-- SKIPPED (international, no master data): 'MATRIGALI Camillo' place=5
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    191,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2025-2026'),
    6,
    'NOWICKI Robert'
); -- matched: NOWICKI Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    33,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2025-2026'),
    7,
    'CHIAROMONTE Francesco'
); -- matched: CHIAROMONTE Francesco (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    140,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2025-2026'),
    8,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
-- SKIPPED (international, no master data): 'NAPOLI Roberto' place=9
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    294,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2025-2026'),
    10,
    'WINGROWICZ Mariusz'
); -- matched: WINGROWICZ Mariusz (score=100.0)
-- SKIPPED (international, no master data): 'PARISE Alessandro' place=11
-- SKIPPED (international, no master data): 'CASTAGNER Diego' place=12
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    270,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2025-2026'),
    13,
    'SZYMAŃSKI Adam'
); -- matched: SZYMAŃSKI Adam (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    293,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2025-2026'),
    14,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100.0)
-- SKIPPED (international, no master data): 'BIZZARRO Martin' place=15
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    168,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2025-2026'),
    16,
    'MAZIK Aleksander'
); -- matched: MAZIK Aleksander (score=100.0)
-- Compute scores for PEW7-V2-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2025-2026')
);

-- SKIP PEW8 (EVF Grand Prix 8 — Guildford): N=0 — tournament had no participants

-- SKIP PEW9 (EVF Grand Prix 9 — Sztokholm): N=0 — tournament had no participants

-- ---- PS: Puchar Świata (Paryż) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PS-2025-2026',
    'Puchar Świata',
    'Paryż',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PS-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PS-2025-2026'),
    'PS-V2-M-SABRE-2025-2026',
    'Puchar Świata',
    'PSW',
    'SABRE', 'M', 'V2',
    '2025-07-05', 12, 'https://engarde-service.com/competition/fencingaddict/crit25/shv2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    140,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PS-V2-M-SABRE-2025-2026'),
    3,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
-- Compute scores for PS-V2-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PS-V2-M-SABRE-2025-2026')
);

-- Summary
-- Total results matched:   95
-- Total results unmatched: 65
-- Total auto-created:      0
