-- =============================================================================
-- Phase 3 (ADR-050) — fn_update_fencer_aliases RPC
--
-- Used by Stage 6 of the unified pipeline (python/pipeline/orchestrator.py)
-- when an admin USER_CONFIRMS a fuzzy-match decision: the matched scraped
-- variant gets appended to the fencer's json_name_aliases array. Future
-- imports of the same scraped variant auto-match without admin review.
--
-- Behaviour (locked by tests in supabase/tests/28_alias_writeback.sql):
--   - Initialize NULL json_name_aliases as a single-element array.
--   - Append to existing array, preserving order.
--   - Deduplicate case-insensitively (don't add same alias twice).
--   - Trim leading/trailing whitespace before storing and comparing.
--   - Reject empty/whitespace-only alias as no-op (return current array).
--   - Return the updated json_name_aliases as the function's JSONB result.
--
-- Tests: supabase/tests/28_alias_writeback.sql (8 assertions).
-- =============================================================================

BEGIN;


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

  -- Always read current value so we can return it even on no-op paths.
  SELECT coalesce(json_name_aliases, '[]'::JSONB)
    INTO v_current
    FROM tbl_fencer
   WHERE id_fencer = p_id_fencer;

  -- Reject empty after trim — don't pollute the array.
  IF v_trimmed = '' THEN
    RAISE WARNING 'fn_update_fencer_aliases: empty alias rejected for id_fencer=%', p_id_fencer;
    RETURN v_current;
  END IF;

  -- Case-insensitive dedup. Compare lower(existing) to lower(trimmed).
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

  -- Append + persist.
  v_current := v_current || to_jsonb(v_trimmed);

  UPDATE tbl_fencer
     SET json_name_aliases = v_current,
         ts_updated        = NOW()
   WHERE id_fencer = p_id_fencer;

  RETURN v_current;
END;
$$;


COMMENT ON FUNCTION fn_update_fencer_aliases(INT, TEXT) IS
  'Phase 3 (ADR-050) Stage 6 alias writeback. Appends p_alias to '
  'tbl_fencer.json_name_aliases for the given fencer (deduped case-'
  'insensitively, whitespace-trimmed). Returns the updated JSONB array. '
  'Empty/whitespace-only alias is rejected as no-op with a warning.';


COMMIT;
