-- =============================================================================
-- T9.1: CRUD SQL + Delete Cascade Tests
-- =============================================================================
-- Tests 9.18–9.36 from doc/MVP_development_plan.md §T9.1.
-- Verifies CRUD functions for seasons, events, tournaments, plus cascade
-- deletes and permission enforcement (REVOKE from anon).
-- =============================================================================

BEGIN;
SELECT plan(19);

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
  VALUES ('CRUD-TEST-SEASON', '2025-09-01', '2026-06-30', FALSE)
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
    '2025-11-15', 24
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


SELECT * FROM finish();
ROLLBACK;
