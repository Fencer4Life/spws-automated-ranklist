-- pgt-ignore-all lint/safety: pgTAP runs this file in one rolled-back transaction on LOCAL/CI, never on CERT/PROD
-- =============================================================================
-- FR-173 (plan registration-name-list-under-surname-2026-11-22, rev 1, Part B):
-- the name list under the registration form's SURNAME box, and how an entry's
-- name arrived.
--
--   RFAC.01  one letter, an empty or NULL text, or an unknown event: no row
--   RFAC.02  two letters give the roster fencer, with gender, country, club, category
--   RFAC.03  typed without Polish letters and in lower case, found
--   RFAC.04  either name first, found
--   RFAC.05  a person in our table and on the EVF ranking comes once, from our table
--   RFAC.06  an EVF row's country and category; OTH is no country
--   RFAC.07  an earlier entrant on neither list comes once, as ENTRY
--   RFAC.08  at most 8 rows; surname matches first; ROSTER, EVF, ENTRY; alphabetical
--   RFAC.09  a person entered in the asked event is flagged, in another event not
--   RFAC.10  eight columns, no birth year and no id; no year gives no category
--   RFAC.11  a visitor may call it and still has no grant on the EVF table
--   RFAC.12  txt_name_source and the write that sets it
--   RFAC.35  the PROD → CERT copy of an event's entries keeps how each name arrived (I28)
--
-- Every name is invented and starts with XQ, so the data already on LOCAL
-- cannot reach these results. The age category follows the asked event's
-- season: both fixture events are in 2026/27. Everything rolls back.
-- =============================================================================

BEGIN;
SELECT plan(28);

INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, enum_status)
SELECT v.code, 'RFAC fixture', (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027'),
       (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'), DATE '2099-04-01', DATE '2099-04-01', 'PLANNED'
  FROM (VALUES ('PPW9-2026-2027'), ('PPW10-2026-2027')) v(code);
SELECT set_config('rfac.event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW9-2026-2027')::TEXT, TRUE);
SELECT set_config('rfac.other', (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW10-2026-2027')::TEXT, TRUE);

INSERT INTO tbl_fencer (txt_surname, txt_first_name, enum_gender, int_birth_year, txt_club, txt_nationality) VALUES
  ('XQNOWAK', 'Anna', 'F', 1970, 'KS Xq', 'POL'),
  ('XQNOWAKOWSKI', 'Xqab', 'M', NULL, NULL, 'POL'),
  ('XQŁUKASIK', 'Żaneta', 'F', 1980, '  ', 'POL');

INSERT INTO tbl_evf_ranking_fencer (id_evf, txt_surname, txt_first_name, enum_gender, int_category, txt_country) VALUES
  ('13800000-0000-4000-8000-000000000001', 'XQNOWAK', 'Anna', 'F', 3, 'HUN'),
  ('13800000-0000-4000-8000-000000000002', 'XQNOVÁK', 'Petr', 'M', 2, 'CZE'),
  ('13800000-0000-4000-8000-000000000003', 'XQNOWICKA', 'Maria', 'F', 4, 'OTH'),
  ('13800000-0000-4000-8000-000000000004', 'XQNOWAK', 'Zenon', 'M', 1, 'GER'),
  ('13800000-0000-4000-8000-000000000005', 'XQNORTH', 'Ola', 'F', 1, 'SWE'),
  ('13800000-0000-4000-8000-000000000006', 'XQNIX', 'Ed', 'M', 1, 'GBR'),
  ('13800000-0000-4000-8000-000000000007', 'XQABEL', 'Ed', 'M', 1, 'GBR');

-- Entries in PPW9 only: two of one newcomer (one titled), and the roster
-- fencer XQNOWAK Anna entered with a title.
INSERT INTO tbl_registration (id_event, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons,
                              txt_country, txt_consent_version, ts_consent, uuid_edit_token)
SELECT current_setting('rfac.event')::INT, v.s, v.f, 'F', v.y, ARRAY['EPEE']::enum_weapon_type[], v.c, 'v1.2',
       TIMESTAMPTZ '2026-11-01 10:00:00+00', v.tok::UUID
  FROM (VALUES ('XQNEWBIE', 'Ola', 1975, 'SWE', '13800000-0000-4000-8000-0000000000a1'),
               ('Dr. XQNEWBIE', 'Ola', 1976, 'SWE', '13800000-0000-4000-8000-0000000000a2'),
               ('Dr. XQNOWAK', 'Anna', 1970, 'POL', '13800000-0000-4000-8000-0000000000a3')) v(s, f, y, c, tok);

-- RFAC.01
SELECT is((SELECT coalesce(string_agg(concat_ws('/', s.txt_surname || ' ' || s.txt_first_name, s.enum_gender::TEXT,
         coalesce(s.txt_country, '-'), coalesce(s.enum_age_category::TEXT, '-'), coalesce(s.txt_club, '-'),
         s.txt_source, s.bool_entered::TEXT), '; ' ORDER BY s.ordinality), '')
    FROM fn_registration_name_suggestions(current_setting('rfac.event')::INT, 'x') WITH ORDINALITY AS s),
  '', 'RFAC.01 one typed letter gives no row');
SELECT is((SELECT coalesce(string_agg(concat_ws('/', s.txt_surname || ' ' || s.txt_first_name, s.enum_gender::TEXT,
         coalesce(s.txt_country, '-'), coalesce(s.enum_age_category::TEXT, '-'), coalesce(s.txt_club, '-'),
         s.txt_source, s.bool_entered::TEXT), '; ' ORDER BY s.ordinality), '')
    FROM fn_registration_name_suggestions(current_setting('rfac.event')::INT, '   ') WITH ORDINALITY AS s),
  '', 'RFAC.01 blanks give no row');
SELECT is((SELECT coalesce(string_agg(concat_ws('/', s.txt_surname || ' ' || s.txt_first_name, s.enum_gender::TEXT,
         coalesce(s.txt_country, '-'), coalesce(s.enum_age_category::TEXT, '-'), coalesce(s.txt_club, '-'),
         s.txt_source, s.bool_entered::TEXT), '; ' ORDER BY s.ordinality), '')
    FROM fn_registration_name_suggestions(current_setting('rfac.event')::INT, NULL) WITH ORDINALITY AS s),
  '', 'RFAC.01 NULL gives no row');
SELECT is((SELECT coalesce(string_agg(concat_ws('/', s.txt_surname || ' ' || s.txt_first_name, s.enum_gender::TEXT,
         coalesce(s.txt_country, '-'), coalesce(s.enum_age_category::TEXT, '-'), coalesce(s.txt_club, '-'),
         s.txt_source, s.bool_entered::TEXT), '; ' ORDER BY s.ordinality), '')
    FROM fn_registration_name_suggestions(-1, 'xqnowak') WITH ORDINALITY AS s),
  '', 'RFAC.01 an unknown event gives no row');

-- RFAC.02
SELECT is((SELECT coalesce(string_agg(concat_ws('/', s.txt_surname || ' ' || s.txt_first_name, s.enum_gender::TEXT,
         coalesce(s.txt_country, '-'), coalesce(s.enum_age_category::TEXT, '-'), coalesce(s.txt_club, '-'),
         s.txt_source, s.bool_entered::TEXT), '; ' ORDER BY s.ordinality), '')
    FROM fn_registration_name_suggestions(current_setting('rfac.other')::INT, 'XQNOWAK A') WITH ORDINALITY AS s),
  'XQNOWAK Anna/F/POL/V2/KS Xq/ROSTER/false', 'RFAC.02 the roster fencer with gender, country, category and club');

-- RFAC.03
SELECT is((SELECT coalesce(string_agg(concat_ws('/', s.txt_surname || ' ' || s.txt_first_name, s.enum_gender::TEXT,
         coalesce(s.txt_country, '-'), coalesce(s.enum_age_category::TEXT, '-'), coalesce(s.txt_club, '-'),
         s.txt_source, s.bool_entered::TEXT), '; ' ORDER BY s.ordinality), '')
    FROM fn_registration_name_suggestions(current_setting('rfac.other')::INT, 'xqlukasik z') WITH ORDINALITY AS s),
  'XQŁUKASIK Żaneta/F/POL/V1/-/ROSTER/false', 'RFAC.03 typed without Polish letters and in lower case, found; a blank club is no club');

-- RFAC.04
SELECT is((SELECT coalesce(string_agg(concat_ws('/', s.txt_surname || ' ' || s.txt_first_name, s.enum_gender::TEXT,
         coalesce(s.txt_country, '-'), coalesce(s.enum_age_category::TEXT, '-'), coalesce(s.txt_club, '-'),
         s.txt_source, s.bool_entered::TEXT), '; ' ORDER BY s.ordinality), '')
    FROM fn_registration_name_suggestions(current_setting('rfac.other')::INT, 'anna xqnow') WITH ORDINALITY AS s),
  'XQNOWAK Anna/F/POL/V2/KS Xq/ROSTER/false', 'RFAC.04 the given name first, found');
SELECT is((SELECT coalesce(string_agg(concat_ws('/', s.txt_surname || ' ' || s.txt_first_name, s.enum_gender::TEXT,
         coalesce(s.txt_country, '-'), coalesce(s.enum_age_category::TEXT, '-'), coalesce(s.txt_club, '-'),
         s.txt_source, s.bool_entered::TEXT), '; ' ORDER BY s.ordinality), '')
    FROM fn_registration_name_suggestions(current_setting('rfac.other')::INT, 'xqnowak an') WITH ORDINALITY AS s),
  'XQNOWAK Anna/F/POL/V2/KS Xq/ROSTER/false', 'RFAC.04 the surname, a space and the given name, found');

-- RFAC.05
SELECT is((SELECT coalesce(string_agg(concat_ws('/', s.txt_surname || ' ' || s.txt_first_name, s.enum_gender::TEXT,
         coalesce(s.txt_country, '-'), coalesce(s.enum_age_category::TEXT, '-'), coalesce(s.txt_club, '-'),
         s.txt_source, s.bool_entered::TEXT), '; ' ORDER BY s.ordinality), '')
    FROM fn_registration_name_suggestions(current_setting('rfac.other')::INT, 'xqnowak anna') WITH ORDINALITY AS s),
  'XQNOWAK Anna/F/POL/V2/KS Xq/ROSTER/false', 'RFAC.05 a person in our table and on the EVF ranking comes once, from our table');

-- RFAC.06
SELECT is((SELECT coalesce(string_agg(concat_ws('/', s.txt_surname || ' ' || s.txt_first_name, s.enum_gender::TEXT,
         coalesce(s.txt_country, '-'), coalesce(s.enum_age_category::TEXT, '-'), coalesce(s.txt_club, '-'),
         s.txt_source, s.bool_entered::TEXT), '; ' ORDER BY s.ordinality), '')
    FROM fn_registration_name_suggestions(current_setting('rfac.other')::INT, 'xqnovak') WITH ORDINALITY AS s),
  'XQNOVÁK Petr/M/CZE/V2/-/EVF/false', 'RFAC.06 an EVF row carries its country and its category');
SELECT is((SELECT coalesce(string_agg(concat_ws('/', s.txt_surname || ' ' || s.txt_first_name, s.enum_gender::TEXT,
         coalesce(s.txt_country, '-'), coalesce(s.enum_age_category::TEXT, '-'), coalesce(s.txt_club, '-'),
         s.txt_source, s.bool_entered::TEXT), '; ' ORDER BY s.ordinality), '')
    FROM fn_registration_name_suggestions(current_setting('rfac.other')::INT, 'xqnowicka') WITH ORDINALITY AS s),
  'XQNOWICKA Maria/F/-/V4/-/EVF/false', 'RFAC.06 OTH comes back as no country');

-- RFAC.07
SELECT is((SELECT coalesce(string_agg(concat_ws('/', s.txt_surname || ' ' || s.txt_first_name, s.enum_gender::TEXT,
         coalesce(s.txt_country, '-'), coalesce(s.enum_age_category::TEXT, '-'), coalesce(s.txt_club, '-'),
         s.txt_source, s.bool_entered::TEXT), '; ' ORDER BY s.ordinality), '')
    FROM fn_registration_name_suggestions(current_setting('rfac.other')::INT, 'xqnewbie') WITH ORDINALITY AS s),
  'XQNEWBIE Ola/F/SWE/V2/-/ENTRY/false', 'RFAC.07 an earlier entrant on neither list comes once, as ENTRY, a title ignored');
SELECT is((SELECT count(*) FROM fn_registration_name_suggestions(current_setting('rfac.other')::INT, 'xqnowak')
            WHERE txt_source = 'ENTRY')::INT, 0,
  'RFAC.07 an entrant who is on a list is not offered as ENTRY');

-- RFAC.08
SELECT is((SELECT string_agg(s.txt_surname || ' ' || s.txt_first_name, ', ' ORDER BY s.ordinality)
             FROM fn_registration_name_suggestions(current_setting('rfac.other')::INT, 'xq') WITH ORDINALITY AS s),
  'XQŁUKASIK Żaneta, XQNOWAK Anna, XQNOWAKOWSKI Xqab, XQABEL Ed, XQNIX Ed, XQNORTH Ola, XQNOVÁK Petr, XQNOWAK Zenon',
  'RFAC.08 eight rows at most: our table, then EVF, alphabetical within');
SELECT is((SELECT string_agg(s.txt_surname, ', ' ORDER BY s.ordinality)
             FROM fn_registration_name_suggestions(current_setting('rfac.other')::INT, 'xqab') WITH ORDINALITY AS s),
  'XQABEL, XQNOWAKOWSKI', 'RFAC.08 a surname match comes before a given-name match');

-- RFAC.09
SELECT is((SELECT bool_entered FROM fn_registration_name_suggestions(current_setting('rfac.event')::INT, 'xqnowak anna')),
  TRUE, 'RFAC.09 a person entered in the asked event is flagged (the entry''s title ignored)');
SELECT is((SELECT bool_entered FROM fn_registration_name_suggestions(current_setting('rfac.other')::INT, 'xqnowak anna')),
  FALSE, 'RFAC.09 the same person asked for another event is not');

-- RFAC.10
SELECT is((SELECT array_agg(a.n ORDER BY a.k) FROM pg_proc p,
             unnest(p.proargnames, p.proargmodes::TEXT[]) WITH ORDINALITY AS a(n, m, k)
            WHERE p.proname = 'fn_registration_name_suggestions' AND a.m = 't'),
  ARRAY['txt_surname', 'txt_first_name', 'enum_gender', 'txt_country', 'enum_age_category', 'txt_club',
        'txt_source', 'bool_entered']::TEXT[],
  'RFAC.10 exactly the eight named columns: no birth year, no id');
SELECT is((SELECT coalesce(string_agg(concat_ws('/', s.txt_surname || ' ' || s.txt_first_name, s.enum_gender::TEXT,
         coalesce(s.txt_country, '-'), coalesce(s.enum_age_category::TEXT, '-'), coalesce(s.txt_club, '-'),
         s.txt_source, s.bool_entered::TEXT), '; ' ORDER BY s.ordinality), '')
    FROM fn_registration_name_suggestions(current_setting('rfac.other')::INT, 'xqnowakowski') WITH ORDINALITY AS s),
  'XQNOWAKOWSKI Xqab/M/POL/-/-/ROSTER/false', 'RFAC.10 a fencer without a year has no category');

-- RFAC.11
SELECT ok(has_function_privilege('anon', 'fn_registration_name_suggestions(integer, text)', 'EXECUTE'),
  'RFAC.11 a visitor may call the list');
SELECT ok(NOT has_table_privilege('anon', 'tbl_evf_ranking_fencer', 'SELECT'),
  'RFAC.11 a visitor still has no grant on the EVF table');

-- RFAC.12
SELECT col_default_is('public', 'tbl_registration', 'txt_name_source', 'TYPED'::TEXT,
  'RFAC.12 an entry''s name is TYPED unless the form says otherwise');
SELECT throws_ok(
  $$UPDATE tbl_registration SET txt_name_source = 'GUESSED' WHERE txt_surname = 'XQNEWBIE'$$,
  '23514', NULL, 'RFAC.12 another word is refused');
SELECT fn_set_registration_name_source(
  (SELECT id_registration FROM tbl_registration WHERE txt_surname = 'XQNEWBIE'),
  '13800000-0000-4000-8000-0000000000a1', 'ENTRY');
SELECT is((SELECT txt_name_source FROM tbl_registration WHERE txt_surname = 'XQNEWBIE'), 'ENTRY',
  'RFAC.12 the entry''s own edit handle sets the source');
SELECT throws_ok(
  $$SELECT fn_set_registration_name_source(
      (SELECT id_registration FROM tbl_registration WHERE txt_surname = 'XQNEWBIE'),
      '13800000-0000-4000-8000-0000000000a2', 'ROSTER')$$,
  'REG_NAME_SOURCE_REFUSED', 'RFAC.12 another entry''s handle is refused');
SELECT throws_ok(
  $$SELECT fn_set_registration_name_source(
      (SELECT id_registration FROM tbl_registration WHERE txt_surname = 'XQNEWBIE'), NULL, 'ROSTER')$$,
  'REG_NAME_SOURCE_REFUSED', 'RFAC.12 no handle is refused');
SELECT throws_ok(
  $$SELECT fn_set_registration_name_source(
      (SELECT id_registration FROM tbl_registration WHERE txt_surname = 'XQNEWBIE'),
      '13800000-0000-4000-8000-0000000000a1', 'GUESSED')$$,
  'REG_NAME_SOURCE_REFUSED', 'RFAC.12 an unknown word is refused');


-- RFAC.35 (I28)
SELECT fn_replace_event_registrations('PPW10-2026-2027',
  '[{"txt_surname": "XQCOPY", "txt_first_name": "Ida", "enum_gender": "F", "int_birth_year": 1971,
     "arr_weapons": ["EPEE"], "txt_country": "POL", "txt_name_source": "EVF"},
    {"txt_surname": "XQCOPYOLD", "txt_first_name": "Ola", "enum_gender": "F", "int_birth_year": 1972,
     "arr_weapons": ["EPEE"], "txt_country": "POL"}]'::JSONB);
SELECT is((SELECT string_agg(txt_surname || '=' || txt_name_source, ', ' ORDER BY txt_surname) FROM tbl_registration
            WHERE id_event = current_setting('rfac.other')::INT),
  'XQCOPY=EVF, XQCOPYOLD=TYPED',
  'RFAC.35 the copy keeps how each name arrived; a row without it reads TYPED');

SELECT * FROM finish();
ROLLBACK;
