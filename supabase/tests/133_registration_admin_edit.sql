-- =============================================================================
-- RFADM — a signed-in administrator edits an entry (FR-170)
-- =============================================================================
-- The database half of FR-170 (plan registration-form-names-year-country rev
-- 10, release 4). A signed-in administrator may read and update a registration
-- under the table's one policy ("Admin all registrations", 20260704000001), the
-- rule that already lets „Usuń” delete (REGDEL.01). The dialog saves through
-- fn_update_registration_as_admin (20261122000003, tests in 135), which also
-- writes a linked entry's changes to the roster; these assertions pin the
-- table-level rules that function relies on: the administrator can read and
-- update the declared fields, a visitor can do neither, the update leaves the
-- link, the consent record and the edit token alone, and the rules of releases
-- 1–3 (name form, roster name, year range, country code) hold for it.
--
-- Each administrator step runs in a DO block under the `authenticated` role and
-- hands its result out through a transaction-local setting, as REGDEL.01 does.
--
-- Everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(13);

INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, enum_status)
SELECT 'PPW8-2026-2027', 'RFADM fixture', (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027'),
       (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'), DATE '2099-03-01', DATE '2099-03-01', 'PLANNED';

-- Two newcomers and one entry linked to a roster fencer, each with a consent
-- record and an edit token the edit must leave alone.
INSERT INTO tbl_registration (id_event, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons,
                              txt_club, txt_country, txt_consent_version, ts_consent, uuid_edit_token, id_fencer)
SELECT e.id_event, v.s, v.f, 'F', v.y, ARRAY['EPEE']::enum_weapon_type[], 'KS Test', 'POL', 'v1.2',
       TIMESTAMPTZ '2026-11-01 10:00:00+00', v.tok::UUID, v.fencer
  FROM tbl_event e,
       (VALUES ('RFADMNEW', 'Anna', 1970, '13300000-0000-4000-8000-0000000000a1', NULL::INT),
               ('RFADMTWO', 'Ewa', 1972, '13300000-0000-4000-8000-0000000000a2', NULL::INT),
               ('RFADMLINKED', 'Typed', 1970, '13300000-0000-4000-8000-0000000000a3',
                (SELECT id_fencer FROM tbl_fencer WHERE enum_gender = 'F' AND int_birth_year BETWEEN 1950 AND 1990
                  ORDER BY id_fencer LIMIT 1))) v(s, f, y, tok, fencer)
 WHERE e.txt_code = 'PPW8-2026-2027';

-- ---------------------------------------------------------------------------
-- RFADM.09 — the administrator reads and updates; a visitor does neither.
-- ---------------------------------------------------------------------------
DO $body$
DECLARE
  v_seen TEXT;
BEGIN
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', '{"role":"authenticated","sub":"test-admin"}', TRUE);
  SELECT concat_ws('|', int_birth_year, txt_club, txt_country, (id_fencer IS NULL)::TEXT) INTO v_seen
    FROM tbl_registration WHERE txt_surname = 'RFADMNEW';
  RESET ROLE;
  PERFORM set_config('rfadm.seen', coalesce(v_seen, 'nothing'), TRUE);
END;
$body$;
SELECT is(current_setting('rfadm.seen'), '1970|KS Test|POL|true',
  'RFADM.09 a signed-in administrator reads the declared year, club, country and link');

DO $body$
DECLARE
  v_rows INT;
BEGIN
  SET LOCAL ROLE anon;
  PERFORM set_config('request.jwt.claims', '{"role":"anon"}', TRUE);
  SELECT count(*) INTO v_rows FROM tbl_registration WHERE txt_surname LIKE 'RFADM%';
  RESET ROLE;
  PERFORM set_config('rfadm.anon_rows', v_rows::TEXT, TRUE);
END;
$body$;
SELECT is(current_setting('rfadm.anon_rows')::INT, 0, 'RFADM.09 a visitor reads no entry from the table');

SELECT throws_ok(
  $$SET LOCAL ROLE anon;
    SELECT set_config('request.jwt.claims', '{"role":"anon"}', TRUE);
    UPDATE tbl_registration SET txt_club = 'X' WHERE txt_surname = 'RFADMNEW'$$,
  '42501', NULL,
  'RFADM.09 a visitor''s update is refused');
RESET ROLE;

DO $body$
DECLARE
  v_rows INT;
BEGIN
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', '{"role":"authenticated","sub":"test-admin"}', TRUE);
  UPDATE tbl_registration
     SET enum_gender = 'F', int_birth_year = 1968, arr_weapons = ARRAY['EPEE', 'FOIL']::enum_weapon_type[],
         txt_club = 'AZS', txt_country = 'GER'
   WHERE txt_surname = 'RFADMNEW';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  UPDATE tbl_registration SET int_birth_year = 1966, txt_country = 'UKR'
   WHERE id_fencer IS NOT NULL AND id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW8-2026-2027');
  RESET ROLE;
  PERFORM set_config('rfadm.updated', v_rows::TEXT, TRUE);
END;
$body$;
SELECT is(current_setting('rfadm.updated')::INT, 1, 'RFADM.09 the administrator''s update changes the one row');
SELECT is(
  (SELECT concat_ws('|', int_birth_year, array_to_string(arr_weapons, ','), txt_club, txt_country)
     FROM tbl_registration WHERE txt_surname = 'RFADMNEW'),
  '1968|EPEE,FOIL|AZS|GER',
  'RFADM.09 the declared fields hold the administrator''s values');

-- ---------------------------------------------------------------------------
-- RFADM.10 — the link, the consent record and the edit token stay.
-- ---------------------------------------------------------------------------
SELECT results_eq(
  $$SELECT txt_consent_version, ts_consent, uuid_edit_token::TEXT, id_fencer IS NULL
      FROM tbl_registration WHERE txt_surname = 'RFADMNEW'$$,
  $$VALUES ('v1.2'::TEXT, TIMESTAMPTZ '2026-11-01 10:00:00+00', '13300000-0000-4000-8000-0000000000a1'::TEXT, TRUE)$$,
  'RFADM.10 a newcomer''s consent record and edit token are unchanged, and it stays unlinked');
SELECT results_eq(
  $$SELECT r.int_birth_year::INT, r.txt_country, r.txt_consent_version, r.uuid_edit_token::TEXT, r.id_fencer IS NOT NULL
      FROM tbl_registration r JOIN tbl_event e USING (id_event)
     WHERE e.txt_code = 'PPW8-2026-2027' AND r.id_fencer IS NOT NULL$$,
  $$VALUES (1966, 'UKR'::TEXT, 'v1.2'::TEXT, '13300000-0000-4000-8000-0000000000a3'::TEXT, TRUE)$$,
  'RFADM.10 a linked entry''s update keeps its link, consent and token');

-- ---------------------------------------------------------------------------
-- RFADM.11 — the rules of releases 1–3 hold for the administrator.
-- ---------------------------------------------------------------------------
DO $body$
BEGIN
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', '{"role":"authenticated","sub":"test-admin"}', TRUE);
  UPDATE tbl_registration SET txt_surname = '  rfadmnowak ', txt_first_name = 'anna-maria' WHERE txt_surname = 'RFADMNEW';
  UPDATE tbl_registration SET txt_surname = 'SOMEONEELSE', txt_first_name = 'Other'
   WHERE id_fencer IS NOT NULL AND id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW8-2026-2027');
  RESET ROLE;
END;
$body$;
SELECT is((SELECT txt_surname || ' ' || txt_first_name FROM tbl_registration WHERE txt_surname = 'RFADMNOWAK'),
  'RFADMNOWAK Anna-Maria',
  'RFADM.11 a newcomer''s name renamed by the administrator takes the name form');
SELECT is(
  (SELECT r.txt_surname || ' ' || r.txt_first_name FROM tbl_registration r JOIN tbl_event e USING (id_event)
    WHERE e.txt_code = 'PPW8-2026-2027' AND r.id_fencer IS NOT NULL),
  (SELECT f.txt_surname || ' ' || f.txt_first_name FROM tbl_fencer f
    WHERE f.id_fencer = (SELECT r.id_fencer FROM tbl_registration r JOIN tbl_event e USING (id_event)
                          WHERE e.txt_code = 'PPW8-2026-2027' AND r.id_fencer IS NOT NULL)),
  'RFADM.11 a linked entry keeps the roster''s name whatever the administrator sends');

SELECT throws_ok(
  $$SET LOCAL ROLE authenticated;
    SELECT set_config('request.jwt.claims', '{"role":"authenticated","sub":"test-admin"}', TRUE);
    UPDATE tbl_registration SET int_birth_year = 1999 WHERE txt_surname = 'RFADMTWO'$$,
  '23514', NULL,
  'RFADM.11 a year outside the season''s range is refused for the administrator too');
RESET ROLE;

SELECT throws_ok(
  $$SET LOCAL ROLE authenticated;
    SELECT set_config('request.jwt.claims', '{"role":"authenticated","sub":"test-admin"}', TRUE);
    UPDATE tbl_registration SET txt_country = 'XYZ' WHERE txt_surname = 'RFADMTWO'$$,
  '23503', NULL,
  'RFADM.11 a code that is not a fencing country is refused');
RESET ROLE;

-- ---------------------------------------------------------------------------
-- RFADM.12 — a rename into another newcomer's identity is refused.
-- ---------------------------------------------------------------------------
SELECT throws_ok(
  $$SET LOCAL ROLE authenticated;
    SELECT set_config('request.jwt.claims', '{"role":"authenticated","sub":"test-admin"}', TRUE);
    UPDATE tbl_registration SET txt_surname = 'RFADMNOWAK', txt_first_name = 'Anna-Maria', int_birth_year = 1968
     WHERE txt_surname = 'RFADMTWO'$$,
  '23505', NULL,
  'RFADM.12 renaming a newcomer into another newcomer''s identity is refused');
RESET ROLE;

SELECT results_eq(
  $$SELECT txt_surname, txt_first_name, int_birth_year::INT FROM tbl_registration
     WHERE txt_surname IN ('RFADMNOWAK', 'RFADMTWO') ORDER BY txt_surname$$,
  $$VALUES ('RFADMNOWAK'::TEXT, 'Anna-Maria'::TEXT, 1968), ('RFADMTWO'::TEXT, 'Ewa'::TEXT, 1972)$$,
  'RFADM.12 both entries stay as they were');

SELECT * FROM finish();
ROLLBACK;
