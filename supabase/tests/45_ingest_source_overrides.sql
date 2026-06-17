-- =============================================================================
-- N13.4 — overlap-clobber fix: ingest-source display data + admin overrides on
-- tbl_event (overlapping-FTL-listing dedup, UI-resolvable in the event accordion).
--
-- Tests 45.1–45.6: the two JSONB columns exist on tbl_event, are exposed on
-- vw_calendar (admin form round-trip), and fn_set_event_source_override writes
-- the admin's skip/process choice. These JSONBs are display/decision only — they
-- never enter tbl_result or any ranking view.
-- =============================================================================

BEGIN;
SELECT plan(6);

SELECT has_column('tbl_event', 'json_ingest_sources',
                  '45.1 tbl_event.json_ingest_sources exists');
SELECT has_column('tbl_event', 'json_source_overrides',
                  '45.2 tbl_event.json_source_overrides exists');
SELECT has_function('fn_set_event_source_override',
                    '45.3 fn_set_event_source_override RPC exists');
SELECT has_column('vw_calendar', 'json_ingest_sources',
                  '45.4 vw_calendar exposes json_ingest_sources');
SELECT has_column('vw_calendar', 'json_source_overrides',
                  '45.5 vw_calendar exposes json_source_overrides');

DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
  v_e      INT;
BEGIN
  v_season := fn_create_season('SRC45', '2099-09-01', '2100-06-30');  -- free range
  INSERT INTO tbl_organizer (txt_code, txt_name)
    VALUES ('SRCORG45', 'Src org 45') RETURNING id_organizer INTO v_org;
  v_e := fn_create_event('SRC45EVT', 'Src 45', v_season, v_org);
  PERFORM fn_set_event_source_override(v_e, '{"skip":["u1"],"process":["u2"]}'::jsonb);
END $setup$;

SELECT is(
  (SELECT json_source_overrides FROM tbl_event WHERE txt_code = 'SRC45EVT'),
  '{"skip":["u1"],"process":["u2"]}'::jsonb,
  '45.6 fn_set_event_source_override writes json_source_overrides'
);

SELECT * FROM finish();
ROLLBACK;
