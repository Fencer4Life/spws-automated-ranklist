-- =============================================================================
-- Kadra Ranking + Updated PPW Return Type
-- =============================================================================
-- fn_ranking_ppw   — updated to return ppw_score and mpw_score separately
-- fn_ranking_kadra — combined domestic + international ranking (§8.3.2)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- fn_ranking_ppw: add ppw_score and mpw_score to return type
-- ---------------------------------------------------------------------------
-- Now returns separate ppw_score (best-K PPW sum) and mpw_score (included MPW
-- contribution, 0 if dropped or absent) alongside total_score.
-- Must DROP first because CREATE OR REPLACE cannot change return type.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ranking_ppw(enum_weapon_type, enum_gender_type, enum_age_category, INT);

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
  ppw_score    NUMERIC,
  mpw_score    NUMERIC,
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
  next_ppw AS (
    SELECT s.id_fencer, s.num_final_score AS next_score
    FROM scored s
    CROSS JOIN cfg
    WHERE s.enum_type = 'PPW'
      AND s.rn = cfg.k + 1
  ),
  best_mpw AS (
    SELECT s.id_fencer, s.num_final_score AS mpw_score
    FROM scored s
    WHERE s.enum_type = 'MPW'
      AND s.rn = 1
  ),
  all_fencers AS (
    SELECT DISTINCT id_fencer FROM scored
  ),
  totals AS (
    SELECT
      af.id_fencer,
      COALESCE(bp.ppw_sum, 0) AS ppw_score,
      CASE
        WHEN bm.mpw_score IS NULL THEN 0::NUMERIC
        WHEN NOT cfg.bool_mpw_droppable THEN bm.mpw_score
        WHEN bp.worst_ppw IS NULL THEN bm.mpw_score
        WHEN bm.mpw_score >= bp.worst_ppw THEN bm.mpw_score
        WHEN np.next_score IS NOT NULL THEN np.next_score
        ELSE 0::NUMERIC
      END AS mpw_score
    FROM all_fencers af
    CROSS JOIN cfg
    LEFT JOIN best_ppw bp ON bp.id_fencer = af.id_fencer
    LEFT JOIN best_mpw bm ON bm.id_fencer = af.id_fencer
    LEFT JOIN next_ppw np ON np.id_fencer = af.id_fencer
  )
  SELECT
    ROW_NUMBER() OVER (ORDER BY (t.ppw_score + t.mpw_score) DESC)::INT AS rank,
    t.id_fencer,
    f.txt_surname || ' ' || f.txt_first_name AS fencer_name,
    t.ppw_score,
    t.mpw_score,
    (t.ppw_score + t.mpw_score) AS total_score
  FROM totals t
  JOIN tbl_fencer f ON f.id_fencer = t.id_fencer
  ORDER BY (t.ppw_score + t.mpw_score) DESC;
$$;

COMMENT ON FUNCTION fn_ranking_ppw(enum_weapon_type, enum_gender_type, enum_age_category, INT) IS
  'Domestic PPW ranking with best-K PPW + conditional MPW drop. '
  'Returns separate ppw_score and mpw_score alongside total_score. '
  'Category determined by fencer birth year, not tournament category.';

-- ---------------------------------------------------------------------------
-- fn_ranking_kadra: combined domestic + international ranking (§8.3.2)
-- ---------------------------------------------------------------------------
-- Starts from fn_ranking_ppw totals, adds best-J PEW + conditional MEW.
-- V0 returns empty (no EVF international equivalent).
-- Uses same fencer-based category filtering as fn_ranking_ppw.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_ranking_kadra(
  p_weapon   enum_weapon_type,
  p_gender   enum_gender_type,
  p_category enum_age_category,
  p_season   INT DEFAULT NULL
)
RETURNS TABLE (
  rank         INT,
  id_fencer    INT,
  fencer_name  TEXT,
  ppw_total    NUMERIC,
  pew_total    NUMERIC,
  total_score  NUMERIC
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
AS $$
DECLARE
  v_season_id INT;
BEGIN
  -- V0 has no EVF equivalent — return empty
  IF p_category = 'V0' THEN
    RETURN;
  END IF;

  -- Resolve season
  v_season_id := COALESCE(
    p_season,
    (SELECT s.id_season FROM tbl_season s WHERE s.bool_active LIMIT 1)
  );

  RETURN QUERY
  WITH cfg AS (
    SELECT sc.int_pew_best_count AS j,
           sc.bool_mew_droppable
    FROM tbl_scoring_config sc
    WHERE sc.id_season = v_season_id
  ),
  -- Get domestic totals from fn_ranking_ppw
  domestic AS (
    SELECT
      r.id_fencer AS fid,
      r.fencer_name AS fname,
      r.total_score AS ppw_total
    FROM fn_ranking_ppw(p_weapon, p_gender, p_category, v_season_id) r
  ),
  -- International scored results (PEW + MEW) with same category filter
  intl_scored AS (
    SELECT
      r.id_fencer AS fid,
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
    WHERE e.id_season = v_season_id
      AND t.enum_weapon = p_weapon
      AND t.enum_gender = p_gender
      AND t.enum_type IN ('PEW', 'MEW')
      AND COALESCE(
        fn_age_category(f.int_birth_year, EXTRACT(YEAR FROM s.dt_end)::INT),
        t.enum_age_category
      ) = p_category
      AND r.num_final_score IS NOT NULL
      AND r.id_fencer IS NOT NULL
  ),
  -- Best J PEW scores per fencer
  best_pew AS (
    SELECT
      i.fid,
      SUM(i.num_final_score) AS pew_sum,
      MIN(i.num_final_score) AS worst_pew
    FROM intl_scored i
    CROSS JOIN cfg
    WHERE i.enum_type = 'PEW'
      AND i.rn <= cfg.j
    GROUP BY i.fid
  ),
  -- (J+1)th PEW score per fencer (replacement when MEW is dropped)
  next_pew AS (
    SELECT i.fid, i.num_final_score AS next_score
    FROM intl_scored i
    CROSS JOIN cfg
    WHERE i.enum_type = 'PEW'
      AND i.rn = cfg.j + 1
  ),
  -- Best MEW score per fencer
  best_mew AS (
    SELECT i.fid, i.num_final_score AS mew_score
    FROM intl_scored i
    WHERE i.enum_type = 'MEW'
      AND i.rn = 1
  ),
  -- All fencers (domestic + international)
  all_fencers AS (
    SELECT fid FROM domestic
    UNION
    SELECT DISTINCT fid FROM intl_scored
  ),
  -- Compute international total per fencer
  intl_totals AS (
    SELECT
      af.fid,
      COALESCE(bp.pew_sum, 0) + (
        CASE
          WHEN bm.mew_score IS NULL THEN 0
          WHEN NOT cfg.bool_mew_droppable THEN bm.mew_score
          WHEN bp.worst_pew IS NULL THEN bm.mew_score
          WHEN bm.mew_score >= bp.worst_pew THEN bm.mew_score
          WHEN np.next_score IS NOT NULL THEN np.next_score
          ELSE 0
        END
      ) AS pew_total
    FROM all_fencers af
    CROSS JOIN cfg
    LEFT JOIN best_pew bp ON bp.fid = af.fid
    LEFT JOIN best_mew bm ON bm.fid = af.fid
    LEFT JOIN next_pew np ON np.fid = af.fid
  )
  SELECT
    ROW_NUMBER() OVER (
      ORDER BY (COALESCE(d.ppw_total, 0) + COALESCE(it.pew_total, 0)) DESC
    )::INT AS rank,
    af.fid AS id_fencer,
    COALESCE(d.fname, fe.txt_surname || ' ' || fe.txt_first_name) AS fencer_name,
    COALESCE(d.ppw_total, 0) AS ppw_total,
    COALESCE(it.pew_total, 0) AS pew_total,
    (COALESCE(d.ppw_total, 0) + COALESCE(it.pew_total, 0)) AS total_score
  FROM all_fencers af
  LEFT JOIN domestic d      ON d.fid = af.fid
  LEFT JOIN intl_totals it  ON it.fid = af.fid
  LEFT JOIN tbl_fencer fe   ON fe.id_fencer = af.fid
  ORDER BY (COALESCE(d.ppw_total, 0) + COALESCE(it.pew_total, 0)) DESC;
END;
$$;

COMMENT ON FUNCTION fn_ranking_kadra(enum_weapon_type, enum_gender_type, enum_age_category, INT) IS
  'Kadra ranking: domestic (PPW+MPW) + international (best-J PEW + conditional MEW). '
  'V0 returns empty — no EVF international equivalent. '
  'Category determined by fencer birth year, not tournament category.';
