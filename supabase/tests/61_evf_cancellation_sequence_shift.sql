-- =============================================================================
-- pgTAP — an EVF event code may shift only when nothing is anchored to it
-- =============================================================================
-- Verifies migration 20260828000005_evf_cancellation_sequence_shift.sql
-- (ADR-086 §4).
--
-- PEW numbers are chronological position, so a newly announced mid-season event
-- moves every later event down one. ADR-043 permits reflow of unscored rows but
-- also pinned a later cancellation absolutely; the two collided live on
-- 2026-08-28 when admitting Tampere moved Stockholm PEW11 -> PEW12 in the same
-- scrape that cancelled it.
--
-- The pin now yields only while nothing is anchored to the old code. This test
-- pins each arm of "anchored" separately, because a single boolean hides which
-- condition actually fired.
-- =============================================================================

BEGIN;

SELECT plan(7);

-- 61.1 — helper exists
SELECT has_function(
  'fn_evf_event_code_is_movable',
  '61.1 — fn_evf_event_code_is_movable() exists'
);

-- ----- fixtures -----
DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
  v_future INT;
  v_past   INT;
  v_undated INT;
  v_reg    INT;
  v_res    INT;
  v_tourn  INT;
BEGIN
  INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
  VALUES ('TEST-SEASON-6100', '2099-01-01', '2099-12-31', FALSE)
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'TEST-SEASON-6100';
  SELECT id_organizer INTO v_org FROM tbl_organizer LIMIT 1;

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start)
  VALUES ('PEW80es-6100-6101', 'Future clean', v_season, v_org, 'PLANNED', '2099-06-01')
  RETURNING id_event INTO v_future;

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start)
  VALUES ('PEW81es-6100-6101', 'Already happened', v_season, v_org, 'PLANNED', '2020-06-01')
  RETURNING id_event INTO v_past;

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start)
  VALUES ('PEW82es-6100-6101', 'No date at all', v_season, v_org, 'PLANNED', NULL)
  RETURNING id_event INTO v_undated;

  -- future, but somebody has entered
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start)
  VALUES ('PEW83es-6100-6101', 'Future with entrant', v_season, v_org, 'PLANNED', '2099-06-01')
  RETURNING id_event INTO v_reg;
  INSERT INTO tbl_registration (
    id_event, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons
  ) VALUES (
    v_reg, 'TESTOWY', 'Jan', 'M', 1975, ARRAY['EPEE']::enum_weapon_type[]
  );

  -- future, but already holds a result
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start)
  VALUES ('PEW84es-6100-6101', 'Future with result', v_season, v_org, 'PLANNED', '2099-06-01')
  RETURNING id_event INTO v_res;
  INSERT INTO tbl_tournament (
    id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category
  ) VALUES (
    v_res, 'PEW84es-6100-6101-V2-M-EPEE', 'PEW', 'EPEE', 'M', 'V2'
  ) RETURNING id_tournament INTO v_tourn;
  INSERT INTO tbl_result (id_tournament, int_place) VALUES (v_tourn, 1);
END;
$setup$;

-- 61.2 — future, unregistered, result-free: the code may move
SELECT ok(
  fn_evf_event_code_is_movable(
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW80es-6100-6101')),
  '61.2 — future event with nothing anchored to it is movable'
);

-- 61.3 — a past event is never silently renamed
SELECT ok(
  NOT fn_evf_event_code_is_movable(
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW81es-6100-6101')),
  '61.3 — an event that already happened is not movable'
);

-- 61.4 — unknown is not zero
SELECT ok(
  NOT fn_evf_event_code_is_movable(
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW82es-6100-6101')),
  '61.4 — an event with no start date is not movable'
);

-- 61.5 — a fencer holds this code; it must not move under them
SELECT ok(
  NOT fn_evf_event_code_is_movable(
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW83es-6100-6101')),
  '61.5 — an event with a registration is not movable'
);

-- 61.6 — results are anchored via the child tournament codes
SELECT ok(
  NOT fn_evf_event_code_is_movable(
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW84es-6100-6101')),
  '61.6 — an event holding results is not movable'
);

-- 61.7 — an unknown event is not movable (never NULL, never true)
SELECT ok(
  NOT fn_evf_event_code_is_movable(-999999),
  '61.7 — an unknown event id is not movable'
);

SELECT * FROM finish();
ROLLBACK;
