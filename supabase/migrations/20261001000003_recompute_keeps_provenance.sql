-- =============================================================================
-- A recompute writes each result's stored provenance back verbatim
-- =============================================================================
-- Flips RECOMP.PROV.RPC.01-04 in supabase/tests/87_recompute_provenance.sql
-- from RED to GREEN; RPC.05 pins the behaviour every source write relies on.
-- The Python half is python/tests/test_recompute_provenance.py.
--
-- THE DEFECT
--
--   RECOMPUTE_DOMESTIC (ADR-072) rewrites an event's results through this RPC,
--   which deletes and re-inserts every row. The recompute rebuilt each row from
--   the fencer id alone, so every drain stored the id as txt_scraped_name,
--   reset enum_match_method to AUTO_MATCH and the confidence to 100. The
--   pipeline now sends the stored values; for that write to be verbatim, the
--   RPC must keep the NULLs it is handed:
--
--   1. num_match_confidence: an explicit "num_confidence": null is stored as
--      NULL. An absent key still means 100. No caller but the recompute sends
--      an explicit null (source writes always send a number).
--   2. tbl_match_candidate: a row with no scraped name gets no candidate,
--      whose txt_scraped_name is NOT NULL. Rows stored that way (early EVF
--      imports, 183 on LOCAL) have none today; the write used to fail on them.
--
-- enum_match_method already followed this rule (key present = verbatim, NULL
-- included). CREATE OR REPLACE with an unchanged signature keeps the ADR-083
-- grants and SECURITY DEFINER, and the ADR-105 guard from 20261001000002.
-- This migration repairs no stored row.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_ingest_tournament_results(p_tournament_id integer, p_results jsonb, p_participant_count integer DEFAULT NULL::integer, p_joined_order text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_count           INT;
  v_row             JSONB;
  v_result_id       INT;
  v_fencer_id       INT;
  v_event_id        INT;
  v_legacy_status   TEXT;
  v_method_text     TEXT;
  v_method          enum_match_method;
  v_source_vcat     enum_age_category;
  v_type            enum_tournament_type;
  v_max_place       INT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM tbl_tournament WHERE id_tournament = p_tournament_id) THEN
    RAISE EXCEPTION 'Tournament % does not exist', p_tournament_id;
  END IF;

  IF p_results IS NULL OR jsonb_array_length(p_results) = 0 THEN
    RAISE EXCEPTION 'Results array is empty';
  END IF;

  SELECT id_event, enum_type INTO v_event_id, v_type
    FROM tbl_tournament WHERE id_tournament = p_tournament_id;

  -- ADR-105: an international tournament holds only its Polish rows
  -- (ADR-038), so neither the payload nor the order can stand in for its N.
  -- Refuse before anything is deleted, so a bad call leaves the stored
  -- result as it was.
  IF v_type IN ('PEW', 'MEW', 'MSW', 'PSW') THEN
    IF p_participant_count IS NULL THEN
      RAISE EXCEPTION 'International tournament % needs its source bracket size: p_participant_count is required (ADR-105)',
        p_tournament_id;
    END IF;
    SELECT max((r ->> 'int_place')::INT) INTO v_max_place
      FROM jsonb_array_elements(p_results) AS r;
    IF v_max_place > p_participant_count THEN
      RAISE EXCEPTION 'International tournament %: place % exceeds the source bracket of % (ADR-105)',
        p_tournament_id, v_max_place, p_participant_count;
    END IF;
  END IF;

  DELETE FROM tbl_match_candidate
  WHERE id_result IN (
    SELECT id_result FROM tbl_result WHERE id_tournament = p_tournament_id
  );

  DELETE FROM tbl_result WHERE id_tournament = p_tournament_id;

  -- ADR-104 §3: the order has one digit per place of the whole listing, so it
  -- also gives N when no count is passed.
  -- The payload-length fallback is reached only by a domestic tournament;
  -- an international one was refused above without a count (ADR-105).
  v_count := COALESCE(p_participant_count, length(p_joined_order), jsonb_array_length(p_results));

  UPDATE tbl_tournament
  SET int_participant_count = v_count,
      txt_joined_order      = p_joined_order,
      enum_import_status    = 'IMPORTED',
      ts_updated            = NOW()
  WHERE id_tournament = p_tournament_id;

  FOR v_row IN SELECT jsonb_array_elements(p_results)
  LOOP
    v_fencer_id := (v_row ->> 'id_fencer')::INT;
    IF NOT EXISTS (SELECT 1 FROM tbl_fencer WHERE id_fencer = v_fencer_id) THEN
      RAISE EXCEPTION 'Fencer % does not exist', v_fencer_id;
    END IF;

    -- NEW: direct enum_match_method from payload (preserves NULL).
    -- When the key is present in the payload object, trust it verbatim —
    -- even if the value is JSON null or empty string (both map to NULL).
    -- When the key is absent, fall back to legacy enum_match_status with
    -- the historical default of AUTO_MATCH.
    IF v_row ? 'enum_match_method' THEN
      v_method_text := v_row ->> 'enum_match_method';
      IF v_method_text IS NULL OR v_method_text = '' THEN
        v_method := NULL;
      ELSE
        v_method := v_method_text::enum_match_method;
      END IF;
    ELSE
      v_legacy_status := COALESCE(v_row ->> 'enum_match_status', 'AUTO_MATCHED');
      v_method := CASE v_legacy_status
        WHEN 'AUTO_MATCHED' THEN 'AUTO_MATCH'::enum_match_method
        WHEN 'APPROVED'     THEN 'USER_CONFIRMED'::enum_match_method
        WHEN 'NEW_FENCER'   THEN 'AUTO_CREATED'::enum_match_method
        ELSE 'AUTO_MATCH'::enum_match_method
      END;
    END IF;

    -- For the legacy tbl_match_candidate row, derive a status from the
    -- (possibly NULL) method. Match-candidate enum has no NULL value, so
    -- a NULL method maps to AUTO_MATCHED (workflow-state best guess) —
    -- this preserves prior behavior for that table since it's slated for
    -- removal in Phase 6.
    v_legacy_status := COALESCE(v_row ->> 'enum_match_status',
      CASE v_method::TEXT
        WHEN 'AUTO_MATCH'      THEN 'AUTO_MATCHED'
        WHEN 'USER_CONFIRMED'  THEN 'APPROVED'
        WHEN 'AUTO_CREATED'    THEN 'NEW_FENCER'
        ELSE 'AUTO_MATCHED'
      END);

    v_source_vcat := CASE
      WHEN v_row ? 'enum_source_age_category' AND NULLIF(v_row ->> 'enum_source_age_category', '') IS NOT NULL
        THEN (v_row ->> 'enum_source_age_category')::enum_age_category
      ELSE NULL
    END;

    INSERT INTO tbl_result (
      id_fencer, id_tournament, int_place,
      txt_scraped_name, num_match_confidence, enum_match_method,
      enum_source_age_category
    )
    VALUES (
      v_fencer_id,
      p_tournament_id,
      (v_row ->> 'int_place')::INT,
      v_row ->> 'txt_scraped_name',
      -- An explicit null is kept (a recompute writing back a stored NULL);
      -- only an absent key means a fresh match at 100.
      CASE WHEN v_row ? 'num_confidence'
           THEN (v_row ->> 'num_confidence')::NUMERIC(5,2)
           ELSE 100 END,
      v_method,
      v_source_vcat
    )
    RETURNING id_result INTO v_result_id;

    -- A candidate needs a scraped name. A row stored without one (an early
    -- EVF import) never had a candidate, and a recompute keeps it that way.
    IF v_row ->> 'txt_scraped_name' IS NOT NULL THEN
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
    END IF;
  END LOOP;

  PERFORM fn_calc_tournament_scores(p_tournament_id);

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
$function$;
