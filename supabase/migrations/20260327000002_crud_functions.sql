-- =============================================================================
-- T9.1: CRUD functions for seasons, events, tournaments
-- =============================================================================
-- ADR-016 pattern: SECURITY DEFINER + REVOKE from anon in next migration.
-- Audit triggers (trg_audit_*) fire automatically on UPDATE/DELETE.
-- Season auto-config trigger (trg_season_auto_config) fires on INSERT.
-- Tournament multiplier trigger (trg_tournament_auto_multiplier) fires on INSERT.
-- =============================================================================

-- ─── Season CRUD ─────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION fn_create_season(
  p_code     TEXT,
  p_dt_start DATE,
  p_dt_end   DATE
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_id INT;
BEGIN
  INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
  VALUES (p_code, p_dt_start, p_dt_end, FALSE)
  RETURNING id_season INTO v_id;
  RETURN v_id;
END;
$$;


CREATE OR REPLACE FUNCTION fn_update_season(
  p_id       INT,
  p_code     TEXT,
  p_dt_start DATE,
  p_dt_end   DATE
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE tbl_season
  SET txt_code = p_code,
      dt_start = p_dt_start,
      dt_end   = p_dt_end
  WHERE id_season = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Season % not found', p_id;
  END IF;
END;
$$;


CREATE OR REPLACE FUNCTION fn_delete_season(p_id INT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Delete auto-created scoring_config (always exists via trigger)
  DELETE FROM tbl_scoring_config WHERE id_season = p_id;
  -- FK RESTRICT on tbl_event will raise if events exist
  DELETE FROM tbl_season WHERE id_season = p_id;
END;
$$;


-- ─── Event CRUD ──────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION fn_create_event(
  p_code          TEXT,
  p_name          TEXT,
  p_id_season     INT,
  p_id_organizer  INT,
  p_location      TEXT    DEFAULT NULL,
  p_dt_start      DATE    DEFAULT NULL,
  p_dt_end        DATE    DEFAULT NULL,
  p_url_event     TEXT    DEFAULT NULL,
  p_country       TEXT    DEFAULT NULL,
  p_venue_address TEXT    DEFAULT NULL,
  p_invitation    TEXT    DEFAULT NULL,
  p_entry_fee     NUMERIC DEFAULT NULL
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_id INT;
BEGIN
  INSERT INTO tbl_event (
    txt_code, txt_name, id_season, id_organizer,
    txt_location, dt_start, dt_end, url_event,
    txt_country, txt_venue_address, url_invitation, num_entry_fee
  ) VALUES (
    p_code, p_name, p_id_season, p_id_organizer,
    p_location, p_dt_start, p_dt_end, p_url_event,
    p_country, p_venue_address, p_invitation, p_entry_fee
  )
  RETURNING id_event INTO v_id;
  RETURN v_id;
END;
$$;


CREATE OR REPLACE FUNCTION fn_update_event(
  p_id            INT,
  p_name          TEXT,
  p_location      TEXT,
  p_dt_start      DATE,
  p_dt_end        DATE,
  p_url_event     TEXT,
  p_country       TEXT,
  p_venue_address TEXT,
  p_invitation    TEXT,
  p_entry_fee     NUMERIC
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE tbl_event
  SET txt_name          = p_name,
      txt_location      = p_location,
      dt_start          = p_dt_start,
      dt_end            = p_dt_end,
      url_event         = p_url_event,
      txt_country       = p_country,
      txt_venue_address = p_venue_address,
      url_invitation    = p_invitation,
      num_entry_fee     = p_entry_fee,
      ts_updated        = NOW()
  WHERE id_event = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Event % not found', p_id;
  END IF;
END;
$$;


-- ─── Tournament CRUD ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION fn_create_tournament(
  p_id_event          INT,
  p_code              TEXT,
  p_name              TEXT,
  p_type              enum_tournament_type,
  p_weapon            enum_weapon_type,
  p_gender            enum_gender_type,
  p_age_category      enum_age_category,
  p_dt_tournament     DATE    DEFAULT NULL,
  p_participant_count INT     DEFAULT NULL,
  p_url_results       TEXT    DEFAULT NULL
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_id INT;
BEGIN
  INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, url_results
  ) VALUES (
    p_id_event, p_code, p_name, p_type,
    p_weapon, p_gender, p_age_category,
    p_dt_tournament, p_participant_count, p_url_results
  )
  RETURNING id_tournament INTO v_id;
  RETURN v_id;
END;
$$;


CREATE OR REPLACE FUNCTION fn_update_tournament(
  p_id            INT,
  p_url_results   TEXT,
  p_import_status enum_import_status,
  p_status_reason TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE tbl_tournament
  SET url_results              = p_url_results,
      enum_import_status       = p_import_status,
      txt_import_status_reason = p_status_reason,
      ts_updated               = NOW()
  WHERE id_tournament = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tournament % not found', p_id;
  END IF;
END;
$$;
