-- =============================================================================
-- FR-170: the administrator's edit of a linked entry reaches the roster
-- (ADR-079 amendment 2026-11-21, release 4; the user's addition of 22 Nov 2026,
-- pixel sheet registration-admin-edit-release-4-pixel-sheet-2026-11-21.html
-- §05, R1–R3 A)
-- =============================================================================
-- fn_update_registration_as_admin replaces the admin application's direct
-- UPDATE of tbl_registration. One transaction:
--   1. the entry takes the declared fields; a linked entry's name is the
--      roster's (trg_registration_roster_name), so p_surname / p_first_name
--      are used for a newcomer only; every rule of releases 1–3 is the table's
--      own trigger or reference and still decides;
--   2. for a linked entry only (R1), what this save changed reaches the roster
--      (R2): the birth year, confirmed, through fn_update_fencer_birth_year
--      (whose trigger queues the fencer's events for recompute, ADR-072); the
--      gender through fn_update_fencer_gender; the country as the event
--      season's ADMIN row in tbl_fencer_nationality (R3), never
--      tbl_fencer.txt_nationality. The club stays the entry's own
--      (20260913000001). A field left as it was is never copied.
-- A refused write anywhere refuses the whole save. Signed-in administrators
-- only: anon has no EXECUTE, and the body checks the role as well.
-- Tests: supabase/tests/135_registration_admin_edit_roster.sql (RFADM.16–22).
-- =============================================================================

BEGIN;

SET LOCAL lock_timeout = '2s';

CREATE OR REPLACE FUNCTION fn_update_registration_as_admin(
  p_id_registration INT,
  p_surname         TEXT,
  p_first_name      TEXT,
  p_gender          enum_gender_type,
  p_birth_year      INT,
  p_weapons         enum_weapon_type[],
  p_club            TEXT,
  p_country         TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_old     tbl_registration%ROWTYPE;
  v_country TEXT := NULLIF(btrim(p_country), '');
  v_season  INT;
BEGIN
  IF COALESCE(auth.role(), '') <> 'authenticated' THEN
    RAISE EXCEPTION 'REG_ADMIN_ONLY: only a signed-in administrator edits an entry'
      USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_old FROM tbl_registration WHERE id_registration = p_id_registration FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Registration % not found', p_id_registration USING ERRCODE = 'P0002';
  END IF;

  UPDATE tbl_registration
     SET txt_surname    = CASE WHEN v_old.id_fencer IS NULL THEN COALESCE(p_surname, txt_surname) ELSE txt_surname END,
         txt_first_name = CASE WHEN v_old.id_fencer IS NULL THEN COALESCE(p_first_name, txt_first_name) ELSE txt_first_name END,
         enum_gender    = p_gender,
         int_birth_year = p_birth_year,
         arr_weapons    = p_weapons,
         txt_club       = NULLIF(btrim(p_club), ''),
         txt_country    = v_country
   WHERE id_registration = p_id_registration;

  IF v_old.id_fencer IS NULL THEN
    RETURN;
  END IF;

  IF p_birth_year IS DISTINCT FROM v_old.int_birth_year THEN
    PERFORM fn_update_fencer_birth_year(v_old.id_fencer, p_birth_year, FALSE);
  END IF;

  IF p_gender IS DISTINCT FROM v_old.enum_gender THEN
    PERFORM fn_update_fencer_gender(v_old.id_fencer, p_gender);
  END IF;

  IF v_country IS NOT NULL AND v_country IS DISTINCT FROM v_old.txt_country THEN
    SELECT id_season INTO v_season FROM tbl_event WHERE id_event = v_old.id_event;
    INSERT INTO tbl_fencer_nationality (id_fencer, id_season, txt_country, id_result_first, enum_source)
    VALUES (v_old.id_fencer, v_season, v_country, NULL, 'ADMIN')
    ON CONFLICT (id_fencer, id_season) DO UPDATE
       SET txt_country     = EXCLUDED.txt_country,
           id_result_first = NULL,
           enum_source     = 'ADMIN',
           ts_updated      = NOW();
  END IF;
END;
$$;

COMMENT ON FUNCTION fn_update_registration_as_admin(INT, TEXT, TEXT, enum_gender_type, INT, enum_weapon_type[], TEXT, TEXT) IS
  'FR-170: the administrator''s edit of an entry; a linked entry''s changed birth year, gender and country reach the roster in the same transaction.';

REVOKE ALL ON FUNCTION fn_update_registration_as_admin(INT, TEXT, TEXT, enum_gender_type, INT, enum_weapon_type[], TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fn_update_registration_as_admin(INT, TEXT, TEXT, enum_gender_type, INT, enum_weapon_type[], TEXT, TEXT) TO authenticated, service_role;

COMMIT;
