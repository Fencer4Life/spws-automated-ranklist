-- =========================================================================
-- Season 2025-2026 — V2 F EPEE — generated from SZPADA-K2-2025-2026.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- ---- PP1: I Puchar Polski Weteranów (Szpada kobiet weterani 2) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW1-2025-2026',
    'I Puchar Polski Weteranów',
    'Szpada kobiet weterani 2',
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
    'PPW1-V2-F-EPEE-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'F', 'V2',
    NULL, 4, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    253,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-F-EPEE-2025-2026'),
    1,
    'STAŃCZYK Agnieszka'
); -- matched: STAŃCZYK Agnieszka (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    289,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-F-EPEE-2025-2026'),
    2,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    64,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-F-EPEE-2025-2026'),
    3,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    109,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-F-EPEE-2025-2026'),
    4,
    'KARMAN Irene'
); -- matched: KARMAN Irene (score=100.0)
-- Compute scores for PPW1-V2-F-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-F-EPEE-2025-2026')
);

-- ---- PP2: II Puchar Polski Weteranów (SZPADA KOBIET 2 WETERANI) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW2-2025-2026',
    'II Puchar Polski Weteranów',
    'SZPADA KOBIET 2 WETERANI',
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
    'PPW2-V2-F-EPEE-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'F', 'V2',
    NULL, 3, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    289,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-F-EPEE-2025-2026'),
    1,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    64,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-F-EPEE-2025-2026'),
    2,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    286,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-F-EPEE-2025-2026'),
    3,
    'WALECKA Wanda'
); -- matched: WALECKA Wanda (score=100.0)
-- Compute scores for PPW2-V2-F-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-F-EPEE-2025-2026')
);

-- ---- PP3: III Puchar Polski Weteranów (Szpada Kobiet kat. 2) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW3-2025-2026',
    'III Puchar Polski Weteranów',
    'Szpada Kobiet kat. 2',
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
    'PPW3-V2-F-EPEE-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'F', 'V2',
    NULL, 6, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    150,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-F-EPEE-2025-2026'),
    1,
    'KUZMICHOVA Svitlana'
); -- matched: KUZMICHOVA Svitlana (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    215,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-F-EPEE-2025-2026'),
    2,
    'PRAHA-TSAREHRADSKA Nadiia'
); -- matched: PRAHA-TSAREHRADSKA Nadiia (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    253,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-F-EPEE-2025-2026'),
    3,
    'STAŃCZYK Agnieszka'
); -- matched: STAŃCZYK Agnieszka (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    64,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-F-EPEE-2025-2026'),
    4,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    289,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-F-EPEE-2025-2026'),
    5,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    206,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-F-EPEE-2025-2026'),
    6,
    'PILARSKA Barbara'
); -- matched: PILARSKA Barbara (score=100.0)
-- Compute scores for PPW3-V2-F-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-F-EPEE-2025-2026')
);

-- ---- PP4: IV Puchar Polski Weteranów (SZPADA KOBIET v2) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW4-2025-2026',
    'IV Puchar Polski Weteranów',
    'SZPADA KOBIET v2',
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
    'PPW4-V2-F-EPEE-2025-2026',
    'IV Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'F', 'V2',
    NULL, 5, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    289,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-F-EPEE-2025-2026'),
    1,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    64,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-F-EPEE-2025-2026'),
    2,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    154,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-F-EPEE-2025-2026'),
    3,
    'LASKUS Krystyna'
); -- matched: LASKUS Krystyna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-F-EPEE-2025-2026'),
    4,
    'SADOWIŃSKA Adriana'
); -- matched: SADOWIŃSKA Adriana (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    253,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-F-EPEE-2025-2026'),
    5,
    'STAŃCZYK Agnieszka'
); -- matched: STAŃCZYK Agnieszka (score=100.0)
-- Compute scores for PPW4-V2-F-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-F-EPEE-2025-2026')
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
    'PEW1-V2-F-EPEE-2025-2026',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'EPEE', 'F', 'V2',
    NULL, 28, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'HABLÜTZEL-BÜRKI Gianna' place=1
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    150,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-F-EPEE-2025-2026'),
    2,
    'KUZMICHOVA Svitlana'
); -- matched: KUZMICHOVA Svitlana (score=100.0)
-- SKIPPED (international, no master data): 'TANZMEISTER Dorothea' place=3
-- SKIPPED (international, no master data): 'BOYKO Maria' place=4
-- SKIPPED (international, no master data): 'HEILIG Bernadett' place=5
-- SKIPPED (international, no master data): 'DE GROOTE Annica' place=6
-- SKIPPED (international, no master data): 'SZUKICS Annamária Réka' place=7
-- SKIPPED (international, no master data): 'CHALON Natalia' place=8
-- SKIPPED (international, no master data): 'ARNOLD Mónika' place=9
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    289,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-F-EPEE-2025-2026'),
    10,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
-- SKIPPED (international, no master data): 'SELLEI Petra' place=11
-- SKIPPED (international, no master data): 'EHLERMANN Julia Dr.' place=12
-- SKIPPED (international, no master data): 'FOLZ Iris' place=13
-- SKIPPED (international, no master data): 'SIMÓKA Beáta' place=14
-- SKIPPED (international, no master data): 'TORDA Melinda' place=15
-- SKIPPED (international, no master data): 'PÓKA Bea' place=16
-- SKIPPED (international, no master data): 'KASOLYNÉ DÉKÁNY Dóra' place=17
-- SKIPPED (international, no master data): 'BRUCKER-KLEY Elke' place=18
-- SKIPPED (international, no master data): 'SZABÓ Adrienn' place=19
-- SKIPPED (international, no master data): 'DR. KÁRMÁN Irén' place=20
-- SKIPPED (international, no master data): 'NOVOSELSKA Tetiana' place=21
-- SKIPPED (international, no master data): 'MEUNIER-DUPAS Katy' place=22
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    215,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-F-EPEE-2025-2026'),
    23,
    'PRAHA-TSAREHRADSKA Nadiia'
); -- matched: PRAHA-TSAREHRADSKA Nadiia (score=100.0)
-- SKIPPED (international, no master data): 'OHRABLOVA Zuzana' place=24
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    64,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-F-EPEE-2025-2026'),
    25,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
-- SKIPPED (international, no master data): 'GÁBOR Annamária' place=26
-- SKIPPED (international, no master data): 'DR. KÁCSORNÉ DR. DURST Gyöngyvér' place=27
-- SKIPPED (international, no master data): 'KRSMANOVIC Bojana' place=28
-- Compute scores for PEW1-V2-F-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-F-EPEE-2025-2026')
);

-- SKIP PEW2 (EVF Grand Prix 2 — Madryt): 0 matched fencers in DB — tournament not created

-- SKIP PEW3 (EVF Grand Prix 3): N=0 — tournament had no participants

-- ---- PEW4: EVF Grand Prix 4 (2026-03-08-07 Napoli - 4 Prova Circuito Nazionale Master 2025-2 - Spada Femminile ) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW4-2025-2026',
    'EVF Grand Prix 4',
    '2026-03-08-07 Napoli - 4 Prova Circuito Nazionale Master 2025-2 - Spada Femminile ',
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
    'PEW4-V2-F-EPEE-2025-2026',
    'EVF Grand Prix 4',
    'PEW',
    'EPEE', 'F', 'V2',
    NULL, 49, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'DUMOULIN SANDRINE' place=1
-- SKIPPED (international, no master data): 'PASQUINI ELISABETTA' place=2
-- SKIPPED (international, no master data): 'LAISNEY SANDRA' place=3
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    150,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-F-EPEE-2025-2026'),
    4,
    'KUZMICHOVA SVITALINA'
); -- matched: KUZMICHOVA Svitlana (score=95.58823529411765)
-- SKIPPED (international, no master data): 'VALAER MARTINA' place=5
-- SKIPPED (international, no master data): 'PURICELLI LAURA' place=6
-- SKIPPED (international, no master data): 'MARCHANT SANDRA' place=7
-- SKIPPED (international, no master data): 'STRAUB ANJA' place=8
-- SKIPPED (international, no master data): 'TERZANI MARTA' place=9
-- SKIPPED (international, no master data): 'CHALON NATALIA' place=10
-- SKIPPED (international, no master data): 'SELLEI PETRA' place=11
-- SKIPPED (international, no master data): 'BONATO ILIANA DIANA' place=12
-- SKIPPED (international, no master data): 'LANZA PAOLA' place=13
-- SKIPPED (international, no master data): 'GABELLA BARBARA' place=14
-- SKIPPED (international, no master data): 'KARABULUT ALOE ARMAGAN' place=15
-- SKIPPED (international, no master data): 'FLEURY CORINNE' place=16
-- SKIPPED (international, no master data): 'TANZMEISTER DOROTHEA' place=17
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    253,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-F-EPEE-2025-2026'),
    18,
    'STAŃCZYK Agnieszka'
); -- matched: STAŃCZYK Agnieszka (score=100.0)
-- SKIPPED (international, no master data): 'DE LUCA SERENA' place=19
-- SKIPPED (international, no master data): 'AVANCINI ANNALISA' place=20
-- SKIPPED (international, no master data): 'CORSINI ROBERTA' place=21
-- SKIPPED (international, no master data): 'VIOLATI FLAMINIA' place=22
-- SKIPPED (international, no master data): 'DE VITO CRISTINA' place=23
-- SKIPPED (international, no master data): 'MORONI FRANCESCA' place=24
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    215,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-F-EPEE-2025-2026'),
    25,
    'PRAHA-TSAREHRAD NADIIA'
); -- matched: PRAHA-TSAREHRADSKA Nadiia (score=93.61702127659575)
-- SKIPPED (international, no master data): 'INSERRA SABRINA' place=26
-- SKIPPED (international, no master data): 'CARLINI VALERIA' place=27
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    64,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-F-EPEE-2025-2026'),
    28,
    'GANSZCZYK ANNA'
); -- matched: GANSZCZYK Anna (score=100.0)
-- SKIPPED (international, no master data): 'RANNONE GIUSEPPINA' place=29
-- SKIPPED (international, no master data): 'GIUNTA MONICA' place=30
-- SKIPPED (international, no master data): 'CAREY MICHELE SUSAN' place=31
-- SKIPPED (international, no master data): 'VALORZI DANIELA' place=32
-- SKIPPED (international, no master data): 'SODDU GIULIA' place=33
-- SKIPPED (international, no master data): 'CARUSI FULVIA' place=34
-- SKIPPED (international, no master data): 'SONZOGNO ENRICA' place=35
-- SKIPPED (international, no master data): 'GIOVANNETTI ELISABETTA' place=36
-- SKIPPED (international, no master data): 'SGUBIN ELISABETTA' place=37
-- SKIPPED (international, no master data): 'MOSCA FEDERICA' place=38
-- SKIPPED (international, no master data): 'PASI ROBERTA' place=39
-- SKIPPED (international, no master data): 'ORLANDO SIMONA' place=40
-- SKIPPED (international, no master data): 'IOVACCHINI FLAVIA' place=41
-- SKIPPED (international, no master data): 'ACACIA CARLA' place=42
-- SKIPPED (international, no master data): 'CARTA MARIA CARMEN' place=43
-- SKIPPED (international, no master data): 'OHRABLOVA ZUZANA' place=44
-- SKIPPED (international, no master data): 'FRASSON MARINA' place=45
-- SKIPPED (international, no master data): 'STELLA ANTONELLA' place=46
-- SKIPPED (international, no master data): 'ORLANDO FRANCESCA' place=47
-- SKIPPED (international, no master data): 'UGHI ESMERALDA' place=48
-- SKIPPED (international, no master data): 'PASCUCCI ORNELLA' place=49
-- Compute scores for PEW4-V2-F-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-F-EPEE-2025-2026')
);

-- SKIP PEW5 (EVF Grand Prix 5): 0 matched fencers in DB — tournament not created

-- ---- PEW6: EVF Grand Prix 6 (Szpada Kobiet V2) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW6-2025-2026',
    'EVF Grand Prix 6',
    'Szpada Kobiet V2',
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
    'PEW6-V2-F-EPEE-2025-2026',
    'EVF Grand Prix 6',
    'PEW',
    'EPEE', 'F', 'V2',
    NULL, 19, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'CISZEWSKA Barbara' place=1
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    7,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-F-EPEE-2025-2026'),
    2,
    'MION Anna-Lise'
); -- matched: ANNA-LISE Mion (score=100.0)
-- SKIPPED (international, no master data): 'AVANCINI Annalisa' place=3
-- SKIPPED (international, no master data): 'SELLEI 2 Petra' place=4
-- SKIPPED (international, no master data): 'IGARIENE Asta' place=5
-- SKIPPED (international, no master data): 'GRAF Bettina' place=6
-- SKIPPED (international, no master data): 'VENGALE Aida' place=7
-- SKIPPED (international, no master data): 'BELANGER Marie-Claire' place=8
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    215,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-F-EPEE-2025-2026'),
    9,
    'PRAHA-TSAREHRADSKA Nadiia'
); -- matched: PRAHA-TSAREHRADSKA Nadiia (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    253,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-F-EPEE-2025-2026'),
    10,
    'STAŃCZYK Agnieszka'
); -- matched: STAŃCZYK Agnieszka (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    289,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-F-EPEE-2025-2026'),
    11,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    150,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-F-EPEE-2025-2026'),
    12,
    'KUZMICHOVA Svitlana'
); -- matched: KUZMICHOVA Svitlana (score=100.0)
-- SKIPPED (international, no master data): 'NOVOSELSKA Tetiana' place=13
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    64,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-F-EPEE-2025-2026'),
    14,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-F-EPEE-2025-2026'),
    15,
    'SADOWIŃSKA Adriana'
); -- matched: SADOWIŃSKA Adriana (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    154,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-F-EPEE-2025-2026'),
    16,
    'LASKUS Krystyna'
); -- matched: LASKUS Krystyna (score=100.0)
-- SKIPPED (international, no master data): 'PARK-BHASIN Ok Kyong' place=17
-- SKIPPED (international, no master data): 'BELIAKOVA Alena' place=18
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    286,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-F-EPEE-2025-2026'),
    19,
    'WALECKA Wanda'
); -- matched: WALECKA Wanda (score=100.0)
-- Compute scores for PEW6-V2-F-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-F-EPEE-2025-2026')
);

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): N=0 — tournament had no participants

-- SKIP PS (Puchar Świata): N=0 — tournament had no participants

-- Summary
-- Total results matched:   41
-- Total results unmatched: 114
-- Total auto-created:      0
