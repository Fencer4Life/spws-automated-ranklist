-- =========================================================================
-- Season 2025-2026 — V3 M FOIL — auto-exported from CERT (ADR-027)
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
    'PEW1-V3-M-FOIL-2025-2026',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'FOIL', 'M', 'V3',
    NULL, 21, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NIKALAICHUK' AND txt_first_name = 'Aliaksandr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-FOIL-2025-2026'),
    7
); -- NIKALAICHUK Aliaksandr
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ANDERSCH' AND txt_first_name = 'Robert' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-FOIL-2025-2026'),
    8
); -- ANDERSCH Robert
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DRAPELLA' AND txt_first_name = 'Maciej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-FOIL-2025-2026'),
    9
); -- DRAPELLA Maciej
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ĆWIORO' AND txt_first_name = 'Krzysztof' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-FOIL-2025-2026'),
    21
); -- ĆWIORO Krzysztof

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
    'PPW1-V3-M-FOIL-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V3',
    '2025-09-27', 2, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NIKALAICHUK' AND txt_first_name = 'Aliaksandr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-FOIL-2025-2026'),
    1
); -- NIKALAICHUK Aliaksandr
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'PYZIK' AND txt_first_name = 'Zdzisław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-FOIL-2025-2026'),
    2
); -- PYZIK Zdzisław

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
    'PPW2-V3-M-FOIL-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V3',
    NULL, 1, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'PYZIK' AND txt_first_name = 'Zdzisław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-FOIL-2025-2026'),
    1
); -- PYZIK Zdzisław

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
    'PPW3-V3-M-FOIL-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V3',
    '2025-12-13', 2, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DRAPELLA' AND txt_first_name = 'Maciej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-FOIL-2025-2026'),
    1
); -- DRAPELLA Maciej
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'PYZIK' AND txt_first_name = 'Zdzisław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-FOIL-2025-2026'),
    2
); -- PYZIK Zdzisław

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
    'PPW4-V3-M-FOIL-2025-2026',
    'V3 M FOIL',
    'PPW',
    'FOIL', 'M', 'V3',
    '2026-02-21', 3, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DRAPELLA' AND txt_first_name = 'Maciej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-FOIL-2025-2026'),
    1
); -- DRAPELLA Maciej
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'MAŁASIŃSKI' AND txt_first_name = 'Adam' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-FOIL-2025-2026'),
    2
); -- MAŁASIŃSKI Adam
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NIKALAICHUK' AND txt_first_name = 'Aliaksandr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-FOIL-2025-2026'),
    3
); -- NIKALAICHUK Aliaksandr

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
    'PEW8-V3-M-FOIL-2025-2026',
    'EVF Grand Prix 8 — Guildford',
    'PEW',
    'FOIL', 'M', 'V3',
    NULL, 11, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DRAPELLA' AND txt_first_name = 'Maciej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V3-M-FOIL-2025-2026'),
    2
); -- DRAPELLA Maciej
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NIKALAICHUK' AND txt_first_name = 'Aliaksandr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V3-M-FOIL-2025-2026'),
    3
); -- NIKALAICHUK Aliaksandr
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'MAŁASIŃSKI' AND txt_first_name = 'Adam' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V3-M-FOIL-2025-2026'),
    11
); -- MAŁASIŃSKI Adam
