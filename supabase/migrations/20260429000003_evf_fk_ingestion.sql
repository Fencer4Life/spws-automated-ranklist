-- =============================================================================
-- EVF FK columns — wire ingestion RPCs to populate id_evf_event /
-- id_evf_competition.
-- =============================================================================
-- Three RPCs touched (signatures stay backwards-compatible — new params are
-- optional with NULL default):
--
--   fn_import_evf_events_v2          — calendar-path bulk importer.
--                                      JSONB rows can now include `evf_id`,
--                                      written to tbl_event.id_evf_event.
--                                      Old payloads (no `evf_id`) still work,
--                                      column stays NULL.
--   fn_create_evf_event_from_results — results-path event creator. Adds
--                                      optional `p_id_evf_event`.
--   fn_find_or_create_tournament     — per-(weapon, gender, category)
--                                      tournament finder. Adds optional
--                                      `p_id_evf_competition`.
--
-- Domestic FTL/XML/Engarde scrapers don't call any of these with FK args, so
-- their tournament rows continue to have NULL id_evf_competition.
-- =============================================================================


-- =============================================================================
-- fn_import_evf_events_v2 — calendar-path bulk importer (extended)
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
  LOCK TABLE tbl_event IN SHARE ROW EXCLUSIVE MODE;

  SELECT id_organizer INTO v_evf_org FROM tbl_organizer WHERE txt_code = 'EVF';
  IF v_evf_org IS NULL THEN
    RAISE EXCEPTION 'fn_import_evf_events_v2: EVF organizer not found in tbl_organizer';
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
    BEGIN
      v_kind := fn_classify_evf_event(v_name, v_is_team);

      SELECT * INTO v_alloc
        FROM fn_allocate_evf_event_code(p_id_season, v_kind, v_location, v_country);

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
          enum_status, id_prior_event, id_evf_event
        ) VALUES (
          v_alloc.txt_code, v_name, p_id_season, v_evf_org,
          v_dt_start, v_dt_end,
          NULLIF(v_location, ''), NULLIF(v_country, ''),
          NULLIF(v_addr, ''), NULLIF(v_url_event, ''), NULLIF(v_url_inv, ''),
          'PLANNED', v_alloc.id_prior_event, v_evf_id
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

REVOKE EXECUTE ON FUNCTION fn_import_evf_events_v2(JSONB, INT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_import_evf_events_v2(JSONB, INT) TO authenticated;


-- =============================================================================
-- fn_create_evf_event_from_results — adds optional p_id_evf_event
-- Drop the prior 6-arg signature so the new 7-arg form is unambiguous when
-- called via DEFAULT (otherwise both signatures collide).
-- =============================================================================
DROP FUNCTION IF EXISTS fn_create_evf_event_from_results(INT, TEXT, DATE, TEXT, TEXT, BOOLEAN);

CREATE OR REPLACE FUNCTION fn_create_evf_event_from_results(
  p_id_season   INT,
  p_name        TEXT,
  p_dt_start    DATE,
  p_location    TEXT,
  p_country     TEXT,
  p_is_team     BOOLEAN,
  p_id_evf_event INT DEFAULT NULL
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

  SELECT o.id_organizer INTO v_evf_org FROM tbl_organizer o WHERE o.txt_code = 'EVF';
  IF v_evf_org IS NULL THEN
    RAISE EXCEPTION 'fn_create_evf_event_from_results: EVF organizer not found';
  END IF;

  v_kind := fn_classify_evf_event(p_name, p_is_team);

  SELECT * INTO v_alloc
    FROM fn_allocate_evf_event_code(p_id_season, v_kind, p_location, p_country);

  IF EXISTS (SELECT 1 FROM tbl_event ev
              WHERE ev.txt_code = v_alloc.txt_code AND ev.id_season = p_id_season) THEN
    SELECT e.id_event INTO v_id_evt FROM tbl_event e
      WHERE e.txt_code = v_alloc.txt_code AND e.id_season = p_id_season;
    -- Backfill id_evf_event when a new value is supplied and the row had NULL.
    IF p_id_evf_event IS NOT NULL THEN
      UPDATE tbl_event SET id_evf_event = p_id_evf_event
        WHERE id_event = v_id_evt AND id_evf_event IS NULL;
    END IF;
    id_event := v_id_evt;
    txt_code := v_alloc.txt_code;
    RETURN NEXT; RETURN;
  END IF;

  INSERT INTO tbl_event (
    txt_code, txt_name, id_season, id_organizer,
    dt_start, dt_end, txt_location, txt_country,
    enum_status, id_prior_event, id_evf_event
  ) VALUES (
    v_alloc.txt_code, p_name, p_id_season, v_evf_org,
    p_dt_start, p_dt_start,
    NULLIF(p_location, ''), NULLIF(p_country, ''),
    'COMPLETED', v_alloc.id_prior_event, p_id_evf_event
  ) RETURNING tbl_event.id_event INTO v_id_evt;

  id_event := v_id_evt;
  txt_code := v_alloc.txt_code;
  RETURN NEXT;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_create_evf_event_from_results(INT, TEXT, DATE, TEXT, TEXT, BOOLEAN, INT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_create_evf_event_from_results(INT, TEXT, DATE, TEXT, TEXT, BOOLEAN, INT) TO authenticated;


-- =============================================================================
-- fn_find_or_create_tournament — adds optional p_id_evf_competition
-- Drop the prior 6-arg signature so the new 7-arg form is unambiguous when
-- called via DEFAULT (otherwise both signatures collide for 6-arg callers).
-- =============================================================================
DROP FUNCTION IF EXISTS fn_find_or_create_tournament(INT, enum_weapon_type, enum_gender_type, enum_age_category, DATE, enum_tournament_type);

CREATE OR REPLACE FUNCTION fn_find_or_create_tournament(
  p_event_id           INT,
  p_weapon             enum_weapon_type,
  p_gender             enum_gender_type,
  p_age_category       enum_age_category,
  p_date               DATE,
  p_type               enum_tournament_type,
  p_id_evf_competition INT DEFAULT NULL
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tourn_id    INT;
  v_event_code  TEXT;
  v_season_code TEXT;
  v_tourn_code  TEXT;
BEGIN
  SELECT t.id_tournament INTO v_tourn_id
  FROM tbl_tournament t
  WHERE t.id_event = p_event_id
    AND t.enum_weapon = p_weapon
    AND t.enum_gender = p_gender
    AND t.enum_age_category = p_age_category;

  IF v_tourn_id IS NOT NULL THEN
    -- Backfill id_evf_competition when supplied and currently NULL.
    IF p_id_evf_competition IS NOT NULL THEN
      UPDATE tbl_tournament
         SET id_evf_competition = p_id_evf_competition
       WHERE id_tournament = v_tourn_id AND id_evf_competition IS NULL;
    END IF;
    RETURN v_tourn_id;
  END IF;

  SELECT e.txt_code, s.txt_code
    INTO v_event_code, v_season_code
  FROM tbl_event e
  JOIN tbl_season s ON s.id_season = e.id_season
  WHERE e.id_event = p_event_id;

  IF v_event_code IS NULL THEN
    RAISE EXCEPTION 'Event % does not exist', p_event_id;
  END IF;

  v_event_code := regexp_replace(v_event_code, '-\d{4}-\d{4}$', '');
  v_tourn_code := v_event_code || '-' || p_age_category || '-' || p_gender || '-' || p_weapon || '-' || v_season_code;
  v_tourn_code := regexp_replace(v_tourn_code, '-SPWS-(\d{4}-\d{4})$', '-\1');

  INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, enum_import_status,
    id_evf_competition
  ) VALUES (
    p_event_id, v_tourn_code,
    p_age_category || ' ' || p_gender || ' ' || p_weapon,
    p_type, p_weapon, p_gender, p_age_category,
    p_date, 0, 'PLANNED', p_id_evf_competition
  )
  RETURNING id_tournament INTO v_tourn_id;

  RETURN v_tourn_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_find_or_create_tournament(INT, enum_weapon_type, enum_gender_type, enum_age_category, DATE, enum_tournament_type, INT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_find_or_create_tournament(INT, enum_weapon_type, enum_gender_type, enum_age_category, DATE, enum_tournament_type, INT) TO authenticated;
