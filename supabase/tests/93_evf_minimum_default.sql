-- =============================================================================
-- CFG.EVFMIN — a new season's EVF minimum is 1 (ADR-066 amendment, 2026-10-02)
-- =============================================================================
-- EVF ranks every category of its events, however small, and the association
-- scores an EVF event by EVF's rules, so a season's EVF minimum
-- (int_min_participants_evf: PEW, MEW, MSW) defaults to 1, as the domestic
-- minimum already does. The value stays a per-season setting.
-- =============================================================================

BEGIN;

SELECT plan(1);

SELECT is(
  (SELECT column_default FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'tbl_scoring_config'
      AND column_name = 'int_min_participants_evf'),
  '1',
  'CFG.EVFMIN.01 a new season''s EVF minimum defaults to 1');

SELECT * FROM finish();
ROLLBACK;
