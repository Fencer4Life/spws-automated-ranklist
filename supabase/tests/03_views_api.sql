-- =============================================================================
-- M5/M6: SQL Views, API & Kadra Ranking — Acceptance Tests
-- =============================================================================
-- Tests 5.1–5.25 from the POC development plan.
-- Uses pre-scored results (num_final_score set directly) to test
-- vw_score, fn_ranking_ppw, and fn_ranking_kadra independently of the
-- scoring engine.
--
-- Category filtering uses fencer's birth-year-derived category (not tournament
-- category). Tests use the active season (SPWS-2025-2026, dt_end=2026-07-15,
-- end year=2026), which keeps test data isolated from real 2024-2025 results.
-- Fencer birth years → categories (end year 2026):
--   ATANASSOW (1969): age 57 → V2
--   BARAŃSKI  (1964): age 62 → V3  (cross-category: results in V2 tournaments)
--   BAZAK     (1974): age 52 → V2
--   DUDEK     (1973): age 53 → V2
--   HAŚKO     (1974): age 52 → V2
--   FORAJTER  (1977): age 49 → V1
-- =============================================================================

BEGIN;
SELECT plan(27);

-- ===== SETUP: Create test tournaments and pre-scored results =====
DO $setup$
DECLARE
  v_season INT;
  v_org INT;
  v_event INT;
  v_ppw1 INT; v_ppw2 INT; v_ppw3 INT; v_ppw4 INT; v_ppw5 INT;
  v_mpw1 INT;
  v_foil1 INT;
  v_fem1 INT;
  v_v1_1 INT;
  v_pew1 INT; v_pew2 INT; v_pew3 INT; v_pew4 INT;
  v_mew1 INT;
  v_fencer_a INT;  -- ATANASSOW (V2)
  v_fencer_b INT;  -- BARAŃSKI  (V3 — cross-category test)
  v_fencer_c INT;  -- BAZAK     (V2)
  v_fencer_d INT;  -- DUDEK     (V2)
  v_fencer_e INT;  -- HAŚKO     (V2 — unscored)
  v_fencer_f INT;  -- FORAJTER  (V1)
  v_fencer_g INT;  -- INTL-ONLY (V2 — international only, no domestic results)
  v_fencer_h INT;  -- ZERO-DOM  (V2 — domestic result with 0 score)
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE bool_active = TRUE;
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  -- Clear pre-loaded tournament data for the test season so tests are isolated.
  -- This runs inside BEGIN...ROLLBACK, so real seed data is restored after tests.
  DELETE FROM tbl_result
  WHERE id_tournament IN (
    SELECT t.id_tournament FROM tbl_tournament t
    JOIN tbl_event e ON t.id_event = e.id_event
    WHERE e.id_season = v_season
  );
  DELETE FROM tbl_tournament
  WHERE id_event IN (SELECT id_event FROM tbl_event WHERE id_season = v_season);
  DELETE FROM tbl_event WHERE id_season = v_season;

  -- Create test event for views
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('VW-TEST-EVT', 'Views Test Event', v_season, v_org, 'COMPLETED');
  SELECT id_event INTO v_event FROM tbl_event WHERE txt_code = 'VW-TEST-EVT';

  -- 5 PPW tournaments (EPEE, M, V2) with SCORED status
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category, dt_tournament,
    int_participant_count, enum_import_status)
  VALUES
    (v_event, 'VW-PPW1', 'Views PPW1', 'PPW', 'EPEE', 'M', 'V2', '2024-09-01', 24, 'SCORED'),
    (v_event, 'VW-PPW2', 'Views PPW2', 'PPW', 'EPEE', 'M', 'V2', '2024-10-01', 24, 'SCORED'),
    (v_event, 'VW-PPW3', 'Views PPW3', 'PPW', 'EPEE', 'M', 'V2', '2024-11-01', 24, 'SCORED'),
    (v_event, 'VW-PPW4', 'Views PPW4', 'PPW', 'EPEE', 'M', 'V2', '2024-12-01', 24, 'SCORED'),
    (v_event, 'VW-PPW5', 'Views PPW5', 'PPW', 'EPEE', 'M', 'V2', '2025-01-01', 24, 'SCORED');

  -- 1 MPW tournament
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category, dt_tournament,
    int_participant_count, enum_import_status)
  VALUES (v_event, 'VW-MPW1', 'Views MPW1', 'MPW', 'EPEE', 'M', 'V2', '2025-02-01', 24, 'SCORED');

  -- FOIL tournament (for filter test 5.8)
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category, dt_tournament,
    int_participant_count, enum_import_status)
  VALUES (v_event, 'VW-FOIL1', 'Views FOIL1', 'PPW', 'FOIL', 'M', 'V2', '2024-09-01', 16, 'SCORED');

  -- Female tournament (for filter test 5.9)
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category, dt_tournament,
    int_participant_count, enum_import_status)
  VALUES (v_event, 'VW-FEM1', 'Views FEM1', 'PPW', 'EPEE', 'F', 'V2', '2024-09-01', 16, 'SCORED');

  -- V1 tournament (for filter test 5.10)
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category, dt_tournament,
    int_participant_count, enum_import_status)
  VALUES (v_event, 'VW-V1-1', 'Views V1-1', 'PPW', 'EPEE', 'M', 'V1', '2024-09-01', 16, 'SCORED');

  -- 4 PEW tournaments (EPEE, M, V2) for Kadra ranking tests
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category, dt_tournament,
    int_participant_count, enum_import_status)
  VALUES
    (v_event, 'VW-PEW1', 'Views PEW1', 'PEW', 'EPEE', 'M', 'V2', '2024-10-15', 48, 'SCORED'),
    (v_event, 'VW-PEW2', 'Views PEW2', 'PEW', 'EPEE', 'M', 'V2', '2025-01-15', 52, 'SCORED'),
    (v_event, 'VW-PEW3', 'Views PEW3', 'PEW', 'EPEE', 'M', 'V2', '2025-03-15', 60, 'SCORED'),
    (v_event, 'VW-PEW4', 'Views PEW4', 'PEW', 'EPEE', 'M', 'V2', '2025-04-15', 55, 'SCORED');

  -- 1 MEW tournament
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category, dt_tournament,
    int_participant_count, enum_import_status)
  VALUES (v_event, 'VW-MEW1', 'Views MEW1', 'MEW', 'EPEE', 'M', 'V2', '2025-05-15', 45, 'SCORED');

  SELECT id_tournament INTO v_pew1 FROM tbl_tournament WHERE txt_code = 'VW-PEW1';
  SELECT id_tournament INTO v_pew2 FROM tbl_tournament WHERE txt_code = 'VW-PEW2';
  SELECT id_tournament INTO v_pew3 FROM tbl_tournament WHERE txt_code = 'VW-PEW3';
  SELECT id_tournament INTO v_pew4 FROM tbl_tournament WHERE txt_code = 'VW-PEW4';
  SELECT id_tournament INTO v_mew1 FROM tbl_tournament WHERE txt_code = 'VW-MEW1';

  SELECT id_tournament INTO v_ppw1 FROM tbl_tournament WHERE txt_code = 'VW-PPW1';
  SELECT id_tournament INTO v_ppw2 FROM tbl_tournament WHERE txt_code = 'VW-PPW2';
  SELECT id_tournament INTO v_ppw3 FROM tbl_tournament WHERE txt_code = 'VW-PPW3';
  SELECT id_tournament INTO v_ppw4 FROM tbl_tournament WHERE txt_code = 'VW-PPW4';
  SELECT id_tournament INTO v_ppw5 FROM tbl_tournament WHERE txt_code = 'VW-PPW5';
  SELECT id_tournament INTO v_mpw1 FROM tbl_tournament WHERE txt_code = 'VW-MPW1';
  SELECT id_tournament INTO v_foil1 FROM tbl_tournament WHERE txt_code = 'VW-FOIL1';
  SELECT id_tournament INTO v_fem1  FROM tbl_tournament WHERE txt_code = 'VW-FEM1';
  SELECT id_tournament INTO v_v1_1  FROM tbl_tournament WHERE txt_code = 'VW-V1-1';

  SELECT id_fencer INTO v_fencer_a FROM tbl_fencer WHERE txt_surname = 'ATANASSOW';
  SELECT id_fencer INTO v_fencer_b FROM tbl_fencer WHERE txt_surname = 'BARAŃSKI' AND txt_first_name = 'Wacław';
  SELECT id_fencer INTO v_fencer_c FROM tbl_fencer WHERE txt_surname = 'BAZAK';
  SELECT id_fencer INTO v_fencer_d FROM tbl_fencer WHERE txt_surname = 'DUDEK';
  SELECT id_fencer INTO v_fencer_e FROM tbl_fencer WHERE txt_surname = 'HAŚKO';
  SELECT id_fencer INTO v_fencer_f FROM tbl_fencer WHERE txt_surname = 'FORAJTER';

  -- -----------------------------------------------------------------------
  -- Fencer A (ATANASSOW, V2): PPW=[100,90,80,70,60], MPW=80
  -- Best 4 PPW = 100+90+80+70=340, worst=70, MPW=80≥70 → include
  -- Total = 340+80 = 420
  -- -----------------------------------------------------------------------
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score, ts_points_calc) VALUES
    (v_fencer_a, v_ppw1, 1, 100.00, NOW()),
    (v_fencer_a, v_ppw2, 1, 90.00,  NOW()),
    (v_fencer_a, v_ppw3, 1, 80.00,  NOW()),
    (v_fencer_a, v_ppw4, 1, 70.00,  NOW()),
    (v_fencer_a, v_ppw5, 1, 60.00,  NOW()),
    (v_fencer_a, v_mpw1, 1, 80.00,  NOW());

  -- -----------------------------------------------------------------------
  -- Fencer B (BARAŃSKI, V3 by birth year): PPW=[95,85,75,65,55], MPW=36
  -- in V2 tournaments — cross-category carryover to V3 ranking
  -- JSONB: best 4 PPW=320 + always MPW=36 → total=356
  -- -----------------------------------------------------------------------
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score, ts_points_calc) VALUES
    (v_fencer_b, v_ppw1, 2, 95.00,  NOW()),
    (v_fencer_b, v_ppw2, 2, 85.00,  NOW()),
    (v_fencer_b, v_ppw3, 2, 75.00,  NOW()),
    (v_fencer_b, v_ppw4, 2, 65.00,  NOW()),
    (v_fencer_b, v_ppw5, 2, 55.00,  NOW()),
    (v_fencer_b, v_mpw1, 2, 36.00,  NOW());

  -- -----------------------------------------------------------------------
  -- Fencer C (BAZAK, V2): only 2 PPW results, no MPW
  -- Total = 50+40 = 90
  -- -----------------------------------------------------------------------
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score, ts_points_calc) VALUES
    (v_fencer_c, v_ppw1, 3, 50.00, NOW()),
    (v_fencer_c, v_ppw2, 3, 40.00, NOW());

  -- -----------------------------------------------------------------------
  -- Fencer D (DUDEK, V2): PPW=[95,85,75,65,55], MPW=36  (same pattern as B)
  -- JSONB: best 4 PPW=320 + always MPW=36 → total=356
  -- Also has FOIL result for weapon filter test 5.8
  -- -----------------------------------------------------------------------
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score, ts_points_calc) VALUES
    (v_fencer_d, v_ppw1, 4, 95.00,  NOW()),
    (v_fencer_d, v_ppw2, 4, 85.00,  NOW()),
    (v_fencer_d, v_ppw3, 4, 75.00,  NOW()),
    (v_fencer_d, v_ppw4, 4, 65.00,  NOW()),
    (v_fencer_d, v_ppw5, 4, 55.00,  NOW()),
    (v_fencer_d, v_mpw1, 4, 36.00,  NOW()),
    (v_fencer_d, v_foil1, 1, 200.00, NOW());

  -- -----------------------------------------------------------------------
  -- Fencer E (HAŚKO, V2): unscored result → should be excluded (5.11)
  -- -----------------------------------------------------------------------
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES
    (v_fencer_e, v_ppw1, 5);

  -- -----------------------------------------------------------------------
  -- Unlinked result (id_fencer=NULL) → international fencer, excluded (5.12)
  -- -----------------------------------------------------------------------
  INSERT INTO tbl_result (id_tournament, int_place, num_final_score, txt_scraped_name, ts_points_calc) VALUES
    (v_ppw1, 6, 110.00, 'MÜLLER Hans', NOW());

  -- -----------------------------------------------------------------------
  -- Female fencer result (for filter test 5.9)
  -- ATANASSOW (V2) in female tournament — tests gender filter works
  -- -----------------------------------------------------------------------
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score, ts_points_calc) VALUES
    (v_fencer_a, v_fem1, 1, 150.00, NOW());

  -- -----------------------------------------------------------------------
  -- V1 fencer result (for filter test 5.10)
  -- FORAJTER (born 1977, age 48 → V1) in V1 tournament
  -- -----------------------------------------------------------------------
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score, ts_points_calc) VALUES
    (v_fencer_f, v_v1_1, 1, 180.00, NOW());

  -- -----------------------------------------------------------------------
  -- International results for Kadra ranking tests
  -- -----------------------------------------------------------------------

  -- Fencer A (ATANASSOW, V2): PEW=[120,100,90,65], MEW=80
  -- JSONB pool {PEW, MEW}: sorted [120,100,90,80,65] → best 3 = 120+100+90=310
  -- ppw_total=420, pew_total=310, kadra total=730
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score, ts_points_calc) VALUES
    (v_fencer_a, v_pew1, 5,  120.00, NOW()),
    (v_fencer_a, v_pew2, 8,  100.00, NOW()),
    (v_fencer_a, v_pew3, 12,  90.00, NOW()),
    (v_fencer_a, v_pew4, 15,  65.00, NOW()),
    (v_fencer_a, v_mew1, 3,   80.00, NOW());

  -- Fencer D (DUDEK, V2): PEW=[110,85], no MEW — domestic-only comparison
  -- JSONB pool {PEW}: best 3 (only 2 available) = 110+85=195
  -- ppw_total=356, pew_total=195, kadra total=551
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score, ts_points_calc) VALUES
    (v_fencer_d, v_pew1, 7,  110.00, NOW()),
    (v_fencer_d, v_pew2, 10,  85.00, NOW());

  -- -----------------------------------------------------------------------
  -- Fencer G (INTL-ONLY, V2): PEW only — no domestic results (5.25)
  -- Should be excluded from both fn_ranking_ppw and fn_ranking_kadra
  -- -----------------------------------------------------------------------
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality, int_birth_year)
  VALUES ('INTL-ONLY', 'Tester', 'PL', 1970)
  RETURNING id_fencer INTO v_fencer_g;

  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score, ts_points_calc) VALUES
    (v_fencer_g, v_pew1, 20, 100.00, NOW()),
    (v_fencer_g, v_pew2, 25,  90.00, NOW());

  -- -----------------------------------------------------------------------
  -- Fencer H (ZERO-DOM, V2): PPW result with 0 score — edge case (5.24)
  -- Should be excluded from fn_ranking_ppw (total_score = 0)
  -- -----------------------------------------------------------------------
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality, int_birth_year)
  VALUES ('ZERO-DOM', 'Tester', 'PL', 1971)
  RETURNING id_fencer INTO v_fencer_h;

  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score, ts_points_calc) VALUES
    (v_fencer_h, v_ppw1, 24, 0.00, NOW());
END;
$setup$;

-- ---------------------------------------------------------------------------
-- 5.1  vw_score: returns one row per fencer per tournament with all columns
-- ---------------------------------------------------------------------------
SELECT ok(
  (SELECT COUNT(*) > 0
   FROM vw_score
   WHERE txt_tournament_code = 'VW-PPW1'),
  '5.1a vw_score returns rows for scored tournaments'
);

SELECT ok(
  (SELECT
    id_fencer IS NOT NULL
    AND fencer_name IS NOT NULL
    AND txt_tournament_code IS NOT NULL
    AND dt_tournament IS NOT NULL
    AND enum_weapon IS NOT NULL
    AND enum_gender IS NOT NULL
    AND enum_age_category IS NOT NULL
    AND enum_type IS NOT NULL
    AND int_place IS NOT NULL
    AND num_final_score IS NOT NULL
    AND txt_season_code IS NOT NULL
   FROM vw_score
   WHERE txt_tournament_code = 'VW-PPW1'
   LIMIT 1),
  '5.1b vw_score has all required columns'
);

-- ---------------------------------------------------------------------------
-- 5.2  fn_ranking_ppw: V2 ranking by fencer birth-year category
-- ---------------------------------------------------------------------------
-- V2 fencers: ATANASSOW(1969), DUDEK(1973), BAZAK(1974)
-- BARAŃSKI(1964) is V3 → excluded from V2 ranking
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_ranking_ppw('EPEE', 'M', 'V2')),
  3,
  '5.2a fn_ranking_ppw returns 3 V2 fencers (ATANASSOW, DUDEK, BAZAK) for active season'
);

-- ---------------------------------------------------------------------------
-- 5.3  fn_ranking_ppw: explicit season returns same results
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT COUNT(*)::INT
   FROM fn_ranking_ppw('EPEE', 'M', 'V2',
     (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'))),
  3,
  '5.3 Explicit season parameter returns same 3 V2 fencers'
);

-- ---------------------------------------------------------------------------
-- 5.4  Best-K selection: with K=4 and 5 PPW scores, only top 4 are summed
-- ---------------------------------------------------------------------------
-- Fencer D (DUDEK, V2): PPW=[95,85,75,65,55], MPW=36
-- JSONB: best 4 PPW bucket = 95+85+75+65=320, MPW always bucket = 36
-- Total = 320+36 = 356 (PPW5=55 is dropped — only top 4 selected by bucket)
SELECT is(
  (SELECT total_score
   FROM fn_ranking_ppw('EPEE', 'M', 'V2')
   WHERE fencer_name = 'DUDEK Mariusz'),
  356.00::NUMERIC,
  '5.4 Best-K: DUDEK total=356 (best 4 PPW=320 + always MPW=36)'
);

-- ---------------------------------------------------------------------------
-- 5.5  MPW always included (JSONB always-bucket): unconditional regardless of score
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT total_score
   FROM fn_ranking_ppw('EPEE', 'M', 'V2')
   WHERE fencer_name = 'ATANASSOW Aleksander'),
  420.00::NUMERIC,
  '5.5 MPW always included (JSONB): ATANASSOW total=420 (best 4 PPW=340 + always MPW=80)'
);

-- ---------------------------------------------------------------------------
-- 5.6  MPW always included (JSONB): even when lower than every PPW score
-- ---------------------------------------------------------------------------
SELECT ok(
  (SELECT total_score = 356.00
   FROM fn_ranking_ppw('EPEE', 'M', 'V2')
   WHERE fencer_name = 'DUDEK Mariusz'),
  '5.6 MPW always included (JSONB): DUDEK total=356 (MPW=36 always counted, PPW5=55 dropped)'
);

-- ---------------------------------------------------------------------------
-- 5.7  Ranking ordered by total descending
-- ---------------------------------------------------------------------------
SELECT ok(
  (SELECT bool_and(total_score >= next_score)
   FROM (
     SELECT total_score,
            LEAD(total_score) OVER (ORDER BY rank) AS next_score
     FROM fn_ranking_ppw('EPEE', 'M', 'V2')
   ) sub
   WHERE next_score IS NOT NULL),
  '5.7 Ranking ordered by total descending'
);

-- Verify ordering: A (420) > D (375) > C (90)
SELECT is(
  (SELECT rank FROM fn_ranking_ppw('EPEE', 'M', 'V2')
   WHERE fencer_name = 'ATANASSOW Aleksander'),
  1,
  '5.7b ATANASSOW is rank 1'
);

-- ---------------------------------------------------------------------------
-- 5.8  Filter by weapon: 'FOIL' excludes EPEE results
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_ranking_ppw('FOIL', 'M', 'V2')),
  1,
  '5.8 Filter by weapon=FOIL returns only DUDEK (1 V2 fencer with FOIL results)'
);

-- ---------------------------------------------------------------------------
-- 5.9  Filter by gender: 'F' excludes male-only results
-- ---------------------------------------------------------------------------
SELECT ok(
  (SELECT COUNT(*)::INT >= 1
   FROM fn_ranking_ppw('EPEE', 'F', 'V2')),
  '5.9 Filter by gender=F returns female tournament results'
);

-- ---------------------------------------------------------------------------
-- 5.10  Filter by category: 'V1' returns fencers whose birth-year category is V1
-- ---------------------------------------------------------------------------
-- FORAJTER (born 1977, age 48 → V1) has results in V1 tournament
SELECT ok(
  (SELECT COUNT(*)::INT >= 1
   FROM fn_ranking_ppw('EPEE', 'M', 'V1')),
  '5.10 Filter by category=V1 returns V1 fencer (FORAJTER)'
);

-- ---------------------------------------------------------------------------
-- 5.11  Only scored results included (num_final_score IS NOT NULL)
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_ranking_ppw('EPEE', 'M', 'V2')
   WHERE fencer_name LIKE 'HAŚKO%'),
  0,
  '5.11 Unscored fencer (HAŚKO) excluded from ranking'
);

-- ---------------------------------------------------------------------------
-- 5.12  Unlinked fencer (NULL id_fencer) not in ranking
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_ranking_ppw('EPEE', 'M', 'V2')
   WHERE fencer_name LIKE 'MÜLLER%'),
  0,
  '5.12 Unlinked result (NULL id_fencer) excluded from ranking'
);

-- ---------------------------------------------------------------------------
-- 5.13  fn_ranking_ppw returns expected column shape
-- ---------------------------------------------------------------------------
SELECT ok(
  (SELECT rank IS NOT NULL AND id_fencer IS NOT NULL AND fencer_name IS NOT NULL AND total_score IS NOT NULL
   FROM fn_ranking_ppw('EPEE', 'M', 'V2')
   LIMIT 1),
  '5.13 fn_ranking_ppw returns expected column shape (rank, id_fencer, fencer_name, total_score)'
);

-- ---------------------------------------------------------------------------
-- 5.14  Cross-category carryover: V3 fencer's V2 tournament results in V3 ranking
-- ---------------------------------------------------------------------------
-- BARAŃSKI (born 1964, age 61 → V3) has results in V2 tournaments.
-- These should appear in V3 ranking (his home category), not V2.
SELECT is(
  (SELECT total_score
   FROM fn_ranking_ppw('EPEE', 'M', 'V3')
   WHERE fencer_name = 'BARAŃSKI Wacław'),
  356.00::NUMERIC,
  '5.14 Cross-category: BARAŃSKI (V3) total=356 from V2 tournament results in V3 ranking'
);

-- ---------------------------------------------------------------------------
-- 5.15  Cross-category exclusion: V3 fencer NOT in V2 ranking
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_ranking_ppw('EPEE', 'M', 'V2')
   WHERE fencer_name = 'BARAŃSKI Wacław'),
  0,
  '5.15 Cross-category: BARAŃSKI (V3 by birth year) does NOT appear in V2 ranking'
);

-- ---------------------------------------------------------------------------
-- 5.16  fn_ranking_ppw returns separate ppw_score and mpw_score columns
-- ---------------------------------------------------------------------------
SELECT ok(
  (SELECT ppw_score IS NOT NULL AND mpw_score IS NOT NULL AND total_score IS NOT NULL
   AND total_score = ppw_score + mpw_score
   FROM fn_ranking_ppw('EPEE', 'M', 'V2')
   WHERE fencer_name = 'ATANASSOW Aleksander'),
  '5.16 fn_ranking_ppw returns ppw_score + mpw_score = total_score'
);

-- ---------------------------------------------------------------------------
-- 5.17  fn_ranking_kadra: correct total (JSONB pool logic) for V2
-- ---------------------------------------------------------------------------
-- ATANASSOW: ppw_total=420, PEW=[120,100,90,65], MEW=80
-- JSONB pool {PEW, MEW}: sorted [120,100,90,80,65] → best 3 = 120+100+90=310
-- pew_total=310, kadra total = 420+310 = 730
SELECT is(
  (SELECT total_score
   FROM fn_ranking_kadra('EPEE', 'M', 'V2')
   WHERE fencer_name = 'ATANASSOW Aleksander'),
  730.00::NUMERIC,
  '5.17 fn_ranking_kadra: ATANASSOW total=730 (ppw_total=420 + pew_total=310)'
);

-- ---------------------------------------------------------------------------
-- 5.18  fn_ranking_kadra returns empty for V0 category
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_ranking_kadra('EPEE', 'M', 'V0')),
  0,
  '5.18 fn_ranking_kadra returns empty for V0 (no EVF equivalent)'
);

-- ---------------------------------------------------------------------------
-- 5.19  fn_ranking_kadra: domestic-only fencer has pew_total=0
-- ---------------------------------------------------------------------------
-- BAZAK has only domestic results (PPW), no PEW/MEW
-- Kadra total should equal PPW total = 90
SELECT is(
  (SELECT total_score
   FROM fn_ranking_kadra('EPEE', 'M', 'V2')
   WHERE fencer_name = 'BAZAK Jacek'),
  90.00::NUMERIC,
  '5.19 fn_ranking_kadra: BAZAK (domestic only) total=90, pew_total=0'
);

-- ---------------------------------------------------------------------------
-- 5.20  fn_ranking_ppw JSONB: ppw_score = sum of best-4 PPW bucket only
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT ppw_score
   FROM fn_ranking_ppw('EPEE', 'M', 'V2')
   WHERE fencer_name = 'ATANASSOW Aleksander'),
  340.00::NUMERIC,
  '5.20 fn_ranking_ppw JSONB: ATANASSOW ppw_score=340 (best 4 PPW: 100+90+80+70)'
);

-- ---------------------------------------------------------------------------
-- 5.21  fn_ranking_ppw JSONB: MPW always-bucket included regardless of score
-- ---------------------------------------------------------------------------
-- DUDEK MPW=36 < worst included PPW=65, but with JSONB "always" bucket it IS included
SELECT is(
  (SELECT mpw_score
   FROM fn_ranking_ppw('EPEE', 'M', 'V2')
   WHERE fencer_name = 'DUDEK Mariusz'),
  36.00::NUMERIC,
  '5.21 fn_ranking_ppw JSONB: DUDEK mpw_score=36 (always-bucket, even though < worst PPW)'
);

-- ---------------------------------------------------------------------------
-- 5.22  fn_ranking_kadra JSONB: pew_total = best 3 from pooled {PEW, MEW}
-- ---------------------------------------------------------------------------
-- ATANASSOW: pool [120,100,90,80,65], best 3 = 120+100+90 = 310
SELECT is(
  (SELECT pew_total
   FROM fn_ranking_kadra('EPEE', 'M', 'V2')
   WHERE fencer_name = 'ATANASSOW Aleksander'),
  310.00::NUMERIC,
  '5.22 fn_ranking_kadra JSONB: ATANASSOW pew_total=310 (best 3 from PEW+MEW pool)'
);

-- ---------------------------------------------------------------------------
-- 5.23  Legacy path (NULL json_ranking_rules): MPW dropped when < worst PPW
-- ---------------------------------------------------------------------------
-- Uses SPWS-2023-2024 season (no season_config.sql → json_ranking_rules=NULL).
-- A temporary fencer with 5 PPW + 1 MPW is inserted in that season.
-- MPW=50 < worst included PPW=70 → legacy logic drops MPW, uses PPW5=60.
-- Expected total = 100+90+80+70+60 = 400 (best 4 PPW + 5th PPW substituted)
DO $setup_legacy$
DECLARE
  v_season_23  INT;
  v_org        INT;
  v_event_23   INT;
  v_fencer_leg INT;
BEGIN
  SELECT id_season INTO v_season_23 FROM tbl_season WHERE txt_code = 'SPWS-2023-2024';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality, int_birth_year)
  VALUES ('LEGACY-TEST', 'Fencer', 'PL', 1969)
  RETURNING id_fencer INTO v_fencer_leg;

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('VW-LEGACY-EVT', 'Legacy Test Event', v_season_23, v_org, 'COMPLETED');
  SELECT id_event INTO v_event_23 FROM tbl_event WHERE txt_code = 'VW-LEGACY-EVT';

  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category, dt_tournament,
    int_participant_count, enum_import_status)
  VALUES
    (v_event_23, 'VW-L-PPW1', 'Legacy PPW1', 'PPW', 'EPEE', 'M', 'V2', '2023-09-01', 24, 'SCORED'),
    (v_event_23, 'VW-L-PPW2', 'Legacy PPW2', 'PPW', 'EPEE', 'M', 'V2', '2023-10-01', 24, 'SCORED'),
    (v_event_23, 'VW-L-PPW3', 'Legacy PPW3', 'PPW', 'EPEE', 'M', 'V2', '2023-11-01', 24, 'SCORED'),
    (v_event_23, 'VW-L-PPW4', 'Legacy PPW4', 'PPW', 'EPEE', 'M', 'V2', '2023-12-01', 24, 'SCORED'),
    (v_event_23, 'VW-L-PPW5', 'Legacy PPW5', 'PPW', 'EPEE', 'M', 'V2', '2024-01-01', 24, 'SCORED'),
    (v_event_23, 'VW-L-MPW1', 'Legacy MPW1', 'MPW', 'EPEE', 'M', 'V2', '2024-02-01', 24, 'SCORED');

  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score, ts_points_calc)
  VALUES
    (v_fencer_leg, (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'VW-L-PPW1'), 1, 100.00, NOW()),
    (v_fencer_leg, (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'VW-L-PPW2'), 1,  90.00, NOW()),
    (v_fencer_leg, (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'VW-L-PPW3'), 1,  80.00, NOW()),
    (v_fencer_leg, (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'VW-L-PPW4'), 1,  70.00, NOW()),
    (v_fencer_leg, (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'VW-L-PPW5'), 1,  60.00, NOW()),
    (v_fencer_leg, (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'VW-L-MPW1'), 1,  50.00, NOW());
END;
$setup_legacy$;

SELECT is(
  (SELECT total_score
   FROM fn_ranking_ppw('EPEE', 'M', 'V2',
     (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024'))
   WHERE fencer_name = 'LEGACY-TEST Fencer'),
  400.00::NUMERIC,
  '5.23 Legacy path (NULL json_ranking_rules): MPW=50 dropped (< worst PPW=70), total=400'
);

-- ---------------------------------------------------------------------------
-- 5.24  fn_ranking_ppw: fencer with total_score = 0 excluded from output
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_ranking_ppw('EPEE', 'M', 'V2')
   WHERE fencer_name = 'ZERO-DOM Tester'),
  0,
  '5.24 fn_ranking_ppw: fencer with total_score=0 excluded from output'
);

-- ---------------------------------------------------------------------------
-- 5.25  fn_ranking_kadra: fencer with only PEW/MEW results (no domestic)
--       does not appear in output
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_ranking_kadra('EPEE', 'M', 'V2')
   WHERE fencer_name = 'INTL-ONLY Tester'),
  0,
  '5.25 fn_ranking_kadra: fencer with only PEW results (no domestic) excluded'
);

SELECT * FROM finish();
ROLLBACK;
