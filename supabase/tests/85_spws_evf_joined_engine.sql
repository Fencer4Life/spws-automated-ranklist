-- =============================================================================
-- JB27 — the 2026/2027 SPWS engine: place-and-medal removed (ADR-104)
-- =============================================================================
-- Acceptance IDs for doc/plans/adr-104-joined-engine-implementation-plan-
-- 2026-09-30.html §8, registered in the RTM before the migrations landed.
--
-- This file replaces 83_spws_place_medal_engine.sql, deleted with the engine
-- it pinned. What 83 held that outlives the engine moves here unchanged:
-- SE27.TYPE.01 and .05 (the engine per type), SE27.CALC.02-04 (the published
-- parameters) and SE27.RANK.01-05 (ranking entry through PPW or MPW).
--
-- JB27.CLEAN pins the cleanup migration: the strategy, its registry row, its
-- dispatcher branch and every column it added are gone, and nothing that was
-- scored changed. The engine tests (JB27.ENG, CAP, ORD, PRE, TYPE, STORE) join
-- this file with the engine migration.
--
-- ORDER MATTERS
-- -----------------------------------------------------------------------------
-- Scoring a 2026/2027 result locks that season (ADR-097). CLEAN reads the
-- seeded history before any fixture is scored; TYPE and CALC need 2026/2027
-- unlocked; the RANK fixtures score results last. Everything rolls back.
--
-- RED-SAFE WRAPPERS
-- -----------------------------------------------------------------------------
-- As in 80_season_scoring_contract.sql, helpers catch "undefined object"
-- errors and yield NULL, so a missing object produces named failures instead
-- of aborting the file. They add no arithmetic, so they cannot make a broken
-- migration pass — only a missing one fail cleanly.
-- =============================================================================

BEGIN;

-- Fixtures carry V-cats that do not follow from the dummy birth years; the
-- same targeted bypass 80_season_scoring_contract.sql uses.
ALTER TABLE tbl_result DISABLE TRIGGER trg_assert_result_vcat;

SELECT plan(22);

CREATE FUNCTION pg_temp.safe_bool(p_sql TEXT)
RETURNS BOOLEAN LANGUAGE plpgsql AS $$
DECLARE v BOOLEAN;
BEGIN
  EXECUTE p_sql INTO v;
  RETURN v;
EXCEPTION WHEN undefined_function OR undefined_column OR undefined_table
            OR undefined_object OR invalid_text_representation THEN
  RETURN NULL;
END $$;

CREATE FUNCTION pg_temp.safe_text(p_sql TEXT)
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE v TEXT;
BEGIN
  EXECUTE p_sql INTO v;
  RETURN v;
EXCEPTION WHEN undefined_function OR undefined_column OR undefined_table
            OR undefined_object OR invalid_text_representation THEN
  RETURN NULL;
END $$;

-- The columns the cleanup drops, per table (ADR-104 §1).
CREATE FUNCTION pg_temp.retired_result_columns() RETURNS TEXT[] LANGUAGE sql AS $$
  SELECT ARRAY['int_category_count', 'int_category_place', 'int_below_count',
               'num_field_pts', 'num_below_pts', 'num_medal_bonus'];
$$;

-- =============================================================================
-- JB27.CLEAN — the place-and-medal engine and its columns are gone
-- =============================================================================

-- JB27.CLEAN.01a — the strategy function is gone.
SELECT ok(
  NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
               WHERE n.nspname = 'public'
                 AND p.proname = 'fn_score_spws_place_medal_v1_2026_2027'),
  'JB27.CLEAN.01a fn_score_spws_place_medal_v1_2026_2027 is absent from the catalogue');

-- JB27.CLEAN.01b — its registry row is gone: nothing named it once 2026/2027
-- moved off it (0 results and 0 revisions on every environment, 30 Sep 2026).
SELECT ok(
  NOT EXISTS (SELECT 1 FROM tbl_scoring_engine WHERE txt_code = 'SPWS_PLACE_MEDAL_V1_2026_2027'),
  'JB27.CLEAN.01b SPWS_PLACE_MEDAL_V1_2026_2027 is absent from the engine registry');

-- JB27.CLEAN.01c — the dispatcher has no branch for it and fails closed, as
-- for any unknown engine; the dispatcher no longer takes K, m or b.
SELECT throws_like(
  $$SELECT fn_score_by_engine('SPWS_PLACE_MEDAL_V1_2026_2027', 8, 1, 50, 10, 3, 2, 1)$$,
  '%Unknown scoring engine%',
  'JB27.CLEAN.01c the dispatcher raises Unknown scoring engine for the removed engine');

-- JB27.CLEAN.02a — the six columns are gone from tbl_result and
-- tbl_result_draft; the method column stays.
SELECT is(
  (SELECT string_agg(table_name || '.' || column_name, ',' ORDER BY table_name, column_name)
     FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name IN ('tbl_result', 'tbl_result_draft')
      AND (column_name = ANY (pg_temp.retired_result_columns()) OR column_name = 'enum_score_method')),
  'tbl_result.enum_score_method,tbl_result_draft.enum_score_method',
  'JB27.CLEAN.02a tbl_result and tbl_result_draft keep enum_score_method and none of the six retired columns');

-- JB27.CLEAN.02b — no reader publishes them: vw_score and the rolling
-- functions' result sets.
SELECT is(
  (SELECT count(*)::INT FROM (
     SELECT column_name AS name FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'vw_score'
     UNION ALL
     SELECT unnest(p.proargnames) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public'
        AND p.proname IN ('fn_fencer_scores_rolling', 'fn_fencer_scores_rolling_event_code_matching',
                          'fn_fencer_scores_rolling_event_fk_matching')
   ) c WHERE c.name = ANY (pg_temp.retired_result_columns())),
  0,
  'JB27.CLEAN.02b vw_score and the three rolling functions publish none of the retired columns');

-- JB27.CLEAN.02c — the PZSz review queue no longer keeps b, and its queue RPC
-- is back to five parameters.
SELECT ok(
  NOT EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'public' AND table_name = 'tbl_pzsz_match_review'
                 AND column_name = 'int_below_count')
  AND (SELECT array_agg(p.pronargs) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = 'fn_queue_pzsz_match_review') = ARRAY[5::SMALLINT],
  'JB27.CLEAN.02c tbl_pzsz_match_review has no int_below_count and fn_queue_pzsz_match_review takes five parameters');

-- JB27.CLEAN.02d — the method enum has no PLACE_MEDAL, and the breakdown type
-- keeps none of the three place-and-medal components.
SELECT ok(
  NOT ('PLACE_MEDAL' = ANY (enum_range(NULL::enum_score_method)::TEXT[]))
  AND NOT EXISTS (SELECT 1 FROM pg_attribute a
                   WHERE a.attrelid = (SELECT typrelid FROM pg_type WHERE typname = 'typ_score_breakdown')
                     AND a.attname IN ('num_field_pts', 'num_below_pts', 'num_medal_bonus')
                     AND NOT a.attisdropped),
  'JB27.CLEAN.02d enum_score_method has no PLACE_MEDAL and typ_score_breakdown no field, below or medal component');

-- JB27.CLEAN.03a — history is intact: every scored result is EVF_CLASSIC with
-- real place, DE and podium components. Read before any fixture is scored.
SELECT is(
  (SELECT (count(*) > 0 AND count(*) = count(*) FILTER (
             WHERE r.enum_score_method = 'EVF_CLASSIC'
               AND r.num_place_pts >= 0 AND r.num_de_bonus >= 0 AND r.num_podium_bonus >= 0
               AND r.num_final_score IS NOT NULL))::TEXT
     FROM tbl_result r
    WHERE r.ts_points_calc IS NOT NULL),
  'true',
  'JB27.CLEAN.03a every scored result is EVF_CLASSIC with its place, DE and podium components and a final score');

-- JB27.CLEAN.03b — the rolling functions and vw_score return and are granted
-- as before: anon reads them, because the ranklist holds only the anon key.
SELECT ok(
  COALESCE((SELECT bool_and(has_function_privilege('anon', p.oid, 'EXECUTE')
                            AND has_function_privilege('authenticated', p.oid, 'EXECUTE'))
                   AND count(*) = 3
              FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
             WHERE n.nspname = 'public'
               AND p.proname IN ('fn_fencer_scores_rolling', 'fn_fencer_scores_rolling_event_code_matching',
                                 'fn_fencer_scores_rolling_event_fk_matching')), FALSE)
  AND has_table_privilege('anon', 'vw_score', 'SELECT')
  AND has_table_privilege('authenticated', 'vw_score', 'SELECT'),
  'JB27.CLEAN.03b anon and authenticated execute the three rolling functions and read vw_score');

-- JB27.CLEAN.03c — and they return the stored scores: a scored fencer's rolling
-- rows and vw_score rows carry the stored final score and method.
SELECT ok(
  pg_temp.safe_bool($$
    WITH one AS (
      SELECT r.id_fencer, t.enum_weapon, t.enum_gender, t.enum_age_category, e.id_season
        FROM tbl_result r
        JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
        JOIN tbl_event e      ON e.id_event      = t.id_event
       WHERE r.ts_points_calc IS NOT NULL
       ORDER BY r.id_result LIMIT 1)
    SELECT EXISTS (SELECT 1 FROM one,
                     fn_fencer_scores_rolling(one.id_fencer, one.enum_weapon, one.enum_gender,
                                              one.enum_age_category, one.id_season) rs
                    WHERE rs.num_final_score IS NOT NULL AND rs.enum_score_method = 'EVF_CLASSIC')
       AND EXISTS (SELECT 1 FROM vw_score v
                    WHERE v.num_final_score IS NOT NULL AND v.enum_score_method = 'EVF_CLASSIC')$$),
  'JB27.CLEAN.03c the rolling functions and vw_score return stored final scores with their method');

-- JB27.CLEAN.04 — the cleanup's guard refuses to drop a column that holds a
-- value. It is the function the migration calls on tbl_result,
-- tbl_result_draft and tbl_pzsz_match_review before any DROP; a scratch table
-- stands in for them, because the real columns are gone.
CREATE TEMP TABLE jb27_guard_probe (
  id                 INT PRIMARY KEY,
  int_category_count INT     NOT NULL DEFAULT -1,
  num_medal_bonus    NUMERIC NOT NULL DEFAULT -1
);
INSERT INTO jb27_guard_probe (id) VALUES (1), (2);

SELECT lives_ok(
  $$SELECT fn_assert_retired_columns_unused('pg_temp.jb27_guard_probe'::REGCLASS,
                                            ARRAY['int_category_count', 'num_medal_bonus'])$$,
  'JB27.CLEAN.04a the guard passes when every retired column holds -1');

UPDATE jb27_guard_probe SET int_category_count = 3 WHERE id = 2;
SELECT throws_like(
  $$SELECT fn_assert_retired_columns_unused('pg_temp.jb27_guard_probe'::REGCLASS,
                                            ARRAY['int_category_count', 'num_medal_bonus'])$$,
  '%int_category_count%',
  'JB27.CLEAN.04b the guard aborts, naming the column, when a row holds K = 3');

-- =============================================================================
-- SE27.TYPE / SE27.CALC — moved unchanged from 83 (2026/2027 still unlocked)
-- =============================================================================

-- SE27.TYPE.01 — the type rows carry the engine.
SELECT has_column('public', 'tbl_scoring_type_config', 'id_scoring_engine',
  'SE27.TYPE.01 tbl_scoring_type_config.id_scoring_engine exists');

-- SE27.TYPE.05 — a revision snapshot records the engine of each type. A
-- scratch season's first revision snapshots fn_export_scoring_config.
CREATE FUNCTION pg_temp.snapshot_has_type_engines() RETURNS TEXT
LANGUAGE plpgsql AS $sn$
DECLARE v_season INT; v_snap JSONB;
BEGIN
  v_season := fn_create_season('SE27-SNAPSHOT', '2033-08-01', '2034-07-15');
  UPDATE tbl_season SET id_scoring_engine =
    (SELECT id_engine FROM tbl_scoring_engine WHERE txt_code = 'EVF_CLASSIC_V1_2025_2026')
   WHERE id_season = v_season;
  PERFORM fn_ensure_active_scoring_revision(v_season);
  SELECT json_snapshot INTO v_snap FROM tbl_scoring_config_revision
   WHERE id_season = v_season AND bool_active;
  IF v_snap -> 'type_engines' ->> 'PPW' IS NOT DISTINCT FROM fn_get_type_engine(v_season, 'PPW')
     AND v_snap -> 'type_engines' ->> 'PPW' IS NOT NULL THEN
    RETURN 'OK';
  END IF;
  RETURN 'snapshot: ' || COALESCE((v_snap -> 'type_engines')::TEXT, 'no type_engines');
EXCEPTION WHEN OTHERS THEN
  RETURN 'ERROR: ' || SQLERRM;
END $sn$;

SELECT is(pg_temp.snapshot_has_type_engines(), 'OK',
  'SE27.TYPE.05 a revision snapshot records the engine of each type');

-- SE27.CALC.02 — each row's coefficient is that type's stored multiplier.
SELECT ok(
  pg_temp.safe_bool($$
    SELECT count(*) = 8 AND bool_and(p.multiplier = tc.num_multiplier)
      FROM fn_public_scoring_params('SPWS-2026-2027') p
      JOIN tbl_season s ON s.txt_code = 'SPWS-2026-2027'
      JOIN tbl_scoring_config c ON c.id_season = s.id_season
      JOIN tbl_scoring_type_config tc ON tc.id_config = c.id_config AND tc.enum_type::TEXT = p.type_code$$),
  'SE27.CALC.02 each published coefficient equals the type''s stored multiplier');

-- SE27.CALC.03 — anon may execute it: the pages hold only the anon key.
SELECT ok(
  COALESCE((SELECT has_function_privilege('anon', p.oid, 'EXECUTE')
              FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
             WHERE n.nspname = 'public' AND p.proname = 'fn_public_scoring_params' LIMIT 1), FALSE),
  'SE27.CALC.03 anon holds EXECUTE on fn_public_scoring_params');

-- SE27.CALC.04 — every row publishes the season's EVF settings, which feed
-- every bracket of 4 or more.
SELECT ok(
  pg_temp.safe_bool($$
    SELECT count(*) > 0
       AND bool_and(p.mp_value = c.int_mp_value AND p.de_round = 10
                    AND p.podium_gold = c.int_podium_gold AND p.podium_silver = c.int_podium_silver
                    AND p.podium_bronze = c.int_podium_bronze)
      FROM fn_public_scoring_params('SPWS-2026-2027') p
      JOIN tbl_season s ON s.txt_code = 'SPWS-2026-2027'
      JOIN tbl_scoring_config c ON c.id_season = s.id_season$$),
  'SE27.CALC.04 every row carries the season''s stored EVF settings and DE round 10');

-- =============================================================================
-- FIXTURES — scored results (this locks 2026/2027; everything rolls back)
-- =============================================================================
-- Events are COMPLETED: the 2026/2027 ranking (EVENT_FK_MATCHING) reads events
-- through vw_eligible_event, which hides planned ones. Category in a ranking
-- follows the birth year (fn_age_category against the season's end year), so
-- each ranked fixture fencer's birth year puts them in the category queried.
--
-- Fencers:
--   SE27-11  EVF only: PEW 2026/2027, foil M, b. 1970 (V2 in 2027).
--   SE27-12  a foreigner (CZ) who fenced PPW 2026/2027, foil M V4, b. 1950.
--   SE27-13  PPW 2025/2026 (épée) + PEW 2026/2027 (foil), b. 1970.
--   SE27-14  PPW 2024/2025 (épée) + PEW 2026/2027 (foil), b. 1970.
--   SE27-15  PPW 2025/2026 sabre F V1, b. 1977: V2 in 2027 (§8 ust. 13).
--   SE27-16  filler: the second of the bracket of 2.
CREATE TEMP TABLE se27_fx (fixture TEXT PRIMARY KEY, detail TEXT);

DO $fx$
DECLARE
  v_s27 INT; v_s26 INT; v_s25 INT; v_org INT;
  v_e27 INT; v_pew INT; v_e26 INT; v_e25 INT;
  v_t INT; f INT[] := '{}'; v_id INT;
BEGIN
  SELECT id_season INTO v_s27 FROM tbl_season WHERE txt_code = 'SPWS-2026-2027';
  SELECT id_season INTO v_s26 FROM tbl_season WHERE txt_code = 'SPWS-2025-2026';
  SELECT id_season INTO v_s25 FROM tbl_season WHERE txt_code = 'SPWS-2024-2025';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  FOR i IN 1..16 LOOP
    INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality, int_birth_year, enum_gender)
    VALUES ('SE27-' || i, 'Test', CASE WHEN i = 12 THEN 'CZ' ELSE 'PL' END,
            CASE WHEN i IN (12, 16) THEN 1950 WHEN i = 15 THEN 1977 ELSE 1970 END,
            (CASE WHEN i = 15 THEN 'F' ELSE 'M' END)::enum_gender_type)
    RETURNING id_fencer INTO v_id;
    f := f || v_id;
  END LOOP;

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('PPW98-2026-2027', 'SE27 PPW 2026/27', v_s27, v_org, 'COMPLETED') RETURNING id_event INTO v_e27;
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('PEW98-2026-2027', 'SE27 PEW 2026/27', v_s27, v_org, 'COMPLETED') RETURNING id_event INTO v_pew;
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('PPW97-2025-2026', 'SE27 PPW 2025/26', v_s26, v_org, 'COMPLETED') RETURNING id_event INTO v_e26;
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('PPW96-2024-2025', 'SE27 PPW 2024/25', v_s25, v_org, 'COMPLETED') RETURNING id_event INTO v_e25;

  -- A PPW bracket of 2.
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
    enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_e27, 'SE27-N2', 'SE27 N=2', 'PPW', 'FOIL', 'M', 'V4', '2026-10-01', 2, 'IMPORTED')
  RETURNING id_tournament INTO v_t;
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES (f[12], v_t, 1), (f[16], v_t, 2);

  -- PEW 2026/2027, EVF classic.
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
    enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_pew, 'SE27-PEW', 'SE27 PEW', 'PEW', 'FOIL', 'M', 'V2', '2026-10-05', 10, 'IMPORTED')
  RETURNING id_tournament INTO v_t;
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
  VALUES (f[11], v_t, 1), (f[13], v_t, 2), (f[14], v_t, 3);

  -- PPW 2025/2026: SE27-13 (épée) and SE27-15 (sabre F V1).
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
    enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_e26, 'SE27-PPW26-E', 'SE27 PPW 2025/26 epee', 'PPW', 'EPEE', 'M', 'V2', '2026-03-01', 4, 'IMPORTED')
  RETURNING id_tournament INTO v_t;
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES (f[13], v_t, 1);
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
    enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_e26, 'SE27-PPW26-S', 'SE27 PPW 2025/26 sabre', 'PPW', 'SABRE', 'F', 'V1', '2026-03-01', 4, 'IMPORTED')
  RETURNING id_tournament INTO v_t;
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES (f[15], v_t, 1);

  -- PPW 2024/2025: SE27-14, outside every 2026/2027 window.
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
    enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_e25, 'SE27-PPW25-E', 'SE27 PPW 2024/25 epee', 'PPW', 'EPEE', 'M', 'V2', '2025-03-01', 4, 'IMPORTED')
  RETURNING id_tournament INTO v_t;
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES (f[14], v_t, 1);

  INSERT INTO se27_fx VALUES ('base', 'ok');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO se27_fx VALUES ('base', SQLERRM);
END $fx$;

-- Score every fixture tournament; a failure is recorded, not raised, so the
-- assertions below still report by name.
DO $sc$
BEGIN
  PERFORM fn_calc_tournament_scores(t.id_tournament)
     FROM tbl_tournament t WHERE t.txt_code LIKE 'SE27-%';
  INSERT INTO se27_fx VALUES ('scored', 'ok');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO se27_fx VALUES ('scored', SQLERRM);
END $sc$;

-- =============================================================================
-- SE27.RANK — ranking entry through PPW or MPW (§8 ust. 13–14), moved from 83
-- =============================================================================
CREATE FUNCTION pg_temp.in_ranking(p_fencer TEXT, p_weapon TEXT, p_gender TEXT, p_cat TEXT,
                                   p_rolling BOOLEAN)
RETURNS BOOLEAN LANGUAGE sql AS $$
  SELECT EXISTS (
    SELECT 1 FROM fn_ranking_full(p_weapon::enum_weapon_type, p_gender::enum_gender_type,
                                  p_cat::enum_age_category,
                                  (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027'),
                                  p_rolling) rk
      JOIN tbl_fencer f ON f.id_fencer = rk.id_fencer
     WHERE f.txt_surname = p_fencer);
$$;

-- SE27.RANK.01 — a fencer with only EVF results is absent from 2026/2027.
-- Guarded on the fixture so an absent fixture cannot pass it.
SELECT is(
  ROW((SELECT detail FROM se27_fx WHERE fixture = 'base'),
      pg_temp.in_ranking('SE27-11', 'FOIL', 'M', 'V2', FALSE))::TEXT,
  ROW('ok', FALSE)::TEXT,
  'SE27.RANK.01 a fencer with only EVF results is absent from the 2026/2027 ranking');

-- SE27.RANK.02 — a foreigner who fenced PPW is ranked.
SELECT is(
  pg_temp.in_ranking('SE27-12', 'FOIL', 'M', 'V4', FALSE),
  TRUE,
  'SE27.RANK.02 a foreign PPW participant is ranked');

-- SE27.RANK.03 — a 2025/2026 PPW start, in any weapon, admits a fencer to the
-- rolling 2026/2027 ranking only.
SELECT is(
  ROW(pg_temp.in_ranking('SE27-13', 'FOIL', 'M', 'V2', TRUE),
      pg_temp.in_ranking('SE27-13', 'FOIL', 'M', 'V2', FALSE))::TEXT,
  ROW(TRUE, FALSE)::TEXT,
  'SE27.RANK.03 a 2025/2026 PPW start admits to the rolling 2026/2027 ranking, not the non-rolling one');

-- SE27.RANK.04 — a last PPW start in 2024/2025 admits to neither.
SELECT is(
  ROW((SELECT detail FROM se27_fx WHERE fixture = 'base'),
      pg_temp.in_ranking('SE27-14', 'FOIL', 'M', 'V2', TRUE),
      pg_temp.in_ranking('SE27-14', 'FOIL', 'M', 'V2', FALSE))::TEXT,
  ROW('ok', FALSE, FALSE)::TEXT,
  'SE27.RANK.04 a last PPW start in 2024/2025 admits to neither 2026/2027 ranking');

-- SE27.RANK.05 — §8 ust. 13: a fencer V1 in 2025/2026 and V2 in 2026/2027
-- carries the 2025/2026 points into the V2 ranking. Pins existing behaviour
-- (the ranked season's category decides) on the EVENT_CODE_MATCHING body,
-- which carries by event position; the entry gate must not remove it.
SELECT is(
  (SELECT bool_or(rk.bool_has_carryover AND rk.total_score > 0)
     FROM fn_ranking_full_event_code_matching('SABRE', 'F', 'V2',
            (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027'), TRUE) rk
     JOIN tbl_fencer f ON f.id_fencer = rk.id_fencer
    WHERE f.txt_surname = 'SE27-15'),
  TRUE,
  'SE27.RANK.05 a V1 → V2 move carries the previous season''s points into the V2 ranking');

SELECT * FROM finish();

ROLLBACK;
