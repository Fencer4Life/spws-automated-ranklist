-- =============================================================================
-- pgTAP — CERT→PROD carries the planning lifecycle and nothing else
-- =============================================================================
-- Verifies 20260828000010_prod_mirror_planning_status.sql (ADR-086 amendment).
--
-- CERT owns PLANNING, PROD owns RESULTS. Once an event is PLANNED on PROD the
-- only status change automation may make is a cancellation.
--
-- 65.2-65.4 pin the three automated transitions. 65.5 and 65.6 pin the two that
-- must never happen: automation may not hide a live event by walking it back to
-- CREATED, and may not regress a results-bearing row. Both refusals matter more
-- than the applications -- PPW1-2026-2027 had 14 registrations behind it.
-- =============================================================================

BEGIN;

SELECT plan(6);

SELECT has_function(
  'fn_mirror_events_to_prod',
  '65.1 — fn_mirror_events_to_prod() exists'
);

DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
BEGIN
  INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
  VALUES ('SPWS-6500-6501', '6500-08-01', '6501-07-31', FALSE)
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-6500-6501';
  INSERT INTO tbl_organizer (txt_code, txt_name)
  VALUES ('SPWS', 'SPWS') ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start)
  VALUES
    ('PPW1-6500-6501',  'Skeleton to publish', v_season, v_org, 'CREATED',   '6501-03-01'),
    ('PPW2-6500-6501',  'Skeleton cancelled',  v_season, v_org, 'CREATED',   '6501-03-02'),
    ('PPW3-6500-6501',  'Planned cancelled',   v_season, v_org, 'PLANNED',   '6501-03-03'),
    ('PPW4-6500-6501',  'Live, must not hide', v_season, v_org, 'PLANNED',   '6501-03-04'),
    ('PPW5-6500-6501',  'Already completed',   v_season, v_org, 'COMPLETED', '6500-09-01');
END;
$setup$;

DO $apply$
DECLARE
  v JSONB := '[]'::JSONB;
BEGIN
  SELECT jsonb_agg(jsonb_build_object('id_event', e.id_event, 'enum_status', x.want))
    INTO v
    FROM (VALUES
      ('PPW1-6500-6501','PLANNED'),    -- CREATED -> PLANNED   : applied
      ('PPW2-6500-6501','CANCELLED'),  -- CREATED -> CANCELLED : applied
      ('PPW3-6500-6501','CANCELLED'),  -- PLANNED -> CANCELLED : applied
      ('PPW4-6500-6501','CREATED'),    -- PLANNED -> CREATED   : REFUSED
      ('PPW5-6500-6501','PLANNED')     -- COMPLETED -> PLANNED : REFUSED
    ) AS x(code, want)
    JOIN tbl_event e ON e.txt_code = x.code;
  PERFORM fn_mirror_events_to_prod('[]'::JSONB, v, '[]'::JSONB);
END;
$apply$;

SELECT is((SELECT enum_status::TEXT FROM tbl_event WHERE txt_code='PPW1-6500-6501'),
  'PLANNED',   '65.2 — CREATED → PLANNED is applied: the skeleton becomes visible');

SELECT is((SELECT enum_status::TEXT FROM tbl_event WHERE txt_code='PPW2-6500-6501'),
  'CANCELLED', '65.3 — CREATED → CANCELLED is applied');

SELECT is((SELECT enum_status::TEXT FROM tbl_event WHERE txt_code='PPW3-6500-6501'),
  'CANCELLED', '65.4 — PLANNED → CANCELLED is applied: the only automated change once PLANNED');

SELECT is((SELECT enum_status::TEXT FROM tbl_event WHERE txt_code='PPW4-6500-6501'),
  'PLANNED',   '65.5 — PLANNED → CREATED is REFUSED: automation cannot hide a live event');

SELECT is((SELECT enum_status::TEXT FROM tbl_event WHERE txt_code='PPW5-6500-6501'),
  'COMPLETED', '65.6 — COMPLETED is REFUSED: CERT cannot regress the results lifecycle');

SELECT * FROM finish();
ROLLBACK;
