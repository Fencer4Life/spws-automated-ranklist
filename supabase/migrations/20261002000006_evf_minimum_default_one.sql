-- =============================================================================
-- A new season's EVF minimum defaults to 1 (CFG.EVFMIN, ADR-066 amendment)
-- =============================================================================
-- EVF ranks every category of its events, however small, a single fencer
-- included, and the association scores an EVF event by EVF's rules
-- (decision of 2026-10-02). The EVF minimum (int_min_participants_evf: PEW,
-- MEW, MSW) therefore defaults to 1, as the domestic minimum already does.
-- Existing seasons are revised through fn_revise_and_rescore_season (ADR-097),
-- not here: a migration runs before the seed on a fresh bootstrap. The value
-- stays a per-season setting.
-- =============================================================================

-- lock_timeout matches the 20250301000002_rls_policies.sql convention.
SET LOCAL lock_timeout = '2s';
ALTER TABLE tbl_scoring_config ALTER COLUMN int_min_participants_evf SET DEFAULT 1;
