-- =============================================================================
-- fn_delete_event — Durable admin tool for full event removal (ADR-025 amendment)
-- =============================================================================
-- Problem: fn_rollback_event wipes child tournaments + results and resets the
-- event to PLANNED, but leaves the tbl_event row. When an event was created
-- in error (wrong-ingest, erroneous scrape, or a dedup bug that synthesised a
-- phantom event), you need both rollback AND removal of the event row itself.
--
-- Historically this was done as two separate DDL steps via the Management API:
--   1. SELECT fn_rollback_event('PREFIX')
--   2. DELETE FROM tbl_event WHERE txt_code = 'PREFIX-...'
--
-- That's error-prone (easy to forget step 2) and not idempotently recoverable.
-- fn_delete_event packages both into a single transactional RPC with the same
-- permission model as fn_rollback_event (authenticated only).
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_delete_event(p_prefix TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_event_id      INT;
  v_event_code    TEXT;
  v_tourn_count   INT := 0;
  v_result_count  INT := 0;
  v_tid           INT;
BEGIN
  -- Reuse the active-season prefix resolver (raises on no-match)
  v_event_id := _resolve_event_prefix(p_prefix);

  SELECT txt_code INTO v_event_code
    FROM tbl_event WHERE id_event = v_event_id;

  -- Count before deletion (for the summary payload)
  SELECT COUNT(*) INTO v_tourn_count
    FROM tbl_tournament WHERE id_event = v_event_id;

  SELECT COUNT(*) INTO v_result_count
    FROM tbl_result r
    JOIN tbl_tournament t ON r.id_tournament = t.id_tournament
   WHERE t.id_event = v_event_id;

  -- Cascade-delete every child tournament (also wipes tbl_result +
  -- tbl_match_candidate + fencer_scores_rolling cache via its own cascade)
  FOR v_tid IN SELECT id_tournament FROM tbl_tournament WHERE id_event = v_event_id
  LOOP
    PERFORM fn_delete_tournament_cascade(v_tid);
  END LOOP;

  -- Finally delete the event row itself
  DELETE FROM tbl_event WHERE id_event = v_event_id;

  RETURN jsonb_build_object(
    'status',              'DELETED',
    'event_id',            v_event_id,
    'event_code',          v_event_code,
    'tournaments_deleted', v_tourn_count,
    'results_deleted',     v_result_count,
    'event_deleted',       TRUE
  );
END;
$$;

COMMENT ON FUNCTION fn_delete_event(TEXT) IS
  'Admin tool: rollback + delete event row. For erroneous ingests / scrapes. '
  'Accepts an event-code prefix matching in the active season (same resolver '
  'as fn_rollback_event). Returns summary JSONB. See ADR-025.';

REVOKE EXECUTE ON FUNCTION fn_delete_event(TEXT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_delete_event(TEXT) TO authenticated;
