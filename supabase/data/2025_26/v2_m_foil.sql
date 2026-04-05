-- =========================================================================
-- Season 2025-2026 — V2 M FOIL — generated from FLORET-2-2025-2026.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- SKIP PP1 (I Puchar Polski Weteranów): N=0 — tournament had no participants

-- SKIP PP2 (II Puchar Polski Weteranów): N=0 — tournament had no participants

-- ---- PP3: III Puchar Polski Weteranów (ŁOMIANKI) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW3-2025-2026',
    'III Puchar Polski Weteranów',
    'ŁOMIANKI',
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
    'PPW3-V2-M-FOIL-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V2',
    '2025-12-13', 2, 'https://www.fencingtimelive.com/events/results/6FC6FCED7C4E4D1C95CA591801308B79',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-FOIL-2025-2026'),
    1,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    241,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-FOIL-2025-2026'),
    2,
    'SERWATKA Marek'
); -- matched: SERWATKA Marek (score=100.0)
-- Compute scores for PPW3-V2-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-FOIL-2025-2026')
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
    'PPW4-V2-M-FOIL-2025-2026',
    'IV Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V2',
    '2026-02-21', 2, 'https://fencingtimelive.com/events/results/4929E313891049FA9CF83C9DC9CECD3D',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-FOIL-2025-2026'),
    1,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-FOIL-2025-2026'),
    2,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
-- Compute scores for PPW4-V2-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-FOIL-2025-2026')
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
    'PEW1-V2-M-FOIL-2025-2026',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'FOIL', 'M', 'V2',
    NULL, 25, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'PULEGA Roberto' place=1
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-FOIL-2025-2026'),
    2,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
-- SKIPPED (international, no master data): 'PESCE Filippo' place=3
-- SKIPPED (international, no master data): 'MÁLICS Róbert' place=4
-- SKIPPED (international, no master data): 'KOZAKIVSKYI Vasyl' place=5
-- SKIPPED (international, no master data): 'LEZHAVA Nikoloz' place=6
-- SKIPPED (international, no master data): 'SEGURA CHECA Enrique' place=7
-- SKIPPED (international, no master data): 'FARKAS Attila' place=8
-- SKIPPED (international, no master data): 'GERZANICS Márk' place=9
-- SKIPPED (international, no master data): 'BAIR Stephan' place=10
-- SKIPPED (international, no master data): 'SÁGHY Ervin' place=11
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    246,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-FOIL-2025-2026'),
    12,
    'SOKOL Vratislav'
); -- matched: SOKOL Vratislav (score=100.0)
-- SKIPPED (international, no master data): 'SZABÓ András' place=13
-- SKIPPED (international, no master data): 'KRISTÓF Márton' place=14
-- SKIPPED (international, no master data): 'GMEREK Marcel' place=15
-- SKIPPED (international, no master data): 'HIRNER Wolfgang' place=16
-- SKIPPED (international, no master data): 'HEGEDŰS Sándor' place=17
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    140,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-FOIL-2025-2026'),
    18,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
-- SKIPPED (international, no master data): 'MÜLLER Ferenc' place=19
-- SKIPPED (international, no master data): 'PATAKI Zoltán' place=20
-- SKIPPED (international, no master data): 'VILA Paulo' place=21
-- SKIPPED (international, no master data): 'BRUNNER Konstantin' place=22
-- SKIPPED (international, no master data): 'DR CSIGÓ Csaba' place=23
-- SKIPPED (international, no master data): 'NOVELLINO Giuseppe' place=24
-- SKIPPED (international, no master data): 'FÁBIÁN Gábor' place=25
-- Compute scores for PEW1-V2-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-FOIL-2025-2026')
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
    'PEW2-V2-M-FOIL-2025-2026',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'FOIL', 'M', 'V2',
    NULL, 17, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-FOIL-2025-2026'),
    8,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
-- SKIPPED (international, no master data): 'CHEN' place=25
-- SKIPPED (international, no master data): 'SEGURA CHECA' place=26
-- SKIPPED (international, no master data): 'ALVEAR' place=27
-- SKIPPED (international, no master data): 'ALCSER' place=28
-- Compute scores for PEW2-V2-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-FOIL-2025-2026')
);

-- SKIP PEW3 (EVF Grand Prix 3): N=0 — tournament had no participants

-- ---- PEW4: EVF Grand Prix 4 (Men's Foil Category 2) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW4-2025-2026',
    'EVF Grand Prix 4',
    'Men''s Foil Category 2',
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
    'PEW4-V2-M-FOIL-2025-2026',
    'EVF Grand Prix 4',
    'PEW',
    'FOIL', 'M', 'V2',
    NULL, 30, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'PAYNE 2 Nick' place=1
-- SKIPPED (international, no master data): 'MCKAY 2 Mike' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    140,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-FOIL-2025-2026'),
    3,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
-- SKIPPED (international, no master data): 'BARNES-WEBB 2 Richard' place=4
-- SKIPPED (international, no master data): 'CHO 2 Michael' place=5
-- SKIPPED (international, no master data): 'RIFFATERRE 2 Jason' place=6
-- SKIPPED (international, no master data): 'ENRIQUEZ SILVEIRA 2 Lazaro Vladimir' place=7
-- SKIPPED (international, no master data): 'GRIFFIN 2 Adrian' place=8
-- SKIPPED (international, no master data): 'PULEGA 2 Roberto' place=9
-- SKIPPED (international, no master data): 'MORT 2 Nick' place=10
-- SKIPPED (international, no master data): 'THOMAS 2 Michael' place=11
-- SKIPPED (international, no master data): 'ELLISON 2 Alexander' place=12
-- SKIPPED (international, no master data): 'GMEREK 2 Marcel' place=13
-- SKIPPED (international, no master data): 'RHODES 2 Giles' place=14
-- SKIPPED (international, no master data): 'KINGSTON 2 Matthew' place=15
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-FOIL-2025-2026'),
    16,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
-- SKIPPED (international, no master data): 'NGUYEN 2 Thomas' place=17
-- SKIPPED (international, no master data): 'SUNG 2 Velota' place=18
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    18,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-FOIL-2025-2026'),
    19,
    'BLAKE 2 Daniel'
); -- matched: BETLEJ Daniel (score=74.07407407407408)
-- SKIPPED (international, no master data): 'RYSDALE 2 Edward' place=20
-- SKIPPED (international, no master data): 'THOMAS 2 Richard' place=21
-- SKIPPED (international, no master data): 'JENNINGS 2 Sean' place=22
-- SKIPPED (international, no master data): 'WEBB 2 Andrew' place=23
-- SKIPPED (international, no master data): 'MCWILLIAMS 2 Keith' place=24
-- SKIPPED (international, no master data): 'SHING MAN 2 Tam' place=25
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    6,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-FOIL-2025-2026'),
    26,
    'ANDERSON 2 Robert'
); -- matched: ANDERSCH Robert (score=81.25)
-- SKIPPED (international, no master data): 'STANBRIDGE 2 Paul' place=27
-- SKIPPED (international, no master data): 'VICTORY 2 David' place=28
-- SKIPPED (international, no master data): 'VILA 2 Paulo' place=29
-- SKIPPED (international, no master data): 'BRITTAIN 2 Brian' place=30
-- Compute scores for PEW4-V2-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-FOIL-2025-2026')
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
    'PEW6-V2-M-FOIL-2025-2026',
    'EVF Grand Prix 6',
    'PEW',
    'FOIL', 'M', 'V2',
    NULL, 23, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'WYSZYNSKI MAREK' place=1
-- SKIPPED (international, no master data): 'DI RUSSO FABIO' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-FOIL-2025-2026'),
    3,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
-- SKIPPED (international, no master data): 'PESCE FILIPPO' place=4
-- SKIPPED (international, no master data): 'PERSICHETTI LORENZO' place=5
-- SKIPPED (international, no master data): 'RICHIARDI LORENZO' place=6
-- SKIPPED (international, no master data): 'PULEGA ROBERTO ANDREA' place=7
-- SKIPPED (international, no master data): 'BECHER KARL' place=8
-- SKIPPED (international, no master data): 'ZEIN ELABEDIN TAMER' place=9
-- SKIPPED (international, no master data): 'CAGGIANI FILIPPO' place=10
-- SKIPPED (international, no master data): 'HEGEDUS SANDOR' place=11
-- SKIPPED (international, no master data): 'GRAVES SMITH GEOFFREY' place=12
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    15,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-FOIL-2025-2026'),
    13,
    'BAZAK JACEK TOMASZ'
); -- matched: BAZAK Jacek (score=100.0)
-- SKIPPED (international, no master data): 'LARATO FABRIZIO NICOLA' place=14
-- SKIPPED (international, no master data): 'CICOIRA MARIO' place=15
-- SKIPPED (international, no master data): 'RONDINA FRANCESCO' place=16
-- SKIPPED (international, no master data): 'ORAZI ANDREA' place=17
-- SKIPPED (international, no master data): 'LUCREZI GINO' place=18
-- SKIPPED (international, no master data): 'VIRGILI FLAVIO' place=19
-- SKIPPED (international, no master data): 'FURCHI'' ROBERTO' place=20
-- SKIPPED (international, no master data): 'MULLER FERENC' place=21
-- SKIPPED (international, no master data): 'VARGA GERGELY' place=22
-- SKIPPED (international, no master data): 'BRUSCHI DAVIDE' place=23
-- Compute scores for PEW6-V2-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-FOIL-2025-2026')
);

-- ---- PEW7: EVF Grand Prix 7 — Terni ( Mens Foil Cat 2 - Stockholm International Veteran Open ) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW7-2025-2026',
    'EVF Grand Prix 7 — Terni',
    ' Mens Foil Cat 2 - Stockholm International Veteran Open ',
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
    'PEW7-V2-M-FOIL-2025-2026',
    'EVF Grand Prix 7 — Terni',
    'PEW',
    'FOIL', 'M', 'V2',
    NULL, 9, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'SZABO Andras Laszlo' place=1
-- SKIPPED (international, no master data): 'SIPOS Szilard' place=2
-- SKIPPED (international, no master data): 'GRIFFIN Adrian' place=3
-- SKIPPED (international, no master data): 'GRAVES SMITH Geoffrey' place=4
-- SKIPPED (international, no master data): 'PULEGA Roberto Andrea Enzo' place=5
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    15,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-FOIL-2025-2026'),
    6,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
-- SKIPPED (international, no master data): 'KREIS Sebastian' place=7
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-FOIL-2025-2026'),
    8,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
-- SKIPPED (international, no master data): 'VICTORY David' place=9
-- SKIPPED (international, no master data): '.' place=10
-- SKIPPED (international, no master data): '.' place=11
-- SKIPPED (international, no master data): '.' place=12
-- SKIPPED (international, no master data): '.' place=13
-- SKIPPED (international, no master data): '.' place=14
-- SKIPPED (international, no master data): '.' place=15
-- SKIPPED (international, no master data): '.' place=16
-- SKIPPED (international, no master data): '.' place=17
-- Compute scores for PEW7-V2-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-FOIL-2025-2026')
);

-- ---- PEW8: EVF Grand Prix 8 — Guildford (Floret Mężczyzn V2) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW8-2025-2026',
    'EVF Grand Prix 8 — Guildford',
    'Floret Mężczyzn V2',
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
    'PEW8-V2-M-FOIL-2025-2026',
    'EVF Grand Prix 8 — Guildford',
    'PEW',
    'FOIL', 'M', 'V2',
    NULL, 17, NULL,
    'SCORED'
);
-- SKIPPED (international, no master data): 'ZEIN ELABEDIN Tamer' place=1
-- SKIPPED (international, no master data): 'RICHIARDI Lorenzo' place=2
-- SKIPPED (international, no master data): 'HEGEDUS Sandor' place=3
-- SKIPPED (international, no master data): 'KOZAKIVSKYI Vasyl' place=4
-- SKIPPED (international, no master data): 'SZABO Andras' place=5
-- SKIPPED (international, no master data): 'PULEGA Roberto' place=6
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2025-2026'),
    7,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
-- SKIPPED (international, no master data): 'ZHAO Zhiyong' place=8
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    15,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2025-2026'),
    9,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    140,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2025-2026'),
    10,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
-- SKIPPED (international, no master data): 'RUSTAMZADE Rufat' place=11
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    123,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2025-2026'),
    12,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    246,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2025-2026'),
    13,
    'SOKOL Vratislav'
); -- matched: SOKOL Vratislav (score=100.0)
-- SKIPPED (international, no master data): 'GRAVES SMITH Geoffrey' place=14
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2025-2026'),
    15,
    'MALICS Robert'
); -- matched: ALCSER Norbert (score=74.07407407407408)
-- SKIPPED (international, no master data): 'NOVELLINO Giuseppe' place=16
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    318,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2025-2026'),
    17,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100.0)
-- Compute scores for PEW8-V2-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2025-2026')
);

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
    'PEW10-V2-M-FOIL-2025-2026',
    'EVF Criterium Mondial Vétérans 2025',
    'PEW',
    'FOIL', 'M', 'V2',
    '2025-07-05', 27, 'https://engarde-service.com/competition/fencingaddict/crit25/fhv2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    140,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW10-V2-M-FOIL-2025-2026'),
    11,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
-- Compute scores for PEW10-V2-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW10-V2-M-FOIL-2025-2026')
);

-- Summary
-- Total results matched:   34
-- Total results unmatched: 98
-- Total auto-created:      0
