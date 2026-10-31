-- =============================================================================
-- An event's details: one contract for every calendar scraper on CERT, and a
-- newer CERT write carried to PROD (ADR-118)
-- =============================================================================
-- The details are nine fields, eleven columns: name, start and end date, city,
-- country, weapons, venue address, invitation letter, the organizer's
-- registration link, and the entry fee with its currency.
--
-- CERT. Every calendar scraper writes them through fn_calendar_apply_fields:
--   1 an empty field takes the source's value (an event page in the letter
--     counts as empty, ADR-117 D7 A);
--   2 a source that changed replaces the scraper's own earlier value;
--   3 a value a person set is kept, and the source's different value is
--     reported once (S2 A);
--   4 a blank from the source clears nothing;
--   5 our own register.html link is never written by a scraper.
-- tbl_calendar_field_state holds, per event and field, the value the scraper
-- last wrote. With no state yet the audit decides: a value a person last set
-- is the person's, any other is the scraper's. EVF's calendar ingest, identity
-- sync and refresh stop writing the details themselves (the ingest blanked a
-- city and country a person had set, F1); EVF's weapons stay with its code
-- (ADR-089).
--
-- PROD. fn_mirror_events_to_prod takes all nine from CERT when CERT wrote them
-- later than PROD did (the payload's ts_details_set against
-- fn_event_details_set_at); a blank on CERT clears nothing (S1 A); our own
-- registration link is never copied or replaced; an event with nothing to
-- change is not written (F2). A payload without ts_details_set keeps the
-- earlier rules.
--
-- Plan: doc/plans/cert-event-details-reach-prod-every-scraper-2026-10-31.html.
-- Tests: supabase/tests/117_mirror_cert_event_details.sql (CALSYNC.01-16),
-- 118_calendar_field_contract.sql (CALSYNC.20-39).
-- =============================================================================

-- Per event and detail: the value the scraper last wrote (NULL when it has
-- written none: the current value is a person's) and the source value last
-- reported as held, so a held value is reported once.
CREATE TABLE IF NOT EXISTS tbl_calendar_field_state (
  id_event      INT NOT NULL REFERENCES tbl_event (id_event) ON DELETE CASCADE,
  txt_field     TEXT NOT NULL CONSTRAINT ck_calendar_field_state_field
                  CHECK (txt_field IN ('txt_name', 'dt_start', 'dt_end', 'txt_location',
                         'txt_country', 'arr_weapons', 'txt_venue_address', 'url_invitation',
                         'url_registration', 'num_entry_fee', 'txt_entry_fee_currency')),
  txt_scraper   TEXT NOT NULL,
  txt_value     TEXT,
  txt_reported  TEXT,
  ts_written    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id_event, txt_field)
);

COMMENT ON TABLE tbl_calendar_field_state IS
  'ADR-118: per event and detail, the value the calendar scraper last wrote (NULL: a person''s value) and the held source value last reported. CERT only; service_role only; not in the PROD seed (ADR-036).';

ALTER TABLE tbl_calendar_field_state ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON tbl_calendar_field_state FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON tbl_calendar_field_state TO service_role;

-- When an environment last wrote an event's details: the latest audited change
-- to any of the nine, else the row's creation (the audit records no INSERT).
-- promote.py reads CERT's time with the same expression inline.
CREATE OR REPLACE FUNCTION public.fn_event_details_set_at(p_id_event integer)
 RETURNS timestamp with time zone
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT COALESCE(
    (SELECT max(a.ts_created)
       FROM tbl_audit_log a
      WHERE a.txt_table_name = 'tbl_event'
        AND a.id_row = p_id_event
        AND a.txt_action = 'UPDATE'
        AND EXISTS (
          SELECT 1
            FROM unnest(ARRAY['txt_name', 'dt_start', 'dt_end', 'txt_location', 'txt_country',
                              'arr_weapons', 'txt_venue_address', 'url_invitation',
                              'url_registration', 'num_entry_fee',
                              'txt_entry_fee_currency']) AS f(name)
           WHERE (a.jsonb_old_values -> f.name) IS DISTINCT FROM (a.jsonb_new_values -> f.name))),
    (SELECT e.ts_created FROM tbl_event e WHERE e.id_event = p_id_event))
$function$;

REVOKE EXECUTE ON FUNCTION fn_event_details_set_at(INT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_event_details_set_at(INT) TO service_role;

CREATE OR REPLACE FUNCTION public.fn_calendar_apply_fields(p_scraper text, p_events jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  -- The nine details and the type each compares and is written as.
  c_types CONSTANT JSONB := jsonb_build_object(
    'txt_name', 'text', 'dt_start', 'date', 'dt_end', 'date', 'txt_location', 'text',
    'txt_country', 'text', 'arr_weapons', 'enum_weapon_type[]', 'txt_venue_address', 'text',
    'url_invitation', 'text', 'url_registration', 'text', 'num_entry_fee', 'numeric',
    'txt_entry_fee_currency', 'text');
  c_our_link CONSTANT TEXT := '/register\.html\?event=';
  c_page     CONSTANT TEXT :=
    '^https?://(www\.)?(pzszerm\.pl/zawody/kalendarium-zawodow/zawody/|veteransfencing\.eu/event/)';
  v_evt      JSONB;
  v_id       INT;
  v_code     TEXT;
  v_field    TEXT;
  v_value    JSONB;
  v_type     TEXT;
  v_src      TEXT;
  v_col      TEXT;
  v_new      TEXT;
  v_cur      TEXT;
  v_same     BOOLEAN;
  v_owner    BOOLEAN;
  v_person   BOOLEAN;
  v_state    tbl_calendar_field_state%ROWTYPE;
  v_has      BOOLEAN;
  v_written  JSONB := '[]'::JSONB;
  v_held     JSONB := '[]'::JSONB;
BEGIN
  FOR v_evt IN SELECT * FROM jsonb_array_elements(COALESCE(p_events, '[]'::JSONB))
  LOOP
    v_id := NULLIF(v_evt ->> 'id_event', '')::INT;
    -- The row stays locked to the end of the call, so a person's save cannot
    -- land between the read and the write (compare-and-set).
    SELECT txt_code INTO v_code FROM tbl_event WHERE id_event = v_id FOR UPDATE;
    CONTINUE WHEN NOT FOUND;

    FOR v_field, v_value IN SELECT key, value FROM jsonb_each(COALESCE(v_evt -> 'fields', '{}'::JSONB))
    LOOP
      v_type := c_types ->> v_field;
      IF v_type IS NULL THEN
        RAISE EXCEPTION 'fn_calendar_apply_fields: % is not one of the event details', v_field;
      END IF;

      -- The source's value as text in the column's input form; blank is NULL.
      IF jsonb_typeof(v_value) = 'array' THEN
        SELECT '{' || string_agg(x, ',') || '}' INTO v_src
          FROM jsonb_array_elements_text(v_value) AS x WHERE btrim(x) <> '';
      ELSE
        v_src := NULLIF(btrim(v_value #>> '{}'), '');
      END IF;
      CONTINUE WHEN v_src IS NULL;                                           -- rule 4
      CONTINUE WHEN v_field = 'url_registration' AND v_src ~* c_our_link;    -- rule 5

      -- Weapons compare and land as a sorted set; every other field as itself.
      IF v_field = 'arr_weapons' THEN
        v_col := 'ARRAY(SELECT DISTINCT w FROM unnest(arr_weapons) AS w ORDER BY w)';
        v_new := 'ARRAY(SELECT DISTINCT w FROM unnest($1::enum_weapon_type[]) AS w ORDER BY w)';
      ELSE
        v_col := quote_ident(v_field);
        v_new := format('$1::%s', v_type);
      END IF;
      EXECUTE format('SELECT (%s)::TEXT, (%s) IS NOT DISTINCT FROM (%s) FROM tbl_event WHERE id_event = $2',
                     v_col, v_col, v_new)
        INTO v_cur, v_same USING v_src, v_id;

      -- Our own registration link on CERT is never replaced, nor reported.
      CONTINUE WHEN v_field = 'url_registration' AND v_cur ~* c_our_link;

      SELECT * INTO v_state FROM tbl_calendar_field_state
       WHERE id_event = v_id AND txt_field = v_field;
      v_has := FOUND;

      IF v_cur IS NULL OR v_cur IN ('', '{}')
         OR (v_field = 'url_invitation' AND v_cur ~* c_page) THEN
        v_owner := TRUE;                                                     -- rule 1
      ELSIF v_same THEN
        -- Already the source's value: from now on it is the scraper's.
        INSERT INTO tbl_calendar_field_state (id_event, txt_field, txt_scraper, txt_value)
        VALUES (v_id, v_field, p_scraper, v_cur)
        ON CONFLICT (id_event, txt_field) DO UPDATE
          SET txt_scraper = EXCLUDED.txt_scraper, txt_value = EXCLUDED.txt_value,
              txt_reported = NULL, ts_written = NOW();
        CONTINUE;
      ELSIF v_has THEN
        -- rules 2-3: the scraper owns the value only while it is what it wrote.
        IF v_state.txt_value IS NULL THEN
          v_owner := FALSE;
        ELSE
          EXECUTE format('SELECT (%s) IS NOT DISTINCT FROM (%s) FROM tbl_event WHERE id_event = $2',
                         v_col, v_new)
            INTO v_owner USING v_state.txt_value, v_id;
        END IF;
      ELSE
        -- No state yet: whoever last set the value owns it.
        SELECT a.txt_admin_user IS NOT NULL INTO v_person
          FROM tbl_audit_log a
         WHERE a.txt_table_name = 'tbl_event' AND a.id_row = v_id AND a.txt_action = 'UPDATE'
           AND (a.jsonb_old_values -> v_field) IS DISTINCT FROM (a.jsonb_new_values -> v_field)
         ORDER BY a.ts_created DESC, a.id_log DESC
         LIMIT 1;
        v_owner := NOT COALESCE(v_person, FALSE);
      END IF;

      IF v_owner THEN
        EXECUTE format('UPDATE tbl_event SET %I = %s, ts_updated = NOW() WHERE id_event = $2',
                       v_field, v_new)
          USING v_src, v_id;
        INSERT INTO tbl_calendar_field_state (id_event, txt_field, txt_scraper, txt_value)
        VALUES (v_id, v_field, p_scraper, v_src)
        ON CONFLICT (id_event, txt_field) DO UPDATE
          SET txt_scraper = EXCLUDED.txt_scraper, txt_value = EXCLUDED.txt_value,
              txt_reported = NULL, ts_written = NOW();
        v_written := v_written || jsonb_build_object(
          'id_event', v_id, 'txt_code', v_code, 'field', v_field, 'old', v_cur, 'new', v_src);
      ELSE
        -- rule 3: kept; the source's different value is reported once.
        IF NOT v_has OR v_state.txt_reported IS DISTINCT FROM v_src THEN
          v_held := v_held || jsonb_build_object(
            'id_event', v_id, 'txt_code', v_code, 'field', v_field,
            'current', v_cur, 'source', v_src);
        END IF;
        INSERT INTO tbl_calendar_field_state (id_event, txt_field, txt_scraper, txt_value, txt_reported)
        VALUES (v_id, v_field, p_scraper, NULL, v_src)
        ON CONFLICT (id_event, txt_field) DO UPDATE
          SET txt_reported = EXCLUDED.txt_reported, ts_written = NOW();
      END IF;
    END LOOP;
  END LOOP;

  RETURN jsonb_build_object('written', v_written, 'held', v_held);
END;
$function$;

REVOKE EXECUTE ON FUNCTION fn_calendar_apply_fields(TEXT, JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_calendar_apply_fields(TEXT, JSONB) TO service_role;

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
        -- ADR-118: CERT wrote its details later than PROD did, so PROD takes
        -- every one CERT holds; otherwise PROD keeps its own and only an empty
        -- field is filled. A blank on CERT never clears PROD (S1 A).
        v_cert_newer := v_ts > fn_event_details_set_at(v_id_event);
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
      v_reg_deadline    DATE := NULLIF(v_upd ->> 'dt_registration_deadline', '')::DATE;
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

      -- Fill-blank refresh of the two fields outside an event's details: the
      -- registration deadline and the weapons (which the code plan otherwise
      -- writes with the code, ADR-089). The details go through
      -- fn_calendar_apply_fields (ADR-118); the results slots are Admin's
      -- alone. The row is written only when a blank is filled (F2).
      UPDATE tbl_event
         SET dt_registration_deadline = COALESCE(dt_registration_deadline, v_reg_deadline),
             arr_weapons = COALESCE(arr_weapons, v_weapons),
             ts_updated = NOW()
       WHERE id_event = v_id
         AND ((dt_registration_deadline IS NULL AND v_reg_deadline IS NOT NULL)
              OR (arr_weapons IS NULL AND v_weapons IS NOT NULL));

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
        -- A reused slot takes its identity and status here. Its details (name,
        -- dates, city, country, address, letter) go through
        -- fn_calendar_apply_fields under the calendar contract (ADR-118):
        -- writing them here blanked a city and country a person had set
        -- whenever EVF listed none (F1). Written only when something changes.
        UPDATE tbl_event SET
          id_evf_event  = COALESCE(v_evf_id, id_evf_event),
          txt_evf_slug  = COALESCE(v_evf_slug, txt_evf_slug),
          enum_status   = 'PLANNED',
          ts_updated    = NOW()
        WHERE txt_code = v_alloc.txt_code AND id_season = p_id_season
          AND (id_evf_event IS DISTINCT FROM COALESCE(v_evf_id, id_evf_event)
               OR txt_evf_slug IS DISTINCT FROM COALESCE(v_evf_slug, txt_evf_slug)
               OR enum_status IS DISTINCT FROM 'PLANNED');
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

      -- The code and its weapons, the calendar id and the slug. The event's
      -- details (name, dates, city, country) go through
      -- fn_calendar_apply_fields under the calendar contract (ADR-118).
      -- Written only when something changes.
      UPDATE tbl_event
         SET txt_code = v_desired_code,
             arr_weapons = v_weapons_sorted,
             id_evf_calendar_event = v_calendar_id,
             txt_evf_slug = COALESCE(txt_evf_slug, v_slug),
             ts_updated = NOW()
       WHERE id_event = v_existing_id
         AND (txt_code IS DISTINCT FROM v_desired_code
              OR arr_weapons IS DISTINCT FROM v_weapons_sorted
              OR id_evf_calendar_event IS DISTINCT FROM v_calendar_id
              OR txt_evf_slug IS DISTINCT FROM COALESCE(txt_evf_slug, v_slug));
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

CREATE OR REPLACE FUNCTION fn_sync_evf_event_fields(p_updates JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_upd       JSONB;
  v_touched   INT := 0;
  v_changed   INT := 0;
  v_row_cnt   INT;
  v_id        INT;
  v_cancelled BOOLEAN;
BEGIN
  FOR v_upd IN SELECT * FROM jsonb_array_elements(p_updates)
  LOOP
    v_id := NULLIF(v_upd ->> 'id_event', '')::INT;
    IF v_id IS NULL THEN
      CONTINUE;
    END IF;
    v_touched := v_touched + 1;
    v_cancelled := COALESCE((v_upd ->> 'is_cancelled')::BOOLEAN, FALSE);

    IF v_cancelled AND EXISTS (
      SELECT 1 FROM tbl_event e
      WHERE e.id_event = v_id
        AND e.enum_status NOT IN (
          'CREATED','PLANNED','SCHEDULED','CHANGED','IN_PROGRESS','CANCELLED'
        )
    ) THEN
      RAISE EXCEPTION 'refusing to cancel EVF event % from terminal status', v_id;
    END IF;

    IF v_cancelled AND EXISTS (
      SELECT 1 FROM tbl_tournament t
      JOIN tbl_result r ON r.id_tournament = t.id_tournament
      WHERE t.id_event = v_id
    ) THEN
      RAISE EXCEPTION 'refusing to cancel EVF event % because results exist', v_id;
    END IF;

    -- The EVF identity and a cancellation. The event's details (name, dates,
    -- city, country) go through fn_calendar_apply_fields under the calendar
    -- contract (ADR-118).
    UPDATE tbl_event SET
      id_evf_event = COALESCE(id_evf_event, NULLIF(v_upd ->> 'evf_id', '')::INT),
      id_evf_calendar_event = COALESCE(
        id_evf_calendar_event, NULLIF(v_upd ->> 'evf_calendar_id', '')::BIGINT
      ),
      txt_evf_slug = COALESCE(txt_evf_slug, NULLIF(v_upd ->> 'evf_slug', '')),
      enum_status = CASE
        WHEN v_cancelled AND enum_status IN (
          'CREATED','PLANNED','SCHEDULED','CHANGED','IN_PROGRESS','CANCELLED'
        ) THEN 'CANCELLED'::enum_event_status
        ELSE enum_status
      END,
      ts_updated = NOW()
    WHERE id_event = v_id
      AND (
        id_evf_event IS DISTINCT FROM COALESCE(id_evf_event, NULLIF(v_upd ->> 'evf_id', '')::INT)
        OR id_evf_calendar_event IS DISTINCT FROM COALESCE(
          id_evf_calendar_event, NULLIF(v_upd ->> 'evf_calendar_id', '')::BIGINT
        )
        OR txt_evf_slug IS DISTINCT FROM COALESCE(txt_evf_slug, NULLIF(v_upd ->> 'evf_slug', ''))
        OR (v_cancelled AND enum_status <> 'CANCELLED')
      );

    GET DIAGNOSTICS v_row_cnt = ROW_COUNT;
    IF v_row_cnt > 0 THEN
      v_changed := v_changed + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('touched', v_touched, 'changed', v_changed);
END;
$$;
