-- =============================================================================
-- fn_mirror_events_to_prod: NULLIF-guard the UPDATE branch's text fields
-- =============================================================================
-- LIVE REGRESSION (caught by the first real PROD reconcile, 2026-07-11):
-- the UPDATE branch wrote `txt_evf_slug = COALESCE(v_evt->>'txt_evf_slug',
-- txt_evf_slug)`. The CERT->PROD payload always sends every key with a
-- stable shape — an empty string '' for absent values — so a slugless event
-- carried txt_evf_slug = ''. `idx_tbl_event_evf_slug` is UNIQUE WHERE
-- txt_evf_slug IS NOT NULL, so writing '' (not NULL) into two rows in one
-- batch aborted the whole reconcile with:
--   duplicate key value violates unique constraint "idx_tbl_event_evf_slug"
--   Key (txt_evf_slug)=() already exists.
-- (The single-transaction design meant PROD rolled back cleanly — no data
-- was lost — but the reconcile could never complete.)
--
-- Fix: NULLIF the text overwrite fields so an empty CERT value collapses to
-- "keep the current PROD value" instead of writing '' — matching the CREATE
-- branch, which already NULLIFs. This keeps the overwrite intent (a non-empty
-- CERT value still wins, e.g. the MPW name fix) while never storing '' into a
-- uniquely-indexed column. Only the four text fields change; dates / ints /
-- arrays were already guarded.
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
      IF EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = v_evt ->> 'txt_code') THEN
        CONTINUE;
      END IF;

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
        -- Source-owned identity fields: overwrite when CERT provides a
        -- non-empty value, else keep the current PROD value. NULLIF collapses
        -- the stable-shape empty string so '' is never written (critical for
        -- the uniquely-indexed txt_evf_slug — see migration header).
        txt_name      = COALESCE(NULLIF(v_evt ->> 'txt_name', ''), txt_name),
        dt_start      = COALESCE(NULLIF(v_evt ->> 'dt_start', '')::DATE, dt_start),
        dt_end        = COALESCE(NULLIF(v_evt ->> 'dt_end', '')::DATE, dt_end),
        txt_location  = COALESCE(NULLIF(v_evt ->> 'txt_location', ''), txt_location),
        txt_country   = COALESCE(NULLIF(v_evt ->> 'txt_country', ''), txt_country),
        id_organizer  = COALESCE((v_evt ->> 'id_organizer')::INT, id_organizer),
        arr_weapons   = COALESCE(v_arr_weapons, arr_weapons),
        id_evf_event  = COALESCE((v_evt ->> 'id_evf_event')::INT, id_evf_event),
        txt_evf_slug  = COALESCE(NULLIF(v_evt ->> 'txt_evf_slug', ''), txt_evf_slug),
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
