-- =============================================================================
-- pgTAP — dt_start_first_published anchors the moved-date pill
-- =============================================================================
-- Verifies 20260828000012_event_first_published_date.sql.
--
-- CHANGED was designed to flag "EVF moved this event" and never implemented.
-- The replacement is a pill anchored to the FIRST date EVF published, so an
-- event moved twice still reads against the date originally announced. The
-- anchor is set on insert and never updated, which makes "moved" a field
-- comparison rather than an audit-history scan.
--
-- 67.4 is the one that protects the calendar from noise: the backfill anchored
-- every existing event to the date it already held, so nothing historical is
-- retroactively flagged as moved.
-- =============================================================================

BEGIN;

SELECT plan(5);

SELECT has_column(
  'tbl_event', 'dt_start_first_published',
  '67.1 — tbl_event.dt_start_first_published exists'
);

DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
BEGIN
  INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
  VALUES ('SPWS-6700-6701', '6700-08-01', '6701-07-31', FALSE)
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-6700-6701';
  INSERT INTO tbl_organizer (txt_code, txt_name)
  VALUES ('SPWS', 'SPWS') ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start)
  VALUES ('PPW1-6700-6701', 'Anchored on insert', v_season, v_org, 'PLANNED', '6701-03-01');
END;
$setup$;

-- 67.2 — the trigger anchors it from dt_start, whoever inserts
SELECT is(
  (SELECT dt_start_first_published::TEXT FROM tbl_event WHERE txt_code='PPW1-6700-6701'),
  '6701-03-01',
  '67.2 — the anchor is set on insert from dt_start'
);

-- 67.3 — moving the date does NOT move the anchor, so "moved from" stays true
DO $move$
BEGIN
  UPDATE tbl_event SET dt_start = '6701-04-15' WHERE txt_code = 'PPW1-6700-6701';
  UPDATE tbl_event SET dt_start = '6701-05-20' WHERE txt_code = 'PPW1-6700-6701';
END;
$move$;

SELECT results_eq(
  $$SELECT dt_start::TEXT, dt_start_first_published::TEXT,
           (dt_start IS DISTINCT FROM dt_start_first_published)
      FROM tbl_event WHERE txt_code='PPW1-6700-6701'$$,
  $$VALUES ('6701-05-20'::TEXT, '6701-03-01'::TEXT, true)$$,
  '67.3 — after two moves the anchor still holds the FIRST published date'
);

-- 67.4 — no real event would show the pill.
-- Asserting the PILL's predicate, not merely that the column differs: a handful
-- of historical rows legitimately hold an anchor unequal to dt_start, because
-- the seed itself repairs their dates (one-day corrections and DD/MM parse
-- fixes) and the anchor correctly keeps the FIRST value. All of them are
-- COMPLETED, so the pill never fires. What must be zero is the set the fencer
-- would actually see.
SELECT is(
  (SELECT count(*)::INT FROM tbl_event
    WHERE txt_code NOT LIKE '%-6700-6701'
      AND enum_status = 'PLANNED'
      AND dt_start > CURRENT_DATE
      AND dt_start_first_published IS NOT NULL
      AND dt_start IS DISTINCT FROM dt_start_first_published),
  0,
  '67.4 — no pre-existing event would show the moved-date pill'
);

-- 67.5 — an explicit value survives (the CERT→PROD mirror passes CERT''s anchor)
DO $mirror$
DECLARE
  v_season INT;
  v_org    INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-6700-6701';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';
  INSERT INTO tbl_event (
    txt_code, txt_name, id_season, id_organizer, enum_status,
    dt_start, dt_start_first_published
  ) VALUES (
    'PPW2-6700-6701', 'Promoted with anchor', v_season, v_org, 'PLANNED',
    '6701-06-01', '6701-02-02'
  );
END;
$mirror$;

SELECT is(
  (SELECT dt_start_first_published::TEXT FROM tbl_event WHERE txt_code='PPW2-6700-6701'),
  '6701-02-02',
  '67.5 — an explicitly supplied anchor is not overwritten by the trigger'
);

SELECT * FROM finish();
ROLLBACK;
