-- =============================================================================
-- Scope idx_tbl_event_evf_slug to (id_season, txt_evf_slug) (ADR-039 rev 3
-- follow-up, live incident 2026-07-14)
-- =============================================================================
-- Root cause: 20260710000001_evf_slug_dedup.sql made txt_evf_slug globally
-- unique. That was correct for its target bug (7x Samorin duplicates WITHIN
-- one season) but wrong across a season boundary: EVF reuses the same
-- detail-page slug (e.g. "evf-circuit-munich") for every yearly edition of a
-- recurring circuit stop. The first calendar sync against the newly-active
-- SPWS-2026-2027 season (2026-07-14) tried to insert next season's Munich
-- row with the same slug as last season's completed row and hit the global
-- unique index. fn_import_evf_events_v2 inserts its whole batch in one
-- statement, so that single collision rolled back all 13 new events for the
-- season, not just Munich -- calendar sync appeared to find nothing new on
-- every subsequent scheduled run.
--
-- Fix: uniqueness is what it always needed to be -- one slug per season, not
-- one slug ever. Same-season duplicate creation (the original Samorin bug)
-- stays impossible; cross-season reuse of a recurring event's slug is now
-- allowed. See supabase/tests/50_evf_slug_dedup.sql 50.5 (same-season, still
-- rejected) and 50.8 (cross-season, now allowed).
-- =============================================================================

DROP INDEX IF EXISTS idx_tbl_event_evf_slug;

CREATE UNIQUE INDEX idx_tbl_event_evf_slug
  ON tbl_event (id_season, txt_evf_slug)
  WHERE txt_evf_slug IS NOT NULL;

COMMENT ON INDEX idx_tbl_event_evf_slug IS
  'One EVF slug per season, not one slug ever -- EVF reuses the same '
  'detail-page slug across yearly editions of a recurring circuit stop. '
  'Scoped by id_season since 20260714000001 (was global from '
  '20260710000001, see that migration for the original Samorin-duplicate '
  'intent this preserves).';
