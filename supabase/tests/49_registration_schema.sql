-- =============================================================================
-- FR-120–FR-124 — Event Self-Registration Phase 1: DB schema
-- (ADR-079 §5, ADR-080 §5)
-- =============================================================================
-- tbl_registration (ephemeral, public self-registration record) + 6 new
-- tbl_event columns + RLS (no direct anon writes, controlled RPC only) +
-- public entry-list view (excludes birth year + club, GDPR minimisation) +
-- exact-tuple match RPC (ADR-079 Path A only; fuzzy paths B/C/D deferred).
-- =============================================================================

BEGIN;
SELECT plan(29);

-- 49.1 — tbl_registration exists
SELECT has_table('tbl_registration', '49.1 tbl_registration exists');

-- 49.2–49.5 — key columns exist with the declared-identity shape
SELECT has_column('tbl_registration', 'id_event', '49.2 id_event column exists');
SELECT has_column('tbl_registration', 'id_fencer', '49.3 id_fencer column exists (nullable match)');
SELECT has_column('tbl_registration', 'txt_ftl_name', '49.4 txt_ftl_name column exists (canonical seed name)');
SELECT has_column('tbl_registration', 'txt_email_hash', '49.5 txt_email_hash column exists (salted, abuse log only)');

-- 49.6 — no payment-status tracking (corrected 2026-07-04): this system
-- displays bank-transfer info but does not track whether it's paid — that's
-- checked in person at the venue. Regression guard against re-adding it.
SELECT hasnt_column('tbl_registration', 'enum_payment_status',
                    '49.6 tbl_registration has NO payment-status column (not tracked)');

-- 49.7–49.12 — the 6 new tbl_event columns (FR-121)
SELECT has_column('tbl_event', 'url_entry_list', '49.7 tbl_event.url_entry_list exists');
SELECT has_column('tbl_event', 'txt_organizer_email', '49.8 tbl_event.txt_organizer_email exists');
SELECT has_column('tbl_event', 'ts_ftl_sent', '49.9 tbl_event.ts_ftl_sent exists');
SELECT has_column('tbl_event', 'num_entry_fee_2w', '49.10 tbl_event.num_entry_fee_2w exists');
SELECT has_column('tbl_event', 'num_entry_fee_3w', '49.11 tbl_event.num_entry_fee_3w exists');
SELECT has_column('tbl_event', 'bool_use_spws_registration', '49.12 tbl_event.bool_use_spws_registration exists');

-- ----- fixtures for the behavioural tests below -----
DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
  v_e      INT;
  v_fencer INT;
BEGIN
  v_season := fn_create_season('REG49', '2098-09-01', '2099-06-30');
  INSERT INTO tbl_organizer (txt_code, txt_name)
    VALUES ('REGORG49', 'Reg org 49') RETURNING id_organizer INTO v_org;
  v_e := fn_create_event('REG49EVT', 'Reg 49', v_season, v_org);

  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year)
    VALUES ('KOWALSKI', 'Jan', 1970) RETURNING id_fencer INTO v_fencer;
END $setup$;

-- 49.13 — direct anon INSERT into tbl_registration is denied (no public write policy)
SET LOCAL ROLE anon;
SELECT throws_ok(
  $$INSERT INTO tbl_registration (id_event, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons)
    SELECT id_event, 'NOWAK'::TEXT, 'Anna'::TEXT, 'F'::enum_gender_type, 1975::SMALLINT, ARRAY['EPEE']::enum_weapon_type[]
    FROM tbl_event WHERE txt_code = 'REG49EVT'$$,
  '42501',
  NULL,
  '49.13 direct anon INSERT into tbl_registration denied'
);
RESET ROLE;

-- 49.14 — fn_create_registration RPC succeeds as anon (the only public write path)
-- NOTE: explicit casts are required here — Postgres's function-resolution
-- cannot unify multiple untyped ('unknown') literals against a signature that
-- mixes custom enum types with a trailing NULL, NULL, and throws "function
-- does not exist" without them. This is a raw-SQL-text quirk only (pgTAP
-- tests build queries as text); real callers (PostgREST RPC, Supabase-js)
-- bind parameters with known types over the wire and are unaffected.
SET LOCAL ROLE anon;
SELECT lives_ok(
  $$SELECT fn_create_registration(
      (SELECT id_event FROM tbl_event WHERE txt_code = 'REG49EVT'),
      'NOWAK'::TEXT, 'Anna'::TEXT, 'F'::enum_gender_type, 1975::SMALLINT, ARRAY['EPEE']::enum_weapon_type[],
      NULL::INT, NULL::TEXT
    )$$,
  '49.14 fn_create_registration succeeds as anon (controlled write path)'
);
RESET ROLE;

-- 49.15–49.16 — public entry-list view excludes birth year and club (GDPR minimisation)
SELECT hasnt_column('vw_registration_entry_list', 'int_birth_year',
                    '49.15 vw_registration_entry_list excludes int_birth_year');
SELECT hasnt_column('vw_registration_entry_list', 'txt_club',
                    '49.16 vw_registration_entry_list excludes txt_club');

-- 49.25 — public entry-list view now exposes computed age category (FR-123
-- mockup parity: doc/mockups/registration_entry_list.html shows a "Kat."
-- column + filter; the view never carried it before). int_birth_year itself
-- stays excluded (49.15/49.27) — only the DERIVED category is exposed.
SELECT col_type_is('vw_registration_entry_list', 'enum_age_category', 'enum_age_category',
                    '49.25 vw_registration_entry_list.enum_age_category is enum_age_category');

-- 49.26 — computed value is correct for the 49.14 fixture: NOWAK/Anna born
-- 1975, season REG49 ends 2099-06-30 (end year 2099) => age 124 => V4
-- (fn_age_category has no upper bound on the V4 band).
SELECT is(
  (SELECT enum_age_category::TEXT FROM vw_registration_entry_list
   WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'REG49EVT')
     AND txt_surname = 'NOWAK'),
  'V4',
  '49.26 vw_registration_entry_list computes V4 for NOWAK/1975 in season ending 2099'
);

-- 49.27 — regression guard: adding enum_age_category must not reopen the
-- int_birth_year GDPR exclusion under a different name/alias.
SELECT hasnt_column('vw_registration_entry_list', 'int_birth_year',
                    '49.27 vw_registration_entry_list still excludes int_birth_year after adding age category');

-- 49.17 — anon can read the entry-list view (view owner bypasses the table's
-- restrictive RLS, matching the standard vw_* pattern already used repo-wide)
SET LOCAL ROLE anon;
SELECT lives_ok(
  $$SELECT * FROM vw_registration_entry_list$$,
  '49.17 anon can SELECT vw_registration_entry_list'
);
RESET ROLE;

-- 49.17b — the entry list shows every declared registration, no payment gate
-- (user correction 2026-07-04: we do not track payment completion —
-- bank-transfer info is shown to the fencer, but whether it actually lands
-- is checked in person by the organizer at the venue before the competition
-- starts. The seed/entry-list source of truth is DECLARED INTENT to
-- participate). The 49.14 fixture registration (NOWAK/Anna) must appear here.
SELECT ok(
  EXISTS (
    SELECT 1 FROM vw_registration_entry_list
    WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'REG49EVT')
      AND txt_surname = 'NOWAK'
  ),
  '49.17b entry list includes every declared registration — no payment gate'
);

-- 49.18–49.19 — exact-tuple match RPC (ADR-079 Path A): found vs not found
SELECT is(
  fn_match_registration_fencer('kowalski'::TEXT, 'jan'::TEXT, 1970::SMALLINT),
  (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOWALSKI' AND int_birth_year = 1970),
  '49.18 fn_match_registration_fencer finds exact (case/space-insensitive) match'
);
SELECT is(
  fn_match_registration_fencer('KOWALSKI'::TEXT, 'Jan'::TEXT, 1999::SMALLINT),
  NULL,
  '49.19 fn_match_registration_fencer returns NULL when no exact tuple matches'
);

-- 49.22 — exact-only routing contract (ADR-079 §2, invocation-gap resolution
-- 2026-07-05): a STRONG-name near-miss (surname typo 'KOWALSK', exact first +
-- BY) returns NULL from the form-side matcher, exactly like a total miss. This
-- pins the decision that the public form does NO fuzzy matching: fn_match_
-- registration_fencer is the COMPLETE form-side router (exact triple → Path A
-- skip-email; anything else → email-verify). ADR-079's Paths B/C/D are an
-- INGESTION-time reconciliation model realised by the existing Python
-- find_best_match — never invoked synchronously from the browser. So there is
-- nothing for the public frontend to invoke in Python (the "invocation gap"
-- closes by construction); the step-2 mockup collapses B/C/D into one
-- email-verify screen that explicitly defers "final matching" to ingestion.
SELECT is(
  fn_match_registration_fencer('KOWALSK'::TEXT, 'Jan'::TEXT, 1970::SMALLINT),
  NULL,
  '49.22 strong-name near-miss returns NULL — form does no fuzzy match, routes to email (Path B/C/D resolved at ingestion)'
);

-- 49.20 — UNIQUE(id_event, id_fencer) upsert: re-registering the SAME matched
-- fencer for the SAME event updates the existing row, never duplicates it
SELECT is(
  (SELECT count(*)::INT FROM tbl_registration
     WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'REG49EVT')
       AND id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOWALSKI' AND int_birth_year = 1970)),
  0,
  '49.20a sanity: no registration yet for the matched KOWALSKI/REG49EVT pair'
);

DO $reg_twice$
DECLARE
  v_event  INT := (SELECT id_event FROM tbl_event WHERE txt_code = 'REG49EVT');
  v_fencer INT := (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOWALSKI' AND int_birth_year = 1970);
BEGIN
  PERFORM fn_create_registration(v_event, 'KOWALSKI'::TEXT, 'Jan'::TEXT, 'M'::enum_gender_type, 1970::SMALLINT, ARRAY['EPEE']::enum_weapon_type[], v_fencer, NULL::TEXT);
  PERFORM fn_create_registration(v_event, 'KOWALSKI'::TEXT, 'Jan'::TEXT, 'M'::enum_gender_type, 1970::SMALLINT, ARRAY['EPEE','SABRE']::enum_weapon_type[], v_fencer, NULL::TEXT);
END $reg_twice$;

SELECT is(
  (SELECT count(*)::INT FROM tbl_registration
     WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'REG49EVT')
       AND id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOWALSKI' AND int_birth_year = 1970)),
  1,
  '49.20b registering the same matched fencer twice upserts (still exactly 1 row)'
);

-- 49.21 — two NULL-id_fencer registrations for the SAME event never falsely
-- collide (Postgres treats NULLs as distinct under a plain UNIQUE constraint)
DO $reg_two_nulls$
DECLARE
  v_event INT := (SELECT id_event FROM tbl_event WHERE txt_code = 'REG49EVT');
BEGIN
  PERFORM fn_create_registration(v_event, 'ZIELINSKI'::TEXT, 'Piotr'::TEXT, 'M'::enum_gender_type, 1980::SMALLINT, ARRAY['FOIL']::enum_weapon_type[], NULL::INT, NULL::TEXT);
  PERFORM fn_create_registration(v_event, 'MAZUR'::TEXT, 'Tomasz'::TEXT, 'M'::enum_gender_type, 1981::SMALLINT, ARRAY['FOIL']::enum_weapon_type[], NULL::INT, NULL::TEXT);
END $reg_two_nulls$;

SELECT is(
  (SELECT count(*)::INT FROM tbl_registration
     WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'REG49EVT')
       AND id_fencer IS NULL),
  3,
  '49.21 two unmatched (NULL id_fencer) registrations + the 49.14 fixture row = 3, never collided'
);

-- ----- P2.0 fixtures: a second event with a PAST registration window -----
DO $setup_past$
DECLARE
  v_season INT;
  v_org    INT;
BEGIN
  v_season := fn_create_season('REG49P', '2020-01-01', '2020-12-31');
  INSERT INTO tbl_organizer (txt_code, txt_name)
    VALUES ('REGORG49P', 'Reg org 49 past') RETURNING id_organizer INTO v_org;
  PERFORM fn_create_event(
    'REG49PAST', 'Reg 49 past', v_season, v_org,
    p_dt_start := '2020-06-01'::DATE
  );
END $setup_past$;

-- 49.23 — consent recorded (D5): passing p_consent_version stamps ts_consent
-- + txt_consent_version on the write.
DO $consent$
DECLARE
  v_event INT := (SELECT id_event FROM tbl_event WHERE txt_code = 'REG49EVT');
BEGIN
  PERFORM fn_create_registration(
    v_event, 'PIOTROWSKI'::TEXT, 'Ewa'::TEXT, 'F'::enum_gender_type, 1972::SMALLINT,
    ARRAY['FOIL']::enum_weapon_type[], NULL::INT, NULL::TEXT, 'v1.0'::TEXT
  );
END $consent$;

SELECT ok(
  EXISTS (
    SELECT 1 FROM tbl_registration
    WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'REG49EVT')
      AND txt_surname = 'PIOTROWSKI'
      AND ts_consent IS NOT NULL
      AND txt_consent_version = 'v1.0'
  ),
  '49.23 fn_create_registration stamps ts_consent + txt_consent_version when p_consent_version is given'
);

-- 49.24 — expiry guard (D10): a write against an event whose registration
-- window (COALESCE(dt_registration_deadline, dt_start)) is already in the
-- past is rejected. REG49EVT (NULL dates, 49.13/.14 etc.) stays unaffected —
-- proving NULL-date events remain open.
SELECT throws_ok(
  $$SELECT fn_create_registration(
      (SELECT id_event FROM tbl_event WHERE txt_code = 'REG49PAST'),
      'SPÓŹNIONY'::TEXT, 'Adam'::TEXT, 'M'::enum_gender_type, 1975::SMALLINT,
      ARRAY['SABRE']::enum_weapon_type[], NULL::INT, NULL::TEXT, NULL::TEXT
    )$$,
  'P0001',
  NULL,
  '49.24 fn_create_registration rejects a write past the registration window (D10)'
);

SELECT * FROM finish();
ROLLBACK;
