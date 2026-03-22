-- =============================================================================
-- Domestic-participation requirement (§8.5(7))
-- =============================================================================
-- Exclude fencers with zero domestic points from ranking output.
-- fn_ranking_ppw: add WHERE (total > 0) filter to both legacy and JSONB paths.
-- fn_ranking_kadra: add WHERE domestic > 0 filter to both legacy and JSONB paths.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- fn_ranking_ppw: recreate with domestic > 0 filter on both paths
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ranking_ppw(enum_weapon_type, enum_gender_type, enum_age_category, INT);

CREATE FUNCTION fn_ranking_ppw(
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
LANGUAGE plpgsql STABLE SECURITY DEFINER
AS $$
DECLARE
  v_season_id  INT;
  v_rules      JSONB;
  v_k          INT;
  v_mpw_drop   BOOLEAN;
BEGIN
  v_season_id := COALESCE(
    p_season,
    (SELECT s.id_season FROM tbl_season s WHERE s.bool_active LIMIT 1)
  );

  SELECT sc.json_ranking_rules, sc.int_ppw_best_count, sc.bool_mpw_droppable
    INTO v_rules, v_k, v_mpw_drop
    FROM tbl_scoring_config sc
   WHERE sc.id_season = v_season_id;

  IF v_rules IS NULL THEN
    -- -------------------------------------------------------------------------
    -- Legacy path: hardcoded K/droppable logic
    -- -------------------------------------------------------------------------
    RETURN QUERY
    WITH scored AS (
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
      WHERE e.id_season = v_season_id
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
      WHERE s.enum_type = 'PPW'
        AND s.rn <= v_k
      GROUP BY s.id_fencer
    ),
    next_ppw AS (
      SELECT s.id_fencer, s.num_final_score AS next_score
      FROM scored s
      WHERE s.enum_type = 'PPW'
        AND s.rn = v_k + 1
    ),
    best_mpw AS (
      SELECT s.id_fencer, s.num_final_score AS mpw_score
      FROM scored s
      WHERE s.enum_type = 'MPW'
        AND s.rn = 1
    ),
    all_fencers AS (
      SELECT DISTINCT scored.id_fencer FROM scored
    ),
    totals AS (
      SELECT
        af.id_fencer,
        COALESCE(bp.ppw_sum, 0) AS ppw_score,
        CASE
          WHEN bm.mpw_score IS NULL THEN 0::NUMERIC
          WHEN NOT v_mpw_drop        THEN bm.mpw_score
          WHEN bp.worst_ppw IS NULL  THEN bm.mpw_score
          WHEN bm.mpw_score >= bp.worst_ppw THEN bm.mpw_score
          WHEN np.next_score IS NOT NULL    THEN np.next_score
          ELSE 0::NUMERIC
        END AS mpw_score
      FROM all_fencers af
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
    WHERE (t.ppw_score + t.mpw_score) > 0
    ORDER BY (t.ppw_score + t.mpw_score) DESC;

  ELSE
    -- -------------------------------------------------------------------------
    -- JSONB path: bucket-based selection driven by json_ranking_rules->'domestic'
    -- -------------------------------------------------------------------------
    RETURN QUERY
    WITH
      raw_buckets AS (
        SELECT
          (b.value ->> 'best')::INT        AS best_n,
          (b.value ->> 'always')::BOOLEAN  AS always_include,
          ARRAY(SELECT jsonb_array_elements_text(b.value -> 'types')) AS types_arr,
          b.ordinality::INT                AS bucket_idx
        FROM jsonb_array_elements(v_rules -> 'domestic')
             WITH ORDINALITY AS b(value, ordinality)
      ),
      eligible AS (
        SELECT
          r.id_fencer            AS fid,
          r.num_final_score      AS score,
          t.enum_type::TEXT      AS type_code
        FROM tbl_result r
        JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
        JOIN tbl_event e      ON e.id_event = t.id_event
        JOIN tbl_fencer f     ON f.id_fencer = r.id_fencer
        JOIN tbl_season s     ON s.id_season = e.id_season
        WHERE e.id_season = v_season_id
          AND t.enum_weapon = p_weapon
          AND t.enum_gender = p_gender
          AND COALESCE(
            fn_age_category(f.int_birth_year, EXTRACT(YEAR FROM s.dt_end)::INT),
            t.enum_age_category
          ) = p_category
          AND r.num_final_score IS NOT NULL
          AND r.id_fencer IS NOT NULL
      ),
      bucket_results AS (
        SELECT
          e.fid,
          e.score,
          b.types_arr,
          b.best_n,
          b.always_include,
          ROW_NUMBER() OVER (
            PARTITION BY b.bucket_idx, e.fid
            ORDER BY e.score DESC
          ) AS rn
        FROM eligible e
        CROSS JOIN raw_buckets b
        WHERE e.type_code = ANY(b.types_arr)
      ),
      selected AS (
        SELECT fid, score, types_arr
        FROM bucket_results
        WHERE COALESCE(always_include, FALSE) OR rn <= best_n
      ),
      all_fencers AS (
        SELECT DISTINCT fid FROM eligible
      ),
      totals AS (
        SELECT
          af.fid,
          COALESCE(SUM(sel.score) FILTER (WHERE 'PPW' = ANY(sel.types_arr)), 0) AS ppw_score,
          COALESCE(SUM(sel.score) FILTER (WHERE 'MPW' = ANY(sel.types_arr)), 0) AS mpw_score
        FROM all_fencers af
        LEFT JOIN selected sel ON sel.fid = af.fid
        GROUP BY af.fid
      )
    SELECT
      ROW_NUMBER() OVER (ORDER BY (t.ppw_score + t.mpw_score) DESC)::INT AS rank,
      t.fid AS id_fencer,
      f.txt_surname || ' ' || f.txt_first_name AS fencer_name,
      t.ppw_score,
      t.mpw_score,
      (t.ppw_score + t.mpw_score) AS total_score
    FROM totals t
    JOIN tbl_fencer f ON f.id_fencer = t.fid
    WHERE (t.ppw_score + t.mpw_score) > 0
    ORDER BY (t.ppw_score + t.mpw_score) DESC;

  END IF;
END;
$$;

COMMENT ON FUNCTION fn_ranking_ppw(enum_weapon_type, enum_gender_type, enum_age_category, INT) IS
  'Domestic PPW ranking. '
  'Excludes fencers with zero domestic points (§8.5(7)). '
  'NULL json_ranking_rules: best-K PPW + conditional MPW drop (legacy). '
  'Non-NULL: JSONB bucket selection from json_ranking_rules->''domestic''. '
  'Category determined by fencer birth year, not tournament category.';


-- ---------------------------------------------------------------------------
-- fn_ranking_kadra: recreate with domestic > 0 filter on both paths
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ranking_kadra(enum_weapon_type, enum_gender_type, enum_age_category, INT);

CREATE FUNCTION fn_ranking_kadra(
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
  v_season_id  INT;
  v_rules      JSONB;
  v_j          INT;
  v_mew_drop   BOOLEAN;
BEGIN
  -- V0 has no EVF equivalent — return empty
  IF p_category = 'V0' THEN
    RETURN;
  END IF;

  v_season_id := COALESCE(
    p_season,
    (SELECT s.id_season FROM tbl_season s WHERE s.bool_active LIMIT 1)
  );

  SELECT sc.json_ranking_rules, sc.int_pew_best_count, sc.bool_mew_droppable
    INTO v_rules, v_j, v_mew_drop
    FROM tbl_scoring_config sc
   WHERE sc.id_season = v_season_id;

  IF v_rules IS NULL THEN
    -- -------------------------------------------------------------------------
    -- Legacy path: domestic via fn_ranking_ppw + best-J PEW + conditional MEW
    -- -------------------------------------------------------------------------
    RETURN QUERY
    WITH
    domestic AS (
      SELECT
        r.id_fencer AS fid,
        r.fencer_name AS fname,
        r.total_score AS ppw_total
      FROM fn_ranking_ppw(p_weapon, p_gender, p_category, v_season_id) r
    ),
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
    best_pew AS (
      SELECT
        i.fid,
        SUM(i.num_final_score) AS pew_sum,
        MIN(i.num_final_score) AS worst_pew
      FROM intl_scored i
      WHERE i.enum_type = 'PEW'
        AND i.rn <= v_j
      GROUP BY i.fid
    ),
    next_pew AS (
      SELECT i.fid, i.num_final_score AS next_score
      FROM intl_scored i
      WHERE i.enum_type = 'PEW'
        AND i.rn = v_j + 1
    ),
    best_mew AS (
      SELECT i.fid, i.num_final_score AS mew_score
      FROM intl_scored i
      WHERE i.enum_type = 'MEW'
        AND i.rn = 1
    ),
    all_fencers AS (
      SELECT fid FROM domestic
      UNION
      SELECT DISTINCT fid FROM intl_scored
    ),
    intl_totals AS (
      SELECT
        af.fid,
        COALESCE(bp.pew_sum, 0) + (
          CASE
            WHEN bm.mew_score IS NULL   THEN 0
            WHEN NOT v_mew_drop         THEN bm.mew_score
            WHEN bp.worst_pew IS NULL   THEN bm.mew_score
            WHEN bm.mew_score >= bp.worst_pew THEN bm.mew_score
            WHEN np.next_score IS NOT NULL    THEN np.next_score
            ELSE 0
          END
        ) AS pew_total
      FROM all_fencers af
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
    WHERE COALESCE(d.ppw_total, 0) > 0
    ORDER BY (COALESCE(d.ppw_total, 0) + COALESCE(it.pew_total, 0)) DESC;

  ELSE
    -- -------------------------------------------------------------------------
    -- JSONB path: fully self-contained, json_ranking_rules->'international'
    -- -------------------------------------------------------------------------
    RETURN QUERY
    WITH
      raw_buckets AS (
        SELECT
          (b.value ->> 'best')::INT        AS best_n,
          (b.value ->> 'always')::BOOLEAN  AS always_include,
          ARRAY(SELECT jsonb_array_elements_text(b.value -> 'types')) AS types_arr,
          b.ordinality::INT                AS bucket_idx
        FROM jsonb_array_elements(v_rules -> 'international')
             WITH ORDINALITY AS b(value, ordinality)
      ),
      eligible AS (
        SELECT
          r.id_fencer            AS fid,
          r.num_final_score      AS score,
          t.enum_type::TEXT      AS type_code
        FROM tbl_result r
        JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
        JOIN tbl_event e      ON e.id_event = t.id_event
        JOIN tbl_fencer f     ON f.id_fencer = r.id_fencer
        JOIN tbl_season s     ON s.id_season = e.id_season
        WHERE e.id_season = v_season_id
          AND t.enum_weapon = p_weapon
          AND t.enum_gender = p_gender
          AND COALESCE(
            fn_age_category(f.int_birth_year, EXTRACT(YEAR FROM s.dt_end)::INT),
            t.enum_age_category
          ) = p_category
          AND r.num_final_score IS NOT NULL
          AND r.id_fencer IS NOT NULL
      ),
      bucket_results AS (
        SELECT
          e.fid,
          e.score,
          b.types_arr,
          b.best_n,
          b.always_include,
          ROW_NUMBER() OVER (
            PARTITION BY b.bucket_idx, e.fid
            ORDER BY e.score DESC
          ) AS rn
        FROM eligible e
        CROSS JOIN raw_buckets b
        WHERE e.type_code = ANY(b.types_arr)
      ),
      selected AS (
        SELECT fid, score, types_arr
        FROM bucket_results
        WHERE COALESCE(always_include, FALSE) OR rn <= best_n
      ),
      all_fencers AS (
        SELECT DISTINCT fid FROM eligible
      ),
      -- Split domestic vs international totals
      dom_totals AS (
        SELECT
          af.fid,
          COALESCE(
            SUM(sel.score) FILTER (
              WHERE NOT (sel.types_arr && ARRAY['PEW','MEW','MSW','PSW'])
            ), 0
          ) AS ppw_total
        FROM all_fencers af
        LEFT JOIN selected sel ON sel.fid = af.fid
        GROUP BY af.fid
      ),
      totals AS (
        SELECT
          af.fid,
          COALESCE(
            SUM(sel.score) FILTER (
              WHERE NOT (sel.types_arr && ARRAY['PEW','MEW','MSW','PSW'])
            ), 0
          ) AS ppw_total,
          COALESCE(
            SUM(sel.score) FILTER (
              WHERE sel.types_arr && ARRAY['PEW','MEW','MSW','PSW']
            ), 0
          ) AS pew_total
        FROM all_fencers af
        LEFT JOIN selected sel ON sel.fid = af.fid
        GROUP BY af.fid
      )
    SELECT
      ROW_NUMBER() OVER (ORDER BY (t.ppw_total + t.pew_total) DESC)::INT AS rank,
      t.fid AS id_fencer,
      f.txt_surname || ' ' || f.txt_first_name AS fencer_name,
      t.ppw_total,
      t.pew_total,
      (t.ppw_total + t.pew_total) AS total_score
    FROM totals t
    JOIN tbl_fencer f ON f.id_fencer = t.fid
    WHERE t.ppw_total > 0
    ORDER BY (t.ppw_total + t.pew_total) DESC;

  END IF;
END;
$$;

COMMENT ON FUNCTION fn_ranking_kadra(enum_weapon_type, enum_gender_type, enum_age_category, INT) IS
  'Kadra ranking combining domestic and international results. '
  'Excludes fencers with zero domestic points (§8.5(7)). '
  'NULL json_ranking_rules: fn_ranking_ppw + best-J PEW + conditional MEW (legacy). '
  'Non-NULL: JSONB bucket selection from json_ranking_rules->''international''; '
  'ppw_total = domestic-type buckets (PPW/MPW), pew_total = international-type buckets. '
  'V0 returns empty — no EVF international equivalent.';
