-- =========================================================================
-- Season 2025/26 — V2 Male Epee — generated from SZPADA-2-2025-2026.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- ---- PPW1: I Puchar Polski Weteranów — Szpada M (OPOLE) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, txt_location, txt_country, url_invitation, num_entry_fee, url_event)
SELECT
    'PPW1-2025-2026',
    'I Puchar Polski Weteranów',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED',
    '2025-09-28', 'Opole', 'Polska', 'https://spws.fencing.pl/pp1-2025', 80,
    'https://www.fightingtimelive.com/pp1-2025'

WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW1-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW1-2025-2026'),
    'PPW1-V2-M-EPEE-2025-2026',
    'I Puchar Polski Weteranów — Szpada M',
    'PPW',
    'EPEE', 'M', 'V2',
    '2025-09-28', 8, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    275,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2025-2026'),
    1,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    6,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2025-2026'),
    2,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2025-2026'),
    3,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2025-2026'),
    4,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    45,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2025-2026'),
    5,
    'DROBIŃSKI Leszek'
); -- matched: DROBIŃSKI Leszek (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    182,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2025-2026'),
    6,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    259,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2025-2026'),
    7,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    83,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2025-2026'),
    8,
    'HEŁKA Jacek'
); -- matched: HEŁKA Jacek (score=100)
-- Compute scores for PP1-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2025-2026')
);

-- ---- PPW2: II Puchar Polski Weteranów — Szpada M (II Puchar Weteranów Poznań) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, txt_location, txt_country, url_invitation, num_entry_fee, url_event)
SELECT
    'PPW2-2025-2026',
    'II Puchar Polski Weteranów',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED',
    '2025-11-23', 'Warszawa', 'Polska', 'https://spws.fencing.pl/pp2-2025', 80,
    'https://www.fightingtimelive.com/pp2-2025'

WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW2-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW2-2025-2026'),
    'PPW2-V2-M-EPEE-2025-2026',
    'II Puchar Polski Weteranów — Szpada M',
    'PPW',
    'EPEE', 'M', 'V2',
    '2025-10-26', 8, 'https://www.fencingtimelive.com/events/results/0387CC20A25B4EBA9BDAFAB148E8C12B',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2025-2026'),
    1,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    45,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2025-2026'),
    2,
    'DROBIŃSKI Leszek'
); -- matched: DROBIŃSKI Leszek (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    279,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2025-2026'),
    3,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    223,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2025-2026'),
    4,
    'STANIEWICZ Witold'
); -- matched: STANIEWICZ Witold (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    259,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2025-2026'),
    5,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    182,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2025-2026'),
    6,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    83,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2025-2026'),
    7,
    'HEŁKA Jacek'
); -- matched: HEŁKA Jacek (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    248,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2025-2026'),
    8,
    'TOMCZAK Ireneusz'
); -- matched: TOMCZAK Ireneusz (score=100)
-- Compute scores for PP2-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-EPEE-2025-2026')
);

-- ---- PPW3: III Puchar Polski Weteranów — Szpada M (Warsaw Epee Open) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, txt_location, txt_country, url_invitation, num_entry_fee, url_event)
SELECT
    'PPW3-2025-2026',
    'III Puchar Polski Weteranów',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED',
    '2026-02-15', 'Kraków', 'Polska', 'https://spws.fencing.pl/pp3-2026', 90,
    'https://www.fightingtimelive.com/pp3-2026'

WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW3-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW3-2025-2026'),
    'PPW3-V2-M-EPEE-2025-2026',
    'III Puchar Polski Weteranów — Szpada M',
    'PPW',
    'EPEE', 'M', 'V2',
    '2025-12-13', 19, 'https://www.fencingtimelive.com/events/results/2034F718AC554C8D89A639B0EC0984DD',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    6,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    2,
    'JENDRYŚ Marek'
); -- matched: JENDRYŚ Marek (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    3,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
-- UNMATCHED (<80): 'LEAHEY John' place=4
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    275,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    5,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    92,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    6,
    'JASZCZAK Piotr'
); -- matched: JASZCZAK Piotr (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    175,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    7,
    'OLSZEWSKI Mikołaj'
); -- matched: OLSZEWSKI Mikołaj (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    8,
    'PILUTKIEWICZ Igor'
); -- matched: PILUTKIEWICZ Igor (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    45,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    9,
    'DROBIŃSKI Leszek'
); -- matched: DROBIŃSKI Leszek (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    279,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    10,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100)
-- UNMATCHED (<80): 'GERTSMAN Alex' place=11
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    217,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    12,
    'SKOCZEK Artur'
); -- matched: SKOCZEK Artur (score=100)
-- UNMATCHED (<80): 'ODOLAK Jarosław' place=13
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    248,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    14,
    'TOMCZAK Ireneusz'
); -- matched: TOMCZAK Ireneusz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    215,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    15,
    'SERWATKA Marek'
); -- matched: SERWATKA Marek (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    259,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    16,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    182,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026'),
    17,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100)
-- UNMATCHED (<80): 'MCQUEEN Andy' place=18
-- UNMATCHED (<80): 'GOLD Oleg' place=19
-- Compute scores for PP3-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-EPEE-2025-2026')
);

-- ---- PEW1: EVF Grand Prix 1 — Budapeszt (BUDAPEST CUP 2025.09.20) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, txt_location, txt_country, url_invitation, num_entry_fee, url_event)
SELECT
    'PEW1-2025-2026',
    'EVF Grand Prix 1 — Budapeszt',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED',
    '2025-10-12', 'Budapeszt', 'Węgry',
    'https://veteransfencing.eu/gp1-budapest-2025', 50,
    'https://veteransfencing.eu/gp1-budapest-2025/results'

WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW1-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1-2025-2026'),
    'PEW1-V2-M-EPEE-2025-2026',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'EPEE', 'M', 'V2',
    NULL, 57, 'https://www.fencingtimelive.com/events/results/F335344201F74762AED57ADC339F65EF',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    6,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-EPEE-2025-2026'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100)
-- UNMATCHED (<80): 'GOETZ Gregory' place=2
-- UNMATCHED (<80): 'ASHRAFI Ehsan' place=3
-- UNMATCHED (<80): 'PÖNISCH Thomas' place=4
-- UNMATCHED (<80): 'LYONS Michael James' place=5
-- UNMATCHED (<80): 'HIRNER Wolfgang' place=6
-- UNMATCHED (<80): 'SCHATTENFROH Sebastian Dr.' place=7
-- UNMATCHED (<80): 'STRAKA Tomas' place=8
-- UNMATCHED (<80): 'BERGER Matthias' place=9
-- UNMATCHED (<80): 'DEGAUQUE Gilles' place=10
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    220,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-EPEE-2025-2026'),
    11,
    'SOKOL Vratislav'
); -- matched: SOKOL Vratislav (score=100)
-- UNMATCHED (<80): 'HAYEK Günter' place=12
-- UNMATCHED (<80): 'PILHÁL Zsolt' place=13
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-EPEE-2025-2026'),
    14,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
-- UNMATCHED (<80): 'GOETTMANN Jean-Julien' place=15
-- UNMATCHED (<80): 'KÁMÁNY Roland' place=16
-- UNMATCHED (<80): 'KÁLLAI Ákos' place=17
-- UNMATCHED (<80): 'GACSAL Károly' place=18
-- UNMATCHED (<80): 'FEZARD Julien' place=19
-- UNMATCHED (<80): 'KOEMETS Sven' place=20
-- UNMATCHED (<80): 'CICOIRA Mario' place=21
-- UNMATCHED (<80): 'KOUTSOUFLAKIS Stamatios' place=22
-- UNMATCHED (<80): 'RODARY Emmanuel' place=23
-- UNMATCHED (<80): 'KENESEI János' place=24
-- UNMATCHED (<80): 'LEE Ambrose' place=25
-- UNMATCHED (<80): 'GYÖRGY Attila' place=26
-- UNMATCHED (<80): 'ROTA Carlo' place=27
-- UNMATCHED (<80): 'SZAKMÁRY Sándor' place=28
-- UNMATCHED (<80): 'LESNE Ludovic' place=29
-- UNMATCHED (<80): 'DR VITÉZY Péter László' place=30
-- UNMATCHED (<80): 'AUTZEN Olaf' place=31
-- UNMATCHED (<80): 'BERMAN Robert' place=32
-- UNMATCHED (<80): 'MÁTYÁS Pál' place=33
-- UNMATCHED (<80): 'FERKE Norbert' place=34
-- UNMATCHED (<80): 'TULUMELLO Carmelo' place=35
-- UNMATCHED (<80): 'PULEGA Roberto' place=36
-- UNMATCHED (<80): 'DEÁK István' place=37
-- UNMATCHED (<80): 'MAGHON Hans' place=38
-- UNMATCHED (<80): 'VICHI Tommaso' place=39
-- UNMATCHED (<80): 'ÓCSAI János' place=40
-- UNMATCHED (<80): 'ACIKEL Ugur' place=41
-- UNMATCHED (<80): 'FÁBIÁN Gábor' place=42
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    259,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-EPEE-2025-2026'),
    43,
    'WIERZBICKI Jacek'
); -- matched: WIERZBICKI Jacek (score=100)
-- UNMATCHED (<80): 'ERTÜN Müjdat' place=44
-- UNMATCHED (<80): 'BALLA Ádám' place=45
-- UNMATCHED (<80): 'MESTER György' place=46
-- UNMATCHED (<80): 'STUDENY Frantisek' place=47
-- UNMATCHED (<80): 'GERTSMAN Alexandr' place=48
-- UNMATCHED (<80): 'GOLD Oleg' place=49
-- UNMATCHED (<80): 'MÜLLER Ferenc' place=50
-- UNMATCHED (<80): 'SZABÓ Péter' place=51
-- UNMATCHED (<80): 'RUSIN Serghei' place=52
-- UNMATCHED (<80): 'MAGLIOZZI Roberto' place=53
-- UNMATCHED (<80): 'NYÉKI Zsolt' place=54
-- UNMATCHED (<80): 'CSISZÁR Zoltán' place=55
-- UNMATCHED (<80): 'SÓS Csaba' place=56
-- UNMATCHED (<80): 'VARGA Gergely' place=57
-- Compute scores for PEW1-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-EPEE-2025-2026')
);

-- ---- PEW2: EVF Grand Prix 2 — Madryt (MADRID _x000D_) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, txt_location, txt_country, url_invitation, num_entry_fee, url_event)
SELECT
    'PEW2-2025-2026',
    'EVF Grand Prix 2 — Madryt',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED',
    '2025-12-07', 'Madryt', 'Hiszpania',
    'https://veteransfencing.eu/gp2-madrid-2025', 60,
    'https://veteransfencing.eu/gp2-madrid-2025/results'

WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW2-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW2-2025-2026'),
    'PEW2-V2-M-EPEE-2025-2026',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'EPEE', 'M', 'V2',
    '2025-11-02', 33, 'https://www.fencingtimelive.com/events/results/B62D97116A9A459796E0C76A590415A3',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-EPEE-2025-2026'),
    1,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
-- UNMATCHED (<80): 'ASHRAFI' place=2
-- UNMATCHED (<80): 'LAUGA' place=3
-- UNMATCHED (<80): 'LEAHEY' place=4
-- UNMATCHED (<80): 'BERGER' place=5
-- UNMATCHED (<80): 'GARCIA CALDERON' place=6
-- UNMATCHED (<80): 'AUTZEN' place=7
-- UNMATCHED (<80): 'DE BURGH' place=8
-- UNMATCHED (<80): 'GOETTMANN' place=9
-- UNMATCHED (<80): 'PULEGA' place=10
-- UNMATCHED (<80): 'MOYA FERNÁNDEZ' place=11
-- UNMATCHED (<80): 'ALCÁZAR ROLDÁN' place=12
-- UNMATCHED (<80): 'DE BERNARDI' place=13
-- UNMATCHED (<80): 'SWENNING' place=14
-- UNMATCHED (<80): 'ZONNO' place=15
-- UNMATCHED (<80): 'NYÉKI' place=16
-- UNMATCHED (<80): 'JANET' place=17
-- UNMATCHED (<80): 'GARCIA FERNANDEZ' place=18
-- UNMATCHED (<80): 'ERTÜN' place=19
-- UNMATCHED (<80): 'AÇIKEL' place=20
-- UNMATCHED (<80): 'GÓMEZ PAZ' place=21
-- UNMATCHED (<80): 'POMELL' place=22
-- UNMATCHED (<80): 'FERNANDEZ RAMOS' place=23
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    182,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-EPEE-2025-2026'),
    24,
    'PARDUS Borys'
); -- matched: PARDUS Borys (score=100)
-- UNMATCHED (<80): 'VARGA' place=25
-- UNMATCHED (<80): 'KAMANY' place=26
-- UNMATCHED (<80): 'DOMINGUEZ' place=27
-- UNMATCHED (<80): 'BERNEIS' place=28
-- UNMATCHED (<80): 'GONZÁLEZ DÍAZ' place=29
-- UNMATCHED (<80): 'RODRÍGUEZ' place=30
-- UNMATCHED (<80): 'MCQUEEN' place=31
-- UNMATCHED (<80): 'GALÁN ROCILLO' place=32
-- UNMATCHED (<80): 'SALCEDO PLAZA' place=33
-- Compute scores for PEW2-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-EPEE-2025-2026')
);

-- ---- IMSW: Indywidualne Mistrzostwa Świata Weteranów (2025 Veteran World Championships) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, txt_location, txt_country, url_invitation, num_entry_fee, url_event)
SELECT
    'IMSW-2025-2026',
    'Indywidualne Mistrzostwa Świata Weteranów',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED',
    '2026-04-18', 'Dubaj', 'Zjednoczone Emiraty Arabskie',
    'https://veteransfencing.eu/wch-dubai-2026', 100,
    'https://veteransfencing.eu/wch-dubai-2026/results'

WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'IMSW-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'IMSW-2025-2026'),
    'IMSW-V2-M-EPEE-2025-2026',
    'Indywidualne Mistrzostwa Świata Weteranów',
    'MSW',
    'EPEE', 'M', 'V2',
    '2025-11-13', 76, 'https://www.fencingtimelive.com/events/results/12C3BCD029104BA19426095D43A2233C',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    6,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMSW-V2-M-EPEE-2025-2026'),
    1,
    'ATANASSOW Aleksander'
); -- matched: ATANASSOW Aleksander (score=100)
-- UNMATCHED (<80): 'COVANI Carlos Enrique' place=2
-- UNMATCHED (<80): 'TRUETZSCHLER Alexander' place=3
-- UNMATCHED (<80): 'TEPEDELENLIOGLU Mehmet' place=4
-- UNMATCHED (<80): 'FEZARD Julien' place=5
-- UNMATCHED (<80): 'SCHATTENFROH Sebastian' place=6
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    275,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMSW-V2-M-EPEE-2025-2026'),
    7,
    'ZIELIŃSKI Dariusz'
); -- matched: ZIELIŃSKI Dariusz (score=100)
-- UNMATCHED (<80): 'MARCHET Alexander' place=8
-- UNMATCHED (<80): 'ELLISON Alexander' place=9
-- UNMATCHED (<80): 'VINCENZI Gabriele' place=10
-- UNMATCHED (<80): 'DIMOV Dmitriy' place=11
-- UNMATCHED (<80): 'PRIHODKO Andrew' place=12
-- UNMATCHED (<80): 'WACQUEZ Francois' place=13
-- UNMATCHED (<80): 'KATASHIMA Akinori' place=14
-- UNMATCHED (<80): 'STRAKA Tomas' place=15
-- UNMATCHED (<80): 'ARKHIPOV Alexey' place=16
-- UNMATCHED (<80): 'LICHTEN Keith H.' place=17
-- UNMATCHED (<80): 'OHANESSIAN Sarkis' place=18
-- UNMATCHED (<80): 'SALAMANDRA Lev' place=19
-- UNMATCHED (<80): 'FERGUSON Darren' place=20
-- UNMATCHED (<80): 'LESNE Ludovic' place=21
-- UNMATCHED (<80): 'HESS Alexander' place=22
-- UNMATCHED (<80): 'ROTA Carlo' place=23
-- UNMATCHED (<80): 'ALITISZ Valentin Andres' place=24
-- UNMATCHED (<80): 'GRAVES-SMITH Geoff' place=25
-- UNMATCHED (<80): 'PIRANI Claudio' place=26
-- UNMATCHED (<80): 'AL-SUBAYEE WALEED' place=27
-- UNMATCHED (<80): 'CRANOR Erich L.' place=28
-- UNMATCHED (<80): 'LE DEVEHAT Yannick' place=29
-- UNMATCHED (<80): 'RIASKIN Andrei' place=30
-- UNMATCHED (<80): 'MIKHEIKIN Aleksei' place=31
-- UNMATCHED (<80): 'KUWAHATA Takashi' place=32
-- UNMATCHED (<80): 'ALLEN Gregory' place=33
-- UNMATCHED (<80): 'LAUGA Eric' place=34
-- UNMATCHED (<80): 'COLLING Emile' place=35
-- UNMATCHED (<80): 'DOI TAKEO' place=36
-- UNMATCHED (<80): 'GOETTMANN Jean-Julien' place=37
-- UNMATCHED (<80): 'TANTIPIRIYAPONGS Nipon' place=38
-- UNMATCHED (<80): 'SZAKMARY Sandor' place=39
-- UNMATCHED (<80): 'SALAMANDRA Paolo' place=40
-- UNMATCHED (<80): 'PENKIN Andrey' place=41
-- UNMATCHED (<80): 'LYONS Michael James' place=42
-- UNMATCHED (<80): 'VITEZY Peter Laszlo' place=43
-- UNMATCHED (<80): 'NOMURA Masahito' place=44
-- UNMATCHED (<80): 'GATES Darcy' place=45
-- UNMATCHED (<80): 'KHRIAKOV Dmitrii' place=46
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    279,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMSW-V2-M-EPEE-2025-2026'),
    47,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100)
-- UNMATCHED (<80): 'MACDONALD Leslie' place=48
-- UNMATCHED (<80): 'FENG Qiong' place=49
-- UNMATCHED (<80): 'GRABHER Gernot' place=50
-- UNMATCHED (<80): 'BERNERON Guillaume' place=51
-- UNMATCHED (<80): 'BATTAGGI Augusto' place=52
-- UNMATCHED (<80): 'SAKHRANI Naresh' place=53
-- UNMATCHED (<80): 'ABASSI Wajdi' place=54
-- UNMATCHED (<80): 'POUTSENKO Serguei' place=55
-- UNMATCHED (<80): 'KHALID ABDULRAHMAN' place=56
-- UNMATCHED (<80): 'LAHTI Taneli' place=57
-- UNMATCHED (<80): 'SANTOS Felipe' place=58
-- UNMATCHED (<80): 'WU Bing Chi Patrick' place=59
-- UNMATCHED (<80): 'KAMANY Roland' place=60
-- UNMATCHED (<80): 'ALATAWI KHALIFA' place=61
-- UNMATCHED (<80): 'PALTINISEANU Sorin' place=62
-- UNMATCHED (<80): 'TSANG Hin Kwong' place=63
-- UNMATCHED (<80): 'CHAN Wai Ching Jason' place=64
-- UNMATCHED (<80): 'MACKLEY Jay' place=65
-- UNMATCHED (<80): 'ALSABBAN Ahmed' place=66
-- UNMATCHED (<80): 'STUDENY Frantisek' place=67
-- UNMATCHED (<80): 'ALMUTAIR Tariq' place=68
-- UNMATCHED (<80): 'PATEL Manish' place=69
-- UNMATCHED (<80): 'HOYER Martin' place=70
-- UNMATCHED (<80): 'ALI SALMAN' place=71
-- UNMATCHED (<80): 'ASAAD Abdulkareem' place=72
-- UNMATCHED (<80): 'ABED Hazem' place=73
-- UNMATCHED (<80): 'ESPARZA Mario' place=74
-- UNMATCHED (<80): 'MOHAMMEDAWI MOHAMMED' place=75
-- UNMATCHED (<80): 'AL-DARRAJI RAHEEM' place=76
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMSW-V2-M-EPEE-2025-2026'),
    79,
    'KORONA Przemysław'
); -- matched: KORONA Przemysław (score=100)
-- Compute scores for IMSW-V2-M-EPEE-2025-2026
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMSW-V2-M-EPEE-2025-2026')
);


-- ---- PPW4: IV Puchar Polski Weteranów (Gdańsk, 2026-02-21) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, txt_location, txt_country)
SELECT
    'PPW4-2025-2026',
    'IV Puchar Polski Weteranów',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED',
    '2026-02-21', 'Gdańsk', 'Polska'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW4-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW4-2025-2026'),
    'PPW4-V2-M-EPEE-2025-2026',
    'IV Puchar Polski Weteranów — Szpada M',
    'PPW',
    'EPEE', 'M', 'V2',
    '2026-02-21', 11, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    116,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2025-2026'),
    1,
    'KORONA Przemysław'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    6,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2025-2026'),
    2,
    'ATANASSOW Aleksander'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    93,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2025-2026'),
    3,
    'JENDRYŚ Marek'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    46,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2025-2026'),
    4,
    'DUDEK Mariusz'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    257,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2025-2026'),
    5,
    'WASIOŁKA Sebastian'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    45,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2025-2026'),
    6,
    'DROBIŃSKI Leszek'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    82,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2025-2026'),
    7,
    'HAŚKO Sergiusz'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    259,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2025-2026'),
    8,
    'WIERZBICKI Jacek'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    248,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2025-2026'),
    9,
    'TOMCZAK Ireneusz'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2025-2026'),
    10,
    'PILUTKIEWICZ Igor'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    83,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2025-2026'),
    11,
    'HEŁKA Jacek'
);
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2025-2026')
);

-- ---- PPW5: V Puchar Polski Weteranów (SCHEDULED — declared counterpart for rolling) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, txt_location, txt_country)
SELECT
    'PPW5-2025-2026',
    'V Puchar Polski Weteranów',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'SCHEDULED',
    '2026-05-10', 'Warszawa', 'Polska'

WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW5-2025-2026');

-- ---- MPW: Mistrzostwa Polski Weteranów (SCHEDULED — declared counterpart for rolling) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, txt_location, txt_country)
SELECT
    'MPW-2025-2026',
    'Mistrzostwa Polski Weteranów',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'SCHEDULED',
    '2026-06-07', 'Pabianice', 'Polska'

WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'MPW-2025-2026');

-- ---- IMEW: Indywidualne Mistrzostwa Europy Weteranów (SCHEDULED — declared counterpart for rolling) ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, txt_location, txt_country)
SELECT
    'IMEW-2025-2026',
    'Indywidualne Mistrzostwa Europy Weteranów',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'SCHEDULED',
    '2026-07-15', 'Budapeszt', 'Węgry'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'IMEW-2025-2026');

-- Backfill txt_location for 2025/26 events
UPDATE tbl_event SET txt_location = 'Opole'     WHERE txt_code = 'PPW1-2025-2026';
UPDATE tbl_event SET txt_location = 'Poznań'    WHERE txt_code = 'PPW2-2025-2026';
UPDATE tbl_event SET txt_location = 'Warszawa'  WHERE txt_code = 'PPW3-2025-2026';
UPDATE tbl_event SET txt_location = 'Budapeszt'      WHERE txt_code = 'PEW1-2025-2026';
UPDATE tbl_event SET txt_location = 'Madryt'         WHERE txt_code = 'PEW2-2025-2026';
UPDATE tbl_event SET txt_location = 'Manama, Bahrain' WHERE txt_code = 'IMSW-2025-2026';

-- Summary
-- Domestic:      PP1, PP2, PP3 (COMPLETED) + PP4, PP5, MPW (SCHEDULED — rolling counterparts)
-- International: PEW1, PEW2, IMSW (COMPLETED) + IMEW (SCHEDULED — rolling counterpart)
-- PP4+PP5+MPW+IMEW declared for M10 rolling score: carry-over from 2024-25 until completed
