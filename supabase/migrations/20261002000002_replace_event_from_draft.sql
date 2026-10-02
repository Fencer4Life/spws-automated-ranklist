-- =============================================================================
-- fn_replace_event_from_draft — repair a past event from a draft run, atomically
-- =============================================================================
-- doc/plans/international-data-repair-batch-1-2026-10-01.html.
--
-- A repaired event is re-staged from its organiser's results into a draft run
-- (Phase 5). Committing it needs the stored tournaments gone first, because the
-- draft commit only inserts and tournament codes are unique. Two separate calls
-- (fn_rollback_event_by_code, then fn_commit_event_draft) would leave the event
-- with no results if the commit failed in between. This function does both in
-- one transaction:
--   1. refuses a run that has no drafts, whose drafts belong to another event,
--      or that holds an unresolved PENDING row (a guessed fencer with no match
--      method, which the commit would credit to the guess);
--   2. fn_rollback_event_by_code(p_event_code): the event's tournaments,
--      results and match candidates go, the event row stays;
--   3. fn_commit_event_draft(p_run_id): the run's tournaments and results are
--      written and scored.
-- An error in step 3 undoes step 2. The runner calls it after its own sign-off
-- check, which refuses while a suspected wrong match is unresolved
-- (phase5_runner --commit-run-id --replace-event).
--
-- service_role only (ADR-083). pgTAP REPAIR.RB.05–09 in
-- supabase/tests/89_rollback_event_by_code.sql.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_replace_event_from_draft(p_event_code TEXT, p_run_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_id INT;
  v_rolled   JSONB;
  v_commit   JSONB;
BEGIN
  SELECT id_event INTO v_event_id FROM tbl_event WHERE txt_code = p_event_code;
  IF v_event_id IS NULL THEN
    RAISE EXCEPTION 'fn_replace_event_from_draft: no event with code % (an exact code)', p_event_code;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM tbl_tournament_draft WHERE txt_run_id = p_run_id) THEN
    RAISE EXCEPTION 'fn_replace_event_from_draft: run % has no drafts', p_run_id;
  END IF;
  IF EXISTS (SELECT 1 FROM tbl_tournament_draft
              WHERE txt_run_id = p_run_id AND id_event IS DISTINCT FROM v_event_id) THEN
    RAISE EXCEPTION 'fn_replace_event_from_draft: run % has drafts of another event than %',
      p_run_id, p_event_code;
  END IF;

  IF EXISTS (SELECT 1 FROM tbl_result_draft
              WHERE txt_run_id = p_run_id AND id_fencer IS NOT NULL AND enum_match_method IS NULL) THEN
    RAISE EXCEPTION 'fn_replace_event_from_draft: run % has unresolved PENDING rows (a guessed fencer, no match method)',
      p_run_id;
  END IF;

  v_rolled := fn_rollback_event_by_code(p_event_code);
  v_commit := fn_commit_event_draft(p_run_id);

  RETURN jsonb_build_object('event_code', p_event_code, 'run_id', p_run_id,
                            'rolled_back', v_rolled, 'committed', v_commit);
END;
$$;

COMMENT ON FUNCTION fn_replace_event_from_draft(TEXT, UUID) IS
  'Replaces every tournament of the event with exactly this code by the tournaments '
  'and results of a draft run of that event, in one transaction: rollback by exact '
  'code, then fn_commit_event_draft. Used to repair a past event from its source. '
  'service_role only.';

REVOKE ALL ON FUNCTION fn_replace_event_from_draft(TEXT, UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_replace_event_from_draft(TEXT, UUID) TO service_role;
