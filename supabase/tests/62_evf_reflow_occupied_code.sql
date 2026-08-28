-- =============================================================================
-- pgTAP — a mid-season insertion reflows the whole tail without collision
-- =============================================================================
-- Verifies migration 20260828000006_evf_reflow_occupied_code.sql.
--
-- Codes are chronological position, so inserting one event mid-season shifts
-- every later event down one. Because the loop assigns in date order, each
-- shifted event momentarily collides with its own successor: live run
-- 33188636456 aborted with "unsafe occupied code PEW16efs-2026-2027" when
-- Dublin reached the code Toronto had not yet vacated.
--
-- 62.2 is the regression: before the fix it raised; after it, the tail reflows.
-- 62.3 and 62.4 pin that the guard still refuses the two cases it must.
-- =============================================================================

BEGIN;

SELECT plan(5);

SELECT has_function(
  'fn_ingest_evf_calendar',
  '62.1 — fn_ingest_evf_calendar() exists'
);

-- ----- fixtures: three future EVF events, chronological, no results -----
DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
BEGIN
  INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
  VALUES ('SPWS-6200-6201', '6200-08-01', '6201-07-31', FALSE)
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-6200-6201';

  INSERT INTO tbl_organizer (txt_code, txt_name)
  VALUES ('EVF', 'European Veterans Fencing')
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'EVF';

  INSERT INTO tbl_event (
    txt_code, txt_name, id_season, id_organizer, enum_status,
    dt_start, dt_end, id_evf_calendar_event, arr_weapons
  ) VALUES
    ('PEW1e-6200-6201', 'Alpha', v_season, v_org, 'PLANNED',
     '6200-10-01', '6200-10-01', 901, ARRAY['EPEE']::enum_weapon_type[]),
    ('PEW2e-6200-6201', 'Beta',  v_season, v_org, 'PLANNED',
     '6200-11-01', '6200-11-01', 902, ARRAY['EPEE']::enum_weapon_type[]),
    ('PEW3e-6200-6201', 'Gamma', v_season, v_org, 'PLANNED',
     '6200-12-01', '6200-12-01', 903, ARRAY['EPEE']::enum_weapon_type[]);
END;
$setup$;

-- 62.2 — insert a new event between Alpha and Beta; the tail must reflow
SELECT lives_ok(
  $ing$
  DO $body$
  DECLARE
    v_season INT;
  BEGIN
    SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-6200-6201';
    PERFORM fn_ingest_evf_calendar(
      jsonb_build_array(
        jsonb_build_object('name','Alpha','dt_start','6200-10-01','dt_end','6200-10-01',
          'weapons', jsonb_build_array('EPEE'), 'evf_calendar_id', 901,
          'existing_id_event', (SELECT id_event FROM tbl_event WHERE id_evf_calendar_event=901),
          'is_cancelled', false, 'desired_code','PEW1e-6200-6201'),
        jsonb_build_object('name','Inserted','dt_start','6200-10-15','dt_end','6200-10-15',
          'weapons', jsonb_build_array('EPEE'), 'evf_calendar_id', 904,
          'is_cancelled', false, 'desired_code','PEW2e-6200-6201'),
        jsonb_build_object('name','Beta','dt_start','6200-11-01','dt_end','6200-11-01',
          'weapons', jsonb_build_array('EPEE'), 'evf_calendar_id', 902,
          'existing_id_event', (SELECT id_event FROM tbl_event WHERE id_evf_calendar_event=902),
          'is_cancelled', false, 'desired_code','PEW3e-6200-6201'),
        jsonb_build_object('name','Gamma','dt_start','6200-12-01','dt_end','6200-12-01',
          'weapons', jsonb_build_array('EPEE'), 'evf_calendar_id', 903,
          'existing_id_event', (SELECT id_event FROM tbl_event WHERE id_evf_calendar_event=903),
          'is_cancelled', false, 'desired_code','PEW4e-6200-6201')
      ), v_season, 4);
  END;
  $body$
  $ing$,
  '62.2 — a mid-season insertion reflows the tail instead of colliding'
);

-- 62.3 — every event ends on its chronological code, identities intact
-- Scoped to calendar-identified rows: this test is about the reflow, and the
-- wrapper's pre-claim path also mints unidentified skeletons for a synthetic
-- payload. The pre-pass under test only ever RENAMES rows matched by calendar
-- id, so it cannot create those and they are out of scope here.
SELECT results_eq(
  $$SELECT id_evf_calendar_event::INT, txt_code::TEXT
      FROM tbl_event
     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code='SPWS-6200-6201')
       AND id_evf_calendar_event IS NOT NULL
     ORDER BY id_evf_calendar_event$$,
  $$VALUES (901,'PEW1e-6200-6201'), (902,'PEW3e-6200-6201'),
           (903,'PEW4e-6200-6201'), (904,'PEW2e-6200-6201')$$,
  '62.3 — codes follow chronology and each keeps its own calendar identity'
);

-- 62.4 — no staging placeholder survives the transaction
SELECT is(
  (SELECT count(*)::INT FROM tbl_event WHERE txt_code LIKE '\_\_evfcal\_evt\_%'),
  0,
  '62.4 — no event is left parked on a neutral staging code'
);

-- 62.5 — regression: parking a code must not reclassify a LATER cancellation
--        as a first-import one. Gamma is cancelled in the same batch that
--        shifts it, so it must keep a positive base (PEW4e) and not fall to
--        PEW0 -- the exact mismatch that aborted run 33190231601.
SELECT lives_ok(
  $ing2$
  DO $body2$
  DECLARE
    v_season INT;
  BEGIN
    SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-6200-6201';
    PERFORM fn_ingest_evf_calendar(
      jsonb_build_array(
        jsonb_build_object('name','Alpha','dt_start','6200-10-01','dt_end','6200-10-01',
          'weapons', jsonb_build_array('EPEE'), 'evf_calendar_id', 901,
          'existing_id_event', (SELECT id_event FROM tbl_event WHERE id_evf_calendar_event=901),
          'is_cancelled', false, 'desired_code','PEW1e-6200-6201'),
        jsonb_build_object('name','Inserted','dt_start','6200-10-15','dt_end','6200-10-15',
          'weapons', jsonb_build_array('EPEE'), 'evf_calendar_id', 904,
          'is_cancelled', false, 'desired_code','PEW2e-6200-6201'),
        jsonb_build_object('name','Beta','dt_start','6200-11-01','dt_end','6200-11-01',
          'weapons', jsonb_build_array('EPEE'), 'evf_calendar_id', 902,
          'existing_id_event', (SELECT id_event FROM tbl_event WHERE id_evf_calendar_event=902),
          'is_cancelled', false, 'desired_code','PEW3e-6200-6201'),
        jsonb_build_object('name','Gamma - Cancelled','dt_start','6200-12-01','dt_end','6200-12-01',
          'weapons', jsonb_build_array('EPEE'), 'evf_calendar_id', 903,
          'existing_id_event', (SELECT id_event FROM tbl_event WHERE id_evf_calendar_event=903),
          'is_cancelled', true, 'desired_code','PEW4e-6200-6201')
      ), v_season, 4);
  END;
  $body2$
  $ing2$,
  '62.5 — a later cancellation shifts with the sequence instead of falling to PEW0'
);

SELECT * FROM finish();
ROLLBACK;
