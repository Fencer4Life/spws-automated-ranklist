-- =============================================================================
-- Migration: fn_ranking_kadra with p_rolling parameter (ADR-018)
-- =============================================================================
-- Adds p_rolling BOOLEAN DEFAULT FALSE parameter.
-- When TRUE, carries over previous-season results for positions that are
-- declared but not yet completed in the current season.
-- Return type extended with bool_has_carryover.
-- Same pattern as fn_ranking_ppw rolling migration.
-- =============================================================================

DROP FUNCTION IF EXISTS fn_ranking_kadra(enum_weapon_type, enum_gender_type, enum_age_category, INT);

CREATE FUNCTION fn_ranking_kadra(
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
  ppw_total         NUMERIC,
  pew_total         NUMERIC,
  total_score       NUMERIC,
  bool_has_carryover BOOLEAN
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
AS $$
DECLARE
  v_season_id      INT;
  v_rules          JSONB;
  v_j              INT;
  v_mew_drop       BOOLEAN;
  v_prev_season_id INT;
  v_season_end_yr  INT;
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
    -- Legacy path: domestic via fn_ranking_ppw + best-J PEW + conditional MEW
    -- Rolling NOT supported here (active season always has JSONB rules)
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
      (COALESCE(d.ppw_total, 0) + COALESCE(it.pew_total, 0)) AS total_score,
      FALSE AS bool_has_carryover
    FROM all_fencers af
    LEFT JOIN domestic d      ON d.fid = af.fid
    LEFT JOIN intl_totals it  ON it.fid = af.fid
    LEFT JOIN tbl_fencer fe   ON fe.id_fencer = af.fid
    WHERE COALESCE(d.ppw_total, 0) > 0
    ORDER BY (COALESCE(d.ppw_total, 0) + COALESCE(it.pew_total, 0)) DESC;

  ELSE
    -- -------------------------------------------------------------------------
    -- JSONB path: fully self-contained, json_ranking_rules->'international'
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
        FROM jsonb_array_elements(v_rules -> 'international')
             WITH ORDINALITY AS b(value, ordinality)
      ),
      -- Tournament types declared in ranking rules (ADR-021: rules-based carry-over)
      rules_types AS (
        SELECT DISTINCT jsonb_array_elements_text(b.value -> 'types') AS type_code
          FROM jsonb_array_elements(v_rules -> 'international') AS b(value)
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
          -- Type must be in ranking rules AND position not yet completed (ADR-021)
          AND t.enum_type::TEXT IN (SELECT type_code FROM rules_types)
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
          COALESCE(
            SUM(sel.score) FILTER (
              WHERE NOT (sel.types_arr && ARRAY['PEW','MEW','MSW','PSW'])
            ), 0
          ) AS ppw_total,
          COALESCE(
            SUM(sel.score) FILTER (
              WHERE sel.types_arr && ARRAY['PEW','MEW','MSW','PSW']
            ), 0
          ) AS pew_total,
          BOOL_OR(sel.is_carried) AS has_carry
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
      (t.ppw_total + t.pew_total) AS total_score,
      COALESCE(t.has_carry, FALSE) AS bool_has_carryover
    FROM totals t
    JOIN tbl_fencer f ON f.id_fencer = t.fid
    WHERE t.ppw_total > 0
    ORDER BY (t.ppw_total + t.pew_total) DESC;

  END IF;
END;
$$;

COMMENT ON FUNCTION fn_ranking_kadra(enum_weapon_type, enum_gender_type, enum_age_category, INT, BOOLEAN) IS
  'Kadra ranking (domestic + international) with optional rolling carry-over (ADR-018). '
  'p_rolling=TRUE: previous-season results for declared-but-uncompleted positions are included. '
  'Excludes fencers with zero domestic points (§8.5(7)). '
  'NULL json_ranking_rules: best-J PEW + conditional MEW drop (legacy, no rolling). '
  'Non-NULL: JSONB bucket selection from json_ranking_rules->''international''. '
  'Category determined by fencer birth year against CURRENT season end year.';
