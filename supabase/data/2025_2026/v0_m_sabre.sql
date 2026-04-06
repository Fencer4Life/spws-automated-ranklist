-- =========================================================================
-- Season 2025-2026 — V0 M SABRE — auto-exported from CERT (ADR-027)
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
    'PPW1-V0-M-SABRE-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V0',
    NULL, 3, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ROMANOWICZ' AND txt_first_name = 'Aleksiej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-SABRE-2025-2026'),
    1
); -- ROMANOWICZ Aleksiej
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CHARKIEWICZ' AND txt_first_name = 'Paweł' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-SABRE-2025-2026'),
    2
); -- CHARKIEWICZ Paweł
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DOMAŃSKI' AND txt_first_name = 'Sławomir' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-M-SABRE-2025-2026'),
    3
); -- DOMAŃSKI Sławomir

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
    'PPW2-V0-M-SABRE-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V0',
    NULL, 3, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'STANISŁAWSKI' AND txt_first_name = 'Albert' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-SABRE-2025-2026'),
    1
); -- STANISŁAWSKI Albert
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GĘZIKIEWICZ' AND txt_first_name = 'Marcin' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-SABRE-2025-2026'),
    2
); -- GĘZIKIEWICZ Marcin
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CHOJNACKI' AND txt_first_name = 'Tomasz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-M-SABRE-2025-2026'),
    3
); -- CHOJNACKI Tomasz

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
    'PPW3-V0-M-SABRE-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'M', 'V0',
    '2025-12-14', 3, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'STANISŁAWSKI' AND txt_first_name = 'Albert' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-SABRE-2025-2026'),
    1
); -- STANISŁAWSKI Albert
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'TECŁAW' AND txt_first_name = 'Robert' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-SABRE-2025-2026'),
    2
); -- TECŁAW Robert
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ZAJĄC' AND txt_first_name = 'Michał' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-M-SABRE-2025-2026'),
    3
); -- ZAJĄC Michał

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
    'PPW4-V0-M-SABRE-2025-2026',
    'V0 M SABRE',
    'PPW',
    'SABRE', 'M', 'V0',
    '2026-02-21', 1, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'LISOWSKI' AND txt_first_name = 'Igor' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-M-SABRE-2025-2026'),
    1
); -- LISOWSKI Igor
