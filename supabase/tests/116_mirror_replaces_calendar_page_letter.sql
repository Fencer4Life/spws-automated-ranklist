-- =============================================================================
-- CALURL.23 — the mirror replaces a calendar page in PROD's URL komunikatu (D7 A)
-- =============================================================================
-- PROD's url_invitation ("URL komunikatu") kept the EVF event page that the
-- calendar once wrote, while CERT moved on to the organizer's letter: the
-- mirror fills PROD's field only while it is empty. Now, when PROD holds a
-- calendar page (pzszerm.pl or veteransfencing.eu event page) and CERT holds
-- a letter, the mirror's UPDATE replaces it. Any other PROD value stays, and
-- an empty one is still filled. ADR-117 §2, plan
-- doc/plans/pzsz-results-url-rca-2026-10-25.html. Rolls back.
-- =============================================================================

BEGIN;

SELECT plan(4);

DO $setup$
DECLARE
  v_season INT;
  v_evf    INT;
BEGIN
  INSERT INTO tbl_season (txt_code, dt_start, dt_end)
  VALUES ('SPWS-9600-9601', '9600-08-01', '9601-07-31')
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-9600-9601';
  SELECT id_organizer INTO v_evf FROM tbl_organizer WHERE txt_code = 'EVF';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status,
                         dt_start, dt_end, url_invitation)
  VALUES
    ('PEW1e-9600-9601', 'CALURL.23 page, CERT letter', v_season, v_evf, 'PLANNED',
     '9601-01-10', '9601-01-11', 'https://www.veteransfencing.eu/event/calurl-23a/'),
    ('PEW2e-9600-9601', 'CALURL.23 page, CERT page too', v_season, v_evf, 'PLANNED',
     '9601-02-10', '9601-02-11', 'https://www.veteransfencing.eu/event/calurl-23b/'),
    ('PEW3e-9600-9601', 'CALURL.23 older letter', v_season, v_evf, 'PLANNED',
     '9601-03-10', '9601-03-11', 'https://www.veteransfencing.eu/wp-content/uploads/old.pdf'),
    ('PEW4e-9600-9601', 'CALURL.23 empty', v_season, v_evf, 'PLANNED',
     '9601-04-10', '9601-04-11', NULL);
END
$setup$;

DO $mirror$
BEGIN
  PERFORM fn_mirror_events_to_prod(
    '[]'::JSONB,
    jsonb_build_array(
      jsonb_build_object(
        'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1e-9600-9601'),
        'url_invitation', 'https://www.veteransfencing.eu/wp-content/uploads/new-a.pdf'),
      jsonb_build_object(
        'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW2e-9600-9601'),
        'url_invitation', 'https://www.veteransfencing.eu/event/calurl-23b-cert/'),
      jsonb_build_object(
        'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW3e-9600-9601'),
        'url_invitation', 'https://www.veteransfencing.eu/wp-content/uploads/new-c.pdf'),
      jsonb_build_object(
        'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW4e-9600-9601'),
        'url_invitation', 'https://www.veteransfencing.eu/wp-content/uploads/new-d.pdf')),
    '[]'::JSONB);
END;
$mirror$;

SELECT is(
  (SELECT url_invitation FROM tbl_event WHERE txt_code = 'PEW1e-9600-9601'),
  'https://www.veteransfencing.eu/wp-content/uploads/new-a.pdf',
  'CALURL.23a a calendar page on PROD gives way to CERT''s letter');

SELECT is(
  (SELECT url_invitation FROM tbl_event WHERE txt_code = 'PEW2e-9600-9601'),
  'https://www.veteransfencing.eu/event/calurl-23b/',
  'CALURL.23b CERT holding a calendar page too replaces nothing');

SELECT is(
  (SELECT url_invitation FROM tbl_event WHERE txt_code = 'PEW3e-9600-9601'),
  'https://www.veteransfencing.eu/wp-content/uploads/old.pdf',
  'CALURL.23c any other PROD value stays');

SELECT is(
  (SELECT url_invitation FROM tbl_event WHERE txt_code = 'PEW4e-9600-9601'),
  'https://www.veteransfencing.eu/wp-content/uploads/new-d.pdf',
  'CALURL.23d an empty PROD field is still filled');

SELECT * FROM finish();
ROLLBACK;
