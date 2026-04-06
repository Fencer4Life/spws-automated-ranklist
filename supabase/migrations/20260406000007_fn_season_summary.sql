-- =============================================================================
-- fn_season_summary: aggregate counts for the active season (Telegram status)
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_season_summary()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_season INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE bool_active = TRUE;
  IF v_season IS NULL THEN
    RAISE EXCEPTION 'No active season';
  END IF;

  RETURN (
    SELECT jsonb_build_object(
      'season_code', (SELECT txt_code FROM tbl_season WHERE id_season = v_season),
      'fencers', (SELECT COUNT(*) FROM tbl_fencer),
      'events', (SELECT COUNT(*) FROM tbl_event WHERE id_season = v_season),
      'tournaments', (SELECT COUNT(*) FROM tbl_tournament t
                      JOIN tbl_event e ON t.id_event = e.id_event
                      WHERE e.id_season = v_season
                        AND EXISTS(SELECT 1 FROM tbl_result r WHERE r.id_tournament = t.id_tournament)),
      'results', (SELECT COUNT(*) FROM tbl_result r
                  JOIN tbl_tournament t ON r.id_tournament = t.id_tournament
                  JOIN tbl_event e ON t.id_event = e.id_event
                  WHERE e.id_season = v_season),
      'scored', (SELECT COUNT(*) FROM tbl_result r
                 JOIN tbl_tournament t ON r.id_tournament = t.id_tournament
                 JOIN tbl_event e ON t.id_event = e.id_event
                 WHERE e.id_season = v_season
                   AND r.num_final_score IS NOT NULL)
    )
  );
END;
$$;
