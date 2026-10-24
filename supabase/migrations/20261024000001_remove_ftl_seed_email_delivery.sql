-- =============================================================================
-- Remove the FTL seed e-mail delivery (ADR-080 amendment 2026-10-24)
-- =============================================================================
-- The e-mail delivery of seed files was withdrawn on 2026-09-25 and is now
-- removed from the tree: the association holds no registered sending identity,
-- and the organizer downloads the files from the capability-link page.
--
-- 1. fn_mark_ftl_sent stamped tbl_event.ts_ftl_sent after SMTP acceptance. Its
--    only caller, python/pipeline/ftl_feed_seed_send.py, is deleted in the same
--    change, and it never ran: 0 of 104 events carry a stamp on CERT or PROD
--    (checked 2026-10-24).
-- 2. ts_ftl_sent and txt_organizer_email are RETIRED, not dropped. Both are empty
--    on every CERT and PROD event, no code reads or writes them, and they stay
--    because the seed dump every LOCAL and CI bootstrap loads names them and
--    vw_calendar selects them. Drop them together with a seed regeneration.
--
-- Untouched: vw_calendar, fn_update_event (its p_txt_organizer_email parameter
-- defaults to NULL = leave unchanged), the PROD mirror functions, and the
-- download page's fn_ftl_export_* / fn_ftl_roster / tbl_ftl_export_token.
--
-- Plan: doc/plans/ftl-seed-email-removal-2026-10-24.html.
-- Tests: supabase/tests/49_registration_schema.sql NOMAIL.06-07;
-- python/tests/test_no_outbound_email.py NOMAIL.01-04.
-- =============================================================================
SET LOCAL lock_timeout = '2s';

DROP FUNCTION IF EXISTS fn_mark_ftl_sent(TEXT);

COMMENT ON COLUMN tbl_event.ts_ftl_sent IS
  'Retired 2026-10-24 (ADR-080 amendment): the e-mail delivery that stamped it is removed. Never written; kept so the seed dump and vw_calendar stay valid. Drop together with a seed regeneration.';

COMMENT ON COLUMN tbl_event.txt_organizer_email IS
  'Retired 2026-10-24 (ADR-080 amendment): it held the recipient of the removed e-mail delivery. Not read by any code; fn_update_event still accepts it (NULL = unchanged). Kept so the seed dump and vw_calendar stay valid. Drop together with a seed regeneration.';
