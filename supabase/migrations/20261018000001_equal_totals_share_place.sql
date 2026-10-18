-- =============================================================================
-- Equal totals share a place; the next place skips (ADR-115)
-- =============================================================================
-- Every ranking function numbered its rows with ROW_NUMBER() OVER (ORDER BY
-- total DESC), so fencers on exactly the same total took consecutive places in
-- an order nothing fixed. Decided by the user on 2026-10-18: a fencer's place is
-- one more than the number of fencers with a higher total — two on equal points
-- are both 16th, there is no 17th, the next fencer is 18th (RANK()).
--
-- Fencers sharing a place are listed alphabetically by the name shown, in Polish
-- order (Q1 A; "pl-x-icu" exists on LOCAL, CERT and PROD), so a list never
-- reshuffles between two loads. The seed export (fn_ftl_export_entries) keeps
-- that ranking order for them instead of registration time, as the Python seed
-- generator already does (ADR-080, amended by ADR-115).
--
-- Each body below is the live definition with only those lines changed
-- (generated from pg_get_functiondef on LOCAL). CREATE OR REPLACE keeps every
-- signature, so the grants of ADR-083 stay as they are.
--
-- Plan: doc/plans/equal-totals-shared-place-2026-10-18.html.
-- Tests: supabase/tests/111_equal_totals_share_place.sql (RANK.TIE.01-07).
-- =============================================================================

BEGIN;

SET LOCAL lock_timeout = '2s';

-- fn_ranking_full_event_fk_matching: RANK() on the rank column; the name orders a shared place.
CREATE OR REPLACE FUNCTION public.fn_ranking_full_event_fk_matching(p_weapon enum_weapon_type, p_gender enum_gender_type, p_category enum_age_category, p_season integer DEFAULT NULL::integer, p_rolling boolean DEFAULT false)
 RETURNS TABLE(rank integer, id_fencer integer, fencer_name text, spws_total numeric, evf_plus_total numeric, total_score numeric, bool_has_carryover boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_season_id     INT;
  v_rules         JSONB;
  v_season_end_yr INT;
  v_prev_season_id INT;
  v_entry_gate     BOOLEAN;
  v_entry_types    TEXT[];
BEGIN
  v_season_id := COALESCE(
    p_season,
    (SELECT s.id_season FROM tbl_season s WHERE s.bool_active LIMIT 1)
  );

  SELECT sc.json_ranking_rules INTO v_rules
    FROM tbl_scoring_config sc WHERE sc.id_season = v_season_id;

  SELECT EXTRACT(YEAR FROM dt_end)::INT INTO v_season_end_yr
    FROM tbl_season WHERE id_season = v_season_id;

  -- ADR-103 §6: ranking entry through the types the rules name.
  v_entry_gate  := COALESCE(jsonb_typeof(v_rules -> 'entry_types') = 'array', FALSE);
  v_entry_types := ARRAY(SELECT jsonb_array_elements_text(
                           CASE WHEN v_entry_gate THEN v_rules -> 'entry_types' ELSE '[]'::JSONB END));

  -- The previous season, for the rolling entry window: the same resolution
  -- fn_ranking_full_event_code_matching uses.
  IF p_rolling THEN
    SELECT s.id_season INTO v_prev_season_id
      FROM tbl_season s
     WHERE s.dt_end < (SELECT s2.dt_start FROM tbl_season s2 WHERE s2.id_season = v_season_id)
     ORDER BY s.dt_end DESC
     LIMIT 1;
  END IF;

  RETURN QUERY
  WITH
    raw_buckets AS (
      SELECT section, grp, types, best, always_include, bucket_idx
        FROM fn_ranking_rules_canonical(v_rules)
    ),
    eligible AS (
      SELECT
        r.id_fencer       AS fid,
        r.num_final_score AS score,
        t.enum_type::TEXT AS type_code,
        v.is_carried      AS is_carried
      FROM vw_eligible_event v
      JOIN tbl_tournament t ON t.id_event = v.id_event
      JOIN tbl_result r     ON r.id_tournament = t.id_tournament
      JOIN tbl_fencer f     ON f.id_fencer = r.id_fencer
      WHERE v.effective_season_id = v_season_id
        AND (NOT v.is_carried OR p_rolling)
        AND t.enum_weapon = p_weapon
        AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender
        AND COALESCE(fn_age_category(f.int_birth_year, v_season_end_yr), t.enum_age_category) = p_category
        AND r.num_final_score IS NOT NULL
        AND r.id_fencer IS NOT NULL
        AND (NOT v.is_carried OR t.enum_type::TEXT NOT IN ('PPS', 'MPS'))  -- SS26.RANK.12
        AND NOT (v.is_carried AND fn_carry_stopped_by_results(v.id_event, v.effective_season_id, p_weapon, p_gender))  -- ADR-108 §8
    ),
    bucket_results AS (
      SELECT
        e.fid, e.score, e.is_carried,
        b.grp, b.section, b.bucket_idx, b.best, b.always_include,
        ROW_NUMBER() OVER (
          PARTITION BY b.section, b.bucket_idx, e.fid ORDER BY e.score DESC
        ) AS rn
      FROM eligible e CROSS JOIN raw_buckets b
      WHERE e.type_code = ANY(b.types)
    ),
    selected AS (
      SELECT fid, score, grp, is_carried
      FROM bucket_results
      WHERE COALESCE(always_include, FALSE) OR rn <= best
    ),
    all_fencers AS (
      SELECT DISTINCT el.fid FROM eligible el
       WHERE NOT v_entry_gate
          OR EXISTS (
               SELECT 1
                 FROM tbl_result er
                 JOIN tbl_tournament et ON et.id_tournament = er.id_tournament
                 JOIN tbl_event ee      ON ee.id_event      = et.id_event
                WHERE er.id_fencer = el.fid
                  AND et.enum_type::TEXT = ANY (v_entry_types)
                  AND (ee.id_season = v_season_id
                       OR (p_rolling AND ee.id_season = v_prev_season_id)))
    ),
    totals AS (
      SELECT
        af.fid,
        COALESCE(SUM(sel.score) FILTER (WHERE sel.grp = 'spws'), 0) AS spws_total,
        COALESCE(SUM(sel.score) FILTER (WHERE sel.grp = 'evf_plus'), 0) AS evf_plus_total,
        BOOL_OR(sel.is_carried) AS has_carry
      FROM all_fencers af
      LEFT JOIN selected sel ON sel.fid = af.fid
      GROUP BY af.fid
    )
  SELECT
    RANK() OVER (ORDER BY (t.spws_total + t.evf_plus_total) DESC)::INT AS rank,
    t.fid AS id_fencer,
    COALESCE(f.txt_surname || ' ' || f.txt_first_name, '') AS fencer_name,
    t.spws_total,
    t.evf_plus_total,
    (t.spws_total + t.evf_plus_total) AS total_score,
    COALESCE(t.has_carry, FALSE) AS bool_has_carryover
  FROM totals t
  LEFT JOIN tbl_fencer f ON f.id_fencer = t.fid
  WHERE (t.spws_total + t.evf_plus_total) > 0
  ORDER BY (t.spws_total + t.evf_plus_total) DESC, (COALESCE(f.txt_surname || ' ' || f.txt_first_name, '')) COLLATE "pl-x-icu";
END;
$function$;

-- fn_ranking_full_event_code_matching: RANK() on the rank column; the name orders a shared place.
CREATE OR REPLACE FUNCTION public.fn_ranking_full_event_code_matching(p_weapon enum_weapon_type, p_gender enum_gender_type, p_category enum_age_category, p_season integer DEFAULT NULL::integer, p_rolling boolean DEFAULT false)
 RETURNS TABLE(rank integer, id_fencer integer, fencer_name text, spws_total numeric, evf_plus_total numeric, total_score numeric, bool_has_carryover boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_season_id      INT;
  v_rules          JSONB;
  v_prev_season_id INT;
  v_season_end_yr  INT;
  v_entry_gate     BOOLEAN;
  v_entry_types    TEXT[];
BEGIN
  v_season_id := COALESCE(
    p_season,
    (SELECT s.id_season FROM tbl_season s WHERE s.bool_active LIMIT 1)
  );

  SELECT sc.json_ranking_rules INTO v_rules
    FROM tbl_scoring_config sc WHERE sc.id_season = v_season_id;

  SELECT EXTRACT(YEAR FROM s.dt_end)::INT INTO v_season_end_yr
    FROM tbl_season s WHERE s.id_season = v_season_id;

  -- ADR-103 §6: ranking entry through the types the rules name.
  v_entry_gate  := COALESCE(jsonb_typeof(v_rules -> 'entry_types') = 'array', FALSE);
  v_entry_types := ARRAY(SELECT jsonb_array_elements_text(
                           CASE WHEN v_entry_gate THEN v_rules -> 'entry_types' ELSE '[]'::JSONB END));

  IF p_rolling THEN
    SELECT s.id_season INTO v_prev_season_id
      FROM tbl_season s
     WHERE s.dt_end < (SELECT s2.dt_start FROM tbl_season s2 WHERE s2.id_season = v_season_id)
     ORDER BY s.dt_end DESC
     LIMIT 1;
  END IF;

  RETURN QUERY
  WITH
    raw_buckets AS (
      SELECT section, grp, types, best, always_include, bucket_idx
        FROM fn_ranking_rules_canonical(v_rules)
    ),
    rules_types AS (
      SELECT DISTINCT unnest(types) AS type_code FROM raw_buckets
    ),
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
        AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender
        AND COALESCE(
          fn_age_category(f.int_birth_year, EXTRACT(YEAR FROM s.dt_end)::INT),
          t.enum_age_category
        ) = p_category
        AND r.num_final_score IS NOT NULL
        AND r.id_fencer IS NOT NULL
    ),
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
        AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender
        AND COALESCE(fn_age_category(f.int_birth_year, v_season_end_yr), t.enum_age_category) = p_category
        AND r.num_final_score IS NOT NULL
        AND r.id_fencer IS NOT NULL
        AND t.enum_type::TEXT IN (SELECT type_code FROM rules_types)
        AND t.enum_type::TEXT NOT IN ('PPS', 'MPS')  -- SS26.RANK.12: begins disabled
        AND fn_event_position(e.txt_code) NOT IN (SELECT pos FROM completed_positions)
    ),
    eligible AS (
      SELECT fid, score, type_code, is_carried FROM current_eligible
      UNION ALL
      SELECT fid, score, type_code, is_carried FROM carried_eligible
    ),
    bucket_results AS (
      SELECT
        e.fid, e.score, e.is_carried,
        b.grp, b.section, b.bucket_idx, b.best, b.always_include,
        ROW_NUMBER() OVER (
          PARTITION BY b.section, b.bucket_idx, e.fid ORDER BY e.score DESC
        ) AS rn
      FROM eligible e CROSS JOIN raw_buckets b
      WHERE e.type_code = ANY(b.types)
    ),
    selected AS (
      SELECT fid, score, grp, is_carried
      FROM bucket_results
      WHERE COALESCE(always_include, FALSE) OR rn <= best
    ),
    all_fencers AS (
      SELECT DISTINCT el.fid FROM eligible el
       WHERE NOT v_entry_gate
          OR EXISTS (
               SELECT 1
                 FROM tbl_result er
                 JOIN tbl_tournament et ON et.id_tournament = er.id_tournament
                 JOIN tbl_event ee      ON ee.id_event      = et.id_event
                WHERE er.id_fencer = el.fid
                  AND et.enum_type::TEXT = ANY (v_entry_types)
                  AND (ee.id_season = v_season_id
                       OR (p_rolling AND ee.id_season = v_prev_season_id)))
    ),
    totals AS (
      SELECT
        af.fid,
        COALESCE(SUM(sel.score) FILTER (WHERE sel.grp = 'spws'), 0) AS spws_total,
        COALESCE(SUM(sel.score) FILTER (WHERE sel.grp = 'evf_plus'), 0) AS evf_plus_total,
        BOOL_OR(sel.is_carried) AS has_carry
      FROM all_fencers af
      LEFT JOIN selected sel ON sel.fid = af.fid
      GROUP BY af.fid
    )
  SELECT
    RANK() OVER (ORDER BY (t.spws_total + t.evf_plus_total) DESC)::INT AS rank,
    t.fid AS id_fencer,
    COALESCE(fe.txt_surname || ' ' || fe.txt_first_name, '') AS fencer_name,
    t.spws_total,
    t.evf_plus_total,
    (t.spws_total + t.evf_plus_total) AS total_score,
    COALESCE(t.has_carry, FALSE) AS bool_has_carryover
  FROM totals t
  LEFT JOIN tbl_fencer fe ON fe.id_fencer = t.fid
  WHERE (t.spws_total + t.evf_plus_total) > 0
  ORDER BY (t.spws_total + t.evf_plus_total) DESC, (COALESCE(fe.txt_surname || ' ' || fe.txt_first_name, '')) COLLATE "pl-x-icu";
END;
$function$;

-- fn_ranking_ppw_event_fk_matching: RANK() on the rank column; the name orders a shared place.
CREATE OR REPLACE FUNCTION public.fn_ranking_ppw_event_fk_matching(p_weapon enum_weapon_type, p_gender enum_gender_type, p_category enum_age_category, p_season integer DEFAULT NULL::integer, p_rolling boolean DEFAULT false)
 RETURNS TABLE(rank integer, id_fencer integer, fencer_name text, ppw_score numeric, mpw_score numeric, total_score numeric, bool_has_carryover boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  v_season_id     INT;
  v_rules         JSONB;
  v_k             INT;
  v_mpw_drop      BOOLEAN;
  v_season_end_yr INT;
BEGIN
  v_season_id := COALESCE(
    p_season,
    (SELECT s.id_season FROM tbl_season s WHERE s.bool_active LIMIT 1)
  );

  SELECT sc.json_ranking_rules, sc.int_ppw_best_count, sc.bool_mpw_droppable
    INTO v_rules, v_k, v_mpw_drop
    FROM tbl_scoring_config sc
   WHERE sc.id_season = v_season_id;

  SELECT EXTRACT(YEAR FROM s.dt_end)::INT INTO v_season_end_yr
    FROM tbl_season s WHERE s.id_season = v_season_id;

  IF v_rules IS NULL THEN
    -- Legacy NULL-rules path is identical to event-code-matching (no carry-over)
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
        AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender
        AND COALESCE(
          fn_age_category(f.int_birth_year, EXTRACT(YEAR FROM s.dt_end)::INT),
          t.enum_age_category
        ) = p_category
        AND r.num_final_score IS NOT NULL
        AND r.id_fencer IS NOT NULL
    ),
    best_ppw AS (
      SELECT sc.id_fencer, SUM(sc.num_final_score) AS ppw_sum, MIN(sc.num_final_score) AS worst_ppw
      FROM scored sc WHERE sc.enum_type = 'PPW' AND sc.rn <= v_k
      GROUP BY sc.id_fencer
    ),
    next_ppw AS (
      SELECT sc.id_fencer, sc.num_final_score AS next_score
      FROM scored sc WHERE sc.enum_type = 'PPW' AND sc.rn = v_k + 1
    ),
    best_mpw AS (
      SELECT sc.id_fencer, sc.num_final_score AS mpw_score
      FROM scored sc WHERE sc.enum_type = 'MPW' AND sc.rn = 1
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
      RANK() OVER (ORDER BY (t.ppw_score + t.mpw_score) DESC)::INT AS rank,
      t.id_fencer,
      f.txt_surname || ' ' || f.txt_first_name AS fencer_name,
      t.ppw_score, t.mpw_score,
      (t.ppw_score + t.mpw_score) AS total_score,
      FALSE AS bool_has_carryover
    FROM totals t JOIN tbl_fencer f ON f.id_fencer = t.id_fencer
    WHERE (t.ppw_score + t.mpw_score) > 0
    ORDER BY (t.ppw_score + t.mpw_score) DESC, (f.txt_surname || ' ' || f.txt_first_name) COLLATE "pl-x-icu";

  ELSE
    -- JSONB path with FK-based carry-over via vw_eligible_event
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
      rules_types AS (
        SELECT DISTINCT jsonb_array_elements_text(b.value -> 'types') AS type_code
          FROM jsonb_array_elements(v_rules -> 'domestic') AS b(value)
      ),
      eligible AS (
        SELECT
          r.id_fencer            AS fid,
          r.num_final_score      AS score,
          t.enum_type::TEXT      AS type_code,
          v.is_carried           AS is_carried
        FROM vw_eligible_event v
        JOIN tbl_tournament t ON t.id_event = v.id_event
        JOIN tbl_result r     ON r.id_tournament = t.id_tournament
        JOIN tbl_fencer f     ON f.id_fencer = r.id_fencer
        WHERE v.effective_season_id = v_season_id
          AND (NOT v.is_carried OR p_rolling)
          AND t.enum_weapon = p_weapon
          AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender
          AND COALESCE(fn_age_category(f.int_birth_year, v_season_end_yr), t.enum_age_category) = p_category
          AND r.num_final_score IS NOT NULL
          AND r.id_fencer IS NOT NULL
          AND (NOT v.is_carried OR t.enum_type::TEXT IN (SELECT type_code FROM rules_types))
          AND NOT (v.is_carried AND fn_carry_stopped_by_results(v.id_event, v.effective_season_id, p_weapon, p_gender))  -- ADR-108 §8
      ),
      bucket_results AS (
        SELECT
          e.fid, e.score, e.is_carried,
          b.types_arr, b.best_n, b.always_include,
          ROW_NUMBER() OVER (
            PARTITION BY b.bucket_idx, e.fid ORDER BY e.score DESC
          ) AS rn
        FROM eligible e CROSS JOIN raw_buckets b
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
      RANK() OVER (ORDER BY (t.ppw_score + t.mpw_score) DESC)::INT AS rank,
      t.fid AS id_fencer,
      f.txt_surname || ' ' || f.txt_first_name AS fencer_name,
      t.ppw_score, t.mpw_score,
      (t.ppw_score + t.mpw_score) AS total_score,
      COALESCE(t.has_carry, FALSE) AS bool_has_carryover
    FROM totals t JOIN tbl_fencer f ON f.id_fencer = t.fid
    WHERE (t.ppw_score + t.mpw_score) > 0
    ORDER BY (t.ppw_score + t.mpw_score) DESC, (f.txt_surname || ' ' || f.txt_first_name) COLLATE "pl-x-icu";
  END IF;
END;
$function$;

-- fn_ranking_ppw_event_code_matching: RANK() on the rank column; the name orders a shared place.
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
      RANK() OVER (ORDER BY (t.ppw_score + t.mpw_score) DESC)::INT AS rank,
      t.id_fencer,
      f.txt_surname || ' ' || f.txt_first_name AS fencer_name,
      t.ppw_score,
      t.mpw_score,
      (t.ppw_score + t.mpw_score) AS total_score,
      FALSE AS bool_has_carryover
    FROM totals t
    JOIN tbl_fencer f ON f.id_fencer = t.id_fencer
    WHERE (t.ppw_score + t.mpw_score) > 0
    ORDER BY (t.ppw_score + t.mpw_score) DESC, (f.txt_surname || ' ' || f.txt_first_name) COLLATE "pl-x-icu";

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
      RANK() OVER (ORDER BY (t.ppw_score + t.mpw_score) DESC)::INT AS rank,
      t.fid AS id_fencer,
      f.txt_surname || ' ' || f.txt_first_name AS fencer_name,
      t.ppw_score,
      t.mpw_score,
      (t.ppw_score + t.mpw_score) AS total_score,
      COALESCE(t.has_carry, FALSE) AS bool_has_carryover
    FROM totals t
    JOIN tbl_fencer f ON f.id_fencer = t.fid
    WHERE (t.ppw_score + t.mpw_score) > 0
    ORDER BY (t.ppw_score + t.mpw_score) DESC, (f.txt_surname || ' ' || f.txt_first_name) COLLATE "pl-x-icu";

  END IF;
END;
$function$;

-- fn_ranking_kadra_event_fk_matching: RANK() on the rank column; the name orders a shared place.
CREATE OR REPLACE FUNCTION public.fn_ranking_kadra_event_fk_matching(p_weapon enum_weapon_type, p_gender enum_gender_type, p_category enum_age_category, p_season integer DEFAULT NULL::integer, p_rolling boolean DEFAULT false)
 RETURNS TABLE(rank integer, id_fencer integer, fencer_name text, ppw_total numeric, pew_total numeric, total_score numeric, bool_has_carryover boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  v_season_id     INT;
  v_rules         JSONB;
  v_j             INT;
  v_mew_drop      BOOLEAN;
  v_season_end_yr INT;
BEGIN
  IF p_category = 'V0' THEN RETURN; END IF;

  v_season_id := COALESCE(
    p_season,
    (SELECT s.id_season FROM tbl_season s WHERE s.bool_active LIMIT 1)
  );

  SELECT sc.json_ranking_rules, sc.int_pew_best_count, sc.bool_mew_droppable
    INTO v_rules, v_j, v_mew_drop
    FROM tbl_scoring_config sc
   WHERE sc.id_season = v_season_id;

  SELECT EXTRACT(YEAR FROM s.dt_end)::INT INTO v_season_end_yr
    FROM tbl_season s WHERE s.id_season = v_season_id;

  IF v_rules IS NULL THEN
    -- Legacy NULL-rules path: identical to event-code-matching (no carry-over)
    RETURN QUERY
    WITH
    domestic AS (
      SELECT r.id_fencer AS fid, r.fencer_name AS fname, r.total_score AS ppw_total
        FROM fn_ranking_ppw(p_weapon, p_gender, p_category, v_season_id) r
    ),
    intl_scored AS (
      SELECT
        r.id_fencer AS fid, r.num_final_score, t.enum_type,
        ROW_NUMBER() OVER (
          PARTITION BY r.id_fencer, t.enum_type ORDER BY r.num_final_score DESC
        ) AS rn
      FROM tbl_result r
      JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
      JOIN tbl_event e      ON e.id_event = t.id_event
      JOIN tbl_fencer f     ON f.id_fencer = r.id_fencer
      JOIN tbl_season s     ON s.id_season = e.id_season
      WHERE e.id_season = v_season_id
        AND t.enum_weapon = p_weapon
        AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender
        AND t.enum_type IN ('PEW', 'MEW')
        AND COALESCE(fn_age_category(f.int_birth_year, EXTRACT(YEAR FROM s.dt_end)::INT), t.enum_age_category) = p_category
        AND r.num_final_score IS NOT NULL
        AND r.id_fencer IS NOT NULL
    ),
    best_pew AS (
      SELECT i.fid, SUM(i.num_final_score) AS pew_sum, MIN(i.num_final_score) AS worst_pew
      FROM intl_scored i WHERE i.enum_type = 'PEW' AND i.rn <= v_j GROUP BY i.fid
    ),
    next_pew AS (
      SELECT i.fid, i.num_final_score AS next_score
      FROM intl_scored i WHERE i.enum_type = 'PEW' AND i.rn = v_j + 1
    ),
    best_mew AS (
      SELECT i.fid, i.num_final_score AS mew_score
      FROM intl_scored i WHERE i.enum_type = 'MEW' AND i.rn = 1
    ),
    all_fencers AS (
      SELECT fid FROM domestic UNION SELECT DISTINCT fid FROM intl_scored
    ),
    intl_totals AS (
      SELECT af.fid,
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
      RANK() OVER (ORDER BY (COALESCE(d.ppw_total, 0) + COALESCE(it.pew_total, 0)) DESC)::INT AS rank,
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
    ORDER BY (COALESCE(d.ppw_total, 0) + COALESCE(it.pew_total, 0)) DESC, (COALESCE(d.fname, fe.txt_surname || ' ' || fe.txt_first_name)) COLLATE "pl-x-icu";

  ELSE
    -- JSONB path with FK-based carry-over via vw_eligible_event
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
      rules_types AS (
        SELECT DISTINCT jsonb_array_elements_text(b.value -> 'types') AS type_code
          FROM jsonb_array_elements(v_rules -> 'international') AS b(value)
      ),
      eligible AS (
        SELECT
          r.id_fencer            AS fid,
          r.num_final_score      AS score,
          t.enum_type::TEXT      AS type_code,
          v.is_carried           AS is_carried
        FROM vw_eligible_event v
        JOIN tbl_tournament t ON t.id_event = v.id_event
        JOIN tbl_result r     ON r.id_tournament = t.id_tournament
        JOIN tbl_fencer f     ON f.id_fencer = r.id_fencer
        WHERE v.effective_season_id = v_season_id
          AND (NOT v.is_carried OR p_rolling)
          AND t.enum_weapon = p_weapon
          AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender
          AND COALESCE(fn_age_category(f.int_birth_year, v_season_end_yr), t.enum_age_category) = p_category
          AND r.num_final_score IS NOT NULL
          AND r.id_fencer IS NOT NULL
          AND (NOT v.is_carried OR t.enum_type::TEXT IN (SELECT type_code FROM rules_types))
          AND NOT (v.is_carried AND fn_carry_stopped_by_results(v.id_event, v.effective_season_id, p_weapon, p_gender))  -- ADR-108 §8
      ),
      bucket_results AS (
        SELECT
          e.fid, e.score, e.is_carried,
          b.types_arr, b.best_n, b.always_include,
          ROW_NUMBER() OVER (
            PARTITION BY b.bucket_idx, e.fid ORDER BY e.score DESC
          ) AS rn
        FROM eligible e CROSS JOIN raw_buckets b
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
          COALESCE(SUM(sel.score) FILTER (
            WHERE NOT (sel.types_arr && ARRAY['PEW','MEW','MSW','PSW'])
          ), 0) AS ppw_total,
          COALESCE(SUM(sel.score) FILTER (
            WHERE sel.types_arr && ARRAY['PEW','MEW','MSW','PSW']
          ), 0) AS pew_total,
          BOOL_OR(sel.is_carried) AS has_carry
        FROM all_fencers af
        LEFT JOIN selected sel ON sel.fid = af.fid
        GROUP BY af.fid
      )
    SELECT
      RANK() OVER (ORDER BY (t.ppw_total + t.pew_total) DESC)::INT AS rank,
      t.fid AS id_fencer,
      f.txt_surname || ' ' || f.txt_first_name AS fencer_name,
      t.ppw_total, t.pew_total,
      (t.ppw_total + t.pew_total) AS total_score,
      COALESCE(t.has_carry, FALSE) AS bool_has_carryover
    FROM totals t JOIN tbl_fencer f ON f.id_fencer = t.fid
    WHERE t.ppw_total > 0
    ORDER BY (t.ppw_total + t.pew_total) DESC, (f.txt_surname || ' ' || f.txt_first_name) COLLATE "pl-x-icu";
  END IF;
END;
$function$;

-- fn_ranking_kadra_event_code_matching: RANK() on the rank column; the name orders a shared place.
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
      RANK() OVER (
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
    ORDER BY (COALESCE(d.ppw_total, 0) + COALESCE(it.pew_total, 0)) DESC, (COALESCE(d.fname, fe.txt_surname || ' ' || fe.txt_first_name)) COLLATE "pl-x-icu";

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
      RANK() OVER (ORDER BY (t.ppw_total + t.pew_total) DESC)::INT AS rank,
      t.fid AS id_fencer,
      f.txt_surname || ' ' || f.txt_first_name AS fencer_name,
      t.ppw_total,
      t.pew_total,
      (t.ppw_total + t.pew_total) AS total_score,
      COALESCE(t.has_carry, FALSE) AS bool_has_carryover
    FROM totals t
    JOIN tbl_fencer f ON f.id_fencer = t.fid
    WHERE t.ppw_total > 0
    ORDER BY (t.ppw_total + t.pew_total) DESC, (f.txt_surname || ' ' || f.txt_first_name) COLLATE "pl-x-icu";

  END IF;
END;
$function$;

-- fn_ftl_export_entries: a shared tier follows the ranking's order.
CREATE OR REPLACE FUNCTION public.fn_ftl_export_entries(p_id_event integer, p_token uuid)
 RETURNS TABLE(txt_surname text, txt_first_name text, enum_gender enum_gender_type, enum_age_category enum_age_category, enum_weapon enum_weapon_type, int_order integer, int_rank integer, num_rank_points numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id_season INT;
  v_end_year  INT;
  v_rolling   BOOLEAN;
BEGIN
  -- No token, no data. Returning empty rather than raising is deliberate: a
  -- stale link should look empty, not broken, and an error would confirm to a
  -- prober that they had found a real endpoint.
  IF NOT COALESCE(fn_ftl_export_token_valid(p_token), FALSE) THEN
    RETURN;
  END IF;

  SELECT e.id_season, EXTRACT(YEAR FROM s.dt_end)::INT
    INTO v_id_season, v_end_year
    FROM tbl_event e
    JOIN tbl_season s ON s.id_season = e.id_season
   WHERE e.id_event = p_id_event;

  -- An unknown event is an empty entry list, not an error: the page resolves
  -- an event from a URL parameter, and a stale link must not show a stack trace.
  IF v_id_season IS NULL THEN
    RETURN;
  END IF;

  v_rolling := COALESCE(fn_ftl_export_use_rolling(p_id_event), FALSE);

  RETURN QUERY
  WITH entries AS (
    -- One row per declared weapon. A registration for épée and foil is two
    -- entries in two competitions, and they can be seeded differently.
    --
    -- The category comes from tbl_fencer when the registration is matched,
    -- because that is the year fn_ranking_ppw ranks on. COALESCE falls back to
    -- the declared year for an unmatched row, which has no fencer to consult.
    SELECT r.id_fencer       AS fid,
           r.txt_surname     AS surname,
           r.txt_first_name  AS first_name,
           r.enum_gender     AS gender,
           fn_age_category(
             COALESCE(f.int_birth_year, r.int_birth_year)::INT, v_end_year
           )                 AS vcat,
           w.weapon          AS weapon,
           r.ts_created      AS created
      FROM tbl_registration r
      LEFT JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
      CROSS JOIN LATERAL unnest(r.arr_weapons) AS w(weapon)
     WHERE r.id_event = p_id_event
  ),
  live AS (
    -- A birth year below the veteran floor has no sub-ranking, so it has no
    -- seed position and no file to go in. Same rule as the exporter's
    -- registration_subranking_key.
    SELECT * FROM entries WHERE vcat IS NOT NULL
  ),
  groups AS (
    SELECT DISTINCT weapon, gender, vcat FROM live
  ),
  ranked AS (
    -- One fn_ranking_ppw call per sub-ranking that actually has entrants,
    -- rather than all thirty.
    SELECT g.weapon, g.gender, g.vcat, rk.id_fencer AS fid, rk.rank AS position,
           rk.total_score AS points,
           rk.ordinality AS ord
      FROM groups g
      CROSS JOIN LATERAL fn_ranking_ppw(
        g.weapon, g.gender, g.vcat, v_id_season, v_rolling
      ) WITH ORDINALITY rk
  )
  SELECT l.surname,
         l.first_name,
         l.gender,
         l.vcat,
         l.weapon,
         ROW_NUMBER() OVER (
           PARTITION BY l.weapon, l.gender, l.vcat
           -- Ranked registrants in ranking order; everyone else after them, in
           -- the order they entered. Name is the final tiebreak so that two
           -- registrations written in the same transaction still order
           -- deterministically — a seed file that changes between two downloads
           -- of the same entry list would be impossible to reconcile. This is
           -- no longer the seed position: it orders the UNRANKED tail, and
           -- exists so that tail is stable without publishing ts_created.
           -- ADR-115: fencers sharing a place keep the ranking's own order (rk.ord),
           -- the same order the Python generator reads; registration time
           -- orders only the unranked tail.
           ORDER BY rk.position NULLS LAST, rk.ord NULLS LAST, l.created, l.surname, l.first_name
         )::INT,
         -- The seed tier. NULL means no ranking points at all, which is not
         -- rank 0 and not "last in the bucket": it is what sends the entry to
         -- the tail after every ranked fencer in every bucket.
         rk.position::INT,
         -- The points that rank is built on. Orders the entries INSIDE a tier
         -- (2026-09-26); the tier itself is still rk.position. NULL exactly
         -- when the rank is NULL, for the same reason.
         rk.points::NUMERIC
    FROM live l
    LEFT JOIN ranked rk
      ON  rk.weapon = l.weapon
      AND rk.gender = l.gender
      AND rk.vcat   = l.vcat
      AND rk.fid    = l.fid
   ORDER BY l.weapon, l.gender, l.vcat, 6;
END;
$function$;

COMMIT;
