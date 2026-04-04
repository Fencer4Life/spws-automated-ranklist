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
    225,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-F-EPEE-2025-2026'),
    1,
    'STAŃCZYK Agnieszka'
); -- matched: STAŃCZYK Agnieszka (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    256,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-F-EPEE-2025-2026'),
    2,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    60,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-F-EPEE-2025-2026'),
    3,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    98,
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
    256,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-F-EPEE-2025-2026'),
    1,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    60,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-F-EPEE-2025-2026'),
    2,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    254,
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
    139,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-F-EPEE-2025-2026'),
    1,
    'KUZMICHOVA Svitlana'
); -- matched: KUZMICHOVA Svitlana (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    193,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-F-EPEE-2025-2026'),
    2,
    'PRAHA-TSAREHRADSKA Nadiia'
); -- matched: PRAHA-TSAREHRADSKA Nadiia (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    225,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-F-EPEE-2025-2026'),
    3,
    'STAŃCZYK Agnieszka'
); -- matched: STAŃCZYK Agnieszka (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    60,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-F-EPEE-2025-2026'),
    4,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    256,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-F-EPEE-2025-2026'),
    5,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    186,
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
    256,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-F-EPEE-2025-2026'),
    1,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    60,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-F-EPEE-2025-2026'),
    2,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    140,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-F-EPEE-2025-2026'),
    3,
    'LASKUS Krystyna'
); -- matched: LASKUS Krystyna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    208,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-F-EPEE-2025-2026'),
    4,
    'SADOWIŃSKA Adriana'
); -- matched: SADOWIŃSKA Adriana (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    225,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-F-EPEE-2025-2026'),
    5,
    'STAŃCZYK Agnieszka'
); -- matched: STAŃCZYK Agnieszka (score=100.0)
-- Compute scores for PPW4-V2-F-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-F-EPEE-2025-2026')
);

-- SKIP PP5: event not yet held (SCHEDULED) — results are rolling carry-over from previous season

-- SKIP MPW: event not yet held (SCHEDULED) — results are rolling carry-over from previous season

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
-- UNMATCHED (score<80): 'HABLÜTZEL-BÜRKI Gianna' place=1
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    139,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-F-EPEE-2025-2026'),
    2,
    'KUZMICHOVA Svitlana'
); -- matched: KUZMICHOVA Svitlana (score=100.0)
-- UNMATCHED (score<80): 'TANZMEISTER Dorothea' place=3
-- UNMATCHED (score<80): 'BOYKO Maria' place=4
-- UNMATCHED (score<80): 'HEILIG Bernadett' place=5
-- UNMATCHED (score<80): 'DE GROOTE Annica' place=6
-- UNMATCHED (score<80): 'SZUKICS Annamária Réka' place=7
-- UNMATCHED (score<80): 'CHALON Natalia' place=8
-- UNMATCHED (score<80): 'ARNOLD Mónika' place=9
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    256,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-F-EPEE-2025-2026'),
    10,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
-- UNMATCHED (score<80): 'SELLEI Petra' place=11
-- UNMATCHED (score<80): 'EHLERMANN Julia Dr.' place=12
-- UNMATCHED (score<80): 'FOLZ Iris' place=13
-- UNMATCHED (score<80): 'SIMÓKA Beáta' place=14
-- UNMATCHED (score<80): 'TORDA Melinda' place=15
-- UNMATCHED (score<80): 'PÓKA Bea' place=16
-- UNMATCHED (score<80): 'KASOLYNÉ DÉKÁNY Dóra' place=17
-- UNMATCHED (score<80): 'BRUCKER-KLEY Elke' place=18
-- UNMATCHED (score<80): 'SZABÓ Adrienn' place=19
-- UNMATCHED (score<80): 'DR. KÁRMÁN Irén' place=20
-- UNMATCHED (score<80): 'NOVOSELSKA Tetiana' place=21
-- UNMATCHED (score<80): 'MEUNIER-DUPAS Katy' place=22
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    193,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-F-EPEE-2025-2026'),
    23,
    'PRAHA-TSAREHRADSKA Nadiia'
); -- matched: PRAHA-TSAREHRADSKA Nadiia (score=100.0)
-- UNMATCHED (score<80): 'OHRABLOVA Zuzana' place=24
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    60,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-F-EPEE-2025-2026'),
    25,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
-- UNMATCHED (score<80): 'GÁBOR Annamária' place=26
-- UNMATCHED (score<80): 'DR. KÁCSORNÉ DR. DURST Gyöngyvér' place=27
-- UNMATCHED (score<80): 'KRSMANOVIC Bojana' place=28
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
-- UNMATCHED (score<80): 'DUMOULIN SANDRINE' place=1
-- UNMATCHED (score<80): 'PASQUINI ELISABETTA' place=2
-- UNMATCHED (score<80): 'LAISNEY SANDRA' place=3
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    139,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-F-EPEE-2025-2026'),
    4,
    'KUZMICHOVA SVITALINA'
); -- matched: KUZMICHOVA Svitlana (score=92.3076923076923)
-- UNMATCHED (score<80): 'VALAER MARTINA' place=5
-- UNMATCHED (score<80): 'PURICELLI LAURA' place=6
-- UNMATCHED (score<80): 'MARCHANT SANDRA' place=7
-- UNMATCHED (score<80): 'STRAUB ANJA' place=8
-- UNMATCHED (score<80): 'TERZANI MARTA' place=9
-- UNMATCHED (score<80): 'CHALON NATALIA' place=10
-- UNMATCHED (score<80): 'SELLEI PETRA' place=11
-- UNMATCHED (score<80): 'BONATO ILIANA DIANA' place=12
-- UNMATCHED (score<80): 'LANZA PAOLA' place=13
-- UNMATCHED (score<80): 'GABELLA BARBARA' place=14
-- UNMATCHED (score<80): 'KARABULUT ALOE ARMAGAN' place=15
-- UNMATCHED (score<80): 'FLEURY CORINNE' place=16
-- UNMATCHED (score<80): 'TANZMEISTER DOROTHEA' place=17
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    225,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-F-EPEE-2025-2026'),
    18,
    'STAŃCZYK Agnieszka'
); -- matched: STAŃCZYK Agnieszka (score=100.0)
-- UNMATCHED (score<80): 'DE LUCA SERENA' place=19
-- UNMATCHED (score<80): 'AVANCINI ANNALISA' place=20
-- UNMATCHED (score<80): 'CORSINI ROBERTA' place=21
-- UNMATCHED (score<80): 'VIOLATI FLAMINIA' place=22
-- UNMATCHED (score<80): 'DE VITO CRISTINA' place=23
-- UNMATCHED (score<80): 'MORONI FRANCESCA' place=24
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    193,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-F-EPEE-2025-2026'),
    25,
    'PRAHA-TSAREHRAD NADIIA'
); -- matched: PRAHA-TSAREHRADSKA Nadiia (score=93.61702127659575)
-- UNMATCHED (score<80): 'INSERRA SABRINA' place=26
-- UNMATCHED (score<80): 'CARLINI VALERIA' place=27
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    60,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-F-EPEE-2025-2026'),
    28,
    'GANSZCZYK ANNA'
); -- matched: GANSZCZYK Anna (score=100.0)
-- UNMATCHED (score<80): 'RANNONE GIUSEPPINA' place=29
-- UNMATCHED (score<80): 'GIUNTA MONICA' place=30
-- UNMATCHED (score<80): 'CAREY MICHELE SUSAN' place=31
-- UNMATCHED (score<80): 'VALORZI DANIELA' place=32
-- UNMATCHED (score<80): 'SODDU GIULIA' place=33
-- UNMATCHED (score<80): 'CARUSI FULVIA' place=34
-- UNMATCHED (score<80): 'SONZOGNO ENRICA' place=35
-- UNMATCHED (score<80): 'GIOVANNETTI ELISABETTA' place=36
-- UNMATCHED (score<80): 'SGUBIN ELISABETTA' place=37
-- UNMATCHED (score<80): 'MOSCA FEDERICA' place=38
-- UNMATCHED (score<80): 'PASI ROBERTA' place=39
-- UNMATCHED (score<80): 'ORLANDO SIMONA' place=40
-- UNMATCHED (score<80): 'IOVACCHINI FLAVIA' place=41
-- UNMATCHED (score<80): 'ACACIA CARLA' place=42
-- UNMATCHED (score<80): 'CARTA MARIA CARMEN' place=43
-- UNMATCHED (score<80): 'OHRABLOVA ZUZANA' place=44
-- UNMATCHED (score<80): 'FRASSON MARINA' place=45
-- UNMATCHED (score<80): 'STELLA ANTONELLA' place=46
-- UNMATCHED (score<80): 'ORLANDO FRANCESCA' place=47
-- UNMATCHED (score<80): 'UGHI ESMERALDA' place=48
-- UNMATCHED (score<80): 'PASCUCCI ORNELLA' place=49
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
-- UNMATCHED (score<80): 'CISZEWSKA Barbara' place=1
-- UNMATCHED (score<80): 'AVANCINI Annalisa' place=3
-- UNMATCHED (score<80): 'SELLEI 2 Petra' place=4
-- UNMATCHED (score<80): 'IGARIENE Asta' place=5
-- UNMATCHED (score<80): 'GRAF Bettina' place=6
-- UNMATCHED (score<80): 'VENGALE Aida' place=7
-- UNMATCHED (score<80): 'BELANGER Marie-Claire' place=8
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    193,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-F-EPEE-2025-2026'),
    9,
    'PRAHA-TSAREHRADSKA Nadiia'
); -- matched: PRAHA-TSAREHRADSKA Nadiia (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    225,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-F-EPEE-2025-2026'),
    10,
    'STAŃCZYK Agnieszka'
); -- matched: STAŃCZYK Agnieszka (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    256,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-F-EPEE-2025-2026'),
    11,
    'WASILCZUK Beata'
); -- matched: WASILCZUK Beata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    139,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-F-EPEE-2025-2026'),
    12,
    'KUZMICHOVA Svitlana'
); -- matched: KUZMICHOVA Svitlana (score=100.0)
-- UNMATCHED (score<80): 'NOVOSELSKA Tetiana' place=13
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    60,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-F-EPEE-2025-2026'),
    14,
    'GANSZCZYK Anna'
); -- matched: GANSZCZYK Anna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    208,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-F-EPEE-2025-2026'),
    15,
    'SADOWIŃSKA Adriana'
); -- matched: SADOWIŃSKA Adriana (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    140,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-F-EPEE-2025-2026'),
    16,
    'LASKUS Krystyna'
); -- matched: LASKUS Krystyna (score=100.0)
-- UNMATCHED (score<80): 'PARK-BHASIN Ok Kyong' place=17
-- UNMATCHED (score<80): 'BELIAKOVA Alena' place=18
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    254,
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

-- SKIP IMEW: event not yet held (SCHEDULED) — results are rolling carry-over from previous season

-- Summary
-- Total results matched:   41
-- Total results unmatched: 114
