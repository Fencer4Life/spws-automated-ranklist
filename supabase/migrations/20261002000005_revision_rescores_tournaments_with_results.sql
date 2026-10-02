-- =============================================================================
-- The governed revision rescores the tournaments that have results (REV.EMPTY)
-- =============================================================================
-- fn_revise_and_rescore_season (20260919000006, ADR-097) rescored every SCORED
-- tournament of the season. 2023/24, 2024/25 and 2025/26 hold SCORED
-- tournaments with no participant count and no results (18 on CERT and PROD);
-- scoring one raises, so no locked season could be revised. Found on
-- 2026-10-02 while setting the EVF minimum to 1 (ADR-066 amendment). The
-- function is otherwise unchanged; its privileges carry over.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_revise_and_rescore_season(p_id_season integer, p_new_config jsonb, p_new_engine text, p_reason text, p_actor text, p_board_ref text DEFAULT NULL::text)
 RETURNS TABLE(id_revision integer, rescored_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_engine_id     INT;
  v_config        JSONB;
  v_new_revision  INT;
  v_rescored      INT := 0;
  v_tournament    RECORD;
  v_bad_count     INT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM tbl_season WHERE id_season = p_id_season) THEN
    RAISE EXCEPTION 'Season % does not exist', p_id_season;
  END IF;
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'p_reason is required and must not be empty';
  END IF;
  IF p_actor IS NULL OR btrim(p_actor) = '' THEN
    RAISE EXCEPTION 'p_actor is required and must not be empty';
  END IF;

  -- Resolve p_new_engine to an EXISTING engine id -- this function never
  -- creates one. A new formula is a code change (a new released engine
  -- version), not something a data revision can conjure.
  IF p_new_engine IS NOT NULL THEN
    SELECT id_engine INTO v_engine_id
      FROM tbl_scoring_engine WHERE txt_code = p_new_engine;
    IF v_engine_id IS NULL THEN
      RAISE EXCEPTION 'Unknown scoring engine: %', p_new_engine;
    END IF;
  END IF;

  -- Apply the new config -- same COALESCE-over-current semantics as
  -- ordinary import, but through the lock-free write path: this function
  -- IS the authorized exception to the lock fn_import_scoring_config
  -- enforces for everyone else.
  v_config := p_new_config || jsonb_build_object('id_season', p_id_season);
  IF p_new_engine IS NOT NULL THEN
    v_config := v_config || jsonb_build_object('engine_code', p_new_engine);
  END IF;
  PERFORM fn_apply_scoring_config_write(v_config);

  -- New revision row, activated right after deactivating its sibling.
  -- Deliberately TWO sequential statements, not one WITH-CTE combining both:
  -- Postgres does not guarantee a data-modifying CTE's effects are visible
  -- to the main statement's own constraint checks within that same
  -- statement, and uq_scoring_config_revision_active (a partial unique
  -- index) reproducibly raised a duplicate-key violation here when both
  -- were combined -- the deactivating UPDATE and the activating INSERT must
  -- run as separate statements so the index sees them in order. One rescore
  -- pass below either way, not two.
  UPDATE tbl_scoring_config_revision
     SET bool_active = FALSE
   WHERE id_season = p_id_season AND bool_active;

  INSERT INTO tbl_scoring_config_revision
    (id_season, id_engine, json_snapshot, txt_actor, txt_reason, txt_board_ref, bool_active)
  VALUES (
    p_id_season,
    COALESCE(v_engine_id, (SELECT id_scoring_engine FROM tbl_season WHERE id_season = p_id_season)),
    fn_export_scoring_config(p_id_season),
    p_actor, p_reason, p_board_ref, TRUE
  )
  RETURNING tbl_scoring_config_revision.id_revision INTO v_new_revision;

  UPDATE tbl_season
     SET id_active_scoring_revision = v_new_revision
   WHERE id_season = p_id_season;

  -- Rescore every already-scored tournament that has results --
  -- fn_calc_tournament_scores stamps each touched result with whichever
  -- revision is CURRENTLY active, which is now the new one (activated above).
  -- A SCORED tournament without results has nothing to rescore, and scoring
  -- it raises for its missing participant count (REV.EMPTY, 2026-10-02).
  FOR v_tournament IN
    SELECT t.id_tournament
      FROM tbl_tournament t
      JOIN tbl_event e ON e.id_event = t.id_event
     WHERE e.id_season = p_id_season
       AND t.enum_import_status = 'SCORED'
       AND EXISTS (SELECT 1 FROM tbl_result r WHERE r.id_tournament = t.id_tournament)
  LOOP
    PERFORM fn_calc_tournament_scores(v_tournament.id_tournament);
    v_rescored := v_rescored + 1;
  END LOOP;

  -- SS26.REVISION.06's invariant, asserted inline: no result in this season
  -- references any revision other than the new one. A mismatch raises --
  -- the whole transaction, including the activation above, rolls back
  -- (SS26.REVISION.07/.08).
  SELECT COUNT(*) INTO v_bad_count
    FROM tbl_result r
    JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
    JOIN tbl_event e ON e.id_event = t.id_event
   WHERE e.id_season = p_id_season
     AND r.id_scoring_revision IS NOT NULL
     AND r.id_scoring_revision <> v_new_revision;

  IF v_bad_count > 0 THEN
    RAISE EXCEPTION
      'Revision activation invariant violated: % result(s) in season % still reference a stale revision',
      v_bad_count, p_id_season;
  END IF;

  RETURN QUERY SELECT v_new_revision, v_rescored;
END;
$function$;
