-- =============================================================================
-- pgTAP — per-event payment details: resolution, vetting and the toggle guard
-- =============================================================================
-- Verifies migration 20260902000001_event_payment_details.sql.
--
-- Until now one account number served every event, compiled into the frontend
-- bundle (lib/orgPayment.ts). Organizers other than SPWS need their own account
-- and individual events occasionally override it, so payee and IBAN become
-- columns on tbl_organizer (the default) and tbl_event (the override).
--
-- The system never handles the money — it publishes the account a fencer is
-- asked to pay into, and the organizer verifies payment in person (ADR-079 §4).
-- That is precisely why the number is vetted rather than trusted: a wrong value
-- sends the fencer's own transfer astray under a label saying IBAN.
--
-- One definition of "absent" throughout: NULL, empty and whitespace-only are
-- the same thing, normalised on write. Without that, a payee of '   ' would
-- satisfy the toggle guard, and a field cleared in the editor would silently
-- mean "locked against the sync" while looking identical to one never filled.
-- =============================================================================

BEGIN;

SELECT plan(21);

-- ----- 69.1–69.4 shape -------------------------------------------------------
SELECT has_column('tbl_organizer', 'txt_payee', '69.1 — tbl_organizer.txt_payee exists');
SELECT has_column('tbl_organizer', 'txt_iban',  '69.2 — tbl_organizer.txt_iban exists');
SELECT has_column('tbl_event',     'txt_payee', '69.3 — tbl_event.txt_payee exists (override)');
SELECT has_column('tbl_event',     'txt_iban',  '69.4 — tbl_event.txt_iban exists (override)');

-- ----- 69.5–69.9 the IBAN rule, in the database ------------------------------
SELECT ok(fn_is_valid_iban('PL 06 1090 1665 0000 0001 5004 1549'),
  '69.5 — the association account is valid');
SELECT ok(NOT fn_is_valid_iban('06 1090 1665 0000 0001 5004 1549'),
  '69.6 — the domestic NRB is refused: same account, no country code (mod-97 = 73)');
SELECT ok(NOT fn_is_valid_iban('PL 06 1090 1665 0000 0001 5004 1548'),
  '69.7 — a single mistyped digit is refused');
SELECT ok(fn_is_valid_iban('DE89 3704 0044 0532 0130 00'),
  '69.8 — a valid foreign IBAN is accepted; the rule is ISO 13616, not PL-only');
SELECT ok(NOT fn_is_valid_iban('   ') AND NOT fn_is_valid_iban('nonsense'),
  '69.9 — blank and junk are refused');

-- ----- fixtures --------------------------------------------------------------
DO $setup$
DECLARE v_season INT; v_org INT; v_org2 INT;
BEGIN
  v_season := fn_create_season('PAY69', '2098-09-01', '2099-06-30');
  INSERT INTO tbl_organizer (txt_code, txt_name, txt_payee, txt_iban)
    VALUES ('PAYORG69', 'Org with an account',
            'ORGANIZER DEFAULT PAYEE', 'PL 06 1090 1665 0000 0001 5004 1549')
    RETURNING id_organizer INTO v_org;
  INSERT INTO tbl_organizer (txt_code, txt_name)
    VALUES ('PAYORG69B', 'Org with no account') RETURNING id_organizer INTO v_org2;
  PERFORM fn_create_event('PAY69INHERIT', 'Inherits the organizer account', v_season, v_org);
  PERFORM fn_create_event('PAY69OVERRIDE', 'Overrides it', v_season, v_org);
  PERFORM fn_create_event('PAY69NONE', 'No account anywhere', v_season, v_org2);

  UPDATE tbl_event SET txt_payee = 'EVENT SPECIFIC PAYEE',
                       txt_iban  = 'PL 27 1140 2004 0000 3002 0135 5387'
   WHERE txt_code = 'PAY69OVERRIDE';
END $setup$;

-- ----- 69.10–69.12 constraints and normalisation ------------------------------
SELECT throws_ok(
  $$UPDATE tbl_event SET txt_iban = 'PL 06 1090 1665 0000 0001 5004 1548'
     WHERE txt_code = 'PAY69INHERIT'$$,
  NULL, NULL,
  '69.10 — an invalid IBAN cannot be stored on an event, whatever the caller'
);

SELECT throws_ok(
  $$UPDATE tbl_organizer SET txt_iban = 'not an iban' WHERE txt_code = 'PAYORG69'$$,
  NULL, NULL,
  '69.11 — nor on an organizer'
);

-- Whitespace is not data. Without this, a payee of '   ' would satisfy the
-- toggle guard and a cleared field would read as a value.
DO $blank$
BEGIN
  UPDATE tbl_event SET txt_payee = '   ', txt_iban = '  ' WHERE txt_code = 'PAY69OVERRIDE';
END $blank$;

SELECT ok(
  (SELECT txt_payee IS NULL AND txt_iban IS NULL FROM tbl_event WHERE txt_code = 'PAY69OVERRIDE'),
  '69.12 — blank-looking values collapse to NULL on write'
);

-- restore the override for the resolution assertions
UPDATE tbl_event SET txt_payee = 'EVENT SPECIFIC PAYEE',
                     txt_iban  = 'PL 27 1140 2004 0000 3002 0135 5387'
 WHERE txt_code = 'PAY69OVERRIDE';

-- ----- 69.13–69.17 resolution, and where it came from -------------------------
SELECT is(
  (SELECT txt_payee FROM vw_calendar WHERE txt_code = 'PAY69INHERIT'),
  'ORGANIZER DEFAULT PAYEE',
  '69.13 — an event with no override inherits the organizer account'
);

SELECT is(
  (SELECT txt_payment_source::TEXT FROM vw_calendar WHERE txt_code = 'PAY69INHERIT'),
  'ORGANIZER',
  '69.14 — and says so, so the admin is never left inferring it'
);

SELECT is(
  (SELECT txt_iban FROM vw_calendar WHERE txt_code = 'PAY69OVERRIDE'),
  'PL 27 1140 2004 0000 3002 0135 5387',
  '69.15 — an override wins over the organizer default'
);

SELECT is(
  (SELECT txt_payment_source::TEXT FROM vw_calendar WHERE txt_code = 'PAY69OVERRIDE'),
  'EVENT',
  '69.16 — reported as the event''s own account'
);

SELECT is(
  (SELECT txt_payment_source::TEXT FROM vw_calendar WHERE txt_code = 'PAY69NONE'),
  'NONE',
  '69.17 — no account at either level is reported as NONE, not as a blank'
);

-- ----- 69.18 the toggle guard -------------------------------------------------
-- Enabling registration with nowhere to pay is a configuration mistake rather
-- than a legitimate state: the fee cannot be quoted against anything and the
-- entrant reaches the end of the flow with nowhere to send it. The database
-- refuses it, so a client that skips the check cannot create that state.
SELECT throws_ok(
  $$UPDATE tbl_event SET bool_use_spws_registration = TRUE WHERE txt_code = 'PAY69NONE'$$,
  NULL, NULL,
  '69.18 — registration cannot be enabled on an event with no resolvable account'
);

-- Enforced as a trigger rather than inside fn_update_event so no caller can
-- route around it -- the admin RPC, a promotion, or a hand-written statement.
SELECT lives_ok(
  $$UPDATE tbl_event SET bool_use_spws_registration = TRUE WHERE txt_code = 'PAY69INHERIT'$$,
  '69.19 — but it can be enabled where the organizer supplies one'
);

-- ----- 69.20–69.21 the admin write path ---------------------------------------
-- The RPC is how an administrator actually sets these, so it must carry them
-- and honour the same "NULL keeps, empty clears" contract as its siblings.
DO $rpc$
DECLARE v_eid INT;
BEGIN
  SELECT id_event INTO v_eid FROM tbl_event WHERE txt_code = 'PAY69INHERIT';
  PERFORM fn_update_event(
    v_eid, 'Inherits the organizer account', NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL::NUMERIC, NULL, NULL, NULL::enum_weapon_type[], NULL, NULL::DATE,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL::NUMERIC, NULL::NUMERIC,
    NULL, NULL,
    'RPC SET PAYEE', 'PL 27 1140 2004 0000 3002 0135 5387'
  );
END $rpc$;

SELECT is(
  (SELECT txt_payment_source::TEXT FROM vw_calendar WHERE txt_code = 'PAY69INHERIT'),
  'EVENT',
  '69.20 — fn_update_event sets the override, and the event now owns its account'
);

DO $rpcclear$
DECLARE v_eid INT;
BEGIN
  SELECT id_event INTO v_eid FROM tbl_event WHERE txt_code = 'PAY69INHERIT';
  PERFORM fn_update_event(
    v_eid, 'Inherits the organizer account', NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL::NUMERIC, NULL, NULL, NULL::enum_weapon_type[], NULL, NULL::DATE,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL::NUMERIC, NULL::NUMERIC,
    NULL, NULL,
    '   ', '  '
  );
END $rpcclear$;

SELECT is(
  (SELECT txt_payment_source::TEXT FROM vw_calendar WHERE txt_code = 'PAY69INHERIT'),
  'ORGANIZER',
  '69.21 — clearing the override falls back to the organizer, and whitespace clears'
);

SELECT * FROM finish();

ROLLBACK;
