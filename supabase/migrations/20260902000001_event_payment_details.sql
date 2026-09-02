-- =============================================================================
-- Per-event payment details: an organizer default, an event override, a vetted
-- IBAN, and a registration toggle that cannot be switched on without an account
-- =============================================================================
-- One account number served every event, compiled into the frontend bundle as
-- SPWS_PAYEE / SPWS_IBAN in lib/orgPayment.ts. The `payee` / `iban` props on
-- <spws-registration> existed but nothing set them: register.html passed empty
-- strings and the calendar modal passed nothing. Organizers other than SPWS
-- need their own account, and individual events occasionally override it.
--
-- The system never handles the money. It displays transfer instructions and
-- deliberately does not track whether a transfer arrives, which the organizer
-- verifies in person at the venue (ADR-079 section 4). What it publishes is the
-- account a fencer is asked to pay into -- which is exactly why the number is
-- vetted rather than trusted: a wrong value sends the fencer's own transfer
-- astray, printed under a label saying IBAN and copied with one tap. On
-- 2026-09-02 the stored value turned out to be the domestic NRB, scoring 73 on
-- mod-97 instead of 1.
--
-- ONE DEFINITION OF ABSENT. NULL, the empty string and whitespace-only are the
-- same thing, normalised on write by a trigger so every caller is covered --
-- the idiom already used by trg_trim_fencer_names and trg_trim_registration_names.
-- Without it a payee of '   ' would satisfy the toggle guard, and a field
-- cleared in the editor would silently mean "locked against the CERT sync"
-- while looking identical to one that was never filled. The consequence,
-- accepted deliberately: a field cannot be locked empty on PROD, so removing an
-- account permanently means clearing it on both sides.
--
-- Plan-test-ID 69 (supabase/tests/69_event_payment_details.sql).
-- =============================================================================

BEGIN;

SET LOCAL lock_timeout = '2s';

-- 1. The IBAN rule, in the database, so no path can store an invalid value.
--    IMMUTABLE because a CHECK constraint may only call immutable functions.
--    NUMERIC carries the expanded value exactly -- it reaches ~68 digits, far
--    beyond a bigint, and rounding here would silently accept bad accounts.
CREATE OR REPLACE FUNCTION fn_is_valid_iban(p_iban TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_compact  TEXT;
  v_rotated  TEXT;
  v_expanded TEXT := '';
  v_ch       TEXT;
BEGIN
  IF p_iban IS NULL OR btrim(p_iban) = '' THEN
    RETURN FALSE;
  END IF;

  v_compact := upper(regexp_replace(p_iban, '\s', '', 'g'));

  -- Country code, two check digits, then 1..30 more. 34 is the ISO maximum;
  -- Poland uses 28.
  IF v_compact !~ '^[A-Z]{2}[0-9]{2}[A-Z0-9]{1,30}$' THEN
    RETURN FALSE;
  END IF;

  v_rotated := substr(v_compact, 5) || substr(v_compact, 1, 4);

  FOR i IN 1..length(v_rotated) LOOP
    v_ch := substr(v_rotated, i, 1);
    IF v_ch ~ '[A-Z]' THEN
      v_expanded := v_expanded || (ascii(v_ch) - 55)::TEXT;
    ELSE
      v_expanded := v_expanded || v_ch;
    END IF;
  END LOOP;

  RETURN mod(v_expanded::NUMERIC, 97) = 1;
END;
$$;

-- Not part of the public surface. anon holds no write privilege on either
-- table, so it can never reach these constraints; ADR-083's allowlist is an
-- equality, and a helper nobody calls from the browser does not belong in it.
-- authenticated keeps EXECUTE because an administrator's own UPDATE evaluates
-- the CHECK as themselves.
REVOKE ALL ON FUNCTION fn_is_valid_iban(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION fn_is_valid_iban(TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION fn_is_valid_iban(TEXT) TO authenticated;

COMMENT ON FUNCTION fn_is_valid_iban IS
  'ISO 13616 IBAN validity: rotate the first four characters to the end, map '
  'letters to numbers (A=10..Z=35), require mod 97 = 1. Deliberately NOT '
  'Poland-specific -- an organizer abroad is plausible and rejecting a valid '
  'foreign IBAN would be a defect of our own making.';

-- 2. Columns. The organizer holds the default; the event overrides it.
ALTER TABLE tbl_organizer
  ADD COLUMN IF NOT EXISTS txt_payee TEXT,
  ADD COLUMN IF NOT EXISTS txt_iban  TEXT;

ALTER TABLE tbl_event
  ADD COLUMN IF NOT EXISTS txt_payee TEXT,
  ADD COLUMN IF NOT EXISTS txt_iban  TEXT;

COMMENT ON COLUMN tbl_organizer.txt_iban IS
  'Organizer default account. Used by every event of this organizer that does '
  'not override it.';
COMMENT ON COLUMN tbl_event.txt_iban IS
  'Per-event override. NULL means inherit the organizer default. Admin '
  'enrichment for CERT->PROD purposes: fill-blank, so a PROD value stands.';

-- 3. Blank is blank. Normalise before the CHECK runs, so '   ' becomes NULL
--    rather than failing validation as a malformed IBAN.
CREATE OR REPLACE FUNCTION fn_normalise_payment_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.txt_payee := NULLIF(btrim(COALESCE(NEW.txt_payee, '')), '');
  NEW.txt_iban  := NULLIF(btrim(COALESCE(NEW.txt_iban,  '')), '');
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_normalise_payment_fields IS
  'Collapses NULL, empty and whitespace-only payment fields to NULL on write so '
  'one definition of "absent" serves the resolution, the toggle guard and the '
  'CERT->PROD fill-blank policy alike.';

DROP TRIGGER IF EXISTS trg_normalise_organizer_payment ON tbl_organizer;
CREATE TRIGGER trg_normalise_organizer_payment
  BEFORE INSERT OR UPDATE OF txt_payee, txt_iban ON tbl_organizer
  FOR EACH ROW EXECUTE FUNCTION fn_normalise_payment_fields();

DROP TRIGGER IF EXISTS trg_normalise_event_payment ON tbl_event;
CREATE TRIGGER trg_normalise_event_payment
  BEFORE INSERT OR UPDATE OF txt_payee, txt_iban ON tbl_event
  FOR EACH ROW EXECUTE FUNCTION fn_normalise_payment_fields();

-- 4. The constraints. NULL is allowed -- absent is a legitimate state; a
--    present value must be a real IBAN.
ALTER TABLE tbl_organizer
  DROP CONSTRAINT IF EXISTS chk_organizer_iban_valid,
  ADD  CONSTRAINT chk_organizer_iban_valid
       CHECK (txt_iban IS NULL OR fn_is_valid_iban(txt_iban));

ALTER TABLE tbl_event
  DROP CONSTRAINT IF EXISTS chk_event_iban_valid,
  ADD  CONSTRAINT chk_event_iban_valid
       CHECK (txt_iban IS NULL OR fn_is_valid_iban(txt_iban));

-- 5. One-off seed: the two values that lived in lib/orgPayment.ts move onto the
--    SPWS organizer row, so deleting the module changes nothing a fencer sees.
--    Guarded, so it fills an empty column and never overwrites a value an
--    administrator has since changed -- CI and reset-dev.sh replay this file
--    against a fresh database, while CERT and PROD apply it once.
UPDATE tbl_organizer
   SET txt_payee = 'STOWARZYSZENIE POLSKICH WETERANOW SZERMIERKI',
       txt_iban  = 'PL 06 1090 1665 0000 0001 5004 1549'
 WHERE txt_code = 'SPWS'
   AND txt_iban IS NULL;

-- 6. The toggle guard. Enabling registration with nowhere to pay is a
--    configuration mistake rather than a legitimate state: the fee cannot be
--    quoted against anything and the entrant reaches the end of the flow with
--    nowhere to send it. A trigger rather than a check inside fn_update_event,
--    so no caller can route around it -- not the admin RPC, not a promotion,
--    not a hand-written statement.
CREATE OR REPLACE FUNCTION fn_assert_registration_has_account()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_payee TEXT;
  v_iban  TEXT;
BEGIN
  IF NOT NEW.bool_use_spws_registration THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(NEW.txt_payee, o.txt_payee), COALESCE(NEW.txt_iban, o.txt_iban)
    INTO v_payee, v_iban
    FROM tbl_organizer o
   WHERE o.id_organizer = NEW.id_organizer;

  IF v_payee IS NULL OR v_iban IS NULL THEN
    RAISE EXCEPTION
      'Event % has SPWS registration enabled but no payment account resolves '
      '(neither the event nor its organizer supplies a payee and IBAN)',
      NEW.txt_code;
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_assert_registration_has_account IS
  'Refuses bool_use_spws_registration = TRUE unless a payee AND an IBAN resolve '
  'from the event or its organizer. Registration exists to support collecting a '
  'fee; enabling it with no account is a misconfiguration that surfaces later, '
  'for the fencer.';

DROP TRIGGER IF EXISTS trg_registration_needs_account ON tbl_event;
CREATE TRIGGER trg_registration_needs_account
  BEFORE INSERT OR UPDATE OF bool_use_spws_registration, txt_payee, txt_iban, id_organizer
  ON tbl_event
  FOR EACH ROW EXECUTE FUNCTION fn_assert_registration_has_account();

-- 7. Fail loudly if any event already has registration on but no account. The
--    seed above must have covered them; if it has not, the deploy stops here
--    rather than leaving a live event in a state the new rule forbids.
DO $guard$
DECLARE v_bad TEXT;
BEGIN
  SELECT string_agg(e.txt_code, ', ')
    INTO v_bad
    FROM tbl_event e
    LEFT JOIN tbl_organizer o ON o.id_organizer = e.id_organizer
   WHERE e.bool_use_spws_registration
     AND (COALESCE(e.txt_payee, o.txt_payee) IS NULL
       OR COALESCE(e.txt_iban,  o.txt_iban)  IS NULL);

  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION
      'Cannot arm the payment-account rule: registration is already enabled '
      'without a resolvable account on %', v_bad;
  END IF;
END $guard$;

-- 8. Rebuild vw_calendar so the resolved account and its source are visible.
--    Standing rule: a new tbl_event column means rebuilding this view. The page
--    is handed one answer rather than a chain to walk, and txt_payment_source
--    lets the admin UI state which level answered instead of inferring it from
--    whether a field looks empty.
DROP VIEW IF EXISTS vw_calendar;
CREATE VIEW vw_calendar AS
SELECT e.id_event,
    e.txt_code,
    e.txt_name,
    e.id_season,
    s.txt_code AS txt_season_code,
    e.id_organizer,
    o.txt_name AS txt_organizer_name,
    e.txt_location,
    e.txt_country,
    e.txt_venue_address,
    e.url_invitation,
    e.num_entry_fee,
    e.txt_entry_fee_currency,
    e.arr_weapons,
    e.dt_start,
    e.dt_end,
    e.url_event,
    e.enum_status,
    e.url_registration,
    e.dt_registration_deadline,
    e.url_event_2,
    e.url_event_3,
    e.url_event_4,
    e.url_event_5,
    e.id_evf_event,
    e.txt_evf_slug,
    e.id_evf_calendar_event,
    e.id_prior_event,
    count(t.id_tournament)::integer AS num_tournaments,
    COALESCE(bool_or(t.enum_type = ANY (ARRAY['PEW'::enum_tournament_type, 'MEW'::enum_tournament_type, 'MSW'::enum_tournament_type, 'PSW'::enum_tournament_type])), false) AS bool_has_international,
    e.json_ingest_sources,
    e.json_source_overrides,
    e.url_entry_list,
    e.txt_organizer_email,
    e.ts_ftl_sent,
    e.num_entry_fee_2w,
    e.num_entry_fee_3w,
    e.bool_use_spws_registration,
    e.dt_start_first_published,
    e.txt_payee AS txt_event_payee,
    e.txt_iban AS txt_event_iban,
    COALESCE(e.txt_payee, o.txt_payee) AS txt_payee,
    COALESCE(e.txt_iban, o.txt_iban) AS txt_iban,
    CASE
      WHEN e.txt_payee IS NOT NULL AND e.txt_iban IS NOT NULL THEN 'EVENT'
      WHEN o.txt_payee IS NOT NULL AND o.txt_iban IS NOT NULL THEN 'ORGANIZER'
      ELSE 'NONE'
    END AS txt_payment_source
   FROM tbl_event e
     JOIN tbl_season s ON s.id_season = e.id_season
     LEFT JOIN tbl_organizer o ON o.id_organizer = e.id_organizer
     LEFT JOIN tbl_tournament t ON t.id_event = e.id_event
  GROUP BY e.id_event, s.txt_code, o.txt_name, o.txt_payee, o.txt_iban
  ORDER BY e.dt_start;

GRANT SELECT ON vw_calendar TO anon;
GRANT SELECT ON vw_calendar TO authenticated;

COMMIT;
