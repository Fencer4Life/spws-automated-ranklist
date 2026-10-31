-- =============================================================================
-- ADR-118 F9: PROD's side of the comparison counts a person's changes only
-- =============================================================================
-- The mirror keeps PROD's details when PROD was written later than CERT. It
-- read PROD's time from every audited change, so each mirror run that copied
-- a CERT write made PROD look newer than that write: on 31 Oct 2026 Madrid
-- and Skopje showed CERT 6 Oct 12:53:51 against PROD 6 Oct 13:00:13, the
-- mirror's own copy, and PROD kept the August letter and V2. The signed rule
-- is that PROD keeps its values when a person edited PROD after CERT's last
-- write.
--
-- fn_event_details_set_at keeps its name and now answers that question: the
-- latest change a person made (txt_admin_user set) to any of the nine
-- details, and NULL when no person ever changed them. The mirror treats NULL
-- as "CERT is newer". The name stays because the released migration
-- 20261031000001 calls it and applied migrations are never edited (plan F10
-- A). CERT's side is unchanged: promote.py counts every write on CERT, a
-- scraper's or a person's.
--
-- Plan: doc/plans/cert-event-details-reach-prod-every-scraper-2026-10-31.html
-- §13. Tests: supabase/tests/117_mirror_cert_event_details.sql CALSYNC.17-19.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_event_details_set_at(p_id_event integer)
 RETURNS timestamp with time zone
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT max(a.ts_created)
    FROM tbl_audit_log a
   WHERE a.txt_table_name = 'tbl_event'
     AND a.id_row = p_id_event
     AND a.txt_action = 'UPDATE'
     AND a.txt_admin_user IS NOT NULL
     AND EXISTS (
       SELECT 1
         FROM unnest(ARRAY['txt_name', 'dt_start', 'dt_end', 'txt_location', 'txt_country',
                           'arr_weapons', 'txt_venue_address', 'url_invitation',
                           'url_registration', 'num_entry_fee',
                           'txt_entry_fee_currency']) AS f(name)
        WHERE (a.jsonb_old_values -> f.name) IS DISTINCT FROM (a.jsonb_new_values -> f.name))
$function$;

COMMENT ON FUNCTION fn_event_details_set_at(INT) IS
  'ADR-118 (F9): when a person last changed any of the event''s nine details in this environment; NULL when no person ever did. The mirror''s own writes on PROD do not count.';

REVOKE EXECUTE ON FUNCTION fn_event_details_set_at(INT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_event_details_set_at(INT) TO service_role;

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
  -- ADR-118: the row before and after this update, CERT's time, and the two
  -- link shapes the details rule treats specially.
  v_cur            tbl_event%ROWTYPE;
  v_next           tbl_event%ROWTYPE;
  v_ts             TIMESTAMPTZ;
  v_cert_newer     BOOLEAN;
  v_fee            NUMERIC;
  c_page CONSTANT TEXT :=
    '^https?://(www\.)?(pzszerm\.pl/zawody/kalendarium-zawodow/zawody/|veteransfencing\.eu/event/)';
  c_our_link CONSTANT TEXT := '/register\.html\?event=';
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

  -- The PZSz identity has the same transient collision as id_prior_event.
  -- idx_tbl_event_pzsz_season is UNIQUE (id_season, id_pzsz_event) WHERE
  -- id_pzsz_event IS NOT NULL, and CERT's id wins on update (Q5 A, below), so
  -- a re-key on CERT that swaps two pzszerm.pl ids would make the loop collide
  -- row by row. Release an id only when ANOTHER element of this payload claims
  -- it: an update naming a different id_event, or a create whose code PROD does
  -- not hold yet (a create of an existing code is skipped below, so it must not
  -- release anything). A payload that says nothing releases nothing.
  UPDATE tbl_event e
     SET id_pzsz_event = NULL
   WHERE e.id_pzsz_event IS NOT NULL
     AND (
       EXISTS (
         SELECT 1
           FROM jsonb_array_elements(p_updates) je
          WHERE NULLIF(je ->> 'id_pzsz_event', '')::INT = e.id_pzsz_event
            AND (je ->> 'id_event')::INT <> e.id_event
       )
       OR EXISTS (
         SELECT 1
           FROM jsonb_array_elements(p_creates) je
          WHERE NULLIF(je ->> 'id_pzsz_event', '')::INT = e.id_pzsz_event
            AND NOT EXISTS (
              SELECT 1 FROM tbl_event x WHERE x.txt_code = je ->> 'txt_code'
            )
       )
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
        url_invitation, url_registration, dt_registration_deadline,
        txt_venue_address, num_entry_fee, txt_entry_fee_currency,
        arr_weapons, id_prior_event, id_evf_event, txt_evf_slug,
        id_evf_calendar_event, id_pzsz_event,
        num_entry_fee_2w, num_entry_fee_3w, url_entry_list,
        txt_organizer_email, bool_use_spws_registration,
        txt_payee, txt_iban,
        dt_start_first_published
      ) VALUES (
        v_evt ->> 'txt_code', v_evt ->> 'txt_name',
        (v_evt ->> 'id_season')::INT, v_id_org,
        NULLIF(v_evt ->> 'dt_start', '')::DATE, NULLIF(v_evt ->> 'dt_end', '')::DATE,
        NULLIF(v_evt ->> 'txt_location', ''), NULLIF(v_evt ->> 'txt_country', ''),
        COALESCE(v_evt ->> 'enum_status', 'PLANNED')::enum_event_status,
        -- No results slot: PROD's results links are set in Admin only.
        NULLIF(v_evt ->> 'url_invitation', ''), NULLIF(v_evt ->> 'url_registration', ''),
        NULLIF(v_evt ->> 'dt_registration_deadline', '')::DATE,
        NULLIF(v_evt ->> 'txt_venue_address', ''),
        NULLIF(v_evt ->> 'num_entry_fee', '')::NUMERIC,
        NULLIF(v_evt ->> 'txt_entry_fee_currency', ''),
        v_arr_weapons, (v_evt ->> 'id_prior_event')::INT,
        (v_evt ->> 'id_evf_event')::INT, NULLIF(v_evt ->> 'txt_evf_slug', ''),
        (v_evt ->> 'id_evf_calendar_event')::BIGINT,
        NULLIF(v_evt ->> 'id_pzsz_event', '')::INT,
        NULLIF(v_evt ->> 'num_entry_fee_2w', '')::NUMERIC,
        NULLIF(v_evt ->> 'num_entry_fee_3w', '')::NUMERIC,
        NULLIF(v_evt ->> 'url_entry_list', ''),
        NULLIF(v_evt ->> 'txt_organizer_email', ''),
        -- NOT NULL with default false: a payload that omits the switch must
        -- fall back to the column default, not insert NULL.
        COALESCE((v_evt ->> 'bool_use_spws_registration')::BOOLEAN, FALSE),
        NULLIF(btrim(COALESCE(v_evt ->> 'txt_payee', '')), ''),
        NULLIF(btrim(COALESCE(v_evt ->> 'txt_iban', '')), ''),
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

      -- The next row is built from the current one, field by field, and
      -- written only when it differs (F2): a run that changes nothing writes
      -- nothing, so the audit's times mean something.
      SELECT * INTO v_cur FROM tbl_event WHERE id_event = v_id_event FOR UPDATE;
      CONTINUE WHEN NOT FOUND;
      v_next := v_cur;

      -- The code follows the row, which is identified by id_event: a renamed
      -- event must land on PROD as a rename, never as a second row.
      v_next.txt_code := COALESCE(NULLIF(v_evt ->> 'txt_code', ''), v_cur.txt_code);
      v_next.id_organizer := COALESCE((v_evt ->> 'id_organizer')::INT, v_cur.id_organizer);
      v_next.id_evf_event := COALESCE((v_evt ->> 'id_evf_event')::INT, v_cur.id_evf_event);
      v_next.id_evf_calendar_event := COALESCE(
        v_cur.id_evf_calendar_event, (v_evt ->> 'id_evf_calendar_event')::BIGINT);
      v_next.txt_evf_slug := COALESCE(NULLIF(v_evt ->> 'txt_evf_slug', ''), v_cur.txt_evf_slug);
      -- The pzszerm.pl identity follows id_evf_event (Q5 A, 6 Oct 2026): CERT's
      -- id wins when it sends one, PROD keeps its own when CERT sends none.
      -- promote_event needs it to read the start lists (ADR-111).
      v_next.id_pzsz_event := COALESCE(NULLIF(v_evt ->> 'id_pzsz_event', '')::INT, v_cur.id_pzsz_event);
      v_next.id_prior_event := COALESCE((v_evt ->> 'id_prior_event')::INT, v_cur.id_prior_event);

      v_ts := NULLIF(v_evt ->> 'ts_details_set', '')::TIMESTAMPTZ;
      IF v_ts IS NULL THEN
        -- A payload from before ADR-118: the earlier rules. Scraped facts
        -- overwrite; admin enrichment fills a blank; a calendar page on PROD
        -- gives way to CERT's letter (D7 A); a PZSz address follows CERT (D5).
        v_next.txt_name := COALESCE(NULLIF(v_evt ->> 'txt_name', ''), v_cur.txt_name);
        v_next.dt_start := COALESCE(NULLIF(v_evt ->> 'dt_start', '')::DATE, v_cur.dt_start);
        v_next.dt_end := COALESCE(NULLIF(v_evt ->> 'dt_end', '')::DATE, v_cur.dt_end);
        v_next.txt_location := COALESCE(NULLIF(v_evt ->> 'txt_location', ''), v_cur.txt_location);
        v_next.txt_country := COALESCE(NULLIF(v_evt ->> 'txt_country', ''), v_cur.txt_country);
        v_next.arr_weapons := COALESCE(v_arr_weapons, v_cur.arr_weapons);
        v_next.url_invitation := CASE
          WHEN v_cur.url_invitation ~* c_page
           AND NULLIF(v_evt ->> 'url_invitation', '') !~* c_page
            THEN v_evt ->> 'url_invitation'
          ELSE COALESCE(v_cur.url_invitation, NULLIF(v_evt ->> 'url_invitation', ''))
        END;
        v_next.url_registration := COALESCE(
          v_cur.url_registration, NULLIF(v_evt ->> 'url_registration', ''));
        v_next.num_entry_fee := COALESCE(
          v_cur.num_entry_fee, NULLIF(v_evt ->> 'num_entry_fee', '')::NUMERIC);
        v_next.txt_entry_fee_currency := COALESCE(
          v_cur.txt_entry_fee_currency, NULLIF(v_evt ->> 'txt_entry_fee_currency', ''));
        v_next.txt_venue_address := CASE
          WHEN NULLIF(v_evt ->> 'id_pzsz_event', '') IS NOT NULL OR v_cur.id_pzsz_event IS NOT NULL
            THEN COALESCE(NULLIF(v_evt ->> 'txt_venue_address', ''), v_cur.txt_venue_address)
          ELSE COALESCE(v_cur.txt_venue_address, NULLIF(v_evt ->> 'txt_venue_address', ''))
        END;
      ELSE
        -- ADR-118: CERT wrote its details later than a person last changed
        -- them on PROD (or no person ever did), so PROD takes every one CERT
        -- holds; otherwise PROD keeps its own and only an empty field is
        -- filled. The mirror's own writes on PROD are copies of CERT and do
        -- not count (F9). A blank on CERT never clears PROD (S1 A).
        v_cert_newer := v_ts > COALESCE(fn_event_details_set_at(v_id_event),
                                        '-infinity'::TIMESTAMPTZ);
        v_next.txt_name := CASE WHEN v_cert_newer
          THEN COALESCE(NULLIF(v_evt ->> 'txt_name', ''), v_cur.txt_name)
          ELSE COALESCE(v_cur.txt_name, NULLIF(v_evt ->> 'txt_name', '')) END;
        v_next.dt_start := CASE WHEN v_cert_newer
          THEN COALESCE(NULLIF(v_evt ->> 'dt_start', '')::DATE, v_cur.dt_start)
          ELSE COALESCE(v_cur.dt_start, NULLIF(v_evt ->> 'dt_start', '')::DATE) END;
        v_next.dt_end := CASE WHEN v_cert_newer
          THEN COALESCE(NULLIF(v_evt ->> 'dt_end', '')::DATE, v_cur.dt_end)
          ELSE COALESCE(v_cur.dt_end, NULLIF(v_evt ->> 'dt_end', '')::DATE) END;
        v_next.txt_location := CASE WHEN v_cert_newer
          THEN COALESCE(NULLIF(v_evt ->> 'txt_location', ''), v_cur.txt_location)
          ELSE COALESCE(v_cur.txt_location, NULLIF(v_evt ->> 'txt_location', '')) END;
        v_next.txt_country := CASE WHEN v_cert_newer
          THEN COALESCE(NULLIF(v_evt ->> 'txt_country', ''), v_cur.txt_country)
          ELSE COALESCE(v_cur.txt_country, NULLIF(v_evt ->> 'txt_country', '')) END;
        -- Weapons compare as a set; an empty list from CERT is a blank.
        v_arr_weapons := NULLIF(ARRAY(SELECT DISTINCT w FROM unnest(v_arr_weapons) AS w ORDER BY w), '{}');
        IF v_arr_weapons IS NOT NULL
           AND (v_cert_newer OR cardinality(COALESCE(v_cur.arr_weapons, '{}')) = 0)
           AND ARRAY(SELECT DISTINCT w FROM unnest(v_cur.arr_weapons) AS w ORDER BY w)
               IS DISTINCT FROM v_arr_weapons THEN
          v_next.arr_weapons := v_arr_weapons;
        END IF;
        v_next.txt_venue_address := CASE WHEN v_cert_newer
          THEN COALESCE(NULLIF(v_evt ->> 'txt_venue_address', ''), v_cur.txt_venue_address)
          ELSE COALESCE(v_cur.txt_venue_address, NULLIF(v_evt ->> 'txt_venue_address', '')) END;
        v_next.url_invitation := CASE WHEN v_cert_newer
          THEN COALESCE(NULLIF(v_evt ->> 'url_invitation', ''), v_cur.url_invitation)
          ELSE COALESCE(v_cur.url_invitation, NULLIF(v_evt ->> 'url_invitation', '')) END;
        -- D7 A holds either way: an event page on PROD gives way to a letter.
        IF v_next.url_invitation ~* c_page
           AND NULLIF(v_evt ->> 'url_invitation', '') !~* c_page THEN
          v_next.url_invitation := v_evt ->> 'url_invitation';
        END IF;
        -- Our own registration link is never copied and never replaced.
        IF NOT COALESCE(v_cur.url_registration ~* c_our_link, FALSE)
           AND NOT COALESCE(NULLIF(v_evt ->> 'url_registration', '') ~* c_our_link, FALSE) THEN
          v_next.url_registration := CASE WHEN v_cert_newer
            THEN COALESCE(NULLIF(v_evt ->> 'url_registration', ''), v_cur.url_registration)
            ELSE COALESCE(v_cur.url_registration, NULLIF(v_evt ->> 'url_registration', '')) END;
        END IF;
        -- The fee compares as a number: 50.0 from CERT is PROD's 50.
        v_fee := NULLIF(v_evt ->> 'num_entry_fee', '')::NUMERIC;
        IF v_fee IS NOT NULL AND v_fee IS DISTINCT FROM v_cur.num_entry_fee
           AND (v_cert_newer OR v_cur.num_entry_fee IS NULL) THEN
          v_next.num_entry_fee := v_fee;
        END IF;
        v_next.txt_entry_fee_currency := CASE WHEN v_cert_newer
          THEN COALESCE(NULLIF(v_evt ->> 'txt_entry_fee_currency', ''), v_cur.txt_entry_fee_currency)
          ELSE COALESCE(v_cur.txt_entry_fee_currency, NULLIF(v_evt ->> 'txt_entry_fee_currency', '')) END;
      END IF;

      -- Outside the details, as before. Admin enrichment fills a blank, so an
      -- edit made on PROD stands; the registration switch is not synced (it is
      -- per-environment: registration may be off on CERT and on in PROD).
      v_next.dt_registration_deadline := COALESCE(
        v_cur.dt_registration_deadline, NULLIF(v_evt ->> 'dt_registration_deadline', '')::DATE);
      v_next.num_entry_fee_2w := COALESCE(
        v_cur.num_entry_fee_2w, NULLIF(v_evt ->> 'num_entry_fee_2w', '')::NUMERIC);
      v_next.num_entry_fee_3w := COALESCE(
        v_cur.num_entry_fee_3w, NULLIF(v_evt ->> 'num_entry_fee_3w', '')::NUMERIC);
      v_next.url_entry_list := COALESCE(v_cur.url_entry_list, NULLIF(v_evt ->> 'url_entry_list', ''));
      v_next.txt_organizer_email := COALESCE(
        v_cur.txt_organizer_email, NULLIF(v_evt ->> 'txt_organizer_email', ''));
      -- btrim so a whitespace-only CERT value counts as absent (migration
      -- 20260902000001).
      v_next.txt_payee := COALESCE(v_cur.txt_payee, NULLIF(btrim(COALESCE(v_evt ->> 'txt_payee', '')), ''));
      v_next.txt_iban := COALESCE(v_cur.txt_iban, NULLIF(btrim(COALESCE(v_evt ->> 'txt_iban', '')), ''));
      -- Planning lifecycle, forward only (ADR-086 amendment): CERT owns
      -- PLANNING, PROD owns RESULTS. Only the three transitions automation is
      -- permitted to make; a row at IN_PROGRESS/SCORED/COMPLETED is never
      -- touched.
      v_next.enum_status := CASE
        WHEN (v_cur.enum_status::TEXT, NULLIF(v_evt ->> 'enum_status', '')) IN (
          ('CREATED', 'PLANNED'),
          ('CREATED', 'CANCELLED'),
          ('PLANNED', 'CANCELLED')
        ) THEN (v_evt ->> 'enum_status')::enum_event_status
        ELSE v_cur.enum_status
      END;
      -- Set once and never moved: PROD receives it only when missing.
      v_next.dt_start_first_published := COALESCE(
        v_cur.dt_start_first_published, NULLIF(v_evt ->> 'dt_start_first_published', '')::DATE);

      IF (to_jsonb(v_next) - 'ts_updated') IS DISTINCT FROM (to_jsonb(v_cur) - 'ts_updated') THEN
        UPDATE tbl_event SET
          txt_code = v_next.txt_code,
          txt_name = v_next.txt_name,
          dt_start = v_next.dt_start,
          dt_end = v_next.dt_end,
          txt_location = v_next.txt_location,
          txt_country = v_next.txt_country,
          id_organizer = v_next.id_organizer,
          arr_weapons = v_next.arr_weapons,
          id_evf_event = v_next.id_evf_event,
          id_evf_calendar_event = v_next.id_evf_calendar_event,
          txt_evf_slug = v_next.txt_evf_slug,
          id_pzsz_event = v_next.id_pzsz_event,
          url_invitation = v_next.url_invitation,
          url_registration = v_next.url_registration,
          dt_registration_deadline = v_next.dt_registration_deadline,
          num_entry_fee = v_next.num_entry_fee,
          txt_entry_fee_currency = v_next.txt_entry_fee_currency,
          txt_venue_address = v_next.txt_venue_address,
          id_prior_event = v_next.id_prior_event,
          num_entry_fee_2w = v_next.num_entry_fee_2w,
          num_entry_fee_3w = v_next.num_entry_fee_3w,
          url_entry_list = v_next.url_entry_list,
          txt_organizer_email = v_next.txt_organizer_email,
          txt_payee = v_next.txt_payee,
          txt_iban = v_next.txt_iban,
          enum_status = v_next.enum_status,
          dt_start_first_published = v_next.dt_start_first_published,
          ts_updated = NOW()
        WHERE id_event = v_id_event;
        v_updated := v_updated + 1;
      END IF;
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
