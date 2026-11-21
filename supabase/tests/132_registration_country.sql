-- =============================================================================
-- RFCTRY — a registration's declared country (FR-169)
-- =============================================================================
-- The database half of FR-169 (plan registration-form-names-year-country rev
-- 10, release 3). An entry holds a fencing code of tbl_fencing_country or
-- nothing; both write functions store it, an old cached page that does not send
-- it still works; the PROD → CERT copy carries it; the public entry list shows
-- it and still no birth year or club; the organizer's export returns it.
--
-- Everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(14);

INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, enum_status)
SELECT c, 'RFCTRY fixture', (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027'),
       (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'), DATE '2099-03-01', DATE '2099-03-01', 'PLANNED'
  FROM (VALUES ('PPW8-2026-2027'), ('PPW9-2026-2027')) v(c);

INSERT INTO tbl_ftl_export_token (uuid_token, txt_label)
VALUES ('13200000-0000-4000-8000-000000000001', 'pgTAP 132 live');

-- ---------------------------------------------------------------------------
-- RFCTRY.18 — a code of the table, or nothing.
-- ---------------------------------------------------------------------------
SELECT has_column('tbl_registration', 'txt_country', 'RFCTRY.18 tbl_registration.txt_country exists');

SELECT throws_ok(
  $$INSERT INTO tbl_registration (id_event, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons, txt_country)
    SELECT id_event, 'RFCTRYBAD', 'Ana', 'F', 1970, ARRAY['EPEE']::enum_weapon_type[], 'XYZ'
      FROM tbl_event WHERE txt_code = 'PPW8-2026-2027'$$,
  '23503', NULL,
  'RFCTRY.18 a code the table does not hold is refused');

SELECT lives_ok(
  $$INSERT INTO tbl_registration (id_event, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons, txt_country)
    SELECT id_event, 'RFCTRYNONE', 'Ana', 'F', 1970, ARRAY['EPEE']::enum_weapon_type[], NULL
      FROM tbl_event WHERE txt_code = 'PPW8-2026-2027'$$,
  'RFCTRY.18 an entry may hold no country (entries made before the release)');

-- ---------------------------------------------------------------------------
-- RFCTRY.19 — the visitor's create path.
-- ---------------------------------------------------------------------------
SELECT fn_create_registration((SELECT id_event FROM tbl_event WHERE txt_code = 'PPW8-2026-2027'),
         'RFCTRYMUELLER', 'Hans', 'M', 1970::SMALLINT, ARRAY['EPEE']::enum_weapon_type[],
         p_edit_token => '13200000-0000-4000-8000-0000000000a1'::UUID, p_country => 'GER');
SELECT is((SELECT txt_country FROM tbl_registration WHERE txt_surname = 'RFCTRYMUELLER'), 'GER',
  'RFCTRY.19 create stores the declared country');

SELECT fn_create_registration((SELECT id_event FROM tbl_event WHERE txt_code = 'PPW8-2026-2027'),
         'RFCTRYOLDPAGE', 'Ola', 'F', 1970::SMALLINT, ARRAY['FOIL']::enum_weapon_type[]);
SELECT ok((SELECT txt_country IS NULL FROM tbl_registration WHERE txt_surname = 'RFCTRYOLDPAGE'),
  'RFCTRY.19 an old page''s call without a country still works and stores none');

-- ---------------------------------------------------------------------------
-- RFCTRY.20 — the visitor's edit path.
-- ---------------------------------------------------------------------------
SELECT fn_update_registration((SELECT id_registration FROM tbl_registration WHERE txt_surname = 'RFCTRYMUELLER'),
         '13200000-0000-4000-8000-0000000000a1'::UUID, 'RFCTRYMUELLER', 'Hans', 'M', 1970::SMALLINT,
         ARRAY['EPEE']::enum_weapon_type[], p_country => 'AUT');
SELECT is((SELECT txt_country FROM tbl_registration WHERE txt_surname = 'RFCTRYMUELLER'), 'AUT',
  'RFCTRY.20 edit stores the corrected country');

SELECT fn_update_registration((SELECT id_registration FROM tbl_registration WHERE txt_surname = 'RFCTRYMUELLER'),
         '13200000-0000-4000-8000-0000000000a1'::UUID, 'RFCTRYMUELLER', 'Hans', 'M', 1970::SMALLINT,
         ARRAY['EPEE', 'SABRE']::enum_weapon_type[]);
SELECT is((SELECT txt_country FROM tbl_registration WHERE txt_surname = 'RFCTRYMUELLER'), 'AUT',
  'RFCTRY.20 an old page''s edit without a country keeps the stored one');

-- ---------------------------------------------------------------------------
-- RFCTRY.21 — the PROD → CERT copy.
-- ---------------------------------------------------------------------------
SELECT fn_replace_event_registrations('PPW9-2026-2027', '[
  {"txt_surname": "RFCTRYCOPY", "txt_first_name": "Eva", "enum_gender": "F", "int_birth_year": 1975,
   "arr_weapons": ["EPEE"], "id_fencer": null, "txt_country": "SUI"}]'::JSONB);
SELECT is((SELECT txt_country FROM tbl_registration WHERE txt_surname = 'RFCTRYCOPY'), 'SUI',
  'RFCTRY.21 the copy carries the country');

-- ---------------------------------------------------------------------------
-- RFCTRY.22 — the public entry list.
-- ---------------------------------------------------------------------------
SELECT has_column('vw_registration_entry_list', 'txt_country', 'RFCTRY.22 the public entry list shows the country');
SELECT hasnt_column('vw_registration_entry_list', 'int_birth_year', 'RFCTRY.22 and still no birth year');
SELECT hasnt_column('vw_registration_entry_list', 'txt_club', 'RFCTRY.22 and still no club');
SELECT is((SELECT txt_country FROM vw_registration_entry_list WHERE txt_surname = 'RFCTRYMUELLER'), 'AUT',
  'RFCTRY.22 the entry list reads the stored country');

-- ---------------------------------------------------------------------------
-- RFCTRY.23 — the organizer's export.
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT string_agg(DISTINCT coalesce(x.txt_country, '-'), ',' ORDER BY coalesce(x.txt_country, '-'))
     FROM fn_ftl_export_entries((SELECT id_event FROM tbl_event WHERE txt_code = 'PPW8-2026-2027'),
                                '13200000-0000-4000-8000-000000000001'::UUID) x),
  '-,AUT',
  'RFCTRY.23 the export returns each entry''s country, none for an entry without one');

SELECT is(
  (SELECT count(*)::INT FROM fn_ftl_export_entries((SELECT id_event FROM tbl_event WHERE txt_code = 'PPW8-2026-2027'),
                                                    '13200000-0000-4000-8000-0000000000ff'::UUID)),
  0,
  'RFCTRY.23 without a live token the export still returns nothing');

SELECT * FROM finish();
ROLLBACK;
