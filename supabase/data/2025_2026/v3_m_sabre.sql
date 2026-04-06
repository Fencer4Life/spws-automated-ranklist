-- =========================================================================
-- Season 2025-2026 — V3 M SABRE — auto-exported from CERT (ADR-027)
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- =========================================================================

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
    'PPW1-V3-M-SABRE-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V3',
    NULL, 4, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ZABŁOCKI' AND txt_first_name = 'Michał' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-SABRE-2025-2026'),
    1
); -- ZABŁOCKI Michał
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GAJDA' AND txt_first_name = 'Leszek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-SABRE-2025-2026'),
    2
); -- GAJDA Leszek
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NIKALAICHUK' AND txt_first_name = 'Aliaksandr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-SABRE-2025-2026'),
    3
); -- NIKALAICHUK Aliaksandr
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CHUDYCKI' AND txt_first_name = 'Artur' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-SABRE-2025-2026'),
    4
); -- CHUDYCKI Artur

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
    'PPW2-V3-M-SABRE-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V3',
    NULL, 2, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GAJDA' AND txt_first_name = 'Leszek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-SABRE-2025-2026'),
    1
); -- GAJDA Leszek
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CHUDYCKI' AND txt_first_name = 'Artur' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-SABRE-2025-2026'),
    2
); -- CHUDYCKI Artur

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
    'PPW3-V3-M-SABRE-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V3',
    '2025-12-14', 2, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GAJDA' AND txt_first_name = 'Leszek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-SABRE-2025-2026'),
    1
); -- GAJDA Leszek
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CHUDYCKI' AND txt_first_name = 'Artur' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-SABRE-2025-2026'),
    2
); -- CHUDYCKI Artur

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
    'PEW3-V3-M-SABRE-2025-2026',
    'EVF Grand Prix 3',
    'PEW',
    'SABRE', 'M', 'V3',
    '2025-12-06', 22, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GAJDA' AND txt_first_name = 'Leszek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-SABRE-2025-2026'),
    7
); -- GAJDA Leszek

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
    'PPW4-V3-M-SABRE-2025-2026',
    'V3 M SABRE',
    'PPW',
    'SABRE', 'M', 'V3',
    '2026-02-21', 4, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GAJDA' AND txt_first_name = 'Leszek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-SABRE-2025-2026'),
    1
); -- GAJDA Leszek
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'OSSOWSKI' AND txt_first_name = 'Wojciech' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-SABRE-2025-2026'),
    2
); -- OSSOWSKI Wojciech
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'JASIŃSKI' AND txt_first_name = 'Tomasz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-SABRE-2025-2026'),
    3
); -- JASIŃSKI Tomasz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CHUDYCKI' AND txt_first_name = 'Artur' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-SABRE-2025-2026'),
    4
); -- CHUDYCKI Artur

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
    'PEW6-V3-M-SABRE-2025-2026',
    'EVF Grand Prix 6',
    'PEW',
    'SABRE', 'M', 'V3',
    NULL, 20, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ZABŁOCKI' AND txt_first_name = 'Michał' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-SABRE-2025-2026'),
    1
); -- ZABŁOCKI Michał
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GAJDA' AND txt_first_name = 'Leszek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-SABRE-2025-2026'),
    3
); -- GAJDA Leszek
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'WOJCIECHOWSKI' AND txt_first_name = 'Marek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-SABRE-2025-2026'),
    20
); -- WOJCIECHOWSKI Marek

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
    'PEW7-V3-M-SABRE-2025-2026',
    'EVF Grand Prix 7 — Terni',
    'PEW',
    'SABRE', 'M', 'V3',
    NULL, 12, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ZABŁOCKI' AND txt_first_name = 'Michał' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V3-M-SABRE-2025-2026'),
    1
); -- ZABŁOCKI Michał
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GAJDA' AND txt_first_name = 'Leszek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V3-M-SABRE-2025-2026'),
    4
); -- GAJDA Leszek
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'JASIŃSKI' AND txt_first_name = 'Tomasz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V3-M-SABRE-2025-2026'),
    7
); -- JASIŃSKI Tomasz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CHUDYCKI' AND txt_first_name = 'Artur' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V3-M-SABRE-2025-2026'),
    10
); -- CHUDYCKI Artur
