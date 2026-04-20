-- =============================================================================
-- EVF Import Tests (ADR-028)
-- =============================================================================
-- Tests 12.1–12.4: fn_import_evf_events
-- =============================================================================

BEGIN;
SELECT plan(13);

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
-- 12.1 — fn_import_evf_events creates event with PLANNED status
-- =========================================================================
DO $t121$
DECLARE
  v_season INT;
  v_result JSONB;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'EVF-TEST';
  v_result := fn_import_evf_events(
    '[{"code": "PEW-TESTCITY-2030-2031", "name": "EVF Circuit Test City", "dt_start": "2031-03-15", "dt_end": "2031-03-16", "location": "Test City", "country": "Germany", "weapons": ["EPEE", "FOIL"], "is_team": false}]'::JSONB,
    v_season
  );
END;
$t121$;

SELECT is(
  (SELECT enum_status::TEXT FROM tbl_event WHERE txt_code = 'PEW-TESTCITY-2030-2031'),
  'PLANNED',
  '12.1: fn_import_evf_events creates event with PLANNED status'
);


-- =========================================================================
-- 12.2 — fn_import_evf_events creates child tournaments per weapon
-- =========================================================================
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_tournament WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW-TESTCITY-2030-2031')),
  4,
  '12.2: fn_import_evf_events creates 4 tournaments (2 weapons × 2 genders)'
);


-- =========================================================================
-- 12.3 — fn_import_evf_events sets tournament type to PEW
-- =========================================================================
SELECT is(
  (SELECT DISTINCT enum_type::TEXT FROM tbl_tournament WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW-TESTCITY-2030-2031')),
  'PEW',
  '12.3: All tournaments have type PEW'
);


-- =========================================================================
-- 12.4 — Duplicate import is idempotent
-- =========================================================================
DO $t124$
DECLARE
  v_season INT;
  v_result JSONB;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'EVF-TEST';
  v_result := fn_import_evf_events(
    '[{"code": "PEW-TESTCITY-2030-2031", "name": "EVF Circuit Test City", "dt_start": "2031-03-15", "weapons": ["EPEE", "FOIL"], "is_team": false}]'::JSONB,
    v_season
  );
END;
$t124$;

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event WHERE txt_code = 'PEW-TESTCITY-2030-2031'),
  1,
  '12.4: Duplicate import is idempotent — still 1 event'
);


-- =========================================================================
-- 12.5–12.9 — fn_import_evf_events writes URL + enrichment fields
-- =========================================================================
DO $t125$
DECLARE
  v_season INT;
  v_result JSONB;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'EVF-TEST';
  v_result := fn_import_evf_events(
    '[{
       "code": "PEW-URLTEST-2030-2031",
       "name": "EVF Circuit URL Test",
       "dt_start": "2031-04-10",
       "dt_end": "2031-04-11",
       "location": "URL City",
       "country": "Germany",
       "weapons": ["EPEE"],
       "is_team": false,
       "url_event": "https://www.veteransfencing.eu/event/url-test/",
       "url_invitation": "https://www.veteransfencing.eu/wp-content/uploads/urltest-invitation.pdf",
       "url_registration": "https://engarde-service.com/register/urltest",
       "dt_registration_deadline": "2031-04-01",
       "address": "Main Street 1, URL City",
       "fee": 85.0,
       "fee_currency": "EUR"
    }]'::JSONB,
    v_season
  );
END;
$t125$;

SELECT is(
  (SELECT url_event FROM tbl_event WHERE txt_code = 'PEW-URLTEST-2030-2031'),
  'https://www.veteransfencing.eu/event/url-test/',
  '12.5: fn_import_evf_events writes url_event'
);

SELECT is(
  (SELECT url_invitation FROM tbl_event WHERE txt_code = 'PEW-URLTEST-2030-2031'),
  'https://www.veteransfencing.eu/wp-content/uploads/urltest-invitation.pdf',
  '12.6: fn_import_evf_events writes url_invitation'
);

SELECT is(
  (SELECT url_registration FROM tbl_event WHERE txt_code = 'PEW-URLTEST-2030-2031'),
  'https://engarde-service.com/register/urltest',
  '12.7: fn_import_evf_events writes url_registration'
);

SELECT is(
  (SELECT dt_registration_deadline FROM tbl_event WHERE txt_code = 'PEW-URLTEST-2030-2031'),
  '2031-04-01'::DATE,
  '12.8: fn_import_evf_events writes dt_registration_deadline'
);

SELECT is(
  (SELECT txt_venue_address || '|' || COALESCE(num_entry_fee::TEXT,'') || '|' || COALESCE(txt_entry_fee_currency,'')
   FROM tbl_event WHERE txt_code = 'PEW-URLTEST-2030-2031'),
  'Main Street 1, URL City|85.0|EUR',
  '12.9: fn_import_evf_events writes address + fee + currency'
);


-- =========================================================================
-- 12.10–12.13 — fn_refresh_evf_event_urls: fill NULLs, preserve admin edits
-- =========================================================================
-- Setup: create a seed event with admin-edited url_registration + txt_name,
-- but a NULL url_invitation. The refresh must fill the NULL while preserving
-- the admin-curated fields.
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


SELECT * FROM finish();
ROLLBACK;
