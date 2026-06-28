-- =============================================================================
-- ADR-034: Cross-Gender Tournament Scoring Tests  (self-contained fixture)
-- =============================================================================
-- Tests CG.1–CG.9 covering fn_effective_gender and the ranking-level cross-gender
-- rules. DESIGN (2026-06-28 robustness rewrite): builds its own throwaway world
-- in-transaction and ROLLBACKs — no named production fencers (SAMECKA / TECŁAW /
-- KOWALEWSKI), no dependence on which sabre brackets a given PPW re-ingest
-- happened to produce. Immune to live-DB mutation and season rollover.
--
-- Cross-gender rules under test (fn_effective_gender):
--   1. genders match / fencer gender NULL → tournament gender (normal)
--   2. man in women's tournament            → NULL (always dropped)
--   3. woman in men's tournament, NO F sibling at the event → 'F' (reassigned)
--   4. woman in men's tournament, F sibling exists          → NULL (dropped)
-- =============================================================================

BEGIN;
SELECT plan(9);

-- =========================================================================
-- CG.1–CG.3: fn_effective_gender pure-enum unit tests (already self-contained)
-- =========================================================================

SELECT is(
  fn_effective_gender('F'::enum_gender_type, 'F'::enum_gender_type, 1, 'SABRE'::enum_weapon_type, 'V1'::enum_age_category),
  'F'::enum_gender_type,
  'CG.1: fencer F + tournament F → F (normal match)');

SELECT is(
  fn_effective_gender(NULL::enum_gender_type, 'M'::enum_gender_type, 1, 'SABRE'::enum_weapon_type, 'V1'::enum_age_category),
  'M'::enum_gender_type,
  'CG.2: fencer NULL + tournament M → M (backwards-compatible)');

SELECT is(
  fn_effective_gender('M'::enum_gender_type, 'F'::enum_gender_type, 1, 'SABRE'::enum_weapon_type, 'V1'::enum_age_category),
  NULL::enum_gender_type,
  'CG.3: fencer M + tournament F → NULL (always dropped)');

-- =========================================================================
-- Synthetic fixture
-- =========================================================================

INSERT INTO tbl_organizer (txt_code, txt_name) VALUES ('TST-ORG', 'Test Organizer');

-- One non-active season on the active results-based engine, with a cloned real
-- scoring config (real json_ranking_rules so fn_ranking_ppw takes the JSONB path).
INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active, enum_carryover_engine)
VALUES ('TST-CG', '2091-09-01', '2092-08-31', FALSE, 'EVENT_CODE_MATCHING');

UPDATE tbl_scoring_config dst SET
  int_mp_value             = src.int_mp_value,
  int_podium_gold          = src.int_podium_gold,
  int_podium_silver        = src.int_podium_silver,
  int_podium_bronze        = src.int_podium_bronze,
  num_ppw_multiplier       = src.num_ppw_multiplier,
  int_ppw_best_count       = src.int_ppw_best_count,
  int_ppw_total_rounds     = src.int_ppw_total_rounds,
  num_mpw_multiplier       = src.num_mpw_multiplier,
  bool_mpw_droppable       = src.bool_mpw_droppable,
  num_pew_multiplier       = src.num_pew_multiplier,
  int_pew_best_count       = src.int_pew_best_count,
  num_mew_multiplier       = src.num_mew_multiplier,
  bool_mew_droppable       = src.bool_mew_droppable,
  num_msw_multiplier       = src.num_msw_multiplier,
  num_psw_multiplier       = src.num_psw_multiplier,
  int_min_participants_evf = src.int_min_participants_evf,
  int_min_participants_ppw = src.int_min_participants_ppw,
  json_ranking_rules       = src.json_ranking_rules
FROM tbl_scoring_config src
WHERE src.id_season = (
        SELECT id_season FROM tbl_scoring_config
         WHERE json_ranking_rules ? 'domestic' AND json_ranking_rules ? 'international'
         ORDER BY id_season DESC LIMIT 1)
  AND dst.id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'TST-CG');

CREATE FUNCTION pg_temp.sid(p_code text) RETURNS int
  LANGUAGE sql STABLE AS $$ SELECT id_season FROM tbl_season WHERE txt_code = p_code $$;
CREATE FUNCTION pg_temp.fid(p_surname text) RETURNS int
  LANGUAGE sql STABLE AS $$ SELECT id_fencer FROM tbl_fencer WHERE txt_surname = p_surname LIMIT 1 $$;
CREATE FUNCTION pg_temp.eid(p_code text) RETURNS int
  LANGUAGE sql STABLE AS $$ SELECT id_event FROM tbl_event WHERE txt_code = p_code $$;

-- Fencers — BY 2047 → V1 at season end 2092 (satisfies trg_assert_result_vcat for
-- the V1 brackets below; no trigger-disable needed).
INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, enum_gender) VALUES
  ('TSTWOMAN', 'Wanda',  2047, 'F'),    -- woman who fences in a men's bracket
  ('TSTNULLG', 'Nikodem', 2047, NULL);  -- NULL-gender fencer (backwards compat)

-- Event CG-NOSIB: ONLY a men's SABRE V1 tournament (no F sibling). Both fencers
-- have a result in it.
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start)
VALUES ('CG-NOSIB-TST', 'No F sibling event', pg_temp.sid('TST-CG'),
        (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'TST-ORG'), 'SCHEDULED', '2092-01-10');

DO $cg$
DECLARE v_tid int;
BEGIN
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon,
                              enum_gender, enum_age_category, dt_tournament,
                              int_participant_count, enum_import_status)
  VALUES (pg_temp.eid('CG-NOSIB-TST'), 'CG-NOSIB-V1-M-SABRE-TST', 'no-sibling men sabre V1',
          'PPW', 'SABRE', 'M', 'V1', '2092-01-10', 8, 'IMPORTED')
  RETURNING id_tournament INTO v_tid;
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name) VALUES
    (pg_temp.fid('TSTWOMAN'), v_tid, 1, 'synthetic-woman'),   -- woman → reassigned to F
    (pg_temp.fid('TSTNULLG'), v_tid, 2, 'synthetic-nullg');   -- NULL gender → M
  PERFORM fn_calc_tournament_scores(v_tid);
END $cg$;

-- Event CG-SIB: BOTH a men's and a women's SABRE V1 tournament (the F sibling
-- exists). No results needed — only the sibling's existence matters.
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start)
VALUES ('CG-SIB-TST', 'F sibling event', pg_temp.sid('TST-CG'),
        (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'TST-ORG'), 'SCHEDULED', '2092-02-10');
INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon,
                            enum_gender, enum_age_category, dt_tournament, enum_import_status)
VALUES
  (pg_temp.eid('CG-SIB-TST'), 'CG-SIB-V1-M-SABRE-TST', 'sibling men sabre V1',   'PPW', 'SABRE', 'M', 'V1', '2092-02-10', 'PLANNED'),
  (pg_temp.eid('CG-SIB-TST'), 'CG-SIB-V1-F-SABRE-TST', 'sibling women sabre V1', 'PPW', 'SABRE', 'F', 'V1', '2092-02-10', 'PLANNED');

-- =========================================================================
-- CG.4–CG.5: fn_effective_gender against synthetic events
-- =========================================================================

SELECT is(
  fn_effective_gender('F'::enum_gender_type, 'M'::enum_gender_type,
    pg_temp.eid('CG-NOSIB-TST'), 'SABRE'::enum_weapon_type, 'V1'::enum_age_category),
  'F'::enum_gender_type,
  'CG.4: fencer F + tournament M + no F sibling → F (reassigned)');

SELECT is(
  fn_effective_gender('F'::enum_gender_type, 'M'::enum_gender_type,
    pg_temp.eid('CG-SIB-TST'), 'SABRE'::enum_weapon_type, 'V1'::enum_age_category),
  NULL::enum_gender_type,
  'CG.5: fencer F + tournament M + F sibling exists → NULL (dropped)');

-- =========================================================================
-- CG.6–CG.7: fn_ranking_ppw integration — the woman in the men's bracket
-- =========================================================================

SELECT ok(
  EXISTS(
    SELECT 1 FROM fn_ranking_ppw('SABRE'::enum_weapon_type, 'F'::enum_gender_type, 'V1'::enum_age_category, pg_temp.sid('TST-CG'))
     WHERE id_fencer = pg_temp.fid('TSTWOMAN')),
  'CG.6: reassigned woman appears in the F sabre V1 ranking');

SELECT ok(
  NOT EXISTS(
    SELECT 1 FROM fn_ranking_ppw('SABRE'::enum_weapon_type, 'M'::enum_gender_type, 'V1'::enum_age_category, pg_temp.sid('TST-CG'))
     WHERE id_fencer = pg_temp.fid('TSTWOMAN')),
  'CG.7: the woman is excluded from the M sabre V1 ranking');

-- =========================================================================
-- CG.8: fn_fencer_scores_rolling drilldown shows the reassigned result
-- =========================================================================

SELECT ok(
  EXISTS(
    SELECT 1 FROM fn_fencer_scores_rolling(
      pg_temp.fid('TSTWOMAN'), 'SABRE'::enum_weapon_type, 'F'::enum_gender_type,
      'V1'::enum_age_category, pg_temp.sid('TST-CG'))
     WHERE txt_tournament_code = 'CG-NOSIB-V1-M-SABRE-TST'),
  'CG.8: F sabre V1 drilldown includes the reassigned men''s-bracket result');

-- =========================================================================
-- CG.9: NULL gender backward compatibility
-- =========================================================================

SELECT ok(
  EXISTS(
    SELECT 1 FROM fn_ranking_ppw('SABRE'::enum_weapon_type, 'M'::enum_gender_type, 'V1'::enum_age_category, pg_temp.sid('TST-CG'))
     WHERE id_fencer = pg_temp.fid('TSTNULLG')),
  'CG.9: fencer with NULL gender in M tournament still in M ranking');

SELECT * FROM finish();
ROLLBACK;
