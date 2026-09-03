-- =============================================================================
-- pgTAP — PZSz as a fourth organizer, and the PZSz event id on tbl_event
-- =============================================================================
-- Verifies migration 20260903000001_pzsz_organizer_and_event_id.sql.
--
-- Polish veterans also enter senior national competitions run by Polski Zwiazek
-- Szermierczy (PZSz). The calendar carried SPWS, EVF and FIE events and nothing
-- from PZSz, so those outings were invisible. A fourth organizer row makes them
-- storable.
--
-- Two properties matter more than the row itself.
--
-- IDEMPOTENCE. tbl_organizer rows live in the PROD seed dumps, not in any
-- migration. Migrations run BEFORE the seed dump on CI and on `db reset`, so
-- this insert has to survive the seed re-inserting the other three codes, and
-- has to survive being replayed. ON CONFLICT (txt_code) DO NOTHING, backed by
-- idx_organizer_code, is what makes both true.
--
-- ORDERING. python/pipeline/promote.py resolves id_organizer to PROD by code
-- and raises when the code is unresolved (ADR-081), so PZSz must exist on CERT
-- and on PROD before the first calendar promote runs. That is why this ships as
-- its own migration ahead of the scraper rather than alongside it.
--
-- id_pzsz_event is the stable identity for the fill-when-available enrichment
-- pass: PZSz event names drift in casing and carry live typos, so a name-based
-- match would create duplicates on a rename. The uniqueness is per season, not
-- global, mirroring idx_tbl_event_evf_calendar_season.
--
-- Plan-test-ID 70 (supabase/tests/70_pzsz_organizer_and_event_id.sql).
-- =============================================================================

BEGIN;

SELECT plan(11);

-- ----- 70.1-70.3 the organizer row -------------------------------------------
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_organizer WHERE txt_code = 'PZSz'),
  1,
  '70.1 — exactly one PZSz organizer row exists'
);

SELECT is(
  (SELECT txt_name FROM tbl_organizer WHERE txt_code = 'PZSz'),
  'Polski Związek Szermierczy',
  '70.2 — the name stays Polish, as the sibling SPWS row already is'
);

-- Replaying the migration's own statement must not add a second row. This is
-- the CI ordering property stated in words: migrations, then the seed.
INSERT INTO tbl_organizer (txt_code, txt_name)
VALUES ('PZSz', 'Polski Związek Szermierczy')
ON CONFLICT (txt_code) DO NOTHING;

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_organizer WHERE txt_code = 'PZSz'),
  1,
  '70.3 — re-running the insert is a no-op, so the seed cannot duplicate it'
);

-- ----- 70.4-70.5 the column ---------------------------------------------------
SELECT has_column('tbl_event', 'id_pzsz_event',
  '70.4 — tbl_event.id_pzsz_event exists');

SELECT col_type_is('tbl_event', 'id_pzsz_event', 'integer',
  '70.5 — id_pzsz_event is INTEGER: PZSz ids are four digits, not a bigint');

-- ----- 70.6-70.9 identity: unique per season, NULL for everyone else ----------
DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
BEGIN
  INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
  VALUES ('PZSZ70-A', '2126-07-01', '2127-06-30', FALSE)
  RETURNING id_season INTO v_season;

  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'PZSz';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer,
                         txt_location, dt_start, dt_end, id_pzsz_event)
  VALUES ('PZSZ70A', 'PPS1s', v_season, v_org,
          'Poznań', '2126-10-03', '2126-10-03', 4588);
END $setup$;

SELECT is(
  (SELECT id_pzsz_event FROM tbl_event WHERE txt_code = 'PZSZ70A'),
  4588,
  '70.6 — a PZSz event carries its source id'
);

SELECT throws_ok(
  $$INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer,
                           dt_start, dt_end, id_pzsz_event)
    VALUES ('PZSZ70DUP', 'PPS1s again',
            (SELECT id_season FROM tbl_season WHERE txt_code = 'PZSZ70-A'),
            (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'PZSz'),
            '2126-10-03', '2126-10-03', 4588)$$,
  '23505',
  NULL,
  '70.7 — the same PZSz id twice in one season is refused, not silently doubled'
);

-- The same source id in a DIFFERENT season is allowed: uniqueness is per
-- season, exactly as idx_tbl_event_evf_calendar_season already is.
DO $othersesason$
DECLARE
  v_season INT;
BEGIN
  INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
  VALUES ('PZSZ70-B', '2127-07-01', '2128-06-30', FALSE)
  RETURNING id_season INTO v_season;

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer,
                         dt_start, dt_end, id_pzsz_event)
  VALUES ('PZSZ70B', 'PPS1s next season', v_season,
          (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'PZSz'),
          '2127-10-03', '2127-10-03', 4588);
END $othersesason$;

-- Scoped to this test's own seasons on purpose. A bare
-- `WHERE id_pzsz_event = 4588` also counts whatever the real scraper has
-- written to this database, so it passes on an empty LOCAL and fails the moment
-- someone runs the sync -- which is exactly what happened on 2026-09-03.
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event e
     JOIN tbl_season s ON s.id_season = e.id_season
    WHERE e.id_pzsz_event = 4588 AND s.txt_code IN ('PZSZ70-A', 'PZSZ70-B')),
  2,
  '70.8 — the same source id may recur in another season'
);

-- Every non-PZSz event leaves the column NULL, and the partial index must not
-- treat those NULLs as colliding.
DO $nulls$
DECLARE
  v_season INT;
  v_org    INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'PZSZ70-A';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer,
                         dt_start, dt_end)
  VALUES ('PZSZ70N1', 'not a PZSz event', v_season, v_org,
          '2126-11-01', '2126-11-01'),
         ('PZSZ70N2', 'nor is this one', v_season, v_org,
          '2126-11-08', '2126-11-08');
END $nulls$;

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
    WHERE txt_code IN ('PZSZ70N1', 'PZSZ70N2') AND id_pzsz_event IS NULL),
  2,
  '70.9 — many events may share a NULL source id; the index is partial'
);

-- ----- 70.10-70.11 the organizer is usable, and nothing else moved ------------
SELECT is(
  (SELECT o.txt_code FROM tbl_event e
     JOIN tbl_organizer o ON o.id_organizer = e.id_organizer
    WHERE e.txt_code = 'PZSZ70A'),
  'PZSz',
  '70.10 — an event resolves to the PZSz organizer by code, as promote.py does'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_organizer
    WHERE txt_code IN ('SPWS', 'EVF', 'FIE')),
  3,
  '70.11 — the three existing organizers are untouched'
);

SELECT * FROM finish();

ROLLBACK;
