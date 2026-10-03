-- =============================================================================
-- ADR-108 §7 (build step 11) — the manual close takes an exact event code
-- =============================================================================
-- The daily close (event-close.yml) completes a domestic event once every
-- listing is final, CERT and PROD hold the CERT run's result and the end date
-- has passed. The Telegram `complete <code>` command stays as the manual close.
-- It resolved a prefix in the active season, so `complete PPW1` could complete
-- whichever event matched first. It now takes an exact code. A prefix, or a
-- code that does not exist, is refused, and the refusal lists the active
-- season's exact codes that start with it. It does not check the end date.
-- The parameter keeps its name, p_prefix, because the deployed GAS sends it.
-- Grants are unchanged (CREATE OR REPLACE keeps them).
-- Tests: supabase/tests/105 (COMPLETE.01-06); 10.16-10.17 stay green.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_complete_event(p_prefix TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_id INT;
  v_status   enum_event_status;
  v_matches  TEXT;
BEGIN
  SELECT e.id_event, e.enum_status INTO v_event_id, v_status
    FROM tbl_event e
   WHERE e.txt_code = p_prefix;

  IF v_event_id IS NULL THEN
    SELECT string_agg(e.txt_code, ', ' ORDER BY e.txt_code) INTO v_matches
      FROM tbl_event e
      JOIN tbl_season s ON s.id_season = e.id_season
     WHERE s.bool_active
       AND starts_with(e.txt_code, coalesce(p_prefix, ''));
    RAISE EXCEPTION 'COMPLETE_EXACT_CODE: % is not an exact event code%', p_prefix,
      CASE WHEN v_matches IS NULL THEN '' ELSE '; the active season has: ' || v_matches END;
  END IF;

  IF v_status <> 'IN_PROGRESS' THEN
    RAISE EXCEPTION 'Event must be IN_PROGRESS to complete (current: %)', v_status;
  END IF;

  UPDATE tbl_event
     SET enum_status = 'COMPLETED', ts_updated = NOW()
   WHERE id_event = v_event_id;

  RETURN jsonb_build_object('event_id', v_event_id, 'event_code', p_prefix, 'status', 'COMPLETED');
END;
$$;

COMMENT ON FUNCTION fn_complete_event(TEXT) IS
  'ADR-108 §7: the manual close behind Telegram `complete <code>`. Takes an exact event code (the parameter keeps the name p_prefix for the deployed GAS); a prefix or unknown code refuses with the active season''s matching codes. IN_PROGRESS to COMPLETED only; the end date is not checked.';
