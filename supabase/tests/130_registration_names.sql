-- =============================================================================
-- RFNAME — a fencer's name in one form, titles apart, reversed fields (FR-167)
-- =============================================================================
-- The database half of FR-167 (plan registration-form-names-year-country rev
-- 10, release 1). The form writes the name form before it submits; the table's
-- trigger writes the same form for a newcomer whatever wrote the row, so an old
-- cached page or a direct write cannot store „JOHN” or „DR VERESS”. The
-- cases mirror frontend/tests/registrationName.test.ts.
--
-- Everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(26);

INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, enum_status)
SELECT 'PPW8-2025-2026', 'RFNAME fixture', (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
       (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'), DATE '2099-03-01', DATE '2099-03-01', 'PLANNED';

INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, enum_gender)
VALUES ('RFNAMEFENCER', 'Wojmir', 1970, 'M');

INSERT INTO tbl_common_given_name (txt_name, txt_source) VALUES ('Zdislava', 'EVF');

-- ---------------------------------------------------------------------------
-- RFNAME.17 — given names only, keyed by the folded name, unique.
-- ---------------------------------------------------------------------------
SELECT columns_are('tbl_common_given_name',
  ARRAY['txt_name', 'txt_name_key', 'txt_source', 'ts_created'],
  'RFNAME.17 tbl_common_given_name holds a name, its key, its source and when it was added — nothing else');

SELECT is((SELECT txt_name_key FROM tbl_common_given_name WHERE txt_name = 'Zdislava'), 'ZDISLAVA',
  'RFNAME.17 the key is the folded name');

SELECT throws_ok(
  $$INSERT INTO tbl_common_given_name (txt_name, txt_source) VALUES ('ZDISLAVA', 'EVF')$$,
  '23505', NULL,
  'RFNAME.17 a name already held under another spelling of case is refused');

-- ---------------------------------------------------------------------------
-- RFNAME.18 — known = the table's names + the fencer table's, folded.
-- ---------------------------------------------------------------------------
SELECT is((SELECT bool_given_name_known FROM fn_registration_name_check('X', 'zdisláva')), TRUE,
  'RFNAME.18 a listed name is known without regard to capitals or accents');

SELECT is((SELECT bool_given_name_known FROM fn_registration_name_check('X', 'wojmir')), TRUE,
  'RFNAME.18 a given name of the fencer table is known');

SELECT is((SELECT bool_given_name_known FROM fn_registration_name_check('X', 'Zdislava Wojmir')), TRUE,
  'RFNAME.18 a double name is known when each part is');

SELECT is((SELECT bool_given_name_known FROM fn_registration_name_check('X', 'Zdislava-Qwertz')), FALSE,
  'RFNAME.18 a double name with an unknown part is not known');

SELECT is((SELECT bool_surname_is_given_name FROM fn_registration_name_check('ZDISLAVA', 'Qwertz')), TRUE,
  'RFNAME.18 a surname box holding a known given name is reported');

-- ---------------------------------------------------------------------------
-- RFNAME.19 — two yes/no answers, callable by a visitor; the list is not.
-- ---------------------------------------------------------------------------
SELECT results_eq(
  $$SELECT * FROM fn_registration_name_check('Dr. ZDISLAVA', 'Qwertz')$$,
  $$VALUES (TRUE, FALSE)$$,
  'RFNAME.19 the check returns exactly its two answers, a title ignored');

SELECT ok(has_function_privilege('anon', 'fn_registration_name_check(text, text)', 'EXECUTE'),
  'RFNAME.19 a visitor may call the check');

SELECT ok(NOT has_table_privilege('anon', 'tbl_common_given_name', 'SELECT'),
  'RFNAME.19 a visitor cannot read the names table');

SELECT ok(NOT has_table_privilege('authenticated', 'tbl_common_given_name', 'INSERT'),
  'RFNAME.19 a signed-in user cannot write the names table');

-- ---------------------------------------------------------------------------
-- RFNAME.20 — a newcomer's row is stored in the name form, title in front.
-- ---------------------------------------------------------------------------
INSERT INTO tbl_registration (id_event, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons)
SELECT e.id_event, v.s, v.f, 'F', 1979, ARRAY['EPEE']::enum_weapon_type[]
  FROM tbl_event e,
       (VALUES ('dr kovács', '  péter  '),
               ('ORSOLYA', 'szabó dr.'),
               ('DR VERESS', 'ILONA   KATALIN'),
               ('o''neil', 'mary-ann'),
               ('DRAGAN', 'ingrid'),
               ('KOWALSKA', 'aNNA')) v(s, f)
 WHERE e.txt_code = 'PPW8-2025-2026';

SELECT results_eq(
  $$SELECT txt_surname, txt_first_name FROM tbl_registration
     WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW8-2025-2026')
     ORDER BY id_registration$$,
  $$VALUES ('Dr. KOVÁCS'::TEXT, 'Péter'::TEXT),
           ('Dr. ORSOLYA', 'Szabó'),
           ('Dr. VERESS', 'Ilona Katalin'),
           ('O''NEIL', 'Mary-Ann'),
           ('DRAGAN', 'Ingrid'),
           ('KOWALSKA', 'Anna')$$,
  'RFNAME.20 an insert stores the name form: capitals, title case, title in front, spaces collapsed');

UPDATE tbl_registration SET txt_first_name = 'jOLANTA', txt_surname = 'kowalska prof'
 WHERE txt_surname = 'KOWALSKA'
   AND id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW8-2025-2026');

SELECT results_eq(
  $$SELECT txt_surname, txt_first_name FROM tbl_registration
     WHERE txt_surname LIKE '%KOWALSKA'
       AND id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW8-2025-2026')$$,
  $$VALUES ('Prof. KOWALSKA'::TEXT, 'Jolanta'::TEXT)$$,
  'RFNAME.20 an update stores the name form too');

SELECT results_eq(
  $$SELECT * FROM fn_registration_canonical_names('prof dr  kovács', 'PÉTER')$$,
  $$VALUES ('Prof. Dr. KOVÁCS'::TEXT, 'Péter'::TEXT)$$,
  'RFNAME.20 combined titles keep their order');

SELECT results_eq(
  $$SELECT * FROM fn_registration_canonical_names('dipl-ing maier', 'hans') UNION ALL
    SELECT * FROM fn_registration_canonical_names('ddr huber', 'eva') UNION ALL
    SELECT * FROM fn_registration_canonical_names('DR', 'Ing') UNION ALL
    SELECT * FROM fn_registration_canonical_names('MAGDA', 'doctor')$$,
  $$VALUES ('Dipl.-Ing. MAIER'::TEXT, 'Hans'::TEXT),
           ('DDr. HUBER', 'Eva'),
           ('DR', 'Ing'),
           ('MAGDA', 'Doctor')$$,
  'RFNAME.20 each title has one form; a lone word or a look-alike is a name');

-- ---------------------------------------------------------------------------
-- RFNAME.21 — a linked row keeps the roster's name.
-- ---------------------------------------------------------------------------
INSERT INTO tbl_registration (id_event, id_fencer, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons)
SELECT e.id_event, f.id_fencer, 'dr rfnamefencer', 'WOJMIR', 'M', 1970, ARRAY['SABRE']::enum_weapon_type[]
  FROM tbl_event e, tbl_fencer f
 WHERE e.txt_code = 'PPW8-2025-2026' AND f.txt_surname = 'RFNAMEFENCER';

SELECT results_eq(
  $$SELECT txt_surname, txt_first_name FROM tbl_registration WHERE id_fencer =
      (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'RFNAMEFENCER')$$,
  $$VALUES ('RFNAMEFENCER'::TEXT, 'Wojmir'::TEXT)$$,
  'RFNAME.21 a linked entry carries the roster''s name, not the typed one');

-- ---------------------------------------------------------------------------
-- RFNAME.22 — the exact match and the near-miss lookup ignore a title.
-- ---------------------------------------------------------------------------
SELECT is(fn_match_registration_fencer('Dr. RFNAMEFENCER', 'Wojmir', 1970::SMALLINT),
  (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'RFNAMEFENCER'),
  'RFNAME.22 the exact match finds the fencer behind a title');

SELECT is(
  (SELECT enum_kind FROM fn_registration_identity_candidates('Prof. Dr. RFNAMEFENCER', 'Wojmir', 1970::SMALLINT)),
  'EXACT',
  'RFNAME.22 the near-miss lookup finds the fencer behind a title');

SELECT is(fn_name_without_title('Dr. VERESS'), 'VERESS',
  'RFNAME.22 the surname without its title');

SELECT is(fn_name_without_title('DRAGAN'), 'DRAGAN',
  'RFNAME.22 a look-alike is not a title');

SELECT ok(has_function_privilege('anon', 'fn_name_without_title(text)', 'EXECUTE'),
  'RFNAME.22 a visitor may call the title rule the lookups use');

-- ---------------------------------------------------------------------------
-- RFNAME.23 — the migration's realignment: rows written before the trigger
-- knew the name form are rewritten, linked rows keep the roster's names.
-- The rows are written with triggers off, as the old trigger left them.
-- ---------------------------------------------------------------------------
SET LOCAL session_replication_role = replica;
INSERT INTO tbl_registration (id_event, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons)
SELECT e.id_event, 'DR OLDROW', 'ESZTER', 'F', 1979, ARRAY['FOIL']::enum_weapon_type[]
  FROM tbl_event e WHERE e.txt_code = 'PPW8-2025-2026';
UPDATE tbl_registration SET txt_first_name = 'wojmir typed'
 WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'RFNAMEFENCER');
SET LOCAL session_replication_role = origin;

SELECT fn_registration_realign_names();

SELECT is((SELECT txt_surname || ' ' || txt_first_name FROM tbl_registration WHERE txt_surname LIKE '%OLDROW'),
  'Dr. OLDROW Eszter',
  'RFNAME.23 an old newcomer row is rewritten into the name form');

SELECT is(
  (SELECT txt_first_name FROM tbl_registration WHERE id_fencer =
     (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'RFNAMEFENCER')),
  'Wojmir',
  'RFNAME.23 a linked row carries the roster''s name again');

SELECT is(
  (SELECT count(*)::INT FROM tbl_registration r,
          LATERAL fn_registration_canonical_names(r.txt_surname, r.txt_first_name) c
    WHERE r.id_fencer IS NULL
      AND (c.txt_surname, c.txt_first_name) IS DISTINCT FROM (r.txt_surname, r.txt_first_name)),
  0,
  'RFNAME.23 no newcomer row stands outside the name form');

SELECT is(
  (SELECT count(*)::INT FROM tbl_registration r JOIN tbl_fencer f USING (id_fencer)
    WHERE (r.txt_surname, r.txt_first_name) IS DISTINCT FROM (f.txt_surname, f.txt_first_name)),
  0,
  'RFNAME.23 no linked row differs from the roster''s name');

SELECT * FROM finish();
ROLLBACK;
