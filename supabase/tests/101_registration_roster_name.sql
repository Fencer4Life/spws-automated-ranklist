-- =============================================================================
-- REGNAME — a linked registration carries its fencer's roster name (ADR-079)
-- =============================================================================
-- A registration typed "STANISLAWSKI ALBERT" is #282 STANISŁAWSKI Albert. Once a
-- registration is linked to a fencer, its name is the roster's, with Polish
-- diacritics and the roster's case, whatever path links or edits it: the
-- public create, the identity answer, the edit path, an admin link, or the CERT
-- refresh. The public entry list and the FTL export read the registration's
-- name, so they show the roster's. A fencer renamed on the roster renames his
-- linked registrations. An unlinked registration keeps the name as typed.
--
-- Everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(9);

DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
BEGIN
  v_season := fn_create_season('REGNAME101', '2098-09-01', '2099-06-30');
  INSERT INTO tbl_organizer (txt_code, txt_name) VALUES ('REGORG101', 'Reg org 101') RETURNING id_organizer INTO v_org;
  PERFORM fn_create_event('REGNAME101EVT', 'Reg name 101', v_season, v_org);
END $setup$;

INSERT INTO tbl_fencer (id_fencer, txt_surname, txt_first_name, int_birth_year, enum_gender)
VALUES (97901, 'STANISŁAWSKI', 'Albert', 1987, 'M'),
       (97902, 'KACZMAREK', 'Paweł', 1970, 'M'),
       (97903, 'MŁYNEK', 'Janusz', 1951, 'M');

-- ---------------------------------------------------------------- the public create
DO $create$
BEGIN
  PERFORM fn_create_registration((SELECT id_event FROM tbl_event WHERE txt_code = 'REGNAME101EVT'),
            'STANISLAWSKI'::TEXT, 'ALBERT'::TEXT, 'M'::enum_gender_type, 1987::SMALLINT,
            ARRAY['SABRE']::enum_weapon_type[], 97901, NULL::TEXT);
  PERFORM fn_create_registration((SELECT id_event FROM tbl_event WHERE txt_code = 'REGNAME101EVT'),
            'NOWY'::TEXT, 'Fencer'::TEXT, 'M'::enum_gender_type, 1960::SMALLINT,
            ARRAY['EPEE']::enum_weapon_type[], NULL::INT, NULL::TEXT);
END $create$;

SELECT is((SELECT txt_surname || ' ' || txt_first_name FROM tbl_registration WHERE id_fencer = 97901),
          'STANISŁAWSKI Albert',
  'REGNAME.01 a registration linked when created carries the roster name, Ł and case included');

SELECT is((SELECT txt_surname || ' ' || txt_first_name FROM tbl_registration WHERE txt_surname = 'NOWY'),
          'NOWY Fencer',
  'REGNAME.02 an unlinked registration keeps the name as typed');

-- ---------------------------------------------------------------- linking later
INSERT INTO tbl_registration (id_event, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons)
SELECT id_event, 'PAWEL', 'KACZMAREK', 'M', 1970, ARRAY['FOIL']::enum_weapon_type[] FROM tbl_event WHERE txt_code = 'REGNAME101EVT';
UPDATE tbl_registration SET id_fencer = 97902 WHERE txt_surname = 'PAWEL';

SELECT is((SELECT txt_surname || ' ' || txt_first_name FROM tbl_registration WHERE id_fencer = 97902),
          'KACZMAREK Paweł',
  'REGNAME.03 linking an existing registration gives it the roster name, swapped fields put right');

-- ---------------------------------------------------------------- editing a linked name
DO $edit$
DECLARE
  v_reg INT := (SELECT id_registration FROM tbl_registration WHERE id_fencer = 97901);
  v_tok UUID := (SELECT uuid_edit_token FROM tbl_registration WHERE id_fencer = 97901);
BEGIN
  PERFORM fn_update_registration(v_reg, v_tok, 'STANISLAWSKI'::TEXT, 'Albercik'::TEXT, 'M'::enum_gender_type,
                                 1987::SMALLINT, ARRAY['SABRE','FOIL']::enum_weapon_type[], NULL::TEXT);
END $edit$;

SELECT is((SELECT txt_surname || ' ' || txt_first_name || ' ' || array_to_string(arr_weapons, ',')
             FROM tbl_registration WHERE id_fencer = 97901),
          'STANISŁAWSKI Albert SABRE,FOIL',
  'REGNAME.04 the edit path changes the entry but not a linked registration''s roster name');

UPDATE tbl_registration SET txt_surname = 'Stanislawski' WHERE id_fencer = 97901;
SELECT is((SELECT txt_surname FROM tbl_registration WHERE id_fencer = 97901), 'STANISŁAWSKI',
  'REGNAME.05 a direct write cannot take a linked registration''s name away from the roster');

-- ---------------------------------------------------------------- the roster leads
UPDATE tbl_fencer SET txt_first_name = 'Albert Jan' WHERE id_fencer = 97901;
SELECT is((SELECT txt_first_name FROM tbl_registration WHERE id_fencer = 97901), 'Albert Jan',
  'REGNAME.06 renaming a fencer renames his linked registrations');

UPDATE tbl_registration SET id_fencer = NULL WHERE id_fencer = 97902;
SELECT is((SELECT txt_surname || ' ' || txt_first_name FROM tbl_registration WHERE txt_first_name = 'Paweł'),
          'KACZMAREK Paweł',
  'REGNAME.07 unlinking keeps the last name; nothing is guessed back');

-- ---------------------------------------------------------------- what the public sees
SELECT is((SELECT v.txt_surname || ' ' || v.txt_first_name FROM vw_registration_entry_list v
             JOIN tbl_registration r USING (id_registration) WHERE r.id_fencer = 97901),
          'STANISŁAWSKI Albert Jan',
  'REGNAME.08 the public entry list shows the roster name');

-- ---------------------------------------------------------------- every linked row agrees
SELECT is((SELECT count(*)::INT FROM tbl_registration r JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
            WHERE r.txt_surname IS DISTINCT FROM f.txt_surname OR r.txt_first_name IS DISTINCT FROM f.txt_first_name),
          0,
  'REGNAME.09 no linked registration anywhere differs from its fencer''s name');

SELECT * FROM finish();
ROLLBACK;
