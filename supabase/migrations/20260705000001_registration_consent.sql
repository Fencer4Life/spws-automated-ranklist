-- =============================================================================
-- P2.0 — Registration consent + expiry guard (ADR-078/079/080; spec §5.2)
-- =============================================================================
-- Extends fn_create_registration (migration 20260704000001) with:
--   1. p_consent_version — stamps ts_consent/txt_consent_version when the
--      frontend passes it (RODO-gate accept, D5). NULL = unchanged (existing
--      calls, e.g. pgTAP 49.14/49.20/49.21, stay green with no consent).
--   2. A registration-window guard (D10) — rejects the write once
--      COALESCE(dt_registration_deadline, dt_start) has passed, so a stale
--      shared link can no longer register into a closed/past event. NULL
--      dates (open events, existing fixtures) are always open.
-- DROP + recreate (not a bare CREATE OR REPLACE) per the signed-off plan —
-- explicit about the parameter-list change even though PL/pgSQL allows
-- appending a trailing DEFAULT-valued param without it.
-- =============================================================================

DROP FUNCTION IF EXISTS fn_create_registration(INT, TEXT, TEXT, enum_gender_type, SMALLINT, enum_weapon_type[], INT, TEXT);

CREATE OR REPLACE FUNCTION fn_create_registration(
  p_event           INT,
  p_surname         TEXT,
  p_first_name      TEXT,
  p_gender          enum_gender_type,
  p_birth_year      SMALLINT,
  p_weapons         enum_weapon_type[],
  p_id_fencer       INT DEFAULT NULL,
  p_email_hash      TEXT DEFAULT NULL,
  p_consent_version TEXT DEFAULT NULL
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id      INT;
  v_cutoff  DATE;
BEGIN
  SELECT COALESCE(dt_registration_deadline, dt_start) INTO v_cutoff
  FROM tbl_event WHERE id_event = p_event;

  IF v_cutoff IS NOT NULL AND now()::date > v_cutoff THEN
    RAISE EXCEPTION 'Registration window closed for event %', p_event;
  END IF;

  INSERT INTO tbl_registration (
    id_event, id_fencer, txt_surname, txt_first_name, enum_gender,
    int_birth_year, arr_weapons, txt_email_hash,
    ts_consent, txt_consent_version
  ) VALUES (
    p_event, p_id_fencer, p_surname, p_first_name, p_gender,
    p_birth_year, p_weapons, p_email_hash,
    CASE WHEN p_consent_version IS NOT NULL THEN now() END, p_consent_version
  )
  ON CONFLICT (id_event, id_fencer) DO UPDATE SET
    txt_surname         = EXCLUDED.txt_surname,
    txt_first_name       = EXCLUDED.txt_first_name,
    enum_gender          = EXCLUDED.enum_gender,
    int_birth_year       = EXCLUDED.int_birth_year,
    arr_weapons          = EXCLUDED.arr_weapons,
    ts_consent           = COALESCE(EXCLUDED.ts_consent, tbl_registration.ts_consent),
    txt_consent_version  = COALESCE(EXCLUDED.txt_consent_version, tbl_registration.txt_consent_version)
  RETURNING id_registration INTO v_id;

  RETURN v_id;
END;
$$;

COMMENT ON FUNCTION fn_create_registration IS
  'Sole public write path for tbl_registration (FR-122). p_consent_version '
  'stamps ts_consent+txt_consent_version when given (RODO accept, D5). '
  'Rejects the write once COALESCE(dt_registration_deadline, dt_start) has '
  'passed (D10 registration-window guard); NULL dates are always open.';
