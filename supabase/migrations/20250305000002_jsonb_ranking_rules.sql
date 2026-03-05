-- =============================================================================
-- JSONB Ranking Rules — Configurable Per Season
-- =============================================================================
-- Adds PSW tournament type, per-season JSONB ranking rules, and rewrites
-- fn_ranking_ppw / fn_ranking_kadra to branch on NULL vs. JSONB rules.
--
--   NULL  json_ranking_rules → legacy K/J/droppable logic (SPWS-2023-2024)
--   Non-NULL                 → JSONB bucket-based selection
--
-- Season rules live on disk in supabase/data/{folder}/season_config.sql,
-- loaded automatically via the data/**/*.sql glob in config.toml.
-- =============================================================================


-- =============================================================================
-- PART A: Schema additions
-- =============================================================================

-- New tournament type: PSW = Puchar Świata Weteranów (FIE Veterans World Cup)
ALTER TYPE enum_tournament_type ADD VALUE IF NOT EXISTS 'PSW';

-- New scoring-config columns
ALTER TABLE tbl_scoring_config
  ADD COLUMN IF NOT EXISTS num_psw_multiplier  NUMERIC(8,4) NOT NULL DEFAULT 2.0,
  ADD COLUMN IF NOT EXISTS json_ranking_rules  JSONB DEFAULT NULL;

COMMENT ON COLUMN tbl_scoring_config.num_psw_multiplier IS
  'Score multiplier for PSW (Puchar Świata Weteranów, FIE Veterans World Cup). Default 2.0.';

COMMENT ON COLUMN tbl_scoring_config.json_ranking_rules IS
  'Per-season JSONB bucket rules for fn_ranking_ppw and fn_ranking_kadra. '
  'NULL = legacy hardcoded K/J/droppable logic. See §8.6.6 in project specification.';


-- =============================================================================
-- PART B: fn_calc_tournament_scores — add PSW to multiplier CASE
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_calc_tournament_scores(p_tournament_id INT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_n             INT;
  v_type          enum_tournament_type;
  v_multiplier    NUMERIC;
  v_mp            INT;
  v_gold          INT;
  v_silver        INT;
  v_bronze        INT;
  v_id_season     INT;
  v_is_power_of_2 BOOLEAN;
BEGIN
  -- 1. Fetch tournament metadata
  SELECT t.int_participant_count, t.enum_type, e.id_season
    INTO v_n, v_type, v_id_season
    FROM tbl_tournament t
    JOIN tbl_event e ON e.id_event = t.id_event
   WHERE t.id_tournament = p_tournament_id;

  IF v_n IS NULL OR v_n < 1 THEN
    RAISE EXCEPTION 'Tournament % has no participant count', p_tournament_id;
  END IF;

  -- 2. Fetch scoring config for the season
  SELECT sc.int_mp_value,
         sc.int_podium_gold,
         sc.int_podium_silver,
         sc.int_podium_bronze,
         CASE v_type
           WHEN 'PPW' THEN sc.num_ppw_multiplier
           WHEN 'MPW' THEN sc.num_mpw_multiplier
           WHEN 'PEW' THEN sc.num_pew_multiplier
           WHEN 'MEW' THEN sc.num_mew_multiplier
           WHEN 'MSW' THEN sc.num_msw_multiplier
           WHEN 'PSW' THEN sc.num_psw_multiplier
         END
    INTO v_mp, v_gold, v_silver, v_bronze, v_multiplier
    FROM tbl_scoring_config sc
   WHERE sc.id_season = v_id_season;

  -- 3. Determine if N is an exact power of 2
  v_is_power_of_2 := (v_n & (v_n - 1)) = 0;

  -- 4. Compute and store all four point columns for every result row
  -- de_bonus: fixed 10 pts per DE round won (matches SPWS Excel "Bonus za rundę = 10")
  -- podium_bonus: 3×N^(1/3) dynamic scaling (matches Excel =3*N^(1/3) formula)
  UPDATE tbl_result r
     SET num_place_pts = CASE
           WHEN v_n = 1 THEN v_mp
           WHEN r.int_place > v_n THEN 0
           ELSE ROUND((v_mp - (v_mp - 1) * LN(r.int_place) / LN(v_n))::NUMERIC, 2)
         END,

         num_de_bonus = CASE
           WHEN v_n <= 1 THEN 0
           ELSE ROUND((
             GREATEST(0,
               FLOOR(LN(v_n) / LN(2))
               - CEIL(LN(r.int_place) / LN(2))
               + CASE WHEN v_is_power_of_2 THEN 0 ELSE 1 END
             ) * 10
           )::NUMERIC, 2)
         END,

         num_podium_bonus = CASE
           WHEN r.int_place = 1 THEN ROUND((v_gold   * (3 * POWER(v_n, 1.0/3)))::NUMERIC, 2)
           WHEN r.int_place = 2 THEN ROUND((v_silver * (3 * POWER(v_n, 1.0/3)))::NUMERIC, 2)
           WHEN r.int_place = 3 THEN ROUND((v_bronze * (3 * POWER(v_n, 1.0/3)))::NUMERIC, 2)
           ELSE 0
         END,

         num_final_score = ROUND(((
           CASE
             WHEN v_n = 1 THEN v_mp
             WHEN r.int_place > v_n THEN 0
             ELSE v_mp - (v_mp - 1) * LN(r.int_place) / LN(v_n)
           END
           +
           CASE
             WHEN v_n <= 1 THEN 0
             ELSE GREATEST(0,
               FLOOR(LN(v_n) / LN(2))
               - CEIL(LN(r.int_place) / LN(2))
               + CASE WHEN v_is_power_of_2 THEN 0 ELSE 1 END
             ) * 10
           END
           +
           CASE
             WHEN r.int_place = 1 THEN v_gold   * (3 * POWER(v_n, 1.0/3))
             WHEN r.int_place = 2 THEN v_silver * (3 * POWER(v_n, 1.0/3))
             WHEN r.int_place = 3 THEN v_bronze * (3 * POWER(v_n, 1.0/3))
             ELSE 0
           END
         ) * v_multiplier)::NUMERIC, 2),

         ts_points_calc = NOW()

   WHERE r.id_tournament = p_tournament_id;

  -- 5. Update tournament import status to SCORED
  UPDATE tbl_tournament
     SET enum_import_status = 'SCORED',
         ts_updated = NOW()
   WHERE id_tournament = p_tournament_id;
END;
$$;


-- =============================================================================
-- PART C: fn_ranking_ppw — JSONB-driven branch
-- =============================================================================
-- Changing LANGUAGE from sql → plpgsql to support IF/ELSE branching.
-- Return type unchanged: (rank, id_fencer, fencer_name, ppw_score, mpw_score, total_score)
-- =============================================================================
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
    -- Legacy path: hardcoded K/droppable logic (SPWS-2023-2024 and any season
    -- without json_ranking_rules set)
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
    ORDER BY (t.ppw_score + t.mpw_score) DESC;

  ELSE
    -- -------------------------------------------------------------------------
    -- JSONB path: bucket-based selection driven by json_ranking_rules->'domestic'
    --
    -- Each bucket in the rules array defines a group of tournament types with
    -- a selection rule:
    --   {"types": ["PPW"], "best": 4}        → top 4 PPW scores per fencer
    --   {"types": ["MPW"], "always": true}   → all MPW scores (no limit)
    --
    -- Results are cross-joined with matching buckets, ranked within each bucket
    -- per fencer, then selected by the bucket's rule. Multipliers are already
    -- embedded in num_final_score — no extra weighting needed here.
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
        -- Cross-join each eligible result with every bucket whose types list
        -- includes the result's tournament type, then rank within bucket per fencer.
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
    ORDER BY (t.ppw_score + t.mpw_score) DESC;

  END IF;
END;
$$;

COMMENT ON FUNCTION fn_ranking_ppw(enum_weapon_type, enum_gender_type, enum_age_category, INT) IS
  'Domestic PPW ranking. '
  'NULL json_ranking_rules: best-K PPW + conditional MPW drop (legacy). '
  'Non-NULL: JSONB bucket selection from json_ranking_rules->''domestic''. '
  'Category determined by fencer birth year, not tournament category.';


-- =============================================================================
-- PART D: fn_ranking_kadra — JSONB-driven branch
-- =============================================================================
-- Return type unchanged: (rank, id_fencer, fencer_name, ppw_total, pew_total, total_score)
-- JSONB path is fully self-contained (does not call fn_ranking_ppw).
-- =============================================================================
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
    ORDER BY (COALESCE(d.ppw_total, 0) + COALESCE(it.pew_total, 0)) DESC;

  ELSE
    -- -------------------------------------------------------------------------
    -- JSONB path: fully self-contained, processes json_ranking_rules->'international'
    --
    -- Example international rules:
    --   [
    --     {"types": ["PPW"], "best": 4},
    --     {"types": ["MPW"], "always": true},
    --     {"types": ["PEW", "MEW", "MSW"], "best": 3}
    --   ]
    --
    -- ppw_total: sum of selected scores from buckets with only PPW/MPW types
    -- pew_total: sum of selected scores from buckets containing any international type
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
      totals AS (
        SELECT
          af.fid,
          -- Buckets containing only domestic types (PPW / MPW)
          COALESCE(
            SUM(sel.score) FILTER (
              WHERE NOT (sel.types_arr && ARRAY['PEW','MEW','MSW','PSW'])
            ), 0
          ) AS ppw_total,
          -- Buckets containing at least one international type
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
    ORDER BY (t.ppw_total + t.pew_total) DESC;

  END IF;
END;
$$;

COMMENT ON FUNCTION fn_ranking_kadra(enum_weapon_type, enum_gender_type, enum_age_category, INT) IS
  'Kadra ranking combining domestic and international results. '
  'NULL json_ranking_rules: fn_ranking_ppw + best-J PEW + conditional MEW (legacy). '
  'Non-NULL: JSONB bucket selection from json_ranking_rules->''international''; '
  'ppw_total = domestic-type buckets (PPW/MPW), pew_total = international-type buckets. '
  'V0 returns empty — no EVF international equivalent.';


-- =============================================================================
-- PART E: fn_export_scoring_config, fn_import_scoring_config — new columns
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_export_scoring_config(p_id_season INT)
RETURNS JSONB
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT jsonb_build_object(
    'id_season',              sc.id_season,
    'season_code',            s.txt_code,
    'mp_value',               sc.int_mp_value,
    'podium_gold',            sc.int_podium_gold,
    'podium_silver',          sc.int_podium_silver,
    'podium_bronze',          sc.int_podium_bronze,
    'ppw_multiplier',         sc.num_ppw_multiplier,
    'ppw_best_count',         sc.int_ppw_best_count,
    'ppw_total_rounds',       sc.int_ppw_total_rounds,
    'mpw_multiplier',         sc.num_mpw_multiplier,
    'mpw_droppable',          sc.bool_mpw_droppable,
    'pew_multiplier',         sc.num_pew_multiplier,
    'pew_best_count',         sc.int_pew_best_count,
    'mew_multiplier',         sc.num_mew_multiplier,
    'mew_droppable',          sc.bool_mew_droppable,
    'msw_multiplier',         sc.num_msw_multiplier,
    'psw_multiplier',         sc.num_psw_multiplier,
    'min_participants_evf',   sc.int_min_participants_evf,
    'min_participants_ppw',   sc.int_min_participants_ppw,
    'ranking_rules',          sc.json_ranking_rules,
    'extra',                  sc.json_extra
  )
  FROM tbl_scoring_config sc
  JOIN tbl_season s ON s.id_season = sc.id_season
  WHERE sc.id_season = p_id_season;
$$;


CREATE OR REPLACE FUNCTION fn_import_scoring_config(p_config JSONB)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_season INT := (p_config->>'id_season')::INT;
BEGIN
  IF v_season IS NULL THEN
    RAISE EXCEPTION 'id_season is required in the config JSON';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM tbl_season WHERE id_season = v_season) THEN
    RAISE EXCEPTION 'Season % does not exist', v_season;
  END IF;

  INSERT INTO tbl_scoring_config (
    id_season,
    int_mp_value,
    int_podium_gold, int_podium_silver, int_podium_bronze,
    num_ppw_multiplier, int_ppw_best_count, int_ppw_total_rounds,
    num_mpw_multiplier, bool_mpw_droppable,
    num_pew_multiplier, int_pew_best_count,
    num_mew_multiplier, bool_mew_droppable,
    num_msw_multiplier, num_psw_multiplier,
    int_min_participants_evf, int_min_participants_ppw,
    json_ranking_rules, json_extra,
    ts_updated
  ) VALUES (
    v_season,
    COALESCE((p_config->>'mp_value')::INT,              50),
    COALESCE((p_config->>'podium_gold')::INT,            3),
    COALESCE((p_config->>'podium_silver')::INT,          2),
    COALESCE((p_config->>'podium_bronze')::INT,          1),
    COALESCE((p_config->>'ppw_multiplier')::NUMERIC,     1.0),
    COALESCE((p_config->>'ppw_best_count')::INT,         4),
    COALESCE((p_config->>'ppw_total_rounds')::INT,       5),
    COALESCE((p_config->>'mpw_multiplier')::NUMERIC,     1.2),
    COALESCE((p_config->>'mpw_droppable')::BOOLEAN,      TRUE),
    COALESCE((p_config->>'pew_multiplier')::NUMERIC,     1.0),
    COALESCE((p_config->>'pew_best_count')::INT,         3),
    COALESCE((p_config->>'mew_multiplier')::NUMERIC,     2.0),
    COALESCE((p_config->>'mew_droppable')::BOOLEAN,      TRUE),
    COALESCE((p_config->>'msw_multiplier')::NUMERIC,     2.0),
    COALESCE((p_config->>'psw_multiplier')::NUMERIC,     2.0),
    COALESCE((p_config->>'min_participants_evf')::INT,   5),
    COALESCE((p_config->>'min_participants_ppw')::INT,   1),
    p_config->'ranking_rules',
    COALESCE(p_config->'extra', '{}'::JSONB),
    NOW()
  )
  ON CONFLICT (id_season) DO UPDATE SET
    int_mp_value              = COALESCE((p_config->>'mp_value')::INT,              tbl_scoring_config.int_mp_value),
    int_podium_gold           = COALESCE((p_config->>'podium_gold')::INT,            tbl_scoring_config.int_podium_gold),
    int_podium_silver         = COALESCE((p_config->>'podium_silver')::INT,          tbl_scoring_config.int_podium_silver),
    int_podium_bronze         = COALESCE((p_config->>'podium_bronze')::INT,          tbl_scoring_config.int_podium_bronze),
    num_ppw_multiplier        = COALESCE((p_config->>'ppw_multiplier')::NUMERIC,     tbl_scoring_config.num_ppw_multiplier),
    int_ppw_best_count        = COALESCE((p_config->>'ppw_best_count')::INT,         tbl_scoring_config.int_ppw_best_count),
    int_ppw_total_rounds      = COALESCE((p_config->>'ppw_total_rounds')::INT,       tbl_scoring_config.int_ppw_total_rounds),
    num_mpw_multiplier        = COALESCE((p_config->>'mpw_multiplier')::NUMERIC,     tbl_scoring_config.num_mpw_multiplier),
    bool_mpw_droppable        = COALESCE((p_config->>'mpw_droppable')::BOOLEAN,      tbl_scoring_config.bool_mpw_droppable),
    num_pew_multiplier        = COALESCE((p_config->>'pew_multiplier')::NUMERIC,     tbl_scoring_config.num_pew_multiplier),
    int_pew_best_count        = COALESCE((p_config->>'pew_best_count')::INT,         tbl_scoring_config.int_pew_best_count),
    num_mew_multiplier        = COALESCE((p_config->>'mew_multiplier')::NUMERIC,     tbl_scoring_config.num_mew_multiplier),
    bool_mew_droppable        = COALESCE((p_config->>'mew_droppable')::BOOLEAN,      tbl_scoring_config.bool_mew_droppable),
    num_msw_multiplier        = COALESCE((p_config->>'msw_multiplier')::NUMERIC,     tbl_scoring_config.num_msw_multiplier),
    num_psw_multiplier        = COALESCE((p_config->>'psw_multiplier')::NUMERIC,     tbl_scoring_config.num_psw_multiplier),
    int_min_participants_evf  = COALESCE((p_config->>'min_participants_evf')::INT,   tbl_scoring_config.int_min_participants_evf),
    int_min_participants_ppw  = COALESCE((p_config->>'min_participants_ppw')::INT,   tbl_scoring_config.int_min_participants_ppw),
    json_ranking_rules        = COALESCE(p_config->'ranking_rules',                  tbl_scoring_config.json_ranking_rules),
    json_extra                = COALESCE(p_config->'extra',                          tbl_scoring_config.json_extra),
    ts_updated                = NOW();
END;
$$;
