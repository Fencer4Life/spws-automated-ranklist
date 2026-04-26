-- =============================================================================
-- Phase 3a — fn_copy_prior_scoring_config: read-only helper for wizard step-2
-- =============================================================================
-- Returns the scoring config of the chronologically-prior season as JSONB so
-- the wizard's ScoringConfigEditor can pre-fill (with banner "Skopiowane z
-- SPWS-YYYY-YYYY"). Returns NULL when no prior season exists; the frontend
-- then falls back to static defaults.
--
-- Reuses fn_export_scoring_config so the JSONB shape matches what the editor
-- already understands (and what fn_import_scoring_config consumes on commit).
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_copy_prior_scoring_config(p_dt_start DATE)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_prior INT;
BEGIN
  IF p_dt_start IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT id_season INTO v_prior
    FROM tbl_season
   WHERE dt_end < p_dt_start
   ORDER BY dt_end DESC LIMIT 1;

  IF v_prior IS NULL THEN
    RETURN NULL;
  END IF;

  RETURN fn_export_scoring_config(v_prior);
END;
$$;

-- Read-only: anon may call (the wizard runs as authenticated, but allowing
-- anon keeps parity with fn_export_scoring_config's permission model).
GRANT EXECUTE ON FUNCTION fn_copy_prior_scoring_config(DATE) TO anon, authenticated;
