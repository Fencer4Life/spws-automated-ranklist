-- =============================================================================
-- Migration: Copy json_ranking_rules from previous season on season creation
-- =============================================================================
-- Bug fix for ADR-018: fn_auto_create_scoring_config previously inserted a bare
-- row with only id_season, leaving json_ranking_rules as NULL. This caused
-- rolling carry-over to never activate for new seasons (the ranking function
-- falls into the legacy code path when rules are NULL).
--
-- Fix: The trigger now copies json_ranking_rules and bool_show_evf_toggle from
-- the most recent previous season. Falls back to defaults if no previous season
-- exists (first season edge case).
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_auto_create_scoring_config()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_prev_rules JSONB;
  v_prev_evf   BOOLEAN;
BEGIN
    -- Copy ranking rules from the most recent previous season
    SELECT sc.json_ranking_rules, sc.bool_show_evf_toggle
      INTO v_prev_rules, v_prev_evf
      FROM tbl_scoring_config sc
      JOIN tbl_season s ON s.id_season = sc.id_season
     WHERE s.id_season <> NEW.id_season
     ORDER BY s.dt_end DESC
     LIMIT 1;

    INSERT INTO tbl_scoring_config (id_season, json_ranking_rules, bool_show_evf_toggle)
    VALUES (NEW.id_season, v_prev_rules, COALESCE(v_prev_evf, FALSE))
    ON CONFLICT (id_season) DO NOTHING;
    RETURN NEW;
END;
$$;

-- Patch existing season 14 (SPWS-2026-2027) which was created before this fix
UPDATE tbl_scoring_config
   SET json_ranking_rules = sub.rules
  FROM (
    SELECT sc.json_ranking_rules AS rules
      FROM tbl_scoring_config sc
      JOIN tbl_season s ON s.id_season = sc.id_season
     WHERE s.id_season <> 14
     ORDER BY s.dt_end DESC
     LIMIT 1
  ) sub
 WHERE tbl_scoring_config.id_season = 14
   AND tbl_scoring_config.json_ranking_rules IS NULL;
