-- =============================================================================
-- ADR-077 §6 — fn_revert_season_init: guard on CHILDLESSNESS, not status
-- =============================================================================
-- The wizard provisions seasons as CHILDLESS skeleton events (migration
-- 20260627000003); tournaments are ingested per-event later. The original
-- revert guard refused whenever any event had advanced past CREATED
-- (e.g. an admin dated a skeleton to PLANNED) — but a childless PLANNED
-- season carries NO results and is perfectly safe to revert/delete.
--
-- New guard: refuse only when AT LEAST ONE event has a tbl_tournament child.
-- A tournament child is the first point at which results can exist, so that
-- is the true regime boundary protecting the live ranklist — independent of
-- the lifecycle status. A childless-but-PLANNED (or SCHEDULED, etc.) season
-- is now revertible; a season with any ingested tournament is not.
--
-- Supersedes the status-based guard in 20260428000005_fn_revert_season_init.sql.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_revert_season_init(p_id_season INT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM tbl_season WHERE id_season = p_id_season) THEN
    RAISE EXCEPTION 'fn_revert_season_init: season % not found', p_id_season;
  END IF;

  -- ADR-077 §6: childlessness, not status, is the revertibility boundary.
  IF EXISTS (
    SELECT 1
      FROM tbl_tournament t
      JOIN tbl_event e ON e.id_event = t.id_event
     WHERE e.id_season = p_id_season
  ) THEN
    RAISE EXCEPTION
      'fn_revert_season_init: season % has events with tournament children — revert refused (results may exist)',
      p_id_season;
  END IF;

  -- No children by the guard above; these deletes are childless-safe.
  DELETE FROM tbl_tournament
   WHERE id_event IN (SELECT id_event FROM tbl_event WHERE id_season = p_id_season);

  DELETE FROM tbl_event          WHERE id_season = p_id_season;
  DELETE FROM tbl_scoring_config WHERE id_season = p_id_season;
  DELETE FROM tbl_season         WHERE id_season = p_id_season;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_revert_season_init(INT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_revert_season_init(INT) TO authenticated;
