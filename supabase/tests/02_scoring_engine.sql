-- =============================================================================
-- M2: Scoring Engine, Configuration & Calibration — Acceptance Tests
-- =============================================================================
-- Tests 2.1–2.19 from the POC development plan.
--
-- FOLLOWS THE ACTIVE SEASON (2026-07-19)
-- -----------------------------------------------------------------------------
-- This file used to pin itself to a hardcoded 'SPWS-2024-2025' and score against
-- that season's tbl_scoring_config. Scoring config is per-season and had since
-- diverged: SPWS-2024-2025 sets num_msw_multiplier = 2.0, while the active
-- season sets 1.2. Test 9.85 therefore asserted a multiplier that had not been
-- in force since SPWS-2025-2026, and no test in the repository guarded the live
-- value. The suite was green for the wrong reason.
--
-- The fixture now resolves the ACTIVE season, so these tests always guard the
-- rules actually in force. That deliberately trades one risk for another: a
-- config-following test can silently change meaning when an admin edits scoring
-- config. Two rules keep that from happening quietly:
--
--   1. Test 2.0 below checks that the active season HAS one complete config
--      (a positive MP, podium values in descending order, every multiplier
--      positive, an engine for every type). It pins no value: an admin sets
--      these, and a test that assumed them failed on every change (2026-10-03).
--   2. Every expectation reads the CONFIGURED value through pg_temp.cfg() —
--      MP, podium points, multipliers — never a literal. That checks the thing
--      worth checking, that the engine honours config, and cannot drift.
--
-- PER-TYPE ENGINES (2026-09-28, ADR-103; 2026-09-30, ADR-104)
-- -----------------------------------------------------------------------------
-- The active season assigns its engine per tournament type: PPW and MPW use
-- SPWS_EVF_JOINED_V1_2026_2027 (ADR-104), PEW, PSW and MSW use EVF classic.
-- The joined engine scores a bracket from the category order its tournament
-- stores, so every PPW and MPW fixture below carries one; each is a single
-- category, where the joined engine IS EVF classic from 4 fencers. The EVF
-- mechanics below (place points, DE rounds, podium) are exercised on PEW; the
-- PPW/MPW pair checks the configured coefficient; 2.2 names the joined engine's
-- table for N up to 3.
--
-- Fencers are created by this file (see the convention in
-- doc/handbook/reference/test-and-traceability.html). Do not reintroduce
-- lookups by surname: SELECT ... INTO silently binds the first row when two
-- fencers share a surname, the defect fixed in export_seed.py::fencer_lookup().
-- Scoring itself is placement- and participant-driven — fn_calc_tournament_scores
-- reads no birth year and no season dates — so these fixtures need no particular
-- age, unlike 03_views_api.
-- =============================================================================

BEGIN;
-- Layer 6 (2026-04-30): targeted bypass of trg_assert_result_vcat for
-- legacy test fixtures whose dummy V-cats predate the FATAL invariant
-- guard. Targeted (not session_replication_role) so audit + status-
-- transition triggers stay live.
ALTER TABLE tbl_result DISABLE TRIGGER trg_assert_result_vcat;
SELECT plan(30);

-- ===== SETUP: Create test data for scoring tests =====
-- We use the ACTIVE season and its scoring config (see header).
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
  v_tourn_msw INT;
  v_fencer1 INT;
  v_fencer2 INT;
  v_fencer3 INT;
  v_fencer4 INT;
  v_fencer5 INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE bool_active = TRUE;
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  -- Create test event for scoring
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('SCORE-TEST-EVT', 'Scoring Test Event', v_season, v_org, 'PLANNED');
  SELECT id_event INTO v_event FROM tbl_event WHERE txt_code = 'SCORE-TEST-EVT';

  -- Tournament A: PEW, N=24 (EVF classic; non-power-of-2, c=1)
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count,
    enum_import_status)
  VALUES (v_event, 'SCORE-PEW-N24', 'Test PEW N=24', 'PEW',
    'EPEE', 'M', 'V2', '2024-10-01', 24, 'IMPORTED');

  -- Tournament A2: PPW, N=24 (pairs with MPW for 2.7)
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count,
    enum_import_status)
  VALUES (v_event, 'SCORE-PPW-N24', 'Test PPW N=24', 'PPW',
    'FOIL', 'M', 'V2', '2024-10-01', 24, 'IMPORTED');

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

  -- Tournament D: PEW N=16 (EVF classic; power-of-2, c=0)
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count,
    enum_import_status)
  VALUES (v_event, 'SCORE-PEW-N16', 'Test PEW N=16', 'PEW',
    'SABRE', 'M', 'V2', '2025-01-01', 16, 'IMPORTED');

  -- Tournament E: PSW, N=24 (multiplier read from the active season's config)
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count,
    enum_import_status)
  VALUES (v_event, 'SCORE-PSW-N24', 'Test PSW N=24', 'PSW',
    'EPEE', 'M', 'V2', '2025-02-01', 24, 'IMPORTED');

  -- Tournament F: MSW, N=24 (multiplier read from the active season's config)
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count,
    enum_import_status)
  VALUES (v_event, 'SCORE-MSW-N24', 'Test MSW N=24', 'MSW',
    'EPEE', 'M', 'V2', '2025-03-01', 24, 'IMPORTED');

  SELECT id_tournament INTO v_tourn_ppw FROM tbl_tournament WHERE txt_code = 'SCORE-PEW-N24';
  SELECT id_tournament INTO v_tourn_mpw FROM tbl_tournament WHERE txt_code = 'SCORE-MPW-N24';
  SELECT id_tournament INTO v_tourn_n1  FROM tbl_tournament WHERE txt_code = 'SCORE-PPW-N1';
  SELECT id_tournament INTO v_tourn_n16 FROM tbl_tournament WHERE txt_code = 'SCORE-PEW-N16';
  SELECT id_tournament INTO v_tourn_psw FROM tbl_tournament WHERE txt_code = 'SCORE-PSW-N24';
  SELECT id_tournament INTO v_tourn_msw FROM tbl_tournament WHERE txt_code = 'SCORE-MSW-N24';

  -- Fixture fencers, owned by this file. Scoring is placement-driven, so the
  -- birth year is immaterial here; it is set from the active season's end year
  -- anyway so the rows never sit near a category boundary if this file later
  -- grows a category-aware assertion.
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality,
                          int_birth_year, enum_gender)
  SELECT 'SC-FENCER-' || i, 'Tester', 'PL',
         EXTRACT(YEAR FROM (SELECT dt_end FROM tbl_season WHERE id_season = v_season))::INT - 55,
         'M'
  FROM generate_series(1, 5) AS i;

  SELECT id_fencer INTO v_fencer1 FROM tbl_fencer WHERE txt_surname = 'SC-FENCER-1';
  SELECT id_fencer INTO v_fencer2 FROM tbl_fencer WHERE txt_surname = 'SC-FENCER-2';
  SELECT id_fencer INTO v_fencer3 FROM tbl_fencer WHERE txt_surname = 'SC-FENCER-3';
  SELECT id_fencer INTO v_fencer4 FROM tbl_fencer WHERE txt_surname = 'SC-FENCER-4';
  SELECT id_fencer INTO v_fencer5 FROM tbl_fencer WHERE txt_surname = 'SC-FENCER-5';

  -- Insert results for PEW N=24: places 1,2,3,4,24
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES
    (v_fencer1, v_tourn_ppw, 1),
    (v_fencer2, v_tourn_ppw, 2),
    (v_fencer3, v_tourn_ppw, 3),
    (v_fencer4, v_tourn_ppw, 4),
    (v_fencer5, v_tourn_ppw, 24);


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

  -- Insert results for PSW N=24: places 1,2 (for PSW multiplier comparison with PEW)
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES
    (v_fencer1, v_tourn_psw, 1),
    (v_fencer2, v_tourn_psw, 2);

  -- Insert results for MSW N=24: places 1,2 (for MSW multiplier test)
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES
    (v_fencer1, v_tourn_msw, 1),
    (v_fencer2, v_tourn_msw, 2);
END;
$setup$;

-- The joined engine's category order: one digit per place, all V2 here.
DO $setup_order$
BEGIN
  EXECUTE $$UPDATE tbl_tournament SET txt_joined_order = repeat('2', int_participant_count)
             WHERE txt_code IN ('SCORE-PPW-N24', 'SCORE-MPW-N24', 'SCORE-PPW-N1')$$;
EXCEPTION WHEN undefined_column THEN NULL;  -- before the engine migration: fail by name below
END;
$setup_order$;

-- PPW and MPW N=24, the same five placements.
DO $setup_new$
DECLARE v_t TEXT; v_place INT; v_i INT := 0;
BEGIN
  FOREACH v_t IN ARRAY ARRAY['SCORE-PPW-N24', 'SCORE-MPW-N24'] LOOP
    v_i := 0;
    FOREACH v_place IN ARRAY ARRAY[1, 2, 3, 4, 24] LOOP
      v_i := v_i + 1;
      INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
      SELECT f.id_fencer, t.id_tournament, v_place
        FROM tbl_fencer f, tbl_tournament t
       WHERE f.txt_surname = 'SC-FENCER-' || v_i AND t.txt_code = v_t;
    END LOOP;
  END LOOP;
END;
$setup_new$;

-- ===== RUN SCORING ENGINE =====
-- Score all test tournaments
SELECT fn_calc_tournament_scores(id_tournament) FROM tbl_tournament WHERE txt_code = 'SCORE-PEW-N24';
SELECT fn_calc_tournament_scores(id_tournament) FROM tbl_tournament WHERE txt_code = 'SCORE-PPW-N24';
SELECT fn_calc_tournament_scores(id_tournament) FROM tbl_tournament WHERE txt_code = 'SCORE-MPW-N24';
SELECT fn_calc_tournament_scores(id_tournament) FROM tbl_tournament WHERE txt_code = 'SCORE-PPW-N1';
SELECT fn_calc_tournament_scores(id_tournament) FROM tbl_tournament WHERE txt_code = 'SCORE-PEW-N16';
SELECT fn_calc_tournament_scores(id_tournament) FROM tbl_tournament WHERE txt_code = 'SCORE-PSW-N24';
SELECT fn_calc_tournament_scores(id_tournament) FROM tbl_tournament WHERE txt_code = 'SCORE-MSW-N24';

-- ---------------------------------------------------------------------------
-- 2.0  The active season has one complete scoring config
-- ---------------------------------------------------------------------------
-- The values are an admin's to set (MP, podium points, the per-type
-- multipliers), so nothing here pins them: every expectation below reads them
-- through pg_temp.cfg(). What must hold is that there is exactly one config
-- for the active season and that it is complete, and that every type this file
-- scores resolves to an engine (ADR-097, ADR-104).
CREATE FUNCTION pg_temp.cfg() RETURNS tbl_scoring_config
LANGUAGE sql STABLE AS $$
  SELECT c.* FROM tbl_scoring_config c
    JOIN tbl_season s ON s.id_season = c.id_season
   WHERE s.bool_active
$$;

SELECT is(
  (SELECT COUNT(*)::INT
     FROM tbl_scoring_config c
     JOIN tbl_season s ON s.id_season = c.id_season
    WHERE s.bool_active
      AND c.int_mp_value > 0
      AND c.int_podium_gold >= c.int_podium_silver
      AND c.int_podium_silver >= c.int_podium_bronze
      AND c.int_podium_bronze >= 0
      AND c.num_ppw_multiplier > 0 AND c.num_mpw_multiplier > 0
      AND c.num_pew_multiplier > 0 AND c.num_mew_multiplier > 0
      AND c.num_msw_multiplier > 0 AND c.num_psw_multiplier > 0
      AND c.int_ppw_total_rounds > 0
      AND (SELECT COUNT(fn_get_type_engine(s.id_season, t))
             FROM unnest(ARRAY['MPW','MSW','PEW','PPW','PSW']) t) = 5),
  1,
  '2.0 The active season has one complete scoring config and an engine for every type'
);

-- ---------------------------------------------------------------------------
-- 2.1  fn_calc_tournament_scores: N=24 PEW (EVF classic) → point columns populated
-- ---------------------------------------------------------------------------
-- For N=24, place=1, MP = the season's int_mp_value:
--   PlacePoints = MP (1st place always gets MP)
--   DE_rounds = floor(ln(24)/ln(2)) - ceil(ln(1)/ln(2)) + 1 = 4 - 0 + 1 = 5
--   DE_bonus = 5 rounds × 10 pts/round = 50 (fixed formula, matches Excel "Bonus za rundę = 10")
--   bonus_per_round (podium) = 3 * 24^(1/3) = 3 * 2.8845 = 8.65
--   Podium_bonus = gold * 8.65
--   Final = (MP + 50 + Podium_bonus) * the PEW multiplier
SELECT ok(
  (SELECT num_place_pts IS NOT NULL
      AND num_de_bonus IS NOT NULL
      AND num_podium_bonus IS NOT NULL
      AND num_final_score IS NOT NULL
   FROM tbl_result r
   JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
   WHERE t.txt_code = 'SCORE-PEW-N24' AND f.txt_surname = 'SC-FENCER-1'),
  '2.1 All four point columns populated for scored PEW N=24 tournament'
);

-- 1st place receives the full base, the season's int_mp_value, under EVF
-- classic whatever the size of the field.
SELECT is(
  (SELECT num_place_pts
   FROM tbl_result r
   JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
   WHERE t.txt_code = 'SCORE-PEW-N24' AND f.txt_surname = 'SC-FENCER-1'),
  (pg_temp.cfg()).int_mp_value::NUMERIC(10,2),
  '2.1b 1st place gets the EVF classic base, the configured MP, in place points'
);

-- Last place (24th of 24): MP - (MP-1)*ln(24)/ln(24) = MP - (MP-1) = 1.00,
-- whatever MP is.
SELECT is(
  (SELECT num_place_pts
   FROM tbl_result r
   JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
   WHERE t.txt_code = 'SCORE-PEW-N24' AND f.txt_surname = 'SC-FENCER-5'),
  1.00::NUMERIC,
  '2.1c Last place (24th of 24) gets 1.00 place points'
);

-- ---------------------------------------------------------------------------
-- 2.2  Edge case: N=1 → the walkover, scored by the 2026/2027 table
-- ---------------------------------------------------------------------------
-- Up to three fencers the joined engine scores N − place + 1 (a meeting, not a
-- competition), so a one-competitor bracket earns 1 point where EVF classic
-- gave 50+0+9 = 59 (SS26.HIST.04 pins the classic side). A live case: ADR-066
-- records six of seven FOIL brackets in PPW2-2025-2026 as single-competitor.
-- The table stores its points in num_place_pts; the DE bonus is not used by
-- the table and holds −1.
SELECT is(
  (SELECT num_place_pts
   FROM tbl_result r
   JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   WHERE t.txt_code = 'SCORE-PPW-N1'),
  1.00::NUMERIC,
  '2.2a N=1: the walkover scores 1.00 by the table, not the classic 59'
);

SELECT is(
  (SELECT num_de_bonus
   FROM tbl_result r
   JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   WHERE t.txt_code = 'SCORE-PPW-N1'),
  -1.00::NUMERIC,
  '2.2b N=1: the DE bonus is −1, not used by the table'
);

-- ---------------------------------------------------------------------------
-- 2.3  Edge case: place > N → scoring is REJECTED, not scored as zero
-- ---------------------------------------------------------------------------
-- REVERSED 2026-09-19. This test previously asserted that place 25 in a field
-- of 24 scores 0 place points. A place larger than the field is corrupt data,
-- and zero is the one value that hides it: it sorts to the bottom and reads as
-- an ordinary weak result. Worse, num_podium_bonus was guarded only by
-- WHEN place = 1/2/3 with no place > N check at all, so N=2 with place=3
-- collected a bronze bonus for a place that does not exist in the bracket while
-- its place points correctly collapsed to zero.
--
-- Scoring now raises. Safe to enforce because it was proven so rather than
-- assumed: scripts/check-scoring-migration-preflight.sh found zero violating
-- rows in LOCAL, CERT and PROD on 2026-09-19.
DO $test_place_gt_n$
DECLARE
  v_fencer INT;
  v_tourn INT;
BEGIN
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality)
  VALUES ('TESTOWY', 'Extra', 'PL') RETURNING id_fencer INTO v_fencer;

  SELECT id_tournament INTO v_tourn FROM tbl_tournament WHERE txt_code = 'SCORE-PEW-N24';

  INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
  VALUES (v_fencer, v_tourn, 25);
END;
$test_place_gt_n$;

SELECT throws_like(
  $$SELECT fn_calc_tournament_scores(id_tournament)
      FROM tbl_tournament WHERE txt_code = 'SCORE-PEW-N24'$$,
  '%Invalid scoring input%',
  '2.3 place > N: scoring raises instead of writing a silent zero'
);

-- The raise aborts the whole UPDATE, so no row is left half-scored: 1st place
-- still holds the value the earlier successful run wrote.
SELECT is(
  (SELECT num_place_pts
   FROM tbl_result r
   JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
   WHERE t.txt_code = 'SCORE-PEW-N24' AND f.txt_surname = 'SC-FENCER-1'),
  (pg_temp.cfg()).int_mp_value::NUMERIC(10,2),
  '2.3b a rejected rescore leaves the previously scored rows untouched'
);

-- Remove the corrupt row so the rest of this file scores a valid tournament;
-- 2.10 re-scores SCORE-PEW-N24 and would otherwise inherit the rejection.
DELETE FROM tbl_result r
 USING tbl_fencer f
 WHERE f.id_fencer = r.id_fencer AND f.txt_surname = 'TESTOWY';

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
   WHERE t.txt_code = 'SCORE-PEW-N16' AND f.txt_surname = 'SC-FENCER-1'),
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
   WHERE t.txt_code = 'SCORE-PEW-N24' AND f.txt_surname = 'SC-FENCER-1'),
  50.00::NUMERIC,
  '2.5 Non-power-of-2 N=24: 1st place DE bonus = 5 rounds × 10 = 50'
);

-- ---------------------------------------------------------------------------
-- 2.6  Podium bonus: 1st=gold*bpr, 2nd=silver*bpr, 3rd=bronze*bpr, 4th=0
-- ---------------------------------------------------------------------------
-- bonus_per_round for N=24 = 3 * 24^(1/3) ≈ 8.65; gold, silver and bronze are
-- the season's configured podium points.
SELECT is(
  (SELECT num_podium_bonus
   FROM tbl_result r
   JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
   WHERE t.txt_code = 'SCORE-PEW-N24' AND f.txt_surname = 'SC-FENCER-1'),
  (SELECT ROUND((pg_temp.cfg()).int_podium_gold * (3 * POWER(24, 1.0/3)), 2))::NUMERIC,
  '2.6a 1st place podium bonus = the configured gold points * bonus_per_round'
);

SELECT is(
  (SELECT num_podium_bonus
   FROM tbl_result r
   JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
   WHERE t.txt_code = 'SCORE-PEW-N24' AND f.txt_surname = 'SC-FENCER-2'),
  (SELECT ROUND((pg_temp.cfg()).int_podium_silver * (3 * POWER(24, 1.0/3)), 2))::NUMERIC,
  '2.6b 2nd place podium bonus = the configured silver points * bonus_per_round'
);

SELECT is(
  (SELECT num_podium_bonus
   FROM tbl_result r
   JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
   WHERE t.txt_code = 'SCORE-PEW-N24' AND f.txt_surname = 'SC-FENCER-3'),
  (SELECT ROUND((pg_temp.cfg()).int_podium_bronze * (3 * POWER(24, 1.0/3)), 2))::NUMERIC,
  '2.6c 3rd place podium bonus = the configured bronze points * bonus_per_round'
);

SELECT is(
  (SELECT num_podium_bonus
   FROM tbl_result r
   JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
   WHERE t.txt_code = 'SCORE-PEW-N24' AND f.txt_surname = 'SC-FENCER-4'),
  0.00::NUMERIC,
  '2.6d 4th place gets 0 podium bonus'
);

-- ---------------------------------------------------------------------------
-- 2.7  Multiplier: PPW and MPW each use their configured multiplier
-- ---------------------------------------------------------------------------
-- Same fencer, same N=24, same place: PPW vs MPW. The components (place, DE
-- rounds, podium) should be identical; each final score is the components
-- times its type's configured multiplier (rounding applied at the end). N=24
-- place 1 is EVF classic under every 2026/2027 engine, since 24 is at least 16.
SELECT ok(
  (SELECT
    ppw.num_place_pts = mpw.num_place_pts
    AND ppw.num_de_bonus = mpw.num_de_bonus
    AND ppw.num_podium_bonus = mpw.num_podium_bonus
    AND ppw.num_place_pts = (pg_temp.cfg()).int_mp_value
    AND ppw.num_final_score = ROUND((ppw.num_place_pts + ppw.num_de_bonus + ppw.num_podium_bonus)
                                    * (pg_temp.cfg()).num_ppw_multiplier, 2)
    AND mpw.num_final_score = ROUND((mpw.num_place_pts + mpw.num_de_bonus + mpw.num_podium_bonus)
                                    * (pg_temp.cfg()).num_mpw_multiplier, 2)
   FROM
    (SELECT r.* FROM tbl_result r
     JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
     JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
     WHERE t.txt_code = 'SCORE-PPW-N24' AND f.txt_surname = 'SC-FENCER-1') ppw,
    (SELECT r.* FROM tbl_result r
     JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
     JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
     WHERE t.txt_code = 'SCORE-MPW-N24' AND f.txt_surname = 'SC-FENCER-1') mpw
  ),
  '2.7 MPW has the same components as PPW; each final score uses its configured multiplier'
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
   WHERE t.txt_code = 'SCORE-PEW-N24' AND f.txt_surname = 'SC-FENCER-1'),
  '2.8 ts_points_calc set to recent timestamp after scoring'
);

-- ---------------------------------------------------------------------------
-- 2.9  After scoring: tournament enum_import_status = SCORED
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT enum_import_status::TEXT FROM tbl_tournament WHERE txt_code = 'SCORE-PEW-N24'),
  'SCORED',
  '2.9 Tournament enum_import_status = SCORED after scoring'
);

-- ---------------------------------------------------------------------------
-- 2.10  Scoring reads multiplier from tbl_scoring_config, not tbl_tournament
-- ---------------------------------------------------------------------------
-- Change the cached multiplier on the tournament row (should NOT affect scoring)
UPDATE tbl_tournament SET num_multiplier = 999.0 WHERE txt_code = 'SCORE-PEW-N24';
UPDATE tbl_tournament SET enum_import_status = 'IMPORTED' WHERE txt_code = 'SCORE-PEW-N24';

-- Re-score
SELECT fn_calc_tournament_scores(id_tournament) FROM tbl_tournament WHERE txt_code = 'SCORE-PEW-N24';

-- Final score should still use PEW's configured multiplier, not 999.0
SELECT ok(
  (SELECT r.num_final_score = ROUND(
    (r.num_place_pts + r.num_de_bonus + r.num_podium_bonus) * (pg_temp.cfg()).num_pew_multiplier, 2)
   FROM tbl_result r
   JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
   WHERE t.txt_code = 'SCORE-PEW-N24' AND f.txt_surname = 'SC-FENCER-1'),
  '2.10 Scoring uses the PEW multiplier from tbl_scoring_config, not tbl_tournament (999.0)'
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
  v_mp_before INT;
BEGIN
  SELECT r.num_final_score INTO v_score_before
  FROM tbl_result r
  JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
  JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
  WHERE t.txt_code = 'SCORE-PEW-N24' AND f.txt_surname = 'SC-FENCER-1';

  -- Change MP value in scoring config
  SELECT id_season INTO v_season FROM tbl_season WHERE bool_active = TRUE;
  SELECT int_mp_value INTO v_mp_before FROM tbl_scoring_config WHERE id_season = v_season;
  UPDATE tbl_scoring_config SET int_mp_value = v_mp_before + 50 WHERE id_season = v_season;

  -- Check the score is unchanged (no automatic recalculation)
  SELECT r.num_final_score INTO v_score_after
  FROM tbl_result r
  JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
  JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
  WHERE t.txt_code = 'SCORE-PEW-N24' AND f.txt_surname = 'SC-FENCER-1';

  IF v_score_before <> v_score_after THEN
    RAISE EXCEPTION 'Score changed from % to % after config update', v_score_before, v_score_after;
  END IF;

  -- Restore the MP value it found
  UPDATE tbl_scoring_config SET int_mp_value = v_mp_before WHERE id_season = v_season;
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
       (SELECT id_season FROM tbl_season WHERE bool_active = TRUE)
     ) AS result
   ) sub),
  '2.12 fn_export_scoring_config returns JSON with all 19 parameters + id_season + season_code'
);

-- ---------------------------------------------------------------------------
-- 2.13  Export is idempotent
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT fn_export_scoring_config(id_season) FROM tbl_season WHERE bool_active = TRUE),
  (SELECT fn_export_scoring_config(id_season) FROM tbl_season WHERE bool_active = TRUE),
  '2.13 Export is idempotent: two calls return identical JSON'
);

-- ---------------------------------------------------------------------------
-- 2.14  fn_import_scoring_config: upserts all columns, sets ts_updated
-- ---------------------------------------------------------------------------
-- Uses a fresh scratch season, not `bool_active = TRUE`: by this point in the
-- file, 2.1-2.13 have already scored fixture tournaments in the active
-- season, which now locks its configuration (2026-09-19, governance lock).
-- This test's own subject is fn_import_scoring_config's generic upsert
-- mechanics, orthogonal to the lock -- a scratch season with zero results
-- tests exactly that without colliding with it.
SELECT lives_ok(
  $test214$DO $body$
  DECLARE
    v_season INT;
    v_ts_before TIMESTAMPTZ;
    v_ts_after TIMESTAMPTZ;
  BEGIN
    v_season := fn_create_season('SCORE-2-14', '2036-08-01', '2037-07-15');
    -- Explicitly backdate rather than pg_sleep + compare: pgTAP runs the
    -- whole file in one transaction, and NOW() is frozen for its entire
    -- duration, so a scratch season created in THIS transaction has
    -- ts_updated = NOW() already -- the same frozen value
    -- fn_import_scoring_config's own `ts_updated = NOW()` would produce a
    -- moment later, making "after > before" trivially false regardless of
    -- any pg_sleep. The original test never hit this: it used the seed-
    -- loaded active season, whose ts_updated came from the SEPARATE, earlier-
    -- committed seed transaction. A scratch season needs the same real gap,
    -- forced explicitly since transaction-frozen NOW() cannot provide one.
    UPDATE tbl_scoring_config SET ts_updated = NOW() - INTERVAL '1 hour' WHERE id_season = v_season;
    SELECT ts_updated INTO v_ts_before FROM tbl_scoring_config WHERE id_season = v_season;

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
-- Same fresh-season reasoning as 2.14 above.
SELECT lives_ok(
  $test215$DO $body$
  DECLARE
    v_season INT;
    v_gold_before INT;
    v_gold_after INT;
  BEGIN
    v_season := fn_create_season('SCORE-2-15', '2037-08-01', '2038-07-15');

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
-- 2.19  PSW tournament uses the configured num_psw_multiplier
-- ---------------------------------------------------------------------------
-- Same fencer, same N=24, same place, both EVF classic: PEW (mult=1.0) vs
-- PSW (mult=2.0).
-- Components (place_pts, de_bonus, podium_bonus) should be identical.
-- Final scores differ by multiplier (rounding applied at the end).
SELECT ok(
  (SELECT
    ppw.num_place_pts = psw.num_place_pts
    AND ppw.num_de_bonus = psw.num_de_bonus
    AND ppw.num_podium_bonus = psw.num_podium_bonus
    AND psw.num_final_score > ppw.num_final_score
    AND ABS(psw.num_final_score / ppw.num_final_score
            - (SELECT num_psw_multiplier / num_pew_multiplier FROM tbl_scoring_config c
                 JOIN tbl_season s ON s.id_season = c.id_season
                WHERE s.bool_active)) < 0.01
   FROM
    (SELECT r.* FROM tbl_result r
     JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
     JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
     WHERE t.txt_code = 'SCORE-PEW-N24' AND f.txt_surname = 'SC-FENCER-1') ppw,
    (SELECT r.* FROM tbl_result r
     JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
     JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
     WHERE t.txt_code = 'SCORE-PSW-N24' AND f.txt_surname = 'SC-FENCER-1') psw
  ),
  '2.19 PSW has same components as PEW, final_score scaled by the configured PSW multiplier'
);

-- ---------------------------------------------------------------------------
-- 9.85  MSW tournament: final_score scaled by the configured MSW multiplier
-- ---------------------------------------------------------------------------
SELECT ok(
  (SELECT
    ppw.num_place_pts = msw.num_place_pts
    AND ppw.num_de_bonus = msw.num_de_bonus
    AND ppw.num_podium_bonus = msw.num_podium_bonus
    AND msw.num_final_score > ppw.num_final_score
    AND ABS(msw.num_final_score / ppw.num_final_score
            - (SELECT num_msw_multiplier / num_pew_multiplier FROM tbl_scoring_config c
                 JOIN tbl_season s ON s.id_season = c.id_season
                WHERE s.bool_active)) < 0.01
   FROM
    (SELECT r.* FROM tbl_result r
     JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
     JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
     WHERE t.txt_code = 'SCORE-PEW-N24' AND f.txt_surname = 'SC-FENCER-1') ppw,
    (SELECT r.* FROM tbl_result r
     JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
     JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
     WHERE t.txt_code = 'SCORE-MSW-N24' AND f.txt_surname = 'SC-FENCER-1') msw
  ),
  '9.85 MSW has same components as PEW, final_score scaled by the configured MSW multiplier'
);

-- ---------------------------------------------------------------------------
-- 9.91  Import status: tournament created with IMPORTED status persists
-- ---------------------------------------------------------------------------
-- Create a separate unscored tournament to verify IMPORTED status
SELECT lives_ok(
  $test991$DO $body$
  DECLARE v_event INT; v_season INT; v_org INT;
  BEGIN
    SELECT id_season INTO v_season FROM tbl_season WHERE bool_active = TRUE;
    SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';
    SELECT id_event INTO v_event FROM tbl_event WHERE txt_code = 'SCORE-TEST-EVT';
    INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type,
      enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count,
      enum_import_status)
    VALUES (v_event, 'SCORE-IMPORT-TEST', 'Import Status Test', 'PPW',
      'EPEE', 'M', 'V2', '2025-04-01', 10, 'IMPORTED');
    IF (SELECT enum_import_status FROM tbl_tournament WHERE txt_code = 'SCORE-IMPORT-TEST') <> 'IMPORTED' THEN
      RAISE EXCEPTION 'Expected IMPORTED status';
    END IF;
  END;
  $body$$test991$,
  '9.91 Tournament with enum_import_status = IMPORTED persists correctly'
);

-- ---------------------------------------------------------------------------
-- 9.92  Import status transition: IMPORTED → SCORED after fn_calc_tournament_scores
-- ---------------------------------------------------------------------------
SELECT ok(
  (SELECT enum_import_status = 'SCORED'
   FROM tbl_tournament
   WHERE txt_code = 'SCORE-PEW-N24'),
  '9.92 After fn_calc_tournament_scores, enum_import_status = SCORED'
);

SELECT * FROM finish();
ROLLBACK;
