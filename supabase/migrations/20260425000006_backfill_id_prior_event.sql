-- =============================================================================
-- Migration: fn_backfill_id_prior_event() — idempotent backfill function
-- =============================================================================
-- Phase 1B step 4 — auto-link current-season events to their prior-season
-- counterpart based on prefix-match (fn_event_position).
--
-- Rule: a current-season event links to a prior-season event IFF both events'
-- prefixes are UNIQUE within their respective seasons. This excludes:
--   - Slug events with shared prefix (PEW-SALLEJEANZ, PEW-SPORTHALLE,
--     PEW-LIÈGE all share prefix 'PEW') → manual cleanup needed
--   - Naturally-singular events with no counterpart → no link, NULL stays
--
-- Why a function (not a one-shot UPDATE in the migration body):
--   In local dev / CI, `supabase db reset` runs migrations on an empty DB
--   THEN seeds. A one-shot UPDATE would match zero rows. Wrapping in a
--   function lets us invoke it post-seed via supabase/seed_post_backfill.sql.
--   In PROD/CERT, after migrations apply against live data, an admin runs
--   `SELECT fn_backfill_id_prior_event();` once via SQL editor.
--
-- Idempotent: only sets NULL FKs; skips already-linked rows.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_backfill_id_prior_event()
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
  v_updated INT;
  r RECORD;
BEGIN
  WITH season_pairs AS (
    SELECT
      s_curr.id_season AS curr_id,
      (SELECT s_prev.id_season FROM tbl_season s_prev
         WHERE s_prev.dt_end < s_curr.dt_start
         ORDER BY s_prev.dt_end DESC LIMIT 1) AS prev_id
    FROM tbl_season s_curr
  ),
  unique_prefixes AS (
    SELECT id_season, fn_event_position(txt_code) AS prefix, MIN(id_event) AS id_event
    FROM tbl_event
    GROUP BY id_season, fn_event_position(txt_code)
    HAVING COUNT(*) = 1
  )
  UPDATE tbl_event curr
  SET id_prior_event = up_prev.id_event
  FROM season_pairs sp,
       unique_prefixes up_curr,
       unique_prefixes up_prev
  WHERE curr.id_prior_event IS NULL
    AND up_curr.id_season = sp.curr_id
    AND up_curr.id_event = curr.id_event
    AND up_prev.id_season = sp.prev_id
    AND up_prev.prefix = up_curr.prefix;

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  RAISE NOTICE 'fn_backfill_id_prior_event: linked % event(s)', v_updated;

  -- Diagnostic: list events that still have NULL FK and need manual review
  FOR r IN
    SELECT e.id_event, e.txt_code, s.txt_code AS season_code
      FROM tbl_event e
      JOIN tbl_season s ON s.id_season = e.id_season
     WHERE e.id_prior_event IS NULL
       AND e.id_season > (SELECT MIN(id_season) FROM tbl_event)
     ORDER BY s.txt_code, e.txt_code
  LOOP
    RAISE NOTICE 'Event needs manual id_prior_event assignment: id=%, code=%, season=%',
      r.id_event, r.txt_code, r.season_code;
  END LOOP;

  RETURN v_updated;
END;
$$;

COMMENT ON FUNCTION fn_backfill_id_prior_event() IS
  'Phase 1B (ADR-042): idempotent backfill that links current-season events to '
  'their prior-season counterpart by unique prefix. Returns count of rows updated. '
  'Run AFTER seed/data exists. In PROD: admin invokes once via SQL editor post-deploy.';
