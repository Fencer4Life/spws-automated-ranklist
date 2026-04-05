-- =============================================================================
-- Go-to-PROD: fn_ingest_tournament_results (ADR-022)
-- =============================================================================
-- Atomic ingest: delete old results + insert new + create match_candidates
-- + update tournament metadata + run scoring engine — all in one transaction.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_ingest_tournament_results(
  p_tournament_id INT,
  p_results       JSONB   -- [{id_fencer, int_place, txt_scraped_name, num_confidence, enum_match_status}, ...]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count       INT;
  v_row         JSONB;
  v_result_id   INT;
  v_fencer_id   INT;
BEGIN
  -- Validate tournament exists
  IF NOT EXISTS (SELECT 1 FROM tbl_tournament WHERE id_tournament = p_tournament_id) THEN
    RAISE EXCEPTION 'Tournament % does not exist', p_tournament_id;
  END IF;

  -- Validate p_results is a non-empty array
  IF p_results IS NULL OR jsonb_array_length(p_results) = 0 THEN
    RAISE EXCEPTION 'Results array is empty';
  END IF;

  -- 1. Delete existing match_candidate rows for this tournament's results
  DELETE FROM tbl_match_candidate
  WHERE id_result IN (
    SELECT id_result FROM tbl_result WHERE id_tournament = p_tournament_id
  );

  -- 2. Delete existing results for this tournament
  DELETE FROM tbl_result WHERE id_tournament = p_tournament_id;

  -- 3. Count incoming results
  v_count := jsonb_array_length(p_results);

  -- 4. Update tournament metadata (before scoring, which needs int_participant_count)
  UPDATE tbl_tournament
  SET int_participant_count = v_count,
      enum_import_status    = 'IMPORTED',
      ts_updated            = NOW()
  WHERE id_tournament = p_tournament_id;

  -- 5. Insert new results and match_candidate entries
  FOR v_row IN SELECT jsonb_array_elements(p_results)
  LOOP
    -- Validate fencer exists (FK will catch this, but we give a clearer error)
    v_fencer_id := (v_row ->> 'id_fencer')::INT;
    IF NOT EXISTS (SELECT 1 FROM tbl_fencer WHERE id_fencer = v_fencer_id) THEN
      RAISE EXCEPTION 'Fencer % does not exist', v_fencer_id;
    END IF;

    INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
    VALUES (
      v_fencer_id,
      p_tournament_id,
      (v_row ->> 'int_place')::INT
    )
    RETURNING id_result INTO v_result_id;

    INSERT INTO tbl_match_candidate (id_result, txt_scraped_name, id_fencer, num_confidence, enum_status)
    VALUES (
      v_result_id,
      v_row ->> 'txt_scraped_name',
      v_fencer_id,
      (v_row ->> 'num_confidence')::NUMERIC,
      (v_row ->> 'enum_match_status')::enum_match_status
    );
  END LOOP;

  -- 6. Run scoring engine
  PERFORM fn_calc_tournament_scores(p_tournament_id);

  -- 7. Return summary
  RETURN jsonb_build_object(
    'tournament_id', p_tournament_id,
    'inserted',      v_count,
    'scored',        TRUE
  );
END;
$$;

-- ADR-016 pattern: restrict to authenticated role only
REVOKE EXECUTE ON FUNCTION fn_ingest_tournament_results(INT, JSONB) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_ingest_tournament_results(INT, JSONB) TO authenticated;