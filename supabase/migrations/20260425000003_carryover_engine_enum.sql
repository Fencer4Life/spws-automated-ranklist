-- =============================================================================
-- Migration: enum_event_carryover_engine + tbl_season.enum_carryover_engine
-- =============================================================================
-- Phase 1A — strangler-fig pattern, dispatcher refactor.
--
-- Introduces a per-season flag selecting which carry-over engine the rolling-
-- score functions use. The default 'EVENT_CODE_MATCHING' preserves existing
-- behavior (fn_event_position prefix-string parsing). 'EVENT_FK_MATCHING'
-- (Phase 1B) will drive an FK-based engine using a future tbl_event.id_prior_event
-- column and a vw_eligible_event view.
-- =============================================================================

CREATE TYPE enum_event_carryover_engine AS ENUM (
  'EVENT_CODE_MATCHING',
  'EVENT_FK_MATCHING'
);

ALTER TABLE tbl_season
  ADD COLUMN enum_carryover_engine enum_event_carryover_engine
    NOT NULL DEFAULT 'EVENT_CODE_MATCHING';
