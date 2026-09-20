-- =============================================================================
-- Versioned season scoring — engine foundation
-- =============================================================================
-- Delivery step 2 of doc/plans/versioned-season-scoring-and-pzsz-ranking-design.html.
-- Flips SS26.DB.*, SS26.NEW.* and SS26.PARITY.* in
-- supabase/tests/80_season_scoring_contract.sql from RED to GREEN, and must
-- leave SS26.HIST.01-06 — the golden 2025/2026 fixtures — untouched.
--
-- WHAT THIS CHANGES AND WHAT IT DELIBERATELY DOES NOT
--
-- fn_calc_tournament_scores keeps its name, its signature and its transactional
-- contract. What changes is that the arithmetic moves out of it: it now resolves
-- the season's assigned engine and dispatches, instead of holding one formula
-- inline. Existing callers see no difference, and for every season assigned
-- EVF_CLASSIC_V1_2025_2026 the numbers are identical by construction — the
-- classic strategy is the previous expression, moved rather than rewritten.
--
-- ENGINES ARE ASSIGNED, NEVER BRANCHED TO (§03)
--
-- Nothing chooses an algorithm at calculation time. tbl_season names an engine;
-- a static CASE resolves it. This follows the dispatcher ADR-042/ADR-045 already
-- established for event carry-over, down to the ELSE RAISE EXCEPTION, rather
-- than inventing a second mechanism.
--
-- tbl_scoring_engine is METADATA ONLY. It stores no function reference and
-- performs no dispatch. §03 rejected a table-stored function reference: it needs
-- dynamic EXECUTE inside a SECURITY DEFINER function, which turns a writable row
-- into an execution path; Postgres tracks no dependency, so DROP FUNCTION on a
-- live strategy would succeed and break a closed season at runtime instead of at
-- migration time; and neither postgrestools nor the knowledge graph can see the
-- call edge. SS26.DB.01b guards that this stays true.
--
-- THE ENGINE OWNS THE SHAPE OF THE BASE, NOT THE NUMBERS (§04)
--
-- mp_value and the podium coefficients stay in tbl_scoring_config, editable
-- until the season's first result is scored. They are passed IN to a strategy,
-- never baked into one. The only thing an engine version freezes is what cannot
-- be written as a number: a flat base against a field-scaled one.
--
-- TWO UNRELATED TENS. p_base_slope is base points per bracket round and is used
-- only by the field-scaled engine; p_de_round is points per DE round won and is
-- used by both. They both happen to equal 10 today and are not the same
-- quantity, so they are separate parameters with separate names, everywhere.
--
-- A PLACE GREATER THAN THE FIELD IS INVALID DATA, NOT A ZERO (§04)
--
-- Both strategies raise. The previous inline expression scored it as 0, which is
-- the one value that hides the problem: it sorts to the bottom and reads as an
-- ordinary weak result. It also let num_podium_bonus award a medal for a place
-- that does not exist in the bracket, because that term was guarded only by
-- WHEN place = 1/2/3. Applying this to the CLASSIC engine as well as the new one
-- is safe because it was proven so, not assumed:
-- scripts/check-scoring-migration-preflight.sh found zero violating rows in
-- LOCAL, CERT and PROD on 2026-09-19.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- The common component contract every strategy returns (§03).
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'typ_score_components') THEN
    CREATE TYPE typ_score_components AS (
      num_place_pts    NUMERIC,
      num_de_bonus     NUMERIC,
      num_podium_bonus NUMERIC
    );
  END IF;
END $$;

COMMENT ON TYPE typ_score_components IS
  'The components every scoring strategy returns. The final score is these three '
  'summed and multiplied by the tournament-type multiplier, rounded once at the '
  'end by the caller — the formula comes from the strategy, the two-decimal '
  'rounding stays the database''s.';

-- -----------------------------------------------------------------------------
-- Engine registry — METADATA ONLY.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_scoring_engine (
  id_engine      SERIAL PRIMARY KEY,
  txt_code       TEXT NOT NULL UNIQUE,
  txt_label      TEXT NOT NULL,
  txt_base_shape TEXT NOT NULL,
  bool_active    BOOLEAN NOT NULL DEFAULT TRUE,
  ts_created     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE tbl_scoring_engine IS
  'Display metadata for released scoring engines. Holds NO function reference '
  'and performs NO dispatch: the dispatcher is a static CASE in '
  'fn_score_by_engine. Adding a column that names a function reintroduces the '
  'alternative §03 rejected and is caught by SS26.DB.01b.';
COMMENT ON COLUMN tbl_scoring_engine.txt_code IS
  'DESCRIPTIVE_FAMILY_V<contract-version>_<reference-season>. A later season '
  'reusing this formula points at this row; it does not get a new one.';
COMMENT ON COLUMN tbl_scoring_engine.txt_base_shape IS
  'Human-readable documentation of the base the engine applies. The engine '
  'version freezes this shape and nothing else — mp_value and the podium '
  'coefficients remain season configuration.';

INSERT INTO tbl_scoring_engine (txt_code, txt_label, txt_base_shape)
VALUES
  ('EVF_CLASSIC_V1_2025_2026',
   'EVF klasyczny (do sezonu 2025/2026)',
   'B(N) = mpValue — a flat base independent of field size.'),
  ('SPWS_FIELD_SCALED_V1_2026_2027',
   'SPWS skalowany polem (od sezonu 2026/2027)',
   'B(N) = min(mpValue, baseSlope * log2(max(2, N))) — the base grows with the '
   'field and then holds flat at mpValue, which it reaches at N = 32.')
ON CONFLICT (txt_code) DO NOTHING;

-- -----------------------------------------------------------------------------
-- Explicit per-season assignment. Distinct from enum_carryover_engine, which is
-- prior-event matching policy and is NOT a scoring formula (§02). Neither name
-- may ever be overloaded onto the other.
-- -----------------------------------------------------------------------------
ALTER TABLE tbl_season
  ADD COLUMN IF NOT EXISTS id_scoring_engine INT REFERENCES tbl_scoring_engine(id_engine);

COMMENT ON COLUMN tbl_season.id_scoring_engine IS
  'The one engine this season is scored with. Assigned, never branched to: '
  'nothing chooses an algorithm at calculation time. Unrelated to '
  'enum_carryover_engine (ADR-042/ADR-045), which is prior-event matching.';

-- -----------------------------------------------------------------------------
-- Backfill, with the §11 hard gate.
--
-- Historical seasons are assigned the classic engine only after their stored
-- configuration is proven to be the one that engine reproduces. Because those
-- values are season configuration, the check READS them per season instead of
-- assuming 50 and 3/2/1, and any deviation aborts the migration rather than
-- silently coercing a season onto an engine that does not describe it.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_backfill_scoring_engines()
RETURNS VOID
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $backfill$
DECLARE
  v_classic INT;
  v_field   INT;
  v_deviant TEXT;
  v_scored  INT;
  v_current INT;
BEGIN
  SELECT id_engine INTO v_classic FROM tbl_scoring_engine WHERE txt_code = 'EVF_CLASSIC_V1_2025_2026';
  SELECT id_engine INTO v_field   FROM tbl_scoring_engine WHERE txt_code = 'SPWS_FIELD_SCALED_V1_2026_2027';

  -- Assigning EVF_CLASSIC_V1_2025_2026 to a historical season is only truthful
  -- if that season was actually scored with the base it reproduces. Because
  -- mp_value and the podium coefficients are SEASON CONFIGURATION rather than
  -- engine constants, this READS them per season instead of assuming 50 and
  -- 3/2/1. A deviation aborts rather than coercing a season onto an engine that
  -- does not describe it.
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

  -- The §11 hard gate: never silently switch an already-scored season.
  SELECT s.id_scoring_engine INTO v_current
    FROM tbl_season s WHERE s.txt_code = 'SPWS-2026-2027';

  SELECT count(*) INTO v_scored
    FROM tbl_result r
    JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
    JOIN tbl_event e      ON e.id_event      = t.id_event
    JOIN tbl_season s     ON s.id_season     = e.id_season
   WHERE s.txt_code = 'SPWS-2026-2027' AND r.ts_points_calc IS NOT NULL;

  IF v_scored > 0 AND v_current IS DISTINCT FROM v_field THEN
    RAISE EXCEPTION
      'SPWS-2026-2027 already holds % scored result(s) and is not assigned SPWS_FIELD_SCALED_V1_2026_2027. Switching an already-scored season''s engine is forbidden; a board-authorized revision with a full rescore is required.',
      v_scored;
  END IF;

  UPDATE tbl_season s
     SET id_scoring_engine = v_field
   WHERE s.txt_code = 'SPWS-2026-2027' AND s.id_scoring_engine IS NULL;

  -- Any other season that predates this migration and holds no assignment at
  -- all falls back to the classic engine. A deliberate assignment is never
  -- overwritten, and a season created AFTER this migration gets nothing here —
  -- it must be assigned an engine explicitly (§05).
  UPDATE tbl_season s
     SET id_scoring_engine = v_classic
   WHERE s.id_scoring_engine IS NULL AND s.ts_created < NOW();
END;
$backfill$;

COMMENT ON FUNCTION fn_backfill_scoring_engines() IS
  'Idempotent engine backfill, extracted into a function because `supabase db '
  'reset` applies migrations BEFORE loading the seed dump (ADR-036 amendment). '
  'On LOCAL this migration therefore runs against an empty tbl_season and '
  'assigns nothing, so supabase/seed_post_backfill.sql calls it again once the '
  'seasons exist. CERT and PROD have their data already and are served by the '
  'call below.';

SELECT fn_backfill_scoring_engines();

-- -----------------------------------------------------------------------------
-- The fail-closed type gate (§02, §07).
--
-- The previous six-way multiplier CASE had no ELSE, so a tournament type it did
-- not list resolved to NULL and wrote num_final_score = NULL with no exception
-- raised. Python's get_min_participants has the mirror-image defect, returning a
-- threshold of 1 for an unrecognised type — failing OPEN in both directions.
-- This resolves the multiplier and raises when there is none.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_assert_type_configured(p_id_season INT, p_type TEXT)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_multiplier NUMERIC;
BEGIN
  SELECT CASE p_type
           WHEN 'PPW' THEN c.num_ppw_multiplier
           WHEN 'MPW' THEN c.num_mpw_multiplier
           WHEN 'PEW' THEN c.num_pew_multiplier
           WHEN 'MEW' THEN c.num_mew_multiplier
           WHEN 'MSW' THEN c.num_msw_multiplier
           WHEN 'PSW' THEN c.num_psw_multiplier
         END
    INTO v_multiplier
    FROM tbl_scoring_config c
   WHERE c.id_season = p_id_season;

  IF v_multiplier IS NULL THEN
    RAISE EXCEPTION
      'No scoring configuration for tournament type % in season %. Refusing to write a NULL score.',
      p_type, p_id_season;
  END IF;

  RETURN v_multiplier;
END;
$$;

COMMENT ON FUNCTION fn_assert_type_configured(INT, TEXT) IS
  'Resolves the multiplier for a tournament type, raising when the season has no '
  'setting for it. Takes TEXT rather than the enum so it fails closed for a type '
  'that is not in the enum at all, which is the state PPS/MPS are in until the '
  'type-policy migration lands. SS26.DB.05.';

-- -----------------------------------------------------------------------------
-- Shared validation. Both strategies call it, so rejection cannot be
-- implemented in one engine and forgotten in the other.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_assert_scoring_input(p_n INT, p_place INT)
RETURNS VOID
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_n IS NULL OR p_n < 1 THEN
    RAISE EXCEPTION 'Invalid scoring input: participant count % is not at least 1', p_n;
  END IF;
  IF p_place IS NULL OR p_place < 1 THEN
    RAISE EXCEPTION 'Invalid scoring input: place % is not at least 1', p_place;
  END IF;
  IF p_place > p_n THEN
    RAISE EXCEPTION
      'Invalid scoring input: place % exceeds the field of %. A place larger than the field is corrupt data, not a weak result.',
      p_place, p_n;
  END IF;
END;
$$;

-- -----------------------------------------------------------------------------
-- The terms both engines share: DE bonus and podium bonus. Only the base
-- differs between engines (§04), so factoring these out is what makes that
-- statement structurally true rather than a claim two copies happen to honour.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_score_de_bonus(p_n INT, p_place INT, p_de_round NUMERIC)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT CASE
    WHEN p_n <= 1 THEN 0::NUMERIC
    ELSE GREATEST(0,
           FLOOR(LN(p_n) / LN(2))
           - CEIL(LN(p_place) / LN(2))
           -- powerOfTwoAdjustment: +1 when N is not an exact power of two, 0 when it is.
           + CASE WHEN (p_n & (p_n - 1)) = 0 THEN 0 ELSE 1 END
         )::NUMERIC * p_de_round
  END;
$$;

CREATE OR REPLACE FUNCTION fn_score_podium_bonus(
  p_n INT, p_place INT, p_gold NUMERIC, p_silver NUMERIC, p_bronze NUMERIC)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT (CASE p_place WHEN 1 THEN p_gold WHEN 2 THEN p_silver WHEN 3 THEN p_bronze
          ELSE 0::NUMERIC END) * (3 * POWER(p_n, 1.0/3))::NUMERIC;
$$;

-- -----------------------------------------------------------------------------
-- Immutable strategy: EVF_CLASSIC_V1_2025_2026.
--
-- A flat base. This is the expression that scored every season up to and
-- including 2025/2026, moved here unchanged. Its outputs are pinned by the
-- golden fixtures SS26.HIST.01-06; it must never be edited. A change to the
-- formula means a NEW engine version, not a new body for this one.
--
-- p_base_slope is accepted and ignored: the uniform signature is what keeps
-- "adding a branch edits the dispatcher, never a strategy" true.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_score_evf_classic_v1_2025_2026(
  p_n            INT,
  p_place        INT,
  p_mp_value     NUMERIC,
  p_base_slope   NUMERIC,
  p_de_round     NUMERIC,
  p_podium_gold  NUMERIC,
  p_podium_silver NUMERIC,
  p_podium_bronze NUMERIC
)
RETURNS typ_score_components
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_base NUMERIC;
  v_out  typ_score_components;
BEGIN
  PERFORM fn_assert_scoring_input(p_n, p_place);

  v_base := p_mp_value;                        -- flat: the field size does not enter

  -- UNROUNDED on purpose. The previous implementation derived num_final_score
  -- from the raw terms and rounded once, at the end. Rounding here as well would
  -- round twice and could move a stored score by a cent, which is exactly what
  -- the golden fixtures exist to catch. The caller rounds: components to two
  -- decimals for storage, and the final score from these raw values.
  v_out.num_place_pts :=
    CASE WHEN p_n = 1 THEN v_base
         ELSE v_base - (v_base - 1) * (LN(p_place) / LN(p_n))::NUMERIC END;
  v_out.num_de_bonus     := fn_score_de_bonus(p_n, p_place, p_de_round);
  v_out.num_podium_bonus :=
    fn_score_podium_bonus(p_n, p_place, p_podium_gold, p_podium_silver, p_podium_bronze);
  RETURN v_out;
END;
$$;

COMMENT ON FUNCTION fn_score_evf_classic_v1_2025_2026 IS
  'IMMUTABLE RELEASED STRATEGY — do not edit. Flat base B(N) = mpValue. Scored '
  'every season through 2025/2026 and is pinned by the golden fixtures in '
  'supabase/tests/80_season_scoring_contract.sql. A formula change is a new '
  'engine version, never a new body for this function.';

-- -----------------------------------------------------------------------------
-- Immutable strategy: SPWS_FIELD_SCALED_V1_2026_2027.
--
-- B(N) = min(mpValue, baseSlope * log2(max(2, N))).
--
-- The max(2, N) guard stops log2(1) = 0 producing a base of zero, so a
-- one-competitor bracket inherits the N = 2 base. That deliberately re-prices
-- the walkover ADR-066 admits: 50 + 0 + 9 = 59 becomes 10 + 0 + 9 = 19. It is
-- the intended shape of a curve whose stated purpose is that small fields are
-- worth less — a walkover outscoring a fought four-person bracket would be the
-- stranger outcome. SS26.NEW.01 pins it so it cannot regress silently.
--
-- At N >= 32 the base reaches mpValue (10 * log2(32) = 50) and this engine is
-- identical to the classic one for the same placement and multiplier. The whole
-- difference between the two is confined to fields smaller than 32.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_score_spws_field_scaled_v1_2026_2027(
  p_n            INT,
  p_place        INT,
  p_mp_value     NUMERIC,
  p_base_slope   NUMERIC,
  p_de_round     NUMERIC,
  p_podium_gold  NUMERIC,
  p_podium_silver NUMERIC,
  p_podium_bronze NUMERIC
)
RETURNS typ_score_components
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_base NUMERIC;
  v_out  typ_score_components;
BEGIN
  PERFORM fn_assert_scoring_input(p_n, p_place);

  v_base := LEAST(p_mp_value,
                  p_base_slope * (LN(GREATEST(2, p_n)) / LN(2))::NUMERIC);

  -- UNROUNDED on purpose. The previous implementation derived num_final_score
  -- from the raw terms and rounded once, at the end. Rounding here as well would
  -- round twice and could move a stored score by a cent, which is exactly what
  -- the golden fixtures exist to catch. The caller rounds: components to two
  -- decimals for storage, and the final score from these raw values.
  v_out.num_place_pts :=
    CASE WHEN p_n = 1 THEN v_base
         ELSE v_base - (v_base - 1) * (LN(p_place) / LN(p_n))::NUMERIC END;
  v_out.num_de_bonus     := fn_score_de_bonus(p_n, p_place, p_de_round);
  v_out.num_podium_bonus :=
    fn_score_podium_bonus(p_n, p_place, p_podium_gold, p_podium_silver, p_podium_bronze);
  RETURN v_out;
END;
$$;

COMMENT ON FUNCTION fn_score_spws_field_scaled_v1_2026_2027 IS
  'IMMUTABLE RELEASED STRATEGY — do not edit. Field-scaled base '
  'B(N) = min(mpValue, baseSlope * log2(max(2, N))). Introduced for 2026/2027 '
  'and identical to the classic engine at N >= 32.';

-- -----------------------------------------------------------------------------
-- The dispatcher. A static CASE, one branch per distinct formula ever released
-- — never one per season. Three seasons sharing a formula is one branch.
-- Closes with the same ELSE RAISE the carry-over dispatcher already uses.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_score_by_engine(
  p_engine_code  TEXT,
  p_n            INT,
  p_place        INT,
  p_mp_value     NUMERIC,
  p_base_slope   NUMERIC,
  p_de_round     NUMERIC,
  p_podium_gold  NUMERIC,
  p_podium_silver NUMERIC,
  p_podium_bronze NUMERIC
)
RETURNS typ_score_components
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  CASE p_engine_code
    WHEN 'EVF_CLASSIC_V1_2025_2026' THEN
      RETURN fn_score_evf_classic_v1_2025_2026(
        p_n, p_place, p_mp_value, p_base_slope, p_de_round,
        p_podium_gold, p_podium_silver, p_podium_bronze);
    WHEN 'SPWS_FIELD_SCALED_V1_2026_2027' THEN
      RETURN fn_score_spws_field_scaled_v1_2026_2027(
        p_n, p_place, p_mp_value, p_base_slope, p_de_round,
        p_podium_gold, p_podium_silver, p_podium_bronze);
    ELSE
      RAISE EXCEPTION 'Unknown scoring engine: %', p_engine_code;
  END CASE;
END;
$$;

COMMENT ON FUNCTION fn_score_by_engine IS
  'Static dispatcher over released scoring strategies, following the '
  'ADR-042/ADR-045 carry-over precedent. Adding an engine edits THIS function '
  'and adds a new strategy; it never edits an existing strategy.';

-- -----------------------------------------------------------------------------
-- Resolve everything a season's scoring needs, in one place, so the bulk writer
-- and the read-only preview cannot drift apart. "Real scoring and read-only
-- preview use one dispatcher and the same immutable strategy" (§01) is only
-- true if there is one resolution path, not two that agree today.
--
-- BASE SLOPE AND DE ROUND. Both are 10 today and both are constants here, as
-- they were before this migration (§02: "Only the DE round's * 10 is
-- hardcoded"). They are separate columns in this result rather than one shared
-- value because they are different quantities that happen to coincide: base
-- points per bracket round versus points per DE round won. Promoting either to
-- season configuration would widen the Admin lock surface and is a decision for
-- the configuration step, not this one.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_resolve_scoring_params(p_tournament_id INT)
RETURNS TABLE (
  n              INT,
  engine_code    TEXT,
  multiplier     NUMERIC,
  mp_value       NUMERIC,
  base_slope     NUMERIC,
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

  SELECT se.txt_code INTO v_engine
    FROM tbl_season s
    JOIN tbl_scoring_engine se ON se.id_engine = s.id_scoring_engine
   WHERE s.id_season = v_season;

  IF v_engine IS NULL THEN
    RAISE EXCEPTION
      'Unknown scoring engine: season % has no engine assigned. An engine is assigned deliberately, never inferred.',
      v_season;
  END IF;

  RETURN QUERY
    SELECT v_n,
           v_engine,
           fn_assert_type_configured(v_season, v_type::TEXT),
           c.int_mp_value::NUMERIC,
           10::NUMERIC,   -- base_slope: base points per bracket round
           10::NUMERIC,   -- de_round:   points per DE round won
           c.int_podium_gold::NUMERIC,
           c.int_podium_silver::NUMERIC,
           c.int_podium_bronze::NUMERIC
      FROM tbl_scoring_config c
     WHERE c.id_season = v_season;
END;
$$;

-- -----------------------------------------------------------------------------
-- The stable transactional writer. Same name, same signature, same contract as
-- before; the arithmetic is now dispatched rather than inline.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_calc_tournament_scores(p_tournament_id INT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  p RECORD;
BEGIN
  SELECT * INTO p FROM fn_resolve_scoring_params(p_tournament_id);

  UPDATE tbl_result r
     SET num_place_pts    = ROUND(c.num_place_pts, 2),
         num_de_bonus     = ROUND(c.num_de_bonus, 2),
         num_podium_bonus = ROUND(c.num_podium_bonus, 2),
         -- Rounded ONCE, from the raw terms, exactly as before this migration.
         num_final_score  = ROUND(
           (c.num_place_pts + c.num_de_bonus + c.num_podium_bonus) * p.multiplier, 2),
         ts_points_calc   = NOW()
    FROM (
      SELECT r2.id_result, (x.comp).*
        FROM tbl_result r2
        CROSS JOIN LATERAL (
          SELECT fn_score_by_engine(
                   p.engine_code, p.n, r2.int_place, p.mp_value, p.base_slope,
                   p.de_round, p.podium_gold, p.podium_silver, p.podium_bronze) AS comp
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
  'The stable transactional scoring writer. Resolves the season''s assigned '
  'engine and dispatches; holds no formula of its own. Unchanged in name, '
  'signature and transactional contract — callers see no difference, and for a '
  'season assigned EVF_CLASSIC_V1_2025_2026 the numbers are identical by '
  'construction.';

-- -----------------------------------------------------------------------------
-- The public read-only preview facade (§03).
--
-- STABLE rather than VOLATILE so "it cannot update a tournament or result" is a
-- property Postgres enforces, not a promise this body happens to keep. Fixed
-- search_path per §08. It shares fn_resolve_scoring_params and fn_score_by_engine
-- with the writer, which is what makes SS26.PARITY.04 an assertion about one
-- implementation rather than a comparison of two.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_preview_tournament_score(p_tournament_id INT, p_place INT)
RETURNS TABLE (
  txt_engine_code  TEXT,
  num_place_pts    NUMERIC,
  num_de_bonus     NUMERIC,
  num_podium_bonus NUMERIC,
  num_final_score  NUMERIC
)
LANGUAGE plpgsql
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  p RECORD;
  c typ_score_components;
BEGIN
  SELECT * INTO p FROM fn_resolve_scoring_params(p_tournament_id);

  c := fn_score_by_engine(p.engine_code, p.n, p_place, p.mp_value, p.base_slope,
                          p.de_round, p.podium_gold, p.podium_silver, p.podium_bronze);

  RETURN QUERY SELECT
    p.engine_code,
    ROUND(c.num_place_pts, 2),
    ROUND(c.num_de_bonus, 2),
    ROUND(c.num_podium_bonus, 2),
    ROUND((c.num_place_pts + c.num_de_bonus + c.num_podium_bonus) * p.multiplier, 2);
END;
$$;

COMMENT ON FUNCTION fn_preview_tournament_score(INT, INT) IS
  'Read-only preview over the same dispatcher and strategies the writer uses. '
  'STABLE, so it cannot write. Returns the engine label and every component, '
  'rounded exactly as the writer stores them.';

-- =============================================================================
-- ADR-083 deny-by-default posture.
-- =============================================================================
-- Two separate things, both of which 52_security_posture.sql caught locally
-- rather than letting them reach the deploy job:
--
--   1. Every table in schema public must have RLS enabled (52.1). The registry
--      is migration/service data and is never browser-writable, so it carries
--      no policy at all — RLS on with no policy denies everything that is not
--      SECURITY DEFINER or service_role.
--
--   2. Postgres grants EXECUTE on a new function to PUBLIC by default, which
--      silently widens the anon surface. 52.7 asserts the anon-executable set as
--      a set EQUALITY, so every function added here must be revoked or the
--      allowlist must grow. None of these belong to anon YET: publishing
--      fn_preview_tournament_score to the GitHub Pages origin is the
--      published-page cutover, and §08 requires that grant to be made in BOTH
--      copies of the allowlist at once — supabase/tests/52_security_posture.sql
--      and scripts/check-security-posture.sh — because they drifted on
--      2026-09-12 and the disagreement surfaced at deploy, blocking PROD.
-- =============================================================================
ALTER TABLE tbl_scoring_engine ENABLE ROW LEVEL SECURITY;

REVOKE EXECUTE ON FUNCTION fn_score_evf_classic_v1_2025_2026(
  INT, INT, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_score_spws_field_scaled_v1_2026_2027(
  INT, INT, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_score_by_engine(
  TEXT, INT, INT, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_score_de_bonus(INT, INT, NUMERIC) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_score_podium_bonus(INT, INT, NUMERIC, NUMERIC, NUMERIC) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_assert_scoring_input(INT, INT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_assert_type_configured(INT, TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_resolve_scoring_params(INT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_preview_tournament_score(INT, INT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_backfill_scoring_engines() FROM PUBLIC, anon;
