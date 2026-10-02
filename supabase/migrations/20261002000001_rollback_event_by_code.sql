-- =============================================================================
-- fn_rollback_event_by_code — roll back a past event by its exact code
-- =============================================================================
-- doc/plans/international-data-repair-batch-1-2026-10-01.html (R3 = A).
--
-- A repaired international event is re-ingested from its source through the
-- draft commit, which only inserts; tournament codes are unique, so the stored
-- tournaments must go first. fn_rollback_event cannot do it:
--   * it resolves a code PREFIX (_resolve_event_prefix), so 'PEW1efs' matches
--     the event of that name in every season;
--   * it looks in the active season only, so a 2025/26 event is out of reach;
--   * it resets the event to PLANNED.
-- This function takes the exact code, deletes the event's tournaments through
-- fn_delete_tournament_cascade (match candidates, results, then the
-- tournament), and leaves the event row and its status as they are. The draft
-- commit that follows in the same session writes the event's tournaments again.
--
-- service_role only (ADR-083): it is called by the repair runner, never by the
-- admin UI. pgTAP REPAIR.RB.01–04 in supabase/tests/89_rollback_event_by_code.sql.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_rollback_event_by_code(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_id     INT;
  v_tourn_count  INT;
  v_result_count INT;
  v_tid          INT;
BEGIN
  SELECT id_event INTO v_event_id FROM tbl_event WHERE txt_code = p_code;
  IF v_event_id IS NULL THEN
    RAISE EXCEPTION 'fn_rollback_event_by_code: no event with code % (an exact code, not a prefix)', p_code;
  END IF;

  SELECT count(*) INTO v_tourn_count FROM tbl_tournament WHERE id_event = v_event_id;
  SELECT count(*) INTO v_result_count
    FROM tbl_result r JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   WHERE t.id_event = v_event_id;

  FOR v_tid IN SELECT id_tournament FROM tbl_tournament WHERE id_event = v_event_id LOOP
    PERFORM fn_delete_tournament_cascade(v_tid);
  END LOOP;

  RETURN jsonb_build_object(
    'event_id', v_event_id,
    'event_code', p_code,
    'tournaments_deleted', v_tourn_count,
    'results_deleted', v_result_count);
END;
$$;

COMMENT ON FUNCTION fn_rollback_event_by_code(TEXT) IS
  'Deletes every tournament of the event with exactly this code, in any season, '
  'through fn_delete_tournament_cascade; keeps the event row and its status. '
  'Used before a draft commit re-ingests a past event (international data repair). '
  'service_role only.';

REVOKE ALL ON FUNCTION fn_rollback_event_by_code(TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_rollback_event_by_code(TEXT) TO service_role;
