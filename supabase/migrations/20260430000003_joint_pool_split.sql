-- ---------------------------------------------------------------------------
-- ADR-049 (2026-04-30): bool_joint_pool_split on tbl_tournament
--
-- A combined-pool tournament physically runs N V-cat fencers in one shared
-- pool but is RANKED per V-cat. The ingester creates one tbl_tournament row
-- per V-cat present in the pool, sets bool_joint_pool_split = TRUE on each,
-- and writes the same url_results on every sibling.
--
-- Siblings are identified by:
--   same (id_event, enum_weapon, enum_gender)
--   same url_results
--   bool_joint_pool_split = TRUE
--
-- int_participant_count on each sibling = full physical pool size
-- (sum of tbl_result rows across all siblings).
-- ---------------------------------------------------------------------------

ALTER TABLE tbl_tournament
  ADD COLUMN bool_joint_pool_split BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN tbl_tournament.bool_joint_pool_split IS
  'TRUE = this row is one V-cat slice of a physically combined pool. '
  'Siblings share (id_event, enum_weapon, enum_gender) + url_results. '
  'int_participant_count on each sibling = full physical pool size.';

CREATE INDEX idx_tbl_tournament_joint_split
  ON tbl_tournament (id_event, enum_weapon, enum_gender)
  WHERE bool_joint_pool_split = TRUE;
