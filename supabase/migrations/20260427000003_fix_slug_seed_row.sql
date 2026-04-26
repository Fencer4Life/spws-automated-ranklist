-- =============================================================================
-- Phase 2: data fix — rename MEW-COMPLEXESP-2025-2026 → DMEW-2025-2026,
-- reassign EVF-organized events from SPWS to EVF (ADR-043).
-- =============================================================================
-- 'MEW' is not a real event kind. The European Team Championships row was
-- mis-coded with a venue slug (`MEW-COMPLEXESP-2025-2026`). The correct
-- code is the singleton `DMEW-2025-2026`. Cascades to child tournaments.
-- Sweep also fixes id_organizer for any PEW/IMEW/DMEW row mistakenly
-- assigned to the SPWS organizer (these events are organized by EVF).
--
-- Idempotent: each UPDATE narrows on rows still in the wrong state, so
-- re-running is a no-op.
-- =============================================================================

DO $migrate$
DECLARE
  v_evf_org   INT;
  v_spws_org  INT;
  v_old_event INT;
  v_new_code  CONSTANT TEXT := 'DMEW-2025-2026';
  v_old_code  CONSTANT TEXT := 'MEW-COMPLEXESP-2025-2026';
BEGIN
  SELECT id_organizer INTO v_evf_org  FROM tbl_organizer WHERE txt_code = 'EVF';
  SELECT id_organizer INTO v_spws_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  -- LOCAL dev runs migrations BEFORE seed loads, so tbl_organizer is empty
  -- on first apply. Skip silently — seed_post_backfill.sql re-runs the same
  -- fix after the seed lands. CERT/PROD always have organizers seeded
  -- (the snapshot exported from PROD includes them), so the migration
  -- performs the rename there.
  IF v_evf_org IS NULL THEN
    RAISE NOTICE 'fix_slug_seed_row: EVF organizer not found, skipping (expected on local pre-seed)';
    RETURN;
  END IF;

  -- Step 1: rename slug event → DMEW (only if old row still exists)
  SELECT id_event INTO v_old_event
    FROM tbl_event
   WHERE txt_code = v_old_code;

  IF v_old_event IS NOT NULL THEN
    -- 1a) Cascade-rename child tournaments first (txt_code embeds parent code).
    UPDATE tbl_tournament
       SET txt_code = replace(txt_code, v_old_code, v_new_code)
     WHERE id_event = v_old_event
       AND txt_code LIKE v_old_code || '%';

    -- 1b) Reset child tournament enum_type from 'MEW' to 'DMEW'
    --     (only if the enum has 'DMEW' value — safe-skip otherwise)
    IF EXISTS (
      SELECT 1 FROM pg_enum e
        JOIN pg_type t ON t.oid = e.enumtypid
       WHERE t.typname = 'enum_tournament_type' AND e.enumlabel = 'DMEW'
    ) THEN
      UPDATE tbl_tournament
         SET enum_type = 'DMEW'
       WHERE id_event = v_old_event
         AND enum_type::TEXT = 'MEW';
    END IF;

    -- 1c) Rename the parent event + reassign organizer to EVF
    UPDATE tbl_event
       SET txt_code     = v_new_code,
           id_organizer = v_evf_org
     WHERE id_event = v_old_event;

    RAISE NOTICE 'fix_slug_seed_row: renamed % → % (id_event=%)',
      v_old_code, v_new_code, v_old_event;
  END IF;

  -- Step 2: sweep — any PEW/IMEW/DMEW row still owned by SPWS gets EVF
  IF v_spws_org IS NOT NULL THEN
    UPDATE tbl_event
       SET id_organizer = v_evf_org
     WHERE id_organizer = v_spws_org
       AND (txt_code LIKE 'PEW%' OR txt_code LIKE 'IMEW%' OR txt_code LIKE 'DMEW%');
  END IF;
END;
$migrate$;
