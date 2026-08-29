-- =============================================================================
-- dt_start_first_published: the anchor for the moved-date pill
-- =============================================================================
-- ADR-077 amendment / ADR-086 amendment.
--
-- CHANGED was meant to flag "EVF moved this event" and was never implemented.
-- The signal becomes a visual pill on the event card instead, and it needs an
-- anchor: the FIRST date EVF ever published for the event, not the previous one,
-- so an event moved twice still reads against the date originally announced.
--
-- Set on first import and never updated, so "moved" is a field comparison
-- (dt_start <> dt_start_first_published) rather than an audit-history scan.
-- There is no predicate to re-tune later.
--
-- The pill shows only when enum_status = 'PLANNED' AND dt_start > CURRENT_DATE
-- AND the two dates differ. Measured against all recorded history that yields
-- zero false positives: every past date change belongs to a COMPLETED event and
-- is a data repair -- one-day corrections, DD/MM parse fixes and the 2025-2026
-- fragment repair -- not a reschedule.
--
-- Backfilled from dt_start, so no existing event is retroactively flagged as
-- moved. Carried CERT->PROD fill-blank-only by fn_mirror_events_to_prod.
--
-- Plan-test-ID 67 (supabase/tests/67_event_first_published_date.sql).
-- =============================================================================

BEGIN;

-- postgrestools flags this file for holding ACCESS EXCLUSIVE across the
-- statements that follow the ALTER. Accepted, not ignored: ADD COLUMN without a
-- default is metadata-only in modern Postgres, tbl_event holds ~100 rows, and
-- the backfill touches only rows where the column is NULL -- the lock is held
-- for milliseconds. lock_timeout is set so a blocked deploy fails fast rather
-- than queueing behind a long transaction.
SET lock_timeout = '5s';

ALTER TABLE tbl_event
  ADD COLUMN IF NOT EXISTS dt_start_first_published DATE;

COMMENT ON COLUMN tbl_event.dt_start_first_published IS
  'ADR-077 amendment: the first start date EVF published for this event. Set on first import, never updated. dt_start <> this means EVF moved the event; the calendar shows a "moved from" pill while the event is PLANNED and still ahead.';

-- Backfill: existing events are anchored to the date they hold now, so nothing
-- historical is retroactively flagged as moved.
UPDATE tbl_event
   SET dt_start_first_published = dt_start
 WHERE dt_start_first_published IS NULL
   AND dt_start IS NOT NULL;

CREATE OR REPLACE FUNCTION public.fn_mirror_events_to_prod(p_creates jsonb DEFAULT '[]'::jsonb, p_updates jsonb DEFAULT '[]'::jsonb, p_deletes jsonb DEFAULT '[]'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_evt            JSONB;
  v_created        INT := 0;
  v_updated        INT := 0;
  v_deleted        INT := 0;
  v_delete_skipped JSONB := '[]'::JSONB;
  v_id_org         INT;
  v_id_event       INT;
  v_arr_weapons    enum_weapon_type[];
BEGIN
  -- ===== rename staging (ADR-086) =====
  -- A mid-season EVF insertion renumbers every later event, so CERT sends the
  -- SAME rows back under new codes. Applied in payload order those renames
  -- collide with each other -- Dublin taking the code Toronto has not vacated --
  -- exactly as they did inside fn_ingest_evf_calendar on CERT. Park every code
  -- that is about to change, then let the create and update branches assign
  -- into codes that are guaranteed free.
  UPDATE tbl_event e
     SET txt_code = '__mirror_evt_' || e.id_event::TEXT
    FROM jsonb_array_elements(p_updates) je
   WHERE e.id_event = (je ->> 'id_event')::INT
     AND NULLIF(je ->> 'txt_code', '') IS NOT NULL
     AND e.txt_code IS DISTINCT FROM (je ->> 'txt_code');

  IF jsonb_array_length(p_creates) > 0 THEN
    FOR v_evt IN SELECT * FROM jsonb_array_elements(p_creates)
    LOOP
      IF EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = v_evt ->> 'txt_code') THEN
        CONTINUE;
      END IF;

      v_id_org := (v_evt ->> 'id_organizer')::INT;
      IF v_id_org IS NULL OR NOT EXISTS (
        SELECT 1 FROM tbl_organizer WHERE id_organizer = v_id_org
      ) THEN
        RAISE EXCEPTION 'fn_mirror_events_to_prod: event % has unresolved id_organizer (%)',
          v_evt ->> 'txt_code', v_id_org;
      END IF;

      v_arr_weapons := NULL;
      IF v_evt ? 'arr_weapons' THEN
        SELECT ARRAY(
          SELECT (value #>> '{}')::enum_weapon_type
          FROM jsonb_array_elements(v_evt -> 'arr_weapons')
        ) INTO v_arr_weapons;
      END IF;

      INSERT INTO tbl_event (
        txt_code, txt_name, id_season, id_organizer,
        dt_start, dt_end, txt_location, txt_country, enum_status,
        url_event, url_event_2, url_event_3, url_event_4, url_event_5,
        url_invitation, url_registration, dt_registration_deadline,
        txt_venue_address, num_entry_fee, txt_entry_fee_currency,
        arr_weapons, id_prior_event, id_evf_event, txt_evf_slug,
        id_evf_calendar_event,
        num_entry_fee_2w, num_entry_fee_3w, url_entry_list,
        txt_organizer_email, bool_use_spws_registration,
        dt_start_first_published
      ) VALUES (
        v_evt ->> 'txt_code', v_evt ->> 'txt_name',
        (v_evt ->> 'id_season')::INT, v_id_org,
        NULLIF(v_evt ->> 'dt_start', '')::DATE, NULLIF(v_evt ->> 'dt_end', '')::DATE,
        NULLIF(v_evt ->> 'txt_location', ''), NULLIF(v_evt ->> 'txt_country', ''),
        COALESCE(v_evt ->> 'enum_status', 'PLANNED')::enum_event_status,
        NULLIF(v_evt ->> 'url_event', ''), NULLIF(v_evt ->> 'url_event_2', ''),
        NULLIF(v_evt ->> 'url_event_3', ''), NULLIF(v_evt ->> 'url_event_4', ''),
        NULLIF(v_evt ->> 'url_event_5', ''),
        NULLIF(v_evt ->> 'url_invitation', ''), NULLIF(v_evt ->> 'url_registration', ''),
        NULLIF(v_evt ->> 'dt_registration_deadline', '')::DATE,
        NULLIF(v_evt ->> 'txt_venue_address', ''),
        NULLIF(v_evt ->> 'num_entry_fee', '')::NUMERIC,
        NULLIF(v_evt ->> 'txt_entry_fee_currency', ''),
        v_arr_weapons, (v_evt ->> 'id_prior_event')::INT,
        (v_evt ->> 'id_evf_event')::INT, NULLIF(v_evt ->> 'txt_evf_slug', ''),
        (v_evt ->> 'id_evf_calendar_event')::BIGINT,
        NULLIF(v_evt ->> 'num_entry_fee_2w', '')::NUMERIC,
        NULLIF(v_evt ->> 'num_entry_fee_3w', '')::NUMERIC,
        NULLIF(v_evt ->> 'url_entry_list', ''),
        NULLIF(v_evt ->> 'txt_organizer_email', ''),
        -- NOT NULL with default false: a payload that omits the switch must
        -- fall back to the column default, not insert NULL.
        COALESCE((v_evt ->> 'bool_use_spws_registration')::BOOLEAN, FALSE),
        NULLIF(v_evt ->> 'dt_start_first_published', '')::DATE
      );
      v_created := v_created + 1;
    END LOOP;
  END IF;

  IF jsonb_array_length(p_updates) > 0 THEN
    FOR v_evt IN SELECT * FROM jsonb_array_elements(p_updates)
    LOOP
      v_id_event := (v_evt ->> 'id_event')::INT;
      v_arr_weapons := NULL;
      IF v_evt ? 'arr_weapons' THEN
        SELECT ARRAY(
          SELECT (value #>> '{}')::enum_weapon_type
          FROM jsonb_array_elements(v_evt -> 'arr_weapons')
        ) INTO v_arr_weapons;
      END IF;

      UPDATE tbl_event SET
        -- The code follows the row, which is identified by id_event: a renamed
        -- event must land on PROD as a rename, never as a second row.
        txt_code = COALESCE(NULLIF(v_evt ->> 'txt_code', ''), txt_code),
        txt_name = COALESCE(NULLIF(v_evt ->> 'txt_name', ''), txt_name),
        dt_start = COALESCE(NULLIF(v_evt ->> 'dt_start', '')::DATE, dt_start),
        dt_end = COALESCE(NULLIF(v_evt ->> 'dt_end', '')::DATE, dt_end),
        txt_location = COALESCE(NULLIF(v_evt ->> 'txt_location', ''), txt_location),
        txt_country = COALESCE(NULLIF(v_evt ->> 'txt_country', ''), txt_country),
        id_organizer = COALESCE((v_evt ->> 'id_organizer')::INT, id_organizer),
        arr_weapons = COALESCE(v_arr_weapons, arr_weapons),
        id_evf_event = COALESCE((v_evt ->> 'id_evf_event')::INT, id_evf_event),
        id_evf_calendar_event = COALESCE(
          id_evf_calendar_event, (v_evt ->> 'id_evf_calendar_event')::BIGINT
        ),
        txt_evf_slug = COALESCE(NULLIF(v_evt ->> 'txt_evf_slug', ''), txt_evf_slug),
        url_event = COALESCE(url_event, NULLIF(v_evt ->> 'url_event', '')),
        url_event_2 = COALESCE(url_event_2, NULLIF(v_evt ->> 'url_event_2', '')),
        url_event_3 = COALESCE(url_event_3, NULLIF(v_evt ->> 'url_event_3', '')),
        url_event_4 = COALESCE(url_event_4, NULLIF(v_evt ->> 'url_event_4', '')),
        url_event_5 = COALESCE(url_event_5, NULLIF(v_evt ->> 'url_event_5', '')),
        url_invitation = COALESCE(url_invitation, NULLIF(v_evt ->> 'url_invitation', '')),
        url_registration = COALESCE(url_registration, NULLIF(v_evt ->> 'url_registration', '')),
        dt_registration_deadline = COALESCE(
          dt_registration_deadline,
          NULLIF(v_evt ->> 'dt_registration_deadline', '')::DATE
        ),
        num_entry_fee = COALESCE(
          num_entry_fee, NULLIF(v_evt ->> 'num_entry_fee', '')::NUMERIC
        ),
        txt_entry_fee_currency = COALESCE(
          txt_entry_fee_currency, NULLIF(v_evt ->> 'txt_entry_fee_currency', '')
        ),
        -- Present in the CREATE branch but absent here until now, so an
        -- established PROD row never received them again. PPW1-2026-2027 held
        -- its venue address on CERT and NULL on PROD in every reconcile log.
        txt_venue_address = COALESCE(
          NULLIF(v_evt ->> 'txt_venue_address', ''), txt_venue_address
        ),
        id_prior_event = COALESCE((v_evt ->> 'id_prior_event')::INT, id_prior_event),
        -- Never reached PROD at all before. Fee tiers, entry list and organizer
        -- contact follow the fill-blank policy of their siblings so an admin
        -- edit made on PROD is preserved; the registration switch is config that
        -- CERT owns, so it overwrites whenever CERT states a value.
        num_entry_fee_2w = COALESCE(
          num_entry_fee_2w, NULLIF(v_evt ->> 'num_entry_fee_2w', '')::NUMERIC
        ),
        num_entry_fee_3w = COALESCE(
          num_entry_fee_3w, NULLIF(v_evt ->> 'num_entry_fee_3w', '')::NUMERIC
        ),
        url_entry_list = COALESCE(url_entry_list, NULLIF(v_evt ->> 'url_entry_list', '')),
        txt_organizer_email = COALESCE(
          txt_organizer_email, NULLIF(v_evt ->> 'txt_organizer_email', '')
        ),
        bool_use_spws_registration = COALESCE(
          (v_evt ->> 'bool_use_spws_registration')::BOOLEAN, bool_use_spws_registration
        ),
        -- Planning lifecycle, forward only (ADR-086 amendment).
        -- CERT owns PLANNING; PROD owns RESULTS. Withholding the planning half
        -- left PPW1-2026-2027 stuck at CREATED on PROD -- which the calendar
        -- hides as a "date-less planning skeleton" -- while its registration was
        -- open with 14 entrants, and left a CANCELLED event still advertised.
        --
        -- Only the three transitions automation is permitted to make. Every
        -- source is a planning state, so a row at IN_PROGRESS/SCORED/COMPLETED
        -- is never touched and promote_event keeps the results axis. All three
        -- pairs are in fn_validate_event_transition's own table, and
        -- trg_event_transition fires only when the status actually changes, so
        -- the validator always accepts them and a status cannot abort a promote.
        enum_status = CASE
          WHEN (enum_status::TEXT, NULLIF(v_evt ->> 'enum_status', '')) IN (
            ('CREATED', 'PLANNED'),
            ('CREATED', 'CANCELLED'),
            ('PLANNED', 'CANCELLED')
          ) THEN (v_evt ->> 'enum_status')::enum_event_status
          ELSE enum_status
        END,
        -- Fill-blank only: the first published date is set once and never
        -- moves, so PROD must receive it if it is missing and never have it
        -- overwritten afterwards.
        dt_start_first_published = COALESCE(
          dt_start_first_published,
          NULLIF(v_evt ->> 'dt_start_first_published', '')::DATE
        ),
        ts_updated = NOW()
      WHERE id_event = v_id_event;

      IF FOUND THEN v_updated := v_updated + 1; END IF;
    END LOOP;
  END IF;

  IF jsonb_array_length(p_deletes) > 0 THEN
    FOR v_id_event IN
      SELECT (value)::INT FROM jsonb_array_elements_text(p_deletes) AS value
    LOOP
      IF EXISTS (
        SELECT 1 FROM tbl_event e
        WHERE e.id_event = v_id_event
          AND e.enum_status = 'PLANNED'
          AND NOT EXISTS (
            SELECT 1 FROM tbl_tournament t
            JOIN tbl_result r ON r.id_tournament = t.id_tournament
            WHERE t.id_event = e.id_event
          )
      ) THEN
        DELETE FROM tbl_tournament WHERE id_event = v_id_event;
        DELETE FROM tbl_event WHERE id_event = v_id_event;
        v_deleted := v_deleted + 1;
      ELSE
        v_delete_skipped := v_delete_skipped || to_jsonb(v_id_event);
      END IF;
    END LOOP;
  END IF;

  RETURN jsonb_build_object(
    'created', v_created,
    'updated', v_updated,
    'deleted', v_deleted,
    'delete_skipped', v_delete_skipped
  );
END;
$function$;


-- Set on INSERT, from whatever path creates the row -- the EVF scraper's ingest
-- RPC, the admin UI, the CERT->PROD mirror or a seed load. A trigger rather than
-- edits to each writer: the invariant is "the first date we ever published",
-- and it must hold no matter who inserts. Only ever fills a NULL, so the mirror
-- passing an explicit value (a row already anchored on CERT) wins.
CREATE OR REPLACE FUNCTION fn_set_event_first_published_date()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $fn$
BEGIN
  -- Anchor on the first date the event ever HELD, which is not always the
  -- insert. A season skeleton is created date-less (ADR-077), so its anchor is
  -- NULL until an admin or the scrape dates it -- and that first date is the
  -- one EVF published. Filling it only while NULL means a later reschedule
  -- never moves the anchor, which is what makes "moved from" true.
  IF NEW.dt_start_first_published IS NULL AND NEW.dt_start IS NOT NULL THEN
    NEW.dt_start_first_published := NEW.dt_start;
  END IF;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_set_event_first_published_date ON tbl_event;

CREATE TRIGGER trg_set_event_first_published_date
  BEFORE INSERT OR UPDATE OF dt_start, dt_start_first_published ON tbl_event
  FOR EACH ROW
  EXECUTE FUNCTION fn_set_event_first_published_date();


-- vw_calendar names its columns explicitly, so a new tbl_event column does not
-- reach the frontend until the view is rebuilt -- the calendar would render no
-- pill and the omission would be invisible. Rebuilt here rather than left for a
-- later change to discover.
CREATE OR REPLACE VIEW vw_calendar AS
 SELECT e.id_event, e.txt_code, e.txt_name, e.id_season,
    s.txt_code AS txt_season_code,
    e.id_organizer, o.txt_name AS txt_organizer_name,
    e.txt_location, e.txt_country, e.txt_venue_address, e.url_invitation,
    e.num_entry_fee, e.txt_entry_fee_currency, e.arr_weapons,
    e.dt_start, e.dt_end,
    e.url_event, e.enum_status, e.url_registration, e.dt_registration_deadline,
    e.url_event_2, e.url_event_3, e.url_event_4, e.url_event_5,
    e.id_evf_event, e.txt_evf_slug, e.id_evf_calendar_event, e.id_prior_event,
    count(t.id_tournament)::integer AS num_tournaments,
    COALESCE(bool_or(t.enum_type = ANY (ARRAY['PEW'::enum_tournament_type,
      'MEW'::enum_tournament_type, 'MSW'::enum_tournament_type,
      'PSW'::enum_tournament_type])), false) AS bool_has_international,
    e.json_ingest_sources, e.json_source_overrides, e.url_entry_list,
    e.txt_organizer_email, e.ts_ftl_sent, e.num_entry_fee_2w, e.num_entry_fee_3w,
    e.bool_use_spws_registration,
    -- Appended, not inserted: CREATE OR REPLACE VIEW can only add columns at
    -- the end, and dropping vw_calendar would cascade to its dependants.
    e.dt_start_first_published
   FROM tbl_event e
     JOIN tbl_season s ON s.id_season = e.id_season
     LEFT JOIN tbl_organizer o ON o.id_organizer = e.id_organizer
     LEFT JOIN tbl_tournament t ON t.id_event = e.id_event
  GROUP BY e.id_event, s.txt_code, o.txt_name
  ORDER BY e.dt_start;

COMMIT;
