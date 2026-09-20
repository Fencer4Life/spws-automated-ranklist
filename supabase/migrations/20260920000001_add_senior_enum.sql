-- =============================================================================
-- Add SENIOR to enum_age_category
-- =============================================================================
-- Design step 6 of doc/plans/versioned-season-scoring-and-pzsz-ranking-design.html
-- §07, doc/plans/pzsz-senior-result-ingestion-2026-09-19.html §04. RTM
-- SS26.TYPE.06e-f.
--
-- SENIOR represents a PZSz PPS/MPS competition's SOURCE bracket -- one
-- undivided senior field a veteran enters alongside much younger fencers.
-- It is a TOURNAMENT-level label only (tbl_tournament.enum_age_category may
-- be SENIOR); a RESULT row's own effective category must always be a real
-- veteran category (V0-V4) or NULL, never SENIOR. The CHECK constraint that
-- enforces that on tbl_result.enum_source_age_category is a SEPARATE later
-- migration (20260920000002), because a new enum value cannot be used --
-- including inside a CHECK constraint's own expression -- in the same
-- transaction that adds it. Same split PPS/MPS's own enum values already
-- needed (20260919000003/20260919000004).
-- =============================================================================

ALTER TYPE enum_age_category ADD VALUE IF NOT EXISTS 'SENIOR';
