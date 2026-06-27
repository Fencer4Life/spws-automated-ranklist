-- =============================================================================
-- Fix: EVENT carry-over picker (id_prior_event) saves but doesn't round-trip
-- =============================================================================
-- ADR-044's Phase-3 admin picker links an EVENT to its previous-season
-- counterpart via tbl_event.id_prior_event (the FK that drives the rolling /
-- carry-over score engine, ADR-018/021/042). fn_update_event already persisted
-- the FK, but vw_calendar never SELECTed the column, so the admin form read it
-- back as NULL on reopen and the dropdown reset to "none" — the user perceived
-- this as "Save doesn't save".
--
-- This migration closes the round-trip (the documented "new tbl_event column →
-- rebuild vw_calendar" discipline) AND makes the picker's "— none —" option
-- actually unlink, via a -1 sentinel (real NULL still means "leave unchanged"
-- so legacy callers are unaffected).
-- =============================================================================

-- 1. Rebuild vw_calendar from its current (20260618000001) definition, adding
--    e.id_prior_event. It is functionally dependent on the grouped PK
--    e.id_event, so no GROUP BY change is required. A recreated view loses its
--    grants, so they are re-issued below.
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
  e.url_event_2, e.url_event_3, e.url_event_4, e.url_event_5,
  e.id_evf_event,
  e.id_prior_event,
  COUNT(t.id_tournament)::INT AS num_tournaments,
  COALESCE(BOOL_OR(t.enum_type IN ('PEW','MEW','MSW','PSW')), FALSE) AS bool_has_international,
  e.json_ingest_sources, e.json_source_overrides
FROM tbl_event e
JOIN tbl_season s ON s.id_season = e.id_season
LEFT JOIN tbl_organizer o ON o.id_organizer = e.id_organizer
LEFT JOIN tbl_tournament t ON t.id_event = e.id_event
GROUP BY e.id_event, s.txt_code, o.txt_name
ORDER BY e.dt_start ASC;

GRANT SELECT ON vw_calendar TO anon;
GRANT SELECT ON vw_calendar TO authenticated;

-- 2. fn_update_event: same 21-arg signature as 20260428000002, but the
--    id_prior_event write now distinguishes three intents on p_id_prior_event:
--      NULL  → leave unchanged (backward compatible with 19-arg legacy callers)
--      -1    → explicit "none": clear the link (picker "— none —" option)
--      >0    → set the link to that event id
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
      -- NULL = unchanged, -1 = clear ("none"), >0 = set the link.
      id_prior_event    = CASE
                            WHEN p_id_prior_event IS NULL THEN id_prior_event
                            WHEN p_id_prior_event = -1    THEN NULL
                            ELSE p_id_prior_event
                          END,
      ts_updated        = NOW()
  WHERE id_event = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Event % not found', p_id;
  END IF;
END;
$$;

-- Signature unchanged from 20260428000002, so its REVOKE/GRANT still hold; no
-- re-grant needed for CREATE OR REPLACE on an identical signature.
