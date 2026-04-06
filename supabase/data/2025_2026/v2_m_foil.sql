-- =========================================================================
-- Season 2025-2026 — V2 M FOIL — auto-exported from CERT (ADR-027)
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
    'PEW10-V2-M-FOIL-2025-2026',
    'EVF Criterium Mondial Vétérans 2025',
    'PEW',
    'FOIL', 'M', 'V2',
    '2025-07-05', 27, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOŃCZYŁO' AND txt_first_name = 'Tomasz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW10-V2-M-FOIL-2025-2026'),
    11, 24.35
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
    'PEW1-V2-M-FOIL-2025-2026',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'FOIL', 'M', 'V2',
    NULL, 25, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KORONA' AND txt_first_name = 'Przemysław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-FOIL-2025-2026'),
    2, 96.99
); -- KORONA Przemysław
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SOKOL' AND txt_first_name = 'Vratislav' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-FOIL-2025-2026'),
    12, 22.17
); -- SOKOL Vratislav
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOŃCZYŁO' AND txt_first_name = 'Tomasz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V2-M-FOIL-2025-2026'),
    18, 6.00
); -- KOŃCZYŁO Tomasz

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
    'PEW2-V2-M-FOIL-2025-2026',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'FOIL', 'M', 'V2',
    NULL, 17, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KORONA' AND txt_first_name = 'Przemysław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V2-M-FOIL-2025-2026'),
    8, 34.04
); -- KORONA Przemysław

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
    'PPW3-V2-M-FOIL-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'FOIL', 'M', 'V2',
    '2025-12-13', 2, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KORONA' AND txt_first_name = 'Przemysław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-FOIL-2025-2026'),
    1, 71.34
); -- KORONA Przemysław
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SERWATKA' AND txt_first_name = 'Marek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-M-FOIL-2025-2026'),
    2, 8.56
); -- SERWATKA Marek

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
    'PPW4-V2-M-FOIL-2025-2026',
    'V2 M FOIL',
    'PPW',
    'FOIL', 'M', 'V2',
    '2026-02-21', 2, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KORONA' AND txt_first_name = 'Przemysław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-FOIL-2025-2026'),
    1, 71.34
); -- KORONA Przemysław
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'HAŚKO' AND txt_first_name = 'Sergiusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-FOIL-2025-2026'),
    2, 8.56
); -- HAŚKO Sergiusz

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
    'PEW4-V2-M-FOIL-2025-2026',
    'EVF Grand Prix 4',
    'PEW',
    'FOIL', 'M', 'V2',
    NULL, 30, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOŃCZYŁO' AND txt_first_name = 'Tomasz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-FOIL-2025-2026'),
    3, 73.49
); -- KOŃCZYŁO Tomasz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KORONA' AND txt_first_name = 'Przemysław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-FOIL-2025-2026'),
    16, 20.06
); -- KORONA Przemysław
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'BETLEJ' AND txt_first_name = 'Daniel' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-FOIL-2025-2026'),
    19, 7.58
); -- BETLEJ Daniel
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ANDERSCH' AND txt_first_name = 'Robert' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V2-M-FOIL-2025-2026'),
    26, 3.06
); -- ANDERSCH Robert

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
    'PEW6-V2-M-FOIL-2025-2026',
    'EVF Grand Prix 6',
    'PEW',
    'FOIL', 'M', 'V2',
    NULL, 23, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KORONA' AND txt_first_name = 'Przemysław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-FOIL-2025-2026'),
    3, 71.36
); -- KORONA Przemysław
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'BAZAK' AND txt_first_name = 'Jacek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V2-M-FOIL-2025-2026'),
    13, 19.92
); -- BAZAK Jacek

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
    'PEW7-V2-M-FOIL-2025-2026',
    'EVF Grand Prix 7 — Terni',
    'PEW',
    'FOIL', 'M', 'V2',
    NULL, 9, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'BAZAK' AND txt_first_name = 'Jacek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-FOIL-2025-2026'),
    6, 20.04
); -- BAZAK Jacek
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KORONA' AND txt_first_name = 'Przemysław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW7-V2-M-FOIL-2025-2026'),
    8, 13.63
); -- KORONA Przemysław

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
    'PEW8-V2-M-FOIL-2025-2026',
    'EVF Grand Prix 8 — Guildford',
    'PEW',
    'FOIL', 'M', 'V2',
    NULL, 17, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'HAŚKO' AND txt_first_name = 'Sergiusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2025-2026'),
    7, 36.35
); -- HAŚKO Sergiusz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'BAZAK' AND txt_first_name = 'Jacek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2025-2026'),
    9, 22.00
); -- BAZAK Jacek
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOŃCZYŁO' AND txt_first_name = 'Tomasz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2025-2026'),
    10, 20.18
); -- KOŃCZYŁO Tomasz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KORONA' AND txt_first_name = 'Przemysław' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2025-2026'),
    12, 17.02
); -- KORONA Przemysław
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SOKOL' AND txt_first_name = 'Vratislav' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2025-2026'),
    13, 15.64
); -- SOKOL Vratislav
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ALCSER' AND txt_first_name = 'Norbert' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2025-2026'),
    15, 13.16
); -- ALCSER Norbert
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ŻUKOWSKI' AND txt_first_name = 'Wojciech' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW8-V2-M-FOIL-2025-2026'),
    17, 1.00
); -- ŻUKOWSKI Wojciech
