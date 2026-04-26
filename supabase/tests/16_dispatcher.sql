-- =============================================================================
-- Phase 1A: Carry-over engine dispatcher tests
-- =============================================================================
-- Tests D.1–D.8 from doc/adr/042-carryover-engine-dispatcher.md (when written).
-- D.1-D.2:  Schema additions (enum + season column)
-- D.3-D.5:  Renamed engine functions exist
-- D.6-D.7:  Dispatcher routing + fail-fast behavior
-- D.8:      Dispatcher overhead is invisible (smoke vs direct call)
-- Existing 21 R.* tests in 09_rolling_score.sql also serve as regression gate.
-- =============================================================================

BEGIN;
SELECT plan(8);

-- =========================================================================
-- D.1: enum_event_carryover_engine type exists with both values
-- =========================================================================
SELECT bag_eq(
  $$ SELECT unnest(enum_range(NULL::enum_event_carryover_engine))::TEXT $$,
  $$ VALUES ('EVENT_CODE_MATCHING'), ('EVENT_FK_MATCHING') $$,
  'D.1: enum_event_carryover_engine has EVENT_CODE_MATCHING and EVENT_FK_MATCHING'
);

-- =========================================================================
-- D.2: tbl_season.enum_carryover_engine exists, defaults applied to all rows
-- =========================================================================
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_season WHERE enum_carryover_engine != 'EVENT_CODE_MATCHING'),
  0,
  'D.2: every existing tbl_season row defaults to EVENT_CODE_MATCHING'
);

-- =========================================================================
-- D.3-D.5: renamed engine functions exist with original signatures
-- =========================================================================
SELECT has_function(
  'fn_ranking_ppw_event_code_matching',
  ARRAY['enum_weapon_type', 'enum_gender_type', 'enum_age_category', 'integer', 'boolean'],
  'D.3: fn_ranking_ppw_event_code_matching exists with original 5-arg signature'
);

SELECT has_function(
  'fn_ranking_kadra_event_code_matching',
  ARRAY['enum_weapon_type', 'enum_gender_type', 'enum_age_category', 'integer', 'boolean'],
  'D.4: fn_ranking_kadra_event_code_matching exists with original 5-arg signature'
);

SELECT has_function(
  'fn_fencer_scores_rolling_event_code_matching',
  ARRAY['integer', 'enum_weapon_type', 'enum_gender_type', 'enum_age_category', 'integer'],
  'D.5: fn_fencer_scores_rolling_event_code_matching exists with original 5-arg signature'
);

-- =========================================================================
-- D.6: dispatcher routes EVENT_CODE_MATCHING to renamed engine
-- KORONA score via dispatcher == KORONA score via direct engine call
-- =========================================================================
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE'::enum_weapon_type, 'M'::enum_gender_type, 'V2'::enum_age_category,
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KORONA' AND txt_first_name = 'Przemysław')),
  (SELECT total_score FROM fn_ranking_ppw_event_code_matching(
    'EPEE'::enum_weapon_type, 'M'::enum_gender_type, 'V2'::enum_age_category,
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KORONA' AND txt_first_name = 'Przemysław')),
  'D.6: dispatcher fn_ranking_ppw routes to event_code_matching engine — KORONA scores match'
);

-- =========================================================================
-- D.7: dispatcher fail-fast on EVENT_FK_MATCHING (engine not implemented yet)
-- =========================================================================
-- Flip SPWS-2025-2026 to EVENT_FK_MATCHING within the test transaction
UPDATE tbl_season SET enum_carryover_engine = 'EVENT_FK_MATCHING'
WHERE txt_code = 'SPWS-2025-2026';

SELECT throws_like(
  $$ SELECT * FROM fn_ranking_ppw(
       'EPEE'::enum_weapon_type, 'M'::enum_gender_type, 'V2'::enum_age_category,
       (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
       p_rolling := TRUE
     ) $$,
  '%not yet implemented%',
  'D.7: dispatcher raises "not yet implemented" when engine is EVENT_FK_MATCHING'
);

-- Restore default engine for safety (ROLLBACK also cleans up)
UPDATE tbl_season SET enum_carryover_engine = 'EVENT_CODE_MATCHING'
WHERE txt_code = 'SPWS-2025-2026';

-- =========================================================================
-- D.8: row-count parity between dispatcher and direct engine call
-- =========================================================================
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_ranking_ppw(
    'EPEE'::enum_weapon_type, 'M'::enum_gender_type, 'V2'::enum_age_category,
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  )),
  (SELECT COUNT(*)::INT FROM fn_ranking_ppw_event_code_matching(
    'EPEE'::enum_weapon_type, 'M'::enum_gender_type, 'V2'::enum_age_category,
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  )),
  'D.8: dispatcher and direct engine return identical row counts'
);

SELECT * FROM finish();
ROLLBACK;
