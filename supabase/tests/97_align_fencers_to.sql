-- =============================================================================
-- ALIGN — fn_align_fencers_to gives a target database PROD's fencer ids (ADR-108 §3)
-- =============================================================================
-- The rule is the administrator's: the fencer id is the same on LOCAL, CERT and
-- PROD, and nothing is guessed. The refresh pairs every target fencer with its
-- PROD row in Python; this function applies the pairing in one transaction:
--
--   * renumbering in two phases (copy to a temporary negative id, move every
--     reference, delete; then the same to PROD's id), so swaps and cycles of
--     ids cannot collide, with no trigger switched off;
--   * every foreign key to tbl_fencer found from the catalogue, plus the soft
--     references (tbl_result_draft.id_fencer and the audit log);
--   * PROD's values copied once the ids are in place; PROD-only fencers created;
--     unreferenced target-only fencers deleted; the sequence set;
--   * a check before commit that the roster equals PROD's and that every
--     person keeps exactly the rows they had.
--
-- Fixture fencers live at ids 96001–96008; the rest of the roster is paired
-- with itself. Everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(28);

-- Sequences are not transactional: remember the fencer sequence and put it back
-- before the rollback, so this test leaves LOCAL's next id where it found it.
CREATE TEMP TABLE al_seq AS SELECT last_value, is_called FROM tbl_fencer_id_fencer_seq;

-- ---------------------------------------------------------------------------
-- Fixture. A↔B swap ids; C→F→G→C cycle; H keeps its id but takes PROD's birth
-- year, confirmed flag and aliases; D exists only on the target and nothing
-- refers to it; E exists only on PROD.
-- ---------------------------------------------------------------------------
INSERT INTO tbl_fencer (id_fencer, txt_surname, txt_first_name, int_birth_year,
                        bool_birth_year_estimated, enum_gender, json_name_aliases)
VALUES (96001, 'ALIGNA', 'Adam',    1970, false, 'M', '["ALIGNA ADAMEK"]'),
       (96002, 'ALIGNB', 'Bogdan',  1971, false, 'M', NULL),
       (96003, 'ALIGNC', 'Cezary',  1972, false, 'M', NULL),
       (96004, 'ALIGND', 'Dawid',   1973, false, 'M', NULL),
       (96006, 'ALIGNF', 'Filip',   1966, false, 'M', NULL),
       (96007, 'ALIGNG', 'Gustaw',  1967, false, 'M', NULL),
       (96008, 'ALIGNH', 'Hubert',  1974, true,  'M', '["ALIGNH HUBI"]');

CREATE TEMP TABLE al_ids AS
SELECT (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025') AS s2425,
       (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS') AS spws;

INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, enum_status)
SELECT 'PPW8-2024-2025', 'ALIGN fixture', s2425, spws, DATE '2025-05-10', DATE '2025-05-10', 'COMPLETED'
  FROM al_ids;

INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category, dt_tournament)
SELECT e.id_event, c, 'PPW', w::enum_weapon_type, 'M', 'V2', DATE '2025-05-10'
  FROM tbl_event e, (VALUES ('PPW8-V2-M-EPEE-2024-2025', 'EPEE'),
                            ('PPW8-V2-M-FOIL-2024-2025', 'FOIL')) v(c, w)
 WHERE e.txt_code = 'PPW8-2024-2025';

CREATE TEMP VIEW al_t AS
SELECT (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW8-V2-M-EPEE-2024-2025') AS epee,
       (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW8-V2-M-FOIL-2024-2025') AS foil;

INSERT INTO tbl_result (id_tournament, id_fencer, int_place)
SELECT epee, f, p FROM al_t, (VALUES (96001, 1), (96002, 2), (96003, 3), (96006, 4), (96007, 5), (96008, 6)) v(f, p);
INSERT INTO tbl_result (id_tournament, id_fencer, int_place) SELECT foil, 96001, 1 FROM al_t;

INSERT INTO tbl_registration (id_event, id_fencer, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons)
SELECT id_event, 96001, 'ALIGNA', 'Adam', 'M', 1970, ARRAY['EPEE']::enum_weapon_type[]
  FROM tbl_event WHERE txt_code = 'PPW8-2024-2025';

INSERT INTO tbl_match_candidate (id_result, id_fencer, txt_scraped_name)
SELECT r.id_result, 96001, 'ALIGNA Adam'
  FROM tbl_result r, al_t WHERE r.id_tournament = al_t.foil AND r.id_fencer = 96001;

INSERT INTO tbl_fencer_nationality (id_fencer, id_season, txt_country, enum_source)
SELECT 96001, s2425, 'POL', 'ADMIN' FROM al_ids;

INSERT INTO tbl_registration_identity_override (id_registration, id_fencer, txt_surname, txt_first_name,
                                                int_birth_year_before, int_birth_year_after)
SELECT id_registration, 96001, 'ALIGNA', 'Adam', 1969, 1970
  FROM tbl_registration WHERE id_fencer = 96001;

INSERT INTO tbl_tournament_draft (id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category, txt_run_id)
SELECT id_event, 'PPW8-V2-M-EPEE-2024-2025', 'PPW', 'EPEE', 'M', 'V2', 'a1a1a1a1-0000-4000-8000-000000000097'
  FROM tbl_event WHERE txt_code = 'PPW8-2024-2025';
INSERT INTO tbl_result_draft (id_tournament_draft, id_fencer, int_place, txt_run_id)
SELECT id_tournament_draft, 96001, 1, 'a1a1a1a1-0000-4000-8000-000000000097' FROM tbl_tournament_draft WHERE txt_run_id = 'a1a1a1a1-0000-4000-8000-000000000097';

-- History written before the alignment: one fencer row, one result row.
INSERT INTO tbl_audit_log (txt_table_name, id_row, txt_action, jsonb_old_values, jsonb_new_values)
VALUES ('tbl_fencer', 96001, 'ALIGN_FIXTURE', '{"id_fencer": 96001}', '{"id_fencer": 96001}'),
       ('tbl_result', 1, 'ALIGN_FIXTURE', '{"id_fencer": 96001, "int_place": 1}', NULL);

-- ---------------------------------------------------------------------------
-- The payload the refresh would send.
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE al_map AS
SELECT id_fencer AS cert_id,
       CASE id_fencer WHEN 96001 THEN 96002 WHEN 96002 THEN 96001
                      WHEN 96003 THEN 96006 WHEN 96006 THEN 96007 WHEN 96007 THEN 96003
                      ELSE id_fencer END AS prod_id
  FROM tbl_fencer WHERE id_fencer <> 96004;

CREATE TEMP TABLE al_prod AS
SELECT to_jsonb(f) || jsonb_build_object('id_fencer', m.prod_id) AS j
  FROM tbl_fencer f JOIN al_map m ON m.cert_id = f.id_fencer;
-- On PROD the alias "ALIGNA ADAMEK" belongs to B (id 96001); A (96002) has none.
UPDATE al_prod SET j = j || '{"json_name_aliases": []}' WHERE (j->>'id_fencer')::INT = 96002;
UPDATE al_prod SET j = j || '{"json_name_aliases": ["ALIGNA ADAMEK"]}' WHERE (j->>'id_fencer')::INT = 96001;
-- H: PROD confirmed 1975 and holds no alias; E holds H's old alias.
UPDATE al_prod SET j = j || '{"int_birth_year": 1975, "bool_birth_year_estimated": false, "json_name_aliases": []}'
 WHERE (j->>'id_fencer')::INT = 96008;
INSERT INTO al_prod
SELECT jsonb_build_object('id_fencer', 96005, 'txt_surname', 'ALIGNE', 'txt_first_name', 'Edward',
                          'int_birth_year', 1969, 'txt_nationality', 'PL', 'bool_birth_year_estimated', false,
                          'enum_gender', 'M', 'json_name_aliases', '["ALIGNH HUBI"]'::jsonb,
                          'json_revoked_aliases', '[]'::jsonb, 'json_user_confirmed_aliases', '[]'::jsonb,
                          'ts_created', now(), 'ts_updated', now());

-- The target's roster before the alignment: the restore point (ALIGN.28).
CREATE TEMP TABLE al_orig AS SELECT jsonb_agg(to_jsonb(f)) AS j FROM tbl_fencer f;
CREATE TEMP TABLE al_orig_places AS
SELECT f.txt_surname, r.int_place, r.id_tournament FROM tbl_result r JOIN tbl_fencer f USING (id_fencer)
 WHERE f.id_fencer BETWEEN 96001 AND 96008;

CREATE TEMP VIEW al_pairs AS
SELECT jsonb_agg(jsonb_build_object('cert_id', cert_id, 'prod_id', prod_id)) AS j FROM al_map;
CREATE TEMP VIEW al_roster AS SELECT jsonb_agg(j) AS j FROM al_prod;

-- ---------------------------------------------------------------------------
-- Grants and the catalogue guard
-- ---------------------------------------------------------------------------
SELECT ok(NOT has_function_privilege('anon', 'fn_align_fencers_to(jsonb,jsonb,jsonb,bigint,boolean)', 'EXECUTE')
          AND NOT has_function_privilege('authenticated', 'fn_align_fencers_to(jsonb,jsonb,jsonb,bigint,boolean)', 'EXECUTE')
          AND has_function_privilege('service_role', 'fn_align_fencers_to(jsonb,jsonb,jsonb,bigint,boolean)', 'EXECUTE'),
  'ALIGN.01 only the service role may run the alignment');

SELECT is_empty(
  $$SELECT c.table_name || '.' || c.column_name
      FROM information_schema.columns c
      JOIN information_schema.tables t ON t.table_schema = c.table_schema AND t.table_name = c.table_name
     WHERE c.table_schema = 'public' AND t.table_type = 'BASE TABLE'
       AND c.column_name LIKE '%fencer%' AND c.data_type = 'integer'
       AND (c.table_name, c.column_name) NOT IN (('tbl_fencer', 'id_fencer'), ('tbl_result_draft', 'id_fencer'))
       AND NOT EXISTS (
         SELECT 1 FROM pg_constraint k
           JOIN pg_attribute a ON a.attrelid = k.conrelid AND a.attnum = ANY (k.conkey)
          WHERE k.contype = 'f' AND k.confrelid = 'tbl_fencer'::regclass
            AND k.conrelid = ('public.' || c.table_name)::regclass AND a.attname = c.column_name)$$,
  'ALIGN.02 every fencer-id column is a foreign key to tbl_fencer or a listed soft reference');

-- ---------------------------------------------------------------------------
-- Refusals change nothing
-- ---------------------------------------------------------------------------
SELECT throws_like(
  $$SELECT fn_align_fencers_to((SELECT jsonb_agg(x) FROM jsonb_array_elements((SELECT j FROM al_pairs)) x
                                 WHERE (x->>'cert_id')::INT <> 96008),
                               (SELECT j FROM al_roster), '[96004]', NULL, false)$$,
  '%ALIGN_UNPAIRED%96008%',
  'ALIGN.03 a target fencer neither paired nor deleted stops the alignment, named');

SELECT throws_like(
  $$SELECT fn_align_fencers_to((SELECT j FROM al_pairs), (SELECT j FROM al_roster), '[96004, 96001]', NULL, false)$$,
  '%ALIGN_%96001%',
  'ALIGN.04 a fencer cannot be both paired and deleted');

SELECT throws_like(
  $$SELECT fn_align_fencers_to((SELECT j FROM al_pairs) || '[{"cert_id": 96004, "prod_id": 96002}]',
                               (SELECT j FROM al_roster), '[]', NULL, false)$$,
  '%ALIGN_DUPLICATE_PROD_ID%96002%',
  'ALIGN.05 two target fencers paired with one PROD id stop the alignment');

UPDATE tbl_fencer SET int_birth_year = 1940 WHERE id_fencer = 96007;
SELECT throws_like(
  $$SELECT fn_align_fencers_to((SELECT j FROM al_pairs), (SELECT j FROM al_roster), '[96004]', NULL, false)$$,
  '%ALIGN_VCAT%96007%',
  'ALIGN.06 a moving fencer with a result its stored birth year contradicts is listed before anything is written');
UPDATE tbl_fencer SET int_birth_year = 1967 WHERE id_fencer = 96007;

SELECT throws_like(
  $$SELECT fn_align_fencers_to((SELECT j FROM al_pairs), (SELECT j FROM al_roster), '[96004]', NULL, true)$$,
  '%ALIGN_DRY_RUN_OK%',
  'ALIGN.07 a dry run does every step and then raises');

SELECT results_eq(
  $$SELECT id_fencer, txt_surname FROM tbl_fencer WHERE id_fencer BETWEEN 96001 AND 96008 ORDER BY 1$$,
  $$VALUES (96001, 'ALIGNA'::TEXT), (96002, 'ALIGNB'), (96003, 'ALIGNC'), (96004, 'ALIGND'),
           (96006, 'ALIGNF'), (96007, 'ALIGNG'), (96008, 'ALIGNH')$$,
  'ALIGN.08 after the refusals and the dry run the roster is exactly as before');

-- ---------------------------------------------------------------------------
-- The alignment
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE al_out AS
SELECT fn_align_fencers_to((SELECT j FROM al_pairs), (SELECT j FROM al_roster), '[96004]', NULL, false) AS j;

SELECT results_eq(
  $$SELECT id_fencer, txt_surname FROM tbl_fencer WHERE id_fencer BETWEEN 96001 AND 96008 ORDER BY 1$$,
  $$VALUES (96001, 'ALIGNB'::TEXT), (96002, 'ALIGNA'), (96003, 'ALIGNG'), (96005, 'ALIGNE'),
           (96006, 'ALIGNC'), (96007, 'ALIGNF'), (96008, 'ALIGNH')$$,
  'ALIGN.09 swapped and cycled fencers sit at PROD''s ids; E is created; D is deleted');

SELECT results_eq(
  $$SELECT r.id_fencer, count(*)::INT FROM tbl_result r JOIN al_t ON r.id_tournament IN (al_t.epee, al_t.foil)
     GROUP BY 1 ORDER BY 1$$,
  $$VALUES (96001, 1), (96002, 2), (96003, 1), (96006, 1), (96007, 1), (96008, 1)$$,
  'ALIGN.10 every result follows its person');

SELECT results_eq(
  $$SELECT f.txt_surname, r.int_place FROM tbl_result r JOIN tbl_fencer f USING (id_fencer)
      JOIN al_t ON r.id_tournament = al_t.epee ORDER BY r.int_place$$,
  $$VALUES ('ALIGNA'::TEXT, 1), ('ALIGNB', 2), ('ALIGNC', 3), ('ALIGNF', 4), ('ALIGNG', 5), ('ALIGNH', 6)$$,
  'ALIGN.11 each place still belongs to the same person');

SELECT is((SELECT id_fencer FROM tbl_registration r JOIN tbl_event e USING (id_event)
            WHERE e.txt_code = 'PPW8-2024-2025'), 96002,
  'ALIGN.12 the registration follows');
SELECT is((SELECT id_fencer FROM tbl_match_candidate WHERE txt_scraped_name = 'ALIGNA Adam'), 96002,
  'ALIGN.13 the match candidate follows');
SELECT is((SELECT id_fencer FROM tbl_fencer_nationality n JOIN al_ids ON n.id_season = al_ids.s2425
            WHERE txt_country = 'POL' AND enum_source = 'ADMIN' AND id_fencer IN (96001, 96002)), 96002,
  'ALIGN.14 the season nationality follows and keeps its admin source');
SELECT is((SELECT id_fencer FROM tbl_registration_identity_override WHERE txt_surname = 'ALIGNA'), 96002,
  'ALIGN.15 the identity override follows');
SELECT is((SELECT id_fencer FROM tbl_result_draft WHERE txt_run_id = 'a1a1a1a1-0000-4000-8000-000000000097'), 96002,
  'ALIGN.16 the draft result, which has no foreign key, follows');

SELECT results_eq(
  $$SELECT id_fencer, json_name_aliases FROM tbl_fencer WHERE id_fencer IN (96001, 96002, 96005, 96008) ORDER BY 1$$,
  $$VALUES (96001, '["ALIGNA ADAMEK"]'::jsonb), (96002, '[]'::jsonb),
           (96005, '["ALIGNH HUBI"]'::jsonb), (96008, '[]'::jsonb)$$,
  'ALIGN.17 aliases are PROD''s, including one that moved to another person');

SELECT results_eq(
  $$SELECT int_birth_year::INT, bool_birth_year_estimated FROM tbl_fencer WHERE id_fencer = 96008$$,
  $$VALUES (1975, false)$$,
  'ALIGN.18 an unmoved fencer takes PROD''s birth year and confirmed flag');

SELECT is_empty(
  $$SELECT id_fencer FROM tbl_fencer WHERE id_fencer < 0$$,
  'ALIGN.19 no temporary row is left behind');

SELECT is_empty(
  $$(SELECT id_fencer, txt_surname, txt_first_name, int_birth_year, bool_birth_year_estimated, enum_gender::TEXT
       FROM tbl_fencer)
    EXCEPT
    (SELECT (j->>'id_fencer')::INT, j->>'txt_surname', j->>'txt_first_name', (j->>'int_birth_year')::SMALLINT,
            (j->>'bool_birth_year_estimated')::BOOLEAN, j->>'enum_gender' FROM al_prod)$$,
  'ALIGN.20 the roster equals PROD''s, id for id');

SELECT ok((SELECT last_value FROM tbl_fencer_id_fencer_seq) >= 96007,
  'ALIGN.21 the id sequence is past the highest id');

SELECT is((SELECT id_row FROM tbl_audit_log WHERE txt_action = 'ALIGN_FIXTURE' AND txt_table_name = 'tbl_fencer'), 96002,
  'ALIGN.22 an older audit row about a fencer follows the person');
SELECT is((SELECT (jsonb_old_values->>'id_fencer')::INT FROM tbl_audit_log
            WHERE txt_action = 'ALIGN_FIXTURE' AND txt_table_name = 'tbl_result'), 96002,
  'ALIGN.23 an older audit row about a result names the person''s new id');
SELECT is((SELECT jsonb_old_values->'96001' FROM tbl_audit_log WHERE txt_action = 'ALIGN_TO_PROD'
            ORDER BY id_log DESC LIMIT 1), '96002'::jsonb,
  'ALIGN.24 one audit row keeps the whole old-to-new map');

SELECT results_eq(
  $$SELECT (j->>'renumbered')::INT, (j->>'created')::INT, (j->>'deleted')::INT, (j->>'values_changed')::INT FROM al_out$$,
  $$VALUES (5, 1, 1, 3)$$,
  'ALIGN.25 the summary counts renumbered, created, deleted and changed fencers (A, B, H), measured against their rows before the move');

-- A second run with the same payload changes nothing and still checks out.
SELECT results_eq(
  $$SELECT (j->>'renumbered')::INT, (j->>'created')::INT, (j->>'deleted')::INT
      FROM (SELECT fn_align_fencers_to(
              (SELECT jsonb_agg(jsonb_build_object('cert_id', (x->>'id_fencer')::INT, 'prod_id', (x->>'id_fencer')::INT))
                 FROM jsonb_array_elements((SELECT j FROM al_roster)) x),
              (SELECT j FROM al_roster), '[]', NULL, false) AS j) s$$,
  $$VALUES (0, 0, 0)$$,
  'ALIGN.26 an aligned roster aligns to itself with nothing to do');

SELECT is((SELECT count(*)::INT FROM tbl_result r JOIN al_t ON r.id_tournament IN (al_t.epee, al_t.foil)), 7,
  'ALIGN.27 no result was lost or duplicated');

-- The restore: the inverse pairing with the saved roster. E (created) is deleted,
-- D (deleted, unreferenced) comes back from the saved roster.
SELECT fn_align_fencers_to(
  (SELECT jsonb_agg(jsonb_build_object('cert_id', prod_id, 'prod_id', cert_id)) FROM al_map),
  (SELECT j FROM al_orig), '[96005]', NULL, false);

SELECT ok(
  NOT EXISTS ((SELECT id_fencer, txt_surname, int_birth_year, bool_birth_year_estimated, json_name_aliases FROM tbl_fencer)
              EXCEPT
              (SELECT id_fencer, txt_surname, int_birth_year, bool_birth_year_estimated, json_name_aliases
                 FROM jsonb_populate_recordset(NULL::tbl_fencer, (SELECT j FROM al_orig))))
  AND NOT EXISTS ((SELECT f.txt_surname, r.int_place, r.id_tournament FROM tbl_result r JOIN tbl_fencer f USING (id_fencer)
                    WHERE f.id_fencer BETWEEN 96001 AND 96008)
                  EXCEPT SELECT * FROM al_orig_places),
  'ALIGN.28 the inverse pairing with the saved roster restores every id, value and result');

SELECT setval('tbl_fencer_id_fencer_seq', last_value, is_called) FROM al_seq;

SELECT * FROM finish();
ROLLBACK;
