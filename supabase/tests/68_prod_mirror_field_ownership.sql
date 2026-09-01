-- =============================================================================
-- pgTAP — who owns each field CERT→PROD
-- =============================================================================
-- Verifies 20260829000001_prod_mirror_field_ownership.sql.
--
-- 20260828000009 classified bool_use_spws_registration as CERT-owned config
-- that overwrites. The column is NOT NULL DEFAULT false, so CERT always states a
-- value and the overwrite was unconditional -- the next promote would have
-- switched off a live PROD registration form holding 18 entries.
--
-- Three ownership tiers, one assertion each way:
--   scraped from EVF  -> overwrite   (68.2: a moved date must reach PROD)
--   admin enrichment  -> fill-blank  (68.3, 68.4)
--   per-environment   -> not synced  (68.5, 68.6)
-- =============================================================================

BEGIN;

SELECT plan(6);

SELECT has_function(
  'fn_mirror_events_to_prod',
  '68.1 — fn_mirror_events_to_prod() exists'
);

DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
BEGIN
  INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
  VALUES ('SPWS-6800-6801', '6800-08-01', '6801-07-31', FALSE)
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-6800-6801';
  INSERT INTO tbl_organizer (txt_code, txt_name)
  VALUES ('SPWS', 'SPWS') ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  -- A live PROD event: registration ON, venue already filled in on PROD.
  INSERT INTO tbl_event (
    txt_code, txt_name, id_season, id_organizer, enum_status,
    dt_start, dt_end, txt_venue_address, bool_use_spws_registration
  ) VALUES (
    'PPW1-6800-6801', 'Live event', v_season, v_org, 'PLANNED',
    '6801-03-01', '6801-03-02', 'PROD hall, Opole', TRUE
  );

  -- A PROD event whose venue is still empty.
  INSERT INTO tbl_event (
    txt_code, txt_name, id_season, id_organizer, enum_status, dt_start
  ) VALUES (
    'PPW2-6800-6801', 'Empty venue', v_season, v_org, 'PLANNED', '6801-03-05'
  );
END;
$setup$;

DO $apply$
DECLARE
  v_a INT;
  v_b INT;
BEGIN
  SELECT id_event INTO v_a FROM tbl_event WHERE txt_code = 'PPW1-6800-6801';
  SELECT id_event INTO v_b FROM tbl_event WHERE txt_code = 'PPW2-6800-6801';
  PERFORM fn_mirror_events_to_prod(
    '[]'::JSONB,
    jsonb_build_array(
      -- CERT moved the date, holds a different venue, and has registration OFF
      jsonb_build_object(
        'id_event', v_a,
        'dt_start', '6801-04-15',
        'txt_venue_address', 'CERT hall, Warszawa',
        'bool_use_spws_registration', false),
      -- CERT seeds a venue into an event that has none on PROD
      jsonb_build_object(
        'id_event', v_b,
        'txt_venue_address', 'CERT hall, Kraków')
    ),
    '[]'::JSONB);
END;
$apply$;

-- 68.2 — scraped fact: a moved date MUST reach PROD, or the calendar goes stale
SELECT is(
  (SELECT dt_start::TEXT FROM tbl_event WHERE txt_code = 'PPW1-6800-6801'),
  '6801-04-15',
  '68.2 — dt_start overwrites: EVF moving a date reaches PROD'
);

-- 68.3 — admin enrichment: a value already on PROD stops propagation
SELECT is(
  (SELECT txt_venue_address FROM tbl_event WHERE txt_code = 'PPW1-6800-6801'),
  'PROD hall, Opole',
  '68.3 — txt_venue_address is fill-blank: a PROD value is not overwritten'
);

-- 68.4 — …but an empty PROD field is still seeded from CERT
SELECT is(
  (SELECT txt_venue_address FROM tbl_event WHERE txt_code = 'PPW2-6800-6801'),
  'CERT hall, Kraków',
  '68.4 — txt_venue_address is seeded when PROD has none'
);

-- 68.5 — THE ONE THAT MATTERS: a live registration is never switched off
SELECT is(
  (SELECT bool_use_spws_registration FROM tbl_event WHERE txt_code = 'PPW1-6800-6801'),
  TRUE,
  '68.5 — registration stays ON in PROD though CERT has it OFF'
);

-- 68.6 — and the reverse: CERT cannot switch it on either. PROD owns it.
DO $on$
DECLARE
  v_b INT;
BEGIN
  SELECT id_event INTO v_b FROM tbl_event WHERE txt_code = 'PPW2-6800-6801';
  PERFORM fn_mirror_events_to_prod(
    '[]'::JSONB,
    jsonb_build_array(jsonb_build_object(
      'id_event', v_b, 'bool_use_spws_registration', true)),
    '[]'::JSONB);
END;
$on$;

SELECT is(
  (SELECT bool_use_spws_registration FROM tbl_event WHERE txt_code = 'PPW2-6800-6801'),
  FALSE,
  '68.6 — the switch is PROD-owned in both directions, not merely protected'
);

SELECT * FROM finish();
ROLLBACK;
