-- =============================================================================
-- RUN — the record of one CERT ingestion, which promote replays (ADR-108 §4)
-- =============================================================================
-- ingest-event.yml with target cert opens a row in tbl_ingest_run before it
-- writes anything and closes it when the run ends. The row holds the event,
-- the environment, the commit, the event URL it ingested, the input
-- fingerprint, the hash of every source listing, and the master-data changes
-- the run made. Fingerprints and changes are computed in SQL only, so CERT and
-- PROD compute them the same way:
--
--   fn_schema_fingerprint       the release's schema fingerprint, over RPC
--   fn_event_input_fingerprint  what the ingestion reads, by person, never by id
--   fn_roster_snapshot          the roster as the run found it
--   fn_roster_changes           fencers created, birth years moved, aliases added
--
-- Service role only (ADR-083). Everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(30);

-- A season of its own, unlocked, so its scoring settings can change.
INSERT INTO tbl_season (txt_code, dt_start, dt_end) VALUES ('SPWS-2097-2098', DATE '2097-09-01', DATE '2098-06-30');

INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, enum_status)
SELECT c, 'RUN fixture', (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2097-2098'),
       (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'), DATE '2097-10-10', DATE '2097-10-11', 'PLANNED'
  FROM (VALUES ('PPW9-2097-2098'), ('PPW8-2097-2098')) v(c);

INSERT INTO tbl_fencer (id_fencer, txt_surname, txt_first_name, int_birth_year, enum_gender, json_name_aliases)
VALUES (98101, 'RUNA', 'Anna', 1975, 'F', '[]'::JSONB),
       (98102, 'RUNB', 'Beata', 1980, 'F', '["RUNB Beatka"]'::JSONB);

INSERT INTO tbl_registration (id_event, id_fencer, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons)
SELECT id_event, 98101, 'RUNA', 'Anna', 'F', 1975, ARRAY['EPEE']::enum_weapon_type[]
  FROM tbl_event WHERE txt_code = 'PPW9-2097-2098';

CREATE TEMP TABLE snaps (label TEXT PRIMARY KEY, fp JSONB);
INSERT INTO snaps SELECT 'base', fn_event_input_fingerprint('PPW9-2097-2098');

-- ---------------------------------------------------------------- service role only
SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid = 'tbl_ingest_run'::regclass),
  'RUN.01 tbl_ingest_run has row-level security on');

SELECT ok(NOT has_table_privilege('anon', 'tbl_ingest_run', 'SELECT')
      AND NOT has_table_privilege('authenticated', 'tbl_ingest_run', 'SELECT')
      AND has_table_privilege('service_role', 'tbl_ingest_run', 'INSERT'),
  'RUN.01 only the service role reads or writes run records');

SELECT is((SELECT count(*)::INT FROM unnest(ARRAY[
             'fn_schema_fingerprint()', 'fn_roster_snapshot()', 'fn_event_input_fingerprint(text)',
             'fn_roster_changes(jsonb,jsonb)',
             'fn_ingest_run_open(text,text,text,integer,text,text,text)',
             'fn_ingest_run_close(bigint,text,jsonb,text)', 'fn_ingest_run_finish(bigint,jsonb)',
             'fn_ingest_run_fail(bigint,text,jsonb)']) f
            WHERE NOT has_function_privilege('anon', f, 'EXECUTE')
              AND NOT has_function_privilege('authenticated', f, 'EXECUTE')
              AND has_function_privilege('service_role', f, 'EXECUTE')), 8,
  'RUN.01 the eight run-record functions run for the service role only');

-- ---------------------------------------------------------------- the schema fingerprint
SELECT matches(fn_schema_fingerprint(), '^[0-9a-f]{32}$', 'RUN.02 the schema fingerprint is an md5');

SET LOCAL ROLE service_role;
DO $$ BEGIN PERFORM set_config('run.fp_service', fn_schema_fingerprint(), TRUE); END $$;
RESET ROLE;
SELECT is(current_setting('run.fp_service'), fn_schema_fingerprint(),
  'RUN.02 the service role sees the whole schema, as the release script does');

-- ---------------------------------------------------------------- the input fingerprint
SELECT is((SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys((SELECT fp->'parts' FROM snaps WHERE label = 'base')) k),
          ARRAY['event', 'lock', 'registrations', 'roster', 'schema', 'season'],
  'RUN.03 the input fingerprint has a part per input: schema, roster, registrations, season, lock, event');

SELECT throws_like($$SELECT fn_event_input_fingerprint('PPW7-2097-2098')$$, '%INGEST_RUN_EVENT_NOT_FOUND%',
  'RUN.04 an unknown event is refused');

UPDATE tbl_event SET url_event = 'https://www.fencingtimelive.com/tournaments/eventSchedule/RUN'
 WHERE txt_code = 'PPW9-2097-2098';
SELECT is(fn_event_input_fingerprint('PPW9-2097-2098')->>'fingerprint', (SELECT fp->>'fingerprint' FROM snaps WHERE label = 'base'),
  'RUN.05 the event URL is not an input: promote writes CERT''s URL on PROD');

INSERT INTO tbl_registration (id_event, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons)
SELECT id_event, 'ELSEWHERE', 'Ewa', 'F', 1965, ARRAY['FOIL']::enum_weapon_type[] FROM tbl_event WHERE txt_code = 'PPW8-2097-2098';
SELECT is(fn_event_input_fingerprint('PPW9-2097-2098')->>'fingerprint', (SELECT fp->>'fingerprint' FROM snaps WHERE label = 'base'),
  'RUN.05 another event''s registrations are not an input');

UPDATE tbl_fencer SET id_fencer = 98199 WHERE id_fencer = 98102;
SELECT is(fn_event_input_fingerprint('PPW9-2097-2098')->>'fingerprint', (SELECT fp->>'fingerprint' FROM snaps WHERE label = 'base'),
  'RUN.05 the roster is fingerprinted by person, never by id');

SET LOCAL TimeZone = 'Pacific/Auckland';
SELECT is(fn_event_input_fingerprint('PPW9-2097-2098')->>'fingerprint', (SELECT fp->>'fingerprint' FROM snaps WHERE label = 'base'),
  'RUN.05 the session time zone changes nothing');
RESET TimeZone;

UPDATE tbl_scoring_config SET bool_show_evf_toggle = NOT COALESCE(bool_show_evf_toggle, FALSE)
 WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2097-2098');
SELECT is(fn_event_input_fingerprint('PPW9-2097-2098')->>'fingerprint', (SELECT fp->>'fingerprint' FROM snaps WHERE label = 'base'),
  'RUN.05 a display switch is not a scoring setting');

UPDATE tbl_fencer SET int_birth_year = 1976 WHERE id_fencer = 98101;
SELECT isnt(fn_event_input_fingerprint('PPW9-2097-2098')->'parts'->>'roster', (SELECT fp->'parts'->>'roster' FROM snaps WHERE label = 'base'),
  'RUN.06 a moved birth year changes the roster part');

INSERT INTO tbl_registration (id_event, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons)
SELECT id_event, 'LATE', 'Lena', 'F', 1970, ARRAY['SABRE']::enum_weapon_type[] FROM tbl_event WHERE txt_code = 'PPW9-2097-2098';
SELECT isnt(fn_event_input_fingerprint('PPW9-2097-2098')->'parts'->>'registrations', (SELECT fp->'parts'->>'registrations' FROM snaps WHERE label = 'base'),
  'RUN.06 a registration for the event changes the registrations part');

UPDATE tbl_scoring_config SET num_ppw_multiplier = num_ppw_multiplier + 1
 WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2097-2098');
SELECT isnt(fn_event_input_fingerprint('PPW9-2097-2098')->'parts'->>'season', (SELECT fp->'parts'->>'season' FROM snaps WHERE label = 'base'),
  'RUN.06 a scoring setting changes the season part');

UPDATE tbl_event SET json_source_overrides = '{"skip": ["https://www.fencingtimelive.com/events/results/X"]}'::JSONB
 WHERE txt_code = 'PPW9-2097-2098';
SELECT isnt(fn_event_input_fingerprint('PPW9-2097-2098')->'parts'->>'event', (SELECT fp->'parts'->>'event' FROM snaps WHERE label = 'base'),
  'RUN.06 an admin skip/process choice changes the event part');

INSERT INTO snaps SELECT 'prelock', fn_event_input_fingerprint('PPW9-2097-2098');
UPDATE tbl_season SET ts_scoring_locked_at = now() WHERE txt_code = 'SPWS-2097-2098';
SELECT is((fn_event_input_fingerprint('PPW9-2097-2098')->'parts'->>'lock')
          || '|' || (fn_event_input_fingerprint('PPW9-2097-2098')->'parts'->>'season'),
          'locked|' || (SELECT fp->'parts'->>'season' FROM snaps WHERE label = 'prelock'),
  'RUN.06 the lock is a part of its own; the season part ignores it');
UPDATE tbl_season SET ts_scoring_locked_at = NULL WHERE txt_code = 'SPWS-2097-2098';

-- ---------------------------------------------------------------- opening a run
CREATE TEMP TABLE runs (label TEXT PRIMARY KEY, id BIGINT);
INSERT INTO runs SELECT 'first', fn_ingest_run_open('PPW9-2097-2098', 'local', repeat('a', 40), 2098,
                                                   'https://www.fencingtimelive.com/tournaments/eventSchedule/RUN', NULL, NULL);

SELECT is((SELECT txt_status || '|' || txt_input_fingerprint FROM tbl_ingest_run WHERE id_ingest_run = (SELECT id FROM runs WHERE label = 'first')),
          'RUNNING|' || (fn_event_input_fingerprint('PPW9-2097-2098')->>'fingerprint'),
  'RUN.07 a run opens RUNNING, with the input fingerprint of the moment it opened');

SELECT is((SELECT jsonb_array_length(jsonb_roster_before) FROM tbl_ingest_run WHERE id_ingest_run = (SELECT id FROM runs WHERE label = 'first')),
          (SELECT count(*)::INT FROM tbl_fencer),
  'RUN.07 a run keeps the roster as it found it');

SELECT throws_ok($$SELECT fn_ingest_run_open('PPW9-2097-2098', 'prod', repeat('a', 40), 2098, 'https://x', NULL, NULL)$$,
  '23514', NULL, 'RUN.08 only LOCAL and CERT record runs');

SELECT throws_ok($$SELECT fn_ingest_run_open('PPW9-2097-2098', 'cert', 'main', 2098, 'https://x', NULL, NULL)$$,
  '23514', NULL, 'RUN.08 the commit is a full git hash');

INSERT INTO runs SELECT 'second', fn_ingest_run_open('PPW9-2097-2098', 'local', repeat('b', 40), 2098,
                                                    'https://www.fencingtimelive.com/tournaments/eventSchedule/RUN', NULL, NULL);
SELECT is((SELECT txt_status FROM tbl_ingest_run WHERE id_ingest_run = (SELECT id FROM runs WHERE label = 'first')), 'ABANDONED',
  'RUN.09 a newer run of the same event abandons one still running');

-- ---------------------------------------------------------------- what the run changed
INSERT INTO tbl_fencer (id_fencer, txt_surname, txt_first_name, int_birth_year, enum_gender)
VALUES (98103, 'RUNC', 'Celina', 1990, 'F');
UPDATE tbl_fencer SET int_birth_year = 1977 WHERE id_fencer = 98101;
UPDATE tbl_fencer SET json_name_aliases = json_name_aliases || '["RUNB B."]'::JSONB WHERE id_fencer = 98199;

INSERT INTO snaps SELECT 'finished', fn_ingest_run_finish((SELECT id FROM runs WHERE label = 'second'),
                                                          '{"rounds": [{"name": "Szpada K", "sha256": "x"}]}'::JSONB);

SELECT is((SELECT fp->'created' FROM snaps WHERE label = 'finished'),
          '[{"id_fencer": 98103, "surname": "RUNC", "first_name": "Celina", "birth_year": 1990, "estimated": false, "gender": "F", "aliases": []}]'::JSONB,
  'RUN.10 a fencer the run created is recorded, with the id it got');

SELECT is((SELECT fp->'birth_year_moved' FROM snaps WHERE label = 'finished'),
          '[{"id_fencer": 98101, "surname": "RUNA", "first_name": "Anna", "from": 1976, "to": 1977, "estimated_from": false, "estimated_to": false}]'::JSONB,
  'RUN.10 a birth year the run moved is recorded, from and to');

SELECT is((SELECT fp->'aliases_added' FROM snaps WHERE label = 'finished'),
          '[{"id_fencer": 98199, "surname": "RUNB", "first_name": "Beata", "alias": "RUNB B."}]'::JSONB,
  'RUN.10 an alias the run added is recorded');

SELECT is((SELECT txt_status || '|' || (jsonb_master_data = (SELECT fp FROM snaps WHERE label = 'finished'))::TEXT
                  || '|' || (jsonb_listings->'rounds'->0->>'name') || '|' || (ts_finished IS NOT NULL)::TEXT
             FROM tbl_ingest_run WHERE id_ingest_run = (SELECT id FROM runs WHERE label = 'second')),
          'FINISHED|true|Szpada K|true',
  'RUN.10 a finished run keeps its listings and its master-data changes');

SELECT throws_like($$SELECT fn_ingest_run_finish((SELECT id FROM runs WHERE label = 'second'), '{}'::JSONB)$$,
  '%INGEST_RUN_NOT_RUNNING%', 'RUN.11 a run finishes once');

INSERT INTO runs SELECT 'failed', fn_ingest_run_open('PPW9-2097-2098', 'cert', repeat('c', 40), 2098,
                                                    'https://www.fencingtimelive.com/tournaments/eventSchedule/RUN', NULL, NULL);
UPDATE tbl_fencer SET bool_birth_year_estimated = TRUE WHERE id_fencer = 98103;
DO $$ BEGIN PERFORM fn_ingest_run_fail((SELECT id FROM runs WHERE label = 'failed'), 'FTL timed out', NULL); END $$;
SELECT is((SELECT txt_status || '|' || txt_error || '|' || (jsonb_master_data->'birth_year_moved'->0->>'estimated_to')
             FROM tbl_ingest_run WHERE id_ingest_run = (SELECT id FROM runs WHERE label = 'failed')),
          'FAILED|FTL timed out|true',
  'RUN.12 a failed run keeps its error and what it had changed');

-- ---------------------------------------------------------------- anything else is recorded too
SELECT is(fn_roster_changes(
            '[{"id_fencer": 1, "txt_surname": "A", "txt_first_name": "B", "int_birth_year": 1970, "json_name_aliases": []},
              {"id_fencer": 2, "txt_surname": "C", "txt_first_name": "D", "int_birth_year": 1971, "json_name_aliases": ["C Dd"]}]'::JSONB,
            '[{"id_fencer": 2, "txt_surname": "C", "txt_first_name": "Dorota", "int_birth_year": 1971, "json_name_aliases": []}]'::JSONB)
          - 'created' - 'birth_year_moved' - 'aliases_added',
          '{"deleted": [{"id_fencer": 1, "surname": "A", "first_name": "B", "birth_year": 1970}],
            "other": [{"id_fencer": 2, "surname": "C", "first_name": "Dorota", "columns": ["json_name_aliases", "txt_first_name"]}]}'::JSONB,
  'RUN.13 a deleted fencer, a renamed fencer and a removed alias are recorded');

SELECT is(fn_roster_changes('[]'::JSONB, '[]'::JSONB),
          '{"created": [], "deleted": [], "birth_year_moved": [], "aliases_added": [], "other": []}'::JSONB,
  'RUN.13 no change is five empty lists');

SELECT * FROM finish();
ROLLBACK;
