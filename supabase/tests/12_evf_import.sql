-- =============================================================================
-- CERT->PROD event mirror tests (ADR-028; reconciler ADR pending sign-off)
-- =============================================================================
-- Tests 12.1, 12.4-12.9, 12.14: fn_mirror_events_to_prod CREATE branch
-- (ported from the retired fn_import_evf_events — see 51_prod_event_reconcile.sql
-- for the full C/U/D reconciler test suite; this file keeps the CREATE-payload
-- field-by-field coverage that predates the reconciler rewrite).
-- Tests 12.10-12.13: fn_refresh_evf_event_urls (untouched, reused as-is by
-- the reconciler's UPDATE branch for admin-owned URL fields).
-- =============================================================================

BEGIN;
SELECT plan(12);

-- ===== SETUP =====
DO $setup$
DECLARE
  v_season INT;
BEGIN
  UPDATE tbl_season SET bool_active = FALSE;
  v_season := fn_create_season('EVF-TEST', '2030-09-01', '2031-06-30');
  UPDATE tbl_season SET bool_active = TRUE WHERE id_season = v_season;
END;
$setup$;


-- =========================================================================
-- 12.1 — fn_mirror_events_to_prod CREATE inserts event with PLANNED status
-- =========================================================================
DO $t121$
DECLARE
  v_season  INT;
  v_org     INT;
  v_result  JSONB;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'EVF-TEST';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'EVF';
  v_result := fn_mirror_events_to_prod(
    jsonb_build_array(jsonb_build_object(
      'txt_code', 'PEW-TESTCITY-2030-2031', 'txt_name', 'EVF Circuit Test City',
      'id_season', v_season, 'id_organizer', v_org,
      'dt_start', '2031-03-15', 'dt_end', '2031-03-16',
      'txt_location', 'Test City', 'txt_country', 'Germany',
      'enum_status', 'PLANNED',
      'arr_weapons', jsonb_build_array('EPEE', 'FOIL')
    )),
    '[]'::JSONB, '[]'::JSONB
  );
END;
$t121$;

SELECT is(
  (SELECT enum_status::TEXT FROM tbl_event WHERE txt_code = 'PEW-TESTCITY-2030-2031'),
  'PLANNED',
  '12.1: fn_mirror_events_to_prod CREATE inserts event with PLANNED status'
);


-- =========================================================================
-- 12.4 — Re-CREATE with the same txt_code is idempotent (no duplicate row)
-- =========================================================================
DO $t124$
DECLARE
  v_season  INT;
  v_org     INT;
  v_result  JSONB;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'EVF-TEST';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'EVF';
  v_result := fn_mirror_events_to_prod(
    jsonb_build_array(jsonb_build_object(
      'txt_code', 'PEW-TESTCITY-2030-2031', 'txt_name', 'EVF Circuit Test City',
      'id_season', v_season, 'id_organizer', v_org,
      'dt_start', '2031-03-15', 'enum_status', 'PLANNED'
    )),
    '[]'::JSONB, '[]'::JSONB
  );
END;
$t124$;

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event WHERE txt_code = 'PEW-TESTCITY-2030-2031'),
  1,
  '12.4: re-CREATE with an existing txt_code is idempotent — still 1 event'
);


-- =========================================================================
-- 12.5–12.9 — fn_mirror_events_to_prod CREATE writes URL + enrichment fields
-- =========================================================================
DO $t125$
DECLARE
  v_season  INT;
  v_org     INT;
  v_result  JSONB;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'EVF-TEST';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'EVF';
  v_result := fn_mirror_events_to_prod(
    jsonb_build_array(jsonb_build_object(
      'txt_code', 'PEW-URLTEST-2030-2031', 'txt_name', 'EVF Circuit URL Test',
      'id_season', v_season, 'id_organizer', v_org,
      'dt_start', '2031-04-10', 'dt_end', '2031-04-11',
      'txt_location', 'URL City', 'txt_country', 'Germany',
      'enum_status', 'PLANNED',
      'url_event', 'https://www.veteransfencing.eu/event/url-test/',
      'url_invitation', 'https://www.veteransfencing.eu/wp-content/uploads/urltest-invitation.pdf',
      'url_registration', 'https://engarde-service.com/register/urltest',
      'dt_registration_deadline', '2031-04-01',
      'txt_venue_address', 'Main Street 1, URL City',
      'num_entry_fee', 85.0,
      'txt_entry_fee_currency', 'EUR'
    )),
    '[]'::JSONB, '[]'::JSONB
  );
END;
$t125$;

SELECT is(
  (SELECT url_event FROM tbl_event WHERE txt_code = 'PEW-URLTEST-2030-2031'),
  'https://www.veteransfencing.eu/event/url-test/',
  '12.5: fn_mirror_events_to_prod CREATE writes url_event'
);

SELECT is(
  (SELECT url_invitation FROM tbl_event WHERE txt_code = 'PEW-URLTEST-2030-2031'),
  'https://www.veteransfencing.eu/wp-content/uploads/urltest-invitation.pdf',
  '12.6: fn_mirror_events_to_prod CREATE writes url_invitation'
);

SELECT is(
  (SELECT url_registration FROM tbl_event WHERE txt_code = 'PEW-URLTEST-2030-2031'),
  'https://engarde-service.com/register/urltest',
  '12.7: fn_mirror_events_to_prod CREATE writes url_registration'
);

SELECT is(
  (SELECT dt_registration_deadline FROM tbl_event WHERE txt_code = 'PEW-URLTEST-2030-2031'),
  '2031-04-01'::DATE,
  '12.8: fn_mirror_events_to_prod CREATE writes dt_registration_deadline'
);

SELECT is(
  (SELECT txt_venue_address || '|' || COALESCE(num_entry_fee::TEXT,'') || '|' || COALESCE(txt_entry_fee_currency,'')
   FROM tbl_event WHERE txt_code = 'PEW-URLTEST-2030-2031'),
  'Main Street 1, URL City|85.0|EUR',
  '12.9: fn_mirror_events_to_prod CREATE writes address + fee + currency'
);


-- =========================================================================
-- 12.10–12.13 — fn_refresh_evf_event_urls: fill NULLs, preserve admin edits
-- (untouched — reused as-is by the reconciler's UPDATE branch)
-- =========================================================================
DO $t1210$
DECLARE
  v_season INT;
  v_event  INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'EVF-TEST';
  INSERT INTO tbl_event (
    txt_code, txt_name, id_season, id_organizer,
    dt_start, txt_location, txt_country, enum_status,
    url_registration, url_invitation, arr_weapons
  ) VALUES (
    'PEW-REFRESH-2030-2031', 'Admin-edited name', v_season,
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    '2031-05-15', 'Refresh City', 'France', 'PLANNED',
    'https://admin-edit.example.com/register', NULL, '{EPEE}'::enum_weapon_type[]
  ) RETURNING id_event INTO v_event;

  PERFORM fn_refresh_evf_event_urls(
    ('[{
        "id_event": ' || v_event || ',
        "url_event": "https://scraped.example.com/event",
        "url_invitation": "https://scraped.example.com/invitation.pdf",
        "url_registration": "https://SCRAPED-SHOULD-NOT-WIN.example.com/reg",
        "address": "Scraped Address",
        "fee": 60.0,
        "fee_currency": "EUR",
        "weapons": ["EPEE","FOIL","SABRE"]
     }]')::JSONB
  );
END;
$t1210$;

SELECT is(
  (SELECT url_invitation FROM tbl_event WHERE txt_code = 'PEW-REFRESH-2030-2031'),
  'https://scraped.example.com/invitation.pdf',
  '12.10: fn_refresh_evf_event_urls fills NULL url_invitation with scraped value'
);

SELECT is(
  (SELECT url_registration FROM tbl_event WHERE txt_code = 'PEW-REFRESH-2030-2031'),
  'https://admin-edit.example.com/register',
  '12.11: fn_refresh_evf_event_urls does NOT overwrite admin-set url_registration'
);

SELECT is(
  (SELECT txt_name FROM tbl_event WHERE txt_code = 'PEW-REFRESH-2030-2031'),
  'Admin-edited name',
  '12.12: fn_refresh_evf_event_urls never touches txt_name'
);

-- 12.13: unknown id_event returns touched=1, refreshed=0 without exception
SELECT is(
  (SELECT fn_refresh_evf_event_urls(
    '[{"id_event": 999999999, "url_event": "https://x.example.com/"}]'::JSONB
  )),
  jsonb_build_object('touched', 1, 'refreshed', 0),
  '12.13: fn_refresh_evf_event_urls is a no-op on unknown id_event'
);


-- =========================================================================
-- 12.14 — empty-string dt_start (promote.py's NULL sentinel) does not error
-- =========================================================================
-- The CERT->PROD event mirror (python/pipeline/promote.py) always emits
-- "" rather than JSON null for missing date fields (payload-shape stability).
-- fn_mirror_events_to_prod must accept "" for dt_start/dt_end the same way
-- fn_refresh_evf_event_urls already does for dt_registration_deadline, and
-- store NULL, not error.
DO $t1214$
DECLARE
  v_season  INT;
  v_org     INT;
  v_result  JSONB;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'EVF-TEST';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'EVF';
  v_result := fn_mirror_events_to_prod(
    jsonb_build_array(jsonb_build_object(
      'txt_code', 'PEW-NODATE-2030-2031', 'txt_name', 'EVF Circuit No Date',
      'id_season', v_season, 'id_organizer', v_org,
      'dt_start', '', 'dt_end', '',
      'txt_location', 'No Date City', 'txt_country', 'Germany',
      'enum_status', 'PLANNED'
    )),
    '[]'::JSONB, '[]'::JSONB
  );
END;
$t1214$;

SELECT is(
  (SELECT dt_start FROM tbl_event WHERE txt_code = 'PEW-NODATE-2030-2031'),
  NULL::DATE,
  '12.14: fn_mirror_events_to_prod CREATE accepts empty-string dt_start/dt_end as NULL, no error'
);


SELECT * FROM finish();
ROLLBACK;
