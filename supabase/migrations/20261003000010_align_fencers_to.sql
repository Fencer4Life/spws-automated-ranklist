-- =============================================================================
-- ADR-108 §3 — fn_align_fencers_to: give a target database PROD's fencer ids
-- =============================================================================
-- The administrator's rule: the fencer id is the same on LOCAL, CERT and PROD,
-- and nothing is guessed. `python/pipeline/promotion/refresh.py` pairs every
-- target fencer with its PROD row (name, birth year, namesake rule, recorded
-- decisions) and sends the pairing here. This function applies it in one
-- transaction and checks the result before it returns.
--
--   p_pairs          [{"cert_id": <target id>, "prod_id": <PROD id>}] — every
--                    target fencer that is a PROD fencer, moving or not
--   p_prod_roster    PROD's tbl_fencer rows, every column (to_jsonb of a row)
--   p_deletes        target ids that exist only on the target; nothing may
--                    refer to them
--   p_prod_sequence  PROD's id sequence, so the target never allocates below it
--   p_dry_run        do everything, then raise ALIGN_DRY_RUN_OK with the summary
--
-- Every foreign key to tbl_fencer is ON UPDATE NO ACTION and not deferrable, so
-- an id cannot simply be updated. Each moving fencer is therefore copied to a
-- temporary negative id, every reference moves there, and the old row is
-- deleted; then the same again to PROD's id. Swaps and cycles of ids cannot
-- collide, and no trigger is switched off:
--   * the copies carry no aliases, because trg_check_alias_uniqueness would
--     refuse a second holder; PROD's aliases are written afterwards;
--   * the copies keep the target's own birth year while results move, so
--     trg_assert_result_vcat is satisfied exactly as before; a result it would
--     refuse today is listed before anything is written (ALIGN_VCAT);
--   * season nationality rows move first: trg_result_season_nationality then
--     recomputes them at the end of each result statement and finds them in place;
--   * references always move before a row is deleted, because two of them
--     (season nationality, identity override) cascade on delete.
-- The references are every foreign key to tbl_fencer, read from the catalogue,
-- plus the soft ones: tbl_result_draft.id_fencer, and tbl_audit_log rows written
-- before the alignment (id_row of fencer rows, "id_fencer" in old and new values).
--
-- Then PROD's values are copied with an ordinary UPDATE, so a moved birth year
-- queues recomputes through trg_fencer_change_enqueue, as a correction on PROD
-- does; PROD-only fencers are created at PROD's ids; the sequence is set.
--
-- Before returning: the roster must equal PROD's in every column but the
-- timestamps, and every person must hold exactly the rows they held before, in
-- every referencing table. Any difference raises, and nothing persists.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_align_fencers_to(
  p_pairs         JSONB,
  p_prod_roster   JSONB,
  p_deletes       JSONB   DEFAULT '[]'::JSONB,
  p_prod_sequence BIGINT  DEFAULT NULL,
  p_dry_run       BOOLEAN DEFAULT FALSE
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET client_min_messages = warning
AS $$
DECLARE
  v_ref        RECORD;
  v_bad        TEXT;
  v_audit_max  BIGINT;
  v_set_cols   TEXT;
  v_f_cols     TEXT;
  v_p_cols     TEXT;
  v_cmp_cols   TEXT;
  v_renumbered INT;
  v_created    INT;
  v_deleted    INT;
  v_changed    INT;
  v_seq        BIGINT;
  v_map        JSONB;
  v_summary    JSONB;
BEGIN
  -- ---------------------------------------------------------------- inputs
  DROP TABLE IF EXISTS pg_temp._align_map, pg_temp._align_prod, pg_temp._align_del, pg_temp._align_refs,
                       pg_temp._align_before, pg_temp._align_after, pg_temp._align_orig;

  CREATE TEMP TABLE _align_map ON COMMIT DROP AS
  SELECT (x->>'cert_id')::INT AS cert_id, (x->>'prod_id')::INT AS prod_id, -((x->>'cert_id')::INT) AS tmp_id
    FROM jsonb_array_elements(COALESCE(p_pairs, '[]'::JSONB)) x;

  CREATE TEMP TABLE _align_prod ON COMMIT DROP AS
  SELECT * FROM jsonb_populate_recordset(NULL::tbl_fencer, COALESCE(p_prod_roster, '[]'::JSONB));
  UPDATE _align_prod SET ts_created = COALESCE(ts_created, now()), ts_updated = COALESCE(ts_updated, now());

  CREATE TEMP TABLE _align_del ON COMMIT DROP AS
  SELECT (x #>> '{}')::INT AS id_fencer FROM jsonb_array_elements(COALESCE(p_deletes, '[]'::JSONB)) x;

  -- Every reference to a fencer: the foreign keys, from the catalogue, then the
  -- one soft column. Season nationality first (see the header).
  CREATE TEMP TABLE _align_refs ON COMMIT DROP AS
  SELECT c.conrelid::regclass::TEXT AS tbl, a.attname::TEXT AS col, array_length(c.conkey, 1) AS width
    FROM pg_constraint c
    JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
   WHERE c.contype = 'f' AND c.confrelid = 'tbl_fencer'::regclass
  UNION ALL
  SELECT 'tbl_result_draft', 'id_fencer', 1;

  SELECT string_agg(tbl || '.' || col, ', ') INTO v_bad FROM _align_refs WHERE width <> 1;
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'ALIGN_COMPOSITE_REFERENCE: % (this function moves single-column references only)', v_bad;
  END IF;

  -- ---------------------------------------------------------------- the payload is whole and unambiguous
  IF EXISTS (SELECT 1 FROM _align_map WHERE cert_id IS NULL OR prod_id IS NULL OR cert_id <= 0 OR prod_id <= 0)
     OR EXISTS (SELECT 1 FROM _align_prod WHERE id_fencer IS NULL OR id_fencer <= 0)
     OR EXISTS (SELECT 1 FROM tbl_fencer WHERE id_fencer <= 0) THEN
    RAISE EXCEPTION 'ALIGN_BAD_ID: every id must be a positive integer, and the negative range must be free';
  END IF;

  SELECT string_agg(cert_id::TEXT, ', ' ORDER BY cert_id) INTO v_bad
    FROM (SELECT cert_id FROM _align_map GROUP BY cert_id HAVING count(*) > 1) d;
  IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'ALIGN_DUPLICATE_TARGET_ID: %', v_bad; END IF;

  SELECT string_agg(prod_id::TEXT, ', ' ORDER BY prod_id) INTO v_bad
    FROM (SELECT prod_id FROM _align_map GROUP BY prod_id HAVING count(*) > 1) d;
  IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'ALIGN_DUPLICATE_PROD_ID: %', v_bad; END IF;

  SELECT string_agg(id_fencer::TEXT, ', ' ORDER BY id_fencer) INTO v_bad
    FROM (SELECT id_fencer FROM _align_prod GROUP BY id_fencer HAVING count(*) > 1) d;
  IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'ALIGN_DUPLICATE_PROD_ROW: %', v_bad; END IF;

  SELECT string_agg(m.prod_id::TEXT, ', ' ORDER BY m.prod_id) INTO v_bad
    FROM _align_map m WHERE NOT EXISTS (SELECT 1 FROM _align_prod p WHERE p.id_fencer = m.prod_id);
  IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'ALIGN_PROD_ID_NOT_IN_ROSTER: %', v_bad; END IF;

  SELECT string_agg(m.cert_id::TEXT, ', ' ORDER BY m.cert_id) INTO v_bad
    FROM _align_map m WHERE NOT EXISTS (SELECT 1 FROM tbl_fencer f WHERE f.id_fencer = m.cert_id);
  IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'ALIGN_TARGET_ID_UNKNOWN: %', v_bad; END IF;

  SELECT string_agg(d.id_fencer::TEXT, ', ' ORDER BY d.id_fencer) INTO v_bad
    FROM _align_del d JOIN _align_map m ON m.cert_id = d.id_fencer;
  IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'ALIGN_PAIRED_AND_DELETED: %', v_bad; END IF;

  SELECT string_agg(d.id_fencer::TEXT, ', ' ORDER BY d.id_fencer) INTO v_bad
    FROM _align_del d WHERE NOT EXISTS (SELECT 1 FROM tbl_fencer f WHERE f.id_fencer = d.id_fencer);
  IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'ALIGN_DELETE_UNKNOWN: %', v_bad; END IF;

  SELECT string_agg(f.id_fencer::TEXT, ', ' ORDER BY f.id_fencer) INTO v_bad
    FROM tbl_fencer f
   WHERE NOT EXISTS (SELECT 1 FROM _align_map m WHERE m.cert_id = f.id_fencer)
     AND NOT EXISTS (SELECT 1 FROM _align_del d WHERE d.id_fencer = f.id_fencer);
  IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'ALIGN_UNPAIRED: %', v_bad; END IF;

  -- A deleted fencer is one nothing refers to.
  FOR v_ref IN SELECT tbl, col FROM _align_refs LOOP
    EXECUTE format('SELECT string_agg(DISTINCT t.%2$I::TEXT, '', '') FROM %1$s t JOIN _align_del d ON d.id_fencer = t.%2$I',
                   v_ref.tbl, v_ref.col) INTO v_bad;
    IF v_bad IS NOT NULL THEN
      RAISE EXCEPTION 'ALIGN_DELETE_REFERENCED: % (referenced from %)', v_bad, v_ref.tbl;
    END IF;
  END LOOP;

  -- A result the V-category trigger would refuse today would stop the move halfway.
  SELECT string_agg(format('%s (result %s in %s)', r.id_fencer, r.id_result, t.txt_code), '; '
                    ORDER BY r.id_fencer, r.id_result) INTO v_bad
    FROM tbl_result r
    JOIN _align_map m     ON m.cert_id = r.id_fencer AND m.cert_id <> m.prod_id
    JOIN tbl_fencer f     ON f.id_fencer = r.id_fencer
    JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
    JOIN tbl_event e      ON e.id_event = t.id_event
    JOIN tbl_season s     ON s.id_season = e.id_season
   WHERE r.enum_source_age_category IS NULL
     AND fn_vcat_violation_msg(f.int_birth_year::INT, t.enum_age_category, EXTRACT(YEAR FROM s.dt_end)::INT,
                               f.txt_surname || ' ' || f.txt_first_name, t.txt_code) IS NOT NULL;
  IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'ALIGN_VCAT: %', v_bad; END IF;

  -- ---------------------------------------------------------------- what each person holds now
  CREATE TEMP TABLE _align_before (tbl TEXT, id_fencer INT, n BIGINT) ON COMMIT DROP;
  CREATE TEMP TABLE _align_after  (tbl TEXT, id_fencer INT, n BIGINT) ON COMMIT DROP;
  FOR v_ref IN SELECT tbl, col FROM _align_refs LOOP
    EXECUTE format('INSERT INTO _align_before SELECT %3$L, m.prod_id, count(*) FROM %1$s t
                      JOIN _align_map m ON m.cert_id = t.%2$I GROUP BY m.prod_id',
                   v_ref.tbl, v_ref.col, v_ref.tbl);
  END LOOP;

  -- Each paired fencer's row as it is now, under PROD's id, to count real changes
  -- (the temporary copies carry no aliases, so the rows in between are no guide).
  CREATE TEMP TABLE _align_orig ON COMMIT DROP AS
  SELECT (jsonb_populate_record(NULL::tbl_fencer, to_jsonb(f) || jsonb_build_object('id_fencer', m.prod_id))).*
    FROM tbl_fencer f JOIN _align_map m ON m.cert_id = f.id_fencer;

  SELECT COALESCE(max(id_log), 0) INTO v_audit_max FROM tbl_audit_log;

  -- ---------------------------------------------------------------- delete target-only fencers
  DELETE FROM tbl_fencer f USING _align_del d WHERE f.id_fencer = d.id_fencer;
  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  -- ---------------------------------------------------------------- phase 1: to the temporary ids
  INSERT INTO tbl_fencer
  SELECT (jsonb_populate_record(NULL::tbl_fencer,
            to_jsonb(f) || jsonb_build_object('id_fencer', m.tmp_id, 'json_name_aliases', '[]'::JSONB))).*
    FROM tbl_fencer f JOIN _align_map m ON m.cert_id = f.id_fencer
   WHERE m.cert_id <> m.prod_id;

  FOR v_ref IN SELECT tbl, col FROM _align_refs ORDER BY (tbl = 'tbl_fencer_nationality') DESC, tbl LOOP
    EXECUTE format('UPDATE %1$s t SET %2$I = m.tmp_id FROM _align_map m
                     WHERE t.%2$I = m.cert_id AND m.cert_id <> m.prod_id', v_ref.tbl, v_ref.col);
  END LOOP;

  DELETE FROM tbl_fencer f USING _align_map m WHERE f.id_fencer = m.cert_id AND m.cert_id <> m.prod_id;

  -- ---------------------------------------------------------------- phase 2: to PROD's ids
  INSERT INTO tbl_fencer
  SELECT (jsonb_populate_record(NULL::tbl_fencer, to_jsonb(f) || jsonb_build_object('id_fencer', m.prod_id))).*
    FROM tbl_fencer f JOIN _align_map m ON m.tmp_id = f.id_fencer
   WHERE m.cert_id <> m.prod_id;

  FOR v_ref IN SELECT tbl, col FROM _align_refs ORDER BY (tbl = 'tbl_fencer_nationality') DESC, tbl LOOP
    EXECUTE format('UPDATE %1$s t SET %2$I = m.prod_id FROM _align_map m
                     WHERE t.%2$I = m.tmp_id AND m.cert_id <> m.prod_id', v_ref.tbl, v_ref.col);
  END LOOP;

  DELETE FROM tbl_fencer f USING _align_map m WHERE f.id_fencer = m.tmp_id AND m.cert_id <> m.prod_id;

  -- ---------------------------------------------------------------- PROD's values
  -- An alias that differs from PROD's is cleared first, so no alias ever has
  -- two holders while the rows are updated one by one.
  UPDATE tbl_fencer f SET json_name_aliases = '[]'::JSONB
    FROM _align_prod p
   WHERE p.id_fencer = f.id_fencer AND f.json_name_aliases IS DISTINCT FROM p.json_name_aliases;

  SELECT string_agg(format('%1$I = p.%1$I', column_name), ', ' ORDER BY ordinal_position),
         string_agg(format('f.%I', column_name), ', ' ORDER BY ordinal_position),
         string_agg(format('p.%I', column_name), ', ' ORDER BY ordinal_position)
    INTO v_set_cols, v_f_cols, v_p_cols
    FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'tbl_fencer'
     AND column_name NOT IN ('id_fencer', 'ts_created', 'ts_updated');

  EXECUTE format('UPDATE tbl_fencer f SET %s, ts_updated = now() FROM _align_prod p
                   WHERE p.id_fencer = f.id_fencer AND (%s) IS DISTINCT FROM (%s)',
                 v_set_cols, v_f_cols, v_p_cols);

  EXECUTE format('SELECT count(*) FROM _align_orig f JOIN _align_prod p ON p.id_fencer = f.id_fencer
                   WHERE (%s) IS DISTINCT FROM (%s)', v_f_cols, v_p_cols)
    INTO v_changed;

  -- ---------------------------------------------------------------- PROD-only fencers
  INSERT INTO tbl_fencer
  SELECT p.* FROM _align_prod p WHERE NOT EXISTS (SELECT 1 FROM _align_map m WHERE m.prod_id = p.id_fencer);
  GET DIAGNOSTICS v_created = ROW_COUNT;

  -- ---------------------------------------------------------------- the sequence
  -- setval is not transactional, so a dry run only reports the value.
  SELECT GREATEST(COALESCE(max(id_fencer), 1), COALESCE(p_prod_sequence, 0)) INTO v_seq FROM tbl_fencer;
  IF NOT p_dry_run THEN
    PERFORM setval(pg_get_serial_sequence('tbl_fencer', 'id_fencer'), v_seq, true);
  END IF;

  -- ---------------------------------------------------------------- history follows the person
  UPDATE tbl_audit_log a SET id_row = m.prod_id
    FROM _align_map m
   WHERE a.id_log <= v_audit_max AND a.txt_table_name = 'tbl_fencer'
     AND a.id_row = m.cert_id AND m.cert_id <> m.prod_id;

  UPDATE tbl_audit_log a SET jsonb_old_values = jsonb_set(a.jsonb_old_values, '{id_fencer}', to_jsonb(m.prod_id))
    FROM _align_map m
   WHERE a.id_log <= v_audit_max AND jsonb_typeof(a.jsonb_old_values) = 'object'
     AND a.jsonb_old_values->>'id_fencer' = m.cert_id::TEXT AND m.cert_id <> m.prod_id;

  UPDATE tbl_audit_log a SET jsonb_new_values = jsonb_set(a.jsonb_new_values, '{id_fencer}', to_jsonb(m.prod_id))
    FROM _align_map m
   WHERE a.id_log <= v_audit_max AND jsonb_typeof(a.jsonb_new_values) = 'object'
     AND a.jsonb_new_values->>'id_fencer' = m.cert_id::TEXT AND m.cert_id <> m.prod_id;

  -- ---------------------------------------------------------------- check before returning
  SELECT string_agg(format('%I', column_name), ', ' ORDER BY ordinal_position) INTO v_cmp_cols
    FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'tbl_fencer'
     AND column_name NOT IN ('ts_created', 'ts_updated');

  EXECUTE format('SELECT string_agg(DISTINCT id_fencer::TEXT, '', '') FROM (
                    (SELECT %1$s FROM tbl_fencer EXCEPT SELECT %1$s FROM _align_prod)
                    UNION ALL
                    (SELECT %1$s FROM _align_prod EXCEPT SELECT %1$s FROM tbl_fencer)) d', v_cmp_cols)
    INTO v_bad;
  IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'ALIGN_ROSTER_MISMATCH: %', v_bad; END IF;

  FOR v_ref IN SELECT tbl, col FROM _align_refs LOOP
    EXECUTE format('INSERT INTO _align_after SELECT %3$L, t.%2$I, count(*) FROM %1$s t
                     WHERE t.%2$I IN (SELECT prod_id FROM _align_map) GROUP BY t.%2$I',
                   v_ref.tbl, v_ref.col, v_ref.tbl);
  END LOOP;

  SELECT string_agg(format('%s in %s: %s before, %s after', COALESCE(b.id_fencer, a.id_fencer),
                           COALESCE(b.tbl, a.tbl), COALESCE(b.n, 0), COALESCE(a.n, 0)), '; ') INTO v_bad
    FROM _align_before b FULL JOIN _align_after a ON a.tbl = b.tbl AND a.id_fencer = b.id_fencer
   WHERE COALESCE(b.n, 0) <> COALESCE(a.n, 0);
  IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'ALIGN_REFERENCES_MOVED: %', v_bad; END IF;

  -- ---------------------------------------------------------------- record it
  SELECT count(*) INTO v_renumbered FROM _align_map WHERE cert_id <> prod_id;
  SELECT COALESCE(jsonb_object_agg(cert_id::TEXT, prod_id), '{}'::JSONB) INTO v_map
    FROM _align_map WHERE cert_id <> prod_id;
  v_summary := jsonb_build_object('renumbered', v_renumbered, 'created', v_created, 'deleted', v_deleted,
                                  'values_changed', v_changed, 'sequence', v_seq);

  INSERT INTO tbl_audit_log (txt_table_name, id_row, txt_action, jsonb_old_values, jsonb_new_values)
  VALUES ('tbl_fencer', 0, 'ALIGN_TO_PROD', v_map, v_summary);

  IF p_dry_run THEN
    RAISE EXCEPTION 'ALIGN_DRY_RUN_OK %', v_summary::TEXT;
  END IF;
  RETURN v_summary;
END;
$$;

COMMENT ON FUNCTION fn_align_fencers_to(JSONB, JSONB, JSONB, BIGINT, BOOLEAN) IS
  'ADR-108 §3: give this database PROD''s fencer ids in one checked transaction (two-phase renumbering, PROD values, creates, deletes, sequence, audit). LOCAL and CERT only.';

REVOKE ALL ON FUNCTION fn_align_fencers_to(JSONB, JSONB, JSONB, BIGINT, BOOLEAN) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_align_fencers_to(JSONB, JSONB, JSONB, BIGINT, BOOLEAN) TO service_role;
