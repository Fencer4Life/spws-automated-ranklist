-- =========================================================================
-- Season 2025-2026 — V1 F EPEE — auto-exported from CERT (ADR-027)
-- Auto-loaded by supabase db reset via config.toml sql_paths glob.
-- =========================================================================

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
    'PEW1-V1-F-EPEE-2025-2026',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'EPEE', 'F', 'V1',
    NULL, 17, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SAMECKA-NACZYŃSKA' AND txt_first_name = 'Martyna' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V1-F-EPEE-2025-2026'),
    7, 36.35
); -- SAMECKA-NACZYŃSKA Martyna

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
    'PPW1-V1-F-EPEE-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'F', 'V1',
    NULL, 2, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KLIMECKA' AND txt_first_name = 'Dorota' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-F-EPEE-2025-2026'),
    1, 71.34
); -- KLIMECKA Dorota
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CHMIELEWSKA' AND txt_first_name = 'Emilia' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V1-F-EPEE-2025-2026'),
    2, 8.56
); -- CHMIELEWSKA Emilia

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
    'PPW2-V1-F-EPEE-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'F', 'V1',
    NULL, 3, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KAMIŃSKA' AND txt_first_name = 'Gabriela' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-F-EPEE-2025-2026'),
    1, 82.98
); -- KAMIŃSKA Gabriela
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SAMECKA-NACZYŃSKA' AND txt_first_name = 'Martyna' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-F-EPEE-2025-2026'),
    2, 37.74
); -- SAMECKA-NACZYŃSKA Martyna
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KLIMECKA' AND txt_first_name = 'Dorota' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V1-F-EPEE-2025-2026'),
    3, 5.33
); -- KLIMECKA Dorota

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
    'PPW3-V1-F-EPEE-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'F', 'V1',
    NULL, 6, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KAMIŃSKA' AND txt_first_name = 'Gabriela' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-F-EPEE-2025-2026'),
    1, 96.35
); -- KAMIŃSKA Gabriela
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SAMECKA-NACZYŃSKA' AND txt_first_name = 'Martyna' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-F-EPEE-2025-2026'),
    2, 61.95
); -- SAMECKA-NACZYŃSKA Martyna
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CHMIELEWSKA' AND txt_first_name = 'Emilia' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-F-EPEE-2025-2026'),
    3, 35.41
); -- CHMIELEWSKA Emilia
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KLIMECKA' AND txt_first_name = 'Dorota' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-F-EPEE-2025-2026'),
    4, 22.09
); -- KLIMECKA Dorota
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SADOWSKA' AND txt_first_name = 'Małgorzata' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-F-EPEE-2025-2026'),
    5, 5.99
); -- SADOWSKA Małgorzata
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GIERS-ROMEK' AND txt_first_name = 'Monika' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V1-F-EPEE-2025-2026'),
    6, 1.00
); -- GIERS-ROMEK Monika

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
    'PEW3-V1-F-EPEE-2025-2026',
    'EVF Grand Prix 3',
    'PEW',
    'EPEE', 'F', 'V1',
    '2026-01-10', 23, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KAMIŃSKA' AND txt_first_name = 'Gabriela' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V1-F-EPEE-2025-2026'),
    8, 37.50
); -- KAMIŃSKA Gabriela

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
    'PPW4-V1-F-EPEE-2025-2026',
    'V1 F EPEE',
    'PPW',
    'EPEE', 'F', 'V1',
    '2026-02-21', 4, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KAMIŃSKA' AND txt_first_name = 'Gabriela' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-F-EPEE-2025-2026'),
    1, 84.29
); -- KAMIŃSKA Gabriela
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SAMECKA-NACZYŃSKA' AND txt_first_name = 'Martyna' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-F-EPEE-2025-2026'),
    2, 45.02
); -- SAMECKA-NACZYŃSKA Martyna
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CHMIELEWSKA' AND txt_first_name = 'Emilia' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-F-EPEE-2025-2026'),
    3, 15.93
); -- CHMIELEWSKA Emilia
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'MARNIAK' AND txt_first_name = 'Ksenia' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V1-F-EPEE-2025-2026'),
    4, 1.00
); -- MARNIAK Ksenia

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
    'PEW4-V1-F-EPEE-2025-2026',
    'EVF Grand Prix 4',
    'PEW',
    'EPEE', 'F', 'V1',
    NULL, 34, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CHIAROMONTE' AND txt_first_name = 'Francesco' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-F-EPEE-2025-2026'),
    12, 35.47
); -- CHIAROMONTE Francesco
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KAMIŃSKA' AND txt_first_name = 'Gabriela' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V1-F-EPEE-2025-2026'),
    13, 34.36
); -- KAMIŃSKA Gabriela

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
    'PEW6-V1-F-EPEE-2025-2026',
    'EVF Grand Prix 6',
    'PEW',
    'EPEE', 'F', 'V1',
    NULL, 12, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SAMECKA-NACZYŃSKA' AND txt_first_name = 'Martyna' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-F-EPEE-2025-2026'),
    7, 21.63
); -- SAMECKA-NACZYŃSKA Martyna
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KAMIŃSKA' AND txt_first_name = 'Gabriela' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-F-EPEE-2025-2026'),
    8, 19.00
); -- KAMIŃSKA Gabriela
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CHMIELEWSKA' AND txt_first_name = 'Emilia' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-F-EPEE-2025-2026'),
    10, 4.60
); -- CHMIELEWSKA Emilia
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'MURRAY' AND txt_first_name = 'Claire' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V1-F-EPEE-2025-2026'),
    11, 2.72
); -- MURRAY Claire
