-- =============================================================================
-- pgTAP — EVENT.PAST: no open event outside the active season
-- =============================================================================
-- The user's rule of 4 Nov 2026 (closing plan rev 5, N2): an event that is not
-- closed (COMPLETED, SCORED or CANCELLED) is permitted only in the active
-- season. A season is past once its end date has passed; a future season's
-- PLANNED events stay as they are (N3 A). The daily close completes every open
-- event of a past season each morning (N1); this check fails preflight and CI
-- on any drift in the PROD seed LOCAL is built from. The planted row of 128.2
-- rolls back with the transaction.
-- =============================================================================

BEGIN;

SELECT plan(2);

-- 128.1 — the invariant holds on the seed
SELECT is(
  (SELECT count(*)::int
     FROM tbl_event e
     JOIN tbl_season s ON s.id_season = e.id_season
    WHERE s.dt_end < CURRENT_DATE
      AND e.enum_status NOT IN ('COMPLETED', 'SCORED', 'CANCELLED')),
  0,
  '128.1 — every event of a past season is COMPLETED, SCORED or CANCELLED'
);

-- 128.2 — the check bites: an open event planted in the oldest past season is counted
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, dt_end)
SELECT 'ZZZ-PGTAP-128', 'pgTAP 128: a planted open event of a past season',
       s.id_season, (SELECT min(id_organizer) FROM tbl_organizer), 'PLANNED', s.dt_start, s.dt_start
  FROM tbl_season s
 WHERE s.dt_end < CURRENT_DATE
 ORDER BY s.dt_end
 LIMIT 1;

SELECT is(
  (SELECT count(*)::int
     FROM tbl_event e
     JOIN tbl_season s ON s.id_season = e.id_season
    WHERE s.dt_end < CURRENT_DATE
      AND e.enum_status NOT IN ('COMPLETED', 'SCORED', 'CANCELLED')),
  1,
  '128.2 — an open event of a past season is counted (rolled back)'
);

SELECT * FROM finish();

ROLLBACK;
