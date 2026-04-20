-- =============================================================================
-- fn_import_evf_events URL harvesting (ADR-028 revision)
-- =============================================================================
-- Extends fn_import_evf_events so it writes the event-level URL fields the
-- scraper now harvests:
--   * url_event                 (ADR-029)
--   * url_invitation            (existing column, never populated)
--   * url_registration          (ADR-030)
--   * dt_registration_deadline  (ADR-030)
--   * txt_venue_address
--   * num_entry_fee, txt_entry_fee_currency
--   * arr_weapons (so vw_calendar + admin CRUD see weapons on the event row)
-- Backward-compatible: JSON payloads without the new keys still work — each
-- new key is optional and falls back to NULL / COALESCE defaults.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_import_evf_events(
  p_events  JSONB,
  p_season_id INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_evt      JSONB;
  v_event_id INT;
  v_org_id   INT;
  v_weapon   TEXT;
  v_created  INT := 0;
  v_skipped  INT := 0;
BEGIN
  SELECT id_organizer INTO v_org_id FROM tbl_organizer WHERE txt_code = 'SPWS';

  FOR v_evt IN SELECT * FROM jsonb_array_elements(p_events)
  LOOP
    DECLARE
      v_name           TEXT := v_evt ->> 'name';
      v_code           TEXT := v_evt ->> 'code';
      v_dt_start       DATE := (v_evt ->> 'dt_start')::DATE;
      v_dt_end         DATE := COALESCE((v_evt ->> 'dt_end')::DATE, v_dt_start);
      v_location       TEXT := COALESCE(v_evt ->> 'location', '');
      v_country        TEXT := COALESCE(v_evt ->> 'country', '');
      v_weapons_json   JSONB := COALESCE(v_evt -> 'weapons', '[]'::JSONB);
      v_is_team        BOOLEAN := COALESCE((v_evt ->> 'is_team')::BOOLEAN, FALSE);
      v_url_event      TEXT := NULLIF(v_evt ->> 'url_event', '');
      v_url_invitation TEXT := NULLIF(v_evt ->> 'url_invitation', '');
      v_url_register   TEXT := NULLIF(v_evt ->> 'url_registration', '');
      v_reg_deadline   DATE := NULLIF(v_evt ->> 'dt_registration_deadline', '')::DATE;
      v_venue_address  TEXT := COALESCE(v_evt ->> 'address', '');
      v_entry_fee      NUMERIC := NULLIF(v_evt ->> 'fee', '')::NUMERIC;
      v_entry_fee_curr TEXT := COALESCE(v_evt ->> 'fee_currency', '');
      v_arr_weapons    enum_weapon_type[];
      v_tourn_type     TEXT;
    BEGIN
      -- Idempotency: skip if event code already exists
      IF EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = v_code) THEN
        v_skipped := v_skipped + 1;
        CONTINUE;
      END IF;

      v_tourn_type := CASE WHEN v_is_team THEN 'MEW' ELSE 'PEW' END;

      -- Convert JSONB weapon list → enum_weapon_type[]
      SELECT ARRAY(
        SELECT (value #>> '{}')::enum_weapon_type
        FROM jsonb_array_elements(v_weapons_json)
      ) INTO v_arr_weapons;

      -- Create event (with URL + enrichment fields)
      INSERT INTO tbl_event (
        txt_code, txt_name, id_season, id_organizer,
        dt_start, dt_end, txt_location, txt_country, enum_status,
        url_event, url_invitation, url_registration, dt_registration_deadline,
        txt_venue_address, num_entry_fee, txt_entry_fee_currency, arr_weapons
      ) VALUES (
        v_code, v_name, p_season_id, v_org_id,
        v_dt_start, v_dt_end, v_location, v_country, 'PLANNED',
        v_url_event, v_url_invitation, v_url_register, v_reg_deadline,
        NULLIF(v_venue_address, ''), v_entry_fee, NULLIF(v_entry_fee_curr, ''),
        COALESCE(NULLIF(v_arr_weapons, '{}'::enum_weapon_type[]), '{EPEE,FOIL,SABRE}'::enum_weapon_type[])
      ) RETURNING id_event INTO v_event_id;

      -- Create child tournaments (one per weapon × gender), unchanged
      FOR v_weapon IN SELECT jsonb_array_elements_text(v_weapons_json)
      LOOP
        INSERT INTO tbl_tournament (
          id_event, txt_code, txt_name, enum_type,
          enum_weapon, enum_gender, enum_age_category,
          dt_tournament, int_participant_count, enum_import_status
        ) VALUES (
          v_event_id,
          v_code || '-M-' || v_weapon,
          v_name,
          v_tourn_type::enum_tournament_type,
          v_weapon::enum_weapon_type, 'M', 'V2',
          v_dt_start, 0, 'PLANNED'
        );

        INSERT INTO tbl_tournament (
          id_event, txt_code, txt_name, enum_type,
          enum_weapon, enum_gender, enum_age_category,
          dt_tournament, int_participant_count, enum_import_status
        ) VALUES (
          v_event_id,
          v_code || '-F-' || v_weapon,
          v_name,
          v_tourn_type::enum_tournament_type,
          v_weapon::enum_weapon_type, 'F', 'V2',
          v_dt_start, 0, 'PLANNED'
        );
      END LOOP;

      v_created := v_created + 1;
    END;
  END LOOP;

  RETURN jsonb_build_object('created', v_created, 'skipped', v_skipped);
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_import_evf_events(JSONB, INT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_import_evf_events(JSONB, INT) TO authenticated;
