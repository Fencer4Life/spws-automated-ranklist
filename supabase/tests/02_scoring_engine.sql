-- =============================================================================
-- M2: Scoring Engine, Configuration & Calibration — Acceptance Tests
-- =============================================================================
-- Tests 2.1–2.19 from the POC development plan.
-- Relies on seed data from M1 + test data created within this file.
-- =============================================================================

BEGIN;
SELECT plan(25);

-- ===== SETUP: Create test data for scoring tests =====
-- We use the seed season (SPWS-2024-2025) and its scoring config.
-- Create a test event + tournaments with known N values for formula verification.

-- Helper: get season and organizer IDs
DO $setup$
DECLARE
  v_season INT;
  v_org INT;
  v_event INT;
  v_tourn_ppw INT;
  v_tourn_mpw INT;
  v_tourn_n1 INT;
  v_tourn_n16 INT;
  v_tourn_psw INT;
  v_fencer1 INT;
  v_fencer2 INT;
  v_fencer3 INT;
  v_fencer4 INT;
  v_fencer5 INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  -- Create test event for scoring
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('SCORE-TEST-EVT', 'Scoring Test Event', v_season, v_org, 'PLANNED');
  SELECT id_event INTO v_event FROM tbl_event WHERE txt_code = 'SCORE-TEST-EVT';

  -- Tournament A: PPW, N=24 (non-power-of-2, c=1)
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count,
    enum_import_status)
  VALUES (v_event, 'SCORE-PPW-N24', 'Test PPW N=24', 'PPW',
    'EPEE', 'M', 'V2', '2024-10-01', 24, 'IMPORTED');

  -- Tournament B: MPW, N=24 (for multiplier test)
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count,
    enum_import_status)
  VALUES (v_event, 'SCORE-MPW-N24', 'Test MPW N=24', 'MPW',
    'EPEE', 'M', 'V2', '2024-11-01', 24, 'IMPORTED');

  -- Tournament C: N=1 (edge case)
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count,
    enum_import_status)
  VALUES (v_event, 'SCORE-PPW-N1', 'Test PPW N=1', 'PPW',
    'EPEE', 'M', 'V2', '2024-12-01', 1, 'IMPORTED');

  -- Tournament D: N=16 (power-of-2, c=0)
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count,
    enum_import_status)
  VALUES (v_event, 'SCORE-PPW-N16', 'Test PPW N=16', 'PPW',
    'EPEE', 'M', 'V2', '2025-01-01', 16, 'IMPORTED');

  -- Tournament E: PSW, N=24 (for PSW multiplier test — multiplier=2.0)
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count,
    enum_import_status)
  VALUES (v_event, 'SCORE-PSW-N24', 'Test PSW N=24', 'PSW',
    'EPEE', 'M', 'V2', '2025-02-01', 24, 'IMPORTED');

  SELECT id_tournament INTO v_tourn_ppw FROM tbl_tournament WHERE txt_code = 'SCORE-PPW-N24';
  SELECT id_tournament INTO v_tourn_mpw FROM tbl_tournament WHERE txt_code = 'SCORE-MPW-N24';
  SELECT id_tournament INTO v_tourn_n1  FROM tbl_tournament WHERE txt_code = 'SCORE-PPW-N1';
  SELECT id_tournament INTO v_tourn_n16 FROM tbl_tournament WHERE txt_code = 'SCORE-PPW-N16';
  SELECT id_tournament INTO v_tourn_psw FROM tbl_tournament WHERE txt_code = 'SCORE-PSW-N24';

  -- Get fencer IDs from seed data (master fencer list)
  SELECT id_fencer INTO v_fencer1 FROM tbl_fencer WHERE txt_surname = 'ATANASSOW';
  SELECT id_fencer INTO v_fencer2 FROM tbl_fencer WHERE txt_surname = 'BARAŃSKI';
  SELECT id_fencer INTO v_fencer3 FROM tbl_fencer WHERE txt_surname = 'BAZAK';
  SELECT id_fencer INTO v_fencer4 FROM tbl_fencer WHERE txt_surname = 'DUDEK';
  SELECT id_fencer INTO v_fencer5 FROM tbl_fencer WHERE txt_surname = 'HAŚKO';

  -- Insert results for PPW N=24: places 1,2,3,4,24
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES
    (v_fencer1, v_tourn_ppw, 1),
    (v_fencer2, v_tourn_ppw, 2),
    (v_fencer3, v_tourn_ppw, 3),
    (v_fencer4, v_tourn_ppw, 4),
    (v_fencer5, v_tourn_ppw, 24);

  -- Insert results for MPW N=24: same fencers, same places (for multiplier comparison)
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES
    (v_fencer1, v_tourn_mpw, 1),
    (v_fencer2, v_tourn_mpw, 2),
    (v_fencer3, v_tourn_mpw, 3),
    (v_fencer4, v_tourn_mpw, 4),
    (v_fencer5, v_tourn_mpw, 24);

  -- Insert result for N=1: single fencer
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES
    (v_fencer1, v_tourn_n1, 1);

  -- Insert results for N=16: places 1,2,3,4,16
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES
    (v_fencer1, v_tourn_n16, 1),
    (v_fencer2, v_tourn_n16, 2),
    (v_fencer3, v_tourn_n16, 3),
    (v_fencer4, v_tourn_n16, 4),
    (v_fencer5, v_tourn_n16, 16);

  -- Insert results for PSW N=24: places 1,2 (for PSW multiplier comparison with PPW)
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES
    (v_fencer1, v_tourn_psw, 1),
    (v_fencer2, v_tourn_psw, 2);
END;
$setup$;

-- ===== RUN SCORING ENGINE =====
-- Score all test tournaments
SELECT fn_calc_tournament_scores(id_tournament) FROM tbl_tournament WHERE txt_code = 'SCORE-PPW-N24';
SELECT fn_calc_tournament_scores(id_tournament) FROM tbl_tournament WHERE txt_code = 'SCORE-MPW-N24';
SELECT fn_calc_tournament_scores(id_tournament) FROM tbl_tournament WHERE txt_code = 'SCORE-PPW-N1';
SELECT fn_calc_tournament_scores(id_tournament) FROM tbl_tournament WHERE txt_code = 'SCORE-PPW-N16';
SELECT fn_calc_tournament_scores(id_tournament) FROM tbl_tournament WHERE txt_code = 'SCORE-PSW-N24';

-- ---------------------------------------------------------------------------
-- 2.1  fn_calc_tournament_scores: N=24 PPW → point columns populated
-- ---------------------------------------------------------------------------
-- For N=24, place=1, MP=50, PPW multiplier=1.0:
--   PlacePoints = 50 (1st place always gets MP)
--   DE_rounds = floor(ln(24)/ln(2)) - ceil(ln(1)/ln(2)) + 1 = 4 - 0 + 1 = 5
--   DE_bonus = 5 rounds × 10 pts/round = 50 (fixed formula, matches Excel "Bonus za rundę = 10")
--   bonus_per_round (podium) = 3 * 24^(1/3) = 3 * 2.8845 = 8.65
--   Podium_bonus = 3 * 8.65 = 25.96
--   Final = (50 + 50 + 25.96) * 1.0 = 125.96
SELECT ok(
  (SELECT num_place_pts IS NOT NULL
      AND num_de_bonus IS NOT NULL
      AND num_podium_bonus IS NOT NULL
      AND num_final_score IS NOT NULL
   FROM tbl_result r
   JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
   WHERE t.txt_code = 'SCORE-PPW-N24' AND f.txt_surname = 'ATANASSOW'),
  '2.1 All four point columns populated for scored PPW N=24 tournament'
);

-- Verify 1st place gets MP (50) for place points
SELECT is(
  (SELECT num_place_pts
   FROM tbl_result r
   JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
   WHERE t.txt_code = 'SCORE-PPW-N24' AND f.txt_surname = 'ATANASSOW'),
  50.00::NUMERIC,
  '2.1b 1st place gets MP (50) place points for N=24'
);

-- Verify last place (24th of 24) gets 0 place points (ln(24)/ln(24) = 1, so 50 - 49*1 = 1)
-- Actually: MP - (MP-1)*ln(24)/ln(24) = 50 - 49*1 = 1.00
SELECT is(
  (SELECT num_place_pts
   FROM tbl_result r
   JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
   WHERE t.txt_code = 'SCORE-PPW-N24' AND f.txt_surname = 'HAŚKO'),
  1.00::NUMERIC,
  '2.1c Last place (24th of 24) gets 1.00 place points'
);

-- ---------------------------------------------------------------------------
-- 2.2  Edge case: N=1 → single fencer receives MP (50)
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT num_place_pts
   FROM tbl_result r
   JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   WHERE t.txt_code = 'SCORE-PPW-N1'),
  50.00::NUMERIC,
  '2.2a N=1: single fencer receives MP (50) place points'
);

SELECT is(
  (SELECT num_de_bonus
   FROM tbl_result r
   JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   WHERE t.txt_code = 'SCORE-PPW-N1'),
  0.00::NUMERIC,
  '2.2b N=1: DE bonus is 0'
);

-- ---------------------------------------------------------------------------
-- 2.3  Edge case: place > N → fencer gets 0 place points
-- ---------------------------------------------------------------------------
-- We test this by inserting a result with place=25 in the N=24 tournament
DO $test_place_gt_n$
DECLARE
  v_fencer INT;
  v_tourn INT;
BEGIN
  -- Create a temporary extra fencer for this test
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality)
  VALUES ('TESTOWY', 'Extra', 'PL') RETURNING id_fencer INTO v_fencer;

  SELECT id_tournament INTO v_tourn FROM tbl_tournament WHERE txt_code = 'SCORE-PPW-N24';

  INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
  VALUES (v_fencer, v_tourn, 25);
END;
$test_place_gt_n$;

-- Re-score to include the new result
SELECT fn_calc_tournament_scores(id_tournament) FROM tbl_tournament WHERE txt_code = 'SCORE-PPW-N24';

SELECT is(
  (SELECT num_place_pts
   FROM tbl_result r
   JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
   JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   WHERE t.txt_code = 'SCORE-PPW-N24' AND f.txt_surname = 'TESTOWY'),
  0.00::NUMERIC,
  '2.3 place > N: fencer gets 0 place points'
);

-- ---------------------------------------------------------------------------
-- 2.4  Power-of-2 N (N=16): DE bonus correction factor c=0
-- ---------------------------------------------------------------------------
-- For N=16, place=1: DE_rounds = floor(log2(16)) - ceil(log2(1)) + 0 = 4 - 0 + 0 = 4
-- DE bonus = 4 rounds × 10 pts/round = 40 (fixed formula, matches Excel "Bonus za rundę = 10")
SELECT is(
  (SELECT num_de_bonus
   FROM tbl_result r
   JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
   WHERE t.txt_code = 'SCORE-PPW-N16' AND f.txt_surname = 'ATANASSOW'),
  40.00::NUMERIC,
  '2.4 Power-of-2 N=16: 1st place DE bonus = 4 rounds × 10 = 40'
);

-- ---------------------------------------------------------------------------
-- 2.5  Non-power-of-2 N (N=24): DE bonus correction factor c=1
-- ---------------------------------------------------------------------------
-- For N=24, place=1: DE_rounds = floor(log2(24)) - ceil(log2(1)) + 1 = 4 - 0 + 1 = 5
-- DE bonus = 5 rounds × 10 pts/round = 50 (fixed formula, matches Excel "Bonus za rundę = 10")
SELECT is(
  (SELECT num_de_bonus
   FROM tbl_result r
   JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
   WHERE t.txt_code = 'SCORE-PPW-N24' AND f.txt_surname = 'ATANASSOW'),
  50.00::NUMERIC,
  '2.5 Non-power-of-2 N=24: 1st place DE bonus = 5 rounds × 10 = 50'
);

-- ---------------------------------------------------------------------------
-- 2.6  Podium bonus: 1st=gold*bpr, 2nd=silver*bpr, 3rd=bronze*bpr, 4th=0
-- ---------------------------------------------------------------------------
-- bonus_per_round for N=24 = 3 * 24^(1/3) ≈ 8.65
-- gold=3, silver=2, bronze=1
SELECT is(
  (SELECT num_podium_bonus
   FROM tbl_result r
   JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
   WHERE t.txt_code = 'SCORE-PPW-N24' AND f.txt_surname = 'ATANASSOW'),
  (SELECT ROUND(3 * (3 * POWER(24, 1.0/3)), 2))::NUMERIC,
  '2.6a 1st place podium bonus = gold(3) * bonus_per_round'
);

SELECT is(
  (SELECT num_podium_bonus
   FROM tbl_result r
   JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
   WHERE t.txt_code = 'SCORE-PPW-N24' AND f.txt_surname = 'BARAŃSKI'),
  (SELECT ROUND(2 * (3 * POWER(24, 1.0/3)), 2))::NUMERIC,
  '2.6b 2nd place podium bonus = silver(2) * bonus_per_round'
);

SELECT is(
  (SELECT num_podium_bonus
   FROM tbl_result r
   JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
   WHERE t.txt_code = 'SCORE-PPW-N24' AND f.txt_surname = 'BAZAK'),
  (SELECT ROUND(1 * (3 * POWER(24, 1.0/3)), 2))::NUMERIC,
  '2.6c 3rd place podium bonus = bronze(1) * bonus_per_round'
);

SELECT is(
  (SELECT num_podium_bonus
   FROM tbl_result r
   JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
   WHERE t.txt_code = 'SCORE-PPW-N24' AND f.txt_surname = 'DUDEK'),
  0.00::NUMERIC,
  '2.6d 4th place gets 0 podium bonus'
);

-- ---------------------------------------------------------------------------
-- 2.7  Multiplier: PPW uses 1.0, MPW uses 1.2
-- ---------------------------------------------------------------------------
-- Same fencer, same N=24, same place: PPW (mult=1.0) vs MPW (mult=1.2).
-- Components (place_pts, de_bonus, podium_bonus) should be identical.
-- Final scores differ by multiplier (rounding applied at the end).
SELECT ok(
  (SELECT
    -- Components must be identical between PPW and MPW for the same fencer/place/N
    ppw.num_place_pts = mpw.num_place_pts
    AND ppw.num_de_bonus = mpw.num_de_bonus
    AND ppw.num_podium_bonus = mpw.num_podium_bonus
    -- MPW final_score must be greater than PPW final_score (1.2 > 1.0)
    AND mpw.num_final_score > ppw.num_final_score
    -- The ratio should be very close to 1.2
    AND ABS(mpw.num_final_score / ppw.num_final_score - 1.2) < 0.01
   FROM
    (SELECT r.* FROM tbl_result r
     JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
     JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
     WHERE t.txt_code = 'SCORE-PPW-N24' AND f.txt_surname = 'ATANASSOW') ppw,
    (SELECT r.* FROM tbl_result r
     JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
     JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
     WHERE t.txt_code = 'SCORE-MPW-N24' AND f.txt_surname = 'ATANASSOW') mpw
  ),
  '2.7 MPW has same components as PPW but final_score scaled by 1.2 multiplier'
);

-- ---------------------------------------------------------------------------
-- 2.8  After scoring: ts_points_calc is set to a recent timestamp
-- ---------------------------------------------------------------------------
SELECT ok(
  (SELECT ts_points_calc IS NOT NULL
      AND ts_points_calc > NOW() - INTERVAL '5 minutes'
   FROM tbl_result r
   JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
   WHERE t.txt_code = 'SCORE-PPW-N24' AND f.txt_surname = 'ATANASSOW'),
  '2.8 ts_points_calc set to recent timestamp after scoring'
);

-- ---------------------------------------------------------------------------
-- 2.9  After scoring: tournament enum_import_status = SCORED
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT enum_import_status::TEXT FROM tbl_tournament WHERE txt_code = 'SCORE-PPW-N24'),
  'SCORED',
  '2.9 Tournament enum_import_status = SCORED after scoring'
);

-- ---------------------------------------------------------------------------
-- 2.10  Scoring reads multiplier from tbl_scoring_config, not tbl_tournament
-- ---------------------------------------------------------------------------
-- Change the cached multiplier on the tournament row (should NOT affect scoring)
UPDATE tbl_tournament SET num_multiplier = 999.0 WHERE txt_code = 'SCORE-PPW-N24';
UPDATE tbl_tournament SET enum_import_status = 'IMPORTED' WHERE txt_code = 'SCORE-PPW-N24';

-- Re-score
SELECT fn_calc_tournament_scores(id_tournament) FROM tbl_tournament WHERE txt_code = 'SCORE-PPW-N24';

-- Final score should still use 1.0 (from scoring config), not 999.0
SELECT ok(
  (SELECT r.num_final_score = ROUND(
    (r.num_place_pts + r.num_de_bonus + r.num_podium_bonus) * 1.0, 2)
   FROM tbl_result r
   JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
   WHERE t.txt_code = 'SCORE-PPW-N24' AND f.txt_surname = 'ATANASSOW'),
  '2.10 Scoring uses multiplier from tbl_scoring_config (1.0), not tbl_tournament (999.0)'
);

-- ---------------------------------------------------------------------------
-- 2.11  Changing int_mp_value does NOT change already-scored values
-- ---------------------------------------------------------------------------
-- Record the current final score
DO $test211$
DECLARE
  v_score_before NUMERIC;
  v_score_after NUMERIC;
  v_season INT;
BEGIN
  SELECT r.num_final_score INTO v_score_before
  FROM tbl_result r
  JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
  JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
  WHERE t.txt_code = 'SCORE-PPW-N24' AND f.txt_surname = 'ATANASSOW';

  -- Change MP value in scoring config
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025';
  UPDATE tbl_scoring_config SET int_mp_value = 100 WHERE id_season = v_season;

  -- Check the score is unchanged (no automatic recalculation)
  SELECT r.num_final_score INTO v_score_after
  FROM tbl_result r
  JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
  JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
  WHERE t.txt_code = 'SCORE-PPW-N24' AND f.txt_surname = 'ATANASSOW';

  IF v_score_before <> v_score_after THEN
    RAISE EXCEPTION 'Score changed from % to % after config update', v_score_before, v_score_after;
  END IF;

  -- Restore original MP value
  UPDATE tbl_scoring_config SET int_mp_value = 50 WHERE id_season = v_season;
END;
$test211$;

SELECT pass('2.11 Changing int_mp_value does NOT change already-scored values');

-- ---------------------------------------------------------------------------
-- 2.12  fn_export_scoring_config: returns JSON with all parameters
-- ---------------------------------------------------------------------------
SELECT ok(
  (SELECT
    result->>'id_season' IS NOT NULL
    AND result->>'season_code' IS NOT NULL
    AND result->>'mp_value' IS NOT NULL
    AND result->>'podium_gold' IS NOT NULL
    AND result->>'podium_silver' IS NOT NULL
    AND result->>'podium_bronze' IS NOT NULL
    AND result->>'ppw_multiplier' IS NOT NULL
    AND result->>'ppw_best_count' IS NOT NULL
    AND result->>'ppw_total_rounds' IS NOT NULL
    AND result->>'mpw_multiplier' IS NOT NULL
    AND result->>'mpw_droppable' IS NOT NULL
    AND result->>'pew_multiplier' IS NOT NULL
    AND result->>'pew_best_count' IS NOT NULL
    AND result->>'mew_multiplier' IS NOT NULL
    AND result->>'mew_droppable' IS NOT NULL
    AND result->>'msw_multiplier' IS NOT NULL
    AND result->>'min_participants_evf' IS NOT NULL
    AND result->>'min_participants_ppw' IS NOT NULL
    AND result->'extra' IS NOT NULL
    AND result->>'psw_multiplier' IS NOT NULL
    AND result ? 'ranking_rules'
   FROM (
     SELECT fn_export_scoring_config(
       (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025')
     ) AS result
   ) sub),
  '2.12 fn_export_scoring_config returns JSON with all 19 parameters + id_season + season_code'
);

-- ---------------------------------------------------------------------------
-- 2.13  Export is idempotent
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT fn_export_scoring_config(id_season) FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
  (SELECT fn_export_scoring_config(id_season) FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
  '2.13 Export is idempotent: two calls return identical JSON'
);

-- ---------------------------------------------------------------------------
-- 2.14  fn_import_scoring_config: upserts all columns, sets ts_updated
-- ---------------------------------------------------------------------------
SELECT lives_ok(
  $test214$DO $body$
  DECLARE
    v_season INT;
    v_ts_before TIMESTAMPTZ;
    v_ts_after TIMESTAMPTZ;
  BEGIN
    SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025';
    SELECT ts_updated INTO v_ts_before FROM tbl_scoring_config WHERE id_season = v_season;

    -- Wait a tiny bit to ensure timestamp differs
    PERFORM pg_sleep(0.01);

    PERFORM fn_import_scoring_config(jsonb_build_object(
      'id_season', v_season,
      'mp_value', 60,
      'podium_gold', 4
    ));

    SELECT ts_updated INTO v_ts_after FROM tbl_scoring_config WHERE id_season = v_season;

    IF v_ts_after <= v_ts_before THEN
      RAISE EXCEPTION 'ts_updated not updated after import';
    END IF;

    -- Verify the values were set
    IF NOT EXISTS (
      SELECT 1 FROM tbl_scoring_config
      WHERE id_season = v_season AND int_mp_value = 60 AND int_podium_gold = 4
    ) THEN
      RAISE EXCEPTION 'Values not updated after import';
    END IF;

    -- Restore defaults
    PERFORM fn_import_scoring_config(jsonb_build_object(
      'id_season', v_season,
      'mp_value', 50,
      'podium_gold', 3
    ));
  END;
  $body$$test214$,
  '2.14 fn_import_scoring_config upserts columns and sets ts_updated'
);

-- ---------------------------------------------------------------------------
-- 2.15  Partial import: only mp_value → preserves other values
-- ---------------------------------------------------------------------------
SELECT lives_ok(
  $test215$DO $body$
  DECLARE
    v_season INT;
    v_gold_before INT;
    v_gold_after INT;
  BEGIN
    SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025';

    SELECT int_podium_gold INTO v_gold_before
    FROM tbl_scoring_config WHERE id_season = v_season;

    PERFORM fn_import_scoring_config(jsonb_build_object(
      'id_season', v_season,
      'mp_value', 55
    ));

    SELECT int_podium_gold INTO v_gold_after
    FROM tbl_scoring_config WHERE id_season = v_season;

    IF v_gold_before <> v_gold_after THEN
      RAISE EXCEPTION 'podium_gold changed from % to % during partial import', v_gold_before, v_gold_after;
    END IF;

    -- Restore
    PERFORM fn_import_scoring_config(jsonb_build_object('id_season', v_season, 'mp_value', 50));
  END;
  $body$$test215$,
  '2.15 Partial import preserves existing values'
);

-- ---------------------------------------------------------------------------
-- 2.16  Import with invalid type raises exception
-- ---------------------------------------------------------------------------
SELECT throws_ok(
  $test216$SELECT fn_import_scoring_config('{"id_season": 1, "mp_value": "not_a_number"}'::JSONB)$test216$,
  NULL,
  NULL,
  '2.16 Import with invalid type (string for mp_value) raises exception'
);

-- ---------------------------------------------------------------------------
-- 2.17  Import without id_season raises exception
-- ---------------------------------------------------------------------------
SELECT throws_ok(
  $test217$SELECT fn_import_scoring_config('{"mp_value": 50}'::JSONB)$test217$,
  NULL,
  NULL,
  '2.17 Import without id_season raises exception'
);

-- ---------------------------------------------------------------------------
-- 2.18  Import for non-existent season raises exception
-- ---------------------------------------------------------------------------
SELECT throws_ok(
  $test218$SELECT fn_import_scoring_config('{"id_season": 99999}'::JSONB)$test218$,
  NULL,
  NULL,
  '2.18 Import for non-existent season raises exception'
);

-- ---------------------------------------------------------------------------
-- 2.19  PSW tournament uses num_psw_multiplier (2.0)
-- ---------------------------------------------------------------------------
-- Same fencer, same N=24, same place: PPW (mult=1.0) vs PSW (mult=2.0).
-- Components (place_pts, de_bonus, podium_bonus) should be identical.
-- Final scores differ by multiplier (rounding applied at the end).
SELECT ok(
  (SELECT
    ppw.num_place_pts = psw.num_place_pts
    AND ppw.num_de_bonus = psw.num_de_bonus
    AND ppw.num_podium_bonus = psw.num_podium_bonus
    AND psw.num_final_score > ppw.num_final_score
    AND ABS(psw.num_final_score / ppw.num_final_score - 2.0) < 0.01
   FROM
    (SELECT r.* FROM tbl_result r
     JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
     JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
     WHERE t.txt_code = 'SCORE-PPW-N24' AND f.txt_surname = 'ATANASSOW') ppw,
    (SELECT r.* FROM tbl_result r
     JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
     JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
     WHERE t.txt_code = 'SCORE-PSW-N24' AND f.txt_surname = 'ATANASSOW') psw
  ),
  '2.19 PSW has same components as PPW but final_score scaled by 2.0 multiplier'
);

SELECT * FROM finish();
ROLLBACK;
