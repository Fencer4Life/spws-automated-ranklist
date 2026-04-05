-- =============================================================================
-- Go-to-PROD: Ingest Pipeline Tests
-- =============================================================================
-- Tests 10.1–10.7 from doc/Go-to-PROD.md (ADR-022).
-- Verifies fn_ingest_tournament_results: atomic insert, scoring, re-import,
-- match candidates, import status, rollback, participant count.
-- =============================================================================

BEGIN;
SELECT plan(23);

-- ===== SETUP: create test data for ingest tests =====

DO $setup$
DECLARE
  v_season   INT;
  v_org      INT;
  v_event    INT;
  v_tourn    INT;
  v_fencer1  INT;
  v_fencer2  INT;
  v_fencer3  INT;
BEGIN
  -- Get existing organizer from seed
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  -- Create a season for ingest testing
  -- Use fn_create_season which auto-creates scoring_config
  v_season := fn_create_season('INGEST-TEST-SEASON', '2025-09-01', '2026-06-30');

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('INGEST-EVT-1', 'Ingest Test Event', v_season, v_org, 'PLANNED')
  RETURNING id_event INTO v_event;

  INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, enum_import_status
  ) VALUES (
    v_event, 'INGEST-TRN-1', 'Ingest Test Tournament', 'PPW',
    'EPEE', 'M', 'V2',
    '2025-11-15', 0, 'PLANNED'
  ) RETURNING id_tournament INTO v_tourn;

  -- Create 3 test fencers
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, txt_nationality)
  VALUES ('TESTOWSKI', 'Jan', 1970, 'PL')
  RETURNING id_fencer INTO v_fencer1;

  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, txt_nationality)
  VALUES ('TESTOWA', 'Anna', 1972, 'PL')
  RETURNING id_fencer INTO v_fencer2;

  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, txt_nationality)
  VALUES ('TESTOWY', 'Piotr', 1968, 'PL')
  RETURNING id_fencer INTO v_fencer3;
END;
$setup$;


-- =========================================================================
-- 10.1 — fn_ingest_tournament_results inserts results into tbl_result
-- =========================================================================
DO $t101$
DECLARE
  v_tourn INT;
  v_f1 INT; v_f2 INT; v_f3 INT;
  v_results JSONB;
  v_summary JSONB;
BEGIN
  SELECT id_tournament INTO v_tourn FROM tbl_tournament WHERE txt_code = 'INGEST-TRN-1';
  SELECT id_fencer INTO v_f1 FROM tbl_fencer WHERE txt_surname = 'TESTOWSKI';
  SELECT id_fencer INTO v_f2 FROM tbl_fencer WHERE txt_surname = 'TESTOWA';
  SELECT id_fencer INTO v_f3 FROM tbl_fencer WHERE txt_surname = 'TESTOWY';

  v_results := jsonb_build_array(
    jsonb_build_object('id_fencer', v_f1, 'int_place', 1, 'txt_scraped_name', 'TESTOWSKI Jan', 'num_confidence', 98.5, 'enum_match_status', 'AUTO_MATCHED'),
    jsonb_build_object('id_fencer', v_f2, 'int_place', 2, 'txt_scraped_name', 'TESTOWA Anna', 'num_confidence', 97.0, 'enum_match_status', 'AUTO_MATCHED'),
    jsonb_build_object('id_fencer', v_f3, 'int_place', 3, 'txt_scraped_name', 'TESTOWY Piotr', 'num_confidence', 65.0, 'enum_match_status', 'PENDING')
  );

  v_summary := fn_ingest_tournament_results(v_tourn, v_results);
END;
$t101$;
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_result r
   JOIN tbl_tournament t ON r.id_tournament = t.id_tournament
   WHERE t.txt_code = 'INGEST-TRN-1'),
  3,
  '10.1: fn_ingest_tournament_results inserts 3 results into tbl_result'
);


-- =========================================================================
-- 10.2 — After ingest, num_final_score is populated (scoring engine ran)
-- =========================================================================
SELECT isnt(
  (SELECT num_final_score FROM tbl_result r
   JOIN tbl_tournament t ON r.id_tournament = t.id_tournament
   WHERE t.txt_code = 'INGEST-TRN-1' AND r.int_place = 1),
  NULL,
  '10.2: After ingest, num_final_score is populated (scoring engine ran)'
);


-- =========================================================================
-- 10.3 — Re-import same tournament replaces results (ADR-014)
-- =========================================================================
DO $t103$
DECLARE
  v_tourn INT;
  v_f1 INT; v_f2 INT;
  v_results JSONB;
  v_summary JSONB;
BEGIN
  SELECT id_tournament INTO v_tourn FROM tbl_tournament WHERE txt_code = 'INGEST-TRN-1';
  SELECT id_fencer INTO v_f1 FROM tbl_fencer WHERE txt_surname = 'TESTOWSKI';
  SELECT id_fencer INTO v_f2 FROM tbl_fencer WHERE txt_surname = 'TESTOWA';

  -- Re-import with only 2 fencers (simulates corrected results)
  v_results := jsonb_build_array(
    jsonb_build_object('id_fencer', v_f1, 'int_place', 1, 'txt_scraped_name', 'TESTOWSKI Jan', 'num_confidence', 99.0, 'enum_match_status', 'AUTO_MATCHED'),
    jsonb_build_object('id_fencer', v_f2, 'int_place', 2, 'txt_scraped_name', 'TESTOWA Anna', 'num_confidence', 97.0, 'enum_match_status', 'AUTO_MATCHED')
  );

  v_summary := fn_ingest_tournament_results(v_tourn, v_results);
END;
$t103$;
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_result r
   JOIN tbl_tournament t ON r.id_tournament = t.id_tournament
   WHERE t.txt_code = 'INGEST-TRN-1'),
  2,
  '10.3: Re-import replaces results — now 2 instead of 3 (ADR-014)'
);


-- =========================================================================
-- 10.4 — Each result gets a tbl_match_candidate entry
-- =========================================================================
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_match_candidate mc
   JOIN tbl_result r ON mc.id_result = r.id_result
   JOIN tbl_tournament t ON r.id_tournament = t.id_tournament
   WHERE t.txt_code = 'INGEST-TRN-1'),
  2,
  '10.4: Each result has a tbl_match_candidate entry (2 results = 2 candidates)'
);


-- =========================================================================
-- 10.5 — Tournament enum_import_status updates to 'IMPORTED'
-- =========================================================================
SELECT is(
  (SELECT enum_import_status::TEXT FROM tbl_tournament WHERE txt_code = 'INGEST-TRN-1'),
  'SCORED',
  '10.5: Tournament enum_import_status updated to SCORED (after scoring engine runs)'
);


-- =========================================================================
-- 10.6 — Invalid data causes full rollback (no partial inserts)
-- =========================================================================
-- Attempt ingest with invalid fencer_id — should raise error
SELECT throws_ok(
  $$SELECT fn_ingest_tournament_results(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'INGEST-TRN-1'),
    '[{"id_fencer": -99999, "int_place": 1, "txt_scraped_name": "GHOST", "num_confidence": 50, "enum_match_status": "PENDING"}]'::JSONB
  )$$,
  NULL,
  '10.6: Invalid fencer_id causes error (rollback — previous results preserved)'
);


-- =========================================================================
-- 10.7 — int_participant_count updated on tournament
-- =========================================================================
-- After the successful re-import in 10.3 with 2 fencers:
SELECT is(
  (SELECT int_participant_count FROM tbl_tournament WHERE txt_code = 'INGEST-TRN-1'),
  2,
  '10.7: int_participant_count updated to 2 after re-import'
);


-- =========================================================================
-- SETUP for event-centric tests (10.8–10.12)
-- =========================================================================
DO $setup2$
DECLARE
  v_season INT;
  v_org    INT;
BEGIN
  -- Get the season we created earlier
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'INGEST-TEST-SEASON';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  -- Mark it as active season (needed for prefix matching)
  -- First deactivate any existing active season
  UPDATE tbl_season SET bool_active = FALSE WHERE bool_active = TRUE;
  UPDATE tbl_season SET bool_active = TRUE WHERE id_season = v_season;

  -- Create a second event with a known date for fn_find_event_by_date testing
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, enum_status)
  VALUES ('INGEST-EVT-2', 'Event-Centric Test', v_season, v_org, '2026-04-05', '2026-04-05', 'PLANNED');
END;
$setup2$;


-- =========================================================================
-- 10.8 — fn_find_event_by_date returns correct event for known date
-- =========================================================================
SELECT is(
  (SELECT txt_code FROM fn_find_event_by_date('2026-04-05'::DATE)),
  'INGEST-EVT-2',
  '10.8: fn_find_event_by_date returns correct event for known date'
);


-- =========================================================================
-- 10.9 — fn_find_event_by_date returns NULL for unknown date
-- =========================================================================
SELECT is(
  (SELECT id_event FROM fn_find_event_by_date('2099-01-01'::DATE)),
  NULL,
  '10.9: fn_find_event_by_date returns NULL for unknown date'
);


-- =========================================================================
-- 10.10 — fn_find_or_create_tournament creates new tournament under event
-- =========================================================================
DO $t1010$
DECLARE
  v_event_id INT;
  v_tourn_id INT;
BEGIN
  SELECT id_event INTO v_event_id FROM tbl_event WHERE txt_code = 'INGEST-EVT-2';
  v_tourn_id := fn_find_or_create_tournament(v_event_id, 'EPEE', 'M', 'V2', '2026-04-05'::DATE, 'PPW');
END;
$t1010$;
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_tournament
   WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'INGEST-EVT-2')
     AND enum_weapon = 'EPEE' AND enum_gender = 'M' AND enum_age_category = 'V2'),
  1,
  '10.10: fn_find_or_create_tournament creates new tournament under event'
);


-- =========================================================================
-- 10.11 — fn_find_or_create_tournament returns existing on re-call (idempotent)
-- =========================================================================
DO $t1011$
DECLARE
  v_event_id INT;
  v_id1 INT;
  v_id2 INT;
BEGIN
  SELECT id_event INTO v_event_id FROM tbl_event WHERE txt_code = 'INGEST-EVT-2';
  v_id1 := fn_find_or_create_tournament(v_event_id, 'EPEE', 'M', 'V2', '2026-04-05'::DATE, 'PPW');
  v_id2 := fn_find_or_create_tournament(v_event_id, 'EPEE', 'M', 'V2', '2026-04-05'::DATE, 'PPW');
  -- They must be the same tournament
  IF v_id1 != v_id2 THEN
    RAISE EXCEPTION 'Tournament IDs differ: % vs %', v_id1, v_id2;
  END IF;
END;
$t1011$;
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_tournament
   WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'INGEST-EVT-2')
     AND enum_weapon = 'EPEE' AND enum_gender = 'M' AND enum_age_category = 'V2'),
  1,
  '10.11: fn_find_or_create_tournament is idempotent (still 1 tournament)'
);


-- =========================================================================
-- 10.12 — Ingest sets event status to IN_PROGRESS
-- =========================================================================
DO $t1012$
DECLARE
  v_event_id INT;
  v_tourn_id INT;
  v_f1 INT;
  v_results JSONB;
  v_summary JSONB;
BEGIN
  SELECT id_event INTO v_event_id FROM tbl_event WHERE txt_code = 'INGEST-EVT-2';
  v_tourn_id := fn_find_or_create_tournament(v_event_id, 'FOIL', 'F', 'V0', '2026-04-05'::DATE, 'PPW');

  SELECT id_fencer INTO v_f1 FROM tbl_fencer WHERE txt_surname = 'TESTOWSKI';

  v_results := jsonb_build_array(
    jsonb_build_object('id_fencer', v_f1, 'int_place', 1, 'txt_scraped_name', 'TESTOWSKI Jan', 'num_confidence', 99.0, 'enum_match_status', 'AUTO_MATCHED')
  );

  v_summary := fn_ingest_tournament_results(v_tourn_id, v_results);
END;
$t1012$;
SELECT is(
  (SELECT enum_status::TEXT FROM tbl_event WHERE txt_code = 'INGEST-EVT-2'),
  'IN_PROGRESS',
  '10.12: Ingest sets event status to IN_PROGRESS'
);


-- =========================================================================
-- SETUP for Telegram command tests (10.13–10.22)
-- =========================================================================
-- INGEST-EVT-2 is now IN_PROGRESS with 2 tournaments (EPEE M V2 + FOIL F V0)
-- from tests 10.10–10.12 above.


-- =========================================================================
-- 10.13 — fn_rollback_event deletes all tournaments and results
-- =========================================================================
SELECT lives_ok(
  $$SELECT fn_rollback_event('INGEST-EVT-2')$$,
  '10.13: fn_rollback_event executes without error'
);

-- =========================================================================
-- 10.14 — fn_rollback_event resets event to PLANNED
-- =========================================================================
SELECT is(
  (SELECT enum_status::TEXT FROM tbl_event WHERE txt_code = 'INGEST-EVT-2'),
  'PLANNED',
  '10.14: fn_rollback_event resets event to PLANNED'
);

-- =========================================================================
-- 10.15 — fn_rollback_event on unknown prefix raises error
-- =========================================================================
SELECT throws_ok(
  $$SELECT fn_rollback_event('NONEXISTENT-EVENT')$$,
  NULL,
  '10.15: fn_rollback_event on unknown prefix raises error'
);

-- Re-create tournaments and results for remaining tests
DO $resetup$
DECLARE
  v_event_id INT;
  v_tourn_id INT;
  v_f1 INT;
  v_results JSONB;
  v_summary JSONB;
BEGIN
  SELECT id_event INTO v_event_id FROM tbl_event WHERE txt_code = 'INGEST-EVT-2';
  SELECT id_fencer INTO v_f1 FROM tbl_fencer WHERE txt_surname = 'TESTOWSKI';

  v_tourn_id := fn_find_or_create_tournament(v_event_id, 'EPEE', 'M', 'V2', '2026-04-05'::DATE, 'PPW');
  v_results := jsonb_build_array(
    jsonb_build_object('id_fencer', v_f1, 'int_place', 1, 'txt_scraped_name', 'TESTOWSKI Jan', 'num_confidence', 99.0, 'enum_match_status', 'AUTO_MATCHED')
  );
  v_summary := fn_ingest_tournament_results(v_tourn_id, v_results);
END;
$resetup$;


-- =========================================================================
-- 10.16 — fn_complete_event sets COMPLETED
-- =========================================================================
SELECT lives_ok(
  $$SELECT fn_complete_event('INGEST-EVT-2')$$,
  '10.16: fn_complete_event executes without error'
);
SELECT is(
  (SELECT enum_status::TEXT FROM tbl_event WHERE txt_code = 'INGEST-EVT-2'),
  'COMPLETED',
  '10.16b: fn_complete_event sets status to COMPLETED'
);

-- =========================================================================
-- 10.17 — fn_complete_event on non-IN_PROGRESS event raises error
-- =========================================================================
-- Event is now COMPLETED, calling complete again should fail
SELECT throws_ok(
  $$SELECT fn_complete_event('INGEST-EVT-2')$$,
  NULL,
  '10.17: fn_complete_event on non-IN_PROGRESS event raises error'
);

-- Reset to IN_PROGRESS for remaining tests
DO $reset_ip$
BEGIN
  -- Rollback sets to PLANNED, then re-ingest sets to IN_PROGRESS
  PERFORM fn_rollback_event('INGEST-EVT-2');
END;
$reset_ip$;
DO $reingest$
DECLARE
  v_event_id INT;
  v_tourn_id INT;
  v_f1 INT; v_f2 INT;
  v_results JSONB;
  v_summary JSONB;
BEGIN
  SELECT id_event INTO v_event_id FROM tbl_event WHERE txt_code = 'INGEST-EVT-2';
  SELECT id_fencer INTO v_f1 FROM tbl_fencer WHERE txt_surname = 'TESTOWSKI';
  SELECT id_fencer INTO v_f2 FROM tbl_fencer WHERE txt_surname = 'TESTOWA';

  v_tourn_id := fn_find_or_create_tournament(v_event_id, 'EPEE', 'M', 'V2', '2026-04-05'::DATE, 'PPW');
  v_results := jsonb_build_array(
    jsonb_build_object('id_fencer', v_f1, 'int_place', 1, 'txt_scraped_name', 'TESTOWSKI Jan', 'num_confidence', 99.0, 'enum_match_status', 'AUTO_MATCHED'),
    jsonb_build_object('id_fencer', v_f2, 'int_place', 2, 'txt_scraped_name', 'TESTOWA Anna', 'num_confidence', 85.0, 'enum_match_status', 'PENDING')
  );
  v_summary := fn_ingest_tournament_results(v_tourn_id, v_results);
END;
$reingest$;


-- =========================================================================
-- 10.18 — fn_event_status returns correct counts
-- =========================================================================
SELECT is(
  (SELECT (fn_event_status('INGEST-EVT-2'))::JSONB ->> 'tournament_count'),
  '1',
  '10.18: fn_event_status returns correct tournament count'
);


-- =========================================================================
-- 10.19 — fn_event_results_summary returns per-tournament data
-- =========================================================================
SELECT isnt(
  (SELECT fn_event_results_summary('INGEST-EVT-2')),
  NULL,
  '10.19: fn_event_results_summary returns non-null result'
);


-- =========================================================================
-- 10.20 — fn_event_pending returns PENDING fencers
-- =========================================================================
SELECT is(
  (SELECT jsonb_array_length(fn_event_pending('INGEST-EVT-2'))),
  1,
  '10.20: fn_event_pending returns 1 PENDING fencer (TESTOWA)'
);


-- =========================================================================
-- 10.21 — fn_event_missing_categories identifies gaps
-- =========================================================================
-- Create a reference event with more categories so missing_categories has something to compare
DO $ref_evt$
DECLARE
  v_season INT;
  v_org INT;
  v_ref_event INT;
  v_tid INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'INGEST-TEST-SEASON';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, enum_status)
  VALUES ('INGEST-REF-EVT', 'Reference Event', v_season, v_org, '2026-01-01', 'PLANNED')
  RETURNING id_event INTO v_ref_event;

  -- Add FOIL M V2 tournament (INGEST-EVT-2 only has EPEE M V2)
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_ref_event, 'REF-FOIL-V2-M', 'Ref Foil V2 M', 'PPW', 'FOIL', 'M', 'V2', '2026-01-01', 5, 'PLANNED');
END;
$ref_evt$;

-- INGEST-EVT-2 only has EPEE M V2 — FOIL M V2 exists in ref event → should be "missing"
SELECT isnt(
  (SELECT fn_event_missing_categories('INGEST-EVT-2')),
  '[]'::JSONB,
  '10.21: fn_event_missing_categories identifies gaps (FOIL M V2 missing from EVT-2)'
);


-- =========================================================================
-- 10.22 — fn_season_overview returns all events with counts
-- =========================================================================
SELECT isnt(
  (SELECT fn_season_overview()),
  NULL,
  '10.22: fn_season_overview returns non-null result'
);


SELECT * FROM finish();
ROLLBACK;
