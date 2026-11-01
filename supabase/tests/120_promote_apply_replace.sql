-- =============================================================================
-- APPLY.REPLACE / APPLY.RESERVE — one apply on both sides (ADR-119 §3, D3, D4)
-- =============================================================================
-- The CERT ingest becomes plan + apply: the plan is recorded against CERT and
-- applied by fn_promote_event_apply, the function promote uses on PROD.
--
--   (a) An expected fingerprint of NULL means "compute and return": the apply
--       never skips, makes every write and returns the fingerprint it reached.
--       A dry run still raises PROMOTE_DRY_RUN_OK with that fingerprint.
--   (b) D4: the apply deletes the event's tournaments the plan does not name
--       (with their results and match candidates) before it compares the
--       fingerprint, so a listing the organiser renamed or a keep-rule owner
--       that changed never strands the target. A named tournament keeps its id
--       and its results are replaced. Another event is never touched, and a
--       prior mismatch raises before anything is deleted.
--   (c) Result slots 2-5 keep ADR-113's fill-blank tier.
--   (d) G16: an apply whose results the target already holds skips them, and
--       still writes the event's record of its sources and fills its blank
--       result slots under the same tier, all or nothing. url_event is in the
--       result document, so a skip already holds it; the fingerprint is
--       compared after a skip too.
--
-- fn_reserve_fencer_id() hands the CERT plan the id a new fencer will take
-- (one nextval; sequences do not roll back, which is harmless). Service role
-- only. Everything rolls back; the fencer sequence is restored.
-- =============================================================================

BEGIN;

SELECT plan(21);

-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT pg_sequence_last_value(pg_get_serial_sequence('public.tbl_fencer', 'id_fencer')::regclass) AS seq_before \gset

-- A season of its own on EVF classic, with the latest real settings, unlocked (as 103).
INSERT INTO tbl_season (txt_code, dt_start, dt_end) VALUES ('SPWS-2089-2090', DATE '2089-09-01', DATE '2090-06-30');
UPDATE tbl_season SET id_scoring_engine = (SELECT id_engine FROM tbl_scoring_engine WHERE txt_code = 'EVF_CLASSIC_V1_2025_2026')
 WHERE txt_code = 'SPWS-2089-2090';
UPDATE tbl_scoring_config dst SET
  int_mp_value = src.int_mp_value, int_podium_gold = src.int_podium_gold, int_podium_silver = src.int_podium_silver,
  int_podium_bronze = src.int_podium_bronze, num_ppw_multiplier = src.num_ppw_multiplier,
  num_mpw_multiplier = src.num_mpw_multiplier, int_min_participants_ppw = src.int_min_participants_ppw,
  int_min_participants_evf = src.int_min_participants_evf, json_ranking_rules = src.json_ranking_rules
FROM tbl_scoring_config src
WHERE src.id_season = (SELECT id_season FROM tbl_scoring_config
                        WHERE json_ranking_rules ? 'domestic' AND json_ranking_rules ? 'international'
                        ORDER BY id_season DESC LIMIT 1)
  AND dst.id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2089-2090');

INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, enum_status)
SELECT c, 'APPLY.REPLACE fixture', (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2089-2090'),
       (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'), DATE '2089-10-10', DATE '2089-10-11',
       'IN_PROGRESS'
  FROM (VALUES ('PPW7-2089-2090'), ('PPW6-2089-2090')) v(c);

-- Born 2040: V2 at season end 2090.
INSERT INTO tbl_fencer (id_fencer, txt_surname, txt_first_name, int_birth_year, enum_gender, bool_birth_year_estimated)
VALUES (98401, 'REPLACEA', 'Adam', 2040, 'M', FALSE), (98402, 'REPLACEB', 'Bogdan', 2040, 'M', FALSE);

-- What an earlier run left: sabre (which the new plan names) and foil (which
-- it does not), and an unrelated event's foil.
INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender, enum_age_category,
                            dt_tournament, int_participant_count, enum_import_status)
SELECT e.id_event, t.code, 'r', 'PPW', t.weapon::enum_weapon_type, 'M', 'V2', DATE '2089-10-10', 2, 'IMPORTED'
  FROM (VALUES ('PPW7-2089-2090', 'PPW7-V2-M-SABRE-2089-2090', 'SABRE'),
               ('PPW7-2089-2090', 'PPW7-V2-M-FOIL-2089-2090', 'FOIL'),
               ('PPW6-2089-2090', 'PPW6-V2-M-FOIL-2089-2090', 'FOIL')) t(ev, code, weapon)
  JOIN tbl_event e ON e.txt_code = t.ev;
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
SELECT f.id, t.id_tournament, f.place, f.name
  FROM tbl_tournament t
 CROSS JOIN (VALUES (98401, 1, 'REPLACEA Adam'), (98402, 2, 'REPLACEB Bogdan')) f(id, place, name)
 WHERE t.txt_code IN ('PPW7-V2-M-SABRE-2089-2090', 'PPW7-V2-M-FOIL-2089-2090', 'PPW6-V2-M-FOIL-2089-2090');
INSERT INTO tbl_match_candidate (id_result, txt_scraped_name, id_fencer, num_confidence, enum_status)
SELECT r.id_result, r.txt_scraped_name, r.id_fencer, 100, 'AUTO_MATCHED'
  FROM tbl_result r JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
 WHERE t.txt_code = 'PPW7-V2-M-FOIL-2089-2090';

-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT id_event AS ev FROM tbl_event WHERE txt_code = 'PPW7-2089-2090' \gset
-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT id_tournament AS sabre FROM tbl_tournament WHERE txt_code = 'PPW7-V2-M-SABRE-2089-2090' \gset
-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT id_tournament AS foil FROM tbl_tournament WHERE txt_code = 'PPW7-V2-M-FOIL-2089-2090' \gset
-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT array_agg(mc.id_match)::TEXT AS foil_candidates
  FROM tbl_match_candidate mc JOIN tbl_result r ON r.id_result = mc.id_result
 WHERE r.id_tournament = :foil \gset
-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT (fn_event_input_fingerprint('PPW7-2089-2090')->'parts')::TEXT AS inputs \gset
-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT fn_event_result_fingerprint('PPW7-2089-2090') AS prior_fp \gset
-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT fn_event_result_fingerprint('PPW6-2089-2090') AS other_fp \gset

-- The new run's plan: sabre only, the places swapped, a blank slot 2 filled.
CREATE TEMP TABLE p (label TEXT PRIMARY KEY, j JSONB);
-- pgt-ignore-start typecheck: temp tables/views this file creates (the checker sees only the live schema)
INSERT INTO p VALUES ('plan', jsonb_build_object('event_code', 'PPW7-2089-2090', 'ops', jsonb_build_array(
  jsonb_build_object('op', 'find_or_create_tournament', 'ref', :sabre, 'event_id', :ev, 'weapon', 'SABRE', 'gender', 'M',
    'category', 'V2', 'date', '2089-10-10', 'tournament_type', 'PPW', 'url_results', NULL),
  jsonb_build_object('op', 'ingest_results', 'tournament', :sabre, 'participant_count', 2, 'joined_order', NULL,
    'rows', jsonb_build_array(
      jsonb_build_object('id_fencer', 98402, 'int_place', 1, 'txt_scraped_name', 'REPLACEB Bogdan'),
      jsonb_build_object('id_fencer', 98401, 'int_place', 2, 'txt_scraped_name', 'REPLACEA Adam'))),
  jsonb_build_object('op', 'set_event_source_url', 'id_event', :ev, 'slot', 'url_event_2',
    'url_event', 'https://b.example/e'))));
-- pgt-ignore-end typecheck

-- What the target holds after the same writes made directly: foil deleted,
-- sabre re-ingested. Measured, then undone.
SAVEPOINT live;
DELETE FROM tbl_match_candidate WHERE id_result IN (SELECT id_result FROM tbl_result WHERE id_tournament = :foil);
DELETE FROM tbl_result WHERE id_tournament = :foil;
DELETE FROM tbl_tournament WHERE id_tournament = :foil;
-- pgt-ignore-start typecheck: temp tables/views this file creates (the checker sees only the live schema)
SELECT fn_ingest_tournament_results(:sabre, (SELECT j->'ops'->1->'rows' FROM p WHERE label = 'plan'), 2, NULL);
-- pgt-ignore-end typecheck
-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT fn_event_result_fingerprint('PPW7-2089-2090') AS live_fp \gset
ROLLBACK TO SAVEPOINT live;

-- ---------------------------------------------------------------- a dry run, then a refused prior: nothing deleted
-- pgt-ignore-start typecheck: temp tables/views this file creates (the checker sees only the live schema)
SELECT throws_like(format($$SELECT fn_promote_event_apply('PPW7-2089-2090', %L::JSONB, NULL, %L::JSONB, %L, 'IN_PROGRESS', TRUE)$$,
                          (SELECT j FROM p WHERE label = 'plan'), :'inputs', :'prior_fp'),
  'PROMOTE_DRY_RUN_OK ' || :'live_fp' || '%',
  'APPLY.REPLACE.04 a dry run with no expected fingerprint raises with the one it computed');
-- pgt-ignore-end typecheck

SELECT ok(EXISTS (SELECT 1 FROM tbl_tournament WHERE id_tournament = :foil)
      AND fn_event_result_fingerprint('PPW7-2089-2090') = :'prior_fp',
  'APPLY.REPLACE.04 after the dry run the event holds what it held');

-- pgt-ignore-start typecheck: temp tables/views this file creates (the checker sees only the live schema)
SELECT throws_like(format($$SELECT fn_promote_event_apply('PPW7-2089-2090', %L::JSONB, NULL, %L::JSONB, %L, 'IN_PROGRESS', FALSE)$$,
                          (SELECT j FROM p WHERE label = 'plan'), :'inputs', repeat('0', 64)),
  'PROMOTE_PRIOR%',
  'APPLY.REPLACE.06 a prior mismatch raises');
-- pgt-ignore-end typecheck

SELECT ok(EXISTS (SELECT 1 FROM tbl_tournament WHERE id_tournament = :foil)
      AND (SELECT count(*) FROM tbl_result WHERE id_tournament = :foil) = 2,
  'APPLY.REPLACE.06 the refused apply deleted nothing');

SELECT throws_like(format($$SELECT fn_promote_event_apply('PPW7-2089-2090', '{"event_code": "PPW7-2089-2090", "ops": []}'::JSONB,
                                                          NULL, %L::JSONB, %L, 'IN_PROGRESS', FALSE)$$,
                          :'inputs'::TEXT, :'prior_fp'::TEXT),
  'PROMOTE_PLAN_EMPTY%',
  'APPLY.REPLACE.07 a plan that names no tournament never empties an event that holds results (R2.1 C)');

-- ---------------------------------------------------------------- the apply with no expected fingerprint
CREATE TEMP TABLE applied AS
-- pgt-ignore-start typecheck: temp tables/views this file creates (the checker sees only the live schema)
SELECT fn_promote_event_apply('PPW7-2089-2090', (SELECT j FROM p WHERE label = 'plan'), NULL, :'inputs'::JSONB,
                              :'prior_fp', 'IN_PROGRESS', FALSE) AS r;
-- pgt-ignore-end typecheck

-- pgt-ignore-start typecheck: temp tables/views this file creates (the checker sees only the live schema)
SELECT ok((SELECT r->>'fingerprint' FROM applied) = :'live_fp'
      AND (SELECT r->>'fingerprint' FROM applied) = fn_event_result_fingerprint('PPW7-2089-2090')
      AND (SELECT (r->>'skipped')::BOOLEAN FROM applied) IS FALSE,
  'APPLY.REPLACE.03 with no expected fingerprint the apply never skips and returns the fingerprint it reached');
-- pgt-ignore-end typecheck

SELECT ok(NOT EXISTS (SELECT 1 FROM tbl_tournament WHERE id_tournament = :foil)
      AND NOT EXISTS (SELECT 1 FROM tbl_result WHERE id_tournament = :foil),
  'APPLY.REPLACE.01 a tournament the plan does not name is deleted with its results');

SELECT ok(cardinality(:'foil_candidates'::INT[]) = 2
      AND NOT EXISTS (SELECT 1 FROM tbl_match_candidate WHERE id_match = ANY (:'foil_candidates'::INT[])),
  'APPLY.REPLACE.01 its match candidates go with it');

SELECT is((SELECT id_fencer FROM tbl_result WHERE id_tournament = :sabre AND int_place = 1), 98402,
  'APPLY.REPLACE.02 a tournament the plan names keeps its id and takes the plan''s results');

SELECT is((SELECT count(*)::INT FROM tbl_result WHERE id_tournament = :sabre), 2,
  'APPLY.REPLACE.02 its results are replaced, not doubled');

SELECT is((SELECT url_event_2 FROM tbl_event WHERE id_event = :ev), 'https://b.example/e',
  'APPLY.REPLACE.05 a blank result slot still takes the run''s URL');

SELECT is(fn_event_result_fingerprint('PPW6-2089-2090'), :'other_fp',
  'APPLY.REPLACE.06 another event''s tournaments are never touched');

-- ---------------------------------------------------------------- a skip still writes the event's record (G16)
-- The next run reads the same results, so the target already holds them and
-- the apply skips; its record of the listings and its blank links still move.
-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT array_agg(id_result ORDER BY id_result)::TEXT AS sabre_results FROM tbl_result WHERE id_tournament = :sabre \gset
-- pgt-ignore-start typecheck: temp tables/views this file creates (the checker sees only the live schema)
-- url_event is part of the result document, so a skip (an equal fingerprint)
-- already holds the run's url_event; slots 2-5 and the sources record are not.
INSERT INTO p SELECT 'skip', jsonb_build_object('event_code', 'PPW7-2089-2090', 'ops', jsonb_build_array(
    j->'ops'->0, j->'ops'->1,
    jsonb_build_object('op', 'set_event_source_url', 'id_event', :ev, 'slot', 'url_event_3',
      'url_event', 'https://c.example/e'),
    jsonb_build_object('op', 'set_event_ingest_sources', 'id_event', :ev, 'sources', jsonb_build_array(
      jsonb_build_object('url', 'https://a.example/r1', 'status', 'committed', 'weapon', 'SABRE', 'gender', 'M',
                         'committed_categories', jsonb_build_array('V2'))))))
  FROM p WHERE label = 'plan';
-- Its sources are written first, then slot 2 names another link: the refusal
-- must take the earlier write back with it.
INSERT INTO p SELECT 'skip_other_link', jsonb_build_object('event_code', 'PPW7-2089-2090', 'ops', jsonb_build_array(
    j->'ops'->0, j->'ops'->1,
    jsonb_build_object('op', 'set_event_ingest_sources', 'id_event', :ev, 'sources', jsonb_build_array(
      jsonb_build_object('url', 'https://other.example/r9', 'status', 'committed'))),
    jsonb_build_object('op', 'set_event_source_url', 'id_event', :ev, 'slot', 'url_event_2',
      'url_event', 'https://other.example/e')))
  FROM p WHERE label = 'plan';
-- A plan claiming the held result while filling the blank url_event is not
-- what any run records: the end-state check refuses it.
INSERT INTO p SELECT 'skip_moves_result', jsonb_build_object('event_code', 'PPW7-2089-2090', 'ops', jsonb_build_array(
    j->'ops'->0, j->'ops'->1,
    jsonb_build_object('op', 'set_event_url_event', 'id_event', :ev, 'url_event', 'https://a.example/e')))
  FROM p WHERE label = 'plan';
CREATE TEMP TABLE skipped AS
SELECT fn_promote_event_apply('PPW7-2089-2090', (SELECT j FROM p WHERE label = 'skip'), :'live_fp', :'inputs'::JSONB,
                              :'live_fp', 'IN_PROGRESS', FALSE) AS r;

SELECT ok((SELECT (r->>'skipped')::BOOLEAN FROM skipped) IS TRUE
      AND (SELECT (r->>'writes')::INT FROM skipped) = 2
      AND (SELECT r->>'fingerprint' FROM skipped) = :'live_fp',
  'APPLY.REPLACE.08 an apply whose results the target already holds skips them and counts only the record''s writes');
-- pgt-ignore-end typecheck

SELECT ok((SELECT json_ingest_sources->0->>'url' FROM tbl_event WHERE id_event = :ev) = 'https://a.example/r1'
      AND (SELECT url_event_3 FROM tbl_event WHERE id_event = :ev) = 'https://c.example/e',
  'APPLY.REPLACE.08 a skip still writes the event''s record of its sources and fills a blank result slot');

SELECT is((SELECT array_agg(id_result ORDER BY id_result)::TEXT FROM tbl_result WHERE id_tournament = :sabre),
          :'sabre_results',
  'APPLY.REPLACE.08 a skip leaves every result row as it was');

-- pgt-ignore-start typecheck: temp tables/views this file creates (the checker sees only the live schema)
SELECT throws_like(format($$SELECT fn_promote_event_apply('PPW7-2089-2090', %L::JSONB, %L, %L::JSONB, %L, 'IN_PROGRESS', FALSE)$$,
                          (SELECT j FROM p WHERE label = 'skip_other_link'), :'live_fp', :'inputs', :'live_fp'),
  'PROMOTE_URL_DIFFERS%',
  'APPLY.REPLACE.08 on a skip a different non-blank link still refuses');
-- pgt-ignore-end typecheck

SELECT ok((SELECT url_event_2 FROM tbl_event WHERE id_event = :ev) = 'https://b.example/e'
      AND (SELECT json_ingest_sources->0->>'url' FROM tbl_event WHERE id_event = :ev) = 'https://a.example/r1',
  'APPLY.REPLACE.08 the refused skip wrote nothing, not even the record it wrote before the refusal');

-- pgt-ignore-start typecheck: temp tables/views this file creates (the checker sees only the live schema)
SELECT throws_like(format($$SELECT fn_promote_event_apply('PPW7-2089-2090', %L::JSONB, %L, %L::JSONB, %L, 'IN_PROGRESS', FALSE)$$,
                          (SELECT j FROM p WHERE label = 'skip_moves_result'), :'live_fp', :'inputs', :'live_fp'),
  'PROMOTE_FINGERPRINT_MISMATCH%',
  'APPLY.REPLACE.08 a skip is compared too: a record write that would change the result refuses');
-- pgt-ignore-end typecheck

SELECT ok((SELECT url_event IS NULL FROM tbl_event WHERE id_event = :ev),
  'APPLY.REPLACE.08 and leaves the link as it was');

-- ---------------------------------------------------------------- reserved fencer ids
CREATE TEMP TABLE reserved AS
SELECT fn_reserve_fencer_id() AS a, (SELECT count(*) FROM tbl_fencer) AS fencers;
-- pgt-ignore-start typecheck: temp tables/views this file creates (the checker sees only the live schema)
SELECT ok(fn_reserve_fencer_id() = (SELECT a FROM reserved) + 1
      AND (SELECT a FROM reserved) > COALESCE(NULLIF(:'seq_before', '')::BIGINT, 0)
      AND (SELECT count(*) FROM tbl_fencer) = (SELECT fencers FROM reserved),
  'APPLY.RESERVE.01 the fencer sequence hands out the next ids and nothing is inserted');
-- pgt-ignore-end typecheck

SELECT ok(NOT has_function_privilege('anon', 'fn_reserve_fencer_id()', 'EXECUTE')
      AND NOT has_function_privilege('authenticated', 'fn_reserve_fencer_id()', 'EXECUTE')
      AND has_function_privilege('service_role', 'fn_reserve_fencer_id()', 'EXECUTE'),
  'APPLY.RESERVE.02 only the service role reserves an id');

-- Restore the fencer sequence (sequences do not roll back).
SELECT CASE WHEN NULLIF(:'seq_before', '') IS NULL
            THEN setval(pg_get_serial_sequence('public.tbl_fencer', 'id_fencer'), 1, FALSE)
            ELSE setval(pg_get_serial_sequence('public.tbl_fencer', 'id_fencer'), :'seq_before'::BIGINT) END;

SELECT * FROM finish();
ROLLBACK;
