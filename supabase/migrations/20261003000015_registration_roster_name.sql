-- =============================================================================
-- ADR-079 amendment (2026-10-03): a linked registration carries its fencer's
-- roster name
-- =============================================================================
-- "STANISLAWSKI ALBERT" registered for PPW1-2026-2027 on 20 Sep. He is #282
-- STANISŁAWSKI Albert. The public entry list and the FTL export read the
-- registration's own name, so a linked entrant appeared without the Ł, in the
-- case he typed, or with the name fields swapped ("MACIEJ SPLAWA - NEYMAN").
-- Polish diacritics are not optional, and the roster is the authority on a
-- fencer's name.
--
-- Once id_fencer is set, the registration's surname and first name are the
-- fencer's, whatever path links or edits it: fn_create_registration with a
-- fencer, fn_confirm_registration_identity, fn_update_registration, an admin
-- write, and fn_replace_event_registrations on the CERT refresh. A fencer
-- renamed on the roster renames his linked registrations. An unlinked
-- registration keeps the name as typed; unlinking keeps the last name.
--
-- The registrations already linked are aligned once below.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_registration_roster_name()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.id_fencer IS NOT NULL THEN
    SELECT f.txt_surname, f.txt_first_name
      INTO NEW.txt_surname, NEW.txt_first_name
      FROM tbl_fencer f
     WHERE f.id_fencer = NEW.id_fencer;
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_registration_roster_name() IS
  'ADR-079 (2026-10-03): a linked registration takes its fencer''s surname and first name from the roster. Trigger trg_registration_roster_name.';

DROP TRIGGER IF EXISTS trg_registration_roster_name ON tbl_registration;
CREATE TRIGGER trg_registration_roster_name
  BEFORE INSERT OR UPDATE OF id_fencer, txt_surname, txt_first_name ON tbl_registration
  FOR EACH ROW EXECUTE FUNCTION fn_registration_roster_name();

CREATE OR REPLACE FUNCTION fn_fencer_name_to_registrations()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE tbl_registration r
     SET txt_surname = NEW.txt_surname, txt_first_name = NEW.txt_first_name
   WHERE r.id_fencer = NEW.id_fencer
     AND (r.txt_surname IS DISTINCT FROM NEW.txt_surname
          OR r.txt_first_name IS DISTINCT FROM NEW.txt_first_name);
  RETURN NULL;
END;
$$;

COMMENT ON FUNCTION fn_fencer_name_to_registrations() IS
  'ADR-079 (2026-10-03): a fencer renamed on the roster renames his linked registrations. Trigger trg_fencer_name_to_registrations.';

DROP TRIGGER IF EXISTS trg_fencer_name_to_registrations ON tbl_fencer;
CREATE TRIGGER trg_fencer_name_to_registrations
  AFTER UPDATE OF txt_surname, txt_first_name ON tbl_fencer
  FOR EACH ROW
  WHEN (OLD.txt_surname IS DISTINCT FROM NEW.txt_surname OR OLD.txt_first_name IS DISTINCT FROM NEW.txt_first_name)
  EXECUTE FUNCTION fn_fencer_name_to_registrations();

REVOKE ALL ON FUNCTION fn_registration_roster_name() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_fencer_name_to_registrations() FROM PUBLIC, anon, authenticated;

-- The registrations linked before this migration.
UPDATE tbl_registration r
   SET txt_surname = f.txt_surname, txt_first_name = f.txt_first_name
  FROM tbl_fencer f
 WHERE f.id_fencer = r.id_fencer
   AND (r.txt_surname IS DISTINCT FROM f.txt_surname OR r.txt_first_name IS DISTINCT FROM f.txt_first_name);
