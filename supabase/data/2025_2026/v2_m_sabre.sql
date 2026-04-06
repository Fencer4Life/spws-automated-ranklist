-- =========================================================================
-- Season 2025-2026 — V2 M SABRE — auto-exported from CERT (ADR-027)
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
    'PEW10-V2-M-SABRE-2025-2026',
    'EVF Criterium Mondial Vétérans 2025',
    'PEW',
    'SABRE', 'M', 'V2',
    '2025-07-05', 12, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOŃCZYŁO' AND txt_first_name = 'Tomasz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW10-V2-M-SABRE-2025-2026'),
    3
); -- KOŃCZYŁO Tomasz

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
    'PEW1-V2-M-SABRE-2025-2026',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'SABRE', 'M', 'V2',
    NULL, 22, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOŃCZYŁO' AND txt_first_name = 'Tomasz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-SABRE-2025-2026'),
    3
); -- KOŃCZYŁO Tomasz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GANSZCZYK' AND txt_first_name = 'Marcin' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-SABRE-2025-2026'),
    4
); -- GANSZCZYK Marcin
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CHIAROMONTE' AND txt_first_name = 'Francesco' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-SABRE-2025-2026'),
    5
); -- CHIAROMONTE Francesco
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ZAWROTNIAK' AND txt_first_name = 'Przemysław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-SABRE-2025-2026'),
    6
); -- ZAWROTNIAK Przemysław
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NOWICKI' AND txt_first_name = 'Robert' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-SABRE-2025-2026'),
    10
); -- NOWICKI Robert
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'MAZIK' AND txt_first_name = 'Aleksander' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-SABRE-2025-2026'),
    14
); -- MAZIK Aleksander
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'WIERZBICKI' AND txt_first_name = 'Jacek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-SABRE-2025-2026'),
    15
); -- WIERZBICKI Jacek

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
    'PPW1-V2-M-SABRE-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V2',
    NULL, 11, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GANSZCZYK' AND txt_first_name = 'Marcin' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2025-2026'),
    1
); -- GANSZCZYK Marcin
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KROCHMALSKI' AND txt_first_name = 'Jakub' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2025-2026'),
    2
); -- KROCHMALSKI Jakub
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NOWICKI' AND txt_first_name = 'Robert' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2025-2026'),
    3
); -- NOWICKI Robert
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ZAWROTNIAK' AND txt_first_name = 'Przemysław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2025-2026'),
    4
); -- ZAWROTNIAK Przemysław
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'WINGROWICZ' AND txt_first_name = 'Mariusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2025-2026'),
    5
); -- WINGROWICZ Mariusz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KACZMAREK' AND txt_first_name = 'Paweł' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2025-2026'),
    6
); -- KACZMAREK Paweł
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOŁUCKI' AND txt_first_name = 'Michał' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2025-2026'),
    7
); -- KOŁUCKI Michał
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'MAZIK' AND txt_first_name = 'Aleksander' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2025-2026'),
    8
); -- MAZIK Aleksander
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'JAROSZEK' AND txt_first_name = 'Zbigniew' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2025-2026'),
    9
); -- JAROSZEK Zbigniew
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'WIERZBICKI' AND txt_first_name = 'Jacek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2025-2026'),
    10
); -- WIERZBICKI Jacek
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOTTS' AND txt_first_name = 'Radosław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-SABRE-2025-2026'),
    11
); -- KOTTS Radosław

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
    'PPW2-V2-M-SABRE-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V2',
    NULL, 9, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KROCHMALSKI' AND txt_first_name = 'Jakub' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2025-2026'),
    1
); -- KROCHMALSKI Jakub
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GANSZCZYK' AND txt_first_name = 'Marcin' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2025-2026'),
    2
); -- GANSZCZYK Marcin
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NOWICKI' AND txt_first_name = 'Robert' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2025-2026'),
    3
); -- NOWICKI Robert
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ZAWROTNIAK' AND txt_first_name = 'Przemysław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2025-2026'),
    4
); -- ZAWROTNIAK Przemysław
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KACZMAREK' AND txt_first_name = 'Paweł' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2025-2026'),
    5
); -- KACZMAREK Paweł
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'MAZIK' AND txt_first_name = 'Aleksander' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2025-2026'),
    6
); -- MAZIK Aleksander
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'PLUCIŃSKI' AND txt_first_name = 'Paweł' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2025-2026'),
    7
); -- PLUCIŃSKI Paweł
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'WIERZBICKI' AND txt_first_name = 'Jacek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2025-2026'),
    8
); -- WIERZBICKI Jacek
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOTTS' AND txt_first_name = 'Radosław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V2-M-SABRE-2025-2026'),
    9
); -- KOTTS Radosław

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
    'PPW3-V2-M-SABRE-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V2',
    NULL, 12, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KROCHMALSKI' AND txt_first_name = 'Jakub' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2025-2026'),
    1
); -- KROCHMALSKI Jakub
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ZAWROTNIAK' AND txt_first_name = 'Przemysław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2025-2026'),
    2
); -- ZAWROTNIAK Przemysław
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GANSZCZYK' AND txt_first_name = 'Marcin' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2025-2026'),
    3
); -- GANSZCZYK Marcin
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NOWICKI' AND txt_first_name = 'Robert' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2025-2026'),
    4
); -- NOWICKI Robert
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'WINGROWICZ' AND txt_first_name = 'Mariusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2025-2026'),
    5
); -- WINGROWICZ Mariusz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KACZMAREK' AND txt_first_name = 'Paweł' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2025-2026'),
    6
); -- KACZMAREK Paweł
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'MAZIK' AND txt_first_name = 'Aleksander' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2025-2026'),
    7
); -- MAZIK Aleksander
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'PLUCIŃSKI' AND txt_first_name = 'Paweł' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2025-2026'),
    8
); -- PLUCIŃSKI Paweł
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GAJDA' AND txt_first_name = 'Zbigniew' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2025-2026'),
    9
); -- GAJDA Zbigniew
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SZYMAŃSKI' AND txt_first_name = 'Adam' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2025-2026'),
    10
); -- SZYMAŃSKI Adam
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'JAROSZEK' AND txt_first_name = 'Zbigniew' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2025-2026'),
    11
); -- JAROSZEK Zbigniew
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'WIERZBICKI' AND txt_first_name = 'Jacek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-SABRE-2025-2026'),
    12
); -- WIERZBICKI Jacek

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
    'PEW3-V2-M-SABRE-2025-2026',
    'EVF Grand Prix 3',
    'PEW',
    'SABRE', 'M', 'V2',
    '2025-12-06', 25, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GANSZCZYK' AND txt_first_name = 'Marcin' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-SABRE-2025-2026'),
    6
); -- GANSZCZYK Marcin
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NOWICKI' AND txt_first_name = 'Robert' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-SABRE-2025-2026'),
    9
); -- NOWICKI Robert

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
    'PPW4-V2-M-SABRE-2025-2026',
    'V2 M SABRE',
    'PPW',
    'SABRE', 'M', 'V2',
    '2026-02-21', 10, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GANSZCZYK' AND txt_first_name = 'Marcin' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-SABRE-2025-2026'),
    1
); -- GANSZCZYK Marcin
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KROCHMALSKI' AND txt_first_name = 'Jakub' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-SABRE-2025-2026'),
    2
); -- KROCHMALSKI Jakub
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NOWICKI' AND txt_first_name = 'Robert' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-SABRE-2025-2026'),
    3
); -- NOWICKI Robert
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'MAZIK' AND txt_first_name = 'Aleksander' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-SABRE-2025-2026'),
    4
); -- MAZIK Aleksander
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CHIAROMONTE' AND txt_first_name = 'Francesco' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-SABRE-2025-2026'),
    5
); -- CHIAROMONTE Francesco
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'WINGROWICZ' AND txt_first_name = 'Mariusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-SABRE-2025-2026'),
    6
); -- WINGROWICZ Mariusz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'WIERZBICKI' AND txt_first_name = 'Jacek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-SABRE-2025-2026'),
    7
); -- WIERZBICKI Jacek
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'JAROSZEK' AND txt_first_name = 'Zbigniew' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-SABRE-2025-2026'),
    8
); -- JAROSZEK Zbigniew
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SZYMAŃSKI' AND txt_first_name = 'Adam' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-SABRE-2025-2026'),
    9
); -- SZYMAŃSKI Adam
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'LISOWSKI' AND txt_first_name = 'Robert' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-SABRE-2025-2026'),
    10
); -- LISOWSKI Robert

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
    'PEW4-V2-M-SABRE-2025-2026',
    'EVF Grand Prix 4',
    'PEW',
    'SABRE', 'M', 'V2',
    '2026-11-11', 22, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOŃCZYŁO' AND txt_first_name = 'Tomasz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-SABRE-2025-2026'),
    3
); -- KOŃCZYŁO Tomasz

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
    'PEW6-V2-M-SABRE-2025-2026',
    'EVF Grand Prix 6',
    'PEW',
    'SABRE', 'M', 'V2',
    NULL, 32, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NOWICKI' AND txt_first_name = 'Robert' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-SABRE-2025-2026'),
    3
); -- NOWICKI Robert
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ZAWROTNIAK' AND txt_first_name = 'Przemysław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-SABRE-2025-2026'),
    6
); -- ZAWROTNIAK Przemysław
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GANSZCZYK' AND txt_first_name = 'Marcin' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-SABRE-2025-2026'),
    9
); -- GANSZCZYK Marcin
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CHIAROMONTE' AND txt_first_name = 'Francesco' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-SABRE-2025-2026'),
    13
); -- CHIAROMONTE Francesco
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'MAZIK' AND txt_first_name = 'Aleksander' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-SABRE-2025-2026'),
    21
); -- MAZIK Aleksander
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KACZMAREK' AND txt_first_name = 'Paweł' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-SABRE-2025-2026'),
    28
); -- KACZMAREK Paweł
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'WIERZBICKI' AND txt_first_name = 'Jacek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-SABRE-2025-2026'),
    31
); -- WIERZBICKI Jacek

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
    'PEW7-V2-M-SABRE-2025-2026',
    'EVF Grand Prix 7 — Terni',
    'PEW',
    'SABRE', 'M', 'V2',
    NULL, 16, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GANSZCZYK' AND txt_first_name = 'Marcin' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2025-2026'),
    2
); -- GANSZCZYK Marcin
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ZAWROTNIAK' AND txt_first_name = 'Przemysław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2025-2026'),
    3
); -- ZAWROTNIAK Przemysław
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KROCHMALSKI' AND txt_first_name = 'Jakub' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2025-2026'),
    4
); -- KROCHMALSKI Jakub
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NOWICKI' AND txt_first_name = 'Robert' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2025-2026'),
    6
); -- NOWICKI Robert
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CHIAROMONTE' AND txt_first_name = 'Francesco' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2025-2026'),
    7
); -- CHIAROMONTE Francesco
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOŃCZYŁO' AND txt_first_name = 'Tomasz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2025-2026'),
    8
); -- KOŃCZYŁO Tomasz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'WINGROWICZ' AND txt_first_name = 'Mariusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2025-2026'),
    10
); -- WINGROWICZ Mariusz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SZYMAŃSKI' AND txt_first_name = 'Adam' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2025-2026'),
    13
); -- SZYMAŃSKI Adam
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'WIERZBICKI' AND txt_first_name = 'Jacek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2025-2026'),
    14
); -- WIERZBICKI Jacek
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'MAZIK' AND txt_first_name = 'Aleksander' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-SABRE-2025-2026'),
    16
); -- MAZIK Aleksander
