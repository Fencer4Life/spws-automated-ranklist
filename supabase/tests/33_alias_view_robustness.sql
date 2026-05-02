-- =============================================================================
-- pgTAP — Phase 4 follow-up: vw_fencer_aliases scalar-tolerance
-- =============================================================================
-- Verifies the 2026-05-02 fix:
--   * Scalar `json_name_aliases` values do NOT crash the view (alias_count=0)
--   * Array values render correctly (alias_count = jsonb_array_length)
--   * NULL renders as alias_count=0
-- These are the contract the FencerAliasManager UI depends on.
-- =============================================================================

BEGIN;

SELECT plan(6);

-- ---------------------------------------------------------------------------
-- Setup: insert one of each shape directly (skipping the array-shape trigger
-- via DISABLE TRIGGER for the scalar row only — the whole point is that
-- pre-existing seed-corruption rows must be readable, even if the trigger
-- would block them on re-write).
-- ---------------------------------------------------------------------------
INSERT INTO tbl_fencer (id_fencer, txt_surname, txt_first_name)
VALUES (90901, 'PGTAP_ARRAY', 'Test');

INSERT INTO tbl_fencer (id_fencer, txt_surname, txt_first_name)
VALUES (90902, 'PGTAP_NULL', 'Test');

INSERT INTO tbl_fencer (id_fencer, txt_surname, txt_first_name)
VALUES (90903, 'PGTAP_SCALAR', 'Test');

-- Array shape — written through trigger (it accepts arrays).
UPDATE tbl_fencer
   SET json_name_aliases = '["alt-name-1","alt-name-2"]'::jsonb
 WHERE id_fencer = 90901;

-- Scalar shape — bypass the rejection trigger to simulate seed corruption.
ALTER TABLE tbl_fencer DISABLE TRIGGER trg_check_alias_uniqueness;
UPDATE tbl_fencer
   SET json_name_aliases = '"some-scalar-string"'::jsonb
 WHERE id_fencer = 90903;
ALTER TABLE tbl_fencer ENABLE TRIGGER trg_check_alias_uniqueness;

-- ---------------------------------------------------------------------------
-- 33.1 — view query does NOT raise even with a scalar row present
-- ---------------------------------------------------------------------------
SELECT lives_ok(
  $$ SELECT count(*) FROM vw_fencer_aliases $$,
  '33.1 vw_fencer_aliases query survives scalar json_name_aliases (no array-length error)'
);

-- ---------------------------------------------------------------------------
-- 33.2 — array row exposes correct alias_count
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT alias_count FROM vw_fencer_aliases WHERE id_fencer = 90901),
  2,
  '33.2 array-shape json_name_aliases reports alias_count = jsonb_array_length'
);

-- ---------------------------------------------------------------------------
-- 33.3 — NULL row reports alias_count=0
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT alias_count FROM vw_fencer_aliases WHERE id_fencer = 90902),
  0,
  '33.3 NULL json_name_aliases reports alias_count = 0'
);

-- ---------------------------------------------------------------------------
-- 33.4 — scalar row reports alias_count=0 (defensive fallback)
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT alias_count FROM vw_fencer_aliases WHERE id_fencer = 90903),
  0,
  '33.4 scalar json_name_aliases reports alias_count = 0 (defensive fallback)'
);

-- ---------------------------------------------------------------------------
-- 33.5 — scalar row exposes empty array (not the original scalar)
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT json_name_aliases FROM vw_fencer_aliases WHERE id_fencer = 90903),
  '[]'::jsonb,
  '33.5 scalar row''s json_name_aliases coerces to empty array in the view'
);

-- ---------------------------------------------------------------------------
-- 33.6 — fn_list_fencer_aliases RPC also survives the scalar row
-- ---------------------------------------------------------------------------
SELECT lives_ok(
  $$ SELECT count(*) FROM fn_list_fencer_aliases() $$,
  '33.6 fn_list_fencer_aliases RPC survives a scalar json_name_aliases row'
);

-- Cleanup
DELETE FROM tbl_fencer WHERE id_fencer IN (90901, 90902, 90903);

SELECT * FROM finish();
ROLLBACK;
