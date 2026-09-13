-- =============================================================================
-- pgTAP — tbl_registration.txt_club round-trips through both write RPCs and
-- the FTL export projection (ADR-080 amendment (f))
-- =============================================================================
-- Verifies migration 20260913000001_registration_club.sql.
--
-- The club input has existed on the public registration form since Phase 2
-- (2026-07-05) but was decorative: nothing read it, there was no column, and
-- both FTL exporters hardcoded Club="". This file pins the fix end to end:
-- fn_create_registration and fn_update_registration both accept and persist
-- p_club, fn_ftl_export_entries returns it, and — the privacy boundary this
-- whole change turns on — anon still cannot read tbl_registration directly,
-- so widening this one token-gated projection does not widen what the public
-- entry list (vw_registration_entry_list, unaffected, still excludes it per
-- 49.16) publishes to the whole field.
--
-- Plan-test-ID 78 (this file). Complements 49 (schema/column), 57 (trim
-- trigger) and 76 (the projection's own fixture-based club assertions).
-- =============================================================================

BEGIN;

SELECT plan(11);

-- ----- fixtures -----
DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
BEGIN
  v_season := fn_create_season('REG78', '2098-09-01', '2099-06-30');
  INSERT INTO tbl_organizer (txt_code, txt_name)
    VALUES ('REGORG78', 'Reg org 78') RETURNING id_organizer INTO v_org;
  PERFORM fn_create_event('REG78EVT', 'Reg 78', v_season, v_org);
END $setup$;

-- 78.1 — fn_create_registration accepts p_club and persists it, unmatched path
SET LOCAL ROLE anon;
SELECT fn_create_registration(
  (SELECT id_event FROM tbl_event WHERE txt_code = 'REG78EVT'),
  'PGTAP78_NEW'::TEXT, 'Ewa'::TEXT, 'F'::enum_gender_type, 1980::SMALLINT,
  ARRAY['EPEE']::enum_weapon_type[], NULL::INT, NULL::TEXT, NULL::TEXT, NULL::UUID,
  'AZS AWFiS Gdańsk'::TEXT
);
RESET ROLE;

SELECT is(
  (SELECT txt_club FROM tbl_registration WHERE txt_surname = 'PGTAP78_NEW'),
  'AZS AWFiS Gdańsk',
  '78.1 fn_create_registration persists p_club on the unmatched (INSERT) path'
);

-- 78.2 — a caller that omits p_club leaves the row with no club (NULL), not
-- an empty string — same "no value given" contract the trim trigger enforces.
SET LOCAL ROLE anon;
SELECT fn_create_registration(
  (SELECT id_event FROM tbl_event WHERE txt_code = 'REG78EVT'),
  'PGTAP78_NOCLUB'::TEXT, 'Tomasz'::TEXT, 'M'::enum_gender_type, 1981::SMALLINT,
  ARRAY['FOIL']::enum_weapon_type[], NULL::INT, NULL::TEXT, NULL::TEXT, NULL::UUID
);
RESET ROLE;

SELECT is(
  (SELECT txt_club FROM tbl_registration WHERE txt_surname = 'PGTAP78_NOCLUB'),
  NULL,
  '78.2 omitting p_club stores no club at all'
);

-- 78.3 — re-registering the SAME unmatched identity with a club supplied the
-- second time updates it (COALESCE(p_club, txt_club) on the unmatched upsert
-- path), rather than the second submission's silence wiping the first club.
SET LOCAL ROLE anon;
SELECT fn_create_registration(
  (SELECT id_event FROM tbl_event WHERE txt_code = 'REG78EVT'),
  'PGTAP78_NOCLUB'::TEXT, 'Tomasz'::TEXT, 'M'::enum_gender_type, 1981::SMALLINT,
  ARRAY['FOIL', 'EPEE']::enum_weapon_type[], NULL::INT, NULL::TEXT, NULL::TEXT, NULL::UUID,
  'KS Pogoń'::TEXT
);
RESET ROLE;

SELECT is(
  (SELECT txt_club FROM tbl_registration WHERE txt_surname = 'PGTAP78_NOCLUB'),
  'KS Pogoń',
  '78.3 a later submission that DOES supply a club sets it on the upserted row'
);

-- 78.4 — the matched path (p_id_fencer given) persists p_club on first INSERT.
DO $matched_fixture$
DECLARE
  v_fencer INT;
BEGIN
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year)
    VALUES ('PGTAP78MATCH', 'Adam', 1970) RETURNING id_fencer INTO v_fencer;
END $matched_fixture$;

SET LOCAL ROLE anon;
SELECT fn_create_registration(
  (SELECT id_event FROM tbl_event WHERE txt_code = 'REG78EVT'),
  'PGTAP78MATCH'::TEXT, 'Adam'::TEXT, 'M'::enum_gender_type, 1970::SMALLINT,
  ARRAY['SABRE']::enum_weapon_type[],
  (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'PGTAP78MATCH'),
  NULL::TEXT, NULL::TEXT, NULL::UUID, 'MKS Start'::TEXT
);
RESET ROLE;

SELECT is(
  (SELECT txt_club FROM tbl_registration WHERE txt_surname = 'PGTAP78MATCH'),
  'MKS Start',
  '78.4 fn_create_registration persists p_club on the matched (INSERT) path'
);

-- 78.5 — fn_update_registration accepts p_club and SETs it directly (not
-- COALESCEd), so an edit that supplies a club changes it.
DO $update_fixture$
DECLARE
  v_event INT := (SELECT id_event FROM tbl_event WHERE txt_code = 'REG78EVT');
  v_id    INT;
  v_token UUID := gen_random_uuid();
BEGIN
  v_id := fn_create_registration(
    v_event, 'PGTAP78EDIT'::TEXT, 'Beata'::TEXT, 'F'::enum_gender_type, 1975::SMALLINT,
    ARRAY['EPEE']::enum_weapon_type[], NULL::INT, NULL::TEXT, NULL::TEXT, v_token, 'Old Club'::TEXT
  );
  PERFORM fn_update_registration(
    v_id, v_token, 'PGTAP78EDIT'::TEXT, 'Beata'::TEXT, 'F'::enum_gender_type, 1975::SMALLINT,
    ARRAY['EPEE']::enum_weapon_type[], 'New Club'::TEXT
  );
END $update_fixture$;

SELECT is(
  (SELECT txt_club FROM tbl_registration WHERE txt_surname = 'PGTAP78EDIT'),
  'New Club',
  '78.5 fn_update_registration overwrites the club with the new declared value'
);

-- 78.6 — and, unlike the create path's COALESCE, an edit that supplies NULL
-- for p_club actually CLEARS it — the edit path corrects a declaration, it
-- does not merge with what was there before.
DO $update_clears$
DECLARE
  v_event INT := (SELECT id_event FROM tbl_event WHERE txt_code = 'REG78EVT');
  v_id    INT;
  v_token UUID := gen_random_uuid();
BEGIN
  v_id := fn_create_registration(
    v_event, 'PGTAP78CLEAR'::TEXT, 'Cezary'::TEXT, 'M'::enum_gender_type, 1976::SMALLINT,
    ARRAY['EPEE']::enum_weapon_type[], NULL::INT, NULL::TEXT, NULL::TEXT, v_token, 'Some Club'::TEXT
  );
  PERFORM fn_update_registration(
    v_id, v_token, 'PGTAP78CLEAR'::TEXT, 'Cezary'::TEXT, 'M'::enum_gender_type, 1976::SMALLINT,
    ARRAY['EPEE']::enum_weapon_type[], NULL::TEXT
  );
END $update_clears$;

SELECT is(
  (SELECT txt_club FROM tbl_registration WHERE txt_surname = 'PGTAP78CLEAR'),
  NULL,
  '78.6 fn_update_registration with p_club NULL clears a previously declared club'
);

-- 78.7 — fn_ftl_export_entries returns the declared club for a live token.
INSERT INTO tbl_ftl_export_token (uuid_token, txt_label)
  VALUES ('78000000-0000-4000-8000-000000000001', 'pgTAP 78');

SELECT is(
  (SELECT txt_club FROM fn_ftl_export_entries(
     (SELECT id_event FROM tbl_event WHERE txt_code = 'REG78EVT'),
     '78000000-0000-4000-8000-000000000001'::UUID)
   WHERE txt_surname = 'PGTAP78_NEW'),
  'AZS AWFiS Gdańsk',
  '78.7 fn_ftl_export_entries returns the declared club for a live token'
);

-- ---------------------------------------------------------------------------
-- The privacy boundary this whole change turns on.
-- ---------------------------------------------------------------------------

-- 78.8 — anon still cannot read tbl_registration directly (RLS unaffected by
-- adding a column) — the widening is confined to the token-gated projection.
SET LOCAL ROLE anon;
SELECT is(
  (SELECT count(*)::INT FROM tbl_registration WHERE txt_surname = 'PGTAP78_NEW'),
  0,
  '78.8 anon SELECT on tbl_registration still returns zero rows (RLS unaffected)'
);
RESET ROLE;

-- 78.9 — the public entry-list view still excludes the club (belt-and-braces
-- alongside 49.16 — this file's own fixtures prove it holds under real data).
SELECT hasnt_column('vw_registration_entry_list', 'txt_club',
  '78.9 vw_registration_entry_list still excludes txt_club (belt-and-braces with 49.16)');

-- Sanity: the exclusion above is of the COLUMN, not the whole row — the
-- registration itself is still visible on the public entry list.
SELECT ok(
  EXISTS (
    SELECT 1 FROM vw_registration_entry_list
     WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'REG78EVT')
       AND txt_surname = 'PGTAP78_NEW'
  ),
  '78.10 the registration itself is visible on the public entry list (only its club is not)'
);

-- 78.11 — a revoked token gets nothing, club included — same silent-empty
-- contract as every other field on this projection.
UPDATE tbl_ftl_export_token SET ts_revoked = now()
 WHERE uuid_token = '78000000-0000-4000-8000-000000000001';

SELECT is(
  (SELECT count(*)::INT FROM fn_ftl_export_entries(
     (SELECT id_event FROM tbl_event WHERE txt_code = 'REG78EVT'),
     '78000000-0000-4000-8000-000000000001'::UUID)),
  0,
  '78.11 a revoked token returns nothing at all — including no club-bearing rows'
);

SELECT * FROM finish();

ROLLBACK;
