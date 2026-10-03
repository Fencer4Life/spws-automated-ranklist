-- =============================================================================
-- SEED — fn_seed_load_fencers loads PROD's roster at PROD's ids (ADR-036 §1)
-- =============================================================================
-- On a fresh bootstrap every migration runs before the seed, and three data
-- migrations create fencers by hand under whatever ids the sequence gives them.
-- The seed then hands PROD's whole roster and id sequence to this function,
-- which:
--
--   * pairs every fencer already present with exactly one roster row, by
--     surname, first name and birth year (an unknown year matches an unknown
--     year), and refuses, naming them, a fencer the roster lacks or a fencer
--     two roster rows describe;
--   * applies the pairing through fn_align_fencers_to: the present fencers
--     move to PROD's ids and take PROD's values, every other roster row is
--     created at its PROD id, the sequence is set, and the roster must then
--     equal the one given.
--
-- The seeded roster stands in for PROD's here, each fencer at its own id.
-- Fixture fencers live at ids 97001–97005 and move to 97101–97105.
-- Everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(8);

CREATE TEMP TABLE sd_seq AS SELECT last_value, is_called FROM tbl_fencer_id_fencer_seq;

-- "Migration-created" fencers, at the ids a fresh bootstrap happened to give them.
INSERT INTO tbl_fencer (id_fencer, txt_surname, txt_first_name, int_birth_year,
                        bool_birth_year_estimated, enum_gender)
VALUES (97001, 'SEEDA',  'Adam',  1970, false, 'M'),
       (97002, 'SEEDB',  'Beata', NULL, false, 'F'),
       (97003, 'SEEDN',  'Jan',   1950, false, 'M'),
       (97004, 'SEEDN',  'Jan',   1980, false, 'M');

-- PROD's roster: every seeded fencer as it is, the fixtures at PROD's ids (the
-- namesakes swapped, B with a club PROD has), and E, who exists only on PROD.
CREATE TEMP TABLE sd_roster AS
SELECT to_jsonb(f) || jsonb_build_object('id_fencer',
         CASE f.id_fencer WHEN 97001 THEN 97101 WHEN 97002 THEN 97102
                          WHEN 97003 THEN 97104 WHEN 97004 THEN 97103 ELSE f.id_fencer END) AS j
  FROM tbl_fencer f;
UPDATE sd_roster SET j = j || '{"txt_club": "KS Seed"}' WHERE (j->>'id_fencer')::INT = 97102;
INSERT INTO sd_roster
SELECT jsonb_build_object('id_fencer', 97105, 'txt_surname', 'SEEDE', 'txt_first_name', 'Ewa',
                          'int_birth_year', 1965, 'txt_nationality', 'PL', 'bool_birth_year_estimated', false,
                          'enum_gender', 'F', 'json_name_aliases', '[]'::jsonb,
                          'json_revoked_aliases', '[]'::jsonb, 'json_user_confirmed_aliases', '[]'::jsonb,
                          'ts_created', now(), 'ts_updated', now());

CREATE TEMP VIEW sd_all AS SELECT jsonb_agg(j) AS j FROM sd_roster;

SELECT ok(NOT has_function_privilege('anon', 'fn_seed_load_fencers(jsonb,bigint)', 'EXECUTE')
          AND NOT has_function_privilege('authenticated', 'fn_seed_load_fencers(jsonb,bigint)', 'EXECUTE')
          AND has_function_privilege('service_role', 'fn_seed_load_fencers(jsonb,bigint)', 'EXECUTE'),
  'SEED.01 only the service role (and the seed, as owner) may load the roster');

-- Refusals first: each must leave the table exactly as it was.
SELECT throws_like(
  $$SELECT fn_seed_load_fencers((SELECT jsonb_agg(j) FROM sd_roster WHERE (j->>'id_fencer')::INT <> 97101), 400)$$,
  '%SEED_FENCER_NOT_IN_ROSTER%SEEDA Adam (1970)%',
  'SEED.02 a present fencer the roster lacks is refused, by name');

SELECT throws_like(
  $$SELECT fn_seed_load_fencers((SELECT j || jsonb_build_array(
             (SELECT j FROM sd_roster WHERE (j->>'id_fencer')::INT = 97101) || '{"id_fencer": 97106}')
           FROM sd_all), 400)$$,
  '%SEED_FENCER_AMBIGUOUS%SEEDA Adam (1970)%',
  'SEED.03 a present fencer two roster rows describe is refused, by name');

SELECT is((SELECT count(*)::INT FROM tbl_fencer WHERE id_fencer BETWEEN 97001 AND 97106), 4,
  'SEED.04 a refusal changes nothing');

-- The load.
CREATE TEMP TABLE sd_out AS SELECT fn_seed_load_fencers((SELECT j FROM sd_all), 97200) AS j;

SELECT results_eq(
  $$SELECT id_fencer, txt_surname, int_birth_year, txt_club FROM tbl_fencer
     WHERE id_fencer BETWEEN 97001 AND 97106 ORDER BY id_fencer$$,
  $$VALUES (97101, 'SEEDA'::TEXT, 1970::SMALLINT, NULL::TEXT),
           (97102, 'SEEDB', NULL::SMALLINT, 'KS Seed'),
           (97103, 'SEEDN', 1980::SMALLINT, NULL::TEXT),
           (97104, 'SEEDN', 1950::SMALLINT, NULL::TEXT),
           (97105, 'SEEDE', 1965::SMALLINT, NULL::TEXT)$$,
  'SEED.05 present fencers sit at PROD''s ids with PROD''s values (namesakes by birth year, an unknown year with an unknown year), and E is created');

SELECT is((SELECT count(*)::INT FROM tbl_fencer),
          (SELECT jsonb_array_length(j) FROM sd_all),
  'SEED.06 the roster holds exactly the rows given');

SELECT ok((SELECT last_value >= 97200 FROM tbl_fencer_id_fencer_seq),
  'SEED.07 the id sequence is set to PROD''s, so a new fencer never takes a PROD id');

SELECT is((SELECT (j->>'renumbered')::INT || '/' || (j->>'created')::INT FROM sd_out), '4/1',
  'SEED.08 the summary counts the four present fencers moved and the one created');

-- Put the sequence back: sequences do not roll back.
SELECT setval('tbl_fencer_id_fencer_seq', last_value, is_called) FROM sd_seq;

SELECT * FROM finish();
ROLLBACK;
