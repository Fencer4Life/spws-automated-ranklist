-- =============================================================================
-- Phase 3a — fn_update_event v2: cascade txt_code rename + id_prior_event picker
-- =============================================================================
-- Replaces the 19-arg signature with a 21-arg version. NULL on either of the
-- two new parameters means "leave unchanged" (matches existing p_id_organizer
-- semantics; preserves backward compatibility for callers still on the old
-- 19-arg shape until App.svelte is updated in Phase 3c).
--
-- When p_code is supplied and differs from the current txt_code, all child
-- tournaments whose txt_code begins with the old event code get their prefix
-- rewritten in the same transaction (RPC-side cascade — same pattern as
-- fn_delete_event).
-- =============================================================================

-- 1. Drop existing 19-arg signature so the new one isn't ambiguous on resolve.
DROP FUNCTION IF EXISTS fn_update_event(
  INT, TEXT, TEXT, DATE, DATE, TEXT, TEXT, TEXT, TEXT, NUMERIC,
  TEXT, INT, enum_weapon_type[], TEXT, DATE, TEXT, TEXT, TEXT, TEXT
);

-- 2. Recreate with 2 new trailing params (DEFAULT NULL → backward compatible).
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
  p_id_prior_event INT DEFAULT NULL
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

  -- If a new code is supplied and differs, cascade the rename to all child
  -- tournaments. Children are rebuilt from the new event code + their own
  -- (enum_age_category, enum_gender, enum_weapon) fields so both naming
  -- conventions are handled in one shot:
  --   PPW/PEW: {kind}-V{age}-{G}-{W}-{suffix}
  --   MPW/MEW/MSW: {full_event_code}-{G}-{W}    (no V{age}, suffix already in full)
  -- Detection is on the first existing child's code: a `-V\d-` infix means the
  -- PPW/PEW pattern, otherwise the simpler appended pattern.
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
      id_prior_event    = COALESCE(p_id_prior_event, id_prior_event),
      ts_updated        = NOW()
  WHERE id_event = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Event % not found', p_id;
  END IF;
END;
$$;

-- 3. REVOKE/GRANT for the new signature.
REVOKE EXECUTE ON FUNCTION fn_update_event(
  INT, TEXT, TEXT, DATE, DATE, TEXT, TEXT, TEXT, TEXT, NUMERIC,
  TEXT, INT, enum_weapon_type[], TEXT, DATE, TEXT, TEXT, TEXT, TEXT, TEXT, INT
) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION fn_update_event(
  INT, TEXT, TEXT, DATE, DATE, TEXT, TEXT, TEXT, TEXT, NUMERIC,
  TEXT, INT, enum_weapon_type[], TEXT, DATE, TEXT, TEXT, TEXT, TEXT, TEXT, INT
) TO authenticated;
