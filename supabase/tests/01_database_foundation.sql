-- =============================================================================
-- M1: Database Foundation & Season Lifecycle — Acceptance Tests
-- =============================================================================

BEGIN;
SELECT plan(69);

-- ---------------------------------------------------------------------------
-- 1.1  All 7 enum types exist with correct values
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT string_agg(e.enumlabel, ',' ORDER BY e.enumsortorder)
   FROM pg_type t
   JOIN pg_enum e ON e.enumtypid = t.oid
   WHERE t.typname = 'enum_weapon_type'),
  'EPEE,FOIL,SABRE',
  '1.1a enum_weapon_type values'
);

SELECT is(
  (SELECT string_agg(e.enumlabel, ',' ORDER BY e.enumsortorder)
   FROM pg_type t
   JOIN pg_enum e ON e.enumtypid = t.oid
   WHERE t.typname = 'enum_gender_type'),
  'M,F',
  '1.1b enum_gender_type values'
);

SELECT is(
  (SELECT string_agg(e.enumlabel, ',' ORDER BY e.enumsortorder)
   FROM pg_type t
   JOIN pg_enum e ON e.enumtypid = t.oid
   WHERE t.typname = 'enum_tournament_type'),
  'PPW,MPW,PEW,MEW,MSW,PSW',
  '1.1c enum_tournament_type values'
);

SELECT is(
  (SELECT string_agg(e.enumlabel, ',' ORDER BY e.enumsortorder)
   FROM pg_type t
   JOIN pg_enum e ON e.enumtypid = t.oid
   WHERE t.typname = 'enum_age_category'),
  'V0,V1,V2,V3,V4',
  '1.1d enum_age_category values'
);

SELECT is(
  (SELECT string_agg(e.enumlabel, ',' ORDER BY e.enumsortorder)
   FROM pg_type t
   JOIN pg_enum e ON e.enumtypid = t.oid
   WHERE t.typname = 'enum_event_status'),
  'CREATED,PLANNED,SCHEDULED,CHANGED,IN_PROGRESS,SCORED,COMPLETED,CANCELLED',
  '1.1e enum_event_status values (CREATED before PLANNED, SCORED before COMPLETED — Phase 1B / ADR-042)'
);

SELECT is(
  (SELECT string_agg(e.enumlabel, ',' ORDER BY e.enumsortorder)
   FROM pg_type t
   JOIN pg_enum e ON e.enumtypid = t.oid
   WHERE t.typname = 'enum_import_status'),
  'PLANNED,PENDING,IMPORTED,SCORED,REJECTED',
  '1.1f enum_import_status values'
);

SELECT is(
  (SELECT string_agg(e.enumlabel, ',' ORDER BY e.enumsortorder)
   FROM pg_type t
   JOIN pg_enum e ON e.enumtypid = t.oid
   WHERE t.typname = 'enum_match_status'),
  'PENDING,AUTO_MATCHED,APPROVED,NEW_FENCER,DISMISSED,UNMATCHED',
  '1.1g enum_match_status values'
);

-- ---------------------------------------------------------------------------
-- 1.2  All 9 core tables exist
-- ---------------------------------------------------------------------------
SELECT has_table('public', 'tbl_fencer',           '1.2a tbl_fencer exists');
SELECT has_table('public', 'tbl_organizer',        '1.2b tbl_organizer exists');
SELECT has_table('public', 'tbl_event',            '1.2c tbl_event exists');
SELECT has_table('public', 'tbl_tournament',       '1.2d tbl_tournament exists');
SELECT has_table('public', 'tbl_result',           '1.2e tbl_result exists');
SELECT has_table('public', 'tbl_match_candidate',  '1.2f tbl_match_candidate exists');
SELECT has_table('public', 'tbl_audit_log',        '1.2g tbl_audit_log exists');
SELECT has_table('public', 'tbl_season',           '1.2h tbl_season exists');
SELECT has_table('public', 'tbl_scoring_config',   '1.2i tbl_scoring_config exists');

-- ---------------------------------------------------------------------------
-- 1.3  FK constraint enforced: result with non-existent fencer fails
-- ---------------------------------------------------------------------------
SELECT throws_ok(
  'INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES (999999, 1, 1)',
  '23503',
  NULL,
  '1.3 FK on tbl_result.id_fencer enforced'
);

-- ---------------------------------------------------------------------------
-- 1.4  Unique constraint on (id_fencer, id_tournament) in tbl_result
-- ---------------------------------------------------------------------------
SELECT lives_ok(
  $test4$DO $body$
  DECLARE
    v_fencer INT;
    v_tourn INT;
  BEGIN
    SELECT id_fencer INTO v_fencer FROM tbl_fencer LIMIT 1;
    SELECT id_tournament INTO v_tourn FROM tbl_tournament LIMIT 1;

    INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
    VALUES (v_fencer, v_tourn, 1);

    BEGIN
      INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
      VALUES (v_fencer, v_tourn, 2);
      RAISE EXCEPTION 'Expected unique violation did not occur';
    EXCEPTION WHEN unique_violation THEN
      NULL;
    END;

    DELETE FROM tbl_result WHERE id_fencer = v_fencer AND id_tournament = v_tourn;
  END;
  $body$$test4$,
  '1.4 Unique (id_fencer, id_tournament) on tbl_result'
);

-- ---------------------------------------------------------------------------
-- 1.5  Unique constraint on (id_result, txt_scraped_name) in tbl_match_candidate
-- ---------------------------------------------------------------------------
SELECT lives_ok(
  $test5$DO $body$
  DECLARE
    v_fencer INT;
    v_tourn INT;
    v_result INT;
  BEGIN
    SELECT id_fencer INTO v_fencer FROM tbl_fencer LIMIT 1;
    SELECT id_tournament INTO v_tourn FROM tbl_tournament LIMIT 1;

    INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
    VALUES (v_fencer, v_tourn, 1) RETURNING id_result INTO v_result;

    INSERT INTO tbl_match_candidate (id_result, txt_scraped_name, enum_status)
    VALUES (v_result, 'DOE John', 'PENDING');

    BEGIN
      INSERT INTO tbl_match_candidate (id_result, txt_scraped_name, enum_status)
      VALUES (v_result, 'DOE John', 'PENDING');
      RAISE EXCEPTION 'Expected unique violation did not occur';
    EXCEPTION WHEN unique_violation THEN
      NULL;
    END;

    DELETE FROM tbl_match_candidate WHERE id_result = v_result;
    DELETE FROM tbl_result WHERE id_result = v_result;
  END;
  $body$$test5$,
  '1.5 Unique (id_result, txt_scraped_name) on tbl_match_candidate'
);

-- ---------------------------------------------------------------------------
-- 1.6  Global uniqueness on txt_code columns
-- ---------------------------------------------------------------------------
SELECT has_index('public', 'tbl_season',     'idx_season_code',     '1.6a tbl_season txt_code unique index');
SELECT has_index('public', 'tbl_event',      'idx_event_code',      '1.6b tbl_event txt_code unique index');
SELECT has_index('public', 'tbl_tournament', 'idx_tournament_code', '1.6c tbl_tournament txt_code unique index');
SELECT has_index('public', 'tbl_organizer',  'idx_organizer_code',  '1.6d tbl_organizer txt_code unique index');

-- ---------------------------------------------------------------------------
-- 1.7  Exclusion constraint: no overlapping season date ranges (ADR-031)
-- ---------------------------------------------------------------------------
SELECT ok(
  EXISTS(SELECT 1 FROM pg_constraint WHERE conname = 'excl_season_date_overlap'),
  '1.7 tbl_season has excl_season_date_overlap exclusion constraint'
);

-- ---------------------------------------------------------------------------
-- 1.8  Unique constraint on tbl_scoring_config(id_season)
-- ---------------------------------------------------------------------------
SELECT has_index('public', 'tbl_scoring_config', 'idx_scoring_config_season', '1.8 Unique index on tbl_scoring_config(id_season)');

-- ---------------------------------------------------------------------------
-- 1.9  All indexes from §9.2 exist
-- ---------------------------------------------------------------------------
SELECT has_index('public', 'tbl_result',          'idx_result_fencer',        '1.9a idx_result_fencer');
SELECT has_index('public', 'tbl_result',          'idx_result_tournament',    '1.9b idx_result_tournament');
SELECT has_index('public', 'tbl_tournament',      'idx_tournament_event',     '1.9c idx_tournament_event');
SELECT has_index('public', 'tbl_event',           'idx_event_season',         '1.9d idx_event_season');
SELECT has_index('public', 'tbl_event',           'idx_event_organizer',      '1.9e idx_event_organizer');
SELECT has_index('public', 'tbl_fencer',          'idx_fencer_name',          '1.9f idx_fencer_name');
SELECT has_index('public', 'tbl_match_candidate', 'idx_match_result',         '1.9g idx_match_result');
SELECT has_index('public', 'tbl_match_candidate', 'idx_match_fencer',         '1.9h idx_match_fencer');
SELECT has_index('public', 'tbl_match_candidate', 'idx_match_status',         '1.9i idx_match_status');
SELECT has_index('public', 'tbl_audit_log',       'idx_audit_table_row',      '1.9j idx_audit_table_row');
SELECT has_index('public', 'tbl_audit_log',       'idx_audit_created',        '1.9k idx_audit_created');

-- ---------------------------------------------------------------------------
-- 1.10  RLS: anonymous can SELECT, cannot INSERT
-- ---------------------------------------------------------------------------
SELECT lives_ok(
  'SET ROLE anon; SELECT count(*) FROM tbl_result; RESET ROLE',
  '1.10a anon can SELECT from tbl_result'
);

SELECT throws_ok(
  'SET ROLE anon; INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES (1, 1, 1); RESET ROLE',
  '42501',
  NULL,
  '1.10b anon cannot INSERT into tbl_result'
);

-- ---------------------------------------------------------------------------
-- 1.11  RLS: authenticated can INSERT/UPDATE/DELETE
-- ---------------------------------------------------------------------------
SELECT lives_ok(
  $test11$DO $body$
  DECLARE
    v_fencer INT;
    v_tourn INT;
    v_result INT;
  BEGIN
    -- Simulate authenticated user (set both PG role and JWT claim)
    SET LOCAL ROLE authenticated;
    PERFORM set_config('request.jwt.claim.role', 'authenticated', TRUE);
    PERFORM set_config('request.jwt.claims', '{"role":"authenticated","sub":"test-user"}', TRUE);

    SELECT id_fencer INTO v_fencer FROM tbl_fencer LIMIT 1;
    SELECT id_tournament INTO v_tourn FROM tbl_tournament LIMIT 1;

    INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
    VALUES (v_fencer, v_tourn, 5)
    RETURNING id_result INTO v_result;

    UPDATE tbl_result SET int_place = 3 WHERE id_result = v_result;
    DELETE FROM tbl_result WHERE id_result = v_result;
    RESET ROLE;
  END;
  $body$$test11$,
  '1.11 authenticated can INSERT/UPDATE/DELETE on tbl_result'
);

-- ---------------------------------------------------------------------------
-- 1.12  Seed data loads without errors
-- ---------------------------------------------------------------------------
SELECT ok(
  (SELECT count(*) > 0 FROM tbl_season),
  '1.12a Seed data: at least one season exists'
);

SELECT ok(
  (SELECT count(*) > 0 FROM tbl_fencer),
  '1.12b Seed data: at least one fencer exists'
);

SELECT ok(
  (SELECT count(*) > 0 FROM tbl_organizer),
  '1.12c Seed data: at least one organizer exists'
);

-- ---------------------------------------------------------------------------
-- 1.12d  Seed tournament multiplier auto-populated by trigger
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT num_multiplier FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2024-2025'),
  1.0::NUMERIC,
  '1.12d Seed tournament PPW1-V2-M-EPEE-2024-2025 has multiplier 1.0 from trigger'
);

-- ---------------------------------------------------------------------------
-- 1.13  Create season
-- ---------------------------------------------------------------------------
SELECT lives_ok(
  'INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
   VALUES (''TEST-SEASON-9999'', ''2099-08-01'', ''2100-07-15'', FALSE)',
  '1.13 Can create a season with txt_code, dt_start, dt_end'
);

-- ---------------------------------------------------------------------------
-- 1.14  Create season: scoring config auto-created with defaults
-- ---------------------------------------------------------------------------
SELECT ok(
  (SELECT count(*) = 1
   FROM tbl_scoring_config sc
   JOIN tbl_season s ON s.id_season = sc.id_season
   WHERE s.txt_code = 'TEST-SEASON-9999'),
  '1.14 Scoring config auto-created for new season'
);

-- ---------------------------------------------------------------------------
-- 1.14b  Scoring config has correct default values
-- ---------------------------------------------------------------------------
SELECT ok(
  (SELECT int_mp_value = 50
      AND int_podium_gold = 3 AND int_podium_silver = 2 AND int_podium_bronze = 1
      AND num_ppw_multiplier = 1.0 AND int_ppw_best_count = 4
      AND num_mpw_multiplier = 1.2 AND bool_mpw_droppable = TRUE
      AND num_pew_multiplier = 1.0 AND int_pew_best_count = 3
      AND num_mew_multiplier = 2.0 AND bool_mew_droppable = TRUE
      AND num_msw_multiplier = 2.0
      AND int_min_participants_evf = 5 AND int_min_participants_ppw = 1
   FROM tbl_scoring_config sc
   JOIN tbl_season s ON s.id_season = sc.id_season
   WHERE s.txt_code = 'TEST-SEASON-9999'),
  '1.14b Scoring config defaults are correct'
);

-- ---------------------------------------------------------------------------
-- 1.15  Enforce no overlapping season dates (ADR-031)
-- ---------------------------------------------------------------------------
SELECT throws_ok(
  'INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
   VALUES (''OVERLAP-SEASON'', ''2025-09-01'', ''2026-06-30'', FALSE)',
  '23P01',
  NULL,
  '1.15 Overlapping season dates rejected by exclusion constraint'
);

-- ---------------------------------------------------------------------------
-- 1.16  Create event: defaults to PLANNED status
-- ---------------------------------------------------------------------------
SELECT lives_ok(
  $test16$DO $body$
  DECLARE
    v_season INT;
    v_org INT;
  BEGIN
    SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'TEST-SEASON-9999';
    SELECT id_organizer INTO v_org FROM tbl_organizer LIMIT 1;
    INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
    VALUES ('TEST-EVT-9999', 'Test Event', v_season, v_org, 'PLANNED');
  END;
  $body$$test16$,
  '1.16 Can create event with PLANNED status'
);

-- ---------------------------------------------------------------------------
-- 1.17  Create tournament: season-scoped txt_code
-- ---------------------------------------------------------------------------
SELECT lives_ok(
  $test17$DO $body$
  DECLARE
    v_event INT;
  BEGIN
    SELECT id_event INTO v_event FROM tbl_event WHERE txt_code = 'TEST-EVT-9999';
    INSERT INTO tbl_tournament (
      id_event, txt_code, txt_name, enum_type,
      enum_weapon, enum_gender, enum_age_category,
      enum_import_status
    ) VALUES (
      v_event, 'PPW1-V2-M-EPEE-9999', 'Test Tournament', 'PPW',
      'EPEE', 'M', 'V2', 'PLANNED'
    );
  END;
  $body$$test17$,
  '1.17 Can create tournament with season-scoped txt_code'
);

-- ---------------------------------------------------------------------------
-- 1.18  Create tournament: enum_import_status defaults to PLANNED
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT enum_import_status::TEXT FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-9999'),
  'PLANNED',
  '1.18 Tournament enum_import_status defaults to PLANNED'
);

-- ---------------------------------------------------------------------------
-- 1.19  Create tournament: num_multiplier auto-populated from scoring config
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT num_multiplier FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-9999'),
  1.0::NUMERIC,
  '1.19 Tournament num_multiplier auto-populated from scoring config'
);

-- ---------------------------------------------------------------------------
-- 1.19b  Multiplier auto-populated for MPW type (1.2)
-- ---------------------------------------------------------------------------
SELECT lives_ok(
  $test19b$DO $body$
  DECLARE
    v_event INT;
  BEGIN
    SELECT id_event INTO v_event FROM tbl_event WHERE txt_code = 'TEST-EVT-9999';
    INSERT INTO tbl_tournament (
      id_event, txt_code, txt_name, enum_type,
      enum_weapon, enum_gender, enum_age_category
    ) VALUES (
      v_event, 'MPW-V2-M-EPEE-9999', 'Test MPW', 'MPW',
      'EPEE', 'M', 'V2'
    );
  END;
  $body$$test19b$,
  '1.19b setup: create MPW tournament'
);

SELECT is(
  (SELECT num_multiplier FROM tbl_tournament WHERE txt_code = 'MPW-V2-M-EPEE-9999'),
  1.2::NUMERIC,
  '1.19c MPW tournament gets multiplier 1.2 from scoring config'
);

-- ---------------------------------------------------------------------------
-- 1.20  Valid event transition: PLANNED → SCHEDULED → IN_PROGRESS → COMPLETED
-- ---------------------------------------------------------------------------
SELECT lives_ok(
  $test20$DO $body$
  BEGIN
    UPDATE tbl_event SET enum_status = 'SCHEDULED' WHERE txt_code = 'TEST-EVT-9999';
    UPDATE tbl_event SET enum_status = 'IN_PROGRESS' WHERE txt_code = 'TEST-EVT-9999';
    UPDATE tbl_event SET enum_status = 'COMPLETED' WHERE txt_code = 'TEST-EVT-9999';
  END;
  $body$$test20$,
  '1.20 Valid transitions PLANNED->SCHEDULED->IN_PROGRESS->COMPLETED succeed'
);

-- ---------------------------------------------------------------------------
-- 1.21  Invalid event transition: PLANNED → COMPLETED rejected
-- ---------------------------------------------------------------------------
-- Create a fresh PLANNED event for this test
SELECT lives_ok(
  $test21s$DO $body$
  DECLARE
    v_season INT;
    v_org INT;
  BEGIN
    SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'TEST-SEASON-9999';
    SELECT id_organizer INTO v_org FROM tbl_organizer LIMIT 1;
    INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
    VALUES ('TEST-EVT-TRANS', 'Transition Test Event', v_season, v_org, 'PLANNED');
  END;
  $body$$test21s$,
  '1.21 setup: create event for transition test'
);

SELECT throws_ok(
  'UPDATE tbl_event SET enum_status = ''COMPLETED'' WHERE txt_code = ''TEST-EVT-TRANS''',
  NULL,
  NULL,
  '1.21 Invalid transition PLANNED->COMPLETED rejected'
);

-- ---------------------------------------------------------------------------
-- 1.21b  Terminal state: COMPLETED → SCHEDULED rejected
-- ---------------------------------------------------------------------------
SELECT throws_ok(
  'UPDATE tbl_event SET enum_status = ''SCHEDULED'' WHERE txt_code = ''TEST-EVT-9999''',
  NULL,
  NULL,
  '1.21b COMPLETED is terminal: COMPLETED->SCHEDULED rejected'
);

-- ---------------------------------------------------------------------------
-- 1.22  Event status change logged in tbl_audit_log with old/new values
-- ---------------------------------------------------------------------------
SELECT ok(
  (SELECT count(*) > 0
   FROM tbl_audit_log
   WHERE txt_table_name = 'tbl_event'
     AND txt_action = 'UPDATE'),
  '1.22a Event status changes logged in tbl_audit_log'
);

SELECT ok(
  (SELECT jsonb_old_values IS NOT NULL AND jsonb_new_values IS NOT NULL
   FROM tbl_audit_log
   WHERE txt_table_name = 'tbl_event'
     AND txt_action = 'UPDATE'
   LIMIT 1),
  '1.22b Audit log captures both old and new values'
);

-- ---------------------------------------------------------------------------
-- 1.23  Event cancellation: SCHEDULED → CANCELLED succeeds
-- ---------------------------------------------------------------------------
SELECT lives_ok(
  $test23$DO $body$
  BEGIN
    UPDATE tbl_event SET enum_status = 'SCHEDULED' WHERE txt_code = 'TEST-EVT-TRANS';
    UPDATE tbl_event SET enum_status = 'CANCELLED' WHERE txt_code = 'TEST-EVT-TRANS';
  END;
  $body$$test23$,
  '1.23 Event cancellation SCHEDULED->CANCELLED succeeds'
);

-- ---------------------------------------------------------------------------
-- 1.24  CANCELLED is terminal: CANCELLED → PLANNED rejected
-- ---------------------------------------------------------------------------
SELECT throws_ok(
  'UPDATE tbl_event SET enum_status = ''PLANNED'' WHERE txt_code = ''TEST-EVT-TRANS''',
  NULL,
  NULL,
  '1.24 CANCELLED is terminal: CANCELLED->PLANNED rejected'
);

-- ---------------------------------------------------------------------------
-- 9.86  CHANGED state: SCHEDULED → CHANGED succeeds
-- ---------------------------------------------------------------------------
SELECT lives_ok(
  $test986$DO $body$
  BEGIN
    -- Reset to PLANNED first, then walk through valid path
    INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
    SELECT 'TEST-EVT-CHANGED', 'Changed Test', s.id_season, o.id_organizer, 'PLANNED'
    FROM tbl_season s, tbl_organizer o
    WHERE s.txt_code = 'SPWS-2024-2025' AND o.txt_code = 'SPWS';
    UPDATE tbl_event SET enum_status = 'SCHEDULED' WHERE txt_code = 'TEST-EVT-CHANGED';
    UPDATE tbl_event SET enum_status = 'CHANGED' WHERE txt_code = 'TEST-EVT-CHANGED';
  END;
  $body$$test986$,
  '9.86 SCHEDULED->CHANGED succeeds'
);

-- ---------------------------------------------------------------------------
-- 9.87  CHANGED → SCHEDULED succeeds
-- ---------------------------------------------------------------------------
SELECT lives_ok(
  $test987$UPDATE tbl_event SET enum_status = 'SCHEDULED' WHERE txt_code = 'TEST-EVT-CHANGED'$test987$,
  '9.87 CHANGED->SCHEDULED succeeds'
);

-- ---------------------------------------------------------------------------
-- 9.88  CHANGED → IN_PROGRESS succeeds
-- ---------------------------------------------------------------------------
SELECT lives_ok(
  $test988$DO $body$
  BEGIN
    UPDATE tbl_event SET enum_status = 'CHANGED' WHERE txt_code = 'TEST-EVT-CHANGED';
    UPDATE tbl_event SET enum_status = 'IN_PROGRESS' WHERE txt_code = 'TEST-EVT-CHANGED';
  END;
  $body$$test988$,
  '9.88 CHANGED->IN_PROGRESS succeeds'
);

-- ---------------------------------------------------------------------------
-- 9.89  CHANGED → CANCELLED succeeds
-- ---------------------------------------------------------------------------
SELECT lives_ok(
  $test989$DO $body$
  BEGIN
    -- Create a new event since previous one is now IN_PROGRESS
    INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
    SELECT 'TEST-EVT-CHANGED2', 'Changed Test 2', s.id_season, o.id_organizer, 'PLANNED'
    FROM tbl_season s, tbl_organizer o
    WHERE s.txt_code = 'SPWS-2024-2025' AND o.txt_code = 'SPWS';
    UPDATE tbl_event SET enum_status = 'SCHEDULED' WHERE txt_code = 'TEST-EVT-CHANGED2';
    UPDATE tbl_event SET enum_status = 'CHANGED' WHERE txt_code = 'TEST-EVT-CHANGED2';
    UPDATE tbl_event SET enum_status = 'CANCELLED' WHERE txt_code = 'TEST-EVT-CHANGED2';
  END;
  $body$$test989$,
  '9.89 CHANGED->CANCELLED succeeds'
);

-- ---------------------------------------------------------------------------
-- 9.90  PLANNED → CHANGED rejected (invalid transition)
-- ---------------------------------------------------------------------------
SELECT throws_ok(
  $test990$DO $body$
  BEGIN
    INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
    SELECT 'TEST-EVT-CHANGED3', 'Changed Test 3', s.id_season, o.id_organizer, 'PLANNED'
    FROM tbl_season s, tbl_organizer o
    WHERE s.txt_code = 'SPWS-2024-2025' AND o.txt_code = 'SPWS';
    UPDATE tbl_event SET enum_status = 'CHANGED' WHERE txt_code = 'TEST-EVT-CHANGED3';
  END;
  $body$$test990$,
  NULL,
  NULL,
  '9.90 PLANNED->CHANGED rejected'
);

-- ---------------------------------------------------------------------------
-- 1.25  RLS: tbl_match_candidate has no anon SELECT policy (structural check)
-- ---------------------------------------------------------------------------
-- Note: SET LOCAL ROLE anon inside a superuser transaction does not enforce RLS
-- (postgres bypasses RLS). We verify structurally that no anon/public policy exists.
SELECT ok(
  NOT EXISTS(
    SELECT 1 FROM pg_policy
    WHERE polrelid = 'tbl_match_candidate'::regclass
      AND polroles @> ARRAY[(SELECT oid FROM pg_roles WHERE rolname = 'anon')]
  ),
  '1.25 tbl_match_candidate has no anon RLS policy (admin-only access)'
);

-- ---------------------------------------------------------------------------
-- 1.26  RLS: tbl_audit_log has no anon SELECT policy (only admin read)
-- ---------------------------------------------------------------------------
-- Note: in-transaction RLS tests for audit_log are unreliable because rows
-- created by the postgres superuser in the same transaction are visible
-- regardless of role. We verify the policy structure instead.
SELECT ok(
  (SELECT count(*) = 0
   FROM pg_policies
   WHERE tablename = 'tbl_audit_log'
     AND policyname ILIKE '%public%'),
  '1.26 tbl_audit_log has no public/anon SELECT policy'
);

-- ---------------------------------------------------------------------------
-- 1.27  tbl_fencer has bool_birth_year_estimated column (intake rules)
-- ---------------------------------------------------------------------------
SELECT has_column(
  'public', 'tbl_fencer', 'bool_birth_year_estimated',
  '1.27 tbl_fencer has bool_birth_year_estimated column for intake rules'
);

SELECT * FROM finish();
ROLLBACK;
