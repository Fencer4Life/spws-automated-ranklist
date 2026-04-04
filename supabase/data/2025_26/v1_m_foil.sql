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
    164,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-FOIL-2025-2026'),
    1,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    68,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-FOIL-2025-2026'),
    2,
    'GIBULA Marcin'
); -- matched: GIBULA Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    37,
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
    164,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-FOIL-2025-2026'),
    1,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    54,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-FOIL-2025-2026'),
    2,
    'EJCHSZTET Mariusz'
); -- matched: EJCHSZTET Mariusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    68,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-FOIL-2025-2026'),
    3,
    'GIBULA Marcin'
); -- matched: GIBULA Marcin (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    37,
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
    164,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-FOIL-2025-2026'),
    1,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    250,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-FOIL-2025-2026'),
    2,
    'SPŁAWA-NEYMAN (0) MACIEJ'
); -- matched: SPŁAWA-NEYMAN MACIEJ (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    266,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-FOIL-2025-2026'),
    3,
    'SZMELC (0) Łukasz'
); -- matched: SZMELC Łukasz (score=100.0)
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
    37,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-FOIL-2025-2026'),
    1,
    'CHUDY Tomasz'
); -- matched: CHUDY Tomasz (score=100.0)
-- Compute scores for PPW4-V1-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-FOIL-2025-2026')
);
-- ---- PEW2: EVF Grand Prix 2 — Madryt (VI Ciudad de Madrid CUP VETERANS FENCING) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW2-2025-2026',
    'EVF Grand Prix 2 — Madryt',
    'VI Ciudad de Madrid CUP VETERANS FENCING',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW2-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW2-2025-2026'),
    'PEW2-V1-M-FOIL-2025-2026',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'FOIL', 'M', 'V1',
    NULL, 28, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'ERNST' place=1
-- SKIPPED (international, no master data): 'TOKOLA' place=2
-- SKIPPED (international, no master data): 'SIERRA' place=3
-- SKIPPED (international, no master data): 'ALONSO ESCOBAR' place=4
-- SKIPPED (international, no master data): 'GHITTI' place=5
-- SKIPPED (international, no master data): 'GRAHAM REID' place=6
-- SKIPPED (international, no master data): 'HERRANZ FERREROS' place=7
-- SKIPPED (international, no master data): 'SEEGER' place=8
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    70,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-M-FOIL-2025-2026'),
    9,
    'GINZERY'
); -- matched: GINZERY Tomas (score=70.0)
-- SKIPPED (international, no master data): 'PULEGA' place=10
-- SKIPPED (international, no master data): 'RUIZ ALCONERO' place=11
-- SKIPPED (international, no master data): 'ZHAO' place=12
-- SKIPPED (international, no master data): 'BENTZ' place=13
-- SKIPPED (international, no master data): 'MARTOS GARCIA' place=14
-- SKIPPED (international, no master data): 'GAMEZ SANCHEZ' place=15
-- SKIPPED (international, no master data): 'HEGEDAS' place=16
-- SKIPPED (international, no master data): 'FARKAS' place=17
-- SKIPPED (international, no master data): 'DE ANDRES RUIZ-AYUCAR' place=18
-- SKIPPED (international, no master data): 'BLANCO BLANCO' place=19
-- SKIPPED (international, no master data): 'KORONA' place=20
-- SKIPPED (international, no master data): 'POMELLI' place=21
-- SKIPPED (international, no master data): 'HILTUNEN' place=22
-- SKIPPED (international, no master data): 'MULLER' place=23
-- SKIPPED (international, no master data): 'BARDON' place=24
-- SKIPPED (international, no master data): 'CHEN' place=25
-- SKIPPED (international, no master data): 'SEGURA CHECA' place=26
-- SKIPPED (international, no master data): 'ALVEAR' place=27
-- SKIPPED (international, no master data): 'ALCSER' place=28
-- Compute scores for PEW2-V1-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-M-FOIL-2025-2026')
);

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
-- SKIPPED (international, no master data): 'SUTTON 1 Mark' place=1
-- SKIPPED (international, no master data): 'DELATTRE 1 Jeffrey' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    216,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-FOIL-2025-2026'),
    3,
    'PRZYSTAJKO Daniel'
); -- matched: PRZYSTAJKO Daniel (score=100.0)
-- SKIPPED (international, no master data): 'GHITTI 1 Michele' place=4
-- SKIPPED (international, no master data): 'SEEGER 1 Martin' place=5
-- SKIPPED (international, no master data): 'VEAZEY 1 Paul' place=6
-- SKIPPED (international, no master data): 'ERNST 1 Deniz' place=7
-- SKIPPED (international, no master data): 'GIBSON 1 Rory' place=8
-- SKIPPED (international, no master data): 'MASSEY 1 Oliver' place=9
-- SKIPPED (international, no master data): 'NAULLS 1 Michael' place=10
-- SKIPPED (international, no master data): 'HOULDSWORTH 1 Alastair' place=11
-- SKIPPED (international, no master data): 'CIMPEAN 1 Ioan' place=12
-- SKIPPED (international, no master data): 'CHATTERTON 1 Phil' place=13
-- SKIPPED (international, no master data): 'COX 1 Gregory' place=14
-- SKIPPED (international, no master data): 'BA 1 Mouhamadou Alpha' place=15
-- SKIPPED (international, no master data): 'RIOUX 1 Frederic' place=16
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-FOIL-2025-2026'),
    17,
    'ALCSER 1 Norbert'
); -- matched: ALCSER Norbert (score=100.0)
-- SKIPPED (international, no master data): 'SIDGWICK 1 Aly' place=18
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
-- SKIPPED (international, no master data): 'WOLNY PRZEMYSLAW SZYM' place=1
-- SKIPPED (international, no master data): 'ALONSO ESCOBAR JAVIER' place=2
-- SKIPPED (international, no master data): 'BALESTRIERI UGO' place=3
-- SKIPPED (international, no master data): 'D''ATTELLIS PIETRO' place=4
-- SKIPPED (international, no master data): 'SPEZZAFERRO ALBERTO MARIA' place=5
-- SKIPPED (international, no master data): 'JUNCO CARLOS' place=6
-- SKIPPED (international, no master data): 'GHITTI MICHELE' place=7
-- SKIPPED (international, no master data): 'BALLARINI SIMONE' place=8
-- SKIPPED (international, no master data): 'SIROLLI FRANCESCO SAVER' place=9
-- SKIPPED (international, no master data): 'CAMPLONE CRISTIANO' place=10
-- SKIPPED (international, no master data): 'SIMEONI MARIO' place=11
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-FOIL-2025-2026'),
    12,
    'ALCSER NORBERT'
); -- matched: ALCSER Norbert (score=100.0)
-- SKIPPED (international, no master data): 'MASELLA ROBERTO MARIA' place=13
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
    70,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-M-FOIL-2025-2026'),
    1,
    'GINZERY Tomas'
); -- matched: GINZERY Tomas (score=100.0)
-- SKIPPED (international, no master data): 'ERNST Deniz' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
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
-- SKIPPED (international, no master data): 'SZUMIELEWICZ Paweł' place=1
-- SKIPPED (international, no master data): 'GLATT Andor' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    70,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V1-M-FOIL-2025-2026'),
    3,
    'GINZERY Tomas'
); -- matched: GINZERY Tomas (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    216,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V1-M-FOIL-2025-2026'),
    3,
    'PRZYSTAJKO Daniel'
); -- matched: PRZYSTAJKO Daniel (score=100.0)
-- SKIPPED (international, no master data): 'SEEGER Martin' place=5
-- SKIPPED (international, no master data): 'WOLNY Przemyslaw Szymon' place=6
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    240,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V1-M-FOIL-2025-2026'),
    7,
    'SERAFIN Błażej'
); -- matched: SERAFIN Błażej (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    164,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V1-M-FOIL-2025-2026'),
    8,
    'MALINOWSKI Piotr'
); -- matched: MALINOWSKI Piotr (score=100.0)
-- SKIPPED (international, no master data): 'TJARKS Lasse' place=9
-- SKIPPED (international, no master data): 'GRÉGOIRE Jean-Charles' place=10
-- SKIPPED (international, no master data): 'VARADI Marton' place=11
-- SKIPPED (international, no master data): 'ERNST Deniz' place=12
-- SKIPPED (international, no master data): 'RIOUX Frederic' place=13
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
    216,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PS-V1-M-FOIL-2025-2026'),
    6,
    'PRZYSTAJKO Daniel'
); -- matched: PRZYSTAJKO Daniel (score=100.0)
-- Compute scores for PS-V1-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PS-V1-M-FOIL-2025-2026')
);

-- Summary
-- Total results matched:   27
-- Total results unmatched: 65
-- Total auto-created:      0
