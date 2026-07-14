-- =============================================================================
-- Sync SPWS-2026-2027's dt_start across environments (live incident 2026-07-14)
-- =============================================================================
-- CERT's SPWS-2026-2027 row was edited to dt_start = 2026-07-13 (moving the
-- season boundary earlier than the 2026-08-01 seeded on 2026-06-28), which is
-- why fn_refresh_active_season (ADR-031) already activated it there. PROD's
-- row was never given the same edit, so PROD stayed on dt_start = 2026-08-01
-- -- outside today's window -- and its active season never rolled over. The
-- "EVF Calendar + Results Sync" workflow's promote-calendar job correctly
-- refused to reconcile events across that active-season mismatch (the exact
-- guard that prevented the original Samorin cross-season duplication bug).
--
-- Idempotent on every environment: a no-op where dt_start already matches
-- (CERT), the actual fix where it doesn't (PROD). Firing on dt_start fires
-- trg_season_refresh_active (20260411000003_auto_active_season.sql), which
-- re-derives bool_active immediately -- no separate activation step needed.
-- =============================================================================

UPDATE tbl_season
   SET dt_start = '2026-07-13'
 WHERE txt_code = 'SPWS-2026-2027'
   AND dt_start <> '2026-07-13';
