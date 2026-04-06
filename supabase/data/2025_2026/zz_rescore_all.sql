-- =========================================================================
-- Post-seed: compute scores for all tournaments with unscored results
-- =========================================================================
-- Seed files export int_place but not num_final_score. This file runs
-- fn_calc_tournament_scores on every tournament that has results but
-- missing scores. Loaded last (zz_ prefix) via config.toml sql_paths glob.
-- =========================================================================

DO $$
DECLARE
  v_tid INT;
BEGIN
  FOR v_tid IN
    SELECT DISTINCT r.id_tournament
    FROM tbl_result r
    WHERE r.num_final_score IS NULL
      AND r.int_place IS NOT NULL
  LOOP
    PERFORM fn_calc_tournament_scores(v_tid);
  END LOOP;
END;
$$;
