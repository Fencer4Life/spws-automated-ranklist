-- =============================================================================
-- pgTAP — Phase 5: alias UI extends to tbl_result_draft
-- =============================================================================
-- Verifies the 2026-05-02 fix that wires fn_transfer_fencer_alias and
-- fn_discard_fencer_alias_and_results into the draft layer:
--   * Transfer moves draft rows to the destination fencer
--   * Discard hard-deletes draft rows for the (alias, fencer) pair
--   * Audit log records the draft delta
-- =============================================================================

BEGIN;

SELECT plan(8);

-- Setup: 2 fencers, 1 alias on the source, 1 committed result, 1 draft result.
INSERT INTO tbl_fencer (id_fencer, txt_surname, txt_first_name, int_birth_year, enum_gender)
VALUES
  (90801, 'PGTAP_SRC', 'Test', 1970, 'M'),
  (90802, 'PGTAP_DEST', 'Test', 1970, 'M');

UPDATE tbl_fencer
   SET json_name_aliases = '["PGTAP_ALIAS Variant"]'::jsonb
 WHERE id_fencer = 90801;

-- Need a tournament + result for the committed-side parity check
-- Pick existing season + organizer — pgTAP rolls back so FK is fine
INSERT INTO tbl_event (
  id_event, txt_code, dt_start, dt_end, txt_name, enum_status,
  id_season, id_organizer
)
VALUES (
  90801, 'PGTAP-EVT-1', '2026-01-01', '2026-01-01', 'PGTAP Event', 'COMPLETED',
  (SELECT id_season FROM tbl_season ORDER BY id_season LIMIT 1),
  (SELECT id_organizer FROM tbl_organizer ORDER BY id_organizer LIMIT 1)
)
ON CONFLICT DO NOTHING;
INSERT INTO tbl_tournament (id_tournament, id_event, txt_code, enum_type, enum_weapon,
                             enum_gender, enum_age_category, dt_tournament,
                             int_participant_count)
VALUES (90801, 90801, 'PGTAP-T-1', 'PPW', 'EPEE', 'M', 'V2', '2026-01-01', 1)
ON CONFLICT DO NOTHING;
INSERT INTO tbl_result (id_result, id_tournament, id_fencer, int_place, txt_scraped_name,
                         enum_match_method)
VALUES (90801, 90801, 90801, 1, 'PGTAP_ALIAS Variant', 'AUTO_MATCH')
ON CONFLICT DO NOTHING;

-- Insert a DRAFT result row for the same (alias, fencer)
INSERT INTO tbl_tournament_draft (
  id_tournament_draft, txt_run_id, id_event, txt_code, enum_type, enum_weapon,
  enum_gender, enum_age_category, dt_tournament, enum_parser_kind
)
VALUES (
  90801, '00000000-0000-0000-0000-000000009081', 90801, 'PGTAP-DRAFT-1', 'PPW', 'EPEE',
  'M', 'V2', '2026-01-01', 'FENCINGTIME_XML'
);
INSERT INTO tbl_result_draft (
  id_result_draft, txt_run_id, id_tournament_draft, id_fencer, int_place,
  txt_scraped_name, enum_match_method
)
VALUES (
  90801, '00000000-0000-0000-0000-000000009081', 90801, 90801, 1, 'PGTAP_ALIAS Variant', 'AUTO_MATCH'
);

-- ---------------------------------------------------------------------------
-- 34.1-34.4 — fn_transfer_fencer_alias moves committed AND draft rows
-- ---------------------------------------------------------------------------
SELECT lives_ok(
  $$ SELECT fn_transfer_fencer_alias(90801, 90802, 'PGTAP_ALIAS Variant') $$,
  '34.1 fn_transfer_fencer_alias runs without error'
);

-- Committed result moved
SELECT is(
  (SELECT id_fencer FROM tbl_result WHERE id_result = 90801),
  90802,
  '34.2 committed tbl_result.id_fencer reassigned to destination'
);

-- Draft result moved (Phase 5 extension)
SELECT is(
  (SELECT id_fencer FROM tbl_result_draft WHERE id_result_draft = 90801),
  90802,
  '34.3 draft tbl_result_draft.id_fencer reassigned to destination'
);

-- Audit log captured the draft-results delta
SELECT ok(
  EXISTS(
    SELECT 1 FROM tbl_audit_log
    WHERE txt_table_name = 'tbl_fencer'
      AND id_row = 90802
      AND txt_action = 'alias_transfer_dest'
      AND (jsonb_new_values->>'draft_results_moved')::INT >= 1
  ),
  '34.4 audit log records draft_results_moved on transfer-dest entry'
);

-- ---------------------------------------------------------------------------
-- 34.5-34.8 — fn_discard_fencer_alias_and_results deletes draft rows too
-- ---------------------------------------------------------------------------
-- Re-stage: put alias+results back, this time on dest fencer (90802)
INSERT INTO tbl_result_draft (
  id_result_draft, txt_run_id, id_tournament_draft, id_fencer, int_place,
  txt_scraped_name, enum_match_method
)
VALUES (
  90802, '00000000-0000-0000-0000-000000009082', 90801, 90802, 2, 'PGTAP_ALIAS Variant', 'AUTO_MATCH'
);

SELECT lives_ok(
  $$ SELECT fn_discard_fencer_alias_and_results(90802, 'PGTAP_ALIAS Variant') $$,
  '34.5 fn_discard_fencer_alias_and_results runs without error'
);

-- Committed result deleted
SELECT is(
  (SELECT count(*)::INT FROM tbl_result
    WHERE id_result = 90801),
  0,
  '34.6 committed tbl_result row hard-deleted'
);

-- Draft result deleted (Phase 5 extension)
SELECT is(
  (SELECT count(*)::INT FROM tbl_result_draft
    WHERE id_result_draft = 90802),
  0,
  '34.7 draft tbl_result_draft row hard-deleted on discard'
);

-- Audit log records the draft-results delta on discard
SELECT ok(
  EXISTS(
    SELECT 1 FROM tbl_audit_log
    WHERE txt_table_name = 'tbl_fencer'
      AND id_row = 90802
      AND txt_action = 'alias_discard'
      AND (jsonb_new_values->>'draft_results_deleted')::INT >= 1
  ),
  '34.8 audit log records draft_results_deleted on discard'
);

-- Cleanup
DELETE FROM tbl_result_draft WHERE id_result_draft IN (90801, 90802);
DELETE FROM tbl_tournament_draft WHERE id_tournament_draft = 90801;
DELETE FROM tbl_result WHERE id_result = 90801;
DELETE FROM tbl_tournament WHERE id_tournament = 90801;
DELETE FROM tbl_event WHERE id_event = 90801;
DELETE FROM tbl_fencer WHERE id_fencer IN (90801, 90802);

SELECT * FROM finish();
ROLLBACK;
