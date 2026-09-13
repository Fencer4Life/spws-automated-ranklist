-- =============================================================================
-- pgTAP — fn_ftl_roster, the organizer's pick-list
-- =============================================================================
-- Verifies migration 20260912000005_ftl_roster.sql (ADR-080 amendment (e)).
--
-- WHAT THIS FILE IS FOR. Somebody turns up at the venue who never entered. The
-- organizer has two ways to put them in the bracket: type the name, or tick
-- them out of a list we supplied. Typing is how a duplicate identity is born —
-- the name comes back to us on the results, matches nothing, and a second
-- fencer record is created for a person we already knew. ADR-065's amendment
-- records exactly that happening (fencer #330). This function is the list.
--
-- THE SUPPRESSION RULE IS TWO CLAUSES, NOT ONE, AND THE SECOND ONE IS THE WHOLE
-- POINT. The obvious rule — "leave out anyone whose name matches a
-- registration" — is wrong on live data. PROD holds two people called
-- MŁYNEK Janusz: #197 born 1951 with nineteen results, and #356 born 1984 with
-- none. If #356 registers, the naive rule deletes #197 from the roster — and
-- #197 is precisely the fencer an organizer might need to tick in. So:
--
--   1. always suppress an id_fencer that a registration for THIS event and
--      weapon already points at (exact, unambiguous, no names involved); and
--   2. suppress by name only when an unmatched registration bears that name AND
--      exactly one fencer in the table bears it too.
--
-- The MŁYNEK pair is carried here as a fixture so clause 2 is exercised rather
-- than assumed.
--
-- Plan-test-ID 77 (this file).
-- =============================================================================

BEGIN;

SELECT plan(14);

DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
  v_ev     INT;
  v_t_e    INT;
  v_t_f    INT;
  v_plain  INT;
  v_reged  INT;
  v_solo   INT;
  v_twin_a INT;
  v_twin_b INT;
  v_foil   INT;
BEGIN
  v_season := fn_create_season('FTLR77', '2098-09-01', '2099-06-30');
  INSERT INTO tbl_organizer (txt_code, txt_name)
    VALUES ('FTLRORG77', 'FTL roster org 77') RETURNING id_organizer INTO v_org;
  v_ev := fn_create_event('FTLR77EVT', 'FTL roster 77', v_season, v_org,
                          NULL, '2099-01-20', '2099-01-20');

  -- Season end year 2099 → V2 is birth years 2040-2049, V0 is 2060-2069.
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, enum_gender,
                          bool_birth_year_estimated)
    VALUES ('PGTAP77PLAIN', 'Piotr',  2045, 'M', FALSE) RETURNING id_fencer INTO v_plain;
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, enum_gender,
                          bool_birth_year_estimated)
    VALUES ('PGTAP77REGED', 'Rafał',  2045, 'M', FALSE) RETURNING id_fencer INTO v_reged;
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, enum_gender,
                          bool_birth_year_estimated)
    VALUES ('PGTAP77SOLO',  'Sylwia', 2045, 'F', FALSE) RETURNING id_fencer INTO v_solo;
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, enum_gender,
                          bool_birth_year_estimated)
    VALUES ('PGTAP77FOIL',  'Fabian', 2045, 'M', FALSE) RETURNING id_fencer INTO v_foil;

  -- THE MŁYNEK FIXTURE: one name, two people, 33 years apart. Only the elder
  -- has results, which is what makes suppressing the wrong one unrecoverable.
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, enum_gender,
                          bool_birth_year_estimated)
    VALUES ('PGTAP77TWIN', 'Janusz', 2045, 'M', FALSE) RETURNING id_fencer INTO v_twin_a;
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, enum_gender,
                          bool_birth_year_estimated)
    VALUES ('PGTAP77TWIN', 'Janusz', 2065, 'M', FALSE) RETURNING id_fencer INTO v_twin_b;

  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon,
                              enum_gender, enum_age_category, enum_import_status,
                              num_multiplier, int_participant_count)
    VALUES (v_ev, 'FTLR77TE', 'roster 77 epee', 'PPW', 'EPEE', 'M', 'V2',
            'SCORED', 1.0, 8) RETURNING id_tournament INTO v_t_e;
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon,
                              enum_gender, enum_age_category, enum_import_status,
                              num_multiplier, int_participant_count)
    VALUES (v_ev, 'FTLR77TF', 'roster 77 foil', 'PPW', 'FOIL', 'M', 'V2',
            'SCORED', 1.0, 8) RETURNING id_tournament INTO v_t_f;

  -- Results are what puts a fencer on the roster. Épée for everyone except
  -- Fabian, who has only ever fenced foil and must therefore be absent from the
  -- épée roster entirely. enum_source_age_category is set for the same reason
  -- as in tests 75 and 76.
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place,
                          enum_fencer_age_category, enum_source_age_category,
                          num_final_score)
  VALUES (v_plain,  v_t_e, 1, 'V2', 'V2', 100.0),
         (v_reged,  v_t_e, 2, 'V2', 'V2',  90.0),
         (v_solo,   v_t_e, 3, 'V2', 'V2',  80.0),
         (v_twin_a, v_t_e, 4, 'V2', 'V2',  70.0),
         (v_foil,   v_t_f, 1, 'V2', 'V2', 100.0);

  INSERT INTO tbl_registration (id_event, id_fencer, txt_surname, txt_first_name,
                                enum_gender, int_birth_year, arr_weapons)
  VALUES
    -- Matched: suppressed by clause 1, on identity, whatever their name is.
    (v_ev, v_reged, 'PGTAP77REGED', 'Rafał', 'M', 2045,
     ARRAY['EPEE']::enum_weapon_type[]),
    -- Unmatched, and exactly one fencer bears this name: clause 2 suppresses.
    (v_ev, NULL, 'PGTAP77SOLO', 'Sylwia', 'F', 2045,
     ARRAY['EPEE']::enum_weapon_type[]),
    -- Unmatched, and TWO fencers bear this name: clause 2 must NOT fire, or the
    -- fencer with the results disappears because his namesake entered.
    (v_ev, NULL, 'PGTAP77TWIN', 'Janusz', 'M', 2065,
     ARRAY['EPEE']::enum_weapon_type[]);

  INSERT INTO tbl_ftl_export_token (uuid_token, txt_label)
    VALUES ('77000000-0000-4000-8000-000000000001', 'pgTAP 77');
END $setup$;

-- ---------------------------------------------------------------------------
-- Shape and posture — the same contract as the entries projection
-- ---------------------------------------------------------------------------
SELECT has_function('fn_ftl_roster', ARRAY['integer', 'enum_weapon_type', 'uuid'],
  '77.1 fn_ftl_roster(INT, weapon, UUID) exists');

SELECT ok(
  pg_get_function_result('fn_ftl_roster(integer,enum_weapon_type,uuid)'::regprocedure)
    NOT LIKE '%birth_year%'
  AND pg_get_function_result('fn_ftl_roster(integer,enum_weapon_type,uuid)'::regprocedure)
    NOT LIKE '%id_fencer%',
  '77.2 the roster publishes no birth year and no fencer id, like the entry projection');

SELECT ok(
  has_function_privilege('anon', 'fn_ftl_roster(integer,enum_weapon_type,uuid)', 'EXECUTE'),
  '77.3 anon can call it — same public page, same anon key');

SELECT is_empty(
  $$SELECT 1 FROM fn_ftl_roster(
      (SELECT id_event FROM tbl_event WHERE txt_code = 'FTLR77EVT'),
      'EPEE', '77000000-0000-4000-8000-0000000000ff')$$,
  '77.4 an unknown token returns nothing, exactly as the other two do');

-- ---------------------------------------------------------------------------
-- Population: results in THIS weapon, full history, all nationalities
-- ---------------------------------------------------------------------------
-- The roster is GLOBAL by design — every fencer with a result in this weapon,
-- which on LOCAL means the whole PROD seed (206 épéeists). Every count below is
-- therefore scoped to this file's own fixtures; asserting a total would be
-- asserting the seed, which changes every time it is refreshed.
SELECT is(
  (SELECT count(*)::INT FROM fn_ftl_roster(
     (SELECT id_event FROM tbl_event WHERE txt_code = 'FTLR77EVT'),
     'EPEE', '77000000-0000-4000-8000-000000000001')
    WHERE txt_surname LIKE 'PGTAP77%'),
  2,
  '77.5 of the fixture''s six fencers only two reach the pick-list: one is foil-only, one never fenced at all, and two are suppressed');

SELECT is(
  (SELECT array_agg(txt_surname ORDER BY txt_surname) FROM fn_ftl_roster(
     (SELECT id_event FROM tbl_event WHERE txt_code = 'FTLR77EVT'),
     'EPEE', '77000000-0000-4000-8000-000000000001')
    WHERE txt_surname LIKE 'PGTAP77%'),
  ARRAY['PGTAP77PLAIN', 'PGTAP77TWIN'],
  '77.6 and they are the expected two — the surviving twin is the one with results');

SELECT is_empty(
  $$SELECT 1 FROM fn_ftl_roster(
      (SELECT id_event FROM tbl_event WHERE txt_code = 'FTLR77EVT'),
      'EPEE', '77000000-0000-4000-8000-000000000001')
     WHERE txt_surname = 'PGTAP77FOIL'$$,
  '77.7 a fencer with results only in another weapon is not on this weapon''s roster');

SELECT is(
  (SELECT count(*)::INT FROM fn_ftl_roster(
     (SELECT id_event FROM tbl_event WHERE txt_code = 'FTLR77EVT'),
     'FOIL', '77000000-0000-4000-8000-000000000001')
    WHERE txt_surname LIKE 'PGTAP77%'),
  1,
  '77.8 and he is on the foil roster, which nobody registered for');

-- ---------------------------------------------------------------------------
-- Suppression — clause 1, on identity
-- ---------------------------------------------------------------------------
SELECT is_empty(
  $$SELECT 1 FROM fn_ftl_roster(
      (SELECT id_event FROM tbl_event WHERE txt_code = 'FTLR77EVT'),
      'EPEE', '77000000-0000-4000-8000-000000000001')
     WHERE txt_surname = 'PGTAP77REGED'$$,
  '77.9 a fencer this event''s registration already points at is off the pick-list');

-- ---------------------------------------------------------------------------
-- Suppression — clause 2, by name, and only when the name is unambiguous
-- ---------------------------------------------------------------------------
SELECT is_empty(
  $$SELECT 1 FROM fn_ftl_roster(
      (SELECT id_event FROM tbl_event WHERE txt_code = 'FTLR77EVT'),
      'EPEE', '77000000-0000-4000-8000-000000000001')
     WHERE txt_surname = 'PGTAP77SOLO'$$,
  '77.10 an unmatched registration suppresses by name when exactly one fencer bears it');

SELECT is(
  (SELECT count(*)::INT FROM fn_ftl_roster(
     (SELECT id_event FROM tbl_event WHERE txt_code = 'FTLR77EVT'),
     'EPEE', '77000000-0000-4000-8000-000000000001')
    WHERE txt_surname = 'PGTAP77TWIN'),
  1,
  '77.11 THE MŁYNEK GUARD: two fencers share the name, so the name rule stays its hand and the one with results survives');

-- ---------------------------------------------------------------------------
-- What each row carries
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT enum_age_category FROM fn_ftl_roster(
     (SELECT id_event FROM tbl_event WHERE txt_code = 'FTLR77EVT'),
     'EPEE', '77000000-0000-4000-8000-000000000001')
    WHERE txt_surname = 'PGTAP77PLAIN'),
  'V2'::enum_age_category,
  '77.12 the V-category is computed for THIS event''s season, not the fencer''s last one');

SELECT is(
  (SELECT array_agg(txt_surname ORDER BY int_order) FROM fn_ftl_roster(
     (SELECT id_event FROM tbl_event WHERE txt_code = 'FTLR77EVT'),
     'EPEE', '77000000-0000-4000-8000-000000000001')
    WHERE txt_surname LIKE 'PGTAP77%'),
  ARRAY['PGTAP77PLAIN', 'PGTAP77TWIN'],
  '77.13 ordered alphabetically — this is a list to find a name in, not to seed from');

SELECT is_empty(
  $$SELECT 1 FROM fn_ftl_roster(-1, 'EPEE', '77000000-0000-4000-8000-000000000001')$$,
  '77.14 an unknown event yields no rows rather than an error');

SELECT * FROM finish();
ROLLBACK;
