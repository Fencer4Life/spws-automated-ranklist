-- =============================================================================
-- Migration: fn_compare_carryover_engines (A/B verification helper)
-- =============================================================================
-- Phase 1B step 8 — admin-facing comparison endpoint to surface per-fencer
-- deltas between EVENT_CODE_MATCHING (legacy) and EVENT_FK_MATCHING (new)
-- engines for a given season.
--
-- Use case: BEFORE flipping a season to EVENT_FK_MATCHING via UPDATE
-- tbl_season..., admin runs:
--   SELECT * FROM fn_compare_carryover_engines((SELECT id_season FROM tbl_season WHERE bool_active))
--    WHERE delta != 0 ORDER BY ABS(delta) DESC LIMIT 20;
-- to see who would gain/lose points under the new engine. Non-zero deltas
-- are usually attributable to slug events (ambiguous prefixes whose FK is
-- NULL → don't carry under FK engine).
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_compare_carryover_engines(p_id_season INT)
RETURNS TABLE (
  bucket_label TEXT,
  id_fencer    INT,
  fencer_name  TEXT,
  legacy_total NUMERIC,
  fk_total     NUMERIC,
  delta        NUMERIC
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
AS $$
DECLARE
  w enum_weapon_type;
  g enum_gender_type;
  c enum_age_category;
BEGIN
  FOREACH w IN ARRAY ARRAY['EPEE','FOIL','SABRE']::enum_weapon_type[] LOOP
    FOREACH g IN ARRAY ARRAY['M','F']::enum_gender_type[] LOOP
      FOREACH c IN ARRAY ARRAY['V1','V2','V3','V4']::enum_age_category[] LOOP
        RETURN QUERY
        WITH legacy AS (
          SELECT r.id_fencer, r.fencer_name, r.total_score
            FROM fn_ranking_kadra_event_code_matching(w, g, c, p_id_season, TRUE) r
        ),
        fk AS (
          SELECT r.id_fencer, r.fencer_name, r.total_score
            FROM fn_ranking_kadra_event_fk_matching(w, g, c, p_id_season, TRUE) r
        )
        SELECT
          (w::TEXT || '/' || g::TEXT || '/' || c::TEXT) AS bucket_label,
          COALESCE(l.id_fencer, f.id_fencer)             AS id_fencer,
          COALESCE(l.fencer_name, f.fencer_name)         AS fencer_name,
          COALESCE(l.total_score, 0)                     AS legacy_total,
          COALESCE(f.total_score, 0)                     AS fk_total,
          (COALESCE(f.total_score, 0) - COALESCE(l.total_score, 0)) AS delta
        FROM legacy l FULL OUTER JOIN fk f ON l.id_fencer = f.id_fencer;
      END LOOP;
    END LOOP;
  END LOOP;
END;
$$;

COMMENT ON FUNCTION fn_compare_carryover_engines(INT) IS
  'Phase 1B (ADR-042): A/B comparison of legacy vs FK carry-over engines for a '
  'given season. Returns one row per (weapon/gender/category, fencer) where '
  'either engine produced a score. Non-zero deltas reveal divergence — typically '
  'caused by slug events whose ambiguous prefix could not be auto-FK-linked.';

GRANT EXECUTE ON FUNCTION fn_compare_carryover_engines(INT) TO authenticated;
