-- =============================================================================
-- Post-seed: Phase 1B FK backfill + Phase 2 slug-event repair
-- =============================================================================
-- Runs after seed_prod_latest.sql via config.toml [db.seed].sql_paths order.
-- In PROD/CERT, run this manually once via SQL editor after each phase deploys.
-- Idempotent: safe to run multiple times.
-- =============================================================================

SELECT fn_backfill_id_prior_event();

-- Phase 2 (Migration 20260427000003): repeat the slug-rename + organizer
-- sweep here for LOCAL dev, where the migration ran against an empty schema
-- (no tbl_organizer rows yet). PROD/CERT runs the migration directly.
DO $phase2$
DECLARE
  v_evf_org   INT;
  v_spws_org  INT;
  v_old_event INT;
  v_new_code  CONSTANT TEXT := 'DMEW-2025-2026';
  v_old_code  CONSTANT TEXT := 'MEW-COMPLEXESP-2025-2026';
BEGIN
  SELECT id_organizer INTO v_evf_org  FROM tbl_organizer WHERE txt_code = 'EVF';
  SELECT id_organizer INTO v_spws_org FROM tbl_organizer WHERE txt_code = 'SPWS';
  IF v_evf_org IS NULL THEN
    RETURN;
  END IF;

  SELECT id_event INTO v_old_event FROM tbl_event WHERE txt_code = v_old_code;
  IF v_old_event IS NOT NULL THEN
    UPDATE tbl_tournament
       SET txt_code = replace(txt_code, v_old_code, v_new_code)
     WHERE id_event = v_old_event
       AND txt_code LIKE v_old_code || '%';

    IF EXISTS (
      SELECT 1 FROM pg_enum e
        JOIN pg_type t ON t.oid = e.enumtypid
       WHERE t.typname = 'enum_tournament_type' AND e.enumlabel = 'DMEW'
    ) THEN
      UPDATE tbl_tournament SET enum_type = 'DMEW'
       WHERE id_event = v_old_event AND enum_type::TEXT = 'MEW';
    END IF;

    UPDATE tbl_event
       SET txt_code = v_new_code, id_organizer = v_evf_org
     WHERE id_event = v_old_event;
  END IF;

  IF v_spws_org IS NOT NULL THEN
    UPDATE tbl_event SET id_organizer = v_evf_org
     WHERE id_organizer = v_spws_org
       AND (txt_code LIKE 'PEW%' OR txt_code LIKE 'IMEW%' OR txt_code LIKE 'DMEW%');
  END IF;
END;
$phase2$;

-- PEW-LIÈGE-2025-2026: event held; sabre weapons had no entrants and results
-- cannot be retrieved. Mark event COMPLETED while leaving the empty F-SABRE /
-- M-SABRE child tournaments in place (matches the PEW-SPORTHALLE / SALLEJEANZ
-- pattern: COMPLETED event with weapon slots that had zero participants).
-- Walk the status sequence to satisfy the transition trigger
-- (PLANNED → IN_PROGRESS → SCORED → COMPLETED).
DO $liege$
DECLARE
  v_id INT;
BEGIN
  SELECT id_event INTO v_id FROM tbl_event WHERE txt_code = 'PEW-LIÈGE-2025-2026';
  IF v_id IS NULL THEN RETURN; END IF;
  IF (SELECT enum_status::TEXT FROM tbl_event WHERE id_event = v_id) = 'PLANNED' THEN
    UPDATE tbl_event SET enum_status = 'IN_PROGRESS' WHERE id_event = v_id;
    UPDATE tbl_event SET enum_status = 'SCORED'      WHERE id_event = v_id;
    UPDATE tbl_event SET enum_status = 'COMPLETED'   WHERE id_event = v_id;
  END IF;
END;
$liege$;
