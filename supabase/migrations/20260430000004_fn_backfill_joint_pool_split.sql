-- ---------------------------------------------------------------------------
-- ADR-049 (2026-04-30): fn_backfill_joint_pool_split()
--
-- One-shot remediation for the PPW4-class bug where joint-pool siblings
-- existed in the DB before bool_joint_pool_split was introduced. Detection
-- signal: two or more tbl_tournament rows under the same
-- (id_event, enum_weapon, enum_gender) sharing the same non-empty
-- url_results.
--
-- For every detected group:
--   1. set bool_joint_pool_split = TRUE on all members,
--   2. set int_participant_count on each member = SUM of tbl_result rows
--      across all members (full physical pool size).
--
-- Idempotent: rows already flagged TRUE with the correct count are skipped
-- by the WHERE clauses on each UPDATE.
--
-- The PPW5-class case (per-V-cat URLs, but a single physical pool) cannot
-- be detected from existing data and is out of scope for this function;
-- it will be handled at ingestion time by the scraper writing
-- bool_joint_pool_split = TRUE directly.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_backfill_joint_pool_split()
RETURNS TABLE (
    groups_detected   INT,
    siblings_flagged  INT,
    counts_rewritten  INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_groups   INT;
    v_flagged  INT;
    v_counts   INT;
BEGIN
    -- Step 1: flip the flag on every row that shares url_results with a
    -- sibling under the same (id_event, enum_weapon, enum_gender).
    UPDATE tbl_tournament t
       SET bool_joint_pool_split = TRUE
      FROM (
        SELECT id_event, enum_weapon, enum_gender, url_results
          FROM tbl_tournament
         WHERE url_results IS NOT NULL
           AND url_results <> ''
         GROUP BY id_event, enum_weapon, enum_gender, url_results
        HAVING COUNT(*) > 1
      ) g
     WHERE t.id_event      = g.id_event
       AND t.enum_weapon   = g.enum_weapon
       AND t.enum_gender   = g.enum_gender
       AND t.url_results   = g.url_results
       AND t.bool_joint_pool_split = FALSE;
    GET DIAGNOSTICS v_flagged = ROW_COUNT;

    -- Step 2: recompute int_participant_count for every joint-pool member
    -- as the total number of tbl_result rows across all siblings of that
    -- pool.
    UPDATE tbl_tournament t
       SET int_participant_count = ps.sz
      FROM (
        SELECT tt.id_event, tt.enum_weapon, tt.enum_gender, tt.url_results,
               COUNT(r.id_result)::INT AS sz
          FROM tbl_tournament tt
          JOIN tbl_result r ON r.id_tournament = tt.id_tournament
         WHERE tt.bool_joint_pool_split = TRUE
         GROUP BY tt.id_event, tt.enum_weapon, tt.enum_gender, tt.url_results
      ) ps
     WHERE t.id_event      = ps.id_event
       AND t.enum_weapon   = ps.enum_weapon
       AND t.enum_gender   = ps.enum_gender
       AND t.url_results   = ps.url_results
       AND t.bool_joint_pool_split = TRUE
       AND t.int_participant_count IS DISTINCT FROM ps.sz;
    GET DIAGNOSTICS v_counts = ROW_COUNT;

    -- Group count = number of distinct joint-pool groups currently flagged.
    SELECT COUNT(*)::INT INTO v_groups
      FROM (
        SELECT 1
          FROM tbl_tournament
         WHERE bool_joint_pool_split = TRUE
         GROUP BY id_event, enum_weapon, enum_gender, url_results
      ) sg;

    RETURN QUERY SELECT v_groups, v_flagged, v_counts;
END;
$$;

COMMENT ON FUNCTION fn_backfill_joint_pool_split() IS
  'ADR-049 backfill. Flags pre-existing PPW4-class joint-pool siblings '
  '(shared url_results under same event/weapon/gender) and rewrites '
  'int_participant_count = full physical pool size on each sibling. '
  'Idempotent.';
