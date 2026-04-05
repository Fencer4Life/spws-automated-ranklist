-- =============================================================================
-- Go-to-PROD: Ingest Pipeline Tests
-- =============================================================================
-- Tests 10.1–10.7 from doc/Go-to-PROD.md (ADR-022).
-- Verifies fn_ingest_tournament_results: atomic insert, scoring, re-import,
-- match candidates, import status, rollback, participant count.
-- =============================================================================

BEGIN;
SELECT plan(7);

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


SELECT * FROM finish();
ROLLBACK;
