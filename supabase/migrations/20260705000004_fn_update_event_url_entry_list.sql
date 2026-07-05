-- =============================================================================
-- ADR-079 amend — SPWS-registration URL auto-fill: fn_update_event gains
-- p_url_entry_list so the EventManager can persist BOTH the form URL
-- (url_registration, already writable via p_registration) and the entry-list
-- URL (url_entry_list) when the admin ticks bool_use_spws_registration. The
-- toggle derives self-contained absolute register.html URLs client-side
-- (deliberate exception to the "URLs are always hand-entered" rule, for
-- cross-origin/WordPress embeds).
--
-- url_entry_list is written by DIRECT assignment, exactly like url_registration
-- (p_registration) — a value sets it, NULL clears it (untick). This differs
-- from the COALESCE (NULL = unchanged) trailing params on purpose: the two
-- registration URLs are always sent together by the form.
--
-- Postgres keys a function on name + parameter TYPE LIST; widening the list via
-- CREATE OR REPLACE makes a SECOND overload and old-arity calls become
-- ambiguous. DROP the 24-arg signature first (same pattern as 20260705000002).
-- =============================================================================

DROP FUNCTION IF EXISTS fn_update_event(
  INT, TEXT, TEXT, DATE, DATE, TEXT, TEXT, TEXT, TEXT, NUMERIC,
  TEXT, INT, enum_weapon_type[], TEXT, DATE, TEXT, TEXT, TEXT, TEXT, TEXT, INT,
  BOOLEAN, NUMERIC, NUMERIC
);

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
  p_url_event_5   TEXT DEFAULT NULL,
  p_code          TEXT DEFAULT NULL,
  p_id_prior_event INT DEFAULT NULL,
  p_use_spws_registration BOOLEAN DEFAULT NULL,
  p_entry_fee_2w  NUMERIC DEFAULT NULL,
  p_entry_fee_3w  NUMERIC DEFAULT NULL,
  p_url_entry_list TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_compact      TEXT[];
  v_old_code     TEXT;
  v_new_kind     TEXT;
  v_new_suffix   TEXT;
  v_sample_child TEXT;
BEGIN
  v_compact := fn_compact_urls(p_url_event, p_url_event_2, p_url_event_3, p_url_event_4, p_url_event_5);

  IF p_code IS NOT NULL THEN
    SELECT txt_code INTO v_old_code FROM tbl_event WHERE id_event = p_id;
    IF v_old_code IS NULL THEN
      RAISE EXCEPTION 'Event % not found', p_id;
    END IF;

    IF p_code <> v_old_code THEN
      v_new_kind   := regexp_replace(p_code, '-\d{4}-\d{4}$', '');
      v_new_suffix := COALESCE((regexp_match(p_code, '(\d{4}-\d{4})$'))[1], '');

      SELECT txt_code INTO v_sample_child
        FROM tbl_tournament WHERE id_event = p_id LIMIT 1;

      IF v_sample_child IS NOT NULL AND v_sample_child ~ '-V\d-' THEN
        UPDATE tbl_tournament t
           SET txt_code = v_new_kind
                          || '-' || t.enum_age_category::TEXT
                          || '-' || t.enum_gender::TEXT
                          || '-' || t.enum_weapon::TEXT
                          || CASE WHEN v_new_suffix = '' THEN ''
                                  ELSE '-' || v_new_suffix END
         WHERE t.id_event = p_id;
      ELSE
        UPDATE tbl_tournament t
           SET txt_code = p_code
                          || '-' || t.enum_gender::TEXT
                          || '-' || t.enum_weapon::TEXT
         WHERE t.id_event = p_id;
      END IF;
    END IF;
  END IF;

  UPDATE tbl_event
  SET txt_code          = COALESCE(p_code, txt_code),
      txt_name          = p_name,
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
      id_prior_event    = CASE
                            WHEN p_id_prior_event IS NULL THEN id_prior_event
                            WHEN p_id_prior_event = -1    THEN NULL
                            ELSE p_id_prior_event
                          END,
      bool_use_spws_registration = COALESCE(p_use_spws_registration, bool_use_spws_registration),
      num_entry_fee_2w  = COALESCE(p_entry_fee_2w, num_entry_fee_2w),
      num_entry_fee_3w  = COALESCE(p_entry_fee_3w, num_entry_fee_3w),
      url_entry_list    = p_url_entry_list,
      ts_updated        = NOW()
  WHERE id_event = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Event % not found', p_id;
  END IF;
END;
$$;

-- Privileges do not carry over from the dropped overload — re-grant on the new
-- (widened) signature (matches every prior fn_update_event signature change).
REVOKE EXECUTE ON FUNCTION fn_update_event(
  INT, TEXT, TEXT, DATE, DATE, TEXT, TEXT, TEXT, TEXT, NUMERIC,
  TEXT, INT, enum_weapon_type[], TEXT, DATE, TEXT, TEXT, TEXT, TEXT, TEXT, INT,
  BOOLEAN, NUMERIC, NUMERIC, TEXT
) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION fn_update_event(
  INT, TEXT, TEXT, DATE, DATE, TEXT, TEXT, TEXT, TEXT, NUMERIC,
  TEXT, INT, enum_weapon_type[], TEXT, DATE, TEXT, TEXT, TEXT, TEXT, TEXT, INT,
  BOOLEAN, NUMERIC, NUMERIC, TEXT
) TO authenticated;
