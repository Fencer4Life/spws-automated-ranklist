-- =============================================================================
-- Intake Rules: Tournament-type-based fencer intake
-- =============================================================================
-- PPW/MPW (domestic): all results always enter the ranklist.
--   If fencer is unknown → auto-create in tbl_fencer with estimated birth year.
-- PEW/MEW (international): only import results for fencers already in master data.
--   Unknown international fencers are skipped entirely.
--
-- This migration adds a flag to distinguish real vs estimated birth years.
-- =============================================================================

ALTER TABLE tbl_fencer
  ADD COLUMN bool_birth_year_estimated BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN tbl_fencer.bool_birth_year_estimated IS
  'TRUE when int_birth_year was estimated from tournament age category (youngest boundary). '
  'Admin should verify and correct. Set by auto-create from PPW/MPW unmatched results.';
