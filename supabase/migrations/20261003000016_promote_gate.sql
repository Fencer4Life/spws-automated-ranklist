-- =============================================================================
-- ADR-108 §5: the CERT gate's database checks (build step 7)
-- =============================================================================
-- After a CERT run, python/pipeline/promotion/gate.py reads the run record,
-- this function's findings on CERT, and PROD's preconditions, and blocks
-- promote on any identity, scoring or joined-bracket issue. The checks that
-- read committed data live here, in SQL, so they read exactly what is stored:
--
--   estimated_years     participants whose birth year is an estimate or unknown
--   pending_candidates  PENDING match candidates on the event's results
--   unscored            results without a score or a score component
--   active_revisions /  exactly one active scoring revision for the season,
--   unstamped           and every result of the event stamped with it
--   parity              the SS26.PARITY contract for every scored result: the
--                       engine's preview reproduces the stored components
--   type_code           tournaments typed against their code family (TT.CODE.06)
--   joined              siblings of one joined listing disagreeing on N or on
--                       the order; an order digit that is not the stored
--                       fencer's category. An order whose length is not N
--                       cannot be stored (chk_tournament_joined_order).
--   queue               recompute rows not DONE for the event, or for an event
--                       where a fencer the run touched has a result
--   fitting_years       the birth years each named fencer's results allow
--   joining             ADR-104 §7 joining checks that differ (information)
--   stored              the event's tournaments with N, order and results, for
--                       the comparison with the source listings
--
-- fn_ingest_run_gate records the gate's outcome on the run row (§4).
-- Service role only (ADR-083).
-- =============================================================================

-- The years in which a fencer's every categorised result fits its category:
-- by the season's end year, or, for a result labelled with that category, by
-- the calendar year of the tournament (the rule vw_vcat_violation accepts).
CREATE OR REPLACE FUNCTION fn_fencer_fitting_birth_years(p_id_fencer INT)
RETURNS INT[]
LANGUAGE sql STABLE
SET search_path = public
AS $$
  WITH res AS (
    SELECT t.enum_age_category AS cat,
           r.enum_source_age_category AS label,
           EXTRACT(YEAR FROM s.dt_end)::INT AS season_end,
           EXTRACT(YEAR FROM COALESCE(t.dt_tournament, e.dt_start))::INT AS cal_year
      FROM tbl_result r
      JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
      JOIN tbl_event e      ON e.id_event      = t.id_event
      JOIN tbl_season s     ON s.id_season     = e.id_season
     WHERE r.id_fencer = p_id_fencer AND t.enum_age_category IS NOT NULL),
  span AS (SELECT min(season_end) - 110 AS lo, max(season_end) AS hi FROM res)
  SELECT COALESCE(array_agg(y ORDER BY y), '{}'::INT[])
    FROM span, generate_series(span.lo, span.hi) y
   WHERE NOT EXISTS (
           SELECT 1 FROM res
            WHERE fn_age_category(y, res.season_end) IS DISTINCT FROM res.cat
              AND NOT (res.label IS NOT NULL AND res.label = res.cat
                       AND fn_age_category(y, COALESCE(res.cal_year, res.season_end)) IS NOT DISTINCT FROM res.cat));
$$;

COMMENT ON FUNCTION fn_fencer_fitting_birth_years(INT) IS
  'ADR-108 §5 (G2): the birth years in which every categorised result of the fencer fits its category; empty when none does or he has none.';

CREATE OR REPLACE FUNCTION fn_promote_gate_checks(p_event_code TEXT, p_fencer_ids INT[] DEFAULT '{}')
RETURNS JSONB
LANGUAGE plpgsql STABLE
SET search_path = public
AS $$
DECLARE
  v_event  tbl_event%ROWTYPE;
  v_active INT;
  v_rev    INT;
BEGIN
  SELECT * INTO v_event FROM tbl_event WHERE txt_code = p_event_code;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'GATE_EVENT_NOT_FOUND: %', p_event_code;
  END IF;

  SELECT count(*), max(id_revision) INTO v_active, v_rev
    FROM tbl_scoring_config_revision
   WHERE id_season = v_event.id_season AND bool_active;

  RETURN jsonb_build_object(
    'event', p_event_code,

    'estimated_years', COALESCE((
      SELECT jsonb_agg(x ORDER BY x->>'surname', x->>'first_name') FROM (
        SELECT DISTINCT jsonb_build_object('id_fencer', f.id_fencer, 'surname', f.txt_surname,
                                           'first_name', f.txt_first_name, 'birth_year', f.int_birth_year) AS x
          FROM tbl_result r
          JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
          JOIN tbl_fencer f     ON f.id_fencer     = r.id_fencer
         WHERE t.id_event = v_event.id_event
           AND (f.bool_birth_year_estimated OR f.int_birth_year IS NULL)) d), '[]'::JSONB),

    'pending_candidates', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('id_result', mc.id_result, 'tournament', t.txt_code,
                                          'scraped_name', mc.txt_scraped_name, 'id_fencer', mc.id_fencer)
                       ORDER BY t.txt_code, mc.txt_scraped_name)
        FROM tbl_match_candidate mc
        JOIN tbl_result r     ON r.id_result     = mc.id_result
        JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
       WHERE t.id_event = v_event.id_event AND mc.enum_status = 'PENDING'), '[]'::JSONB),

    'unscored', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('id_result', r.id_result, 'id_fencer', r.id_fencer,
                                          'tournament', t.txt_code, 'place', r.int_place)
                       ORDER BY t.txt_code, r.int_place)
        FROM tbl_result r
        JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
       WHERE t.id_event = v_event.id_event
         AND (r.num_final_score IS NULL OR r.num_place_pts IS NULL OR r.num_de_bonus IS NULL
              OR r.num_podium_bonus IS NULL OR r.ts_points_calc IS NULL)), '[]'::JSONB),

    'active_revisions', v_active,

    'unstamped', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('id_result', r.id_result, 'id_fencer', r.id_fencer,
                                          'tournament', t.txt_code, 'place', r.int_place)
                       ORDER BY t.txt_code, r.int_place)
        FROM tbl_result r
        JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
       WHERE t.id_event = v_event.id_event
         AND r.id_scoring_revision IS DISTINCT FROM v_rev), '[]'::JSONB),

    'parity', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'id_result', r.id_result, 'id_fencer', r.id_fencer, 'tournament', t.txt_code, 'place', r.int_place,
               'stored', jsonb_build_object('place_pts', r.num_place_pts, 'de', r.num_de_bonus,
                                            'podium', r.num_podium_bonus, 'final', r.num_final_score),
               'preview', jsonb_build_object('place_pts', pv.num_place_pts, 'de', pv.num_de_bonus,
                                             'podium', pv.num_podium_bonus, 'final', pv.num_final_score))
             ORDER BY t.txt_code, r.int_place)
        FROM tbl_result r
        JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
        CROSS JOIN LATERAL fn_preview_tournament_score(t.id_tournament, r.int_place) pv
       WHERE t.id_event = v_event.id_event
         AND r.num_final_score IS NOT NULL
         AND (pv.num_final_score  IS DISTINCT FROM r.num_final_score
           OR pv.num_place_pts    IS DISTINCT FROM r.num_place_pts
           OR pv.num_de_bonus     IS DISTINCT FROM r.num_de_bonus
           OR pv.num_podium_bonus IS DISTINCT FROM r.num_podium_bonus)), '[]'::JSONB),

    'type_code', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('tournament', t.txt_code, 'type', t.enum_type,
                                          'expected', fn_tournament_type_for_code(t.txt_code))
                       ORDER BY t.txt_code)
        FROM tbl_tournament t
       WHERE t.id_event = v_event.id_event
         AND fn_tournament_type_for_code(t.txt_code) IS NOT NULL
         AND fn_tournament_type_for_code(t.txt_code) IS DISTINCT FROM t.enum_type::TEXT), '[]'::JSONB),

    'joined', COALESCE((
      SELECT jsonb_agg(x ORDER BY x->>'tournament', x->>'problem') FROM (
        SELECT jsonb_build_object('tournament', string_agg(t.txt_code, ', ' ORDER BY t.txt_code),
                                  'listing', t.url_results,
                                  'problem', 'siblings disagree on N or on the category order') AS x
          FROM tbl_tournament t
         WHERE t.id_event = v_event.id_event AND t.txt_joined_order IS NOT NULL
         GROUP BY t.enum_weapon, t.enum_gender, t.url_results
        HAVING count(DISTINCT (t.int_participant_count, t.txt_joined_order)) > 1
        UNION ALL
        SELECT jsonb_build_object('tournament', t.txt_code, 'listing', t.url_results,
                                  'problem', format('place %s digit %s, but the fencer is %s', r.int_place,
                                                    NULLIF(substr(t.txt_joined_order, r.int_place, 1), ''),
                                                    t.enum_age_category))
          FROM tbl_tournament t
          JOIN tbl_result r ON r.id_tournament = t.id_tournament
         WHERE t.id_event = v_event.id_event AND t.txt_joined_order IS NOT NULL
           AND NULLIF(substr(t.txt_joined_order, r.int_place, 1), '') IS DISTINCT FROM substr(t.enum_age_category::TEXT, 2, 1)
      ) d), '[]'::JSONB),

    'queue', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('event', e2.txt_code, 'status', q.enum_status, 'n', q.n)
                       ORDER BY e2.txt_code, q.enum_status)
        FROM (SELECT id_event, enum_status, count(*) AS n
                FROM tbl_recompute_queue
               WHERE enum_status <> 'DONE'
               GROUP BY id_event, enum_status) q
        JOIN tbl_event e2 ON e2.id_event = q.id_event
       WHERE q.id_event = v_event.id_event
          OR q.id_event IN (SELECT t.id_event
                              FROM tbl_result r JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
                             WHERE r.id_fencer = ANY (COALESCE(p_fencer_ids, '{}'::INT[])))), '[]'::JSONB),

    'fitting_years', COALESCE((
      SELECT jsonb_object_agg(i::TEXT, to_jsonb(fn_fencer_fitting_birth_years(i)))
        FROM unnest(COALESCE(p_fencer_ids, '{}'::INT[])) i), '{}'::JSONB),

    'joining', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('weapon', j.enum_weapon, 'gender', j.enum_gender,
                                          'fenced', j.txt_fenced, 'rule', j.txt_rule)
                       ORDER BY j.enum_weapon, j.enum_gender)
        FROM tbl_joining_check j
       WHERE j.id_event = v_event.id_event AND NOT j.bool_match), '[]'::JSONB),

    'stored', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'tournament', t.txt_code, 'url', t.url_results, 'weapon', t.enum_weapon, 'gender', t.enum_gender,
               'category', t.enum_age_category, 'n', t.int_participant_count, 'order', t.txt_joined_order,
               'results', COALESCE((SELECT jsonb_agg(jsonb_build_object('scraped_name', r.txt_scraped_name,
                                                                        'place', r.int_place, 'id_fencer', r.id_fencer)
                                                     ORDER BY r.int_place, r.txt_scraped_name)
                                      FROM tbl_result r WHERE r.id_tournament = t.id_tournament), '[]'::JSONB))
             ORDER BY t.txt_code)
        FROM tbl_tournament t
       WHERE t.id_event = v_event.id_event), '[]'::JSONB)
  );
END;
$$;

COMMENT ON FUNCTION fn_promote_gate_checks(TEXT, INT[]) IS
  'ADR-108 §5: the CERT gate''s database checks for one event, each a list of findings; p_fencer_ids are the fencers whose master data the run changed.';

CREATE OR REPLACE FUNCTION fn_ingest_run_gate(p_id BIGINT, p_gate JSONB)
RETURNS VOID
LANGUAGE plpgsql VOLATILE
SET search_path = public
AS $$
BEGIN
  UPDATE tbl_ingest_run SET jsonb_gate = p_gate WHERE id_ingest_run = p_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'INGEST_RUN_NOT_FOUND: %', p_id;
  END IF;
END;
$$;

COMMENT ON FUNCTION fn_ingest_run_gate(BIGINT, JSONB) IS
  'ADR-108 §4: record the gate''s outcome on a run row.';

REVOKE ALL ON FUNCTION fn_fencer_fitting_birth_years(INT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_promote_gate_checks(TEXT, INT[]) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_ingest_run_gate(BIGINT, JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_fencer_fitting_birth_years(INT) TO service_role;
GRANT EXECUTE ON FUNCTION fn_promote_gate_checks(TEXT, INT[]) TO service_role;
GRANT EXECUTE ON FUNCTION fn_ingest_run_gate(BIGINT, JSONB) TO service_role;
