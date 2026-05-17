-- =============================================================================
-- fn_ingest_tournament_results: preserve enum_match_method NULL from payload
-- =============================================================================
-- Prior behavior collapsed any missing/empty enum_match_status payload field
-- to AUTO_MATCHED, then mapped to enum_match_method = AUTO_MATCH. The new
-- Phase-5 pipeline writes NULL for rows derived from V-cat-marker downgrades
-- (no identity resolution event happened — the result was BY-derived). On
-- cross-env promote (promote.py) those NULL rows were silently re-tagged
-- AUTO_MATCH on PROD, diverging from LOCAL/CERT.
--
-- This change adds an optional `enum_match_method` field to each result
-- payload entry. When the caller sends it, we use it directly (including
-- NULL). Legacy callers that only send `enum_match_status` see no change.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_ingest_tournament_results(
  p_tournament_id integer, p_results jsonb, p_participant_count integer DEFAULT NULL::integer
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_count           INT;
  v_row             JSONB;
  v_result_id       INT;
  v_fencer_id       INT;
  v_event_id        INT;
  v_legacy_status   TEXT;
  v_method_text     TEXT;
  v_method          enum_match_method;
  v_source_vcat     enum_age_category;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM tbl_tournament WHERE id_tournament = p_tournament_id) THEN
    RAISE EXCEPTION 'Tournament % does not exist', p_tournament_id;
  END IF;

  IF p_results IS NULL OR jsonb_array_length(p_results) = 0 THEN
    RAISE EXCEPTION 'Results array is empty';
  END IF;

  SELECT id_event INTO v_event_id
    FROM tbl_tournament WHERE id_tournament = p_tournament_id;

  DELETE FROM tbl_match_candidate
  WHERE id_result IN (
    SELECT id_result FROM tbl_result WHERE id_tournament = p_tournament_id
  );

  DELETE FROM tbl_result WHERE id_tournament = p_tournament_id;

  v_count := COALESCE(p_participant_count, jsonb_array_length(p_results));

  UPDATE tbl_tournament
  SET int_participant_count = v_count,
      enum_import_status    = 'IMPORTED',
      ts_updated            = NOW()
  WHERE id_tournament = p_tournament_id;

  FOR v_row IN SELECT jsonb_array_elements(p_results)
  LOOP
    v_fencer_id := (v_row ->> 'id_fencer')::INT;
    IF NOT EXISTS (SELECT 1 FROM tbl_fencer WHERE id_fencer = v_fencer_id) THEN
      RAISE EXCEPTION 'Fencer % does not exist', v_fencer_id;
    END IF;

    -- NEW: direct enum_match_method from payload (preserves NULL).
    -- When the key is present in the payload object, trust it verbatim —
    -- even if the value is JSON null or empty string (both map to NULL).
    -- When the key is absent, fall back to legacy enum_match_status with
    -- the historical default of AUTO_MATCH.
    IF v_row ? 'enum_match_method' THEN
      v_method_text := v_row ->> 'enum_match_method';
      IF v_method_text IS NULL OR v_method_text = '' THEN
        v_method := NULL;
      ELSE
        v_method := v_method_text::enum_match_method;
      END IF;
    ELSE
      v_legacy_status := COALESCE(v_row ->> 'enum_match_status', 'AUTO_MATCHED');
      v_method := CASE v_legacy_status
        WHEN 'AUTO_MATCHED' THEN 'AUTO_MATCH'::enum_match_method
        WHEN 'APPROVED'     THEN 'USER_CONFIRMED'::enum_match_method
        WHEN 'NEW_FENCER'   THEN 'AUTO_CREATED'::enum_match_method
        ELSE 'AUTO_MATCH'::enum_match_method
      END;
    END IF;

    -- For the legacy tbl_match_candidate row, derive a status from the
    -- (possibly NULL) method. Match-candidate enum has no NULL value, so
    -- a NULL method maps to AUTO_MATCHED (workflow-state best guess) —
    -- this preserves prior behavior for that table since it's slated for
    -- removal in Phase 6.
    v_legacy_status := COALESCE(v_row ->> 'enum_match_status',
      CASE v_method::TEXT
        WHEN 'AUTO_MATCH'      THEN 'AUTO_MATCHED'
        WHEN 'USER_CONFIRMED'  THEN 'APPROVED'
        WHEN 'AUTO_CREATED'    THEN 'NEW_FENCER'
        ELSE 'AUTO_MATCHED'
      END);

    v_source_vcat := CASE
      WHEN v_row ? 'enum_source_age_category' AND NULLIF(v_row ->> 'enum_source_age_category', '') IS NOT NULL
        THEN (v_row ->> 'enum_source_age_category')::enum_age_category
      ELSE NULL
    END;

    INSERT INTO tbl_result (
      id_fencer, id_tournament, int_place,
      txt_scraped_name, num_match_confidence, enum_match_method,
      enum_source_age_category
    )
    VALUES (
      v_fencer_id,
      p_tournament_id,
      (v_row ->> 'int_place')::INT,
      v_row ->> 'txt_scraped_name',
      COALESCE((v_row ->> 'num_confidence')::NUMERIC(5,2), 100),
      v_method,
      v_source_vcat
    )
    RETURNING id_result INTO v_result_id;

    INSERT INTO tbl_match_candidate (
      id_result, id_fencer,
      txt_scraped_name, num_confidence, enum_status
    ) VALUES (
      v_result_id,
      v_fencer_id,
      v_row ->> 'txt_scraped_name',
      COALESCE((v_row ->> 'num_confidence')::NUMERIC, 100),
      v_legacy_status::enum_match_status
    );
  END LOOP;

  PERFORM fn_calc_tournament_scores(p_tournament_id);

  UPDATE tbl_event
  SET enum_status = 'IN_PROGRESS', ts_updated = NOW()
  WHERE id_event = v_event_id
    AND enum_status = 'PLANNED';

  RETURN jsonb_build_object(
    'tournament_id',     p_tournament_id,
    'results_count',     jsonb_array_length(p_results),
    'participant_count', v_count,
    'status',            'IMPORTED'
  );
END;
$function$;
