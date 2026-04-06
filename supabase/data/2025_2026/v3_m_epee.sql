-- =========================================================================
-- Season 2025-2026 — V3 M EPEE — auto-exported from CERT (ADR-027)
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
    'PEW1-V3-M-EPEE-2025-2026',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'EPEE', 'M', 'V3',
    NULL, 34, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KRZEMIŃSKI' AND txt_first_name = 'Mariusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-EPEE-2025-2026'),
    6
); -- KRZEMIŃSKI Mariusz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DRAPELLA' AND txt_first_name = 'Maciej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-EPEE-2025-2026'),
    14
); -- DRAPELLA Maciej
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'HERONIMEK' AND txt_first_name = 'Leszek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-EPEE-2025-2026'),
    15
); -- HERONIMEK Leszek
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ĆWIORO' AND txt_first_name = 'Krzysztof' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-EPEE-2025-2026'),
    22
); -- ĆWIORO Krzysztof
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'WHITLEY' AND txt_first_name = 'Gary' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V3-M-EPEE-2025-2026'),
    27
); -- WHITLEY Gary

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
    'PPW1-V3-M-EPEE-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V3',
    '2025-09-28', 7, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DRAPELLA' AND txt_first_name = 'Maciej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2025-2026'),
    1
); -- DRAPELLA Maciej
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KRZEMIŃSKI' AND txt_first_name = 'Mariusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2025-2026'),
    2
); -- KRZEMIŃSKI Mariusz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'AUGUSTOWSKI' AND txt_first_name = 'Waldemar' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2025-2026'),
    3
); -- AUGUSTOWSKI Waldemar
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'TRACZ' AND txt_first_name = 'Jerzy' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2025-2026'),
    4
); -- TRACZ Jerzy
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'HERONIMEK' AND txt_first_name = 'Leszek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2025-2026'),
    5
); -- HERONIMEK Leszek
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'STOŁOWSKI' AND txt_first_name = 'Mariusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2025-2026'),
    6
); -- STOŁOWSKI Mariusz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CHUDYCKI' AND txt_first_name = 'Artur' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V3-M-EPEE-2025-2026'),
    7
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
    'PPW2-V3-M-EPEE-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V3',
    NULL, 5, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOSTRZEWA' AND txt_first_name = 'Ireneusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-EPEE-2025-2026'),
    1
); -- KOSTRZEWA Ireneusz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'AUGUSTOWSKI' AND txt_first_name = 'Waldemar' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-EPEE-2025-2026'),
    2
); -- AUGUSTOWSKI Waldemar
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DRAPELLA' AND txt_first_name = 'Maciej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-EPEE-2025-2026'),
    3
); -- DRAPELLA Maciej
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KRZEMIŃSKI' AND txt_first_name = 'Mariusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-EPEE-2025-2026'),
    4
); -- KRZEMIŃSKI Mariusz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'STOŁOWSKI' AND txt_first_name = 'Mariusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V3-M-EPEE-2025-2026'),
    5
); -- STOŁOWSKI Mariusz

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
    'PEW2-V3-M-EPEE-2025-2026',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'EPEE', 'M', 'V3',
    NULL, 38, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'WHITLEY' AND txt_first_name = 'Gary' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V3-M-EPEE-2025-2026'),
    10
); -- WHITLEY Gary
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOSTRZEWA' AND txt_first_name = 'Ireneusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V3-M-EPEE-2025-2026'),
    11
); -- KOSTRZEWA Ireneusz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'LYNCH' AND txt_first_name = 'Pat' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V3-M-EPEE-2025-2026'),
    35
); -- LYNCH Pat

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
    'PPW3-V3-M-EPEE-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V3',
    NULL, 8, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KRZEMIŃSKI' AND txt_first_name = 'Mariusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2025-2026'),
    1
); -- KRZEMIŃSKI Mariusz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOSTRZEWA' AND txt_first_name = 'Ireneusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2025-2026'),
    2
); -- KOSTRZEWA Ireneusz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DRAPELLA' AND txt_first_name = 'Maciej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2025-2026'),
    3
); -- DRAPELLA Maciej
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'AUGUSTOWSKI' AND txt_first_name = 'Waldemar' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2025-2026'),
    4
); -- AUGUSTOWSKI Waldemar
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'STOŁOWSKI' AND txt_first_name = 'Mariusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2025-2026'),
    5
); -- STOŁOWSKI Mariusz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'HERONIMEK' AND txt_first_name = 'Leszek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2025-2026'),
    6
); -- HERONIMEK Leszek
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'TRACZ' AND txt_first_name = 'Jerzy' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2025-2026'),
    7
); -- TRACZ Jerzy
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CHUDYCKI' AND txt_first_name = 'Artur' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V3-M-EPEE-2025-2026'),
    8
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
    'PEW3-V3-M-EPEE-2025-2026',
    'EVF Grand Prix 3',
    'PEW',
    'EPEE', 'M', 'V3',
    NULL, 44, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOSTRZEWA' AND txt_first_name = 'Ireneusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2025-2026'),
    3
); -- KOSTRZEWA Ireneusz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KRZEMIŃSKI' AND txt_first_name = 'Mariusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2025-2026'),
    11
); -- KRZEMIŃSKI Mariusz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SOMERS' AND txt_first_name = 'Jan' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V3-M-EPEE-2025-2026'),
    21
); -- SOMERS Jan

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
    'PPW4-V3-M-EPEE-2025-2026',
    'V3 M EPEE',
    'PPW',
    'EPEE', 'M', 'V3',
    '2026-02-21', 7, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KRZEMIŃSKI' AND txt_first_name = 'Mariusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2025-2026'),
    1
); -- KRZEMIŃSKI Mariusz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'MAŁASIŃSKI' AND txt_first_name = 'Adam' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2025-2026'),
    2
); -- MAŁASIŃSKI Adam
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DRAPELLA' AND txt_first_name = 'Maciej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2025-2026'),
    3
); -- DRAPELLA Maciej
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOSTRZEWA' AND txt_first_name = 'Ireneusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2025-2026'),
    4
); -- KOSTRZEWA Ireneusz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'STOŁOWSKI' AND txt_first_name = 'Mariusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2025-2026'),
    5
); -- STOŁOWSKI Mariusz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'HERONIMEK' AND txt_first_name = 'Leszek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2025-2026'),
    6
); -- HERONIMEK Leszek
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CHUDYCKI' AND txt_first_name = 'Artur' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V3-M-EPEE-2025-2026'),
    7
); -- CHUDYCKI Artur

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
    'PEW4-V3-M-EPEE-2025-2026',
    'EVF Grand Prix 4',
    'PEW',
    'EPEE', 'M', 'V3',
    NULL, 74, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KRZEMIŃSKI' AND txt_first_name = 'Mariusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V3-M-EPEE-2025-2026'),
    12
); -- KRZEMIŃSKI Mariusz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SOMERS' AND txt_first_name = 'Jan' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V3-M-EPEE-2025-2026'),
    32
); -- SOMERS Jan

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
    'PEW6-V3-M-EPEE-2025-2026',
    'EVF Grand Prix 6',
    'PEW',
    'EPEE', 'M', 'V3',
    NULL, 18, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOSTRZEWA' AND txt_first_name = 'Ireneusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2025-2026'),
    3
); -- KOSTRZEWA Ireneusz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DRAPELLA' AND txt_first_name = 'Maciej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2025-2026'),
    5
); -- DRAPELLA Maciej
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KRZEMIŃSKI' AND txt_first_name = 'Mariusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2025-2026'),
    7
); -- KRZEMIŃSKI Mariusz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'WHITLEY' AND txt_first_name = 'Gary' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2025-2026'),
    11
); -- WHITLEY Gary
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'HERONIMEK' AND txt_first_name = 'Leszek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2025-2026'),
    12
); -- HERONIMEK Leszek
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'MAŁASIŃSKI' AND txt_first_name = 'Adam' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2025-2026'),
    13
); -- MAŁASIŃSKI Adam
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'TRACZ' AND txt_first_name = 'Jerzy' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2025-2026'),
    14
); -- TRACZ Jerzy
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CHUDYCKI' AND txt_first_name = 'Artur' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V3-M-EPEE-2025-2026'),
    16
); -- CHUDYCKI Artur
