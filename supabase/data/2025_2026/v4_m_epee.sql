-- =========================================================================
-- Season 2025-2026 — V4 M EPEE — auto-exported from CERT (ADR-027)
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
    'PEW1-V4-M-EPEE-2025-2026',
    'EVF Grand Prix 1 — Budapeszt',
    'PEW',
    'EPEE', 'M', 'V4',
    NULL, 17, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SZCZĘSNY' AND txt_first_name = 'Jacek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V4-M-EPEE-2025-2026'),
    6
); -- SZCZĘSNY Jacek
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SOBIERAJ' AND txt_first_name = 'Wojciech' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V4-M-EPEE-2025-2026'),
    8
); -- SOBIERAJ Wojciech
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOLLAR' AND txt_first_name = 'Gabriel' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V4-M-EPEE-2025-2026'),
    12
); -- KOLLAR Gabriel
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'LYNCH' AND txt_first_name = 'Pat' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW1-V4-M-EPEE-2025-2026'),
    14
); -- LYNCH Pat

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
    'PPW1-V4-M-EPEE-2025-2026',
    'I Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V4',
    '2025-09-28', 8, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SZYMKOWIAK' AND txt_first_name = 'Krzysztof' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2025-2026'),
    1
); -- SZYMKOWIAK Krzysztof
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SZCZĘSNY' AND txt_first_name = 'Jacek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2025-2026'),
    2
); -- SZCZĘSNY Jacek
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SOBIERAJ' AND txt_first_name = 'Wojciech' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2025-2026'),
    3
); -- SOBIERAJ Wojciech
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KIERSZNICKI' AND txt_first_name = 'Ryszard' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2025-2026'),
    4
); -- KIERSZNICKI Ryszard
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ZYLKA' AND txt_first_name = 'Henryk' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2025-2026'),
    5
); -- ZYLKA Henryk
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'JUSZKIEWICZ' AND txt_first_name = 'Piotr' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2025-2026'),
    6
); -- JUSZKIEWICZ Piotr
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'FURMANIAK' AND txt_first_name = 'Andrzej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2025-2026'),
    7
); -- FURMANIAK Andrzej
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NOWAKOWSKI' AND txt_first_name = 'Andrzej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V4-M-EPEE-2025-2026'),
    8
); -- NOWAKOWSKI Andrzej

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
    'PPW2-V4-M-EPEE-2025-2026',
    'II Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V4',
    NULL, 5, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SZCZĘSNY' AND txt_first_name = 'Jacek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V4-M-EPEE-2025-2026'),
    1
); -- SZCZĘSNY Jacek
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SOBIERAJ' AND txt_first_name = 'Wojciech' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V4-M-EPEE-2025-2026'),
    2
); -- SOBIERAJ Wojciech
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KIERSZNICKI' AND txt_first_name = 'Ryszard' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V4-M-EPEE-2025-2026'),
    3
); -- KIERSZNICKI Ryszard
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ADAMCZEWSKI' AND txt_first_name = 'Wojciech' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V4-M-EPEE-2025-2026'),
    4
); -- ADAMCZEWSKI Wojciech
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'FURMANIAK' AND txt_first_name = 'Andrzej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW2-V4-M-EPEE-2025-2026'),
    5
); -- FURMANIAK Andrzej

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
    'PEW2-V4-M-EPEE-2025-2026',
    'EVF Grand Prix 2 — Madryt',
    'PEW',
    'EPEE', 'M', 'V4',
    NULL, 38, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'WHITLEY' AND txt_first_name = 'Gary' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V4-M-EPEE-2025-2026'),
    10
); -- WHITLEY Gary
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOSTRZEWA' AND txt_first_name = 'Ireneusz' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V4-M-EPEE-2025-2026'),
    11
); -- KOSTRZEWA Ireneusz
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'LYNCH' AND txt_first_name = 'Pat' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW2-V4-M-EPEE-2025-2026'),
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
    'PPW3-V4-M-EPEE-2025-2026',
    'III Puchar Polski Weteranów',
    'PPW',
    'EPEE', 'M', 'V4',
    NULL, 6, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SOBIERAJ' AND txt_first_name = 'Wojciech' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V4-M-EPEE-2025-2026'),
    1
); -- SOBIERAJ Wojciech
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ADAMCZEWSKI' AND txt_first_name = 'Wojciech' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V4-M-EPEE-2025-2026'),
    2
); -- ADAMCZEWSKI Wojciech
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SZCZĘSNY' AND txt_first_name = 'Jacek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V4-M-EPEE-2025-2026'),
    3
); -- SZCZĘSNY Jacek
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KIERSZNICKI' AND txt_first_name = 'Ryszard' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V4-M-EPEE-2025-2026'),
    4
); -- KIERSZNICKI Ryszard
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DONKE' AND txt_first_name = 'Ryszard' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V4-M-EPEE-2025-2026'),
    5
); -- DONKE Ryszard
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'BORKOWSKI' AND txt_first_name = 'Andrzej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V4-M-EPEE-2025-2026'),
    6
); -- BORKOWSKI Andrzej

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
    'PEW3-V4-M-EPEE-2025-2026',
    'EVF Grand Prix 3',
    'PEW',
    'EPEE', 'M', 'V4',
    '2026-10-01', 19, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SOBIERAJ' AND txt_first_name = 'Wojciech' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW3-V4-M-EPEE-2025-2026'),
    11
); -- SOBIERAJ Wojciech

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
    'PPW4-V4-M-EPEE-2025-2026',
    'V4 M EPEE',
    'PPW',
    'EPEE', 'M', 'V4',
    '2026-02-21', 6, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ADAMCZEWSKI' AND txt_first_name = 'Wojciech' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-EPEE-2025-2026'),
    1
); -- ADAMCZEWSKI Wojciech
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SZCZĘSNY' AND txt_first_name = 'Jacek' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-EPEE-2025-2026'),
    2
); -- SZCZĘSNY Jacek
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SOBIERAJ' AND txt_first_name = 'Wojciech' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-EPEE-2025-2026'),
    3
); -- SOBIERAJ Wojciech
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KIERSZNICKI' AND txt_first_name = 'Ryszard' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-EPEE-2025-2026'),
    4
); -- KIERSZNICKI Ryszard
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'FURMANIAK' AND txt_first_name = 'Andrzej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-EPEE-2025-2026'),
    5
); -- FURMANIAK Andrzej
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NOWAKOWSKI' AND txt_first_name = 'Andrzej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V4-M-EPEE-2025-2026'),
    6
); -- NOWAKOWSKI Andrzej

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
    'PEW4-V4-M-EPEE-2025-2026',
    'EVF Grand Prix 4',
    'PEW',
    'EPEE', 'M', 'V4',
    NULL, 22, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SOBIERAJ' AND txt_first_name = 'Wojciech' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW4-V4-M-EPEE-2025-2026'),
    13
); -- SOBIERAJ Wojciech

-- ---- PEW5-2025-2026: EVF Circuit Stockholm ----
INSERT INTO tbl_event (txt_code, txt_name, txt_location, id_season, id_organizer, enum_status)
SELECT
    'PEW5-2025-2026',
    'EVF Circuit Stockholm',
    'Stockholm',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW5-2025-2026');
INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results,
    enum_import_status
) VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW5-2025-2026'),
    'PEW5-V4-M-EPEE-2025-2026',
    'EVF Grand Prix 5',
    'PEW',
    'EPEE', 'M', 'V4',
    NULL, 9, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GRODNER' AND txt_first_name = 'Michał' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V4-M-EPEE-2025-2026'),
    4
); -- GRODNER Michał
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOLLAR' AND txt_first_name = 'Gabriel' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW5-V4-M-EPEE-2025-2026'),
    5
); -- KOLLAR Gabriel

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
    'PEW6-V4-M-EPEE-2025-2026',
    'EVF Grand Prix 6',
    'PEW',
    'EPEE', 'M', 'V4',
    NULL, 13, NULL,
    'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ADAMCZEWSKI' AND txt_first_name = 'Wojciech' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2025-2026'),
    1
); -- ADAMCZEWSKI Wojciech
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ZYLKA' AND txt_first_name = 'Henryk' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2025-2026'),
    2
); -- ZYLKA Henryk
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SOBIERAJ' AND txt_first_name = 'Wojciech' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2025-2026'),
    4
); -- SOBIERAJ Wojciech
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOLLAR' AND txt_first_name = 'Gabriel' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2025-2026'),
    5
); -- KOLLAR Gabriel
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'BORKOWSKI' AND txt_first_name = 'Andrzej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2025-2026'),
    6
); -- BORKOWSKI Andrzej
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'LYNCH' AND txt_first_name = 'Pat' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2025-2026'),
    7
); -- LYNCH Pat
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DROBCZYK' AND txt_first_name = 'Paweł' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2025-2026'),
    10
); -- DROBCZYK Paweł
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KIERSZNICKI' AND txt_first_name = 'Ryszard' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2025-2026'),
    11
); -- KIERSZNICKI Ryszard
INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
VALUES (
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NOWAKOWSKI' AND txt_first_name = 'Andrzej' LIMIT 1),
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PEW6-V4-M-EPEE-2025-2026'),
    13
); -- NOWAKOWSKI Andrzej
