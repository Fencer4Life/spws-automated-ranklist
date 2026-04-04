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
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-FOIL-2025-2026'),
    1,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    215,
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
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-FOIL-2025-2026'),
    1,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    82,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-FOIL-2025-2026'),
    2,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
-- Compute scores for PPW4-V2-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-FOIL-2025-2026')
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
    'PEW1-V2-M-FOIL-2025-2026',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'FOIL', 'M', 'V2',
    NULL, 25, NULL,
    'SCORED'
);
-- UNMATCHED (score<80): 'PULEGA Roberto' place=1
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-FOIL-2025-2026'),
    2,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
-- UNMATCHED (score<80): 'PESCE Filippo' place=3
-- UNMATCHED (score<80): 'MÁLICS Róbert' place=4
-- UNMATCHED (score<80): 'KOZAKIVSKYI Vasyl' place=5
-- UNMATCHED (score<80): 'LEZHAVA Nikoloz' place=6
-- UNMATCHED (score<80): 'SEGURA CHECA Enrique' place=7
-- UNMATCHED (score<80): 'FARKAS Attila' place=8
-- UNMATCHED (score<80): 'GERZANICS Márk' place=9
-- UNMATCHED (score<80): 'BAIR Stephan' place=10
-- UNMATCHED (score<80): 'SÁGHY Ervin' place=11
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    220,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-FOIL-2025-2026'),
    12,
    'SOKOL Vratislav'
); -- matched: SOKOL Vratislav (score=100.0)
-- UNMATCHED (score<80): 'SZABÓ András' place=13
-- UNMATCHED (score<80): 'KRISTÓF Márton' place=14
-- UNMATCHED (score<80): 'GMEREK Marcel' place=15
-- UNMATCHED (score<80): 'HIRNER Wolfgang' place=16
-- UNMATCHED (score<80): 'HEGEDŰS Sándor' place=17
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    113,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-FOIL-2025-2026'),
    18,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
-- UNMATCHED (score<80): 'MÜLLER Ferenc' place=19
-- UNMATCHED (score<80): 'PATAKI Zoltán' place=20
-- UNMATCHED (score<80): 'VILA Paulo' place=21
-- UNMATCHED (score<80): 'BRUNNER Konstantin' place=22
-- UNMATCHED (score<80): 'DR CSIGÓ Csaba' place=23
-- UNMATCHED (score<80): 'NOVELLINO Giuseppe' place=24
-- UNMATCHED (score<80): 'FÁBIÁN Gábor' place=25
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
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-FOIL-2025-2026'),
    8,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
-- UNMATCHED (score<80): 'CHEN' place=25
-- UNMATCHED (score<80): 'SEGURA CHECA' place=26
-- UNMATCHED (score<80): 'ALVEAR' place=27
-- UNMATCHED (score<80): 'ALCSER' place=28
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
-- UNMATCHED (score<80): 'PAYNE 2 Nick' place=1
-- UNMATCHED (score<80): 'MCKAY 2 Mike' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    113,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-FOIL-2025-2026'),
    3,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
-- UNMATCHED (score<80): 'BARNES-WEBB 2 Richard' place=4
-- UNMATCHED (score<80): 'CHO 2 Michael' place=5
-- UNMATCHED (score<80): 'RIFFATERRE 2 Jason' place=6
-- UNMATCHED (score<80): 'ENRIQUEZ SILVEIRA 2 Lazaro Vladimir' place=7
-- UNMATCHED (score<80): 'GRIFFIN 2 Adrian' place=8
-- UNMATCHED (score<80): 'PULEGA 2 Roberto' place=9
-- UNMATCHED (score<80): 'MORT 2 Nick' place=10
-- UNMATCHED (score<80): 'THOMAS 2 Michael' place=11
-- UNMATCHED (score<80): 'ELLISON 2 Alexander' place=12
-- UNMATCHED (score<80): 'GMEREK 2 Marcel' place=13
-- UNMATCHED (score<80): 'RHODES 2 Giles' place=14
-- UNMATCHED (score<80): 'KINGSTON 2 Matthew' place=15
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-FOIL-2025-2026'),
    16,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
-- UNMATCHED (score<80): 'NGUYEN 2 Thomas' place=17
-- UNMATCHED (score<80): 'SUNG 2 Velota' place=18
-- UNMATCHED (score<80): 'BLAKE 2 Daniel' place=19
-- UNMATCHED (score<80): 'RYSDALE 2 Edward' place=20
-- UNMATCHED (score<80): 'THOMAS 2 Richard' place=21
-- UNMATCHED (score<80): 'JENNINGS 2 Sean' place=22
-- UNMATCHED (score<80): 'WEBB 2 Andrew' place=23
-- UNMATCHED (score<80): 'MCWILLIAMS 2 Keith' place=24
-- UNMATCHED (score<80): 'SHING MAN 2 Tam' place=25
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    5,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-FOIL-2025-2026'),
    26,
    'ANDERSON 2 Robert'
); -- matched: ANDERSCH Robert (score=81.25)
-- UNMATCHED (score<80): 'STANBRIDGE 2 Paul' place=27
-- UNMATCHED (score<80): 'VICTORY 2 David' place=28
-- UNMATCHED (score<80): 'VILA 2 Paulo' place=29
-- UNMATCHED (score<80): 'BRITTAIN 2 Brian' place=30
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
-- UNMATCHED (score<80): 'WYSZYNSKI MAREK' place=1
-- UNMATCHED (score<80): 'DI RUSSO FABIO' place=2
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-FOIL-2025-2026'),
    3,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
-- UNMATCHED (score<80): 'PESCE FILIPPO' place=4
-- UNMATCHED (score<80): 'PERSICHETTI LORENZO' place=5
-- UNMATCHED (score<80): 'RICHIARDI LORENZO' place=6
-- UNMATCHED (score<80): 'PULEGA ROBERTO ANDREA' place=7
-- UNMATCHED (score<80): 'BECHER KARL' place=8
-- UNMATCHED (score<80): 'ZEIN ELABEDIN TAMER' place=9
-- UNMATCHED (score<80): 'CAGGIANI FILIPPO' place=10
-- UNMATCHED (score<80): 'HEGEDUS SANDOR' place=11
-- UNMATCHED (score<80): 'GRAVES SMITH GEOFFREY' place=12
-- UNMATCHED (score<80): 'BAZAK JACEK TOMASZ' place=13
-- UNMATCHED (score<80): 'LARATO FABRIZIO NICOLA' place=14
-- UNMATCHED (score<80): 'CICOIRA MARIO' place=15
-- UNMATCHED (score<80): 'RONDINA FRANCESCO' place=16
-- UNMATCHED (score<80): 'ORAZI ANDREA' place=17
-- UNMATCHED (score<80): 'LUCREZI GINO' place=18
-- UNMATCHED (score<80): 'VIRGILI FLAVIO' place=19
-- UNMATCHED (score<80): 'FURCHI'' ROBERTO' place=20
-- UNMATCHED (score<80): 'MULLER FERENC' place=21
-- UNMATCHED (score<80): 'VARGA GERGELY' place=22
-- UNMATCHED (score<80): 'BRUSCHI DAVIDE' place=23
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
-- UNMATCHED (score<80): 'SZABO Andras Laszlo' place=1
-- UNMATCHED (score<80): 'SIPOS Szilard' place=2
-- UNMATCHED (score<80): 'GRIFFIN Adrian' place=3
-- UNMATCHED (score<80): 'GRAVES SMITH Geoffrey' place=4
-- UNMATCHED (score<80): 'PULEGA Roberto Andrea Enzo' place=5
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    12,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-FOIL-2025-2026'),
    6,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
-- UNMATCHED (score<80): 'KREIS Sebastian' place=7
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-FOIL-2025-2026'),
    8,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
-- UNMATCHED (score<80): 'VICTORY David' place=9
-- UNMATCHED (score<80): '.' place=10
-- UNMATCHED (score<80): '.' place=11
-- UNMATCHED (score<80): '.' place=12
-- UNMATCHED (score<80): '.' place=13
-- UNMATCHED (score<80): '.' place=14
-- UNMATCHED (score<80): '.' place=15
-- UNMATCHED (score<80): '.' place=16
-- UNMATCHED (score<80): '.' place=17
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
-- UNMATCHED (score<80): 'ZEIN ELABEDIN Tamer' place=1
-- UNMATCHED (score<80): 'RICHIARDI Lorenzo' place=2
-- UNMATCHED (score<80): 'HEGEDUS Sandor' place=3
-- UNMATCHED (score<80): 'KOZAKIVSKYI Vasyl' place=4
-- UNMATCHED (score<80): 'SZABO Andras' place=5
-- UNMATCHED (score<80): 'PULEGA Roberto' place=6
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    82,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2025-2026'),
    7,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
-- UNMATCHED (score<80): 'ZHAO Zhiyong' place=8
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    12,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2025-2026'),
    9,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    113,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2025-2026'),
    10,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
-- UNMATCHED (score<80): 'RUSTAMZADE Rufat' place=11
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2025-2026'),
    12,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    220,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2025-2026'),
    13,
    'SOKOL Vratislav'
); -- matched: SOKOL Vratislav (score=100.0)
-- UNMATCHED (score<80): 'GRAVES SMITH Geoffrey' place=14
-- UNMATCHED (score<80): 'MALICS Robert' place=15
-- UNMATCHED (score<80): 'NOVELLINO Giuseppe' place=16
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    279,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2025-2026'),
    17,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100.0)
-- Compute scores for PEW8-V2-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2025-2026')
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
    'PS-V2-M-FOIL-2025-2026',
    'Puchar Świata',
    'PSW',
    'FOIL', 'M', 'V2',
    '2025-07-05', 27, 'https://engarde-service.com/competition/fencingaddict/crit25/fhv2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    113,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PS-V2-M-FOIL-2025-2026'),
    11,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
-- Compute scores for PS-V2-M-FOIL-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PS-V2-M-FOIL-2025-2026')
);

-- SKIP IMEW (Indywidualne Mistrzostwa Europy Weteranów): N=0 — tournament had no participants

-- Summary
-- Total results matched:   31
-- Total results unmatched: 101
