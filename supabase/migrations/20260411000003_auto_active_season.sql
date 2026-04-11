-- =============================================================================
-- Migration: Auto-Active Season by Date (ADR-031)
-- =============================================================================
-- Changes bool_active from manually-set to auto-derived:
--   Primary: season where dt_start <= TODAY <= dt_end
--   Fallback: nearest future season (smallest dt_start > TODAY)
-- Also adds exclusion constraint preventing overlapping season date ranges.
-- =============================================================================

-- 1. Enable btree_gist (required for daterange exclusion constraint)
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- 2. Exclusion constraint — no overlapping season date ranges
ALTER TABLE tbl_season
  ADD CONSTRAINT excl_season_date_overlap
  EXCLUDE USING gist (daterange(dt_start, dt_end, '[]') WITH &&);

-- 3. Core function: determine and set the active season
CREATE OR REPLACE FUNCTION fn_refresh_active_season()
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_target_id INT;
BEGIN
  -- Primary: season where dt_start <= TODAY <= dt_end
  SELECT id_season INTO v_target_id
    FROM tbl_season
   WHERE dt_start <= CURRENT_DATE AND dt_end >= CURRENT_DATE
   LIMIT 1;

  -- Fallback: nearest future season
  IF v_target_id IS NULL THEN
    SELECT id_season INTO v_target_id
      FROM tbl_season
     WHERE dt_start > CURRENT_DATE
     ORDER BY dt_start ASC
     LIMIT 1;
  END IF;

  -- Deactivate all, then activate the target (if any)
  UPDATE tbl_season SET bool_active = FALSE WHERE bool_active = TRUE;
  IF v_target_id IS NOT NULL THEN
    UPDATE tbl_season SET bool_active = TRUE WHERE id_season = v_target_id;
  END IF;
END;
$$;

COMMENT ON FUNCTION fn_refresh_active_season() IS
  'Auto-derive the active season (ADR-031). '
  'Primary: dt_start <= TODAY <= dt_end. '
  'Fallback: nearest future season. '
  'Called by trigger on tbl_season changes and by frontend on app load.';

-- 4. Trigger wrapper (AFTER statement to avoid repeated recalculation)
CREATE OR REPLACE FUNCTION fn_trg_refresh_active_season()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  PERFORM fn_refresh_active_season();
  RETURN NULL;
END;
$$;

-- Fire on date changes and deletes, NOT on bool_active updates (avoids recursion)
CREATE TRIGGER trg_season_refresh_active
  AFTER INSERT OR UPDATE OF dt_start, dt_end OR DELETE
  ON tbl_season
  FOR EACH STATEMENT
  EXECUTE FUNCTION fn_trg_refresh_active_season();

-- 5. Drop the old unique partial index on bool_active
--    No longer needed — single-active is enforced by fn_refresh_active_season logic
DROP INDEX IF EXISTS idx_season_active;

-- 6. Run initial refresh to set bool_active based on current dates
SELECT fn_refresh_active_season();

-- 7. Grant to authenticated so frontend can call refresh on app load
GRANT EXECUTE ON FUNCTION fn_refresh_active_season() TO authenticated;
