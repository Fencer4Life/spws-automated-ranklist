-- =============================================================================
-- REPAIR.RB — roll back a past event by its exact code
-- =============================================================================
-- Acceptance IDs for doc/plans/international-data-repair-batch-1-2026-10-01.html.
--
-- A repaired international event is re-ingested from its source through the
-- draft commit, which only inserts; tournament codes are unique, so the stored
-- tournaments must go first. fn_rollback_event resolves a code PREFIX in the
-- active season only, so it cannot reach a 2025/26 event, and a prefix such as
-- 'PEW1efs' would match every season's event of that name.
-- fn_rollback_event_by_code takes the exact code, deletes the event's
-- tournaments through fn_delete_tournament_cascade, keeps the event row and its
-- status, and is service_role only (ADR-083).
--
-- fn_replace_event_from_draft does the repair in one transaction: it refuses a
-- draft run that belongs to another event, rolls the event back by its exact
-- code and commits the run. If the commit fails, the stored event is untouched.
--
-- Everything rolls back.
-- =============================================================================

BEGIN;

ALTER TABLE tbl_result DISABLE TRIGGER trg_assert_result_vcat;

SELECT plan(9);

CREATE TEMP TABLE rb_ids (k TEXT PRIMARY KEY, v INT) ON COMMIT DROP;

DO $fx$
DECLARE v_evf INT; v_s25 INT; v_s26 INT; v_e INT; v_t INT; v_f INT; v_r INT;
BEGIN
  SELECT id_organizer INTO v_evf FROM tbl_organizer WHERE txt_code = 'EVF';
  SELECT id_season INTO v_s25 FROM tbl_season WHERE txt_code = 'SPWS-2024-2025';
  SELECT id_season INTO v_s26 FROM tbl_season WHERE txt_code = 'SPWS-2025-2026';

  INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality, int_birth_year, enum_gender)
  VALUES ('RB-F', 'Test', 'PL', 1970, 'M') RETURNING id_fencer INTO v_f;

  -- The same event name in two seasons: a prefix would match both.
  FOR i IN 1..2 LOOP
    INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
    VALUES (CASE i WHEN 1 THEN 'PEW96efs-2025-2026' ELSE 'PEW96efs-2024-2025' END,
            'RB event ' || i, CASE i WHEN 1 THEN v_s26 ELSE v_s25 END, v_evf, 'COMPLETED')
    RETURNING id_event INTO v_e;
    INSERT INTO rb_ids VALUES ('event' || i, v_e);

    INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
      enum_age_category, dt_tournament, int_participant_count, enum_import_status)
    VALUES (v_e, 'RB-T' || i, 'RB tournament ' || i, 'PEW', 'EPEE', 'M', 'V2', '2025-11-12', 60, 'SCORED')
    RETURNING id_tournament INTO v_t;
    INSERT INTO tbl_result (id_fencer, id_tournament, int_place, enum_fencer_age_category)
    VALUES (v_f, v_t, 31, 'V2') RETURNING id_result INTO v_r;
    INSERT INTO tbl_match_candidate (id_result, txt_scraped_name, id_fencer, num_confidence, enum_status)
    VALUES (v_r, 'RB-F Test', v_f, 100, 'AUTO_MATCHED');
  END LOOP;
END $fx$;

CREATE FUNCTION pg_temp.id(p_k TEXT) RETURNS INT LANGUAGE sql AS $$
  SELECT v FROM rb_ids WHERE k = p_k;
$$;

-- The error text of a statement, or 'OK' when it runs.
CREATE FUNCTION pg_temp.err(p_sql TEXT) RETURNS TEXT LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE p_sql;
  RETURN 'OK';
EXCEPTION WHEN OTHERS THEN
  RETURN SQLERRM;
END;
$$;

-- REPAIR.RB.01 — a prefix is refused; the exact code deletes the event's
-- tournaments, results and match candidates, and reports what it deleted.
-- The call runs in its own statement: a sibling subquery of the same statement
-- reads the snapshot taken before the delete.
CREATE TEMP TABLE rb_out ON COMMIT DROP AS
SELECT pg_temp.err($$SELECT fn_rollback_event_by_code('PEW96efs')$$) AS prefix_err,
       fn_rollback_event_by_code('PEW96efs-2025-2026') AS result;

SELECT is(
  jsonb_build_object(
    'prefix', (SELECT prefix_err LIKE '%no event%PEW96efs%' FROM rb_out),
    'result', (SELECT result - 'event_id' FROM rb_out),
    'tournaments_left', (SELECT count(*) FROM tbl_tournament WHERE id_event = pg_temp.id('event1')),
    'candidates_left', (SELECT count(*) FROM tbl_match_candidate mc
                          JOIN tbl_result r USING (id_result)
                          JOIN tbl_tournament t USING (id_tournament)
                         WHERE t.id_event = pg_temp.id('event1'))),
  jsonb_build_object(
    'prefix', TRUE,
    'result', jsonb_build_object('event_code', 'PEW96efs-2025-2026',
                                 'tournaments_deleted', 1, 'results_deleted', 1),
    'tournaments_left', 0,
    'candidates_left', 0),
  'REPAIR.RB.01 a prefix is refused; the exact code deletes that event''s tournaments, results and candidates');

-- REPAIR.RB.02 — the same event name in another season is untouched.
SELECT is(
  (SELECT jsonb_build_object('tournaments', count(DISTINCT t.id_tournament),
                             'results', count(r.id_result),
                             'n', max(t.int_participant_count),
                             'place', max(r.int_place))
     FROM tbl_tournament t LEFT JOIN tbl_result r USING (id_tournament)
    WHERE t.id_event = pg_temp.id('event2')),
  jsonb_build_object('tournaments', 1, 'results', 1, 'n', 60, 'place', 31),
  'REPAIR.RB.02 the same event name in another season keeps its tournament and result');

-- REPAIR.RB.03 — the event row and its status are kept.
SELECT is(
  (SELECT jsonb_build_object('code', txt_code, 'status', enum_status::TEXT)
     FROM tbl_event WHERE id_event = pg_temp.id('event1')),
  jsonb_build_object('code', 'PEW96efs-2025-2026', 'status', 'COMPLETED'),
  'REPAIR.RB.03 the event row and its status are kept');

-- REPAIR.RB.04 — service_role only (ADR-083).
SELECT is(
  jsonb_build_object(
    'anon', has_function_privilege('anon', 'fn_rollback_event_by_code(text)', 'EXECUTE'),
    'authenticated', has_function_privilege('authenticated', 'fn_rollback_event_by_code(text)', 'EXECUTE'),
    'public', EXISTS (SELECT 1 FROM information_schema.routine_privileges
                       WHERE routine_name = 'fn_rollback_event_by_code' AND grantee = 'PUBLIC'),
    'service_role', has_function_privilege('service_role', 'fn_rollback_event_by_code(text)', 'EXECUTE')),
  jsonb_build_object('anon', FALSE, 'authenticated', FALSE, 'public', FALSE, 'service_role', TRUE),
  'REPAIR.RB.04 only service_role may execute the rollback by code');

-- ---------------------------------------------------------------------------
-- fn_replace_event_from_draft
-- ---------------------------------------------------------------------------
DO $fx2$
DECLARE v_evf INT; v_s26 INT; v_e INT; v_t INT; v_d INT; v_run UUID;
BEGIN
  SELECT id_organizer INTO v_evf FROM tbl_organizer WHERE txt_code = 'EVF';
  SELECT id_season INTO v_s26 FROM tbl_season WHERE txt_code = 'SPWS-2025-2026';
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('PEW95efs-2025-2026', 'RB replace', v_s26, v_evf, 'COMPLETED') RETURNING id_event INTO v_e;
  INSERT INTO rb_ids VALUES ('event3', v_e);
  -- The damaged stored state: N recounted to the one Pole, renumbered 1st.
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
    enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_e, 'RB-T3', 'RB replace tournament', 'PEW', 'EPEE', 'M', 'V2', '2025-11-12', 1, 'SCORED')
  RETURNING id_tournament INTO v_t;
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, enum_fencer_age_category)
  SELECT id_fencer, v_t, 1, 'V2' FROM tbl_fencer WHERE txt_surname = 'RB-F';

  -- Three draft runs: the source bracket (RB-T3, 31st of 60); one filed under
  -- another event; one whose code collides with another event's tournament.
  FOREACH v_run IN ARRAY ARRAY['00000000-0000-0000-0000-0000000000a1'::UUID,
                               '00000000-0000-0000-0000-0000000000a2'::UUID,
                               '00000000-0000-0000-0000-0000000000a3'::UUID] LOOP
    INSERT INTO tbl_tournament_draft (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
      enum_age_category, dt_tournament, int_participant_count, txt_run_id)
    VALUES (CASE WHEN v_run = '00000000-0000-0000-0000-0000000000a2' THEN pg_temp.id('event2') ELSE v_e END,
            CASE WHEN v_run = '00000000-0000-0000-0000-0000000000a3' THEN 'RB-T2' ELSE 'RB-T3' END,
            'RB draft', 'PEW', 'EPEE', 'M', 'V2', '2025-11-12', 60, v_run)
    RETURNING id_tournament_draft INTO v_d;
    INSERT INTO tbl_result_draft (txt_run_id, id_tournament_draft, id_fencer, int_place,
      enum_fencer_age_category, txt_scraped_name, num_match_confidence, enum_match_method)
    SELECT v_run, v_d, id_fencer, 31, 'V2', 'RB-F Test', 100, 'AUTO_MATCH'
      FROM tbl_fencer WHERE txt_surname = 'RB-F';
  END LOOP;
END $fx2$;

CREATE FUNCTION pg_temp.event3_state() RETURNS JSONB LANGUAGE sql AS $$
  SELECT jsonb_build_object('tournaments', count(DISTINCT t.id_tournament),
                            'n', max(t.int_participant_count), 'place', max(r.int_place))
    FROM tbl_tournament t LEFT JOIN tbl_result r USING (id_tournament)
   WHERE t.id_event = pg_temp.id('event3');
$$;

-- REPAIR.RB.05 — a run of another event is refused before anything is deleted.
SELECT is(
  jsonb_build_object(
    'err', pg_temp.err($$SELECT fn_replace_event_from_draft('PEW95efs-2025-2026',
                         '00000000-0000-0000-0000-0000000000a2')$$) LIKE '%another event%',
    'state', pg_temp.event3_state()),
  jsonb_build_object('err', TRUE,
                     'state', jsonb_build_object('tournaments', 1, 'n', 1, 'place', 1)),
  'REPAIR.RB.05 a draft run of another event is refused and the stored event is kept');

-- REPAIR.RB.06 — a commit that fails leaves the stored event as it was.
SELECT is(
  jsonb_build_object(
    'failed', pg_temp.err($$SELECT fn_replace_event_from_draft('PEW95efs-2025-2026',
                            '00000000-0000-0000-0000-0000000000a3')$$) LIKE '%duplicate key%',
    'state', pg_temp.event3_state()),
  jsonb_build_object('failed', TRUE,
                     'state', jsonb_build_object('tournaments', 1, 'n', 1, 'place', 1)),
  'REPAIR.RB.06 when the commit fails, the rollback is undone with it');

-- REPAIR.RB.09 — an unresolved PENDING guess (a fencer, no match method) is
-- refused: committing it would credit the result to the guess.
UPDATE tbl_result_draft SET enum_match_method = NULL
 WHERE txt_run_id = '00000000-0000-0000-0000-0000000000a1';
SELECT is(
  jsonb_build_object(
    'err', pg_temp.err($$SELECT fn_replace_event_from_draft('PEW95efs-2025-2026',
                         '00000000-0000-0000-0000-0000000000a1')$$) LIKE '%unresolved%',
    'state', pg_temp.event3_state()),
  jsonb_build_object('err', TRUE,
                     'state', jsonb_build_object('tournaments', 1, 'n', 1, 'place', 1)),
  'REPAIR.RB.09 a run with an unresolved PENDING guess is refused and the stored event is kept');
UPDATE tbl_result_draft SET enum_match_method = 'AUTO_MATCH'
 WHERE txt_run_id = '00000000-0000-0000-0000-0000000000a1';

-- REPAIR.RB.07 — the event is replaced by the run: the same code, the source N
-- and place, in one call.
CREATE TEMP TABLE rb_rep ON COMMIT DROP AS
SELECT fn_replace_event_from_draft('PEW95efs-2025-2026', '00000000-0000-0000-0000-0000000000a1') AS out;

SELECT is(
  jsonb_build_object(
    'rolled_back', (SELECT out -> 'rolled_back' -> 'tournaments_deleted' FROM rb_rep),
    'committed', (SELECT out -> 'committed' -> 'tournaments_committed' FROM rb_rep),
    'state', pg_temp.event3_state(),
    'code', (SELECT txt_code FROM tbl_tournament WHERE id_event = pg_temp.id('event3'))),
  jsonb_build_object('rolled_back', 1, 'committed', 1,
                     'state', jsonb_build_object('tournaments', 1, 'n', 60, 'place', 31),
                     'code', 'RB-T3'),
  'REPAIR.RB.07 the stored tournaments are replaced by the run''s, code kept, N and place from the source');

-- REPAIR.RB.08 — service_role only (ADR-083).
SELECT is(
  jsonb_build_object(
    'anon', has_function_privilege('anon', 'fn_replace_event_from_draft(text,uuid)', 'EXECUTE'),
    'authenticated', has_function_privilege('authenticated', 'fn_replace_event_from_draft(text,uuid)', 'EXECUTE'),
    'public', EXISTS (SELECT 1 FROM information_schema.routine_privileges
                       WHERE routine_name = 'fn_replace_event_from_draft' AND grantee = 'PUBLIC'),
    'service_role', has_function_privilege('service_role', 'fn_replace_event_from_draft(text,uuid)', 'EXECUTE')),
  jsonb_build_object('anon', FALSE, 'authenticated', FALSE, 'public', FALSE, 'service_role', TRUE),
  'REPAIR.RB.08 only service_role may replace an event from a draft run');

SELECT * FROM finish();
ROLLBACK;
