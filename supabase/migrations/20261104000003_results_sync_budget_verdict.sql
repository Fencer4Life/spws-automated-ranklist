-- =============================================================================
-- ADR-120 §3: the results sync's verdict "budget"
-- =============================================================================
-- When FTL's daily allowance is spent (ADR-120 §1), a cycle of an FTL event
-- reads and writes nothing and pauses nothing: the next day's allowance reads
-- the event. Its verdict "budget" is recorded on the event's row like every
-- other verdict, so the CHECK on txt_last_verdict takes it.
--
-- Plan: doc/plans/ftl-daily-read-budget-2026-11-04.html (S1, S4).
-- Tests: supabase/tests/127_results_sync_budget_verdict.sql (SYNC.BUDGET),
--        python/tests/test_results_sync.py (SYNC.PAUSE.01 reads this CHECK).
-- =============================================================================

-- The file runs as one transaction (scripts/apply-migrations.sh sends it as one
-- query), so SET LOCAL holds for all of it and ends with it. The table holds a
-- row per event the sync has seen (tens), so the brief exclusive lock of one
-- ALTER is negligible; a blocked deploy fails fast instead of waiting.
SET LOCAL lock_timeout = '2s';

ALTER TABLE tbl_results_sync_event
  DROP CONSTRAINT IF EXISTS ck_results_sync_last_verdict,
  ADD CONSTRAINT ck_results_sync_last_verdict
    CHECK (txt_last_verdict IN ('unchanged', 'promoted', 'nothing_final', 'failed',
                                'blocked', 'refused', 'stopped', 'budget'));
