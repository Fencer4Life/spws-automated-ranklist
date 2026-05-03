-- =============================================================================
-- Phase 5.5 — Repair tbl_fencer.json_name_aliases JSONB corruption
-- =============================================================================
-- Bug history (operator caught 2026-05-03 during GP1 rescrape):
-- 9 tbl_fencer rows had json_name_aliases stored as a JSON-string-of-postgres-
-- array-literal e.g. '"{\"WOJTAS Bogdan\"}"' instead of a proper JSON array
-- '["WOJTAS Bogdan"]'. The corruption originates in legacy seed export logic
-- (now superseded). Symptoms:
--   * vw_fencer_aliases.json_name_aliases returns [] (the safe_aliases CTE
--     defends against non-array typeof by returning []) — UI loses track.
--   * fn_update_fencer_aliases throws "cannot extract elements from a scalar"
--     because jsonb_array_elements_text rejects non-array JSONB. The Phase 5
--     stage-time alias-flush catches the exception and increments an error
--     counter SILENTLY — operator never sees that wrong-match aliases failed
--     to land in the FencerAliasManager UI. (Plan-test-ID 5.15 — review_cli
--     Bug B is the data-loss companion fix.)
--
-- This migration:
--   1. Repairs the 9 corrupted rows by parsing the embedded postgres-array
--      literal back to a proper JSONB array. Idempotent — non-corrupt rows
--      are skipped.
--   2. Hardens fn_update_fencer_aliases: if the existing column value is not
--      a JSONB array, normalise to '[]'::jsonb before appending. Defence in
--      depth so future corruption (e.g. a careless seed import) cannot break
--      alias writeback silently.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Data repair — convert JSON-string-wrapped pg-array-literals to JSONB[]
-- ---------------------------------------------------------------------------
-- The repair: extract the JSON-string text via #>>{} (returns the unquoted
-- text payload), cast to TEXT[] (parses the pg-array literal), and convert
-- back to JSONB via array_to_json()::jsonb. Idempotent: only rows where
-- jsonb_typeof != 'array' are touched.
UPDATE tbl_fencer
   SET json_name_aliases = array_to_json(
         (json_name_aliases #>> '{}')::TEXT[]
       )::JSONB
 WHERE jsonb_typeof(json_name_aliases) = 'string';

-- Same defence for the other two alias columns (none corrupted today, but
-- make it impossible for them to silently break a future migration).
UPDATE tbl_fencer
   SET json_user_confirmed_aliases = array_to_json(
         (json_user_confirmed_aliases #>> '{}')::TEXT[]
       )::JSONB
 WHERE jsonb_typeof(json_user_confirmed_aliases) = 'string';

UPDATE tbl_fencer
   SET json_revoked_aliases = array_to_json(
         (json_revoked_aliases #>> '{}')::TEXT[]
       )::JSONB
 WHERE jsonb_typeof(json_revoked_aliases) = 'string';

-- ---------------------------------------------------------------------------
-- 2. Defence-in-depth — fn_update_fencer_aliases tolerates non-array v_current
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_update_fencer_aliases(
  p_id_fencer INT,
  p_alias     TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_trimmed   TEXT;
  v_current   JSONB;
  v_lower     TEXT;
  v_already   BOOLEAN;
BEGIN
  v_trimmed := btrim(coalesce(p_alias, ''));

  SELECT coalesce(json_name_aliases, '[]'::JSONB)
    INTO v_current
    FROM tbl_fencer
   WHERE id_fencer = p_id_fencer;

  -- Defence in depth (Phase 5.5 / 5.15.2): if the column was corrupted to a
  -- non-array JSONB (legacy seed export bug), treat it as empty. Without this
  -- guard, jsonb_array_elements_text raises "cannot extract elements from a
  -- scalar" on the dedup check below, which the Phase-5 alias flush catches
  -- silently — operator loses track of the wrong-match alias entirely.
  IF jsonb_typeof(v_current) != 'array' THEN
    v_current := '[]'::JSONB;
  END IF;

  IF v_trimmed = '' THEN
    RAISE WARNING 'fn_update_fencer_aliases: empty alias rejected for id_fencer=%', p_id_fencer;
    RETURN v_current;
  END IF;

  v_lower := lower(v_trimmed);
  SELECT EXISTS (
    SELECT 1
      FROM jsonb_array_elements_text(v_current) AS existing
     WHERE lower(existing) = v_lower
  )
  INTO v_already;

  IF v_already THEN
    RETURN v_current;
  END IF;

  v_current := v_current || to_jsonb(v_trimmed);

  UPDATE tbl_fencer
     SET json_name_aliases = v_current,
         ts_updated        = NOW()
   WHERE id_fencer = p_id_fencer;

  RETURN v_current;
END;
$$;

COMMENT ON FUNCTION fn_update_fencer_aliases(INT, TEXT) IS
  'Phase 3 (ADR-050) Stage 6 alias writeback, hardened in Phase 5.5 (5.15.2) '
  'to tolerate non-array json_name_aliases (legacy seed-export corruption). '
  'Appends p_alias to tbl_fencer.json_name_aliases (deduped case-insensitively, '
  'whitespace-trimmed). Empty alias rejected as no-op with a warning.';

COMMIT;
