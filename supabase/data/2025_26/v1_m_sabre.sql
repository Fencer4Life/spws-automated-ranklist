-- =========================================================================
-- Season 2025-2026 — V1 M SABRE — generated from SZABLA-1-2025-2026.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- =========================================================================
-- Auto-created fencers (domestic unmatched — ADR-020)
-- =========================================================================
INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, bool_birth_year_estimated)
SELECT 'FRYDRYCH', 'Aleksander', 1986, TRUE
WHERE NOT EXISTS (
    SELECT 1 FROM tbl_fencer WHERE txt_surname = 'FRYDRYCH' AND txt_first_name = 'Aleksander'
);

-- ---- PP1: I Puchar Polski Weteranów (Szabla Weterani Mężczyn 1) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW1-2025-2026',
    'I Puchar Polski Weteranów',
    'Szabla Weterani Mężczyn 1',
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
    'PPW1-V1-M-SABRE-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V1',
    NULL, 4, 'https://www.fencingtimelive.com/events/results/88D7892597C44D6B8CF310D852E6E62C',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    133,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-SABRE-2025-2026'),
    1,
    'KOWALEWSKI Rafał'
); -- matched: KOWALEWSKI Rafał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    127,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-SABRE-2025-2026'),
    2,
    'KOSIŃSKI Łukasz'
); -- matched: KOSIŃSKI Łukasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    147,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-SABRE-2025-2026'),
    3,
    'KUCIĘBA PIOTR'
); -- matched: KUCIĘBA Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    276,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-SABRE-2025-2026'),
    4,
    'TECŁAW Robert'
); -- matched: TECŁAW Robert (score=100.0)
-- Compute scores for PPW1-V1-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-SABRE-2025-2026')
);

-- ---- PP2: II Puchar Polski Weteranów (SZABLA WETERANI MĘŻCZYZNI 1) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW2-2025-2026',
    'II Puchar Polski Weteranów',
    'SZABLA WETERANI MĘŻCZYZNI 1',
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
    'PPW2-V1-M-SABRE-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V1',
    NULL, 5, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    147,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-SABRE-2025-2026'),
    1,
    'KUCIĘBA PIOTR'
); -- matched: KUCIĘBA Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    127,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-SABRE-2025-2026'),
    2,
    'KOSIŃSKI Łukasz'
); -- matched: KOSIŃSKI Łukasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    276,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-SABRE-2025-2026'),
    3,
    'TECŁAW Robert'
); -- matched: TECŁAW Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    133,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-SABRE-2025-2026'),
    4,
    'KOWALEWSKI Rafał'
); -- matched: KOWALEWSKI Rafał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'FRYDRYCH' AND txt_first_name = 'Aleksander'),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-SABRE-2025-2026'),
    5,
    'FRYDRYCH Aleksander'
); -- auto-created domestic fencer
-- Compute scores for PPW2-V1-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-SABRE-2025-2026')
);

-- ---- PP3: III Puchar Polski Weteranów (KRAKÓW) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW3-2025-2026',
    'III Puchar Polski Weteranów',
    'KRAKÓW',
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
    'PPW3-V1-M-SABRE-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V1',
    '2024-12-01', 2, 'https://www.fencingtimelive.com/events/results/5D5E76FEE3074C1A9032E1F3B74952AC',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    276,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-SABRE-2025-2026'),
    1,
    'TECŁAW Robert'
); -- matched: TECŁAW Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    307,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-SABRE-2025-2026'),
    2,
    'ZAJĄC Michał'
); -- matched: ZAJĄC Michał (score=100.0)
-- Compute scores for PPW3-V1-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-SABRE-2025-2026')
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
    'PPW4-V1-M-SABRE-2025-2026',
    'IV Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V1',
    '2026-02-21', 2, 'https://fencingtimelive.com/events/results/4793BEF489D848EDB24851784C0AC6D0',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    276,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-SABRE-2025-2026'),
    1,
    'TECŁAW Robert'
); -- matched: TECŁAW Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    133,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-SABRE-2025-2026'),
    2,
    'KOWALEWSKI Rafał'
); -- matched: KOWALEWSKI Rafał (score=100.0)
-- Compute scores for PPW4-V1-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-SABRE-2025-2026')
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
    'PEW4-V1-M-SABRE-2025-2026',
    'EVF Grand Prix 4',
    'PEW',
    'SABRE', 'M', 'V1',
    '2026-11-11', 13, 'https://www.fencingtimelive.com/events/results/A90FDA65C0B6491FA60F89C1EE0C1BF6',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    216,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-SABRE-2025-2026'),
    2,
    'PRZYSTAJKO Daniel'
); -- matched: PRZYSTAJKO Daniel (score=100.0)
-- Compute scores for PEW4-V1-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-SABRE-2025-2026')
);

-- ---- PEW5: EVF Grand Prix 5 (Faches-Thumesnil) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW5-2025-2026',
    'EVF Grand Prix 5',
    'Faches-Thumesnil',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW5-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW5-2025-2026'),
    'PEW5-V1-M-SABRE-2025-2026',
    'EVF Grand Prix 5',
    'PEW',
    'SABRE', 'M', 'V1',
    '2026-02-07', 20, 'https://engarde-service.com/competition/club_des_escrimeurs_de_faches_thumesnil/faches2026/shv1',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    276,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V1-M-SABRE-2025-2026'),
    3,
    'TECŁAW Robert'
); -- matched: TECŁAW Robert (score=100.0)
-- Compute scores for PEW5-V1-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V1-M-SABRE-2025-2026')
);

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
    'PEW6-V1-M-SABRE-2025-2026',
    'EVF Grand Prix 6',
    'PEW',
    'SABRE', 'M', 'V1',
    NULL, 17, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'GAY PAOLO' place=1
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    276,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-SABRE-2025-2026'),
    2,
    'TECŁAW Robert'
); -- matched: TECŁAW Robert (score=100.0)
-- SKIPPED (international, no master data): 'GALLAVOTTI FRANCESCO' place=3
-- SKIPPED (international, no master data): 'ZANELLATO LORENZO' place=4
-- SKIPPED (international, no master data): 'TUCCILLO ALESSANDRO' place=5
-- SKIPPED (international, no master data): 'ROSSETTO ALBERTO' place=6
-- SKIPPED (international, no master data): 'MARTINI MATTEO' place=7
-- SKIPPED (international, no master data): 'GRECO NICOLA' place=8
-- SKIPPED (international, no master data): 'SPILIMBERGO JACOPO' place=9
-- SKIPPED (international, no master data): 'NASH RUBIN' place=10
-- SKIPPED (international, no master data): 'VENDITTI GASPARE LORENZO' place=11
-- SKIPPED (international, no master data): 'GIOVANGIACOMO LUCA' place=12
-- SKIPPED (international, no master data): 'ANDREAZZO MORGAN' place=13
-- SKIPPED (international, no master data): 'DORNYEI MARTON' place=14
-- SKIPPED (international, no master data): 'MORRA EMANUELE' place=15
-- SKIPPED (international, no master data): 'BENETTOLO LUIGI' place=16
-- SKIPPED (international, no master data): 'DI MUZIO ENZO' place=17
-- Compute scores for PEW6-V1-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-SABRE-2025-2026')
);

-- ---- PEW7: EVF Grand Prix 7 — Terni (Szabla Mężczyzn V1 DE) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW7-2025-2026',
    'EVF Grand Prix 7 — Terni',
    'Szabla Mężczyzn V1 DE',
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
    'PEW7-V1-M-SABRE-2025-2026',
    'EVF Grand Prix 7 — Terni',
    'PEW',
    'SABRE', 'M', 'V1',
    NULL, 7, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    276,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-M-SABRE-2025-2026'),
    1,
    'TECŁAW Robert'
); -- matched: TECŁAW Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    147,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-M-SABRE-2025-2026'),
    2,
    'KUCIĘBA Piotr'
); -- matched: KUCIĘBA Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    216,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-M-SABRE-2025-2026'),
    3,
    'PRZYSTAJKO Daniel'
); -- matched: PRZYSTAJKO Daniel (score=100.0)
-- SKIPPED (international, no master data): 'NEMES Balázs' place=4
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    127,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-M-SABRE-2025-2026'),
    5,
    'KOSIŃSKI Łukasz'
); -- matched: KOSIŃSKI Łukasz (score=100.0)
-- SKIPPED (international, no master data): 'GALLAVOTTI Francesco' place=6
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    307,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-M-SABRE-2025-2026'),
    7,
    'ZAJĄC Michał'
); -- matched: ZAJĄC Michał (score=100.0)
-- Compute scores for PEW7-V1-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-M-SABRE-2025-2026')
);

-- SKIP PEW8 (EVF Grand Prix 8 — Guildford): N=0 — tournament had no participants

-- SKIP PEW9 (EVF Grand Prix 9 — Sztokholm): N=0 — tournament had no participants

-- ---- PEW10: EVF Criterium Mondial Vétérans (Paryż) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW10-2025-2026',
    'EVF Criterium Mondial Vétérans 2025',
    'Paryż',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW10-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW10-2025-2026'),
    'PEW10-V1-M-SABRE-2025-2026',
    'EVF Criterium Mondial Vétérans 2025',
    'PEW',
    'SABRE', 'M', 'V1',
    '2025-07-05', 9, 'https://engarde-service.com/competition/fencingaddict/crit25/shv1',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    216,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW10-V1-M-SABRE-2025-2026'),
    5,
    'PRZYSTAJKO Daniel'
); -- matched: PRZYSTAJKO Daniel (score=100.0)
-- Compute scores for PEW10-V1-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW10-V1-M-SABRE-2025-2026')
);

-- Summary
-- Total results matched:   29
-- Total results unmatched: 31
-- Total auto-created:      1
