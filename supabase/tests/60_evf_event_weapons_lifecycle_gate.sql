-- =============================================================================
-- pgTAP — an EVF event with unknown weapons may not leave PLANNED
-- =============================================================================
-- Verifies migration 20260828000004_evf_event_weapons_lifecycle_gate.sql.
--
-- Context: EVF published "EVF Circuit – Tampere (FIN)" (calendar id 5379) with
-- no weapon categories, which fail-closed the whole season scrape for nine days
-- from 2026-08-19. The scraper now holds such stubs back instead of inventing
-- weapons; this guard is the database-side half, so the rule holds even when
-- the scraper is not the writer.
--
-- The guard reads the txt_code suffix, NOT arr_weapons: arr_weapons DEFAULTs to
-- '{EPEE,FOIL,SABRE}' and 86 of 96 CERT rows sit on that default (60 of them
-- COMPLETED, including epee-only events), so it cannot distinguish "all three"
-- from "nobody set this".
--
-- It is a trigger on UPDATE, not a CHECK: the seed inserts 32+ unsuffixed PEW
-- events already COMPLETED, and migrations run before the seed on LOCAL and CI.
-- 60.6 pins that an already-non-PLANNED historical row is still updatable.
-- =============================================================================

BEGIN;

SELECT plan(7);

-- 60.1 — guard function exists
SELECT has_function(
  'fn_guard_evf_event_weapons_known',
  '60.1 — fn_guard_evf_event_weapons_known() exists'
);

-- 60.2 — trigger is wired BEFORE UPDATE on tbl_event
SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_trigger
     WHERE tgname = 'trg_guard_evf_event_weapons_known'
       AND tgrelid = 'tbl_event'::regclass
       AND NOT tgisinternal
  ),
  '60.2 — trg_guard_evf_event_weapons_known trigger present on tbl_event'
);

-- ----- fixtures -----
DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
BEGIN
  INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
  VALUES ('TEST-SEASON-6000', '2099-01-01', '2099-12-31', FALSE)
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'TEST-SEASON-6000';
  SELECT id_organizer INTO v_org FROM tbl_organizer LIMIT 1;

  -- unsuffixed EVF code: weapons were never established
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('PEW90-6000-6001', 'Unweaponed EVF stub', v_season, v_org, 'PLANNED');

  -- suffixed EVF code: weapons known
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('PEW91es-6000-6001', 'Weaponed EVF event', v_season, v_org, 'PLANNED');

  -- a domestic code legitimately carries no weapon letters
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('PPW90-6000-6001', 'Domestic event', v_season, v_org, 'PLANNED');

  -- a historical row inserted already past PLANNED, as the seed does
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('PEW92-6000-6001', 'Historical unsuffixed', v_season, v_org, 'COMPLETED');
END;
$setup$;

-- 60.3 — the guard refuses the transition out of PLANNED
SELECT throws_ok(
  $$UPDATE tbl_event SET enum_status = 'CREATED'
     WHERE txt_code = 'PEW90-6000-6001'$$,
  'P0001',
  NULL,
  '60.3 — unsuffixed PEW event cannot leave PLANNED'
);

-- 60.4 — a weaponed EVF event advances normally
SELECT lives_ok(
  $$UPDATE tbl_event SET enum_status = 'CREATED'
     WHERE txt_code = 'PEW91es-6000-6001'$$,
  '60.4 — suffixed PEW event advances out of PLANNED'
);

-- 60.5 — domestic codes are out of scope and unaffected
SELECT lives_ok(
  $$UPDATE tbl_event SET enum_status = 'CREATED'
     WHERE txt_code = 'PPW90-6000-6001'$$,
  '60.5 — PPW event is unaffected by the EVF-scoped guard'
);

-- 60.6 — the seed shape survives: an already-non-PLANNED historical row is
--        still updatable, which a CHECK constraint would have forbidden
SELECT lives_ok(
  $$UPDATE tbl_event SET txt_location = 'Guildford'
     WHERE txt_code = 'PEW92-6000-6001'$$,
  '60.6 — historical unsuffixed COMPLETED row remains updatable'
);

-- 60.7 — edits WITHIN PLANNED are untouched, so the scraper''s daily refresh
--        of a held-back event is never blocked
SELECT lives_ok(
  $$UPDATE tbl_event SET txt_location = 'Tampere'
     WHERE txt_code = 'PEW90-6000-6001'$$,
  '60.7 — non-status edits to an unweaponed event still succeed'
);

SELECT * FROM finish();
ROLLBACK;
