-- =============================================================================
-- REG — fn_replace_event_registrations gives a target PROD's entries for one event
-- =============================================================================
-- ADR-108 §2. Every CERT ingestion starts from PROD's master data. For the event
-- being ingested, PROD's registrations replace the target's: they carry the
-- birth years fencers declared (ADR-093), which the ingestion reads. Copied:
-- surname, first name, gender, declared birth year, weapons, FTL name, club and
-- the fencer link, valid once fencer ids are identical. Never copied: the e-mail
-- hash, the edit token and the consent stamp (data minimisation); the target
-- generates its own edit token.
--
-- Everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(8);

INSERT INTO tbl_fencer (id_fencer, txt_surname, txt_first_name, int_birth_year, enum_gender)
VALUES (96101, 'REGA', 'Anna', 1975, 'F');

INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, enum_status)
SELECT c, 'REG fixture', (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
       (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'), DATE '2026-03-01', DATE '2026-03-01', 'PLANNED'
  FROM (VALUES ('PPW9-2025-2026'), ('PPW8-2025-2026')) v(c);

-- The target's own test entries, and an entry for another event.
INSERT INTO tbl_registration (id_event, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons, txt_email_hash)
SELECT e.id_event, s, 'Test', 'M', 1970, ARRAY['EPEE']::enum_weapon_type[], 'cert-test-hash'
  FROM tbl_event e, (VALUES ('CERTTESTA'), ('CERTTESTB')) v(s) WHERE e.txt_code = 'PPW9-2025-2026';
INSERT INTO tbl_registration (id_event, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons)
SELECT id_event, 'OTHEREVENT', 'Olga', 'F', 1960, ARRAY['FOIL']::enum_weapon_type[]
  FROM tbl_event WHERE txt_code = 'PPW8-2025-2026';

-- An identity override recorded against one of the target's entries.
INSERT INTO tbl_registration_identity_override (id_registration, id_fencer, txt_surname, txt_first_name,
                                                int_birth_year_before, int_birth_year_after)
SELECT id_registration, 96101, 'CERTTESTA', 'Test', 1969, 1970 FROM tbl_registration WHERE txt_surname = 'CERTTESTA';

CREATE TEMP TABLE reg_rows AS
SELECT '[
  {"txt_surname": "REGA", "txt_first_name": "Anna", "enum_gender": "F", "int_birth_year": 1975,
   "arr_weapons": ["EPEE", "SABRE"], "txt_ftl_name": "REGA Anna", "txt_club": "AZS", "id_fencer": 96101,
   "txt_email_hash": "prod-hash", "uuid_edit_token": "11111111-1111-4111-8111-111111111111",
   "ts_consent": "2026-09-01T10:00:00Z", "txt_consent_version": "v3"},
  {"txt_surname": "NOWYB", "txt_first_name": "Bogdan", "enum_gender": "M", "int_birth_year": 1980,
   "arr_weapons": ["FOIL"], "txt_ftl_name": null, "txt_club": null, "id_fencer": null},
  {"txt_surname": "NOWYC", "txt_first_name": "Cezary", "enum_gender": "M", "int_birth_year": 1985,
   "arr_weapons": ["EPEE"], "txt_ftl_name": "NOWYC Cezary", "txt_club": "KS", "id_fencer": null}
]'::JSONB AS j;

SELECT ok(NOT has_function_privilege('anon', 'fn_replace_event_registrations(text,jsonb)', 'EXECUTE')
          AND NOT has_function_privilege('authenticated', 'fn_replace_event_registrations(text,jsonb)', 'EXECUTE')
          AND has_function_privilege('service_role', 'fn_replace_event_registrations(text,jsonb)', 'EXECUTE'),
  'REG.01 only the service role may replace an event''s registrations');

SELECT throws_like(
  $$SELECT fn_replace_event_registrations('PPW9-2025-2026',
          (SELECT j FROM reg_rows) || '[{"txt_surname": "GHOST", "txt_first_name": "G", "enum_gender": "M",
                                         "int_birth_year": 1970, "arr_weapons": ["EPEE"], "id_fencer": 96199}]')$$,
  '%REG_FENCER_UNKNOWN%96199%',
  'REG.02 a fencer link the target does not know refuses the whole copy');

SELECT throws_like(
  $$SELECT fn_replace_event_registrations('PPW9', (SELECT j FROM reg_rows))$$,
  '%REG_EVENT_UNKNOWN%PPW9%',
  'REG.03 the event is named by its exact code; a prefix refuses');

SELECT results_eq(
  $$SELECT count(*)::INT FROM tbl_registration r JOIN tbl_event e USING (id_event) WHERE e.txt_code = 'PPW9-2025-2026'$$,
  $$VALUES (2)$$,
  'REG.04 after the refusals the target''s entries are untouched');

SELECT is(fn_replace_event_registrations('PPW9-2025-2026', (SELECT j FROM reg_rows)),
          '{"deleted": 2, "inserted": 3}'::JSONB,
  'REG.05 the target''s entries for the event are replaced by PROD''s');

SELECT results_eq(
  $$SELECT r.txt_surname, r.int_birth_year::INT, r.arr_weapons::TEXT, r.txt_ftl_name, r.txt_club, r.id_fencer
      FROM tbl_registration r JOIN tbl_event e USING (id_event)
     WHERE e.txt_code IN ('PPW9-2025-2026', 'PPW8-2025-2026') ORDER BY 1$$,
  $$VALUES ('NOWYB'::TEXT, 1980, '{FOIL}'::TEXT, NULL::TEXT, NULL::TEXT, NULL::INT),
           ('NOWYC', 1985, '{EPEE}', 'NOWYC Cezary', 'KS', NULL),
           ('OTHEREVENT', 1960, '{FOIL}', NULL, NULL, NULL),
           ('REGA', 1975, '{EPEE,SABRE}', 'REGA Anna', 'AZS', 96101)$$,
  'REG.06 what the ingestion reads is copied, and another event''s entries are untouched');

SELECT results_eq(
  $$SELECT txt_email_hash, ts_consent, txt_consent_version,
           uuid_edit_token IS NOT NULL AND uuid_edit_token <> '11111111-1111-4111-8111-111111111111'::UUID
      FROM tbl_registration WHERE txt_surname = 'REGA'$$,
  $$VALUES (NULL::TEXT, NULL::TIMESTAMPTZ, NULL::TEXT, TRUE)$$,
  'REG.07 no e-mail hash, consent stamp or edit token reaches the target; it makes its own token');

SELECT results_eq(
  $$SELECT id_registration IS NULL, txt_surname FROM tbl_registration_identity_override WHERE id_fencer = 96101$$,
  $$VALUES (TRUE, 'CERTTESTA'::TEXT)$$,
  'REG.08 an identity override keeps its record, with the replaced entry''s link cleared');

SELECT * FROM finish();
ROLLBACK;
