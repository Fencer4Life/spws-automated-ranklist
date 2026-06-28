-- =============================================================================
-- ADR-077 §5/§7 — CERT→PROD season-skeleton promotion RPCs
-- =============================================================================
-- Two target-side functions backing the SeasonManager "⬆ Promote to PROD" /
-- "Remove from PROD" controls. The cross-env hop is orchestrated by
-- python/pipeline/promote_season.py (reads CERT, writes PROD via the Management
-- API + service role, like promote.py) — these functions run *within one DB*:
--
--   fn_promote_season_skeleton(p_payload JSONB) — INSERT a childless season +
--     its events + scoring_config with EXPLICIT ids so the new season's ids stay
--     aligned across envs going forward. id_prior_event in the payload is already
--     resolved to TARGET ids by txt_code (the Python caller), NOT raw source ids
--     — the one-time natural-key baseline left legacy event ids divergent between
--     CERT and PROD, so a raw-id copy would mis-link carry-over (same hazard as
--     the export_seed id_prior_event fix, 2026-06-28).
--
--   fn_delete_season_skeleton(p_id_season INT) — reversibility: delete a whole
--     childless, non-active season (events → scoring_config → season). Symmetric
--     on CERT and PROD.
--
-- Guards (ADR-077): childless (no tbl_tournament child / source_childless flag),
-- not-active (deleting the live season would blank the ranklist), idempotency
-- (refuse if the season code already exists on the target).
-- id columns are plain serial (nextval) so explicit ids go in the column list;
-- trg_season_auto_config auto-creates scoring_config on season INSERT, which we
-- then replace with the promoted values.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_promote_season_skeleton(p_payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_season  JSONB := p_payload -> 'season';
  v_sc      JSONB := p_payload -> 'scoring_config';
  v_events  JSONB := COALESCE(p_payload -> 'events', '[]'::JSONB);
  v_code    TEXT  := v_season ->> 'txt_code';
  v_id      INT   := (v_season ->> 'id_season')::INT;
  v_cols    TEXT;
  v_n       INT;
BEGIN
  IF v_season IS NULL OR v_code IS NULL OR v_id IS NULL THEN
    RAISE EXCEPTION 'fn_promote_season_skeleton: payload.season must include txt_code + id_season';
  END IF;

  -- Childless guard (caller asserts the SOURCE season has no tournament children).
  IF COALESCE((p_payload ->> 'source_childless')::BOOLEAN, FALSE) IS NOT TRUE THEN
    RAISE EXCEPTION
      'fn_promote_season_skeleton: refused — source season % is not childless (results may exist)', v_code;
  END IF;

  -- Idempotency: never overwrite an existing season on the target.
  IF EXISTS (SELECT 1 FROM tbl_season WHERE txt_code = v_code) THEN
    RAISE EXCEPTION 'fn_promote_season_skeleton: season % already exists on target', v_code;
  END IF;

  -- Insert only the columns PRESENT in each payload object so omitted columns
  -- (ts_created, defaults, …) keep their DEFAULT — jsonb_populate_record would
  -- otherwise null them and violate NOT-NULL. Column-agnostic: survives schema
  -- additions without code change.

  -- Season with explicit id. trg_season_auto_config creates a default scoring_config.
  SELECT string_agg(quote_ident(key), ', ') INTO v_cols FROM jsonb_object_keys(v_season) AS key;
  EXECUTE format(
    'INSERT INTO tbl_season (%1$s) SELECT %1$s FROM jsonb_populate_record(NULL::tbl_season, $1)',
    v_cols
  ) USING v_season;

  -- Replace the auto-created scoring_config with the promoted values (id_season
  -- carried in the payload row).
  IF v_sc IS NOT NULL AND v_sc <> 'null'::JSONB THEN
    -- id_config is tbl_scoring_config's OWN serial PK (independent of id_season);
    -- drop it so the promoted row gets a fresh one — copying the source's id_config
    -- collides with an existing target config. All config lookups key on id_season.
    v_sc := v_sc - 'id_config';
    DELETE FROM tbl_scoring_config WHERE id_season = v_id;
    SELECT string_agg(quote_ident(key), ', ') INTO v_cols FROM jsonb_object_keys(v_sc) AS key;
    EXECUTE format(
      'INSERT INTO tbl_scoring_config (%1$s) SELECT %1$s FROM jsonb_populate_record(NULL::tbl_scoring_config, $1)',
      v_cols
    ) USING v_sc;
  END IF;

  -- Events with explicit ids; id_prior_event already target-resolved by the caller.
  -- Project the UNION of keys across all events (robust to non-uniform payloads —
  -- e.g. only some events carry id_prior_event); rows missing a projected key get NULL.
  IF jsonb_array_length(v_events) > 0 THEN
    SELECT string_agg(DISTINCT quote_ident(key), ', ') INTO v_cols
      FROM jsonb_array_elements(v_events) AS ev, jsonb_object_keys(ev) AS key;
    EXECUTE format(
      'INSERT INTO tbl_event (%1$s) SELECT %1$s FROM jsonb_populate_recordset(NULL::tbl_event, $1)',
      v_cols
    ) USING v_events;
    GET DIAGNOSTICS v_n = ROW_COUNT;
  ELSE
    v_n := 0;
  END IF;

  -- Advance sequences past the explicit ids so later allocations don't collide.
  PERFORM setval('tbl_season_id_season_seq', GREATEST((SELECT MAX(id_season) FROM tbl_season), 1));
  PERFORM setval('tbl_event_id_event_seq',  GREATEST((SELECT MAX(id_event)  FROM tbl_event), 1));

  RETURN jsonb_build_object(
    'season_code', v_code,
    'id_season', v_id,
    'events_created', v_n
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_promote_season_skeleton(JSONB) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_promote_season_skeleton(JSONB) TO authenticated;


CREATE OR REPLACE FUNCTION fn_delete_season_skeleton(p_id_season INT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_code   TEXT;
  v_active BOOLEAN;
  v_n      INT;
BEGIN
  SELECT txt_code, bool_active INTO v_code, v_active
    FROM tbl_season WHERE id_season = p_id_season;
  IF v_code IS NULL THEN
    RAISE EXCEPTION 'fn_delete_season_skeleton: season % not found', p_id_season;
  END IF;

  -- Not-active guard: deleting the live season would blank the ranklist.
  IF v_active THEN
    RAISE EXCEPTION 'fn_delete_season_skeleton: season % is active — refused', v_code;
  END IF;

  -- Childless guard: once any event has a tournament child, results may exist.
  IF EXISTS (
    SELECT 1 FROM tbl_tournament t
      JOIN tbl_event e ON e.id_event = t.id_event
     WHERE e.id_season = p_id_season
  ) THEN
    RAISE EXCEPTION
      'fn_delete_season_skeleton: season % has events with tournament children — refused', v_code;
  END IF;

  SELECT COUNT(*)::INT INTO v_n FROM tbl_event WHERE id_season = p_id_season;

  DELETE FROM tbl_event          WHERE id_season = p_id_season;
  DELETE FROM tbl_scoring_config WHERE id_season = p_id_season;
  DELETE FROM tbl_season         WHERE id_season = p_id_season;

  RETURN jsonb_build_object('season_code', v_code, 'events_deleted', v_n);
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_delete_season_skeleton(INT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_delete_season_skeleton(INT) TO authenticated;
