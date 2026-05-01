-- =============================================================================
-- T8.1: tbl_event Schema Extension — Acceptance Tests
-- =============================================================================
-- Tests 8.05–8.10 from doc/archive/m8_implementation_plan.md §T8.1.
-- Verifies the 4 new nullable columns added to tbl_event for calendar display.
-- =============================================================================

BEGIN;
SELECT plan(6);

-- 8.05 — txt_country column exists (TEXT, nullable)
SELECT has_column('public', 'tbl_event', 'txt_country',
  '8.05: tbl_event has txt_country column');

-- 8.06 — txt_venue_address column exists (TEXT, nullable)
SELECT has_column('public', 'tbl_event', 'txt_venue_address',
  '8.06: tbl_event has txt_venue_address column');

-- 8.07 — url_invitation column exists (TEXT, nullable)
SELECT has_column('public', 'tbl_event', 'url_invitation',
  '8.07: tbl_event has url_invitation column');

-- 8.08 — num_entry_fee column exists (NUMERIC, nullable)
SELECT has_column('public', 'tbl_event', 'num_entry_fee',
  '8.08: tbl_event has num_entry_fee column');

-- 8.09 — Existing tbl_event rows unaffected after migration
-- After db reset + seed, existing events should still have their data intact.
-- We check that at least one event exists and its existing columns are non-null.
SELECT ok(
  (SELECT COUNT(*) FROM tbl_event WHERE txt_code IS NOT NULL) > 0,
  '8.09: Existing tbl_event rows have intact txt_code after migration'
);

-- 8.10 — INSERT with all 4 new columns populated succeeds
DO $test_insert$
DECLARE
  v_season INT;
  v_org INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season LIMIT 1;
  SELECT id_organizer INTO v_org FROM tbl_organizer LIMIT 1;
  INSERT INTO tbl_event (
    txt_code, txt_name, id_season, id_organizer,
    txt_country, txt_venue_address, url_invitation, num_entry_fee
  ) VALUES (
    'TEST-SCHEMA-EXT', 'Schema Extension Test Event', v_season, v_org,
    'POL', 'ul. Sportowa 1, Warszawa', 'https://example.com/invitation.pdf', 50.00
  );
END;
$test_insert$;
SELECT pass('8.10: INSERT with all 4 new columns populated succeeds');

SELECT * FROM finish();
ROLLBACK;
