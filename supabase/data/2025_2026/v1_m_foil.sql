-- =========================================================================
-- Season 2025-2026 — V1 M FOIL — auto-exported from CERT (ADR-027)
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
    'PEW10-V1-M-FOIL-2025-2026',
    'EVF Criterium Mondial Vétérans 2025',
    'PEW',
    'FOIL', 'M', 'V1',
    '2025-07-05', 16, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'PRZYSTAJKO' AND txt_first_name = 'Daniel' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW10-V1-M-FOIL-2025-2026'),
    6
); -- PRZYSTAJKO Daniel

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
    'PPW1-V1-M-FOIL-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V1',
    NULL, 3, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'MALINOWSKI' AND txt_first_name = 'Piotr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-FOIL-2025-2026'),
    1
); -- MALINOWSKI Piotr
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GIBULA' AND txt_first_name = 'Marcin' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-FOIL-2025-2026'),
    2
); -- GIBULA Marcin
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CHUDY' AND txt_first_name = 'Tomasz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-M-FOIL-2025-2026'),
    3
); -- CHUDY Tomasz

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
    'PPW2-V1-M-FOIL-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V1',
    NULL, 4, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'MALINOWSKI' AND txt_first_name = 'Piotr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-FOIL-2025-2026'),
    1
); -- MALINOWSKI Piotr
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'EJCHSZTET' AND txt_first_name = 'Mariusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-FOIL-2025-2026'),
    2
); -- EJCHSZTET Mariusz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GIBULA' AND txt_first_name = 'Marcin' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-FOIL-2025-2026'),
    3
); -- GIBULA Marcin
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CHUDY' AND txt_first_name = 'Tomasz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-M-FOIL-2025-2026'),
    4
); -- CHUDY Tomasz

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
    'PEW2-V1-M-FOIL-2025-2026',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'FOIL', 'M', 'V1',
    NULL, 28, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GINZERY' AND txt_first_name = 'Tomas' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V1-M-FOIL-2025-2026'),
    9
); -- GINZERY Tomas

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
    'PPW3-V1-M-FOIL-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V1',
    NULL, 3, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'MALINOWSKI' AND txt_first_name = 'Piotr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-FOIL-2025-2026'),
    1
); -- MALINOWSKI Piotr
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SPŁAWA-NEYMAN' AND txt_first_name = 'MACIEJ' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-FOIL-2025-2026'),
    2
); -- SPŁAWA-NEYMAN MACIEJ
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SZMELC' AND txt_first_name = 'Łukasz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-M-FOIL-2025-2026'),
    3
); -- SZMELC Łukasz

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
    'PPW4-V1-M-FOIL-2025-2026',
    'V1 M FOIL',
    'PPW',
    'FOIL', 'M', 'V1',
    '2026-02-21', 1, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CHUDY' AND txt_first_name = 'Tomasz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-M-FOIL-2025-2026'),
    1
); -- CHUDY Tomasz

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
    'PEW4-V1-M-FOIL-2025-2026',
    'EVF Grand Prix 4',
    'PEW',
    'FOIL', 'M', 'V1',
    NULL, 18, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'PRZYSTAJKO' AND txt_first_name = 'Daniel' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-FOIL-2025-2026'),
    3
); -- PRZYSTAJKO Daniel
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ALCSER' AND txt_first_name = 'Norbert' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-M-FOIL-2025-2026'),
    17
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
    'PEW6-V1-M-FOIL-2025-2026',
    'EVF Grand Prix 6',
    'PEW',
    'FOIL', 'M', 'V1',
    NULL, 13, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ALCSER' AND txt_first_name = 'Norbert' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-M-FOIL-2025-2026'),
    12
); -- ALCSER Norbert

-- ---- PEW7-2025-2026: EVF Circuit Salzburg ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW7-2025-2026',
    'EVF Circuit Salzburg',
    'Salzburg',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'PLANNED'
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
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GINZERY' AND txt_first_name = 'Tomas' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-M-FOIL-2025-2026'),
    1
); -- GINZERY Tomas
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ALCSER' AND txt_first_name = 'Norbert' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V1-M-FOIL-2025-2026'),
    3
); -- ALCSER Norbert

-- ---- PEW8-2025-2026: EVF Circuit Chania ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW8-2025-2026',
    'EVF Circuit Chania',
    'Chania',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'PLANNED'
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
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GINZERY' AND txt_first_name = 'Tomas' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V1-M-FOIL-2025-2026'),
    3
); -- GINZERY Tomas
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'PRZYSTAJKO' AND txt_first_name = 'Daniel' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V1-M-FOIL-2025-2026'),
    3
); -- PRZYSTAJKO Daniel
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SERAFIN' AND txt_first_name = 'Błażej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V1-M-FOIL-2025-2026'),
    7
); -- SERAFIN Błażej
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'MALINOWSKI' AND txt_first_name = 'Piotr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V1-M-FOIL-2025-2026'),
    8
); -- MALINOWSKI Piotr
