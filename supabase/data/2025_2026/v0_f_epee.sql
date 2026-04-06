-- =========================================================================
-- Season 2025-2026 — V0 F EPEE — auto-exported from CERT (ADR-027)
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
    'PPW1-V0-F-EPEE-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'F', 'V0',
    NULL, 2, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'PĘCZEK' AND txt_first_name = 'Sandra' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-F-EPEE-2025-2026'),
    1, 71.34
); -- PĘCZEK Sandra
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOCÓR' AND txt_first_name = 'Agata' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V0-F-EPEE-2025-2026'),
    2, 8.56
); -- KOCÓR Agata

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
    'PPW2-V0-F-EPEE-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'F', 'V0',
    NULL, 2, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KRUJALSKIENE' AND txt_first_name = 'Julija' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-F-EPEE-2025-2026'),
    1, 71.34
); -- KRUJALSKIENE Julija
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOCÓR' AND txt_first_name = 'Agata' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V0-F-EPEE-2025-2026'),
    2, 8.56
); -- KOCÓR Agata

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
    'PPW3-V0-F-EPEE-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'F', 'V0',
    NULL, 5, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'PĘCZEK' AND txt_first_name = 'Sandra' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-F-EPEE-2025-2026'),
    1, 95.39
); -- PĘCZEK Sandra
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SZMAJDZIŃSKA' AND txt_first_name = 'Katarzyna' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-F-EPEE-2025-2026'),
    2, 59.16
); -- SZMAJDZIŃSKA Katarzyna
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'IRZYK' AND txt_first_name = 'Sabina' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-F-EPEE-2025-2026'),
    3, 31.68
); -- IRZYK Sabina
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DRAPELLA' AND txt_first_name = 'Magdalena' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-F-EPEE-2025-2026'),
    4, 17.79
); -- DRAPELLA Magdalena
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GÓRNA' AND txt_first_name = 'Karolina' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V0-F-EPEE-2025-2026'),
    5, 1.00
); -- GÓRNA Karolina

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
    'PPW4-V0-F-EPEE-2025-2026',
    'V0 F EPEE',
    'PPW',
    'EPEE', 'F', 'V0',
    '2026-02-21', 3, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SZMAJDZIŃSKA' AND txt_first_name = 'Katarzyna' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-F-EPEE-2025-2026'),
    1, 82.98
); -- SZMAJDZIŃSKA Katarzyna
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GÓRNA' AND txt_first_name = 'Karolina' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-F-EPEE-2025-2026'),
    2, 37.74
); -- GÓRNA Karolina
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DRAPELLA' AND txt_first_name = 'Magdalena' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V0-F-EPEE-2025-2026'),
    3, 5.33
); -- DRAPELLA Magdalena
