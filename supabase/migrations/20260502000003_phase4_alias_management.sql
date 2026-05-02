-- =============================================================================
-- Phase 4 (ADR-050) — Alias management UI infrastructure
--
-- View, RPCs, and constraints for the new FencerAliasManager.svelte component.
-- Adds the three-operation correction model on top of the matcher-driven
-- json_name_aliases population already shipped in Phase 3:
--
--   Transfer  — alias on wrong fencer; right fencer EXISTS in SPWS
--   Create    — alias on wrong fencer; right person needs a NEW SPWS fencer
--   Discard   — alias on wrong fencer; right person doesn't belong in SPWS
--               (e.g. non-POL fencer matched into an EVF event by mistake)
--
-- Tests: supabase/tests/30_alias_management.sql (16 assertions).
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. tbl_fencer.json_revoked_aliases — Discard tombstones
-- ---------------------------------------------------------------------------
ALTER TABLE tbl_fencer
  ADD COLUMN IF NOT EXISTS json_revoked_aliases JSONB NOT NULL DEFAULT '[]'::JSONB;

COMMENT ON COLUMN tbl_fencer.json_revoked_aliases IS
  'Tombstones for aliases that were Discarded (operator confirmed the matcher '
  'made a wrong binding for a non-SPWS fencer). The matcher consults this list '
  'to avoid re-binding the same scraped string to this fencer. Per-fencer scope '
  '(an alias tombstoned on fencer A may still validly bind to fencer B).';


-- ---------------------------------------------------------------------------
-- 2. Cross-fencer alias-uniqueness invariant
-- An alias string must not appear on more than one fencer's json_name_aliases
-- at any moment. The matcher enforces this implicitly (it auto-binds to the
-- first existing match), but bare UPDATEs could violate it. Trigger catches
-- those.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_check_alias_uniqueness()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_alias TEXT;
  v_other_fencer INT;
BEGIN
  IF NEW.json_name_aliases IS NULL
     OR jsonb_typeof(NEW.json_name_aliases) != 'array'
     OR jsonb_array_length(NEW.json_name_aliases) = 0 THEN
    RETURN NEW;
  END IF;

  FOR v_alias IN
    SELECT jsonb_array_elements_text(NEW.json_name_aliases)
  LOOP
    SELECT id_fencer INTO v_other_fencer
    FROM tbl_fencer
    WHERE id_fencer != NEW.id_fencer
      AND json_name_aliases ? v_alias
    LIMIT 1;

    IF v_other_fencer IS NOT NULL THEN
      RAISE EXCEPTION
        'Alias % already exists on fencer id=% (cannot duplicate on fencer id=%)',
        v_alias, v_other_fencer, NEW.id_fencer;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_alias_uniqueness ON tbl_fencer;

CREATE TRIGGER trg_check_alias_uniqueness
  BEFORE INSERT OR UPDATE OF json_name_aliases ON tbl_fencer
  FOR EACH ROW
  EXECUTE FUNCTION fn_check_alias_uniqueness();

COMMENT ON FUNCTION fn_check_alias_uniqueness() IS
  'BEFORE INSERT/UPDATE trigger on tbl_fencer enforcing the cross-fencer '
  'alias-uniqueness invariant: no alias string appears on more than one '
  'fencer''s json_name_aliases simultaneously.';


-- ---------------------------------------------------------------------------
-- 3. vw_fencer_aliases — list view (all fencers; UI default-filters to alias_count > 0)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_fencer_aliases AS
SELECT
  f.id_fencer,
  f.txt_first_name,
  f.txt_surname,
  COALESCE(f.json_name_aliases, '[]'::jsonb) AS json_name_aliases,
  COALESCE(f.json_revoked_aliases, '[]'::jsonb) AS json_revoked_aliases,
  jsonb_array_length(COALESCE(f.json_name_aliases, '[]'::jsonb)) AS alias_count,
  f.ts_updated AS ts_last_alias_added
FROM tbl_fencer f;

COMMENT ON VIEW vw_fencer_aliases IS
  'List view for FencerAliasManager.svelte. Exposes alias_count for UI '
  'filtering (default: alias_count > 0).';


-- ---------------------------------------------------------------------------
-- 4. fn_list_fencer_aliases — view wrapper (RPC for explicit RLS control)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_list_fencer_aliases()
RETURNS TABLE (
  id_fencer            INT,
  txt_first_name       TEXT,
  txt_surname          TEXT,
  json_name_aliases    JSONB,
  json_revoked_aliases JSONB,
  alias_count          INT,
  ts_last_alias_added  TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT id_fencer, txt_first_name, txt_surname,
         json_name_aliases, json_revoked_aliases,
         alias_count, ts_last_alias_added
    FROM vw_fencer_aliases
    ORDER BY alias_count DESC, txt_surname, txt_first_name;
$$;

REVOKE EXECUTE ON FUNCTION fn_list_fencer_aliases() FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_list_fencer_aliases() TO authenticated;


-- ---------------------------------------------------------------------------
-- 5. fn_transfer_fencer_alias — atomic move + reassign
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_transfer_fencer_alias(
  p_from_fencer INT,
  p_to_fencer   INT,
  p_alias       TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_alias       TEXT := trim(p_alias);
  v_from_arr    JSONB;
  v_to_arr      JSONB;
  v_from_new    JSONB;
  v_to_new      JSONB;
  v_results_moved INT;
  v_tournaments INT[];
  v_t INT;
  v_old_from JSONB;
  v_old_to JSONB;
BEGIN
  IF v_alias IS NULL OR v_alias = '' THEN
    RAISE EXCEPTION 'fn_transfer_fencer_alias: alias is empty';
  END IF;
  IF p_from_fencer = p_to_fencer THEN
    RAISE EXCEPTION 'fn_transfer_fencer_alias: from and to fencer are identical (id=%)', p_from_fencer;
  END IF;

  SELECT COALESCE(json_name_aliases, '[]'::jsonb) INTO v_from_arr
    FROM tbl_fencer WHERE id_fencer = p_from_fencer;
  SELECT COALESCE(json_name_aliases, '[]'::jsonb) INTO v_to_arr
    FROM tbl_fencer WHERE id_fencer = p_to_fencer;

  IF v_from_arr IS NULL THEN
    RAISE EXCEPTION 'fn_transfer_fencer_alias: source fencer % not found', p_from_fencer;
  END IF;
  IF v_to_arr IS NULL THEN
    RAISE EXCEPTION 'fn_transfer_fencer_alias: destination fencer % not found', p_to_fencer;
  END IF;
  IF NOT (v_from_arr ? v_alias) THEN
    RAISE EXCEPTION 'fn_transfer_fencer_alias: alias % not on source fencer %', v_alias, p_from_fencer;
  END IF;

  -- Build new arrays: remove from source, append to destination (no-op if already there)
  SELECT jsonb_agg(elem) INTO v_from_new
    FROM jsonb_array_elements_text(v_from_arr) AS elem
    WHERE elem != v_alias;
  v_from_new := COALESCE(v_from_new, '[]'::jsonb);

  IF v_to_arr ? v_alias THEN
    v_to_new := v_to_arr;  -- already there, no append
  ELSE
    v_to_new := v_to_arr || to_jsonb(v_alias);
  END IF;

  -- Snapshot for audit log
  v_old_from := jsonb_build_object('json_name_aliases', v_from_arr);
  v_old_to   := jsonb_build_object('json_name_aliases', v_to_arr);

  -- Source first (removes alias) — uniqueness trigger then permits dest add
  UPDATE tbl_fencer SET json_name_aliases = v_from_new, ts_updated = NOW()
    WHERE id_fencer = p_from_fencer;
  UPDATE tbl_fencer SET json_name_aliases = v_to_new, ts_updated = NOW()
    WHERE id_fencer = p_to_fencer;

  -- Reassign tbl_result rows whose scraped name = alias and id_fencer = source
  WITH moved AS (
    UPDATE tbl_result
    SET id_fencer = p_to_fencer
    WHERE txt_scraped_name = v_alias
      AND id_fencer = p_from_fencer
    RETURNING id_tournament
  )
  SELECT array_agg(DISTINCT id_tournament), count(*)
    INTO v_tournaments, v_results_moved FROM moved;

  -- Recompute scoring for affected tournaments
  IF v_tournaments IS NOT NULL THEN
    FOREACH v_t IN ARRAY v_tournaments LOOP
      PERFORM fn_calc_tournament_scores(v_t);
    END LOOP;
  END IF;

  -- Audit log entries (one per fencer mutation)
  INSERT INTO tbl_audit_log (txt_table_name, id_row, txt_action, jsonb_old_values, jsonb_new_values)
  VALUES
    ('tbl_fencer', p_from_fencer, 'alias_transfer_source', v_old_from,
       jsonb_build_object('json_name_aliases', v_from_new, 'alias_moved', v_alias, 'to_fencer', p_to_fencer, 'results_moved', COALESCE(v_results_moved, 0))),
    ('tbl_fencer', p_to_fencer, 'alias_transfer_dest', v_old_to,
       jsonb_build_object('json_name_aliases', v_to_new, 'alias_moved', v_alias, 'from_fencer', p_from_fencer, 'results_moved', COALESCE(v_results_moved, 0)));

  RETURN jsonb_build_object(
    'alias',          v_alias,
    'from_fencer',    p_from_fencer,
    'to_fencer',      p_to_fencer,
    'results_moved',  COALESCE(v_results_moved, 0),
    'tournaments_recomputed', COALESCE(array_length(v_tournaments, 1), 0)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_transfer_fencer_alias(INT, INT, TEXT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_transfer_fencer_alias(INT, INT, TEXT) TO authenticated;

COMMENT ON FUNCTION fn_transfer_fencer_alias(INT, INT, TEXT) IS
  'Atomic alias correction: move alias from source fencer to destination, '
  'reassign tbl_result.id_fencer for rows scraped under that alias, recompute '
  'scoring for affected tournaments, audit log. ADR-050 alias UI.';


-- ---------------------------------------------------------------------------
-- 6. fn_split_fencer_from_alias — create new fencer + transfer alias
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_split_fencer_from_alias(
  p_from_fencer    INT,
  p_alias          TEXT,
  p_new_fencer_data JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_new_id INT;
  v_surname     TEXT := p_new_fencer_data ->> 'txt_surname';
  v_first_name  TEXT := p_new_fencer_data ->> 'txt_first_name';
  v_birth_year  INT  := (p_new_fencer_data ->> 'int_birth_year')::INT;
  v_gender      enum_gender_type := (p_new_fencer_data ->> 'enum_gender')::enum_gender_type;
  v_country     TEXT := p_new_fencer_data ->> 'txt_nationality';
  v_club        TEXT := p_new_fencer_data ->> 'txt_club';
  v_transfer_result JSONB;
BEGIN
  IF v_surname IS NULL OR v_first_name IS NULL OR v_birth_year IS NULL OR v_gender IS NULL THEN
    RAISE EXCEPTION 'fn_split_fencer_from_alias: required fields missing (txt_surname, txt_first_name, int_birth_year, enum_gender)';
  END IF;

  INSERT INTO tbl_fencer (
    txt_surname, txt_first_name, int_birth_year, enum_gender,
    txt_nationality, txt_club, json_name_aliases
  )
  VALUES (
    v_surname, v_first_name, v_birth_year, v_gender,
    COALESCE(v_country, 'PL'), v_club, '[]'::jsonb
  )
  RETURNING id_fencer INTO v_new_id;

  -- Audit log for fencer creation
  INSERT INTO tbl_audit_log (txt_table_name, id_row, txt_action, jsonb_new_values)
  VALUES ('tbl_fencer', v_new_id, 'create_from_alias_split',
          jsonb_build_object(
            'split_from_fencer', p_from_fencer,
            'alias', p_alias,
            'new_fencer_data', p_new_fencer_data
          ));

  -- Reuse transfer logic for the alias + result reassignment
  SELECT fn_transfer_fencer_alias(p_from_fencer, v_new_id, p_alias) INTO v_transfer_result;

  RETURN jsonb_build_object(
    'new_fencer_id',   v_new_id,
    'transfer_result', v_transfer_result
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_split_fencer_from_alias(INT, TEXT, JSONB) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_split_fencer_from_alias(INT, TEXT, JSONB) TO authenticated;

COMMENT ON FUNCTION fn_split_fencer_from_alias(INT, TEXT, JSONB) IS
  'Create a new fencer from operator-supplied data, then transfer the alias '
  'and any matching tbl_result rows from source to the new fencer. Reuses '
  'fn_transfer_fencer_alias internally for the move. ADR-050 alias UI.';


-- ---------------------------------------------------------------------------
-- 7. fn_discard_fencer_alias_and_results — tombstone + hard-delete results
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_discard_fencer_alias_and_results(
  p_from_fencer INT,
  p_alias       TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_alias       TEXT := trim(p_alias);
  v_from_arr    JSONB;
  v_revoked_arr JSONB;
  v_from_new    JSONB;
  v_revoked_new JSONB;
  v_results_deleted INT;
  v_tournaments INT[];
  v_t INT;
  v_old JSONB;
BEGIN
  IF v_alias IS NULL OR v_alias = '' THEN
    RAISE EXCEPTION 'fn_discard_fencer_alias_and_results: alias is empty';
  END IF;

  SELECT COALESCE(json_name_aliases, '[]'::jsonb), COALESCE(json_revoked_aliases, '[]'::jsonb)
    INTO v_from_arr, v_revoked_arr
    FROM tbl_fencer WHERE id_fencer = p_from_fencer;

  IF v_from_arr IS NULL THEN
    RAISE EXCEPTION 'fn_discard_fencer_alias_and_results: fencer % not found', p_from_fencer;
  END IF;
  IF NOT (v_from_arr ? v_alias) THEN
    RAISE EXCEPTION 'fn_discard_fencer_alias_and_results: alias % not on fencer %', v_alias, p_from_fencer;
  END IF;

  -- Remove from active aliases
  SELECT jsonb_agg(elem) INTO v_from_new
    FROM jsonb_array_elements_text(v_from_arr) AS elem
    WHERE elem != v_alias;
  v_from_new := COALESCE(v_from_new, '[]'::jsonb);

  -- Append to revoked (tombstone)
  IF v_revoked_arr ? v_alias THEN
    v_revoked_new := v_revoked_arr;
  ELSE
    v_revoked_new := v_revoked_arr || to_jsonb(v_alias);
  END IF;

  v_old := jsonb_build_object(
    'json_name_aliases', v_from_arr,
    'json_revoked_aliases', v_revoked_arr
  );

  UPDATE tbl_fencer
    SET json_name_aliases = v_from_new,
        json_revoked_aliases = v_revoked_new,
        ts_updated = NOW()
    WHERE id_fencer = p_from_fencer;

  -- Snapshot affected results into a temp table for tournament discovery + audit
  CREATE TEMP TABLE _discard_affected_results ON COMMIT DROP AS
    SELECT id_result, id_tournament, id_fencer, int_place, txt_scraped_name
    FROM tbl_result
    WHERE txt_scraped_name = v_alias
      AND id_fencer = p_from_fencer;

  SELECT count(*)::INT, array_agg(DISTINCT id_tournament)
    INTO v_results_deleted, v_tournaments
    FROM _discard_affected_results;

  -- Hard-delete the rows
  DELETE FROM tbl_result
    WHERE txt_scraped_name = v_alias
      AND id_fencer = p_from_fencer;

  -- Recompute scoring for affected tournaments (now without these rows)
  IF v_tournaments IS NOT NULL THEN
    FOREACH v_t IN ARRAY v_tournaments LOOP
      PERFORM fn_calc_tournament_scores(v_t);
    END LOOP;
  END IF;

  -- Audit log
  INSERT INTO tbl_audit_log (txt_table_name, id_row, txt_action, jsonb_old_values, jsonb_new_values)
  VALUES (
    'tbl_fencer', p_from_fencer, 'alias_discard',
    v_old,
    jsonb_build_object(
      'json_name_aliases', v_from_new,
      'json_revoked_aliases', v_revoked_new,
      'alias_discarded', v_alias,
      'results_deleted', COALESCE(v_results_deleted, 0),
      'deleted_rows', (SELECT jsonb_agg(to_jsonb(r)) FROM _discard_affected_results r)
    )
  );

  RETURN jsonb_build_object(
    'alias',           v_alias,
    'fencer',          p_from_fencer,
    'results_deleted', COALESCE(v_results_deleted, 0),
    'tournaments_recomputed', COALESCE(array_length(v_tournaments, 1), 0)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_discard_fencer_alias_and_results(INT, TEXT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_discard_fencer_alias_and_results(INT, TEXT) TO authenticated;

COMMENT ON FUNCTION fn_discard_fencer_alias_and_results(INT, TEXT) IS
  'Discard a wrong-binding alias when the right person doesn''t belong in '
  'SPWS at all (e.g. non-POL fencer matched into an EVF event). Tombstones '
  'the alias on json_revoked_aliases (so the matcher won''t re-bind), '
  'hard-deletes affected tbl_result rows, recomputes scoring for affected '
  'tournaments, audit log. ADR-050 alias UI.';

COMMIT;
