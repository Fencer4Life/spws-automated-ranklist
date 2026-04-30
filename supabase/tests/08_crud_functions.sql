-- =============================================================================
-- T9.1: CRUD SQL + Delete Cascade Tests
-- =============================================================================
-- Tests 9.18–9.36 from doc/MVP_development_plan.md §T9.1.
-- Verifies CRUD functions for seasons, events, tournaments, plus cascade
-- deletes and permission enforcement (REVOKE from anon).
-- =============================================================================

BEGIN;
-- Layer 6 (2026-04-30): targeted bypass of trg_assert_result_vcat for
-- legacy test fixtures whose dummy V-cats predate the FATAL invariant
-- guard. Targeted (not session_replication_role) so audit + status-
-- transition triggers stay live.
ALTER TABLE tbl_result DISABLE TRIGGER trg_assert_result_vcat;
SELECT plan(30);

-- ===== SETUP: create test data for CRUD and cascade tests =====

DO $setup$
DECLARE
  v_season   INT;
  v_org      INT;
  v_event    INT;
  v_tourn    INT;
  v_fencer   INT;
  v_result   INT;
BEGIN
  -- Get existing organizer from seed
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  -- Create a season with events for cascade testing
  INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
  VALUES ('CRUD-TEST-SEASON', '2035-09-01', '2036-06-30', FALSE)
  RETURNING id_season INTO v_season;

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('CRUD-EVT-1', 'CRUD Test Event', v_season, v_org, 'PLANNED')
  RETURNING id_event INTO v_event;

  INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count
  ) VALUES (
    v_event, 'CRUD-TRN-1', 'CRUD Test Tournament', 'PPW',
    'EPEE', 'M', 'V2',
    '2035-11-15', 24
  ) RETURNING id_tournament INTO v_tourn;

  -- Get a fencer from seed data
  SELECT id_fencer INTO v_fencer FROM tbl_fencer LIMIT 1;

  -- Insert a result for cascade testing
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
  VALUES (v_fencer, v_tourn, 1)
  RETURNING id_result INTO v_result;

  -- Insert a match candidate for cascade testing
  INSERT INTO tbl_match_candidate (id_result, txt_scraped_name, id_fencer, num_confidence, enum_status)
  VALUES (v_result, 'Test Fencer', v_fencer, 99.5, 'AUTO_MATCHED');
END;
$setup$;


-- =========================================================================
-- Season CRUD (9.18–9.22, 9.27)
-- =========================================================================

-- 9.18 — fn_create_season inserts row + auto-creates scoring_config
DO $t918$
DECLARE
  v_sid INT;
BEGIN
  v_sid := fn_create_season('NEW-CRUD-S', '2026-09-01', '2027-06-30');
END;
$t918$;
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_scoring_config sc JOIN tbl_season s ON s.id_season = sc.id_season WHERE s.txt_code = 'NEW-CRUD-S'),
  1,
  '9.18: fn_create_season inserts row + auto-creates scoring_config'
);

-- 9.19 — fn_create_season duplicate txt_code raises error
SELECT throws_ok(
  $$SELECT fn_create_season('NEW-CRUD-S', '2026-09-01', '2027-06-30')$$,
  '23505',
  NULL,
  '9.19: fn_create_season duplicate txt_code raises unique violation'
);

-- 9.20 — fn_update_season updates txt_code, dt_start, dt_end
DO $t920$
DECLARE
  v_sid INT;
BEGIN
  SELECT id_season INTO v_sid FROM tbl_season WHERE txt_code = 'NEW-CRUD-S';
  PERFORM fn_update_season(v_sid, 'RENAMED-S', '2026-10-01', '2027-07-31');
END;
$t920$;
SELECT ok(
  EXISTS(SELECT 1 FROM tbl_season WHERE txt_code = 'RENAMED-S' AND dt_start = '2026-10-01' AND dt_end = '2027-07-31'),
  '9.20: fn_update_season updates txt_code, dt_start, dt_end'
);

-- 9.21 — fn_delete_season with no events succeeds
DO $t921$
DECLARE
  v_sid INT;
BEGIN
  SELECT id_season INTO v_sid FROM tbl_season WHERE txt_code = 'RENAMED-S';
  PERFORM fn_delete_season(v_sid);
END;
$t921$;
SELECT ok(
  NOT EXISTS(SELECT 1 FROM tbl_season WHERE txt_code = 'RENAMED-S'),
  '9.21: fn_delete_season with no events succeeds'
);

-- 9.22 — fn_delete_season with events raises error
SELECT throws_ok(
  $$SELECT fn_delete_season((SELECT id_season FROM tbl_season WHERE txt_code = 'CRUD-TEST-SEASON'))$$,
  NULL,
  NULL,
  '9.22: fn_delete_season with events raises FK error'
);

-- 9.27 — fn_create_season permission denied for anon
SET LOCAL ROLE anon;
SELECT throws_ok(
  $$SELECT fn_create_season('ANON-TEST', '2026-01-01', '2026-12-31')$$,
  '42501',
  NULL,
  '9.27: fn_create_season permission denied for anon'
);
RESET ROLE;


-- =========================================================================
-- Event CRUD (9.23–9.24, 9.28)
-- =========================================================================

-- 9.23 — fn_create_event inserts with all M8 columns
DO $t923$
DECLARE
  v_sid INT;
  v_org INT;
  v_eid INT;
BEGIN
  SELECT id_season INTO v_sid FROM tbl_season WHERE txt_code = 'CRUD-TEST-SEASON';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';
  v_eid := fn_create_event(
    'CRUD-EVT-NEW', 'New CRUD Event', v_sid, v_org,
    'Warszawa', '2025-12-01', '2025-12-02', 'https://example.com',
    'PL', 'ul. Testowa 1', 'https://example.com/invite', 80.00,
    'PLN', '{EPEE,FOIL,SABRE}'::enum_weapon_type[]
  );
END;
$t923$;
SELECT ok(
  EXISTS(
    SELECT 1 FROM tbl_event
    WHERE txt_code = 'CRUD-EVT-NEW'
      AND txt_country = 'PL'
      AND txt_venue_address = 'ul. Testowa 1'
      AND url_invitation = 'https://example.com/invite'
      AND num_entry_fee = 80.00
  ),
  '9.23: fn_create_event inserts with all M8 columns'
);

-- 9.24 — fn_update_event updates and logs to audit_log
DO $t924$
DECLARE
  v_eid INT;
  v_audit_before INT;
BEGIN
  SELECT id_event INTO v_eid FROM tbl_event WHERE txt_code = 'CRUD-EVT-NEW';
  SELECT COUNT(*) INTO v_audit_before FROM tbl_audit_log WHERE txt_table_name = 'tbl_event' AND id_row = v_eid;
  PERFORM fn_update_event(
    v_eid, 'Updated Event', 'Kraków', '2025-12-10', '2025-12-11',
    'https://updated.com', 'PL', 'ul. Nowa 2', 'https://updated.com/invite', 100.00,
    'EUR', NULL, '{EPEE,SABRE}'::enum_weapon_type[]
  );
END;
$t924$;
SELECT ok(
  EXISTS(
    SELECT 1 FROM tbl_audit_log
    WHERE txt_table_name = 'tbl_event'
      AND txt_action = 'UPDATE'
      AND id_row = (SELECT id_event FROM tbl_event WHERE txt_code = 'CRUD-EVT-NEW')
  ),
  '9.24: fn_update_event updates and logs to audit_log'
);

-- 9.28 — fn_create_event permission denied for anon
SET LOCAL ROLE anon;
SELECT throws_ok(
  $$SELECT fn_create_event('ANON-EVT', 'Anon Event', 1, 1, NULL, NULL::DATE, NULL::DATE, NULL, NULL, NULL, NULL, NULL::NUMERIC, NULL, NULL::enum_weapon_type[])$$,
  '42501',
  NULL,
  '9.28: fn_create_event permission denied for anon'
);
RESET ROLE;


-- =========================================================================
-- Tournament CRUD (9.25–9.26, 9.29)
-- =========================================================================

-- 9.25 — fn_create_tournament inserts with auto-populated multiplier
DO $t925$
DECLARE
  v_eid INT;
  v_tid INT;
BEGIN
  SELECT id_event INTO v_eid FROM tbl_event WHERE txt_code = 'CRUD-EVT-NEW';
  v_tid := fn_create_tournament(
    v_eid, 'CRUD-TRN-NEW', 'New CRUD Tournament', 'PPW',
    'EPEE', 'M', 'V2', '2025-12-01', 16, NULL
  );
END;
$t925$;
SELECT ok(
  EXISTS(
    SELECT 1 FROM tbl_tournament
    WHERE txt_code = 'CRUD-TRN-NEW' AND num_multiplier IS NOT NULL
  ),
  '9.25: fn_create_tournament inserts with auto-populated multiplier'
);

-- 9.26 — fn_update_tournament updates url_results, import_status
DO $t926$
DECLARE
  v_tid INT;
BEGIN
  SELECT id_tournament INTO v_tid FROM tbl_tournament WHERE txt_code = 'CRUD-TRN-NEW';
  PERFORM fn_update_tournament(v_tid, 'https://results.com', 'IMPORTED', 'Imported OK');
END;
$t926$;
SELECT ok(
  EXISTS(
    SELECT 1 FROM tbl_tournament
    WHERE txt_code = 'CRUD-TRN-NEW'
      AND url_results = 'https://results.com'
      AND enum_import_status = 'IMPORTED'
      AND txt_import_status_reason = 'Imported OK'
  ),
  '9.26: fn_update_tournament updates url_results, import_status'
);

-- 9.29 — fn_create_tournament permission denied for anon
SET LOCAL ROLE anon;
SELECT throws_ok(
  $$SELECT fn_create_tournament(1, 'ANON-TRN', 'Anon', 'PPW', 'EPEE', 'M', 'V2', NULL, NULL, NULL)$$,
  '42501',
  NULL,
  '9.29: fn_create_tournament permission denied for anon'
);
RESET ROLE;


-- =========================================================================
-- Delete Cascade (9.30–9.36)
-- =========================================================================

-- Test fn_delete_tournament_cascade on CRUD-TRN-1
-- (which has 1 result + 1 match_candidate from setup)

-- 9.30 — fn_delete_tournament_cascade deletes match_candidates
-- 9.31 — fn_delete_tournament_cascade deletes results
-- 9.32 — fn_delete_tournament_cascade deletes the tournament
DO $cascade_tourn$
DECLARE
  v_tid INT;
BEGIN
  SELECT id_tournament INTO v_tid FROM tbl_tournament WHERE txt_code = 'CRUD-TRN-1';
  PERFORM fn_delete_tournament_cascade(v_tid);
END;
$cascade_tourn$;

SELECT ok(
  NOT EXISTS(
    SELECT 1 FROM tbl_match_candidate mc
    JOIN tbl_result r ON r.id_result = mc.id_result
    JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
    WHERE t.txt_code = 'CRUD-TRN-1'
  ),
  '9.30: fn_delete_tournament_cascade deletes match_candidates'
);

SELECT ok(
  NOT EXISTS(
    SELECT 1 FROM tbl_result r
    JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
    WHERE t.txt_code = 'CRUD-TRN-1'
  ),
  '9.31: fn_delete_tournament_cascade deletes results'
);

SELECT ok(
  NOT EXISTS(SELECT 1 FROM tbl_tournament WHERE txt_code = 'CRUD-TRN-1'),
  '9.32: fn_delete_tournament_cascade deletes the tournament'
);

-- Test fn_delete_event_cascade on CRUD-EVT-NEW
-- (which has CRUD-TRN-NEW tournament from earlier tests)

-- First add a result to CRUD-TRN-NEW so cascade has something to delete
DO $cascade_evt_setup$
DECLARE
  v_tid INT;
  v_fid INT;
BEGIN
  SELECT id_tournament INTO v_tid FROM tbl_tournament WHERE txt_code = 'CRUD-TRN-NEW';
  SELECT id_fencer INTO v_fid FROM tbl_fencer LIMIT 1;
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
  VALUES (v_fid, v_tid, 1);
END;
$cascade_evt_setup$;

DO $cascade_evt$
DECLARE
  v_eid INT;
BEGIN
  SELECT id_event INTO v_eid FROM tbl_event WHERE txt_code = 'CRUD-EVT-NEW';
  PERFORM fn_delete_event_cascade(v_eid);
END;
$cascade_evt$;

-- 9.33 — fn_delete_event_cascade deletes all child tournaments+results+candidates
SELECT ok(
  NOT EXISTS(SELECT 1 FROM tbl_tournament WHERE txt_code = 'CRUD-TRN-NEW'),
  '9.33: fn_delete_event_cascade deletes all child tournaments+results+candidates'
);

-- 9.34 — fn_delete_event_cascade deletes the event
SELECT ok(
  NOT EXISTS(SELECT 1 FROM tbl_event WHERE txt_code = 'CRUD-EVT-NEW'),
  '9.34: fn_delete_event_cascade deletes the event'
);

-- 9.35 — fn_delete_event_cascade logs to audit_log
SELECT ok(
  EXISTS(
    SELECT 1 FROM tbl_audit_log
    WHERE txt_table_name = 'tbl_event'
      AND txt_action = 'DELETE'
  ),
  '9.35: fn_delete_event_cascade logs to audit_log'
);

-- 9.36 — fn_delete_event_cascade permission denied for anon
SET LOCAL ROLE anon;
SELECT throws_ok(
  $$SELECT fn_delete_event_cascade(1)$$,
  '42501',
  NULL,
  '9.36: fn_delete_event_cascade permission denied for anon'
);
RESET ROLE;


-- =========================================================================
-- EVF Toggle Config (9.37–9.39, ADR-017)
-- =========================================================================

-- 9.37 — bool_show_evf_toggle column exists with default FALSE
SELECT has_column(
  'tbl_scoring_config', 'bool_show_evf_toggle',
  '9.37: tbl_scoring_config has bool_show_evf_toggle column'
);
SELECT is(
  (SELECT bool_show_evf_toggle FROM tbl_scoring_config LIMIT 1),
  FALSE,
  '9.37b: bool_show_evf_toggle defaults to FALSE'
);

-- 9.38 — fn_export_scoring_config includes show_evf_toggle key
SELECT ok(
  (SELECT fn_export_scoring_config(
    (SELECT id_season FROM tbl_season WHERE bool_active LIMIT 1)
  ) ? 'show_evf_toggle'),
  '9.38: fn_export_scoring_config includes show_evf_toggle key'
);

-- 9.39 — fn_import_scoring_config accepts and persists show_evf_toggle
DO $t939$
DECLARE
  v_sid INT;
BEGIN
  SELECT id_season INTO v_sid FROM tbl_season WHERE bool_active LIMIT 1;
  PERFORM fn_import_scoring_config(
    jsonb_build_object('id_season', v_sid, 'show_evf_toggle', true)
  );
END;
$t939$;
SELECT is(
  (SELECT (fn_export_scoring_config(
    (SELECT id_season FROM tbl_season WHERE bool_active LIMIT 1)
  ))->>'show_evf_toggle'),
  'true',
  '9.39: fn_import_scoring_config persists show_evf_toggle = true'
);


-- =========================================================================
-- Season Config Inheritance (9.40, ADR-018 prerequisite)
-- =========================================================================

-- 9.40 — fn_create_season copies json_ranking_rules from previous season
DO $t940$
DECLARE
  v_base_sid INT;
  v_new_sid  INT;
  v_rules    JSONB := '{"domestic":[{"best":4,"types":["PPW"]},{"types":["MPW"],"always":true}]}'::JSONB;
BEGIN
  -- Create a base season with known ranking rules
  v_base_sid := fn_create_season('RULES-BASE', '2038-08-01', '2039-07-15');
  UPDATE tbl_scoring_config
     SET json_ranking_rules = v_rules
   WHERE id_season = v_base_sid;

  -- Create a new season after the base season
  v_new_sid := fn_create_season('RULES-INHERIT', '2039-08-01', '2040-07-15');

  -- Verify the new season inherited the rules
  PERFORM 1 FROM tbl_scoring_config
   WHERE id_season = v_new_sid
     AND json_ranking_rules = v_rules;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'json_ranking_rules not copied to new season';
  END IF;
END;
$t940$;
SELECT pass('9.40: fn_create_season copies json_ranking_rules from previous season');


-- =========================================================================
-- Auto-Active Season (9.41–9.46, ADR-031)
-- =========================================================================

-- 9.41 — fn_refresh_active_season activates season engulfing today
DO $t941$
DECLARE
  v_active_id INT;
BEGIN
  -- Seed data: SPWS-2025-2026 has dt_start=2025-08-01, dt_end=2026-07-15
  -- Today (2026-04-11) falls within it
  PERFORM fn_refresh_active_season();
  SELECT id_season INTO v_active_id FROM tbl_season WHERE bool_active = TRUE;
  IF v_active_id IS NULL THEN
    RAISE EXCEPTION 'no active season after refresh';
  END IF;
  -- Verify it's the season engulfing today
  PERFORM 1 FROM tbl_season
   WHERE id_season = v_active_id
     AND dt_start <= CURRENT_DATE
     AND dt_end >= CURRENT_DATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'active season does not engulf today';
  END IF;
END;
$t941$;
SELECT pass('9.41: fn_refresh_active_season activates season engulfing today');

-- 9.42 — fn_refresh_active_season fallback to nearest future season
DO $t942$
DECLARE
  v_future_sid INT;
  v_active_id  INT;
  v_rec        RECORD;
  v_idx        INT := 0;
BEGIN
  -- Move each existing season to a unique past date range (avoids overlap constraint)
  FOR v_rec IN SELECT id_season FROM tbl_season ORDER BY id_season LOOP
    UPDATE tbl_season
       SET dt_start = ('2000-01-01'::DATE + v_idx * 400),
           dt_end   = ('2000-06-01'::DATE + v_idx * 400)
     WHERE id_season = v_rec.id_season;
    v_idx := v_idx + 1;
  END LOOP;
  -- Create a future season
  v_future_sid := fn_create_season('FUTURE-ONLY', '2040-08-01', '2041-07-15');
  -- Refresh — should pick the nearest future
  PERFORM fn_refresh_active_season();
  SELECT id_season INTO v_active_id FROM tbl_season WHERE bool_active = TRUE;
  IF v_active_id <> v_future_sid THEN
    RAISE EXCEPTION 'expected future season %, got %', v_future_sid, v_active_id;
  END IF;
END;
$t942$;
SELECT pass('9.42: fn_refresh_active_season fallback to nearest future season');

-- 9.43 — fn_refresh_active_season: no active season when all are past
DO $t943$
DECLARE
  v_count INT;
  v_rec   RECORD;
  v_idx   INT := 0;
BEGIN
  -- Move each season to a unique past date range (avoids overlap constraint)
  FOR v_rec IN SELECT id_season FROM tbl_season ORDER BY id_season LOOP
    UPDATE tbl_season
       SET dt_start = ('2000-01-01'::DATE + v_idx * 400),
           dt_end   = ('2000-06-01'::DATE + v_idx * 400)
     WHERE id_season = v_rec.id_season;
    v_idx := v_idx + 1;
  END LOOP;
  PERFORM fn_refresh_active_season();
  SELECT COUNT(*) INTO v_count FROM tbl_season WHERE bool_active = TRUE;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'expected no active season, got %', v_count;
  END IF;
END;
$t943$;
SELECT pass('9.43: fn_refresh_active_season: no active season when all are past');

-- 9.44 — Exclusion constraint rejects overlapping season dates
DO $t944$
BEGIN
  -- Create two non-overlapping seasons, then try to insert one that overlaps the first
  INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
  VALUES ('OVERLAP-A', '2060-01-01', '2060-06-30', FALSE);
  -- This should fail: overlaps with OVERLAP-A
  INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
  VALUES ('OVERLAP-B', '2060-03-01', '2060-12-31', FALSE);
  RAISE EXCEPTION 'expected constraint violation but insert succeeded';
EXCEPTION
  WHEN exclusion_violation THEN
    NULL; -- expected
END;
$t944$;
SELECT pass('9.44: exclusion constraint rejects overlapping season dates');

-- 9.45 — Trigger auto-activates on season INSERT (engulfs today)
DO $t945$
DECLARE
  v_sid       INT;
  v_is_active BOOLEAN;
BEGIN
  -- Insert a season engulfing today — trigger should auto-activate it
  INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
  VALUES ('AUTO-ACTIVE-INS', '2026-01-01', '2026-12-31', FALSE)
  RETURNING id_season INTO v_sid;
  SELECT bool_active INTO v_is_active FROM tbl_season WHERE id_season = v_sid;
  IF NOT v_is_active THEN
    RAISE EXCEPTION 'season not auto-activated on INSERT';
  END IF;
END;
$t945$;
SELECT pass('9.45: trigger auto-activates on season INSERT');

-- 9.46 — Trigger auto-corrects on season UPDATE (date change)
DO $t946$
DECLARE
  v_sid1 INT;
  v_sid2 INT;
BEGIN
  -- Create two non-overlapping future seasons
  INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
  VALUES ('CORRECT-A', '2070-01-01', '2070-06-30', FALSE)
  RETURNING id_season INTO v_sid1;
  INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
  VALUES ('CORRECT-B', '2071-01-01', '2071-06-30', FALSE)
  RETURNING id_season INTO v_sid2;
  -- If AUTO-ACTIVE-INS (engulfing today) is still present, it's the primary active.
  -- Remove it so fallback logic kicks in for future seasons.
  DELETE FROM tbl_scoring_config WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'AUTO-ACTIVE-INS');
  DELETE FROM tbl_season WHERE txt_code = 'AUTO-ACTIVE-INS';
  -- Now refresh — CORRECT-A should be nearest future (2070 < 2071)
  -- But we also have FUTURE-ONLY at 2040 and possibly OVERLAP-A at 2060...
  -- FUTURE-ONLY (2040) is nearer, so delete test seasons that interfere
  DELETE FROM tbl_scoring_config WHERE id_season IN (SELECT id_season FROM tbl_season WHERE txt_code IN ('FUTURE-ONLY', 'OVERLAP-A'));
  DELETE FROM tbl_season WHERE txt_code IN ('FUTURE-ONLY', 'OVERLAP-A');
  PERFORM fn_refresh_active_season();
  -- CORRECT-A (2070) should be active (nearest future, all others are in the past)
  PERFORM 1 FROM tbl_season WHERE id_season = v_sid1 AND bool_active = TRUE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'nearest future season not active after cleanup';
  END IF;
  -- Move CORRECT-A to the distant past — CORRECT-B should become active
  UPDATE tbl_season SET dt_start = '1990-01-01', dt_end = '1990-06-30'
   WHERE id_season = v_sid1;
  PERFORM 1 FROM tbl_season WHERE id_season = v_sid2 AND bool_active = TRUE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'active season not corrected after UPDATE';
  END IF;
END;
$t946$;
SELECT pass('9.46: trigger auto-corrects on season UPDATE (date change)');


SELECT * FROM finish();
ROLLBACK;
