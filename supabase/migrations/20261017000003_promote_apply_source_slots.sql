-- ============================================================================
-- Promote fills a blank result slot 2-5 on PROD (ADR-113)
-- ============================================================================
-- Telegram `ingest` / `promote` carry every organizer from ADR-113 on. An
-- international CERT run records every result slot it read (url_event …
-- url_event_5); promote's plan reads exactly those on PROD and records one
-- `set_event_source_url` operation per slot 2-5 that PROD holds blank
-- (python/pipeline/promotion/plan.py, _fill_blank_slots).
--
-- fn_promote_event_apply gains that one operation, under ADR-086's fill-blank
-- tier, exactly as `set_event_url_event` does for url_event: blank takes the
-- run's URL, equal stays, different refuses (PROMOTE_URL_DIFFERS), and any
-- other column refuses (PROMOTE_PLAN_SLOT). The rest of the function is the
-- definition of 20261003000017_promote_apply.sql, unchanged. The slots are not
-- part of fn_event_result_fingerprint, so no fingerprint changes.
--
-- pgTAP: supabase/tests/110_promote_apply_source_slot.sql (ROUTE.APPLY.01-05).
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_promote_event_apply(
  p_event_code           TEXT,
  p_plan                 JSONB,
  p_expected_fingerprint TEXT,
  p_expected_inputs      JSONB,
  p_prior_fingerprint    TEXT,
  p_status               TEXT,
  p_dry_run              BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event    tbl_event%ROWTYPE;
  v_before   TEXT;
  v_after    TEXT;
  v_parts    JSONB;
  v_part     TEXT;
  v_op       JSONB;
  v_fencer   JSONB;
  v_cols     TEXT;
  v_id       INT;
  v_max_id   INT;
  v_tid      INT;
  v_ref      INT;
  v_refs     JSONB := '{}'::JSONB;
  v_url      TEXT;
  v_skipped  BOOLEAN := FALSE;
  v_writes   INT := 0;
  v_seq      TEXT := pg_get_serial_sequence('public.tbl_fencer', 'id_fencer');
BEGIN
  SELECT * INTO v_event FROM tbl_event WHERE txt_code = p_event_code FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'PROMOTE_EVENT_NOT_FOUND: %', p_event_code;
  END IF;
  IF p_plan->>'event_code' IS DISTINCT FROM p_event_code THEN
    RAISE EXCEPTION 'PROMOTE_PLAN_EVENT: the plan is for %, not %', p_plan->>'event_code', p_event_code;
  END IF;
  IF p_status IS NULL OR p_status NOT IN ('IN_PROGRESS', 'COMPLETED') THEN
    RAISE EXCEPTION 'PROMOTE_STATUS: promote sets IN_PROGRESS or COMPLETED, not %', p_status;
  END IF;
  IF v_event.enum_status NOT IN ('PLANNED', 'IN_PROGRESS', 'COMPLETED') THEN
    RAISE EXCEPTION 'PROMOTE_EVENT_STATUS: % is %', p_event_code, v_event.enum_status;
  END IF;

  v_before := fn_event_result_fingerprint(p_event_code);
  IF v_before = p_expected_fingerprint THEN
    v_skipped := TRUE;
  ELSE
    -- What PROD holds now: nothing, or exactly the previous promote.
    IF p_prior_fingerprint IS NULL THEN
      IF EXISTS (SELECT 1 FROM tbl_result r JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
                  WHERE t.id_event = v_event.id_event) THEN
        RAISE EXCEPTION 'PROMOTE_PRIOR: % already holds results, and no previous promote was named', p_event_code;
      END IF;
    ELSIF v_before <> p_prior_fingerprint THEN
      RAISE EXCEPTION 'PROMOTE_PRIOR: % does not hold the previous promote (expected %, found %)',
        p_event_code, p_prior_fingerprint, v_before;
    END IF;

    -- The participants' rows, in id order, so a concurrent writer waits.
    PERFORM 1 FROM tbl_fencer
     WHERE id_fencer IN (
       SELECT (o->>'id_fencer')::INT FROM jsonb_array_elements(p_plan->'ops') o
        WHERE o->>'op' = 'update_fencer_birth_year'
       UNION
       SELECT (r->>'id_fencer')::INT FROM jsonb_array_elements(p_plan->'ops') o, jsonb_array_elements(o->'rows') r
        WHERE o->>'op' = 'ingest_results')
     ORDER BY id_fencer FOR UPDATE;

    -- PROD's inputs must be the ones the CERT run started from (G1 A for the lock).
    v_parts := fn_event_input_fingerprint(p_event_code)->'parts';
    FOREACH v_part IN ARRAY ARRAY['schema', 'roster', 'registrations', 'season', 'event'] LOOP
      IF v_parts->>v_part IS DISTINCT FROM p_expected_inputs->>v_part THEN
        RAISE EXCEPTION 'PROMOTE_INPUT_CHANGED: % differs from the CERT run''s', v_part;
      END IF;
    END LOOP;
    IF v_parts->>'lock' = 'locked' AND p_expected_inputs->>'lock' = 'unlocked' THEN
      RAISE EXCEPTION 'PROMOTE_INPUT_CHANGED: lock — PROD''s season is locked and CERT''s was not';
    END IF;

    -- A correction of a COMPLETED event is written while IN_PROGRESS.
    IF v_event.enum_status = 'COMPLETED' THEN
      UPDATE tbl_event SET enum_status = 'IN_PROGRESS' WHERE id_event = v_event.id_event;
    END IF;

    FOR v_op IN SELECT o FROM jsonb_array_elements(p_plan->'ops') o LOOP
      v_writes := v_writes + 1;
      CASE v_op->>'op'
      WHEN 'insert_fencer' THEN
        v_id := (v_op->>'id_fencer')::INT;
        IF EXISTS (SELECT 1 FROM tbl_fencer WHERE id_fencer = v_id) THEN
          RAISE EXCEPTION 'PROMOTE_FENCER_ID_TAKEN: % is already used on PROD', v_id;
        END IF;
        v_fencer := v_op->'fencer';
        IF EXISTS (SELECT 1 FROM jsonb_object_keys(v_fencer) k
                    WHERE k NOT IN ('txt_surname', 'txt_first_name', 'int_birth_year', 'bool_birth_year_estimated',
                                    'txt_nationality', 'enum_gender')) THEN
          RAISE EXCEPTION 'PROMOTE_PLAN_FENCER: unexpected fencer column in %', v_fencer;
        END IF;
        -- Only the columns the ingestion sent, as the live insert does.
        SELECT string_agg(quote_ident(k), ', ') INTO v_cols FROM jsonb_object_keys(v_fencer) k;
        EXECUTE format('INSERT INTO tbl_fencer (id_fencer, %1$s) SELECT $1, %1$s FROM jsonb_populate_record(NULL::tbl_fencer, $2)',
                       v_cols)
          USING v_id, v_fencer;
        v_max_id := GREATEST(COALESCE(v_max_id, v_id), v_id);
      WHEN 'update_fencer_birth_year' THEN
        PERFORM fn_update_fencer_birth_year((v_op->>'id_fencer')::INT, (v_op->>'birth_year')::INT,
                                            COALESCE((v_op->>'estimated')::BOOLEAN, FALSE));
      WHEN 'find_or_create_tournament' THEN
        IF (v_op->>'event_id')::INT IS DISTINCT FROM v_event.id_event THEN
          RAISE EXCEPTION 'PROMOTE_PLAN_EVENT: a tournament of event %, not %', v_op->>'event_id', v_event.id_event;
        END IF;
        v_tid := fn_find_or_create_tournament(
          v_event.id_event, (v_op->>'weapon')::enum_weapon_type, (v_op->>'gender')::enum_gender_type,
          (v_op->>'category')::enum_age_category, (v_op->>'date')::DATE,
          (v_op->>'tournament_type')::enum_tournament_type, NULL, v_op->>'url_results');
        v_ref := (v_op->>'ref')::INT;
        IF v_ref > 0 AND v_tid <> v_ref THEN
          RAISE EXCEPTION 'PROMOTE_TOURNAMENT_MOVED: the plan read tournament %, the apply found %', v_ref, v_tid;
        END IF;
        v_refs := v_refs || jsonb_build_object(v_ref::TEXT, v_tid);
      WHEN 'ingest_results' THEN
        v_tid := (v_refs->>(v_op->>'tournament'))::INT;
        IF v_tid IS NULL THEN
          RAISE EXCEPTION 'PROMOTE_PLAN_TOURNAMENT: results for tournament % before it was found or created',
            v_op->>'tournament';
        END IF;
        PERFORM fn_ingest_tournament_results(v_tid, v_op->'rows', (v_op->>'participant_count')::INT,
                                             v_op->>'joined_order');
      WHEN 'set_event_url_event' THEN
        -- ADR-086's fill-blank tier: blank takes CERT's URL, equal stays, different refuses.
        SELECT NULLIF(btrim(COALESCE(url_event, '')), '') INTO v_url FROM tbl_event WHERE id_event = v_event.id_event;
        IF (v_op->>'id_event')::INT IS DISTINCT FROM v_event.id_event THEN
          RAISE EXCEPTION 'PROMOTE_PLAN_EVENT: a URL for event %, not %', v_op->>'id_event', v_event.id_event;
        ELSIF v_url IS NULL THEN
          UPDATE tbl_event SET url_event = v_op->>'url_event' WHERE id_event = v_event.id_event;
        ELSIF v_url <> v_op->>'url_event' THEN
          RAISE EXCEPTION 'PROMOTE_URL_DIFFERS: PROD has %, the CERT run ingested %', v_url, v_op->>'url_event';
        END IF;
      WHEN 'set_event_source_url' THEN
        -- ADR-113: result slots 2-5 of an international event, under the same
        -- fill-blank tier (ADR-086): blank takes CERT's URL, equal stays,
        -- different refuses. url_event keeps its own operation above.
        IF (v_op->>'id_event')::INT IS DISTINCT FROM v_event.id_event THEN
          RAISE EXCEPTION 'PROMOTE_PLAN_EVENT: a URL for event %, not %', v_op->>'id_event', v_event.id_event;
        END IF;
        IF v_op->>'slot' IS NULL
           OR v_op->>'slot' NOT IN ('url_event_2', 'url_event_3', 'url_event_4', 'url_event_5') THEN
          RAISE EXCEPTION 'PROMOTE_PLAN_SLOT: % is not result slot 2-5', v_op->>'slot';
        END IF;
        EXECUTE format('SELECT NULLIF(btrim(COALESCE(%I, %L)), %L) FROM tbl_event WHERE id_event = $1',
                       v_op->>'slot', '', '')
          INTO v_url USING v_event.id_event;
        IF v_url IS NULL THEN
          EXECUTE format('UPDATE tbl_event SET %I = $1 WHERE id_event = $2', v_op->>'slot')
            USING v_op->>'url_event', v_event.id_event;
        ELSIF v_url <> v_op->>'url_event' THEN
          RAISE EXCEPTION 'PROMOTE_URL_DIFFERS: PROD''s % is %, the CERT run read %',
            v_op->>'slot', v_url, v_op->>'url_event';
        END IF;
      WHEN 'set_event_ingest_sources' THEN
        IF (v_op->>'id_event')::INT IS DISTINCT FROM v_event.id_event THEN
          RAISE EXCEPTION 'PROMOTE_PLAN_EVENT: sources for event %, not %', v_op->>'id_event', v_event.id_event;
        END IF;
        UPDATE tbl_event SET json_ingest_sources = v_op->'sources' WHERE id_event = v_event.id_event;
      ELSE
        RAISE EXCEPTION 'PROMOTE_PLAN_OP: unknown operation %', v_op->>'op';
      END CASE;
    END LOOP;

    v_after := fn_event_result_fingerprint(p_event_code);
    IF v_after IS DISTINCT FROM p_expected_fingerprint THEN
      RAISE EXCEPTION 'PROMOTE_FINGERPRINT_MISMATCH: expected %, PROD would hold %', p_expected_fingerprint, v_after
        USING DETAIL = fn_event_result_document(p_event_code)::TEXT;
    END IF;
  END IF;

  -- The lifecycle's status, through the transition validator; an unchanged status is not written.
  IF (SELECT enum_status::TEXT FROM tbl_event WHERE id_event = v_event.id_event) <> p_status THEN
    UPDATE tbl_event SET enum_status = p_status::enum_event_status WHERE id_event = v_event.id_event;
  END IF;

  IF p_dry_run THEN
    RAISE EXCEPTION 'PROMOTE_DRY_RUN_OK %', COALESCE(v_after, v_before)
      USING DETAIL = jsonb_build_object('skipped', v_skipped, 'writes', v_writes, 'tournaments', v_refs)::TEXT;
  END IF;

  -- After an insert with CERT's ids, the sequence moves past them (sequences do not roll back,
  -- so a dry run never gets here).
  IF v_max_id IS NOT NULL THEN
    PERFORM setval(v_seq, GREATEST((SELECT max(id_fencer) FROM tbl_fencer),
                                   COALESCE(pg_sequence_last_value(v_seq::regclass), 0)));
  END IF;

  RETURN jsonb_build_object(
    'event', p_event_code,
    'skipped', v_skipped,
    'fingerprint', COALESCE(v_after, v_before),
    'writes', v_writes,
    'tournaments', v_refs,
    'status', p_status);
END;
$$;

COMMENT ON FUNCTION fn_promote_event_apply(TEXT, JSONB, TEXT, JSONB, TEXT, TEXT, BOOLEAN) IS
  'ADR-108 §6, ADR-113: plan mode''s operations (result slots 2-5 included) applied in one transaction; raises on any input, prior or result difference; a dry run always raises PROMOTE_DRY_RUN_OK <fingerprint>; skipped when PROD already holds CERT''s result.';

REVOKE ALL ON FUNCTION fn_promote_event_apply(TEXT, JSONB, TEXT, JSONB, TEXT, TEXT, BOOLEAN) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_promote_event_apply(TEXT, JSONB, TEXT, JSONB, TEXT, TEXT, BOOLEAN) TO service_role;
