-- =============================================================================
-- EVF.URL — an EVF archive page never replaces an event's organiser URL
-- =============================================================================
-- The organiser's results page (FTL, Engarde, Ophardt, ...) is the source EVF
-- itself publishes from; the EVF archive page (veteransfencing.eu/event/...)
-- is used only when no organiser URL is stored. The daily EVF sync writes
-- url_event through fn_refresh_evf_event_urls (CERT) and
-- fn_mirror_events_to_prod (PROD), and both fill a blank slot only. The
-- identity sync, fn_sync_evf_event_fields, does not write url_event at all.
--
-- On 8 Aug 2026 a one-off migration (20260808000003) replaced the organiser
-- URLs of Guildford and Stockholm 2025/26 with EVF archive pages; the daily
-- sync did not. This file pins that the sync cannot do it.
-- doc/plans/international-data-repair-batch-1-2026-10-01.html. Rolls back.
-- =============================================================================

BEGIN;

SELECT plan(3);

DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
BEGIN
  INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
  VALUES ('SPWS-9500-9501', '9500-08-01', '9501-07-31', FALSE)
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-9500-9501';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'EVF';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status,
                         dt_start, dt_end, url_event)
  VALUES
    ('PEW1efs-9500-9501', 'EVF.URL organiser source', v_season, v_org, 'COMPLETED',
     '9501-01-10', '9501-01-11', 'https://www.fencingtimelive.com/tournaments/eventSchedule/EVFURL01'),
    ('PEW2efs-9500-9501', 'EVF.URL no source', v_season, v_org, 'COMPLETED',
     '9501-02-10', '9501-02-11', NULL),
    ('PEW3efs-9500-9501', 'EVF.URL refresh', v_season, v_org, 'COMPLETED',
     '9501-03-10', '9501-03-11', 'https://engarde-service.com/tournament/evfurl/03');
END;
$setup$;

-- The PROD mirror carries an EVF archive page for both events.
DO $mirror$
BEGIN
  PERFORM fn_mirror_events_to_prod(
    '[]'::JSONB,
    jsonb_build_array(
      jsonb_build_object(
        'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1efs-9500-9501'),
        'url_event', 'https://www.veteransfencing.eu/event/evf-url-01/'),
      jsonb_build_object(
        'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW2efs-9500-9501'),
        'url_event', 'https://www.veteransfencing.eu/event/evf-url-02/')),
    '[]'::JSONB);
  PERFORM fn_refresh_evf_event_urls(jsonb_build_array(jsonb_build_object(
    'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW3efs-9500-9501'),
    'url_event', 'https://www.veteransfencing.eu/event/evf-url-03/')));
END;
$mirror$;

SELECT results_eq(
  $$SELECT txt_code::TEXT, url_event::TEXT FROM tbl_event
     WHERE txt_code IN ('PEW1efs-9500-9501', 'PEW3efs-9500-9501') ORDER BY txt_code$$,
  $$VALUES ('PEW1efs-9500-9501', 'https://www.fencingtimelive.com/tournaments/eventSchedule/EVFURL01'),
           ('PEW3efs-9500-9501', 'https://engarde-service.com/tournament/evfurl/03')$$,
  'EVF.URL.01 the PROD mirror and the CERT URL refresh keep a stored organiser URL against an EVF archive page');

SELECT is(
  (SELECT url_event FROM tbl_event WHERE txt_code = 'PEW2efs-9500-9501'),
  'https://www.veteransfencing.eu/event/evf-url-02/',
  'EVF.URL.02 an event with no organiser URL takes the EVF archive page');

SELECT ok(
  pg_get_functiondef('fn_sync_evf_event_fields(jsonb)'::regprocedure) !~ 'url_event',
  'EVF.URL.03 the EVF identity sync does not write url_event');

SELECT * FROM finish();
ROLLBACK;
