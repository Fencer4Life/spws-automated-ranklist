-- =============================================================================
-- A CREATED/PLANNED event carries event-level facts only (ADR-096)
-- =============================================================================
-- Amends ADR-028 §Calendar Scraping (tournament creation), ADR-046 (canonical tournament code
-- formula gains one shared implementation). Relates to ADR-091 (the same
-- "a skeleton is a PREDICTION of a row that is going to arrive anyway" ruling,
-- one layer up, for events instead of brackets), ADR-081 (the CERT->PROD
-- reconciler, whose CREATE path is already childless -- test 51.1b -- and
-- needs no change here).
--
-- WHY. fn_import_evf_events (ADR-028, April 2026) minted one stub
-- tbl_tournament row per weapon x gender at calendar-import time, hardcoded to
-- V2, int_participant_count 0. Every justification has expired: the old
-- ±3-day/EXISTS(tournament) dedup marker is gone, replaced by Python's
-- _find_existing_match id->slug->fuzzy ladder; arr_weapons now carries the
-- weapon/type facts a child row used to be the only home for (migration
-- 20260904000001, test 71); and vw_calendar.bool_has_international's frontend
-- consumer already falls back to the code prefix. The predicted SHAPE was also
-- always wrong: a real EVF weekend ends with 10-23 brackets across V1-V4, not
-- 2-6 at V2 only.
--
-- This is worse than a shape mismatch. The loop survives, unchanged, in
-- exactly one live function: the 2-arg fn_ingest_evf_calendar (this migration
-- is the first to touch it since 20260711000001). Because
-- fn_ingest_evf_calendar_identity_v1 delegates every pre-terminal event to it
-- on EVERY sync -- not just newly-created ones -- an event that already holds
-- a real, results-backed bracket gets TWO MORE stub rows injected alongside it
-- on every single calendar refresh, guarded only by a string match against the
-- stub's OWN code shape (which the real bracket never has, so the guard never
-- fires). The stub and the real bracket then collide the next time the event
-- renumbers, because the rebuild rewrites every child of that event to the
-- same canonical formula in one UPDATE -- reproduced locally in
-- 79_no_bracket_stubs.sql 79.3b, and observed live as run 34468447030:
--   23505: duplicate key value violates unique constraint "idx_tournament_code"
--   Key (txt_code)=(PEW13es-2026-2027-V2-M-EPEE) already exists.
--
-- Measured reach at time of writing: CERT 154 stub rows / 19 events (68
-- duplicate bracket pairs among them), PROD 82 stub rows / 18 events, zero
-- rows anywhere failing only ONE of the six prune guards below, zero scored
-- brackets touched.
--
-- THE FIX, four pieces:
--   1. Delete the whole weapon-loop INSERT from the 2-arg fn_ingest_evf_calendar.
--      A bracket is now created only by results ingestion
--      (fn_find_or_create_tournament), never by calendar discovery.
--   2. fn_rebuild_tournament_codes -- the one shared implementation of the
--      ADR-046 canonical formula, extracted from fn_update_event's existing
--      sniff-and-rebuild block (a child carrying '-V\d-' rebuilds canonical;
--      one that doesn't keeps the placeholder shape), hardened to park EVERY
--      child on a neutral code before rebuilding any of them, so an A->B, B->C
--      shuffle within one event cannot self-collide.
--   3. fn_ingest_evf_calendar_identity_v1's inline park-and-rebuild block is
--      replaced by a call to the shared helper.
--   4. fn_update_event is refactored onto the same helper, so the admin rename
--      path and the calendar reflow path agree by construction.
--   5. fn_prune_bracket_stubs() removes the stubs already on CERT/PROD, guarded
--      exactly as measured above.
--
-- NOT DONE: a UNIQUE index on (id_event, cat, gender, weapon). It would have
-- converted a recurrence into a local insert failure, and the natural key is
-- real -- fn_find_or_create_tournament already treats it as one, and PROD has
-- zero violations across all 788 scored rows. But at least four pgTAP fixtures
-- predating this change (01_database_foundation, 02_scoring_engine,
-- 03_views_api, 05_calendar_view) deliberately share ONE throwaway event
-- across several synthetic tournaments distinguished only by enum_type, all
-- at the same (V2, M, EPEE) -- a convention this index would break broadly,
-- for files this defect has nothing to do with. Pieces 1-4 above fully remove
-- the defect without it; the plan named this an optional hardening for
-- exactly this reason ("strike this step if a uniqueness constraint is not
-- wanted"). Worth reconsidering once/if those fixtures are ever untangled.
--
-- Plan-test-ID 79 (supabase/tests/79_no_bracket_stubs.sql).
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. fn_rebuild_tournament_codes -- one shared implementation of ADR-046.
--
-- Extracted from fn_update_event's existing shape-sniffing block
-- (20260902000002), with two hardenings over BOTH prior copies (fn_update_event
-- and identity_v1's own inline block): the sniff is bool_or() across ALL of the
-- event's children instead of an unordered LIMIT 1 (a single-row sample could
-- pick the "wrong" shape when a stub and a real bracket briefly coexist), and
-- every child is parked on a neutral placeholder BEFORE any of them is
-- rebuilt, so a shuffle that would otherwise have one child's new code collide
-- with a sibling's still-old code cannot -- the exact shape of the failure
-- this migration exists to fix.
--
-- ADR-083 deny-by-default: this function stays OFF the anon-EXECUTEable
-- allowlist. Neither 52_security_posture.sql (52.7) nor
-- scripts/check-security-posture.sh needs an edit, and the deploy-time
-- check-anon-allowlist-sync.sql gate stays green.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_rebuild_tournament_codes(
  p_id_event      INT,
  p_new_event_code TEXT
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_kind     TEXT;
  v_new_suffix   TEXT;
  v_is_canonical BOOLEAN;
  v_renamed      INT := 0;
BEGIN
  SELECT bool_or(txt_code ~ '-V\d-') INTO v_is_canonical
    FROM tbl_tournament WHERE id_event = p_id_event;

  IF v_is_canonical IS NULL THEN
    RETURN 0;  -- no children: nothing to rebuild (the now-common case)
  END IF;

  -- Park every child on a neutral code first, so the rebuild below can never
  -- have one child's new code collide with a sibling's still-old one.
  UPDATE tbl_tournament SET txt_code = '__tcode_' || id_tournament::TEXT
   WHERE id_event = p_id_event;

  IF v_is_canonical THEN
    v_new_kind   := regexp_replace(p_new_event_code, '-\d{4}-\d{4}$', '');
    v_new_suffix := COALESCE((regexp_match(p_new_event_code, '(\d{4}-\d{4})$'))[1], '');

    UPDATE tbl_tournament t
       SET txt_code = v_new_kind
                      || '-' || t.enum_age_category::TEXT
                      || '-' || t.enum_gender::TEXT
                      || '-' || t.enum_weapon::TEXT
                      || CASE WHEN v_new_suffix = '' THEN ''
                              ELSE '-' || v_new_suffix END
     WHERE t.id_event = p_id_event;
  ELSE
    UPDATE tbl_tournament t
       SET txt_code = p_new_event_code
                      || '-' || t.enum_gender::TEXT
                      || '-' || t.enum_weapon::TEXT
     WHERE t.id_event = p_id_event;
  END IF;

  GET DIAGNOSTICS v_renamed = ROW_COUNT;
  RETURN v_renamed;
END;
$$;

REVOKE ALL ON FUNCTION fn_rebuild_tournament_codes(INT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION fn_rebuild_tournament_codes(INT, TEXT) FROM anon;
REVOKE ALL ON FUNCTION fn_rebuild_tournament_codes(INT, TEXT) FROM authenticated;

COMMENT ON FUNCTION fn_rebuild_tournament_codes(INT, TEXT) IS
  'The one implementation of the ADR-046 tournament-code formula, shared by '
  'fn_update_event (admin rename) and fn_ingest_evf_calendar_identity_v1 '
  '(calendar reflow). Sniffs the canonical vs placeholder dialect from the '
  'event''s existing children (bool_or over all of them, not a single sample), '
  'parks every child before rebuilding any of them so an A->B, B->C shuffle '
  'cannot self-collide. Returns 0 for a childless event. Not anon-EXECUTEable '
  '(ADR-083); internal to the two callers above.';

-- -----------------------------------------------------------------------------
-- 2. fn_update_event: refactor its inline sniff-and-rebuild block onto the
--    shared helper. Behavior is unchanged (same sniff rule, same two dialects);
--    only the implementation is now shared rather than duplicated.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_update_event(p_id integer, p_name text, p_location text, p_dt_start date, p_dt_end date, p_url_event text, p_country text, p_venue_address text, p_invitation text, p_entry_fee numeric, p_entry_fee_currency text DEFAULT NULL::text, p_id_organizer integer DEFAULT NULL::integer, p_weapons enum_weapon_type[] DEFAULT NULL::enum_weapon_type[], p_registration text DEFAULT NULL::text, p_registration_deadline date DEFAULT NULL::date, p_url_event_2 text DEFAULT NULL::text, p_url_event_3 text DEFAULT NULL::text, p_url_event_4 text DEFAULT NULL::text, p_url_event_5 text DEFAULT NULL::text, p_code text DEFAULT NULL::text, p_id_prior_event integer DEFAULT NULL::integer, p_use_spws_registration boolean DEFAULT NULL::boolean, p_entry_fee_2w numeric DEFAULT NULL::numeric, p_entry_fee_3w numeric DEFAULT NULL::numeric, p_url_entry_list text DEFAULT NULL::text, p_txt_organizer_email text DEFAULT NULL::text, p_payee text DEFAULT NULL::text, p_iban text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_compact      TEXT[];
  v_old_code     TEXT;
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
      PERFORM fn_rebuild_tournament_codes(p_id, p_code);
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

-- CREATE OR REPLACE preserves the existing REVOKE/GRANT posture on this
-- signature (set by 20260902000002); no repeat needed here.

-- -----------------------------------------------------------------------------
-- 3. fn_ingest_evf_calendar_identity_v1: replace the inline park-and-rebuild
--    block with a call to the shared helper. Everything else is carried
--    forward verbatim from 20260828000007 (which itself reproduced
--    20260828000005/6 and the prior-link amendments in 20260808000001/2).
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
        PERFORM fn_rebuild_tournament_codes(v_existing_id, v_desired_code);
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

-- -----------------------------------------------------------------------------
-- 4. The 2-arg fn_ingest_evf_calendar: delete the weapon-loop stub INSERT.
--    This is the whole behavioral change -- everything else in this function
--    (identity pre-check, allocate, CURRENT_SLOT_REUSE / CREATE) is carried
--    forward verbatim from 20260711000001.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_ingest_evf_calendar(
  p_events    JSONB,
  p_id_season INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_evt          JSONB;
  v_evf_org      INT;
  v_alloc        RECORD;
  v_event_id     INT;
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
      v_url_event TEXT    := COALESCE(v_evt ->> 'url_event', '');
      v_url_inv   TEXT    := COALESCE(v_evt ->> 'url_invitation', '');
      v_url_reg   TEXT    := COALESCE(v_evt ->> 'url_registration', '');
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
          url_event     = COALESCE(NULLIF(v_url_event, ''), url_event),
          url_invitation = COALESCE(NULLIF(v_url_inv, ''), url_invitation),
          id_evf_event  = COALESCE(v_evf_id, id_evf_event),
          txt_evf_slug  = COALESCE(v_evf_slug, txt_evf_slug),
          enum_status   = 'PLANNED'
        WHERE txt_code = v_alloc.txt_code AND id_season = p_id_season
        RETURNING id_event INTO v_event_id;
        v_slot_reused := v_slot_reused + 1;
      ELSE
        IF EXISTS (SELECT 1 FROM tbl_event
                    WHERE txt_code = v_alloc.txt_code AND id_season = p_id_season) THEN
          CONTINUE;
        END IF;

        INSERT INTO tbl_event (
          txt_code, txt_name, id_season, id_organizer,
          dt_start, dt_end, txt_location, txt_country,
          txt_venue_address, url_event, url_invitation,
          enum_status, id_prior_event, id_evf_event, txt_evf_slug
        ) VALUES (
          v_alloc.txt_code, v_name, p_id_season, v_evf_org,
          v_dt_start, v_dt_end,
          NULLIF(v_location, ''), NULLIF(v_country, ''),
          NULLIF(v_addr, ''), NULLIF(v_url_event, ''), NULLIF(v_url_inv, ''),
          'PLANNED', v_alloc.id_prior_event, v_evf_id, v_evf_slug
        ) RETURNING id_event INTO v_event_id;

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
$$;

-- CREATE OR REPLACE preserves the existing REVOKE/GRANT posture on this
-- signature (set by 20260711000001); no repeat needed here.

-- -----------------------------------------------------------------------------
-- 5. fn_prune_bracket_stubs() -- idempotent removal of the stubs the loop
--    above already created, on CERT and PROD. Shaped like
--    fn_prune_unclaimed_evf_skeletons (20260906000001): every clause is a
--    guard against deleting something real, not a filter of convenience.
--
--    A row is deleted only when ALL of:
--      - its event is CREATED/PLANNED/SCHEDULED/CHANGED/CANCELLED (a stub
--        under a terminal-status event would mean results exist -- excluded
--        by the next clause anyway, but the event-status check is the first,
--        cheapest filter and documents the intent);
--      - enum_import_status = 'PLANNED' (a stub is never scored);
--      - int_participant_count is 0 or NULL (a stub never carries entrants);
--      - url_results IS NULL (a stub is never pointed at a results page);
--      - no tbl_result row exists for it (the load-bearing guard: a real
--        bracket, however it got its code, is never touched);
--      - no tbl_tournament_ingest_history row exists for it (a bracket that
--        was ever committed through the ingest pipeline is never touched,
--        even if its results were later cleared).
--
--    Measured reach 2026-09-12: CERT 154 rows / 19 events, PROD 82 rows / 18
--    events; zero rows anywhere fail only ONE of these six guards.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_prune_bracket_stubs()
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_deleted INTEGER;
BEGIN
  WITH gone AS (
    DELETE FROM tbl_tournament t
    USING tbl_event e
    WHERE t.id_event = e.id_event
      AND e.enum_status IN ('CREATED','PLANNED','SCHEDULED','CHANGED','CANCELLED')
      AND t.enum_import_status = 'PLANNED'
      AND COALESCE(t.int_participant_count, 0) = 0
      AND t.url_results IS NULL
      AND NOT EXISTS (SELECT 1 FROM tbl_result r WHERE r.id_tournament = t.id_tournament)
      AND NOT EXISTS (
            SELECT 1 FROM tbl_tournament_ingest_history h
             WHERE h.id_tournament = t.id_tournament)
    RETURNING 1
  )
  SELECT COUNT(*)::INTEGER INTO v_deleted FROM gone;
  RETURN v_deleted;
END;
$$;

COMMENT ON FUNCTION fn_prune_bracket_stubs() IS
  'Delete calendar-created bracket stubs: PLANNED import status, zero/NULL '
  'participant count, no url_results, no result, no ingest history, under a '
  'non-terminal event. Idempotent. Called by migration 20260913000002 for live '
  'environments and by seed_post_backfill.sql for fresh bootstraps, where '
  'migrations run before the seed dump. Returns the row count. ADR-096.';

REVOKE ALL ON FUNCTION fn_prune_bracket_stubs() FROM PUBLIC;
REVOKE ALL ON FUNCTION fn_prune_bracket_stubs() FROM anon;
REVOKE ALL ON FUNCTION fn_prune_bracket_stubs() FROM authenticated;

SELECT fn_prune_bracket_stubs();

-- No uniqueness index on (id_event, cat, gender, weapon) -- see the file
-- header for why: pieces 1-4 above already remove the defect, and at least
-- four pre-existing pgTAP fixtures deliberately share one bracket tuple
-- across several synthetic tournaments under a single throwaway event.

COMMIT;
