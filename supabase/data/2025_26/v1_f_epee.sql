-- =========================================================================
-- Season 2025-2026 — V1 F EPEE — generated from SZPADA-K1-2025-2026.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- ---- PP1: I Puchar Polski Weteranów (Szpada kobiet weterani 1) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW1-2025-2026',
    'I Puchar Polski Weteranów',
    'Szpada kobiet weterani 1',
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
    'PPW1-V1-F-EPEE-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'F', 'V1',
    NULL, 2, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    107,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-F-EPEE-2025-2026'),
    1,
    'KLIMECKA Dorota'
); -- matched: KLIMECKA Dorota (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    28,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-F-EPEE-2025-2026'),
    2,
    'CHMIELEWSKA Emilia'
); -- matched: CHMIELEWSKA Emilia (score=100.0)
-- Compute scores for PPW1-V1-F-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-F-EPEE-2025-2026')
);

-- ---- PP2: II Puchar Polski Weteranów (SZPADA KOBIET 1 WETERANI) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW2-2025-2026',
    'II Puchar Polski Weteranów',
    'SZPADA KOBIET 1 WETERANI',
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
    'PPW2-V1-F-EPEE-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'F', 'V1',
    NULL, 3, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-F-EPEE-2025-2026'),
    1,
    'KAMIŃSKA Gabriela'
); -- matched: KAMIŃSKA Gabriela (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    204,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-F-EPEE-2025-2026'),
    2,
    'SAMECKA-NACZYŃSKA Martyna'
); -- matched: SAMECKA-NACZYŃSKA Martyna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    107,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-F-EPEE-2025-2026'),
    3,
    'KLIMECKA Dorota'
); -- matched: KLIMECKA Dorota (score=100.0)
-- Compute scores for PPW2-V1-F-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-F-EPEE-2025-2026')
);

-- ---- PP3: III Puchar Polski Weteranów (Szpada Kobiet kat. 1) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW3-2025-2026',
    'III Puchar Polski Weteranów',
    'Szpada Kobiet kat. 1',
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
    'PPW3-V1-F-EPEE-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'F', 'V1',
    NULL, 6, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-F-EPEE-2025-2026'),
    1,
    'KAMIŃSKA Gabriela'
); -- matched: KAMIŃSKA Gabriela (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    204,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-F-EPEE-2025-2026'),
    2,
    'SAMECKA-NACZYŃSKA Martyna'
); -- matched: SAMECKA-NACZYŃSKA Martyna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    28,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-F-EPEE-2025-2026'),
    3,
    'CHMIELEWSKA Emilia'
); -- matched: CHMIELEWSKA Emilia (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    107,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-F-EPEE-2025-2026'),
    4,
    'KLIMECKA Dorota'
); -- matched: KLIMECKA Dorota (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    202,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-F-EPEE-2025-2026'),
    5,
    'SADOWSKA Małgorzata'
); -- matched: SADOWSKA Małgorzata (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    66,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-F-EPEE-2025-2026'),
    6,
    'GIERS-ROMEK Monika'
); -- matched: GIERS-ROMEK Monika (score=100.0)
-- Compute scores for PPW3-V1-F-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-F-EPEE-2025-2026')
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
    'PPW4-V1-F-EPEE-2025-2026',
    'IV Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'F', 'V1',
    '2026-02-21', 4, 'https://fencingtimelive.com/events/results/48791095BA20459E8C815D9CA6070097',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-F-EPEE-2025-2026'),
    1,
    'KAMIŃSKA Gabriela'
); -- matched: KAMIŃSKA Gabriela (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    204,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-F-EPEE-2025-2026'),
    2,
    'SAMECKA-NACZYŃSKA Martyna'
); -- matched: SAMECKA-NACZYŃSKA Martyna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    28,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-F-EPEE-2025-2026'),
    3,
    'CHMIELEWSKA Emilia'
); -- matched: CHMIELEWSKA Emilia (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    317,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-F-EPEE-2025-2026'),
    4,
    'MARNIAK Ksenia'
); -- matched: MARNIAK Ksenia (score=100.0)
-- Compute scores for PPW4-V1-F-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-F-EPEE-2025-2026')
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
    'PEW1-V1-F-EPEE-2025-2026',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'EPEE', 'F', 'V1',
    NULL, 17, 'https://engarde-service.com/app.php?id=4208L1',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    204,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-F-EPEE-2025-2026'),
    7,
    'SAMECKA-NACZYŃSKA Martyna'
); -- matched: SAMECKA-NACZYŃSKA Martyna (score=100.0)
-- Compute scores for PEW1-V1-F-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-F-EPEE-2025-2026')
);

-- SKIP PEW2 (EVF Grand Prix 2 — Madryt): 0 matched fencers in DB — tournament not created

-- ---- PEW3: EVF Grand Prix 3 (Guildford) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW3-2025-2026',
    'EVF Grand Prix 3',
    'Guildford',
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
    'PEW3-V1-F-EPEE-2025-2026',
    'EVF Grand Prix 3',
    'PEW',
    'EPEE', 'F', 'V1',
    '2026-01-10', 23, 'https://www.fencingtimelive.com/events/results/5E5D6077AD1D43518C771B68947F054D',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-F-EPEE-2025-2026'),
    8,
    'KAMIŃSKA Gabriela'
); -- matched: KAMIŃSKA Gabriela (score=100.0)
-- Compute scores for PEW3-V1-F-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-F-EPEE-2025-2026')
);

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
    'PEW4-V1-F-EPEE-2025-2026',
    'EVF Grand Prix 4',
    'PEW',
    'EPEE', 'F', 'V1',
    NULL, 34, NULL,
    'SCORED'
);
-- UNMATCHED (score<80): 'ASCHEHOUG IRINA' place=1
-- UNMATCHED (score<80): 'DORNACHER SAPIN MARIA' place=2
-- UNMATCHED (score<80): 'LATTANZI VALENTINA' place=3
-- UNMATCHED (score<80): 'URANIA STEFANIA' place=4
-- UNMATCHED (score<80): 'LAMBERTINI ALICE' place=5
-- UNMATCHED (score<80): 'CAFFINO SARA' place=6
-- UNMATCHED (score<80): 'LOTTI LAURA' place=7
-- UNMATCHED (score<80): 'LIBERTINI NORMA' place=8
-- UNMATCHED (score<80): 'SUDANO GIULIA' place=9
-- UNMATCHED (score<80): 'GIUGNI CARLOTTA' place=10
-- UNMATCHED (score<80): 'ARIAUDO FEDERICA' place=11
-- UNMATCHED (score<80): 'CUOMO FRANCESCA' place=12
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-F-EPEE-2025-2026'),
    13,
    'KAMIŃSKA Gabriela'
); -- matched: KAMIŃSKA Gabriela (score=100.0)
-- UNMATCHED (score<80): 'LIBERTINI EUGENIA' place=14
-- UNMATCHED (score<80): 'CUSCINI ELISA' place=15
-- UNMATCHED (score<80): 'SZINI ANDREA KATALIN' place=16
-- UNMATCHED (score<80): 'MAHROVA MARIA' place=17
-- UNMATCHED (score<80): 'BUNTINA IRINA' place=18
-- UNMATCHED (score<80): 'FRASCA LAURA' place=19
-- UNMATCHED (score<80): 'ENRIGHT RITVA IRENE' place=20
-- UNMATCHED (score<80): 'MALAVASI SILVIA' place=21
-- UNMATCHED (score<80): 'HERENDA KRISTINA' place=22
-- UNMATCHED (score<80): 'ZEAITER IRINA' place=23
-- UNMATCHED (score<80): 'CARUSO SABINA' place=24
-- UNMATCHED (score<80): 'PERETTO NADIA' place=25
-- UNMATCHED (score<80): 'FRANCHI CATERINA' place=26
-- UNMATCHED (score<80): 'MAGLIA GIUSY' place=27
-- UNMATCHED (score<80): 'SZABO ORSOLYA JOLAN' place=28
-- UNMATCHED (score<80): 'D''ERRICO ANTONELLA' place=29
-- UNMATCHED (score<80): 'PENNA ELISA' place=30
-- UNMATCHED (score<80): 'CARUSO VERONICA' place=31
-- UNMATCHED (score<80): 'NAPOLI LUCIA' place=32
-- UNMATCHED (score<80): 'MOREALE ISABELLA' place=33
-- UNMATCHED (score<80): 'STAQUET CAROLINE' place=34
-- Compute scores for PEW4-V1-F-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-F-EPEE-2025-2026')
);

-- SKIP PEW5 (EVF Grand Prix 5): 0 matched fencers in DB — tournament not created

-- ---- PEW6: EVF Grand Prix 6 (Szpada Kobiet V1) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW6-2025-2026',
    'EVF Grand Prix 6',
    'Szpada Kobiet V1',
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
    'PEW6-V1-F-EPEE-2025-2026',
    'EVF Grand Prix 6',
    'PEW',
    'EPEE', 'F', 'V1',
    NULL, 12, NULL,
    'SCORED'
);
-- UNMATCHED (score<80): 'ARIAUDO Federica' place=1
-- UNMATCHED (score<80): 'ZILIONE Zivile' place=2
-- UNMATCHED (score<80): 'HERCZEG Krisztina' place=3
-- UNMATCHED (score<80): 'PETROVSKA Olha' place=4
-- UNMATCHED (score<80): 'HEITMANN Anne' place=5
-- UNMATCHED (score<80): 'SZINI Andrea Katalin' place=6
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    204,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-F-EPEE-2025-2026'),
    7,
    'SAMECKA-NACZYŃSKA Martyna'
); -- matched: SAMECKA-NACZYŃSKA Martyna (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    100,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-F-EPEE-2025-2026'),
    8,
    'KAMIŃSKA Gabriela'
); -- matched: KAMIŃSKA Gabriela (score=100.0)
-- UNMATCHED (score<80): 'ENRIGHT 1 Ritva Irene' place=9
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    28,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-F-EPEE-2025-2026'),
    10,
    'CHMIELEWSKA Emilia'
); -- matched: CHMIELEWSKA Emilia (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    325,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-F-EPEE-2025-2026'),
    11,
    'MURRAY Claire'
); -- matched: MURRAY Claire (score=100.0)
-- UNMATCHED (score<80): 'CEDERLUND Elisa' place=12
-- Compute scores for PEW6-V1-F-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-F-EPEE-2025-2026')
);

-- SKIP PEW7 (EVF Grand Prix 7 — Terni): N=0 — tournament had no participants

-- SKIP PS (Puchar Świata): N=0 — tournament had no participants

-- SKIP IMEW: event not yet held (SCHEDULED) — results are rolling carry-over from previous season

-- Summary
-- Total results matched:   31
-- Total results unmatched: 63
