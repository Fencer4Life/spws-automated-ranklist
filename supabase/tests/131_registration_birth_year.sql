-- =============================================================================
-- RFYEAR — a registration's birth year lies inside its season's range (FR-168)
-- =============================================================================
-- The database half of FR-168 (plan registration-form-names-year-country rev
-- 10, release 2). The youngest year is the event's season's later year minus
-- 30 (the V0 rule); the oldest is this year minus 120. The form offers only
-- those years; the table refuses any other on every write path, so an old
-- cached page, an administrator's direct update or the PROD → CERT copy
-- cannot store „47” or „-1972” again. Edges mirror
-- frontend/tests/birthYearRange.test.ts.
--
-- Everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(15);

-- 2026/27 ends in 2027: the youngest year is 1997.
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, enum_status)
SELECT c, 'RFYEAR fixture', (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027'),
       (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'), DATE '2099-03-01', DATE '2099-03-01', 'PLANNED'
  FROM (VALUES ('PPW8-2026-2027'), ('PPW9-2026-2027')) v(c);

-- The oldest year is this year minus 120, computed where it is used: the
-- checker sees only the live schema, so no temp table carries it.

-- ---------------------------------------------------------------------------
-- RFYEAR.07 — the visitor's create path.
-- ---------------------------------------------------------------------------
SELECT throws_like(
  $$SELECT fn_create_registration((SELECT id_event FROM tbl_event WHERE txt_code = 'PPW8-2026-2027'), 'RFYEARA', 'Anna', 'F', 1998::SMALLINT, ARRAY['EPEE']::enum_weapon_type[])$$,
  '%REG_BIRTH_YEAR_OUT_OF_RANGE%',
  'RFYEAR.07 create refuses a year younger than V0 (1998 for 2026/27)');

SELECT throws_like(
  format($$SELECT fn_create_registration(%s, 'RFYEARB', 'Anna', 'F', %s::SMALLINT, ARRAY['EPEE']::enum_weapon_type[])$$,
         (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW8-2026-2027'), extract(year FROM now())::INT - 120 - 1),
  '%REG_BIRTH_YEAR_OUT_OF_RANGE%',
  'RFYEAR.07 create refuses a year more than 120 years ago');

SELECT throws_like(
  $$SELECT fn_create_registration((SELECT id_event FROM tbl_event WHERE txt_code = 'PPW8-2026-2027'), 'RFYEARC', 'Anna', 'F', 47::SMALLINT, ARRAY['EPEE']::enum_weapon_type[])$$,
  format('%%%s%%%s%%', extract(year FROM now())::INT - 120, 1997),
  'RFYEAR.07 the refusal names the range the form shows');

SELECT lives_ok(
  format($$SELECT fn_create_registration(%s, 'RFYEARYOUNG', 'Anna', 'F', 1997::SMALLINT, ARRAY['EPEE']::enum_weapon_type[],
                                         NULL, NULL, NULL, '11111111-1111-4111-8111-111111111131'::UUID);
           SELECT fn_create_registration(%s, 'RFYEAROLD', 'Olga', 'F', %s::SMALLINT, ARRAY['FOIL']::enum_weapon_type[])$$,
         (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW8-2026-2027'), (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW8-2026-2027'), extract(year FROM now())::INT - 120),
  'RFYEAR.07 both edges are accepted: 1997 and this year minus 120');

-- ---------------------------------------------------------------------------
-- RFYEAR.08 — the visitor's edit path.
-- ---------------------------------------------------------------------------
SELECT throws_like(
  $$SELECT fn_update_registration((SELECT id_registration FROM tbl_registration WHERE txt_surname = 'RFYEARYOUNG'),
                                  '11111111-1111-4111-8111-111111111131'::UUID, 'RFYEARYOUNG', 'Anna', 'F',
                                  1998::SMALLINT, ARRAY['EPEE']::enum_weapon_type[])$$,
  '%REG_BIRTH_YEAR_OUT_OF_RANGE%',
  'RFYEAR.08 edit refuses a year younger than V0');

SELECT throws_like(
  $$SELECT fn_update_registration((SELECT id_registration FROM tbl_registration WHERE txt_surname = 'RFYEARYOUNG'),
                                  '11111111-1111-4111-8111-111111111131'::UUID, 'RFYEARYOUNG', 'Anna', 'F',
                                  (-1972)::SMALLINT, ARRAY['EPEE']::enum_weapon_type[])$$,
  '%REG_BIRTH_YEAR_OUT_OF_RANGE%',
  'RFYEAR.08 edit refuses a negative year');

-- ---------------------------------------------------------------------------
-- RFYEAR.09 — an administrator's direct update.
-- ---------------------------------------------------------------------------
SELECT throws_like(
  $$UPDATE tbl_registration SET int_birth_year = 1998 WHERE txt_surname = 'RFYEARYOUNG'$$,
  '%REG_BIRTH_YEAR_OUT_OF_RANGE%',
  'RFYEAR.09 a direct update of the year outside the range is refused');

SELECT lives_ok(
  $$UPDATE tbl_registration SET arr_weapons = ARRAY['EPEE', 'SABRE']::enum_weapon_type[] WHERE txt_surname = 'RFYEARYOUNG'$$,
  'RFYEAR.09 an update that leaves the year alone is unaffected');

-- ---------------------------------------------------------------------------
-- RFYEAR.10 — the PROD → CERT copy.
-- ---------------------------------------------------------------------------
INSERT INTO tbl_registration (id_event, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons)
SELECT id_event, 'RFYEARTARGET', 'Test', 'M', 1970, ARRAY['EPEE']::enum_weapon_type[]
  FROM tbl_event WHERE txt_code = 'PPW9-2026-2027';

SELECT throws_like(
  $$SELECT fn_replace_event_registrations('PPW9-2026-2027', '[
      {"txt_surname": "RFYEARCOPY", "txt_first_name": "Ewa", "enum_gender": "F", "int_birth_year": 1975,
       "arr_weapons": ["EPEE"], "id_fencer": null},
      {"txt_surname": "RFYEARBAD", "txt_first_name": "Ola", "enum_gender": "F", "int_birth_year": 47,
       "arr_weapons": ["FOIL"], "id_fencer": null}]'::JSONB)$$,
  '%REG_BIRTH_YEAR_OUT_OF_RANGE%',
  'RFYEAR.10 the copy refuses a row outside the range');

SELECT results_eq(
  $$SELECT txt_surname FROM tbl_registration r JOIN tbl_event e USING (id_event) WHERE e.txt_code = 'PPW9-2026-2027'$$,
  $$VALUES ('RFYEARTARGET'::TEXT)$$,
  'RFYEAR.10 after the refusal the target''s entries are untouched');

-- ---------------------------------------------------------------------------
-- RFYEAR.07 — the range moves with the season and with today. Five years on:
-- a 2031/32 event, written on 21 Nov 2031, accepts 1911 to 2002.
-- ---------------------------------------------------------------------------
SELECT results_eq(
  $$SELECT int_oldest, int_youngest FROM fn_registration_birth_year_bounds(2027, DATE '2026-11-21')$$,
  $$VALUES (1906, 1997)$$,
  'RFYEAR.07 2026/27 on 21 Nov 2026: 1906 to 1997');

SELECT results_eq(
  $$SELECT int_oldest, int_youngest FROM fn_registration_birth_year_bounds(2032, DATE '2031-11-21')$$,
  $$VALUES (1911, 2002)$$,
  'RFYEAR.07 five years on, 2031/32 on 21 Nov 2031: 1911 to 2002');

SELECT results_eq(
  $$SELECT int_oldest, int_youngest FROM fn_registration_birth_year_bounds(2032, current_date)$$,
  $$VALUES (extract(year FROM current_date)::INT - 120, 2002)$$,
  'RFYEAR.07 the table rule reads today''s date, not a fixed year');

SELECT fn_create_season('RFYEAR2032', DATE '2031-09-01', DATE '2032-06-30');
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, enum_status)
SELECT 'PPW8-2031-2032', 'RFYEAR fixture five years on', (SELECT id_season FROM tbl_season WHERE txt_code = 'RFYEAR2032'),
       (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'), DATE '2099-03-01', DATE '2099-03-01', 'PLANNED';

SELECT lives_ok(
  $$SELECT fn_create_registration((SELECT id_event FROM tbl_event WHERE txt_code = 'PPW8-2031-2032'),
                                  'RFYEARFUTURE', 'Ada', 'F', 2002::SMALLINT, ARRAY['EPEE']::enum_weapon_type[])$$,
  'RFYEAR.07 a 2031/32 event accepts 2002, its V0 edge');

SELECT throws_like(
  $$SELECT fn_create_registration((SELECT id_event FROM tbl_event WHERE txt_code = 'PPW8-2031-2032'),
                                  'RFYEARFUTURE2', 'Ada', 'F', 2003::SMALLINT, ARRAY['EPEE']::enum_weapon_type[])$$,
  '%REG_BIRTH_YEAR_OUT_OF_RANGE%2003%2002%',
  'RFYEAR.07 and refuses 2003');

SELECT * FROM finish();
ROLLBACK;
