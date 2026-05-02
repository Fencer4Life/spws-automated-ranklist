-- =============================================================================
-- Phase 4 (ADR-046, ADR-050) — Stage 8b PEW cascade-rename hook
--
-- Per-event extraction of the cascade-rename logic that fn_split_pew_by_weapon
-- already runs in bulk. Stage 8b of the unified pipeline calls this RPC
-- post-commit when the Stage 7 weapon-mismatch flag (pew_cascade_pending)
-- was set — operator added a new weapon to a PEW weekend, code needs to
-- evolve.
--
-- Idempotent: re-running on already-suffixed events with the same child
-- weapon set is a no-op (returns 0).
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_pew_recompute_event_code(p_id_event INT)
RETURNS INT  -- count of tbl_event + tbl_tournament rows renamed
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_evt          RECORD;
  v_letters      TEXT;
  v_new_code     TEXT;
  v_temp_marker  TEXT := '__pew_cascade_temp__';
  v_renamed      INT  := 0;
  v_t            RECORD;
  v_age_part     TEXT;
  v_t_new_code   TEXT;
  v_pew_n        INT;
  v_season_suffix TEXT;
BEGIN
  SELECT id_event, txt_code
    INTO v_evt
    FROM tbl_event
    WHERE id_event = p_id_event;
  IF v_evt IS NULL THEN
    RETURN 0;
  END IF;

  -- Non-PEW events: no-op (per ADR-046 PEW-only scope)
  IF v_evt.txt_code !~ '^PEW\d+[efs]*-' THEN
    RETURN 0;
  END IF;

  v_pew_n := ((regexp_match(v_evt.txt_code, '^PEW(\d+)'))[1])::INT;
  v_season_suffix := regexp_replace(v_evt.txt_code, '^PEW\d+[efs]*-', '');

  -- Compute current letters from child weapon set
  SELECT fn_pew_weapon_letters(array_agg(DISTINCT t.enum_weapon))
    INTO v_letters
    FROM tbl_tournament t
    WHERE t.id_event = p_id_event;

  IF v_letters IS NULL OR v_letters = '' THEN
    RETURN 0;  -- defensive: no children
  END IF;

  v_new_code := 'PEW' || v_pew_n::TEXT || v_letters || '-' || v_season_suffix;

  IF v_evt.txt_code = v_new_code THEN
    RETURN 0;  -- idempotent
  END IF;

  -- Two-step cascade to avoid uniqueness conflicts
  UPDATE tbl_tournament
     SET txt_code = v_temp_marker || id_tournament::TEXT
     WHERE id_event = p_id_event;

  UPDATE tbl_event SET txt_code = v_new_code, ts_updated = NOW()
     WHERE id_event = p_id_event;
  v_renamed := v_renamed + 1;

  FOR v_t IN
    SELECT id_tournament, enum_weapon, enum_gender, enum_age_category
      FROM tbl_tournament WHERE id_event = p_id_event
  LOOP
    v_age_part   := v_t.enum_age_category::TEXT;
    v_t_new_code := 'PEW' || v_pew_n::TEXT || v_letters
                    || '-' || v_age_part
                    || '-' || v_t.enum_gender::TEXT
                    || '-' || v_t.enum_weapon::TEXT
                    || '-' || v_season_suffix;
    UPDATE tbl_tournament
       SET txt_code = v_t_new_code, ts_updated = NOW()
       WHERE id_tournament = v_t.id_tournament;
    v_renamed := v_renamed + 1;
  END LOOP;

  -- Audit log
  INSERT INTO tbl_audit_log (txt_table_name, id_row, txt_action, jsonb_old_values, jsonb_new_values)
  VALUES (
    'tbl_event', p_id_event, 'pew_cascade_rename',
    jsonb_build_object('txt_code', v_evt.txt_code),
    jsonb_build_object('txt_code', v_new_code, 'rows_renamed', v_renamed)
  );

  RETURN v_renamed;
END;
$$;

COMMENT ON FUNCTION fn_pew_recompute_event_code(INT) IS
  'Stage 8b (Phase 4 ADR-046, ADR-050): per-event PEW cascade-rename. '
  'Idempotent. No-op for non-PEW events. Returns count of rows renamed '
  '(0 on no-op, 1 + N children on cascade). Called post-commit by the '
  'orchestrator when Stage 7 set pew_cascade_pending = True.';

REVOKE EXECUTE ON FUNCTION fn_pew_recompute_event_code(INT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_pew_recompute_event_code(INT) TO authenticated, service_role;

COMMIT;
