-- pgt-ignore-all lint/safety: pgTAP runs this file in one rolled-back transaction on LOCAL/CI, never on CERT/PROD
-- =============================================================================
-- ELRANK.01–06 — the entry list may show the ranking place, switched per event (FR-175)
-- =============================================================================
-- tbl_event.bool_show_seed is an administrator's switch, per environment: the
-- CERT→PROD mirror never writes it. fn_registration_entry_ranks is what the
-- public entry list reads: each start's place in the organiser's ranking and
-- its seed order (fn_event_seed_ranks, FR-174), only for an event whose switch
-- and our registration are both on, and never a birth year, points or a fencer id.
--
-- Plan doc/plans/seeding-by-organiser-ranking-2026-11-22.html, rev 1, release 2.
-- Every person here is invented. Everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(22);

DO $setup$
DECLARE
  v_season INT;
  v_evf    INT;
  v_org    INT;
  v_ev     INT;
  v_ours   INT;
  v_off    INT;
BEGIN
  -- A season ending in 2099: V2 is birth years 2040–2049.
  v_season := fn_create_season('RANK140', '2098-09-01', '2099-06-30');
  SELECT id_organizer INTO v_evf FROM tbl_organizer WHERE txt_code = 'EVF';
  INSERT INTO tbl_organizer (txt_code, txt_name)
    VALUES ('RANK140ORG', 'Rank test organiser 140') RETURNING id_organizer INTO v_org;

  v_ev   := fn_create_event('RANK140EVF', 'Rank 140 EVF event', v_season, v_evf, NULL, '2099-01-15', '2099-01-16');
  v_ours := fn_create_event('RANK140OUR', 'Rank 140 our event', v_season, v_org, NULL, '2099-02-15', '2099-02-16');
  v_off  := fn_create_event('RANK140OFF', 'Rank 140 registration off', v_season, v_evf, NULL, '2099-03-15', '2099-03-16');
  -- Our registration needs a payment account (fn_assert_registration_has_account).
  UPDATE tbl_event SET txt_payee = 'RANK 140 PAYEE', txt_iban = 'PL 27 1140 2004 0000 3002 0135 5387',
                       bool_use_spws_registration = TRUE
   WHERE id_event IN (v_ev, v_ours, v_off);

  INSERT INTO tbl_evf_ranking_fencer (id_evf, txt_surname, txt_first_name, enum_gender, int_category, txt_country)
  VALUES ('14000000-0000-4000-8000-000000000001', 'NOWAK', 'Anna', 'F', 2, 'POL'),
         ('14000000-0000-4000-8000-000000000002', 'KOWALSKA', 'Irena', 'F', 2, 'POL');
  INSERT INTO tbl_evf_ranking_place (id_evf, enum_weapon, enum_gender, int_category, int_place, num_points)
  VALUES ('14000000-0000-4000-8000-000000000001', 'EPEE', 'F', 2, 3, 100),
         ('14000000-0000-4000-8000-000000000002', 'EPEE', 'F', 2, 41, 10);

  INSERT INTO tbl_registration (id_event, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons)
  VALUES (v_ev,   'NOWAK', 'Anna', 'F', 2045, ARRAY['EPEE', 'FOIL']::enum_weapon_type[]),
         (v_ev,   'KOWALSKA', 'Irena', 'F', 2045, ARRAY['EPEE']::enum_weapon_type[]),
         (v_ev,   'BIELSKA', 'Ewa', 'F', 2045, ARRAY['EPEE']::enum_weapon_type[]),
         (v_ours, 'NOWAK', 'Anna', 'F', 2045, ARRAY['EPEE']::enum_weapon_type[]),
         (v_off,  'NOWAK', 'Anna', 'F', 2045, ARRAY['EPEE']::enum_weapon_type[]);
END $setup$;

-- ---------------------------------------------------------------------------
-- ELRANK.01 · the switch, and the mirror never writes it
-- ---------------------------------------------------------------------------
SELECT has_column('tbl_event', 'bool_show_seed', 'ELRANK.01 tbl_event.bool_show_seed exists');
SELECT col_type_is('tbl_event', 'bool_show_seed', 'boolean', 'ELRANK.01 it is a boolean');
SELECT col_not_null('tbl_event', 'bool_show_seed', 'ELRANK.01 it is never null');
SELECT col_default_is('tbl_event', 'bool_show_seed', 'false', 'ELRANK.01 it is off by default');

UPDATE tbl_event SET bool_show_seed = TRUE WHERE txt_code = 'RANK140EVF';
SELECT fn_mirror_events_to_prod('[]'::JSONB,
  jsonb_build_array(jsonb_build_object('id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'RANK140EVF'),
                                       'txt_name', 'Rank 140 EVF event, renamed on CERT',
                                       'bool_show_seed', false)),
  '[]'::JSONB);
SELECT is((SELECT txt_name FROM tbl_event WHERE txt_code = 'RANK140EVF'), 'Rank 140 EVF event, renamed on CERT',
  'ELRANK.01 (the mirror did update this event)');
SELECT is((SELECT bool_show_seed FROM tbl_event WHERE txt_code = 'RANK140EVF'), TRUE,
  'ELRANK.01 the CERT→PROD mirror does not switch it off');
SELECT fn_mirror_events_to_prod('[]'::JSONB,
  jsonb_build_array(jsonb_build_object('id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'RANK140OUR'),
                                       'txt_name', 'Rank 140 our event, renamed on CERT',
                                       'bool_show_seed', true)),
  '[]'::JSONB);
SELECT is((SELECT txt_name FROM tbl_event WHERE txt_code = 'RANK140OUR'), 'Rank 140 our event, renamed on CERT',
  'ELRANK.01 (the mirror did update that event too)');
SELECT is((SELECT bool_show_seed FROM tbl_event WHERE txt_code = 'RANK140OUR'), FALSE,
  'ELRANK.01 nor on: each environment keeps its own');
UPDATE tbl_event SET bool_show_seed = FALSE WHERE txt_code = 'RANK140EVF';

-- ---------------------------------------------------------------------------
-- ELRANK.02 · switch off: nothing
-- ---------------------------------------------------------------------------
SELECT is((SELECT count(*)::INT FROM fn_registration_entry_ranks((SELECT id_event FROM tbl_event WHERE txt_code = 'RANK140EVF'))), 0,
  'ELRANK.02 an EVF event whose switch is off gives no row');
SELECT is((SELECT count(*)::INT FROM fn_registration_entry_ranks((SELECT id_event FROM tbl_event WHERE txt_code = 'RANK140OUR'))), 0,
  'ELRANK.02 an event of ours whose switch is off gives no row');

-- ---------------------------------------------------------------------------
-- ELRANK.03 · switch on: one row per start
-- ---------------------------------------------------------------------------
UPDATE tbl_event SET bool_show_seed = TRUE WHERE txt_code IN ('RANK140EVF', 'RANK140OUR', 'RANK140OFF');

SELECT is((SELECT count(*)::INT FROM fn_registration_entry_ranks((SELECT id_event FROM tbl_event WHERE txt_code = 'RANK140EVF'))), 4,
  'ELRANK.03 one row per start (an entry in two weapons gives two)');
SELECT is((SELECT ROW(s.int_rank, s.int_seed_order, s.txt_ranking, s.enum_age_category::TEXT)::TEXT
             FROM fn_registration_entry_ranks((SELECT id_event FROM tbl_event WHERE txt_code = 'RANK140EVF')) s
             JOIN tbl_registration r USING (id_registration)
            WHERE r.txt_surname = 'NOWAK' AND s.enum_weapon = 'EPEE'),
  ROW(3, 1, 'EVF', 'V2')::TEXT,
  'ELRANK.03 a ranked start carries its EVF place, its seed order, the ranking and its category');
SELECT ok((SELECT s.ts_ranking_read IS NOT NULL
             FROM fn_registration_entry_ranks((SELECT id_event FROM tbl_event WHERE txt_code = 'RANK140EVF')) s
             JOIN tbl_registration r USING (id_registration)
            WHERE r.txt_surname = 'NOWAK' AND s.enum_weapon = 'EPEE'),
  'ELRANK.03 and when the EVF ranking was read');
SELECT is((SELECT ROW(s.int_rank, s.int_seed_order)::TEXT
             FROM fn_registration_entry_ranks((SELECT id_event FROM tbl_event WHERE txt_code = 'RANK140EVF')) s
             JOIN tbl_registration r USING (id_registration)
            WHERE r.txt_surname = 'BIELSKA'),
  ROW(NULL::INT, NULL::INT)::TEXT,
  'ELRANK.03 an unranked start has no place and no seed order');
SELECT is((SELECT string_agg(DISTINCT s.txt_ranking || '/' || COALESCE(s.ts_ranking_read::TEXT, 'none'), ',')
             FROM fn_registration_entry_ranks((SELECT id_event FROM tbl_event WHERE txt_code = 'RANK140OUR')) s),
  'SPWS/none',
  'ELRANK.03 an event of ours names our ranking, with no read time');

-- ---------------------------------------------------------------------------
-- ELRANK.04 · switch on, our registration off: nothing
-- ---------------------------------------------------------------------------
UPDATE tbl_event SET bool_use_spws_registration = FALSE WHERE txt_code = 'RANK140OFF';
SELECT is((SELECT count(*)::INT FROM fn_registration_entry_ranks((SELECT id_event FROM tbl_event WHERE txt_code = 'RANK140OFF'))), 0,
  'ELRANK.04 an event without our registration gives no row, whatever its switch');

-- ---------------------------------------------------------------------------
-- ELRANK.05 · exactly seven columns
-- ---------------------------------------------------------------------------
SELECT is(pg_get_function_result('fn_registration_entry_ranks(integer)'::regprocedure),
  'TABLE(id_registration integer, enum_weapon enum_weapon_type, enum_age_category enum_age_category, '
  'int_rank integer, int_seed_order integer, txt_ranking text, ts_ranking_read timestamp with time zone)',
  'ELRANK.05 it returns its seven columns: no birth year, no points, no fencer id');

-- ---------------------------------------------------------------------------
-- ELRANK.06 · who may call and who may switch
-- ---------------------------------------------------------------------------
SELECT ok(has_function_privilege('anon', 'fn_registration_entry_ranks(integer)', 'EXECUTE'),
  'ELRANK.06 a visitor may call it');
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{"role":"anon"}', TRUE);
SELECT is((SELECT count(*)::INT FROM fn_registration_entry_ranks((SELECT id_event FROM tbl_event WHERE txt_code = 'RANK140EVF'))), 4,
  'ELRANK.06 and gets the rows of an event whose switch is on');
SELECT throws_ok($$UPDATE tbl_event SET bool_show_seed = FALSE WHERE txt_code = 'RANK140EVF'$$,
  '42501', NULL, 'ELRANK.06 a visitor cannot change the switch');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"role":"authenticated","sub":"00000000-0000-4000-8000-000000000140"}', TRUE);
SELECT lives_ok($$UPDATE tbl_event SET bool_show_seed = FALSE WHERE txt_code = 'RANK140EVF'$$,
  'ELRANK.06 a signed-in administrator can');
RESET ROLE;
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{}', TRUE); END $$;
SELECT is((SELECT bool_show_seed FROM tbl_event WHERE txt_code = 'RANK140EVF'), FALSE,
  'ELRANK.06 and the change holds');

SELECT * FROM finish();
ROLLBACK;
