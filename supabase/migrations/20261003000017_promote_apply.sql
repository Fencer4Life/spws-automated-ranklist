-- =============================================================================
-- ADR-108 §6 (build step 9) — promote's apply on PROD.
-- =============================================================================
-- fn_event_result_document / fn_event_result_fingerprint: the one canonical
-- account of what an ingestion left for an event, computed in SQL so CERT and
-- PROD compute it the same way (no 59.16 against 59.160): the event's URL,
-- every tournament, every result with its score, and the participants' roster
-- rows, keyed by codes and fencer ids, never by generated ids or timestamps.
-- The CERT run records it when it finishes (fn_ingest_run_close).
--
-- fn_promote_event_apply: plan mode's operations (python/pipeline/promotion/
-- plan.py) applied in one transaction. It locks the event and the participants,
-- recomputes the input fingerprint (G1 A for the lock), checks what PROD holds
-- (nothing, or the previous promote), makes every write, sets the status, and
-- compares PROD's result fingerprint with CERT's. Any difference raises, so
-- PostgreSQL undoes everything: new fencers, birth years, results, scores, the
-- season's first revision and its lock (ADR-097), the queued recomputes. A dry
-- run always raises at the end. When PROD already holds CERT's result it writes
-- nothing but the status.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_event_result_document(p_event_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql STABLE
SET search_path = public
AS $$
DECLARE
  v_event tbl_event%ROWTYPE;
BEGIN
  SELECT * INTO v_event FROM tbl_event WHERE txt_code = p_event_code;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'PROMOTE_EVENT_NOT_FOUND: %', p_event_code;
  END IF;

  RETURN jsonb_build_object(
    'event', v_event.txt_code,
    'url_event', NULLIF(btrim(COALESCE(v_event.url_event, '')), ''),
    'tournaments', COALESCE((
      SELECT jsonb_agg(
               (to_jsonb(t) - 'id_tournament' - 'id_event' - 'ts_created' - 'ts_updated' - 'dt_last_scraped')
               || jsonb_build_object('results', COALESCE((
                    SELECT jsonb_agg(
                             to_jsonb(r) - 'id_result' - 'id_tournament' - 'id_scoring_revision'
                                         - 'ts_points_calc' - 'ts_created' - 'ts_updated'
                             ORDER BY r.int_place, r.id_fencer)
                      FROM tbl_result r WHERE r.id_tournament = t.id_tournament), '[]'::JSONB))
               ORDER BY t.enum_weapon, t.enum_gender, t.enum_age_category, t.txt_code)
        FROM tbl_tournament t WHERE t.id_event = v_event.id_event), '[]'::JSONB),
    'fencers', COALESCE((
      SELECT jsonb_agg(to_jsonb(f) - 'ts_created' - 'ts_updated' ORDER BY f.id_fencer)
        FROM tbl_fencer f
       WHERE f.id_fencer IN (SELECT r.id_fencer FROM tbl_result r
                               JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
                              WHERE t.id_event = v_event.id_event)), '[]'::JSONB));
END;
$$;

COMMENT ON FUNCTION fn_event_result_document(TEXT) IS
  'ADR-108 §6: what an ingestion left for an event, by codes and fencer ids, without generated ids or timestamps. Its SHA-256 is fn_event_result_fingerprint.';

CREATE OR REPLACE FUNCTION fn_event_result_fingerprint(p_event_code TEXT)
RETURNS TEXT
LANGUAGE sql STABLE
SET search_path = public
AS $$
  SELECT encode(sha256(convert_to(fn_event_result_document(p_event_code)::TEXT, 'UTF8')), 'hex');
$$;

COMMENT ON FUNCTION fn_event_result_fingerprint(TEXT) IS
  'ADR-108 §6: the canonical result fingerprint of an event. The CERT run records it; the apply compares PROD''s with it. Python never computes it.';

-- The CERT run records the result fingerprint when it finishes.
CREATE OR REPLACE FUNCTION fn_ingest_run_close(p_id BIGINT, p_status TEXT, p_listings JSONB, p_error TEXT)
RETURNS JSONB
LANGUAGE plpgsql VOLATILE
SET search_path = public
AS $$
DECLARE
  v_changes JSONB;
  v_status  TEXT;
BEGIN
  UPDATE tbl_ingest_run r
     SET txt_status = p_status, ts_finished = now(), jsonb_listings = p_listings, txt_error = p_error,
         jsonb_master_data = fn_roster_changes(r.jsonb_roster_before, fn_roster_snapshot()),
         txt_result_fingerprint = CASE WHEN p_status = 'FINISHED'
                                       THEN fn_event_result_fingerprint(r.txt_event_code) END
   WHERE r.id_ingest_run = p_id AND r.txt_status = 'RUNNING'
  RETURNING r.jsonb_master_data INTO v_changes;

  IF NOT FOUND THEN
    SELECT txt_status INTO v_status FROM tbl_ingest_run WHERE id_ingest_run = p_id;
    RAISE EXCEPTION 'INGEST_RUN_NOT_RUNNING: run % is %', p_id, COALESCE(v_status, 'missing');
  END IF;
  RETURN v_changes;
END;
$$;

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
  'ADR-108 §6: plan mode''s operations applied in one transaction; raises on any input, prior or result difference; a dry run always raises PROMOTE_DRY_RUN_OK <fingerprint>; skipped when PROD already holds CERT''s result.';

REVOKE ALL ON FUNCTION fn_event_result_document(TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_event_result_fingerprint(TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_promote_event_apply(TEXT, JSONB, TEXT, JSONB, TEXT, TEXT, BOOLEAN) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_event_result_document(TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION fn_event_result_fingerprint(TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION fn_promote_event_apply(TEXT, JSONB, TEXT, JSONB, TEXT, TEXT, BOOLEAN) TO service_role;
