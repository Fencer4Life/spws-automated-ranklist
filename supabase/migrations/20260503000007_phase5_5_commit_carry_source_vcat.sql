-- =============================================================================
-- Phase 5.5 — fn_commit_event_draft + vw_fencer_aliases learn the source V-cat
-- =============================================================================
-- Plan-test-IDs 5.18.B + 5.18.C.
-- Companion to migration 20260503000006 (which added the column).
--
-- Single change to fn_commit_event_draft: the INSERT INTO tbl_result column
-- list and SELECT both gain `enum_source_age_category`. Everything else is
-- identical to the body in 20260502000011_phase5_commit_runs_scoring.sql.
--
-- vw_fencer_aliases gains `latest_source_category_hint`, the source V-cat
-- of the most-recent draft/live row keyed on the fencer. fn_list_fencer_aliases
-- republishes its TABLE signature so RPC consumers see the new column.
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
  'Phase 5.5 (5.18) revision — body identical to 20260502000011 except '
  'enum_source_age_category is now copied draft → live so the alias-modal '
  'BY pre-fill can use the source V-cat (parsed.category_hint) instead '
  'of the misroute destination V-cat. Returns tournaments_committed, '
  'results_committed, joint_pool_siblings_flagged, history_rows, '
  'tournaments_scored.';


-- ---------------------------------------------------------------------------
-- vw_fencer_aliases — expose latest_source_category_hint
-- ---------------------------------------------------------------------------
DROP VIEW IF EXISTS vw_fencer_aliases;

CREATE VIEW vw_fencer_aliases AS
WITH safe_aliases AS (
  SELECT
    f.id_fencer,
    f.txt_first_name,
    f.txt_surname,
    CASE WHEN jsonb_typeof(f.json_name_aliases) = 'array'
         THEN f.json_name_aliases ELSE '[]'::jsonb END AS json_name_aliases,
    CASE WHEN jsonb_typeof(f.json_revoked_aliases) = 'array'
         THEN f.json_revoked_aliases ELSE '[]'::jsonb END AS json_revoked_aliases,
    CASE WHEN jsonb_typeof(f.json_user_confirmed_aliases) = 'array'
         THEN f.json_user_confirmed_aliases ELSE '[]'::jsonb END AS json_user_confirmed_aliases,
    f.ts_updated AS ts_last_alias_added
  FROM tbl_fencer f
),
context AS (
  SELECT DISTINCT ON (id_fencer)
    id_fencer,
    enum_age_category::TEXT        AS category_hint,
    enum_source_age_category::TEXT AS source_category_hint,
    season_end_year
  FROM (
    SELECT
      d.id_fencer,
      td.enum_age_category,
      d.enum_source_age_category,
      EXTRACT(YEAR FROM s.dt_end)::INT AS season_end_year,
      td.dt_tournament,
      0 AS source_priority
    FROM tbl_result_draft d
    JOIN tbl_tournament_draft td ON td.id_tournament_draft = d.id_tournament_draft
    JOIN tbl_event e             ON e.id_event = td.id_event
    JOIN tbl_season s            ON s.id_season = e.id_season
    WHERE d.id_fencer IS NOT NULL
      AND td.enum_age_category IS NOT NULL
    UNION ALL
    SELECT
      r.id_fencer,
      t.enum_age_category,
      r.enum_source_age_category,
      EXTRACT(YEAR FROM s.dt_end)::INT AS season_end_year,
      t.dt_tournament,
      1 AS source_priority
    FROM tbl_result r
    JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
    JOIN tbl_event e      ON e.id_event = t.id_event
    JOIN tbl_season s     ON s.id_season = e.id_season
    WHERE r.id_fencer IS NOT NULL
      AND t.enum_age_category IS NOT NULL
  ) ctx
  ORDER BY id_fencer, source_priority, dt_tournament DESC NULLS LAST
)
SELECT
  sa.id_fencer,
  sa.txt_first_name,
  sa.txt_surname,
  sa.json_name_aliases,
  sa.json_revoked_aliases,
  sa.json_user_confirmed_aliases,
  jsonb_array_length(sa.json_name_aliases) AS alias_count,
  GREATEST(
    0,
    jsonb_array_length(sa.json_name_aliases)
    - (
        SELECT COUNT(*)::INT
        FROM jsonb_array_elements_text(sa.json_name_aliases) AS a(name)
        WHERE EXISTS (
          SELECT 1
          FROM jsonb_array_elements_text(sa.json_user_confirmed_aliases) AS c(name)
          WHERE c.name = a.name
        )
      )
  ) AS int_unreviewed_alias_count,
  sa.ts_last_alias_added,
  ctx.category_hint        AS latest_category_hint,
  ctx.source_category_hint AS latest_source_category_hint,
  ctx.season_end_year      AS latest_season_end_year
FROM safe_aliases sa
LEFT JOIN context ctx ON ctx.id_fencer = sa.id_fencer;

COMMENT ON VIEW vw_fencer_aliases IS
  'Phase 5.5 (5.18) — exposes latest_source_category_hint alongside the '
  'destination latest_category_hint. The Create-new-fencer-from-alias '
  'modal prefers source for BY pre-fill; falls back to destination if '
  'source is NULL (joint-pool source bracket).';


DROP FUNCTION IF EXISTS fn_list_fencer_aliases();

CREATE OR REPLACE FUNCTION fn_list_fencer_aliases()
RETURNS TABLE (
  id_fencer                     INT,
  txt_first_name                TEXT,
  txt_surname                   TEXT,
  json_name_aliases             JSONB,
  json_revoked_aliases          JSONB,
  json_user_confirmed_aliases   JSONB,
  alias_count                   INT,
  int_unreviewed_alias_count    INT,
  ts_last_alias_added           TIMESTAMPTZ,
  latest_category_hint          TEXT,
  latest_source_category_hint   TEXT,
  latest_season_end_year        INT
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT id_fencer, txt_first_name, txt_surname,
         json_name_aliases, json_revoked_aliases, json_user_confirmed_aliases,
         alias_count, int_unreviewed_alias_count,
         ts_last_alias_added,
         latest_category_hint, latest_source_category_hint, latest_season_end_year
    FROM vw_fencer_aliases
    ORDER BY int_unreviewed_alias_count DESC, alias_count DESC,
             txt_surname, txt_first_name;
$$;

REVOKE EXECUTE ON FUNCTION fn_list_fencer_aliases() FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_list_fencer_aliases() TO authenticated;

COMMENT ON FUNCTION fn_list_fencer_aliases() IS
  'Phase 5.5 (5.18) extension — returns latest_source_category_hint '
  '(parsed.category_hint at ingestion) alongside latest_category_hint '
  '(stage 7 destination). Frontend prefers source for the modal BY pre-fill.';

COMMIT;
