-- =============================================================================
-- ADR-049 AMENDMENT (2026-06-04) — joint-pool int_participant_count is PER-V-CAT
-- =============================================================================
-- The original ADR-049 set every joint-pool sibling's int_participant_count to
-- the FULL physical pool size (sum of all siblings sharing one url_results).
-- Domain decision 2026-06-04: that is wrong. Each V-cat slice is ranked and
-- scored on its OWN field size, so int_participant_count must be the sibling's
-- own committed result count — never the summed full pool.
--
-- This migration redefines the two functions that wrote the summed value:
--   1. fn_commit_event_draft — the active draft→commit path. Body is identical
--      to 20260503000007 EXCEPT the joint-pool int_participant_count recompute
--      now groups by id_tournament (own count) instead of url_results (sum).
--   2. fn_backfill_joint_pool_split — one-shot remediation; its Step-2 recompute
--      switches from full-pool sum to per-tournament own count. It now doubles
--      as the in-place fix for already-committed joint pools (class-A bug) and
--      stays idempotent.
--
-- bool_joint_pool_split is retained as an informational badge (still flipped on
-- siblings sharing a url_results) but no longer drives the count.
-- fn_calc_tournament_scores is unchanged — it reads int_participant_count, which
-- is now per-V-cat correct.
--
-- See ADR-049 amendment + ADR-069 (participant-count URL validator).
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_commit_event_draft(p_run_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_committed_tournaments INT := 0;
    v_committed_results     INT := 0;
    v_joint_flagged         INT := 0;
    v_history_rows          INT := 0;
    v_tournaments_scored    INT := 0;
    v_t                     INT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM tbl_tournament_draft WHERE txt_run_id = p_run_id) THEN
        RETURN jsonb_build_object(
            'run_id', p_run_id,
            'tournaments_committed', 0,
            'results_committed',     0,
            'joint_pool_siblings_flagged', 0,
            'history_rows',          0,
            'tournaments_scored',    0
        );
    END IF;

    CREATE TEMP TABLE _commit_map (
        id_tournament_draft INT NOT NULL,
        id_tournament       INT NOT NULL
    ) ON COMMIT DROP;

    WITH ins AS (
        INSERT INTO tbl_tournament (
            id_event, txt_code, txt_name, enum_type, num_multiplier,
            enum_age_category, enum_weapon, enum_gender, dt_tournament,
            int_participant_count, txt_import_status_reason,
            enum_import_status, url_results, txt_source_url_used,
            enum_parser_kind, dt_last_scraped, bool_joint_pool_split
        )
        SELECT id_event, txt_code, txt_name, enum_type, num_multiplier,
               enum_age_category, enum_weapon, enum_gender, dt_tournament,
               int_participant_count, txt_import_status_reason,
               enum_import_status, url_results, txt_source_url_used,
               enum_parser_kind, dt_last_scraped, bool_joint_pool_split
          FROM tbl_tournament_draft
         WHERE txt_run_id = p_run_id
        RETURNING id_tournament, txt_code
    )
    INSERT INTO _commit_map (id_tournament_draft, id_tournament)
    SELECT td.id_tournament_draft, ins.id_tournament
      FROM ins
      JOIN tbl_tournament_draft td ON td.txt_code = ins.txt_code
     WHERE td.txt_run_id = p_run_id;

    GET DIAGNOSTICS v_committed_tournaments = ROW_COUNT;

    -- 5.18.B — added enum_source_age_category to BOTH sides so the source
    -- V-cat survives draft → live commit (alias-modal pre-fill needs it).
    INSERT INTO tbl_result (
        id_fencer, id_tournament, int_place, enum_fencer_age_category,
        txt_cross_cat, num_place_pts, num_de_bonus, num_podium_bonus,
        num_final_score, ts_points_calc,
        txt_scraped_name, num_match_confidence, enum_match_method,
        enum_source_age_category
    )
    SELECT rd.id_fencer, m.id_tournament, rd.int_place, rd.enum_fencer_age_category,
           rd.txt_cross_cat, rd.num_place_pts, rd.num_de_bonus, rd.num_podium_bonus,
           rd.num_final_score, rd.ts_points_calc,
           rd.txt_scraped_name, rd.num_match_confidence, rd.enum_match_method,
           rd.enum_source_age_category
      FROM tbl_result_draft rd
      JOIN _commit_map m ON m.id_tournament_draft = rd.id_tournament_draft
     WHERE rd.txt_run_id = p_run_id;

    GET DIAGNOSTICS v_committed_results = ROW_COUNT;

    UPDATE tbl_tournament t
       SET bool_joint_pool_split = TRUE
      FROM (
        SELECT t1.id_event, t1.enum_weapon, t1.enum_gender, t1.url_results
          FROM tbl_tournament t1
          JOIN _commit_map m ON m.id_tournament = t1.id_tournament
         WHERE t1.url_results IS NOT NULL AND t1.url_results <> ''
         GROUP BY t1.id_event, t1.enum_weapon, t1.enum_gender, t1.url_results
        HAVING COUNT(*) > 1
      ) g
     WHERE t.id_event    = g.id_event
       AND t.enum_weapon = g.enum_weapon
       AND t.enum_gender = g.enum_gender
       AND t.url_results = g.url_results
       AND t.bool_joint_pool_split = FALSE;

    GET DIAGNOSTICS v_joint_flagged = ROW_COUNT;

    -- ADR-049 AMENDED 2026-06-04: per-V-cat own count, NOT the full-pool sum.
    -- Group by id_tournament so each joint sibling stores ONLY its own result
    -- rows (was: GROUP BY url_results, which summed across all siblings).
    UPDATE tbl_tournament t
       SET int_participant_count = ps.sz
      FROM (
        SELECT tt.id_tournament,
               COUNT(r.id_result)::INT AS sz
          FROM tbl_tournament tt
          JOIN _commit_map m ON m.id_tournament = tt.id_tournament
          JOIN tbl_result r ON r.id_tournament = tt.id_tournament
         WHERE tt.bool_joint_pool_split = TRUE
         GROUP BY tt.id_tournament
      ) ps
     WHERE t.id_tournament = ps.id_tournament
       AND t.bool_joint_pool_split = TRUE;

    -- Score every newly-committed tournament. Phase 5 historical re-ingest:
    -- events are 3+ years old, results are final — no async scoring step.
    FOR v_t IN SELECT id_tournament FROM _commit_map LOOP
        BEGIN
            PERFORM fn_calc_tournament_scores(v_t);
            v_tournaments_scored := v_tournaments_scored + 1;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'fn_calc_tournament_scores(%) failed during commit %: %',
                          v_t, p_run_id, SQLERRM;
        END;
    END LOOP;

    INSERT INTO tbl_tournament_ingest_history (
        id_tournament, txt_run_id, enum_parser_kind, txt_source_url
    )
    SELECT m.id_tournament, p_run_id, td.enum_parser_kind, td.txt_source_url_used
      FROM tbl_tournament_draft td
      JOIN _commit_map m ON m.id_tournament_draft = td.id_tournament_draft
     WHERE td.txt_run_id = p_run_id
       AND td.enum_parser_kind IS NOT NULL;

    GET DIAGNOSTICS v_history_rows = ROW_COUNT;

    INSERT INTO tbl_event_ingest_history (
        id_event, txt_run_id, enum_parser_kind, txt_source_url
    )
    SELECT DISTINCT ON (td.id_event)
           td.id_event, p_run_id, td.enum_parser_kind, td.txt_source_url_used
      FROM tbl_tournament_draft td
     WHERE td.txt_run_id = p_run_id
       AND td.enum_parser_kind IS NOT NULL
     ORDER BY td.id_event, td.id_tournament_draft;

    INSERT INTO tbl_audit_log (
        txt_table_name, id_row, txt_action,
        jsonb_old_values, jsonb_new_values, txt_admin_user
    )
    SELECT 'tbl_tournament', m.id_tournament, 'DRAFT_COMMIT',
           NULL::JSONB,
           jsonb_build_object('run_id', p_run_id, 'committed_at', NOW()),
           current_setting('request.jwt.claims', TRUE)::JSONB->>'sub'
      FROM _commit_map m;

    DELETE FROM tbl_result_draft     WHERE txt_run_id = p_run_id;
    DELETE FROM tbl_tournament_draft WHERE txt_run_id = p_run_id;

    DROP TABLE _commit_map;

    RETURN jsonb_build_object(
        'run_id', p_run_id,
        'tournaments_committed', v_committed_tournaments,
        'results_committed',     v_committed_results,
        'joint_pool_siblings_flagged', v_joint_flagged,
        'history_rows',          v_history_rows,
        'tournaments_scored',    v_tournaments_scored
    );
END;
$$;

COMMENT ON FUNCTION fn_commit_event_draft(UUID) IS
  'Phase 5.5 body + ADR-049 amendment (2026-06-04): joint-pool '
  'int_participant_count is now each sibling''s OWN result count (per-V-cat), '
  'not the summed full physical pool. bool_joint_pool_split remains a badge. '
  'Returns tournaments_committed, results_committed, '
  'joint_pool_siblings_flagged, history_rows, tournaments_scored.';


-- ---------------------------------------------------------------------------
-- fn_backfill_joint_pool_split — Step 2 recompute switches to per-V-cat own
-- count. Flagging (Step 1) unchanged. Idempotent. Now also serves as the
-- in-place fix for already-committed joint pools whose counts were summed.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_backfill_joint_pool_split()
RETURNS TABLE (
    groups_detected   INT,
    siblings_flagged  INT,
    counts_rewritten  INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_groups   INT;
    v_flagged  INT;
    v_counts   INT;
BEGIN
    -- Step 1: flip the flag on every row that shares url_results with a
    -- sibling under the same (id_event, enum_weapon, enum_gender).
    UPDATE tbl_tournament t
       SET bool_joint_pool_split = TRUE
      FROM (
        SELECT id_event, enum_weapon, enum_gender, url_results
          FROM tbl_tournament
         WHERE url_results IS NOT NULL
           AND url_results <> ''
         GROUP BY id_event, enum_weapon, enum_gender, url_results
        HAVING COUNT(*) > 1
      ) g
     WHERE t.id_event      = g.id_event
       AND t.enum_weapon   = g.enum_weapon
       AND t.enum_gender   = g.enum_gender
       AND t.url_results   = g.url_results
       AND t.bool_joint_pool_split = FALSE;
    GET DIAGNOSTICS v_flagged = ROW_COUNT;

    -- Step 2 (ADR-049 amended 2026-06-04): set int_participant_count on every
    -- joint-pool member to its OWN result-row count (per-V-cat), NOT the
    -- summed full pool. Group by id_tournament.
    UPDATE tbl_tournament t
       SET int_participant_count = ps.sz
      FROM (
        SELECT tt.id_tournament,
               COUNT(r.id_result)::INT AS sz
          FROM tbl_tournament tt
          JOIN tbl_result r ON r.id_tournament = tt.id_tournament
         WHERE tt.bool_joint_pool_split = TRUE
         GROUP BY tt.id_tournament
      ) ps
     WHERE t.id_tournament = ps.id_tournament
       AND t.bool_joint_pool_split = TRUE
       AND t.int_participant_count IS DISTINCT FROM ps.sz;
    GET DIAGNOSTICS v_counts = ROW_COUNT;

    -- Group count = number of distinct joint-pool groups currently flagged.
    SELECT COUNT(*)::INT INTO v_groups
      FROM (
        SELECT 1
          FROM tbl_tournament
         WHERE bool_joint_pool_split = TRUE
         GROUP BY id_event, enum_weapon, enum_gender, url_results
      ) sg;

    RETURN QUERY SELECT v_groups, v_flagged, v_counts;
END;
$$;

COMMENT ON FUNCTION fn_backfill_joint_pool_split() IS
  'ADR-049 backfill (amended 2026-06-04). Flags pre-existing joint-pool '
  'siblings (shared url_results) and sets int_participant_count = each '
  'sibling''s OWN result count (per-V-cat), not the summed full pool. '
  'Idempotent; also repairs already-committed summed counts in place.';

COMMIT;
