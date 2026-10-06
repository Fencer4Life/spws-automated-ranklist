-- =============================================================================
-- A European Championship is a singleton, not a chronological PEW
-- =============================================================================
-- The 2027 Individual European Veterans Championships (Skopje, EVF calendar
-- post 5407) reached CERT and PROD as PEW16fs-2026-2027. Since the 2026-08-07
-- complete-snapshot numbering (ADR-043 amendment) both the Python planner and
-- fn_ingest_evf_calendar_identity_v1 gave every calendar entry a chronological
-- PEW code. fn_classify_evf_event already answered IMEW for that name; the
-- insert branch used the answer only for a prior-season lookup and then
-- inserted the PEW code anyway. Dublin and Toronto moved down to make room.
--
-- This migration, with the planner change in python/scrapers/evf_calendar.py:
--   1. fn_classify_evf_event needs both whole words, European and
--      Championship(s): DMEW when the entry is the team championship, IMEW
--      otherwise, PEW for everything else. The team flag alone no longer
--      makes a DMEW, and a world championship is no longer an IMEW.
--   2. fn_ingest_evf_calendar_identity_v1 expects IMEW-/DMEW-{season} for a
--      European Championship and keeps it out of the PEW sequence; a PEW code
--      for one is a code plan mismatch.
--   3. The same function writes arr_weapons whenever it writes the code
--      (rename and insert). The code's suffix was renamed when EVF's weapons
--      changed while the column kept the old set -- Madrid holds PEW2efs with
--      {EPEE,SABRE}. Closes ADR-089 open item 1.
--   4. The three-argument wrapper links an unlinked singleton to the latest
--      earlier edition of its kind; a link already present is kept.
--
-- No data is changed here. The next calendar run renames the rows through the
-- same reflow every EVF change uses, and the reconciler carries it to PROD.
--
-- Both functions are reproduced from their LIVE definitions (pg_get_functiondef
-- on LOCAL, identical to 20260913000002 / 20260808000002) with only the edits
-- above. CREATE OR REPLACE keeps the existing REVOKE/GRANT posture.
--
-- Plan: doc/plans/evf-skopje-european-championships-2026-10-06.html
-- Tests: supabase/tests/107_evf_singleton_championships.sql (107.1-107.9),
--        python/tests/test_evf_calendar.py (evf.76-evf.83).
-- =============================================================================

BEGIN;

SET LOCAL lock_timeout = '2s';

-- -----------------------------------------------------------------------------
-- 1. The classifier: both words, whole, case-insensitive. The planner applies
--    the same rule after folding accents (classify_calendar_entry).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_classify_evf_event(
  p_name    TEXT,
  p_is_team BOOLEAN
)
RETURNS TEXT
LANGUAGE plpgsql IMMUTABLE
AS $$
BEGIN
  IF COALESCE(p_name, '') ~* '\mEuropean\M'
     AND COALESCE(p_name, '') ~* '\mChampionships?\M' THEN
    IF COALESCE(p_is_team, FALSE) THEN
      RETURN 'DMEW';
    END IF;
    RETURN 'IMEW';
  END IF;
  RETURN 'PEW';
END;
$$;

-- -----------------------------------------------------------------------------
-- 2 and 3. The code plan validator: singleton codes, and weapons with the code.
-- -----------------------------------------------------------------------------
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
  v_weapons_sorted enum_weapon_type[];
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
  -- neutral placeholder first, exactly as fn_rebuild_tournament_codes does
  -- per-event for tournament codes, so the loop only ever assigns into free
  -- codes. Scored events are excluded: they must keep their code and still
  -- trip the 'refusing to renumber scored event' guard below rather than being
  -- parked.
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
    -- The scraped weapons are written with the code, every time the code is
    -- written: the suffix and this column state the same fact (ADR-089 open
    -- item 1). Canonical order, no duplicates.
    SELECT array_agg(DISTINCT w ORDER BY w) INTO v_weapons_sorted
      FROM unnest(v_weapons_arr) AS w;

    -- A European Championship is its season's singleton: IMEW- or
    -- DMEW-{season}, outside the PEW sequence (ADR-043 amendment 2026-10-06).
    v_kind := fn_classify_evf_event(
      v_evt ->> 'name', COALESCE((v_evt ->> 'is_team')::BOOLEAN, FALSE)
    );

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

    IF v_kind IN ('IMEW', 'DMEW') THEN
      v_expected_code := v_kind || '-' || v_season_suffix;
    ELSIF v_cancelled AND (
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
        PERFORM fn_rebuild_tournament_codes(v_existing_id, v_desired_code);
      END IF;

      UPDATE tbl_event
         SET txt_name = COALESCE(v_evt ->> 'name', txt_name),
             dt_start = COALESCE(NULLIF(v_evt ->> 'dt_start', '')::DATE, dt_start),
             dt_end = COALESCE(NULLIF(v_evt ->> 'dt_end', '')::DATE, dt_end),
             txt_location = COALESCE(NULLIF(v_evt ->> 'location', ''), txt_location),
             txt_country = COALESCE(NULLIF(v_evt ->> 'country', ''), txt_country),
             txt_code = v_desired_code,
             arr_weapons = v_weapons_sorted,
             id_evf_calendar_event = v_calendar_id,
             txt_evf_slug = COALESCE(txt_evf_slug, v_slug)
       WHERE id_event = v_existing_id;
    ELSE
      SELECT * INTO v_alloc
        FROM fn_allocate_evf_event_code(
          p_id_season, v_kind,
          COALESCE(v_evt ->> 'location', ''),
          COALESCE(v_evt ->> 'country', ''), v_letters
        );

      INSERT INTO tbl_event (
        txt_code, txt_name, id_season, id_organizer,
        txt_location, txt_country, enum_status, id_prior_event,
        id_evf_calendar_event, txt_evf_slug, arr_weapons
      ) VALUES (
        v_desired_code, COALESCE(v_evt ->> 'name', v_desired_code),
        p_id_season, v_org,
        NULLIF(v_evt ->> 'location', ''), NULLIF(v_evt ->> 'country', ''),
        'CREATED', v_alloc.id_prior_event, v_calendar_id, v_slug, v_weapons_sorted
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

-- -----------------------------------------------------------------------------
-- 4. The wrapper: a singleton's series link.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_ingest_evf_calendar(p_events jsonb, p_id_season integer, p_season_event_count integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  v_kind TEXT;
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
    ELSIF fn_classify_evf_event(
            v_event_name, COALESCE((v_evt ->> 'is_team')::BOOLEAN, FALSE)
          ) IN ('IMEW', 'DMEW') THEN
      -- A European Championship continues the latest earlier edition of its
      -- own kind: IMEW the previous IMEW two seasons back, DMEW the previous
      -- DMEW (ADR-021). The series key cannot express that -- it carries the
      -- year, so "europeanchampionships2027" never meets its predecessor. A
      -- link already on the target is kept, never overwritten.
      v_kind := fn_classify_evf_event(
        v_event_name, COALESCE((v_evt ->> 'is_team')::BOOLEAN, FALSE)
      );
      IF v_target_id IS NOT NULL THEN
        SELECT id_prior_event INTO v_prior_id FROM tbl_event WHERE id_event = v_target_id;
      END IF;
      IF v_prior_id IS NULL THEN
        SELECT e.id_event INTO v_prior_id
          FROM tbl_event e
          JOIN tbl_season s ON s.id_season = e.id_season
         WHERE e.txt_code LIKE v_kind || '-%'
           AND s.dt_end < (SELECT dt_start FROM tbl_season WHERE id_season = p_id_season)
         ORDER BY s.dt_end DESC, e.id_event DESC
         LIMIT 1;
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
$function$;

COMMIT;
