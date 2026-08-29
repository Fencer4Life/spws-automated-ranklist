-- =============================================================================
-- Release a prior-event link before reassigning it
-- =============================================================================
-- ADR-081 / ADR-086. Regression from 20260828000009, which added id_prior_event
-- to the mirror's UPDATE branch. Caught live on the first promote afterwards:
--
--   duplicate key value violates unique constraint "idx_event_prior_unique"
--   DETAIL: Key (id_season, id_prior_event)=(4, 66) already exists.
--
-- idx_event_prior_unique is UNIQUE (id_season, id_prior_event) WHERE
-- id_prior_event IS NOT NULL: within a season only one event may claim a given
-- predecessor. CERT had moved PEW3fs-2025-2026 from PEW6efs-2026-2027 to
-- PEW4fs-2026-2027 -- a swap. The mirror applies updates row by row, so the new
-- claimant hit the index while the previous holder still had it.
--
-- Exactly the collision class the code-rename staging already solves
-- (20260828000008); it simply was not extended to this column when
-- id_prior_event started being carried. The pre-pass now releases every link
-- that is about to be reassigned, before any row takes its new one.
--
-- Guarded: only where the payload states a DIFFERENT, non-null predecessor. The
-- UPDATE is COALESCE(new, old), so clearing on a silent payload would destroy a
-- link PROD holds and CERT never mentioned.
--
-- Reproduced from the LIVE pg_get_functiondef output so 20260828000010-12 carry
-- forward.
--
-- Plan-test-ID 63 (supabase/tests/63_prod_mirror_rename.sql, 63.5).
-- =============================================================================

BEGIN;

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

  -- Same transient collision, different column. idx_event_prior_unique is
  -- UNIQUE (id_season, id_prior_event) WHERE id_prior_event IS NOT NULL, so
  -- within a season only one event may claim a predecessor. When a link SWAPS
  -- between two events -- CERT moving PEW3fs-2025-2026 from PEW6efs to PEW4fs --
  -- the row-by-row loop makes the new claimant collide with the old one that
  -- has not let go yet. Release every link that is about to be reassigned, then
  -- let the loop set them.
  --
  -- The condition is exact: release a link only when ANOTHER event in this same
  -- payload is claiming the predecessor this row currently holds. That covers
  -- both shapes of a swap -- the old holder being reassigned elsewhere, and the
  -- old holder simply letting go -- while never touching a link nobody else
  -- wants. It has to be that narrow: the UPDATE below is COALESCE(new, old), so
  -- clearing on a payload that merely says nothing would silently destroy a
  -- link PROD holds and CERT never mentioned.
  UPDATE tbl_event e
     SET id_prior_event = NULL
   WHERE e.id_prior_event IS NOT NULL
     AND EXISTS (
       SELECT 1
         FROM jsonb_array_elements(p_updates) je
        WHERE NULLIF(je ->> 'id_prior_event', '')::INT = e.id_prior_event
          AND (je ->> 'id_event')::INT <> e.id_event
     );

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

COMMIT;
