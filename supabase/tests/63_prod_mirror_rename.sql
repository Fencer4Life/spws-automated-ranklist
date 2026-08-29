-- =============================================================================
-- pgTAP — CERT→PROD carries a renamed event as a rename, not a second row
-- =============================================================================
-- Verifies migration 20260828000008_prod_mirror_rename.sql (ADR-086/ADR-081).
--
-- A mid-season EVF insertion renumbers every later event, so the same events
-- reach PROD under new codes. Keyed on txt_code alone that read as create+delete
-- and the create collided with the row PROD still held:
--   duplicate key value violates unique constraint "idx_tbl_event_evf_slug"
-- (live run 33191199882). The reconciler now matches on the durable calendar
-- identity and emits an UPDATE; this pins the SQL half.
-- =============================================================================

BEGIN;

SELECT plan(5);

SELECT has_function(
  'fn_mirror_events_to_prod',
  '63.1 — fn_mirror_events_to_prod() exists'
);

DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
BEGIN
  INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
  VALUES ('SPWS-6300-6301', '6300-08-01', '6301-07-31', FALSE)
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-6300-6301';
  INSERT INTO tbl_organizer (txt_code, txt_name)
  VALUES ('EVF', 'European Veterans Fencing') ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'EVF';

  -- Two adjacent events, each about to shift up one: applied naively the first
  -- rename lands on the code the second has not vacated.
  INSERT INTO tbl_event (
    txt_code, txt_name, id_season, id_organizer, enum_status,
    dt_start, dt_end, id_evf_calendar_event, txt_evf_slug
  ) VALUES
    ('PEW7efs-6300-6301', 'Levi Open', v_season, v_org, 'PLANNED',
     '6301-01-30', '6301-01-30', 4855, 'levi-open-fin'),
    ('PEW8fs-6300-6301', 'Faches', v_season, v_org, 'PLANNED',
     '6301-02-06', '6301-02-06', 882, 'evf-circuit-faches');
END;
$setup$;

-- 63.2 — both renames apply in one call without colliding
SELECT lives_ok(
  $mir$
  DO $body$
  DECLARE
    v_levi INT;
    v_fach INT;
  BEGIN
    SELECT id_event INTO v_levi FROM tbl_event WHERE id_evf_calendar_event = 4855;
    SELECT id_event INTO v_fach FROM tbl_event WHERE id_evf_calendar_event = 882;
    PERFORM fn_mirror_events_to_prod(
      '[]'::JSONB,
      jsonb_build_array(
        jsonb_build_object('id_event', v_levi, 'txt_code', 'PEW8efs-6300-6301'),
        jsonb_build_object('id_event', v_fach, 'txt_code', 'PEW9fs-6300-6301')
      ),
      '[]'::JSONB);
  END;
  $body$
  $mir$,
  '63.2 — cascading renames apply without a code collision'
);

-- 63.3 — the rows moved; no duplicate was created
SELECT results_eq(
  $$SELECT id_evf_calendar_event::INT, txt_code::TEXT
      FROM tbl_event
     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code='SPWS-6300-6301')
     ORDER BY id_evf_calendar_event$$,
  $$VALUES (882,'PEW9fs-6300-6301'), (4855,'PEW8efs-6300-6301')$$,
  '63.3 — each event is renamed in place, keeping its calendar identity'
);

-- 63.4 — no row is left parked on a staging code
SELECT is(
  (SELECT count(*)::INT FROM tbl_event WHERE txt_code LIKE '\_\_mirror\_evt\_%'),
  0,
  '63.4 — no event is left parked on a staging code'
);

-- 63.5 — a prior-event link that SWAPS between two events must not collide.
-- idx_event_prior_unique is UNIQUE (id_season, id_prior_event), so when CERT
-- moves a predecessor from one event to another the row-by-row loop hits the
-- index unless the old holder releases first. Live failure 2026-08-29:
--   Key (id_season, id_prior_event)=(4, 66) already exists
SELECT lives_ok(
  $swap$
  DO $body$
  DECLARE
    v_season INT;
    v_org    INT;
    v_prior  INT;
    v_a      INT;
    v_b      INT;
  BEGIN
    SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-6300-6301';
    SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'EVF';

    INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start)
    VALUES ('PEW90-6300-6301', 'Predecessor', v_season, v_org, 'COMPLETED', '6300-09-01')
    RETURNING id_event INTO v_prior;

    INSERT INTO tbl_event (
      txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, id_prior_event
    ) VALUES
      ('PEW91-6300-6301', 'Holds the link', v_season, v_org, 'PLANNED', '6301-04-01', v_prior)
    RETURNING id_event INTO v_a;

    INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start)
    VALUES ('PEW92-6300-6301', 'Wants the link', v_season, v_org, 'PLANNED', '6301-04-02')
    RETURNING id_event INTO v_b;

    -- CERT moves the predecessor from A to B in one payload.
    PERFORM fn_mirror_events_to_prod(
      '[]'::JSONB,
      jsonb_build_array(
        jsonb_build_object('id_event', v_b, 'id_prior_event', v_prior),
        jsonb_build_object('id_event', v_a, 'id_prior_event', NULL)
      ),
      '[]'::JSONB);
  END;
  $body$
  $swap$,
  '63.5 — a prior-event link swapping between two events does not collide'
);

SELECT * FROM finish();
ROLLBACK;
