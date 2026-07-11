-- =============================================================================
-- CERT->PROD event reconciler (ADR pending sign-off — supersedes the
-- calendar-delta half of ADR-026; ADR-039 rev 3 / ADR-028 amendment for the
-- ingest identity pre-check; ADR-077 amendment for the skeleton slimming)
-- =============================================================================
-- Three defects in the old calendar-promotion path, all the same root
-- mistake ("this path only ever sees EVF"):
--   1. fn_import_evf_events hardcoded `WHERE txt_code = 'SPWS'` for every
--      promoted event's organizer, never verified — confirmed live on 7
--      mistagged Samorin rows on PROD.
--   2. It was insert-or-refresh only, no DELETE — it could introduce
--      divergence from CERT but never remove it. The 6 dead Samorin
--      duplicates it created had no route to removal.
--   3. It filtered to PEW/MEW codes only — domestic PPW/MPW events added
--      after season go-live had no incremental route to PROD at all.
-- A fourth, upstream defect fed duplicates into the pipe in the first
-- place: fn_allocate_evf_event_code's location-matching Steps A/B are both
-- gated `IF v_loc_key <> ''`, so a venue-less future event skipped both
-- and Step C minted a fresh code on every call.
--
-- This migration:
--   - Replaces fn_import_evf_events with fn_mirror_events_to_prod — a full
--     Create/Update/Delete reconciler over the WHOLE active-season event
--     set, keyed on txt_code, organizer-agnostic (id_organizer arrives
--     pre-resolved by code in the payload; SQL still validates it exists —
--     fail loud, never guess).
--   - Renames fn_import_evf_events_v2 -> fn_ingest_evf_calendar and adds an
--     identity-first pre-check (evf_id / evf_slug) before the location-
--     gated allocator, closing the blank-location blind spot at the SQL
--     layer (mirrors the Python id->slug->fuzzy ladder shipped 2026-07-10).
--   - Slims fn_promote_season_skeleton to season row + scoring_config only
--     — event C/U/D is now owned entirely by fn_mirror_events_to_prod.
-- =============================================================================


-- =============================================================================
-- fn_mirror_events_to_prod — replaces fn_import_evf_events
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_mirror_events_to_prod(
  p_creates JSONB DEFAULT '[]'::JSONB,
  p_updates JSONB DEFAULT '[]'::JSONB,
  p_deletes JSONB DEFAULT '[]'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
  -- ---- CREATE: CERT \ PROD ----
  IF jsonb_array_length(p_creates) > 0 THEN
    FOR v_evt IN SELECT * FROM jsonb_array_elements(p_creates)
    LOOP
      -- Idempotency: skip (never error) if this code already exists on PROD.
      IF EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = v_evt ->> 'txt_code') THEN
        CONTINUE;
      END IF;

      -- Fail loud: id_organizer must already resolve on PROD. No hardcoded
      -- organizer literal anywhere in this function — the caller resolves
      -- the CERT-verified organizer code to a PROD id (by txt_code, never
      -- a raw cross-env id) and this is the guard that refuses to guess
      -- if that resolution came back empty or wrong.
      v_id_org := (v_evt ->> 'id_organizer')::INT;
      IF v_id_org IS NULL OR NOT EXISTS (SELECT 1 FROM tbl_organizer WHERE id_organizer = v_id_org) THEN
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
        arr_weapons, id_prior_event, id_evf_event, txt_evf_slug
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
        NULLIF(v_evt ->> 'num_entry_fee', '')::NUMERIC, NULLIF(v_evt ->> 'txt_entry_fee_currency', ''),
        v_arr_weapons, (v_evt ->> 'id_prior_event')::INT,
        (v_evt ->> 'id_evf_event')::INT, NULLIF(v_evt ->> 'txt_evf_slug', '')
      );
      v_created := v_created + 1;
    END LOOP;
  END IF;

  -- ---- UPDATE: CERT ∩ PROD, split by field ownership ----
  -- Identity fields (source-owned) overwrite from CERT. Admin-owned URL
  -- fields are fill-blank-only (never clobber a hand entry — reuses the
  -- same contract fn_refresh_evf_event_urls already enforces, kept as a
  -- separate function since it is shared/locked by pgTAP 15.6).
  -- enum_status, tournaments and results are never touched — owned by the
  -- results lifecycle (promote_event).
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
        txt_name      = COALESCE(v_evt ->> 'txt_name', txt_name),
        dt_start      = COALESCE(NULLIF(v_evt ->> 'dt_start', '')::DATE, dt_start),
        dt_end        = COALESCE(NULLIF(v_evt ->> 'dt_end', '')::DATE, dt_end),
        txt_location  = COALESCE(v_evt ->> 'txt_location', txt_location),
        txt_country   = COALESCE(v_evt ->> 'txt_country', txt_country),
        id_organizer  = COALESCE((v_evt ->> 'id_organizer')::INT, id_organizer),
        arr_weapons   = COALESCE(v_arr_weapons, arr_weapons),
        id_evf_event  = COALESCE((v_evt ->> 'id_evf_event')::INT, id_evf_event),
        txt_evf_slug  = COALESCE(v_evt ->> 'txt_evf_slug', txt_evf_slug),
        -- fill-blank-only admin fields
        url_event                = COALESCE(url_event, NULLIF(v_evt ->> 'url_event', '')),
        url_event_2              = COALESCE(url_event_2, NULLIF(v_evt ->> 'url_event_2', '')),
        url_event_3              = COALESCE(url_event_3, NULLIF(v_evt ->> 'url_event_3', '')),
        url_event_4              = COALESCE(url_event_4, NULLIF(v_evt ->> 'url_event_4', '')),
        url_event_5              = COALESCE(url_event_5, NULLIF(v_evt ->> 'url_event_5', '')),
        url_invitation           = COALESCE(url_invitation, NULLIF(v_evt ->> 'url_invitation', '')),
        url_registration         = COALESCE(url_registration, NULLIF(v_evt ->> 'url_registration', '')),
        dt_registration_deadline = COALESCE(dt_registration_deadline, NULLIF(v_evt ->> 'dt_registration_deadline', '')::DATE),
        num_entry_fee            = COALESCE(num_entry_fee, NULLIF(v_evt ->> 'num_entry_fee', '')::NUMERIC),
        txt_entry_fee_currency   = COALESCE(txt_entry_fee_currency, NULLIF(v_evt ->> 'txt_entry_fee_currency', '')),
        ts_updated = NOW()
      WHERE id_event = v_id_event;

      IF FOUND THEN v_updated := v_updated + 1; END IF;
    END LOOP;
  END IF;

  -- ---- DELETE: PROD \ CERT, guarded ----
  -- Only a PLANNED event with zero results across its tournaments may be
  -- deleted. A results-bearing event absent from CERT is a CERT anomaly to
  -- alert on (the caller inspects delete_skipped), never erased — once an
  -- event has results its status leaves PLANNED, so it is structurally
  -- untouchable here regardless of what the caller passed.
  IF jsonb_array_length(p_deletes) > 0 THEN
    FOR v_id_event IN SELECT (value)::INT FROM jsonb_array_elements_text(p_deletes) AS value
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
$$;

REVOKE EXECUTE ON FUNCTION fn_mirror_events_to_prod(JSONB, JSONB, JSONB) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_mirror_events_to_prod(JSONB, JSONB, JSONB) TO authenticated;

DROP FUNCTION IF EXISTS fn_import_evf_events(JSONB, INT);


-- =============================================================================
-- fn_ingest_evf_calendar — renamed from fn_import_evf_events_v2, plus an
-- identity-first pre-check that closes the blank-location allocator blind
-- spot: a current-season row already carrying this evf_id/evf_slug is
-- reused directly (bypassing fn_allocate_evf_event_code's location-gated
-- Steps A/B entirely) BEFORE falling through to location-based allocation.
-- Mirrors the id -> slug -> fuzzy ladder the Python scraper already uses
-- (_find_existing_match, shipped 2026-07-10) at the SQL layer too, so a
-- venue-less repeat scrape can never mint a second row even if the Python
-- dedup is ever bypassed.
-- =============================================================================
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
  v_weapon       TEXT;
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
      v_weapons   JSONB   := COALESCE(v_evt -> 'weapons', '[]'::JSONB);
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

      FOR v_weapon IN SELECT jsonb_array_elements_text(v_weapons)
      LOOP
        INSERT INTO tbl_tournament (
          id_event, txt_code, txt_name, enum_type,
          enum_weapon, enum_gender, enum_age_category,
          dt_tournament, int_participant_count, enum_import_status
        )
        SELECT
          v_event_id,
          v_alloc.txt_code || '-M-' || v_weapon,
          v_name,
          v_kind::enum_tournament_type,
          v_weapon::enum_weapon_type, 'M', 'V2',
          v_dt_start, 0, 'PLANNED'
        WHERE NOT EXISTS (
          SELECT 1 FROM tbl_tournament
          WHERE txt_code = v_alloc.txt_code || '-M-' || v_weapon
        );

        INSERT INTO tbl_tournament (
          id_event, txt_code, txt_name, enum_type,
          enum_weapon, enum_gender, enum_age_category,
          dt_tournament, int_participant_count, enum_import_status
        )
        SELECT
          v_event_id,
          v_alloc.txt_code || '-F-' || v_weapon,
          v_name,
          v_kind::enum_tournament_type,
          v_weapon::enum_weapon_type, 'F', 'V2',
          v_dt_start, 0, 'PLANNED'
        WHERE NOT EXISTS (
          SELECT 1 FROM tbl_tournament
          WHERE txt_code = v_alloc.txt_code || '-F-' || v_weapon
        );
      END LOOP;
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

REVOKE EXECUTE ON FUNCTION fn_ingest_evf_calendar(JSONB, INT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_ingest_evf_calendar(JSONB, INT) TO authenticated;

DROP FUNCTION IF EXISTS fn_import_evf_events_v2(JSONB, INT);


-- =============================================================================
-- fn_promote_season_skeleton — slimmed to season row + scoring_config only.
-- Event C/U/D is now owned entirely by fn_mirror_events_to_prod; the
-- events block + its sequence advance are removed. The payload's 'events'
-- key, if a stale caller still sends one, is silently ignored (48.2).
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_promote_season_skeleton(p_payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_season  JSONB := p_payload -> 'season';
  v_sc      JSONB := p_payload -> 'scoring_config';
  v_code    TEXT  := v_season ->> 'txt_code';
  v_id      INT   := (v_season ->> 'id_season')::INT;
  v_cols    TEXT;
BEGIN
  IF v_season IS NULL OR v_code IS NULL OR v_id IS NULL THEN
    RAISE EXCEPTION 'fn_promote_season_skeleton: payload.season must include txt_code + id_season';
  END IF;

  -- Childless guard (caller asserts the SOURCE season has no tournament children).
  IF COALESCE((p_payload ->> 'source_childless')::BOOLEAN, FALSE) IS NOT TRUE THEN
    RAISE EXCEPTION
      'fn_promote_season_skeleton: refused — source season % is not childless (results may exist)', v_code;
  END IF;

  -- Idempotency: never overwrite an existing season on the target.
  IF EXISTS (SELECT 1 FROM tbl_season WHERE txt_code = v_code) THEN
    RAISE EXCEPTION 'fn_promote_season_skeleton: season % already exists on target', v_code;
  END IF;

  -- Insert only the columns PRESENT in the payload object so omitted columns
  -- (ts_created, defaults, …) keep their DEFAULT — jsonb_populate_record would
  -- otherwise null them and violate NOT-NULL. Column-agnostic: survives schema
  -- additions without code change.

  -- Season with explicit id. trg_season_auto_config creates a default scoring_config.
  SELECT string_agg(quote_ident(key), ', ') INTO v_cols FROM jsonb_object_keys(v_season) AS key;
  EXECUTE format(
    'INSERT INTO tbl_season (%1$s) SELECT %1$s FROM jsonb_populate_record(NULL::tbl_season, $1)',
    v_cols
  ) USING v_season;

  -- Replace the auto-created scoring_config with the promoted values (id_season
  -- carried in the payload row).
  IF v_sc IS NOT NULL AND v_sc <> 'null'::JSONB THEN
    -- id_config is tbl_scoring_config's OWN serial PK (independent of id_season);
    -- drop it so the promoted row gets a fresh one — copying the source's id_config
    -- collides with an existing target config. All config lookups key on id_season.
    v_sc := v_sc - 'id_config';
    DELETE FROM tbl_scoring_config WHERE id_season = v_id;
    SELECT string_agg(quote_ident(key), ', ') INTO v_cols FROM jsonb_object_keys(v_sc) AS key;
    EXECUTE format(
      'INSERT INTO tbl_scoring_config (%1$s) SELECT %1$s FROM jsonb_populate_record(NULL::tbl_scoring_config, $1)',
      v_cols
    ) USING v_sc;
  END IF;

  -- Advance the season sequence past the explicit id so later allocations
  -- don't collide. (Event sequence advance removed — events are no longer
  -- promoted here.)
  PERFORM setval('tbl_season_id_season_seq', GREATEST((SELECT MAX(id_season) FROM tbl_season), 1));

  RETURN jsonb_build_object(
    'season_code', v_code,
    'id_season', v_id
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_promote_season_skeleton(JSONB) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_promote_season_skeleton(JSONB) TO authenticated;
