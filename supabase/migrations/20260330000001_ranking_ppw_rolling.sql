-- =============================================================================
-- Migration: fn_ranking_ppw with p_rolling parameter (ADR-018)
-- =============================================================================
-- Adds p_rolling BOOLEAN DEFAULT FALSE parameter.
-- When TRUE, carries over previous-season results for positions that are
-- declared but not yet completed in the current season.
-- Return type extended with bool_has_carryover.
-- =============================================================================

DROP FUNCTION IF EXISTS fn_ranking_ppw(enum_weapon_type, enum_gender_type, enum_age_category, INT);

CREATE FUNCTION fn_ranking_ppw(
  p_weapon   enum_weapon_type,
  p_gender   enum_gender_type,
  p_category enum_age_category,
  p_season   INT DEFAULT NULL,
  p_rolling  BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
  rank              INT,
  id_fencer         INT,
  fencer_name       TEXT,
  ppw_score         NUMERIC,
  mpw_score         NUMERIC,
  total_score       NUMERIC,
  bool_has_carryover BOOLEAN
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
AS $$
DECLARE
  v_season_id      INT;
  v_rules          JSONB;
  v_k              INT;
  v_mpw_drop       BOOLEAN;
  v_prev_season_id INT;
  v_season_end_yr  INT;
BEGIN
  v_season_id := COALESCE(
    p_season,
    (SELECT s.id_season FROM tbl_season s WHERE s.bool_active LIMIT 1)
  );

  SELECT sc.json_ranking_rules, sc.int_ppw_best_count, sc.bool_mpw_droppable
    INTO v_rules, v_k, v_mpw_drop
    FROM tbl_scoring_config sc
   WHERE sc.id_season = v_season_id;

  -- Resolve previous season and current season end year for rolling
  IF p_rolling THEN
    SELECT EXTRACT(YEAR FROM s.dt_end)::INT INTO v_season_end_yr
      FROM tbl_season s WHERE s.id_season = v_season_id;

    SELECT s.id_season INTO v_prev_season_id
      FROM tbl_season s
     WHERE s.dt_end < (SELECT s2.dt_start FROM tbl_season s2 WHERE s2.id_season = v_season_id)
     ORDER BY s.dt_end DESC
     LIMIT 1;
  END IF;

  IF v_rules IS NULL THEN
    -- -------------------------------------------------------------------------
    -- Legacy path: hardcoded K/droppable logic (rolling NOT supported here)
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
        sc.id_fencer,
        SUM(sc.num_final_score) AS ppw_sum,
        MIN(sc.num_final_score) AS worst_ppw
      FROM scored sc
      WHERE sc.enum_type = 'PPW'
        AND sc.rn <= v_k
      GROUP BY sc.id_fencer
    ),
    next_ppw AS (
      SELECT sc.id_fencer, sc.num_final_score AS next_score
      FROM scored sc
      WHERE sc.enum_type = 'PPW'
        AND sc.rn = v_k + 1
    ),
    best_mpw AS (
      SELECT sc.id_fencer, sc.num_final_score AS mpw_score
      FROM scored sc
      WHERE sc.enum_type = 'MPW'
        AND sc.rn = 1
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
      (t.ppw_score + t.mpw_score) AS total_score,
      FALSE AS bool_has_carryover
    FROM totals t
    JOIN tbl_fencer f ON f.id_fencer = t.id_fencer
    WHERE (t.ppw_score + t.mpw_score) > 0
    ORDER BY (t.ppw_score + t.mpw_score) DESC;

  ELSE
    -- -------------------------------------------------------------------------
    -- JSONB path: bucket-based selection driven by json_ranking_rules->'domestic'
    -- With optional rolling carry-over from previous season
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
      -- Positions declared in current season (any event at that position)
      declared_positions AS (
        SELECT DISTINCT fn_event_position(ev.txt_code) AS pos
          FROM tbl_event ev
         WHERE ev.id_season = v_season_id
      ),
      -- Positions where at least one event is COMPLETED
      completed_positions AS (
        SELECT DISTINCT fn_event_position(ev.txt_code) AS pos
          FROM tbl_event ev
         WHERE ev.id_season = v_season_id
           AND ev.enum_status = 'COMPLETED'
      ),
      -- Current-season results
      current_eligible AS (
        SELECT
          r.id_fencer            AS fid,
          r.num_final_score      AS score,
          t.enum_type::TEXT      AS type_code,
          FALSE                  AS is_carried
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
      -- Previous-season carry-over (only when p_rolling AND prev season exists)
      carried_eligible AS (
        SELECT
          r.id_fencer            AS fid,
          r.num_final_score      AS score,
          t.enum_type::TEXT      AS type_code,
          TRUE                   AS is_carried
        FROM tbl_result r
        JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
        JOIN tbl_event e      ON e.id_event = t.id_event
        JOIN tbl_fencer f     ON f.id_fencer = r.id_fencer
        WHERE p_rolling
          AND v_prev_season_id IS NOT NULL
          AND e.id_season = v_prev_season_id
          AND t.enum_weapon = p_weapon
          AND t.enum_gender = p_gender
          AND COALESCE(fn_age_category(f.int_birth_year, v_season_end_yr), t.enum_age_category) = p_category
          AND r.num_final_score IS NOT NULL
          AND r.id_fencer IS NOT NULL
          -- Position must be declared in current season but NOT completed
          AND fn_event_position(e.txt_code) IN (SELECT pos FROM declared_positions)
          AND fn_event_position(e.txt_code) NOT IN (SELECT pos FROM completed_positions)
      ),
      eligible AS (
        SELECT fid, score, type_code, is_carried FROM current_eligible
        UNION ALL
        SELECT fid, score, type_code, is_carried FROM carried_eligible
      ),
      bucket_results AS (
        SELECT
          e.fid,
          e.score,
          e.is_carried,
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
        SELECT fid, score, types_arr, is_carried
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
          COALESCE(SUM(sel.score) FILTER (WHERE 'MPW' = ANY(sel.types_arr)), 0) AS mpw_score,
          BOOL_OR(sel.is_carried) AS has_carry
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
      (t.ppw_score + t.mpw_score) AS total_score,
      COALESCE(t.has_carry, FALSE) AS bool_has_carryover
    FROM totals t
    JOIN tbl_fencer f ON f.id_fencer = t.fid
    WHERE (t.ppw_score + t.mpw_score) > 0
    ORDER BY (t.ppw_score + t.mpw_score) DESC;

  END IF;
END;
$$;

COMMENT ON FUNCTION fn_ranking_ppw(enum_weapon_type, enum_gender_type, enum_age_category, INT, BOOLEAN) IS
  'Domestic PPW ranking with optional rolling carry-over (ADR-018). '
  'p_rolling=TRUE: previous-season results for declared-but-uncompleted positions are included. '
  'Excludes fencers with zero domestic points (§8.5(7)). '
  'NULL json_ranking_rules: best-K PPW + conditional MPW drop (legacy, no rolling). '
  'Non-NULL: JSONB bucket selection from json_ranking_rules->''domestic''. '
  'Category determined by fencer birth year against CURRENT season end year.';
