-- =============================================================================
-- Add weapons array parameter to event CRUD functions
-- =============================================================================

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
  p_weapons       enum_weapon_type[] DEFAULT NULL
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
    txt_entry_fee_currency, arr_weapons
  ) VALUES (
    p_code, p_name, p_id_season, p_id_organizer,
    p_location, p_dt_start, p_dt_end, p_url_event,
    p_country, p_venue_address, p_invitation, p_entry_fee,
    p_entry_fee_currency, COALESCE(p_weapons, '{EPEE,FOIL,SABRE}')
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
  p_entry_fee     NUMERIC,
  p_entry_fee_currency TEXT DEFAULT NULL,
  p_id_organizer  INT DEFAULT NULL,
  p_weapons       enum_weapon_type[] DEFAULT NULL
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
      ts_updated        = NOW()
  WHERE id_event = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Event % not found', p_id;
  END IF;
END;
$$;

-- Re-grant with updated signatures (now includes enum_weapon_type[])
REVOKE EXECUTE ON FUNCTION fn_create_event(TEXT,TEXT,INT,INT,TEXT,DATE,DATE,TEXT,TEXT,TEXT,TEXT,NUMERIC,TEXT,enum_weapon_type[]) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION fn_create_event(TEXT,TEXT,INT,INT,TEXT,DATE,DATE,TEXT,TEXT,TEXT,TEXT,NUMERIC,TEXT,enum_weapon_type[]) TO authenticated;

REVOKE EXECUTE ON FUNCTION fn_update_event(INT,TEXT,TEXT,DATE,DATE,TEXT,TEXT,TEXT,TEXT,NUMERIC,TEXT,INT,enum_weapon_type[]) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION fn_update_event(INT,TEXT,TEXT,DATE,DATE,TEXT,TEXT,TEXT,TEXT,NUMERIC,TEXT,INT,enum_weapon_type[]) TO authenticated;
