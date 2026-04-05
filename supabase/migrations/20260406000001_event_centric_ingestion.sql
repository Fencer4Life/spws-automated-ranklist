-- =============================================================================
-- Event-Centric Ingestion Functions (ADR-025)
-- =============================================================================
-- fn_find_event_by_date     — Find event in active season by date
-- fn_find_or_create_tournament — Idempotent tournament creation under event
-- Updated fn_ingest_tournament_results — Sets event to IN_PROGRESS
-- Updated fn_validate_event_transition — Allow PLANNED → IN_PROGRESS
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Allow PLANNED → IN_PROGRESS transition (ingestion auto-triggers this)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validate_event_transition()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_valid BOOLEAN := FALSE;
BEGIN
    v_valid := CASE
        -- From PLANNED
        WHEN OLD.enum_status = 'PLANNED'      AND NEW.enum_status = 'SCHEDULED'   THEN TRUE
        WHEN OLD.enum_status = 'PLANNED'      AND NEW.enum_status = 'IN_PROGRESS' THEN TRUE  -- ADR-025: ingestion
        WHEN OLD.enum_status = 'PLANNED'      AND NEW.enum_status = 'CANCELLED'   THEN TRUE
        -- From SCHEDULED
        WHEN OLD.enum_status = 'SCHEDULED'    AND NEW.enum_status = 'CHANGED'     THEN TRUE
        WHEN OLD.enum_status = 'SCHEDULED'    AND NEW.enum_status = 'IN_PROGRESS' THEN TRUE
        WHEN OLD.enum_status = 'SCHEDULED'    AND NEW.enum_status = 'CANCELLED'   THEN TRUE
        -- From CHANGED
        WHEN OLD.enum_status = 'CHANGED'      AND NEW.enum_status = 'SCHEDULED'   THEN TRUE
        WHEN OLD.enum_status = 'CHANGED'      AND NEW.enum_status = 'IN_PROGRESS' THEN TRUE
        WHEN OLD.enum_status = 'CHANGED'      AND NEW.enum_status = 'CANCELLED'   THEN TRUE
        -- From IN_PROGRESS
        WHEN OLD.enum_status = 'IN_PROGRESS'  AND NEW.enum_status = 'COMPLETED'   THEN TRUE
        WHEN OLD.enum_status = 'IN_PROGRESS'  AND NEW.enum_status = 'PLANNED'     THEN TRUE  -- ADR-025: rollback
        WHEN OLD.enum_status = 'IN_PROGRESS'  AND NEW.enum_status = 'CANCELLED'   THEN TRUE
        -- From COMPLETED
        WHEN OLD.enum_status = 'COMPLETED'    AND NEW.enum_status = 'IN_PROGRESS' THEN TRUE  -- ADR-025: rollback from completed
        WHEN OLD.enum_status = 'COMPLETED'    AND NEW.enum_status = 'PLANNED'     THEN TRUE  -- ADR-025: full rollback from completed
        ELSE FALSE
    END;

    IF NOT v_valid THEN
        RAISE EXCEPTION 'Invalid event status transition: % → %',
            OLD.enum_status, NEW.enum_status;
    END IF;

    RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- fn_find_event_by_date: Returns event row for a given date in active season
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_find_event_by_date(p_date DATE)
RETURNS TABLE (
  id_event       INT,
  txt_code       TEXT,
  txt_name       TEXT,
  id_season      INT,
  enum_status    enum_event_status
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_active_season INT;
BEGIN
  -- Get active season
  SELECT s.id_season INTO v_active_season
  FROM tbl_season s WHERE s.bool_active = TRUE;

  IF v_active_season IS NULL THEN
    RAISE EXCEPTION 'No active season found';
  END IF;

  RETURN QUERY
    SELECT e.id_event, e.txt_code, e.txt_name, e.id_season, e.enum_status
    FROM tbl_event e
    WHERE e.id_season = v_active_season
      AND e.dt_start = p_date
    LIMIT 1;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_find_event_by_date(DATE) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_find_event_by_date(DATE) TO authenticated;


-- ---------------------------------------------------------------------------
-- fn_find_or_create_tournament: Idempotent — finds or creates tournament
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_find_or_create_tournament(
  p_event_id      INT,
  p_weapon        enum_weapon_type,
  p_gender        enum_gender_type,
  p_age_category  enum_age_category,
  p_date          DATE,
  p_type          enum_tournament_type
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tourn_id   INT;
  v_event_code TEXT;
  v_season_code TEXT;
  v_tourn_code TEXT;
BEGIN
  -- Check if tournament already exists under this event
  SELECT t.id_tournament INTO v_tourn_id
  FROM tbl_tournament t
  WHERE t.id_event = p_event_id
    AND t.enum_weapon = p_weapon
    AND t.enum_gender = p_gender
    AND t.enum_age_category = p_age_category;

  IF v_tourn_id IS NOT NULL THEN
    RETURN v_tourn_id;
  END IF;

  -- Get event code and season code for auto-generating tournament code
  SELECT e.txt_code, s.txt_code
    INTO v_event_code, v_season_code
  FROM tbl_event e
  JOIN tbl_season s ON s.id_season = e.id_season
  WHERE e.id_event = p_event_id;

  IF v_event_code IS NULL THEN
    RAISE EXCEPTION 'Event % does not exist', p_event_id;
  END IF;

  -- Build tournament code: strip season suffix from event code if present,
  -- then append category-gender-weapon-season
  -- e.g. "PPW4.5-2025-2026" → base "PPW4.5" → "PPW4.5-V2-M-EPEE-2025-2026"
  v_event_code := regexp_replace(v_event_code, '-\d{4}-\d{4}$', '');
  v_tourn_code := v_event_code || '-' || p_age_category || '-' || p_gender || '-' || p_weapon || '-' || v_season_code;
  -- Strip the leading "SPWS-" from season code if present
  v_tourn_code := regexp_replace(v_tourn_code, '-SPWS-(\d{4}-\d{4})$', '-\1');

  -- Create the tournament
  INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, enum_import_status
  ) VALUES (
    p_event_id, v_tourn_code,
    p_age_category || ' ' || p_gender || ' ' || p_weapon,
    p_type, p_weapon, p_gender, p_age_category,
    p_date, 0, 'PLANNED'
  )
  RETURNING id_tournament INTO v_tourn_id;

  RETURN v_tourn_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_find_or_create_tournament(INT, enum_weapon_type, enum_gender_type, enum_age_category, DATE, enum_tournament_type) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_find_or_create_tournament(INT, enum_weapon_type, enum_gender_type, enum_age_category, DATE, enum_tournament_type) TO authenticated;


-- ---------------------------------------------------------------------------
-- Update fn_ingest_tournament_results: also set event to IN_PROGRESS
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_ingest_tournament_results(
  p_tournament_id INT,
  p_results       JSONB
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

  -- 7. Set event to IN_PROGRESS if currently PLANNED
  UPDATE tbl_event
  SET enum_status = 'IN_PROGRESS',
      ts_updated  = NOW()
  WHERE id_event = v_event_id
    AND enum_status = 'PLANNED';

  -- 8. Return summary
  RETURN jsonb_build_object(
    'tournament_id', p_tournament_id,
    'event_id',      v_event_id,
    'inserted',      v_count,
    'scored',        TRUE
  );
END;
$$;
