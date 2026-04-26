-- =============================================================================
-- Migration: FK-based carry-over schema (Phase 1B foundation)
-- =============================================================================
-- Phase 1B step 3 — adds the columns and enum value used by the FK-matching
-- engine. No behavior change yet; the dispatcher (Phase 1A) still routes every
-- season to EVENT_CODE_MATCHING by default.
--
-- New surface:
--   tbl_event.id_prior_event       — explicit cross-year link (nullable FK)
--   tbl_season.int_carryover_days  — per-season carry-over window (default 366)
--   tbl_season.enum_european_event_type — IMEW vs DMEW year flag (nullable)
--   enum_event_status += CREATED   — pre-allocation status (Phase 3 use)
-- =============================================================================

-- Status flow per project memory: CREATED → PLANNED → IN_PROGRESS → SCORED → COMPLETED
-- CREATED: pre-allocation (Phase 3 will populate)
-- SCORED:  results ingested but event not yet finalized (carry-stop trigger for FK engine)
ALTER TYPE enum_event_status ADD VALUE IF NOT EXISTS 'CREATED' BEFORE 'PLANNED';
ALTER TYPE enum_event_status ADD VALUE IF NOT EXISTS 'SCORED' BEFORE 'COMPLETED';

-- Explicit cross-year link; ON DELETE SET NULL preserves history without cascade
ALTER TABLE tbl_event ADD COLUMN id_prior_event INT
  REFERENCES tbl_event(id_event) ON DELETE SET NULL;

-- A given prior event must not carry into two current-season slots simultaneously
CREATE UNIQUE INDEX idx_event_prior_unique
  ON tbl_event (id_season, id_prior_event)
  WHERE id_prior_event IS NOT NULL;

-- Carry-over window cap (days). Default ~1 year; admin-editable in Phase 3
ALTER TABLE tbl_season ADD COLUMN int_carryover_days INTEGER
  NOT NULL DEFAULT 366
  CHECK (int_carryover_days > 0);

-- IMEW vs DMEW year flag (Phase 3 admin sets at season create)
ALTER TABLE tbl_season ADD COLUMN enum_european_event_type TEXT
  CHECK (enum_european_event_type IN ('IMEW', 'DMEW') OR enum_european_event_type IS NULL);

-- ---------------------------------------------------------------------------
-- Extend fn_validate_event_transition to permit CREATED/SCORED transitions.
-- Phase 3 will refine. For Phase 1B, allow:
--   CREATED → PLANNED         (admin fills in dt_start)
--   PLANNED → CREATED         (rollback to skeleton)
--   IN_PROGRESS → SCORED      (results ingested)
--   SCORED → COMPLETED        (final state)
--   SCORED → IN_PROGRESS      (rollback)
--   COMPLETED → SCORED        (rollback)
--   COMPLETED → CREATED       (full rollback to skeleton — used by tests)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validate_event_transition()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_valid BOOLEAN := FALSE;
BEGIN
    v_valid := CASE
        -- From CREATED (new, Phase 1B)
        WHEN OLD.enum_status = 'CREATED'      AND NEW.enum_status = 'PLANNED'     THEN TRUE
        WHEN OLD.enum_status = 'CREATED'      AND NEW.enum_status = 'CANCELLED'   THEN TRUE
        -- From PLANNED
        WHEN OLD.enum_status = 'PLANNED'      AND NEW.enum_status = 'SCHEDULED'   THEN TRUE
        WHEN OLD.enum_status = 'PLANNED'      AND NEW.enum_status = 'IN_PROGRESS' THEN TRUE
        WHEN OLD.enum_status = 'PLANNED'      AND NEW.enum_status = 'CANCELLED'   THEN TRUE
        WHEN OLD.enum_status = 'PLANNED'      AND NEW.enum_status = 'CREATED'     THEN TRUE  -- Phase 1B rollback
        -- From SCHEDULED
        WHEN OLD.enum_status = 'SCHEDULED'    AND NEW.enum_status = 'CHANGED'     THEN TRUE
        WHEN OLD.enum_status = 'SCHEDULED'    AND NEW.enum_status = 'IN_PROGRESS' THEN TRUE
        WHEN OLD.enum_status = 'SCHEDULED'    AND NEW.enum_status = 'CANCELLED'   THEN TRUE
        -- From CHANGED
        WHEN OLD.enum_status = 'CHANGED'      AND NEW.enum_status = 'SCHEDULED'   THEN TRUE
        WHEN OLD.enum_status = 'CHANGED'      AND NEW.enum_status = 'IN_PROGRESS' THEN TRUE
        WHEN OLD.enum_status = 'CHANGED'      AND NEW.enum_status = 'CANCELLED'   THEN TRUE
        -- From IN_PROGRESS
        WHEN OLD.enum_status = 'IN_PROGRESS'  AND NEW.enum_status = 'SCORED'      THEN TRUE  -- Phase 1B
        WHEN OLD.enum_status = 'IN_PROGRESS'  AND NEW.enum_status = 'COMPLETED'   THEN TRUE
        WHEN OLD.enum_status = 'IN_PROGRESS'  AND NEW.enum_status = 'PLANNED'     THEN TRUE
        WHEN OLD.enum_status = 'IN_PROGRESS'  AND NEW.enum_status = 'CANCELLED'   THEN TRUE
        -- From SCORED (new, Phase 1B)
        WHEN OLD.enum_status = 'SCORED'       AND NEW.enum_status = 'COMPLETED'   THEN TRUE
        WHEN OLD.enum_status = 'SCORED'       AND NEW.enum_status = 'IN_PROGRESS' THEN TRUE  -- rollback
        -- From COMPLETED
        WHEN OLD.enum_status = 'COMPLETED'    AND NEW.enum_status = 'SCORED'      THEN TRUE  -- Phase 1B rollback
        WHEN OLD.enum_status = 'COMPLETED'    AND NEW.enum_status = 'IN_PROGRESS' THEN TRUE
        WHEN OLD.enum_status = 'COMPLETED'    AND NEW.enum_status = 'PLANNED'     THEN TRUE
        -- Phase 1B universal rollback to CREATED skeleton (admin reset / season-init reuse)
        WHEN NEW.enum_status = 'CREATED'      AND OLD.enum_status IN
             ('PLANNED','SCHEDULED','CHANGED','IN_PROGRESS','SCORED','COMPLETED','CANCELLED') THEN TRUE
        ELSE FALSE
    END;

    IF NOT v_valid THEN
        RAISE EXCEPTION 'Invalid event status transition: % → %',
            OLD.enum_status, NEW.enum_status;
    END IF;

    RETURN NEW;
END;
$$;
