-- =============================================================================
-- Layer 5 (combined-pool ingestion fix, 2026-04-30):
-- vw_vcat_violation coverage.
--
-- Tests 24.1–24.4: the view exists, has the columns the admin tool reads,
-- excludes clean rows, and surfaces violators with the same formatted
-- message the Layer 2 trigger would emit on write.
-- =============================================================================

BEGIN;
SELECT plan(4);


-- ===== 24.1 — view exists =====
SELECT has_view('vw_vcat_violation', '24.1: vw_vcat_violation view exists');


-- ===== 24.2 — view exposes the columns the admin tool consumes =====
SELECT columns_are(
    'vw_vcat_violation',
    ARRAY[
        'id_result', 'id_fencer', 'id_tournament',
        'txt_surname', 'txt_first_name', 'int_birth_year',
        'tournament_code', 'tournament_vcat', 'expected_vcat',
        'season_end_year', 'event_code', 'season_code',
        'violation_msg'
    ],
    '24.2: vw_vcat_violation has the 13 columns the admin tool consumes'
);


-- ===== 24.3 — view excludes clean rows AND surfaces violators =====
DO $t243$
DECLARE
  v_season  INT;
  v_org     INT;
  v_event   INT;
  v_tour_v0 INT;
  v_tour_v1 INT;
  v_clean   INT;
  v_dirty   INT;
BEGIN
  -- Isolated season: 2098-09-01 → 2099-06-30, end year 2099.
  UPDATE tbl_season SET bool_active = FALSE;
  v_season := fn_create_season('VW-VCAT-24', '2098-09-01', '2099-06-30');
  UPDATE tbl_season SET bool_active = TRUE WHERE id_season = v_season;

  INSERT INTO tbl_organizer (txt_code, txt_name)
       VALUES ('VW24ORG', 'VW Test 24 Org')
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'VW24ORG';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer,
                         txt_location, dt_start, dt_end, enum_status)
       VALUES ('VW24E', 'VW 24 event', v_season, v_org,
               'TestCity', '2099-03-15', '2099-03-15', 'COMPLETED')
    RETURNING id_event INTO v_event;

  INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon,
                              enum_gender, enum_age_category, dt_tournament)
       VALUES (v_event, 'VW24E-V0-M-EPEE', 'PPW', 'EPEE', 'M', 'V0', '2099-03-15')
    RETURNING id_tournament INTO v_tour_v0;
  INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon,
                              enum_gender, enum_age_category, dt_tournament)
       VALUES (v_event, 'VW24E-V1-M-EPEE', 'PPW', 'EPEE', 'M', 'V1', '2099-03-15')
    RETURNING id_tournament INTO v_tour_v1;

  -- Clean fencer: BY=2069 → age 30 → V0 → tournament V0. Match.
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year)
       VALUES ('CLEAN24', 'A', 2069)
    RETURNING id_fencer INTO v_clean;
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
       VALUES (v_clean,
               (SELECT id_tournament FROM tbl_tournament WHERE txt_code='VW24E-V0-M-EPEE'),
               1);

  -- Dirty fencer: insert CLEAN first (BY=2069 → V0, matches), then mutate
  -- the BY to 2059 (V1) so the row becomes a violator. The Layer 6 FATAL
  -- trigger fires only on tbl_result writes, not on tbl_fencer — so this
  -- two-step is the lawful way to seed an existing-data violation in tests.
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year)
       VALUES ('DIRTY24', 'B', 2069)
    RETURNING id_fencer INTO v_dirty;
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
       VALUES (v_dirty,
               (SELECT id_tournament FROM tbl_tournament WHERE txt_code='VW24E-V0-M-EPEE'),
               2);
  UPDATE tbl_fencer SET int_birth_year = 2059 WHERE id_fencer = v_dirty;
END;
$t243$;

SELECT is(
  (SELECT COUNT(*)::INT FROM vw_vcat_violation
    WHERE event_code = 'VW24E'),
  1,
  '24.3: clean rows are excluded, only the dirty row appears in vw_vcat_violation'
);


-- ===== 24.4 — view's violation_msg matches the trigger's NOTICE format =====
SELECT is(
  (SELECT violation_msg FROM vw_vcat_violation
    WHERE event_code = 'VW24E'),
  'fn_assert_result_vcat: DIRTY24 B (BY=2059) placed in V0 but expected V1 (tournament VW24E-V0-M-EPEE)',
  '24.4: view emits same message format as fn_vcat_violation_msg helper'
);


ROLLBACK;
