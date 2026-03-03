-- =============================================================================
-- M5: SQL Views & Ranking Function
-- =============================================================================
-- vw_score          — denormalized view for drill-down (UC13)
-- fn_ranking_ppw    — ranking function with best-K + MPW drop logic (UC12)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- vw_score: one row per fencer per tournament with all scoring details
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_score AS
SELECT
  r.id_result,
  r.id_fencer,
  f.txt_surname || ' ' || f.txt_first_name AS fencer_name,
  t.id_tournament,
  t.txt_code   AS txt_tournament_code,
  t.txt_name   AS txt_tournament_name,
  t.dt_tournament,
  t.enum_type,
  t.enum_weapon,
  t.enum_gender,
  t.enum_age_category,
  t.int_participant_count,
  t.num_multiplier,
  r.int_place,
  r.num_place_pts,
  r.num_de_bonus,
  r.num_podium_bonus,
  r.num_final_score,
  r.ts_points_calc,
  s.id_season,
  s.txt_code AS txt_season_code
FROM tbl_result r
JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
JOIN tbl_event e      ON e.id_event = t.id_event
JOIN tbl_season s     ON s.id_season = e.id_season
LEFT JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
WHERE r.id_fencer IS NOT NULL;


-- ---------------------------------------------------------------------------
-- fn_ranking_ppw: domestic ranking with best-K PPW + conditional MPW drop
-- ---------------------------------------------------------------------------
-- p_weapon, p_gender, p_category: required filters
-- p_season: NULL = active season
--
-- Algorithm (§8.3.1):
--   1. Collect all PPW final_scores per fencer, ranked descending
--   2. Select best K (int_ppw_best_count, default 4)
--   3. If MPW exists and MPW >= worst included PPW → include MPW
--   4. If MPW exists and MPW < worst included PPW → drop MPW, use (K+1)th PPW
--   5. Sum selected scores → total
--   6. Rank by total descending
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_ranking_ppw(
  p_weapon   enum_weapon_type,
  p_gender   enum_gender_type,
  p_category enum_age_category,
  p_season   INT DEFAULT NULL
)
RETURNS TABLE (
  rank         INT,
  id_fencer    INT,
  fencer_name  TEXT,
  total_score  NUMERIC
)
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  WITH params AS (
    SELECT
      COALESCE(p_season, (SELECT id_season FROM tbl_season WHERE bool_active LIMIT 1)) AS season_id
  ),
  cfg AS (
    SELECT sc.int_ppw_best_count AS k,
           sc.bool_mpw_droppable
    FROM tbl_scoring_config sc
    JOIN params p ON sc.id_season = p.season_id
  ),
  -- All scored results matching filters, with per-fencer ranking within type
  scored AS (
    SELECT
      r.id_fencer,
      r.num_final_score,
      t.enum_type,
      ROW_NUMBER() OVER (
        PARTITION BY r.id_fencer, t.enum_type
        ORDER BY r.num_final_score DESC
      ) AS rn
    FROM tbl_result r
    JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
    JOIN tbl_event e      ON e.id_event = t.id_event
    CROSS JOIN params p
    WHERE e.id_season = p.season_id
      AND t.enum_weapon = p_weapon
      AND t.enum_gender = p_gender
      AND t.enum_age_category = p_category
      AND r.num_final_score IS NOT NULL
      AND r.id_fencer IS NOT NULL
  ),
  -- Best K PPW scores per fencer
  best_ppw AS (
    SELECT
      s.id_fencer,
      SUM(s.num_final_score) AS ppw_sum,
      MIN(s.num_final_score) AS worst_ppw
    FROM scored s
    CROSS JOIN cfg
    WHERE s.enum_type = 'PPW'
      AND s.rn <= cfg.k
    GROUP BY s.id_fencer
  ),
  -- The (K+1)th PPW score per fencer (replacement when MPW is dropped)
  next_ppw AS (
    SELECT s.id_fencer, s.num_final_score AS next_score
    FROM scored s
    CROSS JOIN cfg
    WHERE s.enum_type = 'PPW'
      AND s.rn = cfg.k + 1
  ),
  -- Best MPW score per fencer (take best if multiple exist)
  best_mpw AS (
    SELECT s.id_fencer, s.num_final_score AS mpw_score
    FROM scored s
    WHERE s.enum_type = 'MPW'
      AND s.rn = 1
  ),
  -- All fencers who have any scored result
  all_fencers AS (
    SELECT DISTINCT id_fencer FROM scored
  ),
  -- Compute total per fencer
  totals AS (
    SELECT
      af.id_fencer,
      COALESCE(bp.ppw_sum, 0) + (
        CASE
          -- No MPW score → nothing to add
          WHEN bm.mpw_score IS NULL THEN 0
          -- MPW not droppable → always include
          WHEN NOT cfg.bool_mpw_droppable THEN bm.mpw_score
          -- No PPW to compare against → include MPW
          WHEN bp.worst_ppw IS NULL THEN bm.mpw_score
          -- MPW >= worst included PPW → include MPW
          WHEN bm.mpw_score >= bp.worst_ppw THEN bm.mpw_score
          -- MPW < worst PPW and replacement available → use replacement
          WHEN np.next_score IS NOT NULL THEN np.next_score
          -- MPW dropped, no replacement → nothing
          ELSE 0
        END
      ) AS total_score
    FROM all_fencers af
    CROSS JOIN cfg
    LEFT JOIN best_ppw bp ON bp.id_fencer = af.id_fencer
    LEFT JOIN best_mpw bm ON bm.id_fencer = af.id_fencer
    LEFT JOIN next_ppw np ON np.id_fencer = af.id_fencer
  )
  SELECT
    ROW_NUMBER() OVER (ORDER BY t.total_score DESC)::INT AS rank,
    t.id_fencer,
    f.txt_surname || ' ' || f.txt_first_name AS fencer_name,
    t.total_score
  FROM totals t
  JOIN tbl_fencer f ON f.id_fencer = t.id_fencer
  ORDER BY t.total_score DESC;
$$;
