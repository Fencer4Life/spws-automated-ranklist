-- =============================================================================
-- The 2026/2027 SPWS place-and-medal engine, assigned per tournament type
-- =============================================================================
-- ADR-103. doc/plans/scoring-engine-2026-2027-implementation-plan-2026-09-28.html
-- step 4. Flips SE27.ENG/TYPE/STORE/RANK/CALC in
-- supabase/tests/83_spws_place_medal_engine.sql, SE27.STORE.08 in
-- 81_pzsz_senior_ingestion.sql and the re-pointed SS26.* assertions in 02, 80
-- and 82 from RED to GREEN. SS26.HIST.01-06 (the 2025/2026 golden fixtures)
-- must stay untouched: EVF_CLASSIC_V1_2025_2026 is not edited.
--
-- WHAT CHANGES
--
--   1. A new released strategy, fn_score_spws_place_medal_v1_2026_2027, with
--      three ranges chosen by the size of the whole bracket: N <= 3 the table
--      N - p + 1; 4 <= N <= 31 log2 N + 3.5 x fencers below + a category medal
--      13/7/3 x cbrt K; N >= 32 EVF classic on the joined place and N.
--   2. The dispatcher takes K (own category's fencers in the bracket), m (place
--      among them) and b (fencers strictly below) and returns
--      typ_score_breakdown, which names the method that scored the result.
--   3. The engine is resolved per tournament type: a type row that names an
--      engine uses it, a NULL type row uses the season's engine.
--   4. tbl_result stores K, m, b, the three new components and the method.
--      -1 means "not used" by the method that scored the row; a scored row
--      never holds NULL, and never NaN.
--   5. SPWS_FIELD_SCALED_V1_2026_2027 is deleted. It never scored a result.
--   6. The Season Scoring Rules gain entry_types: from 2026/2027 a fencer
--      enters the full ranking only through a PPW or MPW start.
--   7. fn_public_scoring_params returns one row per tournament type.
--
-- BOOTSTRAP ORDER (ADR-036 amendment)
--
-- `supabase db reset` applies migrations before the seed dump, so on LOCAL the
-- backfill calls below run against empty tables. supabase/seed_post_backfill.sql
-- calls fn_backfill_scoring_engines(), fn_backfill_ranking_entry_types() and
-- fn_backfill_score_method() again once the seed has loaded. CERT and PROD
-- hold their data when this applies and are served by the calls here.
-- =============================================================================

SET LOCAL lock_timeout = '2s';

-- =============================================================================
-- 1 · Types
-- =============================================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'enum_score_method') THEN
    CREATE TYPE enum_score_method AS ENUM ('TABLE', 'PLACE_MEDAL', 'EVF_CLASSIC');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'typ_score_breakdown') THEN
    CREATE TYPE typ_score_breakdown AS (
      num_place_pts     NUMERIC,
      num_de_bonus      NUMERIC,
      num_podium_bonus  NUMERIC,
      num_field_pts     NUMERIC,
      num_below_pts     NUMERIC,
      num_medal_bonus   NUMERIC,
      enum_score_method enum_score_method
    );
  END IF;
END $$;

COMMENT ON TYPE enum_score_method IS
  'The range of an engine that scored a result: TABLE (N <= 3), PLACE_MEDAL '
  '(4-31) or EVF_CLASSIC. NULL on a result means it has not been scored yet.';
COMMENT ON TYPE typ_score_breakdown IS
  'What every strategy returns: the raw, unrounded components and the method. '
  'A component the method does not use is NULL here; the writer stores it as '
  '-1. The final score is the non-NULL components summed, multiplied by the '
  'type coefficient and rounded once.';

-- =============================================================================
-- 2 · Registry: the new engine and its paired joined-bracket module
-- =============================================================================
-- tbl_scoring_engine stays metadata only (SS26.DB.01b). The module column is a
-- display name read by python/pipeline/joined_brackets, never a reference the
-- database executes.
ALTER TABLE tbl_scoring_engine
  ADD COLUMN IF NOT EXISTS txt_joined_bracket_module TEXT;

INSERT INTO tbl_scoring_engine (txt_code, txt_label, txt_base_shape, txt_joined_bracket_module)
VALUES (
  'SPWS_PLACE_MEDAL_V1_2026_2027',
  'SPWS — miejsce w stawce i premia medalowa (od sezonu 2026/2027)',
  'By the size N of the whole bracket: N <= 3 scores N - place + 1; 4 <= N <= 31 '
  'scores log2 N + 3.5 x fencers strictly below + 13/7/3 x cbrt K for places '
  '1/2/3 of the own category of K when K > m; N >= 32 scores '
  'EVF_CLASSIC_V1_2025_2026 on the joined place and N, with no category medal.',
  'JOINED_BRACKET_CATEGORY_PLACE'
)
ON CONFLICT (txt_code) DO NOTHING;

UPDATE tbl_scoring_engine
   SET txt_joined_bracket_module = 'PER_CATEGORY_RENUMBER'
 WHERE txt_joined_bracket_module IS NULL;

ALTER TABLE tbl_scoring_engine
  ALTER COLUMN txt_joined_bracket_module SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_scoring_engine_joined_module') THEN
    ALTER TABLE tbl_scoring_engine
      ADD CONSTRAINT chk_scoring_engine_joined_module
      CHECK (txt_joined_bracket_module IN ('PER_CATEGORY_RENUMBER', 'JOINED_BRACKET_CATEGORY_PLACE'));
  END IF;
END $$;

COMMENT ON COLUMN tbl_scoring_engine.txt_joined_bracket_module IS
  'The joined-bracket module paired with this engine (ADR-103 §4): '
  'PER_CATEGORY_RENUMBER splits a joined bracket per category and renumbers '
  '(ADR-049); JOINED_BRACKET_CATEGORY_PLACE keeps the joined place and N and '
  'writes K, m and the count below. A display name, never executed.';

-- =============================================================================
-- 3 · The strategy: SPWS_PLACE_MEDAL_V1_2026_2027
-- =============================================================================
-- IMMUTABLE RELEASED STRATEGY once this migration ships. log2 N, 3.5, 13/7/3,
-- the N <= 3 table and the switch at 32 belong to the engine version; only the
-- per-type coefficient, applied by the caller, is season configuration. The
-- EVF settings (mp_value, DE round, podium) feed the range from 32 only.
--
-- K, m and b are required in the 4-31 range. -1, the stored "not given", is
-- refused there rather than read as zero: a bracket scored without them would
-- publish a number the formula does not define.
CREATE OR REPLACE FUNCTION fn_score_spws_place_medal_v1_2026_2027(
  p_n             INT,
  p_place         INT,
  p_k             INT,
  p_m             INT,
  p_below         INT,
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
  PERFORM fn_assert_scoring_input(p_n, p_place);

  IF p_n <= 3 THEN
    -- §8 ust. 7: a bracket of one, two or three scores N - place + 1.
    v_out.num_place_pts     := (p_n - p_place + 1)::NUMERIC;
    v_out.enum_score_method := 'TABLE';
    RETURN v_out;
  END IF;

  IF p_n >= 32 THEN
    -- §8 ust. 8: from 32 the pure EVF algorithm, on the joined place and N.
    v_classic := fn_score_evf_classic_v1_2025_2026(
      p_n, p_place, p_mp_value, 10, p_de_round,
      p_podium_gold, p_podium_silver, p_podium_bronze);
    v_out.num_place_pts     := v_classic.num_place_pts;
    v_out.num_de_bonus      := v_classic.num_de_bonus;
    v_out.num_podium_bonus  := v_classic.num_podium_bonus;
    v_out.enum_score_method := 'EVF_CLASSIC';
    RETURN v_out;
  END IF;

  IF p_k IS NULL OR p_k < 1 OR p_k > p_n THEN
    RAISE EXCEPTION
      'Invalid scoring input: a bracket of % needs the own category''s fencer count K between 1 and %, got %',
      p_n, p_n, p_k;
  END IF;
  IF p_m IS NULL OR p_m < 1 OR p_m > p_k OR p_m > p_place THEN
    RAISE EXCEPTION
      'Invalid scoring input: category place m % must be between 1 and K = % and not better than place %',
      p_m, p_k, p_place;
  END IF;
  IF p_below IS NULL OR p_below < 0 OR p_below > p_n - p_place THEN
    RAISE EXCEPTION
      'Invalid scoring input: % fencers below place % of % is impossible',
      p_below, p_place, p_n;
  END IF;

  -- UNROUNDED on purpose, like every strategy: the caller rounds once.
  -- cbrt(), not the classic engine's POWER(n, 1.0/3): numeric 1.0/3 stops at
  -- twenty digits, so a perfect cube (K = 8, 27) lands a hair below its root
  -- and a tie at the final ROUND goes down, where the signed-off table and the
  -- browser module (Math.cbrt) go up. SE27.ENG.14 / scoring.test.ts pin it.
  v_out.num_field_pts   := (LN(p_n) / LN(2))::NUMERIC;
  v_out.num_below_pts   := 3.5 * p_below;
  v_out.num_medal_bonus :=
    CASE WHEN p_m < p_k AND p_m <= 3
         THEN (CASE p_m WHEN 1 THEN 13 WHEN 2 THEN 7 ELSE 3 END)
              * cbrt(p_k::DOUBLE PRECISION)::NUMERIC
         ELSE 0::NUMERIC
    END;
  v_out.enum_score_method := 'PLACE_MEDAL';
  RETURN v_out;
END;
$$;

COMMENT ON FUNCTION fn_score_spws_place_medal_v1_2026_2027 IS
  'IMMUTABLE RELEASED STRATEGY — do not edit. ADR-103 §1. N <= 3: N - place + 1. '
  '4-31: log2 N + 3.5 x fencers strictly below + 13/7/3 x cbrt K when m < K. '
  'N >= 32: EVF_CLASSIC_V1_2025_2026. Pinned by SE27.ENG.* and the signed-off '
  'points table. A formula change is a new engine version.';

-- =============================================================================
-- 4 · The dispatcher
-- =============================================================================
-- Same static CASE ... ELSE RAISE as ADR-042/045. It now passes K, m and b,
-- which EVF classic ignores, and returns the breakdown. The field-scaled
-- branch is gone with its engine (§3 of ADR-103).
DROP FUNCTION IF EXISTS fn_score_by_engine(
  TEXT, INT, INT, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC);

CREATE OR REPLACE FUNCTION fn_score_by_engine(
  p_engine_code   TEXT,
  p_n             INT,
  p_place         INT,
  p_k             INT,
  p_m             INT,
  p_below         INT,
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
    WHEN 'SPWS_PLACE_MEDAL_V1_2026_2027' THEN
      RETURN fn_score_spws_place_medal_v1_2026_2027(
        p_n, p_place, p_k, p_m, p_below, p_mp_value, p_de_round,
        p_podium_gold, p_podium_silver, p_podium_bronze);
    ELSE
      RAISE EXCEPTION 'Unknown scoring engine: %', p_engine_code;
  END CASE;
END;
$$;

COMMENT ON FUNCTION fn_score_by_engine IS
  'Static dispatcher over released scoring strategies (ADR-042/ADR-045 '
  'precedent). Adding an engine edits THIS function and adds a new strategy; '
  'it never edits an existing strategy. K, m and b are passed to every branch; '
  'EVF classic ignores them.';

-- =============================================================================
-- 5 · The engine per tournament type
-- =============================================================================
-- A type row that names an engine uses it; NULL means the season's engine.
-- tbl_scoring_type_config stays trigger-owned and closed to direct writes
-- (trg_guard_type_config_direct_write); fn_apply_scoring_config_write is the
-- only writer of this column.
ALTER TABLE tbl_scoring_type_config
  ADD COLUMN IF NOT EXISTS id_scoring_engine INT REFERENCES tbl_scoring_engine(id_engine);

COMMENT ON COLUMN tbl_scoring_type_config.id_scoring_engine IS
  'The engine this tournament type is scored with (ADR-103 §2). NULL means the '
  'season''s engine, tbl_season.id_scoring_engine. Governed like every scoring '
  'field: frozen once the season scores its first result (ADR-097).';

CREATE OR REPLACE FUNCTION fn_get_type_engine(p_id_season INT, p_type TEXT)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_type_row INT;
  v_engine   TEXT;
BEGIN
  SELECT tc.id_type_config, se.txt_code
    INTO v_type_row, v_engine
    FROM tbl_season s
    JOIN tbl_scoring_config c        ON c.id_season = s.id_season
    JOIN tbl_scoring_type_config tc  ON tc.id_config = c.id_config AND tc.enum_type::TEXT = p_type
    LEFT JOIN tbl_scoring_engine se  ON se.id_engine = COALESCE(tc.id_scoring_engine, s.id_scoring_engine)
   WHERE s.id_season = p_id_season;

  IF v_type_row IS NULL THEN
    RAISE EXCEPTION
      'No scoring configuration for tournament type % in season %. Refusing to choose an engine.',
      p_type, p_id_season;
  END IF;

  IF v_engine IS NULL THEN
    RAISE EXCEPTION
      'Unknown scoring engine: season % has no engine assigned for tournament type %. An engine is assigned deliberately, never inferred.',
      p_id_season, p_type;
  END IF;

  RETURN v_engine;
END;
$$;

COMMENT ON FUNCTION fn_get_type_engine(INT, TEXT) IS
  'The engine a tournament type is scored with in a season: the type row''s '
  'engine, or the season''s when the row names none. Raises when the type is '
  'not configured or nothing is assigned. Read by fn_resolve_scoring_params and '
  'by the ingestion pipeline to choose the joined-bracket module (ADR-103 §4).';

-- The resolver drops base_slope: only the deleted field-scaled engine read it.
DROP FUNCTION IF EXISTS fn_resolve_scoring_params(INT);

CREATE OR REPLACE FUNCTION fn_resolve_scoring_params(p_tournament_id INT)
RETURNS TABLE (
  n              INT,
  engine_code    TEXT,
  multiplier     NUMERIC,
  mp_value       NUMERIC,
  de_round       NUMERIC,
  podium_gold    NUMERIC,
  podium_silver  NUMERIC,
  podium_bronze  NUMERIC
)
LANGUAGE plpgsql
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_n        INT;
  v_type     enum_tournament_type;
  v_season   INT;
  v_engine   TEXT;
BEGIN
  SELECT t.int_participant_count, t.enum_type, e.id_season
    INTO v_n, v_type, v_season
    FROM tbl_tournament t
    JOIN tbl_event e ON e.id_event = t.id_event
   WHERE t.id_tournament = p_tournament_id;

  IF v_n IS NULL OR v_n < 1 THEN
    RAISE EXCEPTION 'Tournament % has no participant count', p_tournament_id;
  END IF;

  v_engine := fn_get_type_engine(v_season, v_type::TEXT);

  RETURN QUERY
    SELECT v_n,
           v_engine,
           fn_assert_type_configured(v_season, v_type::TEXT),
           c.int_mp_value::NUMERIC,
           10::NUMERIC,   -- de_round: points per DE round won
           c.int_podium_gold::NUMERIC,
           c.int_podium_silver::NUMERIC,
           c.int_podium_bronze::NUMERIC
      FROM tbl_scoring_config c
     WHERE c.id_season = v_season;
END;
$$;

-- =============================================================================
-- 6 · Storage: K, m, b, the new components and the method
-- =============================================================================
-- NOT NULL DEFAULT -1: adding a column with a constant default is a catalogue
-- change, not a table rewrite. Every existing row reads -1 ("not used"), which
-- is what history is under EVF classic. The method stays NULL until a row is
-- scored; the backfill below names EVF_CLASSIC for every scored row.
ALTER TABLE tbl_result
  ADD COLUMN IF NOT EXISTS int_category_count INT     NOT NULL DEFAULT -1,
  ADD COLUMN IF NOT EXISTS int_category_place INT     NOT NULL DEFAULT -1,
  ADD COLUMN IF NOT EXISTS int_below_count    INT     NOT NULL DEFAULT -1,
  ADD COLUMN IF NOT EXISTS num_field_pts      NUMERIC NOT NULL DEFAULT -1,
  ADD COLUMN IF NOT EXISTS num_below_pts      NUMERIC NOT NULL DEFAULT -1,
  ADD COLUMN IF NOT EXISTS num_medal_bonus    NUMERIC NOT NULL DEFAULT -1,
  ADD COLUMN IF NOT EXISTS enum_score_method  enum_score_method;

ALTER TABLE tbl_result_draft
  ADD COLUMN IF NOT EXISTS int_category_count INT     NOT NULL DEFAULT -1,
  ADD COLUMN IF NOT EXISTS int_category_place INT     NOT NULL DEFAULT -1,
  ADD COLUMN IF NOT EXISTS int_below_count    INT     NOT NULL DEFAULT -1,
  ADD COLUMN IF NOT EXISTS num_field_pts      NUMERIC NOT NULL DEFAULT -1,
  ADD COLUMN IF NOT EXISTS num_below_pts      NUMERIC NOT NULL DEFAULT -1,
  ADD COLUMN IF NOT EXISTS num_medal_bonus    NUMERIC NOT NULL DEFAULT -1,
  ADD COLUMN IF NOT EXISTS enum_score_method  enum_score_method;

COMMENT ON COLUMN tbl_result.int_category_count IS
  'K: fencers of this fencer''s own category in the whole bracket (ADR-103 §5). '
  'Written at ingestion; -1 when the ingestion path does not use it.';
COMMENT ON COLUMN tbl_result.int_category_place IS
  'm: 1 + own-category fencers with a strictly better place, so ties run '
  '1, 2, 3, 3, 5. -1 when not used.';
COMMENT ON COLUMN tbl_result.int_below_count IS
  'b: fencers of the whole bracket with a strictly worse place; a tied fencer '
  'is not below (§8 ust. 6). Stored, not derived: it counts fencers stored in '
  'other tournaments or not stored at all. -1 when not used.';
COMMENT ON COLUMN tbl_result.num_field_pts IS
  'log2 N under PLACE_MEDAL; -1 under any other method.';
COMMENT ON COLUMN tbl_result.num_below_pts IS
  '3.5 x fencers below under PLACE_MEDAL; -1 under any other method.';
COMMENT ON COLUMN tbl_result.num_medal_bonus IS
  '13/7/3 x cbrt K under PLACE_MEDAL (0 without a medal); -1 under any other method.';
COMMENT ON COLUMN tbl_result.enum_score_method IS
  'The range that scored the row. NULL until scored, like ts_points_calc. '
  'Under TABLE the points are in num_place_pts.';

-- Only real values or -1 (ADR-103 §5). NULL passes a CHECK, which is what an
-- unscored legacy component column still holds.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_result_category_count') THEN
    ALTER TABLE tbl_result
      ADD CONSTRAINT chk_result_category_count
        CHECK (int_category_count >= 1 OR int_category_count = -1),
      ADD CONSTRAINT chk_result_category_place
        CHECK (int_category_place >= 1 OR int_category_place = -1),
      ADD CONSTRAINT chk_result_category_place_within_count
        CHECK (int_category_place = -1 OR int_category_count = -1
               OR int_category_place <= int_category_count),
      ADD CONSTRAINT chk_result_below_count
        CHECK (int_below_count >= 0 OR int_below_count = -1),
      ADD CONSTRAINT chk_result_place_pts
        CHECK (num_place_pts >= 0 OR num_place_pts = -1),
      ADD CONSTRAINT chk_result_de_bonus
        CHECK (num_de_bonus >= 0 OR num_de_bonus = -1),
      ADD CONSTRAINT chk_result_podium_bonus
        CHECK (num_podium_bonus >= 0 OR num_podium_bonus = -1),
      ADD CONSTRAINT chk_result_field_pts
        CHECK (num_field_pts >= 0 OR num_field_pts = -1),
      ADD CONSTRAINT chk_result_below_pts
        CHECK (num_below_pts >= 0 OR num_below_pts = -1),
      ADD CONSTRAINT chk_result_medal_bonus
        CHECK (num_medal_bonus >= 0 OR num_medal_bonus = -1),
      -- -1 exactly where the method does not use a component.
      ADD CONSTRAINT chk_result_components_match_method
        CHECK (enum_score_method IS NULL
          OR (enum_score_method = 'EVF_CLASSIC'
              AND num_field_pts = -1 AND num_below_pts = -1 AND num_medal_bonus = -1)
          OR (enum_score_method = 'PLACE_MEDAL'
              AND num_place_pts = -1 AND num_de_bonus = -1 AND num_podium_bonus = -1)
          OR (enum_score_method = 'TABLE'
              AND num_de_bonus = -1 AND num_podium_bonus = -1
              AND num_field_pts = -1 AND num_below_pts = -1 AND num_medal_bonus = -1));
  END IF;
END $$;

-- The PZSz review queue keeps b: the senior field is never stored, so a later
-- approval cannot recount it (ADR-103 §4).
ALTER TABLE tbl_pzsz_match_review
  ADD COLUMN IF NOT EXISTS int_below_count INT NOT NULL DEFAULT -1;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_pzsz_review_below_count') THEN
    ALTER TABLE tbl_pzsz_match_review
      ADD CONSTRAINT chk_pzsz_review_below_count
      CHECK (int_below_count >= 0 OR int_below_count = -1);
  END IF;
END $$;

-- =============================================================================
-- 7 · The writer and the preview
-- =============================================================================
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
         num_field_pts     = COALESCE(ROUND(c.num_field_pts, 2),    -1),
         num_below_pts     = COALESCE(ROUND(c.num_below_pts, 2),    -1),
         num_medal_bonus   = COALESCE(ROUND(c.num_medal_bonus, 2),  -1),
         enum_score_method = c.enum_score_method,
         -- Rounded ONCE, from the raw terms. An unused component is NULL in
         -- the breakdown and adds nothing; -1 is never summed.
         num_final_score   = ROUND(
           (COALESCE(c.num_place_pts, 0) + COALESCE(c.num_de_bonus, 0)
            + COALESCE(c.num_podium_bonus, 0) + COALESCE(c.num_field_pts, 0)
            + COALESCE(c.num_below_pts, 0) + COALESCE(c.num_medal_bonus, 0))
           * p.multiplier, 2),
         ts_points_calc      = NOW(),
         id_scoring_revision = v_revision
    FROM (
      SELECT r2.id_result, (x.comp).*
        FROM tbl_result r2
        CROSS JOIN LATERAL (
          SELECT fn_score_by_engine(
                   p.engine_code, p.n, r2.int_place,
                   r2.int_category_count, r2.int_category_place, r2.int_below_count,
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

-- The preview gains the new components; one category is assumed (K = N,
-- m = place, b = N - place), since a preview takes only a place.
DROP FUNCTION IF EXISTS fn_preview_tournament_score(INT, INT);

CREATE OR REPLACE FUNCTION fn_preview_tournament_score(p_tournament_id INT, p_place INT)
RETURNS TABLE (
  txt_engine_code   TEXT,
  num_place_pts     NUMERIC,
  num_de_bonus      NUMERIC,
  num_podium_bonus  NUMERIC,
  num_field_pts     NUMERIC,
  num_below_pts     NUMERIC,
  num_medal_bonus   NUMERIC,
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

  c := fn_score_by_engine(p.engine_code, p.n, p_place, p.n, p_place, p.n - p_place,
                          p.mp_value, p.de_round,
                          p.podium_gold, p.podium_silver, p.podium_bronze);

  RETURN QUERY SELECT
    p.engine_code,
    COALESCE(ROUND(c.num_place_pts, 2),    -1),
    COALESCE(ROUND(c.num_de_bonus, 2),     -1),
    COALESCE(ROUND(c.num_podium_bonus, 2), -1),
    COALESCE(ROUND(c.num_field_pts, 2),    -1),
    COALESCE(ROUND(c.num_below_pts, 2),    -1),
    COALESCE(ROUND(c.num_medal_bonus, 2),  -1),
    c.enum_score_method::TEXT,
    ROUND((COALESCE(c.num_place_pts, 0) + COALESCE(c.num_de_bonus, 0)
           + COALESCE(c.num_podium_bonus, 0) + COALESCE(c.num_field_pts, 0)
           + COALESCE(c.num_below_pts, 0) + COALESCE(c.num_medal_bonus, 0))
          * p.multiplier, 2);
END;
$$;

COMMENT ON FUNCTION fn_preview_tournament_score(INT, INT) IS
  'Read-only preview over the same resolver, dispatcher and strategies the '
  'writer uses. STABLE, so it cannot write. Assumes one category (K = N, '
  'm = place, b = N - place) and rounds exactly as the writer stores.';

-- =============================================================================
-- 8 · Governance: type_engines in export, import and apply (ADR-097)
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_export_scoring_config(p_id_season INT)
RETURNS JSONB
LANGUAGE sql
STABLE SECURITY DEFINER
AS $$
  SELECT jsonb_build_object(
    'id_season',                sc.id_season,
    'season_code',              s.txt_code,
    'engine_code',               se.txt_code,
    'mp_value',                 sc.int_mp_value,
    'podium_gold',              sc.int_podium_gold,
    'podium_silver',            sc.int_podium_silver,
    'podium_bronze',            sc.int_podium_bronze,
    'ppw_multiplier',           sc.num_ppw_multiplier,
    'ppw_best_count',           sc.int_ppw_best_count,
    'ppw_total_rounds',         sc.int_ppw_total_rounds,
    'mpw_multiplier',           sc.num_mpw_multiplier,
    'mpw_droppable',            sc.bool_mpw_droppable,
    'pew_multiplier',           sc.num_pew_multiplier,
    'pew_best_count',           sc.int_pew_best_count,
    'mew_multiplier',           sc.num_mew_multiplier,
    'mew_droppable',            sc.bool_mew_droppable,
    'msw_multiplier',           sc.num_msw_multiplier,
    'psw_multiplier',           sc.num_psw_multiplier,
    'pps_multiplier',           sc.num_pps_multiplier,
    'mps_multiplier',           sc.num_mps_multiplier,
    'min_participants_evf',     sc.int_min_participants_evf,
    'min_participants_ppw',     sc.int_min_participants_ppw,
    'show_evf_toggle',          sc.bool_show_evf_toggle,
    'show_evf_toggle_calendar', sc.bool_show_evf_toggle_calendar,
    'ranking_rules',            sc.json_ranking_rules,
    'default_ranking_mode',     sc.enum_default_ranking_mode,
    'extra',                    sc.json_extra,
    'scoring_admin_locked',     s.ts_scoring_locked_at IS NOT NULL,
    'scoring_locked_at',        s.ts_scoring_locked_at,
    -- ADR-103 §2: the RESOLVED engine of every type, so an unchanged resend
    -- of a locked season compares equal whether a row names its engine or
    -- inherits the season's.
    'type_engines', (
      SELECT jsonb_object_agg(tc.enum_type::TEXT, tse.txt_code)
        FROM tbl_scoring_type_config tc
        JOIN tbl_scoring_engine tse
          ON tse.id_engine = COALESCE(tc.id_scoring_engine, s.id_scoring_engine)
       WHERE tc.id_config = sc.id_config)
  )
  FROM tbl_scoring_config sc
  JOIN tbl_season s ON s.id_season = sc.id_season
  LEFT JOIN tbl_scoring_engine se ON se.id_engine = s.id_scoring_engine
  WHERE sc.id_season = p_id_season;
$$;

CREATE OR REPLACE FUNCTION fn_apply_scoring_config_write(p_config JSONB)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_season INT := (p_config->>'id_season')::INT;
  v_new_engine_id INT;
  v_type        TEXT;
  v_type_code   TEXT;
  v_type_engine INT;
BEGIN
  IF p_config->>'engine_code' IS NOT NULL THEN
    SELECT id_engine INTO v_new_engine_id
      FROM tbl_scoring_engine WHERE txt_code = p_config->>'engine_code';
    IF v_new_engine_id IS NULL THEN
      RAISE EXCEPTION 'Unknown scoring engine: %', p_config->>'engine_code';
    END IF;
    UPDATE tbl_season SET id_scoring_engine = v_new_engine_id WHERE id_season = v_season;
  END IF;

  INSERT INTO tbl_scoring_config (
    id_season,
    int_mp_value,
    int_podium_gold, int_podium_silver, int_podium_bronze,
    num_ppw_multiplier, int_ppw_best_count, int_ppw_total_rounds,
    num_mpw_multiplier, bool_mpw_droppable,
    num_pew_multiplier, int_pew_best_count,
    num_mew_multiplier, bool_mew_droppable,
    num_msw_multiplier, num_psw_multiplier,
    num_pps_multiplier, num_mps_multiplier,
    int_min_participants_evf, int_min_participants_ppw,
    bool_show_evf_toggle,
    bool_show_evf_toggle_calendar,
    json_ranking_rules, enum_default_ranking_mode, json_extra,
    ts_updated
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
    COALESCE((p_config->>'psw_multiplier')::NUMERIC,     2.0),
    COALESCE((p_config->>'pps_multiplier')::NUMERIC,     1.0),
    COALESCE((p_config->>'mps_multiplier')::NUMERIC,     1.0),
    COALESCE((p_config->>'min_participants_evf')::INT,   5),
    COALESCE((p_config->>'min_participants_ppw')::INT,   1),
    COALESCE((p_config->>'show_evf_toggle')::BOOLEAN,    FALSE),
    COALESCE((p_config->>'show_evf_toggle_calendar')::BOOLEAN, TRUE),
    p_config->'ranking_rules',
    COALESCE((p_config->>'default_ranking_mode')::enum_ranking_mode, 'PPW'::enum_ranking_mode),
    COALESCE(p_config->'extra', '{}'::JSONB),
    NOW()
  )
  ON CONFLICT (id_season) DO UPDATE SET
    int_mp_value                  = COALESCE((p_config->>'mp_value')::INT,              tbl_scoring_config.int_mp_value),
    int_podium_gold               = COALESCE((p_config->>'podium_gold')::INT,            tbl_scoring_config.int_podium_gold),
    int_podium_silver             = COALESCE((p_config->>'podium_silver')::INT,          tbl_scoring_config.int_podium_silver),
    int_podium_bronze             = COALESCE((p_config->>'podium_bronze')::INT,          tbl_scoring_config.int_podium_bronze),
    num_ppw_multiplier            = COALESCE((p_config->>'ppw_multiplier')::NUMERIC,     tbl_scoring_config.num_ppw_multiplier),
    int_ppw_best_count            = COALESCE((p_config->>'ppw_best_count')::INT,         tbl_scoring_config.int_ppw_best_count),
    int_ppw_total_rounds          = COALESCE((p_config->>'ppw_total_rounds')::INT,       tbl_scoring_config.int_ppw_total_rounds),
    num_mpw_multiplier            = COALESCE((p_config->>'mpw_multiplier')::NUMERIC,     tbl_scoring_config.num_mpw_multiplier),
    bool_mpw_droppable            = COALESCE((p_config->>'mpw_droppable')::BOOLEAN,      tbl_scoring_config.bool_mpw_droppable),
    num_pew_multiplier            = COALESCE((p_config->>'pew_multiplier')::NUMERIC,     tbl_scoring_config.num_pew_multiplier),
    int_pew_best_count            = COALESCE((p_config->>'pew_best_count')::INT,         tbl_scoring_config.int_pew_best_count),
    num_mew_multiplier            = COALESCE((p_config->>'mew_multiplier')::NUMERIC,     tbl_scoring_config.num_mew_multiplier),
    bool_mew_droppable            = COALESCE((p_config->>'mew_droppable')::BOOLEAN,      tbl_scoring_config.bool_mew_droppable),
    num_msw_multiplier            = COALESCE((p_config->>'msw_multiplier')::NUMERIC,     tbl_scoring_config.num_msw_multiplier),
    num_psw_multiplier            = COALESCE((p_config->>'psw_multiplier')::NUMERIC,     tbl_scoring_config.num_psw_multiplier),
    num_pps_multiplier            = COALESCE((p_config->>'pps_multiplier')::NUMERIC,     tbl_scoring_config.num_pps_multiplier),
    num_mps_multiplier            = COALESCE((p_config->>'mps_multiplier')::NUMERIC,     tbl_scoring_config.num_mps_multiplier),
    int_min_participants_evf      = COALESCE((p_config->>'min_participants_evf')::INT,   tbl_scoring_config.int_min_participants_evf),
    int_min_participants_ppw      = COALESCE((p_config->>'min_participants_ppw')::INT,   tbl_scoring_config.int_min_participants_ppw),
    bool_show_evf_toggle          = COALESCE((p_config->>'show_evf_toggle')::BOOLEAN,    tbl_scoring_config.bool_show_evf_toggle),
    bool_show_evf_toggle_calendar = COALESCE((p_config->>'show_evf_toggle_calendar')::BOOLEAN, tbl_scoring_config.bool_show_evf_toggle_calendar),
    json_ranking_rules            = COALESCE(NULLIF(p_config->'ranking_rules', 'null'::jsonb), tbl_scoring_config.json_ranking_rules),
    enum_default_ranking_mode     = COALESCE((p_config->>'default_ranking_mode')::enum_ranking_mode, tbl_scoring_config.enum_default_ranking_mode),
    json_extra                    = COALESCE(p_config->'extra',                          tbl_scoring_config.json_extra),
    ts_updated                    = NOW();

  -- ADR-103 §2: the engine per type. The upsert above has (re)projected the
  -- type rows, so each named type exists here. A row is written only when the
  -- type's RESOLVED engine changes, so resending the export never pins a type
  -- that was inheriting the season's engine.
  IF jsonb_typeof(p_config->'type_engines') = 'object' THEN
    FOR v_type, v_type_code IN
      SELECT key, value FROM jsonb_each_text(p_config->'type_engines')
    LOOP
      SELECT id_engine INTO v_type_engine
        FROM tbl_scoring_engine WHERE txt_code = v_type_code;
      IF v_type_engine IS NULL THEN
        RAISE EXCEPTION 'Unknown scoring engine: %', v_type_code;
      END IF;
      IF v_type_code IS DISTINCT FROM fn_get_type_engine(v_season, v_type) THEN
        UPDATE tbl_scoring_type_config tc
           SET id_scoring_engine = v_type_engine,
               ts_updated        = NOW()
          FROM tbl_scoring_config c
         WHERE c.id_config = tc.id_config
           AND c.id_season = v_season
           AND tc.enum_type::TEXT = v_type;
      END IF;
    END LOOP;
  END IF;
END;
$$;

COMMENT ON FUNCTION fn_apply_scoring_config_write(JSONB) IS
  'Unconditional COALESCE-over-current write into tbl_scoring_config, '
  'engine_code onto tbl_season and type_engines onto tbl_scoring_type_config. '
  'No lock check -- callers decide separately whether reaching this point is '
  'allowed. Never expose to authenticated.';

CREATE OR REPLACE FUNCTION fn_import_scoring_config(p_config JSONB)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_season INT := (p_config->>'id_season')::INT;
  v_locked BOOLEAN;
  v_current tbl_scoring_config%ROWTYPE;
  v_new_engine_id INT;

  v_mp_value   INT;
  v_pg NUMERIC; v_ps NUMERIC; v_pb NUMERIC;
  v_ppw NUMERIC; v_mpw NUMERIC; v_pew NUMERIC; v_mew NUMERIC;
  v_msw NUMERIC; v_psw NUMERIC; v_pps NUMERIC; v_mps NUMERIC;
  v_min_evf INT; v_min_ppw INT;
  v_rules JSONB;
  v_mode  enum_ranking_mode;
  v_type      TEXT;
  v_type_code TEXT;
BEGIN
  IF v_season IS NULL THEN
    RAISE EXCEPTION 'id_season is required in the config JSON';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM tbl_season WHERE id_season = v_season) THEN
    RAISE EXCEPTION 'Season % does not exist', v_season;
  END IF;

  SELECT ts_scoring_locked_at IS NOT NULL INTO v_locked
    FROM tbl_season WHERE id_season = v_season;

  SELECT * INTO v_current FROM tbl_scoring_config WHERE id_season = v_season;

  IF v_locked AND v_current.id_config IS NOT NULL THEN
    v_mp_value := COALESCE((p_config->>'mp_value')::INT,            v_current.int_mp_value);
    v_pg       := COALESCE((p_config->>'podium_gold')::NUMERIC,     v_current.int_podium_gold);
    v_ps       := COALESCE((p_config->>'podium_silver')::NUMERIC,   v_current.int_podium_silver);
    v_pb       := COALESCE((p_config->>'podium_bronze')::NUMERIC,   v_current.int_podium_bronze);
    v_ppw      := COALESCE((p_config->>'ppw_multiplier')::NUMERIC,  v_current.num_ppw_multiplier);
    v_mpw      := COALESCE((p_config->>'mpw_multiplier')::NUMERIC,  v_current.num_mpw_multiplier);
    v_pew      := COALESCE((p_config->>'pew_multiplier')::NUMERIC,  v_current.num_pew_multiplier);
    v_mew      := COALESCE((p_config->>'mew_multiplier')::NUMERIC,  v_current.num_mew_multiplier);
    v_msw      := COALESCE((p_config->>'msw_multiplier')::NUMERIC,  v_current.num_msw_multiplier);
    v_psw      := COALESCE((p_config->>'psw_multiplier')::NUMERIC,  v_current.num_psw_multiplier);
    v_pps      := COALESCE((p_config->>'pps_multiplier')::NUMERIC,  v_current.num_pps_multiplier);
    v_mps      := COALESCE((p_config->>'mps_multiplier')::NUMERIC,  v_current.num_mps_multiplier);
    v_min_evf  := COALESCE((p_config->>'min_participants_evf')::INT, v_current.int_min_participants_evf);
    v_min_ppw  := COALESCE((p_config->>'min_participants_ppw')::INT, v_current.int_min_participants_ppw);
    v_rules    := COALESCE(NULLIF(p_config->'ranking_rules', 'null'::jsonb), v_current.json_ranking_rules);
    v_mode     := COALESCE((p_config->>'default_ranking_mode')::enum_ranking_mode, v_current.enum_default_ranking_mode);

    IF v_mp_value  IS DISTINCT FROM v_current.int_mp_value THEN PERFORM fn_raise_scoring_locked(v_season, 'mp_value'); END IF;
    IF v_pg::INT   IS DISTINCT FROM v_current.int_podium_gold THEN PERFORM fn_raise_scoring_locked(v_season, 'podium_gold'); END IF;
    IF v_ps::INT   IS DISTINCT FROM v_current.int_podium_silver THEN PERFORM fn_raise_scoring_locked(v_season, 'podium_silver'); END IF;
    IF v_pb::INT   IS DISTINCT FROM v_current.int_podium_bronze THEN PERFORM fn_raise_scoring_locked(v_season, 'podium_bronze'); END IF;
    IF v_ppw       IS DISTINCT FROM v_current.num_ppw_multiplier THEN PERFORM fn_raise_scoring_locked(v_season, 'ppw_multiplier'); END IF;
    IF v_mpw       IS DISTINCT FROM v_current.num_mpw_multiplier THEN PERFORM fn_raise_scoring_locked(v_season, 'mpw_multiplier'); END IF;
    IF v_pew       IS DISTINCT FROM v_current.num_pew_multiplier THEN PERFORM fn_raise_scoring_locked(v_season, 'pew_multiplier'); END IF;
    IF v_mew       IS DISTINCT FROM v_current.num_mew_multiplier THEN PERFORM fn_raise_scoring_locked(v_season, 'mew_multiplier'); END IF;
    IF v_msw       IS DISTINCT FROM v_current.num_msw_multiplier THEN PERFORM fn_raise_scoring_locked(v_season, 'msw_multiplier'); END IF;
    IF v_psw       IS DISTINCT FROM v_current.num_psw_multiplier THEN PERFORM fn_raise_scoring_locked(v_season, 'psw_multiplier'); END IF;
    IF v_pps       IS DISTINCT FROM v_current.num_pps_multiplier THEN PERFORM fn_raise_scoring_locked(v_season, 'pps_multiplier'); END IF;
    IF v_mps       IS DISTINCT FROM v_current.num_mps_multiplier THEN PERFORM fn_raise_scoring_locked(v_season, 'mps_multiplier'); END IF;
    IF v_min_evf   IS DISTINCT FROM v_current.int_min_participants_evf THEN PERFORM fn_raise_scoring_locked(v_season, 'min_participants_evf'); END IF;
    IF v_min_ppw   IS DISTINCT FROM v_current.int_min_participants_ppw THEN PERFORM fn_raise_scoring_locked(v_season, 'min_participants_ppw'); END IF;
    IF v_rules     IS DISTINCT FROM v_current.json_ranking_rules THEN PERFORM fn_raise_scoring_locked(v_season, 'ranking_rules'); END IF;
    IF v_mode      IS DISTINCT FROM v_current.enum_default_ranking_mode THEN PERFORM fn_raise_scoring_locked(v_season, 'default_ranking_mode'); END IF;
  END IF;

  IF p_config->>'engine_code' IS NOT NULL THEN
    SELECT id_engine INTO v_new_engine_id
      FROM tbl_scoring_engine WHERE txt_code = p_config->>'engine_code';
    IF v_new_engine_id IS NULL THEN
      RAISE EXCEPTION 'Unknown scoring engine: %', p_config->>'engine_code';
    END IF;
    IF v_locked THEN
      IF v_new_engine_id IS DISTINCT FROM (SELECT id_scoring_engine FROM tbl_season WHERE id_season = v_season) THEN
        PERFORM fn_raise_scoring_locked(v_season, 'engine_code');
      END IF;
    END IF;
  END IF;

  -- ADR-103 §2: a type's engine is a governed field. Compared against the
  -- resolved engine, so an unchanged resend of a locked season passes.
  IF jsonb_typeof(p_config->'type_engines') = 'object' THEN
    FOR v_type, v_type_code IN
      SELECT key, value FROM jsonb_each_text(p_config->'type_engines')
    LOOP
      IF NOT EXISTS (SELECT 1 FROM tbl_scoring_engine WHERE txt_code = v_type_code) THEN
        RAISE EXCEPTION 'Unknown scoring engine: %', v_type_code;
      END IF;
      IF v_locked AND v_type_code IS DISTINCT FROM fn_get_type_engine(v_season, v_type) THEN
        PERFORM fn_raise_scoring_locked(v_season, 'type_engines');
      END IF;
    END LOOP;
  END IF;

  PERFORM fn_apply_scoring_config_write(p_config);
END;
$$;

-- =============================================================================
-- 9 · SPWS_FIELD_SCALED_V1_2026_2027 is deleted (ADR-103 §3)
-- =============================================================================
-- It never scored a result: 0 revisions and 0 results on CERT and PROD
-- (27 Sep 2026). A season still assigned to it moves to its successor. A
-- season that DID score on it would have scores no engine could reproduce
-- once the strategy is dropped, so that case aborts the migration instead;
-- scripts/check-scoring-migration-preflight.sh checks it before a release.
DO $$
DECLARE
  v_field  INT;
  v_new    INT;
  v_scored TEXT;
BEGIN
  SELECT id_engine INTO v_field FROM tbl_scoring_engine WHERE txt_code = 'SPWS_FIELD_SCALED_V1_2026_2027';
  IF v_field IS NULL THEN
    RETURN;
  END IF;
  SELECT id_engine INTO v_new FROM tbl_scoring_engine WHERE txt_code = 'SPWS_PLACE_MEDAL_V1_2026_2027';

  SELECT string_agg(DISTINCT s.txt_code, ', ')
    INTO v_scored
    FROM tbl_season s
   WHERE (s.id_scoring_engine = v_field
          AND EXISTS (SELECT 1 FROM tbl_result r
                        JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
                        JOIN tbl_event e      ON e.id_event      = t.id_event
                       WHERE e.id_season = s.id_season AND r.ts_points_calc IS NOT NULL))
      OR EXISTS (SELECT 1 FROM tbl_scoring_config_revision rv
                  WHERE rv.id_season = s.id_season AND rv.id_engine = v_field);

  IF v_scored IS NOT NULL THEN
    RAISE EXCEPTION
      'Cannot delete SPWS_FIELD_SCALED_V1_2026_2027: season(s) % scored results or hold a revision on it. Those scores must be moved by a privileged revision (fn_revise_and_rescore_season) before this migration applies.',
      v_scored;
  END IF;

  UPDATE tbl_season SET id_scoring_engine = v_new WHERE id_scoring_engine = v_field;
  DELETE FROM tbl_scoring_engine WHERE id_engine = v_field;
END $$;

DROP FUNCTION IF EXISTS fn_score_spws_field_scaled_v1_2026_2027(
  INT, INT, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC);

-- =============================================================================
-- 10 · Engine assignment backfill, with the §11 gate
-- =============================================================================
-- Replaces the 2026-09-19 version, which named the deleted engine. 2026/2027
-- gets the new engine as its default and all eight type rows set explicitly
-- (FR-137): PPW and MPW on the new engine; PPS, MPS, PEW, MEW, MSW and PSW on
-- EVF classic (ADR-103 §2 as amended 2026-09-28 — the PZSz senior types keep
-- the algorithm they had). Earlier seasons keep NULL type rows and their EVF
-- classic season engine, which is how they were scored.
CREATE OR REPLACE FUNCTION fn_backfill_scoring_engines()
RETURNS VOID
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $backfill$
DECLARE
  v_classic   INT;
  v_new       INT;
  v_deviant   TEXT;
  v_season    INT;
  v_scored    INT;
  v_mismatch  TEXT;
BEGIN
  SELECT id_engine INTO v_classic FROM tbl_scoring_engine WHERE txt_code = 'EVF_CLASSIC_V1_2025_2026';
  SELECT id_engine INTO v_new     FROM tbl_scoring_engine WHERE txt_code = 'SPWS_PLACE_MEDAL_V1_2026_2027';

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
         SET id_scoring_engine = v_new
       WHERE id_season = v_season AND id_scoring_engine IS NULL;

      UPDATE tbl_scoring_type_config tc
         SET id_scoring_engine = CASE WHEN tc.enum_type::TEXT IN ('PPW', 'MPW')
                                      THEN v_new ELSE v_classic END,
             ts_updated = NOW()
        FROM tbl_scoring_config c
       WHERE c.id_config = tc.id_config
         AND c.id_season = v_season
         AND tc.id_scoring_engine IS NULL;
    ELSE
      -- The §11 gate: a season that already holds scores is never reassigned
      -- here. A board-authorized privileged revision reaches the new layout.
      SELECT string_agg(tc.enum_type::TEXT, ', ' ORDER BY tc.enum_type::TEXT)
        INTO v_mismatch
        FROM tbl_scoring_type_config tc
        JOIN tbl_scoring_config c ON c.id_config = tc.id_config
        JOIN tbl_season s         ON s.id_season = c.id_season
       WHERE c.id_season = v_season
         AND COALESCE(tc.id_scoring_engine, s.id_scoring_engine) IS DISTINCT FROM
             CASE WHEN tc.enum_type::TEXT IN ('PPW', 'MPW') THEN v_new ELSE v_classic END;
      IF v_mismatch IS NOT NULL THEN
        RAISE NOTICE
          'SPWS-2026-2027 holds % scored result(s); types % are not on their ADR-103 engine and are left unchanged. A privileged revision (fn_revise_and_rescore_season) is required.',
          v_scored, v_mismatch;
      END IF;
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
  'Idempotent engine backfill (ADR-103 §2): EVF classic for history, and for '
  'an unscored SPWS-2026-2027 the new engine as season default with all eight '
  'type rows set explicitly. Never reassigns a scored season. Called again from '
  'supabase/seed_post_backfill.sql because migrations run before the seed '
  '(ADR-036 amendment).';

SELECT fn_backfill_scoring_engines();

-- History is EVF classic: name the method on every scored row. A schema
-- backfill, not an edit, so the per-row audit trigger is held for this one
-- statement.
CREATE OR REPLACE FUNCTION fn_backfill_score_method()
RETURNS VOID
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  ALTER TABLE tbl_result DISABLE TRIGGER trg_audit_result;
  UPDATE tbl_result r
     SET enum_score_method = 'EVF_CLASSIC'
    FROM tbl_tournament t
    JOIN tbl_event e ON e.id_event = t.id_event
   WHERE t.id_tournament = r.id_tournament
     AND r.ts_points_calc IS NOT NULL
     AND r.enum_score_method IS NULL
     AND fn_get_type_engine(e.id_season, t.enum_type::TEXT) = 'EVF_CLASSIC_V1_2025_2026';
  ALTER TABLE tbl_result ENABLE TRIGGER trg_audit_result;
END;
$$;

COMMENT ON FUNCTION fn_backfill_score_method() IS
  'Names EVF_CLASSIC on every scored result of a type scored by EVF classic '
  'whose method is still NULL (ADR-103 §5: history is EVF_CLASSIC with -1 in '
  'the new columns). Idempotent. Called again from seed_post_backfill.sql.';

SELECT fn_backfill_score_method();

-- =============================================================================
-- 11 · Ranking entry through PPW or MPW (ADR-103 §6)
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_backfill_ranking_entry_types()
RETURNS VOID
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  -- Only an unlocked season: the rules are a governed field (ADR-097).
  UPDATE tbl_scoring_config c
     SET json_ranking_rules = c.json_ranking_rules || '{"entry_types": ["PPW", "MPW"]}'::JSONB,
         ts_updated         = NOW()
    FROM tbl_season s
   WHERE s.id_season = c.id_season
     AND s.txt_code = 'SPWS-2026-2027'
     AND s.ts_scoring_locked_at IS NULL
     AND c.json_ranking_rules IS NOT NULL
     AND NOT (c.json_ranking_rules ? 'entry_types');
END;
$$;

COMMENT ON FUNCTION fn_backfill_ranking_entry_types() IS
  'Adds entry_types ["PPW","MPW"] to the SPWS-2026-2027 Season Scoring Rules '
  'while the season is unlocked (ADR-103 §6). Idempotent. Called again from '
  'seed_post_backfill.sql, because the rules arrive with the seed.';

SELECT fn_backfill_ranking_entry_types();

-- The entry gate. Both full-ranking bodies admit a fencer only when the rules
-- carry no entry_types, or the fencer has a result of one of those types in
-- the ranking's window: the ranked season, plus the previous season when the
-- ranking is rolling, in any weapon. Everything else in both bodies is
-- unchanged; what a fencer SCORES still comes from every type the buckets name.
CREATE OR REPLACE FUNCTION public.fn_ranking_full_event_code_matching(p_weapon enum_weapon_type, p_gender enum_gender_type, p_category enum_age_category, p_season integer DEFAULT NULL::integer, p_rolling boolean DEFAULT false)
 RETURNS TABLE(rank integer, id_fencer integer, fencer_name text, spws_total numeric, evf_plus_total numeric, total_score numeric, bool_has_carryover boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_season_id      INT;
  v_rules          JSONB;
  v_prev_season_id INT;
  v_season_end_yr  INT;
  v_entry_gate     BOOLEAN;
  v_entry_types    TEXT[];
BEGIN
  v_season_id := COALESCE(
    p_season,
    (SELECT s.id_season FROM tbl_season s WHERE s.bool_active LIMIT 1)
  );

  SELECT sc.json_ranking_rules INTO v_rules
    FROM tbl_scoring_config sc WHERE sc.id_season = v_season_id;

  SELECT EXTRACT(YEAR FROM s.dt_end)::INT INTO v_season_end_yr
    FROM tbl_season s WHERE s.id_season = v_season_id;

  -- ADR-103 §6: ranking entry through the types the rules name.
  v_entry_gate  := COALESCE(jsonb_typeof(v_rules -> 'entry_types') = 'array', FALSE);
  v_entry_types := ARRAY(SELECT jsonb_array_elements_text(
                           CASE WHEN v_entry_gate THEN v_rules -> 'entry_types' ELSE '[]'::JSONB END));

  IF p_rolling THEN
    SELECT s.id_season INTO v_prev_season_id
      FROM tbl_season s
     WHERE s.dt_end < (SELECT s2.dt_start FROM tbl_season s2 WHERE s2.id_season = v_season_id)
     ORDER BY s.dt_end DESC
     LIMIT 1;
  END IF;

  RETURN QUERY
  WITH
    raw_buckets AS (
      SELECT section, grp, types, best, always_include, bucket_idx
        FROM fn_ranking_rules_canonical(v_rules)
    ),
    rules_types AS (
      SELECT DISTINCT unnest(types) AS type_code FROM raw_buckets
    ),
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
    current_eligible AS (
      SELECT
        r.id_fencer            AS fid,
        r.num_final_score      AS score,
        t.enum_type::TEXT      AS type_code,
        FALSE                  AS is_carried
      FROM tbl_result r
      JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
      JOIN tbl_event e      ON e.id_event = t.id_event
      JOIN tbl_fencer f     ON f.id_fencer = r.id_fencer
      JOIN tbl_season s     ON s.id_season = e.id_season
      WHERE e.id_season = v_season_id
        AND t.enum_weapon = p_weapon
        AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender
        AND COALESCE(
          fn_age_category(f.int_birth_year, EXTRACT(YEAR FROM s.dt_end)::INT),
          t.enum_age_category
        ) = p_category
        AND r.num_final_score IS NOT NULL
        AND r.id_fencer IS NOT NULL
    ),
    carried_eligible AS (
      SELECT
        r.id_fencer            AS fid,
        r.num_final_score      AS score,
        t.enum_type::TEXT      AS type_code,
        TRUE                   AS is_carried
      FROM tbl_result r
      JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
      JOIN tbl_event e      ON e.id_event = t.id_event
      JOIN tbl_fencer f     ON f.id_fencer = r.id_fencer
      WHERE p_rolling
        AND v_prev_season_id IS NOT NULL
        AND e.id_season = v_prev_season_id
        AND t.enum_weapon = p_weapon
        AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender
        AND COALESCE(fn_age_category(f.int_birth_year, v_season_end_yr), t.enum_age_category) = p_category
        AND r.num_final_score IS NOT NULL
        AND r.id_fencer IS NOT NULL
        AND t.enum_type::TEXT IN (SELECT type_code FROM rules_types)
        AND t.enum_type::TEXT NOT IN ('PPS', 'MPS')  -- SS26.RANK.12: begins disabled
        AND fn_event_position(e.txt_code) NOT IN (SELECT pos FROM completed_positions)
    ),
    eligible AS (
      SELECT fid, score, type_code, is_carried FROM current_eligible
      UNION ALL
      SELECT fid, score, type_code, is_carried FROM carried_eligible
    ),
    bucket_results AS (
      SELECT
        e.fid, e.score, e.is_carried,
        b.grp, b.section, b.bucket_idx, b.best, b.always_include,
        ROW_NUMBER() OVER (
          PARTITION BY b.section, b.bucket_idx, e.fid ORDER BY e.score DESC
        ) AS rn
      FROM eligible e CROSS JOIN raw_buckets b
      WHERE e.type_code = ANY(b.types)
    ),
    selected AS (
      SELECT fid, score, grp, is_carried
      FROM bucket_results
      WHERE COALESCE(always_include, FALSE) OR rn <= best
    ),
    all_fencers AS (
      SELECT DISTINCT el.fid FROM eligible el
       WHERE NOT v_entry_gate
          OR EXISTS (
               SELECT 1
                 FROM tbl_result er
                 JOIN tbl_tournament et ON et.id_tournament = er.id_tournament
                 JOIN tbl_event ee      ON ee.id_event      = et.id_event
                WHERE er.id_fencer = el.fid
                  AND et.enum_type::TEXT = ANY (v_entry_types)
                  AND (ee.id_season = v_season_id
                       OR (p_rolling AND ee.id_season = v_prev_season_id)))
    ),
    totals AS (
      SELECT
        af.fid,
        COALESCE(SUM(sel.score) FILTER (WHERE sel.grp = 'spws'), 0) AS spws_total,
        COALESCE(SUM(sel.score) FILTER (WHERE sel.grp = 'evf_plus'), 0) AS evf_plus_total,
        BOOL_OR(sel.is_carried) AS has_carry
      FROM all_fencers af
      LEFT JOIN selected sel ON sel.fid = af.fid
      GROUP BY af.fid
    )
  SELECT
    ROW_NUMBER() OVER (ORDER BY (t.spws_total + t.evf_plus_total) DESC)::INT AS rank,
    t.fid AS id_fencer,
    COALESCE(fe.txt_surname || ' ' || fe.txt_first_name, '') AS fencer_name,
    t.spws_total,
    t.evf_plus_total,
    (t.spws_total + t.evf_plus_total) AS total_score,
    COALESCE(t.has_carry, FALSE) AS bool_has_carryover
  FROM totals t
  LEFT JOIN tbl_fencer fe ON fe.id_fencer = t.fid
  WHERE (t.spws_total + t.evf_plus_total) > 0
  ORDER BY (t.spws_total + t.evf_plus_total) DESC;
END;
$function$;
CREATE OR REPLACE FUNCTION public.fn_ranking_full_event_fk_matching(p_weapon enum_weapon_type, p_gender enum_gender_type, p_category enum_age_category, p_season integer DEFAULT NULL::integer, p_rolling boolean DEFAULT false)
 RETURNS TABLE(rank integer, id_fencer integer, fencer_name text, spws_total numeric, evf_plus_total numeric, total_score numeric, bool_has_carryover boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_season_id     INT;
  v_rules         JSONB;
  v_season_end_yr INT;
  v_prev_season_id INT;
  v_entry_gate     BOOLEAN;
  v_entry_types    TEXT[];
BEGIN
  v_season_id := COALESCE(
    p_season,
    (SELECT s.id_season FROM tbl_season s WHERE s.bool_active LIMIT 1)
  );

  SELECT sc.json_ranking_rules INTO v_rules
    FROM tbl_scoring_config sc WHERE sc.id_season = v_season_id;

  SELECT EXTRACT(YEAR FROM dt_end)::INT INTO v_season_end_yr
    FROM tbl_season WHERE id_season = v_season_id;

  -- ADR-103 §6: ranking entry through the types the rules name.
  v_entry_gate  := COALESCE(jsonb_typeof(v_rules -> 'entry_types') = 'array', FALSE);
  v_entry_types := ARRAY(SELECT jsonb_array_elements_text(
                           CASE WHEN v_entry_gate THEN v_rules -> 'entry_types' ELSE '[]'::JSONB END));

  -- The previous season, for the rolling entry window: the same resolution
  -- fn_ranking_full_event_code_matching uses.
  IF p_rolling THEN
    SELECT s.id_season INTO v_prev_season_id
      FROM tbl_season s
     WHERE s.dt_end < (SELECT s2.dt_start FROM tbl_season s2 WHERE s2.id_season = v_season_id)
     ORDER BY s.dt_end DESC
     LIMIT 1;
  END IF;

  RETURN QUERY
  WITH
    raw_buckets AS (
      SELECT section, grp, types, best, always_include, bucket_idx
        FROM fn_ranking_rules_canonical(v_rules)
    ),
    eligible AS (
      SELECT
        r.id_fencer       AS fid,
        r.num_final_score AS score,
        t.enum_type::TEXT AS type_code,
        v.is_carried      AS is_carried
      FROM vw_eligible_event v
      JOIN tbl_tournament t ON t.id_event = v.id_event
      JOIN tbl_result r     ON r.id_tournament = t.id_tournament
      JOIN tbl_fencer f     ON f.id_fencer = r.id_fencer
      WHERE v.effective_season_id = v_season_id
        AND (NOT v.is_carried OR p_rolling)
        AND t.enum_weapon = p_weapon
        AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender
        AND COALESCE(fn_age_category(f.int_birth_year, v_season_end_yr), t.enum_age_category) = p_category
        AND r.num_final_score IS NOT NULL
        AND r.id_fencer IS NOT NULL
        AND (NOT v.is_carried OR t.enum_type::TEXT NOT IN ('PPS', 'MPS'))  -- SS26.RANK.12
    ),
    bucket_results AS (
      SELECT
        e.fid, e.score, e.is_carried,
        b.grp, b.section, b.bucket_idx, b.best, b.always_include,
        ROW_NUMBER() OVER (
          PARTITION BY b.section, b.bucket_idx, e.fid ORDER BY e.score DESC
        ) AS rn
      FROM eligible e CROSS JOIN raw_buckets b
      WHERE e.type_code = ANY(b.types)
    ),
    selected AS (
      SELECT fid, score, grp, is_carried
      FROM bucket_results
      WHERE COALESCE(always_include, FALSE) OR rn <= best
    ),
    all_fencers AS (
      SELECT DISTINCT el.fid FROM eligible el
       WHERE NOT v_entry_gate
          OR EXISTS (
               SELECT 1
                 FROM tbl_result er
                 JOIN tbl_tournament et ON et.id_tournament = er.id_tournament
                 JOIN tbl_event ee      ON ee.id_event      = et.id_event
                WHERE er.id_fencer = el.fid
                  AND et.enum_type::TEXT = ANY (v_entry_types)
                  AND (ee.id_season = v_season_id
                       OR (p_rolling AND ee.id_season = v_prev_season_id)))
    ),
    totals AS (
      SELECT
        af.fid,
        COALESCE(SUM(sel.score) FILTER (WHERE sel.grp = 'spws'), 0) AS spws_total,
        COALESCE(SUM(sel.score) FILTER (WHERE sel.grp = 'evf_plus'), 0) AS evf_plus_total,
        BOOL_OR(sel.is_carried) AS has_carry
      FROM all_fencers af
      LEFT JOIN selected sel ON sel.fid = af.fid
      GROUP BY af.fid
    )
  SELECT
    ROW_NUMBER() OVER (ORDER BY (t.spws_total + t.evf_plus_total) DESC)::INT AS rank,
    t.fid AS id_fencer,
    COALESCE(f.txt_surname || ' ' || f.txt_first_name, '') AS fencer_name,
    t.spws_total,
    t.evf_plus_total,
    (t.spws_total + t.evf_plus_total) AS total_score,
    COALESCE(t.has_carry, FALSE) AS bool_has_carryover
  FROM totals t
  LEFT JOIN tbl_fencer f ON f.id_fencer = t.fid
  WHERE (t.spws_total + t.evf_plus_total) > 0
  ORDER BY (t.spws_total + t.evf_plus_total) DESC;
END;
$function$;

-- The drilldown reads every component, labelled by method (ADR-103 §5); a
-- RETURNS TABLE change needs DROP + CREATE, so the trio is recreated and
-- re-granted exactly as before.
DROP FUNCTION IF EXISTS fn_fencer_scores_rolling(integer, enum_weapon_type, enum_gender_type, enum_age_category, integer);
DROP FUNCTION IF EXISTS fn_fencer_scores_rolling_event_code_matching(integer, enum_weapon_type, enum_gender_type, enum_age_category, integer);
DROP FUNCTION IF EXISTS fn_fencer_scores_rolling_event_fk_matching(integer, enum_weapon_type, enum_gender_type, enum_age_category, integer);
CREATE FUNCTION public.fn_fencer_scores_rolling_event_code_matching(p_fencer_id integer, p_weapon enum_weapon_type, p_gender enum_gender_type, p_category enum_age_category, p_season integer DEFAULT NULL::integer)
 RETURNS TABLE(id_result integer, id_fencer integer, fencer_name text, int_birth_year smallint, id_tournament integer, txt_tournament_code text, txt_tournament_name text, dt_tournament date, enum_type enum_tournament_type, enum_weapon enum_weapon_type, enum_gender enum_gender_type, enum_age_category enum_age_category, int_participant_count integer, num_multiplier numeric, int_place integer, num_place_pts numeric, num_de_bonus numeric, num_podium_bonus numeric, num_final_score numeric, ts_points_calc timestamp with time zone, id_season integer, txt_season_code text, url_results text, txt_location text, bool_carried_over boolean, txt_source_season_code text, int_category_count integer, int_category_place integer, int_below_count integer, num_field_pts numeric, num_below_pts numeric, num_medal_bonus numeric, enum_score_method text)
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
        r.int_category_count, r.int_category_place, r.int_below_count,
        r.num_field_pts, r.num_below_pts, r.num_medal_bonus,
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
        r.int_category_count, r.int_category_place, r.int_below_count,
        r.num_field_pts, r.num_below_pts, r.num_medal_bonus,
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
 RETURNS TABLE(id_result integer, id_fencer integer, fencer_name text, int_birth_year smallint, id_tournament integer, txt_tournament_code text, txt_tournament_name text, dt_tournament date, enum_type enum_tournament_type, enum_weapon enum_weapon_type, enum_gender enum_gender_type, enum_age_category enum_age_category, int_participant_count integer, num_multiplier numeric, int_place integer, num_place_pts numeric, num_de_bonus numeric, num_podium_bonus numeric, num_final_score numeric, ts_points_calc timestamp with time zone, id_season integer, txt_season_code text, url_results text, txt_location text, bool_carried_over boolean, txt_source_season_code text, int_category_count integer, int_category_place integer, int_below_count integer, num_field_pts numeric, num_below_pts numeric, num_medal_bonus numeric, enum_score_method text)
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
    r.int_category_count, r.int_category_place, r.int_below_count,
    r.num_field_pts, r.num_below_pts, r.num_medal_bonus,
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
 RETURNS TABLE(id_result integer, id_fencer integer, fencer_name text, int_birth_year smallint, id_tournament integer, txt_tournament_code text, txt_tournament_name text, dt_tournament date, enum_type enum_tournament_type, enum_weapon enum_weapon_type, enum_gender enum_gender_type, enum_age_category enum_age_category, int_participant_count integer, num_multiplier numeric, int_place integer, num_place_pts numeric, num_de_bonus numeric, num_podium_bonus numeric, num_final_score numeric, ts_points_calc timestamp with time zone, id_season integer, txt_season_code text, url_results text, txt_location text, bool_carried_over boolean, txt_source_season_code text, int_category_count integer, int_category_place integer, int_below_count integer, num_field_pts numeric, num_below_pts numeric, num_medal_bonus numeric, enum_score_method text)
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
GRANT EXECUTE ON FUNCTION fn_fencer_scores_rolling(integer, enum_weapon_type, enum_gender_type, enum_age_category, integer) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION fn_fencer_scores_rolling_event_code_matching(integer, enum_weapon_type, enum_gender_type, enum_age_category, integer) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION fn_fencer_scores_rolling_event_fk_matching(integer, enum_weapon_type, enum_gender_type, enum_age_category, integer) TO anon, authenticated, service_role;

CREATE OR REPLACE VIEW vw_score AS
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
    r.int_category_count,
    r.int_category_place,
    r.int_below_count,
    r.num_field_pts,
    r.num_below_pts,
    r.num_medal_bonus,
    r.enum_score_method
   FROM tbl_result r
     JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
     JOIN tbl_event e ON e.id_event = t.id_event
     JOIN tbl_season s ON s.id_season = e.id_season
     LEFT JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
  WHERE r.id_fencer IS NOT NULL;

-- =============================================================================
-- 12 · The writers carry K, m and b (ADR-103 §4-5)
-- =============================================================================
-- fn_ingest_tournament_results reads them as optional keys of each result
-- (absent means -1, the classic module's value); fn_commit_event_draft copies
-- them, and every new component, from the draft.
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
      enum_source_age_category,
      int_category_count, int_category_place, int_below_count
    )
    VALUES (
      v_fencer_id,
      p_tournament_id,
      (v_row ->> 'int_place')::INT,
      v_row ->> 'txt_scraped_name',
      COALESCE((v_row ->> 'num_confidence')::NUMERIC(5,2), 100),
      v_method,
      v_source_vcat,
      COALESCE((v_row ->> 'int_category_count')::INT, -1),
      COALESCE((v_row ->> 'int_category_place')::INT, -1),
      COALESCE((v_row ->> 'int_below_count')::INT, -1)
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
        enum_source_age_category,
        int_category_count, int_category_place, int_below_count,
        num_field_pts, num_below_pts, num_medal_bonus, enum_score_method
    )
    SELECT rd.id_fencer, m.id_tournament, rd.int_place, rd.enum_fencer_age_category,
           rd.txt_cross_cat, rd.num_place_pts, rd.num_de_bonus, rd.num_podium_bonus,
           rd.num_final_score, rd.ts_points_calc,
           rd.txt_scraped_name, rd.num_match_confidence, rd.enum_match_method,
           rd.enum_source_age_category,
           rd.int_category_count, rd.int_category_place, rd.int_below_count,
           rd.num_field_pts, rd.num_below_pts, rd.num_medal_bonus, rd.enum_score_method
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

-- The PZSz review queue keeps b; an approval writes K = the full senior field,
-- m = the original place and that b (ADR-103 §4, ADR-100). They are facts about
-- the field, written whatever the engine: EVF classic, which scores PPS and MPS
-- in 2026/2027, does not read them, and a later engine that does can. The queue
-- call gains a required argument, so the old signature is dropped rather than
-- left as a way to queue a row without them.
DROP FUNCTION IF EXISTS fn_queue_pzsz_match_review(INT, TEXT, INT, INT, NUMERIC);

CREATE OR REPLACE FUNCTION fn_queue_pzsz_match_review(
  p_id_tournament       INT,
  p_txt_scraped_name    TEXT,
  p_int_place           INT,
  p_id_candidate_fencer INT,
  p_num_confidence      NUMERIC,
  p_int_below_count     INT
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id INT;
BEGIN
  IF p_int_below_count IS NULL OR p_int_below_count < 0 THEN
    RAISE EXCEPTION 'A queued PZSz result needs the count of fencers below it, got %', p_int_below_count;
  END IF;

  INSERT INTO tbl_pzsz_match_review (
    id_tournament, txt_scraped_name, int_place, id_candidate_fencer, num_confidence,
    int_below_count
  )
  VALUES (
    p_id_tournament, p_txt_scraped_name, p_int_place, p_id_candidate_fencer, p_num_confidence,
    p_int_below_count
  )
  RETURNING id_review INTO v_id;

  RETURN v_id;
END;
$$;

COMMENT ON FUNCTION fn_queue_pzsz_match_review IS
  'Ingestion-time writer, SECURITY DEFINER so the pipeline''s own low-privilege '
  'role can queue a review row without a standing INSERT grant. Keeps the count '
  'of fencers below, which the unstored senior field makes unrecoverable later. '
  'Not a public RPC -- called only from the PZSz ingestion flow.';

REVOKE ALL ON FUNCTION fn_queue_pzsz_match_review(INT, TEXT, INT, INT, NUMERIC, INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION fn_queue_pzsz_match_review(INT, TEXT, INT, INT, NUMERIC, INT) FROM anon;
GRANT EXECUTE ON FUNCTION fn_queue_pzsz_match_review(INT, TEXT, INT, INT, NUMERIC, INT) TO authenticated, service_role;

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
  v_below       INT;
  v_field       INT;
  v_season_end  INT;
  v_birth_year  INT;
  v_source_vcat enum_age_category;
BEGIN
  SELECT id_tournament, txt_scraped_name, int_place, num_confidence, int_below_count
    INTO v_tournament, v_name, v_place, v_confidence, v_below
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

  SELECT EXTRACT(YEAR FROM s.dt_end)::INT, t.int_participant_count
    INTO v_season_end, v_field
    FROM tbl_tournament t
    JOIN tbl_event e  ON e.id_event  = t.id_event
    JOIN tbl_season s ON s.id_season = e.id_season
   WHERE t.id_tournament = v_tournament;

  v_source_vcat := CASE
    WHEN v_birth_year IS NOT NULL THEN fn_age_category(v_birth_year, v_season_end)
    ELSE NULL
  END;

  -- A senior bracket is one category: K = the full field and m = the
  -- original place (ADR-103 §4, ADR-100: never renumbered).
  INSERT INTO tbl_result (
    id_fencer, id_tournament, int_place,
    txt_scraped_name, num_match_confidence, enum_match_method,
    enum_source_age_category,
    int_category_count, int_category_place, int_below_count
  ) VALUES (
    p_id_fencer, v_tournament, v_place,
    v_name, v_confidence, 'USER_CONFIRMED',
    v_source_vcat,
    COALESCE(v_field, -1), v_place, v_below
  );

  PERFORM fn_calc_tournament_scores(v_tournament);

  UPDATE tbl_pzsz_match_review
     SET enum_status = 'APPROVED', ts_decided = NOW()
   WHERE id_review = p_id_review;

  RETURN p_id_review;
END;
$$;

-- =============================================================================
-- 13 · The public parameters, one row per tournament type (ADR-103 §7)
-- =============================================================================
-- Same name and argument, so both anon allowlists are unchanged; the result
-- shape changes, which needs DROP + CREATE and a re-grant. base_slope leaves
-- the surface with the only engine that read it.
DROP FUNCTION IF EXISTS fn_public_scoring_params(TEXT);

CREATE OR REPLACE FUNCTION fn_public_scoring_params(p_season_code TEXT DEFAULT NULL)
RETURNS TABLE (
  type_code     TEXT,
  engine_code   TEXT,
  engine_label  TEXT,
  multiplier    NUMERIC,
  mp_value      NUMERIC,
  de_round      NUMERIC,
  podium_gold   NUMERIC,
  podium_silver NUMERIC,
  podium_bronze NUMERIC
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT tc.enum_type::TEXT,
         se.txt_code,
         se.txt_label,
         tc.num_multiplier,
         c.int_mp_value::NUMERIC,
         10::NUMERIC,   -- de_round: points per DE round won (EVF classic, N >= 32)
         c.int_podium_gold::NUMERIC,
         c.int_podium_silver::NUMERIC,
         c.int_podium_bronze::NUMERIC
    FROM tbl_season s
    JOIN tbl_scoring_config c       ON c.id_season  = s.id_season
    JOIN tbl_scoring_type_config tc ON tc.id_config = c.id_config
    JOIN tbl_scoring_engine se      ON se.id_engine = COALESCE(tc.id_scoring_engine, s.id_scoring_engine)
   WHERE CASE
           WHEN p_season_code IS NULL THEN s.bool_active
           ELSE s.txt_code = p_season_code
         END
   ORDER BY tc.enum_type::TEXT;
$$;

COMMENT ON FUNCTION fn_public_scoring_params(TEXT) IS
  'Public scoring parameters for one season, one row per tournament type: its '
  'engine code and label, its coefficient and the season''s EVF settings. Keyed '
  'by season code; NULL means the active season. Feeds the shared formula '
  'module of the published calculator and scoring-table annex. Publishes no '
  'mutable registry field. Zero rows for an unknown season.';

GRANT EXECUTE ON FUNCTION fn_public_scoring_params(TEXT) TO anon, authenticated, service_role;

-- =============================================================================
-- 14 · ADR-083 deny-by-default
-- =============================================================================
-- New functions are revoked from PUBLIC and anon; 52.7 asserts the anon
-- surface as a set equality, and none of these belong to it.
REVOKE EXECUTE ON FUNCTION fn_score_spws_place_medal_v1_2026_2027(
  INT, INT, INT, INT, INT, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_score_by_engine(
  TEXT, INT, INT, INT, INT, INT, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_resolve_scoring_params(INT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_preview_tournament_score(INT, INT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_get_type_engine(INT, TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_backfill_scoring_engines() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_backfill_score_method() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION fn_backfill_ranking_entry_types() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION fn_apply_scoring_config_write(JSONB) FROM PUBLIC, anon, authenticated;

-- The pipeline reads the assignment the way it reads fn_get_min_participants.
GRANT EXECUTE ON FUNCTION fn_get_type_engine(INT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION fn_preview_tournament_score(INT, INT) TO service_role;
