-- =============================================================================
-- Phase 3a — Schema extensions: flip default carry-over engine
-- =============================================================================
-- ADR-045: as Phase 1B + Phase 2 have shipped, FK-based carry-over (FK engine)
-- is now safe to use as the greenfield default. Existing rows are not touched
-- (admin opts each one in via the ScoringConfigEditor engine dropdown).
-- =============================================================================

ALTER TABLE tbl_season
  ALTER COLUMN enum_carryover_engine
    SET DEFAULT 'EVENT_FK_MATCHING'::enum_event_carryover_engine;
