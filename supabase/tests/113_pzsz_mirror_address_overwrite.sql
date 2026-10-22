-- =============================================================================
-- pgTAP — D5: the mirror overwrites a PZSz event's venue address (ADR-116 §9)
-- =============================================================================
-- Verifies migration 20261021000002_pzsz_mirror_address_overwrite.sql: for a
-- PZSz event (id_pzsz_event present) fn_mirror_events_to_prod OVERWRITES
-- txt_venue_address with CERT's value and seeds an empty PROD field, while a
-- non-PZSz event keeps the fill-blank policy, and an empty CERT value never
-- blanks a PROD address.
-- =============================================================================

BEGIN;

SELECT plan(5);

DO $setup$
DECLARE
  v_season INT;
  v_pzsz   INT;
  v_spws   INT;
BEGIN
  INSERT INTO tbl_season (txt_code, dt_start, dt_end)
  VALUES ('SPWS-6900-6901', '6900-08-01', '6901-07-31')
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-6900-6901';
  INSERT INTO tbl_organizer (txt_code, txt_name)
  VALUES ('PZSz', 'Polski Związek Szermierczy') ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_organizer INTO v_pzsz FROM tbl_organizer WHERE txt_code = 'PZSz';
  INSERT INTO tbl_organizer (txt_code, txt_name)
  VALUES ('SPWS', 'SPWS') ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_organizer INTO v_spws FROM tbl_organizer WHERE txt_code = 'SPWS';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status,
                         dt_start, dt_end, txt_venue_address, id_pzsz_event)
  VALUES
    ('PZD1-6900-6901', 'PZSz overwrite', v_season, v_pzsz, 'PLANNED',
     '6900-10-03', '6900-10-03', 'PROD hall OLD', 7901),
    ('PZD2-6900-6901', 'PZSz empty CERT', v_season, v_pzsz, 'PLANNED',
     '6900-11-07', '6900-11-07', 'PROD hall Y', 7902),
    ('PZD3-6900-6901', 'PZSz seed', v_season, v_pzsz, 'PLANNED',
     '6900-12-05', '6900-12-05', NULL, 7903);
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status,
                         dt_start, dt_end, txt_venue_address)
  VALUES
    ('SPD1-6900-6901', 'SPWS fill-blank', v_season, v_spws, 'PLANNED',
     '6901-01-09', '6901-01-09', 'PROD spws hall');
END;
$setup$;

SELECT lives_ok(
  $mir$
  SELECT fn_mirror_events_to_prod(
    '[]'::JSONB,
    jsonb_build_array(
      jsonb_build_object(
        'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PZD1-6900-6901'),
        'id_pzsz_event', 7901, 'txt_venue_address', 'CERT hall NEW'),
      jsonb_build_object(
        'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PZD2-6900-6901'),
        'id_pzsz_event', 7902, 'txt_venue_address', ''),
      jsonb_build_object(
        'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PZD3-6900-6901'),
        'id_pzsz_event', 7903, 'txt_venue_address', 'CERT hall SEED'),
      jsonb_build_object(
        'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'SPD1-6900-6901'),
        'txt_venue_address', 'CERT spws NEW')
    ),
    '[]'::JSONB)
  $mir$,
  '113.0 — the mirror accepts the update batch'
);

SELECT is(
  (SELECT txt_venue_address FROM tbl_event WHERE txt_code = 'PZD1-6900-6901'),
  'CERT hall NEW',
  '113.1 — a PZSz event''s address is overwritten by CERT'
);
SELECT is(
  (SELECT txt_venue_address FROM tbl_event WHERE txt_code = 'SPD1-6900-6901'),
  'PROD spws hall',
  '113.2 — a non-PZSz event keeps fill-blank: PROD''s address stands'
);
SELECT is(
  (SELECT txt_venue_address FROM tbl_event WHERE txt_code = 'PZD2-6900-6901'),
  'PROD hall Y',
  '113.3 — an empty CERT value never blanks a PZSz event''s PROD address'
);
SELECT is(
  (SELECT txt_venue_address FROM tbl_event WHERE txt_code = 'PZD3-6900-6901'),
  'CERT hall SEED',
  '113.4 — an empty PROD address is seeded from CERT for a PZSz event'
);

SELECT * FROM finish();
ROLLBACK;
