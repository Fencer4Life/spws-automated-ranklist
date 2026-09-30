-- =============================================================================
-- Remove the 2026/2027 place-and-medal engine and everything only it used
-- =============================================================================
-- ADR-104 §1. doc/plans/adr-104-joined-engine-implementation-plan-2026-09-30.html
-- step 4. Flips JB27.CLEAN.01-04 in supabase/tests/85_spws_evf_joined_engine.sql
-- and the re-pointed assertions in 02, 80, 81 and 82 from RED to GREEN.
--
-- SPWS_PLACE_MEDAL_V1_2026_2027 (ADR-103, 20260928000001) was released on
-- 28 September 2026 and never scored a result. On 30 September 2026 LOCAL,
-- CERT and PROD held no 2026/2027 result, no revision naming it, and -1
-- ("not used") in every column below. The joined engine replaces it in the
-- next migration; this one removes it first, so the new engine is introduced
-- onto a schema that carries nothing it does not use.
--
-- WHAT GOES
--
--   1. The strategy fn_score_spws_place_medal_v1_2026_2027, its dispatcher
--      branch and its registry row.
--   2. tbl_result and tbl_result_draft: int_category_count, int_category_place,
--      int_below_count (K, m, b), num_field_pts, num_below_pts and
--      num_medal_bonus, with their CHECKs.
--   3. tbl_pzsz_match_review.int_below_count and the sixth parameter of
--      fn_queue_pzsz_match_review, which returns to ADR-100's five.
--   4. The PLACE_MEDAL value of enum_score_method and the three matching fields
--      of typ_score_breakdown.
--   5. The same columns from every reader: vw_score, the three rolling
--      functions, the ingest RPC, the draft commit, the writer and the preview.
--
-- WHAT STAYS (the joined engine reuses it)
--
--   The per-type engine assignment and its governance, the joined-bracket
--   module column and both module names, enum_score_method itself (TABLE and
--   EVF_CLASSIC), the PPW/MPW ranking entry gate and fn_public_scoring_params.
--
-- THE INTERIM
--
--   SPWS-2026-2027's default, PPW and MPW move to EVF classic, the only
--   engine left, while the season holds no scored result. The engine
--   migration that follows moves them to the joined engine in the same deploy.
--
-- GUARDS — this migration changes nothing unless all of them hold
--
--   * no result or draft row was scored PLACE_MEDAL, no scored result belongs
--     to a type assigned the engine, and no revision names it;
--   * every column to drop holds only -1 (fn_assert_retired_columns_unused,
--     kept so the guard itself is tested: JB27.CLEAN.04).
--
-- BOOTSTRAP ORDER (ADR-036 amendment)
--
--   `supabase db reset` applies migrations before the seed dump, so on LOCAL
--   and in CI this runs against empty tables. supabase/seed_post_backfill.sql
--   calls fn_backfill_scoring_engines() again once the seed has loaded.
-- =============================================================================

SET LOCAL lock_timeout = '2s';

-- =============================================================================
-- 1 · Guards
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_assert_retired_columns_unused(p_table REGCLASS, p_columns TEXT[])
RETURNS VOID
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_column TEXT;
  v_rows   BIGINT;
  v_found  TEXT := '';
BEGIN
  FOREACH v_column IN ARRAY p_columns LOOP
    EXECUTE format('SELECT count(*) FROM %s WHERE %I IS DISTINCT FROM -1', p_table, v_column)
       INTO v_rows;
    IF v_rows > 0 THEN
      v_found := v_found || format('%s.%s holds a value in %s row(s); ', p_table, v_column, v_rows);
    END IF;
  END LOOP;

  IF v_found <> '' THEN
    RAISE EXCEPTION 'Refusing to drop retired columns: %', v_found
      USING HINT = 'ADR-104 §1: a retired column must hold only -1 ("not used"). '
                   'Values scored by the removed engine are moved by a privileged revision first.';
  END IF;
END;
$$;

COMMENT ON FUNCTION fn_assert_retired_columns_unused(REGCLASS, TEXT[]) IS
  'Raises, naming each column, when any row of the table holds a value other '
  'than -1 in a column about to be dropped (ADR-104 §1). The cleanup migration '
  'calls it before every DROP; JB27.CLEAN.04 tests it on a scratch table.';

DO $$
DECLARE
  v_pm      INT;
  v_blocked TEXT;
BEGIN
  SELECT id_engine INTO v_pm FROM tbl_scoring_engine WHERE txt_code = 'SPWS_PLACE_MEDAL_V1_2026_2027';

  IF EXISTS (SELECT 1 FROM tbl_result       WHERE enum_score_method::TEXT = 'PLACE_MEDAL')
     OR EXISTS (SELECT 1 FROM tbl_result_draft WHERE enum_score_method::TEXT = 'PLACE_MEDAL') THEN
    RAISE EXCEPTION
      'Cannot remove SPWS_PLACE_MEDAL_V1_2026_2027: results were scored PLACE_MEDAL. '
      'Move them by a privileged revision (fn_revise_and_rescore_season) first.';
  END IF;

  IF v_pm IS NULL THEN
    RETURN;
  END IF;

  SELECT string_agg(DISTINCT s.txt_code || '/' || t.enum_type::TEXT, ', ')
    INTO v_blocked
    FROM tbl_result r
    JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
    JOIN tbl_event e      ON e.id_event      = t.id_event
    JOIN tbl_season s     ON s.id_season     = e.id_season
    JOIN tbl_scoring_config c        ON c.id_season = s.id_season
    JOIN tbl_scoring_type_config tc  ON tc.id_config = c.id_config AND tc.enum_type = t.enum_type
   WHERE r.ts_points_calc IS NOT NULL
     AND COALESCE(tc.id_scoring_engine, s.id_scoring_engine) = v_pm;

  IF v_blocked IS NOT NULL THEN
    RAISE EXCEPTION
      'Cannot remove SPWS_PLACE_MEDAL_V1_2026_2027: % scored results under it. '
      'Move them by a privileged revision (fn_revise_and_rescore_season) first.', v_blocked;
  END IF;

  IF EXISTS (SELECT 1 FROM tbl_scoring_config_revision rv
              WHERE rv.id_engine = v_pm
                 OR rv.json_snapshot::TEXT LIKE '%SPWS_PLACE_MEDAL_V1_2026_2027%') THEN
    RAISE EXCEPTION
      'Cannot remove SPWS_PLACE_MEDAL_V1_2026_2027: a scoring revision names it.';
  END IF;
END $$;

SELECT fn_assert_retired_columns_unused('tbl_result'::REGCLASS,
                                        ARRAY['int_category_count', 'int_category_place', 'int_below_count',
                                        'num_field_pts', 'num_below_pts', 'num_medal_bonus']);
SELECT fn_assert_retired_columns_unused('tbl_result_draft'::REGCLASS,
                                        ARRAY['int_category_count', 'int_category_place', 'int_below_count',
                                        'num_field_pts', 'num_below_pts', 'num_medal_bonus']);
SELECT fn_assert_retired_columns_unused('tbl_pzsz_match_review'::REGCLASS,
                                        ARRAY['int_below_count']);

-- =============================================================================
-- 2 · The interim assignment, then the registry row
-- =============================================================================
-- Whatever named the engine moves to EVF classic: SPWS-2026-2027's default and
-- its PPW and MPW rows. The guards above proved none of them scored anything.
DO $$
DECLARE
  v_pm      INT;
  v_classic INT;
BEGIN
  SELECT id_engine INTO v_pm      FROM tbl_scoring_engine WHERE txt_code = 'SPWS_PLACE_MEDAL_V1_2026_2027';
  SELECT id_engine INTO v_classic FROM tbl_scoring_engine WHERE txt_code = 'EVF_CLASSIC_V1_2025_2026';
  IF v_pm IS NULL THEN
    RETURN;
  END IF;

  UPDATE tbl_scoring_type_config
     SET id_scoring_engine = v_classic, ts_updated = NOW()
   WHERE id_scoring_engine = v_pm;
  UPDATE tbl_season
     SET id_scoring_engine = v_classic
   WHERE id_scoring_engine = v_pm;

  DELETE FROM tbl_scoring_engine WHERE id_engine = v_pm;
END $$;

-- =============================================================================
-- 3 · Drop what reads or returns the retired columns and types
-- =============================================================================
DROP VIEW IF EXISTS vw_score;
DROP FUNCTION IF EXISTS fn_fencer_scores_rolling(integer, enum_weapon_type, enum_gender_type, enum_age_category, integer);
DROP FUNCTION IF EXISTS fn_fencer_scores_rolling_event_code_matching(integer, enum_weapon_type, enum_gender_type, enum_age_category, integer);
DROP FUNCTION IF EXISTS fn_fencer_scores_rolling_event_fk_matching(integer, enum_weapon_type, enum_gender_type, enum_age_category, integer);
DROP FUNCTION IF EXISTS fn_preview_tournament_score(INT, INT);
DROP FUNCTION IF EXISTS fn_score_by_engine(
  TEXT, INT, INT, INT, INT, INT, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC);
DROP FUNCTION IF EXISTS fn_score_spws_place_medal_v1_2026_2027(
  INT, INT, INT, INT, INT, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC);
DROP FUNCTION IF EXISTS fn_queue_pzsz_match_review(INT, TEXT, INT, INT, NUMERIC, INT);

-- =============================================================================
-- 4 · Drop the columns and their CHECKs; the method enum without PLACE_MEDAL
-- =============================================================================
-- Postgres cannot drop an enum value, so the type is rebuilt and swapped in,
-- in the same statement that drops each table's columns: one rewrite per
-- table. The breakdown composite names the enum and is rebuilt after it; the
-- only functions that returned it were dropped in §3.
DROP TYPE IF EXISTS typ_score_breakdown;
CREATE TYPE enum_score_method_v2 AS ENUM ('TABLE', 'EVF_CLASSIC');

ALTER TABLE tbl_result
  DROP CONSTRAINT IF EXISTS chk_result_components_match_method,
  DROP CONSTRAINT IF EXISTS chk_result_category_count,
  DROP CONSTRAINT IF EXISTS chk_result_category_place,
  DROP CONSTRAINT IF EXISTS chk_result_category_place_within_count,
  DROP CONSTRAINT IF EXISTS chk_result_below_count,
  DROP CONSTRAINT IF EXISTS chk_result_field_pts,
  DROP CONSTRAINT IF EXISTS chk_result_below_pts,
  DROP CONSTRAINT IF EXISTS chk_result_medal_bonus,
  DROP COLUMN IF EXISTS int_category_count,
  DROP COLUMN IF EXISTS int_category_place,
  DROP COLUMN IF EXISTS int_below_count,
  DROP COLUMN IF EXISTS num_field_pts,
  DROP COLUMN IF EXISTS num_below_pts,
  DROP COLUMN IF EXISTS num_medal_bonus,
  ALTER COLUMN enum_score_method TYPE enum_score_method_v2
    USING enum_score_method::TEXT::enum_score_method_v2;

ALTER TABLE tbl_result_draft
  DROP COLUMN IF EXISTS int_category_count,
  DROP COLUMN IF EXISTS int_category_place,
  DROP COLUMN IF EXISTS int_below_count,
  DROP COLUMN IF EXISTS num_field_pts,
  DROP COLUMN IF EXISTS num_below_pts,
  DROP COLUMN IF EXISTS num_medal_bonus,
  ALTER COLUMN enum_score_method TYPE enum_score_method_v2
    USING enum_score_method::TEXT::enum_score_method_v2;

ALTER TABLE tbl_pzsz_match_review
  DROP CONSTRAINT IF EXISTS chk_pzsz_review_below_count,
  DROP COLUMN IF EXISTS int_below_count;

-- =============================================================================
-- 5 · The breakdown without the place-and-medal fields
-- =============================================================================
DROP TYPE enum_score_method;
ALTER TYPE enum_score_method_v2 RENAME TO enum_score_method;

CREATE TYPE typ_score_breakdown AS (
  num_place_pts     NUMERIC,
  num_de_bonus      NUMERIC,
  num_podium_bonus  NUMERIC,
  enum_score_method enum_score_method
);

COMMENT ON TYPE enum_score_method IS
  'The range of an engine that scored a result: TABLE (N <= 3) or '
  'EVF_CLASSIC. NULL on a result means it has not been scored yet.';
COMMENT ON TYPE typ_score_breakdown IS
  'What every strategy returns: the raw, unrounded components and the method. '
  'A component the method does not use is NULL here; the writer stores it as '
  '-1. The final score is the non-NULL components summed, multiplied by the '
  'type coefficient and rounded once.';
COMMENT ON COLUMN tbl_result.enum_score_method IS
  'The range that scored the row. NULL until scored, like ts_points_calc. '
  'Under TABLE the points are in num_place_pts.';

-- -1 exactly where the method does not use a component.
ALTER TABLE tbl_result
  ADD CONSTRAINT chk_result_components_match_method
  CHECK (enum_score_method IS NULL
    OR enum_score_method = 'EVF_CLASSIC'
    OR (enum_score_method = 'TABLE'
        AND num_de_bonus = -1 AND num_podium_bonus = -1));

COMMENT ON COLUMN tbl_scoring_engine.txt_joined_bracket_module IS
  'The joined-bracket module paired with this engine (ADR-103 §4, ADR-104): '
  'PER_CATEGORY_RENUMBER splits a joined bracket per category and renumbers '
  '(ADR-049); JOINED_BRACKET_CATEGORY_PLACE keeps the joined place and N. '
  'A display name, never executed.';

-- =============================================================================
-- 6 · The dispatcher, the writer and the preview
-- =============================================================================
-- The dispatcher is back to the scoring inputs every engine reads: N, place
-- and the season's EVF settings. Adding an engine adds a branch here and a
-- new strategy; it never edits an existing strategy.
CREATE FUNCTION fn_score_by_engine(
  p_engine_code   TEXT,
  p_n             INT,
  p_place         INT,
  p_mp_value      NUMERIC,
  p_de_round      NUMERIC,
  p_podium_gold   NUMERIC,
  p_podium_silver NUMERIC,
  p_podium_bronze NUMERIC
)
RETURNS typ_score_breakdown
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_out     typ_score_breakdown;
  v_classic typ_score_components;
BEGIN
  CASE p_engine_code
    WHEN 'EVF_CLASSIC_V1_2025_2026' THEN
      v_classic := fn_score_evf_classic_v1_2025_2026(
        p_n, p_place, p_mp_value, 10, p_de_round,
        p_podium_gold, p_podium_silver, p_podium_bronze);
      v_out.num_place_pts     := v_classic.num_place_pts;
      v_out.num_de_bonus      := v_classic.num_de_bonus;
      v_out.num_podium_bonus  := v_classic.num_podium_bonus;
      v_out.enum_score_method := 'EVF_CLASSIC';
      RETURN v_out;
    ELSE
      RAISE EXCEPTION 'Unknown scoring engine: %', p_engine_code;
  END CASE;
END;
$$;

COMMENT ON FUNCTION fn_score_by_engine(TEXT, INT, INT, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC) IS
  'Static dispatcher over released scoring strategies (ADR-042/ADR-045 '
  'precedent). Adding an engine edits THIS function and adds a new strategy; '
  'it never edits an existing strategy. An unknown code raises.';

CREATE OR REPLACE FUNCTION fn_calc_tournament_scores(p_tournament_id INT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  p RECORD;
  v_season   INT;
  v_revision INT;
BEGIN
  SELECT * INTO p FROM fn_resolve_scoring_params(p_tournament_id);

  SELECT e.id_season INTO v_season
    FROM tbl_tournament t JOIN tbl_event e ON e.id_event = t.id_event
   WHERE t.id_tournament = p_tournament_id;

  v_revision := fn_ensure_active_scoring_revision(v_season);

  UPDATE tbl_result r
     SET num_place_pts     = COALESCE(ROUND(c.num_place_pts, 2),    -1),
         num_de_bonus      = COALESCE(ROUND(c.num_de_bonus, 2),     -1),
         num_podium_bonus  = COALESCE(ROUND(c.num_podium_bonus, 2), -1),
         enum_score_method = c.enum_score_method,
         -- Rounded ONCE, from the raw terms. An unused component is NULL in
         -- the breakdown and adds nothing; -1 is never summed.
         num_final_score   = ROUND(
           (COALESCE(c.num_place_pts, 0) + COALESCE(c.num_de_bonus, 0)
            + COALESCE(c.num_podium_bonus, 0))
           * p.multiplier, 2),
         ts_points_calc      = NOW(),
         id_scoring_revision = v_revision
    FROM (
      SELECT r2.id_result, (x.comp).*
        FROM tbl_result r2
        CROSS JOIN LATERAL (
          SELECT fn_score_by_engine(
                   p.engine_code, p.n, r2.int_place,
                   p.mp_value, p.de_round,
                   p.podium_gold, p.podium_silver, p.podium_bronze) AS comp
        ) x
       WHERE r2.id_tournament = p_tournament_id
    ) c
   WHERE r.id_result = c.id_result;

  UPDATE tbl_tournament
     SET enum_import_status = 'SCORED',
         ts_updated = NOW()
   WHERE id_tournament = p_tournament_id;
END;
$$;

COMMENT ON FUNCTION fn_calc_tournament_scores(INT) IS
  'The stable transactional scoring writer. Resolves the engine of the '
  'tournament''s type and dispatches; holds no formula of its own. Stores every '
  'component, -1 where the method does not use it, and the method itself.';

CREATE FUNCTION fn_preview_tournament_score(p_tournament_id INT, p_place INT)
RETURNS TABLE (
  txt_engine_code   TEXT,
  num_place_pts     NUMERIC,
  num_de_bonus      NUMERIC,
  num_podium_bonus  NUMERIC,
  enum_score_method TEXT,
  num_final_score   NUMERIC
)
LANGUAGE plpgsql
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  p RECORD;
  c typ_score_breakdown;
BEGIN
  SELECT * INTO p FROM fn_resolve_scoring_params(p_tournament_id);

  c := fn_score_by_engine(p.engine_code, p.n, p_place,
                          p.mp_value, p.de_round,
                          p.podium_gold, p.podium_silver, p.podium_bronze);

  RETURN QUERY SELECT
    p.engine_code,
    COALESCE(ROUND(c.num_place_pts, 2),    -1),
    COALESCE(ROUND(c.num_de_bonus, 2),     -1),
    COALESCE(ROUND(c.num_podium_bonus, 2), -1),
    c.enum_score_method::TEXT,
    ROUND((COALESCE(c.num_place_pts, 0) + COALESCE(c.num_de_bonus, 0)
           + COALESCE(c.num_podium_bonus, 0))
          * p.multiplier, 2);
END;
$$;

COMMENT ON FUNCTION fn_preview_tournament_score(INT, INT) IS
  'Read-only preview over the same resolver, dispatcher and strategies the '
  'writer uses. STABLE, so it cannot write. Rounds exactly as the writer stores.';

-- =============================================================================
-- 7 · The readers, without the retired columns
-- =============================================================================
CREATE VIEW vw_score AS
 SELECT r.id_result,
    r.id_fencer,
    (f.txt_surname || ' '::text) || f.txt_first_name AS fencer_name,
    f.int_birth_year,
    t.id_tournament,
    t.txt_code AS txt_tournament_code,
    t.txt_name AS txt_tournament_name,
    t.dt_tournament,
    t.enum_type,
    t.enum_weapon,
    t.enum_gender,
    t.enum_age_category,
    t.int_participant_count,
    t.num_multiplier,
    r.int_place,
    r.num_place_pts,
    r.num_de_bonus,
    r.num_podium_bonus,
    r.num_final_score,
    r.ts_points_calc,
    s.id_season,
    s.txt_code AS txt_season_code,
    t.url_results,
    e.txt_location,
    r.enum_score_method
   FROM tbl_result r
     JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
     JOIN tbl_event e ON e.id_event = t.id_event
     JOIN tbl_season s ON s.id_season = e.id_season
     LEFT JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
  WHERE r.id_fencer IS NOT NULL;

CREATE FUNCTION public.fn_fencer_scores_rolling_event_code_matching(p_fencer_id integer, p_weapon enum_weapon_type, p_gender enum_gender_type, p_category enum_age_category, p_season integer DEFAULT NULL::integer)
 RETURNS TABLE(id_result integer, id_fencer integer, fencer_name text, int_birth_year smallint, id_tournament integer, txt_tournament_code text, txt_tournament_name text, dt_tournament date, enum_type enum_tournament_type, enum_weapon enum_weapon_type, enum_gender enum_gender_type, enum_age_category enum_age_category, int_participant_count integer, num_multiplier numeric, int_place integer, num_place_pts numeric, num_de_bonus numeric, num_podium_bonus numeric, num_final_score numeric, ts_points_calc timestamp with time zone, id_season integer, txt_season_code text, url_results text, txt_location text, bool_carried_over boolean, txt_source_season_code text, enum_score_method text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  v_season_id      INT;
  v_prev_season_id INT;
  v_season_end_yr  INT;
  v_rules          JSONB;
BEGIN
  v_season_id := COALESCE(
    p_season,
    (SELECT s.id_season FROM tbl_season s WHERE s.bool_active LIMIT 1)
  );

  SELECT EXTRACT(YEAR FROM s.dt_end)::INT INTO v_season_end_yr
    FROM tbl_season s WHERE s.id_season = v_season_id;

  SELECT sc.json_ranking_rules INTO v_rules
    FROM tbl_scoring_config sc WHERE sc.id_season = v_season_id;

  SELECT s.id_season INTO v_prev_season_id
    FROM tbl_season s
   WHERE s.dt_end < (SELECT s2.dt_start FROM tbl_season s2 WHERE s2.id_season = v_season_id)
   ORDER BY s.dt_end DESC
   LIMIT 1;

  RETURN QUERY
  WITH
    -- Tournament types from ranking rules — domestic + international (ADR-021)
    rules_types AS (
      SELECT DISTINCT jsonb_array_elements_text(b.value -> 'types') AS type_code
        FROM jsonb_array_elements(
          COALESCE(v_rules -> 'domestic', '[]'::JSONB) || COALESCE(v_rules -> 'international', '[]'::JSONB)
        ) AS b(value)
    ),
    -- Positions the current season already HAS a result for (ADR-018/021 amend)
    completed_positions AS (
      SELECT DISTINCT fn_event_position(ev.txt_code) AS pos
        FROM tbl_event ev
        JOIN tbl_tournament t ON t.id_event = ev.id_event
        JOIN tbl_result r ON r.id_tournament = t.id_tournament
       WHERE ev.id_season = v_season_id
         AND t.enum_weapon = p_weapon
         AND t.enum_gender = p_gender
         AND r.num_final_score IS NOT NULL
    ),
    -- Current-season scores
    current_scores AS (
      SELECT
        r.id_result, r.id_fencer,
        f.txt_surname || ' ' || f.txt_first_name AS fencer_name,
        f.int_birth_year,
        t.id_tournament, t.txt_code AS txt_tournament_code, t.txt_name AS txt_tournament_name,
        t.dt_tournament, t.enum_type, t.enum_weapon, t.enum_gender, t.enum_age_category,
        t.int_participant_count, t.num_multiplier,
        r.int_place, r.num_place_pts, r.num_de_bonus, r.num_podium_bonus,
        r.num_final_score, r.ts_points_calc,
        s.id_season, s.txt_code AS txt_season_code,
        t.url_results, ev.txt_location,
        FALSE AS bool_carried_over,
        s.txt_code AS txt_source_season_code,
        r.enum_score_method::TEXT AS enum_score_method
      FROM tbl_result r
      JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
      JOIN tbl_event ev     ON ev.id_event = t.id_event
      JOIN tbl_season s     ON s.id_season = ev.id_season
      JOIN tbl_fencer f     ON f.id_fencer = r.id_fencer
      WHERE r.id_fencer = p_fencer_id
        AND ev.id_season = v_season_id
        AND t.enum_weapon = p_weapon
        AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender  -- ADR-034
        AND r.num_final_score IS NOT NULL
    ),
    -- Carried-over scores from previous season
    carried_scores AS (
      SELECT
        r.id_result, r.id_fencer,
        f.txt_surname || ' ' || f.txt_first_name AS fencer_name,
        f.int_birth_year,
        t.id_tournament, t.txt_code AS txt_tournament_code, t.txt_name AS txt_tournament_name,
        t.dt_tournament, t.enum_type, t.enum_weapon, t.enum_gender, t.enum_age_category,
        t.int_participant_count, t.num_multiplier,
        r.int_place, r.num_place_pts, r.num_de_bonus, r.num_podium_bonus,
        r.num_final_score, r.ts_points_calc,
        prev_s.id_season, prev_s.txt_code AS txt_season_code,
        t.url_results, ev.txt_location,
        TRUE AS bool_carried_over,
        prev_s.txt_code AS txt_source_season_code,
        r.enum_score_method::TEXT AS enum_score_method
      FROM tbl_result r
      JOIN tbl_tournament t  ON t.id_tournament = r.id_tournament
      JOIN tbl_event ev      ON ev.id_event = t.id_event
      JOIN tbl_season prev_s ON prev_s.id_season = ev.id_season
      JOIN tbl_fencer f      ON f.id_fencer = r.id_fencer
      WHERE v_prev_season_id IS NOT NULL
        AND r.id_fencer = p_fencer_id
        AND ev.id_season = v_prev_season_id
        AND t.enum_weapon = p_weapon
        AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender  -- ADR-034
        AND COALESCE(fn_age_category(f.int_birth_year, v_season_end_yr), t.enum_age_category) = p_category
        AND r.num_final_score IS NOT NULL
        -- Type must be in ranking rules AND position not yet completed (ADR-021)
        AND t.enum_type::TEXT IN (SELECT type_code FROM rules_types)
        AND fn_event_position(ev.txt_code) NOT IN (SELECT pos FROM completed_positions)
    )
  SELECT * FROM current_scores
  UNION ALL
  SELECT * FROM carried_scores
  ORDER BY num_final_score DESC;
END;
$function$;

CREATE FUNCTION public.fn_fencer_scores_rolling_event_fk_matching(p_fencer_id integer, p_weapon enum_weapon_type, p_gender enum_gender_type, p_category enum_age_category, p_season integer DEFAULT NULL::integer)
 RETURNS TABLE(id_result integer, id_fencer integer, fencer_name text, int_birth_year smallint, id_tournament integer, txt_tournament_code text, txt_tournament_name text, dt_tournament date, enum_type enum_tournament_type, enum_weapon enum_weapon_type, enum_gender enum_gender_type, enum_age_category enum_age_category, int_participant_count integer, num_multiplier numeric, int_place integer, num_place_pts numeric, num_de_bonus numeric, num_podium_bonus numeric, num_final_score numeric, ts_points_calc timestamp with time zone, id_season integer, txt_season_code text, url_results text, txt_location text, bool_carried_over boolean, txt_source_season_code text, enum_score_method text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  v_season_id     INT;
  v_season_end_yr INT;
  v_rules         JSONB;
BEGIN
  v_season_id := COALESCE(
    p_season,
    (SELECT s.id_season FROM tbl_season s WHERE s.bool_active LIMIT 1)
  );

  SELECT EXTRACT(YEAR FROM s.dt_end)::INT INTO v_season_end_yr
    FROM tbl_season s WHERE s.id_season = v_season_id;

  SELECT sc.json_ranking_rules INTO v_rules
    FROM tbl_scoring_config sc WHERE sc.id_season = v_season_id;

  RETURN QUERY
  WITH
    rules_types AS (
      SELECT DISTINCT jsonb_array_elements_text(b.value -> 'types') AS type_code
        FROM jsonb_array_elements(
          COALESCE(v_rules -> 'domestic', '[]'::JSONB) || COALESCE(v_rules -> 'international', '[]'::JSONB)
        ) AS b(value)
    )
  SELECT
    r.id_result, r.id_fencer,
    f.txt_surname || ' ' || f.txt_first_name AS fencer_name,
    f.int_birth_year,
    t.id_tournament, t.txt_code AS txt_tournament_code, t.txt_name AS txt_tournament_name,
    t.dt_tournament, t.enum_type, t.enum_weapon, t.enum_gender, t.enum_age_category,
    t.int_participant_count, t.num_multiplier,
    r.int_place, r.num_place_pts, r.num_de_bonus, r.num_podium_bonus,
    r.num_final_score, r.ts_points_calc,
    src_s.id_season, src_s.txt_code AS txt_season_code,
    t.url_results, src_e.txt_location,
    v.is_carried AS bool_carried_over,
    src_s.txt_code AS txt_source_season_code,
    r.enum_score_method::TEXT AS enum_score_method
  FROM vw_eligible_event v
  JOIN tbl_tournament t   ON t.id_event = v.id_event
  JOIN tbl_result r       ON r.id_tournament = t.id_tournament
  JOIN tbl_fencer f       ON f.id_fencer = r.id_fencer
  JOIN tbl_event src_e    ON src_e.id_event = v.source_event_id
  JOIN tbl_season src_s   ON src_s.id_season = src_e.id_season
  WHERE v.effective_season_id = v_season_id
    AND r.id_fencer = p_fencer_id
    AND t.enum_weapon = p_weapon
    AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender
    AND COALESCE(fn_age_category(f.int_birth_year, v_season_end_yr), t.enum_age_category) = p_category
    AND r.num_final_score IS NOT NULL
    AND (NOT v.is_carried OR t.enum_type::TEXT IN (SELECT type_code FROM rules_types))
  ORDER BY r.num_final_score DESC;
END;
$function$;

CREATE FUNCTION public.fn_fencer_scores_rolling(p_fencer_id integer, p_weapon enum_weapon_type, p_gender enum_gender_type, p_category enum_age_category, p_season integer DEFAULT NULL::integer)
 RETURNS TABLE(id_result integer, id_fencer integer, fencer_name text, int_birth_year smallint, id_tournament integer, txt_tournament_code text, txt_tournament_name text, dt_tournament date, enum_type enum_tournament_type, enum_weapon enum_weapon_type, enum_gender enum_gender_type, enum_age_category enum_age_category, int_participant_count integer, num_multiplier numeric, int_place integer, num_place_pts numeric, num_de_bonus numeric, num_podium_bonus numeric, num_final_score numeric, ts_points_calc timestamp with time zone, id_season integer, txt_season_code text, url_results text, txt_location text, bool_carried_over boolean, txt_source_season_code text, enum_score_method text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  v_engine          enum_event_carryover_engine;
  v_resolved_season INT;
BEGIN
  v_resolved_season := COALESCE(
    p_season,
    (SELECT s.id_season FROM tbl_season s WHERE s.bool_active LIMIT 1)
  );

  SELECT s.enum_carryover_engine INTO v_engine
    FROM tbl_season s WHERE s.id_season = v_resolved_season;

  CASE v_engine
    WHEN 'EVENT_CODE_MATCHING' THEN
      RETURN QUERY SELECT * FROM fn_fencer_scores_rolling_event_code_matching(
        p_fencer_id, p_weapon, p_gender, p_category, p_season
      );
    WHEN 'EVENT_FK_MATCHING' THEN
      RETURN QUERY SELECT * FROM fn_fencer_scores_rolling_event_fk_matching(
        p_fencer_id, p_weapon, p_gender, p_category, p_season
      );
    ELSE
      RAISE EXCEPTION 'Unknown carryover engine: % for season %', v_engine, v_resolved_season;
  END CASE;
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_ingest_tournament_results(p_tournament_id integer, p_results jsonb, p_participant_count integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_count           INT;
  v_row             JSONB;
  v_result_id       INT;
  v_fencer_id       INT;
  v_event_id        INT;
  v_legacy_status   TEXT;
  v_method_text     TEXT;
  v_method          enum_match_method;
  v_source_vcat     enum_age_category;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM tbl_tournament WHERE id_tournament = p_tournament_id) THEN
    RAISE EXCEPTION 'Tournament % does not exist', p_tournament_id;
  END IF;

  IF p_results IS NULL OR jsonb_array_length(p_results) = 0 THEN
    RAISE EXCEPTION 'Results array is empty';
  END IF;

  SELECT id_event INTO v_event_id
    FROM tbl_tournament WHERE id_tournament = p_tournament_id;

  DELETE FROM tbl_match_candidate
  WHERE id_result IN (
    SELECT id_result FROM tbl_result WHERE id_tournament = p_tournament_id
  );

  DELETE FROM tbl_result WHERE id_tournament = p_tournament_id;

  v_count := COALESCE(p_participant_count, jsonb_array_length(p_results));

  UPDATE tbl_tournament
  SET int_participant_count = v_count,
      enum_import_status    = 'IMPORTED',
      ts_updated            = NOW()
  WHERE id_tournament = p_tournament_id;

  FOR v_row IN SELECT jsonb_array_elements(p_results)
  LOOP
    v_fencer_id := (v_row ->> 'id_fencer')::INT;
    IF NOT EXISTS (SELECT 1 FROM tbl_fencer WHERE id_fencer = v_fencer_id) THEN
      RAISE EXCEPTION 'Fencer % does not exist', v_fencer_id;
    END IF;

    -- NEW: direct enum_match_method from payload (preserves NULL).
    -- When the key is present in the payload object, trust it verbatim —
    -- even if the value is JSON null or empty string (both map to NULL).
    -- When the key is absent, fall back to legacy enum_match_status with
    -- the historical default of AUTO_MATCH.
    IF v_row ? 'enum_match_method' THEN
      v_method_text := v_row ->> 'enum_match_method';
      IF v_method_text IS NULL OR v_method_text = '' THEN
        v_method := NULL;
      ELSE
        v_method := v_method_text::enum_match_method;
      END IF;
    ELSE
      v_legacy_status := COALESCE(v_row ->> 'enum_match_status', 'AUTO_MATCHED');
      v_method := CASE v_legacy_status
        WHEN 'AUTO_MATCHED' THEN 'AUTO_MATCH'::enum_match_method
        WHEN 'APPROVED'     THEN 'USER_CONFIRMED'::enum_match_method
        WHEN 'NEW_FENCER'   THEN 'AUTO_CREATED'::enum_match_method
        ELSE 'AUTO_MATCH'::enum_match_method
      END;
    END IF;

    -- For the legacy tbl_match_candidate row, derive a status from the
    -- (possibly NULL) method. Match-candidate enum has no NULL value, so
    -- a NULL method maps to AUTO_MATCHED (workflow-state best guess) —
    -- this preserves prior behavior for that table since it's slated for
    -- removal in Phase 6.
    v_legacy_status := COALESCE(v_row ->> 'enum_match_status',
      CASE v_method::TEXT
        WHEN 'AUTO_MATCH'      THEN 'AUTO_MATCHED'
        WHEN 'USER_CONFIRMED'  THEN 'APPROVED'
        WHEN 'AUTO_CREATED'    THEN 'NEW_FENCER'
        ELSE 'AUTO_MATCHED'
      END);

    v_source_vcat := CASE
      WHEN v_row ? 'enum_source_age_category' AND NULLIF(v_row ->> 'enum_source_age_category', '') IS NOT NULL
        THEN (v_row ->> 'enum_source_age_category')::enum_age_category
      ELSE NULL
    END;

    INSERT INTO tbl_result (
      id_fencer, id_tournament, int_place,
      txt_scraped_name, num_match_confidence, enum_match_method,
      enum_source_age_category
    )
    VALUES (
      v_fencer_id,
      p_tournament_id,
      (v_row ->> 'int_place')::INT,
      v_row ->> 'txt_scraped_name',
      COALESCE((v_row ->> 'num_confidence')::NUMERIC(5,2), 100),
      v_method,
      v_source_vcat
    )
    RETURNING id_result INTO v_result_id;

    INSERT INTO tbl_match_candidate (
      id_result, id_fencer,
      txt_scraped_name, num_confidence, enum_status
    ) VALUES (
      v_result_id,
      v_fencer_id,
      v_row ->> 'txt_scraped_name',
      COALESCE((v_row ->> 'num_confidence')::NUMERIC, 100),
      v_legacy_status::enum_match_status
    );
  END LOOP;

  PERFORM fn_calc_tournament_scores(p_tournament_id);

  UPDATE tbl_event
  SET enum_status = 'IN_PROGRESS', ts_updated = NOW()
  WHERE id_event = v_event_id
    AND enum_status = 'PLANNED';

  RETURN jsonb_build_object(
    'tournament_id',     p_tournament_id,
    'results_count',     jsonb_array_length(p_results),
    'participant_count', v_count,
    'status',            'IMPORTED'
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_commit_event_draft(p_run_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_committed_tournaments INT := 0;
    v_committed_results     INT := 0;
    v_joint_flagged         INT := 0;
    v_history_rows          INT := 0;
    v_tournaments_scored    INT := 0;
    v_t                     INT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM tbl_tournament_draft WHERE txt_run_id = p_run_id) THEN
        RETURN jsonb_build_object(
            'run_id', p_run_id,
            'tournaments_committed', 0,
            'results_committed',     0,
            'joint_pool_siblings_flagged', 0,
            'history_rows',          0,
            'tournaments_scored',    0
        );
    END IF;

    CREATE TEMP TABLE _commit_map (
        id_tournament_draft INT NOT NULL,
        id_tournament       INT NOT NULL
    ) ON COMMIT DROP;

    WITH ins AS (
        INSERT INTO tbl_tournament (
            id_event, txt_code, txt_name, enum_type, num_multiplier,
            enum_age_category, enum_weapon, enum_gender, dt_tournament,
            int_participant_count, txt_import_status_reason,
            enum_import_status, url_results, txt_source_url_used,
            enum_parser_kind, dt_last_scraped, bool_joint_pool_split
        )
        SELECT id_event, txt_code, txt_name, enum_type, num_multiplier,
               enum_age_category, enum_weapon, enum_gender, dt_tournament,
               int_participant_count, txt_import_status_reason,
               enum_import_status, url_results, txt_source_url_used,
               enum_parser_kind, dt_last_scraped, bool_joint_pool_split
          FROM tbl_tournament_draft
         WHERE txt_run_id = p_run_id
        RETURNING id_tournament, txt_code
    )
    INSERT INTO _commit_map (id_tournament_draft, id_tournament)
    SELECT td.id_tournament_draft, ins.id_tournament
      FROM ins
      JOIN tbl_tournament_draft td ON td.txt_code = ins.txt_code
     WHERE td.txt_run_id = p_run_id;

    GET DIAGNOSTICS v_committed_tournaments = ROW_COUNT;

    -- 5.18.B — added enum_source_age_category to BOTH sides so the source
    -- V-cat survives draft → live commit (alias-modal pre-fill needs it).
    INSERT INTO tbl_result (
        id_fencer, id_tournament, int_place, enum_fencer_age_category,
        txt_cross_cat, num_place_pts, num_de_bonus, num_podium_bonus,
        num_final_score, ts_points_calc,
        txt_scraped_name, num_match_confidence, enum_match_method,
        enum_source_age_category, enum_score_method
    )
    SELECT rd.id_fencer, m.id_tournament, rd.int_place, rd.enum_fencer_age_category,
           rd.txt_cross_cat, rd.num_place_pts, rd.num_de_bonus, rd.num_podium_bonus,
           rd.num_final_score, rd.ts_points_calc,
           rd.txt_scraped_name, rd.num_match_confidence, rd.enum_match_method,
           rd.enum_source_age_category, rd.enum_score_method
      FROM tbl_result_draft rd
      JOIN _commit_map m ON m.id_tournament_draft = rd.id_tournament_draft
     WHERE rd.txt_run_id = p_run_id;

    GET DIAGNOSTICS v_committed_results = ROW_COUNT;

    UPDATE tbl_tournament t
       SET bool_joint_pool_split = TRUE
      FROM (
        SELECT t1.id_event, t1.enum_weapon, t1.enum_gender, t1.url_results
          FROM tbl_tournament t1
          JOIN _commit_map m ON m.id_tournament = t1.id_tournament
         WHERE t1.url_results IS NOT NULL AND t1.url_results <> ''
         GROUP BY t1.id_event, t1.enum_weapon, t1.enum_gender, t1.url_results
        HAVING COUNT(*) > 1
      ) g
     WHERE t.id_event    = g.id_event
       AND t.enum_weapon = g.enum_weapon
       AND t.enum_gender = g.enum_gender
       AND t.url_results = g.url_results
       AND t.bool_joint_pool_split = FALSE;

    GET DIAGNOSTICS v_joint_flagged = ROW_COUNT;

    -- ADR-049 AMENDED 2026-06-04: per-V-cat own count, NOT the full-pool sum.
    -- Group by id_tournament so each joint sibling stores ONLY its own result
    -- rows (was: GROUP BY url_results, which summed across all siblings).
    UPDATE tbl_tournament t
       SET int_participant_count = ps.sz
      FROM (
        SELECT tt.id_tournament,
               COUNT(r.id_result)::INT AS sz
          FROM tbl_tournament tt
          JOIN _commit_map m ON m.id_tournament = tt.id_tournament
          JOIN tbl_result r ON r.id_tournament = tt.id_tournament
         WHERE tt.bool_joint_pool_split = TRUE
         GROUP BY tt.id_tournament
      ) ps
     WHERE t.id_tournament = ps.id_tournament
       AND t.bool_joint_pool_split = TRUE;

    -- Score every newly-committed tournament. Phase 5 historical re-ingest:
    -- events are 3+ years old, results are final — no async scoring step.
    FOR v_t IN SELECT id_tournament FROM _commit_map LOOP
        BEGIN
            PERFORM fn_calc_tournament_scores(v_t);
            v_tournaments_scored := v_tournaments_scored + 1;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'fn_calc_tournament_scores(%) failed during commit %: %',
                          v_t, p_run_id, SQLERRM;
        END;
    END LOOP;

    INSERT INTO tbl_tournament_ingest_history (
        id_tournament, txt_run_id, enum_parser_kind, txt_source_url
    )
    SELECT m.id_tournament, p_run_id, td.enum_parser_kind, td.txt_source_url_used
      FROM tbl_tournament_draft td
      JOIN _commit_map m ON m.id_tournament_draft = td.id_tournament_draft
     WHERE td.txt_run_id = p_run_id
       AND td.enum_parser_kind IS NOT NULL;

    GET DIAGNOSTICS v_history_rows = ROW_COUNT;

    INSERT INTO tbl_event_ingest_history (
        id_event, txt_run_id, enum_parser_kind, txt_source_url
    )
    SELECT DISTINCT ON (td.id_event)
           td.id_event, p_run_id, td.enum_parser_kind, td.txt_source_url_used
      FROM tbl_tournament_draft td
     WHERE td.txt_run_id = p_run_id
       AND td.enum_parser_kind IS NOT NULL
     ORDER BY td.id_event, td.id_tournament_draft;

    INSERT INTO tbl_audit_log (
        txt_table_name, id_row, txt_action,
        jsonb_old_values, jsonb_new_values, txt_admin_user
    )
    SELECT 'tbl_tournament', m.id_tournament, 'DRAFT_COMMIT',
           NULL::JSONB,
           jsonb_build_object('run_id', p_run_id, 'committed_at', NOW()),
           current_setting('request.jwt.claims', TRUE)::JSONB->>'sub'
      FROM _commit_map m;

    DELETE FROM tbl_result_draft     WHERE txt_run_id = p_run_id;
    DELETE FROM tbl_tournament_draft WHERE txt_run_id = p_run_id;

    DROP TABLE _commit_map;

    RETURN jsonb_build_object(
        'run_id', p_run_id,
        'tournaments_committed', v_committed_tournaments,
        'results_committed',     v_committed_results,
        'joint_pool_siblings_flagged', v_joint_flagged,
        'history_rows',          v_history_rows,
        'tournaments_scored',    v_tournaments_scored
    );
END;
$function$;

-- =============================================================================
-- 8 · The PZSz review queue, back to ADR-100's five parameters
-- =============================================================================
CREATE FUNCTION fn_queue_pzsz_match_review(
  p_id_tournament       INT,
  p_txt_scraped_name    TEXT,
  p_int_place           INT,
  p_id_candidate_fencer INT,
  p_num_confidence      NUMERIC
)
RETURNS INT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  INSERT INTO tbl_pzsz_match_review (
    id_tournament, txt_scraped_name, int_place, id_candidate_fencer, num_confidence
  )
  VALUES (
    p_id_tournament, p_txt_scraped_name, p_int_place, p_id_candidate_fencer, p_num_confidence
  )
  RETURNING id_review;
$$;

COMMENT ON FUNCTION fn_queue_pzsz_match_review(INT, TEXT, INT, INT, NUMERIC) IS
  'Queue one uncertain PZSz senior match for Admin review (ADR-100). Writes no '
  'result row; fn_approve_pzsz_match_review or fn_reject_pzsz_match_review '
  'decides it.';

CREATE OR REPLACE FUNCTION fn_approve_pzsz_match_review(p_id_review INT, p_id_fencer INT)
RETURNS INT
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_tournament  INT;
  v_name        TEXT;
  v_place       INT;
  v_confidence  NUMERIC;
  v_season_end  INT;
  v_birth_year  INT;
  v_source_vcat enum_age_category;
BEGIN
  SELECT id_tournament, txt_scraped_name, int_place, num_confidence
    INTO v_tournament, v_name, v_place, v_confidence
    FROM tbl_pzsz_match_review
   WHERE id_review = p_id_review AND enum_status = 'PENDING'
   FOR UPDATE;

  IF v_tournament IS NULL THEN
    RAISE EXCEPTION 'No pending PZSz match review %', p_id_review;
  END IF;

  IF p_id_fencer IS NULL THEN
    RAISE EXCEPTION 'A fencer must be named to approve review %', p_id_review;
  END IF;

  SELECT f.int_birth_year INTO v_birth_year FROM tbl_fencer f WHERE f.id_fencer = p_id_fencer;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Fencer % does not exist', p_id_fencer;
  END IF;

  SELECT EXTRACT(YEAR FROM s.dt_end)::INT INTO v_season_end
    FROM tbl_tournament t
    JOIN tbl_event e  ON e.id_event  = t.id_event
    JOIN tbl_season s ON s.id_season = e.id_season
   WHERE t.id_tournament = v_tournament;

  v_source_vcat := CASE
    WHEN v_birth_year IS NOT NULL THEN fn_age_category(v_birth_year, v_season_end)
    ELSE NULL
  END;

  INSERT INTO tbl_result (
    id_fencer, id_tournament, int_place,
    txt_scraped_name, num_match_confidence, enum_match_method,
    enum_source_age_category
  ) VALUES (
    p_id_fencer, v_tournament, v_place,
    v_name, v_confidence, 'USER_CONFIRMED',
    v_source_vcat
  );

  PERFORM fn_calc_tournament_scores(v_tournament);

  UPDATE tbl_pzsz_match_review
     SET enum_status = 'APPROVED', ts_decided = NOW()
   WHERE id_review = p_id_review;

  RETURN p_id_review;
END;
$$;

-- =============================================================================
-- 9 · The engine backfill, until the joined engine lands
-- =============================================================================
-- Replaces the 2026-09-28 version, which named the removed engine. History
-- and an unscored SPWS-2026-2027 are EVF classic, the only released engine;
-- the engine migration that follows replaces this function again. A season
-- that holds scores is never reassigned (the §11 gate).
CREATE OR REPLACE FUNCTION fn_backfill_scoring_engines()
RETURNS VOID
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $backfill$
DECLARE
  v_classic   INT;
  v_deviant   TEXT;
  v_season    INT;
  v_scored    INT;
BEGIN
  SELECT id_engine INTO v_classic FROM tbl_scoring_engine WHERE txt_code = 'EVF_CLASSIC_V1_2025_2026';

  -- Assigning EVF_CLASSIC_V1_2025_2026 to a historical season is only truthful
  -- if that season was scored with the base it reproduces. mp_value and the
  -- podium coefficients are season configuration, so they are read per season.
  SELECT string_agg(s.txt_code || ' (mp=' || c.int_mp_value || ', podium='
                    || c.int_podium_gold || '/' || c.int_podium_silver || '/'
                    || c.int_podium_bronze || ')', '; ' ORDER BY s.txt_code)
    INTO v_deviant
    FROM tbl_season s
    JOIN tbl_scoring_config c ON c.id_season = s.id_season
   WHERE s.txt_code < 'SPWS-2026-2027'
     AND (c.int_mp_value <> 50 OR c.int_podium_gold <> 3
          OR c.int_podium_silver <> 2 OR c.int_podium_bronze <> 1);

  IF v_deviant IS NOT NULL THEN
    RAISE EXCEPTION
      'Cannot assign EVF_CLASSIC_V1_2025_2026: these seasons were not scored with the base it reproduces: %. Each needs its own frozen engine rather than silent coercion.',
      v_deviant;
  END IF;

  UPDATE tbl_season s
     SET id_scoring_engine = v_classic
   WHERE s.txt_code < 'SPWS-2026-2027' AND s.id_scoring_engine IS NULL;

  SELECT s.id_season INTO v_season FROM tbl_season s WHERE s.txt_code = 'SPWS-2026-2027';

  IF v_season IS NOT NULL THEN
    SELECT count(*) INTO v_scored
      FROM tbl_result r
      JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
      JOIN tbl_event e      ON e.id_event      = t.id_event
     WHERE e.id_season = v_season AND r.ts_points_calc IS NOT NULL;

    IF v_scored = 0 THEN
      UPDATE tbl_season
         SET id_scoring_engine = v_classic
       WHERE id_season = v_season AND id_scoring_engine IS NULL;

      UPDATE tbl_scoring_type_config tc
         SET id_scoring_engine = v_classic,
             ts_updated = NOW()
        FROM tbl_scoring_config c
       WHERE c.id_config = tc.id_config
         AND c.id_season = v_season
         AND tc.id_scoring_engine IS NULL;
    END IF;
  END IF;

  -- Any other season that predates this call and holds no assignment falls
  -- back to the classic engine. A deliberate assignment is never overwritten.
  UPDATE tbl_season s
     SET id_scoring_engine = v_classic
   WHERE s.id_scoring_engine IS NULL AND s.ts_created < NOW();
END;
$backfill$;

COMMENT ON FUNCTION fn_backfill_scoring_engines() IS
  'Idempotent engine backfill: EVF classic for history and, until the joined '
  'engine lands (ADR-104), for an unscored SPWS-2026-2027 with all eight type '
  'rows set explicitly. Never reassigns a scored season. Called again from '
  'supabase/seed_post_backfill.sql because migrations run before the seed '
  '(ADR-036 amendment).';

SELECT fn_backfill_scoring_engines();

-- =============================================================================
-- 10 · ADR-083 deny-by-default: every recreated object gets its grants back
-- =============================================================================
-- A new function is executable by PUBLIC and a new view readable by nobody
-- but its owner and service_role, so each recreated object states its grants.
REVOKE EXECUTE ON FUNCTION fn_assert_retired_columns_unused(REGCLASS, TEXT[]) FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION fn_score_by_engine(TEXT, INT, INT, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_score_by_engine(TEXT, INT, INT, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC)
  TO service_role;

REVOKE EXECUTE ON FUNCTION fn_preview_tournament_score(INT, INT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_preview_tournament_score(INT, INT) TO service_role;

GRANT SELECT ON vw_score TO anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION fn_fencer_scores_rolling(integer, enum_weapon_type, enum_gender_type, enum_age_category, integer)
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION fn_fencer_scores_rolling_event_code_matching(integer, enum_weapon_type, enum_gender_type, enum_age_category, integer)
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION fn_fencer_scores_rolling_event_fk_matching(integer, enum_weapon_type, enum_gender_type, enum_age_category, integer)
  TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION fn_queue_pzsz_match_review(INT, TEXT, INT, INT, NUMERIC) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fn_queue_pzsz_match_review(INT, TEXT, INT, INT, NUMERIC) TO authenticated, service_role;
