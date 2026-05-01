-- =============================================================================
-- Phase 0 Schema Prep — Unified Ingestion Pipeline (ADR-050 stub, P0 of
-- /Users/aleks/.claude/plans/now-we-have-a-precious-wren.md)
-- =============================================================================
-- Adds the load-bearing schema for the rebuilt pipeline:
--   1. enum_match_method               — provenance enum on tbl_result
--   2. tbl_result.{txt_scraped_name,
--        num_match_confidence,
--        enum_match_method}            — per-result identity provenance
--      (replaces tbl_match_candidate; that table stays present until Phase 6)
--   3. enum_source_status              — per-event ingestion-source status
--   4. tbl_event.txt_source_status     — column carrying enum_source_status
--   5. fn_age_categories_batch         — batch V-cat lookup for the splitter
--   6. fn_ingest_tournament_results    — rewritten to TEE provenance:
--        * writes to new tbl_result columns (post-rebuild source of truth)
--        * still writes to tbl_match_candidate (legacy; Phase 6 drops table)
--
-- Plan-deviation note: p0-prep.md scopes the rewrite to "removing
-- tbl_match_candidate writes". Doing that literally would break
-- supabase/tests/11_identity_resolution.sql (18 references) which is
-- explicitly scheduled for full rewrite in Phase 6 only. To keep tests
-- green, this migration TEES — both targets are written. Phase 6 will
-- (a) rewrite test 11 against the new model, (b) drop tbl_match_candidate,
-- and (c) collapse this function to write only to tbl_result.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. enum_match_method — per-result provenance (NOT a workflow state)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'enum_match_method') THEN
    CREATE TYPE enum_match_method AS ENUM (
      'AUTO_MATCH',      -- ≥95 confidence, no human review
      'USER_CONFIRMED',  -- admin picked among candidates
      'AUTO_CREATED',    -- domestic low-confidence: SPWS auto-created fencer
      'BY_ESTIMATED'     -- this result resolved to a fencer with estimated BY
    );
  END IF;
END$$;

COMMENT ON TYPE enum_match_method IS
  'Provenance of identity resolution for a tbl_result row. Replaces the '
  'workflow-state model in tbl_match_candidate (dropped in Phase 6, ADR-050).';

-- ---------------------------------------------------------------------------
-- 2. tbl_result provenance columns (nullable — historical rows have no
--    provenance to backfill from; Phase 5 rebuild populates them per event)
-- ---------------------------------------------------------------------------
ALTER TABLE tbl_result
  ADD COLUMN IF NOT EXISTS txt_scraped_name      TEXT,
  ADD COLUMN IF NOT EXISTS num_match_confidence  NUMERIC(5,2),
  ADD COLUMN IF NOT EXISTS enum_match_method     enum_match_method;

COMMENT ON COLUMN tbl_result.txt_scraped_name IS
  'Original name as scraped from the source (FTL/Engarde/4Fence/EVF). Provenance '
  'for identity resolution. NULL for pre-rebuild rows.';
COMMENT ON COLUMN tbl_result.num_match_confidence IS
  'Fuzzy-match confidence (0–100) at the moment of identity resolution. '
  'NULL for pre-rebuild rows.';
COMMENT ON COLUMN tbl_result.enum_match_method IS
  'How id_fencer was resolved (AUTO_MATCH / USER_CONFIRMED / AUTO_CREATED / '
  'BY_ESTIMATED). NULL for pre-rebuild rows.';

-- ---------------------------------------------------------------------------
-- 3. enum_source_status — per-event ingestion-source state
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'enum_source_status') THEN
    CREATE TYPE enum_source_status AS ENUM (
      'LIVE_SOURCE',       -- recorded URL still resolves; pipeline ingests live
      'FROZEN_SNAPSHOT',   -- no live source; rows copied verbatim from PROD seed
      'NO_SOURCE'          -- no source ever existed (rare; manually entered)
    );
  END IF;
END$$;

COMMENT ON TYPE enum_source_status IS
  'Ingestion-source status for an event. FROZEN_SNAPSHOT events skip parsing '
  'and copy rows from cert_ref schema (ADR-051).';

-- ---------------------------------------------------------------------------
-- 4. tbl_event.txt_source_status — defaults to LIVE_SOURCE so existing
--    rows behave as before; rebuild flips per-event to FROZEN_SNAPSHOT
--    where applicable (Phase 4)
--    NB: column name preserves the txt_ prefix per p0-prep.md spec; type is
--    the new enum_source_status (column-name vs type-name mismatch is a
--    documented plan choice).
-- ---------------------------------------------------------------------------
ALTER TABLE tbl_event
  ADD COLUMN IF NOT EXISTS txt_source_status enum_source_status
    NOT NULL DEFAULT 'LIVE_SOURCE';

COMMENT ON COLUMN tbl_event.txt_source_status IS
  'Per-event ingestion-source state — drives rebuild pipeline routing '
  'in Phase 4 (LIVE_SOURCE = parse; FROZEN_SNAPSHOT = copy; NO_SOURCE = skip).';

-- Rebuild vw_calendar so the column round-trips through the admin form
-- (per doc/claude/conventions.md "Adding a column to tbl_event?" rule).
-- vw_calendar is rebuilt by SELECT *; CREATE OR REPLACE picks up the new column.
DO $$
DECLARE
  v_def TEXT;
BEGIN
  SELECT pg_get_viewdef('vw_calendar'::regclass, TRUE) INTO v_def;
  IF v_def IS NOT NULL THEN
    -- Drop and recreate to re-resolve the new column
    EXECUTE 'DROP VIEW IF EXISTS vw_calendar CASCADE';
    EXECUTE 'CREATE VIEW vw_calendar AS ' || v_def;
  END IF;
EXCEPTION
  WHEN undefined_table THEN
    NULL;  -- vw_calendar may not exist yet in fresh-DB scenarios
END$$;

-- ---------------------------------------------------------------------------
-- 5. fn_age_categories_batch — batch V-cat resolution for the splitter
--    (Stage 4 of the unified pipeline; ADR-050 R001)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_age_categories_batch(
  p_birth_years     INT[],
  p_season_end_year INT
)
RETURNS TABLE (
  birth_year     INT,
  age_category   enum_age_category
)
LANGUAGE sql IMMUTABLE
AS $$
  SELECT
    by_in,
    fn_age_category(by_in, p_season_end_year)
  FROM unnest(p_birth_years) AS by_in;
$$;

COMMENT ON FUNCTION fn_age_categories_batch(INT[], INT) IS
  'Batch wrapper around fn_age_category — used by the rebuilt combined-pool '
  'splitter (Stage 4 of unified pipeline) to classify a whole pool in one '
  'round-trip. Single SQL implementation; Python birth_year_to_vcat is '
  'deleted in Phase 1 (ADR-050).';

REVOKE EXECUTE ON FUNCTION fn_age_categories_batch(INT[], INT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_age_categories_batch(INT[], INT) TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 6. fn_ingest_tournament_results — TEE rewrite
--    Writes provenance to BOTH tbl_result (new) AND tbl_match_candidate
--    (legacy). Phase 6 collapses to tbl_result-only after test 11 rewrite.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ingest_tournament_results(INT, JSONB, INT);

CREATE FUNCTION fn_ingest_tournament_results(
  p_tournament_id     INT,
  p_results           JSONB,
  p_participant_count INT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count           INT;
  v_row             JSONB;
  v_result_id       INT;
  v_fencer_id       INT;
  v_event_id        INT;
  v_legacy_status   TEXT;
  v_method          enum_match_method;
BEGIN
  -- Validate tournament exists
  IF NOT EXISTS (SELECT 1 FROM tbl_tournament WHERE id_tournament = p_tournament_id) THEN
    RAISE EXCEPTION 'Tournament % does not exist', p_tournament_id;
  END IF;

  -- Validate p_results is a non-empty array
  IF p_results IS NULL OR jsonb_array_length(p_results) = 0 THEN
    RAISE EXCEPTION 'Results array is empty';
  END IF;

  -- Get parent event_id
  SELECT id_event INTO v_event_id
    FROM tbl_tournament WHERE id_tournament = p_tournament_id;

  -- 1. Delete existing tbl_match_candidate rows for this tournament's results
  --    (legacy path; Phase 6 drops the table entirely)
  DELETE FROM tbl_match_candidate
  WHERE id_result IN (
    SELECT id_result FROM tbl_result WHERE id_tournament = p_tournament_id
  );

  -- 2. Delete existing results for this tournament
  DELETE FROM tbl_result WHERE id_tournament = p_tournament_id;

  -- 3. Participant count: provided value OR fall back to input result count
  v_count := COALESCE(p_participant_count, jsonb_array_length(p_results));

  -- 4. Update tournament metadata (before scoring, which needs int_participant_count)
  UPDATE tbl_tournament
  SET int_participant_count = v_count,
      enum_import_status    = 'IMPORTED',
      ts_updated            = NOW()
  WHERE id_tournament = p_tournament_id;

  -- 5. Insert new results (with provenance) AND legacy match_candidate entries
  FOR v_row IN SELECT jsonb_array_elements(p_results)
  LOOP
    v_fencer_id := (v_row ->> 'id_fencer')::INT;
    IF NOT EXISTS (SELECT 1 FROM tbl_fencer WHERE id_fencer = v_fencer_id) THEN
      RAISE EXCEPTION 'Fencer % does not exist', v_fencer_id;
    END IF;

    -- Map legacy enum_match_status (workflow state) → new enum_match_method
    -- (provenance). The new model has 4 values; legacy has 6. Workflow-only
    -- values (PENDING / DISMISSED / UNMATCHED) collapse to AUTO_MATCH because
    -- they don't survive in the post-rebuild model — no row should reach
    -- tbl_result with a non-resolved identity.
    v_legacy_status := COALESCE(v_row ->> 'enum_match_status', 'AUTO_MATCHED');
    v_method := CASE v_legacy_status
      WHEN 'AUTO_MATCHED' THEN 'AUTO_MATCH'::enum_match_method
      WHEN 'APPROVED'     THEN 'USER_CONFIRMED'::enum_match_method
      WHEN 'NEW_FENCER'   THEN 'AUTO_CREATED'::enum_match_method
      ELSE 'AUTO_MATCH'::enum_match_method
    END;

    INSERT INTO tbl_result (
      id_fencer, id_tournament, int_place,
      txt_scraped_name, num_match_confidence, enum_match_method
    )
    VALUES (
      v_fencer_id,
      p_tournament_id,
      (v_row ->> 'int_place')::INT,
      v_row ->> 'txt_scraped_name',
      COALESCE((v_row ->> 'num_confidence')::NUMERIC(5,2), 100),
      v_method
    )
    RETURNING id_result INTO v_result_id;

    -- LEGACY: tbl_match_candidate write — collapses in Phase 6 alongside
    -- supabase/tests/11_identity_resolution.sql rewrite.
    INSERT INTO tbl_match_candidate (
      id_result, id_fencer,
      txt_scraped_name, num_confidence, enum_status
    ) VALUES (
      v_result_id,
      v_fencer_id,
      v_row ->> 'txt_scraped_name',
      COALESCE((v_row ->> 'num_confidence')::NUMERIC, 100),
      v_legacy_status::enum_match_status
    );
  END LOOP;

  -- 6. Run scoring engine for this tournament
  PERFORM fn_calc_tournament_scores(p_tournament_id);

  -- 7. Set event to IN_PROGRESS if still PLANNED
  UPDATE tbl_event
  SET enum_status = 'IN_PROGRESS', ts_updated = NOW()
  WHERE id_event = v_event_id
    AND enum_status = 'PLANNED';

  RETURN jsonb_build_object(
    'tournament_id',     p_tournament_id,
    'results_count',     jsonb_array_length(p_results),
    'participant_count', v_count,
    'status',            'IMPORTED'
  );
END;
$$;

COMMENT ON FUNCTION fn_ingest_tournament_results(INT, JSONB, INT) IS
  'Atomic ingest: delete old + insert new + provenance + scoring. '
  'Phase 0 rewrite (ADR-050): provenance now lands on tbl_result.{txt_scraped_name, '
  'num_match_confidence, enum_match_method}. Legacy tbl_match_candidate writes '
  'preserved during rebuild — Phase 6 will drop the table and remove the tee. '
  'p_participant_count: optional total tournament size (used for international '
  'tournaments where only POL fencers are imported). Falls back to len(p_results).';

REVOKE EXECUTE ON FUNCTION fn_ingest_tournament_results(INT, JSONB, INT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_ingest_tournament_results(INT, JSONB, INT) TO authenticated;

COMMIT;
