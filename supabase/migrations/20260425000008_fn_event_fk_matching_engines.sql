-- =============================================================================
-- Migration: FK-based carry-over engine implementations
-- =============================================================================
-- Phase 1B step 6 — adds the three engine functions that the dispatcher will
-- route to when a season's enum_carryover_engine is 'EVENT_FK_MATCHING'.
--
-- Each function mirrors the structure of its event_code_matching counterpart
-- (signature, return type, NULL-rules legacy path) but replaces the JSONB-path
-- carry-over CTEs (completed_positions + current_eligible + carried_eligible)
-- with a single 'eligible' CTE that joins through vw_eligible_event.
--
-- Carry semantics:
--   - is_carried=FALSE rows: current-season events with results
--   - is_carried=TRUE  rows: prior-season events linked via id_prior_event
--                            (only when p_rolling=TRUE for ranking functions;
--                             always for fn_fencer_scores_rolling)
--   - Type filter for carried events: must be in rules_types (ADR-021)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- (1) fn_ranking_ppw_event_fk_matching
-- ---------------------------------------------------------------------------
CREATE FUNCTION fn_ranking_ppw_event_fk_matching(
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
      ROW_NUMBER() OVER (ORDER BY (t.ppw_score + t.mpw_score) DESC)::INT AS rank,
      t.id_fencer,
      f.txt_surname || ' ' || f.txt_first_name AS fencer_name,
      t.ppw_score, t.mpw_score,
      (t.ppw_score + t.mpw_score) AS total_score,
      FALSE AS bool_has_carryover
    FROM totals t JOIN tbl_fencer f ON f.id_fencer = t.id_fencer
    WHERE (t.ppw_score + t.mpw_score) > 0
    ORDER BY (t.ppw_score + t.mpw_score) DESC;

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
      ROW_NUMBER() OVER (ORDER BY (t.ppw_score + t.mpw_score) DESC)::INT AS rank,
      t.fid AS id_fencer,
      f.txt_surname || ' ' || f.txt_first_name AS fencer_name,
      t.ppw_score, t.mpw_score,
      (t.ppw_score + t.mpw_score) AS total_score,
      COALESCE(t.has_carry, FALSE) AS bool_has_carryover
    FROM totals t JOIN tbl_fencer f ON f.id_fencer = t.fid
    WHERE (t.ppw_score + t.mpw_score) > 0
    ORDER BY (t.ppw_score + t.mpw_score) DESC;
  END IF;
END;
$$;

COMMENT ON FUNCTION fn_ranking_ppw_event_fk_matching(enum_weapon_type, enum_gender_type, enum_age_category, INT, BOOLEAN) IS
  'Phase 1B (ADR-042): FK-based carry-over engine for domestic PPW ranking. '
  'Replaces fn_event_position prefix matching with vw_eligible_event FK linkage. '
  'Identical NULL-rules legacy path; JSONB path uses vw_eligible_event for both '
  'current-season and carried-from-prior eligibility. '
  'Carry stops when linked current slot reaches SCORED, or 366-day cap fires.';

-- ---------------------------------------------------------------------------
-- (2) fn_ranking_kadra_event_fk_matching
-- ---------------------------------------------------------------------------
CREATE FUNCTION fn_ranking_kadra_event_fk_matching(
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
      ROW_NUMBER() OVER (ORDER BY (COALESCE(d.ppw_total, 0) + COALESCE(it.pew_total, 0)) DESC)::INT AS rank,
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
      ROW_NUMBER() OVER (ORDER BY (t.ppw_total + t.pew_total) DESC)::INT AS rank,
      t.fid AS id_fencer,
      f.txt_surname || ' ' || f.txt_first_name AS fencer_name,
      t.ppw_total, t.pew_total,
      (t.ppw_total + t.pew_total) AS total_score,
      COALESCE(t.has_carry, FALSE) AS bool_has_carryover
    FROM totals t JOIN tbl_fencer f ON f.id_fencer = t.fid
    WHERE t.ppw_total > 0
    ORDER BY (t.ppw_total + t.pew_total) DESC;
  END IF;
END;
$$;

COMMENT ON FUNCTION fn_ranking_kadra_event_fk_matching(enum_weapon_type, enum_gender_type, enum_age_category, INT, BOOLEAN) IS
  'Phase 1B (ADR-042): FK-based carry-over engine for Kadra ranking. '
  'Replaces prefix matching with vw_eligible_event linkage; same legacy path.';

-- ---------------------------------------------------------------------------
-- (3) fn_fencer_scores_rolling_event_fk_matching
-- ---------------------------------------------------------------------------
CREATE FUNCTION fn_fencer_scores_rolling_event_fk_matching(
  p_fencer_id INT,
  p_weapon    enum_weapon_type,
  p_gender    enum_gender_type,
  p_category  enum_age_category,
  p_season    INT DEFAULT NULL
)
RETURNS TABLE (
  id_result             INT,
  id_fencer             INT,
  fencer_name           TEXT,
  int_birth_year        SMALLINT,
  id_tournament         INT,
  txt_tournament_code   TEXT,
  txt_tournament_name   TEXT,
  dt_tournament         DATE,
  enum_type             enum_tournament_type,
  enum_weapon           enum_weapon_type,
  enum_gender           enum_gender_type,
  enum_age_category     enum_age_category,
  int_participant_count INT,
  num_multiplier        NUMERIC,
  int_place             INT,
  num_place_pts         NUMERIC,
  num_de_bonus          NUMERIC,
  num_podium_bonus      NUMERIC,
  num_final_score       NUMERIC,
  ts_points_calc        TIMESTAMPTZ,
  id_season             INT,
  txt_season_code       TEXT,
  url_results           TEXT,
  txt_location          TEXT,
  bool_carried_over     BOOLEAN,
  txt_source_season_code TEXT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
AS $$
DECLARE
  v_season_id     INT;
  v_season_end_yr INT;
  v_rules         JSONB;
BEGIN
  v_season_id := COALESCE(
    p_season,
    (SELECT s.id_season FROM tbl_season s WHERE s.bool_active LIMIT 1)
  );

  SELECT EXTRACT(YEAR FROM s.dt_end)::INT INTO v_season_end_yr
    FROM tbl_season s WHERE s.id_season = v_season_id;

  SELECT sc.json_ranking_rules INTO v_rules
    FROM tbl_scoring_config sc WHERE sc.id_season = v_season_id;

  RETURN QUERY
  WITH
    rules_types AS (
      SELECT DISTINCT jsonb_array_elements_text(b.value -> 'types') AS type_code
        FROM jsonb_array_elements(
          COALESCE(v_rules -> 'domestic', '[]'::JSONB) || COALESCE(v_rules -> 'international', '[]'::JSONB)
        ) AS b(value)
    )
  SELECT
    r.id_result, r.id_fencer,
    f.txt_surname || ' ' || f.txt_first_name AS fencer_name,
    f.int_birth_year,
    t.id_tournament, t.txt_code AS txt_tournament_code, t.txt_name AS txt_tournament_name,
    t.dt_tournament, t.enum_type, t.enum_weapon, t.enum_gender, t.enum_age_category,
    t.int_participant_count, t.num_multiplier,
    r.int_place, r.num_place_pts, r.num_de_bonus, r.num_podium_bonus,
    r.num_final_score, r.ts_points_calc,
    src_s.id_season, src_s.txt_code AS txt_season_code,
    t.url_results, src_e.txt_location,
    v.is_carried AS bool_carried_over,
    src_s.txt_code AS txt_source_season_code
  FROM vw_eligible_event v
  JOIN tbl_tournament t   ON t.id_event = v.id_event
  JOIN tbl_result r       ON r.id_tournament = t.id_tournament
  JOIN tbl_fencer f       ON f.id_fencer = r.id_fencer
  JOIN tbl_event src_e    ON src_e.id_event = v.source_event_id
  JOIN tbl_season src_s   ON src_s.id_season = src_e.id_season
  WHERE v.effective_season_id = v_season_id
    AND r.id_fencer = p_fencer_id
    AND t.enum_weapon = p_weapon
    AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender
    AND COALESCE(fn_age_category(f.int_birth_year, v_season_end_yr), t.enum_age_category) = p_category
    AND r.num_final_score IS NOT NULL
    AND (NOT v.is_carried OR t.enum_type::TEXT IN (SELECT type_code FROM rules_types))
  ORDER BY r.num_final_score DESC;
END;
$$;

COMMENT ON FUNCTION fn_fencer_scores_rolling_event_fk_matching IS
  'Phase 1B (ADR-042): FK-based engine for fencer score drilldown with carry-over. '
  'Returns is_carried=FALSE rows for current-season scores; '
  'is_carried=TRUE rows for prior-season scores linked via id_prior_event '
  '(with type-in-rules guard for ADR-021 compliance).';
