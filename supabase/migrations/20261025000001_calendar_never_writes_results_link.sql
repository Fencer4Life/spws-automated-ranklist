-- =============================================================================
-- Calendar automation never writes an event's results link
-- =============================================================================
-- url_event … url_event_5 (Admin: "URL wyników") stay empty until an
-- administrator fills them in the Admin UI. Until now three calendar functions
-- wrote them: the EVF URL refresh filled an empty slot with the scraped EVF
-- event page, the CERT→PROD calendar mirror copied CERT's slots into PROD
-- (on CREATE) and filled PROD's empty ones (on UPDATE), and the older
-- two-argument EVF calendar ingest wrote the scraped page. The PZSz calendar
-- sync wrote the pzszerm.pl event page with its own INSERT (fixed in
-- python/scrapers/pzsz_sync.py). The organizer's letter keeps going to
-- url_invitation ("URL komunikatu"), with the same fill rules as before.
--
-- 1. fn_refresh_evf_event_urls, fn_mirror_events_to_prod and
--    fn_ingest_evf_calendar(JSONB, INT) are redefined without the results
--    slots; every other column keeps its rule. The refresh no longer compacts
--    the slots, because it no longer writes them. fn_ingest_evf_calendar
--    (JSONB, INT) also loses two variables it never read (v_event_id,
--    v_url_reg), which plpgsql_check reports.
-- 2. fn_clear_calendar_results_links() removes the calendar pages the scrapers
--    wrote before this rule (the pzszerm.pl event page, the veteransfencing.eu
--    event page) from the results slots of every event whose season has not
--    ended, keeps any value an administrator set (an admin save in
--    tbl_audit_log that changed the slot to it; a save of the form for
--    another field repeats the slot unchanged and does not count), never touches
--    a closed season, and closes the gaps (fn_compact_urls). It runs here for
--    CERT and PROD, and from seed_post_backfill.sql after a fresh bootstrap,
--    where this migration runs before the seed is loaded.
--
-- pgTAP: supabase/tests/114_calendar_never_writes_results_link.sql
-- (CALURL.10–15). pytest: python/tests/test_calendar_results_link.py
-- (CALURL.01–07). Plan: doc/plans/pzsz-results-url-rca-2026-10-25.html.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_refresh_evf_event_urls(p_updates jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_upd       JSONB;
  v_touched   INT := 0;
  v_refreshed INT := 0;
  v_row_cnt   INT;
BEGIN
  FOR v_upd IN SELECT * FROM jsonb_array_elements(p_updates)
  LOOP
    DECLARE
      v_id              INT  := (v_upd ->> 'id_event')::INT;
      v_url_invitation  TEXT := NULLIF(v_upd ->> 'url_invitation', '');
      v_url_register    TEXT := NULLIF(v_upd ->> 'url_registration', '');
      v_reg_deadline    DATE := NULLIF(v_upd ->> 'dt_registration_deadline', '')::DATE;
      v_addr            TEXT := NULLIF(v_upd ->> 'address', '');
      v_fee             NUMERIC := NULLIF(v_upd ->> 'fee', '')::NUMERIC;
      v_curr            TEXT := NULLIF(v_upd ->> 'fee_currency', '');
      v_weapons_json    JSONB := v_upd -> 'weapons';
      v_weapons         enum_weapon_type[];
    BEGIN
      IF v_id IS NULL THEN
        CONTINUE;
      END IF;

      IF v_weapons_json IS NOT NULL AND jsonb_typeof(v_weapons_json) = 'array' THEN
        SELECT ARRAY(
          SELECT (value #>> '{}')::enum_weapon_type
            FROM jsonb_array_elements(v_weapons_json)
        ) INTO v_weapons;
        IF v_weapons = '{}'::enum_weapon_type[] THEN
          v_weapons := NULL;
        END IF;
      END IF;

      -- Fill-blank refresh of the calendar fields. The results slots are
      -- Admin's alone and are not written here.
      UPDATE tbl_event
         SET url_invitation = CASE
               WHEN url_invitation IS NULL OR url_invitation = ''
                 THEN COALESCE(v_url_invitation, url_invitation)
               ELSE url_invitation
             END,
             url_registration = CASE
               WHEN url_registration IS NULL OR url_registration = ''
                 THEN COALESCE(v_url_register, url_registration)
               ELSE url_registration
             END,
             dt_registration_deadline = CASE
               WHEN dt_registration_deadline IS NULL
                 THEN COALESCE(v_reg_deadline, dt_registration_deadline)
               ELSE dt_registration_deadline
             END,
             txt_venue_address = CASE
               WHEN txt_venue_address IS NULL OR txt_venue_address = ''
                 THEN COALESCE(v_addr, txt_venue_address)
               ELSE txt_venue_address
             END,
             num_entry_fee = CASE
               WHEN num_entry_fee IS NULL
                 THEN COALESCE(v_fee, num_entry_fee)
               ELSE num_entry_fee
             END,
             txt_entry_fee_currency = CASE
               WHEN txt_entry_fee_currency IS NULL OR txt_entry_fee_currency = ''
                 THEN COALESCE(v_curr, txt_entry_fee_currency)
               ELSE txt_entry_fee_currency
             END,
             arr_weapons = CASE
               WHEN arr_weapons IS NULL
                 THEN COALESCE(v_weapons, arr_weapons)
               ELSE arr_weapons
             END,
             ts_updated = NOW()
       WHERE id_event = v_id;

      GET DIAGNOSTICS v_row_cnt = ROW_COUNT;
      v_touched := v_touched + 1;
      IF v_row_cnt > 0 THEN
        v_refreshed := v_refreshed + 1;
      END IF;
    END;
  END LOOP;

  RETURN jsonb_build_object('touched', v_touched, 'refreshed', v_refreshed);
END;
$function$;

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
        -- The pzszerm.pl identity follows id_evf_event (Q5 A, 6 Oct 2026): CERT's
        -- id wins when it sends one, PROD keeps its own when CERT sends none.
        -- promote_event needs it to read the start lists (ADR-111).
        id_pzsz_event = COALESCE(NULLIF(v_evt ->> 'id_pzsz_event', '')::INT, id_pzsz_event),
        -- No results slot: PROD's results links are set in Admin only.
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
        -- D5 (ADR-116 §9): a PZSz event's address is a scraped fact the
        -- calendar run owns and corrects on CERT, so for a PZSz event CERT
        -- OVERWRITES PROD -- CERT's value wins when it sends one, and an empty
        -- CERT value leaves PROD's standing. A hand fix on CERT reached PROD on
        -- 21 October only by writing both by hand; D5 removes that need. Every
        -- other event keeps the fill-blank policy of its siblings: a value
        -- already on PROD stands, an empty PROD field is seeded from CERT. The
        -- event counts as PZSz when the payload or the PROD row carries an
        -- id_pzsz_event.
        txt_venue_address = CASE
          WHEN NULLIF(v_evt ->> 'id_pzsz_event', '') IS NOT NULL OR id_pzsz_event IS NOT NULL
            THEN COALESCE(NULLIF(v_evt ->> 'txt_venue_address', ''), txt_venue_address)
          ELSE COALESCE(txt_venue_address, NULLIF(v_evt ->> 'txt_venue_address', ''))
        END,
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
        -- The payment account is admin enrichment like its siblings: a PROD
        -- value stands, an empty PROD field is seeded from CERT. btrim so a
        -- whitespace-only CERT value counts as absent rather than as data --
        -- one definition of "absent" across the sync, the resolution and the
        -- toggle guard (migration 20260902000001).
        txt_payee = COALESCE(txt_payee, NULLIF(btrim(COALESCE(v_evt ->> 'txt_payee', '')), '')),
        txt_iban  = COALESCE(txt_iban,  NULLIF(btrim(COALESCE(v_evt ->> 'txt_iban',  '')), '')),
        -- bool_use_spws_registration is NOT synced. It is a PER-ENVIRONMENT
        -- operational switch, not shared configuration: registration may be
        -- deliberately off on CERT and on in PROD. The column is NOT NULL, so
        -- CERT always states a value and any COALESCE here is an unconditional
        -- overwrite -- which would have switched off a live PROD form holding 18
        -- entries. The CREATE branch still seeds a new event from CERT; after
        -- that PROD owns it. Joins ts_ftl_sent and the provenance block as a
        -- PROD-owned fact (ADR-086).
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

CREATE OR REPLACE FUNCTION public.fn_ingest_evf_calendar(p_events jsonb, p_id_season integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_evt          JSONB;
  v_evf_org      INT;
  v_alloc        RECORD;
  v_kind         TEXT;
  v_created      INT := 0;
  v_slot_reused  INT := 0;
  v_prior_match  INT := 0;
  v_alerts       JSONB := '[]'::JSONB;
  v_identity_code  TEXT;
  v_identity_prior INT;
BEGIN
  LOCK TABLE tbl_event IN SHARE ROW EXCLUSIVE MODE;

  SELECT id_organizer INTO v_evf_org FROM tbl_organizer WHERE txt_code = 'EVF';
  IF v_evf_org IS NULL THEN
    RAISE EXCEPTION 'fn_ingest_evf_calendar: EVF organizer not found in tbl_organizer';
  END IF;

  FOR v_evt IN SELECT * FROM jsonb_array_elements(p_events)
  LOOP
    DECLARE
      v_name      TEXT    := v_evt ->> 'name';
      v_dt_start  DATE    := (v_evt ->> 'dt_start')::DATE;
      v_dt_end    DATE    := COALESCE((v_evt ->> 'dt_end')::DATE, (v_evt ->> 'dt_start')::DATE);
      v_location  TEXT    := COALESCE(v_evt ->> 'location', '');
      v_country   TEXT    := COALESCE(v_evt ->> 'country', '');
      v_is_team   BOOLEAN := COALESCE((v_evt ->> 'is_team')::BOOLEAN, FALSE);
      v_url_inv   TEXT    := COALESCE(v_evt ->> 'url_invitation', '');
      v_addr      TEXT    := COALESCE(v_evt ->> 'address', '');
      v_evf_id    INT     := NULLIF(v_evt ->> 'evf_id', '')::INT;
      v_evf_slug  TEXT    := NULLIF(v_evt ->> 'evf_slug', '');
    BEGIN
      v_kind := fn_classify_evf_event(v_name, v_is_team);

      -- Identity pre-check: an evf_id or evf_slug match on an existing
      -- CURRENT-SEASON row wins outright, regardless of location — this is
      -- what closes the blank-location blind spot (evf.56).
      v_identity_code := NULL;
      IF v_evf_id IS NOT NULL THEN
        SELECT txt_code, id_prior_event INTO v_identity_code, v_identity_prior
          FROM tbl_event WHERE id_season = p_id_season AND id_evf_event = v_evf_id;
      END IF;
      IF v_identity_code IS NULL AND v_evf_slug IS NOT NULL THEN
        SELECT txt_code, id_prior_event INTO v_identity_code, v_identity_prior
          FROM tbl_event WHERE id_season = p_id_season AND txt_evf_slug = v_evf_slug;
      END IF;

      IF v_identity_code IS NOT NULL THEN
        SELECT v_identity_code AS txt_code, v_identity_prior AS id_prior_event,
               'CURRENT_SLOT_REUSE' AS alloc_path
          INTO v_alloc;
      ELSE
        SELECT * INTO v_alloc
          FROM fn_allocate_evf_event_code(p_id_season, v_kind, v_location, v_country);
      END IF;

      IF v_alloc.alloc_path = 'CURRENT_SLOT_REUSE' THEN
        UPDATE tbl_event SET
          txt_name      = v_name,
          dt_start      = v_dt_start,
          dt_end        = v_dt_end,
          txt_location  = NULLIF(v_location, ''),
          txt_country   = NULLIF(v_country, ''),
          txt_venue_address = COALESCE(NULLIF(v_addr, ''), txt_venue_address),
          url_invitation = COALESCE(NULLIF(v_url_inv, ''), url_invitation),
          id_evf_event  = COALESCE(v_evf_id, id_evf_event),
          txt_evf_slug  = COALESCE(v_evf_slug, txt_evf_slug),
          enum_status   = 'PLANNED'
        WHERE txt_code = v_alloc.txt_code AND id_season = p_id_season;
        v_slot_reused := v_slot_reused + 1;
      ELSE
        IF EXISTS (SELECT 1 FROM tbl_event
                    WHERE txt_code = v_alloc.txt_code AND id_season = p_id_season) THEN
          CONTINUE;
        END IF;

        INSERT INTO tbl_event (
          txt_code, txt_name, id_season, id_organizer,
          dt_start, dt_end, txt_location, txt_country,
          txt_venue_address, url_invitation,
          enum_status, id_prior_event, id_evf_event, txt_evf_slug
        ) VALUES (
          v_alloc.txt_code, v_name, p_id_season, v_evf_org,
          v_dt_start, v_dt_end,
          NULLIF(v_location, ''), NULLIF(v_country, ''),
          NULLIF(v_addr, ''), NULLIF(v_url_inv, ''),
          'PLANNED', v_alloc.id_prior_event, v_evf_id, v_evf_slug
        );

        IF v_alloc.alloc_path = 'PRIOR_SEASON_MATCH' THEN
          v_prior_match := v_prior_match + 1;
        ELSE
          v_created := v_created + 1;
          v_alerts := v_alerts || jsonb_build_object(
            'code',     v_alloc.txt_code,
            'location', v_location,
            'country',  v_country
          );
        END IF;
      END IF;

      -- No child tournaments are created here (ADR-096). A CREATED/PLANNED
      -- event carries event-level facts only; a bracket is created by results
      -- ingestion (fn_find_or_create_tournament), never by calendar discovery.
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'created',       v_created,
    'slot_reused',   v_slot_reused,
    'prior_matched', v_prior_match,
    'alerts',        v_alerts
  );
END;
$function$;


CREATE OR REPLACE FUNCTION fn_clear_calendar_results_links()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
-- The calendar pages a scraper put into an event's results slots, removed:
-- seasons that have not ended only, never a value an administrator set, the
-- remaining slots closed up. Returns the number of events changed. Idempotent.
DECLARE
  v_page CONSTANT TEXT :=
    '^https?://(www\.)?(pzszerm\.pl/zawody/kalendarium-zawodow/zawody/|veteransfencing\.eu/event/)';
  v_changed INT := 0;
  v_row     RECORD;
  v_slots   TEXT[];
  v_kept    TEXT[];
  v_url     TEXT;
BEGIN
  FOR v_row IN
    SELECT e.id_event,
           ARRAY[e.url_event, e.url_event_2, e.url_event_3, e.url_event_4, e.url_event_5] AS slots
      FROM tbl_event e
      JOIN tbl_season s ON s.id_season = e.id_season
     WHERE s.dt_end >= CURRENT_DATE
       AND (e.url_event ~* v_page OR e.url_event_2 ~* v_page OR e.url_event_3 ~* v_page
            OR e.url_event_4 ~* v_page OR e.url_event_5 ~* v_page)
     ORDER BY e.id_event
  LOOP
    v_slots := v_row.slots;
    v_kept := ARRAY[]::TEXT[];
    FOREACH v_url IN ARRAY v_slots LOOP
      IF v_url IS NULL OR btrim(v_url) = '' THEN
        CONTINUE;
      END IF;
      -- An administrator's value is one an admin save changed a results slot
      -- to; a save of the form for another field repeats the slot unchanged.
      IF v_url ~* v_page AND NOT EXISTS (
           SELECT 1
             FROM tbl_audit_log a
             CROSS JOIN LATERAL jsonb_each_text(a.jsonb_new_values) AS n(k, v)
            WHERE a.txt_table_name = 'tbl_event'
              AND a.id_row = v_row.id_event
              AND a.txt_admin_user IS NOT NULL
              AND n.k IN ('url_event', 'url_event_2', 'url_event_3', 'url_event_4', 'url_event_5')
              AND n.v = v_url
              AND (a.jsonb_old_values ->> n.k) IS DISTINCT FROM n.v) THEN
        CONTINUE;
      END IF;
      v_kept := v_kept || v_url;
    END LOOP;
    v_kept := fn_compact_urls(v_kept[1], v_kept[2], v_kept[3], v_kept[4], v_kept[5]);
    IF v_kept IS DISTINCT FROM v_slots THEN
      UPDATE tbl_event
         SET url_event   = v_kept[1],
             url_event_2 = v_kept[2],
             url_event_3 = v_kept[3],
             url_event_4 = v_kept[4],
             url_event_5 = v_kept[5]
       WHERE id_event = v_row.id_event;
      v_changed := v_changed + 1;
    END IF;
  END LOOP;
  RETURN v_changed;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_clear_calendar_results_links() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_clear_calendar_results_links() TO service_role;

DO $clear$
BEGIN
  RAISE NOTICE 'calendar pages removed from results slots: % event(s)', fn_clear_calendar_results_links();
END;
$clear$;
