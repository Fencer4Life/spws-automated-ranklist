-- =========================================================================
-- Season 2025-2026 — V1 M SABRE — generated from SZABLA-1-2025-2026.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

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
    NULL, 4, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    126,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-SABRE-2025-2026'),
    1,
    'KOWALEWSKI Rafał'
); -- matched: KOWALEWSKI Rafał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    120,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-SABRE-2025-2026'),
    2,
    'KOSIŃSKI Łukasz'
); -- matched: KOSIŃSKI Łukasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    137,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-SABRE-2025-2026'),
    3,
    'KUCIĘBA PIOTR'
); -- matched: KUCIĘBA Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    232,
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
    137,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-SABRE-2025-2026'),
    1,
    'KUCIĘBA PIOTR'
); -- matched: KUCIĘBA Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    120,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-SABRE-2025-2026'),
    2,
    'KOSIŃSKI Łukasz'
); -- matched: KOSIŃSKI Łukasz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    232,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-SABRE-2025-2026'),
    3,
    'TECŁAW Robert'
); -- matched: TECŁAW Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    126,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-SABRE-2025-2026'),
    4,
    'KOWALEWSKI Rafał'
); -- matched: KOWALEWSKI Rafał (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    52,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-SABRE-2025-2026'),
    5,
    'FRYDRYCH Aleksander'
); -- matched: FRYDRYCH Aleksander (score=100.0)
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
    232,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-SABRE-2025-2026'),
    1,
    'TECŁAW Robert'
); -- matched: TECŁAW Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    263,
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
    232,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-SABRE-2025-2026'),
    1,
    'TECŁAW Robert'
); -- matched: TECŁAW Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    126,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-SABRE-2025-2026'),
    2,
    'KOWALEWSKI Rafał'
); -- matched: KOWALEWSKI Rafał (score=100.0)
-- Compute scores for PPW4-V1-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-SABRE-2025-2026')
);

-- SKIP PP5: event not yet held (SCHEDULED) — results are rolling carry-over from previous season

-- SKIP MPW: event not yet held (SCHEDULED) — results are rolling carry-over from previous season

-- SKIP PEW1 (EVF Grand Prix 1 — Budapeszt): 0 matched fencers in DB — tournament not created

-- SKIP PEW2 (EVF Grand Prix 2 — Madryt): 0 matched fencers in DB — tournament not created

-- SKIP PEW3 (EVF Grand Prix 3): N=0 — tournament had no participants

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
    189,
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
    232,
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
-- UNMATCHED (score<80): 'GAY PAOLO' place=1
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    232,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-SABRE-2025-2026'),
    2,
    'TECŁAW Robert'
); -- matched: TECŁAW Robert (score=100.0)
-- UNMATCHED (score<80): 'GALLAVOTTI FRANCESCO' place=3
-- UNMATCHED (score<80): 'ZANELLATO LORENZO' place=4
-- UNMATCHED (score<80): 'TUCCILLO ALESSANDRO' place=5
-- UNMATCHED (score<80): 'ROSSETTO ALBERTO' place=6
-- UNMATCHED (score<80): 'MARTINI MATTEO' place=7
-- UNMATCHED (score<80): 'GRECO NICOLA' place=8
-- UNMATCHED (score<80): 'SPILIMBERGO JACOPO' place=9
-- UNMATCHED (score<80): 'NASH RUBIN' place=10
-- UNMATCHED (score<80): 'VENDITTI GASPARE LORENZO' place=11
-- UNMATCHED (score<80): 'GIOVANGIACOMO LUCA' place=12
-- UNMATCHED (score<80): 'ANDREAZZO MORGAN' place=13
-- UNMATCHED (score<80): 'DORNYEI MARTON' place=14
-- UNMATCHED (score<80): 'MORRA EMANUELE' place=15
-- UNMATCHED (score<80): 'BENETTOLO LUIGI' place=16
-- UNMATCHED (score<80): 'DI MUZIO ENZO' place=17
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
    232,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-M-SABRE-2025-2026'),
    1,
    'TECŁAW Robert'
); -- matched: TECŁAW Robert (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    137,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-M-SABRE-2025-2026'),
    2,
    'KUCIĘBA Piotr'
); -- matched: KUCIĘBA Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    189,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-M-SABRE-2025-2026'),
    3,
    'PRZYSTAJKO Daniel'
); -- matched: PRZYSTAJKO Daniel (score=100.0)
-- UNMATCHED (score<80): 'NEMES Balázs' place=4
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    120,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-M-SABRE-2025-2026'),
    5,
    'KOSIŃSKI Łukasz'
); -- matched: KOSIŃSKI Łukasz (score=100.0)
-- UNMATCHED (score<80): 'GALLAVOTTI Francesco' place=6
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    263,
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
    'PS-V1-M-SABRE-2025-2026',
    'Puchar Świata',
    'PSW',
    'SABRE', 'M', 'V1',
    '2025-07-05', 9, 'https://engarde-service.com/competition/fencingaddict/crit25/shv1',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    189,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PS-V1-M-SABRE-2025-2026'),
    5,
    'PRZYSTAJKO Daniel'
); -- matched: PRZYSTAJKO Daniel (score=100.0)
-- Compute scores for PS-V1-M-SABRE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PS-V1-M-SABRE-2025-2026')
);

-- SKIP IMEW (Indywidualne Mistrzostwa Europy Weteranów): 0 matched fencers in DB — tournament not created

-- Summary
-- Total results matched:   30
-- Total results unmatched: 30
