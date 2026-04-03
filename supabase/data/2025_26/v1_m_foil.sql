-- =========================================================================
-- Season 2025-2026 — V1 M FOIL — generated from FLORET-1-2025-2026.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- ---- PP1: I Puchar Polski Weteranów (Floret Weterani Mężczyzni 1) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW1-2025-2026',
    'I Puchar Polski Weteranów',
    'Floret Weterani Mężczyzni 1',
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
    'PPW1-V1-M-FOIL-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V1',
    NULL, 3, 'https://www.fencingtimelive.com/events/results/B70595711BE14439A2EF83D742DA8326',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    145,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-FOIL-2025-2026'),
    1,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    290,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-FOIL-2025-2026'),
    2,
    'GIBULA Marcin'
); -- matched: GIBULA Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    280,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-FOIL-2025-2026'),
    3,
    'CHUDY Tomasz'
); -- matched: CHUDY Tomasz (score=100.0)
-- Compute scores for PPW1-V1-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-FOIL-2025-2026')
);

-- ---- PP2: II Puchar Polski Weteranów (FLORET WETERANI Mężczyzni) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW2-2025-2026',
    'II Puchar Polski Weteranów',
    'FLORET WETERANI Mężczyzni',
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
    'PPW2-V1-M-FOIL-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V1',
    NULL, 4, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    145,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-FOIL-2025-2026'),
    1,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    283,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-FOIL-2025-2026'),
    2,
    'EJCHSZTET Mariusz'
); -- matched: EJCHSZTET Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    290,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-FOIL-2025-2026'),
    3,
    'GIBULA Marcin'
); -- matched: GIBULA Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    280,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-FOIL-2025-2026'),
    4,
    'CHUDY Tomasz'
); -- matched: CHUDY Tomasz (score=100.0)
-- Compute scores for PPW2-V1-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-FOIL-2025-2026')
);

-- ---- PP3: III Puchar Polski Weteranów (Floret Mężczyzn kat. 0-1) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW3-2025-2026',
    'III Puchar Polski Weteranów',
    'Floret Mężczyzn kat. 0-1',
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
    'PPW3-V1-M-FOIL-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V1',
    NULL, 3, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    145,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-FOIL-2025-2026'),
    1,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    350,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-FOIL-2025-2026'),
    2,
    'SPŁAWA-NEYMAN (0) MACIEJ'
); -- matched: SPŁAWA-NEYMAN (0) MACIEJ (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    361,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-FOIL-2025-2026'),
    3,
    'SZMELC (0) Łukasz'
); -- matched: SZMELC (0) Łukasz (score=100.0)
-- Compute scores for PPW3-V1-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-FOIL-2025-2026')
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
    'PPW4-V1-M-FOIL-2025-2026',
    'IV Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V1',
    '2026-02-21', 1, 'https://fencingtimelive.com/events/results/4929E313891049FA9CF83C9DC9CECD3D',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    280,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-FOIL-2025-2026'),
    1,
    'CHUDY Tomasz'
); -- matched: CHUDY Tomasz (score=100.0)
-- Compute scores for PPW4-V1-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-FOIL-2025-2026')
);

-- SKIP PP5: event not yet held (SCHEDULED) — results are rolling carry-over from previous season

-- SKIP MPW: event not yet held (SCHEDULED) — results are rolling carry-over from previous season

-- SKIP PEW1 (EVF Grand Prix 1 — Budapeszt): 0 matched fencers in DB — tournament not created

-- SKIP PEW2 (EVF Grand Prix 2 — Madryt): 0 matched fencers in DB — tournament not created

-- SKIP PEW3 (EVF Grand Prix 3): N=0 — tournament had no participants

-- ---- PEW4: EVF Grand Prix 4 (Men's Foil Category 1) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW4-2025-2026',
    'EVF Grand Prix 4',
    'Men''s Foil Category 1',
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
    'PEW4-V1-M-FOIL-2025-2026',
    'EVF Grand Prix 4',
    'PEW',
    'FOIL', 'M', 'V1',
    NULL, 18, NULL,
    'SCORED'
);
-- UNMATCHED (score<80): 'SUTTON 1 Mark' place=1
-- UNMATCHED (score<80): 'DELATTRE 1 Jeffrey' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    189,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-FOIL-2025-2026'),
    3,
    'PRZYSTAJKO Daniel'
); -- matched: PRZYSTAJKO Daniel (score=100.0)
-- UNMATCHED (score<80): 'GHITTI 1 Michele' place=4
-- UNMATCHED (score<80): 'SEEGER 1 Martin' place=5
-- UNMATCHED (score<80): 'VEAZEY 1 Paul' place=6
-- UNMATCHED (score<80): 'ERNST 1 Deniz' place=7
-- UNMATCHED (score<80): 'GIBSON 1 Rory' place=8
-- UNMATCHED (score<80): 'MASSEY 1 Oliver' place=9
-- UNMATCHED (score<80): 'NAULLS 1 Michael' place=10
-- UNMATCHED (score<80): 'HOULDSWORTH 1 Alastair' place=11
-- UNMATCHED (score<80): 'CIMPEAN 1 Ioan' place=12
-- UNMATCHED (score<80): 'CHATTERTON 1 Phil' place=13
-- UNMATCHED (score<80): 'COX 1 Gregory' place=14
-- UNMATCHED (score<80): 'BA 1 Mouhamadou Alpha' place=15
-- UNMATCHED (score<80): 'RIOUX 1 Frederic' place=16
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    272,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-FOIL-2025-2026'),
    17,
    'ALCSER 1 Norbert'
); -- matched: ALCSER Norbert (score=93.33333333333333)
-- UNMATCHED (score<80): 'SIDGWICK 1 Aly' place=18
-- Compute scores for PEW4-V1-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-FOIL-2025-2026')
);

-- SKIP PEW5 (EVF Grand Prix 5): N=0 — tournament had no participants

-- ---- PEW6: EVF Grand Prix 6 (2026-03-08-07 Napoli - 4 Prova Circuito Nazionale Master 2025-2 - Fioretto Maschile ) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW6-2025-2026',
    'EVF Grand Prix 6',
    '2026-03-08-07 Napoli - 4 Prova Circuito Nazionale Master 2025-2 - Fioretto Maschile ',
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
    'PEW6-V1-M-FOIL-2025-2026',
    'EVF Grand Prix 6',
    'PEW',
    'FOIL', 'M', 'V1',
    NULL, 13, NULL,
    'SCORED'
);
-- UNMATCHED (score<80): 'WOLNY PRZEMYSLAW SZYM' place=1
-- UNMATCHED (score<80): 'ALONSO ESCOBAR JAVIER' place=2
-- UNMATCHED (score<80): 'BALESTRIERI UGO' place=3
-- UNMATCHED (score<80): 'D''ATTELLIS PIETRO' place=4
-- UNMATCHED (score<80): 'SPEZZAFERRO ALBERTO MARIA' place=5
-- UNMATCHED (score<80): 'JUNCO CARLOS' place=6
-- UNMATCHED (score<80): 'GHITTI MICHELE' place=7
-- UNMATCHED (score<80): 'BALLARINI SIMONE' place=8
-- UNMATCHED (score<80): 'SIROLLI FRANCESCO SAVER' place=9
-- UNMATCHED (score<80): 'CAMPLONE CRISTIANO' place=10
-- UNMATCHED (score<80): 'SIMEONI MARIO' place=11
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    272,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-FOIL-2025-2026'),
    12,
    'ALCSER NORBERT'
); -- matched: ALCSER Norbert (score=100.0)
-- UNMATCHED (score<80): 'MASELLA ROBERTO MARIA' place=13
-- Compute scores for PEW6-V1-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-FOIL-2025-2026')
);

-- ---- PEW7: EVF Grand Prix 7 — Terni ( Mens Foil Cat 1 - Stockholm International Veteran Open 2026 ) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW7-2025-2026',
    'EVF Grand Prix 7 — Terni',
    ' Mens Foil Cat 1 - Stockholm International Veteran Open 2026 ',
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
    'PEW7-V1-M-FOIL-2025-2026',
    'EVF Grand Prix 7 — Terni',
    'PEW',
    'FOIL', 'M', 'V1',
    NULL, 3, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    67,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-M-FOIL-2025-2026'),
    1,
    'GINZERY Tomas'
); -- matched: GINZERY Tomas (score=100.0)
-- UNMATCHED (score<80): 'ERNST Deniz' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    272,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-M-FOIL-2025-2026'),
    3,
    'ALCSER Norbert'
); -- matched: ALCSER Norbert (score=100.0)
-- Compute scores for PEW7-V1-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-M-FOIL-2025-2026')
);

-- ---- PEW8: EVF Grand Prix 8 — Guildford (Floret Mężczyzn V1) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW8-2025-2026',
    'EVF Grand Prix 8 — Guildford',
    'Floret Mężczyzn V1',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW8-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW8-2025-2026'),
    'PEW8-V1-M-FOIL-2025-2026',
    'EVF Grand Prix 8 — Guildford',
    'PEW',
    'FOIL', 'M', 'V1',
    NULL, 13, NULL,
    'SCORED'
);
-- UNMATCHED (score<80): 'SZUMIELEWICZ Paweł' place=1
-- UNMATCHED (score<80): 'GLATT Andor' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    67,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V1-M-FOIL-2025-2026'),
    3,
    'GINZERY Tomas'
); -- matched: GINZERY Tomas (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    189,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V1-M-FOIL-2025-2026'),
    3,
    'PRZYSTAJKO Daniel'
); -- matched: PRZYSTAJKO Daniel (score=100.0)
-- UNMATCHED (score<80): 'SEEGER Martin' place=5
-- UNMATCHED (score<80): 'WOLNY Przemyslaw Szymon' place=6
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    345,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V1-M-FOIL-2025-2026'),
    7,
    'SERAFIN Błażej'
); -- matched: SERAFIN Błażej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    145,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V1-M-FOIL-2025-2026'),
    8,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
-- UNMATCHED (score<80): 'TJARKS Lasse' place=9
-- UNMATCHED (score<80): 'GRÉGOIRE Jean-Charles' place=10
-- UNMATCHED (score<80): 'VARADI Marton' place=11
-- UNMATCHED (score<80): 'ERNST Deniz' place=12
-- UNMATCHED (score<80): 'RIOUX Frederic' place=13
-- Compute scores for PEW8-V1-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V1-M-FOIL-2025-2026')
);

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
    'PS-V1-M-FOIL-2025-2026',
    'Puchar Świata',
    'PSW',
    'FOIL', 'M', 'V1',
    '2025-07-05', 16, 'https://engarde-service.com/competition/fencingaddict/crit25/fhv1',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    189,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PS-V1-M-FOIL-2025-2026'),
    6,
    'PRZYSTAJKO Daniel'
); -- matched: PRZYSTAJKO Daniel (score=100.0)
-- Compute scores for PS-V1-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PS-V1-M-FOIL-2025-2026')
);

-- SKIP IMEW: event not yet held (SCHEDULED) — results are rolling carry-over from previous season

-- Summary
-- Total results matched:   26
-- Total results unmatched: 66
