-- =============================================================================
-- pgTAP — Phase 5.5: tbl_fencer.txt_surname / txt_first_name auto-trim trigger
-- =============================================================================
-- Plan-test-ID 5.14 (per /Users/aleks/.claude/plans/tingly-strolling-stearns.md)
-- Verifies migration 20260503000004_phase5_fencer_trim_trigger.sql:
--   * trg_trim_fencer_names exists on tbl_fencer (BEFORE INSERT OR UPDATE)
--   * INSERT with ' Bartosz' → row stored as 'Bartosz'
--   * INSERT with 'BURLIKOWSKI ' → row stored as 'BURLIKOWSKI'
--   * UPDATE that introduces whitespace also gets trimmed
--   * Defence-in-depth complement to phase5_runner's seed-export .strip().
--   * NAMECASE.01–04 (D5 A, 25 Oct 2026): a first name written in capitals
--     is stored with initial capitals, Polish letters included; a mixed-case
--     name, a one-letter initial and the surname are never changed.
-- =============================================================================

BEGIN;

SELECT plan(9);

-- 5.14.1 — trigger function exists
SELECT has_function(
  'fn_trim_fencer_names',
  '5.14.1 — fn_trim_fencer_names() exists'
);

-- 5.14.2 — trigger is wired BEFORE INSERT OR UPDATE on tbl_fencer
SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_trigger
     WHERE tgname = 'trg_trim_fencer_names'
       AND tgrelid = 'tbl_fencer'::regclass
  ),
  '5.14.2 — trg_trim_fencer_names trigger present on tbl_fencer'
);

-- 5.14.3 — INSERT with leading-space first_name gets trimmed
INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, enum_gender)
VALUES ('PGTAP38_TRIM', '  Bartosz', 1974, 'M');

SELECT is(
  (SELECT txt_first_name FROM tbl_fencer WHERE txt_surname = 'PGTAP38_TRIM'),
  'Bartosz',
  '5.14.3 — leading whitespace on first_name stripped on INSERT'
);

-- 5.14.4 — INSERT with trailing-space surname gets trimmed
INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, enum_gender)
VALUES ('PGTAP38_TRAIL  ', 'Anna', 1980, 'F');

SELECT is(
  (SELECT txt_surname FROM tbl_fencer WHERE txt_first_name = 'Anna' AND int_birth_year = 1980),
  'PGTAP38_TRAIL',
  '5.14.4 — trailing whitespace on surname stripped on INSERT'
);

-- 5.14.5 — UPDATE that introduces whitespace also gets trimmed
INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, enum_gender)
VALUES ('PGTAP38_UPD', 'OK', 1970, 'M');
UPDATE tbl_fencer SET txt_first_name = '   OK Updated   ' WHERE txt_surname = 'PGTAP38_UPD';

SELECT is(
  (SELECT txt_first_name FROM tbl_fencer WHERE txt_surname = 'PGTAP38_UPD'),
  'OK Updated',
  '5.14.5 — whitespace on UPDATE also stripped'
);

-- NAMECASE.01 — a first name in capitals gets initial capitals on INSERT
INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, enum_gender)
VALUES ('PGTAP38_CAPS', 'EMILIA', 1981, 'F');

SELECT is(
  (SELECT txt_first_name FROM tbl_fencer WHERE txt_surname = 'PGTAP38_CAPS'),
  'Emilia',
  'NAMECASE.01 — a first name in capitals is stored as Emilia'
);

-- NAMECASE.02 — Polish letters, two given names and a hyphen, on UPDATE too
UPDATE tbl_fencer SET txt_first_name = 'ŁUCJA ŻANETA-MARIA' WHERE txt_surname = 'PGTAP38_CAPS';

SELECT is(
  (SELECT txt_first_name FROM tbl_fencer WHERE txt_surname = 'PGTAP38_CAPS'),
  'Łucja Żaneta-Maria',
  'NAMECASE.02 — Polish letters, two names and a hyphen, on UPDATE'
);

-- NAMECASE.03 — a mixed-case name and a one-letter initial are kept
INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, enum_gender)
VALUES ('PGTAP38_MIXED', 'DeShawn', 1975, 'M'),
       ('PGTAP38_INITIAL', 'J', 1976, 'M');

SELECT is(
  (SELECT string_agg(txt_first_name, ',' ORDER BY txt_surname) FROM tbl_fencer
    WHERE txt_surname IN ('PGTAP38_MIXED', 'PGTAP38_INITIAL')),
  'J,DeShawn',
  'NAMECASE.03 — a mixed-case name and a one-letter initial are kept'
);

-- NAMECASE.04 — the surname keeps its capitals
SELECT is(
  (SELECT txt_surname FROM tbl_fencer WHERE txt_first_name = 'Łucja Żaneta-Maria'),
  'PGTAP38_CAPS',
  'NAMECASE.04 — the surname is never changed'
);

SELECT * FROM finish();

ROLLBACK;
