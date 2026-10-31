-- =============================================================================
-- CALSYNC.01–19 — a write on CERT to an event's details reaches PROD (ADR-118)
-- =============================================================================
-- The nine details (name, dates, city, country, weapons, venue address,
-- invitation letter, the organizer's registration link, entry fee with its
-- currency) follow CERT when CERT wrote them later than PROD did: the payload
-- carries CERT's ts_details_set, and PROD's own time is the last change a
-- person made there to any of the nine; the mirror's own copies do not count
-- (F9, CALSYNC.17-19). A blank on CERT never clears
-- PROD (S1 A); our own register.html link is never copied and never replaced;
-- an event with nothing to change is not written (F2). A payload without
-- ts_details_set keeps the earlier rules. Plan:
-- doc/plans/cert-event-details-reach-prod-every-scraper-2026-10-31.html.
-- Rolls back.
-- =============================================================================

BEGIN;

SELECT plan(19);

DO $setup$
DECLARE
  v_season INT;
  v_evf    INT;
BEGIN
  INSERT INTO tbl_season (txt_code, dt_start, dt_end)
  VALUES ('SPWS-9700-9701', '9700-08-01', '9701-07-31')
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-9700-9701';
  SELECT id_organizer INTO v_evf FROM tbl_organizer WHERE txt_code = 'EVF';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status,
                         dt_start, dt_end, txt_location, txt_country, arr_weapons,
                         txt_venue_address, url_invitation, url_registration,
                         num_entry_fee, txt_entry_fee_currency,
                         bool_use_spws_registration, dt_registration_deadline, txt_iban,
                         url_event, ts_created, txt_payee)
  VALUES
    -- 01 Madrid's shape: PROD's letter last written 30 days ago, CERT's 10.
    ('PEW1e-9700-9701', 'Sync 01', v_season, v_evf, 'PLANNED', '9701-01-10', '9701-01-11',
     'Madrid', 'Hiszpania', '{EPEE}', NULL, 'https://example.org/old-letter.pdf', NULL,
     NULL, NULL, FALSE, NULL, NULL, NULL, NOW() - INTERVAL '60 days', NULL),
    -- 02 Skopje's shape: PROD's letter came with the row 20 days ago, never changed.
    ('PEW2e-9700-9701', 'Sync 02', v_season, v_evf, 'PLANNED', '9701-02-10', '9701-02-11',
     'Skopje', NULL, '{EPEE}', NULL, 'https://example.org/v2.pdf', NULL,
     NULL, NULL, FALSE, NULL, NULL, NULL, NOW() - INTERVAL '20 days', NULL),
    -- 03 a person edited PROD's address yesterday, after CERT's last write.
    ('PEW3e-9700-9701', 'Sync 03 PROD name', v_season, v_evf, 'PLANNED', '9701-03-10', '9701-03-11',
     'Lomianki', NULL, '{EPEE}', 'Typed on PROD', NULL, NULL,
     NULL, NULL, FALSE, NULL, NULL, NULL, NOW() - INTERVAL '60 days', NULL),
    -- 04 CERT newer: every one of the nine follows CERT.
    ('PEW4e-9700-9701', 'Sync 04 old', v_season, v_evf, 'PLANNED', '9701-04-10', '9701-04-11',
     'Old city', 'Stary kraj', '{EPEE}', 'Old address', 'https://example.org/04-old.pdf',
     'https://organizer.example.org/04-old', 40, 'PLN', FALSE, NULL, NULL, NULL,
     NOW() - INTERVAL '60 days', NULL),
    -- 05 CERT's country is blank.
    ('PEW5e-9700-9701', 'Sync 05', v_season, v_evf, 'PLANNED', '9701-05-10', '9701-05-11',
     'Ateny', 'Grecja', '{EPEE}', NULL, NULL, NULL,
     NULL, NULL, FALSE, NULL, NULL, NULL, NOW() - INTERVAL '60 days', NULL),
    -- 06 PROD holds our own registration link.
    ('PEW6e-9700-9701', 'Sync 06', v_season, v_evf, 'PLANNED', '9701-06-10', '9701-06-11',
     'Warszawa', NULL, '{EPEE}', NULL, NULL,
     'https://fencer4life.github.io/spws-automated-ranklist/register.html?event=PEW6e-9700-9701',
     NULL, NULL, TRUE, NULL, 'PL 27 1140 2004 0000 3002 0135 5387', NULL, NOW() - INTERVAL '60 days', 'Klub 06'),
    -- 07 CERT holds our own registration link; PROD has none.
    ('PEW7e-9700-9701', 'Sync 07', v_season, v_evf, 'PLANNED', '9701-07-10', '9701-07-11',
     'Warszawa', NULL, '{EPEE}', NULL, NULL, NULL,
     NULL, NULL, FALSE, NULL, NULL, NULL, NOW() - INTERVAL '60 days', NULL),
    -- 08 nothing to change: CERT sends the same nine (fee 50.0 = 50).
    ('PEW8e-9700-9701', 'Sync 08', v_season, v_evf, 'PLANNED', '9701-08-10', '9701-08-11',
     'Napoli', 'Wlochy', '{EPEE,FOIL}', 'Via Roma 1', 'https://example.org/08.pdf',
     'https://organizer.example.org/08', 50, 'EUR', FALSE, NULL, NULL, NULL,
     NOW() - INTERVAL '60 days', NULL),
    -- 09 an older payload with no ts_details_set: the earlier rules.
    ('PEW9e-9700-9701', 'Sync 09', v_season, v_evf, 'PLANNED', '9701-09-10', '9701-09-11',
     'Liege', NULL, '{EPEE}', 'Kept address', 'https://www.veteransfencing.eu/event/sync-09/', NULL,
     NULL, NULL, FALSE, NULL, NULL, NULL, NOW() - INTERVAL '60 days', NULL),
    -- 10 per-environment fields stay PROD's even when CERT is newer.
    ('PEW10e-9700-9701', 'Sync 10', v_season, v_evf, 'PLANNED', '9701-10-10', '9701-10-11',
     'Dublin', NULL, '{EPEE}', NULL, NULL, NULL,
     NULL, NULL, TRUE, '9701-10-01', 'PL 27 1140 2004 0000 3002 0135 5387', 'https://results.example.org/10',
     NOW() - INTERVAL '60 days', 'Klub 10'),
    -- 11 a later PROD change to a field outside the nine does not make PROD newer.
    ('PEW11e-9700-9701', 'Sync 11', v_season, v_evf, 'PLANNED', '9701-11-10', '9701-11-11',
     'Faches', NULL, '{EPEE}', NULL, 'https://example.org/11-old.pdf', NULL,
     NULL, NULL, FALSE, NULL, NULL, NULL, NOW() - INTERVAL '60 days', NULL),
    -- 17 Madrid on 31 Oct: a person set PROD's letter 40 days ago, CERT wrote 10
    -- days ago, and the mirror copied a CERT change to PROD yesterday.
    ('PEW17e-9700-9701', 'Sync 17', v_season, v_evf, 'PLANNED', '9701-01-17', '9701-01-18',
     'Madrid', NULL, '{EPEE}', NULL, 'https://example.org/17-august.pdf', NULL,
     NULL, NULL, FALSE, NULL, NULL, NULL, NOW() - INTERVAL '60 days', NULL),
    -- 18 a person edited PROD's letter 5 days ago, after CERT's write; the
    -- mirror wrote PROD yesterday.
    ('PEW18e-9700-9701', 'Sync 18', v_season, v_evf, 'PLANNED', '9701-01-24', '9701-01-25',
     'Madrid', NULL, '{EPEE}', NULL, 'https://example.org/18-person.pdf', NULL,
     NULL, NULL, FALSE, NULL, NULL, NULL, NOW() - INTERVAL '60 days', NULL),
    -- 19 created on PROD yesterday, never changed there by a person.
    ('PEW19e-9700-9701', 'Sync 19', v_season, v_evf, 'PLANNED', '9701-01-31', '9701-02-01',
     'Skopje', NULL, '{EPEE}', NULL, 'https://example.org/19-prod.pdf', NULL,
     NULL, NULL, FALSE, NULL, NULL, NULL, NOW() - INTERVAL '1 day', NULL);

  -- PROD's audit history (inserts are not audited; these rows set the times).
  INSERT INTO tbl_audit_log (txt_table_name, id_row, txt_action, jsonb_old_values,
                             jsonb_new_values, txt_admin_user, ts_created)
  VALUES
    ('tbl_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1e-9700-9701'), 'UPDATE',
     '{"url_invitation": null}', '{"url_invitation": "https://example.org/old-letter.pdf"}',
     NULL, NOW() - INTERVAL '30 days'),
    ('tbl_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW3e-9700-9701'), 'UPDATE',
     '{"txt_venue_address": "From EVF"}', '{"txt_venue_address": "Typed on PROD"}',
     '00000000-0000-0000-0000-00000000c503', NOW() - INTERVAL '1 day'),
    ('tbl_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW11e-9700-9701'), 'UPDATE',
     '{"bool_use_spws_registration": false}', '{"bool_use_spws_registration": true}',
     '00000000-0000-0000-0000-00000000c511', NOW() - INTERVAL '1 day'),
    ('tbl_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW17e-9700-9701'), 'UPDATE',
     '{"url_invitation": null}', '{"url_invitation": "https://example.org/17-august.pdf"}',
     '00000000-0000-0000-0000-00000000c517', NOW() - INTERVAL '40 days'),
    ('tbl_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW17e-9700-9701'), 'UPDATE',
     '{"txt_name": "Sync 17 old"}', '{"txt_name": "Sync 17"}',
     NULL, NOW() - INTERVAL '1 day'),
    ('tbl_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW18e-9700-9701'), 'UPDATE',
     '{"url_invitation": "https://example.org/18-cert.pdf"}', '{"url_invitation": "https://example.org/18-person.pdf"}',
     '00000000-0000-0000-0000-00000000c518', NOW() - INTERVAL '5 days'),
    ('tbl_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW18e-9700-9701'), 'UPDATE',
     '{"txt_name": "Sync 18 old"}', '{"txt_name": "Sync 18"}',
     NULL, NOW() - INTERVAL '1 day');
END
$setup$;

CREATE TEMP TABLE sync_result ON COMMIT DROP AS
SELECT fn_mirror_events_to_prod(
  '[]'::JSONB,
  jsonb_build_array(
    jsonb_build_object(
      'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1e-9700-9701'),
      'ts_details_set', (NOW() - INTERVAL '10 days')::TEXT,
      'url_invitation', 'https://example.org/v1.pdf'),
    jsonb_build_object(
      'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW2e-9700-9701'),
      'ts_details_set', (NOW() - INTERVAL '10 days')::TEXT,
      'url_invitation', 'https://example.org/v3.pdf'),
    jsonb_build_object(
      'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW3e-9700-9701'),
      'ts_details_set', (NOW() - INTERVAL '10 days')::TEXT,
      'txt_name', 'Sync 03 CERT name',
      'txt_venue_address', 'From EVF'),
    jsonb_build_object(
      'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW4e-9700-9701'),
      'ts_details_set', (NOW() - INTERVAL '10 days')::TEXT,
      'txt_name', 'Sync 04 new',
      'dt_start', '9701-04-17', 'dt_end', '9701-04-18',
      'txt_location', 'New city', 'txt_country', 'Nowy kraj',
      'arr_weapons', jsonb_build_array('FOIL', 'EPEE'),
      'txt_venue_address', 'New address',
      'url_invitation', 'https://example.org/04-new.pdf',
      'url_registration', 'https://organizer.example.org/04-new',
      'num_entry_fee', '60', 'txt_entry_fee_currency', 'EUR'),
    jsonb_build_object(
      'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW5e-9700-9701'),
      'ts_details_set', (NOW() - INTERVAL '10 days')::TEXT,
      'txt_country', ''),
    jsonb_build_object(
      'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW6e-9700-9701'),
      'ts_details_set', (NOW() - INTERVAL '10 days')::TEXT,
      'url_registration', 'https://organizer.example.org/06'),
    jsonb_build_object(
      'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW7e-9700-9701'),
      'ts_details_set', (NOW() - INTERVAL '10 days')::TEXT,
      'url_registration',
      'https://fencer4life.github.io/spws-automated-ranklist/register.html?event=PEW7e-9700-9701'),
    jsonb_build_object(
      'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW8e-9700-9701'),
      'ts_details_set', (NOW() - INTERVAL '10 days')::TEXT,
      'txt_name', 'Sync 08', 'dt_start', '9701-08-10', 'dt_end', '9701-08-11',
      'txt_location', 'Napoli', 'txt_country', 'Wlochy',
      'arr_weapons', jsonb_build_array('FOIL', 'EPEE'),
      'txt_venue_address', 'Via Roma 1', 'url_invitation', 'https://example.org/08.pdf',
      'url_registration', 'https://organizer.example.org/08',
      'num_entry_fee', '50.0', 'txt_entry_fee_currency', 'EUR'),
    jsonb_build_object(
      'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW9e-9700-9701'),
      'txt_venue_address', 'CERT address',
      'url_invitation', 'https://example.org/09-letter.pdf'),
    jsonb_build_object(
      'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW10e-9700-9701'),
      'ts_details_set', (NOW() - INTERVAL '10 days')::TEXT,
      'bool_use_spws_registration', FALSE,
      'dt_registration_deadline', '9701-09-01',
      'txt_iban', 'PL 06 1090 1665 0000 0001 5004 1548',
      'url_event', 'https://results.example.org/cert'),
    jsonb_build_object(
      'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW11e-9700-9701'),
      'ts_details_set', (NOW() - INTERVAL '10 days')::TEXT,
      'url_invitation', 'https://example.org/11-new.pdf'),
    jsonb_build_object(
      'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW17e-9700-9701'),
      'ts_details_set', (NOW() - INTERVAL '10 days')::TEXT,
      'url_invitation', 'https://example.org/17-october.pdf'),
    jsonb_build_object(
      'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW18e-9700-9701'),
      'ts_details_set', (NOW() - INTERVAL '10 days')::TEXT,
      'url_invitation', 'https://example.org/18-cert.pdf'),
    jsonb_build_object(
      'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW19e-9700-9701'),
      'ts_details_set', (NOW() - INTERVAL '10 days')::TEXT,
      'url_invitation', 'https://example.org/19-cert.pdf')),
  '[]'::JSONB) AS r;

SELECT is(
  (SELECT url_invitation FROM tbl_event WHERE txt_code = 'PEW1e-9700-9701'),
  'https://example.org/v1.pdf',
  'CALSYNC.01 CERT wrote its letter after PROD did: PROD takes it (Madrid)');

SELECT is(
  (SELECT url_invitation FROM tbl_event WHERE txt_code = 'PEW2e-9700-9701'),
  'https://example.org/v3.pdf',
  'CALSYNC.02 a PROD letter no person changed gives way to CERT''s later one (Skopje)');

SELECT is(
  (SELECT ROW(txt_name, txt_venue_address)::TEXT FROM tbl_event WHERE txt_code = 'PEW3e-9700-9701'),
  ROW('Sync 03 PROD name', 'Typed on PROD')::TEXT,
  'CALSYNC.03 PROD written later than CERT: PROD keeps its details');

SELECT is(
  (SELECT ROW(txt_name, dt_start, dt_end, txt_location, txt_country, arr_weapons,
              txt_venue_address, url_invitation, url_registration, num_entry_fee,
              txt_entry_fee_currency)::TEXT
     FROM tbl_event WHERE txt_code = 'PEW4e-9700-9701'),
  ROW('Sync 04 new', '9701-04-17'::DATE, '9701-04-18'::DATE, 'New city', 'Nowy kraj',
      '{EPEE,FOIL}'::enum_weapon_type[], 'New address', 'https://example.org/04-new.pdf',
      'https://organizer.example.org/04-new', 60::NUMERIC, 'EUR')::TEXT,
  'CALSYNC.04 CERT newer: all nine details follow CERT');

SELECT is(
  (SELECT txt_country FROM tbl_event WHERE txt_code = 'PEW5e-9700-9701'),
  'Grecja',
  'CALSYNC.05 a blank on CERT never clears PROD (S1 A)');

SELECT is(
  (SELECT url_registration FROM tbl_event WHERE txt_code = 'PEW6e-9700-9701'),
  'https://fencer4life.github.io/spws-automated-ranklist/register.html?event=PEW6e-9700-9701',
  'CALSYNC.06 PROD''s own registration link is never replaced');

SELECT is(
  (SELECT url_registration FROM tbl_event WHERE txt_code = 'PEW7e-9700-9701'),
  NULL,
  'CALSYNC.07 our own registration link on CERT is never copied');

SELECT is(
  (SELECT num_entry_fee::TEXT FROM tbl_event WHERE txt_code = 'PEW8e-9700-9701'),
  '50',
  'CALSYNC.08 values compare as their type: 50.0 from CERT equals PROD''s 50');

SELECT is(
  (SELECT count(*)::INT FROM tbl_audit_log
    WHERE txt_table_name = 'tbl_event'
      AND id_row = (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW8e-9700-9701')),
  0,
  'CALSYNC.09 an event with nothing to change is not written (F2)');

SELECT is(
  (SELECT ROW(txt_venue_address, url_invitation)::TEXT
     FROM tbl_event WHERE txt_code = 'PEW9e-9700-9701'),
  ROW('Kept address', 'https://example.org/09-letter.pdf')::TEXT,
  'CALSYNC.10 a payload without ts_details_set keeps the earlier rules (fill-blank, D7 A)');

SELECT is(
  (SELECT ROW(bool_use_spws_registration, dt_registration_deadline, replace(txt_iban, ' ', ''), url_event)::TEXT
     FROM tbl_event WHERE txt_code = 'PEW10e-9700-9701'),
  ROW(TRUE, '9701-10-01'::DATE, 'PL27114020040000300201355387', 'https://results.example.org/10')::TEXT,
  'CALSYNC.11 the switch, deadline, account and results link stay PROD''s');

SELECT is(
  (SELECT url_invitation FROM tbl_event WHERE txt_code = 'PEW11e-9700-9701'),
  'https://example.org/11-new.pdf',
  'CALSYNC.12 a later PROD change outside the nine does not make PROD newer');

-- pgt-ignore-start typecheck: temp tables/views this file creates (the checker sees only the live schema)
SELECT is(
  (SELECT (r ->> 'updated')::INT FROM sync_result),
  7,
  'CALSYNC.13 the updated count is the events that actually changed (01, 02, 04, 09, 11, 17, 19)');
-- pgt-ignore-end typecheck

SELECT is(
  (SELECT count(*)::INT FROM tbl_audit_log
    WHERE txt_table_name = 'tbl_event'
      AND id_row = (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW5e-9700-9701')),
  0,
  'CALSYNC.14 a blank-only payload writes nothing');

SELECT is(
  (SELECT txt_name FROM tbl_event WHERE txt_code = 'PEW4e-9700-9701'),
  'Sync 04 new',
  'CALSYNC.15 the name follows CERT when CERT is newer');

-- A second run with the same payload changes nothing: CERT is still the later
-- writer (the mirror's own write does not count), and the values are equal.
SELECT is(
  (SELECT (fn_mirror_events_to_prod(
     '[]'::JSONB,
     jsonb_build_array(jsonb_build_object(
       'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1e-9700-9701'),
       'ts_details_set', (NOW() - INTERVAL '10 days')::TEXT,
       'url_invitation', 'https://example.org/v1.pdf')),
     '[]'::JSONB) ->> 'updated')::INT),
  0,
  'CALSYNC.16 a repeated run is a no-op');

SELECT is(
  (SELECT url_invitation FROM tbl_event WHERE txt_code = 'PEW17e-9700-9701'),
  'https://example.org/17-october.pdf',
  'CALSYNC.17 a mirror write on PROD after CERT''s write does not make PROD newer (Madrid, 31 Oct)');

SELECT is(
  (SELECT url_invitation FROM tbl_event WHERE txt_code = 'PEW18e-9700-9701'),
  'https://example.org/18-person.pdf',
  'CALSYNC.18 a person''s PROD edit after CERT''s write keeps PROD, whatever the mirror wrote since');

SELECT is(
  (SELECT url_invitation FROM tbl_event WHERE txt_code = 'PEW19e-9700-9701'),
  'https://example.org/19-cert.pdf',
  'CALSYNC.19 an event no person changed on PROD takes CERT''s details');

SELECT * FROM finish();
ROLLBACK;
