-- =============================================================================
-- Go-to-PROD: Ingest Pipeline Tests
-- =============================================================================
-- Tests 10.1–10.7 from doc/Go-to-PROD.md (ADR-022).
-- Verifies fn_ingest_tournament_results: atomic insert, scoring, re-import,
-- match candidates, import status, rollback, participant count.
-- =============================================================================

BEGIN;
SELECT plan(33);

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
  v_season := fn_create_season('INGEST-TEST-SEASON', '2035-09-01', '2036-06-30');

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


-- =========================================================================
-- SETUP for carry-over double-counting regression test (10.23–10.24)
-- =========================================================================
-- Regression: when a current-season event is IN_PROGRESS at the same
-- position (e.g. PPW4) as a previous-season event, carry-over from the
-- previous season must be excluded. Previously only COMPLETED triggered
-- exclusion, so IN_PROGRESS events double-counted.
-- =========================================================================

DO $carryover_setup$
DECLARE
  v_prev_season INT;
  v_curr_season INT;
  v_org         INT;
  v_prev_event  INT;
  v_curr_event  INT;
  v_prev_tourn  INT;
  v_curr_tourn  INT;
  v_fencer      INT;
  v_results     JSONB;
  v_summary     JSONB;
BEGIN
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  -- Deactivate all seasons first
  UPDATE tbl_season SET bool_active = FALSE;

  -- Create previous season (dates must not overlap with seed seasons)
  INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
  VALUES ('CARRY-PREV', '2027-09-01', '2028-06-30', FALSE)
  RETURNING id_season INTO v_prev_season;

  -- Create current season — starts after CARRY-PREV ends
  -- (bool_active is auto-derived by trigger; tests use explicit season ID)
  -- Phase 3 flipped the column DEFAULT to FK; this fixture is intentionally
  -- written for the CODE engine (carry-over via txt_code prefix matching, no
  -- id_prior_event linkage), so pin enum_carryover_engine here to keep the
  -- test scope honest.
  INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active, enum_carryover_engine)
  VALUES ('CARRY-CURR', '2028-09-01', '2029-06-30', FALSE,
          'EVENT_CODE_MATCHING'::enum_event_carryover_engine)
  RETURNING id_season INTO v_curr_season;

  -- Both seasons need scoring_config with json_ranking_rules (JSONB path)
  INSERT INTO tbl_scoring_config (id_season, json_ranking_rules)
  VALUES (v_prev_season, '{"domestic":[{"types":["PPW"],"best":4},{"types":["MPW"],"always":true}]}'::JSONB)
  ON CONFLICT (id_season) DO UPDATE SET json_ranking_rules = EXCLUDED.json_ranking_rules;

  INSERT INTO tbl_scoring_config (id_season, json_ranking_rules)
  VALUES (v_curr_season, '{"domestic":[{"types":["PPW"],"best":4},{"types":["MPW"],"always":true}]}'::JSONB)
  ON CONFLICT (id_season) DO UPDATE SET json_ranking_rules = EXCLUDED.json_ranking_rules;

  -- Create fencer for the test
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, txt_nationality)
  VALUES ('CARRYOVER', 'Test', 1970, 'PL')
  RETURNING id_fencer INTO v_fencer;

  -- Previous season: PPW4-CARRY-PREV event, COMPLETED, with a result
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, enum_status)
  VALUES ('PPW4-CARRY-PREV', 'Prev PPW4', v_prev_season, v_org, '2028-03-01', 'COMPLETED')
  RETURNING id_event INTO v_prev_event;

  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_prev_event, 'PPW4-CARRY-PREV-V2-M-EPEE', 'Prev PPW4 V2 M Epee', 'PPW', 'EPEE', 'M', 'V2', '2028-03-01', 1, 'SCORED')
  RETURNING id_tournament INTO v_prev_tourn;

  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
  VALUES (v_fencer, v_prev_tourn, 1, 100.00);

  -- Current season: PPW4-CARRY-CURR event, IN_PROGRESS (just ingested)
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, enum_status)
  VALUES ('PPW4-CARRY-CURR', 'Curr PPW4', v_curr_season, v_org, '2029-03-01', 'IN_PROGRESS')
  RETURNING id_event INTO v_curr_event;

  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_curr_event, 'PPW4-CARRY-CURR-V2-M-EPEE', 'Curr PPW4 V2 M Epee', 'PPW', 'EPEE', 'M', 'V2', '2029-03-01', 1, 'SCORED')
  RETURNING id_tournament INTO v_curr_tourn;

  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
  VALUES (v_fencer, v_curr_tourn, 1, 80.00);
END;
$carryover_setup$;


-- =========================================================================
-- 10.23 — IN_PROGRESS event excludes carry-over at same position (regression)
-- =========================================================================
-- fn_ranking_ppw with rolling=TRUE must return ONLY the current season score
-- (80.00), NOT current + carry-over (80.00 + 100.00 = 180.00).
-- This catches the bug where completed_positions only checked 'COMPLETED'.
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw('EPEE', 'M', 'V2',
     (SELECT id_season FROM tbl_season WHERE txt_code = 'CARRY-CURR'), TRUE)
   WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CARRYOVER')),
  80.00::NUMERIC,
  '10.23: IN_PROGRESS event excludes carry-over at same position (no double-counting)'
);


-- =========================================================================
-- 10.24 — Carry-over IS included when position has no current-season event
-- =========================================================================
-- Add a PPW3 result in prev season only (no PPW3 in current season).
-- The carry-over for PPW3 SHOULD be included in the ranking.
DO $carryover_ppw3$
DECLARE
  v_prev_season INT;
  v_org         INT;
  v_event       INT;
  v_tourn       INT;
  v_fencer      INT;
BEGIN
  SELECT id_season INTO v_prev_season FROM tbl_season WHERE txt_code = 'CARRY-PREV';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';
  SELECT id_fencer INTO v_fencer FROM tbl_fencer WHERE txt_surname = 'CARRYOVER';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, enum_status)
  VALUES ('PPW3-CARRY-PREV', 'Prev PPW3', v_prev_season, v_org, '2028-02-01', 'COMPLETED')
  RETURNING id_event INTO v_event;

  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_event, 'PPW3-CARRY-PREV-V2-M-EPEE', 'Prev PPW3 V2 M Epee', 'PPW', 'EPEE', 'M', 'V2', '2028-02-01', 1, 'SCORED')
  RETURNING id_tournament INTO v_tourn;

  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
  VALUES (v_fencer, v_tourn, 1, 50.00);
END;
$carryover_ppw3$;

-- Now ranking should include: current PPW4 (80) + carried PPW3 (50) = 130
-- But NOT carried PPW4 (100) because PPW4 is IN_PROGRESS in current season
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw('EPEE', 'M', 'V2',
     (SELECT id_season FROM tbl_season WHERE txt_code = 'CARRY-CURR'), TRUE)
   WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'CARRYOVER')),
  130.00::NUMERIC,
  '10.24: Carry-over included for position without current-season event (PPW3=50 + PPW4=80 = 130)'
);


-- =============================================================================
-- 10.25–10.26: fn_update_tournament txt_code editing
-- =============================================================================

-- 10.25: Rename tournament code via p_code parameter
SELECT lives_ok(
  $$SELECT fn_update_tournament(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2025-2026'),
    NULL, 'PLANNED', NULL, 'RENAMED-V2-M-EPEE-2025-2026'
  )$$,
  '10.25: fn_update_tournament with p_code renames txt_code'
);

SELECT is(
  (SELECT txt_code FROM tbl_tournament WHERE txt_code = 'RENAMED-V2-M-EPEE-2025-2026'),
  'RENAMED-V2-M-EPEE-2025-2026',
  '10.26: Tournament txt_code updated in DB'
);

-- =========================================================================
-- 10.27–10.28: p_participant_count parameter (ADR-036 fix)
-- =========================================================================
-- When p_participant_count is provided, fn_ingest_tournament_results should
-- use that value instead of counting input results. Critical for international
-- tournaments where only POL fencers are ingested but the tournament has
-- more participants (e.g., 38 total, 14 POL imported).

-- 10.27 — p_participant_count overrides auto-count
-- Use RENAMED tournament (from test 10.25) which still exists in the transaction
SELECT lives_ok(
  $$SELECT fn_ingest_tournament_results(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'RENAMED-V2-M-EPEE-2025-2026'),
    '[{"id_fencer": 1, "int_place": 1, "txt_scraped_name": "TEST", "num_confidence": 100, "enum_match_status": "AUTO_MATCHED"}]'::JSONB,
    42
  )$$,
  '10.27: fn_ingest_tournament_results accepts p_participant_count parameter'
);

-- 10.28 — verify participant count was set to 42, not 1
SELECT is(
  (SELECT int_participant_count FROM tbl_tournament WHERE txt_code = 'RENAMED-V2-M-EPEE-2025-2026'),
  42,
  '10.28: p_participant_count=42 overrides auto-count of 1 result'
);

-- =========================================================================
-- 10.29–10.32: fn_delete_event — durable admin tool for wrong-ingest cleanup
-- =========================================================================
-- Scope: same cascade as fn_rollback_event, plus DELETE of the event row
-- itself. Returns combined summary. Eliminates the "rollback then manual
-- DELETE tbl_event" two-step dance I used during PEW7 + EVF-dup cleanups.

-- Setup: create DEL-EVT in active season with 1 tournament + 1 result
DO $setup_del$
DECLARE
  v_season_id INT;
  v_event_id INT;
  v_tourn_id INT;
  v_f1 INT;
  v_results JSONB;
BEGIN
  SELECT id_season INTO v_season_id FROM tbl_season WHERE bool_active = TRUE;
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, txt_location, txt_country)
  VALUES (
    'DEL-EVT-2025-2026', 'Delete Cascade Test Event',
    v_season_id,
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'IN_PROGRESS', '2026-03-01', 'TestCity', 'Polska'
  ) RETURNING id_event INTO v_event_id;
  v_tourn_id := fn_find_or_create_tournament(v_event_id, 'EPEE', 'M', 'V2', '2026-03-01'::DATE, 'PPW');
  SELECT id_fencer INTO v_f1 FROM tbl_fencer WHERE txt_surname = 'TESTOWSKI';
  v_results := jsonb_build_array(
    jsonb_build_object('id_fencer', v_f1, 'int_place', 1, 'txt_scraped_name', 'TESTOWSKI Jan', 'num_confidence', 99.0, 'enum_match_status', 'AUTO_MATCHED')
  );
  PERFORM fn_ingest_tournament_results(v_tourn_id, v_results);
END;
$setup_del$;

-- 10.29 — fn_delete_event runs and returns a JSONB summary
SELECT lives_ok(
  $$SELECT fn_delete_event('DEL-EVT')$$,
  '10.29: fn_delete_event executes without error'
);

-- 10.30 — event row is gone after call
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event WHERE txt_code = 'DEL-EVT-2025-2026'),
  0,
  '10.30: fn_delete_event removes the tbl_event row'
);

-- 10.31 — child tournaments are gone too
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_tournament WHERE txt_code LIKE 'DEL-EVT-%'),
  0,
  '10.31: fn_delete_event removes all child tournaments'
);

-- 10.32 — unknown prefix raises
SELECT throws_ok(
  $$SELECT fn_delete_event('NONEXISTENT-DEL-EVT')$$,
  NULL,
  '10.32: fn_delete_event on unknown prefix raises error'
);

SELECT * FROM finish();
ROLLBACK;
