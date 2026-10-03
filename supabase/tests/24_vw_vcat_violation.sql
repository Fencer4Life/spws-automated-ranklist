-- =============================================================================
-- Layer 5 (combined-pool ingestion fix, 2026-04-30):
-- vw_vcat_violation coverage.
--
-- Tests 24.1–24.4: the view exists, has the columns the admin tool reads,
-- excludes clean rows, and surfaces violators with the same formatted
-- message the Layer 2 trigger would emit on write.
--
-- Tests 24.5–24.8 (ADR-047 amendment, 2026-10-03): a result that carries its
-- source's category label passes when that label is the category for the
-- calendar year its tournament was fenced in (the World Championships of
-- November 2025 placed fencers born 1976 in V1; SPWS counts them V2 for
-- 2025/26). Everything else is checked by the season's end year, as before.
-- =============================================================================

BEGIN;
SELECT plan(8);


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


-- ===== 24.5–24.8 — a source label passes by the calendar year it was fenced in =====
-- Same isolated season (end year 2099). Born 2049: 49 in 2098 (V1), 50 in
-- 2099 (V2). Born 2050: 48 in 2098 and 49 in 2099, V1 in both years.
DO $t245$
DECLARE
  v_season  INT;
  v_org     INT;
  v_event   INT;
  v_t_v1    INT;
  v_t_v2    INT;
  v_t_nodt  INT;
  v_f       INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'VW-VCAT-24';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'VW24ORG';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer,
                         txt_location, dt_start, dt_end, enum_status)
       VALUES ('VW24F', 'VW 24 autumn event', v_season, v_org,
               'TestCity', '2098-11-12', '2098-11-16', 'COMPLETED')
    RETURNING id_event INTO v_event;

  INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon,
                              enum_gender, enum_age_category, dt_tournament)
       VALUES (v_event, 'VW24F-V1-M-EPEE', 'PPW', 'EPEE', 'M', 'V1', '2098-11-12')
    RETURNING id_tournament INTO v_t_v1;
  INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon,
                              enum_gender, enum_age_category, dt_tournament)
       VALUES (v_event, 'VW24F-V2-M-EPEE', 'PPW', 'EPEE', 'M', 'V2', '2098-11-14')
    RETURNING id_tournament INTO v_t_v2;
  INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon,
                              enum_gender, enum_age_category, dt_tournament)
       VALUES (v_event, 'VW24F-V1-M-FOIL', 'PPW', 'FOIL', 'M', 'V1', NULL)
    RETURNING id_tournament INTO v_t_nodt;

  -- 24.5: labelled V1, born 2049, fenced in 2098 (49, V1). Season says V2.
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year)
       VALUES ('WORLDS24', 'A', 2049) RETURNING id_fencer INTO v_f;
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, enum_source_age_category)
       VALUES (v_f, v_t_v1, 1, 'V1');

  -- 24.6: labelled V2, born 2050: V1 in 2098 and in 2099. The label explains nothing.
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year)
       VALUES ('WRONGBY24', 'B', 2050) RETURNING id_fencer INTO v_f;
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, enum_source_age_category)
       VALUES (v_f, v_t_v2, 1, 'V2');

  -- 24.7: unlabelled V1, born 2049. Seeded clean (2050), then moved, as in 24.3.
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year)
       VALUES ('NOLABEL24', 'C', 2050) RETURNING id_fencer INTO v_f;
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
       VALUES (v_f, v_t_v1, 2);
  UPDATE tbl_fencer SET int_birth_year = 2049 WHERE id_fencer = v_f;

  -- 24.8: labelled V1, born 2049, tournament undated: the event started in 2098.
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year)
       VALUES ('NODATE24', 'D', 2049) RETURNING id_fencer INTO v_f;
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, enum_source_age_category)
       VALUES (v_f, v_t_nodt, 1, 'V1');
END;
$t245$;

SELECT is(
  (SELECT COUNT(*)::INT FROM vw_vcat_violation WHERE txt_surname = 'WORLDS24'),
  0,
  '24.5: a labelled result passes when the label is the category of the year it was fenced in'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM vw_vcat_violation WHERE txt_surname = 'WRONGBY24'),
  1,
  '24.6: a labelled result that fits neither year is still listed'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM vw_vcat_violation WHERE txt_surname = 'NOLABEL24'),
  1,
  '24.7: an unlabelled result is checked by the season end year only'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM vw_vcat_violation WHERE txt_surname = 'NODATE24'),
  0,
  '24.8: an undated tournament takes the year its event started'
);


ROLLBACK;
