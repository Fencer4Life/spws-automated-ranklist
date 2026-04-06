-- =========================================================================
-- Season 2025-2026 — V0 F SABRE — auto-exported from CERT (ADR-027)
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
    'PPW1-V0-F-SABRE-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'F', 'V0',
    NULL, 1, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'OWCZAREK' AND txt_first_name = 'Ewelina' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-F-SABRE-2025-2026'),
    1
); -- OWCZAREK Ewelina

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
    'PPW2-V0-F-SABRE-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'SABRE', 'F', 'V0',
    NULL, 2, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'HAJDAS' AND txt_first_name = 'Martyna' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-F-SABRE-2025-2026'),
    1
); -- HAJDAS Martyna
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'OWCZAREK' AND txt_first_name = 'Ewelina' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-F-SABRE-2025-2026'),
    2
); -- OWCZAREK Ewelina

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
    'PPW4-V0-F-SABRE-2025-2026',
    'V0 F SABRE',
    'PPW',
    'SABRE', 'F', 'V0',
    '2026-02-21', 2, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'OWCZAREK' AND txt_first_name = 'Ewelina' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-F-SABRE-2025-2026'),
    1
); -- OWCZAREK Ewelina
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'OWCZAREK' AND txt_first_name = 'Elżbieta' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-F-SABRE-2025-2026'),
    2
); -- OWCZAREK Elżbieta
