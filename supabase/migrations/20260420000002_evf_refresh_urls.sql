-- =============================================================================
-- fn_refresh_evf_event_urls — ADR-028 amendment (2026-04-20)
-- =============================================================================
-- Companion to fn_import_evf_events. Called by the EVF sync for every scraped
-- event that matched an already-imported tbl_event row (by name + date).
--
-- Refresh invariant: only fills columns whose current value is NULL or the
-- empty string. NEVER overwrites an existing value. This protects admin edits
-- made via the Event CRUD UI (FR-60) — the scraper's heuristic must not stomp
-- a manually-entered URL or deadline.
--
-- Columns refreshed when NULL/empty:
--   url_event, url_invitation, url_registration, dt_registration_deadline,
--   txt_venue_address, num_entry_fee, txt_entry_fee_currency, arr_weapons
--
-- Columns never refreshed:
--   txt_code, txt_name, id_season, id_organizer, enum_status,
--   dt_start, dt_end, txt_location, txt_country
-- =============================================================================

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
      v_url_invitation  TEXT := NULLIF(v_upd ->> 'url_invitation', '');
      v_url_register    TEXT := NULLIF(v_upd ->> 'url_registration', '');
      v_reg_deadline    DATE := NULLIF(v_upd ->> 'dt_registration_deadline', '')::DATE;
      v_addr            TEXT := NULLIF(v_upd ->> 'address', '');
      v_fee             NUMERIC := NULLIF(v_upd ->> 'fee', '')::NUMERIC;
      v_curr            TEXT := NULLIF(v_upd ->> 'fee_currency', '');
      v_weapons_json    JSONB := v_upd -> 'weapons';
      v_weapons         enum_weapon_type[];
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

      UPDATE tbl_event
         SET url_event = CASE
               WHEN url_event IS NULL OR url_event = ''
                 THEN COALESCE(v_url_event, url_event)
               ELSE url_event
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
      END IF;
    END;
  END LOOP;

  RETURN jsonb_build_object('touched', v_touched, 'refreshed', v_refreshed);
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_refresh_evf_event_urls(JSONB) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_refresh_evf_event_urls(JSONB) TO authenticated;
