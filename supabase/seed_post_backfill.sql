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

-- Drop PEW-SPORTHALLE-2025-2026 (event 45 in seed): pre-allocator slug-format
-- duplicate of Munich Dec 6, 2025 already represented under PEW3-2025-2026
-- with proper url_results + correct field sizes. The duplicate has no URLs
-- and POL-only int_participant_count, so the engine zeros all rows
-- (e.g. Marcin Ganszczyk M-SABRE place 6 → score 0.00). Drop entirely; the
-- five duplicate fencer-records survive in PEW3-V2-M-SABRE-2025-2026 et al.
-- Two unique records (Ginzery V1 M-FOIL, Zylka V4 M-FOIL) intentionally
-- dropped per admin decision — re-scrape later if needed.
DO $drop_sporthalle$
DECLARE
  v_id INT;
BEGIN
  SELECT id_event INTO v_id FROM tbl_event WHERE txt_code = 'PEW-SPORTHALLE-2025-2026';
  IF v_id IS NULL THEN RETURN; END IF;
  DELETE FROM tbl_match_candidate
   WHERE id_result IN (
     SELECT r.id_result FROM tbl_result r
       JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
      WHERE t.id_event = v_id
   );
  DELETE FROM tbl_result
   WHERE id_tournament IN (SELECT id_tournament FROM tbl_tournament WHERE id_event = v_id);
  DELETE FROM tbl_tournament WHERE id_event = v_id;
  DELETE FROM tbl_event      WHERE id_event = v_id;
END;
$drop_sporthalle$;

-- PEW3-2024-2025 (Guildford / Orléans multi-slot): correct corrupted dt_start
-- (was 2024-01-04 — year/month typo) and the txt_location typo (was 'Guilford').
-- The earliest child tournament is 2024-12-07 (Guildford UK leg). dt_end stays
-- 2025-01-04 — that's the genuine end of the multi-slot event span.
DO $fix_guildford$
BEGIN
  UPDATE tbl_event
     SET dt_start = '2024-12-07'::DATE,
         txt_location = 'Guildford'
   WHERE txt_code = 'PEW3-2024-2025'
     AND (dt_start = '2024-01-04'::DATE OR txt_location = 'Guilford');
END;
$fix_guildford$;

-- Tournament 380 (PEW3-V2-M-SABRE-2025-2026, Munich Dec 6 2025): the v2 ingest
-- recorded int_participant_count=2 (POL-only count) instead of the true field
-- size of 25 (verified against fencingworldwide.com/en/912306-2025/results/).
-- Sister tournaments 382/384 already carry correct counts; only 380 was missed.
-- Update count, then recompute scores so all entrants get the right place_pts.
DO $fix_tourn_380$
DECLARE
  v_tid INT;
BEGIN
  SELECT id_tournament INTO v_tid
    FROM tbl_tournament WHERE txt_code = 'PEW3-V2-M-SABRE-2025-2026';
  IF v_tid IS NULL THEN RETURN; END IF;
  UPDATE tbl_tournament SET int_participant_count = 25
   WHERE id_tournament = v_tid AND int_participant_count <> 25;
  PERFORM fn_calc_tournament_scores(v_tid);
END;
$fix_tourn_380$;

-- Phase 4 (ADR-046): re-run splitter after seed loads so LOCAL DB matches the
-- post-migration shape that PROD/CERT see when the migration applies against
-- their existing data. Idempotent — safe to re-run.
SELECT * FROM fn_split_pew_by_weapon();
SELECT fn_backfill_id_prior_event();

-- Phase 4 child-code reconciliation: when fn_split_pew_by_weapon Step 2 finds
-- a parent event already correctly suffixed, it skips the rename — including
-- the child rename. This leaves child tournaments with legacy codes (e.g.,
-- PEW-SPORTHALLE-2025-2026-F-FOIL still under PEW21fs-2025-2026 after the
-- splitter ran during a prior migration apply). Reconcile child codes here
-- so they match parent prefix. Idempotent — finds no mismatches on re-run.
UPDATE tbl_tournament t
   SET txt_code = (
     regexp_replace(e.txt_code, '-\d{4}-\d{4}$', '')
     || '-' || t.enum_age_category::TEXT
     || '-' || t.enum_gender::TEXT
     || '-' || t.enum_weapon::TEXT
     || '-' || regexp_replace(e.txt_code, '^PEW\d+[efs]*-', '')
   )
  FROM tbl_event e
 WHERE t.id_event = e.id_event
   AND e.txt_code ~ '^PEW\d+[efs]+-'
   AND t.txt_code !~ ('^' || regexp_replace(e.txt_code, '-\d{4}-\d{4}$', '') || '-');

-- Phase 4 location fixes for events whose splitter-kept cluster is at a
-- different city than the original parent's txt_location indicated.
-- Munich Dec hosts the early PEW3 weekend in both seasons; Guildford Jan
-- hosts the split-out cluster (which was originally bundled under PEW3).
DO $phase4_locations$
BEGIN
  UPDATE tbl_event
     SET txt_location = 'Munich', txt_country = 'Germany'
   WHERE txt_code IN ('PEW3fs-2024-2025', 'PEW3s-2025-2026')
     AND (txt_location IS DISTINCT FROM 'Munich' OR txt_country IS DISTINCT FROM 'Germany');

  UPDATE tbl_event
     SET txt_location = 'Guildford', txt_country = 'Great Britain'
   WHERE txt_code IN ('PEW11e-2024-2025', 'PEW10efs-2025-2026')
     AND txt_location IS NULL;
END;
$phase4_locations$;
