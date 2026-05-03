-- =============================================================================
-- Phase 5.5 — alias RPCs return id_tournaments[] + tournament_labels[]
-- =============================================================================
-- Extends fn_transfer_fencer_alias and fn_discard_fencer_alias_and_results
-- (and transitively fn_split_fencer_from_alias) to return:
--   * id_tournaments     INT[]   — ordered ascending by id
--   * tournament_labels  TEXT[]  — "<event_code> / <vcat> / <weapon> / <gender>"
--
-- Surfaces the cross-event cascade to the operator (UI banner shows which
-- prior events' scores were also recomputed).
--
-- Plan-test-ID 5.11. ADR amendment of ADR-050.
-- Migration is purely additive at the JSON level — existing 'tournaments_recomputed'
-- key kept for back-compat.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. fn_transfer_fencer_alias — extend return JSONB
-- ---------------------------------------------------------------------------
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
  v_tournament_labels    TEXT[];
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
  SELECT array_agg(DISTINCT id_tournament ORDER BY id_tournament), count(*)
    INTO v_tournaments, v_results_moved FROM moved;

  -- Build tournament_labels: <event_code> / <vcat> / <weapon> / <gender>
  IF v_tournaments IS NOT NULL THEN
    SELECT array_agg(
             COALESCE(e.txt_code, 'unknown')
             || ' / ' || COALESCE(t.enum_age_category::text, '?')
             || ' / ' || COALESCE(t.enum_weapon::text, '?')
             || ' / ' || COALESCE(t.enum_gender::text, '?')
             ORDER BY t.id_tournament
           )
      INTO v_tournament_labels
      FROM unnest(v_tournaments) AS u(id_t)
      JOIN tbl_tournament t ON t.id_tournament = u.id_t
      LEFT JOIN tbl_event e ON e.id_event = t.id_event;

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
         'draft_results_moved', COALESCE(v_draft_results_moved, 0),
         'id_tournaments', COALESCE(to_jsonb(v_tournaments), '[]'::jsonb),
         'tournament_labels', COALESCE(to_jsonb(v_tournament_labels), '[]'::jsonb)
       )),
    ('tbl_fencer', p_to_fencer, 'alias_transfer_dest', v_old_to,
       jsonb_build_object(
         'json_name_aliases', v_to_new,
         'alias_moved', v_alias,
         'from_fencer', p_from_fencer,
         'results_moved', COALESCE(v_results_moved, 0),
         'draft_results_moved', COALESCE(v_draft_results_moved, 0),
         'id_tournaments', COALESCE(to_jsonb(v_tournaments), '[]'::jsonb),
         'tournament_labels', COALESCE(to_jsonb(v_tournament_labels), '[]'::jsonb)
       ));

  RETURN jsonb_build_object(
    'alias',                 v_alias,
    'from_fencer',           p_from_fencer,
    'to_fencer',             p_to_fencer,
    'results_moved',         COALESCE(v_results_moved, 0),
    'draft_results_moved',   COALESCE(v_draft_results_moved, 0),
    'tournaments_recomputed', COALESCE(array_length(v_tournaments, 1), 0),
    'id_tournaments',        COALESCE(to_jsonb(v_tournaments), '[]'::jsonb),
    'tournament_labels',     COALESCE(to_jsonb(v_tournament_labels), '[]'::jsonb)
  );
END;
$$;

COMMENT ON FUNCTION fn_transfer_fencer_alias(INT, INT, TEXT) IS
  'Phase 5.5 — extended return shape with id_tournaments[] + tournament_labels[]. '
  'Cross-event cascade is now visible to the UI. Plan-test-ID 5.11.';


-- ---------------------------------------------------------------------------
-- 2. fn_discard_fencer_alias_and_results — same return-shape extension
-- ---------------------------------------------------------------------------
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
  v_tournament_labels      TEXT[];
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

  -- Snapshot affected tournaments BEFORE delete
  CREATE TEMP TABLE _discard_affected_results ON COMMIT DROP AS
    SELECT id_result, id_tournament, id_fencer, int_place, txt_scraped_name
    FROM tbl_result
    WHERE txt_scraped_name = v_alias
      AND id_fencer = p_from_fencer;

  SELECT count(*)::INT, array_agg(DISTINCT id_tournament ORDER BY id_tournament)
    INTO v_results_deleted, v_tournaments
    FROM _discard_affected_results;

  -- Build tournament_labels BEFORE delete (still in tbl_tournament)
  IF v_tournaments IS NOT NULL THEN
    SELECT array_agg(
             COALESCE(e.txt_code, 'unknown')
             || ' / ' || COALESCE(t.enum_age_category::text, '?')
             || ' / ' || COALESCE(t.enum_weapon::text, '?')
             || ' / ' || COALESCE(t.enum_gender::text, '?')
             ORDER BY t.id_tournament
           )
      INTO v_tournament_labels
      FROM unnest(v_tournaments) AS u(id_t)
      JOIN tbl_tournament t ON t.id_tournament = u.id_t
      LEFT JOIN tbl_event e ON e.id_event = t.id_event;
  END IF;

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
      'id_tournaments', COALESCE(to_jsonb(v_tournaments), '[]'::jsonb),
      'tournament_labels', COALESCE(to_jsonb(v_tournament_labels), '[]'::jsonb)
    )
  );

  RETURN jsonb_build_object(
    'alias',                  v_alias,
    'from_fencer',            p_from_fencer,
    'results_deleted',        COALESCE(v_results_deleted, 0),
    'draft_results_deleted',  COALESCE(v_draft_results_deleted, 0),
    'tournaments_recomputed', COALESCE(array_length(v_tournaments, 1), 0),
    'id_tournaments',         COALESCE(to_jsonb(v_tournaments), '[]'::jsonb),
    'tournament_labels',      COALESCE(to_jsonb(v_tournament_labels), '[]'::jsonb),
    'revoked',                TRUE
  );
END;
$$;

COMMENT ON FUNCTION fn_discard_fencer_alias_and_results(INT, TEXT) IS
  'Phase 5.5 — extended return shape with id_tournaments[] + tournament_labels[]. '
  'Cross-event cascade visible. Plan-test-ID 5.11.';

-- fn_split_fencer_from_alias is unchanged — it calls fn_transfer_fencer_alias
-- internally and packages the JSONB under transfer_result, so the new keys
-- propagate automatically.

COMMIT;
