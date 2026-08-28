-- =============================================================================
-- A later cancellation may shift with the sequence when nothing is anchored
-- =============================================================================
-- ADR-086 §4. PEW numbers are chronological position, so a newly announced
-- mid-season event moves every later event down one. ADR-043's amendment states
-- both "unscored rows may be reflowed transactionally if EVF inserts or
-- reschedules an earlier entry" AND "a later cancellation keeps its positive
-- code" -- and those two rules contradict each other the moment an event is
-- inserted ahead of a cancelled one.
--
-- Observed live 2026-08-28 (run 33187122201): admitting "EVF Circuit - Tampere
-- (FIN)" (23 Jan 2027) moved Stockholm from PEW11 to PEW12 in the same scrape
-- that cancelled it, and the calendar write aborted with
--   fn_ingest_evf_calendar: later cancellation 3444 cannot move PEW11 to PEW12
--
-- The client-side planner (plan_calendar_codes) was relaxed in the same change;
-- this is the server-side half. ADR-043 describes the RPC guards as the
-- backstop, so BOTH must agree or the backstop rejects a plan the planner
-- considers valid -- which is exactly what happened.
--
-- What is preserved: a later cancellation still never collapses to PEW0 and
-- never frees its slot. Only its position within the sequence may move, and
-- only while nothing is anchored to the old code.
--
-- The anchor set is registrations AND results. Registration is the sharper
-- anchor -- a fencer who has entered holds a code that must not move under
-- them -- and did not exist when ADR-043 was written. Results stay in the set
-- because child tournament codes are rebuilt from the event code.
-- Unknown is not zero: a NULL dt_start is not movable.
--
-- fn_ingest_evf_calendar_identity_v1 is reproduced from the LIVE definition
-- (pg_get_functiondef) rather than from 20260807000001, so the prior-link
-- amendments in 20260808000001/2 are carried forward rather than reverted.
-- Only the cancellation guard differs.
--
-- Plan-test-ID 61 (supabase/tests/61_evf_cancellation_sequence_shift.sql).
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_evf_event_code_is_movable(p_id_event INT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SET search_path = public
AS $fn$
  SELECT COALESCE((
    SELECT e.dt_start > CURRENT_DATE
       AND NOT EXISTS (
             SELECT 1 FROM tbl_registration r WHERE r.id_event = e.id_event)
       AND NOT EXISTS (
             SELECT 1
               FROM tbl_tournament t
               JOIN tbl_result res ON res.id_tournament = t.id_tournament
              WHERE t.id_event = e.id_event)
      FROM tbl_event e
     WHERE e.id_event = p_id_event
  ), FALSE);
$fn$;

COMMENT ON FUNCTION fn_evf_event_code_is_movable(INT) IS
  'ADR-086 §4: whether an EVF event code may shift with the chronological sequence. True only when the event is still ahead, carries no registrations and holds no results. NULL dt_start or unknown event is not movable.';

-- ADR-083 deny-by-default: this is an internal helper for the ingest RPC, which
-- is SECURITY DEFINER and therefore reaches it regardless of PUBLIC grants.
-- Postgres grants EXECUTE to PUBLIC on creation, which would otherwise add it to
-- the anon-EXECUTEable surface -- caught by 52_security_posture.sql test 52.7.
REVOKE ALL ON FUNCTION fn_evf_event_code_is_movable(INT) FROM PUBLIC, anon;

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
      SELECT txt_code INTO v_old_code FROM tbl_event WHERE id_event = v_existing_id;
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
