-- =============================================================================
-- T8.3: Multi-Category Seed Data — Acceptance Tests
-- =============================================================================
-- Tests 8.20–8.24 from doc/archive/m8_implementation_plan.md §T8.3.
-- Verifies that after db reset, tournaments exist for all 30 sub-rankings.
-- =============================================================================

BEGIN;
SELECT plan(5);

-- 8.20 — tbl_tournament has rows for all 3 weapons
SELECT is(
  (SELECT COUNT(DISTINCT enum_weapon) FROM tbl_tournament
   WHERE id_event IN (SELECT id_event FROM tbl_event
     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025')))::INT,
  3,
  '8.20: tbl_tournament has rows for all 3 weapons (EPEE, FOIL, SABRE)'
);

-- 8.21 — tbl_tournament has rows for both genders
SELECT is(
  (SELECT COUNT(DISTINCT enum_gender) FROM tbl_tournament
   WHERE id_event IN (SELECT id_event FROM tbl_event
     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025')))::INT,
  2,
  '8.21: tbl_tournament has rows for both genders (M, F)'
);

-- 8.22 — tbl_tournament has rows for all 5 age categories
SELECT is(
  (SELECT COUNT(DISTINCT enum_age_category) FROM tbl_tournament
   WHERE id_event IN (SELECT id_event FROM tbl_event
     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025')))::INT,
  5,
  '8.22: tbl_tournament has rows for all 5 age categories (V0-V4)'
);

-- 8.23 — fn_ranking_ppw returns rows for a non-V2 category (V1 M FOIL)
SELECT ok(
  (SELECT COUNT(*) FROM fn_ranking_ppw('FOIL', 'M', 'V1',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'))) > 0,
  '8.23: fn_ranking_ppw returns rows for V1 M FOIL'
);

-- 8.24 — fn_ranking_ppw returns rows for a female category (V2 F EPEE)
SELECT ok(
  (SELECT COUNT(*) FROM fn_ranking_ppw('EPEE', 'F', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'))) > 0,
  '8.24: fn_ranking_ppw returns rows for V2 F EPEE'
);

SELECT * FROM finish();
ROLLBACK;
