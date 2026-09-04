-- =============================================================================
-- The event's weapons live on the event, and the guard that fills them fires
-- =============================================================================
-- tbl_event.arr_weapons is the field the calendar card reads to show which
-- weapons an event runs. It has been wrong for most EVF events since it was
-- added, for a reason that is worth stating precisely because the shape of the
-- mistake is reusable.
--
-- 20260327000006 declared the column DEFAULT '{EPEE,FOIL,SABRE}'.
-- 20260420000002 then filled it behind a fill-blank guard:
--
--     arr_weapons = CASE WHEN arr_weapons IS NULL
--                          THEN COALESCE(v_weapons, arr_weapons)
--                        ELSE arr_weapons END
--
-- A column carrying a non-null DEFAULT is never NULL, so that branch never ran.
-- The scraper resolves an event's weapons through the ADR-086 evidence ladder
-- and writes them into the event CODE, but they never reached the column. On
-- CERT before this migration: 53 of 69 events whose code carries a weapon suffix
-- sat on the untouched default and 35 of them contradicted their own code --
-- PEW10e, an epee-only competition, advertising foil and sabre.
--
-- Nothing surfaced it because the default is *plausible*: three weapons is what
-- a domestic PPW or MPW genuinely runs, so the wrong value looked like data.
--
-- THE FIX IS THE DEFAULT, NOT THE GUARD. Dropping it makes NULL mean "nobody has
-- said", which is what the guard was always written against and what the column
-- needs in order to distinguish "genuinely all three" from "untouched". The
-- guard itself is left exactly as it is; it starts working the moment NULL is
-- reachable.
--
-- WHY THE CODE SUFFIX IS THE BACKFILL SOURCE. ADR-046 and ADR-086 make the
-- suffix the authoritative weapon record, and it is corroborated: in every one
-- of the 35 disagreements the suffix matched the event's own tournaments and
-- arr_weapons did not. Events with no suffix -- PPW, MPW, GP, IMEW, IMSW, MSW,
-- DMEW, VFC -- keep all three weapons, verified the same way: all 25 of them
-- that have tournaments read exactly EPEE,FOIL,SABRE.
--
-- Plan-test-ID 71 (supabase/tests/71_event_weapons_from_code.sql).
-- =============================================================================

BEGIN;

SET LOCAL lock_timeout = '2s';

-- 1. Backfill from the authoritative source BEFORE the default goes, so no row
--    is left NULL by the change itself.
UPDATE tbl_event e
   SET arr_weapons = ARRAY(
         SELECT w FROM (
           SELECT CASE c WHEN 'e' THEN 'EPEE' WHEN 'f' THEN 'FOIL'
                         WHEN 's' THEN 'SABRE' END AS w
           FROM regexp_split_to_table(
                  substring(split_part(e.txt_code, '-', 1) FROM '[efs]+$'), ''
                ) AS c
         ) x ORDER BY w
       )::enum_weapon_type[],
       ts_updated = NOW()
 WHERE split_part(e.txt_code, '-', 1) ~ '[efs]$';

-- 2. Drop the default. This is the actual repair: NULL becomes reachable, so
--    "nobody has set this" is expressible and every NULL-guarded fill on this
--    column starts working.
--
--    Existing rows keep whatever they hold -- dropping a default never rewrites
--    stored values -- so the suffix-less families (PPW, MPW, DMEW, IMEW, MSW)
--    retain the all-three set that is correct for them.
ALTER TABLE tbl_event ALTER COLUMN arr_weapons DROP DEFAULT;

COMMENT ON COLUMN tbl_event.arr_weapons IS
  'Weapons the event runs. NULL means nobody has established them yet -- the '
  'column deliberately carries NO default, because a default made NULL '
  'unreachable and silently disabled every fill-blank guard written against it. '
  'For an event whose code carries a weapon suffix the suffix is authoritative '
  '(ADR-046, ADR-086) and this column agrees with it.';

COMMIT;
