-- =============================================================================
-- EVF_JOINED: the method of a row scored in a joined bracket of 4-15
-- =============================================================================
-- ADR-104 §6. doc/plans/adr-104-joined-engine-implementation-plan-2026-09-30.html
-- step 6.
--
-- On its own because Postgres refuses a new enum value inside the transaction
-- that added it, and 20260930000003_spws_evf_joined_engine.sql names it in a
-- CHECK and in the strategy it creates.
-- =============================================================================

ALTER TYPE enum_score_method ADD VALUE IF NOT EXISTS 'EVF_JOINED';

COMMENT ON TYPE enum_score_method IS
  'The range of an engine that scored a result: TABLE (N <= 3), EVF_CLASSIC, '
  'or EVF_JOINED (every row of a joined bracket of 4-15 under '
  'SPWS_EVF_JOINED_V1_2026_2027, ADR-104). NULL on a result means it has not '
  'been scored yet.';
