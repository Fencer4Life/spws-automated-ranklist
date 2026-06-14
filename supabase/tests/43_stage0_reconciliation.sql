-- =============================================================================
-- Stage 0 — Roster reconciliation (ADR-050 / ADR-056 / ADR-010 / ADR-038)
-- =============================================================================
-- Tests 43.1–43.10: the DB-side contract Stage 0 relies on —
--   * fn_update_fencer_birth_year estimated→estimated re-estimate (keep flag)
--   * fn_update_fencer_birth_year confirmed→estimated downgrade (flip flag)
--   * trg_audit_fencer preserves the prior birth year for restore
--   * plain tbl_fencer INSERT: NULL BY allowed (V-cat unknown) + midpoint BY
--     with bool_birth_year_estimated = TRUE persists
-- Stage 0 itself creates new participants via a plain INSERT (high-precision
-- exact dedup happens in Python) and reconciles via this RPC, so this file
-- pins the SQL surface those two operations stand on.
-- =============================================================================

BEGIN;
SELECT plan(10);

-- ===== SETUP =====
DO $setup$
BEGIN
  -- Estimated fencer in the WRONG band (BY 1991 → V0), to be re-estimated to V2.
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year,
                          bool_birth_year_estimated, txt_nationality)
  VALUES ('RECONEST', 'Alpha', 1991, TRUE, 'PL');

  -- CONFIRMED fencer in the WRONG band (BY 1991 → V0), to be downgraded to V3.
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year,
                          bool_birth_year_estimated, txt_nationality)
  VALUES ('RECONCONF', 'Beta', 1991, FALSE, 'PL');
END;
$setup$;


-- =========================================================================
-- 43.1–43.3 — estimated conflict → re-estimate to band midpoint, keep flag
-- =========================================================================
SELECT lives_ok(
  $$SELECT fn_update_fencer_birth_year(
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname='RECONEST'),
    1971, TRUE
  )$$,
  '43.1: re-estimate estimated BY executes'
);

SELECT is(
  (SELECT int_birth_year::INT FROM tbl_fencer WHERE txt_surname='RECONEST'),
  1971,
  '43.2: re-estimated BY persisted (V2 midpoint)'
);

SELECT is(
  (SELECT bool_birth_year_estimated FROM tbl_fencer WHERE txt_surname='RECONEST'),
  TRUE,
  '43.3: re-estimated fencer keeps estimated=TRUE'
);


-- =========================================================================
-- 43.4–43.6 — CONFIRMED conflict → overwrite to midpoint AND downgrade flag
-- =========================================================================
SELECT lives_ok(
  $$SELECT fn_update_fencer_birth_year(
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname='RECONCONF'),
    1961, TRUE
  )$$,
  '43.4: downgrade confirmed BY executes'
);

SELECT is(
  (SELECT int_birth_year::INT FROM tbl_fencer WHERE txt_surname='RECONCONF'),
  1961,
  '43.5: downgraded BY persisted (V3 midpoint)'
);

SELECT is(
  (SELECT bool_birth_year_estimated FROM tbl_fencer WHERE txt_surname='RECONCONF'),
  TRUE,
  '43.6: confirmed fencer flipped to estimated=TRUE (downgrade)'
);


-- =========================================================================
-- 43.7 — audit trigger preserves the prior birth year (restore trail)
-- =========================================================================
SELECT is(
  (SELECT (jsonb_old_values->>'int_birth_year')
   FROM tbl_audit_log
   WHERE txt_table_name = 'tbl_fencer'
     AND id_row = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname='RECONCONF')
   ORDER BY ts_created DESC, id_log DESC
   LIMIT 1),
  '1991',
  '43.7: trg_audit_fencer preserved the old confirmed BY (1991)'
);


-- =========================================================================
-- 43.8 — plain INSERT with NULL birth year (V-cat unknown) is allowed
-- =========================================================================
SELECT lives_ok(
  $$INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year,
                            bool_birth_year_estimated, txt_nationality)
    VALUES ('S0NULLBY', 'Gamma', NULL, FALSE, 'MAR')$$,
  '43.8: create new fencer with NULL birth year (unmarked combined-pool row)'
);

SELECT is(
  (SELECT int_birth_year FROM tbl_fencer WHERE txt_surname='S0NULLBY'),
  NULL,
  '43.8b: NULL-BY created fencer persists with NULL birth year'
);


-- =========================================================================
-- 43.9 — plain INSERT with midpoint BY + estimated flag persists
-- =========================================================================
SELECT lives_ok(
  $$INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year,
                            bool_birth_year_estimated, txt_nationality, enum_gender)
    VALUES ('S0MIDBY', 'Delta', 1971, TRUE, 'POL', 'M')$$,
  '43.9: create new fencer with V2 midpoint BY + estimated flag'
);


SELECT * FROM finish();
ROLLBACK;
