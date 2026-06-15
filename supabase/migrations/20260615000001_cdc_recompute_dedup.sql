-- =============================================================================
-- ADR-072 (CDC recompute) + ADR-071 (dedup) — the self-healing DB layer
-- NEW ingestion pipeline build, milestone 5.
-- =============================================================================
-- Objects:
--   tbl_recompute_queue       — events awaiting RECOMPUTE_DOMESTIC (dedup by event)
--   tbl_recompute_watermark   — single-row ts_last_master_change for debounce
--   fn_enqueue_affected_events(id_fencer) — enqueue every event a fencer is in
--   fn_fencer_change_enqueue / trg_fencer_change_enqueue — COLUMN-AWARE trigger:
--       BY / nationality change -> enqueue; name / alias change -> nothing
--       (identity is a durable FK, ADR-003, so a rename heals nothing historical)
--   fn_merge_fencers(survivor, duplicate) — ADR-071: re-point results to the
--       survivor (FK identity), fold aliases, enqueue both sides, drop the dup
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- Queue + watermark
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_recompute_queue (
    id_queue     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_event     INT NOT NULL REFERENCES tbl_event(id_event) ON DELETE CASCADE,
    enum_status  TEXT NOT NULL DEFAULT 'PENDING'
                 CHECK (enum_status IN ('PENDING', 'CLAIMED', 'DONE')),
    ts_enqueued  TIMESTAMPTZ NOT NULL DEFAULT now(),
    ts_claimed   TIMESTAMPTZ
);

-- Dedup: at most one PENDING row per event (re-enqueue coalesces).
CREATE UNIQUE INDEX IF NOT EXISTS uq_recompute_queue_pending
    ON tbl_recompute_queue (id_event) WHERE enum_status = 'PENDING';

CREATE TABLE IF NOT EXISTS tbl_recompute_watermark (
    id                    BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (id),
    ts_last_master_change TIMESTAMPTZ NOT NULL DEFAULT now()
);
INSERT INTO tbl_recompute_watermark (id) VALUES (TRUE) ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Enqueue the events a fencer participated in (+ bump the debounce watermark)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_enqueue_affected_events(p_id_fencer INT)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_inserted INT;
BEGIN
    INSERT INTO tbl_recompute_queue (id_event)
    SELECT DISTINCT t.id_event
    FROM tbl_result r
    JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
    WHERE r.id_fencer = p_id_fencer
      AND t.id_event IS NOT NULL
    ON CONFLICT (id_event) WHERE enum_status = 'PENDING' DO NOTHING;
    GET DIAGNOSTICS v_inserted = ROW_COUNT;

    -- clock_timestamp() (not now()) so the debounce watermark advances even
    -- within a single transaction / test run.
    UPDATE tbl_recompute_watermark SET ts_last_master_change = clock_timestamp() WHERE id;
    RETURN v_inserted;
END;
$$;

-- ---------------------------------------------------------------------------
-- Column-aware CDC trigger on tbl_fencer
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_fencer_change_enqueue()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Only birth-year / nationality changes relocate or re-filter results.
    -- Name / alias edits are cosmetic — the FK is durable (ADR-003).
    IF (NEW.int_birth_year IS DISTINCT FROM OLD.int_birth_year)
       OR (NEW.txt_nationality IS DISTINCT FROM OLD.txt_nationality) THEN
        PERFORM fn_enqueue_affected_events(NEW.id_fencer);
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_fencer_change_enqueue ON tbl_fencer;
CREATE TRIGGER trg_fencer_change_enqueue
    AFTER UPDATE ON tbl_fencer
    FOR EACH ROW
    EXECUTE FUNCTION fn_fencer_change_enqueue();

-- ---------------------------------------------------------------------------
-- Merge two fencers (ADR-071) — survivor keeps the FK identity
-- ---------------------------------------------------------------------------
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

COMMIT;
