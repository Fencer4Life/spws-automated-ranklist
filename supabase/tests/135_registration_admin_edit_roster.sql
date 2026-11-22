-- =============================================================================
-- RFADM.16–22 — the administrator's edit of a linked entry reaches the roster
-- =============================================================================
-- FR-170, release 4, the user's addition of 22 Nov 2026 (pixel sheet
-- registration-admin-edit-release-4-pixel-sheet-2026-11-21.html §05, R1–R3 A).
-- The dialog saves through fn_update_registration_as_admin, which updates the
-- entry and, for a linked entry only (R1), copies to the roster what the
-- administrator changed in this save: the birth year, confirmed; the gender;
-- the country as the event season's ADMIN nationality (R2, R3). One
-- transaction: a refused save writes neither. A visitor cannot call it.
--
-- Everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(12);

INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, enum_status)
SELECT 'PPW8-2026-2027', 'RFADM roster fixture', (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027'),
       (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'), DATE '2099-03-01', DATE '2099-03-01', 'PLANNED';

-- A roster fencer with results (so a birth-year change has events to queue),
-- a known gender and a confirmed year inside the season's range. Its id, year
-- and txt_nationality, and the linked entry's id, are kept in transaction-local
-- settings, as 133 does.
SELECT set_config('rfadm.fencer', f.id_fencer::TEXT, TRUE),
       set_config('rfadm.year', f.int_birth_year::TEXT, TRUE),
       set_config('rfadm.nat', f.txt_nationality, TRUE)
  FROM tbl_fencer f
 WHERE f.enum_gender = 'F' AND f.int_birth_year BETWEEN 1950 AND 1990 AND NOT f.bool_birth_year_estimated
   AND EXISTS (SELECT 1 FROM tbl_result r WHERE r.id_fencer = f.id_fencer)
 ORDER BY f.id_fencer
 LIMIT 1;

-- The linked entry declares the roster's year; a newcomer stays unlinked.
INSERT INTO tbl_registration (id_event, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons,
                              txt_club, txt_country, id_fencer)
SELECT e.id_event, 'RFADMLINKED', 'Typed', 'F', current_setting('rfadm.year')::INT, ARRAY['EPEE']::enum_weapon_type[],
       NULL, 'POL', current_setting('rfadm.fencer')::INT
  FROM tbl_event e WHERE e.txt_code = 'PPW8-2026-2027';
SELECT set_config('rfadm.linked', id_registration::TEXT, TRUE)
  FROM tbl_registration WHERE id_fencer = current_setting('rfadm.fencer')::INT
   AND id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW8-2026-2027');
INSERT INTO tbl_registration (id_event, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons, txt_country)
SELECT e.id_event, 'RFADMNEWCOMER', 'Anna', 'F', 1970, ARRAY['EPEE']::enum_weapon_type[], 'POL'
  FROM tbl_event e WHERE e.txt_code = 'PPW8-2026-2027';

DELETE FROM tbl_recompute_queue
 WHERE id_event IN (SELECT t.id_event FROM tbl_result r JOIN tbl_tournament t USING (id_tournament)
                     WHERE r.id_fencer = current_setting('rfadm.fencer')::INT);

-- Calls the function as a signed-in administrator with the entry's current
-- values, overriding only what the step names.
CREATE FUNCTION pg_temp.rfadm_save(p_id INT, p_gender enum_gender_type, p_year INT, p_club TEXT, p_country TEXT,
                                   p_surname TEXT DEFAULT NULL, p_first TEXT DEFAULT NULL)
RETURNS VOID LANGUAGE plpgsql AS $fn$
BEGIN
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', '{"role":"authenticated","sub":"test-admin"}', TRUE);
  PERFORM fn_update_registration_as_admin(p_id, p_surname, p_first, p_gender, p_year,
                                          ARRAY['EPEE']::enum_weapon_type[], p_club, p_country);
  RESET ROLE;
END;
$fn$;

-- pgt-ignore-start typecheck: pg_temp helpers this file creates (the checker sees only the live schema)
-- ---------------------------------------------------------------------------
-- RFADM.16 — a changed year of a linked entry reaches the roster, confirmed,
-- and queues the fencer's events for recompute.
-- ---------------------------------------------------------------------------
SELECT pg_temp.rfadm_save(current_setting('rfadm.linked')::INT, 'F',
                          (current_setting('rfadm.year')::INT + 1), NULL, 'POL');
SELECT results_eq(
  $$SELECT int_birth_year::INT, bool_birth_year_estimated FROM tbl_fencer WHERE id_fencer = current_setting('rfadm.fencer')::INT$$,
  $$SELECT current_setting('rfadm.year')::INT + 1, FALSE$$,
  'RFADM.16 a changed year of a linked entry reaches the roster, confirmed');
SELECT is((SELECT int_birth_year::INT FROM tbl_registration WHERE id_registration = current_setting('rfadm.linked')::INT), (current_setting('rfadm.year')::INT + 1),
  'RFADM.16 the entry holds the new year');
SELECT is(
  (SELECT count(*)::INT FROM tbl_recompute_queue q
    WHERE q.enum_status = 'PENDING'
      AND q.id_event IN (SELECT t.id_event FROM tbl_result r JOIN tbl_tournament t USING (id_tournament)
                          WHERE r.id_fencer = current_setting('rfadm.fencer')::INT)),
  (SELECT count(DISTINCT t.id_event)::INT FROM tbl_result r JOIN tbl_tournament t USING (id_tournament)
    WHERE r.id_fencer = current_setting('rfadm.fencer')::INT),
  'RFADM.16 every event of the fencer is queued for recompute');

-- ---------------------------------------------------------------------------
-- RFADM.17 — a field the save did not change is not copied.
-- ---------------------------------------------------------------------------
UPDATE tbl_fencer SET int_birth_year = current_setting('rfadm.year')::INT WHERE id_fencer = current_setting('rfadm.fencer')::INT;
SELECT pg_temp.rfadm_save(current_setting('rfadm.linked')::INT, 'F',
                          (current_setting('rfadm.year')::INT + 1), 'AZS', 'POL');
SELECT is((SELECT int_birth_year::INT FROM tbl_fencer WHERE id_fencer = current_setting('rfadm.fencer')::INT),
  current_setting('rfadm.year')::INT,
  'RFADM.17 saving a club leaves the roster''s year as it is, though the declared year differs');
SELECT ok((SELECT txt_club IS DISTINCT FROM 'AZS' FROM tbl_fencer WHERE id_fencer = current_setting('rfadm.fencer')::INT),
  'RFADM.17 the club stays the entry''s own (R2)');

-- ---------------------------------------------------------------------------
-- RFADM.18 — a newcomer's edit writes no roster row and links nothing (R1).
-- ---------------------------------------------------------------------------
SELECT pg_temp.rfadm_save((SELECT id_registration FROM tbl_registration WHERE txt_surname = 'RFADMNEWCOMER'), 'F',
                          1969, NULL, 'GER', 'RFADMNEWCOMER', 'Anna');
SELECT results_eq(
  $$SELECT int_birth_year::INT, txt_country, id_fencer IS NULL FROM tbl_registration WHERE txt_surname = 'RFADMNEWCOMER'$$,
  $$VALUES (1969, 'GER'::TEXT, TRUE)$$,
  'RFADM.18 a newcomer''s edit changes the entry only, and it stays unlinked');

-- ---------------------------------------------------------------------------
-- RFADM.19 — a changed gender reaches the roster.
-- ---------------------------------------------------------------------------
SELECT pg_temp.rfadm_save(current_setting('rfadm.linked')::INT, 'M',
                          (current_setting('rfadm.year')::INT + 1), 'AZS', 'POL');
SELECT is((SELECT enum_gender::TEXT FROM tbl_fencer WHERE id_fencer = current_setting('rfadm.fencer')::INT), 'M',
  'RFADM.19 a changed gender of a linked entry reaches the roster');

-- ---------------------------------------------------------------------------
-- RFADM.20 — a changed country lands in the season's ADMIN nationality (R3),
-- not in tbl_fencer.txt_nationality.
-- ---------------------------------------------------------------------------
SELECT pg_temp.rfadm_save(current_setting('rfadm.linked')::INT, 'M',
                          (current_setting('rfadm.year')::INT + 1), 'AZS', 'UKR');
SELECT results_eq(
  $$SELECT n.txt_country, n.enum_source::TEXT FROM tbl_fencer_nationality n
     WHERE n.id_fencer = current_setting('rfadm.fencer')::INT
       AND n.id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')$$,
  $$VALUES ('UKR'::TEXT, 'ADMIN'::TEXT)$$,
  'RFADM.20 a changed country lands in the event season''s ADMIN nationality');
SELECT is((SELECT txt_nationality FROM tbl_fencer WHERE id_fencer = current_setting('rfadm.fencer')::INT),
  current_setting('rfadm.nat'),
  'RFADM.20 tbl_fencer.txt_nationality is not written');

-- ---------------------------------------------------------------------------
-- RFADM.21 — a refused save writes neither the entry nor the roster.
-- ---------------------------------------------------------------------------
SELECT throws_ok(
  format($$SELECT pg_temp.rfadm_save(%s, 'M', %s, 'AZS', 'XYZ')$$,
         current_setting('rfadm.linked')::INT, (current_setting('rfadm.year')::INT + 3)),
  '23503', NULL,
  'RFADM.21 a country that is not a fencing country refuses the whole save');
RESET ROLE;
SELECT results_eq(
  $$SELECT (SELECT int_birth_year::INT FROM tbl_registration WHERE id_registration = current_setting('rfadm.linked')::INT), (SELECT int_birth_year::INT FROM tbl_fencer WHERE id_fencer = current_setting('rfadm.fencer')::INT)$$,
  $$SELECT current_setting('rfadm.year')::INT + 1, current_setting('rfadm.year')::INT$$,
  'RFADM.21 neither the entry''s nor the roster''s year moved');

-- ---------------------------------------------------------------------------
-- RFADM.22 — a visitor cannot call it.
-- ---------------------------------------------------------------------------
SELECT throws_ok(
  format($$SET LOCAL ROLE anon;
           SELECT set_config('request.jwt.claims', '{"role":"anon"}', TRUE);
           SELECT fn_update_registration_as_admin(%s, NULL, NULL, 'F', 1970, ARRAY['EPEE']::enum_weapon_type[], NULL, 'POL')$$,
         current_setting('rfadm.linked')::INT),
  '42501', NULL,
  'RFADM.22 a visitor cannot call the function');
RESET ROLE;

-- pgt-ignore-end typecheck

SELECT * FROM finish();
ROLLBACK;
