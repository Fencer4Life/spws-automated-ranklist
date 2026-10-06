-- =============================================================================
-- COMPLETE — the Telegram `complete` command takes an exact code (ADR-108 §7)
-- =============================================================================
-- The daily close completes a domestic event once its end date has passed;
-- `complete <code>` stays as the manual close. It takes an exact event code
-- (a prefix could complete the wrong event), answers a prefix with the exact
-- codes it matches in the active season, and does not check the end date.
-- The parameter keeps its name, p_prefix, because the deployed GAS sends it.
-- Everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(6);

CREATE TEMP TABLE cx AS
SELECT (SELECT id_season FROM tbl_season s WHERE s.bool_active LIMIT 1) AS s,
       (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS') AS o;

INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, enum_status)
SELECT c, 'COMPLETE fixture', s, o, d, d, st::enum_event_status
  FROM cx, (VALUES ('PPW96-2026-2027', DATE '2026-09-26', 'IN_PROGRESS'),
                   ('PPW96B-2026-2027', DATE '2026-09-26', 'IN_PROGRESS'),
                   ('PPW95-2026-2027', DATE '2099-12-31', 'IN_PROGRESS'),
                   ('PPW94-2026-2027', DATE '2026-09-26', 'PLANNED')) v(c, d, st);

SELECT throws_like(
  $$SELECT fn_complete_event('PPW96')$$,
  '%COMPLETE_EXACT_CODE%PPW96-2026-2027, PPW96B-2026-2027%',
  'COMPLETE.01 a prefix refuses and names the exact codes it matches');

SELECT is((SELECT count(*)::INT FROM tbl_event
            WHERE txt_code IN ('PPW96-2026-2027', 'PPW96B-2026-2027') AND enum_status = 'COMPLETED'), 0,
  'COMPLETE.02 a refused prefix completes nothing');

SELECT throws_like(
  $$SELECT fn_complete_event('NOPE99-2026-2027')$$,
  '%COMPLETE_EXACT_CODE%',
  'COMPLETE.03 an unknown code refuses');

SELECT is((fn_complete_event('PPW96-2026-2027') ->> 'status'), 'COMPLETED',
  'COMPLETE.04 the exact code completes the event');

SELECT is((fn_complete_event('PPW95-2026-2027') ->> 'event_code'), 'PPW95-2026-2027',
  'COMPLETE.05 the end date is not checked: an event ending in 2099 completes');

SELECT throws_like(
  $$SELECT fn_complete_event('PPW94-2026-2027')$$,
  '%must be IN_PROGRESS%',
  'COMPLETE.06 an event that is not IN_PROGRESS refuses, as before');

SELECT * FROM finish();
ROLLBACK;
