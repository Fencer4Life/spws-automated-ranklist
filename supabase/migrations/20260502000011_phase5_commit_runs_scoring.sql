-- ===========================================================================
-- Phase 5 — fn_commit_event_draft now scores newly-committed tournaments
-- ===========================================================================
-- Before this migration: fn_commit_event_draft moved drafts → live but left
-- tournaments at enum_import_status='PLANNED' (the default) with NULL
-- scoring fields on every tbl_result row. Phase 5 historical re-ingests
-- need every committed tournament fully SCORED — the events happened
-- 3 years ago, results are final, no async scoring step.
--
-- Fix: after the draft → live transfer, loop through newly-committed
-- tournaments and call fn_calc_tournament_scores(id_tournament) on each.
-- That function:
--   * Computes num_place_pts / num_de_bonus / num_podium_bonus / num_final_score
--     across all tbl_result rows for the tournament
--   * Sets enum_import_status='SCORED' on the parent tbl_tournament row
--   * Stamps ts_points_calc on every result row
--
-- Same return shape; the JSONB result gets a new `tournaments_scored` field
-- so callers (phase5_runner) can log it.
-- ===========================================================================

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
            'results_committed', 0,
            'joint_pool_siblings_flagged', 0,
            'history_rows', 0,
            'tournaments_scored', 0
        );
    END IF;

    CREATE TEMP TABLE _commit_map (
        id_tournament_draft INT NOT NULL,
        id_tournament       INT NOT NULL
    ) ON COMMIT DROP;

    WITH inserted AS (
        INSERT INTO tbl_tournament (
            id_event, txt_code, txt_name, enum_type, num_multiplier,
            dt_tournament, int_participant_count, enum_weapon, enum_gender,
            enum_age_category, url_results, enum_import_status,
            txt_import_status_reason, id_evf_competition, bool_joint_pool_split,
            enum_parser_kind, dt_last_scraped, txt_source_url_used
        )
        SELECT id_event, txt_code, txt_name, enum_type, num_multiplier,
               dt_tournament, int_participant_count, enum_weapon, enum_gender,
               enum_age_category, url_results, enum_import_status,
               txt_import_status_reason, id_evf_competition, bool_joint_pool_split,
               enum_parser_kind, dt_last_scraped, txt_source_url_used
          FROM tbl_tournament_draft
         WHERE txt_run_id = p_run_id
        RETURNING id_tournament, txt_code
    )
    INSERT INTO _commit_map (id_tournament_draft, id_tournament)
    SELECT td.id_tournament_draft, i.id_tournament
      FROM inserted i
      JOIN tbl_tournament_draft td ON td.txt_code = i.txt_code
                                  AND td.txt_run_id = p_run_id;

    GET DIAGNOSTICS v_committed_tournaments = ROW_COUNT;

    INSERT INTO tbl_result (
        id_fencer, id_tournament, int_place, enum_fencer_age_category,
        txt_cross_cat, num_place_pts, num_de_bonus, num_podium_bonus,
        num_final_score, ts_points_calc,
        txt_scraped_name, num_match_confidence, enum_match_method
    )
    SELECT rd.id_fencer, m.id_tournament, rd.int_place, rd.enum_fencer_age_category,
           rd.txt_cross_cat, rd.num_place_pts, rd.num_de_bonus, rd.num_podium_bonus,
           rd.num_final_score, rd.ts_points_calc,
           rd.txt_scraped_name, rd.num_match_confidence, rd.enum_match_method
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

    UPDATE tbl_tournament t
       SET int_participant_count = ps.sz
      FROM (
        SELECT tt.id_event, tt.enum_weapon, tt.enum_gender, tt.url_results,
               COUNT(r.id_result)::INT AS sz
          FROM tbl_tournament tt
          JOIN _commit_map m ON m.id_tournament = tt.id_tournament
          JOIN tbl_result r ON r.id_tournament = tt.id_tournament
         WHERE tt.bool_joint_pool_split = TRUE
         GROUP BY tt.id_event, tt.enum_weapon, tt.enum_gender, tt.url_results
      ) ps
     WHERE t.id_event    = ps.id_event
       AND t.enum_weapon = ps.enum_weapon
       AND t.enum_gender = ps.enum_gender
       AND t.url_results = ps.url_results
       AND t.bool_joint_pool_split = TRUE;

    -- Phase 5 — score every newly-committed tournament so it lands at
    -- enum_import_status='SCORED' with populated num_*_pts / num_final_score.
    -- These are historical results, not work-in-progress: they ARE scored,
    -- the rebuild just hasn't told the engine yet.
    FOR v_t IN SELECT id_tournament FROM _commit_map LOOP
        BEGIN
            PERFORM fn_calc_tournament_scores(v_t);
            v_tournaments_scored := v_tournaments_scored + 1;
        EXCEPTION WHEN OTHERS THEN
            -- Don't roll back the whole commit on a per-tournament scoring
            -- failure — log and continue. Operator sees PLANNED-status
            -- rows in the post-commit summary and can re-score manually.
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
        'results_committed', v_committed_results,
        'joint_pool_siblings_flagged', v_joint_flagged,
        'history_rows', v_history_rows,
        'tournaments_scored', v_tournaments_scored
    );
END;
$$;

COMMENT ON FUNCTION fn_commit_event_draft(UUID) IS
  'Phase 5 update — moves drafts → live, sets joint-pool flag, scores '
  'every newly-committed tournament via fn_calc_tournament_scores '
  '(enum_import_status → SCORED, num_*_pts populated), appends history, '
  'writes audit, deletes drafts. Returns JSONB counts incl. tournaments_scored.';

COMMIT;
