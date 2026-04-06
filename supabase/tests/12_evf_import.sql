-- =============================================================================
-- EVF Import Tests (ADR-028)
-- =============================================================================
-- Tests 12.1–12.4: fn_import_evf_events
-- =============================================================================

BEGIN;
SELECT plan(4);

-- ===== SETUP =====
DO $setup$
DECLARE
  v_season INT;
BEGIN
  UPDATE tbl_season SET bool_active = FALSE;
  v_season := fn_create_season('EVF-TEST', '2030-09-01', '2031-06-30');
  UPDATE tbl_season SET bool_active = TRUE WHERE id_season = v_season;
END;
$setup$;


-- =========================================================================
-- 12.1 — fn_import_evf_events creates event with PLANNED status
-- =========================================================================
DO $t121$
DECLARE
  v_season INT;
  v_result JSONB;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'EVF-TEST';
  v_result := fn_import_evf_events(
    '[{"code": "PEW-TESTCITY-2030-2031", "name": "EVF Circuit Test City", "dt_start": "2031-03-15", "dt_end": "2031-03-16", "location": "Test City", "country": "Germany", "weapons": ["EPEE", "FOIL"], "is_team": false}]'::JSONB,
    v_season
  );
END;
$t121$;

SELECT is(
  (SELECT enum_status::TEXT FROM tbl_event WHERE txt_code = 'PEW-TESTCITY-2030-2031'),
  'PLANNED',
  '12.1: fn_import_evf_events creates event with PLANNED status'
);


-- =========================================================================
-- 12.2 — fn_import_evf_events creates child tournaments per weapon
-- =========================================================================
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_tournament WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW-TESTCITY-2030-2031')),
  4,
  '12.2: fn_import_evf_events creates 4 tournaments (2 weapons × 2 genders)'
);


-- =========================================================================
-- 12.3 — fn_import_evf_events sets tournament type to PEW
-- =========================================================================
SELECT is(
  (SELECT DISTINCT enum_type::TEXT FROM tbl_tournament WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW-TESTCITY-2030-2031')),
  'PEW',
  '12.3: All tournaments have type PEW'
);


-- =========================================================================
-- 12.4 — Duplicate import is idempotent
-- =========================================================================
DO $t124$
DECLARE
  v_season INT;
  v_result JSONB;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'EVF-TEST';
  v_result := fn_import_evf_events(
    '[{"code": "PEW-TESTCITY-2030-2031", "name": "EVF Circuit Test City", "dt_start": "2031-03-15", "weapons": ["EPEE", "FOIL"], "is_team": false}]'::JSONB,
    v_season
  );
END;
$t124$;

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event WHERE txt_code = 'PEW-TESTCITY-2030-2031'),
  1,
  '12.4: Duplicate import is idempotent — still 1 event'
);


SELECT * FROM finish();
ROLLBACK;
