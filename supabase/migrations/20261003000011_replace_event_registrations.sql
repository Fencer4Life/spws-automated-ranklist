-- =============================================================================
-- ADR-108 §2 — fn_replace_event_registrations: PROD's entries for one event
-- =============================================================================
-- Every CERT ingestion starts from PROD's master data. For the event being
-- ingested, PROD's registrations replace the target's own: they carry the birth
-- years fencers declared (ADR-093), which the ingestion reads (declared years,
-- D5). The refresh calls this after fn_align_fencers_to, once fencer ids are
-- identical, so each entry's fencer link means the same person on both sides.
--
-- Copied:      surname, first name, gender, declared birth year, weapons, FTL
--              name, club, the fencer link.
-- Not copied:  the e-mail hash, the edit token and the consent stamp. The
--              ingestion does not read them, and personal data stays on PROD
--              (data minimisation). The target generates its own edit token.
--
-- The event is named by its exact code. A fencer link the target does not know
-- refuses the whole copy before anything is deleted.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_replace_event_registrations(
  p_event_code TEXT,
  p_rows       JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event    INT;
  v_bad      TEXT;
  v_deleted  INT;
  v_inserted INT;
BEGIN
  SELECT id_event INTO v_event FROM tbl_event WHERE txt_code = p_event_code;
  IF v_event IS NULL THEN
    RAISE EXCEPTION 'REG_EVENT_UNKNOWN: %', p_event_code;
  END IF;

  SELECT string_agg(DISTINCT x->>'id_fencer', ', ') INTO v_bad
    FROM jsonb_array_elements(COALESCE(p_rows, '[]'::JSONB)) x
   WHERE x->>'id_fencer' IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM tbl_fencer f WHERE f.id_fencer = (x->>'id_fencer')::INT);
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'REG_FENCER_UNKNOWN: % (align fencer ids before copying registrations)', v_bad;
  END IF;

  DELETE FROM tbl_registration WHERE id_event = v_event;
  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  INSERT INTO tbl_registration (id_event, id_fencer, txt_surname, txt_first_name, enum_gender,
                                int_birth_year, arr_weapons, txt_ftl_name, txt_club)
  SELECT v_event, r.id_fencer, r.txt_surname, r.txt_first_name, r.enum_gender,
         r.int_birth_year, r.arr_weapons, r.txt_ftl_name, r.txt_club
    FROM jsonb_populate_recordset(NULL::tbl_registration, COALESCE(p_rows, '[]'::JSONB)) r;
  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  RETURN jsonb_build_object('deleted', v_deleted, 'inserted', v_inserted);
END;
$$;

COMMENT ON FUNCTION fn_replace_event_registrations(TEXT, JSONB) IS
  'ADR-108 §2: replace one event''s registrations with PROD''s (no e-mail hash, edit token or consent stamp). LOCAL and CERT only.';

REVOKE ALL ON FUNCTION fn_replace_event_registrations(TEXT, JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_replace_event_registrations(TEXT, JSONB) TO service_role;
