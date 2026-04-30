-- =============================================================================
-- Layer 2 + 3 (combined-pool ingestion fix, 2026-04-29):
-- fn_vcat_violation_msg + trg_assert_result_vcat coverage.
--
-- Tests 23.1–23.6 exercise the pure expression-only helper across every
-- branch (clean / mismatch / NULL BY / under-30 / cross-V-cat). The
-- trigger itself is a thin wrapper around the helper, so we don't need
-- to capture its NOTICE output to know it behaves correctly.
-- =============================================================================

BEGIN;
SELECT plan(7);

-- ===== 23.1 — clean: BY 1980, season ends 2026 → V1, tournament V1 =====
SELECT is(
  fn_vcat_violation_msg(1980, 'V1'::enum_age_category, 2026, 'KOWAL Jan', 'PPW3-V1-M-EPEE-2025-2026'),
  NULL,
  '23.1: matching V-cat returns NULL (clean row)'
);

-- ===== 23.2 — mismatch: BY 1984 → V1 in 2026, but tournament is V0 =====
SELECT is(
  fn_vcat_violation_msg(1984, 'V0'::enum_age_category, 2026, 'KOWALSKA Milena', 'GP1-V0-F-EPEE-2025-2026'),
  'fn_assert_result_vcat: KOWALSKA Milena (BY=1984) placed in V0 but expected V1 (tournament GP1-V0-F-EPEE-2025-2026)',
  '23.2: V-cat mismatch returns formatted violation message'
);

-- ===== 23.3 — NULL birth year: invariant unprovable, return NULL =====
SELECT is(
  fn_vcat_violation_msg(NULL, 'V1'::enum_age_category, 2026, 'UNKNOWN Test', 'PPW1-V1-M-EPEE-2025-2026'),
  NULL,
  '23.3: NULL birth year returns NULL (admin handles via identity queue)'
);

-- ===== 23.4 — under-30 fencer: expected V-cat is NULL, return NULL =====
SELECT is(
  fn_vcat_violation_msg(2000, 'V0'::enum_age_category, 2026, 'YOUNG Sample', 'PPW1-V0-M-EPEE-2025-2026'),
  NULL,
  '23.4: under-30 fencer (expected V-cat NULL) returns NULL'
);

-- ===== 23.5 — large age gap: BY 1954 in 2026 → V4, tournament V0 =====
SELECT is(
  fn_vcat_violation_msg(1954, 'V0'::enum_age_category, 2026, 'MŁYNEK Janusz', 'PPW1-V0-M-EPEE-2025-2026'),
  'fn_assert_result_vcat: MŁYNEK Janusz (BY=1954) placed in V0 but expected V4 (tournament PPW1-V0-M-EPEE-2025-2026)',
  '23.5: V0/V4 mismatch returns expected message'
);

-- ===== 23.6 / 23.7 — trigger raises on V-cat mismatch (FATAL since Layer 6) =====
-- Set up: an isolated season + V0 tournament + a V4 fencer (BY=1984 in season
-- ending 2100 → age 116 → V4). The mismatched INSERT must throw.
DO $smoke_setup$
DECLARE
  v_season  INT;
  v_org     INT;
  v_event   INT;
  v_tour    INT;
  v_fencer  INT;
BEGIN
  UPDATE tbl_season SET bool_active = FALSE;
  v_season := fn_create_season('VCATTRIG-23', '2099-09-01', '2100-06-30');
  UPDATE tbl_season SET bool_active = TRUE WHERE id_season = v_season;

  INSERT INTO tbl_organizer (txt_code, txt_name)
       VALUES ('VCATORG23', 'V-cat trigger 23 org')
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code='VCATORG23';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer,
                         txt_location, dt_start, dt_end, enum_status)
       VALUES ('VCAT23E', 'V-cat trigger event', v_season, v_org,
               'TestCity', '2100-03-15', '2100-03-15', 'COMPLETED')
    RETURNING id_event INTO v_event;

  INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon,
                              enum_gender, enum_age_category, dt_tournament)
       VALUES (v_event, 'VCAT23E-V0-M-EPEE', 'PPW', 'EPEE', 'M', 'V0', '2100-03-15')
    RETURNING id_tournament INTO v_tour;

  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year)
       VALUES ('TRIG23', 'Smoke', 1984)
    RETURNING id_fencer INTO v_fencer;
END;
$smoke_setup$;

-- 23.6: mismatched INSERT throws.
SELECT throws_like(
  $$ INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
       VALUES ((SELECT id_fencer FROM tbl_fencer WHERE txt_surname='TRIG23'),
               (SELECT id_tournament FROM tbl_tournament WHERE txt_code='VCAT23E-V0-M-EPEE'),
               1) $$,
  '%placed in V0 but expected V4%',
  '23.6: FATAL trigger rejects INSERT into mismatched V-cat tournament'
);

-- 23.7: matching INSERT succeeds (negative-control: V0 fencer into V0 tournament).
DO $insert_clean$
DECLARE
  v_clean_fencer INT;
BEGIN
  -- BY=2069 in season ending 2100 → age 31 → V0. Matches the V0 tournament.
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year)
       VALUES ('TRIG23CLEAN', 'OK', 2069)
    RETURNING id_fencer INTO v_clean_fencer;
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
       VALUES (v_clean_fencer,
               (SELECT id_tournament FROM tbl_tournament WHERE txt_code='VCAT23E-V0-M-EPEE'),
               1);
END;
$insert_clean$;

SELECT pass('23.7: matching V-cat INSERT (V0 fencer into V0 tournament) succeeds');

ROLLBACK;
