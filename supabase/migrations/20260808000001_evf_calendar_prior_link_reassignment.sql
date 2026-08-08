-- =============================================================================
-- Correct chronological EVF renumbering when inherited numeric slots carry
-- rolling links that belong to a different geographic event series.
--
-- 20260807000001 is already deployed to CERT and PROD. Do not edit it.
-- =============================================================================

SET lock_timeout = '5s';


CREATE OR REPLACE FUNCTION fn_evf_series_key(p_name TEXT)
RETURNS TEXT
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE
  v_key TEXT := lower(COALESCE(p_name, ''));
  v_dia_src CONSTANT TEXT :=
    'ąćčęłńňóòôõöøőśšźžżäãàáâåăæçďěèéêëîíìïșțťñřůűùúûüýÿß';
  v_dia_tgt CONSTANT TEXT :=
    'accelnnooooooosszzzaaaaaaaacdeeeeeiiiisttnnruuuuuuyys';
BEGIN
  v_key := translate(v_key, v_dia_src, v_dia_tgt);
  v_key := regexp_replace(v_key, '\([^)]*\)', '', 'g');
  v_key := regexp_replace(v_key, 'evf[[:space:]–—-]*circuit', '', 'g');
  v_key := regexp_replace(v_key, 'memoriam[[:space:]]+max[[:space:]]+geuter', '', 'g');
  v_key := replace(v_key, 'naples', 'napoli');
  RETURN regexp_replace(v_key, '[^a-z0-9]', '', 'g');
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_evf_series_key(TEXT) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION fn_evf_series_key(TEXT) TO authenticated;


CREATE OR REPLACE FUNCTION fn_reassign_evf_prior_link(
  p_id_event       INT,
  p_id_season      INT,
  p_calendar_id    BIGINT,
  p_event_name     TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_series_key TEXT;
  v_match_count INT;
  v_prior_id INT;
BEGIN
  v_series_key := fn_evf_series_key(p_event_name);

  IF p_calendar_id = 3438 THEN
    -- Approved series exception: Athens continues Chania.
    SELECT e.id_event INTO v_prior_id
      FROM tbl_event e
      JOIN tbl_season s ON s.id_season = e.id_season
     WHERE e.id_season <> p_id_season
       AND (e.txt_name ILIKE '%Chania%' OR e.txt_location ILIKE '%Chania%')
     ORDER BY s.dt_end DESC, e.id_event DESC
     LIMIT 1;
    IF v_prior_id IS NULL THEN
      RAISE EXCEPTION 'fn_reassign_evf_prior_link: Athens requires a prior Chania event';
    END IF;
  ELSIF v_series_key <> '' THEN
    -- Inherited childless skeletons are link carriers. Their current-season
    -- number is irrelevant; the prior event's normalized series name decides
    -- which real EVF occurrence receives the link.
    SELECT COUNT(*)::INT, MAX(carrier.id_prior_event)
      INTO v_match_count, v_prior_id
      FROM tbl_event carrier
      JOIN tbl_event prior ON prior.id_event = carrier.id_prior_event
     WHERE carrier.id_season = p_id_season
       AND carrier.id_event <> p_id_event
       AND carrier.id_prior_event IS NOT NULL
       AND carrier.id_evf_calendar_event IS NULL
       AND carrier.dt_start IS NULL
       AND fn_evf_series_key(prior.txt_name) = v_series_key;

    IF v_match_count > 1 THEN
      RAISE EXCEPTION
        'fn_reassign_evf_prior_link: ambiguous prior series % for event %',
        v_series_key, p_id_event;
    END IF;
    IF v_match_count = 0 THEN
      RETURN;
    END IF;
  ELSE
    RETURN;
  END IF;

  -- The unique constraint is intentional: move, never copy, a rolling link.
  UPDATE tbl_event
     SET id_prior_event = NULL
   WHERE id_season = p_id_season
     AND id_event <> p_id_event
     AND id_prior_event = v_prior_id;

  UPDATE tbl_event
     SET id_prior_event = v_prior_id
   WHERE id_event = p_id_event
     AND id_season = p_id_season;
END;
$$;

REVOKE ALL ON FUNCTION fn_reassign_evf_prior_link(INT, INT, BIGINT, TEXT)
  FROM anon, authenticated, PUBLIC;


-- Preserve the deployed implementation as an internal delegate. The wrapper
-- performs collision preparation and post-ingest geographic-link assignment.
ALTER FUNCTION fn_ingest_evf_calendar(JSONB, INT, INT)
  RENAME TO fn_ingest_evf_calendar_identity_v1;

REVOKE ALL ON FUNCTION fn_ingest_evf_calendar_identity_v1(JSONB, INT, INT)
  FROM anon, authenticated, PUBLIC;


CREATE FUNCTION fn_ingest_evf_calendar(
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
  v_result JSONB;
BEGIN
  LOCK TABLE tbl_event IN SHARE ROW EXCLUSIVE MODE;

  -- The v1 implementation used the prior link attached to the desired numeric
  -- slot. Chronological numbers no longer encode event series, so detach a
  -- safe empty occupant before v1 quarantines it. Every change is inside this
  -- call's transaction and rolls back if v1 rejects the payload.
  FOR v_evt IN SELECT value FROM jsonb_array_elements(p_events)
  LOOP
    v_calendar_id := NULLIF(v_evt ->> 'evf_calendar_id', '')::BIGINT;
    v_slug := NULLIF(v_evt ->> 'evf_slug', '');
    v_desired_code := NULLIF(v_evt ->> 'desired_code', '');
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

    v_occupant_id := NULL;
    IF v_target_id IS NOT NULL AND v_desired_code IS NOT NULL THEN
      SELECT id_event INTO v_occupant_id FROM tbl_event
       WHERE id_season = p_id_season
         AND txt_code = v_desired_code
         AND id_event <> v_target_id
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

  -- Durable calendar identity now resolves every real target regardless of
  -- renumbering. Move the prior link by normalized series, not by PEW number.
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
    PERFORM fn_reassign_evf_prior_link(
      v_target_id, p_id_season, v_calendar_id, v_evt ->> 'name'
    );
  END LOOP;

  RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_ingest_evf_calendar(JSONB, INT, INT)
  FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION fn_ingest_evf_calendar(JSONB, INT, INT)
  TO authenticated;

COMMENT ON FUNCTION fn_ingest_evf_calendar(JSONB, INT, INT) IS
  'Complete EVF calendar snapshot ingest. Chronological PEW numbers are '
  'independent of rolling links; inherited links move by normalized event '
  'series, with the explicit Athens-to-Chania exception.';
