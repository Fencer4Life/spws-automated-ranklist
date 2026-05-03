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
-- =============================================================================

BEGIN;

SELECT plan(5);

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

SELECT * FROM finish();

ROLLBACK;
