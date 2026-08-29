-- =============================================================================
-- pgTAP — SCHEDULED and CHANGED are unreachable; cancellation is never blocked
-- =============================================================================
-- Verifies 20260828000011_retire_scheduled_changed.sql.
--
-- ADR-077 documented SCHEDULED and CHANGED as set by the EVF sync. Neither ever
-- was -- zero rows, no code path. They are retired behaviourally: no branch can
-- reach them, the enum labels stay.
--
-- 66.4 is the one that would have bitten in production: PLANNED -> CANCELLED is
-- now an automated CERT->PROD transition, and this morning's weapons guard
-- blocked an unsuffixed PEW event from leaving PLANNED at all -- which would
-- have aborted the whole promote over a single row.
-- =============================================================================

BEGIN;

SELECT plan(5);

DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
BEGIN
  INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
  VALUES ('SPWS-6600-6601', '6600-08-01', '6601-07-31', FALSE)
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-6600-6601';
  INSERT INTO tbl_organizer (txt_code, txt_name)
  VALUES ('SPWS', 'SPWS') ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start)
  VALUES
    ('PPW1-6600-6601',  'Planned',            v_season, v_org, 'PLANNED', '6601-03-01'),
    ('PPW2-6600-6601',  'Planned too',        v_season, v_org, 'PLANNED', '6601-03-02'),
    ('PEW90-6600-6601', 'Unweaponed EVF',     v_season, v_org, 'PLANNED', '6601-03-03'),
    ('PEW91-6600-6601', 'Unweaponed EVF too', v_season, v_org, 'PLANNED', '6601-03-04');
END;
$setup$;

-- 66.1 / 66.2 — nothing can reach the retired states any more
SELECT throws_ok(
  $$UPDATE tbl_event SET enum_status='SCHEDULED' WHERE txt_code='PPW1-6600-6601'$$,
  'P0001', NULL,
  '66.1 — PLANNED → SCHEDULED is refused: SCHEDULED is unreachable'
);

SELECT throws_ok(
  $$UPDATE tbl_event SET enum_status='CHANGED' WHERE txt_code='PPW1-6600-6601'$$,
  'P0001', NULL,
  '66.2 — PLANNED → CHANGED is refused: CHANGED is unreachable'
);

-- 66.3 — the ordinary planning transitions still work
SELECT lives_ok(
  $$UPDATE tbl_event SET enum_status='CANCELLED' WHERE txt_code='PPW2-6600-6601'$$,
  '66.3 — PLANNED → CANCELLED still works for a normal event'
);

-- 66.4 — an unweaponed EVF event may be CANCELLED (the automated transition)
SELECT lives_ok(
  $$UPDATE tbl_event SET enum_status='CANCELLED' WHERE txt_code='PEW90-6600-6601'$$,
  '66.4 — an unsuffixed PEW event can be cancelled without aborting the promote'
);

-- 66.5 — but still may not ADVANCE into a scoring state
SELECT throws_ok(
  $$UPDATE tbl_event SET enum_status='IN_PROGRESS' WHERE txt_code='PEW91-6600-6601'$$,
  'P0001', NULL,
  '66.5 — an unsuffixed PEW event still cannot advance into scoring'
);

SELECT * FROM finish();
ROLLBACK;
