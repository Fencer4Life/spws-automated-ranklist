-- =============================================================================
-- pgTAP — Phase 5.5: alias JSONB corruption repair + fn_update_fencer_aliases
--          defence-in-depth
-- =============================================================================
-- Plan-test-ID 5.15 (per /Users/aleks/.claude/plans/tingly-strolling-stearns.md
-- amendment 2026-05-03 — bug found during GP1 rescrape).
--
-- Verifies migration 20260503000005_phase5_5_fix_alias_jsonb_corruption.sql:
--   * 5.15.1 — corrupted JSON-string-wrapped pg-array-literal is repaired
--              to a proper JSONB array.
--   * 5.15.2 — fn_update_fencer_aliases tolerates non-array json_name_aliases
--              (defence in depth).
--   * 5.15.3 — repair is idempotent — already-array rows are unaffected.
--   * 5.15.4 — fn_update_fencer_aliases on a fencer whose column is a
--              non-array (post-repair, simulated) returns a proper array
--              with the new alias appended (no exception, no silent fail).
-- =============================================================================

BEGIN;

SELECT plan(4);

-- 5.15.1 — verify repair: insert a corrupted row, run the repair UPDATE,
-- expect proper array. We can't re-run the migration inside the test, but
-- we can apply the same repair UPDATE the migration ran and see it works.
INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, enum_gender, json_name_aliases)
VALUES ('PGTAP39_CORRUPT', 'Test', 1974, 'M', '"{\"PGTAP39_OLDNAME Test\"}"'::jsonb);

-- Apply the same repair logic the migration uses
UPDATE tbl_fencer
   SET json_name_aliases = array_to_json(
         (json_name_aliases #>> '{}')::TEXT[]
       )::JSONB
 WHERE txt_surname = 'PGTAP39_CORRUPT'
   AND jsonb_typeof(json_name_aliases) = 'string';

SELECT is(
  (SELECT json_name_aliases FROM tbl_fencer WHERE txt_surname = 'PGTAP39_CORRUPT'),
  '["PGTAP39_OLDNAME Test"]'::jsonb,
  '5.15.1 — JSON-string-wrapped pg-array-literal repaired to proper JSONB array'
);

-- 5.15.2 — fn_update_fencer_aliases on a corrupted row would have thrown
-- before the defence patch. Now it should succeed by normalising to [] first.
-- Set up a corrupted row.
INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, enum_gender, json_name_aliases)
VALUES ('PGTAP39_CORRUPT2', 'Test', 1974, 'M', '"corruption"'::jsonb);

-- Get the id
DO $$
DECLARE
  v_id INT;
  v_result JSONB;
BEGIN
  SELECT id_fencer INTO v_id FROM tbl_fencer WHERE txt_surname = 'PGTAP39_CORRUPT2';
  -- This call would throw before the patch; with the patch it normalises to []
  -- and appends the new alias.
  v_result := fn_update_fencer_aliases(v_id, 'NEW_ALIAS_FOR_CORRUPT2');
END;
$$;

SELECT is(
  (SELECT json_name_aliases FROM tbl_fencer WHERE txt_surname = 'PGTAP39_CORRUPT2'),
  '["NEW_ALIAS_FOR_CORRUPT2"]'::jsonb,
  '5.15.2 — fn_update_fencer_aliases normalises non-array column to [] then appends'
);

-- 5.15.3 — repair idempotency: apply the UPDATE again, the array is unchanged.
UPDATE tbl_fencer
   SET json_name_aliases = array_to_json(
         (json_name_aliases #>> '{}')::TEXT[]
       )::JSONB
 WHERE txt_surname = 'PGTAP39_CORRUPT'
   AND jsonb_typeof(json_name_aliases) = 'string';

SELECT is(
  (SELECT json_name_aliases FROM tbl_fencer WHERE txt_surname = 'PGTAP39_CORRUPT'),
  '["PGTAP39_OLDNAME Test"]'::jsonb,
  '5.15.3 — repair is idempotent (already-array rows skipped via WHERE clause)'
);

-- 5.15.4 — fn_update_fencer_aliases dedup still works after the defence
DO $$
DECLARE
  v_id INT;
  v_result JSONB;
BEGIN
  SELECT id_fencer INTO v_id FROM tbl_fencer WHERE txt_surname = 'PGTAP39_CORRUPT2';
  -- Adding the same alias twice should be a no-op (dedup case-insensitive).
  v_result := fn_update_fencer_aliases(v_id, 'NEW_ALIAS_FOR_CORRUPT2');
  v_result := fn_update_fencer_aliases(v_id, 'new_alias_for_corrupt2');
END;
$$;

SELECT is(
  (SELECT jsonb_array_length(json_name_aliases) FROM tbl_fencer WHERE txt_surname = 'PGTAP39_CORRUPT2'),
  1,
  '5.15.4 — dedup still works after defence-in-depth normalisation'
);

SELECT * FROM finish();

ROLLBACK;
