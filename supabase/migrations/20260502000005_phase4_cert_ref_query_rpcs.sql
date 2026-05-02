-- =============================================================================
-- Phase 4 (ADR-050) — cert_ref query RPCs
--
-- Supabase clients access the public schema by default; cert_ref is a
-- separate schema. These RPCs expose the cert_ref data the orchestrator
-- needs (3-way diff CERT column + cert_ref parser inputs) via SECURITY
-- DEFINER functions.
--
--   fn_cert_ref_rows_for_event(p_event_code)     → list-of-dicts for diff
--   fn_cert_ref_tournament_for_event(p_event_code) → tournament metadata
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Per-result rows for diff (joined to fencer for name)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_cert_ref_rows_for_event(p_event_code TEXT)
RETURNS TABLE (
  id_result        INT,
  id_tournament    INT,
  id_fencer        INT,
  int_place        INT,
  txt_first_name   TEXT,
  txt_surname      TEXT,
  txt_nationality  TEXT,
  int_birth_year   INT,
  enum_age_category TEXT,    -- cert_ref stores enums as TEXT (loose coupling)
  num_final_score  NUMERIC,
  fencer_name      TEXT
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT
    r.id_result,
    r.id_tournament,
    r.id_fencer,
    r.int_place,
    f.txt_first_name,
    f.txt_surname,
    f.txt_nationality,
    f.int_birth_year::INT,
    r.enum_fencer_age_category,
    r.num_final_score,
    (f.txt_surname || ' ' || f.txt_first_name) AS fencer_name
  FROM cert_ref.tbl_event   e
  JOIN cert_ref.tbl_tournament t ON t.id_event = e.id_event
  JOIN cert_ref.tbl_result  r    ON r.id_tournament = t.id_tournament
  JOIN cert_ref.tbl_fencer  f    ON f.id_fencer = r.id_fencer
  WHERE e.txt_code = p_event_code
  ORDER BY r.int_place;
$$;

COMMENT ON FUNCTION fn_cert_ref_rows_for_event(TEXT) IS
  'Fetch cert_ref result rows for an event (joined to fencer). Used by '
  '3-way diff (ADR-050) and by the cert_ref parser when operator picks '
  '`[5] cert_ref placements` in review CLI. Returns empty when cert_ref '
  'schema is unpopulated or the event_code is absent.';

REVOKE EXECUTE ON FUNCTION fn_cert_ref_rows_for_event(TEXT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_cert_ref_rows_for_event(TEXT) TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. Tournament metadata (first tournament of the event for cert_ref parser)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_cert_ref_tournament_for_event(p_event_code TEXT)
RETURNS TABLE (
  id_tournament         INT,
  txt_code              TEXT,
  enum_weapon           TEXT,    -- cert_ref stores enums as TEXT
  enum_gender           TEXT,
  enum_age_category     TEXT,
  dt_tournament         DATE,
  int_participant_count INT
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT
    t.id_tournament,
    t.txt_code,
    t.enum_weapon,
    t.enum_gender,
    t.enum_age_category,
    t.dt_tournament,
    t.int_participant_count
  FROM cert_ref.tbl_event   e
  JOIN cert_ref.tbl_tournament t ON t.id_event = e.id_event
  WHERE e.txt_code = p_event_code
  ORDER BY t.id_tournament
  LIMIT 1;
$$;

COMMENT ON FUNCTION fn_cert_ref_tournament_for_event(TEXT) IS
  'Fetch the (first) tournament for an event from cert_ref schema. '
  'Used by the cert_ref parser to populate ParsedTournament metadata.';

REVOKE EXECUTE ON FUNCTION fn_cert_ref_tournament_for_event(TEXT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_cert_ref_tournament_for_event(TEXT) TO authenticated, service_role;

COMMIT;
