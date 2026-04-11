-- =============================================================================
-- Identity Manager Enhancements (ADR-033, ADR-034)
-- =============================================================================
-- a) Add enum_gender to tbl_fencer
-- b) Backfill gender from tournament participation
-- c) New RPC: fn_update_fencer_gender
-- d) Update vw_match_candidates with gender columns
-- e) Widen fn_approve_match to accept AUTO_MATCHED
-- f) Widen fn_dismiss_match to accept AUTO_MATCHED
-- g) Widen fn_create_fencer_from_match to accept AUTO_MATCHED + add p_gender
-- =============================================================================


-- ---------------------------------------------------------------------------
-- (a) Add gender column to tbl_fencer
-- ---------------------------------------------------------------------------
ALTER TABLE tbl_fencer ADD COLUMN IF NOT EXISTS enum_gender enum_gender_type;


-- ---------------------------------------------------------------------------
-- (b) Backfill gender from tournament participation (majority vote)
-- ---------------------------------------------------------------------------
UPDATE tbl_fencer f
SET enum_gender = sub.dominant_gender
FROM (
  SELECT r.id_fencer, t.enum_gender AS dominant_gender,
         ROW_NUMBER() OVER (PARTITION BY r.id_fencer ORDER BY COUNT(*) DESC) AS rn
  FROM tbl_result r
  JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
  WHERE t.enum_gender IS NOT NULL
  GROUP BY r.id_fencer, t.enum_gender
) sub
WHERE f.id_fencer = sub.id_fencer AND sub.rn = 1
  AND f.enum_gender IS NULL;


-- ---------------------------------------------------------------------------
-- (c) fn_update_fencer_gender
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_update_fencer_gender(p_fencer_id INT, p_gender enum_gender_type)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE tbl_fencer SET enum_gender = p_gender, ts_updated = NOW()
  WHERE id_fencer = p_fencer_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Fencer % not found', p_fencer_id;
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_update_fencer_gender(INT, enum_gender_type) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_update_fencer_gender(INT, enum_gender_type) TO authenticated;


-- ---------------------------------------------------------------------------
-- (d) Update vw_match_candidates — add tournament + fencer gender
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_match_candidates AS
SELECT
  mc.id_match,
  mc.id_result,
  mc.txt_scraped_name,
  mc.id_fencer,
  mc.num_confidence,
  mc.enum_status,
  mc.txt_admin_note,
  f.txt_surname || ' ' || f.txt_first_name AS txt_fencer_name,
  t.txt_code AS txt_tournament_code,
  t.enum_type,
  t.enum_gender AS enum_tournament_gender,
  f.enum_gender AS enum_fencer_gender
FROM tbl_match_candidate mc
JOIN tbl_result r ON mc.id_result = r.id_result
JOIN tbl_tournament t ON r.id_tournament = t.id_tournament
LEFT JOIN tbl_fencer f ON mc.id_fencer = f.id_fencer;


-- ---------------------------------------------------------------------------
-- (e) fn_approve_match — widen to accept PENDING + AUTO_MATCHED
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_approve_match(p_match_id INT, p_fencer_id INT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result_id INT;
  v_status    enum_match_status;
BEGIN
  SELECT mc.id_result, mc.enum_status INTO v_result_id, v_status
  FROM tbl_match_candidate mc WHERE mc.id_match = p_match_id;

  IF v_result_id IS NULL THEN
    RAISE EXCEPTION 'Match candidate % not found', p_match_id;
  END IF;

  IF v_status NOT IN ('PENDING', 'AUTO_MATCHED') THEN
    RAISE EXCEPTION 'Only PENDING or AUTO_MATCHED candidates can be approved (current: %)', v_status;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM tbl_fencer WHERE id_fencer = p_fencer_id) THEN
    RAISE EXCEPTION 'Fencer % not found', p_fencer_id;
  END IF;

  UPDATE tbl_match_candidate
  SET id_fencer = p_fencer_id, enum_status = 'APPROVED', ts_updated = NOW()
  WHERE id_match = p_match_id;

  UPDATE tbl_result
  SET id_fencer = p_fencer_id, ts_updated = NOW()
  WHERE id_result = v_result_id;

  RETURN jsonb_build_object('id_match', p_match_id, 'id_fencer', p_fencer_id, 'status', 'APPROVED');
END;
$$;


-- ---------------------------------------------------------------------------
-- (f) fn_dismiss_match — widen to accept AUTO_MATCHED
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_dismiss_match(p_match_id INT, p_note TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_status enum_match_status;
BEGIN
  SELECT enum_status INTO v_status
  FROM tbl_match_candidate WHERE id_match = p_match_id;

  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Match candidate % not found', p_match_id;
  END IF;

  IF v_status NOT IN ('PENDING', 'UNMATCHED', 'AUTO_MATCHED') THEN
    RAISE EXCEPTION 'Only PENDING, UNMATCHED, or AUTO_MATCHED candidates can be dismissed (current: %)', v_status;
  END IF;

  UPDATE tbl_match_candidate
  SET enum_status = 'DISMISSED', txt_admin_note = p_note, ts_updated = NOW()
  WHERE id_match = p_match_id;

  RETURN jsonb_build_object('id_match', p_match_id, 'status', 'DISMISSED');
END;
$$;


-- ---------------------------------------------------------------------------
-- (g) fn_create_fencer_from_match — widen + add p_gender parameter
-- ---------------------------------------------------------------------------
-- Drop old signature first (different param count)
DROP FUNCTION IF EXISTS fn_create_fencer_from_match(INT, TEXT, TEXT, INT);

CREATE OR REPLACE FUNCTION fn_create_fencer_from_match(
  p_match_id   INT,
  p_surname    TEXT,
  p_first_name TEXT,
  p_birth_year INT DEFAULT NULL,
  p_gender     enum_gender_type DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result_id  INT;
  v_status     enum_match_status;
  v_fencer_id  INT;
BEGIN
  SELECT mc.id_result, mc.enum_status INTO v_result_id, v_status
  FROM tbl_match_candidate mc WHERE mc.id_match = p_match_id;

  IF v_result_id IS NULL THEN
    RAISE EXCEPTION 'Match candidate % not found', p_match_id;
  END IF;

  IF v_status NOT IN ('PENDING', 'UNMATCHED', 'AUTO_MATCHED') THEN
    RAISE EXCEPTION 'Only PENDING, UNMATCHED, or AUTO_MATCHED candidates can create new fencers (current: %)', v_status;
  END IF;

  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, bool_birth_year_estimated, enum_gender)
  VALUES (p_surname, p_first_name, p_birth_year, p_birth_year IS NOT NULL, p_gender)
  RETURNING id_fencer INTO v_fencer_id;

  UPDATE tbl_match_candidate
  SET id_fencer = v_fencer_id, enum_status = 'NEW_FENCER', ts_updated = NOW()
  WHERE id_match = p_match_id;

  UPDATE tbl_result
  SET id_fencer = v_fencer_id, ts_updated = NOW()
  WHERE id_result = v_result_id;

  RETURN jsonb_build_object(
    'id_match', p_match_id,
    'id_fencer', v_fencer_id,
    'status', 'NEW_FENCER'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_create_fencer_from_match(INT, TEXT, TEXT, INT, enum_gender_type) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_create_fencer_from_match(INT, TEXT, TEXT, INT, enum_gender_type) TO authenticated;
