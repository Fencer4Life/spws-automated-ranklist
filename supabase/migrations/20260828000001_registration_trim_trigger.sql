-- =============================================================================
-- tbl_registration.txt_surname / txt_first_name auto-trim trigger + backfill
-- =============================================================================
-- tbl_fencer has had this since 20260503000004 (fn_trim_fencer_names, plan-test
-- ID 5.14). tbl_registration never got the equivalent, and once the public
-- registration form went live on PROD the same class of defect reappeared:
-- RegistrationForm.svelte validated the entry with `surname.trim() !== ''` but
-- submitted the RAW string, so a fencer who typed a trailing space had it
-- persisted verbatim. Two of the first fourteen live PROD registrations carry
-- one ("Gary ", "KUCIĘBA "), and one of eight on CERT.
--
-- Blast radius of the stored value, verified rather than assumed:
--   * vw_registration_entry_list projects txt_surname/txt_first_name straight
--     through, and EntryList.svelte renders them raw — so the public roster
--     carries the padding (HTML collapses it visually, the data does not).
--   * The FTL seed file is NOT affected: ftl_seed_export.to_canonical_name()
--     already .strip()s both names, and it is the only path registration names
--     take into the XML.
--   * Dedupe is NOT affected: uq_registration_unmatched_identity normalises
--     with upper(btrim(...)) already.
-- The defect is therefore in what we store and publish, not in what we export
-- or match on — but storing the declared identity clean is the fix that makes
-- all three agree.
--
-- Why a trigger and not just a form fix: tbl_registration carries an admin
-- "FOR ALL" RLS policy, so an authenticated PostgREST write never passes
-- through the form at all. The form is fixed in the same change (defence in
-- depth, exactly as 20260503000004 paired with CreateFencerFromAliasModal).
--
-- BEFORE INSERT fires ahead of ON CONFLICT arbitration, so fn_create_registration
-- arbitrates on the trimmed tuple. That cannot change which row it picks:
-- the arbiter is upper(btrim(...)) and btrim is idempotent. Pinned by 57.7.
--
-- Plan-test-ID 57 (supabase/tests/57_registration_trim_trigger.sql).
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_trim_registration_names()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.txt_surname IS NOT NULL THEN
    NEW.txt_surname := btrim(NEW.txt_surname);
  END IF;
  IF NEW.txt_first_name IS NOT NULL THEN
    NEW.txt_first_name := btrim(NEW.txt_first_name);
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_trim_registration_names() IS
  'BEFORE INSERT OR UPDATE trigger on tbl_registration that btrims '
  'txt_surname + txt_first_name. Deliberately a separate function from '
  'fn_trim_fencer_names() rather than one shared helper: the two tables are '
  'independent and a shared function would couple a live public write path to '
  'the fencer master table for the sake of nine identical lines.';

DROP TRIGGER IF EXISTS trg_trim_registration_names ON tbl_registration;

CREATE TRIGGER trg_trim_registration_names
  BEFORE INSERT OR UPDATE OF txt_surname, txt_first_name ON tbl_registration
  FOR EACH ROW
  EXECUTE FUNCTION fn_trim_registration_names();

-- Backfill the rows written before the trigger existed. Scoped to rows that
-- actually differ, so it is a no-op on a fresh database and on any environment
-- already clean — and re-running the migration cannot touch a clean row.
-- Safe against the unique index: it is keyed on upper(btrim(...)), so trimming
-- leaves every key byte-identical and no collision can be introduced.
UPDATE tbl_registration
   SET txt_surname    = btrim(txt_surname),
       txt_first_name = btrim(txt_first_name)
 WHERE txt_surname    <> btrim(txt_surname)
    OR txt_first_name <> btrim(txt_first_name);

COMMIT;
