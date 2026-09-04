-- =============================================================================
-- pgTAP — the calendar view carries the organizer's code, and it is the truth
-- =============================================================================
-- Verifies migration 20260904000002_calendar_organizer_code.sql.
--
-- The card picked an organizer logo by guessing from the event code's prefix.
-- That guess disagrees with tbl_event in two of the ten families in use:
-- DMEW (EVF, guessed SPWS) and IMEW (EVF, guessed FIE). 72.3 pins the pairs so
-- a future code family cannot quietly reintroduce the drift.
--
-- Plan-test-ID 72.
-- =============================================================================

BEGIN;

SELECT plan(5);

SELECT has_column('vw_calendar', 'txt_organizer_code',
  '72.1 — vw_calendar exposes the organizer code');

SELECT has_column('vw_calendar', 'txt_organizer_name',
  '72.2 — and still exposes the display name it always did');

-- The two families the prefix heuristic got wrong, asserted as data.
SELECT is(
  (SELECT DISTINCT txt_organizer_code FROM vw_calendar WHERE txt_code LIKE 'DMEW%'),
  'EVF',
  '72.3 — DMEW is EVF''s European TEAM championship, not an SPWS event'
);

SELECT is(
  (SELECT DISTINCT txt_organizer_code FROM vw_calendar WHERE txt_code LIKE 'IMEW%'),
  'EVF',
  '72.4 — IMEW is EVF''s individual European championship, not FIE''s'
);

-- Every row must resolve to one of the four registries the card has a mark for;
-- a fifth would render no logo at all.
SELECT is(
  (SELECT COUNT(*)::INT FROM vw_calendar
    WHERE txt_organizer_code IS NOT NULL
      AND txt_organizer_code NOT IN ('SPWS', 'EVF', 'FIE', 'PZSz')),
  0,
  '72.5 — every event resolves to a registry the card can draw'
);

SELECT * FROM finish();

ROLLBACK;
