-- =============================================================================
-- APPLY — promote's apply on PROD (ADR-108 §6, build step 9)
-- =============================================================================
-- fn_event_result_fingerprint(event) is the one canonical fingerprint of what
-- an ingestion left for an event: the event's URL, every tournament, every
-- result with its score, and the participants' roster rows, by codes and
-- fencer ids, never by generated ids or timestamps. The CERT run records it
-- when it finishes; the apply computes PROD's with the same function.
--
-- fn_promote_event_apply(event, plan, expected fingerprint, expected inputs,
-- prior fingerprint, status, dry run) makes every write of the plan in one
-- transaction and raises on any difference, so PostgreSQL undoes everything:
-- new fencers, birth years, results, scores, the season's first revision and
-- its lock, the queued recomputes. A dry run always raises at the end. When
-- PROD already holds the expected result, it writes nothing.
--
-- The expected fingerprint is taken from the same writes made directly (the
-- live run) inside a savepoint that is rolled back. Service role only
-- (ADR-083). Everything rolls back; the fencer sequence is restored.
-- =============================================================================

BEGIN;

SELECT plan(30);

SELECT pg_sequence_last_value(pg_get_serial_sequence('public.tbl_fencer', 'id_fencer')::regclass) AS seq_before \gset

-- A season of its own on EVF classic, with the latest real settings, unlocked.
INSERT INTO tbl_season (txt_code, dt_start, dt_end) VALUES ('SPWS-2095-2096', DATE '2095-09-01', DATE '2096-06-30');
UPDATE tbl_season SET id_scoring_engine = (SELECT id_engine FROM tbl_scoring_engine WHERE txt_code = 'EVF_CLASSIC_V1_2025_2026')
 WHERE txt_code = 'SPWS-2095-2096';
UPDATE tbl_scoring_config dst SET
  int_mp_value = src.int_mp_value, int_podium_gold = src.int_podium_gold, int_podium_silver = src.int_podium_silver,
  int_podium_bronze = src.int_podium_bronze, num_ppw_multiplier = src.num_ppw_multiplier,
  num_mpw_multiplier = src.num_mpw_multiplier, int_min_participants_ppw = src.int_min_participants_ppw,
  int_min_participants_evf = src.int_min_participants_evf, json_ranking_rules = src.json_ranking_rules
FROM tbl_scoring_config src
WHERE src.id_season = (SELECT id_season FROM tbl_scoring_config
                        WHERE json_ranking_rules ? 'domestic' AND json_ranking_rules ? 'international'
                        ORDER BY id_season DESC LIMIT 1)
  AND dst.id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2095-2096');

INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, enum_status)
SELECT c, 'APPLY fixture', (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2095-2096'),
       (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'), DATE '2095-10-10', DATE '2095-10-11', s::enum_event_status
  FROM (VALUES ('PPW9-2095-2096', 'PLANNED'), ('PPW8-2095-2096', 'IN_PROGRESS')) v(c, s);

-- Born 2050: V1 at season end 2096.
INSERT INTO tbl_fencer (id_fencer, txt_surname, txt_first_name, int_birth_year, enum_gender, bool_birth_year_estimated)
VALUES (98301, 'APPLYA', 'Adam', 2050, 'M', FALSE), (98302, 'APPLYB', 'Bogdan', 2050, 'M', FALSE);

-- 98301 already has an (unscored) result at PPW8, so moving his birth year queues PPW8.
INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender, enum_age_category,
                            dt_tournament, int_participant_count, enum_import_status)
SELECT id_event, 'PPW8-V1-M-SABRE-2095-2096', 'a', 'PPW', 'SABRE', 'M', 'V1', DATE '2095-10-10', 1, 'IMPORTED'
  FROM tbl_event WHERE txt_code = 'PPW8-2095-2096';
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
SELECT 98301, id_tournament, 1, 'APPLYA Adam' FROM tbl_tournament WHERE txt_code = 'PPW8-V1-M-SABRE-2095-2096';

SELECT id_event AS ev FROM tbl_event WHERE txt_code = 'PPW9-2095-2096' \gset
SELECT (fn_event_input_fingerprint('PPW9-2095-2096')->'parts')::TEXT AS inputs \gset
SELECT fn_event_result_fingerprint('PPW9-2095-2096') AS empty_fp \gset

-- The plan as plan mode records it (python/pipeline/promotion/plan.py).
CREATE TEMP TABLE p (label TEXT PRIMARY KEY, j JSONB);
INSERT INTO p VALUES ('plan', jsonb_build_object('event_code', 'PPW9-2095-2096', 'ops', jsonb_build_array(
  jsonb_build_object('op', 'insert_fencer', 'id_fencer', 98310, 'fencer', jsonb_build_object(
    'txt_surname', 'APPLYNEW', 'txt_first_name', 'Nowy', 'int_birth_year', 2051,
    'bool_birth_year_estimated', TRUE, 'txt_nationality', 'PL', 'enum_gender', 'M')),
  jsonb_build_object('op', 'update_fencer_birth_year', 'id_fencer', 98301, 'birth_year', 2049, 'estimated', FALSE),
  jsonb_build_object('op', 'find_or_create_tournament', 'ref', -1, 'event_id', :ev, 'weapon', 'SABRE', 'gender', 'M',
    'category', 'V1', 'date', '2095-10-10', 'tournament_type', 'PPW', 'url_results', 'https://www.fencingtimelive.com/events/results/APPLY1'),
  jsonb_build_object('op', 'ingest_results', 'tournament', -1, 'participant_count', 3, 'joined_order', NULL, 'rows', jsonb_build_array(
    jsonb_build_object('id_fencer', 98301, 'int_place', 1, 'txt_scraped_name', 'APPLYA Adam'),
    jsonb_build_object('id_fencer', 98310, 'int_place', 2, 'txt_scraped_name', 'APPLYNEW Nowy', 'enum_match_status', 'NEW_FENCER'),
    jsonb_build_object('id_fencer', 98302, 'int_place', 3, 'txt_scraped_name', 'APPLYB Bogdan'))),
  jsonb_build_object('op', 'set_event_url_event', 'id_event', :ev, 'url_event', 'https://www.fencingtimelive.com/tournaments/eventSchedule/APPLY'),
  jsonb_build_object('op', 'set_event_ingest_sources', 'id_event', :ev, 'sources', '[{"name": "Szabla", "status": "committed"}]'::JSONB))));

-- The live run: the same writes made directly, measured, then undone.
SAVEPOINT live;
INSERT INTO tbl_fencer (id_fencer, txt_surname, txt_first_name, int_birth_year, bool_birth_year_estimated, txt_nationality, enum_gender)
VALUES (98310, 'APPLYNEW', 'Nowy', 2051, TRUE, 'PL', 'M');
SELECT fn_update_fencer_birth_year(98301, 2049, FALSE);
SELECT fn_ingest_tournament_results(
  fn_find_or_create_tournament(:ev, 'SABRE', 'M', 'V1', DATE '2095-10-10', 'PPW', NULL, 'https://www.fencingtimelive.com/events/results/APPLY1'),
  (SELECT j->'ops'->3->'rows' FROM p WHERE label = 'plan'), 3, NULL);
UPDATE tbl_event SET url_event = 'https://www.fencingtimelive.com/tournaments/eventSchedule/APPLY',
                     json_ingest_sources = '[{"name": "Szabla", "status": "committed"}]' WHERE id_event = :ev;
SELECT fn_event_result_fingerprint('PPW9-2095-2096') AS live_fp \gset
ROLLBACK TO SAVEPOINT live;

CREATE TEMP TABLE before_state AS
SELECT (SELECT count(*) FROM tbl_recompute_queue) AS queue,
       (SELECT ts_scoring_locked_at FROM tbl_season WHERE txt_code = 'SPWS-2095-2096') AS locked;

-- ---------------------------------------------------------------- grants and the fingerprint
SELECT ok(NOT has_function_privilege('anon', 'fn_promote_event_apply(text,jsonb,text,jsonb,text,text,boolean)', 'EXECUTE')
      AND NOT has_function_privilege('authenticated', 'fn_promote_event_apply(text,jsonb,text,jsonb,text,text,boolean)', 'EXECUTE')
      AND has_function_privilege('service_role', 'fn_promote_event_apply(text,jsonb,text,jsonb,text,text,boolean)', 'EXECUTE')
      AND NOT has_function_privilege('anon', 'fn_event_result_fingerprint(text)', 'EXECUTE')
      AND NOT has_function_privilege('anon', 'fn_event_result_document(text)', 'EXECUTE')
      AND has_function_privilege('service_role', 'fn_event_result_fingerprint(text)', 'EXECUTE')
      AND has_function_privilege('service_role', 'fn_event_result_document(text)', 'EXECUTE'),
  'APPLY.01 the apply and the fingerprint run for the service role only');

SELECT ok(:'live_fp' ~ '^[0-9a-f]{64}$' AND :'live_fp' <> :'empty_fp',
  'APPLY.02 the fingerprint is a SHA-256 and moves with the results');

SELECT ok(fn_event_result_document('PPW8-2095-2096')::TEXT !~ '"(id_tournament|id_result|id_event|id_scoring_revision|ts_[a-z_]+)"',
  'APPLY.02 the document carries no generated id and no timestamp');

SELECT throws_like($$SELECT fn_event_result_fingerprint('NOPE-2095-2096')$$, '%PROMOTE_EVENT_NOT_FOUND%',
  'APPLY.02 an unknown event is refused');

-- ---------------------------------------------------------------- a dry run persists nothing
SELECT throws_like(format($$SELECT fn_promote_event_apply('PPW9-2095-2096', %L::JSONB, %L, %L::JSONB, NULL, 'IN_PROGRESS', TRUE)$$,
                          (SELECT j FROM p WHERE label = 'plan'), :'live_fp', :'inputs'),
  'PROMOTE_DRY_RUN_OK ' || :'live_fp' || '%',
  'APPLY.03 a dry run makes every write, matches the live fingerprint and raises');

SELECT ok(NOT EXISTS (SELECT 1 FROM tbl_fencer WHERE id_fencer = 98310)
      AND (SELECT int_birth_year FROM tbl_fencer WHERE id_fencer = 98301) = 2050
      AND NOT EXISTS (SELECT 1 FROM tbl_tournament WHERE id_event = :ev)
      AND (SELECT url_event FROM tbl_event WHERE id_event = :ev) IS NULL
      AND (SELECT enum_status FROM tbl_event WHERE id_event = :ev) = 'PLANNED',
  'APPLY.03 after a dry run: no fencer, no birth year moved, no tournament, no URL, still PLANNED');

SELECT ok((SELECT count(*) FROM tbl_recompute_queue) = (SELECT queue FROM before_state)
      AND (SELECT ts_scoring_locked_at FROM tbl_season WHERE txt_code = 'SPWS-2095-2096') IS NULL
      AND pg_sequence_last_value(pg_get_serial_sequence('public.tbl_fencer', 'id_fencer')::regclass)
          IS NOT DISTINCT FROM NULLIF(:'seq_before', '')::BIGINT,
  'APPLY.03 after a dry run: no queued recompute, the season unlocked, the fencer sequence untouched');

-- ---------------------------------------------------------------- a mismatch rolls back everything
SELECT throws_like(format($$SELECT fn_promote_event_apply('PPW9-2095-2096', %L::JSONB, %L, %L::JSONB, NULL, 'IN_PROGRESS', FALSE)$$,
                          (SELECT j FROM p WHERE label = 'plan'), repeat('0', 64), :'inputs'),
  'PROMOTE_FINGERPRINT_MISMATCH%',
  'APPLY.04 a result different from CERT''s raises');

SELECT ok(NOT EXISTS (SELECT 1 FROM tbl_fencer WHERE id_fencer = 98310)
      AND (SELECT int_birth_year FROM tbl_fencer WHERE id_fencer = 98301) = 2050
      AND NOT EXISTS (SELECT 1 FROM tbl_result r JOIN tbl_tournament t USING (id_tournament) WHERE t.id_event = :ev)
      AND (SELECT count(*) FROM tbl_recompute_queue) = (SELECT queue FROM before_state)
      AND (SELECT ts_scoring_locked_at FROM tbl_season WHERE txt_code = 'SPWS-2095-2096') IS NULL
      AND NOT EXISTS (SELECT 1 FROM tbl_scoring_config_revision r JOIN tbl_season s USING (id_season)
                       WHERE s.txt_code = 'SPWS-2095-2096'),
  'APPLY.04 after a mismatch: no fencer, birth year, result, queued recompute, revision or lock');

-- ---------------------------------------------------------------- preconditions, before any write
SELECT throws_like(format($$SELECT fn_promote_event_apply('PPW9-2095-2096', %L::JSONB, %L, %L::JSONB, NULL, 'IN_PROGRESS', TRUE)$$,
                          (SELECT j FROM p WHERE label = 'plan'), :'live_fp',
                          jsonb_set(:'inputs'::JSONB, '{roster}', '"changed"')),
  'PROMOTE_INPUT_CHANGED: roster%',
  'APPLY.05 a roster different from the one CERT started from refuses');

SELECT throws_like(format($$SELECT fn_promote_event_apply('PPW9-2095-2096', %L::JSONB, %L, %L::JSONB, NULL, 'IN_PROGRESS', TRUE)$$,
                          (SELECT j FROM p WHERE label = 'plan'), :'live_fp',
                          jsonb_set(:'inputs'::JSONB, '{lock}', '"locked"')),
  'PROMOTE_DRY_RUN_OK%',
  'APPLY.05 CERT locked and PROD not is accepted (G1 A)');

SAVEPOINT locked;
UPDATE tbl_season SET ts_scoring_locked_at = now() WHERE txt_code = 'SPWS-2095-2096';
SELECT throws_like(format($$SELECT fn_promote_event_apply('PPW9-2095-2096', %L::JSONB, %L, %L::JSONB, NULL, 'IN_PROGRESS', TRUE)$$,
                          (SELECT j FROM p WHERE label = 'plan'), :'live_fp', :'inputs'),
  'PROMOTE_INPUT_CHANGED: lock%',
  'APPLY.05 PROD locked and CERT not refuses: PROD scored results CERT never had');
ROLLBACK TO SAVEPOINT locked;

SELECT throws_like(format($$SELECT fn_promote_event_apply('PPW9-2095-2096', %L::JSONB, %L, %L::JSONB, NULL, 'IN_PROGRESS', TRUE)$$,
                          jsonb_set((SELECT j FROM p WHERE label = 'plan'), '{ops,0,id_fencer}', '98302'), :'live_fp', :'inputs'),
  'PROMOTE_FENCER_ID_TAKEN: 98302%',
  'APPLY.06 a CERT id PROD already uses refuses');

SELECT throws_like(format($$SELECT fn_promote_event_apply('PPW8-2095-2096', %L::JSONB, %L, %L::JSONB, NULL, 'IN_PROGRESS', TRUE)$$,
                          (SELECT j FROM p WHERE label = 'plan'), :'live_fp', :'inputs'),
  'PROMOTE_PLAN_EVENT%',
  'APPLY.06 a plan of another event refuses');

SELECT throws_like(format($$SELECT fn_promote_event_apply('PPW9-2095-2096', %L::JSONB, %L, %L::JSONB, NULL, 'SCORED', TRUE)$$,
                          (SELECT j FROM p WHERE label = 'plan'), :'live_fp', :'inputs'),
  'PROMOTE_STATUS%',
  'APPLY.06 automation never sets SCORED');

SELECT throws_like(format($$SELECT fn_promote_event_apply('PPW9-2095-2096', %L::JSONB, %L, %L::JSONB, %L, 'IN_PROGRESS', TRUE)$$,
                          (SELECT j FROM p WHERE label = 'plan'), :'live_fp', :'inputs', repeat('1', 64)),
  'PROMOTE_PRIOR%',
  'APPLY.06 PROD must hold the previous promote it is told about');

SAVEPOINT url;
UPDATE tbl_event SET url_event = 'https://www.fencingtimelive.com/tournaments/eventSchedule/OTHER' WHERE id_event = :ev;
SELECT throws_like(format($$SELECT fn_promote_event_apply('PPW9-2095-2096', %L::JSONB, %L, %L::JSONB, NULL, 'IN_PROGRESS', TRUE)$$,
                          (SELECT j FROM p WHERE label = 'plan'), :'live_fp', :'inputs'),
  'PROMOTE_URL_DIFFERS%',
  'APPLY.07 a different non-blank PROD URL refuses (ADR-086 fill-blank tier)');
ROLLBACK TO SAVEPOINT url;

-- ---------------------------------------------------------------- the apply
CREATE TEMP TABLE applied AS
SELECT fn_promote_event_apply('PPW9-2095-2096', (SELECT j FROM p WHERE label = 'plan'), :'live_fp', :'inputs'::JSONB,
                              NULL, 'IN_PROGRESS', FALSE) AS r;

SELECT is((SELECT (r->>'skipped')::BOOLEAN FROM applied), FALSE, 'APPLY.08 the apply writes');
SELECT is(fn_event_result_fingerprint('PPW9-2095-2096'), :'live_fp', 'APPLY.08 PROD now holds exactly the live result');

SELECT ok((SELECT int_birth_year = 2051 AND bool_birth_year_estimated FROM tbl_fencer WHERE id_fencer = 98310)
      AND (SELECT int_birth_year FROM tbl_fencer WHERE id_fencer = 98301) = 2049
      AND (SELECT count(*) FROM tbl_result r JOIN tbl_tournament t USING (id_tournament) WHERE t.id_event = :ev) = 3
      AND (SELECT count(*) FROM tbl_result r JOIN tbl_tournament t USING (id_tournament)
            WHERE t.id_event = :ev AND r.num_final_score IS NOT NULL) = 3,
  'APPLY.08 the new fencer keeps the CERT id, the birth year moved, three results scored');

SELECT is((SELECT url_event FROM tbl_event WHERE id_event = :ev),
          'https://www.fencingtimelive.com/tournaments/eventSchedule/APPLY',
  'APPLY.07 a blank PROD URL takes the CERT run''s');

SELECT ok((SELECT ts_scoring_locked_at FROM tbl_season WHERE txt_code = 'SPWS-2095-2096') IS NOT NULL
      AND EXISTS (SELECT 1 FROM tbl_recompute_queue q JOIN tbl_event e USING (id_event) WHERE e.txt_code = 'PPW8-2095-2096'),
  'APPLY.08 the first score locks the season and the moved birth year queues PPW8');

SELECT ok(pg_sequence_last_value(pg_get_serial_sequence('public.tbl_fencer', 'id_fencer')::regclass) >= 98310,
  'APPLY.08 the fencer sequence moves past the CERT ids');

SELECT is((SELECT enum_status::TEXT FROM tbl_event WHERE id_event = :ev), 'IN_PROGRESS',
  'APPLY.09 PLANNED becomes IN_PROGRESS');

-- ---------------------------------------------------------------- idempotence
SELECT is((fn_promote_event_apply('PPW9-2095-2096', (SELECT j FROM p WHERE label = 'plan'), :'live_fp', :'inputs'::JSONB,
                                  NULL, 'IN_PROGRESS', FALSE)->>'skipped')::BOOLEAN, TRUE,
  'APPLY.10 a second apply finds PROD already equal and writes nothing');
SELECT is((SELECT count(*)::INT FROM tbl_result r JOIN tbl_tournament t USING (id_tournament) WHERE t.id_event = :ev), 3,
  'APPLY.10 still three results');

-- ---------------------------------------------------------------- status pairs
SELECT fn_event_result_fingerprint('PPW9-2095-2096') AS day1_fp \gset
INSERT INTO p SELECT 'swap', jsonb_set(j, '{ops,3,rows}', jsonb_build_array(
    jsonb_build_object('id_fencer', 98302, 'int_place', 1, 'txt_scraped_name', 'APPLYB Bogdan'),
    jsonb_build_object('id_fencer', 98310, 'int_place', 2, 'txt_scraped_name', 'APPLYNEW Nowy', 'enum_match_status', 'NEW_FENCER'),
    jsonb_build_object('id_fencer', 98301, 'int_place', 3, 'txt_scraped_name', 'APPLYA Adam')))
  FROM p WHERE label = 'plan';
-- The correction drops the ops the first apply already made (the fencer exists, the year moved).
UPDATE p SET j = jsonb_set(j, '{ops}', (SELECT jsonb_agg(o) FROM jsonb_array_elements(j->'ops') o
                                         WHERE o->>'op' NOT IN ('insert_fencer', 'update_fencer_birth_year')))
 WHERE label = 'swap';
SELECT (fn_event_input_fingerprint('PPW9-2095-2096')->'parts')::TEXT AS inputs2 \gset

SAVEPOINT live2;
SELECT fn_ingest_tournament_results(
  (SELECT id_tournament FROM tbl_tournament WHERE id_event = :ev),
  (SELECT j->'ops'->1->'rows' FROM p WHERE label = 'swap'), 3, NULL);
SELECT fn_event_result_fingerprint('PPW9-2095-2096') AS swap_fp \gset
ROLLBACK TO SAVEPOINT live2;

UPDATE tbl_event SET enum_status = 'COMPLETED' WHERE id_event = :ev;
SELECT is((fn_promote_event_apply('PPW9-2095-2096', (SELECT j FROM p WHERE label = 'swap'), :'swap_fp', :'inputs2'::JSONB,
                                  :'day1_fp', 'COMPLETED', FALSE)->>'skipped')::BOOLEAN, FALSE,
  'APPLY.09 a correction of a COMPLETED event applies');
SELECT ok((SELECT enum_status::TEXT FROM tbl_event WHERE id_event = :ev) = 'COMPLETED'
      AND fn_event_result_fingerprint('PPW9-2095-2096') = :'swap_fp',
  'APPLY.09 COMPLETED steps to IN_PROGRESS for the writes and back to COMPLETED');

SELECT is((fn_promote_event_apply('PPW9-2095-2096', (SELECT j FROM p WHERE label = 'swap'), :'swap_fp', :'inputs2'::JSONB,
                                  :'day1_fp', 'IN_PROGRESS', FALSE)->>'status'), 'IN_PROGRESS',
  'APPLY.09 an equal result still applies the status: COMPLETED back to IN_PROGRESS');

-- ---------------------------------------------------------------- the CERT run records its fingerprint
SELECT fn_ingest_run_open('PPW9-2095-2096', 'local', repeat('a', 40), 2096, 'https://www.fencingtimelive.com/tournaments/eventSchedule/APPLY', NULL, NULL) AS run_id \gset
SELECT fn_ingest_run_finish(:run_id, '{}'::JSONB);
SELECT is((SELECT txt_result_fingerprint FROM tbl_ingest_run WHERE id_ingest_run = :run_id),
          fn_event_result_fingerprint('PPW9-2095-2096'),
  'APPLY.11 a finished run records the event''s result fingerprint');

-- Restore the fencer sequence the apply moved (sequences do not roll back).
SELECT CASE WHEN NULLIF(:'seq_before', '') IS NULL
            THEN setval(pg_get_serial_sequence('public.tbl_fencer', 'id_fencer'), 1, FALSE)
            ELSE setval(pg_get_serial_sequence('public.tbl_fencer', 'id_fencer'), :'seq_before'::BIGINT) END;

SELECT * FROM finish();
ROLLBACK;
