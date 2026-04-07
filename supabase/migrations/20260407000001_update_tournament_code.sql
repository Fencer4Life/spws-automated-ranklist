-- Extend fn_update_tournament to allow txt_code editing.
-- Drop old 4-param signature to avoid ambiguous overloading.

DROP FUNCTION IF EXISTS fn_update_tournament(INT, TEXT, enum_import_status, TEXT);

CREATE OR REPLACE FUNCTION fn_update_tournament(
  p_id            INT,
  p_url_results   TEXT,
  p_import_status enum_import_status,
  p_status_reason TEXT,
  p_code          TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE tbl_tournament
  SET url_results              = p_url_results,
      enum_import_status       = p_import_status,
      txt_import_status_reason = p_status_reason,
      txt_code                 = COALESCE(p_code, txt_code),
      ts_updated               = NOW()
  WHERE id_tournament = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tournament % not found', p_id;
  END IF;
END;
$$;

-- Update grants for new signature (5 params instead of 4)
REVOKE EXECUTE ON FUNCTION fn_update_tournament(INT, TEXT, enum_import_status, TEXT, TEXT) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION fn_update_tournament(INT, TEXT, enum_import_status, TEXT, TEXT) TO authenticated;
