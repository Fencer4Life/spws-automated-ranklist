-- =============================================================================
-- ADR-030: Event Registration URL + Deadline
-- Adds url_registration and dt_registration_deadline to tbl_event.
-- Recreates vw_calendar, fn_create_event, fn_update_event with new columns.
-- =============================================================================

-- 1. Add columns
ALTER TABLE tbl_event ADD COLUMN IF NOT EXISTS url_registration TEXT;
ALTER TABLE tbl_event ADD COLUMN IF NOT EXISTS dt_registration_deadline DATE;

-- 2. Recreate vw_calendar with new columns
DROP VIEW IF EXISTS vw_calendar;
CREATE VIEW vw_calendar AS
SELECT
  e.id_event, e.txt_code, e.txt_name, e.id_season,
  s.txt_code AS txt_season_code,
  e.id_organizer, o.txt_name AS txt_organizer_name,
  e.txt_location, e.txt_country, e.txt_venue_address,
  e.url_invitation, e.num_entry_fee, e.txt_entry_fee_currency,
  e.arr_weapons,
  e.dt_start, e.dt_end, e.url_event, e.enum_status,
  e.url_registration, e.dt_registration_deadline,
  COUNT(t.id_tournament)::INT AS num_tournaments,
  COALESCE(BOOL_OR(t.enum_type IN ('PEW','MEW','MSW','PSW')), FALSE) AS bool_has_international
FROM tbl_event e
JOIN tbl_season s ON s.id_season = e.id_season
LEFT JOIN tbl_organizer o ON o.id_organizer = e.id_organizer
LEFT JOIN tbl_tournament t ON t.id_event = e.id_event
GROUP BY e.id_event, s.txt_code, o.txt_name
ORDER BY e.dt_start ASC;

GRANT SELECT ON vw_calendar TO anon;
GRANT SELECT ON vw_calendar TO authenticated;

-- 3. Drop old function signatures (14-param) before creating new ones (16-param)
DROP FUNCTION IF EXISTS fn_create_event(TEXT,TEXT,INT,INT,TEXT,DATE,DATE,TEXT,TEXT,TEXT,TEXT,NUMERIC,TEXT,enum_weapon_type[]);
DROP FUNCTION IF EXISTS fn_update_event(INT,TEXT,TEXT,DATE,DATE,TEXT,TEXT,TEXT,TEXT,NUMERIC,TEXT,INT,enum_weapon_type[]);

-- 4. Recreate fn_create_event with registration params
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
  p_entry_fee     NUMERIC DEFAULT NULL,
  p_entry_fee_currency TEXT DEFAULT NULL,
  p_weapons       enum_weapon_type[] DEFAULT NULL,
  p_registration  TEXT    DEFAULT NULL,
  p_registration_deadline DATE DEFAULT NULL
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
    txt_country, txt_venue_address, url_invitation, num_entry_fee,
    txt_entry_fee_currency, arr_weapons,
    url_registration, dt_registration_deadline
  ) VALUES (
    p_code, p_name, p_id_season, p_id_organizer,
    p_location, p_dt_start, p_dt_end, p_url_event,
    p_country, p_venue_address, p_invitation, p_entry_fee,
    p_entry_fee_currency, COALESCE(p_weapons, '{EPEE,FOIL,SABRE}'),
    p_registration, p_registration_deadline
  )
  RETURNING id_event INTO v_id;
  RETURN v_id;
END;
$$;

-- 4. Recreate fn_update_event with registration params
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
  p_entry_fee     NUMERIC,
  p_entry_fee_currency TEXT DEFAULT NULL,
  p_id_organizer  INT DEFAULT NULL,
  p_weapons       enum_weapon_type[] DEFAULT NULL,
  p_registration  TEXT DEFAULT NULL,
  p_registration_deadline DATE DEFAULT NULL
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
      txt_entry_fee_currency = p_entry_fee_currency,
      id_organizer      = COALESCE(p_id_organizer, id_organizer),
      arr_weapons       = COALESCE(p_weapons, arr_weapons),
      url_registration  = p_registration,
      dt_registration_deadline = p_registration_deadline,
      ts_updated        = NOW()
  WHERE id_event = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Event % not found', p_id;
  END IF;
END;
$$;

-- 5. Update permissions with new signatures
REVOKE EXECUTE ON FUNCTION fn_create_event(TEXT,TEXT,INT,INT,TEXT,DATE,DATE,TEXT,TEXT,TEXT,TEXT,NUMERIC,TEXT,enum_weapon_type[],TEXT,DATE) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION fn_create_event(TEXT,TEXT,INT,INT,TEXT,DATE,DATE,TEXT,TEXT,TEXT,TEXT,NUMERIC,TEXT,enum_weapon_type[],TEXT,DATE) TO authenticated;

REVOKE EXECUTE ON FUNCTION fn_update_event(INT,TEXT,TEXT,DATE,DATE,TEXT,TEXT,TEXT,TEXT,NUMERIC,TEXT,INT,enum_weapon_type[],TEXT,DATE) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION fn_update_event(INT,TEXT,TEXT,DATE,DATE,TEXT,TEXT,TEXT,TEXT,NUMERIC,TEXT,INT,enum_weapon_type[],TEXT,DATE) TO authenticated;
