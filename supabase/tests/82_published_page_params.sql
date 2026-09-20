-- =============================================================================
-- SS26.CALC — Published-page cutover: the public scoring-parameter surface
-- =============================================================================
-- Acceptance IDs for doc/plans/versioned-season-scoring-and-pzsz-ranking-design.html,
-- §08 and §11 step 8 ("Published-page cutover"). Written BEFORE the production
-- code, per §10.
--
-- WHY A PARAMETER RPC AND NOT A SCORE RPC
-- -----------------------------------------------------------------------------
-- §08 rejects per-cell and whole-grid score RPCs for the scoring-table annex:
-- that page renders up to 300 x 300 cells and re-renders on every rank-coefficient
-- change, so a round trip per value — or a ~1 MB grid per change — is not viable.
-- The shared TypeScript module therefore computes CLIENT-SIDE from server-supplied
-- PARAMETERS. This function is that parameter surface, and it is the only thing
-- the two published pages need from the database.
--
-- fn_preview_tournament_score stays revoked from anon. It takes an id_tournament,
-- which neither published page has — both take N and place as user input — so
-- granting it would widen the anon surface to per-tournament previews for no gain.
-- §08's invariant is that the grant must land in BOTH allowlist copies at once,
-- not that it must be that particular function.
--
-- WHAT IS RED HERE AND WHY
-- -----------------------------------------------------------------------------
-- All of SS26.CALC.01-08 are RED on purpose: fn_public_scoring_params does not
-- exist yet. They go GREEN in step 8 and not before. The helper below catches
-- 42883 (undefined function) so a missing function yields NULL and produces one
-- clean named failure per assertion instead of aborting the file.
--
-- WHY THE PARAMETERS ARE ASSERTED AGAINST tbl_scoring_config
-- -----------------------------------------------------------------------------
-- mp_value and the podium coefficients are SEASON CONFIGURATION, not engine
-- constants (§04, reversed 19 September 2026). The whole point of the cutover is
-- that a pre-lock Admin edit reaches the engine, the calculator and the annex
-- alike, so these assertions compare the published surface to the season's own
-- stored row rather than to literals. base_slope and de_round are the TWO
-- UNRELATED TENS §04 insists on naming apart: base points per bracket round, and
-- points per DE round won.
-- =============================================================================

BEGIN;

SELECT plan(9);

-- -----------------------------------------------------------------------------
-- RED-safe wrapper: yields NULL instead of aborting when the function is absent.
-- Pass-through once it exists — it adds no arithmetic, so it cannot make a
-- broken implementation pass.
-- -----------------------------------------------------------------------------
CREATE FUNCTION pg_temp.params_of(p_season_code TEXT)
RETURNS TABLE (
  engine_code   TEXT,
  engine_label  TEXT,
  mp_value      NUMERIC,
  base_slope    NUMERIC,
  de_round      NUMERIC,
  podium_gold   NUMERIC,
  podium_silver NUMERIC,
  podium_bronze NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY EXECUTE
    'SELECT engine_code, engine_label, mp_value, base_slope, de_round,
            podium_gold, podium_silver, podium_bronze
       FROM fn_public_scoring_params($1)'
    USING p_season_code;
EXCEPTION
  WHEN undefined_function OR undefined_table THEN
    RETURN QUERY SELECT NULL::TEXT, NULL::TEXT, NULL::NUMERIC, NULL::NUMERIC,
                        NULL::NUMERIC, NULL::NUMERIC, NULL::NUMERIC, NULL::NUMERIC;
END;
$$;

-- =============================================================================
-- SS26.CALC.01 — the parameter surface exists, keyed by season CODE
-- =============================================================================
-- Keyed by code, not id_season: §08 pins the annex to SPWS-2026-2027 by season
-- code so the pin survives any reseed, and a surrogate id would not.
SELECT has_function(
  'public', 'fn_public_scoring_params', ARRAY['text'],
  'SS26.CALC.01: fn_public_scoring_params(TEXT) exists, keyed by season code'
);

-- =============================================================================
-- SS26.CALC.02 — anon can execute it
-- =============================================================================
-- Both published pages are served from the GitHub Pages origin as static files
-- and hold no credential beyond the anon key.
SELECT ok(
  COALESCE(
    (SELECT has_function_privilege('anon', p.oid, 'EXECUTE')
       FROM pg_proc p
       JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public'
        AND p.proname = 'fn_public_scoring_params'
      LIMIT 1),
    FALSE),
  'SS26.CALC.02: anon holds EXECUTE on fn_public_scoring_params'
);

-- =============================================================================
-- SS26.CALC.03 — it is STABLE, so it cannot write
-- =============================================================================
SELECT is(
  (SELECT p.provolatile::TEXT
     FROM pg_proc p
     JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_public_scoring_params'
    LIMIT 1),
  's',
  'SS26.CALC.03: fn_public_scoring_params is STABLE (s), so it performs no write'
);

-- =============================================================================
-- SS26.CALC.04 — it pins its search_path
-- =============================================================================
-- §08: "has a fixed search_path". Every sibling in the scoring set does.
SELECT ok(
  COALESCE(
    (SELECT p.proconfig::TEXT LIKE '%search_path%'
       FROM pg_proc p
       JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.proname = 'fn_public_scoring_params'
      LIMIT 1),
    FALSE),
  'SS26.CALC.04: fn_public_scoring_params pins its search_path'
);

-- =============================================================================
-- SS26.CALC.05 — 2026/2027 reports the field-scaled engine
-- =============================================================================
-- The annex is pinned to this season (§08), so this is the pin's contract.
SELECT is(
  (SELECT engine_code FROM pg_temp.params_of('SPWS-2026-2027')),
  'SPWS_FIELD_SCALED_V1_2026_2027',
  'SS26.CALC.05: SPWS-2026-2027 reports its assigned field-scaled engine'
);

-- =============================================================================
-- SS26.CALC.06 — the published numbers ARE the season's stored configuration
-- =============================================================================
-- Not literals. This is what makes "a pre-lock Admin edit reaches all three
-- surfaces" (§08) a mechanically checked property.
SELECT is(
  (SELECT ROW(p.mp_value, p.podium_gold, p.podium_silver, p.podium_bronze)::TEXT
     FROM pg_temp.params_of('SPWS-2026-2027') p),
  (SELECT ROW(c.int_mp_value::NUMERIC, c.int_podium_gold::NUMERIC,
              c.int_podium_silver::NUMERIC, c.int_podium_bronze::NUMERIC)::TEXT
     FROM tbl_scoring_config c
     JOIN tbl_season s ON s.id_season = c.id_season
    WHERE s.txt_code = 'SPWS-2026-2027'),
  'SS26.CALC.06: published base and podium equal that season''s stored config row'
);

-- =============================================================================
-- SS26.CALC.07 — the two tens are reported separately
-- =============================================================================
-- §04: base_slope (base points per bracket round) and de_round (points per DE
-- round won) coincide at 10 today and are NOT the same quantity. Reporting one
-- value for both would let a future change to either silently move the other.
SELECT is(
  (SELECT ROW(p.base_slope, p.de_round)::TEXT FROM pg_temp.params_of('SPWS-2026-2027') p),
  ROW(10::NUMERIC, 10::NUMERIC)::TEXT,
  'SS26.CALC.07: base_slope and de_round are reported as separate parameters'
);

-- =============================================================================
-- SS26.CALC.08 — an unknown season yields no row, and does not raise
-- =============================================================================
-- The published pages render a validation error in the page (§08: "Render
-- validation and network errors in the page"). Zero rows is the contract; an
-- exception would surface to an anonymous visitor as an opaque 400.
SELECT is(
  (SELECT COUNT(*)::INT FROM pg_temp.params_of('SPWS-1999-2000') WHERE engine_code IS NOT NULL),
  0,
  'SS26.CALC.08: an unknown season code yields no row rather than raising'
);

-- =============================================================================
-- SS26.CALC.09 — omitting the season code yields the ACTIVE season
-- =============================================================================
-- The two pages bind to different seasons by construction (§08): the calculator
-- follows the active season, the annex is pinned to SPWS-2026-2027. One function
-- serves both, so the calculator does not need a second round trip to discover
-- which season is active — which matters for a static page on GitHub Pages.
SELECT is(
  (SELECT engine_code FROM pg_temp.params_of(NULL)),
  (SELECT se.txt_code
     FROM tbl_season s
     JOIN tbl_scoring_engine se ON se.id_engine = s.id_scoring_engine
    WHERE s.bool_active
    LIMIT 1),
  'SS26.CALC.09: a NULL season code resolves to the active season'
);

SELECT * FROM finish();

ROLLBACK;
