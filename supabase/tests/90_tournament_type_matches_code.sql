-- =============================================================================
-- TT.CODE — a tournament's type agrees with its code family
-- =============================================================================
-- The drilldown and the ranking file a result under domestic or EVF+ by its
-- tournament's enum_type. On 2 Oct 2026 the Phase 5 draft builder typed every
-- re-ingested tournament PPW, so Manama (IMSW) and Guildford (PEW62efs) were
-- listed under domestic tournaments and counted in the domestic ranking.
-- fn_tournament_type_for_code mirrors the ingest's
-- derive_tourn_type_from_event_code; the trigger refuses a disagreeing write
-- on every path, and TT.CODE.06 checks the stored data itself.
-- =============================================================================

BEGIN;

SELECT plan(8);

SELECT is(fn_tournament_type_for_code('IMSW-V1-F-FOIL-2025-2026'), 'MSW', 'TT.CODE.01 IMSW is MSW');
SELECT is(fn_tournament_type_for_code('PEW62efs-V2-M-EPEE-2025-2026'), 'PEW', 'TT.CODE.02 PEW62efs is PEW');
SELECT is(
  ARRAY[fn_tournament_type_for_code('IMEW-V1-M-EPEE-2024-2025'),
        fn_tournament_type_for_code('PPW3-V2-M-EPEE-2025-2026'),
        fn_tournament_type_for_code('MPW-V0-F-FOIL-2024-2025'),
        fn_tournament_type_for_code('PPS2Wefs-V1-F-EPEE-2025-2026'),
        fn_tournament_type_for_code('MPSM-V1-M-SABRE-2025-2026')],
  ARRAY['MEW', 'PPW', 'MPW', 'PPS', 'MPS'],
  'TT.CODE.03 IMEW, PPWn, MPW, PPS and MPS families');
SELECT is(fn_tournament_type_for_code('GP3-V2-M-EPEE-2023-2024'), NULL,
  'TT.CODE.04 an unmapped family (GP) is not checked');

-- A fixture event to write tournaments under.
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
SELECT 'IMSW-2096-2097', 'TT fixture',
       (SELECT id_season FROM tbl_season ORDER BY id_season DESC LIMIT 1),
       (SELECT id_organizer FROM tbl_organizer ORDER BY id_organizer LIMIT 1),
       'PLANNED';

SELECT throws_like(
  $$INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category, dt_tournament)
    SELECT id_event, 'IMSW-V1-F-FOIL-2096-2097', 'PPW', 'FOIL', 'F', 'V1', '2026-11-12'
      FROM tbl_event WHERE txt_code = 'IMSW-2096-2097'$$,
  '%coded IMSW-V1-F-FOIL-2096-2097 but typed PPW%',
  'TT.CODE.05 an IMSW tournament typed PPW is refused');

SELECT is(
  (SELECT count(*) FROM tbl_tournament
    WHERE fn_tournament_type_for_code(txt_code) IS DISTINCT FROM enum_type::TEXT
      AND fn_tournament_type_for_code(txt_code) IS NOT NULL),
  0::BIGINT,
  'TT.CODE.06 every stored tournament''s type agrees with its code family');

SELECT lives_ok(
  $$INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category, dt_tournament)
    SELECT id_event, 'IMSW-V1-F-FOIL-2096-2097', 'MSW', 'FOIL', 'F', 'V1', '2026-11-12'
      FROM tbl_event WHERE txt_code = 'IMSW-2096-2097'$$,
  'TT.CODE.07 the same tournament typed MSW is written');

SELECT throws_like(
  $$UPDATE tbl_tournament SET enum_type = 'PPW' WHERE txt_code = 'IMSW-V1-F-FOIL-2096-2097'$$,
  '%coded IMSW-V1-F-FOIL-2096-2097 but typed PPW%',
  'TT.CODE.08 re-typing it PPW afterwards is refused');

SELECT * FROM finish();
ROLLBACK;
