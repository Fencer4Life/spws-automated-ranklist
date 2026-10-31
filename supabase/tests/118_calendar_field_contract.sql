-- =============================================================================
-- CALSYNC.20–31 — the contract every calendar scraper follows on CERT (ADR-118)
-- =============================================================================
-- fn_calendar_apply_fields(p_scraper, p_events) writes an event's details from
-- a scraper's source, field by field, keeping in tbl_calendar_field_state the
-- value the scraper last wrote:
--   1 an empty field takes the source's value (an event page in the letter
--     counts as empty, C1 / ADR-117 D7 A);
--   2 a source that changed replaces the scraper's own value;
--   3 a person's value is kept, and the source's different value is reported
--     once (S2 A);
--   4 a blank from the source clears nothing;
--   5 our own register.html link is never written and never replaced.
-- With no state yet, the audit decides: a value a person last set is the
-- person's; any other is the scraper's. Values compare as their type. Plan:
-- doc/plans/cert-event-details-reach-prod-every-scraper-2026-10-31.html.
-- Rolls back.
-- =============================================================================

BEGIN;

SELECT plan(20);

DO $setup$
DECLARE
  v_season INT;
  v_evf    INT;
BEGIN
  INSERT INTO tbl_season (txt_code, dt_start, dt_end)
  VALUES ('SPWS-9702-9703', '9702-08-01', '9703-07-31')
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-9702-9703';
  SELECT id_organizer INTO v_evf FROM tbl_organizer WHERE txt_code = 'EVF';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status,
                         dt_start, dt_end, txt_location, txt_venue_address, url_invitation,
                         url_registration, num_entry_fee, arr_weapons)
  VALUES
    ('PEW1e-9702-9703', 'Contract 1', v_season, v_evf, 'PLANNED', '9703-01-10', '9703-01-11',
     NULL, NULL, NULL, NULL, NULL, '{EPEE}'),
    ('PEW2e-9702-9703', 'Contract 2', v_season, v_evf, 'PLANNED', '9703-02-10', '9703-02-11',
     'Old city', NULL, 'https://example.org/2-old.pdf', NULL, NULL, '{EPEE}'),
    ('PEW3e-9702-9703', 'Contract 3', v_season, v_evf, 'PLANNED', '9703-03-10', '9703-03-11',
     NULL, 'Typed by a person', NULL, NULL, NULL, '{EPEE}'),
    ('PEW4e-9702-9703', 'Contract 4', v_season, v_evf, 'PLANNED', '9703-04-10', '9703-04-11',
     'Ateny', NULL, NULL, NULL, NULL, '{EPEE}'),
    ('PEW5e-9702-9703', 'Contract 5', v_season, v_evf, 'PLANNED', '9703-05-10', '9703-05-11',
     NULL, NULL, NULL,
     'https://fencer4life.github.io/spws-automated-ranklist/register.html?event=PEW5e-9702-9703',
     NULL, '{EPEE}'),
    ('PEW6e-9702-9703', 'Contract 6', v_season, v_evf, 'PLANNED', '9703-06-10', '9703-06-11',
     NULL, NULL, 'https://www.veteransfencing.eu/event/contract-6/', NULL, NULL, '{EPEE}'),
    ('PEW7e-9702-9703', 'Contract 7', v_season, v_evf, 'PLANNED', '9703-07-10', '9703-07-11',
     'Set by automation', 'Set by a person', 'https://example.org/7-insert.pdf', NULL, 50,
     '{EPEE,FOIL}');

  -- 2: the scraper wrote 'Old city' and the old letter (state matches).
  INSERT INTO tbl_calendar_field_state (id_event, txt_field, txt_scraper, txt_value)
  VALUES
    ((SELECT id_event FROM tbl_event WHERE txt_code = 'PEW2e-9702-9703'), 'txt_location', 'EVF', 'Old city'),
    ((SELECT id_event FROM tbl_event WHERE txt_code = 'PEW2e-9702-9703'), 'url_invitation', 'EVF',
     'https://example.org/2-old.pdf'),
  -- 3: the scraper last wrote another address; a person changed it since.
    ((SELECT id_event FROM tbl_event WHERE txt_code = 'PEW3e-9702-9703'), 'txt_venue_address', 'EVF',
     'Written by EVF');

  -- 7: no state yet. The audit says a person set the address, automation the city.
  INSERT INTO tbl_audit_log (txt_table_name, id_row, txt_action, jsonb_old_values,
                             jsonb_new_values, txt_admin_user, ts_created)
  VALUES
    ('tbl_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW7e-9702-9703'), 'UPDATE',
     '{"txt_venue_address": null}', '{"txt_venue_address": "Set by a person"}',
     '00000000-0000-0000-0000-00000000c707', NOW() - INTERVAL '5 days'),
    ('tbl_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW7e-9702-9703'), 'UPDATE',
     '{"txt_location": null}', '{"txt_location": "Set by automation"}',
     NULL, NOW() - INTERVAL '4 days');
END
$setup$;

CREATE TEMP TABLE run1 ON COMMIT DROP AS
SELECT fn_calendar_apply_fields('EVF', jsonb_build_array(
  jsonb_build_object('id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1e-9702-9703'),
    'fields', jsonb_build_object('txt_location', 'Madrid', 'url_invitation', 'https://example.org/1.pdf')),
  jsonb_build_object('id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW2e-9702-9703'),
    'fields', jsonb_build_object('txt_location', 'New city', 'url_invitation', 'https://example.org/2-new.pdf')),
  jsonb_build_object('id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW3e-9702-9703'),
    'fields', jsonb_build_object('txt_venue_address', 'From the EVF page')),
  jsonb_build_object('id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW4e-9702-9703'),
    'fields', jsonb_build_object('txt_location', '', 'txt_country', NULL)),
  jsonb_build_object('id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW5e-9702-9703'),
    'fields', jsonb_build_object('url_registration', 'https://organizer.example.org/5')),
  jsonb_build_object('id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1e-9702-9703'),
    'fields', jsonb_build_object('url_registration',
      'https://fencer4life.github.io/spws-automated-ranklist/register.html?event=PEW1e-9702-9703')),
  jsonb_build_object('id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW6e-9702-9703'),
    'fields', jsonb_build_object('url_invitation', 'https://example.org/6-letter.pdf')),
  jsonb_build_object('id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW7e-9702-9703'),
    'fields', jsonb_build_object(
      'txt_location', 'From the source', 'txt_venue_address', 'Source address',
      'url_invitation', 'https://example.org/7-insert.pdf',
      'num_entry_fee', '50.0', 'arr_weapons', jsonb_build_array('FOIL', 'EPEE')))
)) AS r;

-- rule 1
SELECT is(
  (SELECT ROW(txt_location, url_invitation)::TEXT FROM tbl_event WHERE txt_code = 'PEW1e-9702-9703'),
  ROW('Madrid', 'https://example.org/1.pdf')::TEXT,
  'CALSYNC.20 an empty field takes the source''s value');
SELECT is(
  (SELECT txt_value FROM tbl_calendar_field_state
    WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1e-9702-9703')
      AND txt_field = 'txt_location'),
  'Madrid',
  'CALSYNC.21 the value written is recorded as the scraper''s');
-- rule 2
SELECT is(
  (SELECT ROW(txt_location, url_invitation)::TEXT FROM tbl_event WHERE txt_code = 'PEW2e-9702-9703'),
  ROW('New city', 'https://example.org/2-new.pdf')::TEXT,
  'CALSYNC.22 a source that changed replaces the scraper''s own value');
-- rule 3
SELECT is(
  (SELECT txt_venue_address FROM tbl_event WHERE txt_code = 'PEW3e-9702-9703'),
  'Typed by a person',
  'CALSYNC.23 a person''s value is kept');
-- pgt-ignore-start typecheck: temp tables/views this file creates (the checker sees only the live schema)
SELECT is(
  (SELECT count(*)::INT FROM run1, jsonb_array_elements(r -> 'held') h
    WHERE h ->> 'txt_code' = 'PEW3e-9702-9703' AND h ->> 'field' = 'txt_venue_address'
      AND h ->> 'source' = 'From the EVF page'),
  1,
  'CALSYNC.24 the source''s different value is reported');
-- pgt-ignore-end typecheck
-- rule 4
SELECT is(
  (SELECT txt_location FROM tbl_event WHERE txt_code = 'PEW4e-9702-9703'),
  'Ateny',
  'CALSYNC.25 a blank from the source clears nothing');
-- rule 5
SELECT is(
  (SELECT url_registration FROM tbl_event WHERE txt_code = 'PEW5e-9702-9703'),
  'https://fencer4life.github.io/spws-automated-ranklist/register.html?event=PEW5e-9702-9703',
  'CALSYNC.26 our own registration link on CERT is never replaced');
SELECT is(
  (SELECT url_registration FROM tbl_event WHERE txt_code = 'PEW1e-9702-9703'),
  NULL,
  'CALSYNC.27 a source never writes our own registration link');
-- pgt-ignore-start typecheck: temp tables/views this file creates (the checker sees only the live schema)
SELECT is(
  (SELECT count(*)::INT FROM run1, jsonb_array_elements(r -> 'held') h
    WHERE h ->> 'txt_code' = 'PEW5e-9702-9703'),
  0,
  'CALSYNC.28 our own link is not reported as held');
-- pgt-ignore-end typecheck
-- C1
SELECT is(
  (SELECT url_invitation FROM tbl_event WHERE txt_code = 'PEW6e-9702-9703'),
  'https://example.org/6-letter.pdf',
  'CALSYNC.29 an event page in the letter counts as empty (C1, ADR-117 D7 A)');
-- no state: the audit decides
SELECT is(
  (SELECT txt_venue_address FROM tbl_event WHERE txt_code = 'PEW7e-9702-9703'),
  'Set by a person',
  'CALSYNC.30 no state: a value a person last set is the person''s');
SELECT is(
  (SELECT txt_location FROM tbl_event WHERE txt_code = 'PEW7e-9702-9703'),
  'From the source',
  'CALSYNC.31 no state: a value automation set is the scraper''s, and follows the source');
SELECT is(
  (SELECT txt_value FROM tbl_calendar_field_state
    WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW7e-9702-9703')
      AND txt_field = 'url_invitation'),
  'https://example.org/7-insert.pdf',
  'CALSYNC.32 no state and the same value: the state is seeded, nothing written');
-- typed comparison
-- pgt-ignore-start typecheck: temp tables/views this file creates (the checker sees only the live schema)
SELECT is(
  (SELECT count(*)::INT FROM run1, jsonb_array_elements(r -> 'written') w
    WHERE w ->> 'txt_code' = 'PEW7e-9702-9703'
      AND w ->> 'field' IN ('num_entry_fee', 'arr_weapons', 'url_invitation')),
  0,
  'CALSYNC.33 values compare as their type: 50.0 = 50, {FOIL,EPEE} = {EPEE,FOIL}');
-- pgt-ignore-end typecheck

-- A second run with the same source: nothing written, the held value is not
-- reported again; a third with a new source value reports it again.
CREATE TEMP TABLE run2 ON COMMIT DROP AS
SELECT fn_calendar_apply_fields('EVF', jsonb_build_array(
  jsonb_build_object('id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW3e-9702-9703'),
    'fields', jsonb_build_object('txt_venue_address', 'From the EVF page')),
  jsonb_build_object('id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW2e-9702-9703'),
    'fields', jsonb_build_object('txt_location', 'New city'))
)) AS r;
-- pgt-ignore-start typecheck: temp tables/views this file creates (the checker sees only the live schema)
SELECT is(
  (SELECT jsonb_array_length(r -> 'held') + jsonb_array_length(r -> 'written') FROM run2),
  0,
  'CALSYNC.34 a repeated run writes nothing and reports nothing again');
-- pgt-ignore-end typecheck
SELECT is(
  (SELECT jsonb_array_length(fn_calendar_apply_fields('EVF', jsonb_build_array(
     jsonb_build_object('id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW3e-9702-9703'),
       'fields', jsonb_build_object('txt_venue_address', 'Moved again')))) -> 'held')),
  1,
  'CALSYNC.35 a newer different source value is reported again');

SELECT throws_ok(
  $$SELECT fn_calendar_apply_fields('EVF', jsonb_build_array(jsonb_build_object(
      'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1e-9702-9703'),
      'fields', jsonb_build_object('bool_use_spws_registration', 'true'))))$$,
  'P0001',
  NULL,
  'CALSYNC.36 a field outside the nine is refused');

SELECT ok(
  NOT has_function_privilege('anon', 'fn_calendar_apply_fields(text, jsonb)', 'EXECUTE')
  AND NOT has_function_privilege('authenticated', 'fn_calendar_apply_fields(text, jsonb)', 'EXECUTE')
  AND has_function_privilege('service_role', 'fn_calendar_apply_fields(text, jsonb)', 'EXECUTE'),
  'CALSYNC.37 the write function is service_role only');

SELECT ok(
  NOT has_table_privilege('anon', 'tbl_calendar_field_state', 'SELECT')
  AND NOT has_table_privilege('authenticated', 'tbl_calendar_field_state', 'SELECT'),
  'CALSYNC.38 the state table is closed to anon and authenticated');

-- F1: the EVF calendar ingest reuses an existing slot without writing its
-- details; a city and country a person set survive EVF sending none.
DO $f1$
BEGIN
  UPDATE tbl_event SET id_evf_event = 970204, txt_country = 'Grecja'
   WHERE txt_code = 'PEW4e-9702-9703';
  PERFORM fn_ingest_evf_calendar(jsonb_build_array(jsonb_build_object(
    'name', 'Contract 4 renamed by EVF', 'dt_start', '9703-04-10', 'dt_end', '9703-04-11',
    'location', '', 'country', '', 'evf_id', 970204,
    'url_invitation', 'https://example.org/4-evf.pdf', 'address', 'EVF address')),
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-9702-9703'));
END
$f1$;
SELECT is(
  (SELECT ROW(txt_name, txt_location, txt_country, txt_venue_address, url_invitation)::TEXT
     FROM tbl_event WHERE txt_code = 'PEW4e-9702-9703'),
  ROW('Contract 4', 'Ateny', 'Grecja', NULL::TEXT, NULL::TEXT)::TEXT,
  'CALSYNC.39 the EVF calendar ingest no longer writes an existing event''s details (F1)');

SELECT * FROM finish();
ROLLBACK;
