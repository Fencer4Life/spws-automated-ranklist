-- =============================================================================
-- pgTAP — one person, one event, one registration row (matched OR unmatched)
-- =============================================================================
-- Verifies migration 20260828000002_registration_absorb_identity_twin.sql.
--
-- fn_create_registration dedupes on two DIFFERENT arbiters — UNIQUE(id_event,
-- id_fencer) when matched, the partial index uq_registration_unmatched_identity
-- WHERE id_fencer IS NULL when not — and nothing spanned them. A person could
-- therefore hold one row of each kind for the same event, both reaching the
-- public roster and the organizer's seed file.
--
-- Reachable in both directions, and not hypothetically:
--   * unmatched → matched: unmatched registration is the normal path for a
--     newcomer, and their tbl_fencer row is created during the window in which
--     registration is still open (result ingestion of an earlier event, or an
--     administrator adding them by hand).
--   * matched → unmatched: submitIdentity() deliberately treats a failed
--     lookup as "no match" so a network blip never blocks an entry, so a
--     fencer who IS in tbl_fencer can be written unmatched beside their own
--     matched row.
--
-- The fix absorbs the twin instead of inserting beside it. Promotion is
-- preferred over delete-and-insert so ts_created and the consent stamp — the
-- RODO evidence — survive.
-- =============================================================================

BEGIN;

SELECT plan(10);

DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
BEGIN
  v_season := fn_create_season('REG58', '2098-09-01', '2099-06-30');
  INSERT INTO tbl_organizer (txt_code, txt_name)
    VALUES ('REGORG58', 'Reg org 58') RETURNING id_organizer INTO v_org;
  PERFORM fn_create_event('REG58EVT',  'Reg 58 a', v_season, v_org);
  PERFORM fn_create_event('REG58EVT2', 'Reg 58 b', v_season, v_org);

  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, enum_gender)
    VALUES ('PGTAP58', 'Jan', 1966, 'M');
  -- A namesake born in a different year: a different entrant by design.
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, enum_gender)
    VALUES ('PGTAP58', 'Jan', 1977, 'M');
END $setup$;

-- ---------------------------------------------------------------------------
-- 58.1–58.4 — unmatched first, then the same person matched: PROMOTE
-- ---------------------------------------------------------------------------
DO $unmatched_then_matched$
DECLARE v_e INT; v_f INT;
BEGIN
  SELECT id_event  INTO v_e FROM tbl_event  WHERE txt_code = 'REG58EVT';
  SELECT id_fencer INTO v_f FROM tbl_fencer
    WHERE txt_surname='PGTAP58' AND txt_first_name='Jan' AND int_birth_year=1966;

  PERFORM fn_create_registration(v_e,'PGTAP58','Jan','M',1966::SMALLINT,
            ARRAY['EPEE']::enum_weapon_type[], NULL, NULL, 'v1.0');
  PERFORM pg_sleep(0.01);
  PERFORM fn_create_registration(v_e,'PGTAP58','Jan','M',1966::SMALLINT,
            ARRAY['FOIL','SABRE']::enum_weapon_type[], v_f, NULL, NULL);
END $unmatched_then_matched$;

SELECT is(
  (SELECT count(*)::INT FROM tbl_registration r JOIN tbl_event e USING (id_event)
    WHERE e.txt_code='REG58EVT' AND r.txt_surname='PGTAP58' AND r.int_birth_year=1966),
  1,
  '58.1 — unmatched then matched leaves ONE row, not two'
);

SELECT isnt(
  (SELECT r.id_fencer FROM tbl_registration r JOIN tbl_event e USING (id_event)
    WHERE e.txt_code='REG58EVT' AND r.txt_surname='PGTAP58' AND r.int_birth_year=1966),
  NULL,
  '58.2 — the surviving row is the MATCHED one (id_fencer set)'
);

SELECT is(
  (SELECT r.arr_weapons FROM tbl_registration r JOIN tbl_event e USING (id_event)
    WHERE e.txt_code='REG58EVT' AND r.txt_surname='PGTAP58' AND r.int_birth_year=1966),
  ARRAY['FOIL','SABRE']::enum_weapon_type[],
  '58.3 — the later submission wins on the editable fields'
);

-- Promotion, not delete-and-insert: the RODO evidence from the first
-- submission must survive, since that is when consent was actually given.
SELECT isnt(
  (SELECT r.ts_consent FROM tbl_registration r JOIN tbl_event e USING (id_event)
    WHERE e.txt_code='REG58EVT' AND r.txt_surname='PGTAP58' AND r.int_birth_year=1966),
  NULL,
  '58.4 — the original consent stamp survives promotion'
);

-- ---------------------------------------------------------------------------
-- 58.5–58.6 — matched first, then the same person unmatched (lookup failure)
-- ---------------------------------------------------------------------------
DO $matched_then_unmatched$
DECLARE v_e INT; v_f INT;
BEGIN
  SELECT id_event  INTO v_e FROM tbl_event  WHERE txt_code = 'REG58EVT2';
  SELECT id_fencer INTO v_f FROM tbl_fencer
    WHERE txt_surname='PGTAP58' AND txt_first_name='Jan' AND int_birth_year=1966;

  PERFORM fn_create_registration(v_e,'PGTAP58','Jan','M',1966::SMALLINT,
            ARRAY['EPEE']::enum_weapon_type[], v_f, NULL, 'v1.0');
  -- The form's lookup failed this time, so it submits with no fencer link.
  PERFORM fn_create_registration(v_e,'PGTAP58','Jan','M',1966::SMALLINT,
            ARRAY['SABRE']::enum_weapon_type[], NULL, NULL, NULL);
END $matched_then_unmatched$;

SELECT is(
  (SELECT count(*)::INT FROM tbl_registration r JOIN tbl_event e USING (id_event)
    WHERE e.txt_code='REG58EVT2' AND r.txt_surname='PGTAP58'),
  1,
  '58.5 — matched then unmatched leaves ONE row (a lookup blip cannot duplicate)'
);

SELECT isnt(
  (SELECT r.id_fencer FROM tbl_registration r JOIN tbl_event e USING (id_event)
    WHERE e.txt_code='REG58EVT2' AND r.txt_surname='PGTAP58'),
  NULL,
  '58.6 — the fencer link is KEPT, not downgraded by the blip'
);

SELECT is(
  (SELECT r.arr_weapons FROM tbl_registration r JOIN tbl_event e USING (id_event)
    WHERE e.txt_code='REG58EVT2' AND r.txt_surname='PGTAP58'),
  ARRAY['SABRE']::enum_weapon_type[],
  '58.7 — the unmatched submission still updates the editable fields'
);

-- ---------------------------------------------------------------------------
-- 58.8 — absorbing must not reach across events
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT count(*)::INT FROM tbl_registration r JOIN tbl_event e USING (id_event)
    WHERE e.txt_code IN ('REG58EVT','REG58EVT2') AND r.txt_surname='PGTAP58'),
  2,
  '58.8 — one row per event; overlapping registrations stay independent'
);

-- ---------------------------------------------------------------------------
-- 58.9–58.10 — a namesake with a different birth year is a different entrant
-- ---------------------------------------------------------------------------
DO $namesake$
DECLARE v_e INT; v_f INT;
BEGIN
  SELECT id_event  INTO v_e FROM tbl_event  WHERE txt_code = 'REG58EVT';
  SELECT id_fencer INTO v_f FROM tbl_fencer
    WHERE txt_surname='PGTAP58' AND txt_first_name='Jan' AND int_birth_year=1977;
  PERFORM fn_create_registration(v_e,'PGTAP58','Jan','M',1977::SMALLINT,
            ARRAY['EPEE']::enum_weapon_type[], v_f, NULL, 'v1.0');
END $namesake$;

SELECT is(
  (SELECT count(*)::INT FROM tbl_registration r JOIN tbl_event e USING (id_event)
    WHERE e.txt_code='REG58EVT' AND r.txt_surname='PGTAP58'),
  2,
  '58.9 — the namesake keeps their own row, absorption does not swallow them'
);

SELECT is(
  (SELECT count(DISTINCT r.int_birth_year)::INT FROM tbl_registration r
     JOIN tbl_event e USING (id_event)
    WHERE e.txt_code='REG58EVT' AND r.txt_surname='PGTAP58'),
  2,
  '58.10 — and the two rows are distinguished by birth year'
);

SELECT * FROM finish();

ROLLBACK;
