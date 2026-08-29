-- =============================================================================
-- pgTAP — CERT→PROD promotes every event-level field on UPDATE
-- =============================================================================
-- Verifies migration 20260828000009_prod_mirror_full_event_fields.sql.
--
-- Sixteen tbl_event columns never reached PROD on update: three were CREATEd
-- then frozen (txt_venue_address, id_prior_event, enum_status) and five were
-- carried by neither branch (fee tiers, entry list, organizer email,
-- registration switch). PPW1-2026-2027 held its venue address on CERT and NULL
-- on PROD in every daily reconcile log.
--
-- 64.5 pins that the PLANNING half of the lifecycle does reach PROD. The
-- results half still does not -- see 65_prod_mirror_planning_status.sql.
-- =============================================================================

BEGIN;

SELECT plan(5);

SELECT has_function(
  'fn_mirror_events_to_prod',
  '64.1 — fn_mirror_events_to_prod() exists'
);

DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
  v_prior  INT;
BEGIN
  INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
  VALUES ('SPWS-6400-6401', '6400-08-01', '6401-07-31', FALSE)
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-6400-6401';
  INSERT INTO tbl_organizer (txt_code, txt_name)
  VALUES ('SPWS', 'SPWS') ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start)
  VALUES ('PPW9-6400-6401', 'Prior season event', v_season, v_org, 'COMPLETED', '6400-09-01')
  RETURNING id_event INTO v_prior;

  -- An established PROD row: created earlier, since starved of updates.
  INSERT INTO tbl_event (
    txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, dt_end
  ) VALUES (
    'PPW1-6400-6401', 'Puchar', v_season, v_org, 'CREATED', '6400-10-10', '6400-10-11'
  );
END;
$setup$;

-- 64.2 — every previously-starved field is applied
SELECT lives_ok(
  $mir$
  DO $body$
  DECLARE
    v_id    INT;
    v_prior INT;
  BEGIN
    SELECT id_event INTO v_id    FROM tbl_event WHERE txt_code = 'PPW1-6400-6401';
    SELECT id_event INTO v_prior FROM tbl_event WHERE txt_code = 'PPW9-6400-6401';
    PERFORM fn_mirror_events_to_prod(
      '[]'::JSONB,
      jsonb_build_array(jsonb_build_object(
        'id_event', v_id,
        'txt_venue_address', 'ITAKA ARENA, ul. Olejnika1, Opole',
        'id_prior_event', v_prior,
        'num_entry_fee_2w', '90',
        'num_entry_fee_3w', '120',
        'url_entry_list', 'https://spws/entries/ppw1',
        'txt_organizer_email', 'organizer@spws.test',
        'bool_use_spws_registration', true,
        'enum_status', 'PLANNED'
      )),
      '[]'::JSONB);
  END;
  $body$
  $mir$,
  '64.2 — the mirror accepts a full event-level update payload'
);

-- 64.3 — the frozen columns now propagate
SELECT results_eq(
  $$SELECT txt_venue_address::TEXT,
           (id_prior_event = (SELECT id_event FROM tbl_event WHERE txt_code='PPW9-6400-6401'))
      FROM tbl_event WHERE txt_code = 'PPW1-6400-6401'$$,
  $$VALUES ('ITAKA ARENA, ul. Olejnika1, Opole', true)$$,
  '64.3 — txt_venue_address and id_prior_event reach an established PROD row'
);

-- 64.4 — the columns that never reached PROD at all now do
SELECT results_eq(
  $$SELECT num_entry_fee_2w::TEXT, num_entry_fee_3w::TEXT,
           url_entry_list::TEXT, txt_organizer_email::TEXT,
           bool_use_spws_registration
      FROM tbl_event WHERE txt_code = 'PPW1-6400-6401'$$,
  $$VALUES ('90'::TEXT, '120'::TEXT, 'https://spws/entries/ppw1'::TEXT,
            'organizer@spws.test'::TEXT, true)$$,
  '64.4 — fee tiers, entry list, organizer email and registration switch propagate'
);

-- 64.5 — the planning lifecycle DOES reach PROD (ADR-086 amendment).
-- This assertion previously expected 'CREATED', encoding the decision that
-- enum_status is wholly PROD-owned. That was wrong and it is what hid
-- PPW1-2026-2027 from the calendar while its registration was open. CERT owns
-- PLANNING, PROD owns RESULTS; 65_prod_mirror_planning_status.sql pins the whole
-- boundary, including the two transitions that must still be refused.
SELECT is(
  (SELECT enum_status::TEXT FROM tbl_event WHERE txt_code = 'PPW1-6400-6401'),
  'PLANNED',
  '64.5 — CREATED → PLANNED reaches PROD, so a dated event becomes visible'
);

SELECT * FROM finish();
ROLLBACK;
