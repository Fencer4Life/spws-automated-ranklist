-- =============================================================================
-- fn_import_evf_events: bulk import events from EVF calendar scrape (ADR-028)
-- =============================================================================
-- Creates tbl_event + child tbl_tournament entries for PEW events.
-- Idempotent: skips events that already exist (by txt_code).
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
    -- Generate event code from name (e.g. "EVF Circuit – Salzburg (AUT)" → "PEW-SALZBURG-2025-2026")
    DECLARE
      v_name     TEXT := v_evt ->> 'name';
      v_code     TEXT := v_evt ->> 'code';
      v_dt_start DATE := (v_evt ->> 'dt_start')::DATE;
      v_dt_end   DATE := COALESCE((v_evt ->> 'dt_end')::DATE, v_dt_start);
      v_location TEXT := COALESCE(v_evt ->> 'location', '');
      v_country  TEXT := COALESCE(v_evt ->> 'country', '');
      v_weapons  JSONB := COALESCE(v_evt -> 'weapons', '[]'::JSONB);
      v_is_team  BOOLEAN := COALESCE((v_evt ->> 'is_team')::BOOLEAN, FALSE);
      v_tourn_type TEXT;
    BEGIN
      -- Skip if event code already exists
      IF EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = v_code) THEN
        v_skipped := v_skipped + 1;
        CONTINUE;
      END IF;

      -- Determine tournament type
      v_tourn_type := CASE WHEN v_is_team THEN 'MEW' ELSE 'PEW' END;

      -- Create event
      INSERT INTO tbl_event (
        txt_code, txt_name, id_season, id_organizer,
        dt_start, dt_end, txt_location, txt_country, enum_status
      ) VALUES (
        v_code, v_name, p_season_id, v_org_id,
        v_dt_start, v_dt_end, v_location, v_country, 'PLANNED'
      ) RETURNING id_event INTO v_event_id;

      -- Create child tournaments (one per weapon × gender)
      -- PEW events have both M and F
      FOR v_weapon IN SELECT jsonb_array_elements_text(v_weapons)
      LOOP
        -- Men's tournament
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

        -- Women's tournament
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
