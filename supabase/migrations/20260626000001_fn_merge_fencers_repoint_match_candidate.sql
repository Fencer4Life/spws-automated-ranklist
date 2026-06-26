-- =============================================================================
-- fn_merge_fencers hardening — re-point tbl_match_candidate before the dup delete
-- =============================================================================
-- ADR-071 (dedup). The original fn_merge_fencers (20260615000001) re-points
-- tbl_result to the survivor but never re-points tbl_match_candidate.id_fencer,
-- which also FK-references tbl_fencer. When the duplicate has any non-colliding
-- match-candidate row, `DELETE FROM tbl_fencer` aborts with
-- tbl_match_candidate_id_fencer_fkey. This surfaced live during the
-- SAMECKA-NACZYŃSKA dedup (CERT/PROD): the duplicate carried AUTO_MATCHED /
-- NEW_FENCER candidate rows that blocked the merge.
--
-- Fix: re-point the duplicate's remaining match-candidate rows to the survivor
-- (faithful to the result re-pointing — the audit follows the result) so the FK
-- clears before the dup row is deleted. Colliding candidates (results in the
-- survivor's tournaments) are still removed earlier with their results.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_merge_fencers(p_survivor INT, p_duplicate INT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_dup tbl_fencer%ROWTYPE;
BEGIN
    IF p_survivor = p_duplicate THEN
        RETURN;
    END IF;
    SELECT * INTO v_dup FROM tbl_fencer WHERE id_fencer = p_duplicate;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    -- Enqueue both sides' events BEFORE re-pointing (capture the dup's events
    -- while they are still linked to the duplicate).
    PERFORM fn_enqueue_affected_events(p_duplicate);
    PERFORM fn_enqueue_affected_events(p_survivor);

    -- Drop dup results that would collide with the survivor in the same
    -- tournament (uq_result_fencer_tournament). Same person, so the survivor's
    -- row wins; remove dependent match-candidate rows first.
    DELETE FROM tbl_match_candidate
    WHERE id_result IN (
        SELECT r.id_result FROM tbl_result r
        WHERE r.id_fencer = p_duplicate
          AND r.id_tournament IN (
              SELECT id_tournament FROM tbl_result WHERE id_fencer = p_survivor)
    );
    DELETE FROM tbl_result r
    WHERE r.id_fencer = p_duplicate
      AND r.id_tournament IN (
          SELECT id_tournament FROM tbl_result WHERE id_fencer = p_survivor);

    -- Re-point the rest to the survivor (identity is the FK, ADR-003).
    UPDATE tbl_result SET id_fencer = p_survivor WHERE id_fencer = p_duplicate;

    -- Re-point the duplicate's remaining match-candidate rows to the survivor.
    -- tbl_match_candidate.id_fencer also FK-references tbl_fencer; without this
    -- the dup delete below FK-fails. The audit follows the re-pointed result.
    UPDATE tbl_match_candidate SET id_fencer = p_survivor WHERE id_fencer = p_duplicate;

    -- Remove the duplicate FIRST so its alias ownership is released before we
    -- fold its name onto the survivor (aliases are globally unique per fencer).
    DELETE FROM tbl_fencer WHERE id_fencer = p_duplicate;

    -- Fold the duplicate's display name + aliases into the survivor's aliases.
    UPDATE tbl_fencer s
    SET json_name_aliases = sub.merged
    FROM (
        SELECT to_jsonb(array_agg(DISTINCT a)) AS merged
        FROM (
            SELECT jsonb_array_elements_text(
                       coalesce((SELECT json_name_aliases FROM tbl_fencer
                                 WHERE id_fencer = p_survivor), '[]'::jsonb)) AS a
            UNION
            SELECT jsonb_array_elements_text(coalesce(v_dup.json_name_aliases, '[]'::jsonb))
            UNION
            SELECT trim(v_dup.txt_surname || ' ' || v_dup.txt_first_name)
        ) u
        WHERE a IS NOT NULL AND a <> ''
    ) sub
    WHERE s.id_fencer = p_survivor;
END;
$$;
