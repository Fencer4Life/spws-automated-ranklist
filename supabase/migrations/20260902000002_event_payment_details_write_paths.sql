-- =============================================================================
-- Carry the payment account through the admin RPC and the CERT->PROD mirror
-- =============================================================================
-- 20260902000001 added the columns, the vetting and the toggle guard. Two
-- write paths still could not reach them: the admin RPC had no parameters for
-- them, and the mirror did not carry them at all, so a new PROD event would
-- have arrived without the account CERT already held.
--
-- OWNERSHIP: admin enrichment, therefore FILL-BLANK -- a PROD value stands and
-- an empty PROD field is seeded from CERT. This is the tier ADR-086 states for
-- num_entry_fee*, url_entry_list and txt_organizer_email, and the payment
-- account belongs with them: it is entered by an administrator, it may
-- legitimately differ per environment while being corrected on PROD, and a
-- scheduled sync must never revert that correction.
--
-- It is deliberately NOT per-environment like bool_use_spws_registration. The
-- switch is off on CERT and on in PROD by design; the account is the same
-- account in both, so seeding it forward saves retyping and cannot cause the
-- 2026-09-01 class of incident, where a synced field silently changed a live
-- PROD state.
--
-- fn_update_event gains two parameters, so its signature changes: DROP then
-- CREATE, both inside this transaction, leaving exactly ONE overload. Two
-- overloads of one function is what made the release fingerprint
-- non-deterministic in ba4ff3a.
--
-- Plan-test-IDs 68.7-68.8 (mirror ownership) and 69.20-69.21 (the RPC).
-- =============================================================================

BEGIN;

SET LOCAL lock_timeout = '2s';

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
        txt_payee, txt_iban,
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
        -- Fill-blank, like its siblings: CERT seeds an empty PROD field, and a
        -- value already on PROD stops further propagation. Venue address is
        -- admin-entered enrichment, not a scraped fact -- unlike the dates,
        -- name, location and weapons above, which must keep overwriting or PROD
        -- goes stale when EVF moves or renames an event.
        txt_venue_address = COALESCE(
          txt_venue_address, NULLIF(v_evt ->> 'txt_venue_address', '')
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

DROP FUNCTION IF EXISTS fn_update_event(
  integer, text, text, date, date, text, text, text, text, numeric, text, integer,
  enum_weapon_type[], text, date, text, text, text, text, text, integer, boolean,
  numeric, numeric, text, text);

CREATE OR REPLACE FUNCTION public.fn_update_event(p_id integer, p_name text, p_location text, p_dt_start date, p_dt_end date, p_url_event text, p_country text, p_venue_address text, p_invitation text, p_entry_fee numeric, p_entry_fee_currency text DEFAULT NULL::text, p_id_organizer integer DEFAULT NULL::integer, p_weapons enum_weapon_type[] DEFAULT NULL::enum_weapon_type[], p_registration text DEFAULT NULL::text, p_registration_deadline date DEFAULT NULL::date, p_url_event_2 text DEFAULT NULL::text, p_url_event_3 text DEFAULT NULL::text, p_url_event_4 text DEFAULT NULL::text, p_url_event_5 text DEFAULT NULL::text, p_code text DEFAULT NULL::text, p_id_prior_event integer DEFAULT NULL::integer, p_use_spws_registration boolean DEFAULT NULL::boolean, p_entry_fee_2w numeric DEFAULT NULL::numeric, p_entry_fee_3w numeric DEFAULT NULL::numeric, p_url_entry_list text DEFAULT NULL::text, p_txt_organizer_email text DEFAULT NULL::text, p_payee text DEFAULT NULL::text, p_iban text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_compact      TEXT[];
  v_old_code     TEXT;
  v_new_kind     TEXT;
  v_new_suffix   TEXT;
  v_sample_child TEXT;
BEGIN
  v_compact := fn_compact_urls(
    p_url_event, p_url_event_2, p_url_event_3, p_url_event_4, p_url_event_5
  );

  IF p_code IS NOT NULL THEN
    SELECT txt_code INTO v_old_code FROM tbl_event WHERE id_event = p_id;
    IF v_old_code IS NULL THEN
      RAISE EXCEPTION 'Event % not found', p_id;
    END IF;

    IF p_code <> v_old_code THEN
      v_new_kind   := regexp_replace(p_code, '-\d{4}-\d{4}$', '');
      v_new_suffix := COALESCE((regexp_match(p_code, '(\d{4}-\d{4})$'))[1], '');

      SELECT txt_code INTO v_sample_child
        FROM tbl_tournament WHERE id_event = p_id LIMIT 1;

      IF v_sample_child IS NOT NULL AND v_sample_child ~ '-V\d-' THEN
        UPDATE tbl_tournament t
           SET txt_code = v_new_kind
                          || '-' || t.enum_age_category::TEXT
                          || '-' || t.enum_gender::TEXT
                          || '-' || t.enum_weapon::TEXT
                          || CASE WHEN v_new_suffix = '' THEN ''
                                  ELSE '-' || v_new_suffix END
         WHERE t.id_event = p_id;
      ELSE
        UPDATE tbl_tournament t
           SET txt_code = p_code
                          || '-' || t.enum_gender::TEXT
                          || '-' || t.enum_weapon::TEXT
         WHERE t.id_event = p_id;
      END IF;
    END IF;
  END IF;

  UPDATE tbl_event
  SET txt_code          = COALESCE(p_code, txt_code),
      txt_name          = p_name,
      txt_location      = p_location,
      dt_start          = p_dt_start,
      dt_end            = p_dt_end,
      url_event         = v_compact[1],
      txt_country       = p_country,
      txt_venue_address = p_venue_address,
      url_invitation    = p_invitation,
      num_entry_fee     = p_entry_fee,
      txt_entry_fee_currency = p_entry_fee_currency,
      id_organizer      = COALESCE(p_id_organizer, id_organizer),
      arr_weapons       = COALESCE(p_weapons, arr_weapons),
      url_registration  = p_registration,
      dt_registration_deadline = p_registration_deadline,
      url_event_2       = v_compact[2],
      url_event_3       = v_compact[3],
      url_event_4       = v_compact[4],
      url_event_5       = v_compact[5],
      id_prior_event    = CASE
                            WHEN p_id_prior_event IS NULL THEN id_prior_event
                            WHEN p_id_prior_event = -1    THEN NULL
                            ELSE p_id_prior_event
                          END,
      bool_use_spws_registration = COALESCE(
        p_use_spws_registration, bool_use_spws_registration
      ),
      num_entry_fee_2w  = COALESCE(p_entry_fee_2w, num_entry_fee_2w),
      num_entry_fee_3w  = COALESCE(p_entry_fee_3w, num_entry_fee_3w),
      url_entry_list    = p_url_entry_list,
      txt_organizer_email = CASE
        WHEN p_txt_organizer_email IS NULL THEN txt_organizer_email
        WHEN btrim(p_txt_organizer_email) = '' THEN NULL
        ELSE btrim(p_txt_organizer_email)
      END,
      -- Same idiom as the organizer e-mail above: NULL means "not stated, keep
      -- what is there", an empty or whitespace-only string means "clear it".
      -- The trim trigger normalises either way; this keeps the RPC's contract
      -- explicit rather than relying on it.
      txt_payee = CASE
        WHEN p_payee IS NULL THEN txt_payee
        WHEN btrim(p_payee) = '' THEN NULL
        ELSE btrim(p_payee)
      END,
      txt_iban = CASE
        WHEN p_iban IS NULL THEN txt_iban
        WHEN btrim(p_iban) = '' THEN NULL
        ELSE btrim(p_iban)
      END,
      ts_updated        = NOW()
  WHERE id_event = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Event % not found', p_id;
  END IF;
END;
$function$;

-- DROP FUNCTION discards the function's privileges along with it, and
-- ALTER DEFAULT PRIVILEGES (ADR-083) leaves a freshly created function with
-- PUBLIC EXECUTE. Restore the intended posture explicitly: fn_update_event is
-- an ADMIN RPC and must not be anon-callable. pgTAP 52.7 asserts the anon set
-- as an equality and catches exactly this.
REVOKE ALL ON FUNCTION fn_update_event(
  integer, text, text, date, date, text, text, text, text, numeric, text, integer,
  enum_weapon_type[], text, date, text, text, text, text, text, integer, boolean,
  numeric, numeric, text, text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION fn_update_event(
  integer, text, text, date, date, text, text, text, text, numeric, text, integer,
  enum_weapon_type[], text, date, text, text, text, text, text, integer, boolean,
  numeric, numeric, text, text, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION fn_update_event(
  integer, text, text, date, date, text, text, text, text, numeric, text, integer,
  enum_weapon_type[], text, date, text, text, text, text, text, integer, boolean,
  numeric, numeric, text, text, text, text) TO authenticated;

COMMIT;
