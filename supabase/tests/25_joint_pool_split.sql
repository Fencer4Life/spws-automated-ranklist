-- =============================================================================
-- ADR-049 (joint-pool split, 2026-04-30):
-- bool_joint_pool_split column + fn_backfill_joint_pool_split() coverage.
--
-- Tests 25.1-25.2: column + index shape (lock-in for migration
--                  20260430000003_joint_pool_split.sql).
-- Tests 25.3-25.7: backfill function semantics (RED until migration
--                  20260430000004_fn_backfill_joint_pool_split.sql lands).
-- =============================================================================

BEGIN;
SELECT plan(7);


-- ===== 25.1 — column shape =====
SELECT col_type_is(
  'tbl_tournament', 'bool_joint_pool_split', 'boolean',
  '25.1: bool_joint_pool_split is BOOLEAN NOT NULL DEFAULT FALSE'
);


-- ===== 25.2 — partial index exists =====
SELECT is(
  (SELECT COUNT(*)::INT FROM pg_indexes
    WHERE tablename = 'tbl_tournament'
      AND indexname = 'idx_tbl_tournament_joint_split'),
  1,
  '25.2: idx_tbl_tournament_joint_split partial index exists'
);


-- ===== 25.3 — backfill function exists =====
SELECT has_function(
  'fn_backfill_joint_pool_split',
  '25.3: fn_backfill_joint_pool_split() function exists'
);


-- ===== Fixture for 25.4-25.7 =====
-- Two siblings (V0+V1) share url_results = 'https://test/joint' (joint pool).
-- One standalone (V2) has a unique url_results = 'https://test/standalone'.
-- Result rows: 4 V0 fencers in A, 3 V1 fencers in B, 5 V2 fencers in C.
-- Expected after backfill: A.flag=TRUE, B.flag=TRUE, A.count=B.count=7,
-- C unchanged.
DO $fix$
DECLARE
  v_season INT;
  v_org    INT;
  v_event  INT;
  v_tA     INT;
  v_tB     INT;
  v_tC     INT;
  v_f      INT;
  i        INT;
BEGIN
  UPDATE tbl_season SET bool_active = FALSE;
  v_season := fn_create_season('VW-JOINT-25', '2098-09-01', '2099-06-30');
  UPDATE tbl_season SET bool_active = TRUE WHERE id_season = v_season;

  INSERT INTO tbl_organizer (txt_code, txt_name)
       VALUES ('VW25ORG', 'VW Test 25 Org')
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code='VW25ORG';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer,
                         txt_location, dt_start, dt_end, enum_status)
       VALUES ('VW25E', 'VW 25 event', v_season, v_org,
               'TestCity', '2099-03-15', '2099-03-15', 'COMPLETED')
    RETURNING id_event INTO v_event;

  -- A: V0 sibling, joint URL
  INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon,
                              enum_gender, enum_age_category, dt_tournament,
                              url_results, int_participant_count)
       VALUES (v_event, 'VW25E-V0-F-EPEE', 'PPW', 'EPEE', 'F', 'V0', '2099-03-15',
               'https://test/joint', 4)
    RETURNING id_tournament INTO v_tA;

  -- B: V1 sibling, joint URL (same as A)
  INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon,
                              enum_gender, enum_age_category, dt_tournament,
                              url_results, int_participant_count)
       VALUES (v_event, 'VW25E-V1-F-EPEE', 'PPW', 'EPEE', 'F', 'V1', '2099-03-15',
               'https://test/joint', 3)
    RETURNING id_tournament INTO v_tB;

  -- C: V2 standalone, unique URL
  INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon,
                              enum_gender, enum_age_category, dt_tournament,
                              url_results, int_participant_count)
       VALUES (v_event, 'VW25E-V2-F-EPEE', 'PPW', 'EPEE', 'F', 'V2', '2099-03-15',
               'https://test/standalone', 5)
    RETURNING id_tournament INTO v_tC;

  -- 4 V0 fencers in A (BY=2069 → age 30 → V0 in season ending 2099)
  FOR i IN 1..4 LOOP
    INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year)
         VALUES ('JOINT25A', 'F'||i, 2069)
      RETURNING id_fencer INTO v_f;
    INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
         VALUES (v_f, v_tA, i);
  END LOOP;

  -- 3 V1 fencers in B (BY=2059 → age 40 → V1)
  FOR i IN 1..3 LOOP
    INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year)
         VALUES ('JOINT25B', 'F'||i, 2059)
      RETURNING id_fencer INTO v_f;
    INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
         VALUES (v_f, v_tB, i);
  END LOOP;

  -- 5 V2 fencers in C (BY=2049 → age 50 → V2)
  FOR i IN 1..5 LOOP
    INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year)
         VALUES ('JOINT25C', 'F'||i, 2049)
      RETURNING id_fencer INTO v_f;
    INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
         VALUES (v_f, v_tC, i);
  END LOOP;
END;
$fix$;


-- Run the backfill.
SELECT * FROM fn_backfill_joint_pool_split();


-- ===== 25.4 — siblings sharing url_results get flag flipped TRUE =====
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_tournament
    WHERE txt_code IN ('VW25E-V0-F-EPEE', 'VW25E-V1-F-EPEE')
      AND bool_joint_pool_split = TRUE),
  2,
  '25.4: backfill flags both siblings that share url_results'
);


-- ===== 25.5 — siblings get int_participant_count rewritten to full pool size =====
SELECT is(
  (SELECT array_agg(int_participant_count ORDER BY txt_code) FROM tbl_tournament
    WHERE txt_code IN ('VW25E-V0-F-EPEE', 'VW25E-V1-F-EPEE')),
  ARRAY[7, 7],
  '25.5: backfill rewrites int_participant_count to full pool size (4+3=7) on each sibling'
);


-- ===== 25.6 — standalone tournament with unique URL is left untouched =====
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_tournament
    WHERE txt_code = 'VW25E-V2-F-EPEE'
      AND bool_joint_pool_split = FALSE
      AND int_participant_count = 5),
  1,
  '25.6: standalone with unique URL: flag stays FALSE AND count unchanged'
);


-- ===== 25.7 — backfill is idempotent =====
SELECT is(
  (SELECT siblings_flagged FROM fn_backfill_joint_pool_split()),
  0,
  '25.7: backfill is idempotent — second run flags zero new rows'
);


ROLLBACK;
