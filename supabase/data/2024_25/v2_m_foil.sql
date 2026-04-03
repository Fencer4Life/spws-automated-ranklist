-- =========================================================================
-- Season 2024-2025 — V2 M FOIL — generated from FLORET-2-2024-2025.xlsx
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- One file per age category per season; see supabase/data/{season}/{cat}.sql
-- =========================================================================

-- ---- PP1: I Puchar Polski Weteranów (KONIN) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW1-2024-2025',
    'I Puchar Polski Weteranów',
    'KONIN',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW1-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW1-2024-2025'),
    'PPW1-V2-M-FOIL-2024-2025',
    'I Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V2',
    '2024-09-29', 6, 'https://www.fencingtimelive.com/events/results/086C52C38C084D51BD2EADD1D74DE524',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-FOIL-2024-2025'),
    1,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    11,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-FOIL-2024-2025'),
    2,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    225,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-FOIL-2024-2025'),
    3,
    'SZMIDT Grzegorz'
); -- matched: SZMIDT Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-FOIL-2024-2025'),
    4,
    'POŚPIESZNY Sławomir'
); -- matched: POŚPIESZNY Sławomir (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    86,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-FOIL-2024-2025'),
    5,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    269,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-FOIL-2024-2025'),
    6,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100.0)
-- Compute scores for PP1-V2-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-FOIL-2024-2025')
);

-- ---- PP2: II Puchar Polski Weteranów (BYTOM) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW2-2024-2025',
    'II Puchar Polski Weteranów',
    'BYTOM',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW2-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW2-2024-2025'),
    'PPW2-V2-M-FOIL-2024-2025',
    'II Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V2',
    '2024-10-27', 7, 'https://www.fencingtimelive.com/events/results/BB46C864D2EE498A96C27152A07AE1AE',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-FOIL-2024-2025'),
    1,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    86,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-FOIL-2024-2025'),
    2,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    11,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-FOIL-2024-2025'),
    3,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    225,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-FOIL-2024-2025'),
    4,
    'SZMIDT Grzegorz'
); -- matched: SZMIDT Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    187,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-FOIL-2024-2025'),
    5,
    'POŚPIESZNY Sławomir'
); -- matched: POŚPIESZNY Sławomir (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    83,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-FOIL-2024-2025'),
    6,
    'GWIAZDA Paweł'
); -- matched: GWIAZDA Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    269,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-FOIL-2024-2025'),
    7,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100.0)
-- Compute scores for PP2-V2-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-FOIL-2024-2025')
);

-- ---- PP3: III Puchar Polski Weteranów (KRAKÓW) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW3-2024-2025',
    'III Puchar Polski Weteranów',
    'KRAKÓW',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW3-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW3-2024-2025'),
    'PPW3-V2-M-FOIL-2024-2025',
    'III Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V2',
    '2024-12-01', 5, 'https://www.fencingtimelive.com/events/results/9FCFAE68C86A425185E62AD8B40DE2D1',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-FOIL-2024-2025'),
    1,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    225,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-FOIL-2024-2025'),
    2,
    'SZMIDT Grzegorz'
); -- matched: SZMIDT Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    86,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-FOIL-2024-2025'),
    3,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    11,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-FOIL-2024-2025'),
    4,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    269,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-FOIL-2024-2025'),
    5,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100.0)
-- Compute scores for PP3-V2-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-FOIL-2024-2025')
);

-- ---- MPW: Mistrzostwa Polski Weteranów (PABIANICE) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'MPW-2024-2025',
    'Mistrzostwa Polski Weteranów',
    'PABIANICE',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'MPW-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'MPW-2024-2025'),
    'MPW-V2-M-FOIL-2024-2025',
    'Mistrzostwa Polski Weteranów',
    'MPW',
    'FOIL', 'M', 'V2',
    '2025-06-08', 5, 'https://www.fencingtimelive.com/tournaments/eventSchedule/B2C615704AB84D0F85BBFF395C07BA41',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-FOIL-2024-2025'),
    1,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    225,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-FOIL-2024-2025'),
    2,
    'SZMIDT Grzegorz'
); -- matched: SZMIDT Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    11,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-FOIL-2024-2025'),
    3,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    269,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-FOIL-2024-2025'),
    4,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100.0)
-- UNMATCHED (score<80): 'BOCHEŃSKI JACEK' place=5
-- Compute scores for MPW-V2-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-FOIL-2024-2025')
);

-- ---- PEW1: EVF Grand Prix 1 — Budapeszt (Budapest) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW1-2024-2025',
    'EVF Grand Prix 1 — Budapeszt',
    'Budapest',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW1-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1-2024-2025'),
    'PEW1-V2-M-FOIL-2024-2025',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'FOIL', 'M', 'V2',
    '2024-09-22', 21, 'https://engarde-service.com/app.php?id=4209S2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-FOIL-2024-2025'),
    2,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    11,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-FOIL-2024-2025'),
    9,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
-- Compute scores for PEW1-V2-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-FOIL-2024-2025')
);

-- ---- PEW2: EVF Grand Prix 2 — Madryt (Madrid) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW2-2024-2025',
    'EVF Grand Prix 2 — Madryt',
    'Madrid',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW2-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW2-2024-2025'),
    'PEW2-V2-M-FOIL-2024-2025',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'FOIL', 'M', 'V2',
    '2024-11-17', 22, 'https://engarde-service.com/competition/aeve_esgrima/evf_madrid_2024/fm-2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-FOIL-2024-2025'),
    5,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    11,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-FOIL-2024-2025'),
    19,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
-- Compute scores for PEW2-V2-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-FOIL-2024-2025')
);

-- ---- PEW7: EVF Grand Prix 7 — Terni (Stockholm) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW7-2024-2025',
    'EVF Grand Prix 7 — Terni',
    'Stockholm',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW7-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW7-2024-2025'),
    'PEW7-V2-M-FOIL-2024-2025',
    'EVF Grand Prix 7 — Terni',
    'PEW',
    'FOIL', 'M', 'V2',
    '2025-05-15', 7, 'https://fencing.ophardt.online/en/search/results/30279',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    11,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-FOIL-2024-2025'),
    1,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
-- Compute scores for PEW7-V2-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-FOIL-2024-2025')
);

-- ---- PEW8: EVF Grand Prix 8 — Guildford (WARSZAWA) ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW8-2024-2025',
    'EVF Grand Prix 8 — Guildford',
    'WARSZAWA',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW8-2024-2025');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW8-2024-2025'),
    'PEW8-V2-M-FOIL-2024-2025',
    'EVF Grand Prix 8 — Guildford',
    'PEW',
    'FOIL', 'M', 'V2',
    '2025-03-30', 15, 'https://www.fencingtimelive.com/events/results/1EA8595859334E548870539DB91198E2',
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    233,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2024-2025'),
    1,
    'TK'
); -- matched: KOŃCZYŁO Tomasz (score=100)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    11,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2024-2025'),
    3,
    'BAZAK Jacek'
); -- matched: BAZAK Jacek (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    225,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2024-2025'),
    7,
    'SZMIDT Grzegorz'
); -- matched: SZMIDT Grzegorz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    86,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2024-2025'),
    10,
    'HAŚKO Sergiusz'
); -- matched: HAŚKO Sergiusz (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    83,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2024-2025'),
    11,
    'GWIAZDA Paweł'
); -- matched: GWIAZDA Paweł (score=100.0)
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (
    269,
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2024-2025'),
    12,
    'ŻUKOWSKI Wojciech'
); -- matched: ŻUKOWSKI Wojciech (score=100.0)
-- Compute scores for PEW8-V2-M-FOIL-2024-2025
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2024-2025')
);

-- SKIP IMEW (Indywidualne Mistrzostwa Europy Weteranów): N=0 — tournament had no participants

-- Summary
-- Total results matched:   33
-- Total results unmatched: 1
