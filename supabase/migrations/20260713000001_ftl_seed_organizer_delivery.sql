-- =============================================================================
-- FR-131 / ADR-080 §5 — FTL seed organizer delivery
--   1. fn_update_event gains the admin-owned txt_organizer_email write path.
--   2. fn_mark_ftl_sent stamps only after SMTP acceptance; service-role only.
-- =============================================================================

-- Postgres identifies overloads by the type list. Drop the current 25-argument
-- signature before creating the widened 26-argument function.
DROP FUNCTION IF EXISTS fn_update_event(
  INT, TEXT, TEXT, DATE, DATE, TEXT, TEXT, TEXT, TEXT, NUMERIC,
  TEXT, INT, enum_weapon_type[], TEXT, DATE, TEXT, TEXT, TEXT, TEXT, TEXT, INT,
  BOOLEAN, NUMERIC, NUMERIC, TEXT
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
  p_url_entry_list TEXT DEFAULT NULL,
  p_txt_organizer_email TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_compact      TEXT[];
  v_old_code     TEXT;
  v_new_kind     TEXT;
  v_new_suffix   TEXT;
  v_sample_child TEXT;
BEGIN
  v_compact := fn_compact_urls(
    p_url_event, p_url_event_2, p_url_event_3, p_url_event_4, p_url_event_5
  );

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
      bool_use_spws_registration = COALESCE(
        p_use_spws_registration, bool_use_spws_registration
      ),
      num_entry_fee_2w  = COALESCE(p_entry_fee_2w, num_entry_fee_2w),
      num_entry_fee_3w  = COALESCE(p_entry_fee_3w, num_entry_fee_3w),
      url_entry_list    = p_url_entry_list,
      txt_organizer_email = CASE
        WHEN p_txt_organizer_email IS NULL THEN txt_organizer_email
        WHEN btrim(p_txt_organizer_email) = '' THEN NULL
        ELSE btrim(p_txt_organizer_email)
      END,
      ts_updated        = NOW()
  WHERE id_event = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Event % not found', p_id;
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_update_event(
  INT, TEXT, TEXT, DATE, DATE, TEXT, TEXT, TEXT, TEXT, NUMERIC,
  TEXT, INT, enum_weapon_type[], TEXT, DATE, TEXT, TEXT, TEXT, TEXT, TEXT, INT,
  BOOLEAN, NUMERIC, NUMERIC, TEXT, TEXT
) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION fn_update_event(
  INT, TEXT, TEXT, DATE, DATE, TEXT, TEXT, TEXT, TEXT, NUMERIC,
  TEXT, INT, enum_weapon_type[], TEXT, DATE, TEXT, TEXT, TEXT, TEXT, TEXT, INT,
  BOOLEAN, NUMERIC, NUMERIC, TEXT, TEXT
) TO authenticated;

CREATE OR REPLACE FUNCTION fn_mark_ftl_sent(p_event_code TEXT)
RETURNS TIMESTAMPTZ
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sent_at TIMESTAMPTZ;
BEGIN
  UPDATE tbl_event
     SET ts_ftl_sent = NOW(),
         ts_updated = NOW()
   WHERE txt_code = p_event_code
   RETURNING ts_ftl_sent INTO v_sent_at;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Event % not found', p_event_code;
  END IF;
  RETURN v_sent_at;
END;
$$;

REVOKE ALL ON FUNCTION fn_mark_ftl_sent(TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_mark_ftl_sent(TEXT) TO service_role;

COMMENT ON FUNCTION fn_mark_ftl_sent(TEXT) IS
  'Service-role-only ADR-080 delivery stamp. Called after Gmail SMTP accepts the message; '
  'manual re-sends intentionally replace the timestamp.';
