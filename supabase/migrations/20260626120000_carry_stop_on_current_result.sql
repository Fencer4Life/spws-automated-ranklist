-- =============================================================================
-- Migration: carry-stop keyed on current-season RESULT existence (not status)
-- =============================================================================
-- ADR-018 / ADR-021 amendment. SUPERSEDES 20260406000006_fix_carryover_in_progress.
--
-- Problem: the EVENT_CODE_MATCHING engine dropped a prior-season carry only when
-- the current-season equivalent position had enum_status IN ('COMPLETED',
-- 'IN_PROGRESS'). current_scores is ungated, so a current event with results but
-- a status outside that set (SCHEDULED/PLANNED/CHANGED) showed BOTH this-year and
-- last-year for the same position -> double-count in the drilldown and ranklist.
--
-- Fix: redefine `completed_positions` as "positions the current season already
-- has a scored result for", scoped to the queried weapon+gender. Strict either/or
-- per (position, weapon, gender): current result present -> only this-year; absent
-- -> only the carried prior-season row. Status-independent (no dependence on the
-- SCHEDULED->IN_PROGRESS->COMPLETED lifecycle being maintained).
--
-- Scope: the three ACTIVE-engine functions only (captured-and-renamed at
-- 20260425000004). The inactive EVENT_FK_MATCHING engine + vw_eligible_event key
-- carry-stop on SCORED status and are intentionally left unchanged.
-- =============================================================================


CREATE OR REPLACE FUNCTION public.fn_fencer_scores_rolling_event_code_matching(p_fencer_id integer, p_weapon enum_weapon_type, p_gender enum_gender_type, p_category enum_age_category, p_season integer DEFAULT NULL::integer)
 RETURNS TABLE(id_result integer, id_fencer integer, fencer_name text, int_birth_year smallint, id_tournament integer, txt_tournament_code text, txt_tournament_name text, dt_tournament date, enum_type enum_tournament_type, enum_weapon enum_weapon_type, enum_gender enum_gender_type, enum_age_category enum_age_category, int_participant_count integer, num_multiplier numeric, int_place integer, num_place_pts numeric, num_de_bonus numeric, num_podium_bonus numeric, num_final_score numeric, ts_points_calc timestamp with time zone, id_season integer, txt_season_code text, url_results text, txt_location text, bool_carried_over boolean, txt_source_season_code text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  v_season_id      INT;
  v_prev_season_id INT;
  v_season_end_yr  INT;
  v_rules          JSONB;
BEGIN
  v_season_id := COALESCE(
    p_season,
    (SELECT s.id_season FROM tbl_season s WHERE s.bool_active LIMIT 1)
  );

  SELECT EXTRACT(YEAR FROM s.dt_end)::INT INTO v_season_end_yr
    FROM tbl_season s WHERE s.id_season = v_season_id;

  SELECT sc.json_ranking_rules INTO v_rules
    FROM tbl_scoring_config sc WHERE sc.id_season = v_season_id;

  SELECT s.id_season INTO v_prev_season_id
    FROM tbl_season s
   WHERE s.dt_end < (SELECT s2.dt_start FROM tbl_season s2 WHERE s2.id_season = v_season_id)
   ORDER BY s.dt_end DESC
   LIMIT 1;

  RETURN QUERY
  WITH
    -- Tournament types from ranking rules — domestic + international (ADR-021)
    rules_types AS (
      SELECT DISTINCT jsonb_array_elements_text(b.value -> 'types') AS type_code
        FROM jsonb_array_elements(
          COALESCE(v_rules -> 'domestic', '[]'::JSONB) || COALESCE(v_rules -> 'international', '[]'::JSONB)
        ) AS b(value)
    ),
    -- Positions the current season already HAS a result for (ADR-018/021 amend)
    completed_positions AS (
      SELECT DISTINCT fn_event_position(ev.txt_code) AS pos
        FROM tbl_event ev
        JOIN tbl_tournament t ON t.id_event = ev.id_event
        JOIN tbl_result r ON r.id_tournament = t.id_tournament
       WHERE ev.id_season = v_season_id
         AND t.enum_weapon = p_weapon
         AND t.enum_gender = p_gender
         AND r.num_final_score IS NOT NULL
    ),
    -- Current-season scores
    current_scores AS (
      SELECT
        r.id_result, r.id_fencer,
        f.txt_surname || ' ' || f.txt_first_name AS fencer_name,
        f.int_birth_year,
        t.id_tournament, t.txt_code AS txt_tournament_code, t.txt_name AS txt_tournament_name,
        t.dt_tournament, t.enum_type, t.enum_weapon, t.enum_gender, t.enum_age_category,
        t.int_participant_count, t.num_multiplier,
        r.int_place, r.num_place_pts, r.num_de_bonus, r.num_podium_bonus,
        r.num_final_score, r.ts_points_calc,
        s.id_season, s.txt_code AS txt_season_code,
        t.url_results, ev.txt_location,
        FALSE AS bool_carried_over,
        s.txt_code AS txt_source_season_code
      FROM tbl_result r
      JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
      JOIN tbl_event ev     ON ev.id_event = t.id_event
      JOIN tbl_season s     ON s.id_season = ev.id_season
      JOIN tbl_fencer f     ON f.id_fencer = r.id_fencer
      WHERE r.id_fencer = p_fencer_id
        AND ev.id_season = v_season_id
        AND t.enum_weapon = p_weapon
        AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender  -- ADR-034
        AND r.num_final_score IS NOT NULL
    ),
    -- Carried-over scores from previous season
    carried_scores AS (
      SELECT
        r.id_result, r.id_fencer,
        f.txt_surname || ' ' || f.txt_first_name AS fencer_name,
        f.int_birth_year,
        t.id_tournament, t.txt_code AS txt_tournament_code, t.txt_name AS txt_tournament_name,
        t.dt_tournament, t.enum_type, t.enum_weapon, t.enum_gender, t.enum_age_category,
        t.int_participant_count, t.num_multiplier,
        r.int_place, r.num_place_pts, r.num_de_bonus, r.num_podium_bonus,
        r.num_final_score, r.ts_points_calc,
        prev_s.id_season, prev_s.txt_code AS txt_season_code,
        t.url_results, ev.txt_location,
        TRUE AS bool_carried_over,
        prev_s.txt_code AS txt_source_season_code
      FROM tbl_result r
      JOIN tbl_tournament t  ON t.id_tournament = r.id_tournament
      JOIN tbl_event ev      ON ev.id_event = t.id_event
      JOIN tbl_season prev_s ON prev_s.id_season = ev.id_season
      JOIN tbl_fencer f      ON f.id_fencer = r.id_fencer
      WHERE v_prev_season_id IS NOT NULL
        AND r.id_fencer = p_fencer_id
        AND ev.id_season = v_prev_season_id
        AND t.enum_weapon = p_weapon
        AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender  -- ADR-034
        AND COALESCE(fn_age_category(f.int_birth_year, v_season_end_yr), t.enum_age_category) = p_category
        AND r.num_final_score IS NOT NULL
        -- Type must be in ranking rules AND position not yet completed (ADR-021)
        AND t.enum_type::TEXT IN (SELECT type_code FROM rules_types)
        AND fn_event_position(ev.txt_code) NOT IN (SELECT pos FROM completed_positions)
    )
  SELECT * FROM current_scores
  UNION ALL
  SELECT * FROM carried_scores
  ORDER BY num_final_score DESC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_ranking_ppw_event_code_matching(p_weapon enum_weapon_type, p_gender enum_gender_type, p_category enum_age_category, p_season integer DEFAULT NULL::integer, p_rolling boolean DEFAULT false)
 RETURNS TABLE(rank integer, id_fencer integer, fencer_name text, ppw_score numeric, mpw_score numeric, total_score numeric, bool_has_carryover boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
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
        AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender  -- ADR-034
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
      -- Tournament types declared in ranking rules (ADR-021: rules-based carry-over)
      rules_types AS (
        SELECT DISTINCT jsonb_array_elements_text(b.value -> 'types') AS type_code
          FROM jsonb_array_elements(v_rules -> 'domestic') AS b(value)
      ),
      -- Positions the current season already HAS a result for (ADR-018/021 amend)
      completed_positions AS (
        SELECT DISTINCT fn_event_position(ev.txt_code) AS pos
        FROM tbl_event ev
        JOIN tbl_tournament t ON t.id_event = ev.id_event
        JOIN tbl_result r ON r.id_tournament = t.id_tournament
       WHERE ev.id_season = v_season_id
         AND t.enum_weapon = p_weapon
         AND t.enum_gender = p_gender
         AND r.num_final_score IS NOT NULL
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
          AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender  -- ADR-034
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
          AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender  -- ADR-034
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
$function$;

CREATE OR REPLACE FUNCTION public.fn_ranking_kadra_event_code_matching(p_weapon enum_weapon_type, p_gender enum_gender_type, p_category enum_age_category, p_season integer DEFAULT NULL::integer, p_rolling boolean DEFAULT false)
 RETURNS TABLE(rank integer, id_fencer integer, fencer_name text, ppw_total numeric, pew_total numeric, total_score numeric, bool_has_carryover boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
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
        AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender  -- ADR-034
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
      -- Positions the current season already HAS a result for (ADR-018/021 amend)
      completed_positions AS (
        SELECT DISTINCT fn_event_position(ev.txt_code) AS pos
        FROM tbl_event ev
        JOIN tbl_tournament t ON t.id_event = ev.id_event
        JOIN tbl_result r ON r.id_tournament = t.id_tournament
       WHERE ev.id_season = v_season_id
         AND t.enum_weapon = p_weapon
         AND t.enum_gender = p_gender
         AND r.num_final_score IS NOT NULL
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
          AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender  -- ADR-034
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
          AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender  -- ADR-034
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
$function$;
