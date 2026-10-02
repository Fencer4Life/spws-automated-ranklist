-- =============================================================================
-- REV.EMPTY — the governed revision rescores the tournaments that have results
-- =============================================================================
-- fn_revise_and_rescore_season (ADR-097) rescored every SCORED tournament of
-- the season. 2023/24, 2024/25 and 2025/26 hold SCORED tournaments with no
-- participant count and no results (18 on CERT and PROD), and scoring one
-- raises, so no locked season could be revised. Found on 2 Oct 2026 while
-- setting the EVF minimum to 1 (ADR-066 amendment).
-- =============================================================================

BEGIN;

SELECT plan(2);

INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
SELECT 'PEW94efs-2025-2026', 'REV.EMPTY fixture',
       (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
       (SELECT id_organizer FROM tbl_organizer ORDER BY id_organizer LIMIT 1),
       'COMPLETED';

-- A tournament marked SCORED that holds no result and no participant count.
INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category,
                            dt_tournament, enum_import_status)
SELECT id_event, 'PEW94efs-V1-M-EPEE-2025-2026', 'PEW', 'EPEE', 'M', 'V1', '2026-03-28', 'SCORED'
  FROM tbl_event WHERE txt_code = 'PEW94efs-2025-2026';

CREATE TEMP TABLE rev_out (id_revision INT, rescored_count INT);

SELECT lives_ok(
  $$INSERT INTO rev_out
    SELECT * FROM fn_revise_and_rescore_season(
      (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
      '{"min_participants_evf": 1}'::jsonb, NULL, 'REV.EMPTY test', 'pgtap')$$,
  'REV.EMPTY.01 a season holding an empty SCORED tournament is revised');

SELECT is(
  (SELECT rescored_count FROM rev_out),
  (SELECT count(*)::INT FROM tbl_tournament t JOIN tbl_event e USING (id_event)
     JOIN tbl_season s USING (id_season)
    WHERE s.txt_code = 'SPWS-2025-2026' AND t.enum_import_status = 'SCORED'
      AND EXISTS (SELECT 1 FROM tbl_result r WHERE r.id_tournament = t.id_tournament)),
  'REV.EMPTY.02 it rescores exactly the tournaments that have results');

SELECT * FROM finish();
ROLLBACK;
