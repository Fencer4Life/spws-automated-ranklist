-- =============================================================================
-- fn_create_evf_event_from_results: qualify id_event in the backfill UPDATE
-- =============================================================================
-- The function RETURNS TABLE(id_event, txt_code), so its OUT column id_event
-- is a PL/pgSQL variable inside the body. The "row already exists" branch ran
--   UPDATE tbl_event SET id_evf_event = … WHERE id_event = v_id_evt …
-- and PL/pgSQL refused the bare id_event with 42702 "column reference is
-- ambiguous". The branch runs whenever the code allocator returns a code that
-- already exists (CURRENT_SLOT_REUSE, always so for IMEW/DMEW once their row
-- exists) and an EVF id is passed: the EVF results sync then stopped on that
-- event instead of backfilling its EVF id. Found 2026-10-24 by plpgsql_check
-- over every live function; reproduced on LOCAL; the same body is live on
-- CERT and PROD. Test: supabase/tests/22_evf_fk_ingestion.sql 22.6a–d.
--
-- The body is 20260429000003_evf_fk_ingestion.sql's, unchanged except that one
-- column, now tbl_event.id_event. Signature, SECURITY DEFINER and grants are
-- unchanged (CREATE OR REPLACE keeps them; restated below for the record).
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_create_evf_event_from_results(
  p_id_season   INT,
  p_name        TEXT,
  p_dt_start    DATE,
  p_location    TEXT,
  p_country     TEXT,
  p_is_team     BOOLEAN,
  p_id_evf_event INT DEFAULT NULL
)
RETURNS TABLE(id_event INT, txt_code TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_evf_org INT;
  v_kind    TEXT;
  v_alloc   RECORD;
  v_id_evt  INT;
BEGIN
  LOCK TABLE tbl_event IN SHARE ROW EXCLUSIVE MODE;

  SELECT o.id_organizer INTO v_evf_org FROM tbl_organizer o WHERE o.txt_code = 'EVF';
  IF v_evf_org IS NULL THEN
    RAISE EXCEPTION 'fn_create_evf_event_from_results: EVF organizer not found';
  END IF;

  v_kind := fn_classify_evf_event(p_name, p_is_team);

  SELECT * INTO v_alloc
    FROM fn_allocate_evf_event_code(p_id_season, v_kind, p_location, p_country);

  IF EXISTS (SELECT 1 FROM tbl_event ev
              WHERE ev.txt_code = v_alloc.txt_code AND ev.id_season = p_id_season) THEN
    SELECT e.id_event INTO v_id_evt FROM tbl_event e
      WHERE e.txt_code = v_alloc.txt_code AND e.id_season = p_id_season;
    -- Backfill id_evf_event when a new value is supplied and the row had NULL.
    IF p_id_evf_event IS NOT NULL THEN
      UPDATE tbl_event SET id_evf_event = p_id_evf_event
        WHERE tbl_event.id_event = v_id_evt AND tbl_event.id_evf_event IS NULL;
    END IF;
    id_event := v_id_evt;
    txt_code := v_alloc.txt_code;
    RETURN NEXT; RETURN;
  END IF;

  INSERT INTO tbl_event (
    txt_code, txt_name, id_season, id_organizer,
    dt_start, dt_end, txt_location, txt_country,
    enum_status, id_prior_event, id_evf_event
  ) VALUES (
    v_alloc.txt_code, p_name, p_id_season, v_evf_org,
    p_dt_start, p_dt_start,
    NULLIF(p_location, ''), NULLIF(p_country, ''),
    'COMPLETED', v_alloc.id_prior_event, p_id_evf_event
  ) RETURNING tbl_event.id_event INTO v_id_evt;

  id_event := v_id_evt;
  txt_code := v_alloc.txt_code;
  RETURN NEXT;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_create_evf_event_from_results(INT, TEXT, DATE, TEXT, TEXT, BOOLEAN, INT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_create_evf_event_from_results(INT, TEXT, DATE, TEXT, TEXT, BOOLEAN, INT) TO authenticated;
