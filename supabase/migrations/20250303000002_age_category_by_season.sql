-- =============================================================================
-- Age Category by Season End Year + Cross-Category Point Carryover
-- =============================================================================
-- fn_age_category     — compute V0–V4 from birth year + season end year
-- fn_ranking_ppw      — updated to use fencer-based category (not tournament)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- fn_age_category: compute a fencer's age category from birth year and
-- the season's end year. Returns NULL if birth year is NULL or age < 30.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_age_category(
  p_birth_year INT,
  p_season_end_year INT
)
RETURNS enum_age_category
LANGUAGE sql IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_birth_year IS NULL THEN NULL
    WHEN (p_season_end_year - p_birth_year) >= 70 THEN 'V4'::enum_age_category
    WHEN (p_season_end_year - p_birth_year) >= 60 THEN 'V3'::enum_age_category
    WHEN (p_season_end_year - p_birth_year) >= 50 THEN 'V2'::enum_age_category
    WHEN (p_season_end_year - p_birth_year) >= 40 THEN 'V1'::enum_age_category
    WHEN (p_season_end_year - p_birth_year) >= 30 THEN 'V0'::enum_age_category
    ELSE NULL  -- under 30, not a veteran
  END;
$$;

COMMENT ON FUNCTION fn_age_category(INT, INT) IS
  'Compute age category (V0–V4) from birth year and season end year. '
  'A fencer enters a category if they turn the minimum age during the end year. '
  'Returns NULL for NULL birth year or age < 30.';

-- ---------------------------------------------------------------------------
-- fn_ranking_ppw: updated to use fencer-based category filtering
-- ---------------------------------------------------------------------------
-- Category is now determined by fn_age_category(birth_year, season_end_year)
-- instead of tournament's enum_age_category. This enables cross-category
-- point carryover: a V3 fencer's results from V2 tournaments count in V3
-- ranking. Fencers with NULL birth year fall back to tournament category.
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
  -- Category filter: use fencer's birth-year-derived category, fall back to
  -- tournament category for fencers with NULL birth year
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
    JOIN tbl_fencer f     ON f.id_fencer = r.id_fencer
    JOIN tbl_season s     ON s.id_season = e.id_season
    CROSS JOIN params p
    WHERE e.id_season = p.season_id
      AND t.enum_weapon = p_weapon
      AND t.enum_gender = p_gender
      AND COALESCE(
        fn_age_category(f.int_birth_year, EXTRACT(YEAR FROM s.dt_end)::INT),
        t.enum_age_category
      ) = p_category
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
