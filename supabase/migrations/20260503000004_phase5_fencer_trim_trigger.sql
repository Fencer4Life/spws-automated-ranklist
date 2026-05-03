-- =============================================================================
-- Phase 5.5 — tbl_fencer.txt_surname / txt_first_name auto-trim trigger
-- =============================================================================
-- Defence-in-depth complement to phase5_runner.py's seed-export .strip()
-- (commit fe63319 / plan-test-ID 5.13.2).
--
-- Bug history (operator caught 2026-05-03 while rescraping GP6):
-- BURLIKOWSKI Bartosz was added via the legacy window.prompt admin flow;
-- the prompt didn't .trim() user input, so the fencer landed in tbl_fencer
-- with txt_first_name = ' Bartosz' (leading space). The Phase-5 seed export
-- then quoted the corrupted value into seed_phase5_increments.sql and any
-- downstream lookup that didn't normalise whitespace lost track of him.
--
-- The new modal (CreateFencerFromAliasModal.svelte) trims at the form
-- boundary, and the seed export now strips on emit. This trigger closes
-- the loop at the DB level so ANY caller — current or future — gets
-- whitespace-normalised txt_surname / txt_first_name on INSERT or UPDATE.
--
-- Plan-test-ID 5.14 (supabase/tests/38_fencer_trim_trigger.sql).
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_trim_fencer_names()
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

COMMENT ON FUNCTION fn_trim_fencer_names() IS
  'Phase 5.5 (5.14) — BEFORE INSERT OR UPDATE trigger on tbl_fencer that '
  'btrims txt_surname + txt_first_name. Closes the loop on the historical '
  'leading-space corruption from the legacy window.prompt admin flow. '
  'Defence in depth — modal + seed-export already trim at their boundaries.';

DROP TRIGGER IF EXISTS trg_trim_fencer_names ON tbl_fencer;

CREATE TRIGGER trg_trim_fencer_names
  BEFORE INSERT OR UPDATE OF txt_surname, txt_first_name ON tbl_fencer
  FOR EACH ROW
  EXECUTE FUNCTION fn_trim_fencer_names();

COMMIT;
