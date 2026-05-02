-- =============================================================================
-- Phase 4 (ADR-053) — EVF parity gate + EVF_PUBLISHED promotion lifecycle
--
-- Replaces enum_source_status from {LIVE_SOURCE, FROZEN_SNAPSHOT, NO_SOURCE}
-- (Phase 0) with {ENGINE_COMPUTED, EVF_PUBLISHED}. Adds tbl_event.txt_parity_notes.
-- Adds DB-level enforcement (trigger) of the status × organizer invariant:
-- only EVF events may carry EVF_PUBLISHED; SPWS and FIE events are pinned to
-- ENGINE_COMPUTED.
--
-- Tests:
--   29.1   enum_source_status has 'ENGINE_COMPUTED' value
--   29.2   enum_source_status has 'EVF_PUBLISHED' value
--   29.3   enum_source_status no longer has 'LIVE_SOURCE'
--   29.4   enum_source_status no longer has 'FROZEN_SNAPSHOT'
--   29.5   enum_source_status no longer has 'NO_SOURCE'
--   29.6   tbl_event.txt_parity_notes column exists (TEXT, nullable)
--   29.7   all existing tbl_event rows have txt_source_status = 'ENGINE_COMPUTED'
--   29.8   trigger rejects EVF_PUBLISHED on SPWS-organized event
--   29.9   trigger rejects EVF_PUBLISHED on FIE-organized event
--   29.10  trigger allows EVF_PUBLISHED on EVF-organized event
--   29.11  trigger allows ENGINE_COMPUTED on any organizer (SPWS / FIE / EVF)
--   29.12  trigger fires on UPDATE not just INSERT (flip SPWS event from
--          ENGINE_COMPUTED → EVF_PUBLISHED is rejected)
-- =============================================================================

BEGIN;
SELECT plan(12);


-- ===== 29.1 — ENGINE_COMPUTED enum value =====
SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_enum
    WHERE enumtypid = 'enum_source_status'::regtype
      AND enumlabel = 'ENGINE_COMPUTED'
  ),
  '29.1: enum_source_status has ENGINE_COMPUTED value'
);


-- ===== 29.2 — EVF_PUBLISHED enum value =====
SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_enum
    WHERE enumtypid = 'enum_source_status'::regtype
      AND enumlabel = 'EVF_PUBLISHED'
  ),
  '29.2: enum_source_status has EVF_PUBLISHED value'
);


-- ===== 29.3 — LIVE_SOURCE removed =====
SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM pg_enum
    WHERE enumtypid = 'enum_source_status'::regtype
      AND enumlabel = 'LIVE_SOURCE'
  ),
  '29.3: enum_source_status no longer has LIVE_SOURCE'
);


-- ===== 29.4 — FROZEN_SNAPSHOT removed =====
SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM pg_enum
    WHERE enumtypid = 'enum_source_status'::regtype
      AND enumlabel = 'FROZEN_SNAPSHOT'
  ),
  '29.4: enum_source_status no longer has FROZEN_SNAPSHOT'
);


-- ===== 29.5 — NO_SOURCE removed =====
SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM pg_enum
    WHERE enumtypid = 'enum_source_status'::regtype
      AND enumlabel = 'NO_SOURCE'
  ),
  '29.5: enum_source_status no longer has NO_SOURCE'
);


-- ===== 29.6 — txt_parity_notes column exists =====
SELECT has_column(
  'tbl_event'::name,
  'txt_parity_notes'::name,
  '29.6: tbl_event.txt_parity_notes column exists'
);


-- ===== 29.7 — all existing rows defaulted to ENGINE_COMPUTED =====
SELECT is(
  (SELECT count(*) FROM tbl_event WHERE txt_source_status::TEXT != 'ENGINE_COMPUTED')::INT,
  0,
  '29.7: all existing tbl_event rows have txt_source_status = ENGINE_COMPUTED'
);


-- =============================================================================
-- Fixture: organizers + events for trigger tests
-- =============================================================================
DO $fix$
DECLARE
  v_evf_org   INT;
  v_spws_org  INT;
  v_fie_org   INT;
  v_season    INT;
BEGIN
  -- Ensure organizers exist
  INSERT INTO tbl_organizer (txt_code, txt_name)
  VALUES ('EVF', 'European Veterans Fencing')
  ON CONFLICT DO NOTHING;
  INSERT INTO tbl_organizer (txt_code, txt_name)
  VALUES ('SPWS', 'Polish Veterans Fencing Association')
  ON CONFLICT DO NOTHING;
  INSERT INTO tbl_organizer (txt_code, txt_name)
  VALUES ('FIE', 'Fédération Internationale d''Escrime')
  ON CONFLICT DO NOTHING;

  SELECT id_organizer INTO v_evf_org  FROM tbl_organizer WHERE txt_code = 'EVF';
  SELECT id_organizer INTO v_spws_org FROM tbl_organizer WHERE txt_code = 'SPWS';
  SELECT id_organizer INTO v_fie_org  FROM tbl_organizer WHERE txt_code = 'FIE';

  -- Ensure a season exists
  SELECT id_season INTO v_season FROM tbl_season ORDER BY id_season LIMIT 1;
  IF v_season IS NULL THEN
    INSERT INTO tbl_season (txt_code, dt_start, dt_end)
    VALUES ('TEST29', '2026-01-01', '2026-12-31')
    RETURNING id_season INTO v_season;
  END IF;

  -- Insert 3 test events with sentinel txt_codes (one per organizer)
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start)
  VALUES ('TEST29-EVF',  'Test EVF event',  v_season, v_evf_org,  '2026-06-01')
  ON CONFLICT DO NOTHING;
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start)
  VALUES ('TEST29-SPWS', 'Test SPWS event', v_season, v_spws_org, '2026-06-02')
  ON CONFLICT DO NOTHING;
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start)
  VALUES ('TEST29-FIE',  'Test FIE event',  v_season, v_fie_org,  '2026-06-03')
  ON CONFLICT DO NOTHING;
END;
$fix$;


-- ===== 29.8 — trigger rejects EVF_PUBLISHED on SPWS event =====
SELECT throws_ok(
  $$ UPDATE tbl_event SET txt_source_status = 'EVF_PUBLISHED' WHERE txt_code = 'TEST29-SPWS' $$,
  NULL,
  NULL,
  '29.8: trigger rejects EVF_PUBLISHED on SPWS-organized event'
);


-- ===== 29.9 — trigger rejects EVF_PUBLISHED on FIE event =====
SELECT throws_ok(
  $$ UPDATE tbl_event SET txt_source_status = 'EVF_PUBLISHED' WHERE txt_code = 'TEST29-FIE' $$,
  NULL,
  NULL,
  '29.9: trigger rejects EVF_PUBLISHED on FIE-organized event'
);


-- ===== 29.10 — trigger allows EVF_PUBLISHED on EVF event =====
SELECT lives_ok(
  $$ UPDATE tbl_event SET txt_source_status = 'EVF_PUBLISHED' WHERE txt_code = 'TEST29-EVF' $$,
  '29.10: trigger allows EVF_PUBLISHED on EVF-organized event'
);


-- ===== 29.11 — trigger allows ENGINE_COMPUTED on any organizer =====
SELECT lives_ok(
  $$
    UPDATE tbl_event SET txt_source_status = 'ENGINE_COMPUTED'
    WHERE txt_code IN ('TEST29-EVF','TEST29-SPWS','TEST29-FIE')
  $$,
  '29.11: trigger allows ENGINE_COMPUTED on SPWS / FIE / EVF organizers'
);


-- ===== 29.12 — trigger fires on UPDATE (regression of 29.8 via direct UPDATE) =====
-- Re-pin SPWS event back to ENGINE_COMPUTED, then attempt to flip → must fail
DO $$ BEGIN
  UPDATE tbl_event SET txt_source_status = 'ENGINE_COMPUTED' WHERE txt_code = 'TEST29-SPWS';
END $$;

SELECT throws_ok(
  $$ UPDATE tbl_event SET txt_source_status = 'EVF_PUBLISHED' WHERE txt_code = 'TEST29-SPWS' $$,
  NULL,
  NULL,
  '29.12: trigger fires on UPDATE (re-flip from ENGINE_COMPUTED → EVF_PUBLISHED on SPWS still rejected)'
);


SELECT * FROM finish();
ROLLBACK;
