-- =========================================================================
-- Season 2025-2026 — V1 M EPEE — auto-exported from CERT (ADR-027)
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- =========================================================================

-- ---- PEW10-2025-2026: EVF Criterium Mondial Vétérans 2025 ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW10-2025-2026',
    'EVF Criterium Mondial Vétérans 2025',
    'Paris',
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
    'PEW10-V1-M-EPEE-2025-2026',
    'EVF Criterium Mondial Vétérans 2025',
    'PEW',
    'EPEE', 'M', 'V1',
    '2025-07-05', 31, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KORONA' AND txt_first_name = 'Przemysław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW10-V1-M-EPEE-2025-2026'),
    8, 40.33
); -- KORONA Przemysław

-- ---- PEW1-2025-2026: EVF Circuit Budapest ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW1-2025-2026',
    'EVF Circuit Budapest',
    'Budapest',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW1-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1-2025-2026'),
    'PEW1-V1-M-EPEE-2025-2026',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'EPEE', 'M', 'V1',
    NULL, 33, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'BOBUSIA' AND txt_first_name = 'Jarosław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-M-EPEE-2025-2026'),
    5, 57.45
); -- BOBUSIA Jarosław
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KULKA' AND txt_first_name = 'Dawid' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-M-EPEE-2025-2026'),
    6, 54.89
); -- KULKA Dawid

-- ---- PPW1-2025-2026: I Puchar Polski Weteranów ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW1-2025-2026',
    'I Puchar Polski Weteranów',
    'Opole',
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
    'PPW1-V1-M-EPEE-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V1',
    NULL, 9, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SĘKOWSKI' AND txt_first_name = 'Maciej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2025-2026'),
    1, 108.72
); -- SĘKOWSKI Maciej
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'BOBUSIA' AND txt_first_name = 'Jarosław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2025-2026'),
    2, 77.02
); -- BOBUSIA Jarosław
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'TATCHYN' AND txt_first_name = 'Andriy' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2025-2026'),
    3, 51.74
); -- TATCHYN Andriy
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'STOCKI' AND txt_first_name = 'Piotr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2025-2026'),
    4, 39.08
); -- STOCKI Piotr
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KORNAŚ' AND txt_first_name = 'Jarosław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2025-2026'),
    5, 24.11
); -- KORNAŚ Jarosław
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DOBRZAŃSKI' AND txt_first_name = 'Maciej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2025-2026'),
    6, 20.04
); -- DOBRZAŃSKI Maciej
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GROMADA' AND txt_first_name = 'Roland' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2025-2026'),
    7, 16.60
); -- GROMADA Roland
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'BOROWIEC' AND txt_first_name = 'Maciej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2025-2026'),
    8, 13.63
); -- BOROWIEC Maciej
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'POKRYWA' AND txt_first_name = 'Bartosz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-EPEE-2025-2026'),
    9, 1.00
); -- POKRYWA Bartosz

-- ---- PPW2-2025-2026: II Puchar Polski Weteranów ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW2-2025-2026',
    'II Puchar Polski Weteranów',
    'Poznań',
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
    'PPW2-V1-M-EPEE-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V1',
    NULL, 6, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SĘKOWSKI' AND txt_first_name = 'Maciej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2025-2026'),
    1, 96.35
); -- SĘKOWSKI Maciej
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KULKA' AND txt_first_name = 'Dawid' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2025-2026'),
    2, 61.95
); -- KULKA Dawid
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GROMADA' AND txt_first_name = 'Roland' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2025-2026'),
    3, 35.41
); -- GROMADA Roland
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'STOCKI' AND txt_first_name = 'Piotr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2025-2026'),
    4, 22.09
); -- STOCKI Piotr
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'POKRYWA' AND txt_first_name = 'Bartosz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2025-2026'),
    5, 5.99
); -- POKRYWA Bartosz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'PAWŁOWSKI' AND txt_first_name = 'Łukasz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-EPEE-2025-2026'),
    6, 1.00
); -- PAWŁOWSKI Łukasz

-- ---- PEW2-2025-2026: EVF Circuit Madrid ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW2-2025-2026',
    'EVF Circuit Madrid',
    'Madrid',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW2-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW2-2025-2026'),
    'PEW2-V1-M-EPEE-2025-2026',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'EPEE', 'M', 'V1',
    NULL, 27, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'STOCKI' AND txt_first_name = 'Piotr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-M-EPEE-2025-2026'),
    7, 41.07
); -- STOCKI Piotr
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KULKA' AND txt_first_name = 'Dawid' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-M-EPEE-2025-2026'),
    11, 24.35
); -- KULKA Dawid
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'STOLARIK' AND txt_first_name = 'Peter' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-M-EPEE-2025-2026'),
    19, 6.22
); -- STOLARIK Peter

-- ---- PPW3-2025-2026: III Puchar Polski Weteranów / Warsaw Epee Open ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW3-2025-2026',
    'III Puchar Polski Weteranów / Warsaw Epee Open',
    'Warszawa-Łomianki',
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
    'PPW3-V1-M-EPEE-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V1',
    NULL, 11, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KORONA' AND txt_first_name = 'Radosław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    1, 110.02
); -- KORONA Radosław
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SĘKOWSKI' AND txt_first_name = 'Maciej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    2, 79.18
); -- SĘKOWSKI Maciej
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOWALCZYK' AND txt_first_name = 'Piotr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    3, 54.22
); -- KOWALCZYK Piotr
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'STOCKI' AND txt_first_name = 'Piotr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    4, 41.67
); -- STOCKI Piotr
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DOBRZAŃSKI' AND txt_first_name = 'Maciej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    5, 27.11
); -- DOBRZAŃSKI Maciej
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KRAMARZ' AND txt_first_name = 'Konrad' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    6, 23.39
); -- KRAMARZ Konrad
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'TATCHYN' AND txt_first_name = 'Andriy' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    7, 20.24
); -- TATCHYN Andriy
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KLEPACKI' AND txt_first_name = 'Denis' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    8, 17.51
); -- KLEPACKI Denis
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'POKRYWA' AND txt_first_name = 'Bartosz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    9, 5.10
); -- POKRYWA Bartosz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'PAWŁOWSKI' AND txt_first_name = 'Łukasz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    10, 2.95
); -- PAWŁOWSKI Łukasz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CHUDY' AND txt_first_name = 'Tomasz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-EPEE-2025-2026'),
    11, 1.00
); -- CHUDY Tomasz

-- ---- PEW3-2025-2026: EVF Circuit Guildford ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW3-2025-2026',
    'EVF Circuit Guildford',
    'Guildford',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW3-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW3-2025-2026'),
    'PEW3-V1-M-EPEE-2025-2026',
    'EVF Grand Prix 3',
    'PEW',
    'EPEE', 'M', 'V1',
    NULL, 34, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'STOCKI' AND txt_first_name = 'Piotr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2025-2026'),
    17, 20.63
); -- STOCKI Piotr
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ALCSER' AND txt_first_name = 'Norbert' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2025-2026'),
    21, 17.70
); -- ALCSER Norbert
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KULKA' AND txt_first_name = 'Dawid' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-M-EPEE-2025-2026'),
    22, 17.05
); -- KULKA Dawid

-- ---- PPW4-2025-2026: IV Puchar Polski Weteranów ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PPW4-2025-2026',
    'IV Puchar Polski Weteranów',
    'Gdańsk',
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
    'PPW4-V1-M-EPEE-2025-2026',
    'V1 M EPEE',
    'PPW',
    'EPEE', 'M', 'V1',
    '2026-02-21', 7, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SĘKOWSKI' AND txt_first_name = 'Maciej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2025-2026'),
    1, 97.22
); -- SĘKOWSKI Maciej
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DOBRZAŃSKI' AND txt_first_name = 'Maciej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2025-2026'),
    2, 64.02
); -- DOBRZAŃSKI Maciej
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'STOCKI' AND txt_first_name = 'Piotr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2025-2026'),
    3, 38.07
); -- STOCKI Piotr
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'TATCHYN' AND txt_first_name = 'Andriy' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2025-2026'),
    4, 25.09
); -- TATCHYN Andriy
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CHUDY' AND txt_first_name = 'Tomasz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2025-2026'),
    5, 9.47
); -- CHUDY Tomasz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'STAŃCZYK' AND txt_first_name = 'Marcin' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2025-2026'),
    6, 4.88
); -- STAŃCZYK Marcin
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'PAWŁOWSKI' AND txt_first_name = 'Łukasz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-EPEE-2025-2026'),
    7, 1.00
); -- PAWŁOWSKI Łukasz

-- ---- PEW4-2025-2026: EVF Circuit Napoli ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW4-2025-2026',
    'EVF Circuit Napoli',
    'Napoli',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW4-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW4-2025-2026'),
    'PEW4-V1-M-EPEE-2025-2026',
    'EVF Grand Prix 4',
    'PEW',
    'EPEE', 'M', 'V1',
    NULL, 59, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KORONA' AND txt_first_name = 'Radosław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-EPEE-2025-2026'),
    3, 88.48
); -- KORONA Radosław
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ALCSER' AND txt_first_name = 'Norbert' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-EPEE-2025-2026'),
    11, 41.18
); -- ALCSER Norbert
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'STOCKI' AND txt_first_name = 'Piotr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-EPEE-2025-2026'),
    13, 39.18
); -- STOCKI Piotr
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SCHOLZ' AND txt_first_name = 'Jurgen' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-EPEE-2025-2026'),
    19, 24.62
); -- SCHOLZ Jurgen
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KORNAŚ' AND txt_first_name = 'Jarosław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-EPEE-2025-2026'),
    30, 19.13
); -- KORNAŚ Jarosław

-- ---- PEW5-2025-2026: EVF Circuit Stockholm ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW5-2025-2026',
    'EVF Circuit Stockholm',
    'Stockholm',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW5-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW5-2025-2026'),
    'PEW5-V1-M-EPEE-2025-2026',
    'EVF Grand Prix 5',
    'PEW',
    'EPEE', 'M', 'V1',
    NULL, 13, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KORONA' AND txt_first_name = 'Radosław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V1-M-EPEE-2025-2026'),
    2, 80.87
); -- KORONA Radosław
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ALCSER' AND txt_first_name = 'Norbert' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V1-M-EPEE-2025-2026'),
    12, 2.53
); -- ALCSER Norbert

-- ---- PEW6-2025-2026: EVF Circuit Jabłonna ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW6-2025-2026',
    'EVF Circuit Jabłonna',
    'Jabłonna',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW6-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW6-2025-2026'),
    'PEW6-V1-M-EPEE-2025-2026',
    'EVF Grand Prix 6',
    'PEW',
    'EPEE', 'M', 'V1',
    NULL, 24, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SĘKOWSKI' AND txt_first_name = 'Maciej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    1, 125.96
); -- SĘKOWSKI Maciej
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'STOCKI' AND txt_first_name = 'Piotr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    3, 71.71
); -- STOCKI Piotr
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'BOBUSIA' AND txt_first_name = 'Jarosław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    4, 58.63
); -- BOBUSIA Jarosław
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KORONA' AND txt_first_name = 'Radosław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    6, 42.37
); -- KORONA Radosław
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOWALCZYK' AND txt_first_name = 'Piotr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    10, 24.50
); -- KOWALCZYK Piotr
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'TATCHYN' AND txt_first_name = 'Andriy' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    11, 23.03
); -- TATCHYN Andriy
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KORNAŚ' AND txt_first_name = 'Jarosław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    12, 21.69
); -- KORNAŚ Jarosław
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NOWAK' AND txt_first_name = 'Szymon' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    13, 20.45
); -- NOWAK Szymon
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DOBRZAŃSKI' AND txt_first_name = 'Maciej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    16, 17.25
); -- DOBRZAŃSKI Maciej
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'LELONEK' AND txt_first_name = 'Tomasz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    22, 2.34
); -- LELONEK Tomasz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'STAŃCZYK' AND txt_first_name = 'Marcin' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    23, 1.66
); -- STAŃCZYK Marcin
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'PAWŁOWSKI' AND txt_first_name = 'Łukasz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-EPEE-2025-2026'),
    24, 1.00
); -- PAWŁOWSKI Łukasz
