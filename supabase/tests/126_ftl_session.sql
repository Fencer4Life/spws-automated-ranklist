-- =============================================================================
-- pgTAP — FTL.SESSION: one FencingTimeLive session, reused by every run (ADR-120 §2)
-- =============================================================================
-- Verifies migration 20261104000002_ftl_session.sql. FTL's session cookie is
-- valid a fixed 10 days from its sign-in. The pipeline stores it right after
-- the sign-in and every later run, CI or LOCAL, loads it instead of signing in.
-- One row; a newer sign-in replaces it; a run whose cookie bounced drops it only
-- if it is still the one stored. The cookie is a credential: service_role only.
-- Everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(12);

-- The one row (id_session = 1) a real run may have stored: cleared for the test.
DELETE FROM tbl_ftl_session WHERE id_session = 1;

-- 126.1 — service_role only (ADR-083)
SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE relname = 'tbl_ftl_session'),
  '126.1a — RLS is on'
);
SELECT ok(
  NOT has_table_privilege('anon', 'tbl_ftl_session', 'SELECT')
  AND NOT has_table_privilege('authenticated', 'tbl_ftl_session', 'SELECT'),
  '126.1b — anon and authenticated cannot read the session'
);
SELECT ok(
  NOT has_function_privilege('anon', 'fn_ftl_session_get()', 'EXECUTE')
  AND NOT has_function_privilege('authenticated', 'fn_ftl_session_get()', 'EXECUTE')
  AND NOT has_function_privilege('anon', 'fn_ftl_session_put(text, timestamptz)', 'EXECUTE')
  AND NOT has_function_privilege('authenticated', 'fn_ftl_session_put(text, timestamptz)', 'EXECUTE')
  AND NOT has_function_privilege('anon', 'fn_ftl_session_drop(text)', 'EXECUTE')
  AND NOT has_function_privilege('authenticated', 'fn_ftl_session_drop(text)', 'EXECUTE'),
  '126.1c — anon and authenticated cannot get, put or drop it'
);

-- 126.2 — no session stored: none is returned
SELECT is(fn_ftl_session_get(), NULL, '126.2 — with nothing stored, get returns NULL');

-- 126.3 — a stored session is returned with its expiry
SELECT is(
  fn_ftl_session_put('cookie-one', now() + interval '10 days') ->> 'stored',
  'true',
  '126.3a — put stores the session'
);
SELECT is(fn_ftl_session_get() ->> 'cookie', 'cookie-one', '126.3b — get returns its cookie');
SELECT is(
  (fn_ftl_session_get() ->> 'expires_at')::timestamptz,
  now() + interval '10 days',
  '126.3c — and its expiry'
);

-- 126.4 — a newer sign-in replaces it: one row
SELECT fn_ftl_session_put('cookie-two', now() + interval '10 days 1 hour');
SELECT is(
  (SELECT count(*)::int FROM tbl_ftl_session),
  1,
  '126.4a — one session is kept'
);
SELECT is(fn_ftl_session_get() ->> 'cookie', 'cookie-two', '126.4b — the newer one');

-- 126.5 — a run drops only the session it used
SELECT is(
  fn_ftl_session_drop('cookie-one'),
  '{"dropped": false}'::jsonb,
  '126.5a — a run whose older cookie bounced leaves the newer session alone'
);
SELECT is(
  fn_ftl_session_drop('cookie-two'),
  '{"dropped": true}'::jsonb,
  '126.5b — the run that used the stored cookie drops it'
);

-- 126.6 — only a usable session is stored
SELECT throws_ok(
  $$SELECT fn_ftl_session_put('', now() + interval '1 day')$$,
  'P0001',
  'FTL_SESSION: a session is stored with its cookie and an expiry in the future',
  '126.6 — an empty cookie is refused'
);

SELECT * FROM finish();
ROLLBACK;
