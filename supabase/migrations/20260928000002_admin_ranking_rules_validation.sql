-- =============================================================================
-- ADM27 — ranking buckets are validated when an admin writes them; the last
-- stub-tournament helper is dropped
-- =============================================================================
-- Plan: doc/plans/admin-ui-ranking-buckets-and-skeletons-2026-09-28.html
-- (Part 2 · A and D). Tests: supabase/tests/84_admin_ranking_rules_validation.sql.
--
-- 1 · fn_validate_ranking_rules_write
--   fn_import_scoring_config stored any ranking_rules it was given. In the
--   two-pool shape, fn_ranking_rules_canonical drops an international bucket
--   whose types are all domestic without a word, and a type named in two
--   buckets counts one score twice. PROD's SPWS-2026-2027 carried an
--   international "PPW best 1" and "MPW best 0" that no ranking ever used.
--   The write now refuses a bucket that:
--     * names a type outside its pool (domestic: PPW, MPW; international:
--       PEW, MEW, MSW, PSW, PPS, MPS) or an unknown type, or no type at all;
--     * repeats a type already named by another bucket, in either pool;
--     * does not declare exactly one of "best" (a whole number >= 1) or
--       "always": true.
--   Three-section rules (schema_version 2, ADR-098) are checked by
--   fn_ranking_rules_canonical itself, which already refuses these faults.
--
-- 2 · fn_import_scoring_config calls it only when the rules CHANGE
--   Every Admin save re-sends the whole configuration. 2024/25 and 2025/26
--   repeat their domestic buckets in the international pool by design (the
--   adapter drops the copies), so an unconditional check would make those
--   seasons unsavable. How stored rules are read is unchanged, so no ranking
--   moves. The body is 20260928000001's, with the one added call before the
--   write.
--
-- 3 · _fn_create_skeleton_children is dropped
--   fn_init_season stopped creating skeleton brackets on 27 Jun 2026
--   (20260627000003); the helper stayed only as a pgTAP fixture builder, still
--   executable by authenticated. 19_phase3_wizard.sql now inserts its brackets
--   directly.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_validate_ranking_rules_write(p_rules JSONB)
RETURNS VOID
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  c_pool_types CONSTANT JSONB :=
    '{"domestic": ["PPW", "MPW"], "international": ["PEW", "MEW", "MSW", "PSW", "PPS", "MPS"]}';
  v_pool       TEXT;
  v_bucket     JSONB;
  v_idx        INT;
  v_type       TEXT;
  v_seen       TEXT[] := '{}';
  v_has_best   BOOLEAN;
  v_has_always BOOLEAN;
BEGIN
  IF p_rules IS NULL OR jsonb_typeof(p_rules) = 'null' THEN
    RETURN;
  END IF;
  IF jsonb_typeof(p_rules) <> 'object' THEN
    RAISE EXCEPTION 'Ranking rules must be a JSON object';
  END IF;

  IF p_rules ? 'schema_version' THEN
    PERFORM fn_ranking_rules_canonical(p_rules);
    RETURN;
  END IF;

  FOREACH v_pool IN ARRAY ARRAY['domestic', 'international'] LOOP
    CONTINUE WHEN NOT (p_rules ? v_pool) OR jsonb_typeof(p_rules->v_pool) = 'null';
    IF jsonb_typeof(p_rules->v_pool) <> 'array' THEN
      RAISE EXCEPTION 'Ranking rules: the % pool must be a list of buckets', v_pool;
    END IF;

    FOR v_bucket, v_idx IN
      SELECT value, ordinality::INT FROM jsonb_array_elements(p_rules->v_pool) WITH ORDINALITY
    LOOP
      IF jsonb_typeof(v_bucket->'types') IS DISTINCT FROM 'array'
         OR jsonb_array_length(v_bucket->'types') = 0 THEN
        RAISE EXCEPTION 'Ranking rules: bucket % of the % pool names no types', v_idx, v_pool;
      END IF;

      FOR v_type IN SELECT jsonb_array_elements_text(v_bucket->'types') LOOP
        IF NOT (v_type = ANY (enum_range(NULL::enum_tournament_type)::TEXT[])) THEN
          RAISE EXCEPTION 'Ranking rules: unknown tournament type % in bucket % of the % pool',
            v_type, v_idx, v_pool;
        END IF;
        IF NOT ((c_pool_types->v_pool) ? v_type) THEN
          RAISE EXCEPTION 'Ranking rules: % is not allowed in the % pool (bucket %)',
            v_type, v_pool, v_idx;
        END IF;
        IF v_type = ANY (v_seen) THEN
          RAISE EXCEPTION 'Ranking rules: % appears in more than one bucket, so one score would count twice',
            v_type;
        END IF;
        v_seen := v_seen || v_type;
      END LOOP;

      v_has_best   := COALESCE(jsonb_typeof(v_bucket->'best') <> 'null', FALSE);
      v_has_always := COALESCE(jsonb_typeof(v_bucket->'always') = 'boolean'
                               AND (v_bucket->>'always')::BOOLEAN, FALSE);
      IF v_has_best = v_has_always THEN
        RAISE EXCEPTION 'Ranking rules: bucket % of the % pool must declare exactly one of best or always',
          v_idx, v_pool;
      END IF;
      IF v_has_best AND NOT (
           jsonb_typeof(v_bucket->'best') = 'number'
           AND (v_bucket->>'best')::NUMERIC >= 1
           AND (v_bucket->>'best')::NUMERIC = trunc((v_bucket->>'best')::NUMERIC)
         ) THEN
        RAISE EXCEPTION 'Ranking rules: bucket % of the % pool has best %, it must be a whole number of at least 1',
          v_idx, v_pool, v_bucket->>'best';
      END IF;
    END LOOP;
  END LOOP;
END;
$$;

COMMENT ON FUNCTION fn_validate_ranking_rules_write(JSONB) IS
  'Refuses two-pool ranking rules the ranking cannot use as written: a type '
  'outside its pool, a type in two buckets, a bucket without exactly one of '
  'best >= 1 or always. Called by fn_import_scoring_config only when the rules '
  'change. Internal: no anon/authenticated grant.';

REVOKE EXECUTE ON FUNCTION fn_validate_ranking_rules_write(JSONB) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION fn_import_scoring_config(p_config JSONB)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_season INT := (p_config->>'id_season')::INT;
  v_locked BOOLEAN;
  v_current tbl_scoring_config%ROWTYPE;
  v_new_engine_id INT;

  v_mp_value   INT;
  v_pg NUMERIC; v_ps NUMERIC; v_pb NUMERIC;
  v_ppw NUMERIC; v_mpw NUMERIC; v_pew NUMERIC; v_mew NUMERIC;
  v_msw NUMERIC; v_psw NUMERIC; v_pps NUMERIC; v_mps NUMERIC;
  v_min_evf INT; v_min_ppw INT;
  v_rules JSONB;
  v_mode  enum_ranking_mode;
  v_type      TEXT;
  v_type_code TEXT;
BEGIN
  IF v_season IS NULL THEN
    RAISE EXCEPTION 'id_season is required in the config JSON';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM tbl_season WHERE id_season = v_season) THEN
    RAISE EXCEPTION 'Season % does not exist', v_season;
  END IF;

  SELECT ts_scoring_locked_at IS NOT NULL INTO v_locked
    FROM tbl_season WHERE id_season = v_season;

  SELECT * INTO v_current FROM tbl_scoring_config WHERE id_season = v_season;

  IF v_locked AND v_current.id_config IS NOT NULL THEN
    v_mp_value := COALESCE((p_config->>'mp_value')::INT,            v_current.int_mp_value);
    v_pg       := COALESCE((p_config->>'podium_gold')::NUMERIC,     v_current.int_podium_gold);
    v_ps       := COALESCE((p_config->>'podium_silver')::NUMERIC,   v_current.int_podium_silver);
    v_pb       := COALESCE((p_config->>'podium_bronze')::NUMERIC,   v_current.int_podium_bronze);
    v_ppw      := COALESCE((p_config->>'ppw_multiplier')::NUMERIC,  v_current.num_ppw_multiplier);
    v_mpw      := COALESCE((p_config->>'mpw_multiplier')::NUMERIC,  v_current.num_mpw_multiplier);
    v_pew      := COALESCE((p_config->>'pew_multiplier')::NUMERIC,  v_current.num_pew_multiplier);
    v_mew      := COALESCE((p_config->>'mew_multiplier')::NUMERIC,  v_current.num_mew_multiplier);
    v_msw      := COALESCE((p_config->>'msw_multiplier')::NUMERIC,  v_current.num_msw_multiplier);
    v_psw      := COALESCE((p_config->>'psw_multiplier')::NUMERIC,  v_current.num_psw_multiplier);
    v_pps      := COALESCE((p_config->>'pps_multiplier')::NUMERIC,  v_current.num_pps_multiplier);
    v_mps      := COALESCE((p_config->>'mps_multiplier')::NUMERIC,  v_current.num_mps_multiplier);
    v_min_evf  := COALESCE((p_config->>'min_participants_evf')::INT, v_current.int_min_participants_evf);
    v_min_ppw  := COALESCE((p_config->>'min_participants_ppw')::INT, v_current.int_min_participants_ppw);
    v_rules    := COALESCE(NULLIF(p_config->'ranking_rules', 'null'::jsonb), v_current.json_ranking_rules);
    v_mode     := COALESCE((p_config->>'default_ranking_mode')::enum_ranking_mode, v_current.enum_default_ranking_mode);

    IF v_mp_value  IS DISTINCT FROM v_current.int_mp_value THEN PERFORM fn_raise_scoring_locked(v_season, 'mp_value'); END IF;
    IF v_pg::INT   IS DISTINCT FROM v_current.int_podium_gold THEN PERFORM fn_raise_scoring_locked(v_season, 'podium_gold'); END IF;
    IF v_ps::INT   IS DISTINCT FROM v_current.int_podium_silver THEN PERFORM fn_raise_scoring_locked(v_season, 'podium_silver'); END IF;
    IF v_pb::INT   IS DISTINCT FROM v_current.int_podium_bronze THEN PERFORM fn_raise_scoring_locked(v_season, 'podium_bronze'); END IF;
    IF v_ppw       IS DISTINCT FROM v_current.num_ppw_multiplier THEN PERFORM fn_raise_scoring_locked(v_season, 'ppw_multiplier'); END IF;
    IF v_mpw       IS DISTINCT FROM v_current.num_mpw_multiplier THEN PERFORM fn_raise_scoring_locked(v_season, 'mpw_multiplier'); END IF;
    IF v_pew       IS DISTINCT FROM v_current.num_pew_multiplier THEN PERFORM fn_raise_scoring_locked(v_season, 'pew_multiplier'); END IF;
    IF v_mew       IS DISTINCT FROM v_current.num_mew_multiplier THEN PERFORM fn_raise_scoring_locked(v_season, 'mew_multiplier'); END IF;
    IF v_msw       IS DISTINCT FROM v_current.num_msw_multiplier THEN PERFORM fn_raise_scoring_locked(v_season, 'msw_multiplier'); END IF;
    IF v_psw       IS DISTINCT FROM v_current.num_psw_multiplier THEN PERFORM fn_raise_scoring_locked(v_season, 'psw_multiplier'); END IF;
    IF v_pps       IS DISTINCT FROM v_current.num_pps_multiplier THEN PERFORM fn_raise_scoring_locked(v_season, 'pps_multiplier'); END IF;
    IF v_mps       IS DISTINCT FROM v_current.num_mps_multiplier THEN PERFORM fn_raise_scoring_locked(v_season, 'mps_multiplier'); END IF;
    IF v_min_evf   IS DISTINCT FROM v_current.int_min_participants_evf THEN PERFORM fn_raise_scoring_locked(v_season, 'min_participants_evf'); END IF;
    IF v_min_ppw   IS DISTINCT FROM v_current.int_min_participants_ppw THEN PERFORM fn_raise_scoring_locked(v_season, 'min_participants_ppw'); END IF;
    IF v_rules     IS DISTINCT FROM v_current.json_ranking_rules THEN PERFORM fn_raise_scoring_locked(v_season, 'ranking_rules'); END IF;
    IF v_mode      IS DISTINCT FROM v_current.enum_default_ranking_mode THEN PERFORM fn_raise_scoring_locked(v_season, 'default_ranking_mode'); END IF;
  END IF;

  IF p_config->>'engine_code' IS NOT NULL THEN
    SELECT id_engine INTO v_new_engine_id
      FROM tbl_scoring_engine WHERE txt_code = p_config->>'engine_code';
    IF v_new_engine_id IS NULL THEN
      RAISE EXCEPTION 'Unknown scoring engine: %', p_config->>'engine_code';
    END IF;
    IF v_locked THEN
      IF v_new_engine_id IS DISTINCT FROM (SELECT id_scoring_engine FROM tbl_season WHERE id_season = v_season) THEN
        PERFORM fn_raise_scoring_locked(v_season, 'engine_code');
      END IF;
    END IF;
  END IF;

  -- ADR-103 §2: a type's engine is a governed field. Compared against the
  -- resolved engine, so an unchanged resend of a locked season passes.
  IF jsonb_typeof(p_config->'type_engines') = 'object' THEN
    FOR v_type, v_type_code IN
      SELECT key, value FROM jsonb_each_text(p_config->'type_engines')
    LOOP
      IF NOT EXISTS (SELECT 1 FROM tbl_scoring_engine WHERE txt_code = v_type_code) THEN
        RAISE EXCEPTION 'Unknown scoring engine: %', v_type_code;
      END IF;
      IF v_locked AND v_type_code IS DISTINCT FROM fn_get_type_engine(v_season, v_type) THEN
        PERFORM fn_raise_scoring_locked(v_season, 'type_engines');
      END IF;
    END LOOP;
  END IF;

  -- ADM27: rules an admin changes must be rules the ranking can use. An
  -- unchanged resend passes, so a season whose older two-pool rules repeat the
  -- domestic buckets internationally (2024/25, 2025/26) stays re-savable.
  IF NULLIF(p_config->'ranking_rules', 'null'::JSONB) IS NOT NULL
     AND (p_config->'ranking_rules') IS DISTINCT FROM v_current.json_ranking_rules THEN
    PERFORM fn_validate_ranking_rules_write(p_config->'ranking_rules');
  END IF;

  PERFORM fn_apply_scoring_config_write(p_config);
END;
$$;


DROP FUNCTION IF EXISTS _fn_create_skeleton_children(INTEGER, TEXT, enum_tournament_type);
