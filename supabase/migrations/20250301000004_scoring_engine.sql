-- =============================================================================
-- M2: Scoring Engine & Configuration Functions
-- =============================================================================
-- fn_calc_tournament_scores  — Compute all four point columns for a tournament
-- fn_export_scoring_config   — Export scoring config as JSON
-- fn_import_scoring_config   — Upsert scoring config from JSON
-- =============================================================================

-- ---------------------------------------------------------------------------
-- fn_calc_tournament_scores
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_calc_tournament_scores(p_tournament_id INT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_n             INT;      -- participant count (N)
  v_type          enum_tournament_type;
  v_multiplier    NUMERIC;
  v_mp            INT;
  v_gold          INT;
  v_silver        INT;
  v_bronze        INT;
  v_id_season     INT;
  v_is_power_of_2 BOOLEAN;
BEGIN
  -- 1. Fetch tournament metadata: N and type
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
         END
    INTO v_mp, v_gold, v_silver, v_bronze, v_multiplier
    FROM tbl_scoring_config sc
   WHERE sc.id_season = v_id_season;

  -- 3. Determine if N is an exact power of 2
  v_is_power_of_2 := (v_n & (v_n - 1)) = 0;

  -- 4. Compute and store all four point columns for every result row
  -- Note: LN/POWER/CEIL/FLOOR return double precision; cast to NUMERIC for ROUND(numeric, int)
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
             ) * (3 * POWER(v_n, 1.0/3))
           )::NUMERIC, 2)
         END,

         num_podium_bonus = CASE
           WHEN r.int_place = 1 THEN ROUND((v_gold   * (3 * POWER(v_n, 1.0/3)))::NUMERIC, 2)
           WHEN r.int_place = 2 THEN ROUND((v_silver * (3 * POWER(v_n, 1.0/3)))::NUMERIC, 2)
           WHEN r.int_place = 3 THEN ROUND((v_bronze * (3 * POWER(v_n, 1.0/3)))::NUMERIC, 2)
           ELSE 0
         END,

         num_final_score = ROUND(((
           -- place_pts + de_bonus + podium_bonus, repeated inline for single-pass UPDATE
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
             ) * (3 * POWER(v_n, 1.0/3))
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


-- ---------------------------------------------------------------------------
-- fn_export_scoring_config
-- ---------------------------------------------------------------------------
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
    'min_participants_evf',   sc.int_min_participants_evf,
    'min_participants_ppw',   sc.int_min_participants_ppw,
    'extra',                  sc.json_extra
  )
  FROM tbl_scoring_config sc
  JOIN tbl_season s ON s.id_season = sc.id_season
  WHERE sc.id_season = p_id_season;
$$;


-- ---------------------------------------------------------------------------
-- fn_import_scoring_config
-- ---------------------------------------------------------------------------
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

  -- Ensure the season exists
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
    num_msw_multiplier,
    int_min_participants_evf, int_min_participants_ppw,
    json_extra, ts_updated
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
    COALESCE((p_config->>'min_participants_evf')::INT,   5),
    COALESCE((p_config->>'min_participants_ppw')::INT,   1),
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
    int_min_participants_evf  = COALESCE((p_config->>'min_participants_evf')::INT,   tbl_scoring_config.int_min_participants_evf),
    int_min_participants_ppw  = COALESCE((p_config->>'min_participants_ppw')::INT,   tbl_scoring_config.int_min_participants_ppw),
    json_extra                = COALESCE(p_config->'extra',                          tbl_scoring_config.json_extra),
    ts_updated                = NOW();
END;
$$;
