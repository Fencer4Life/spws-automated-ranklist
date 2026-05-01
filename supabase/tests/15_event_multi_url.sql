-- =============================================================================
-- Multi-Slot Event Result URLs (ADR-040)
-- =============================================================================
-- Tests 15.1–15.6: tbl_event.url_event_2..5 columns + fn_compact_urls helper
--                  + compact-on-save in fn_create_event / fn_update_event /
--                  fn_refresh_evf_event_urls.
-- =============================================================================

BEGIN;
SELECT plan(7);

-- ===== SETUP =====
DO $setup$
DECLARE
  v_season INT;
BEGIN
  UPDATE tbl_season SET bool_active = FALSE;
  v_season := fn_create_season('MURL-TEST', '2030-09-01', '2031-06-30');
  UPDATE tbl_season SET bool_active = TRUE WHERE id_season = v_season;
END;
$setup$;


-- =========================================================================
-- 15.1 — tbl_event has columns url_event_2..5 (TEXT, nullable)
-- =========================================================================
SELECT is(
  (SELECT COUNT(*)::INT
     FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'tbl_event'
      AND column_name IN ('url_event_2','url_event_3','url_event_4','url_event_5')
      AND data_type = 'text'
      AND is_nullable = 'YES'),
  4,
  '15.1: tbl_event has 4 nullable TEXT columns url_event_2..5'
);


-- =========================================================================
-- 15.2 — fn_compact_urls returns a 5-element TEXT[] array
-- =========================================================================
SELECT is(
  array_length(fn_compact_urls('A','B','C','D','E'), 1),
  5,
  '15.2: fn_compact_urls returns a 5-element array'
);


-- =========================================================================
-- 15.3 — fn_compact_urls trims, drops empties, dedupes, pads NULL
--   Input:  [' A ', NULL, 'A', 'B', '   ']
--   Output: ['A','B', NULL, NULL, NULL]
-- =========================================================================
SELECT is(
  fn_compact_urls(' A ', NULL, 'A', 'B', '   '),
  ARRAY['A','B',NULL,NULL,NULL]::TEXT[],
  '15.3: fn_compact_urls trims, drops empties, dedupes preserving first occurrence, pads NULL'
);


-- =========================================================================
-- 15.4 — fn_create_event accepts p_url_event_2..5 and applies compact
--   Gap input [NULL, B, NULL, D, NULL] stored as [B, D, NULL, NULL, NULL]
-- =========================================================================
DO $t154$
DECLARE
  v_season INT;
  v_org    INT;
  v_id     INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'MURL-TEST';
  SELECT id_organizer INTO v_org FROM tbl_organizer LIMIT 1;
  IF v_org IS NULL THEN
    INSERT INTO tbl_organizer (txt_code, txt_name) VALUES ('MURL-ORG','MURL Test Org')
      RETURNING id_organizer INTO v_org;
  END IF;
  v_id := fn_create_event(
    'MURL-EV-15-4',                  -- p_code
    'Multi-URL gap-input event 15.4',-- p_name
    v_season,                        -- p_id_season
    v_org,                           -- p_id_organizer
    'Test City',                     -- p_location
    '2031-03-15'::DATE,              -- p_dt_start
    '2031-03-15'::DATE,              -- p_dt_end
    NULL,                            -- p_url_event   (gap)
    'Hungary',                       -- p_country
    NULL,                            -- p_venue_address
    NULL,                            -- p_invitation
    NULL,                            -- p_entry_fee
    NULL,                            -- p_entry_fee_currency
    NULL,                            -- p_weapons
    NULL,                            -- p_registration
    NULL,                            -- p_registration_deadline
    'https://b.example/',            -- p_url_event_2
    NULL,                            -- p_url_event_3
    'https://d.example/',            -- p_url_event_4
    NULL                             -- p_url_event_5
  );
END;
$t154$;

SELECT is(
  (SELECT ARRAY[url_event, url_event_2, url_event_3, url_event_4, url_event_5]
     FROM tbl_event WHERE txt_code = 'MURL-EV-15-4'),
  ARRAY['https://b.example/','https://d.example/',NULL,NULL,NULL]::TEXT[],
  '15.4: fn_create_event compacts gap-input [NULL,B,NULL,D,NULL] to [B,D,NULL,NULL,NULL]'
);


-- =========================================================================
-- 15.5 — fn_update_event applies compact when slot #1 cleared
--   Start [A, B, C, NULL, NULL]; admin clears slot #1; stored [B, C, NULL, NULL, NULL]
-- =========================================================================
DO $t155$
DECLARE
  v_season INT;
  v_org    INT;
  v_id     INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'MURL-TEST';
  SELECT id_organizer INTO v_org FROM tbl_organizer ORDER BY id_organizer LIMIT 1;
  v_id := fn_create_event(
    'MURL-EV-15-5',
    'Multi-URL clear-slot1 event 15.5',
    v_season, v_org,
    'Test City', '2031-04-15'::DATE, '2031-04-15'::DATE,
    'https://a.example/',
    'Hungary', NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    'https://b.example/', 'https://c.example/', NULL, NULL
  );
  -- Now admin clears slot #1 (passes empty for url_event); compact must left-shift.
  PERFORM fn_update_event(
    v_id,                         -- p_id
    'Multi-URL clear-slot1 event 15.5',
    'Test City',
    '2031-04-15'::DATE, '2031-04-15'::DATE,
    NULL,                         -- p_url_event ← cleared
    'Hungary', NULL, NULL, NULL, NULL, v_org, NULL, NULL, NULL,
    'https://b.example/',         -- p_url_event_2
    'https://c.example/',         -- p_url_event_3
    NULL,                         -- p_url_event_4
    NULL                          -- p_url_event_5
  );
END;
$t155$;

SELECT is(
  (SELECT ARRAY[url_event, url_event_2, url_event_3, url_event_4, url_event_5]
     FROM tbl_event WHERE txt_code = 'MURL-EV-15-5'),
  ARRAY['https://b.example/','https://c.example/',NULL,NULL,NULL]::TEXT[],
  '15.5: fn_update_event compacts after admin clears slot #1 of [A,B,C]'
);


-- =========================================================================
-- 15.6 — fn_refresh_evf_event_urls accepts new keys, applies per-slot
--          NULL-only invariant, then re-compacts.
--   Existing event slots: [A, NULL, NULL, NULL, NULL]
--   Refresh payload offers slot #2 = X, slot #3 = Y
--   After refresh: [A, X, Y, NULL, NULL]
-- =========================================================================
DO $t156$
DECLARE
  v_season   INT;
  v_org      INT;
  v_id       INT;
  v_payload  JSONB;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'MURL-TEST';
  SELECT id_organizer INTO v_org FROM tbl_organizer ORDER BY id_organizer LIMIT 1;
  v_id := fn_create_event(
    'MURL-EV-15-6',
    'Multi-URL refresh event 15.6',
    v_season, v_org,
    'Test City', '2031-05-15'::DATE, '2031-05-15'::DATE,
    'https://a.example/',
    'Hungary', NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL
  );
  v_payload := jsonb_build_array(jsonb_build_object(
    'id_event',     v_id,
    'url_event',    'https://stomp.example/',  -- should NOT overwrite (slot full)
    'url_event_2',  'https://x.example/',
    'url_event_3',  'https://y.example/'
  ));
  PERFORM fn_refresh_evf_event_urls(v_payload);
END;
$t156$;

SELECT is(
  (SELECT ARRAY[url_event, url_event_2, url_event_3, url_event_4, url_event_5]
     FROM tbl_event WHERE txt_code = 'MURL-EV-15-6'),
  ARRAY['https://a.example/','https://x.example/','https://y.example/',NULL,NULL]::TEXT[],
  '15.6: fn_refresh_evf_event_urls fills NULL slots #2,#3 and preserves slot #1 (admin-edit protection)'
);


-- =========================================================================
-- 15.7 — Regression guard: vw_calendar exposes url_event_2..5
--   Without this the admin Event-edit form silently loses slot data on the
--   round-trip through fetchCalendarEvents() — what looks like a save bug
--   but is actually a view contract bug.
-- =========================================================================
SELECT is(
  (SELECT COUNT(*)::INT
     FROM information_schema.columns
    WHERE table_name = 'vw_calendar'
      AND column_name IN ('url_event_2','url_event_3','url_event_4','url_event_5')),
  4,
  '15.7: vw_calendar exposes url_event_2..5 (form round-trip needs it)'
);


SELECT * FROM finish();
ROLLBACK;
