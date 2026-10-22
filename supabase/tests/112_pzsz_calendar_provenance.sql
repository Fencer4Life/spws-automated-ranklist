-- =============================================================================
-- pgTAP — PZSz calendar provenance and the one atomic write (ADR-116 §9, §14)
-- =============================================================================
-- Verifies migration 20261021000001_pzsz_calendar_provenance.sql: the three
-- provenance tables are service_role only; fn_pzsz_apply_event is a
-- compare-and-set that writes an empty field, keeps a concurrent hand edit,
-- records provenance only for a field it wrote, reports every source, drives
-- digest-on-change for checks, rejects a non-whitelisted field, and rolls an
-- event's whole write back together on a bad value.
-- =============================================================================

BEGIN;

SELECT plan(20);

DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
BEGIN
  INSERT INTO tbl_season (txt_code, dt_start, dt_end)
  VALUES ('SPWS-6500-6501', '6500-08-01', '6501-07-31')
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-6500-6501';
  INSERT INTO tbl_organizer (txt_code, txt_name)
  VALUES ('PZSz', 'Polski Związek Szermierczy') ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'PZSz';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status,
                         dt_start, dt_end, id_pzsz_event)
  VALUES ('PPS1s-6500-6501', 'I PP seniorów', v_season, v_org, 'PLANNED',
          '6500-10-03', '6500-10-03', 7001);
END;
$setup$;

-- 110.1 — the provenance tables are service_role only (ADR-083)
SELECT ok(
  (SELECT bool_and(relrowsecurity) FROM pg_class
    WHERE relname IN ('tbl_pzsz_field_state', 'tbl_pzsz_source_report', 'tbl_pzsz_check')),
  '112.1a — RLS is on for all three tables'
);
SELECT ok(
  NOT has_table_privilege('anon', 'tbl_pzsz_field_state', 'SELECT')
  AND NOT has_table_privilege('authenticated', 'tbl_pzsz_field_state', 'SELECT')
  AND NOT has_table_privilege('anon', 'tbl_pzsz_source_report', 'SELECT')
  AND NOT has_table_privilege('anon', 'tbl_pzsz_check', 'SELECT'),
  '112.1b — anon/authenticated cannot read the provenance tables'
);
SELECT ok(
  has_table_privilege('service_role', 'tbl_pzsz_field_state', 'INSERT')
  AND has_table_privilege('service_role', 'tbl_pzsz_field_state', 'UPDATE'),
  '112.1c — service_role writes the provenance tables'
);
SELECT ok(
  NOT has_function_privilege('anon', 'fn_pzsz_apply_event(int, jsonb)', 'EXECUTE')
  AND NOT has_function_privilege('authenticated', 'fn_pzsz_apply_event(int, jsonb)', 'EXECUTE'),
  '112.1d — anon/authenticated cannot apply an event'
);

-- 110.2 — writing an empty field (rule 2) applies and records provenance
SELECT is(
  (fn_pzsz_apply_event(
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPS1s-6500-6501'),
    jsonb_build_object('changes', jsonb_build_array(jsonb_build_object(
      'field', 'txt_venue_address', 'value', 'Hala AZS, ul. Testowa 1',
      'source', 'letter', 'evidence', 'ul. Testowa 1', 'letter_sha256', repeat('a', 64),
      'parser_version', 'v1')))
  ) -> 'applied') @> '"txt_venue_address"'::jsonb,
  TRUE,
  '112.2a — an empty field is written'
);
SELECT is(
  (SELECT txt_venue_address FROM tbl_event WHERE txt_code = 'PPS1s-6500-6501'),
  'Hala AZS, ul. Testowa 1',
  '112.2b — tbl_event holds the written value'
);
SELECT is(
  (SELECT txt_source FROM tbl_pzsz_field_state
    WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PPS1s-6500-6501')
      AND txt_field = 'txt_venue_address'),
  'letter',
  '112.2c — the run records what it wrote and from where'
);

-- 110.3 — compare-and-set keeps a concurrent hand edit (rule 3)
UPDATE tbl_event SET txt_venue_address = 'Changed by hand'
  WHERE txt_code = 'PPS1s-6500-6501';
SELECT is(
  (fn_pzsz_apply_event(
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPS1s-6500-6501'),
    jsonb_build_object('changes', jsonb_build_array(jsonb_build_object(
      'field', 'txt_venue_address', 'value', 'Hala AZS, ul. Nowa 9',
      'expected', 'Hala AZS, ul. Testowa 1', 'source', 'letter')))
  ) -> 'hand_changed') @> '"txt_venue_address"'::jsonb,
  TRUE,
  '112.3a — a value that is not what the run wrote is reported, not overwritten'
);
SELECT is(
  (SELECT txt_venue_address FROM tbl_event WHERE txt_code = 'PPS1s-6500-6501'),
  'Changed by hand',
  '112.3b — the hand edit stands'
);

-- 110.4 — compare-and-set applies when the expected value matches (rule 4)
SELECT is(
  (fn_pzsz_apply_event(
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPS1s-6500-6501'),
    jsonb_build_object('changes', jsonb_build_array(jsonb_build_object(
      'field', 'dt_end', 'value', '6500-10-04', 'expected', '6500-10-03', 'source', 'letter')))
  ) -> 'applied') @> '"dt_end"'::jsonb,
  TRUE,
  '112.4a — the letter moves the end date when the current value is the run''s own'
);
SELECT is(
  (SELECT dt_end FROM tbl_event WHERE txt_code = 'PPS1s-6500-6501'),
  '6500-10-04'::DATE,
  '112.4b — the end date is updated'
);

-- 110.5 — every source's last report is recorded (rule 6 input)
SELECT lives_ok(
  $rep$
  SELECT fn_pzsz_apply_event(
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPS1s-6500-6501'),
    jsonb_build_object('reports', jsonb_build_array(jsonb_build_object(
      'field', 'dt_end', 'source', 'listing', 'value', '6500-10-05')))
  )
  $rep$,
  '112.5a — a source report is accepted'
);
SELECT is(
  (SELECT txt_value FROM tbl_pzsz_source_report
    WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PPS1s-6500-6501')
      AND txt_field = 'dt_end' AND txt_source = 'listing'),
  '6500-10-05',
  '112.5b — the listing''s last reported value is kept'
);

-- 110.6 — checks drive digest-on-change
SELECT is(
  (fn_pzsz_apply_event(
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPS1s-6500-6501'),
    jsonb_build_object('checks', jsonb_build_array(jsonb_build_object(
      'scope', 'PPS1s-6500-6501', 'check', 'letter', 'state', 'no_text', 'detail', 'no text layer')))
  ) -> 'checks_changed') @> '"letter"'::jsonb,
  TRUE,
  '112.6a — a new check state is reported changed'
);
SELECT is(
  (fn_pzsz_apply_event(
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPS1s-6500-6501'),
    jsonb_build_object('checks', jsonb_build_array(jsonb_build_object(
      'scope', 'PPS1s-6500-6501', 'check', 'letter', 'state', 'no_text', 'detail', 'no text layer')))
  ) -> 'checks_changed'),
  '[]'::jsonb,
  '112.6b — the same state again is not reported changed'
);
SELECT is(
  (fn_pzsz_apply_event(
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPS1s-6500-6501'),
    jsonb_build_object('checks', jsonb_build_array(jsonb_build_object(
      'scope', 'PPS1s-6500-6501', 'check', 'letter', 'state', 'ok', 'detail', '')))
  ) -> 'checks_changed') @> '"letter"'::jsonb,
  TRUE,
  '112.6c — a changed check state is reported changed again'
);

-- 110.7 — a non-whitelisted field is rejected, not written
SELECT is(
  (fn_pzsz_apply_event(
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPS1s-6500-6501'),
    jsonb_build_object('changes', jsonb_build_array(jsonb_build_object(
      'field', 'enum_status', 'value', 'CANCELLED', 'expected', 'PLANNED', 'source', 'letter')))
  ) -> 'rejected') @> '"enum_status"'::jsonb,
  TRUE,
  '112.7a — a field outside the whitelist is rejected'
);
SELECT is(
  (SELECT enum_status::TEXT FROM tbl_event WHERE txt_code = 'PPS1s-6500-6501'),
  'PLANNED',
  '112.7b — the rejected field is untouched'
);

-- 110.8 — a bad value rolls the event's whole write back together
SELECT throws_ok(
  $bad$
  SELECT fn_pzsz_apply_event(
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPS1s-6500-6501'),
    jsonb_build_object('changes', jsonb_build_array(jsonb_build_object(
      'field', 'num_entry_fee', 'value', 'not-a-number', 'source', 'letter')))
  )
  $bad$,
  '22P02', NULL,
  '112.8a — a value that will not cast raises (the event rolls back alone)'
);
SELECT is(
  (SELECT num_entry_fee FROM tbl_event WHERE txt_code = 'PPS1s-6500-6501'),
  NULL::NUMERIC,
  '112.8b — nothing of the failed write remains'
);

SELECT * FROM finish();
ROLLBACK;
