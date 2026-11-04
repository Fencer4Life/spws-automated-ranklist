-- =============================================================================
-- pgTAP — FTL.LEDGER: the day's FencingTimeLive allowance (ADR-120 §1)
-- =============================================================================
-- Verifies migration 20261104000001_ftl_read_ledger.sql. Every FTL request and
-- sign-in of the pipeline is drawn from one row per day before it is sent; a
-- draw is granted up to the cap the caller names, a sign-in all or nothing,
-- and what a run did not use is given back. Rows older than 90 days are pruned
-- by the next draw. The ledger is service_role only. Far-future days keep the
-- test clear of real rows; everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(14);

-- 125.1 — service_role only (ADR-083)
SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE relname = 'tbl_ftl_read_ledger'),
  '125.1a — RLS is on'
);
SELECT ok(
  NOT has_table_privilege('anon', 'tbl_ftl_read_ledger', 'SELECT')
  AND NOT has_table_privilege('authenticated', 'tbl_ftl_read_ledger', 'SELECT'),
  '125.1b — anon and authenticated cannot read the ledger'
);
SELECT ok(
  NOT has_function_privilege('anon', 'fn_ftl_ledger_take(date, integer, integer, integer, integer)', 'EXECUTE')
  AND NOT has_function_privilege('authenticated', 'fn_ftl_ledger_take(date, integer, integer, integer, integer)', 'EXECUTE')
  AND NOT has_function_privilege('anon', 'fn_ftl_ledger_give_back(date, integer)', 'EXECUTE')
  AND NOT has_function_privilege('authenticated', 'fn_ftl_ledger_give_back(date, integer)', 'EXECUTE'),
  '125.1c — anon and authenticated cannot draw or give back'
);

-- 125.2 — the first draw of a day is granted whole
SELECT is(
  fn_ftl_ledger_take(DATE '2087-11-14', 10, 0, 120, 2),
  '{"requests": 10, "sign_ins": 0, "used_requests": 10, "used_sign_ins": 0, "cap_requests": 120, "cap_sign_ins": 2}'::jsonb,
  '125.2 — a draw of 10 on a fresh day grants 10'
);

-- 125.3 — a draw near the cap is granted up to it
UPDATE tbl_ftl_read_ledger SET int_requests = 115 WHERE dt_day = DATE '2087-11-14';
SELECT is(
  fn_ftl_ledger_take(DATE '2087-11-14', 10, 0, 120, 2),
  '{"requests": 5, "sign_ins": 0, "used_requests": 120, "used_sign_ins": 0, "cap_requests": 120, "cap_sign_ins": 2}'::jsonb,
  '125.3 — at 115 of 120, a draw of 10 grants 5'
);

-- 125.4 — at the cap nothing is granted, and nothing is counted
SELECT is(
  fn_ftl_ledger_take(DATE '2087-11-14', 10, 0, 120, 2),
  '{"requests": 0, "sign_ins": 0, "used_requests": 120, "used_sign_ins": 0, "cap_requests": 120, "cap_sign_ins": 2}'::jsonb,
  '125.4 — at the cap a draw grants 0'
);

-- 125.5 — a sign-in is granted whole or not at all
SELECT is(
  fn_ftl_ledger_take(DATE '2087-11-14', 0, 1, 120, 2) ->> 'sign_ins',
  '1',
  '125.5a — the first sign-in of the day is granted, even with the requests spent'
);
UPDATE tbl_ftl_read_ledger SET int_sign_ins = 2 WHERE dt_day = DATE '2087-11-14';
SELECT is(
  fn_ftl_ledger_take(DATE '2087-11-14', 0, 1, 120, 2),
  '{"requests": 0, "sign_ins": 0, "used_requests": 120, "used_sign_ins": 2, "cap_requests": 120, "cap_sign_ins": 2}'::jsonb,
  '125.5b — at 2 of 2 sign-ins a third is refused'
);

-- 125.6 — what a run did not use is given back, never below zero
SELECT is(
  fn_ftl_ledger_give_back(DATE '2087-11-14', 7) ->> 'used_requests',
  '113',
  '125.6a — giving back 7 of 120 leaves 113'
);
SELECT is(
  fn_ftl_ledger_give_back(DATE '2087-11-14', 500) ->> 'used_requests',
  '0',
  '125.6b — giving back more than was used leaves 0'
);

-- 125.7 — a new day starts at zero
SELECT is(
  fn_ftl_ledger_take(DATE '2087-11-15', 10, 1, 120, 2),
  '{"requests": 10, "sign_ins": 1, "used_requests": 10, "used_sign_ins": 1, "cap_requests": 120, "cap_sign_ins": 2}'::jsonb,
  '125.7 — the next day''s first draw is granted whole'
);

-- 125.8 — rows older than 90 days are pruned by the next draw
INSERT INTO tbl_ftl_read_ledger (dt_day, int_requests, int_sign_ins)
VALUES (current_date - 91, 40, 1);
SELECT is(
  (fn_ftl_ledger_take(DATE '2087-11-16', 1, 0, 120, 2) ->> 'requests')::int,
  1,
  '125.8a — a draw after the old row was written'
);
SELECT is(
  (SELECT count(*)::int FROM tbl_ftl_read_ledger WHERE dt_day < current_date - 90),
  0,
  '125.8b — the row older than 90 days is gone'
);

-- 125.9 — a draw names what it wants and the cap it obeys
SELECT throws_ok(
  $$SELECT fn_ftl_ledger_take(DATE '2087-11-16', -1, 0, 120, 2)$$,
  'P0001',
  'FTL_LEDGER: a draw takes no negative or missing amounts, and names its caps',
  '125.9 — a negative draw is refused'
);

SELECT * FROM finish();
ROLLBACK;
