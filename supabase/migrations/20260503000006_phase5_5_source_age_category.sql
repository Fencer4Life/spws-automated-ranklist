-- =============================================================================
-- Phase 5.5 — capture parsed source V-cat per result row
-- =============================================================================
-- Bug history (operator caught 2026-05-03 during GP3 triage):
-- The "Create new fencer from alias" modal pre-fills the birth-year field
-- using `latest_category_hint` from vw_fencer_aliases, which currently
-- exposes the V-cat of the *destination* tournament a row was placed in.
-- For wrong-match rows, stage 7 misroutes them to the wrong V-cat
-- (matched fencer's BY drives the split), so the modal suggests the
-- wrong year — operator either had to override every time or accept a
-- bad guess.
--
-- This migration adds `enum_source_age_category` to tbl_result_draft and
-- tbl_result so the *source* bracket V-cat (parsed.category_hint at
-- ingestion time) is preserved per row, separate from the destination
-- tournament's V-cat. Joint-pool source brackets emit category_hint=NULL
-- (V-cat unknown until stage 7) so the column will also be NULL for those
-- rows — the modal falls back to "no hint" in that case, which is
-- correct (operator must check the FTL page).
--
-- Plan-test-ID 5.18 (deferred). ADR amendment of ADR-058.
-- =============================================================================

BEGIN;

ALTER TABLE tbl_result_draft
  ADD COLUMN IF NOT EXISTS enum_source_age_category enum_age_category;

ALTER TABLE tbl_result
  ADD COLUMN IF NOT EXISTS enum_source_age_category enum_age_category;

COMMENT ON COLUMN tbl_result_draft.enum_source_age_category IS
  'Phase 5.5 (5.18) — V-cat of the source bracket the scraped name came '
  'from (parsed.category_hint at ingestion). NULL for joint-pool brackets '
  'where source V-cat was unknown. Distinct from id_tournament_draft → '
  'enum_age_category, which reflects stage 7 destination after BY-based '
  'split (misrouted for wrong-match rows). Used by the alias-modal BY '
  'pre-fill so the operator gets the correct V-cat hint, not the '
  'misroute destination.';

COMMENT ON COLUMN tbl_result.enum_source_age_category IS
  'Phase 5.5 (5.18) — V-cat of the source bracket. See draft-table column '
  'comment for context. Carried over by fn_commit_event_draft.';

COMMIT;
