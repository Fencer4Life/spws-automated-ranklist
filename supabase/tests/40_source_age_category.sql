-- =============================================================================
-- pgTAP — Phase 5.5: enum_source_age_category capture + commit + view
-- =============================================================================
-- Plan-test-IDs:
--   5.18.A — column exists on tbl_result_draft AND tbl_result with type
--            enum_age_category, NULLABLE
--   5.18.B — fn_commit_event_draft body references the column (so commit
--            preserves it draft → live)
--   5.18.C — vw_fencer_aliases exposes `latest_source_category_hint`
-- =============================================================================

BEGIN;

SELECT plan(8);

-- 5.18.A.1 / .2 — column on tbl_result_draft
SELECT has_column('tbl_result_draft', 'enum_source_age_category',
  '5.18.A.1 — tbl_result_draft.enum_source_age_category exists');
SELECT col_type_is('tbl_result_draft', 'enum_source_age_category', 'enum_age_category',
  '5.18.A.2 — type is enum_age_category');

-- 5.18.A.3 — column on tbl_result
SELECT has_column('tbl_result', 'enum_source_age_category',
  '5.18.A.3 — tbl_result.enum_source_age_category exists');

-- 5.18.A.4 — both columns must be nullable (joint-pool sources have category_hint=NULL)
SELECT col_is_null('tbl_result_draft', 'enum_source_age_category',
  '5.18.A.4 — draft column is nullable');
SELECT col_is_null('tbl_result', 'enum_source_age_category',
  '5.18.A.5 — live column is nullable');

-- 5.18.B — fn_commit_event_draft body must reference enum_source_age_category
-- on BOTH the SELECT-from-draft side and the INSERT-into-live column list,
-- otherwise commit silently drops the source V-cat.
SELECT ok(
  (SELECT routine_definition FROM information_schema.routines
    WHERE routine_name = 'fn_commit_event_draft') LIKE '%enum_source_age_category%',
  '5.18.B — fn_commit_event_draft references enum_source_age_category'
);

-- 5.18.C — view exposes latest_source_category_hint
SELECT has_column('vw_fencer_aliases', 'latest_source_category_hint',
  '5.18.C — vw_fencer_aliases.latest_source_category_hint exists');

-- 5.18.D — view exposes latest_source_bracket_url so the modal can render
-- a "verify on FTL" link. Pulled from the most-recent draft/live row's
-- tournament's txt_source_url_used.
SELECT has_column('vw_fencer_aliases', 'latest_source_bracket_url',
  '5.18.D — vw_fencer_aliases.latest_source_bracket_url exists');

SELECT * FROM finish();

ROLLBACK;
