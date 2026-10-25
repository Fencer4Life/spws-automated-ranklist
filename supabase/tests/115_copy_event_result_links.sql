-- =============================================================================
-- CALURL.22 — the refresh carries PROD's results links to CERT (D2 A)
-- =============================================================================
-- An administrator sets an event's results links (Admin: "URL wyników") in
-- PROD's Admin. The refresh `ingest` runs first reads them from PROD and hands
-- them to fn_copy_event_result_links on CERT, so the ingest reads the same
-- link. When PROD holds a link, CERT's five slots become PROD's, compacted;
-- when PROD holds none, CERT keeps its own. service_role only (ADR-083).
-- doc/plans/pzsz-results-url-rca-2026-10-25.html, ADR-117. Rolls back.
-- =============================================================================

BEGIN;

SELECT plan(7);

DO $setup$
DECLARE
  v_season INT;
  v_pzsz   INT;
BEGIN
  INSERT INTO tbl_season (txt_code, dt_start, dt_end)
  VALUES ('SPWS-9600-9601', '9600-08-01', '9601-07-31')
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-9600-9601';
  SELECT id_organizer INTO v_pzsz FROM tbl_organizer WHERE txt_code = 'PZSz';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status,
                         dt_start, dt_end, url_event, url_event_2)
  VALUES
    ('PPS1f-9600-9601', 'CALURL.22 empty on CERT', v_season, v_pzsz, 'PLANNED',
     '9601-01-10', '9601-01-11', NULL, NULL),
    ('PPS1e-9600-9601', 'CALURL.22 CERT has its own link', v_season, v_pzsz, 'PLANNED',
     '9601-02-10', '9601-02-11',
     'https://www.fencingtimelive.com/tournaments/eventSchedule/CERTONLY', NULL);
END
$setup$;

-- 22a — PROD's links replace CERT's empty slots, compacted
SELECT is(
  (SELECT fn_copy_event_result_links('PPS1f-9600-9601', jsonb_build_object(
     'url_event', NULL,
     'url_event_2', 'https://www.fencingtimelive.com/tournaments/eventSchedule/PROD1',
     'url_event_3', NULL, 'url_event_4', NULL, 'url_event_5', NULL)) ->> 'changed'),
  'true',
  'CALURL.22a the copy reports a change');

SELECT is(
  (SELECT ARRAY[url_event, url_event_2] FROM tbl_event WHERE txt_code = 'PPS1f-9600-9601'),
  ARRAY['https://www.fencingtimelive.com/tournaments/eventSchedule/PROD1', NULL]::TEXT[],
  'CALURL.22a PROD''s link lands in slot 1, compacted');

-- 22b — the same links again change nothing
SELECT is(
  (SELECT fn_copy_event_result_links('PPS1f-9600-9601', jsonb_build_object(
     'url_event', 'https://www.fencingtimelive.com/tournaments/eventSchedule/PROD1')) ->> 'changed'),
  'false',
  'CALURL.22b equal links change nothing');

-- 22c — PROD holds no link: CERT keeps its own
SELECT is(
  (SELECT fn_copy_event_result_links('PPS1e-9600-9601', jsonb_build_object(
     'url_event', NULL, 'url_event_2', '')) ->> 'changed'),
  'false',
  'CALURL.22c no PROD link: nothing is written');

SELECT is(
  (SELECT url_event FROM tbl_event WHERE txt_code = 'PPS1e-9600-9601'),
  'https://www.fencingtimelive.com/tournaments/eventSchedule/CERTONLY',
  'CALURL.22c CERT keeps its own link');

-- 22d — an unknown code is refused
SELECT throws_ok(
  $$SELECT fn_copy_event_result_links('NOPE-9600-9601', '{"url_event": "https://x/y"}'::jsonb)$$,
  'P0001',
  NULL,
  'CALURL.22d an unknown event code is refused');

-- 22e — service_role only
SELECT ok(
  has_function_privilege('service_role', 'fn_copy_event_result_links(text, jsonb)', 'EXECUTE')
  AND NOT has_function_privilege('anon', 'fn_copy_event_result_links(text, jsonb)', 'EXECUTE')
  AND NOT has_function_privilege('authenticated', 'fn_copy_event_result_links(text, jsonb)', 'EXECUTE'),
  'CALURL.22e only service_role runs the copy');

SELECT * FROM finish();
ROLLBACK;
