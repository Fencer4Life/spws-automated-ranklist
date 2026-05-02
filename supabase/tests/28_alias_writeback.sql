-- =============================================================================
-- Phase 3 (ADR-050) — fn_update_fencer_aliases RPC
--
-- Used by Stage 6 of the unified pipeline: when an admin USER_CONFIRMS a
-- fuzzy-match decision (linking a scraped name like "J. Smith" to fencer
-- "John SMITH"), the matched scraped variant is appended to that fencer's
-- json_name_aliases array. Future imports auto-match against the alias.
--
-- Tests:
--   28.1   function exists with (INT, TEXT) signature
--   28.2   returns JSONB
--   28.3   appends alias to existing array
--   28.4   initializes NULL json_name_aliases as ['<alias>']
--   28.5   deduplicates (case-insensitive) — same alias not added twice
--   28.6   trims whitespace from alias before storing
--   28.7   rejects empty/whitespace-only alias (returns array unchanged + warning)
--   28.8   returns updated array in JSONB result
-- =============================================================================

BEGIN;
SELECT plan(8);


-- ===== 28.1 — function exists =====
SELECT has_function(
  'fn_update_fencer_aliases',
  ARRAY['integer', 'text'],
  '28.1: fn_update_fencer_aliases(INT, TEXT) exists'
);


-- ===== 28.2 — returns JSONB =====
SELECT function_returns(
  'fn_update_fencer_aliases',
  ARRAY['integer', 'text'],
  'jsonb',
  '28.2: fn_update_fencer_aliases returns JSONB'
);


-- =============================================================================
-- Fixture: 3 fencers in three states for the behaviour tests.
--   F1: NULL json_name_aliases (test 28.4)
--   F2: ['Existing Alias'] (tests 28.3, 28.5, 28.8)
--   F3: ['Whitespace Test'] (test 28.6)
-- =============================================================================
DO $fix$
BEGIN
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, json_name_aliases)
  VALUES ('ALIAS28', 'F1-NullArr', 1970, NULL);

  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, json_name_aliases)
  VALUES ('ALIAS28', 'F2-Existing', 1971, '["Existing Alias"]'::JSONB);

  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, json_name_aliases)
  VALUES ('ALIAS28', 'F3-Whitespace', 1972, '["Whitespace Test"]'::JSONB);
END;
$fix$;


-- ===== 28.3 — appends to existing array =====
SELECT fn_update_fencer_aliases(
  (SELECT id_fencer FROM tbl_fencer WHERE txt_first_name='F2-Existing' AND txt_surname='ALIAS28'),
  'New Alias'
) AS r1 \gset

SELECT is(
  (SELECT json_name_aliases FROM tbl_fencer
    WHERE txt_first_name='F2-Existing' AND txt_surname='ALIAS28'),
  '["Existing Alias", "New Alias"]'::JSONB,
  '28.3: append adds new alias to existing array'
);


-- ===== 28.4 — initializes NULL as ['<alias>'] =====
SELECT fn_update_fencer_aliases(
  (SELECT id_fencer FROM tbl_fencer WHERE txt_first_name='F1-NullArr' AND txt_surname='ALIAS28'),
  'First Alias'
) AS r2 \gset

SELECT is(
  (SELECT json_name_aliases FROM tbl_fencer
    WHERE txt_first_name='F1-NullArr' AND txt_surname='ALIAS28'),
  '["First Alias"]'::JSONB,
  '28.4: NULL json_name_aliases initialized to single-element array'
);


-- ===== 28.5 — deduplicates case-insensitively =====
SELECT fn_update_fencer_aliases(
  (SELECT id_fencer FROM tbl_fencer WHERE txt_first_name='F2-Existing' AND txt_surname='ALIAS28'),
  'EXISTING ALIAS'  -- different case from existing 'Existing Alias'
) AS r3 \gset

SELECT is(
  (SELECT jsonb_array_length(json_name_aliases) FROM tbl_fencer
    WHERE txt_first_name='F2-Existing' AND txt_surname='ALIAS28'),
  2,  -- still 2 entries (Existing Alias, New Alias from 28.3) — not 3
  '28.5: deduplicates case-insensitively (no duplicate added)'
);


-- ===== 28.6 — trims whitespace =====
SELECT fn_update_fencer_aliases(
  (SELECT id_fencer FROM tbl_fencer WHERE txt_first_name='F3-Whitespace' AND txt_surname='ALIAS28'),
  '  Padded Alias  '
) AS r4 \gset

SELECT is(
  (SELECT json_name_aliases FROM tbl_fencer
    WHERE txt_first_name='F3-Whitespace' AND txt_surname='ALIAS28'),
  '["Whitespace Test", "Padded Alias"]'::JSONB,
  '28.6: trims leading/trailing whitespace from alias before storing'
);


-- ===== 28.7 — empty alias is no-op =====
SELECT fn_update_fencer_aliases(
  (SELECT id_fencer FROM tbl_fencer WHERE txt_first_name='F3-Whitespace' AND txt_surname='ALIAS28'),
  '   '
) AS r5 \gset

SELECT is(
  (SELECT jsonb_array_length(json_name_aliases) FROM tbl_fencer
    WHERE txt_first_name='F3-Whitespace' AND txt_surname='ALIAS28'),
  2,  -- still 2: 'Whitespace Test' + 'Padded Alias'
  '28.7: empty/whitespace-only alias is rejected (array unchanged)'
);


-- ===== 28.8 — returns updated array =====
SELECT is(
  (SELECT fn_update_fencer_aliases(
    (SELECT id_fencer FROM tbl_fencer WHERE txt_first_name='F2-Existing' AND txt_surname='ALIAS28'),
    'Yet Another'
  )),
  '["Existing Alias", "New Alias", "Yet Another"]'::JSONB,
  '28.8: function return value matches the updated json_name_aliases'
);


SELECT * FROM finish();
ROLLBACK;
