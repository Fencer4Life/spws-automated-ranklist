-- =============================================================================
-- Migration: the public scoring-parameter surface (design step 8)
-- =============================================================================
-- doc/plans/versioned-season-scoring-and-pzsz-ranking-design.html §08 and §11
-- step 8 ("Published-page cutover"). Satisfies SS26.CALC.01-09, observed RED in
-- supabase/tests/82_published_page_params.sql before this file existed.
--
-- WHY A PARAMETER SURFACE AND NOT A SCORE RPC
-- -----------------------------------------------------------------------------
-- §08 rejects per-cell and whole-grid score RPCs for the scoring-table annex:
-- that page renders up to 300 x 300 cells and re-renders on every
-- rank-coefficient change. A round trip per value, or a ~1 MB grid per change,
-- is not viable. The shared TypeScript module therefore computes CLIENT-SIDE
-- from the parameters this function publishes, and the formula lives in exactly
-- two places — that module and the SQL strategies — pinned to each other by
-- SS26.PARITY over fixtures.
--
-- fn_preview_tournament_score DELIBERATELY STAYS REVOKED FROM anon. It takes an
-- id_tournament, which neither published page has: both take N and place as user
-- input. Granting it would widen the anon surface to per-tournament previews for
-- no gain. §08's invariant is that whatever the pages call must be granted in
-- BOTH allowlist copies at once, not that it must be that particular function.
--
-- WHY THE NUMBERS COME FROM tbl_scoring_config
-- -----------------------------------------------------------------------------
-- mp_value and the podium coefficients are SEASON CONFIGURATION, not engine
-- constants (§04, reversed 19 September 2026). Reading them from the season's own
-- row is what makes "a pre-lock Admin edit is reflected in the engine, the
-- calculator and the table alike" (§08) true rather than aspirational. Once the
-- season locks, those values stop moving and all three surfaces freeze together —
-- the database lock is the only lock, and neither page needs one of its own.
--
-- WHY SECURITY DEFINER
-- -----------------------------------------------------------------------------
-- tbl_scoring_engine carries RLS with no policy (20260919000001, ADR-083), so an
-- invoker-rights function would return nothing for anon. This is the same shape
-- every other anon-callable read here uses: STABLE, SECURITY DEFINER, pinned
-- search_path, no write possible.
--
-- WHY THE SEASON IS KEYED BY CODE
-- -----------------------------------------------------------------------------
-- §08 pins the annex to SPWS-2026-2027 by season CODE, never by "the active
-- season" and never by numbers copied into the page, so the pin survives a
-- reseed. A NULL code means the active season, which is what the calculator
-- binds to — one function, two bindings, no second round trip from a static page.
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_public_scoring_params(p_season_code TEXT DEFAULT NULL)
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
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT se.txt_code,
         se.txt_label,
         c.int_mp_value::NUMERIC,
         10::NUMERIC,   -- base_slope: base points per bracket round (§04)
         10::NUMERIC,   -- de_round:   points per DE round won (§04)
         c.int_podium_gold::NUMERIC,
         c.int_podium_silver::NUMERIC,
         c.int_podium_bronze::NUMERIC
    FROM tbl_season s
    JOIN tbl_scoring_config c  ON c.id_season  = s.id_season
    JOIN tbl_scoring_engine se ON se.id_engine = s.id_scoring_engine
   WHERE CASE
           WHEN p_season_code IS NULL THEN s.bool_active
           ELSE s.txt_code = p_season_code
         END
   LIMIT 1;
$$;

COMMENT ON FUNCTION fn_public_scoring_params(TEXT) IS
  'Public scoring parameters for one season, keyed by season code; NULL means '
  'the active season. Feeds the shared formula module used by the published '
  'calculator and the scoring-table annex. Publishes the engine code and label '
  'only — never a mutable registry field (id_engine, bool_active, ts_created). '
  'Returns zero rows for an unknown season so the page can render its own error '
  'rather than surfacing an opaque 400 to an anonymous visitor.';

-- =============================================================================
-- The anon grant. §08: this must land in BOTH copies of the allowlist in the
-- same change — supabase/tests/52_security_posture.sql (52.7 asserts the
-- anon-executable set as a set EQUALITY) and scripts/check-security-posture.sh
-- (which the deploy job runs against the real CERT/PROD database). They drifted
-- on 2026-09-12: pgTAP stayed green through the whole of CI and the
-- disagreement surfaced at deploy, failing CERT's posture check and blocking
-- PROD. scripts/check-anon-allowlist-sync.sh catches it locally in two minutes.
-- =============================================================================
GRANT EXECUTE ON FUNCTION fn_public_scoring_params(TEXT) TO anon, authenticated;

COMMIT;
