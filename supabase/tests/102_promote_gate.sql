-- =============================================================================
-- GATE.DB — the CERT gate's database checks for one event (ADR-108 §5)
-- =============================================================================
-- fn_promote_gate_checks(event, fencer ids) reads the target's committed state
-- after a CERT run and lists every finding the gate (promotion/gate.py) turns
-- into a block or a note: participants whose birth year is an estimate, PENDING
-- match candidates, results without a score or components, the season's active
-- revision and its stamp, the SS26.PARITY contract for every result,
-- tournaments typed against their code (TT.CODE.06), joined-listing siblings and
-- their order, the recompute queue for the event and the fencers the run
-- touched, the birth years each named fencer's results allow, the ADR-104 §7
-- joining check, and the stored tournaments the gate compares with the source.
--
-- Service role only (ADR-083). Everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(18);

-- A season of its own on EVF classic, with the latest real settings.
INSERT INTO tbl_season (txt_code, dt_start, dt_end) VALUES ('SPWS-2096-2097', DATE '2096-09-01', DATE '2097-06-30');
UPDATE tbl_season SET id_scoring_engine = (SELECT id_engine FROM tbl_scoring_engine WHERE txt_code = 'EVF_CLASSIC_V1_2025_2026')
 WHERE txt_code = 'SPWS-2096-2097';
UPDATE tbl_scoring_config dst SET
  int_mp_value = src.int_mp_value, int_podium_gold = src.int_podium_gold, int_podium_silver = src.int_podium_silver,
  int_podium_bronze = src.int_podium_bronze, num_ppw_multiplier = src.num_ppw_multiplier,
  num_mpw_multiplier = src.num_mpw_multiplier, int_min_participants_ppw = src.int_min_participants_ppw,
  int_min_participants_evf = src.int_min_participants_evf, json_ranking_rules = src.json_ranking_rules
FROM tbl_scoring_config src
WHERE src.id_season = (SELECT id_season FROM tbl_scoring_config
                        WHERE json_ranking_rules ? 'domestic' AND json_ranking_rules ? 'international'
                        ORDER BY id_season DESC LIMIT 1)
  AND dst.id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2096-2097');

INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, enum_status)
SELECT c, 'GATE fixture', (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2096-2097'),
       (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'), DATE '2096-10-10', DATE '2096-10-11', 'IN_PROGRESS'
  FROM (VALUES ('PPW9-2096-2097'), ('PPW8-2096-2097')) v(c);

-- Born 2050: V1 at season end 2097. Born 2060: V0.
INSERT INTO tbl_fencer (id_fencer, txt_surname, txt_first_name, int_birth_year, enum_gender, bool_birth_year_estimated)
VALUES (98201, 'GATEA', 'Adam', 2050, 'M', FALSE), (98202, 'GATEB', 'Bogdan', 2050, 'M', FALSE),
       (98203, 'GATEC', 'Cezary', 2060, 'M', FALSE), (98204, 'GATED', 'Damian', 2060, 'M', FALSE);

-- One joined listing (V1 and V0, N = 4, order "1010") and its two sibling tournaments.
DO $fx$
DECLARE v_e INT := (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW9-2096-2097'); v1 INT; v0 INT;
BEGIN
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender, enum_age_category,
                              dt_tournament, int_participant_count, url_results, txt_joined_order, enum_import_status)
  VALUES (v_e, 'PPW9-V1-M-SABRE-2096-2097', 'g', 'PPW', 'SABRE', 'M', 'V1', DATE '2096-10-10', 4,
          'https://www.fencingtimelive.com/events/results/GATE1', '1010', 'IMPORTED') RETURNING id_tournament INTO v1;
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender, enum_age_category,
                              dt_tournament, int_participant_count, url_results, txt_joined_order, enum_import_status)
  VALUES (v_e, 'PPW9-V0-M-SABRE-2096-2097', 'g', 'PPW', 'SABRE', 'M', 'V0', DATE '2096-10-10', 4,
          'https://www.fencingtimelive.com/events/results/GATE1', '1010', 'IMPORTED') RETURNING id_tournament INTO v0;
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
  VALUES (98201, v1, 1, 'GATEA Adam'), (98202, v1, 3, 'GATEB Bogdan'),
         (98203, v0, 2, 'GATEC Cezary'), (98204, v0, 4, 'GATED Damian');
  PERFORM fn_calc_tournament_scores(v1);
  PERFORM fn_calc_tournament_scores(v0);
END $fx$;

CREATE TEMP TABLE g (label TEXT PRIMARY KEY, j JSONB);
INSERT INTO g SELECT 'clean', fn_promote_gate_checks('PPW9-2096-2097', ARRAY[98201]);

-- ---------------------------------------------------------------- grants
SELECT ok(NOT has_function_privilege('anon', 'fn_promote_gate_checks(text,integer[])', 'EXECUTE')
      AND NOT has_function_privilege('authenticated', 'fn_promote_gate_checks(text,integer[])', 'EXECUTE')
      AND has_function_privilege('service_role', 'fn_promote_gate_checks(text,integer[])', 'EXECUTE')
      AND NOT has_function_privilege('anon', 'fn_fencer_fitting_birth_years(integer)', 'EXECUTE')
      AND NOT has_function_privilege('anon', 'fn_ingest_run_gate(bigint,jsonb)', 'EXECUTE')
      AND has_function_privilege('service_role', 'fn_ingest_run_gate(bigint,jsonb)', 'EXECUTE')
      AND has_function_privilege('service_role', 'fn_fencer_fitting_birth_years(integer)', 'EXECUTE'),
  'GATE.DB.01 the gate''s functions run for the service role only');

-- ---------------------------------------------------------------- a clean event
SELECT is((SELECT jsonb_object_agg(k, jsonb_array_length(v)) FROM jsonb_each((SELECT j FROM g WHERE label = 'clean')) e(k, v)
            WHERE jsonb_typeof(v) = 'array' AND k NOT IN ('stored')),
          '{"estimated_years": 0, "pending_candidates": 0, "unscored": 0, "unstamped": 0, "parity": 0,
            "type_code": 0, "joined": 0, "queue": 0, "joining": 0}'::JSONB,
  'GATE.DB.02 a clean, scored event has no finding in any check');

SELECT is((SELECT (j->>'active_revisions')::INT FROM g WHERE label = 'clean'), 1,
  'GATE.DB.02 the season has exactly one active revision after its first score');

SELECT is((SELECT jsonb_array_length(j->'stored') || '|' || (j->'stored'->0->>'n') || '|' || (j->'stored'->0->>'order')
                  || '|' || jsonb_array_length(j->'stored'->0->'results') FROM g WHERE label = 'clean'),
          '2|4|1010|2',
  'GATE.DB.03 the stored tournaments come back with N, order and results, for the source comparison');

-- ---------------------------------------------------------------- birth years
SELECT is(fn_fencer_fitting_birth_years(98201), ARRAY(SELECT generate_series(2048, 2057)),
  'GATE.DB.04 a V1 result at season end 2097 allows the years 2048 to 2057');

UPDATE tbl_fencer SET bool_birth_year_estimated = TRUE WHERE id_fencer = 98202;
SELECT is((SELECT jsonb_agg(x->>'id_fencer') FROM jsonb_array_elements(fn_promote_gate_checks('PPW9-2096-2097', '{}')->'estimated_years') x),
          '["98202"]'::JSONB,
  'GATE.DB.05 a participant whose birth year is an estimate is listed');
UPDATE tbl_fencer SET bool_birth_year_estimated = FALSE WHERE id_fencer = 98202;

-- ---------------------------------------------------------------- PENDING
INSERT INTO tbl_match_candidate (id_result, txt_scraped_name, id_fencer, num_confidence, enum_status)
SELECT id_result, 'GATEB Bogdan', 98202, 70, 'PENDING' FROM tbl_result WHERE id_fencer = 98202;
SELECT is(jsonb_array_length(fn_promote_gate_checks('PPW9-2096-2097', '{}')->'pending_candidates'), 1,
  'GATE.DB.06 a PENDING match candidate on the event''s result is listed');
DELETE FROM tbl_match_candidate WHERE txt_scraped_name = 'GATEB Bogdan';

-- ---------------------------------------------------------------- scoring
UPDATE tbl_result SET num_final_score = num_final_score + 1 WHERE id_fencer = 98201;
SELECT is((SELECT x->>'id_fencer' FROM jsonb_array_elements(fn_promote_gate_checks('PPW9-2096-2097', '{}')->'parity') x),
          '98201',
  'GATE.DB.07 a stored score the engine''s preview does not reproduce is listed (SS26.PARITY)');
UPDATE tbl_result SET num_final_score = num_final_score - 1 WHERE id_fencer = 98201;

UPDATE tbl_result SET num_de_bonus = NULL WHERE id_fencer = 98203;
SELECT is((SELECT x->>'id_fencer' FROM jsonb_array_elements(fn_promote_gate_checks('PPW9-2096-2097', '{}')->'unscored') x),
          '98203',
  'GATE.DB.08 a result missing a score component is listed');

UPDATE tbl_result SET id_scoring_revision = NULL WHERE id_fencer = 98204;
SELECT is((SELECT x->>'id_fencer' FROM jsonb_array_elements(fn_promote_gate_checks('PPW9-2096-2097', '{}')->'unstamped') x),
          '98204',
  'GATE.DB.09 a result not stamped with the active revision is listed');

SET LOCAL session_replication_role = replica;
UPDATE tbl_tournament SET enum_type = 'MPW' WHERE txt_code = 'PPW9-V0-M-SABRE-2096-2097';
SET LOCAL session_replication_role = origin;
SELECT is((SELECT x->>'tournament' FROM jsonb_array_elements(fn_promote_gate_checks('PPW9-2096-2097', '{}')->'type_code') x),
          'PPW9-V0-M-SABRE-2096-2097',
  'GATE.DB.10 a tournament typed against its code family is listed (TT.CODE.06)');
SET LOCAL session_replication_role = replica;
UPDATE tbl_tournament SET enum_type = 'PPW' WHERE txt_code = 'PPW9-V0-M-SABRE-2096-2097';
SET LOCAL session_replication_role = origin;

-- ---------------------------------------------------------------- joined listing
UPDATE tbl_tournament SET int_participant_count = 5, txt_joined_order = '10100' WHERE txt_code = 'PPW9-V0-M-SABRE-2096-2097';
SELECT is((SELECT jsonb_agg(x->>'problem' ORDER BY x->>'problem') FROM jsonb_array_elements(fn_promote_gate_checks('PPW9-2096-2097', '{}')->'joined') x),
          '["siblings disagree on N or on the category order"]'::JSONB,
  'GATE.DB.11 siblings of one listing that disagree on N or order are listed');

-- An order whose length is not N cannot be stored at all (chk_tournament_joined_order).
UPDATE tbl_tournament SET int_participant_count = 4, txt_joined_order = '1010' WHERE txt_code LIKE 'PPW9-V%-M-SABRE-2096-2097';

UPDATE tbl_tournament SET txt_joined_order = '1100' WHERE txt_code LIKE 'PPW9-V%-M-SABRE-2096-2097';
SELECT ok((SELECT bool_or(x->>'problem' LIKE 'place % digit%') FROM jsonb_array_elements(fn_promote_gate_checks('PPW9-2096-2097', '{}')->'joined') x),
  'GATE.DB.12 an order digit that does not match the stored fencer''s category is listed');

-- ---------------------------------------------------------------- the queue and the joining check
INSERT INTO tbl_recompute_queue (id_event, enum_status) SELECT id_event, 'PENDING' FROM tbl_event WHERE txt_code = 'PPW8-2096-2097';
SELECT is(jsonb_array_length(fn_promote_gate_checks('PPW9-2096-2097', '{}')->'queue'), 0,
  'GATE.DB.13 another event''s queue row is not this run''s, unless a touched fencer has a result there');

INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender, enum_age_category,
                            dt_tournament, int_participant_count, enum_import_status)
SELECT id_event, 'PPW8-V1-M-FOIL-2096-2097', 'g', 'PPW', 'FOIL', 'M', 'V1', DATE '2096-11-10', 1, 'IMPORTED'
  FROM tbl_event WHERE txt_code = 'PPW8-2096-2097';
INSERT INTO tbl_result (id_fencer, id_tournament, int_place) SELECT 98201, id_tournament, 1 FROM tbl_tournament WHERE txt_code = 'PPW8-V1-M-FOIL-2096-2097';
SELECT is((SELECT x->>'event' FROM jsonb_array_elements(fn_promote_gate_checks('PPW9-2096-2097', ARRAY[98201])->'queue') x),
          'PPW8-2096-2097',
  'GATE.DB.13 a queued event where a fencer the run touched has a result is listed');

INSERT INTO tbl_joining_check (id_event, enum_weapon, enum_gender, txt_fenced, txt_rule, bool_match)
SELECT id_event, 'SABRE', 'M', 'V0+V1', 'V0, V1', FALSE FROM tbl_event WHERE txt_code = 'PPW9-2096-2097';
SELECT is((SELECT x->>'fenced' FROM jsonb_array_elements(fn_promote_gate_checks('PPW9-2096-2097', '{}')->'joining') x),
          'V0+V1',
  'GATE.DB.14 a joining check that differs from the scoring table is listed, for information');

INSERT INTO tbl_ingest_run (txt_event_code, txt_environment, txt_git_commit, int_season_end_year, url_event,
                            txt_status, ts_finished, txt_input_fingerprint, jsonb_input_parts, jsonb_roster_before)
VALUES ('PPW9-2096-2097', 'local', repeat('d', 40), 2097, 'https://x', 'FINISHED', now(), 'f', '{}', '[]');
SELECT fn_ingest_run_gate((SELECT max(id_ingest_run) FROM tbl_ingest_run WHERE txt_event_code = 'PPW9-2096-2097'),
                          '{"passed": false}'::JSONB);
SELECT is((SELECT jsonb_gate FROM tbl_ingest_run WHERE txt_event_code = 'PPW9-2096-2097'), '{"passed": false}'::JSONB,
  'GATE.DB.15 the gate''s outcome is recorded on the run row');

SELECT throws_like($$SELECT fn_promote_gate_checks('PPW7-2096-2097', '{}')$$, '%GATE_EVENT_NOT_FOUND%',
  'GATE.DB.16 an unknown event is refused');

SELECT * FROM finish();
ROLLBACK;
