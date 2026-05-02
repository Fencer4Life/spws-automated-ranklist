-- =============================================================================
-- Phase 4 (ADR-053) — EVF parity gate + EVF_PUBLISHED promotion lifecycle
--
-- Replaces the Phase 0 enum_source_status {LIVE_SOURCE, FROZEN_SNAPSHOT,
-- NO_SOURCE} with the two-state lifecycle {ENGINE_COMPUTED, EVF_PUBLISHED}
-- per ADR-053. Adds tbl_event.txt_parity_notes (nullable) for parity-fail
-- annotations. Adds DB-level enforcement of the status × organizer invariant
-- via a trigger (CHECK can't reference FK organizer code without a cached
-- column; trigger keeps the schema clean).
--
-- Why values collapse: at this migration's runtime, no event has yet been
-- through the new parity gate; every row is engine-computed by definition.
-- LIVE_SOURCE / FROZEN_SNAPSHOT / NO_SOURCE all map to ENGINE_COMPUTED.
-- Subsequent Phase 5 rebuild events that pass parity get promoted to
-- EVF_PUBLISHED via fn_promote_evf_published (added below).
--
-- Tests: supabase/tests/29_evf_parity_lifecycle.sql (12 assertions).
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Drop old vw_calendar so the column type swap can proceed
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_def TEXT;
BEGIN
  SELECT pg_get_viewdef('vw_calendar'::regclass, TRUE) INTO v_def;
  IF v_def IS NOT NULL THEN
    -- Stash the def in a temp table so we can rebuild after the type swap
    CREATE TEMP TABLE _vw_calendar_def_stash (def TEXT) ON COMMIT DROP;
    INSERT INTO _vw_calendar_def_stash VALUES (v_def);
    EXECUTE 'DROP VIEW vw_calendar CASCADE';
  END IF;
EXCEPTION
  WHEN undefined_table THEN
    NULL;
END$$;

-- ---------------------------------------------------------------------------
-- 2. Migrate enum_source_status: replace values
--    Approach: convert column to TEXT, drop old enum, create new enum,
--    map values, convert column back.
-- ---------------------------------------------------------------------------

-- Drop default temporarily (default references old enum value)
ALTER TABLE tbl_event ALTER COLUMN txt_source_status DROP DEFAULT;

-- Convert column to TEXT to free the enum from the column dependency
ALTER TABLE tbl_event
  ALTER COLUMN txt_source_status TYPE TEXT USING txt_source_status::TEXT;

-- Drop old enum
DROP TYPE enum_source_status;

-- Create new enum with the two-state lifecycle
CREATE TYPE enum_source_status AS ENUM (
  'ENGINE_COMPUTED',  -- engine output, default; valid for any organizer
  'EVF_PUBLISHED'     -- EVF API verbatim values; only for EVF-organized events
);

COMMENT ON TYPE enum_source_status IS
  'Per-event data-provenance lifecycle (ADR-053). ENGINE_COMPUTED is the '
  'universal default. EVF_PUBLISHED is reserved for EVF-organized events '
  'whose engine output passed the parity gate and was overwritten with '
  'EVF API''s authoritative numbers.';

-- Map old values → ENGINE_COMPUTED. All current rows are pre-parity.
UPDATE tbl_event
SET txt_source_status = 'ENGINE_COMPUTED'
WHERE txt_source_status IN ('LIVE_SOURCE', 'FROZEN_SNAPSHOT', 'NO_SOURCE');

-- Convert column back to enum
ALTER TABLE tbl_event
  ALTER COLUMN txt_source_status TYPE enum_source_status
    USING txt_source_status::enum_source_status;

ALTER TABLE tbl_event
  ALTER COLUMN txt_source_status SET DEFAULT 'ENGINE_COMPUTED';

-- Reaffirm NOT NULL (was set in Phase 0; survived the type round-trip)
ALTER TABLE tbl_event
  ALTER COLUMN txt_source_status SET NOT NULL;

COMMENT ON COLUMN tbl_event.txt_source_status IS
  'Data-provenance lifecycle (ADR-053). ENGINE_COMPUTED at commit; flips to '
  'EVF_PUBLISHED for EVF events whose parity check passed (engine output '
  'replaced by EVF API verbatim). SPWS / FIE events are pinned to '
  'ENGINE_COMPUTED by trigger trg_check_source_status_organizer.';

-- ---------------------------------------------------------------------------
-- 3. txt_parity_notes — nullable annotation for parity-fail / EVF-empty
-- ---------------------------------------------------------------------------
ALTER TABLE tbl_event
  ADD COLUMN IF NOT EXISTS txt_parity_notes TEXT;

COMMENT ON COLUMN tbl_event.txt_parity_notes IS
  'Structured parity-gate failure summary (ADR-053). NULL when parity '
  'has passed or has not yet run. Set by evf_parity sweep on FAIL or '
  'when EVF API has been empty for 30 days.';

-- ---------------------------------------------------------------------------
-- 4. Trigger enforcing status × organizer invariant
--    SPWS / FIE: txt_source_status MUST be ENGINE_COMPUTED.
--    EVF:        txt_source_status may be ENGINE_COMPUTED or EVF_PUBLISHED.
--    Other organizers (legacy / unrecognized): default to SPWS-equivalent
--    treatment (ENGINE_COMPUTED only) — strict by default.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_check_source_status_organizer()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_organizer_code TEXT;
BEGIN
  IF NEW.txt_source_status = 'EVF_PUBLISHED'::enum_source_status THEN
    SELECT txt_code INTO v_organizer_code
    FROM tbl_organizer
    WHERE id_organizer = NEW.id_organizer;

    IF v_organizer_code IS DISTINCT FROM 'EVF' THEN
      RAISE EXCEPTION
        'tbl_event.txt_source_status = EVF_PUBLISHED is only valid for EVF-organized events. id_event=%, organizer_code=%',
        NEW.id_event, COALESCE(v_organizer_code, '<NULL>');
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_check_source_status_organizer() IS
  'BEFORE INSERT/UPDATE trigger on tbl_event enforcing the ADR-053 '
  'invariant: only EVF-organized events may carry EVF_PUBLISHED. SPWS '
  'and FIE events are pinned to ENGINE_COMPUTED. Substitutes for a CHECK '
  'constraint, which can''t reference FK-joined organizer code.';

DROP TRIGGER IF EXISTS trg_check_source_status_organizer ON tbl_event;

CREATE TRIGGER trg_check_source_status_organizer
  BEFORE INSERT OR UPDATE OF txt_source_status, id_organizer ON tbl_event
  FOR EACH ROW
  EXECUTE FUNCTION fn_check_source_status_organizer();

-- ---------------------------------------------------------------------------
-- 5. Rebuild vw_calendar (column type changed)
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_def TEXT;
BEGIN
  SELECT def INTO v_def FROM _vw_calendar_def_stash LIMIT 1;
  IF v_def IS NOT NULL THEN
    EXECUTE 'CREATE VIEW vw_calendar AS ' || v_def;
  END IF;
EXCEPTION
  WHEN undefined_table THEN
    NULL;  -- stash didn't exist (vw_calendar wasn't there pre-migration)
END$$;

COMMIT;
