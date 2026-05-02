-- ===========================================================================
-- Phase 5 — User-confirmed aliases (disambiguates "fresh flush" from "user OK'd it")
-- ===========================================================================
-- The Phase 5 stage-time alias flush writes EVERY pending pair (✓/❓/❌)
-- to `tbl_fencer.json_name_aliases` so the FencerAliasManager UI can
-- surface them. Without an extra signal, the next stage cannot tell:
--   * Was this alias added by a previous run's flush and STILL needs
--     operator review? → block sign-off
--   * Did the operator already click Keep / Transfer / Create on it
--     and explicitly accept it? → trust it, don't re-classify
--
-- This migration introduces `json_user_confirmed_aliases` (JSONB array
-- of strings). The UI's Keep action appends to this list via a new
-- `fn_confirm_fencer_alias` RPC. The Phase 5 verdict & sign-off logic
-- skips rows whose scraped_name is in this list — they're trusted.
-- Transfer / Discard strip the alias from this list too (the alias is
-- being moved or removed; previous confirmation no longer applies).
-- ===========================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Column
-- ---------------------------------------------------------------------------
ALTER TABLE tbl_fencer
  ADD COLUMN IF NOT EXISTS json_user_confirmed_aliases JSONB
    NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN tbl_fencer.json_user_confirmed_aliases IS
  'Phase 5 — array of scraped name strings the operator has explicitly '
  'OK''d via the FencerAliasManager UI (Keep button). Verdict/sign-off '
  'logic skips ❌ classification for entries here. Transfer/Discard RPCs '
  'strip from this list since prior confirmation no longer applies.';


-- ---------------------------------------------------------------------------
-- 2. fn_confirm_fencer_alias — UI Keep action persists here
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_confirm_fencer_alias(
  p_id_fencer INT,
  p_alias     TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_alias    TEXT := btrim(p_alias);
  v_current  JSONB;
  v_lower    TEXT;
  v_already  BOOLEAN;
BEGIN
  IF v_alias IS NULL OR v_alias = '' THEN
    RAISE EXCEPTION 'fn_confirm_fencer_alias: alias is empty';
  END IF;

  SELECT COALESCE(json_user_confirmed_aliases, '[]'::JSONB)
    INTO v_current
    FROM tbl_fencer
   WHERE id_fencer = p_id_fencer;
  IF v_current IS NULL THEN
    RAISE EXCEPTION 'fn_confirm_fencer_alias: fencer % not found', p_id_fencer;
  END IF;

  v_lower := lower(v_alias);
  SELECT EXISTS (
    SELECT 1 FROM jsonb_array_elements_text(v_current) AS x
     WHERE lower(x) = v_lower
  ) INTO v_already;

  IF v_already THEN
    RETURN v_current;
  END IF;

  v_current := v_current || to_jsonb(v_alias);
  UPDATE tbl_fencer
     SET json_user_confirmed_aliases = v_current,
         ts_updated = NOW()
   WHERE id_fencer = p_id_fencer;

  RETURN v_current;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_confirm_fencer_alias(INT, TEXT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_confirm_fencer_alias(INT, TEXT) TO authenticated;

COMMENT ON FUNCTION fn_confirm_fencer_alias(INT, TEXT) IS
  'Phase 5 — append alias to tbl_fencer.json_user_confirmed_aliases. '
  'Idempotent (case-insensitive). Used by the UI Keep button to mark '
  'an alias as operator-OK''d, exempting it from future ❌ surfacing.';


-- ---------------------------------------------------------------------------
-- 3. fn_transfer_fencer_alias / fn_discard_fencer_alias_and_results —
--    strip the alias from the source fencer's json_user_confirmed_aliases
-- ---------------------------------------------------------------------------
-- Replace just the body, keep the same signature. The previous version
-- (migration 20260502000009) already updates tbl_result_draft; this layer
-- adds the user-confirmed-aliases cleanup.

CREATE OR REPLACE FUNCTION fn_transfer_fencer_alias(
  p_from_fencer INT, p_to_fencer INT, p_alias TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_alias                TEXT := trim(p_alias);
  v_from_arr             JSONB;
  v_to_arr               JSONB;
  v_from_conf            JSONB;
  v_from_new             JSONB;
  v_to_new               JSONB;
  v_from_conf_new        JSONB;
  v_results_moved        INT;
  v_draft_results_moved  INT;
  v_tournaments          INT[];
  v_t                    INT;
  v_old_from             JSONB;
  v_old_to               JSONB;
BEGIN
  IF v_alias IS NULL OR v_alias = '' THEN
    RAISE EXCEPTION 'fn_transfer_fencer_alias: alias is empty';
  END IF;
  IF p_from_fencer = p_to_fencer THEN
    RAISE EXCEPTION 'fn_transfer_fencer_alias: from and to identical (id=%)', p_from_fencer;
  END IF;

  SELECT COALESCE(json_name_aliases, '[]'::jsonb),
         COALESCE(json_user_confirmed_aliases, '[]'::jsonb)
    INTO v_from_arr, v_from_conf
    FROM tbl_fencer WHERE id_fencer = p_from_fencer;
  SELECT COALESCE(json_name_aliases, '[]'::jsonb) INTO v_to_arr
    FROM tbl_fencer WHERE id_fencer = p_to_fencer;

  IF v_from_arr IS NULL THEN
    RAISE EXCEPTION 'fn_transfer_fencer_alias: source fencer % not found', p_from_fencer;
  END IF;
  IF v_to_arr IS NULL THEN
    RAISE EXCEPTION 'fn_transfer_fencer_alias: destination fencer % not found', p_to_fencer;
  END IF;
  IF NOT (v_from_arr ? v_alias) THEN
    RAISE EXCEPTION 'fn_transfer_fencer_alias: alias % not on source fencer %', v_alias, p_from_fencer;
  END IF;

  SELECT jsonb_agg(elem) INTO v_from_new
    FROM jsonb_array_elements_text(v_from_arr) AS elem
    WHERE elem != v_alias;
  v_from_new := COALESCE(v_from_new, '[]'::jsonb);

  -- Strip from user_confirmed too — prior confirmation doesn't transfer
  SELECT jsonb_agg(elem) INTO v_from_conf_new
    FROM jsonb_array_elements_text(v_from_conf) AS elem
    WHERE elem != v_alias;
  v_from_conf_new := COALESCE(v_from_conf_new, '[]'::jsonb);

  IF v_to_arr ? v_alias THEN
    v_to_new := v_to_arr;
  ELSE
    v_to_new := v_to_arr || to_jsonb(v_alias);
  END IF;

  v_old_from := jsonb_build_object('json_name_aliases', v_from_arr,
                                    'json_user_confirmed_aliases', v_from_conf);
  v_old_to   := jsonb_build_object('json_name_aliases', v_to_arr);

  UPDATE tbl_fencer
    SET json_name_aliases = v_from_new,
        json_user_confirmed_aliases = v_from_conf_new,
        ts_updated = NOW()
    WHERE id_fencer = p_from_fencer;
  UPDATE tbl_fencer SET json_name_aliases = v_to_new, ts_updated = NOW()
    WHERE id_fencer = p_to_fencer;

  WITH moved AS (
    UPDATE tbl_result
    SET id_fencer = p_to_fencer
    WHERE txt_scraped_name = v_alias
      AND id_fencer = p_from_fencer
    RETURNING id_tournament
  )
  SELECT array_agg(DISTINCT id_tournament), count(*)
    INTO v_tournaments, v_results_moved FROM moved;

  IF v_tournaments IS NOT NULL THEN
    FOREACH v_t IN ARRAY v_tournaments LOOP
      PERFORM fn_calc_tournament_scores(v_t);
    END LOOP;
  END IF;

  WITH moved_drafts AS (
    UPDATE tbl_result_draft
    SET id_fencer = p_to_fencer
    WHERE txt_scraped_name = v_alias
      AND id_fencer = p_from_fencer
    RETURNING id_result_draft
  )
  SELECT count(*) INTO v_draft_results_moved FROM moved_drafts;

  INSERT INTO tbl_audit_log (txt_table_name, id_row, txt_action, jsonb_old_values, jsonb_new_values)
  VALUES
    ('tbl_fencer', p_from_fencer, 'alias_transfer_source', v_old_from,
       jsonb_build_object(
         'json_name_aliases', v_from_new,
         'json_user_confirmed_aliases', v_from_conf_new,
         'alias_moved', v_alias,
         'to_fencer', p_to_fencer,
         'results_moved', COALESCE(v_results_moved, 0),
         'draft_results_moved', COALESCE(v_draft_results_moved, 0)
       )),
    ('tbl_fencer', p_to_fencer, 'alias_transfer_dest', v_old_to,
       jsonb_build_object(
         'json_name_aliases', v_to_new,
         'alias_moved', v_alias,
         'from_fencer', p_from_fencer,
         'results_moved', COALESCE(v_results_moved, 0),
         'draft_results_moved', COALESCE(v_draft_results_moved, 0)
       ));

  RETURN jsonb_build_object(
    'alias',                v_alias,
    'from_fencer',          p_from_fencer,
    'to_fencer',            p_to_fencer,
    'results_moved',        COALESCE(v_results_moved, 0),
    'draft_results_moved',  COALESCE(v_draft_results_moved, 0),
    'tournaments_recomputed', COALESCE(array_length(v_tournaments, 1), 0)
  );
END;
$$;


-- Discard: strip from json_user_confirmed_aliases too
CREATE OR REPLACE FUNCTION fn_discard_fencer_alias_and_results(
  p_from_fencer INT, p_alias TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_alias                  TEXT := trim(p_alias);
  v_from_arr               JSONB;
  v_revoked_arr            JSONB;
  v_conf_arr               JSONB;
  v_from_new               JSONB;
  v_revoked_new            JSONB;
  v_conf_new               JSONB;
  v_results_deleted        INT;
  v_draft_results_deleted  INT;
  v_tournaments            INT[];
  v_t                      INT;
  v_old                    JSONB;
BEGIN
  IF v_alias IS NULL OR v_alias = '' THEN
    RAISE EXCEPTION 'fn_discard_fencer_alias_and_results: alias is empty';
  END IF;

  SELECT COALESCE(json_name_aliases, '[]'::jsonb),
         COALESCE(json_revoked_aliases, '[]'::jsonb),
         COALESCE(json_user_confirmed_aliases, '[]'::jsonb)
    INTO v_from_arr, v_revoked_arr, v_conf_arr
    FROM tbl_fencer WHERE id_fencer = p_from_fencer;

  IF v_from_arr IS NULL THEN
    RAISE EXCEPTION 'fn_discard_fencer_alias_and_results: fencer % not found', p_from_fencer;
  END IF;
  IF NOT (v_from_arr ? v_alias) THEN
    RAISE EXCEPTION 'fn_discard_fencer_alias_and_results: alias % not on fencer %', v_alias, p_from_fencer;
  END IF;

  SELECT jsonb_agg(elem) INTO v_from_new
    FROM jsonb_array_elements_text(v_from_arr) AS elem
    WHERE elem != v_alias;
  v_from_new := COALESCE(v_from_new, '[]'::jsonb);

  IF v_revoked_arr ? v_alias THEN
    v_revoked_new := v_revoked_arr;
  ELSE
    v_revoked_new := v_revoked_arr || to_jsonb(v_alias);
  END IF;

  SELECT jsonb_agg(elem) INTO v_conf_new
    FROM jsonb_array_elements_text(v_conf_arr) AS elem
    WHERE elem != v_alias;
  v_conf_new := COALESCE(v_conf_new, '[]'::jsonb);

  v_old := jsonb_build_object(
    'json_name_aliases', v_from_arr,
    'json_revoked_aliases', v_revoked_arr,
    'json_user_confirmed_aliases', v_conf_arr
  );

  UPDATE tbl_fencer
    SET json_name_aliases = v_from_new,
        json_revoked_aliases = v_revoked_new,
        json_user_confirmed_aliases = v_conf_new,
        ts_updated = NOW()
    WHERE id_fencer = p_from_fencer;

  CREATE TEMP TABLE _discard_affected_results ON COMMIT DROP AS
    SELECT id_result, id_tournament, id_fencer, int_place, txt_scraped_name
    FROM tbl_result
    WHERE txt_scraped_name = v_alias
      AND id_fencer = p_from_fencer;

  SELECT count(*)::INT, array_agg(DISTINCT id_tournament)
    INTO v_results_deleted, v_tournaments
    FROM _discard_affected_results;

  DELETE FROM tbl_result
    WHERE txt_scraped_name = v_alias
      AND id_fencer = p_from_fencer;

  WITH del AS (
    DELETE FROM tbl_result_draft
      WHERE txt_scraped_name = v_alias
        AND id_fencer = p_from_fencer
      RETURNING id_result_draft
  )
  SELECT count(*) INTO v_draft_results_deleted FROM del;

  IF v_tournaments IS NOT NULL THEN
    FOREACH v_t IN ARRAY v_tournaments LOOP
      PERFORM fn_calc_tournament_scores(v_t);
    END LOOP;
  END IF;

  INSERT INTO tbl_audit_log (txt_table_name, id_row, txt_action, jsonb_old_values, jsonb_new_values)
  VALUES (
    'tbl_fencer', p_from_fencer, 'alias_discard', v_old,
    jsonb_build_object(
      'json_name_aliases', v_from_new,
      'json_revoked_aliases', v_revoked_new,
      'json_user_confirmed_aliases', v_conf_new,
      'alias_discarded', v_alias,
      'results_deleted', COALESCE(v_results_deleted, 0),
      'draft_results_deleted', COALESCE(v_draft_results_deleted, 0),
      'tournaments_recomputed', COALESCE(array_length(v_tournaments, 1), 0)
    )
  );

  RETURN jsonb_build_object(
    'alias',                  v_alias,
    'from_fencer',            p_from_fencer,
    'results_deleted',        COALESCE(v_results_deleted, 0),
    'draft_results_deleted',  COALESCE(v_draft_results_deleted, 0),
    'tournaments_recomputed', COALESCE(array_length(v_tournaments, 1), 0),
    'revoked',                TRUE
  );
END;
$$;

COMMIT;
