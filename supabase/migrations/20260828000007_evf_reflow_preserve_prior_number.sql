-- =============================================================================
-- Reflow staging must not erase an event's prior PEW number
-- =============================================================================
-- ADR-086 / ADR-043. Regression introduced by 20260828000006 and caught live in
-- run 33190231601:
--
--   fn_ingest_evf_calendar: code plan mismatch for 3444:
--     got PEW12ef-2026-2027, expected PEW0ef-2026-2027
--
-- 3444 is Stockholm, cancelled by EVF in the same scrape that inserts Tampere.
-- The cancellation rules read an event's prior PEW number out of its own
-- txt_code: a positive prior number means "cancelled later, keep the number",
-- while no prior number means "already cancelled at first import, belongs at
-- PEW0". The staging pre-pass parks txt_code as '__evfcal_evt_<id>', which the
-- '^PEW\d+[efs]*-' regex does not match -- so a later cancellation whose code
-- had been parked silently reclassified as a first-import one.
--
-- Fix: snapshot every event code in the season BEFORE the pre-pass parks
-- anything, and derive the prior number from that snapshot. The later
-- rename decision still reads the LIVE code, because that is what must differ
-- from the desired code for the rename to happen.
--
-- Reproduced from the LIVE pg_get_functiondef output, so 20260828000005/6 and
-- the prior-link amendments in 20260808000001/2 are carried forward.
--
-- Plan-test-ID 62 (supabase/tests/62_evf_reflow_occupied_code.sql, 62.5).
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_ingest_evf_calendar_identity_v1(p_events jsonb, p_id_season integer, p_season_event_count integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_evt          JSONB;
  v_alloc        RECORD;
  v_org          INT;
  v_existing_id  INT;
  v_calendar_id  BIGINT;
  v_slug         TEXT;
  v_kind         TEXT;
  v_result       JSONB;
  v_delegate     JSONB := '[]'::JSONB;
  v_existing_status TEXT;
  v_desired_code TEXT;
  v_expected_code TEXT;
  v_season_suffix TEXT;
  v_weapons_arr enum_weapon_type[];
  v_letters TEXT;
  v_w TEXT;
  v_positive_n INT := 0;
  v_prior_n INT;
  v_cancelled BOOLEAN;
  v_occupant_id INT;
  v_reflow_ids INT[];
  v_orig_codes JSONB;
  v_old_code TEXT;
BEGIN
  IF p_season_event_count < 0
     OR jsonb_typeof(p_events) <> 'array'
     OR jsonb_array_length(p_events) <> p_season_event_count THEN
    RAISE EXCEPTION 'fn_ingest_evf_calendar: retained count must equal payload length';
  END IF;

  LOCK TABLE tbl_event IN SHARE ROW EXCLUSIVE MODE;
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'EVF';
  IF v_org IS NULL THEN
    RAISE EXCEPTION 'fn_ingest_evf_calendar: EVF organizer not found';
  END IF;

  SELECT regexp_replace(txt_code, '^SPWS-', '') INTO v_season_suffix
    FROM tbl_season WHERE id_season = p_id_season;
  IF v_season_suffix IS NULL THEN
    RAISE EXCEPTION 'fn_ingest_evf_calendar: unknown season %', p_id_season;
  END IF;

  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_events) e
     WHERE COALESCE(e ->> 'name', '') ~* '\mCAMP\M'
  ) THEN
    RAISE EXCEPTION 'fn_ingest_evf_calendar: CAMP entries are forbidden';
  END IF;

  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_events) e
     WHERE NULLIF(e ->> 'evf_calendar_id', '') IS NULL
  ) OR (
    SELECT COUNT(DISTINCT (e ->> 'evf_calendar_id')::BIGINT)
      FROM jsonb_array_elements(p_events) e
  ) <> p_season_event_count THEN
    RAISE EXCEPTION 'fn_ingest_evf_calendar: calendar ids must be present and unique';
  END IF;
  IF (
    SELECT COUNT(DISTINCT e ->> 'desired_code')
      FROM jsonb_array_elements(p_events) e
  ) <> p_season_event_count THEN
    RAISE EXCEPTION 'fn_ingest_evf_calendar: desired codes must be present and unique';
  END IF;

  -- Snapshot the codes as they stand BEFORE any staging. The cancellation
  -- rules read an event's prior PEW number out of its own txt_code, so parking
  -- that code would erase the very signal they depend on: a later cancellation
  -- whose code is parked reads as prior_n NULL, which means "cancelled at first
  -- import" and belongs at PEW0. That regression aborted run 33190231601 with
  --   code plan mismatch for 3444: got PEW12ef-2026-2027, expected PEW0ef-2026-2027
  SELECT COALESCE(jsonb_object_agg(id_event::TEXT, txt_code), '{}'::JSONB)
    INTO v_orig_codes
    FROM tbl_event
   WHERE id_season = p_id_season;

  -- ===== reflow staging pre-pass (ADR-086) =====
  -- Codes are chronological position, so one mid-season insertion shifts the
  -- whole tail. The assignment loop walks in date order, so every shifted event
  -- momentarily wants a code its successor has not vacated yet -- and a brand
  -- new event wants one held by the event it displaces. Both surface as a
  -- collision: 'unsafe occupied code' on the rename path, and a raw
  -- idx_event_code violation on the insert path.
  --
  -- Park every calendar-owned event whose code this payload changes on a
  -- neutral placeholder first, exactly as this function already does per-event
  -- for tournament codes, so the loop only ever assigns into free codes.
  -- Scored events are excluded: they must keep their code and still trip the
  -- 'refusing to renumber scored event' guard below rather than being parked.
  SELECT array_agg(e.id_event)
    INTO v_reflow_ids
    FROM tbl_event e
    JOIN jsonb_array_elements(p_events) je
      ON e.id_evf_calendar_event = NULLIF(je ->> 'evf_calendar_id', '')::BIGINT
   WHERE e.id_season = p_id_season
     AND e.txt_code IS DISTINCT FROM (je ->> 'desired_code')
     AND NOT EXISTS (
           SELECT 1 FROM tbl_tournament t JOIN tbl_result r USING (id_tournament)
            WHERE t.id_event = e.id_event);

  IF v_reflow_ids IS NOT NULL THEN
    UPDATE tbl_tournament SET txt_code = '__evfcal_' || id_tournament::TEXT
     WHERE id_event = ANY(v_reflow_ids);
    UPDATE tbl_event SET txt_code = '__evfcal_evt_' || id_event::TEXT
     WHERE id_event = ANY(v_reflow_ids);
  END IF;

  FOR v_evt IN
    SELECT value FROM jsonb_array_elements(p_events)
    ORDER BY value ->> 'dt_start', (value ->> 'evf_calendar_id')::BIGINT
  LOOP
    v_calendar_id := NULLIF(v_evt ->> 'evf_calendar_id', '')::BIGINT;
    IF v_calendar_id IS NULL THEN
      RAISE EXCEPTION 'fn_ingest_evf_calendar: evf_calendar_id is required for %',
        COALESCE(v_evt ->> 'name', '<unnamed>');
    END IF;
    v_slug := NULLIF(v_evt ->> 'evf_slug', '');
    v_existing_id := NULLIF(v_evt ->> 'existing_id_event', '')::INT;
    v_existing_status := NULL;

    IF v_existing_id IS NOT NULL THEN
      SELECT e.enum_status::TEXT INTO v_existing_status
        FROM tbl_event e
       WHERE e.id_event = v_existing_id AND e.id_season = p_id_season
         AND (e.id_evf_calendar_event IS NULL OR e.id_evf_calendar_event = v_calendar_id);
      IF NOT FOUND THEN
        RAISE EXCEPTION 'fn_ingest_evf_calendar: invalid legacy match % for calendar id %',
          v_existing_id, v_calendar_id;
      END IF;
    ELSE
      SELECT e.id_event, e.enum_status::TEXT INTO v_existing_id, v_existing_status
        FROM tbl_event e
       WHERE e.id_season = p_id_season
         AND e.id_evf_calendar_event = v_calendar_id;
    END IF;

    IF v_existing_id IS NULL AND v_slug IS NOT NULL THEN
      SELECT e.id_event, e.enum_status::TEXT INTO v_existing_id, v_existing_status
        FROM tbl_event e
       WHERE e.id_season = p_id_season
         AND e.txt_evf_slug = v_slug;
    END IF;

    v_weapons_arr := ARRAY[]::enum_weapon_type[];
    FOR v_w IN SELECT jsonb_array_elements_text(COALESCE(v_evt -> 'weapons', '[]'::JSONB))
    LOOP
      v_weapons_arr := v_weapons_arr || v_w::enum_weapon_type;
    END LOOP;
    v_letters := fn_pew_weapon_letters(v_weapons_arr);
    IF v_letters = '' THEN
      RAISE EXCEPTION 'fn_ingest_evf_calendar: weapons are required for calendar id %',
        v_calendar_id;
    END IF;

    v_cancelled := COALESCE((v_evt ->> 'is_cancelled')::BOOLEAN, FALSE);
    v_prior_n := NULL;
    IF v_existing_id IS NOT NULL THEN
      -- Pre-staging code: parking must not turn a later cancellation into a
      -- first-import one. Falls back to the live code for a row that existed
      -- before this transaction's snapshot (there is none in practice).
      v_old_code := COALESCE(
        v_orig_codes ->> v_existing_id::TEXT,
        (SELECT txt_code FROM tbl_event WHERE id_event = v_existing_id));
      IF v_old_code ~ '^PEW\d+[efs]*-' THEN
        v_prior_n := ((regexp_match(v_old_code, '^PEW(\d+)'))[1])::INT;
      END IF;
    END IF;

    IF v_cancelled AND (
      COALESCE(v_prior_n, 0) = 0 OR v_calendar_id = 5074
    ) THEN
      v_expected_code := 'PEW0' || v_letters || '-' || v_season_suffix;
    ELSE
      v_positive_n := v_positive_n + 1;
      IF v_cancelled AND v_prior_n IS DISTINCT FROM v_positive_n
         AND NOT fn_evf_event_code_is_movable(v_existing_id) THEN
        RAISE EXCEPTION
          'fn_ingest_evf_calendar: later cancellation % cannot move PEW% to PEW% '
          '(it is past, has registrations, or holds results)',
          v_calendar_id, v_prior_n, v_positive_n;
      END IF;
      v_expected_code := 'PEW' || v_positive_n::TEXT || v_letters || '-' || v_season_suffix;
    END IF;
    v_desired_code := NULLIF(v_evt ->> 'desired_code', '');
    IF v_desired_code IS DISTINCT FROM v_expected_code THEN
      RAISE EXCEPTION
        'fn_ingest_evf_calendar: code plan mismatch for %: got %, expected %',
        v_calendar_id, v_desired_code, v_expected_code;
    END IF;

    -- An inherited empty skeleton already occupying the desired chronological
    -- code is the canonical row. Attach the durable identity to it instead of
    -- creating another occurrence.
    IF v_existing_id IS NULL THEN
      SELECT e.id_event, e.enum_status::TEXT INTO v_occupant_id, v_existing_status
        FROM tbl_event e
       WHERE e.id_season = p_id_season AND e.txt_code = v_desired_code
         AND e.id_evf_calendar_event IS NULL;
      IF v_occupant_id IS NOT NULL THEN
        v_existing_id := v_occupant_id;
      END IF;
    END IF;

    IF v_existing_id IS NOT NULL THEN
      SELECT id_event INTO v_occupant_id FROM tbl_event
       WHERE id_season = p_id_season AND txt_code = v_desired_code
         AND id_event <> v_existing_id;
      IF v_occupant_id IS NOT NULL THEN
        IF EXISTS (
          SELECT 1 FROM tbl_tournament t JOIN tbl_result r USING (id_tournament)
           WHERE t.id_event IN (v_existing_id, v_occupant_id)
        ) OR EXISTS (
          SELECT 1 FROM tbl_event WHERE id_event = v_occupant_id
            AND id_evf_calendar_event IS NOT NULL
        ) THEN
          RAISE EXCEPTION 'fn_ingest_evf_calendar: unsafe occupied code %', v_desired_code;
        END IF;
        UPDATE tbl_event target
           SET id_prior_event = COALESCE(target.id_prior_event, occupied.id_prior_event)
          FROM tbl_event occupied
         WHERE target.id_event = v_existing_id AND occupied.id_event = v_occupant_id;
        UPDATE tbl_tournament
           SET txt_code = 'EVFLEGACY' || v_occupant_id::TEXT || '-' || id_tournament::TEXT
         WHERE id_event = v_occupant_id;
        UPDATE tbl_event
           SET txt_code = 'EVFLEGACY' || v_occupant_id::TEXT || '-' || v_season_suffix
         WHERE id_event = v_occupant_id;
      END IF;

      SELECT txt_code INTO v_old_code FROM tbl_event WHERE id_event = v_existing_id;
      IF v_old_code <> v_desired_code AND EXISTS (
        SELECT 1 FROM tbl_tournament t JOIN tbl_result r USING (id_tournament)
         WHERE t.id_event = v_existing_id
      ) THEN
        RAISE EXCEPTION 'fn_ingest_evf_calendar: refusing to renumber scored event %',
          v_existing_id;
      END IF;
      IF v_old_code <> v_desired_code THEN
        UPDATE tbl_tournament SET txt_code = '__evfcal_' || id_tournament::TEXT
         WHERE id_event = v_existing_id;
        UPDATE tbl_event SET txt_code = v_desired_code WHERE id_event = v_existing_id;
        UPDATE tbl_tournament SET
          txt_code = v_desired_code || '-' || enum_age_category::TEXT || '-' ||
                     enum_gender::TEXT || '-' || enum_weapon::TEXT
         WHERE id_event = v_existing_id;
      END IF;

      UPDATE tbl_event
         SET txt_name = COALESCE(v_evt ->> 'name', txt_name),
             dt_start = COALESCE(NULLIF(v_evt ->> 'dt_start', '')::DATE, dt_start),
             dt_end = COALESCE(NULLIF(v_evt ->> 'dt_end', '')::DATE, dt_end),
             txt_location = COALESCE(NULLIF(v_evt ->> 'location', ''), txt_location),
             txt_country = COALESCE(NULLIF(v_evt ->> 'country', ''), txt_country),
             txt_code = v_desired_code,
             id_evf_calendar_event = v_calendar_id,
             txt_evf_slug = COALESCE(txt_evf_slug, v_slug)
       WHERE id_event = v_existing_id;
    ELSE
      v_kind := fn_classify_evf_event(
        v_evt ->> 'name', COALESCE((v_evt ->> 'is_team')::BOOLEAN, FALSE)
      );
      SELECT * INTO v_alloc
        FROM fn_allocate_evf_event_code(
          p_id_season, v_kind,
          COALESCE(v_evt ->> 'location', ''),
          COALESCE(v_evt ->> 'country', ''), v_letters
        );

      INSERT INTO tbl_event (
        txt_code, txt_name, id_season, id_organizer,
        txt_location, txt_country, enum_status, id_prior_event,
        id_evf_calendar_event, txt_evf_slug
      ) VALUES (
        v_desired_code, COALESCE(v_evt ->> 'name', v_desired_code),
        p_id_season, v_org,
        NULLIF(v_evt ->> 'location', ''), NULLIF(v_evt ->> 'country', ''),
        'CREATED', v_alloc.id_prior_event, v_calendar_id, v_slug
      ) RETURNING id_event INTO v_existing_id;
    END IF;

    -- Approved geographic-series exception: the Athens occurrence continues
    -- Chania for rolling-score purposes; current-season digits remain purely
    -- chronological and do not participate in this link.
    IF v_calendar_id = 3438 THEN
      UPDATE tbl_event current_event SET id_prior_event = prior_event.id_event
        FROM LATERAL (
          SELECT e.id_event FROM tbl_event e
          JOIN tbl_season s ON s.id_season = e.id_season
          WHERE e.id_season <> p_id_season
            AND (e.txt_name ILIKE '%Chania%' OR e.txt_location ILIKE '%Chania%')
          ORDER BY s.dt_end DESC, e.id_event DESC
          LIMIT 1
        ) prior_event
       WHERE current_event.id_event = v_existing_id;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'fn_ingest_evf_calendar: Athens requires a prior Chania event';
      END IF;
    END IF;

    -- The established two-argument implementation always writes PLANNED.
    -- Delegate new/pre-terminal rows only; terminal lifecycle state is never
    -- demoted by a calendar refresh.
    IF v_existing_status IS NULL OR v_existing_status IN (
      'CREATED','PLANNED','SCHEDULED','CHANGED','IN_PROGRESS'
    ) THEN
      v_delegate := v_delegate || jsonb_build_array(v_evt);
    END IF;
  END LOOP;

  IF jsonb_array_length(v_delegate) > 0 THEN
    v_result := fn_ingest_evf_calendar(v_delegate, p_id_season);
  ELSE
    v_result := jsonb_build_object(
      'created', 0, 'slot_reused', 0, 'prior_matched', 0, 'alerts', '[]'::JSONB
    );
  END IF;

  FOR v_evt IN SELECT * FROM jsonb_array_elements(p_events)
  LOOP
    IF COALESCE((v_evt ->> 'is_cancelled')::BOOLEAN, FALSE) THEN
      v_calendar_id := NULLIF(v_evt ->> 'evf_calendar_id', '')::BIGINT;
      SELECT e.id_event INTO v_existing_id
        FROM tbl_event e
       WHERE e.id_season = p_id_season
         AND e.id_evf_calendar_event = v_calendar_id;

      IF EXISTS (
        SELECT 1 FROM tbl_tournament t
        JOIN tbl_result r ON r.id_tournament = t.id_tournament
        WHERE t.id_event = v_existing_id
      ) THEN
        RAISE EXCEPTION 'refusing to cancel EVF calendar event % because results exist',
          v_calendar_id;
      END IF;

      UPDATE tbl_event
         SET enum_status = 'CANCELLED'
       WHERE id_event = v_existing_id
         AND enum_status IN (
           'CREATED','PLANNED','SCHEDULED','CHANGED','IN_PROGRESS','CANCELLED'
         );

      IF NOT FOUND THEN
        RAISE EXCEPTION 'refusing to cancel EVF calendar event % from advanced status',
          v_calendar_id;
      END IF;
    END IF;
  END LOOP;

  RETURN v_result;
END;
$function$;

COMMIT;
