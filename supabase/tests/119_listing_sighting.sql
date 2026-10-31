-- =============================================================================
-- pgTAP — FINAL.05: the sightings store (ADR-119 §1, D2 B)
-- =============================================================================
-- Verifies migration 20261031000003_listing_sighting.sql. A results engine
-- without a finished signal (4fence, Ophardt, d'Artagnan, EVF's results API, a
-- lone results page) has each bracket's content recorded the first time the
-- CERT ingest sees it; the bracket is taken once that content is 60 minutes
-- old. The store is service_role only, keeps the first sighting of each
-- (event, bracket, content) and never deletes one. It holds bracket keys and
-- content hashes, never a person.
-- =============================================================================

BEGIN;

SELECT plan(12);

-- 119.1 — service_role only (ADR-083)
SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE relname = 'tbl_listing_sighting'),
  '119.1a — RLS is on'
);
SELECT ok(
  NOT has_table_privilege('anon', 'tbl_listing_sighting', 'SELECT')
  AND NOT has_table_privilege('authenticated', 'tbl_listing_sighting', 'SELECT'),
  '119.1b — anon and authenticated cannot read a sighting'
);
SELECT ok(
  NOT has_function_privilege('anon', 'fn_listing_sighting_record(text, text, text)', 'EXECUTE')
  AND NOT has_function_privilege('authenticated', 'fn_listing_sighting_record(text, text, text)', 'EXECUTE'),
  '119.1c — anon and authenticated cannot record a sighting'
);
SELECT ok(
  has_function_privilege('service_role', 'fn_listing_sighting_record(text, text, text)', 'EXECUTE'),
  '119.1d — service_role records sightings'
);

-- 119.2 — a sighting is never deleted
SELECT ok(
  NOT has_table_privilege('service_role', 'tbl_listing_sighting', 'DELETE'),
  '119.2a — service_role cannot delete a sighting'
);
SELECT ok(
  has_table_privilege('service_role', 'tbl_listing_sighting', 'SELECT'),
  '119.2b — service_role reads sightings'
);

-- 119.3 — the first sighting is kept, the last one moves
SELECT is(
  fn_listing_sighting_record('TEST1-2026-2027', 'https://o/1', repeat('a', 64)),
  now(),
  '119.3a — a first sighting is now'
);
UPDATE tbl_listing_sighting SET ts_first_seen = now() - INTERVAL '75 minutes',
                                ts_last_seen  = now() - INTERVAL '75 minutes'
 WHERE txt_event_code = 'TEST1-2026-2027';
SELECT is(
  fn_listing_sighting_record('TEST1-2026-2027', 'https://o/1', repeat('a', 64)),
  now() - INTERVAL '75 minutes',
  '119.3b — the same content again answers its first sighting'
);
SELECT is(
  (SELECT ts_last_seen FROM tbl_listing_sighting
    WHERE txt_event_code = 'TEST1-2026-2027' AND txt_sha256 = repeat('a', 64)),
  now(),
  '119.3c — and moves its last sighting to now'
);
SELECT is(
  fn_listing_sighting_record('TEST1-2026-2027', 'https://o/1', repeat('b', 64)),
  now(),
  '119.3d — changed content is a new first sighting'
);
SELECT is(
  (SELECT count(*)::INT FROM tbl_listing_sighting WHERE txt_event_code = 'TEST1-2026-2027'),
  2,
  '119.3e — one row per event, bracket and content'
);

-- 119.4 — the content is a SHA-256
SELECT throws_ok(
  $$SELECT fn_listing_sighting_record('TEST1-2026-2027', 'https://o/1', 'not-a-hash')$$,
  '23514',
  NULL,
  '119.4 — a content hash that is not 64 hex digits is refused'
);

SELECT * FROM finish();
ROLLBACK;
