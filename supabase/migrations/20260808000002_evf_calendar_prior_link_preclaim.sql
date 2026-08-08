-- =============================================================================
-- Pre-claim rolling links before the deployed chronological ingest delegate.
--
-- The first corrective wrapper moved links after the v1 delegate. That is too
-- late for Athens: v1 applies the approved Athens -> Chania link inside its own
-- loop, while the unrelated-number inherited Chania skeleton still owns it.
-- Resolve and release each geographic link before delegation, then assign the
-- saved link to the durable EVF calendar target after delegation.
-- =============================================================================

SET lock_timeout = '5s';


CREATE OR REPLACE FUNCTION fn_ingest_evf_calendar(
  p_events              JSONB,
  p_id_season           INT,
  p_season_event_count  INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_evt JSONB;
  v_target_id INT;
  v_occupant_id INT;
  v_calendar_id BIGINT;
  v_slug TEXT;
  v_desired_code TEXT;
  v_event_name TEXT;
  v_series_key TEXT;
  v_prior_id INT;
  v_match_count INT;
  v_prior_map JSONB := '{}'::JSONB;
  v_result JSONB;
BEGIN
  LOCK TABLE tbl_event IN SHARE ROW EXCLUSIVE MODE;

  -- Resolve every target and geographic prior link from the untouched
  -- current-season skeleton. Store the mapping in function-local JSONB so the
  -- link can be released before v1 performs any in-loop prior assignment.
  FOR v_evt IN SELECT value FROM jsonb_array_elements(p_events)
  LOOP
    v_calendar_id := NULLIF(v_evt ->> 'evf_calendar_id', '')::BIGINT;
    v_slug := NULLIF(v_evt ->> 'evf_slug', '');
    v_desired_code := NULLIF(v_evt ->> 'desired_code', '');
    v_event_name := COALESCE(v_evt ->> 'name', '');
    v_target_id := NULLIF(v_evt ->> 'existing_id_event', '')::INT;

    IF v_target_id IS NULL AND v_calendar_id IS NOT NULL THEN
      SELECT id_event INTO v_target_id FROM tbl_event
       WHERE id_season = p_id_season
         AND id_evf_calendar_event = v_calendar_id;
    END IF;
    IF v_target_id IS NULL AND v_slug IS NOT NULL THEN
      SELECT id_event INTO v_target_id FROM tbl_event
       WHERE id_season = p_id_season
         AND txt_evf_slug = v_slug;
    END IF;

    v_prior_id := NULL;
    IF v_calendar_id = 3438 THEN
      -- Approved series exception: Athens continues the latest Chania event.
      SELECT e.id_event INTO v_prior_id
        FROM tbl_event e
        JOIN tbl_season s ON s.id_season = e.id_season
       WHERE e.id_season <> p_id_season
         AND (e.txt_name ILIKE '%Chania%' OR e.txt_location ILIKE '%Chania%')
       ORDER BY s.dt_end DESC, e.id_event DESC
       LIMIT 1;
      IF v_prior_id IS NULL THEN
        RAISE EXCEPTION 'fn_ingest_evf_calendar: Athens requires a prior Chania event';
      END IF;
    ELSE
      v_series_key := fn_evf_series_key(v_event_name);
      IF v_series_key <> '' THEN
        -- A repeated scrape may already have moved the correct link onto the
        -- durable target. Preserve it without requiring a remaining carrier.
        IF v_target_id IS NOT NULL THEN
          SELECT current_event.id_prior_event INTO v_prior_id
            FROM tbl_event current_event
            JOIN tbl_event prior ON prior.id_event = current_event.id_prior_event
           WHERE current_event.id_event = v_target_id
             AND fn_evf_series_key(prior.txt_name) = v_series_key;
        END IF;

        IF v_prior_id IS NULL THEN
          SELECT COUNT(*)::INT, MAX(carrier.id_prior_event)
            INTO v_match_count, v_prior_id
            FROM tbl_event carrier
            JOIN tbl_event prior ON prior.id_event = carrier.id_prior_event
           WHERE carrier.id_season = p_id_season
             AND carrier.id_event IS DISTINCT FROM v_target_id
             AND carrier.id_evf_calendar_event IS NULL
             AND carrier.dt_start IS NULL
             AND fn_evf_series_key(prior.txt_name) = v_series_key
             AND NOT EXISTS (
               SELECT 1 FROM tbl_tournament t
               JOIN tbl_result r USING (id_tournament)
               WHERE t.id_event = carrier.id_event
             );
          IF v_match_count > 1 THEN
            RAISE EXCEPTION
              'fn_ingest_evf_calendar: ambiguous prior series % for calendar id %',
              v_series_key, v_calendar_id;
          END IF;
        END IF;
      END IF;
    END IF;

    IF v_prior_id IS NOT NULL THEN
      v_prior_map := v_prior_map ||
        jsonb_build_object(v_calendar_id::TEXT, v_prior_id);

      -- Release only safe inherited carriers. A scored or stamped holder is an
      -- error state and remains protected by idx_event_prior_unique.
      UPDATE tbl_event carrier
         SET id_prior_event = NULL
       WHERE carrier.id_season = p_id_season
         AND carrier.id_event IS DISTINCT FROM v_target_id
         AND carrier.id_prior_event = v_prior_id
         AND carrier.id_evf_calendar_event IS NULL
         AND carrier.dt_start IS NULL
         AND NOT EXISTS (
           SELECT 1 FROM tbl_tournament t
           JOIN tbl_result r USING (id_tournament)
           WHERE t.id_event = carrier.id_event
         );
    END IF;

    -- A chronological slot is never evidence of geographic continuity. Clear
    -- a safe unstamped occupant even when the real EVF target is genuinely new;
    -- v1 may reuse that row, but it must not inherit the numeric slot's link.
    IF v_desired_code IS NOT NULL THEN
      SELECT id_event INTO v_occupant_id FROM tbl_event
       WHERE id_season = p_id_season
         AND txt_code = v_desired_code
         AND id_event IS DISTINCT FROM v_target_id
         AND id_evf_calendar_event IS NULL
         AND NOT EXISTS (
           SELECT 1 FROM tbl_tournament t
           JOIN tbl_result r USING (id_tournament)
           WHERE t.id_event = tbl_event.id_event
         );
      IF v_occupant_id IS NOT NULL THEN
        UPDATE tbl_event SET id_prior_event = NULL
         WHERE id_event = v_occupant_id;
      END IF;
    END IF;
  END LOOP;

  v_result := fn_ingest_evf_calendar_identity_v1(
    p_events, p_id_season, p_season_event_count
  );

  -- Durable public-calendar identity resolves the final target after every
  -- quarantine/reuse/renumber operation. Assign exactly the saved geographic
  -- link, or NULL for a genuinely new series.
  FOR v_evt IN SELECT value FROM jsonb_array_elements(p_events)
  LOOP
    v_calendar_id := NULLIF(v_evt ->> 'evf_calendar_id', '')::BIGINT;
    SELECT id_event INTO v_target_id FROM tbl_event
     WHERE id_season = p_id_season
       AND id_evf_calendar_event = v_calendar_id;
    IF v_target_id IS NULL THEN
      RAISE EXCEPTION
        'fn_ingest_evf_calendar: calendar identity % missing after delegate',
        v_calendar_id;
    END IF;

    v_prior_id := NULLIF(v_prior_map ->> v_calendar_id::TEXT, '')::INT;
    UPDATE tbl_event
       SET id_prior_event = v_prior_id
     WHERE id_event = v_target_id
       AND id_season = p_id_season;
  END LOOP;

  RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_ingest_evf_calendar(JSONB, INT, INT)
  FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION fn_ingest_evf_calendar(JSONB, INT, INT)
  TO authenticated;

COMMENT ON FUNCTION fn_ingest_evf_calendar(JSONB, INT, INT) IS
  'Complete EVF calendar snapshot ingest. Geographic prior links are '
  'pre-claimed before chronological renumbering and restored by durable EVF '
  'calendar identity; absent a unique series match, the event is genuinely new.';
