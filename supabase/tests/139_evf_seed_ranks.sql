-- pgt-ignore-all lint/safety: pgTAP runs this file in one rolled-back transaction on LOCAL/CI, never on CERT/PROD
-- =============================================================================
-- EVFSEED.01–16 — an event's seed follows its organiser's ranking (FR-174)
-- =============================================================================
-- tbl_evf_ranking_place keeps each ranked fencer's place and points on the EVF
-- list of one weapon, gender and category, replaced in full by every complete
-- read (fn_replace_evf_ranking_places). fn_evf_ranking_read_due says whether a
-- read day has come since the last successful read. fn_event_seed_ranks is the
-- one rule both readers use: at an event EVF organises a start takes the place
-- of the one ranked fencer of its name on the list of its weapon, gender and
-- category; at any other event our ranking, as before. fn_ftl_export_entries
-- reads it.
--
-- Plan doc/plans/seeding-by-organiser-ranking-2026-11-22.html, rev 1. Every
-- person here is invented. Everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(51);

DO $setup$
DECLARE
  v_season  INT;
  v_past    INT;
  v_evf     INT;
  v_org     INT;
  v_ev      INT;
  v_pev     INT;
  v_t       INT;
  v_f       INT;
  v_rank    INT;
BEGIN
  -- A season ending in 2099: V0 is birth years 2060–2069, V1 2050–2059, V2 2040–2049.
  v_season := fn_create_season('SEED139', '2098-09-01', '2099-06-30');
  SELECT id_organizer INTO v_evf FROM tbl_organizer WHERE txt_code = 'EVF';
  INSERT INTO tbl_organizer (txt_code, txt_name)
    VALUES ('SEED139ORG', 'Seed test organiser 139') RETURNING id_organizer INTO v_org;

  v_ev := fn_create_event('SEED139EVF', 'Seed 139 EVF event', v_season, v_evf,
                          NULL, '2099-01-15', '2099-01-16');
  -- Our registration needs a payment account (fn_assert_registration_has_account).
  UPDATE tbl_event SET txt_payee = 'SEED 139 PAYEE', txt_iban = 'PL 27 1140 2004 0000 3002 0135 5387',
                       bool_use_spws_registration = TRUE
   WHERE id_event = v_ev;

  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, enum_gender, bool_birth_year_estimated)
    VALUES ('KOWALSKA', 'Irena', 2045, 'F', FALSE) RETURNING id_fencer INTO v_f;

  INSERT INTO tbl_evf_ranking_fencer (id_evf, txt_surname, txt_first_name, enum_gender, int_category, txt_country)
  VALUES ('13900000-0000-4000-8000-000000000001', 'NOWAK', 'Anna', 'F', 2, 'POL'),
         ('13900000-0000-4000-8000-000000000002', 'SVOBODOVÁ', 'Jana', 'F', 2, 'CZE'),
         ('13900000-0000-4000-8000-000000000003', 'ŻAK', 'Ewa', 'F', 1, 'POL'),
         ('13900000-0000-4000-8000-000000000004', 'KOWALSKA', 'Irena', 'F', 2, 'POL'),
         ('13900000-0000-4000-8000-000000000005', 'WÓJCIK', 'Maria', 'F', 2, 'POL'),
         ('13900000-0000-4000-8000-000000000006', 'WÓJCIK', 'Maria', 'F', 2, 'GER'),
         ('13900000-0000-4000-8000-000000000007', 'MAZUR', 'Alex', 'M', 2, 'POL'),
         ('13900000-0000-4000-8000-000000000008', 'LIS', 'Ola', 'F', 1, 'POL'),
         ('13900000-0000-4000-8000-000000000009', 'PGTAP139LATE', 'Bogdan', 'M', 2, 'POL');

  INSERT INTO tbl_evf_ranking_place (id_evf, enum_weapon, enum_gender, int_category, int_place, num_points)
  VALUES ('13900000-0000-4000-8000-000000000001', 'EPEE', 'F', 2, 3, 100),
         ('13900000-0000-4000-8000-000000000001', 'FOIL', 'F', 2, 17, 40),
         ('13900000-0000-4000-8000-000000000002', 'EPEE', 'F', 2, 3, 100),
         ('13900000-0000-4000-8000-000000000003', 'EPEE', 'F', 1, 5, 80),
         ('13900000-0000-4000-8000-000000000004', 'EPEE', 'F', 2, 41, 10),
         ('13900000-0000-4000-8000-000000000005', 'EPEE', 'F', 2, 7, 60),
         ('13900000-0000-4000-8000-000000000006', 'EPEE', 'F', 2, 9, 50),
         ('13900000-0000-4000-8000-000000000007', 'EPEE', 'M', 2, 1, 200),
         ('13900000-0000-4000-8000-000000000008', 'EPEE', 'F', 1, 2, 150),
         ('13900000-0000-4000-8000-000000000009', 'EPEE', 'M', 2, 1, 300);

  -- The entries. ts_created orders the unranked tail of the files.
  INSERT INTO tbl_registration (id_event, id_fencer, txt_surname, txt_first_name, enum_gender,
                                int_birth_year, arr_weapons, ts_created)
  VALUES
    (v_ev, NULL, 'Dr. NOWAK', 'Anna', 'F', 2045, ARRAY['EPEE', 'FOIL']::enum_weapon_type[], '2099-01-01T05:00:00Z'),
    (v_ev, NULL, 'SVOBODOVA', 'Jana', 'F', 2046, ARRAY['EPEE']::enum_weapon_type[], '2099-01-01T04:00:00Z'),
    (v_ev, NULL, 'ZAK', 'Ewa', 'F', 2045, ARRAY['EPEE']::enum_weapon_type[], '2099-01-01T03:00:00Z'),
    (v_ev, v_f, 'KOWALSKA', 'Irena', 'F', 2045, ARRAY['EPEE', 'SABRE']::enum_weapon_type[], '2099-01-01T06:00:00Z'),
    (v_ev, NULL, 'WÓJCIK', 'Maria', 'F', 2045, ARRAY['EPEE']::enum_weapon_type[], '2099-01-01T02:00:00Z'),
    (v_ev, NULL, 'MAZUR', 'Alex', 'F', 2045, ARRAY['EPEE']::enum_weapon_type[], '2099-01-01T01:00:00Z'),
    (v_ev, NULL, 'LIS', 'Ola', 'F', 2063, ARRAY['EPEE']::enum_weapon_type[], '2099-01-01T07:00:00Z'),
    (v_ev, NULL, 'BIELSKA', 'Ewa', 'F', 2045, ARRAY['EPEE']::enum_weapon_type[], '2099-01-01T00:00:00Z');

  -- An event of another organiser in a FINISHED season, seeded by our ranking
  -- on the season's own results (as in test 76).
  v_past := fn_create_season('SEED139P', '2019-09-01', '2020-06-30');
  UPDATE tbl_season SET enum_carryover_engine = 'EVENT_CODE_MATCHING' WHERE id_season = v_past;
  v_pev := fn_create_event('SEED139PEVT', 'Seed 139 our event', v_past, v_org, NULL, '2019-10-05', '2019-10-05');
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, enum_gender, bool_birth_year_estimated)
    VALUES ('PGTAP139RANK', 'Robert', 1965, 'M', FALSE) RETURNING id_fencer INTO v_rank;
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
                              enum_age_category, enum_import_status, num_multiplier, int_participant_count)
    VALUES (v_pev, 'SEED139T', 'Seed 139 tournament', 'PPW', 'EPEE', 'M', 'V2', 'SCORED', 1.0, 8)
    RETURNING id_tournament INTO v_t;
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, enum_fencer_age_category,
                          enum_source_age_category, num_final_score)
    VALUES (v_rank, v_t, 1, 'V2', 'V2', 100.0);
  INSERT INTO tbl_registration (id_event, id_fencer, txt_surname, txt_first_name, enum_gender,
                                int_birth_year, arr_weapons, ts_created)
  VALUES (v_pev, v_rank, 'PGTAP139RANK', 'Robert', 'M', 1965, ARRAY['EPEE']::enum_weapon_type[], '2019-10-02T00:00:00Z'),
         (v_pev, NULL, 'PGTAP139LATE', 'Bogdan', 'M', 1965, ARRAY['EPEE']::enum_weapon_type[], '2019-10-01T00:00:00Z');

  INSERT INTO tbl_ftl_export_token (uuid_token, txt_label)
    VALUES ('13900000-0000-4000-8000-0000000000aa', 'pgTAP 139 live');
END $setup$;

-- ---------------------------------------------------------------------------
-- EVFSEED.01 · the table
-- ---------------------------------------------------------------------------
SELECT has_table('tbl_evf_ranking_place', 'EVFSEED.01 tbl_evf_ranking_place exists');
SELECT columns_are('tbl_evf_ranking_place',
  ARRAY['id_evf', 'enum_weapon', 'enum_gender', 'int_category', 'int_place', 'num_points', 'ts_read'],
  'EVFSEED.01 it keeps the EVF id, weapon, gender, category, place, points and when it was read; nothing else');
SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid = 'tbl_evf_ranking_place'::regclass),
  'EVFSEED.01 row security is on');
SELECT throws_ok(
  $$SET LOCAL ROLE anon;
    SELECT set_config('request.jwt.claims', '{"role":"anon"}', TRUE);
    SELECT count(*) FROM tbl_evf_ranking_place$$,
  '42501', NULL, 'EVFSEED.01 a visitor cannot read it');
RESET ROLE;
SELECT throws_ok(
  $$SET LOCAL ROLE authenticated;
    SELECT set_config('request.jwt.claims', '{"role":"authenticated","sub":"test-admin"}', TRUE);
    SELECT count(*) FROM tbl_evf_ranking_place$$,
  '42501', NULL, 'EVFSEED.01 a signed-in user cannot read it either');
RESET ROLE;
-- The role tests leave an empty claim, which the event audit trigger cannot read.
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{}', TRUE); END $$;

-- ---------------------------------------------------------------------------
-- EVFSEED.08–13 · an event EVF organises
-- ---------------------------------------------------------------------------
SELECT is((SELECT ROW(int_rank, num_rank_points)::TEXT FROM (SELECT r.txt_surname, s.* FROM fn_event_seed_ranks((SELECT id_event FROM tbl_event WHERE txt_code = 'SEED139EVF')) s JOIN tbl_registration r USING (id_registration)) t WHERE txt_surname = 'Dr. NOWAK' AND enum_weapon = 'EPEE'),
  ROW(3, 100::NUMERIC)::TEXT,
  'EVFSEED.08 a titled surname takes the place and points of the one ranked fencer of its name');
SELECT is((SELECT int_rank FROM (SELECT r.txt_surname, s.* FROM fn_event_seed_ranks((SELECT id_event FROM tbl_event WHERE txt_code = 'SEED139EVF')) s JOIN tbl_registration r USING (id_registration)) t WHERE txt_surname = 'SVOBODOVA'), 3,
  'EVFSEED.08 a name typed without its accents matches');
SELECT is((SELECT int_rank FROM (SELECT r.txt_surname, s.* FROM fn_event_seed_ranks((SELECT id_event FROM tbl_event WHERE txt_code = 'SEED139EVF')) s JOIN tbl_registration r USING (id_registration)) t WHERE txt_surname = 'KOWALSKA' AND enum_weapon = 'EPEE'), 41,
  'EVFSEED.08 a linked entry matches by name too');

SELECT is((SELECT int_rank FROM (SELECT r.txt_surname, s.* FROM fn_event_seed_ranks((SELECT id_event FROM tbl_event WHERE txt_code = 'SEED139EVF')) s JOIN tbl_registration r USING (id_registration)) t WHERE txt_surname = 'Dr. NOWAK' AND enum_weapon = 'FOIL'), 17,
  'EVFSEED.09 a fencer ranked in two weapons gets each weapon''s own place');
SELECT ok((SELECT int_rank IS NULL AND num_rank_points IS NULL FROM (SELECT r.txt_surname, s.* FROM fn_event_seed_ranks((SELECT id_event FROM tbl_event WHERE txt_code = 'SEED139EVF')) s JOIN tbl_registration r USING (id_registration)) t WHERE txt_surname = 'KOWALSKA' AND enum_weapon = 'SABRE'),
  'EVFSEED.09 a weapon the fencer is not ranked in gives no place');

SELECT ok((SELECT int_rank IS NULL FROM (SELECT r.txt_surname, s.* FROM fn_event_seed_ranks((SELECT id_event FROM tbl_event WHERE txt_code = 'SEED139EVF')) s JOIN tbl_registration r USING (id_registration)) t WHERE txt_surname = 'WÓJCIK'),
  'EVFSEED.10 two ranked namesakes on the list give no place');
SELECT ok((SELECT int_rank IS NULL FROM (SELECT r.txt_surname, s.* FROM fn_event_seed_ranks((SELECT id_event FROM tbl_event WHERE txt_code = 'SEED139EVF')) s JOIN tbl_registration r USING (id_registration)) t WHERE txt_surname = 'ZAK'),
  'EVFSEED.10 a place only in the neighbouring category gives none');
SELECT ok((SELECT int_rank IS NULL FROM (SELECT r.txt_surname, s.* FROM fn_event_seed_ranks((SELECT id_event FROM tbl_event WHERE txt_code = 'SEED139EVF')) s JOIN tbl_registration r USING (id_registration)) t WHERE txt_surname = 'MAZUR'),
  'EVFSEED.10 a ranked fencer of the other gender gives none');
SELECT ok((SELECT int_rank IS NULL FROM (SELECT r.txt_surname, s.* FROM fn_event_seed_ranks((SELECT id_event FROM tbl_event WHERE txt_code = 'SEED139EVF')) s JOIN tbl_registration r USING (id_registration)) t WHERE txt_surname = 'BIELSKA'),
  'EVFSEED.10 a name not on the ranking gives none');

SELECT is((SELECT count(*)::INT FROM (SELECT r.txt_surname, s.* FROM fn_event_seed_ranks((SELECT id_event FROM tbl_event WHERE txt_code = 'SEED139EVF')) s JOIN tbl_registration r USING (id_registration)) t WHERE txt_surname = 'LIS'), 0,
  'EVFSEED.11 a V0 start has no rank row (EVF ranks 40 and over)');
SELECT is(
  (SELECT ROW(enum_age_category, int_rank)::TEXT FROM fn_ftl_export_entries(
     (SELECT id_event FROM tbl_event WHERE txt_code = 'SEED139EVF'), '13900000-0000-4000-8000-0000000000aa')
    WHERE txt_surname = 'LIS'),
  ROW('V0'::enum_age_category, NULL::INT)::TEXT,
  'EVFSEED.11 and it stays in the export, unranked');

SELECT is(
  (SELECT array_agg(txt_surname ORDER BY int_seed_order) FROM (SELECT r.txt_surname, s.* FROM fn_event_seed_ranks((SELECT id_event FROM tbl_event WHERE txt_code = 'SEED139EVF')) s JOIN tbl_registration r USING (id_registration)) t
    WHERE enum_weapon = 'EPEE' AND enum_age_category = 'V2' AND int_seed_order IS NOT NULL),
  ARRAY['Dr. NOWAK', 'SVOBODOVA', 'KOWALSKA'],
  'EVFSEED.12 seed order: place, then the name for a shared place');
SELECT is(
  (SELECT array_agg(int_seed_order ORDER BY int_seed_order) FROM (SELECT r.txt_surname, s.* FROM fn_event_seed_ranks((SELECT id_event FROM tbl_event WHERE txt_code = 'SEED139EVF')) s JOIN tbl_registration r USING (id_registration)) t
    WHERE enum_weapon = 'EPEE' AND enum_age_category = 'V2' AND int_seed_order IS NOT NULL),
  ARRAY[1, 2, 3], 'EVFSEED.12 numbered from 1 among the ranked');
SELECT is((SELECT count(*)::INT FROM (SELECT r.txt_surname, s.* FROM fn_event_seed_ranks((SELECT id_event FROM tbl_event WHERE txt_code = 'SEED139EVF')) s JOIN tbl_registration r USING (id_registration)) t WHERE int_rank IS NULL AND int_seed_order IS NOT NULL), 0,
  'EVFSEED.12 an unranked start has no seed order');
SELECT is(
  (SELECT array_agg(txt_surname ORDER BY int_order) FROM fn_ftl_export_entries(
     (SELECT id_event FROM tbl_event WHERE txt_code = 'SEED139EVF'), '13900000-0000-4000-8000-0000000000aa')
    WHERE enum_weapon = 'EPEE' AND enum_age_category = 'V2'),
  ARRAY['Dr. NOWAK', 'SVOBODOVA', 'KOWALSKA', 'BIELSKA', 'MAZUR', 'WÓJCIK', 'ZAK'],
  'EVFSEED.12 the export: the ranked in seed order, then the rest in the order they entered');

SELECT is((SELECT DISTINCT txt_ranking FROM (SELECT r.txt_surname, s.* FROM fn_event_seed_ranks((SELECT id_event FROM tbl_event WHERE txt_code = 'SEED139EVF')) s JOIN tbl_registration r USING (id_registration)) t), 'EVF',
  'EVFSEED.13 an EVF event is seeded by the EVF ranking');
SELECT is((SELECT DISTINCT ts_ranking_read FROM (SELECT r.txt_surname, s.* FROM fn_event_seed_ranks((SELECT id_event FROM tbl_event WHERE txt_code = 'SEED139EVF')) s JOIN tbl_registration r USING (id_registration)) t), (SELECT max(ts_read) FROM tbl_evf_ranking_place),
  'EVFSEED.13 with the time the places were read');

-- ---------------------------------------------------------------------------
-- EVFSEED.14 · any other organiser: our ranking, as before
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT ROW(s.int_rank, s.int_seed_order, s.txt_ranking, s.ts_ranking_read)::TEXT
     FROM fn_event_seed_ranks((SELECT id_event FROM tbl_event WHERE txt_code = 'SEED139PEVT')) s
     JOIN tbl_registration r USING (id_registration) WHERE r.txt_surname = 'PGTAP139RANK'),
  ROW(1, 1, 'SPWS', NULL::TIMESTAMPTZ)::TEXT,
  'EVFSEED.14 another organiser''s event is seeded by our ranking, with no read time');
SELECT ok(
  (SELECT s.int_rank IS NULL
     FROM fn_event_seed_ranks((SELECT id_event FROM tbl_event WHERE txt_code = 'SEED139PEVT')) s
     JOIN tbl_registration r USING (id_registration) WHERE r.txt_surname = 'PGTAP139LATE'),
  'EVFSEED.14 an EVF place stored for a fencer of the same name changes nothing there');
SELECT is(
  (SELECT array_agg(txt_surname ORDER BY int_order) FROM fn_ftl_export_entries(
     (SELECT id_event FROM tbl_event WHERE txt_code = 'SEED139PEVT'), '13900000-0000-4000-8000-0000000000aa')),
  ARRAY['PGTAP139RANK', 'PGTAP139LATE'],
  'EVFSEED.14 the export orders it as before: ranked first, then the rest');

-- ---------------------------------------------------------------------------
-- EVFSEED.15 · the export's shape and token
-- ---------------------------------------------------------------------------
SELECT is(
  pg_get_function_result('fn_ftl_export_entries(integer,uuid)'::regprocedure),
  'TABLE(txt_surname text, txt_first_name text, enum_gender enum_gender_type, enum_age_category enum_age_category, '
  'enum_weapon enum_weapon_type, int_order integer, int_rank integer, num_rank_points numeric, txt_country text, '
  'txt_ranking text, ts_ranking_read timestamp with time zone)',
  'EVFSEED.15 the export keeps its nine columns in order and adds the ranking and its read time');
SELECT is(
  (SELECT DISTINCT txt_ranking FROM fn_ftl_export_entries(
     (SELECT id_event FROM tbl_event WHERE txt_code = 'SEED139EVF'), '13900000-0000-4000-8000-0000000000aa')),
  'EVF', 'EVFSEED.15 the export names the ranking');
SELECT is(
  (SELECT count(*)::INT FROM fn_ftl_export_entries(
     (SELECT id_event FROM tbl_event WHERE txt_code = 'SEED139PEVT'), '13900000-0000-4000-8000-0000000000aa')
    WHERE txt_ranking = 'SPWS' AND ts_ranking_read IS NULL),
  2, 'EVFSEED.15 an event of ours names SPWS and no read time');
SELECT is_empty(
  $$SELECT 1 FROM fn_ftl_export_entries((SELECT id_event FROM tbl_event WHERE txt_code = 'SEED139EVF'),
                                         '13900000-0000-4000-8000-0000000000ff')$$,
  'EVFSEED.15 an unknown token still returns nothing');

-- ---------------------------------------------------------------------------
-- EVFSEED.16 · nothing new for a visitor
-- ---------------------------------------------------------------------------
SELECT ok(NOT has_function_privilege('anon', 'fn_event_seed_ranks(integer)', 'EXECUTE'),
  'EVFSEED.16 a visitor cannot call fn_event_seed_ranks');
SELECT ok(NOT has_function_privilege('anon', 'fn_replace_evf_ranking_places(jsonb)', 'EXECUTE'),
  'EVFSEED.16 a visitor cannot call fn_replace_evf_ranking_places');
SELECT ok(NOT has_function_privilege('anon', 'fn_evf_ranking_read_due(date)', 'EXECUTE'),
  'EVFSEED.16 a visitor cannot call fn_evf_ranking_read_due');
SELECT ok(NOT has_function_privilege('authenticated', 'fn_replace_evf_ranking_places(jsonb)', 'EXECUTE'),
  'EVFSEED.16 nor can a signed-in user replace the places');

-- ---------------------------------------------------------------------------
-- EVFSEED.02–03 · the replacement, all or nothing
-- ---------------------------------------------------------------------------
INSERT INTO tbl_evf_ranking_fencer (id_evf, txt_surname, txt_first_name, enum_gender, int_category, txt_country)
SELECT ('13900000-0000-4000-8000-0000000001' || lpad(i::TEXT, 2, '0'))::UUID,
       'PLACE' || i, 'Test', CASE WHEN i <= 12 THEN 'M' ELSE 'F' END::enum_gender_type,
       ((i - 1) % 4 + 1)::SMALLINT, 'POL'
  FROM generate_series(1, 24) i;

SELECT is(
  fn_replace_evf_ranking_places((SELECT jsonb_agg(jsonb_build_object(
    'id', id, 'weapon', weapon, 'gender', gender, 'category', category, 'place', 1, 'points', 10.5))
    FROM (SELECT i, ('13900000-0000-4000-8000-0000000001' || lpad(i::TEXT, 2, '0')) AS id, (ARRAY['FOIL', 'EPEE', 'SABRE'])[((i - 1) / 4) % 3 + 1] AS weapon, CASE WHEN i <= 12 THEN 'M' ELSE 'F' END AS gender, (i - 1) % 4 + 1 AS category FROM generate_series(1, 24) i) l)),
  24, 'EVFSEED.02 a 24-list payload is stored, and the function says how many rows');
SELECT is((SELECT count(*)::INT FROM tbl_evf_ranking_place), 24,
  'EVFSEED.02 and it replaced every earlier place');
SELECT is(
  fn_replace_evf_ranking_places((SELECT jsonb_agg(jsonb_build_object(
    'id', id, 'weapon', weapon, 'gender', gender, 'category', category, 'place', 2, 'points', 5))
    FROM (SELECT i, ('13900000-0000-4000-8000-0000000001' || lpad(i::TEXT, 2, '0')) AS id, (ARRAY['FOIL', 'EPEE', 'SABRE'])[((i - 1) / 4) % 3 + 1] AS weapon, CASE WHEN i <= 12 THEN 'M' ELSE 'F' END AS gender, (i - 1) % 4 + 1 AS category FROM generate_series(1, 24) i) l)),
  24, 'EVFSEED.02 a second payload is stored');
SELECT is((SELECT count(*)::INT FROM tbl_evf_ranking_place WHERE int_place = 1), 0,
  'EVFSEED.02 and only its rows remain');

SELECT throws_ok(
  $$SELECT fn_replace_evf_ranking_places((SELECT jsonb_agg(jsonb_build_object(
      'id', id, 'weapon', weapon, 'gender', gender, 'category', category, 'place', 3, 'points', 1))
      FROM (SELECT i, ('13900000-0000-4000-8000-0000000001' || lpad(i::TEXT, 2, '0')) AS id, (ARRAY['FOIL', 'EPEE', 'SABRE'])[((i - 1) / 4) % 3 + 1] AS weapon, CASE WHEN i <= 12 THEN 'M' ELSE 'F' END AS gender, (i - 1) % 4 + 1 AS category FROM generate_series(1, 24) i) l WHERE i > 1))$$,
  'P0001', 'EVF_PLACES_INCOMPLETE: 23 of 24 lists',
  'EVFSEED.03 a payload of 23 lists is refused');
SELECT throws_ok($$SELECT fn_replace_evf_ranking_places('[]'::JSONB)$$,
  'P0001', 'EVF_PLACES_INCOMPLETE: 0 of 24 lists', 'EVFSEED.03 an empty payload is refused');
SELECT throws_ok($$SELECT fn_replace_evf_ranking_places(NULL)$$,
  'P0001', 'EVF_PLACES_INCOMPLETE: 0 of 24 lists', 'EVFSEED.03 NULL is refused');
SELECT is((SELECT count(*)::INT FROM tbl_evf_ranking_place WHERE int_place = 2), 24,
  'EVFSEED.03 a refused payload leaves the stored places untouched');

-- ---------------------------------------------------------------------------
-- EVFSEED.05–07 · is a read due?
-- ---------------------------------------------------------------------------
-- The last read is set inside the fixture season, so no real event counts.
UPDATE tbl_evf_ranking_place SET ts_read = '2099-04-05T06:00:00Z';

DO $due$
DECLARE
  v_season INT := (SELECT id_season FROM tbl_season WHERE txt_code = 'SEED139');
  v_evf    INT := (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF');
  v_org    INT := (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SEED139ORG');
  v_e      INT;
BEGIN
  PERFORM fn_create_event('SEED139DUEA', 'Seed 139 due A', v_season, v_evf, NULL, '2099-04-10', '2099-04-11');
  PERFORM fn_create_event('SEED139DUED', 'Seed 139 due D', v_season, v_org, NULL, '2099-04-20', '2099-04-21');
  v_e := fn_create_event('SEED139DUEE', 'Seed 139 due E', v_season, v_evf, NULL, '2099-04-22', '2099-04-23');
  UPDATE tbl_event SET enum_status = 'CANCELLED' WHERE id_event = v_e;
END $due$;

SELECT is(fn_evf_ranking_read_due('2099-04-17'), NULL,
  'EVFSEED.05 six days after an EVF event no read is due');
SELECT is(fn_evf_ranking_read_due('2099-04-18'), '7 days after SEED139DUEA',
  'EVFSEED.05 seven days after it a read is due, and the reason names it');
UPDATE tbl_evf_ranking_place SET ts_read = '2099-04-18T06:00:00Z';
SELECT is(fn_evf_ranking_read_due('2099-04-19'), NULL,
  'EVFSEED.05 once a read is stored on the read day, it is not due again');

SELECT is(fn_evf_ranking_read_due('2099-04-30'), NULL,
  'EVFSEED.07 another organiser''s event and a cancelled EVF event make no read due');
SELECT is(fn_evf_ranking_read_due('2099-05-20'), 'the last read is older than 31 days',
  'EVFSEED.07 a last read older than 31 days makes one due');

DO $due2$
BEGIN
  PERFORM fn_create_event('SEED139DUEB', 'Seed 139 due B',
                          (SELECT id_season FROM tbl_season WHERE txt_code = 'SEED139'),
                          (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
                          NULL, '2099-05-10', '2099-05-11');
END $due2$;

SELECT is(fn_evf_ranking_read_due('2099-05-09'), NULL,
  'EVFSEED.06 the day before an EVF event without our registration no read is due');
UPDATE tbl_event SET txt_payee = 'SEED 139 PAYEE', txt_iban = 'PL 27 1140 2004 0000 3002 0135 5387',
                     bool_use_spws_registration = TRUE
 WHERE txt_code = 'SEED139DUEB';
SELECT is(fn_evf_ranking_read_due('2099-05-09'), 'the day before SEED139DUEB',
  'EVFSEED.06 the day before an EVF event with our registration a read is due');
SELECT is(fn_evf_ranking_read_due('2099-05-11'), 'the day before SEED139DUEB',
  'EVFSEED.06 still due on the event''s days while no read has succeeded');
SELECT is(fn_evf_ranking_read_due('2099-05-12'), NULL,
  'EVFSEED.06 not after the event''s last day');

-- ---------------------------------------------------------------------------
-- EVFSEED.04 · nothing stored yet
-- ---------------------------------------------------------------------------
DELETE FROM tbl_evf_ranking_place;
SELECT is(fn_evf_ranking_read_due(), 'no places stored yet',
  'EVFSEED.04 with no place stored a read is due');

SELECT * FROM finish();
ROLLBACK;
