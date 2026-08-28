-- =============================================================================
-- An EVF event with unknown weapons may not leave PLANNED
-- =============================================================================
-- On 2026-08-19 EVF published "EVF Circuit – Tampere (FIN)" (calendar id 5379)
-- as a stub post carrying no weapon categories. The scraper now derives weapons
-- from an evidence ladder (list categories → detail categories → detail body →
-- invitation PDF → approved override) and, where every rung is silent, holds the
-- entry back rather than inventing one — see partition_unweaponed() in
-- python/scrapers/evf_calendar.py.
--
-- This is the database-side half of the same rule, so it holds even when the
-- scraper is not the writer: an EVF event whose weapons are unknown must not
-- advance into a lifecycle state where tournaments and results can attach to it.
--
-- Why the txt_code suffix and NOT arr_weapons:
--   arr_weapons cannot express "unknown". Its DEFAULT is '{EPEE,FOIL,SABRE}',
--   so omitting the column silently asserts all three. Measured on CERT
--   2026-08-28: ZERO rows are NULL and 86 of 96 sit on that default, including
--   60 COMPLETED events — among them epee-only and sabre-only ones. A guard
--   written against arr_weapons would therefore pass for every row including the
--   wrong ones: a guard that always passes, which is worse than none.
--   The code suffix is authoritative (ADR-046), which is exactly why
--   frontend/src/lib/calendarQuarters.ts:weaponLetters() reads weapons from it
--   and returns [] — "rather than a guess" — for an unsuffixed code.
--
-- Why a trigger on UPDATE and NOT a CHECK constraint:
--   supabase/seed_prod_latest.sql inserts 32+ unsuffixed PEW events ALREADY in
--   COMPLETED (PEW11-2024-2025 Guildford, PEW13-2023-2024, PEW68-2026-2027, …).
--   Migrations run BEFORE the seed dump on LOCAL and in CI (ADR-036 amendment),
--   so a CHECK would reject the seed on every reset-dev.sh and every CI run.
--   NOT VALID does not help: it skips validation of pre-existing rows but still
--   binds subsequent inserts. A trigger fires on the TRANSITION, which is what
--   the rule actually means — historical rows are inserted already-COMPLETED and
--   never transition, so they load untouched.
--
-- Accepted residual gap: a direct INSERT of a non-PLANNED unsuffixed PEW event
-- is not blocked, because blocking it is precisely what breaks the seed. The
-- scraper always creates PLANNED, so this only reaches hand-written SQL.
--
-- Scoped to EVF codes: PPW1-2026-2027 and MSW-2026-2027 legitimately carry no
-- weapon letters and are CREATED; an unscoped rule would break them immediately.
--
-- Plan-test-ID 60 (supabase/tests/60_evf_event_weapons_lifecycle_gate.sql).
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_guard_evf_event_weapons_known()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Only EVF-coded events, and only an unsuffixed one: PEW<number>-<season>
  -- with no e/f/s letters means the weapons were never established.
  IF NEW.txt_code !~ '^PEW[0-9]+-' THEN
    RETURN NEW;
  END IF;

  -- Only the transition out of PLANNED is refused; edits within PLANNED, and
  -- any update that leaves the status alone, pass through untouched.
  IF NEW.enum_status IS DISTINCT FROM OLD.enum_status
     AND OLD.enum_status = 'PLANNED'
     AND NEW.enum_status <> 'PLANNED' THEN
    RAISE EXCEPTION
      'fn_guard_evf_event_weapons_known: % has no weapons in its code and may '
      'not leave PLANNED (attempted %). Establish the weapons first — the code '
      'suffix is the authoritative record (ADR-046).',
      NEW.txt_code, NEW.enum_status;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_evf_event_weapons_known ON tbl_event;

CREATE TRIGGER trg_guard_evf_event_weapons_known
  BEFORE UPDATE ON tbl_event
  FOR EACH ROW
  EXECUTE FUNCTION fn_guard_evf_event_weapons_known();

COMMIT;
