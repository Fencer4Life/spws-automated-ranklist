-- =============================================================================
-- CALURL — calendar automation never writes an event's results link
-- =============================================================================
-- url_event … url_event_5 (Admin: "URL wyników") stay empty until an
-- administrator fills them in the Admin UI. The calendar functions (EVF create,
-- EVF refresh, the CERT→PROD mirror, the identity syncs) write the organizer's
-- letter to url_invitation ("URL komunikatu") and nothing to the results slots.
-- fn_clear_calendar_results_links() removes the calendar pages the scrapers
-- wrote before this rule, in seasons that have not ended, and never a value an
-- administrator set.
-- doc/plans/pzsz-results-url-rca-2026-10-25.html. Rolls back.
-- =============================================================================

BEGIN;

SELECT plan(9);

DO $setup$
DECLARE
  v_open   INT;
  v_closed INT;
  v_evf    INT;
  v_pzsz   INT;
BEGIN
  INSERT INTO tbl_season (txt_code, dt_start, dt_end)
  VALUES ('SPWS-9600-9601', '9600-08-01', '9601-07-31'),
         ('SPWS-1990-1991', '1990-08-01', '1991-07-31')
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_season INTO v_open FROM tbl_season WHERE txt_code = 'SPWS-9600-9601';
  SELECT id_season INTO v_closed FROM tbl_season WHERE txt_code = 'SPWS-1990-1991';
  SELECT id_organizer INTO v_evf FROM tbl_organizer WHERE txt_code = 'EVF';
  SELECT id_organizer INTO v_pzsz FROM tbl_organizer WHERE txt_code = 'PZSz';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status,
                         dt_start, dt_end, url_event, url_event_2)
  VALUES
    ('PEW1e-9600-9601', 'CALURL refresh target', v_open, v_evf, 'PLANNED',
     '9601-01-10', '9601-01-11', NULL, NULL),
    ('PEW2e-9600-9601', 'CALURL mirror blank', v_open, v_evf, 'PLANNED',
     '9601-02-10', '9601-02-11', NULL, NULL),
    ('PEW3e-9600-9601', 'CALURL mirror admin', v_open, v_evf, 'PLANNED',
     '9601-03-10', '9601-03-11',
     'https://www.fencingtimelive.com/tournaments/eventSchedule/CALURL03', NULL),
    -- clean-up fixtures
    ('PPS1f-9600-9601', 'CALURL pzsz page', v_open, v_pzsz, 'PLANNED',
     '9601-04-10', '9601-04-11',
     'https://pzszerm.pl/zawody/kalendarium-zawodow/zawody/?id=9601', NULL),
    ('PEW4e-9600-9601', 'CALURL evf page, organiser link behind it', v_open, v_evf, 'PLANNED',
     '9601-05-10', '9601-05-11',
     'https://www.veteransfencing.eu/event/calurl-04/',
     'https://engarde-service.com/tournament/calurl/04'),
    ('PEW5e-9600-9601', 'CALURL organiser link', v_open, v_evf, 'PLANNED',
     '9601-06-10', '9601-06-11',
     'https://www.fencingtimelive.com/tournaments/eventSchedule/CALURL05', NULL),
    ('PEW6e-9600-9601', 'CALURL evf page set by an admin', v_open, v_evf, 'PLANNED',
     '9601-07-10', '9601-07-11',
     'https://www.veteransfencing.eu/event/calurl-06/', NULL),
    ('PEW8e-9600-9601', 'CALURL evf page an admin only re-saved', v_open, v_evf, 'PLANNED',
     '9601-07-20', '9601-07-21',
     'https://www.veteransfencing.eu/event/calurl-08/', NULL),
    ('PEW1e-1990-1991', 'CALURL closed season', v_closed, v_evf, 'COMPLETED',
     '1991-01-10', '1991-01-11',
     'https://www.veteransfencing.eu/event/calurl-closed/', NULL);

  -- An admin set PEW6e's link; an admin saved PEW8e's form for its fee
  -- currency, so its (scraped) link is in the audit row unchanged.
  INSERT INTO tbl_audit_log (txt_table_name, id_row, txt_action, jsonb_old_values,
                             jsonb_new_values, txt_admin_user)
  SELECT 'tbl_event', id_event, 'UPDATE', jsonb_build_object('url_event', NULL),
         jsonb_build_object('url_event', 'https://www.veteransfencing.eu/event/calurl-06/'),
         '00000000-0000-0000-0000-00000000ca1a'
    FROM tbl_event WHERE txt_code = 'PEW6e-9600-9601';
  INSERT INTO tbl_audit_log (txt_table_name, id_row, txt_action, jsonb_old_values,
                             jsonb_new_values, txt_admin_user)
  SELECT 'tbl_event', id_event, 'UPDATE',
         jsonb_build_object('url_event', 'https://www.veteransfencing.eu/event/calurl-08/',
                            'txt_entry_fee_currency', 'PLN'),
         jsonb_build_object('url_event', 'https://www.veteransfencing.eu/event/calurl-08/',
                            'txt_entry_fee_currency', 'EUR'),
         '00000000-0000-0000-0000-00000000ca1a'
    FROM tbl_event WHERE txt_code = 'PEW8e-9600-9601';
END;
$setup$;

-- CALURL.10 — no calendar function writes a results slot
SELECT is(
  (SELECT string_agg(p.oid::regprocedure::TEXT, ', ' ORDER BY p.oid::regprocedure::TEXT)
     FROM pg_proc p
    WHERE p.pronamespace = 'public'::regnamespace
      AND p.proname IN ('fn_ingest_evf_calendar', 'fn_ingest_evf_calendar_identity_v1',
                        'fn_refresh_evf_event_urls', 'fn_mirror_events_to_prod',
                        'fn_sync_evf_event_fields', 'fn_pzsz_apply_event')
      AND pg_get_functiondef(p.oid) ~* 'url_event'),
  NULL,
  'CALURL.10 no calendar function names a results slot (url_event … url_event_5)');

-- CALURL.11 — the EVF refresh carries the letter, not a results link
DO $refresh$
BEGIN
  PERFORM fn_refresh_evf_event_urls(jsonb_build_array(jsonb_build_object(
    'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1e-9600-9601'),
    'url_event', 'https://www.veteransfencing.eu/event/calurl-01/',
    'url_event_2', 'https://x.example/2',
    'url_invitation', 'https://www.veteransfencing.eu/wp-content/uploads/calurl-01.pdf')));
END;
$refresh$;

SELECT results_eq(
  $$SELECT ARRAY[url_event, url_event_2, url_event_3, url_event_4, url_event_5], url_invitation
      FROM tbl_event WHERE txt_code = 'PEW1e-9600-9601'$$,
  $$VALUES (ARRAY[NULL, NULL, NULL, NULL, NULL]::TEXT[],
            'https://www.veteransfencing.eu/wp-content/uploads/calurl-01.pdf'::TEXT)$$,
  'CALURL.11 fn_refresh_evf_event_urls leaves the results slots empty and fills the letter');

-- CALURL.12 / .13 — the CERT→PROD mirror carries the letter, not a results link
DO $mirror$
DECLARE
  v_season INT := (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-9600-9601');
BEGIN
  PERFORM fn_mirror_events_to_prod(
    jsonb_build_array(jsonb_build_object(
      'txt_code', 'PEW7e-9600-9601', 'txt_name', 'CALURL mirror create',
      'id_season', v_season,
      'id_organizer', (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
      'dt_start', '9601-07-20', 'dt_end', '9601-07-21', 'enum_status', 'PLANNED',
      'url_event', 'https://www.veteransfencing.eu/event/calurl-07/',
      'url_event_2', 'https://x.example/7',
      'url_invitation', 'https://www.veteransfencing.eu/wp-content/uploads/calurl-07.pdf')),
    jsonb_build_array(
      jsonb_build_object(
        'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW2e-9600-9601'),
        'url_event', 'https://www.veteransfencing.eu/event/calurl-02/',
        'url_event_2', 'https://x.example/2'),
      jsonb_build_object(
        'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW3e-9600-9601'),
        'url_event', 'https://www.veteransfencing.eu/event/calurl-03/')),
    '[]'::JSONB);
END;
$mirror$;

SELECT results_eq(
  $$SELECT ARRAY[url_event, url_event_2, url_event_3, url_event_4, url_event_5], url_invitation
      FROM tbl_event WHERE txt_code = 'PEW7e-9600-9601'$$,
  $$VALUES (ARRAY[NULL, NULL, NULL, NULL, NULL]::TEXT[],
            'https://www.veteransfencing.eu/wp-content/uploads/calurl-07.pdf'::TEXT)$$,
  'CALURL.12 the mirror CREATE leaves the results slots empty and carries the letter');

SELECT results_eq(
  $$SELECT txt_code::TEXT, ARRAY[url_event, url_event_2, url_event_3, url_event_4, url_event_5]
      FROM tbl_event WHERE txt_code IN ('PEW2e-9600-9601', 'PEW3e-9600-9601') ORDER BY txt_code$$,
  $$VALUES ('PEW2e-9600-9601', ARRAY[NULL, NULL, NULL, NULL, NULL]::TEXT[]),
           ('PEW3e-9600-9601', ARRAY['https://www.fencingtimelive.com/tournaments/eventSchedule/CALURL03',
                                     NULL, NULL, NULL, NULL]::TEXT[])$$,
  'CALURL.13 the mirror UPDATE fills no empty results slot and keeps an admin link');

-- CALURL.14 — the clean-up removes calendar pages only, and never an admin's
SELECT fn_clear_calendar_results_links();

SELECT is(
  (SELECT url_event FROM tbl_event WHERE txt_code = 'PPS1f-9600-9601'),
  NULL,
  'CALURL.14a a pzszerm.pl calendar page leaves the results slot');

SELECT results_eq(
  $$SELECT ARRAY[url_event, url_event_2, url_event_3, url_event_4, url_event_5]
      FROM tbl_event WHERE txt_code = 'PEW4e-9600-9601'$$,
  $$VALUES (ARRAY['https://engarde-service.com/tournament/calurl/04', NULL, NULL, NULL, NULL]::TEXT[])$$,
  'CALURL.14b an EVF calendar page leaves, and the organiser link behind it moves to slot 1');

SELECT results_eq(
  $$SELECT txt_code::TEXT, url_event::TEXT FROM tbl_event
     WHERE txt_code IN ('PEW5e-9600-9601', 'PEW6e-9600-9601', 'PEW1e-1990-1991') ORDER BY txt_code$$,
  $$VALUES ('PEW1e-1990-1991', 'https://www.veteransfencing.eu/event/calurl-closed/'),
           ('PEW5e-9600-9601', 'https://www.fencingtimelive.com/tournaments/eventSchedule/CALURL05'),
           ('PEW6e-9600-9601', 'https://www.veteransfencing.eu/event/calurl-06/')$$,
  'CALURL.14c an organiser link, an admin''s own value and a closed season are left alone');

SELECT is(
  (SELECT url_event FROM tbl_event WHERE txt_code = 'PEW8e-9600-9601'),
  NULL,
  'CALURL.14d a calendar page an admin only re-saved (another field changed) still leaves');

-- CALURL.15 — after the bootstrap (migration or seed_post_backfill.sql), no
-- event of a season that has not ended holds a calendar page in a results slot
SELECT is(
  (SELECT count(*)::INT
     FROM tbl_event e
     JOIN tbl_season s ON s.id_season = e.id_season
    WHERE s.dt_end >= CURRENT_DATE
      AND e.txt_code NOT LIKE '%-9600-9601'
      AND EXISTS (
        SELECT 1
          FROM unnest(ARRAY[e.url_event, e.url_event_2, e.url_event_3, e.url_event_4, e.url_event_5]) AS u(url)
         WHERE u.url ~* '^https?://(www\.)?(pzszerm\.pl/zawody/kalendarium-zawodow/zawody/|veteransfencing\.eu/event/)')),
  0,
  'CALURL.15 no event of an open season holds a calendar page as a results link');

SELECT * FROM finish();
ROLLBACK;
