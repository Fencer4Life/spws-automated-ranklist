-- =============================================================================
-- ADR-034: Cross-Gender Tournament Scoring Tests
-- =============================================================================
-- Tests CG.1–CG.9 covering fn_effective_gender helper and ranking filters.
-- Seed data: PPW5-V1-M-SABRE-2025-2026 has SAMECKA-NACZYŃSKA Martyna (F)
-- as sole participant — no sibling F tournament at that event.
-- =============================================================================

BEGIN;
SELECT plan(9);

-- =========================================================================
-- Setup: ensure fencer gender is set for test subjects
-- =========================================================================
UPDATE tbl_fencer SET enum_gender = 'F'
WHERE txt_surname = 'SAMECKA-NACZYŃSKA' AND txt_first_name = 'Martyna';

-- For M-in-F test: pick a known male fencer (TECŁAW Robert, sabre M V1)
UPDATE tbl_fencer SET enum_gender = 'M'
WHERE txt_surname = 'TECŁAW' AND txt_first_name = 'Robert';

-- =========================================================================
-- CG.1–CG.4: fn_effective_gender unit tests
-- =========================================================================

-- CG.1 — Normal match: fencer F in tournament F → returns F
SELECT is(
  fn_effective_gender('F'::enum_gender_type, 'F'::enum_gender_type, 1, 'SABRE'::enum_weapon_type, 'V1'::enum_age_category),
  'F'::enum_gender_type,
  'CG.1: fencer F + tournament F → F (normal match)'
);

-- CG.2 — Normal match: NULL fencer gender → returns tournament gender
SELECT is(
  fn_effective_gender(NULL::enum_gender_type, 'M'::enum_gender_type, 1, 'SABRE'::enum_weapon_type, 'V1'::enum_age_category),
  'M'::enum_gender_type,
  'CG.2: fencer NULL + tournament M → M (backwards-compatible)'
);

-- CG.3 — Man in women's tournament → always dropped (NULL)
SELECT is(
  fn_effective_gender('M'::enum_gender_type, 'F'::enum_gender_type, 1, 'SABRE'::enum_weapon_type, 'V1'::enum_age_category),
  NULL::enum_gender_type,
  'CG.3: fencer M + tournament F → NULL (always dropped)'
);

-- CG.4 — Woman in men's tournament, no sibling F tournament → reassigned to F
-- Uses PPW5-2025-2026 event (only has M sabre V1 tournament, no F sibling)
SELECT is(
  fn_effective_gender(
    'F'::enum_gender_type,
    'M'::enum_gender_type,
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW5-2025-2026'),
    'SABRE'::enum_weapon_type,
    'V1'::enum_age_category
  ),
  'F'::enum_gender_type,
  'CG.4: fencer F + tournament M + no F sibling → F (reassigned)'
);

-- CG.5 — Woman in men's tournament, sibling F tournament exists → dropped (NULL)
-- PPW1-2025-2026 has both M and F sabre V1 tournaments
SELECT is(
  fn_effective_gender(
    'F'::enum_gender_type,
    'M'::enum_gender_type,
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW1-2025-2026'),
    'SABRE'::enum_weapon_type,
    'V1'::enum_age_category
  ),
  NULL::enum_gender_type,
  'CG.5: fencer F + tournament M + F sibling exists → NULL (dropped)'
);

-- =========================================================================
-- CG.6–CG.7: fn_ranking_ppw integration — Martyna sabre V1
-- =========================================================================

-- CG.6 — Martyna appears in F sabre V1 ranking (via PPW5-V1-M-SABRE reassignment)
SELECT ok(
  EXISTS(
    SELECT 1 FROM fn_ranking_ppw('SABRE'::enum_weapon_type, 'F'::enum_gender_type, 'V1'::enum_age_category)
    WHERE fencer_name LIKE 'SAMECKA-NACZYŃSKA%'
  ),
  'CG.6: SAMECKA-NACZYŃSKA appears in F sabre V1 PPW ranking'
);

-- CG.7 — Martyna does NOT appear in M sabre V1 ranking
SELECT ok(
  NOT EXISTS(
    SELECT 1 FROM fn_ranking_ppw('SABRE'::enum_weapon_type, 'M'::enum_gender_type, 'V1'::enum_age_category)
    WHERE fencer_name LIKE 'SAMECKA-NACZYŃSKA%'
  ),
  'CG.7: SAMECKA-NACZYŃSKA excluded from M sabre V1 PPW ranking'
);

-- =========================================================================
-- CG.8: fn_fencer_scores_rolling — drilldown shows reassigned result
-- =========================================================================

-- CG.8 — Fencer drilldown for Martyna in F sabre V1 includes the M tournament result
SELECT ok(
  EXISTS(
    SELECT 1 FROM fn_fencer_scores_rolling(
      (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SAMECKA-NACZYŃSKA' AND txt_first_name = 'Martyna'),
      'SABRE'::enum_weapon_type, 'F'::enum_gender_type, 'V1'::enum_age_category
    )
    WHERE txt_tournament_code = 'PPW5-V1-M-SABRE-2025-2026'
  ),
  'CG.8: fencer drilldown F sabre V1 includes reassigned PPW5-M result'
);

-- =========================================================================
-- CG.9: NULL gender backward compatibility
-- =========================================================================

-- CG.9 — Fencer with NULL gender in M tournament still appears in M ranking
-- (Temporarily clear gender for KOWALEWSKI to test NULL path)
UPDATE tbl_fencer SET enum_gender = NULL
WHERE txt_surname = 'KOWALEWSKI' AND txt_first_name = 'Rafał';

SELECT ok(
  EXISTS(
    SELECT 1 FROM fn_ranking_ppw('SABRE'::enum_weapon_type, 'M'::enum_gender_type, 'V1'::enum_age_category)
    WHERE fencer_name LIKE 'KOWALEWSKI%'
  ),
  'CG.9: fencer with NULL gender in M tournament still in M ranking'
);

SELECT * FROM finish();
ROLLBACK;
