-- pgt-ignore-all lint/safety: pgTAP runs this file in one rolled-back transaction on LOCAL/CI, never on CERT/PROD
-- =============================================================================
-- REVFC.01–10 — an organiser reads an event's declared revenue by a key (FR-176)
-- =============================================================================
-- tbl_event_report_token holds one live key per event (replaced, never
-- deleted). fn_registration_fee is the one fee rule. fn_issue_event_report_token
-- is the administrator's: it creates or replaces the key. fn_event_revenue_report
-- is what the report page reads: NULL for a key that is not this event's live
-- key, otherwise the fees and one object per entry, never a birth year.
--
-- Plan doc/plans/event-revenue-forecast-2026-11-22.html, rev 3.
-- Every person here is invented. Everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(46);

DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
  v_ev     INT;
  v_two    INT;
  v_off    INT;
BEGIN
  v_season := fn_create_season('REV141', '2098-09-01', '2099-06-30');
  INSERT INTO tbl_organizer (txt_code, txt_name)
    VALUES ('REV141ORG', 'Revenue test organiser 141') RETURNING id_organizer INTO v_org;

  v_ev  := fn_create_event('REV141EV',  'Revenue 141 event',    v_season, v_org, NULL, '2099-02-15', '2099-02-16');
  v_two := fn_create_event('REV141TWO', 'Revenue 141 empty',    v_season, v_org, NULL, '2099-03-15', '2099-03-16');
  v_off := fn_create_event('REV141OFF', 'Revenue 141 reg. off', v_season, v_org, NULL, '2099-04-15', '2099-04-16');
  -- Our registration needs a payment account (fn_assert_registration_has_account).
  UPDATE tbl_event SET txt_payee = 'REV 141 PAYEE', txt_iban = 'PL 27 1140 2004 0000 3002 0135 5387',
                       bool_use_spws_registration = TRUE
   WHERE id_event IN (v_ev, v_two);
  -- v_ev: one weapon 70, two weapons 110, three weapons not set (R2: 3 × 70).
  UPDATE tbl_event SET num_entry_fee = 70, num_entry_fee_2w = 110 WHERE id_event = v_ev;
  -- v_two: no fee at all, and a stated currency.
  UPDATE tbl_event SET txt_entry_fee_currency = 'EUR' WHERE id_event = v_two;

  INSERT INTO tbl_registration (id_event, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons)
  VALUES (v_ev, 'NOWAK',   'Anna', 'F', 2045, ARRAY['EPEE', 'FOIL']::enum_weapon_type[]),
         (v_ev, 'KOWALSKI', 'Jan', 'M', 2045, ARRAY['SABRE']::enum_weapon_type[]),
         (v_ev, 'WIERZBA',  'Ola', 'F', 2045, ARRAY['EPEE', 'FOIL', 'SABRE']::enum_weapon_type[]);
END $setup$;

-- ---------------------------------------------------------------------------
-- REVFC.01 · the key table and who reads it
-- ---------------------------------------------------------------------------
SELECT columns_are('public', 'tbl_event_report_token',
  ARRAY['uuid_token', 'id_event', 'ts_created', 'ts_revoked'],
  'REVFC.01 the key table has exactly its four columns');
SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid = 'public.tbl_event_report_token'::regclass),
  'REVFC.01 row security is on');
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{"role":"anon"}', TRUE);
SELECT throws_ok($$SELECT * FROM tbl_event_report_token$$, '42501', NULL,
  'REVFC.01 a visitor cannot read the key table');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"role":"authenticated","sub":"00000000-0000-4000-8000-000000000141"}', TRUE);
SELECT lives_ok($$SELECT * FROM tbl_event_report_token$$,
  'REVFC.01 a signed-in administrator can read it');
SELECT throws_ok($$INSERT INTO tbl_event_report_token (id_event) SELECT id_event FROM tbl_event WHERE txt_code = 'REV141EV'$$,
  '42501', NULL, 'REVFC.01 and cannot insert directly');
SELECT throws_ok($$UPDATE tbl_event_report_token SET ts_revoked = now()$$,
  '42501', NULL, 'REVFC.01 nor update');
SELECT throws_ok($$DELETE FROM tbl_event_report_token$$,
  '42501', NULL, 'REVFC.01 nor delete');
RESET ROLE;
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{}', TRUE); END $$;

-- ---------------------------------------------------------------------------
-- REVFC.02 · at most one live key per event
-- ---------------------------------------------------------------------------
INSERT INTO tbl_event_report_token (id_event)
  SELECT id_event FROM tbl_event WHERE txt_code = 'REV141TWO';
SELECT throws_ok($$INSERT INTO tbl_event_report_token (id_event) SELECT id_event FROM tbl_event WHERE txt_code = 'REV141TWO'$$,
  '23505', NULL, 'REVFC.02 a second live key for one event is refused');
SELECT set_config('t141.tok_two',
  (SELECT uuid_token::text FROM tbl_event_report_token t JOIN tbl_event e USING (id_event)
    WHERE e.txt_code = 'REV141TWO' AND t.ts_revoked IS NULL), TRUE);

-- ---------------------------------------------------------------------------
-- REVFC.03 · issuing and replacing
-- ---------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"role":"authenticated","sub":"00000000-0000-4000-8000-000000000141"}', TRUE);
SELECT set_config('t141.tok_a', fn_issue_event_report_token((SELECT id_event FROM tbl_event WHERE txt_code = 'REV141EV'))::text, TRUE);
SELECT isnt(current_setting('t141.tok_a'), '', 'REVFC.03 issuing returns a key');
SELECT set_config('t141.tok_b', fn_issue_event_report_token((SELECT id_event FROM tbl_event WHERE txt_code = 'REV141EV'))::text, TRUE);
SELECT isnt(current_setting('t141.tok_b'), current_setting('t141.tok_a'), 'REVFC.03 issuing again returns another key');
SELECT throws_ok($$SELECT fn_issue_event_report_token((SELECT id_event FROM tbl_event WHERE txt_code = 'REV141OFF'))$$,
  'P0001', 'REPORT_NEEDS_SPWS_REGISTRATION', 'REVFC.03 an event without our registration is refused');
SELECT throws_ok($$SELECT fn_issue_event_report_token(-1)$$,
  'P0001', 'REPORT_NEEDS_SPWS_REGISTRATION', 'REVFC.03 an unknown event is refused');
RESET ROLE;
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{}', TRUE); END $$;
SELECT is((SELECT count(*)::INT FROM tbl_event_report_token t JOIN tbl_event e USING (id_event) WHERE e.txt_code = 'REV141EV'), 2,
  'REVFC.03 the replaced key keeps its row');
SELECT ok((SELECT ts_revoked IS NOT NULL FROM tbl_event_report_token WHERE uuid_token = current_setting('t141.tok_a')::uuid),
  'REVFC.03 and is stamped as replaced');
SELECT ok((SELECT ts_revoked IS NULL FROM tbl_event_report_token WHERE uuid_token = current_setting('t141.tok_b')::uuid),
  'REVFC.03 the new key is live');
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{"role":"anon"}', TRUE);
SELECT throws_ok($$SELECT fn_issue_event_report_token((SELECT id_event FROM tbl_event WHERE txt_code = 'REV141EV'))$$,
  '42501', NULL, 'REVFC.03 a visitor cannot call it');
RESET ROLE;
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{}', TRUE); END $$;

-- ---------------------------------------------------------------------------
-- REVFC.04 · the fee rule
-- ---------------------------------------------------------------------------
SELECT is(fn_registration_fee(1, 70, 110, 150), 70::numeric, 'REVFC.04 one weapon: the one-weapon fee');
SELECT is(fn_registration_fee(2, 70, 110, 150), 110::numeric, 'REVFC.04 two weapons: its tier');
SELECT is(fn_registration_fee(3, 70, 110, 150), 150::numeric, 'REVFC.04 three weapons: its tier');
SELECT is(fn_registration_fee(2, 70, NULL, 150), 140::numeric, 'REVFC.04 two weapons, tier not set: 2 × the one-weapon fee');
SELECT is(fn_registration_fee(3, 70, 110, NULL), 210::numeric, 'REVFC.04 three weapons, tier not set: 3 × the one-weapon fee');
SELECT is(fn_registration_fee(1, NULL, NULL, NULL), NULL::numeric, 'REVFC.04 no one-weapon fee: nothing');
SELECT is(fn_registration_fee(2, NULL, NULL, NULL), NULL::numeric, 'REVFC.04 no fee and two weapons: nothing');
SELECT is(fn_registration_fee(0, 70, 110, 150), NULL::numeric, 'REVFC.04 no weapon: nothing');
SELECT is(fn_registration_fee(4, 70, 110, 150), NULL::numeric, 'REVFC.04 four weapons: nothing');

-- ---------------------------------------------------------------------------
-- REVFC.05 · a key that is not this event's live key
-- ---------------------------------------------------------------------------
SELECT is(fn_event_revenue_report((SELECT id_event FROM tbl_event WHERE txt_code = 'REV141OFF'), gen_random_uuid()), NULL::jsonb,
  'REVFC.05 an event with no key answers NULL');
SELECT is(fn_event_revenue_report((SELECT id_event FROM tbl_event WHERE txt_code = 'REV141EV'), NULL), NULL::jsonb,
  'REVFC.05 no key at all answers NULL');
SELECT is(fn_event_revenue_report((SELECT id_event FROM tbl_event WHERE txt_code = 'REV141EV'), gen_random_uuid()), NULL::jsonb,
  'REVFC.05 an unknown key answers NULL');
SELECT is(fn_event_revenue_report((SELECT id_event FROM tbl_event WHERE txt_code = 'REV141EV'), current_setting('t141.tok_a')::uuid), NULL::jsonb,
  'REVFC.05 a replaced key answers NULL');
SELECT is(fn_event_revenue_report((SELECT id_event FROM tbl_event WHERE txt_code = 'REV141EV'), current_setting('t141.tok_two')::uuid), NULL::jsonb,
  'REVFC.05 another event''s live key answers NULL');

-- ---------------------------------------------------------------------------
-- REVFC.06 · the entries
-- ---------------------------------------------------------------------------
SELECT set_config('t141.rep',
  fn_event_revenue_report((SELECT id_event FROM tbl_event WHERE txt_code = 'REV141EV'), current_setting('t141.tok_b')::uuid)::text, TRUE);
SELECT is(jsonb_array_length(current_setting('t141.rep')::jsonb->'entries'), 3, 'REVFC.06 one entry per registration');
SELECT is((SELECT e->'arr_weapons' FROM jsonb_array_elements(current_setting('t141.rep')::jsonb->'entries') e WHERE e->>'txt_surname' = 'NOWAK'),
  '["EPEE", "FOIL"]'::jsonb, 'REVFC.06 an entry carries its weapons');
SELECT is((SELECT e->>'enum_gender' FROM jsonb_array_elements(current_setting('t141.rep')::jsonb->'entries') e WHERE e->>'txt_surname' = 'KOWALSKI'),
  'M', 'REVFC.06 and its gender');
SELECT is((SELECT e->>'enum_age_category' FROM jsonb_array_elements(current_setting('t141.rep')::jsonb->'entries') e WHERE e->>'txt_surname' = 'NOWAK'),
  fn_age_category(2045, 2099)::TEXT, 'REVFC.06 and the category the public list computes');
SELECT is((SELECT array_agg((e->>'num_fee')::numeric ORDER BY e->>'txt_surname') FROM jsonb_array_elements(current_setting('t141.rep')::jsonb->'entries') e),
  ARRAY[70, 110, 210]::numeric[], 'REVFC.06 and its fee by the rule (one, two, three weapons)');

-- ---------------------------------------------------------------------------
-- REVFC.07 · fees and currency
-- ---------------------------------------------------------------------------
SELECT is(current_setting('t141.rep')::jsonb->'fees',
  '{"1": 70, "2": 110, "3": 210, "fallback_2": false, "fallback_3": true}'::jsonb,
  'REVFC.07 the three tier fees, filled by the rule, and which were');
SELECT is(current_setting('t141.rep')::jsonb->>'currency', 'PLN', 'REVFC.07 PLN when the event states no currency');
SELECT is(fn_event_revenue_report((SELECT id_event FROM tbl_event WHERE txt_code = 'REV141TWO'), current_setting('t141.tok_two')::uuid)->>'currency',
  'EUR', 'REVFC.07 the stated currency');

-- ---------------------------------------------------------------------------
-- REVFC.08 · nothing private
-- ---------------------------------------------------------------------------
SELECT is((SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(current_setting('t141.rep')::jsonb->'entries'->0) k),
  ARRAY['arr_weapons', 'enum_age_category', 'enum_gender', 'id_registration', 'num_fee', 'txt_first_name', 'txt_surname'],
  'REVFC.08 an entry has exactly its seven keys: no birth year, club, e-mail hash, edit token, country or fencer id');

-- ---------------------------------------------------------------------------
-- REVFC.09 · a live key and no entries
-- ---------------------------------------------------------------------------
SELECT is(fn_event_revenue_report((SELECT id_event FROM tbl_event WHERE txt_code = 'REV141TWO'), current_setting('t141.tok_two')::uuid)->'entries',
  '[]'::jsonb, 'REVFC.09 a live key and no entries gives an empty list');
SELECT is(fn_event_revenue_report((SELECT id_event FROM tbl_event WHERE txt_code = 'REV141TWO'), current_setting('t141.tok_two')::uuid)->'fees'->'1',
  'null'::jsonb, 'REVFC.09 an event with no fee gives no one-weapon fee');

-- ---------------------------------------------------------------------------
-- REVFC.10 · who may call what
-- ---------------------------------------------------------------------------
SELECT ok(has_function_privilege('anon', 'fn_event_revenue_report(integer, uuid)', 'EXECUTE'),
  'REVFC.10 a visitor may call the report');
SELECT ok(NOT has_function_privilege('anon', 'fn_issue_event_report_token(integer)', 'EXECUTE'),
  'REVFC.10 and not the key''s issue');
SELECT ok(NOT has_function_privilege('anon', 'fn_registration_fee(integer, numeric, numeric, numeric)', 'EXECUTE'),
  'REVFC.10 nor the fee rule');
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{"role":"anon"}', TRUE);
SELECT is(jsonb_array_length(fn_event_revenue_report((SELECT id_event FROM tbl_event WHERE txt_code = 'REV141EV'), current_setting('t141.tok_b')::uuid)->'entries'),
  3, 'REVFC.10 a visitor with the key reads the report');
RESET ROLE;
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{}', TRUE); END $$;
SELECT is((SELECT count(*)::INT FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public' AND p.proname = 'fn_event_revenue_report'
              AND has_function_privilege('anon', p.oid, 'EXECUTE')), 1,
  'REVFC.10 exactly one visitor-callable report function');

SELECT * FROM finish();
ROLLBACK;
