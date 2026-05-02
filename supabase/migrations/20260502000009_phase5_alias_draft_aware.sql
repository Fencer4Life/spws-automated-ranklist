-- ===========================================================================
-- Phase 5 — Alias UI extended to draft-stage results
-- ===========================================================================
-- Phase 4 alias UI (fn_transfer / fn_split / fn_discard) operated on
-- `tbl_result` only. Phase 5 staging produces `tbl_result_draft` rows that
-- are NOT yet committed; when the operator fixes a wrong-match alias via
-- the FencerAliasManager UI, the corresponding DRAFT result rows must
-- follow the alias to the new fencer (or be deleted on discard) — otherwise
-- sign-off later commits a draft row that's still misattributed.
--
-- This migration replaces the 3 RPC bodies with draft-aware versions that
-- update both `tbl_result` AND `tbl_result_draft`. Same return-shape; the
-- existing UI keeps working without code changes. Audit logs gain a
-- `draft_results_moved` / `draft_results_deleted` field for traceability.
-- ===========================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. fn_transfer_fencer_alias — atomic move + reassign (drafts included)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_transfer_fencer_alias(
  p_from_fencer INT,
  p_to_fencer   INT,
  p_alias       TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_alias                TEXT := trim(p_alias);
  v_from_arr             JSONB;
  v_to_arr               JSONB;
  v_from_new             JSONB;
  v_to_new               JSONB;
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
    RAISE EXCEPTION 'fn_transfer_fencer_alias: from and to fencer are identical (id=%)', p_from_fencer;
  END IF;

  SELECT COALESCE(json_name_aliases, '[]'::jsonb) INTO v_from_arr
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

  -- Build new arrays: remove from source, append to destination (no-op if already there)
  SELECT jsonb_agg(elem) INTO v_from_new
    FROM jsonb_array_elements_text(v_from_arr) AS elem
    WHERE elem != v_alias;
  v_from_new := COALESCE(v_from_new, '[]'::jsonb);

  IF v_to_arr ? v_alias THEN
    v_to_new := v_to_arr;
  ELSE
    v_to_new := v_to_arr || to_jsonb(v_alias);
  END IF;

  v_old_from := jsonb_build_object('json_name_aliases', v_from_arr);
  v_old_to   := jsonb_build_object('json_name_aliases', v_to_arr);

  -- Source first (removes alias) — uniqueness trigger then permits dest add
  UPDATE tbl_fencer SET json_name_aliases = v_from_new, ts_updated = NOW()
    WHERE id_fencer = p_from_fencer;
  UPDATE tbl_fencer SET json_name_aliases = v_to_new, ts_updated = NOW()
    WHERE id_fencer = p_to_fencer;

  -- Reassign committed tbl_result rows + recompute scoring
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

  -- Phase 5 — also reassign DRAFT rows that haven't been committed yet.
  -- No tournament-recompute needed (drafts are pre-commit; scoring runs
  -- on commit). Captured in the audit log so the operator can trace.
  WITH moved_drafts AS (
    UPDATE tbl_result_draft
    SET id_fencer = p_to_fencer
    WHERE txt_scraped_name = v_alias
      AND id_fencer = p_from_fencer
    RETURNING id_result_draft
  )
  SELECT count(*) INTO v_draft_results_moved FROM moved_drafts;

  -- Audit log entries — includes the draft-results delta
  INSERT INTO tbl_audit_log (txt_table_name, id_row, txt_action, jsonb_old_values, jsonb_new_values)
  VALUES
    ('tbl_fencer', p_from_fencer, 'alias_transfer_source', v_old_from,
       jsonb_build_object(
         'json_name_aliases', v_from_new,
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


-- ---------------------------------------------------------------------------
-- 2. fn_discard_fencer_alias_and_results — tombstone + delete (drafts too)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_discard_fencer_alias_and_results(
  p_from_fencer INT,
  p_alias       TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_alias                  TEXT := trim(p_alias);
  v_from_arr               JSONB;
  v_revoked_arr            JSONB;
  v_from_new               JSONB;
  v_revoked_new            JSONB;
  v_results_deleted        INT;
  v_draft_results_deleted  INT;
  v_tournaments            INT[];
  v_t                      INT;
  v_old                    JSONB;
BEGIN
  IF v_alias IS NULL OR v_alias = '' THEN
    RAISE EXCEPTION 'fn_discard_fencer_alias_and_results: alias is empty';
  END IF;

  SELECT COALESCE(json_name_aliases, '[]'::jsonb), COALESCE(json_revoked_aliases, '[]'::jsonb)
    INTO v_from_arr, v_revoked_arr
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

  v_old := jsonb_build_object(
    'json_name_aliases', v_from_arr,
    'json_revoked_aliases', v_revoked_arr
  );

  UPDATE tbl_fencer
    SET json_name_aliases = v_from_new,
        json_revoked_aliases = v_revoked_new,
        ts_updated = NOW()
    WHERE id_fencer = p_from_fencer;

  -- Snapshot committed-affected results for tournament discovery + audit
  CREATE TEMP TABLE _discard_affected_results ON COMMIT DROP AS
    SELECT id_result, id_tournament, id_fencer, int_place, txt_scraped_name
    FROM tbl_result
    WHERE txt_scraped_name = v_alias
      AND id_fencer = p_from_fencer;

  SELECT count(*)::INT, array_agg(DISTINCT id_tournament)
    INTO v_results_deleted, v_tournaments
    FROM _discard_affected_results;

  -- Hard-delete committed results
  DELETE FROM tbl_result
    WHERE txt_scraped_name = v_alias
      AND id_fencer = p_from_fencer;

  -- Phase 5 — also hard-delete DRAFT rows for the same (alias, fencer) pair.
  -- These are pre-sign-off; deleting them prevents the bad attribution from
  -- ever being committed.
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
