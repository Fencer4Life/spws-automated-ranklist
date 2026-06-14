-- =============================================================================
-- ADR-049 DATA FIX (2026-06-13) — apply per-V-cat joint-pool counts to PPW3/4/5
-- =============================================================================
-- The 2026-06-04 amendment (migration 20260604000001) redefined the recompute
-- FUNCTIONS to per-V-cat, but changed no committed data. PPW3/4/5-2025-2026
-- therefore still held the OLD SUMMED joint-pool int_participant_count (each
-- V-cat sibling carrying the full physical pool size instead of its own slice).
--
-- This is a "class-A" correction: count-only inflation, membership unchanged.
-- For every joint-pool tournament under PPW3/4/5-2025-2026 we set
-- int_participant_count to the tournament's OWN result-row count, then re-score
-- the affected events (participant count N feeds fn_calc_tournament_scores).
--
-- Scope + safety:
--   * Restricted to PPW3/4/5-2025-2026 by event code — international events
--     (ADR-038 full-field counts) and historical/other joint pools are NOT
--     touched (running the GLOBAL fn_backfill_joint_pool_split would wrongly
--     collapse international N; see ADR-038 / ADR-056).
--   * Idempotent: re-running changes nothing once counts == own-row counts.
--   * On LOCAL `supabase db reset` this runs BEFORE the seed (empty tables) and
--     is a no-op; LOCAL gets the corrected data from seed_prod_2026-06-13.sql.
--     On CERT/PROD (no reseed) release.yml applies it to the live inflated data.
-- =============================================================================

-- Statement 1 — correct the inflated joint-pool counts (class-A only; class-B
-- brackets have no count mismatch so are left untouched for manual identity work).
UPDATE tbl_tournament t
   SET int_participant_count =
         (SELECT count(*) FROM tbl_result r WHERE r.id_tournament = t.id_tournament)
  FROM tbl_event e
 WHERE t.id_event = e.id_event
   AND e.txt_code IN ('PPW3-2025-2026', 'PPW4-2025-2026', 'PPW5-2025-2026')
   AND t.bool_joint_pool_split
   AND t.int_participant_count IS DISTINCT FROM
         (SELECT count(*) FROM tbl_result r WHERE r.id_tournament = t.id_tournament);

-- Statement 2 — re-score every joint-pool tournament in those events so result
-- points reflect the corrected N. Reads the now-updated int_participant_count.
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT t.id_tournament
      FROM tbl_tournament t
      JOIN tbl_event e ON e.id_event = t.id_event
     WHERE e.txt_code IN ('PPW3-2025-2026', 'PPW4-2025-2026', 'PPW5-2025-2026')
       AND t.bool_joint_pool_split
  LOOP
    PERFORM fn_calc_tournament_scores(r.id_tournament);
  END LOOP;
END $$;
