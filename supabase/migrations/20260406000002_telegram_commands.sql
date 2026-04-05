-- =============================================================================
-- Telegram Command DB Functions (ADR-025)
-- =============================================================================
-- fn_rollback_event          — Delete all ingested data, reset event to PLANNED
-- fn_complete_event          — Mark event as COMPLETED
-- fn_event_status            — JSON summary of event state
-- fn_event_results_summary   — Per-tournament results with top 3
-- fn_event_pending           — PENDING match candidates
-- fn_event_missing_categories— Categories without results
-- fn_season_overview         — All events in active season
-- fn_category_ranking        — Top 5 fencers in a category
-- =============================================================================


-- ---------------------------------------------------------------------------
-- Helper: resolve event prefix to id_event in active season
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION _resolve_event_prefix(p_prefix TEXT)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
  v_event_id INT;
  v_active_season INT;
BEGIN
  SELECT id_season INTO v_active_season FROM tbl_season WHERE bool_active = TRUE;
  IF v_active_season IS NULL THEN
    RAISE EXCEPTION 'No active season';
  END IF;

  SELECT id_event INTO v_event_id
  FROM tbl_event
  WHERE id_season = v_active_season
    AND txt_code LIKE p_prefix || '%'
  LIMIT 1;

  IF v_event_id IS NULL THEN
    RAISE EXCEPTION 'No event matching prefix "%" in active season', p_prefix;
  END IF;

  RETURN v_event_id;
END;
$$;


-- ---------------------------------------------------------------------------
-- fn_rollback_event: delete all tournaments+results, reset to PLANNED
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_rollback_event(p_prefix TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_event_id     INT;
  v_tourn_count  INT := 0;
  v_result_count INT := 0;
  v_tid          INT;
BEGIN
  v_event_id := _resolve_event_prefix(p_prefix);

  -- Count before deletion
  SELECT COUNT(*) INTO v_tourn_count
  FROM tbl_tournament WHERE id_event = v_event_id;

  SELECT COUNT(*) INTO v_result_count
  FROM tbl_result r
  JOIN tbl_tournament t ON r.id_tournament = t.id_tournament
  WHERE t.id_event = v_event_id;

  -- Delete all tournaments via cascade function
  FOR v_tid IN SELECT id_tournament FROM tbl_tournament WHERE id_event = v_event_id
  LOOP
    PERFORM fn_delete_tournament_cascade(v_tid);
  END LOOP;

  -- Reset event status to PLANNED
  UPDATE tbl_event
  SET enum_status = 'PLANNED', ts_updated = NOW()
  WHERE id_event = v_event_id;

  RETURN jsonb_build_object(
    'event_id', v_event_id,
    'tournaments_deleted', v_tourn_count,
    'results_deleted', v_result_count,
    'status', 'PLANNED'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_rollback_event(TEXT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_rollback_event(TEXT) TO authenticated;


-- ---------------------------------------------------------------------------
-- fn_complete_event: mark event as COMPLETED
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_complete_event(p_prefix TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_event_id INT;
  v_status   enum_event_status;
BEGIN
  v_event_id := _resolve_event_prefix(p_prefix);

  SELECT enum_status INTO v_status FROM tbl_event WHERE id_event = v_event_id;
  IF v_status != 'IN_PROGRESS' THEN
    RAISE EXCEPTION 'Event must be IN_PROGRESS to complete (current: %)', v_status;
  END IF;

  UPDATE tbl_event
  SET enum_status = 'COMPLETED', ts_updated = NOW()
  WHERE id_event = v_event_id;

  RETURN jsonb_build_object('event_id', v_event_id, 'status', 'COMPLETED');
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_complete_event(TEXT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_complete_event(TEXT) TO authenticated;


-- ---------------------------------------------------------------------------
-- fn_event_status: JSON summary
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_event_status(p_prefix TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_event_id     INT;
  v_code         TEXT;
  v_status       TEXT;
  v_tourn_count  INT;
  v_result_count INT;
  v_pending      INT;
BEGIN
  v_event_id := _resolve_event_prefix(p_prefix);

  SELECT txt_code, enum_status::TEXT INTO v_code, v_status
  FROM tbl_event WHERE id_event = v_event_id;

  SELECT COUNT(*) INTO v_tourn_count
  FROM tbl_tournament WHERE id_event = v_event_id;

  SELECT COUNT(*) INTO v_result_count
  FROM tbl_result r
  JOIN tbl_tournament t ON r.id_tournament = t.id_tournament
  WHERE t.id_event = v_event_id;

  SELECT COUNT(*) INTO v_pending
  FROM tbl_match_candidate mc
  JOIN tbl_result r ON mc.id_result = r.id_result
  JOIN tbl_tournament t ON r.id_tournament = t.id_tournament
  WHERE t.id_event = v_event_id
    AND mc.enum_status = 'PENDING';

  RETURN jsonb_build_object(
    'event_code', v_code,
    'event_status', v_status,
    'tournament_count', v_tourn_count,
    'result_count', v_result_count,
    'pending_count', v_pending
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_event_status(TEXT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_event_status(TEXT) TO authenticated;


-- ---------------------------------------------------------------------------
-- fn_event_results_summary: per-tournament top 3
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_event_results_summary(p_prefix TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_event_id INT;
  v_result   JSONB := '[]'::JSONB;
  v_row      RECORD;
  v_top3     JSONB;
BEGIN
  v_event_id := _resolve_event_prefix(p_prefix);

  FOR v_row IN
    SELECT t.txt_code, t.int_participant_count, t.enum_weapon::TEXT, t.enum_gender::TEXT, t.enum_age_category::TEXT
    FROM tbl_tournament t
    WHERE t.id_event = v_event_id
    ORDER BY t.txt_code
  LOOP
    SELECT jsonb_agg(sub.entry ORDER BY sub.place)
    INTO v_top3
    FROM (
      SELECT r.int_place AS place,
             jsonb_build_object('place', r.int_place, 'name', f.txt_surname || ' ' || f.txt_first_name) AS entry
      FROM tbl_result r
      JOIN tbl_fencer f ON r.id_fencer = f.id_fencer
      WHERE r.id_tournament = (SELECT id_tournament FROM tbl_tournament WHERE txt_code = v_row.txt_code)
        AND r.int_place <= 3
      ORDER BY r.int_place
    ) sub;

    v_result := v_result || jsonb_build_object(
      'tournament', v_row.txt_code,
      'participants', v_row.int_participant_count,
      'weapon', v_row.enum_weapon,
      'gender', v_row.enum_gender,
      'category', v_row.enum_age_category,
      'top3', COALESCE(v_top3, '[]'::JSONB)
    );
  END LOOP;

  RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_event_results_summary(TEXT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_event_results_summary(TEXT) TO authenticated;


-- ---------------------------------------------------------------------------
-- fn_event_pending: PENDING match candidates
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_event_pending(p_prefix TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_event_id INT;
BEGIN
  v_event_id := _resolve_event_prefix(p_prefix);

  RETURN (
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'scraped_name', mc.txt_scraped_name,
      'confidence', mc.num_confidence,
      'tournament', t.txt_code,
      'suggested_fencer', f.txt_surname || ' ' || f.txt_first_name
    )), '[]'::JSONB)
    FROM tbl_match_candidate mc
    JOIN tbl_result r ON mc.id_result = r.id_result
    JOIN tbl_tournament t ON r.id_tournament = t.id_tournament
    LEFT JOIN tbl_fencer f ON mc.id_fencer = f.id_fencer
    WHERE t.id_event = v_event_id
      AND mc.enum_status = 'PENDING'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_event_pending(TEXT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_event_pending(TEXT) TO authenticated;


-- ---------------------------------------------------------------------------
-- fn_event_missing_categories: weapon/gender/category combos without tournaments
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_event_missing_categories(p_prefix TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_event_id   INT;
  v_event_type enum_tournament_type;
BEGIN
  v_event_id := _resolve_event_prefix(p_prefix);

  -- Get the tournament type from existing tournaments (or default PPW)
  SELECT enum_type INTO v_event_type
  FROM tbl_tournament WHERE id_event = v_event_id LIMIT 1;

  IF v_event_type IS NULL THEN
    v_event_type := 'PPW';
  END IF;

  -- Find categories that exist in other events of the same type but not here
  RETURN (
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'weapon', all_combos.enum_weapon,
      'gender', all_combos.enum_gender,
      'category', all_combos.enum_age_category
    )), '[]'::JSONB)
    FROM (
      SELECT DISTINCT t.enum_weapon, t.enum_gender, t.enum_age_category
      FROM tbl_tournament t
      JOIN tbl_event e ON t.id_event = e.id_event
      WHERE e.id_season = (SELECT id_season FROM tbl_event WHERE id_event = v_event_id)
        AND t.enum_type = v_event_type
        AND t.id_event != v_event_id
    ) all_combos
    WHERE NOT EXISTS (
      SELECT 1 FROM tbl_tournament t2
      WHERE t2.id_event = v_event_id
        AND t2.enum_weapon = all_combos.enum_weapon
        AND t2.enum_gender = all_combos.enum_gender
        AND t2.enum_age_category = all_combos.enum_age_category
    )
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_event_missing_categories(TEXT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_event_missing_categories(TEXT) TO authenticated;


-- ---------------------------------------------------------------------------
-- fn_season_overview: all events in active season
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_season_overview()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_active_season INT;
BEGIN
  SELECT id_season INTO v_active_season FROM tbl_season WHERE bool_active = TRUE;
  IF v_active_season IS NULL THEN
    RAISE EXCEPTION 'No active season';
  END IF;

  RETURN (
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'event_code', e.txt_code,
      'event_name', e.txt_name,
      'status', e.enum_status,
      'dt_start', e.dt_start,
      'tournament_count', (SELECT COUNT(*) FROM tbl_tournament t WHERE t.id_event = e.id_event),
      'result_count', (SELECT COUNT(*) FROM tbl_result r JOIN tbl_tournament t ON r.id_tournament = t.id_tournament WHERE t.id_event = e.id_event)
    ) ORDER BY e.dt_start), '[]'::JSONB)
    FROM tbl_event e
    WHERE e.id_season = v_active_season
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_season_overview() FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_season_overview() TO authenticated;


-- ---------------------------------------------------------------------------
-- fn_category_ranking: top 5 in active season for a category
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_category_ranking(
  p_weapon   enum_weapon_type,
  p_gender   enum_gender_type,
  p_category enum_age_category
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_active_season INT;
BEGIN
  SELECT id_season INTO v_active_season FROM tbl_season WHERE bool_active = TRUE;
  IF v_active_season IS NULL THEN
    RAISE EXCEPTION 'No active season';
  END IF;

  RETURN (
    SELECT COALESCE(jsonb_agg(row_data ORDER BY total_score DESC), '[]'::JSONB)
    FROM (
      SELECT jsonb_build_object(
        'fencer', f.txt_surname || ' ' || f.txt_first_name,
        'total_score', ROUND(SUM(r.num_final_score), 2)
      ) AS row_data,
      SUM(r.num_final_score) AS total_score
      FROM tbl_result r
      JOIN tbl_fencer f ON r.id_fencer = f.id_fencer
      JOIN tbl_tournament t ON r.id_tournament = t.id_tournament
      JOIN tbl_event e ON t.id_event = e.id_event
      WHERE e.id_season = v_active_season
        AND t.enum_weapon = p_weapon
        AND t.enum_gender = p_gender
        AND t.enum_age_category = p_category
      GROUP BY f.id_fencer, f.txt_surname, f.txt_first_name
      ORDER BY total_score DESC
      LIMIT 5
    ) ranked
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_category_ranking(enum_weapon_type, enum_gender_type, enum_age_category) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_category_ranking(enum_weapon_type, enum_gender_type, enum_age_category) TO authenticated;
