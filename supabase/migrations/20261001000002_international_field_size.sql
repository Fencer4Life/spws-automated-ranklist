-- =============================================================================
-- ADR-105: an international result keeps the whole source bracket as N
-- =============================================================================
-- doc/plans/international-field-size-root-cause-fix-2026-10-01.html, release 1
-- steps 3-4. Flips INTL.RPC.01, 03 and 04 in
-- supabase/tests/86_international_field.sql from RED to GREEN; 02, 05 and 06
-- pin the behaviour that stays.
--
-- THE DEFECT
--
--   Only Polish fencers are written for PEW, MEW, MSW and PSW (ADR-038), so
--   the rows a tournament holds are never its bracket. Two database paths
--   recounted them anyway and stored the Polish head-count as N:
--
--   1. fn_commit_event_draft overwrote every joint-pool sibling's N with
--      COUNT(tbl_result). That is the ADR-049 2026-06-04 per-V-cat rule, and
--      it is right for a domestic split pool, where every fencer is stored.
--      For an international bracket it turned "31st of 60" into a result in
--      a field of 2.
--   2. fn_ingest_tournament_results fell back to jsonb_array_length(p_results)
--      when no count was passed, which for an international tournament is
--      again the Polish head-count.
--
-- WHAT CHANGES
--
--   1. fn_commit_event_draft: the joint-sibling recount gains
--      enum_type IN ('PPW', 'MPW'). International siblings keep the N the
--      draft carried, and so do PZSz PPS/MPS, whose stored veterans are a
--      subset of a senior field. Nothing else in the function moves.
--   2. fn_ingest_tournament_results: for PEW/MEW/MSW/PSW it raises when
--      p_participant_count is NULL, and when the highest place written is
--      above it. Both checks run before the DELETEs, so a refused call leaves
--      the stored result untouched. Domestic writes keep the fallback.
--
-- Both are CREATE OR REPLACE with unchanged signatures, so the ADR-083 grants
-- (authenticated and service_role) and the ingest RPC's SECURITY DEFINER
-- carry over. This migration repairs no stored row; the damaged brackets are
-- re-ingested from their organisers' sources under a separate plan.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_commit_event_draft(p_run_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
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
            enum_parser_kind, dt_last_scraped, bool_joint_pool_split,
            txt_joined_order
        )
        SELECT id_event, txt_code, txt_name, enum_type, num_multiplier,
               enum_age_category, enum_weapon, enum_gender, dt_tournament,
               int_participant_count, txt_import_status_reason,
               enum_import_status, url_results, txt_source_url_used,
               enum_parser_kind, dt_last_scraped, bool_joint_pool_split,
               txt_joined_order
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
        enum_source_age_category, enum_score_method,
        num_joined_premium, num_cap_reduction, int_category_steps
    )
    SELECT rd.id_fencer, m.id_tournament, rd.int_place, rd.enum_fencer_age_category,
           rd.txt_cross_cat, rd.num_place_pts, rd.num_de_bonus, rd.num_podium_bonus,
           rd.num_final_score, rd.ts_points_calc,
           rd.txt_scraped_name, rd.num_match_confidence, rd.enum_match_method,
           rd.enum_source_age_category, rd.enum_score_method,
           rd.num_joined_premium, rd.num_cap_reduction, rd.int_category_steps
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
    -- ADR-104 §3: a tournament that carries a category order keeps the joined
    -- N; the order's length is N and the joined engine scores by it.
    -- ADR-105: the recount is domestic only. An international tournament
    -- holds only its Polish rows (ADR-038), so its rows are never its bracket;
    -- it keeps the source N the draft carried.
    UPDATE tbl_tournament t
       SET int_participant_count = ps.sz
      FROM (
        SELECT tt.id_tournament,
               COUNT(r.id_result)::INT AS sz
          FROM tbl_tournament tt
          JOIN _commit_map m ON m.id_tournament = tt.id_tournament
          JOIN tbl_result r ON r.id_tournament = tt.id_tournament
         WHERE tt.bool_joint_pool_split = TRUE
           AND tt.txt_joined_order IS NULL
           AND tt.enum_type IN ('PPW', 'MPW')
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
$function$;

CREATE OR REPLACE FUNCTION public.fn_ingest_tournament_results(p_tournament_id integer, p_results jsonb, p_participant_count integer DEFAULT NULL::integer, p_joined_order text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_count           INT;
  v_row             JSONB;
  v_result_id       INT;
  v_fencer_id       INT;
  v_event_id        INT;
  v_legacy_status   TEXT;
  v_method_text     TEXT;
  v_method          enum_match_method;
  v_source_vcat     enum_age_category;
  v_type            enum_tournament_type;
  v_max_place       INT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM tbl_tournament WHERE id_tournament = p_tournament_id) THEN
    RAISE EXCEPTION 'Tournament % does not exist', p_tournament_id;
  END IF;

  IF p_results IS NULL OR jsonb_array_length(p_results) = 0 THEN
    RAISE EXCEPTION 'Results array is empty';
  END IF;

  SELECT id_event, enum_type INTO v_event_id, v_type
    FROM tbl_tournament WHERE id_tournament = p_tournament_id;

  -- ADR-105: an international tournament holds only its Polish rows
  -- (ADR-038), so neither the payload nor the order can stand in for its N.
  -- Refuse before anything is deleted, so a bad call leaves the stored
  -- result as it was.
  IF v_type IN ('PEW', 'MEW', 'MSW', 'PSW') THEN
    IF p_participant_count IS NULL THEN
      RAISE EXCEPTION 'International tournament % needs its source bracket size: p_participant_count is required (ADR-105)',
        p_tournament_id;
    END IF;
    SELECT max((r ->> 'int_place')::INT) INTO v_max_place
      FROM jsonb_array_elements(p_results) AS r;
    IF v_max_place > p_participant_count THEN
      RAISE EXCEPTION 'International tournament %: place % exceeds the source bracket of % (ADR-105)',
        p_tournament_id, v_max_place, p_participant_count;
    END IF;
  END IF;

  DELETE FROM tbl_match_candidate
  WHERE id_result IN (
    SELECT id_result FROM tbl_result WHERE id_tournament = p_tournament_id
  );

  DELETE FROM tbl_result WHERE id_tournament = p_tournament_id;

  -- ADR-104 §3: the order has one digit per place of the whole listing, so it
  -- also gives N when no count is passed.
  -- The payload-length fallback is reached only by a domestic tournament;
  -- an international one was refused above without a count (ADR-105).
  v_count := COALESCE(p_participant_count, length(p_joined_order), jsonb_array_length(p_results));

  UPDATE tbl_tournament
  SET int_participant_count = v_count,
      txt_joined_order      = p_joined_order,
      enum_import_status    = 'IMPORTED',
      ts_updated            = NOW()
  WHERE id_tournament = p_tournament_id;

  FOR v_row IN SELECT jsonb_array_elements(p_results)
  LOOP
    v_fencer_id := (v_row ->> 'id_fencer')::INT;
    IF NOT EXISTS (SELECT 1 FROM tbl_fencer WHERE id_fencer = v_fencer_id) THEN
      RAISE EXCEPTION 'Fencer % does not exist', v_fencer_id;
    END IF;

    -- NEW: direct enum_match_method from payload (preserves NULL).
    -- When the key is present in the payload object, trust it verbatim —
    -- even if the value is JSON null or empty string (both map to NULL).
    -- When the key is absent, fall back to legacy enum_match_status with
    -- the historical default of AUTO_MATCH.
    IF v_row ? 'enum_match_method' THEN
      v_method_text := v_row ->> 'enum_match_method';
      IF v_method_text IS NULL OR v_method_text = '' THEN
        v_method := NULL;
      ELSE
        v_method := v_method_text::enum_match_method;
      END IF;
    ELSE
      v_legacy_status := COALESCE(v_row ->> 'enum_match_status', 'AUTO_MATCHED');
      v_method := CASE v_legacy_status
        WHEN 'AUTO_MATCHED' THEN 'AUTO_MATCH'::enum_match_method
        WHEN 'APPROVED'     THEN 'USER_CONFIRMED'::enum_match_method
        WHEN 'NEW_FENCER'   THEN 'AUTO_CREATED'::enum_match_method
        ELSE 'AUTO_MATCH'::enum_match_method
      END;
    END IF;

    -- For the legacy tbl_match_candidate row, derive a status from the
    -- (possibly NULL) method. Match-candidate enum has no NULL value, so
    -- a NULL method maps to AUTO_MATCHED (workflow-state best guess) —
    -- this preserves prior behavior for that table since it's slated for
    -- removal in Phase 6.
    v_legacy_status := COALESCE(v_row ->> 'enum_match_status',
      CASE v_method::TEXT
        WHEN 'AUTO_MATCH'      THEN 'AUTO_MATCHED'
        WHEN 'USER_CONFIRMED'  THEN 'APPROVED'
        WHEN 'AUTO_CREATED'    THEN 'NEW_FENCER'
        ELSE 'AUTO_MATCHED'
      END);

    v_source_vcat := CASE
      WHEN v_row ? 'enum_source_age_category' AND NULLIF(v_row ->> 'enum_source_age_category', '') IS NOT NULL
        THEN (v_row ->> 'enum_source_age_category')::enum_age_category
      ELSE NULL
    END;

    INSERT INTO tbl_result (
      id_fencer, id_tournament, int_place,
      txt_scraped_name, num_match_confidence, enum_match_method,
      enum_source_age_category
    )
    VALUES (
      v_fencer_id,
      p_tournament_id,
      (v_row ->> 'int_place')::INT,
      v_row ->> 'txt_scraped_name',
      COALESCE((v_row ->> 'num_confidence')::NUMERIC(5,2), 100),
      v_method,
      v_source_vcat
    )
    RETURNING id_result INTO v_result_id;

    INSERT INTO tbl_match_candidate (
      id_result, id_fencer,
      txt_scraped_name, num_confidence, enum_status
    ) VALUES (
      v_result_id,
      v_fencer_id,
      v_row ->> 'txt_scraped_name',
      COALESCE((v_row ->> 'num_confidence')::NUMERIC, 100),
      v_legacy_status::enum_match_status
    );
  END LOOP;

  PERFORM fn_calc_tournament_scores(p_tournament_id);

  UPDATE tbl_event
  SET enum_status = 'IN_PROGRESS', ts_updated = NOW()
  WHERE id_event = v_event_id
    AND enum_status = 'PLANNED';

  RETURN jsonb_build_object(
    'tournament_id',     p_tournament_id,
    'results_count',     jsonb_array_length(p_results),
    'participant_count', v_count,
    'status',            'IMPORTED'
  );
END;
$function$;
