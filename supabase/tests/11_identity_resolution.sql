-- =============================================================================
-- Identity Resolution Admin RPC Tests
-- =============================================================================
-- Tests 11.1–11.12: fn_approve_match, fn_dismiss_match, fn_create_fencer_from_match
-- FRs: FR-56, FR-57
-- =============================================================================

BEGIN;
-- Layer 6 (2026-04-30): targeted bypass of trg_assert_result_vcat for
-- legacy test fixtures whose dummy V-cats predate the FATAL invariant
-- guard. Targeted (not session_replication_role) so audit + status-
-- transition triggers stay live.
ALTER TABLE tbl_result DISABLE TRIGGER trg_assert_result_vcat;
SELECT plan(21);

-- ===== SETUP =====
DO $setup$
DECLARE
  v_season  INT;
  v_org     INT;
  v_event   INT;
  v_tourn   INT;
  v_fencer1 INT;
  v_fencer2 INT;
  v_fencer3 INT;
  v_results JSONB;
  v_summary JSONB;
BEGIN
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  -- Deactivate all seasons, create test season
  UPDATE tbl_season SET bool_active = FALSE;
  v_season := fn_create_season('IDENT-TEST', '2030-09-01', '2031-06-30');
  UPDATE tbl_season SET bool_active = TRUE WHERE id_season = v_season;

  INSERT INTO tbl_scoring_config (id_season)
  VALUES (v_season)
  ON CONFLICT (id_season) DO NOTHING;

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, enum_status)
  VALUES ('IDENT-EVT', 'Identity Test Event', v_season, v_org, '2031-01-15', 'IN_PROGRESS')
  RETURNING id_event INTO v_event;

  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_event, 'IDENT-TRN', 'Identity Test Tournament', 'PPW', 'EPEE', 'M', 'V2', '2031-01-15', 0, 'PLANNED')
  RETURNING id_tournament INTO v_tourn;

  -- Create 3 known fencers (need distinct fencer per result due to unique constraint)
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, txt_nationality)
  VALUES ('IDENTFENCER', 'Alpha', 1970, 'PL')
  RETURNING id_fencer INTO v_fencer1;

  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, txt_nationality)
  VALUES ('IDENTFENCER', 'Beta', 1972, 'PL')
  RETURNING id_fencer INTO v_fencer2;

  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, txt_nationality)
  VALUES ('IDENTFENCER', 'Gamma', 1968, 'PL')
  RETURNING id_fencer INTO v_fencer3;

  -- Ingest 3 results: one PENDING, one UNMATCHED, one AUTO_MATCHED
  v_results := jsonb_build_array(
    jsonb_build_object('id_fencer', v_fencer1, 'int_place', 1, 'txt_scraped_name', 'IDENTFENCER Alpha', 'num_confidence', 55.0, 'enum_match_status', 'PENDING'),
    jsonb_build_object('id_fencer', v_fencer2, 'int_place', 2, 'txt_scraped_name', 'UNKNOWN Fencer', 'num_confidence', 30.0, 'enum_match_status', 'UNMATCHED'),
    jsonb_build_object('id_fencer', v_fencer3, 'int_place', 3, 'txt_scraped_name', 'IDENTFENCER Gamma', 'num_confidence', 99.0, 'enum_match_status', 'AUTO_MATCHED')
  );

  v_summary := fn_ingest_tournament_results(v_tourn, v_results);
END;
$setup$;


-- =========================================================================
-- 11.1 — fn_approve_match PENDING → APPROVED
-- =========================================================================
SELECT lives_ok(
  $$SELECT fn_approve_match(
    (SELECT id_match FROM tbl_match_candidate WHERE txt_scraped_name = 'IDENTFENCER Alpha' AND enum_status = 'PENDING'),
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'IDENTFENCER' AND txt_first_name = 'Alpha')
  )$$,
  '11.1: fn_approve_match on PENDING executes without error'
);


-- =========================================================================
-- 11.2 — fn_approve_match updates tbl_result.id_fencer
-- =========================================================================
SELECT is(
  (SELECT r.id_fencer FROM tbl_result r
   JOIN tbl_match_candidate mc ON mc.id_result = r.id_result
   WHERE mc.txt_scraped_name = 'IDENTFENCER Alpha' AND mc.enum_status = 'APPROVED'),
  (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'IDENTFENCER' AND txt_first_name = 'Alpha'),
  '11.2: fn_approve_match updates tbl_result.id_fencer to approved fencer'
);


-- =========================================================================
-- 11.3 — fn_approve_match on non-PENDING raises error
-- =========================================================================
-- The candidate from 11.1 is now APPROVED — calling approve again should fail
SELECT throws_ok(
  $$SELECT fn_approve_match(
    (SELECT id_match FROM tbl_match_candidate WHERE txt_scraped_name = 'IDENTFENCER Alpha' AND enum_status = 'APPROVED'),
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'IDENTFENCER' AND txt_first_name = 'Alpha')
  )$$,
  NULL,
  '11.3: fn_approve_match on APPROVED candidate raises error'
);


-- =========================================================================
-- 11.4 — fn_approve_match with bad match_id raises error
-- =========================================================================
SELECT throws_ok(
  $$SELECT fn_approve_match(-99999, 1)$$,
  NULL,
  '11.4: fn_approve_match with non-existent match_id raises error'
);


-- =========================================================================
-- 11.5 — fn_approve_match with bad fencer_id raises error
-- =========================================================================
-- Create a fresh PENDING candidate for this test
DO $fresh_pending$
DECLARE
  v_tourn INT;
  v_f1 INT; v_f2 INT; v_f3 INT;
  v_results JSONB;
  v_summary JSONB;
BEGIN
  SELECT id_tournament INTO v_tourn FROM tbl_tournament WHERE txt_code = 'IDENT-TRN';
  SELECT id_fencer INTO v_f1 FROM tbl_fencer WHERE txt_surname = 'IDENTFENCER' AND txt_first_name = 'Alpha';
  SELECT id_fencer INTO v_f2 FROM tbl_fencer WHERE txt_surname = 'IDENTFENCER' AND txt_first_name = 'Beta';
  SELECT id_fencer INTO v_f3 FROM tbl_fencer WHERE txt_surname = 'IDENTFENCER' AND txt_first_name = 'Gamma';

  -- Re-ingest to reset state (ADR-014: delete+reinsert)
  v_results := jsonb_build_array(
    jsonb_build_object('id_fencer', v_f1, 'int_place', 1, 'txt_scraped_name', 'BADFENCER Test', 'num_confidence', 55.0, 'enum_match_status', 'PENDING'),
    jsonb_build_object('id_fencer', v_f2, 'int_place', 2, 'txt_scraped_name', 'UNMATCHED Person', 'num_confidence', 30.0, 'enum_match_status', 'UNMATCHED'),
    jsonb_build_object('id_fencer', v_f3, 'int_place', 3, 'txt_scraped_name', 'AUTO Person', 'num_confidence', 99.0, 'enum_match_status', 'AUTO_MATCHED')
  );
  v_summary := fn_ingest_tournament_results(v_tourn, v_results);
END;
$fresh_pending$;

SELECT throws_ok(
  $$SELECT fn_approve_match(
    (SELECT id_match FROM tbl_match_candidate WHERE txt_scraped_name = 'BADFENCER Test' AND enum_status = 'PENDING'),
    -99999
  )$$,
  NULL,
  '11.5: fn_approve_match with non-existent fencer_id raises error'
);


-- =========================================================================
-- 11.6 — fn_dismiss_match PENDING → DISMISSED + note
-- =========================================================================
SELECT is(
  (SELECT (fn_dismiss_match(
    (SELECT id_match FROM tbl_match_candidate WHERE txt_scraped_name = 'BADFENCER Test' AND enum_status = 'PENDING'),
    'Not a real fencer'
  )) ->> 'status'),
  'DISMISSED',
  '11.6: fn_dismiss_match on PENDING sets DISMISSED with note'
);


-- =========================================================================
-- 11.7 — fn_dismiss_match UNMATCHED → DISMISSED
-- =========================================================================
SELECT is(
  (SELECT (fn_dismiss_match(
    (SELECT id_match FROM tbl_match_candidate WHERE txt_scraped_name = 'UNMATCHED Person' AND enum_status = 'UNMATCHED')
  )) ->> 'status'),
  'DISMISSED',
  '11.7: fn_dismiss_match on UNMATCHED sets DISMISSED'
);


-- =========================================================================
-- 11.8 — fn_dismiss_match on APPROVED raises error
-- =========================================================================
-- Set one candidate to APPROVED first
DO $make_approved$
BEGIN
  UPDATE tbl_match_candidate SET enum_status = 'APPROVED'
  WHERE txt_scraped_name = 'AUTO Person' AND enum_status = 'AUTO_MATCHED'
  AND id_match = (SELECT id_match FROM tbl_match_candidate WHERE txt_scraped_name = 'AUTO Person' LIMIT 1);
END;
$make_approved$;

SELECT throws_ok(
  $$SELECT fn_dismiss_match(
    (SELECT id_match FROM tbl_match_candidate WHERE txt_scraped_name = 'AUTO Person' AND enum_status = 'APPROVED' LIMIT 1)
  )$$,
  NULL,
  '11.8: fn_dismiss_match on APPROVED raises error'
);


-- =========================================================================
-- Re-ingest for create-new tests
-- =========================================================================
DO $reingest$
DECLARE
  v_tourn INT;
  v_f1 INT; v_f2 INT;
  v_results JSONB;
  v_summary JSONB;
BEGIN
  SELECT id_tournament INTO v_tourn FROM tbl_tournament WHERE txt_code = 'IDENT-TRN';
  SELECT id_fencer INTO v_f1 FROM tbl_fencer WHERE txt_surname = 'IDENTFENCER' AND txt_first_name = 'Alpha';
  SELECT id_fencer INTO v_f2 FROM tbl_fencer WHERE txt_surname = 'IDENTFENCER' AND txt_first_name = 'Beta';

  v_results := jsonb_build_array(
    jsonb_build_object('id_fencer', v_f1, 'int_place', 1, 'txt_scraped_name', 'NEWGUY Test', 'num_confidence', 40.0, 'enum_match_status', 'PENDING'),
    jsonb_build_object('id_fencer', v_f2, 'int_place', 2, 'txt_scraped_name', 'ALREADY Done', 'num_confidence', 99.0, 'enum_match_status', 'AUTO_MATCHED')
  );
  v_summary := fn_ingest_tournament_results(v_tourn, v_results);
END;
$reingest$;


-- =========================================================================
-- 11.9 — fn_create_fencer_from_match inserts fencer
-- =========================================================================
SELECT lives_ok(
  $$SELECT fn_create_fencer_from_match(
    (SELECT id_match FROM tbl_match_candidate WHERE txt_scraped_name = 'NEWGUY Test' AND enum_status = 'PENDING'),
    'NEWGUY', 'Test', 1985
  )$$,
  '11.9: fn_create_fencer_from_match inserts new fencer'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_fencer WHERE txt_surname = 'NEWGUY' AND txt_first_name = 'Test'),
  1,
  '11.9b: New fencer exists in tbl_fencer'
);


-- =========================================================================
-- 11.10 — fn_create_fencer_from_match links result to new fencer
-- =========================================================================
SELECT is(
  (SELECT r.id_fencer FROM tbl_result r
   JOIN tbl_match_candidate mc ON mc.id_result = r.id_result
   WHERE mc.txt_scraped_name = 'NEWGUY Test' AND mc.enum_status = 'NEW_FENCER'),
  (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NEWGUY' AND txt_first_name = 'Test'),
  '11.10: fn_create_fencer_from_match links result to new fencer'
);


-- =========================================================================
-- 11.11 — fn_create_fencer_from_match sets status NEW_FENCER
-- =========================================================================
SELECT is(
  (SELECT enum_status::TEXT FROM tbl_match_candidate WHERE txt_scraped_name = 'NEWGUY Test'),
  'NEW_FENCER',
  '11.11: fn_create_fencer_from_match sets status NEW_FENCER'
);


-- =========================================================================
-- 11.12 — fn_create_fencer_from_match on APPROVED raises error
-- =========================================================================
DO $make_approved2$
BEGIN
  UPDATE tbl_match_candidate SET enum_status = 'APPROVED'
  WHERE txt_scraped_name = 'ALREADY Done'
  AND id_match = (SELECT id_match FROM tbl_match_candidate WHERE txt_scraped_name = 'ALREADY Done' LIMIT 1);
END;
$make_approved2$;

SELECT throws_ok(
  $$SELECT fn_create_fencer_from_match(
    (SELECT id_match FROM tbl_match_candidate WHERE txt_scraped_name = 'ALREADY Done' AND enum_status = 'APPROVED' LIMIT 1),
    'SHOULDNT', 'Work'
  )$$,
  NULL,
  '11.12: fn_create_fencer_from_match on APPROVED raises error'
);


-- =========================================================================
-- Re-ingest for AUTO_MATCHED + gender tests
-- =========================================================================
DO $reingest_auto$
DECLARE
  v_tourn INT;
  v_f1 INT; v_f2 INT; v_f3 INT;
  v_results JSONB;
  v_summary JSONB;
BEGIN
  SELECT id_tournament INTO v_tourn FROM tbl_tournament WHERE txt_code = 'IDENT-TRN';
  SELECT id_fencer INTO v_f1 FROM tbl_fencer WHERE txt_surname = 'IDENTFENCER' AND txt_first_name = 'Alpha';
  SELECT id_fencer INTO v_f2 FROM tbl_fencer WHERE txt_surname = 'IDENTFENCER' AND txt_first_name = 'Beta';
  SELECT id_fencer INTO v_f3 FROM tbl_fencer WHERE txt_surname = 'IDENTFENCER' AND txt_first_name = 'Gamma';

  v_results := jsonb_build_array(
    jsonb_build_object('id_fencer', v_f1, 'int_place', 1, 'txt_scraped_name', 'AUTO Approve Test', 'num_confidence', 92.0, 'enum_match_status', 'AUTO_MATCHED'),
    jsonb_build_object('id_fencer', v_f2, 'int_place', 2, 'txt_scraped_name', 'AUTO Dismiss Test', 'num_confidence', 80.0, 'enum_match_status', 'AUTO_MATCHED'),
    jsonb_build_object('id_fencer', v_f3, 'int_place', 3, 'txt_scraped_name', 'AUTO Create Test', 'num_confidence', 70.0, 'enum_match_status', 'AUTO_MATCHED')
  );
  v_summary := fn_ingest_tournament_results(v_tourn, v_results);
END;
$reingest_auto$;


-- =========================================================================
-- 11.13 — fn_approve_match on AUTO_MATCHED → APPROVED
-- =========================================================================
SELECT lives_ok(
  $$SELECT fn_approve_match(
    (SELECT id_match FROM tbl_match_candidate WHERE txt_scraped_name = 'AUTO Approve Test' AND enum_status = 'AUTO_MATCHED'),
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'IDENTFENCER' AND txt_first_name = 'Alpha')
  )$$,
  '11.13: fn_approve_match on AUTO_MATCHED executes without error'
);


-- =========================================================================
-- 11.14 — fn_dismiss_match on AUTO_MATCHED → DISMISSED
-- =========================================================================
SELECT is(
  (SELECT (fn_dismiss_match(
    (SELECT id_match FROM tbl_match_candidate WHERE txt_scraped_name = 'AUTO Dismiss Test' AND enum_status = 'AUTO_MATCHED')
  )) ->> 'status'),
  'DISMISSED',
  '11.14: fn_dismiss_match on AUTO_MATCHED sets DISMISSED'
);


-- =========================================================================
-- 11.15 — fn_create_fencer_from_match on AUTO_MATCHED → NEW_FENCER
-- =========================================================================
SELECT lives_ok(
  $$SELECT fn_create_fencer_from_match(
    (SELECT id_match FROM tbl_match_candidate WHERE txt_scraped_name = 'AUTO Create Test' AND enum_status = 'AUTO_MATCHED'),
    'AUTOCREATED', 'Fencer', NULL, 'M'
  )$$,
  '11.15: fn_create_fencer_from_match on AUTO_MATCHED executes without error'
);


-- =========================================================================
-- 11.16 — fn_create_fencer_from_match with gender stores enum_gender
-- =========================================================================
SELECT is(
  (SELECT enum_gender::TEXT FROM tbl_fencer WHERE txt_surname = 'AUTOCREATED' AND txt_first_name = 'Fencer'),
  'M',
  '11.16: fn_create_fencer_from_match stores enum_gender on new fencer'
);


-- =========================================================================
-- 11.17 — fn_update_fencer_gender sets gender
-- =========================================================================
SELECT lives_ok(
  $$SELECT fn_update_fencer_gender(
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'IDENTFENCER' AND txt_first_name = 'Alpha'),
    'M'
  )$$,
  '11.17: fn_update_fencer_gender executes without error'
);

SELECT is(
  (SELECT enum_gender::TEXT FROM tbl_fencer WHERE txt_surname = 'IDENTFENCER' AND txt_first_name = 'Alpha'),
  'M',
  '11.17b: fn_update_fencer_gender persists gender value'
);


-- =========================================================================
-- 11.18 — fn_update_fencer_gender with bad fencer raises error
-- =========================================================================
SELECT throws_ok(
  $$SELECT fn_update_fencer_gender(-99999, 'M')$$,
  NULL,
  '11.18: fn_update_fencer_gender with non-existent fencer raises error'
);


-- =========================================================================
-- 11.19 — vw_match_candidates returns enum_tournament_gender + enum_fencer_gender
-- =========================================================================
SELECT is(
  (SELECT enum_tournament_gender::TEXT FROM vw_match_candidates
   WHERE txt_scraped_name = 'AUTO Approve Test' LIMIT 1),
  'M',
  '11.19: vw_match_candidates returns enum_tournament_gender'
);


SELECT * FROM finish();
ROLLBACK;
