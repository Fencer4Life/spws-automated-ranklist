-- =============================================================================
-- Fix de_bonus formula: replace dynamic 3×N^(1/3) with fixed 10 pts/round
-- =============================================================================
-- The original M2 implementation used 3×N^(1/3) as the per-DE-round bonus.
-- The SPWS Excel formula uses a fixed "Bonus za rundę = 10" parameter.
-- This migration aligns the DB scoring engine with the Excel ground truth.
-- Podium bonus (which also uses 3×N^(1/3)) is NOT changed — it matches Excel.
-- After redefining the function, all existing SCORED tournaments are recomputed.
-- =============================================================================

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
  -- de_bonus: fixed 10 pts per DE round won (matches SPWS Excel "Bonus za rundę = 10")
  -- podium_bonus: still uses 3×N^(1/3) dynamic scaling (matches Excel's =3*N^(1/3) formula)
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

-- Recompute all existing scored tournaments with the new formula
DO $$
DECLARE
  t INT;
BEGIN
  FOR t IN
    SELECT id_tournament FROM tbl_tournament WHERE enum_import_status = 'SCORED'
  LOOP
    PERFORM fn_calc_tournament_scores(t);
  END LOOP;
END;
$$;
