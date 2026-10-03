-- =============================================================================
-- JB27 — the 2026/2027 SPWS engine: EVF with a joined-bracket premium (ADR-104)
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
-- scored changed. JB27.ENG, CAP, ORD, PRE, TYPE and STORE pin the joined
-- engine: SPWS_EVF_JOINED_V1_2026_2027, the whole-bracket cap in
-- fn_score_joined_bracket, and the category order each tournament stores.
--
-- WHERE THE EXPECTED VALUES COME FROM
-- -----------------------------------------------------------------------------
-- The spec's Part C (doc/plans/joined-scoring-final-spec-2026-09-30.html):
-- seventeen real category line-ups in illustrative finishing orders, with the
-- final score of every place from its reference implementation (A14). The
-- same seventeen are frontend/tests/scoring.test.ts's PART_C. Every value was
-- checked against fn_score_evf_classic_v1_2025_2026's numeric arithmetic on
-- 30 Sep 2026 and agrees to the cent.
--
-- ORDER MATTERS
-- -----------------------------------------------------------------------------
-- Scoring a 2026/2027 result locks that season (ADR-097). CLEAN reads the
-- seeded history before any fixture is scored; ENG and CAP.03 are pure; TYPE,
-- CALC and ORD.01 need 2026/2027 unlocked; the fixtures then score Part C, the
-- RANK line-up and a draft commit, and everything after reads them. Everything
-- rolls back.
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

SELECT plan(43);

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

-- The strategy, called directly with the season's EVF settings (50, 10,
-- 3/2/1): the method, the premium and the one-row total, both rounded as the
-- writer stores them. NULLs when the strategy is missing.
CREATE FUNCTION pg_temp.jb(p_n INT, p_place INT, p_d INT, p_joined BOOLEAN)
RETURNS TABLE (method TEXT, premium NUMERIC, total NUMERIC)
LANGUAGE plpgsql AS $$
DECLARE b RECORD;
BEGIN
  EXECUTE 'SELECT (fn_score_spws_evf_joined_v1_2026_2027($1,$2,$3,$4,50,10,3,2,1)).*'
     INTO b USING p_n, p_place, p_d, p_joined;
  RETURN QUERY SELECT
    b.enum_score_method::TEXT,
    ROUND(b.num_joined_premium, 2),
    ROUND(COALESCE(b.num_place_pts, 0) + COALESCE(b.num_de_bonus, 0)
        + COALESCE(b.num_podium_bonus, 0) + COALESCE(b.num_joined_premium, 0), 2);
EXCEPTION WHEN undefined_function OR undefined_column OR undefined_object THEN
  RETURN QUERY SELECT NULL::TEXT, NULL::NUMERIC, NULL::NUMERIC;
END $$;

-- EVF classic's total for the same (N, place).
CREATE FUNCTION pg_temp.classic_total(p_n INT, p_place INT)
RETURNS NUMERIC LANGUAGE sql AS $$
  SELECT ROUND(c.num_place_pts + c.num_de_bonus + c.num_podium_bonus, 2)
    FROM fn_score_evf_classic_v1_2025_2026(p_n, p_place, 50, 10, 10, 3, 2, 1) c;
$$;

-- TRUE when the statement raises with a message matching the pattern.
CREATE FUNCTION pg_temp.raises_like(p_sql TEXT, p_pattern TEXT)
RETURNS BOOLEAN LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE p_sql;
  RETURN FALSE;
EXCEPTION WHEN OTHERS THEN
  RETURN SQLERRM LIKE p_pattern;
END $$;

-- TRUE when the statement is refused by a CHECK constraint.
CREATE FUNCTION pg_temp.rejects(p_sql TEXT) RETURNS BOOLEAN LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE p_sql;
  RETURN FALSE;
EXCEPTION WHEN check_violation THEN RETURN TRUE;
          WHEN OTHERS THEN RETURN FALSE;
END $$;

-- The eight types and the engine FR-137 assigns to each in 2026/2027.
CREATE FUNCTION pg_temp.expected_2026_2027_engines() RETURNS TEXT LANGUAGE sql AS $$
  SELECT 'MEW=EVF_CLASSIC_V1_2025_2026,MPS=EVF_CLASSIC_V1_2025_2026,'
      || 'MPW=SPWS_EVF_JOINED_V1_2026_2027,MSW=EVF_CLASSIC_V1_2025_2026,'
      || 'PEW=EVF_CLASSIC_V1_2025_2026,PPS=EVF_CLASSIC_V1_2025_2026,'
      || 'PPW=SPWS_EVF_JOINED_V1_2026_2027,PSW=EVF_CLASSIC_V1_2025_2026';
$$;

-- Part C: id, finishing order (category digit per place), type, final scores.
CREATE TEMP TABLE jb27_partc (id TEXT PRIMARY KEY, ord TEXT, ttype TEXT, finals TEXT);
INSERT INTO jb27_partc VALUES
  ('C2A', '343344', 'PPW', '96.35,65.04,35.41,22.09,6.99,2.00'),
  ('C2B', '22222222222323', 'PPW', '111.69,81.59,56.83,44.26,30.12,26.73,23.87,21.39,9.20,7.25,5.48,4.48,2.38,1.38'),
  ('C2C', '2242224', 'MPW', '116.66,76.83,50.26,30.11,11.37,5.86,3.60'),
  ('C2D', '0101101111', 'PPW', '109.39,82.08,53.08,42.52,27.04,21.87,19.59,16.75,4.24,2.00'),
  ('C2E', '30', 'PPW', '2.00,1.00'),
  ('C3A', '1211113121', 'PPW', '109.39,82.08,53.08,40.50,25.75,21.87,20.59,15.75,4.24,1.00'),
  ('C3B', '121321323', 'PPW', '108.72,80.87,51.74,42.99,25.31,20.04,18.60,14.63,3.00'),
  ('C3C', '2120221222222', 'PPW', '122.28,84.91,61.67,43.52,32.18,28.35,23.97,22.30,10.02,8.01,6.19,4.53,3.00'),
  ('C3D', '024024', 'PPW', '96.35,68.14,42.49,22.09,7.99,5.00'),
  ('C3E', '304', 'PPW', '3.00,2.00,1.00'),
  ('C4A', '1013141', 'PPW', '102.08,64.02,39.98,28.86,10.47,8.88,2.00'),
  ('C4B', '010210312', 'MPW', '130.46,97.05,62.09,51.59,30.38,24.05,22.85,17.55,3.60'),
  ('C4C', '2031', 'PPW', '92.72,45.02,18.93,2.00'),
  ('C4D', '22122203222222213', 'PPW', '123.14,93.44,68.71,56.02,42.17,39.01,36.35,34.04,22.00,20.18,18.53,17.02,15.64,14.36,13.16,12.05,1.00'),
  ('C5A', '2102321424', 'PPW', '120.33,82.08,53.08,44.55,29.61,24.06,19.59,18.59,5.24,4.24'),
  ('C5B', '010234', 'PPW', '96.35,65.04,35.41,24.30,8.99,5.00'),
  ('C5C', '01203243', 'MPW', '117.60,82.74,52.95,32.80,18.09,11.73,9.78,4.80');

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
-- for any unknown engine; the dispatcher takes d and the joined flag, never
-- K, m or b.
SELECT throws_like(
  $$SELECT fn_score_by_engine('SPWS_PLACE_MEDAL_V1_2026_2027', 8, 1, 0, FALSE, 50, 10, 3, 2, 1)$$,
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

-- JB27.CLEAN.03a — history is intact: every scored result of a season on the
-- classic engine is EVF_CLASSIC with real place, DE and podium components. Read
-- before any fixture is scored. (SPWS-2026-2027, on the joined engine, holds
-- real scored results since its first promote, 3 Oct 2026.)
SELECT is(
  (SELECT (count(*) > 0 AND count(*) = count(*) FILTER (
             WHERE r.enum_score_method = 'EVF_CLASSIC'
               AND r.num_place_pts >= 0 AND r.num_de_bonus >= 0 AND r.num_podium_bonus >= 0
               AND r.num_final_score IS NOT NULL))::TEXT
     FROM tbl_result r
     JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
     JOIN tbl_event e ON e.id_event = t.id_event
     JOIN tbl_season s ON s.id_season = e.id_season
     JOIN tbl_scoring_engine g ON g.id_engine = s.id_scoring_engine
    WHERE r.ts_points_calc IS NOT NULL AND g.txt_code LIKE 'EVF_CLASSIC%'),
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
-- JB27.ENG — the strategy, one row at a time, without the cap
-- =============================================================================

-- JB27.ENG.01 — a bracket of 1-3 is a meeting: N - place + 1, joined or not.
SELECT is(
  (SELECT string_agg(x.totals, '|' ORDER BY x.n) FROM (
     SELECT n, string_agg(j.total::TEXT || '/' || j.method, ',' ORDER BY p) AS totals
       FROM generate_series(1, 3) n, generate_series(1, 3) p, pg_temp.jb(n, p, 0, FALSE) j
      WHERE p <= n GROUP BY n) x)
  || '#' || (SELECT string_agg(j.total::TEXT, ',' ORDER BY p)
               FROM generate_series(1, 3) p, pg_temp.jb(3, p, 2, TRUE) j),
  '1.00/TABLE|2.00/TABLE,1.00/TABLE|3.00/TABLE,2.00/TABLE,1.00/TABLE#3.00,2.00,1.00',
  'JB27.ENG.01 brackets of 1, 2 and 3 score 1 | 2, 1 | 3, 2, 1 by the table, joined or not');

-- JB27.ENG.02 — a single category of 8 is EVF classic: 98.00 down to 1.00.
SELECT is(
  (SELECT string_agg(j.total::TEXT || '/' || j.method, ',' ORDER BY p)
     FROM generate_series(1, 8) p, pg_temp.jb(8, p, 0, FALSE) j),
  (SELECT string_agg(pg_temp.classic_total(8, p)::TEXT || '/EVF_CLASSIC', ',' ORDER BY p)
     FROM generate_series(1, 8) p),
  'JB27.ENG.02 a single category of 8 scores EVF classic, 98.00 ... 1.00');

-- JB27.ENG.03 — every place of every single-category bracket of 4-15 is EVF
-- classic, to the cent.
SELECT is(
  (SELECT count(*)::INT FROM generate_series(4, 15) n, generate_series(1, 15) p,
          pg_temp.jb(n, p, 0, FALSE) j
    WHERE p <= n
      AND (j.total IS DISTINCT FROM pg_temp.classic_total(n, p)
           OR j.method IS DISTINCT FROM 'EVF_CLASSIC')),
  0,
  'JB27.ENG.03 every single-category place of 4-15 equals EVF classic');

-- JB27.ENG.04 — from 16 a joined bracket is plain EVF too: no premium at any d.
SELECT is(
  (SELECT count(*)::INT FROM (VALUES (16), (17), (20), (32), (64)) v(n),
          generate_series(1, 64) p, generate_series(0, 4) d, pg_temp.jb(v.n, p, d, TRUE) j
    WHERE p <= v.n
      AND (j.total IS DISTINCT FROM pg_temp.classic_total(v.n, p)
           OR j.method IS DISTINCT FROM 'EVF_CLASSIC' OR j.premium IS NOT NULL)),
  0,
  'JB27.ENG.04 a joined bracket of 16 or more scores EVF classic at every d');

-- JB27.ENG.05 — the premium in a joined bracket of 6: at d = 1 place 2 takes
-- EVF x 1.05 (61.95 -> 65.04), place 6 takes EVF + 1 (1.00 -> 2.00); the
-- youngest category (d = 0) is EVF_JOINED with a premium of 0.
SELECT is(
  (SELECT string_agg(j.total || '/' || j.premium || '/' || j.method, ',' ORDER BY x.k)
     FROM (VALUES (1, 2, 1), (2, 6, 1), (3, 1, 0)) x(k, p, d), pg_temp.jb(6, x.p, x.d, TRUE) j),
  '65.04/3.10/EVF_JOINED,2.00/1.00/EVF_JOINED,96.35/0.00/EVF_JOINED',
  'JB27.ENG.05 N = 6, d = 1: 65.04 by 5% and 2.00 by one point; d = 0 adds nothing');

-- JB27.ENG.06 — d outside 0-4, or d > 0 in a single category, raises.
SELECT ok(
  pg_temp.raises_like($$SELECT fn_score_spws_evf_joined_v1_2026_2027(8, 1, -1, TRUE, 50, 10, 3, 2, 1)$$, '%category steps%')
  AND pg_temp.raises_like($$SELECT fn_score_spws_evf_joined_v1_2026_2027(8, 1, 5, TRUE, 50, 10, 3, 2, 1)$$, '%category steps%')
  AND pg_temp.raises_like($$SELECT fn_score_spws_evf_joined_v1_2026_2027(8, 1, 1, FALSE, 50, 10, 3, 2, 1)$$, '%category steps%'),
  'JB27.ENG.06 d of -1 or 5, or d > 0 in a single category, raises');

-- =============================================================================
-- JB27.CAP.03 — the guarantees, over every finishing order of two line-ups
-- =============================================================================
-- V3 3 + V4 3 (20 orders) and V1 3 + V2 3 + V3 3 (1,680 orders), through
-- fn_score_joined_bracket: the youngest category is never capped; everyone
-- scores at least 1 below the fencer directly ahead; and a category of 3 never
-- scores below its own meeting (3, 2, 1 by its own ranks).
CREATE FUNCTION pg_temp.cap_guarantees() RETURNS TEXT
LANGUAGE plpgsql AS $cg$
DECLARE v_orders INT; v_bad TEXT;
BEGIN
  CREATE TEMP TABLE jb27_orders ON COMMIT DROP AS
    SELECT ord FROM (
      SELECT string_agg(CASE WHEN (m >> i) & 1 = 1 THEN '4' ELSE '3' END, '' ORDER BY i) AS ord
        FROM generate_series(0, 63) m, generate_series(0, 5) i GROUP BY m) a
     WHERE length(replace(ord, '3', '')) = 3
    UNION ALL
    SELECT ord FROM (
      SELECT string_agg(((k / (3 ^ i)::INT) % 3 + 1)::TEXT, '' ORDER BY i) AS ord
        FROM generate_series(0, 19682) k, generate_series(0, 8) i GROUP BY k) b
     WHERE length(replace(ord, '1', '')) = 6 AND length(replace(ord, '2', '')) = 6;
  SELECT count(*) INTO v_orders FROM jb27_orders;

  WITH rows AS (
    SELECT o.ord, b.*,
           lag(b.num_capped) OVER (PARTITION BY o.ord ORDER BY b.int_place) AS ahead,
           row_number() OVER (PARTITION BY o.ord, b.int_category ORDER BY b.int_place) AS own_rank,
           count(*)    OVER (PARTITION BY o.ord, b.int_category) AS own_size
      FROM jb27_orders o,
           fn_score_joined_bracket('SPWS_EVF_JOINED_V1_2026_2027', o.ord, 50, 10, 3, 2, 1) b
  )
  SELECT string_agg(DISTINCT ord || ' place ' || int_place, '; ')
    INTO v_bad
    FROM rows
   WHERE (int_category_steps = 0 AND num_cap_reduction <> 0)
      OR (ahead IS NOT NULL AND num_capped > ahead - 1 + 1e-9)
      OR (own_size <= 3 AND num_capped < own_size - own_rank + 1 - 1e-9);

  RETURN v_orders || ' orders; ' || COALESCE(v_bad, 'no violation');
EXCEPTION WHEN undefined_function OR undefined_column OR undefined_object THEN
  RETURN NULL;
END $cg$;

SELECT is(pg_temp.cap_guarantees(), '1700 orders; no violation',
  'JB27.CAP.03 over 1,700 orders the youngest is never capped, everyone is 1 below the fencer ahead, a category of 3 keeps its meeting');

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
-- JB27.TYPE — the joined engine's assignment (2026/2027 still unlocked here)
-- =============================================================================

-- JB27.TYPE.01 — 2026/2027: the default, PPW and MPW on the joined engine, the
-- other six types on EVF classic; the published parameters say the same.
SELECT is(
  pg_temp.safe_text($$
    SELECT e.txt_code || '|' || (
             SELECT string_agg(t || '=' || fn_get_type_engine(s.id_season, t), ',' ORDER BY t)
               FROM unnest(ARRAY['MEW','MPS','MPW','MSW','PEW','PPS','PPW','PSW']) t)
           || '|' || (SELECT string_agg(type_code || '=' || engine_code, ',' ORDER BY type_code)
                        FROM fn_public_scoring_params('SPWS-2026-2027'))
      FROM tbl_season s JOIN tbl_scoring_engine e ON e.id_engine = s.id_scoring_engine
     WHERE s.txt_code = 'SPWS-2026-2027'$$),
  'SPWS_EVF_JOINED_V1_2026_2027|' || pg_temp.expected_2026_2027_engines() || '|' || pg_temp.expected_2026_2027_engines(),
  'JB27.TYPE.01 2026/2027 puts the default, PPW and MPW on the joined engine and the other six on EVF classic');

-- JB27.TYPE.02 — every earlier season stays on EVF classic, every type.
SELECT is(
  (SELECT count(*)::INT FROM tbl_season s,
          unnest(ARRAY['MEW','MPS','MPW','MSW','PEW','PPS','PPW','PSW']) t
    WHERE s.txt_code < 'SPWS-2026-2027'
      AND EXISTS (SELECT 1 FROM tbl_scoring_config c WHERE c.id_season = s.id_season)
      AND fn_get_type_engine(s.id_season, t) <> 'EVF_CLASSIC_V1_2025_2026'),
  0,
  'JB27.TYPE.02 every type of every earlier season stays on EVF classic');

-- JB27.TYPE.04 — export and import round-trip the engine per type; a locked
-- season refuses a change of a type's engine (ADR-097). SPWS-2026-2027 exports
-- its engines; since its first promote (3 Oct 2026) it is locked, so the change
-- lands on an unscored copy of its configuration.
CREATE FUNCTION pg_temp.type_engines_round_trip() RETURNS TEXT
LANGUAGE plpgsql AS $rt$
DECLARE v_open INT; v_locked INT; v_cfg JSONB;
BEGIN
  SELECT id_season INTO v_open   FROM tbl_season WHERE txt_code = 'SPWS-2026-2027';
  SELECT id_season INTO v_locked FROM tbl_season WHERE txt_code = 'SPWS-2025-2026';

  v_cfg := fn_export_scoring_config(v_open);
  INSERT INTO tbl_season (txt_code, dt_start, dt_end)
       VALUES ('SPWS-2095-2096', DATE '2095-09-01', DATE '2096-06-30')
    RETURNING id_season INTO v_open;
  PERFORM fn_import_scoring_config(v_cfg || jsonb_build_object('id_season', v_open));
  IF (SELECT string_agg(key || '=' || value, ',' ORDER BY key)
        FROM jsonb_each_text(v_cfg -> 'type_engines')) IS DISTINCT FROM pg_temp.expected_2026_2027_engines() THEN
    RETURN 'export: ' || COALESCE((v_cfg -> 'type_engines')::TEXT, 'no type_engines');
  END IF;

  PERFORM fn_import_scoring_config(fn_export_scoring_config(v_locked));

  PERFORM fn_import_scoring_config(jsonb_build_object('id_season', v_open,
    'type_engines', jsonb_build_object('MPS', 'SPWS_EVF_JOINED_V1_2026_2027')));
  IF fn_get_type_engine(v_open, 'MPS') <> 'SPWS_EVF_JOINED_V1_2026_2027'
     OR fn_get_type_engine(v_open, 'PPS') <> 'EVF_CLASSIC_V1_2025_2026' THEN
    RETURN 'import did not land on MPS alone';
  END IF;
  PERFORM fn_import_scoring_config(jsonb_build_object('id_season', v_open,
    'type_engines', jsonb_build_object('MPS', 'EVF_CLASSIC_V1_2025_2026')));

  BEGIN
    PERFORM fn_import_scoring_config(jsonb_build_object('id_season', v_locked,
      'type_engines', jsonb_build_object('PPW', 'SPWS_EVF_JOINED_V1_2026_2027')));
    RETURN 'a locked season accepted a change of engine';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%is locked%' THEN RETURN 'locked: ' || SQLERRM; END IF;
  END;
  RETURN 'OK';
EXCEPTION WHEN OTHERS THEN
  RETURN 'ERROR: ' || SQLERRM;
END $rt$;

SELECT is(pg_temp.type_engines_round_trip(), 'OK',
  'JB27.TYPE.04 type_engines round-trip; an unlocked change lands on one type; a locked season refuses it');

-- =============================================================================
-- JB27.ORD.01 — the order's CHECK
-- =============================================================================
-- Digits 0-4 only (0 = V0 ... 4 = V4), exactly one per place of the bracket.
CREATE TEMP TABLE jb27_scratch (id INT);
DO $ord$
DECLARE v_org INT; v_s27 INT; v_e INT; v_t INT;
BEGIN
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';
  SELECT id_season INTO v_s27 FROM tbl_season WHERE txt_code = 'SPWS-2026-2027';
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('PPW94-2026-2027', 'JB27 ORD', v_s27, v_org, 'PLANNED') RETURNING id_event INTO v_e;
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
    enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_e, 'JB27-ORD', 'JB27 ORD', 'PPW', 'FOIL', 'F', 'V1', '2026-10-01', 4, 'IMPORTED')
  RETURNING id_tournament INTO v_t;
  INSERT INTO jb27_scratch VALUES (v_t);
END $ord$;

-- The accepted write is read back inside the same function: a subquery of the
-- asserting statement runs on that statement's snapshot and cannot see it.
CREATE FUNCTION pg_temp.order_stored(p_order TEXT) RETURNS BOOLEAN LANGUAGE plpgsql AS $$
BEGIN
  UPDATE tbl_tournament SET txt_joined_order = p_order WHERE txt_code = 'JB27-ORD';
  RETURN COALESCE((SELECT txt_joined_order = p_order FROM tbl_tournament WHERE txt_code = 'JB27-ORD'), FALSE);
EXCEPTION WHEN OTHERS THEN
  RETURN FALSE;
END $$;

SELECT ok(
  pg_temp.rejects($$UPDATE tbl_tournament SET txt_joined_order = '0125' WHERE txt_code = 'JB27-ORD'$$)
  AND pg_temp.rejects($$UPDATE tbl_tournament SET txt_joined_order = '012' WHERE txt_code = 'JB27-ORD'$$)
  AND pg_temp.rejects($$UPDATE tbl_tournament SET txt_joined_order = '01 2' WHERE txt_code = 'JB27-ORD'$$)
  AND pg_temp.order_stored('0112'),
  'JB27.ORD.01 the order admits only digits 0-4, one per place of the bracket');

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

  -- A PPW bracket of 2, one category: its order is '44'. Set in its own
  -- block, so a schema without the column still leaves the ranking fixture.
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
    enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_e27, 'SE27-N2', 'SE27 N=2', 'PPW', 'FOIL', 'M', 'V4', '2026-10-01', 2, 'IMPORTED')
  RETURNING id_tournament INTO v_t;
  BEGIN
    EXECUTE 'UPDATE tbl_tournament SET txt_joined_order = ''44'' WHERE id_tournament = $1' USING v_t;
  EXCEPTION WHEN undefined_column THEN NULL;
  END;
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

-- Part C through the writer: one event per type, one tournament per category
-- of each order, each carrying the whole order, each scored on its own. A
-- single-category order ('S1', five V2) stands beside them for CAP.02.
DO $pc$
DECLARE
  v_s27 INT; v_org INT; v_ev JSONB := '{}'; v_e INT; r RECORD; v_t INT; v_f INT;
  v_digit TEXT;
BEGIN
  SELECT id_season INTO v_s27 FROM tbl_season WHERE txt_code = 'SPWS-2026-2027';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('PPW95-2026-2027', 'JB27 Part C PPW', v_s27, v_org, 'COMPLETED') RETURNING id_event INTO v_e;
  v_ev := v_ev || jsonb_build_object('PPW', v_e);
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('MPW95-2026-2027', 'JB27 Part C MPW', v_s27, v_org, 'COMPLETED') RETURNING id_event INTO v_e;
  v_ev := v_ev || jsonb_build_object('MPW', v_e);

  INSERT INTO jb27_partc VALUES ('S1', '22222', 'PPW', NULL);

  FOR r IN SELECT * FROM jb27_partc ORDER BY id LOOP
    FOR v_digit IN SELECT DISTINCT substr(r.ord, k, 1) FROM generate_series(1, length(r.ord)) k LOOP
      EXECUTE 'INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon,
                 enum_gender, enum_age_category, dt_tournament, int_participant_count,
                 enum_import_status, txt_joined_order)
               VALUES ($1, $2, $2, $3::enum_tournament_type, ''EPEE'', ''M'',
                       $4::enum_age_category, ''2026-10-10'', $5, ''IMPORTED'', $6)
               RETURNING id_tournament'
         INTO v_t
        USING (v_ev ->> r.ttype)::INT, 'JB27-' || r.id || '-V' || v_digit, r.ttype,
              'V' || v_digit, length(r.ord), r.ord;
      FOR k IN 1..length(r.ord) LOOP
        CONTINUE WHEN substr(r.ord, k, 1) <> v_digit;
        INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality, int_birth_year, enum_gender)
        VALUES ('JB27-' || r.id || '-' || k, 'Test', 'PL', 1970, 'M') RETURNING id_fencer INTO v_f;
        INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES (v_f, v_t, k);
      END LOOP;
    END LOOP;
  END LOOP;
  INSERT INTO se27_fx VALUES ('partc', 'ok');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO se27_fx VALUES ('partc', SQLERRM);
END $pc$;

-- Score each tournament on its own; each failure is recorded by tournament.
CREATE TEMP TABLE jb27_scored (txt_code TEXT PRIMARY KEY, detail TEXT);
DO $sc2$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT id_tournament, txt_code FROM tbl_tournament WHERE txt_code LIKE 'JB27-C%' OR txt_code LIKE 'JB27-S1-%' LOOP
    BEGIN
      PERFORM fn_calc_tournament_scores(r.id_tournament);
      INSERT INTO jb27_scored VALUES (r.txt_code, 'ok');
    EXCEPTION WHEN OTHERS THEN
      INSERT INTO jb27_scored VALUES (r.txt_code, SQLERRM);
    END;
  END LOOP;
END $sc2$;

-- A place's stored row, found by the order's id and the place.
CREATE FUNCTION pg_temp.stored(p_id TEXT, p_place INT)
RETURNS tbl_result LANGUAGE sql AS $$
  SELECT r.* FROM tbl_result r JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   WHERE t.txt_code LIKE 'JB27-' || p_id || '-V%' AND r.int_place = p_place;
$$;

-- =============================================================================
-- JB27.CAP — the whole-bracket cap, through the writer
-- =============================================================================

-- JB27.CAP.01 — all 17 Part C orders store the Part C finals, MPW x 1.2
-- included, each category tournament scored on its own.
SELECT is(
  (SELECT COALESCE(string_agg(p.id || ' stored ' || COALESCE(s.got, 'nothing'), '; ' ORDER BY p.id), 'all 17')
     FROM jb27_partc p
     LEFT JOIN LATERAL (
       SELECT string_agg(to_char(r.num_final_score, 'FM999990.00'), ',' ORDER BY r.int_place) AS got
         FROM tbl_result r JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
        WHERE t.txt_code LIKE 'JB27-' || p.id || '-V%') s ON TRUE
    WHERE p.finals IS NOT NULL AND s.got IS DISTINCT FROM p.finals),
  'all 17',
  'JB27.CAP.01 every Part C order stores its spec finals through fn_calc_tournament_scores');

-- JB27.CAP.02 — the reductions are stored where the cap bites (C2B places 12
-- and 14, C4B place 7) and nowhere it does not apply: a single category, a
-- bracket of 16 or more (C4D) or a meeting (C2E).
SELECT is(
  ROW((pg_temp.stored('C2B', 12)).num_cap_reduction, (pg_temp.stored('C2B', 14)).num_cap_reduction,
      (pg_temp.stored('C4B', 7)).num_cap_reduction,
      (SELECT count(*) FROM tbl_result r JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
        WHERE (t.txt_code LIKE 'JB27-S1-%' OR t.txt_code LIKE 'JB27-C4D-%' OR t.txt_code LIKE 'JB27-C2E-%')
          AND (r.num_cap_reduction <> -1 OR r.num_joined_premium <> -1 OR r.int_category_steps <> -1)))::TEXT,
  ROW(0.38, 0.62, 0.56, 0)::TEXT,
  'JB27.CAP.02 C2B 12 = 0.38, C2B 14 = 0.62, C4B 7 = 0.56; -1 in a single category, from 16 and in a meeting');

-- JB27.CAP.04 — the coefficient multiplies the capped value, and the final
-- rounds once: C4B (MPW) stores ROUND(capped x 1.2, 2) at every place, and
-- place 7 is 22.85, not the uncapped ROUND(raw x 1.2, 2).
SELECT is(
  (SELECT count(*) FILTER (WHERE (pg_temp.stored('C4B', b.int_place)).num_final_score
                                 IS DISTINCT FROM ROUND(b.num_capped * 1.2, 2))::TEXT
          || '|' || max(ROUND(b.num_raw * 1.2, 2)) FILTER (WHERE b.int_place = 7)::TEXT
     FROM fn_score_joined_bracket('SPWS_EVF_JOINED_V1_2026_2027', '010210312', 50, 10, 3, 2, 1) b),
  '0|23.53',
  'JB27.CAP.04 C4B stores ROUND(capped x 1.2, 2) everywhere; place 7 is 22.85, not 23.53');

-- =============================================================================
-- JB27.ORD.02 — the writer needs the order and follows it
-- =============================================================================
CREATE FUNCTION pg_temp.writer_refusals() RETURNS TEXT
LANGUAGE plpgsql AS $wr$
DECLARE v_e INT; v_t INT; v_f INT; v_out TEXT := '';
BEGIN
  SELECT id_event INTO v_e FROM tbl_event WHERE txt_code = 'PPW95-2026-2027';
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year) VALUES ('JB27-ORD2', 'Test', 1970)
  RETURNING id_fencer INTO v_f;

  -- No order: the joined engine cannot score a PPW bracket without one.
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
    enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_e, 'JB27-NOORD', 'JB27 no order', 'PPW', 'SABRE', 'F', 'V2', '2026-10-10', 4, 'IMPORTED')
  RETURNING id_tournament INTO v_t;
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES (v_f, v_t, 1);
  BEGIN
    PERFORM fn_calc_tournament_scores(v_t);
    v_out := v_out || 'no order scored; ';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%category order%' THEN v_out := v_out || 'no order: ' || SQLERRM || '; '; END IF;
  END;

  -- A contradicting order: the V2 tournament's fencer sits where the order says V3.
  EXECUTE 'UPDATE tbl_tournament SET txt_joined_order = ''3222'' WHERE id_tournament = $1' USING v_t;
  BEGIN
    PERFORM fn_calc_tournament_scores(v_t);
    v_out := v_out || 'contradiction scored; ';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%carries category%' THEN v_out := v_out || 'contradiction: ' || SQLERRM || '; '; END IF;
  END;
  RETURN CASE WHEN v_out = '' THEN 'OK' ELSE v_out END;
EXCEPTION WHEN OTHERS THEN
  RETURN 'ERROR: ' || SQLERRM;
END $wr$;

SELECT is(pg_temp.writer_refusals(), 'OK',
  'JB27.ORD.02a the writer refuses a joined-engine bracket with no order, and a row the order places in another category');

-- Sibling tournaments scored one at a time agree with the whole bracket: C3B's
-- three category tournaments hold exactly fn_score_joined_bracket's values.
SELECT is(
  (SELECT count(*)::INT FROM fn_score_joined_bracket('SPWS_EVF_JOINED_V1_2026_2027', '121321323', 50, 10, 3, 2, 1) b
    WHERE (pg_temp.stored('C3B', b.int_place)).num_final_score IS DISTINCT FROM ROUND(b.num_capped, 2)
       OR (pg_temp.stored('C3B', b.int_place)).num_cap_reduction IS DISTINCT FROM ROUND(b.num_cap_reduction, 2)
       OR (pg_temp.stored('C3B', b.int_place)).int_category_steps IS DISTINCT FROM b.int_category_steps),
  0,
  'JB27.ORD.02b C3B''s sibling tournaments, scored separately, agree with fn_score_joined_bracket');

-- =============================================================================
-- JB27.PRE.01 — the preview returns the capped value
-- =============================================================================
SELECT is(
  pg_temp.safe_text($$
    SELECT p.num_final_score || '/' || p.num_cap_reduction || '/' || p.enum_score_method
      FROM tbl_tournament t, fn_preview_tournament_score(t.id_tournament, 7) p
     WHERE t.txt_code = 'JB27-C4B-V3'$$),
  '22.85/0.56/EVF_JOINED',
  'JB27.PRE.01 the preview of C4B place 7 is the capped 22.85, as stored');

-- =============================================================================
-- JB27.STORE — the method, the new components and the draft path
-- =============================================================================

-- JB27.STORE.01 — the methods are TABLE, EVF_CLASSIC and EVF_JOINED, and the
-- new columns exist on the result and tournament tables and their drafts.
SELECT is(
  (SELECT array_to_string(enum_range(NULL::enum_score_method), ',') || '|' ||
          (SELECT count(*) FROM information_schema.columns
            WHERE table_schema = 'public'
              AND ((table_name IN ('tbl_result', 'tbl_result_draft')
                    AND column_name IN ('num_joined_premium', 'num_cap_reduction', 'int_category_steps'))
                OR (table_name IN ('tbl_tournament', 'tbl_tournament_draft')
                    AND column_name = 'txt_joined_order')))),
  'TABLE,EVF_CLASSIC,EVF_JOINED|8',
  'JB27.STORE.01 three methods; d, premium and cap reduction on results and drafts; the order on tournaments and drafts');

-- JB27.STORE.02 — the CHECKs admit only real values or -1, and the components
-- match the method: an EVF_CLASSIC row cannot carry a premium.
SELECT ok(
  pg_temp.rejects($$UPDATE tbl_result SET num_joined_premium = -2 WHERE id_result = (SELECT min(id_result) FROM tbl_result)$$)
  AND pg_temp.rejects($$UPDATE tbl_result SET num_cap_reduction = -0.5 WHERE id_result = (SELECT min(id_result) FROM tbl_result)$$)
  AND pg_temp.rejects($$UPDATE tbl_result SET int_category_steps = -2 WHERE id_result = (SELECT min(id_result) FROM tbl_result)$$)
  AND pg_temp.rejects($$UPDATE tbl_result SET num_joined_premium = 0
                         WHERE id_result = (SELECT min(id_result) FROM tbl_result WHERE enum_score_method = 'EVF_CLASSIC')$$)
  AND pg_temp.rejects($$UPDATE tbl_result SET num_cap_reduction = -1
                         WHERE id_result = (pg_temp.stored('C2B', 12)).id_result$$),
  'JB27.STORE.02 -2, -0.5 and components the method does not use are refused');

-- JB27.STORE.03 — a draft commit carries the order onto the tournament, keeps
-- the joined N, and scores the rows with the new columns.
CREATE FUNCTION pg_temp.draft_commit() RETURNS TEXT
LANGUAGE plpgsql AS $dc$
DECLARE v_e INT; v_run UUID := 'bbbbbbbb-2710-4104-8104-000000000104'; v_td INT; v_f INT; v_out TEXT;
BEGIN
  SELECT id_event INTO v_e FROM tbl_event WHERE txt_code = 'PPW95-2026-2027';
  EXECUTE 'INSERT INTO tbl_tournament_draft (id_event, txt_code, enum_type, enum_weapon, enum_gender,
             enum_age_category, dt_tournament, url_results, int_participant_count, enum_parser_kind,
             txt_source_url_used, txt_run_id, txt_joined_order)
           VALUES ($1, ''JB27-DRAFT-V2'', ''PPW'', ''FOIL'', ''M'', ''V2'', ''2026-10-10'',
                   ''https://test/jb27'', 4, ''FENCINGTIME_XML'', ''https://test/jb27'', $2, ''2322'')
           RETURNING id_tournament_draft' INTO v_td USING v_e, v_run;
  FOR k IN 1..4 LOOP
    CONTINUE WHEN k = 2;
    INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year) VALUES ('JB27-DRAFT-' || k, 'Test', 1970)
    RETURNING id_fencer INTO v_f;
    INSERT INTO tbl_result_draft (id_fencer, id_tournament_draft, int_place, txt_run_id) VALUES (v_f, v_td, k, v_run);
  END LOOP;
  PERFORM fn_commit_event_draft(v_run);
  EXECUTE 'SELECT t.txt_joined_order || ''|'' || t.int_participant_count || ''|'' ||
                  string_agg(r.int_place || '':'' || r.enum_score_method || '':'' || r.int_category_steps
                             || '':'' || r.num_joined_premium || '':'' || r.num_cap_reduction, '','' ORDER BY r.int_place)
             FROM tbl_tournament t JOIN tbl_result r ON r.id_tournament = t.id_tournament
            WHERE t.txt_code = ''JB27-DRAFT-V2''
            GROUP BY t.txt_joined_order, t.int_participant_count' INTO v_out;
  RETURN v_out;
EXCEPTION WHEN OTHERS THEN
  RETURN 'ERROR: ' || SQLERRM;
END $dc$;

SELECT is(pg_temp.draft_commit(),
  '2322|4|1:EVF_JOINED:0:0.00:0.00,3:EVF_JOINED:0:0.00:0.00,4:EVF_JOINED:0:0.00:0.00',
  'JB27.STORE.03 a draft commit keeps the order and the joined N and scores its rows EVF_JOINED');

-- =============================================================================
-- JB27.TYPE.03 — the §11 gate: a scored season is never reassigned
-- =============================================================================
-- 2026/2027 now holds scored results. A type moved off its ADR-104 engine
-- (MPS onto the joined engine, as a direct write) stays where it is when the
-- backfill runs again; the gate only reports it.
CREATE FUNCTION pg_temp.gate_keeps_scored_season() RETURNS TEXT
LANGUAGE plpgsql AS $g$
DECLARE v_s27 INT; v_je INT;
BEGIN
  SELECT id_season INTO v_s27 FROM tbl_season WHERE txt_code = 'SPWS-2026-2027';
  SELECT id_engine INTO v_je FROM tbl_scoring_engine WHERE txt_code = 'SPWS_EVF_JOINED_V1_2026_2027';
  UPDATE tbl_scoring_type_config tc SET id_scoring_engine = v_je
    FROM tbl_scoring_config c WHERE c.id_config = tc.id_config AND c.id_season = v_s27 AND tc.enum_type = 'MPS';
  PERFORM fn_backfill_scoring_engines();
  RETURN fn_get_type_engine(v_s27, 'MPS') || '|' || fn_get_type_engine(v_s27, 'PPW');
EXCEPTION WHEN OTHERS THEN
  RETURN 'ERROR: ' || SQLERRM;
END $g$;

SELECT is(pg_temp.gate_keeps_scored_season(), 'SPWS_EVF_JOINED_V1_2026_2027|SPWS_EVF_JOINED_V1_2026_2027',
  'JB27.TYPE.03 the backfill leaves a scored 2026/2027 as it stands');

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
