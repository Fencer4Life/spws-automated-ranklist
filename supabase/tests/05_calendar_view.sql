-- =============================================================================
-- T8.2: Calendar API View — Acceptance Tests
-- =============================================================================
-- Tests 8.11–8.17 from doc/archive/m8_implementation_plan.md §T8.2.
-- Verifies vw_calendar provides events + tournament counts for Calendar UI.
-- =============================================================================

BEGIN;
SELECT plan(10);

-- ===== SETUP: Create test data for calendar view =====
DO $setup$
DECLARE
  v_season INT;
  v_org INT;
  v_event1 INT;
  v_event2 INT;
  v_event3 INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025';
  SELECT id_organizer INTO v_org FROM tbl_organizer LIMIT 1;

  -- Event 1: with 2 domestic tournaments, has invitation URL
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, txt_location,
    dt_start, dt_end, enum_status, txt_country, url_invitation)
  VALUES ('CAL-TEST-1', 'Calendar Test Event 1', v_season, v_org, 'Warszawa',
    '2024-11-15', '2024-11-16', 'COMPLETED', 'POL', 'https://example.com/invite1.pdf')
  RETURNING id_event INTO v_event1;

  INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category)
  VALUES (v_event1, 'CAL-T1-PPW', 'PPW', 'EPEE', 'M', 'V2');
  INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category)
  VALUES (v_event1, 'CAL-T1-MPW', 'MPW', 'EPEE', 'M', 'V2');

  -- Event 2: with 1 international tournament (PEW), later date
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, txt_location,
    dt_start, dt_end, enum_status, txt_country, num_entry_fee)
  VALUES ('CAL-TEST-2', 'Calendar Test Event 2', v_season, v_org, 'Kraków',
    '2025-01-20', '2025-01-21', 'SCHEDULED', 'POL', 75.00)
  RETURNING id_event INTO v_event2;

  INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category)
  VALUES (v_event2, 'CAL-T2-PEW', 'PEW', 'EPEE', 'M', 'V2');

  -- Event 3: no tournaments (0 count test)
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, txt_location,
    dt_start, enum_status)
  VALUES ('CAL-TEST-3', 'Calendar Test Event 3 (empty)', v_season, v_org, 'Gdańsk',
    '2024-10-01', 'PLANNED')
  RETURNING id_event INTO v_event3;
END;
$setup$;

-- 8.11 — vw_calendar view exists
SELECT has_view('public', 'vw_calendar',
  '8.11: vw_calendar view exists');

-- 8.12 — Returns events ordered by dt_start ASC
SELECT ok(
  (SELECT bool_and(ordered) FROM (
    SELECT dt_start >= LAG(dt_start) OVER (ORDER BY (SELECT NULL)) AS ordered
    FROM vw_calendar
    WHERE txt_code LIKE 'CAL-TEST-%'
  ) sub WHERE ordered IS NOT NULL),
  '8.12: Events ordered by dt_start ASC'
);

-- 8.13 — num_tournaments correctly counts child tournaments
SELECT is(
  (SELECT num_tournaments FROM vw_calendar WHERE txt_code = 'CAL-TEST-1')::INT,
  2,
  '8.13: CAL-TEST-1 has num_tournaments = 2'
);

-- 8.14 — Includes 4 new columns
SELECT ok(
  (SELECT txt_country = 'POL' AND url_invitation = 'https://example.com/invite1.pdf'
   FROM vw_calendar WHERE txt_code = 'CAL-TEST-1'),
  '8.14: vw_calendar includes new columns (txt_country, url_invitation)'
);

-- 8.15 — Accessible to anon role
SELECT lives_ok(
  $$ SET ROLE anon; SELECT * FROM vw_calendar LIMIT 1; RESET ROLE; $$,
  '8.15: vw_calendar accessible to anon role'
);

-- 8.16 — Events with 0 tournaments show num_tournaments = 0
SELECT is(
  (SELECT num_tournaments FROM vw_calendar WHERE txt_code = 'CAL-TEST-3')::INT,
  0,
  '8.16: CAL-TEST-3 has num_tournaments = 0'
);

-- 8.17 — bool_has_international TRUE when event has PEW/MEW/MSW/PSW tournaments
SELECT ok(
  (SELECT bool_has_international FROM vw_calendar WHERE txt_code = 'CAL-TEST-2') = TRUE
  AND (SELECT bool_has_international FROM vw_calendar WHERE txt_code = 'CAL-TEST-1') = FALSE,
  '8.17: bool_has_international correct for domestic vs international events'
);

-- 8.18 — tbl_event has url_registration and dt_registration_deadline columns
SELECT ok(
  (SELECT COUNT(*)::INT = 2 FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'tbl_event'
     AND column_name IN ('url_registration', 'dt_registration_deadline')),
  '8.18: tbl_event has url_registration and dt_registration_deadline columns'
);

-- 8.19 — vw_calendar includes url_registration and dt_registration_deadline
SELECT ok(
  (SELECT COUNT(*)::INT = 2 FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'vw_calendar'
     AND column_name IN ('url_registration', 'dt_registration_deadline')),
  '8.19: vw_calendar includes url_registration and dt_registration_deadline columns'
);

-- 8.20 — fn_create_event and fn_update_event accept registration params and persist them
DO $t820$
DECLARE
  v_season INT;
  v_org INT;
  v_eid INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025';
  SELECT id_organizer INTO v_org FROM tbl_organizer LIMIT 1;

  -- Create event with registration fields
  v_eid := fn_create_event(
    'CAL-REG-TEST', 'Registration Test Event', v_season, v_org,
    'Poznań', '2025-03-01'::DATE, '2025-03-02'::DATE, NULL,
    'POL', NULL, NULL, NULL::NUMERIC, NULL, NULL::enum_weapon_type[],
    'https://example.com/register', '2025-02-20'::DATE
  );

  -- Verify create persisted
  IF NOT (SELECT url_registration = 'https://example.com/register'
            AND dt_registration_deadline = '2025-02-20'
          FROM tbl_event WHERE id_event = v_eid) THEN
    RAISE EXCEPTION 'fn_create_event did not persist registration fields';
  END IF;

  -- Update registration fields
  PERFORM fn_update_event(
    v_eid, 'Registration Test Event', 'Poznań', '2025-03-01'::DATE, '2025-03-02'::DATE,
    NULL, 'POL', NULL, NULL, NULL::NUMERIC, NULL, NULL, NULL::enum_weapon_type[],
    'https://example.com/register2', '2025-02-25'::DATE
  );

  -- Verify update persisted
  IF NOT (SELECT url_registration = 'https://example.com/register2'
            AND dt_registration_deadline = '2025-02-25'
          FROM tbl_event WHERE id_event = v_eid) THEN
    RAISE EXCEPTION 'fn_update_event did not persist registration fields';
  END IF;

  -- Verify vw_calendar returns the fields
  IF NOT (SELECT url_registration = 'https://example.com/register2'
            AND dt_registration_deadline = '2025-02-25'
          FROM vw_calendar WHERE txt_code = 'CAL-REG-TEST') THEN
    RAISE EXCEPTION 'vw_calendar does not return registration fields';
  END IF;
END;
$t820$;
SELECT pass('8.20: fn_create_event and fn_update_event accept registration params and persist them');

SELECT * FROM finish();
ROLLBACK;
