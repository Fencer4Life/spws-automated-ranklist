-- =============================================================================
-- ADR-040: Multi-Slot Event Result URLs with Compact-on-Save
-- =============================================================================
-- Adds url_event_2..5 to tbl_event, fn_compact_urls helper, and extends
-- fn_create_event / fn_update_event / fn_refresh_evf_event_urls to accept and
-- compact the new slots. Tournament-level url_results unchanged.
-- =============================================================================

-- 1. Add 4 nullable URL columns.
ALTER TABLE tbl_event ADD COLUMN IF NOT EXISTS url_event_2 TEXT;
ALTER TABLE tbl_event ADD COLUMN IF NOT EXISTS url_event_3 TEXT;
ALTER TABLE tbl_event ADD COLUMN IF NOT EXISTS url_event_4 TEXT;
ALTER TABLE tbl_event ADD COLUMN IF NOT EXISTS url_event_5 TEXT;


-- 2. fn_compact_urls — pure helper. Trim → drop empty → dedupe first-occurrence
--    → pad with NULL to length 5. Returns a 5-element TEXT[] (slot #1..#5).
CREATE OR REPLACE FUNCTION fn_compact_urls(VARIADIC p_urls TEXT[])
RETURNS TEXT[]
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_compact TEXT[];
BEGIN
  WITH normalised AS (
    SELECT NULLIF(BTRIM(u.val), '') AS url, u.ord
      FROM unnest(p_urls) WITH ORDINALITY AS u(val, ord)
  ),
  dedup AS (
    SELECT DISTINCT ON (url) url, ord
      FROM normalised
     WHERE url IS NOT NULL
     ORDER BY url, ord
  )
  SELECT COALESCE(ARRAY_AGG(url ORDER BY ord), ARRAY[]::TEXT[])
    INTO v_compact
    FROM dedup;

  -- Pad to exactly 5 elements with NULLs.
  WHILE COALESCE(array_length(v_compact, 1), 0) < 5 LOOP
    v_compact := v_compact || ARRAY[NULL]::TEXT[];
  END LOOP;
  RETURN v_compact[1:5];
END;
$$;


-- 3. Drop old fn_create_event (16-arg) and fn_update_event (15-arg) signatures.
DROP FUNCTION IF EXISTS fn_create_event(TEXT,TEXT,INT,INT,TEXT,DATE,DATE,TEXT,TEXT,TEXT,TEXT,NUMERIC,TEXT,enum_weapon_type[],TEXT,DATE);
DROP FUNCTION IF EXISTS fn_update_event(INT,TEXT,TEXT,DATE,DATE,TEXT,TEXT,TEXT,TEXT,NUMERIC,TEXT,INT,enum_weapon_type[],TEXT,DATE);


-- 4. Recreate fn_create_event with 4 new url_event_2..5 params.
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
  p_registration_deadline DATE DEFAULT NULL,
  p_url_event_2   TEXT    DEFAULT NULL,
  p_url_event_3   TEXT    DEFAULT NULL,
  p_url_event_4   TEXT    DEFAULT NULL,
  p_url_event_5   TEXT    DEFAULT NULL
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_id      INT;
  v_compact TEXT[];
BEGIN
  v_compact := fn_compact_urls(p_url_event, p_url_event_2, p_url_event_3, p_url_event_4, p_url_event_5);

  INSERT INTO tbl_event (
    txt_code, txt_name, id_season, id_organizer,
    txt_location, dt_start, dt_end, url_event,
    txt_country, txt_venue_address, url_invitation, num_entry_fee,
    txt_entry_fee_currency, arr_weapons,
    url_registration, dt_registration_deadline,
    url_event_2, url_event_3, url_event_4, url_event_5
  ) VALUES (
    p_code, p_name, p_id_season, p_id_organizer,
    p_location, p_dt_start, p_dt_end, v_compact[1],
    p_country, p_venue_address, p_invitation, p_entry_fee,
    p_entry_fee_currency, COALESCE(p_weapons, '{EPEE,FOIL,SABRE}'),
    p_registration, p_registration_deadline,
    v_compact[2], v_compact[3], v_compact[4], v_compact[5]
  )
  RETURNING id_event INTO v_id;
  RETURN v_id;
END;
$$;


-- 5. Recreate fn_update_event with 4 new url_event_2..5 params.
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
  p_registration_deadline DATE DEFAULT NULL,
  p_url_event_2   TEXT DEFAULT NULL,
  p_url_event_3   TEXT DEFAULT NULL,
  p_url_event_4   TEXT DEFAULT NULL,
  p_url_event_5   TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_compact TEXT[];
BEGIN
  v_compact := fn_compact_urls(p_url_event, p_url_event_2, p_url_event_3, p_url_event_4, p_url_event_5);

  UPDATE tbl_event
  SET txt_name          = p_name,
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
      ts_updated        = NOW()
  WHERE id_event = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Event % not found', p_id;
  END IF;
END;
$$;


-- 6. Extend fn_refresh_evf_event_urls to accept slots #2..5 and re-compact.
--    Per-slot NULL-only invariant preserved: a slot is written only when its
--    current value is NULL/empty AND the payload offers a non-empty value.
--    After per-slot writes, fn_compact_urls is applied so the row's slots stay
--    left-shifted/dedupe.
CREATE OR REPLACE FUNCTION fn_refresh_evf_event_urls(
  p_updates JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
      v_url_event       TEXT := NULLIF(v_upd ->> 'url_event', '');
      v_url_event_2     TEXT := NULLIF(v_upd ->> 'url_event_2', '');
      v_url_event_3     TEXT := NULLIF(v_upd ->> 'url_event_3', '');
      v_url_event_4     TEXT := NULLIF(v_upd ->> 'url_event_4', '');
      v_url_event_5     TEXT := NULLIF(v_upd ->> 'url_event_5', '');
      v_url_invitation  TEXT := NULLIF(v_upd ->> 'url_invitation', '');
      v_url_register    TEXT := NULLIF(v_upd ->> 'url_registration', '');
      v_reg_deadline    DATE := NULLIF(v_upd ->> 'dt_registration_deadline', '')::DATE;
      v_addr            TEXT := NULLIF(v_upd ->> 'address', '');
      v_fee             NUMERIC := NULLIF(v_upd ->> 'fee', '')::NUMERIC;
      v_curr            TEXT := NULLIF(v_upd ->> 'fee_currency', '');
      v_weapons_json    JSONB := v_upd -> 'weapons';
      v_weapons         enum_weapon_type[];
      v_compact         TEXT[];
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

      -- Per-slot NULL-only refresh for url_event_*. Then compact.
      UPDATE tbl_event
         SET url_event = CASE
               WHEN url_event IS NULL OR url_event = ''
                 THEN COALESCE(v_url_event, url_event)
               ELSE url_event
             END,
             url_event_2 = CASE
               WHEN url_event_2 IS NULL OR url_event_2 = ''
                 THEN COALESCE(v_url_event_2, url_event_2)
               ELSE url_event_2
             END,
             url_event_3 = CASE
               WHEN url_event_3 IS NULL OR url_event_3 = ''
                 THEN COALESCE(v_url_event_3, url_event_3)
               ELSE url_event_3
             END,
             url_event_4 = CASE
               WHEN url_event_4 IS NULL OR url_event_4 = ''
                 THEN COALESCE(v_url_event_4, url_event_4)
               ELSE url_event_4
             END,
             url_event_5 = CASE
               WHEN url_event_5 IS NULL OR url_event_5 = ''
                 THEN COALESCE(v_url_event_5, url_event_5)
               ELSE url_event_5
             END,
             url_invitation = CASE
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
        -- Compact slots after per-slot writes so left-shift invariant holds.
        SELECT fn_compact_urls(url_event, url_event_2, url_event_3, url_event_4, url_event_5)
          INTO v_compact
          FROM tbl_event WHERE id_event = v_id;
        UPDATE tbl_event
           SET url_event   = v_compact[1],
               url_event_2 = v_compact[2],
               url_event_3 = v_compact[3],
               url_event_4 = v_compact[4],
               url_event_5 = v_compact[5]
         WHERE id_event = v_id;
      END IF;
    END;
  END LOOP;

  RETURN jsonb_build_object('touched', v_touched, 'refreshed', v_refreshed);
END;
$$;


-- 7. Permissions: REVOKE/GRANT for the new signatures.
REVOKE EXECUTE ON FUNCTION fn_create_event(TEXT,TEXT,INT,INT,TEXT,DATE,DATE,TEXT,TEXT,TEXT,TEXT,NUMERIC,TEXT,enum_weapon_type[],TEXT,DATE,TEXT,TEXT,TEXT,TEXT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_create_event(TEXT,TEXT,INT,INT,TEXT,DATE,DATE,TEXT,TEXT,TEXT,TEXT,NUMERIC,TEXT,enum_weapon_type[],TEXT,DATE,TEXT,TEXT,TEXT,TEXT) TO authenticated;

REVOKE EXECUTE ON FUNCTION fn_update_event(INT,TEXT,TEXT,DATE,DATE,TEXT,TEXT,TEXT,TEXT,NUMERIC,TEXT,INT,enum_weapon_type[],TEXT,DATE,TEXT,TEXT,TEXT,TEXT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_update_event(INT,TEXT,TEXT,DATE,DATE,TEXT,TEXT,TEXT,TEXT,NUMERIC,TEXT,INT,enum_weapon_type[],TEXT,DATE,TEXT,TEXT,TEXT,TEXT) TO authenticated;

REVOKE EXECUTE ON FUNCTION fn_compact_urls(TEXT[]) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_compact_urls(TEXT[]) TO authenticated;
