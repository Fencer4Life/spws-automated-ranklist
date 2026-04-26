-- =============================================================================
-- Phase 2: fn_import_evf_events_v2 + fn_create_evf_event_from_results
-- =============================================================================
-- v2 invokes the allocator (Migration 20260427000001) per row instead of
-- accepting a pre-built `code` from Python. EVF organizer used
-- unconditionally. Returns per-row allocation paths so Python can fire one
-- Telegram alert per NEXT_FREE_ALLOC.
--
-- Input JSONB array shape (per row):
--   { name, dt_start, dt_end, location, country, weapons, is_team,
--     url_event?, url_invitation?, url_registration?, address?,
--     fee?, fee_currency?, dt_registration_deadline? }
--   No `code` key — allocator computes it.
--
-- Return shape:
--   { created, slot_reused, prior_matched,
--     alerts: [ { code, location, country }, ... ] }
-- =============================================================================


-- =============================================================================
-- fn_import_evf_events_v2 — calendar-path bulk importer
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_import_evf_events_v2(
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
BEGIN
  -- Race-safety: serialise concurrent EVF imports while allocating PEW numbers.
  LOCK TABLE tbl_event IN SHARE ROW EXCLUSIVE MODE;

  SELECT id_organizer INTO v_evf_org FROM tbl_organizer WHERE txt_code = 'EVF';
  IF v_evf_org IS NULL THEN
    RAISE EXCEPTION 'fn_import_evf_events_v2: EVF organizer not found in tbl_organizer';
  END IF;

  FOR v_evt IN SELECT * FROM jsonb_array_elements(p_events)
  LOOP
    DECLARE
      v_name     TEXT    := v_evt ->> 'name';
      v_dt_start DATE    := (v_evt ->> 'dt_start')::DATE;
      v_dt_end   DATE    := COALESCE((v_evt ->> 'dt_end')::DATE, (v_evt ->> 'dt_start')::DATE);
      v_location TEXT    := COALESCE(v_evt ->> 'location', '');
      v_country  TEXT    := COALESCE(v_evt ->> 'country', '');
      v_weapons  JSONB   := COALESCE(v_evt -> 'weapons', '[]'::JSONB);
      v_is_team  BOOLEAN := COALESCE((v_evt ->> 'is_team')::BOOLEAN, FALSE);
      v_url_event TEXT   := COALESCE(v_evt ->> 'url_event', '');
      v_url_inv   TEXT   := COALESCE(v_evt ->> 'url_invitation', '');
      v_url_reg   TEXT   := COALESCE(v_evt ->> 'url_registration', '');
      v_addr      TEXT   := COALESCE(v_evt ->> 'address', '');
    BEGIN
      v_kind := fn_classify_evf_event(v_name, v_is_team);

      SELECT * INTO v_alloc
        FROM fn_allocate_evf_event_code(p_id_season, v_kind, v_location, v_country);

      IF v_alloc.alloc_path = 'CURRENT_SLOT_REUSE' THEN
        -- UPDATE the pre-allocated CREATED slot in place.
        UPDATE tbl_event SET
          txt_name      = v_name,
          dt_start      = v_dt_start,
          dt_end        = v_dt_end,
          txt_location  = NULLIF(v_location, ''),
          txt_country   = NULLIF(v_country, ''),
          txt_venue_address = COALESCE(NULLIF(v_addr, ''), txt_venue_address),
          url_event     = COALESCE(NULLIF(v_url_event, ''), url_event),
          url_invitation = COALESCE(NULLIF(v_url_inv, ''), url_invitation),
          enum_status   = 'PLANNED'
        WHERE txt_code = v_alloc.txt_code AND id_season = p_id_season
        RETURNING id_event INTO v_event_id;
        v_slot_reused := v_slot_reused + 1;
      ELSE
        -- INSERT new row (PRIOR_SEASON_MATCH or NEXT_FREE_ALLOC paths).
        -- Idempotency guard: if a row with the allocated txt_code already
        -- exists in this season (admin race), skip silently.
        IF EXISTS (SELECT 1 FROM tbl_event
                    WHERE txt_code = v_alloc.txt_code AND id_season = p_id_season) THEN
          CONTINUE;
        END IF;

        INSERT INTO tbl_event (
          txt_code, txt_name, id_season, id_organizer,
          dt_start, dt_end, txt_location, txt_country,
          txt_venue_address, url_event, url_invitation,
          enum_status, id_prior_event
        ) VALUES (
          v_alloc.txt_code, v_name, p_id_season, v_evf_org,
          v_dt_start, v_dt_end,
          NULLIF(v_location, ''), NULLIF(v_country, ''),
          NULLIF(v_addr, ''), NULLIF(v_url_event, ''), NULLIF(v_url_inv, ''),
          'PLANNED', v_alloc.id_prior_event
        ) RETURNING id_event INTO v_event_id;

        IF v_alloc.alloc_path = 'PRIOR_SEASON_MATCH' THEN
          v_prior_match := v_prior_match + 1;
        ELSE  -- NEXT_FREE_ALLOC
          v_created := v_created + 1;
          v_alerts := v_alerts || jsonb_build_object(
            'code',     v_alloc.txt_code,
            'location', v_location,
            'country',  v_country
          );
        END IF;
      END IF;

      -- Create child tournaments per weapon × gender (M + F),
      -- skipping any that already exist (idempotent).
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

REVOKE EXECUTE ON FUNCTION fn_import_evf_events_v2(JSONB, INT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_import_evf_events_v2(JSONB, INT) TO authenticated;


-- =============================================================================
-- fn_create_evf_event_from_results — results-path single-event creator
-- =============================================================================
-- Used when the EVF results scraper finds an event missing from CERT and
-- wants to insert it as already-COMPLETED (results already exist by the time
-- this fires). Returns (id_event, txt_code) so the caller can log the code.
CREATE OR REPLACE FUNCTION fn_create_evf_event_from_results(
  p_id_season INT,
  p_name      TEXT,
  p_dt_start  DATE,
  p_location  TEXT,
  p_country   TEXT,
  p_is_team   BOOLEAN
)
RETURNS TABLE(id_event INT, txt_code TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_evf_org INT;
  v_kind    TEXT;
  v_alloc   RECORD;
  v_id_evt  INT;
BEGIN
  LOCK TABLE tbl_event IN SHARE ROW EXCLUSIVE MODE;

  SELECT id_organizer INTO v_evf_org FROM tbl_organizer WHERE txt_code = 'EVF';
  IF v_evf_org IS NULL THEN
    RAISE EXCEPTION 'fn_create_evf_event_from_results: EVF organizer not found';
  END IF;

  v_kind := fn_classify_evf_event(p_name, p_is_team);

  SELECT * INTO v_alloc
    FROM fn_allocate_evf_event_code(p_id_season, v_kind, p_location, p_country);

  -- Race / dup guard
  IF EXISTS (SELECT 1 FROM tbl_event
              WHERE txt_code = v_alloc.txt_code AND id_season = p_id_season) THEN
    SELECT e.id_event INTO v_id_evt FROM tbl_event e
      WHERE e.txt_code = v_alloc.txt_code AND e.id_season = p_id_season;
    id_event := v_id_evt;
    txt_code := v_alloc.txt_code;
    RETURN NEXT; RETURN;
  END IF;

  INSERT INTO tbl_event (
    txt_code, txt_name, id_season, id_organizer,
    dt_start, dt_end, txt_location, txt_country,
    enum_status, id_prior_event
  ) VALUES (
    v_alloc.txt_code, p_name, p_id_season, v_evf_org,
    p_dt_start, p_dt_start,
    NULLIF(p_location, ''), NULLIF(p_country, ''),
    'COMPLETED', v_alloc.id_prior_event
  ) RETURNING tbl_event.id_event INTO v_id_evt;

  id_event := v_id_evt;
  txt_code := v_alloc.txt_code;
  RETURN NEXT;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_create_evf_event_from_results(INT, TEXT, DATE, TEXT, TEXT, BOOLEAN) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_create_evf_event_from_results(INT, TEXT, DATE, TEXT, TEXT, BOOLEAN) TO authenticated;
