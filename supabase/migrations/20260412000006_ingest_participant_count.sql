-- =============================================================================
-- Fix: fn_ingest_tournament_results accepts optional p_participant_count
-- =============================================================================
-- For international tournaments (PEW/MEW/MSW), only POL fencers are imported
-- but the tournament has more participants. Without this fix, participant_count
-- is set to the number of imported results (e.g., 14) instead of the total
-- tournament size (e.g., 38), which deflates scoring.
--
-- When p_participant_count is provided, use it. Otherwise fall back to
-- counting input results (correct for domestic tournaments).
-- =============================================================================

-- Drop the existing 2-param function and recreate with 3 params.
-- The DEFAULT NULL on p_participant_count preserves backward compatibility.
DROP FUNCTION IF EXISTS fn_ingest_tournament_results(INT, JSONB);

CREATE FUNCTION fn_ingest_tournament_results(
  p_tournament_id      INT,
  p_results            JSONB,
  p_participant_count  INT DEFAULT NULL
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
  v_event_id    INT;
BEGIN
  -- Validate tournament exists
  IF NOT EXISTS (SELECT 1 FROM tbl_tournament WHERE id_tournament = p_tournament_id) THEN
    RAISE EXCEPTION 'Tournament % does not exist', p_tournament_id;
  END IF;

  -- Validate p_results is a non-empty array
  IF p_results IS NULL OR jsonb_array_length(p_results) = 0 THEN
    RAISE EXCEPTION 'Results array is empty';
  END IF;

  -- Get parent event_id
  SELECT id_event INTO v_event_id
  FROM tbl_tournament WHERE id_tournament = p_tournament_id;

  -- 1. Delete existing match_candidate rows for this tournament's results
  DELETE FROM tbl_match_candidate
  WHERE id_result IN (
    SELECT id_result FROM tbl_result WHERE id_tournament = p_tournament_id
  );

  -- 2. Delete existing results for this tournament
  DELETE FROM tbl_result WHERE id_tournament = p_tournament_id;

  -- 3. Participant count: use provided value, or fall back to input result count
  v_count := COALESCE(p_participant_count, jsonb_array_length(p_results));

  -- 4. Update tournament metadata (before scoring, which needs int_participant_count)
  UPDATE tbl_tournament
  SET int_participant_count = v_count,
      enum_import_status    = 'IMPORTED',
      ts_updated            = NOW()
  WHERE id_tournament = p_tournament_id;

  -- 5. Insert new results and match_candidate entries
  FOR v_row IN SELECT jsonb_array_elements(p_results)
  LOOP
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

    -- Create match candidate (identity audit trail)
    INSERT INTO tbl_match_candidate (
      id_result, id_fencer,
      txt_scraped_name, num_confidence, enum_status
    ) VALUES (
      v_result_id,
      v_fencer_id,
      v_row ->> 'txt_scraped_name',
      COALESCE((v_row ->> 'num_confidence')::NUMERIC, 100),
      COALESCE(v_row ->> 'enum_match_status', 'AUTO_MATCHED')::enum_match_status
    );
  END LOOP;

  -- 6. Run scoring engine for this tournament
  PERFORM fn_calc_tournament_scores(p_tournament_id);

  -- 7. Set event to IN_PROGRESS if still PLANNED
  UPDATE tbl_event
  SET enum_status = 'IN_PROGRESS', ts_updated = NOW()
  WHERE id_event = v_event_id
    AND enum_status = 'PLANNED';

  RETURN jsonb_build_object(
    'tournament_id', p_tournament_id,
    'results_count', jsonb_array_length(p_results),
    'participant_count', v_count,
    'status', 'IMPORTED'
  );
END;
$$;

COMMENT ON FUNCTION fn_ingest_tournament_results(INT, JSONB, INT) IS
  'Atomic ingest: delete old + insert new + match candidates + scoring. '
  'p_participant_count: optional total tournament size (for international tournaments '
  'where only POL fencers are imported). Falls back to counting input results.';

REVOKE EXECUTE ON FUNCTION fn_ingest_tournament_results(INT, JSONB, INT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_ingest_tournament_results(INT, JSONB, INT) TO authenticated;
