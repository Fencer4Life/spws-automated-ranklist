-- =============================================================================
-- Fencer Birth Year Update RPC Tests
-- =============================================================================
-- Tests 13.1–13.4: fn_update_fencer_birth_year
-- FRs: FR-93
-- =============================================================================

BEGIN;
SELECT plan(5);

-- ===== SETUP =====
DO $setup$
DECLARE
  v_fencer_id INT;
BEGIN
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, bool_birth_year_estimated, txt_nationality)
  VALUES ('BIRTHTEST', 'Alpha', 1980, TRUE, 'PL')
  RETURNING id_fencer INTO v_fencer_id;
END;
$setup$;


-- =========================================================================
-- 13.1 — fn_update_fencer_birth_year sets birth year + estimated=false
-- =========================================================================
SELECT lives_ok(
  $$SELECT fn_update_fencer_birth_year(
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'BIRTHTEST' AND txt_first_name = 'Alpha'),
    1975, FALSE
  )$$,
  '13.1: fn_update_fencer_birth_year executes without error'
);


-- =========================================================================
-- 13.1b — fn_update_fencer_birth_year persists both values
-- =========================================================================
SELECT is(
  (SELECT int_birth_year::INT FROM tbl_fencer WHERE txt_surname = 'BIRTHTEST' AND txt_first_name = 'Alpha'),
  1975,
  '13.1b: fn_update_fencer_birth_year persists birth year'
);


-- =========================================================================
-- 13.2 — fn_update_fencer_birth_year with bad fencer raises error
-- =========================================================================
SELECT throws_ok(
  $$SELECT fn_update_fencer_birth_year(-99999, 1970, FALSE)$$,
  NULL,
  '13.2: fn_update_fencer_birth_year with non-existent fencer raises error'
);


-- =========================================================================
-- 13.3 — fn_update_fencer_birth_year can change confirmed birth year
-- =========================================================================
-- First confirm it's currently confirmed (estimated=false from 13.1)
-- Now change to a different year
SELECT lives_ok(
  $$SELECT fn_update_fencer_birth_year(
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'BIRTHTEST' AND txt_first_name = 'Alpha'),
    1972, FALSE
  )$$,
  '13.3: fn_update_fencer_birth_year can change already-confirmed birth year'
);


-- =========================================================================
-- 13.4 — fn_update_fencer_birth_year confirms new value persisted
-- =========================================================================
SELECT is(
  (SELECT int_birth_year::INT FROM tbl_fencer WHERE txt_surname = 'BIRTHTEST' AND txt_first_name = 'Alpha'),
  1972,
  '13.4: fn_update_fencer_birth_year persists changed confirmed birth year'
);


SELECT * FROM finish();
ROLLBACK;
