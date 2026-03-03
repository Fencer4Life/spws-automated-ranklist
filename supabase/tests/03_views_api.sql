-- =============================================================================
-- M5: SQL Views & API — Acceptance Tests
-- =============================================================================
-- Tests 5.1–5.13 from the POC development plan.
-- Uses pre-scored results (num_final_score set directly) to test
-- vw_score and fn_ranking_ppw independently of the scoring engine.
-- =============================================================================

BEGIN;
SELECT plan(17);

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
  v_fencer_a INT;  -- ATANASSOW
  v_fencer_b INT;  -- BARAŃSKI
  v_fencer_c INT;  -- BAZAK
  v_fencer_d INT;  -- DUDEK
  v_fencer_e INT;  -- HAŚKO
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

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
  SELECT id_fencer INTO v_fencer_b FROM tbl_fencer WHERE txt_surname = 'BARAŃSKI';
  SELECT id_fencer INTO v_fencer_c FROM tbl_fencer WHERE txt_surname = 'BAZAK';
  SELECT id_fencer INTO v_fencer_d FROM tbl_fencer WHERE txt_surname = 'DUDEK';
  SELECT id_fencer INTO v_fencer_e FROM tbl_fencer WHERE txt_surname = 'HAŚKO';

  -- -----------------------------------------------------------------------
  -- Fencer A (ATANASSOW): PPW=[100,90,80,70,60], MPW=80
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
  -- Fencer B (BARAŃSKI): PPW=[95,85,75,65,55], MPW=36
  -- Best 4 PPW = 95+85+75+65=320, worst=65, MPW=36<65 → drop, use PPW5=55
  -- Total = 320+55 = 375
  -- -----------------------------------------------------------------------
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score, ts_points_calc) VALUES
    (v_fencer_b, v_ppw1, 2, 95.00,  NOW()),
    (v_fencer_b, v_ppw2, 2, 85.00,  NOW()),
    (v_fencer_b, v_ppw3, 2, 75.00,  NOW()),
    (v_fencer_b, v_ppw4, 2, 65.00,  NOW()),
    (v_fencer_b, v_ppw5, 2, 55.00,  NOW()),
    (v_fencer_b, v_mpw1, 2, 36.00,  NOW());

  -- -----------------------------------------------------------------------
  -- Fencer C (BAZAK): only 2 PPW results, no MPW
  -- Total = 50+40 = 90
  -- -----------------------------------------------------------------------
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score, ts_points_calc) VALUES
    (v_fencer_c, v_ppw1, 3, 50.00, NOW()),
    (v_fencer_c, v_ppw2, 3, 40.00, NOW());

  -- -----------------------------------------------------------------------
  -- Fencer D (DUDEK): in FOIL tournament only → should NOT appear in EPEE ranking
  -- -----------------------------------------------------------------------
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score, ts_points_calc) VALUES
    (v_fencer_d, v_foil1, 1, 200.00, NOW());

  -- -----------------------------------------------------------------------
  -- Fencer E (HAŚKO): unscored result → should be excluded (5.11)
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
  -- -----------------------------------------------------------------------
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score, ts_points_calc) VALUES
    (v_fencer_a, v_fem1, 1, 150.00, NOW());

  -- -----------------------------------------------------------------------
  -- V1 result (for filter test 5.10)
  -- -----------------------------------------------------------------------
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score, ts_points_calc) VALUES
    (v_fencer_a, v_v1_1, 1, 180.00, NOW());
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
-- 5.2  fn_ranking_ppw: correct ranking for known test data (NULL=active season)
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_ranking_ppw('EPEE', 'M', 'V2')),
  3,
  '5.2a fn_ranking_ppw returns 3 fencers (A, B, C) for active season'
);

-- ---------------------------------------------------------------------------
-- 5.3  fn_ranking_ppw: explicit season returns same results
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT COUNT(*)::INT
   FROM fn_ranking_ppw('EPEE', 'M', 'V2',
     (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'))),
  3,
  '5.3 Explicit season parameter returns same 3 fencers'
);

-- ---------------------------------------------------------------------------
-- 5.4  Best-K selection: with K=4 and 5 PPW scores, only top 4 are summed
-- ---------------------------------------------------------------------------
-- Fencer B: PPW=[95,85,75,65,55], MPW=36
-- Best 4 PPW = 95+85+75+65 = 320, MPW dropped (36<65), 5th PPW=55 used
-- Total = 320+55 = 375
SELECT is(
  (SELECT total_score
   FROM fn_ranking_ppw('EPEE', 'M', 'V2')
   WHERE fencer_name = 'BARAŃSKI Wacław'),
  375.00::NUMERIC,
  '5.4 Best-K: fencer B total=375 (best 4 PPW + 5th PPW replacing dropped MPW)'
);

-- ---------------------------------------------------------------------------
-- 5.5  MPW included: MPW (80) ≥ worst included PPW (70) → total includes MPW
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT total_score
   FROM fn_ranking_ppw('EPEE', 'M', 'V2')
   WHERE fencer_name = 'ATANASSOW Aleksander'),
  420.00::NUMERIC,
  '5.5 MPW included: fencer A total=420 (best 4 PPW=340 + MPW=80)'
);

-- ---------------------------------------------------------------------------
-- 5.6  MPW dropped: MPW (36) < worst included PPW (65) → use 5th PPW (55)
-- ---------------------------------------------------------------------------
-- Already tested in 5.4 (fencer B). Additional verification:
SELECT ok(
  (SELECT total_score = 375.00
   FROM fn_ranking_ppw('EPEE', 'M', 'V2')
   WHERE fencer_name = 'BARAŃSKI Wacław'),
  '5.6 MPW dropped: fencer B total=375 (MPW=36 < worst PPW=65, replaced by PPW5=55)'
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

-- Verify ordering: A (420) > B (375) > C (90)
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
  '5.8 Filter by weapon=FOIL returns only DUDEK (1 fencer)'
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
-- 5.10  Filter by category: 'V1' excludes V2 results
-- ---------------------------------------------------------------------------
SELECT ok(
  (SELECT COUNT(*)::INT >= 1
   FROM fn_ranking_ppw('EPEE', 'M', 'V1')),
  '5.10 Filter by category=V1 returns V1 tournament results'
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
-- 5.12  International fencer (NULL id_fencer) not in ranking
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_ranking_ppw('EPEE', 'M', 'V2')
   WHERE fencer_name LIKE 'MÜLLER%'),
  0,
  '5.12 International fencer (NULL id_fencer) excluded from ranking'
);

-- ---------------------------------------------------------------------------
-- 5.13  PostgREST RPC endpoint test: verified externally via curl
--        (In pgTAP we verify the function is callable and returns expected shape)
-- ---------------------------------------------------------------------------
SELECT ok(
  (SELECT rank IS NOT NULL AND id_fencer IS NOT NULL AND fencer_name IS NOT NULL AND total_score IS NOT NULL
   FROM fn_ranking_ppw('EPEE', 'M', 'V2')
   LIMIT 1),
  '5.13 fn_ranking_ppw returns expected column shape (rank, id_fencer, fencer_name, total_score)'
);

SELECT * FROM finish();
ROLLBACK;
