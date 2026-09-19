-- =============================================================================
-- fn_ranking_full -- the generalized ranking RPC (design step 4, second half)
-- =============================================================================
-- doc/plans/ranking-schema-v2-2026-09-19.html §06/§07. Closes SS26.RANK.01-12.
-- Depends on 20260919000007 only for enum_default_ranking_mode being present
-- in the export shape used by fixtures -- no functional dependency.
--
-- WHAT THIS MIGRATION DOES.
--
-- fn_ranking_rules_canonical(v_rules JSONB) reads EITHER JSON shape --
-- schema v1 (domestic/international, or the pure-NULL legacy season) or
-- schema v2 (season_scoring_rules/display_groups/views) -- and returns one
-- row per bucket: (section, grp, types, best, always_include, bucket_idx).
-- It validates as it goes (unknown type, both/neither best-or-always,
-- non-positive best, conflicting display-group assignment, double-counted
-- type within one view) and RAISEs on any violation before returning
-- anything, since a PL/pgSQL set-returning function's tuplestore is only
-- handed to the caller once the function completes without error.
--
-- fn_ranking_full(p_weapon, p_gender, p_category, p_season, p_rolling) is a
-- thin dispatcher on the season's carry-over engine, following the EXACT
-- ADR-042/045 pattern fn_ranking_ppw/fn_ranking_kadra/fn_fencer_scores_
-- rolling already use three times over: a static CASE resolving to
-- fn_ranking_full_event_code_matching or fn_ranking_full_event_fk_matching,
-- ELSE RAISE EXCEPTION 'Unknown carryover engine'. Each body generalizes the
-- existing bucket_results/selected/totals pattern those functions' own
-- JSONB paths already use -- the only change is that group membership comes
-- from fn_ranking_rules_canonical's data instead of a hardcoded
-- ARRAY['PEW','MEW','MSW','PSW'] membership test.
--
-- NEITHER fn_ranking_ppw, fn_ranking_kadra, fn_fencer_scores_rolling, NOR
-- ANY of their four _event_code_matching/_event_fk_matching bodies IS
-- TOUCHED BY THIS MIGRATION. They keep serving the live frontend exactly as
-- today, against whichever season's json_ranking_rules they are pointed at
-- (still schema v1 for the real SPWS-2026-2027 -- see 20260919000007's own
-- header and plan §03).
--
-- THE "INTERNATIONAL IS A SUPERSET" DISCOVERY.
--
-- Verified against the real stored json_ranking_rules for SPWS-2024/2025
-- through 2026/2027 while writing this migration: schema v1's "international"
-- array is NOT international-only. It duplicates "domestic"'s own PPW/MPW
-- buckets verbatim, alongside the genuinely-international one --
-- fn_ranking_kadra's JSONB path reads "international" ALONE and splits its
-- own ppw_total/pew_total afterward by ARRAY['PEW','MEW','MSW','PSW']
-- membership, which only produces the right ppw_total because "international"
-- already carries the domestic buckets too. The canonical legacy adapter
-- below therefore drops any "international" bucket whose types are already
-- wholly covered by "domestic" before emitting it as an evf_fie-section
-- bucket, or evf_plus_total would double-count PPW/MPW. SS26.RANK.11 pins
-- this by comparing fn_ranking_full directly against fn_ranking_ppw and
-- fn_ranking_kadra on one shared fixture built with exactly this real-world
-- shape, rather than trusting a hand-derived expected number.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- fn_ranking_rules_canonical -- internal helper. No grant to anon/authenticated
-- (ADR-083's default-revoke applies untouched); called only from the two
-- SECURITY DEFINER bodies below, which therefore reach it as their owner.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_ranking_rules_canonical(v_rules JSONB)
RETURNS TABLE (
  section        TEXT,
  grp            TEXT,
  types          TEXT[],
  best           INT,
  always_include BOOLEAN,
  bucket_idx     INT
)
LANGUAGE plpgsql
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_schema_version INT;
  v_domestic_types JSONB;
  v_sections       JSONB;
  v_display_groups JSONB;
  v_views          JSONB;
  v_key            TEXT;
  v_dg_key         TEXT;
  v_view_key       TEXT;
  v_view_groups    JSONB;
  v_seen_types     JSONB;
  v_section_obj    JSONB;
  v_section_group  TEXT;
  v_matched_group  TEXT;
  v_bucket         JSONB;
  v_idx            INT;
  v_type           TEXT;
BEGIN
  v_schema_version := NULLIF(v_rules ->> 'schema_version', '')::INT;

  IF v_rules IS NULL OR v_schema_version IS NULL THEN
    -- -------------------------------------------------------------------
    -- Legacy adapter: schema v1 (or the pure-NULL legacy season). "domestic"
    -- becomes section spws/group spws verbatim. "international" becomes
    -- section evf_fie/group evf_plus, EXCLUDING any bucket whose types are
    -- already wholly covered by "domestic" -- see this file's header.
    -- -------------------------------------------------------------------
    v_domestic_types := (
      SELECT COALESCE(jsonb_agg(DISTINCT t), '[]'::JSONB)
        FROM jsonb_array_elements(COALESCE(v_rules -> 'domestic', '[]'::JSONB)) AS b(value)
             CROSS JOIN LATERAL jsonb_array_elements_text(b.value -> 'types') AS t
    );

    FOR v_bucket, v_idx IN
      SELECT b.value, b.ordinality::INT
        FROM jsonb_array_elements(COALESCE(v_rules -> 'domestic', '[]'::JSONB))
             WITH ORDINALITY AS b(value, ordinality)
    LOOP
      IF (v_bucket ? 'best') = (v_bucket ? 'always') THEN
        RAISE EXCEPTION 'Ranking bucket must declare exactly one of best or always';
      END IF;
      IF (v_bucket ? 'best') AND (v_bucket->>'best')::INT <= 0 THEN
        RAISE EXCEPTION 'Ranking bucket best must be positive, got %', v_bucket->>'best';
      END IF;
      FOR v_type IN SELECT jsonb_array_elements_text(v_bucket -> 'types') LOOP
        IF NOT EXISTS (SELECT 1 FROM unnest(enum_range(NULL::enum_tournament_type)) t WHERE t::TEXT = v_type) THEN
          RAISE EXCEPTION 'Unknown tournament type in ranking rules: %', v_type;
        END IF;
      END LOOP;
      RETURN QUERY SELECT 'spws'::TEXT, 'spws'::TEXT,
        ARRAY(SELECT jsonb_array_elements_text(v_bucket -> 'types')),
        (v_bucket->>'best')::INT, (v_bucket->>'always')::BOOLEAN, v_idx;
    END LOOP;

    FOR v_bucket, v_idx IN
      SELECT b.value, b.ordinality::INT
        FROM jsonb_array_elements(COALESCE(v_rules -> 'international', '[]'::JSONB))
             WITH ORDINALITY AS b(value, ordinality)
    LOOP
      IF NOT EXISTS (
        SELECT 1 FROM jsonb_array_elements_text(v_bucket -> 'types') t
         WHERE NOT (v_domestic_types ? t)
      ) THEN
        CONTINUE; -- every type in this bucket is already a domestic duplicate
      END IF;
      IF (v_bucket ? 'best') = (v_bucket ? 'always') THEN
        RAISE EXCEPTION 'Ranking bucket must declare exactly one of best or always';
      END IF;
      IF (v_bucket ? 'best') AND (v_bucket->>'best')::INT <= 0 THEN
        RAISE EXCEPTION 'Ranking bucket best must be positive, got %', v_bucket->>'best';
      END IF;
      FOR v_type IN SELECT jsonb_array_elements_text(v_bucket -> 'types') LOOP
        IF NOT EXISTS (SELECT 1 FROM unnest(enum_range(NULL::enum_tournament_type)) t WHERE t::TEXT = v_type) THEN
          RAISE EXCEPTION 'Unknown tournament type in ranking rules: %', v_type;
        END IF;
      END LOOP;
      RETURN QUERY SELECT 'evf_fie'::TEXT, 'evf_plus'::TEXT,
        ARRAY(SELECT jsonb_array_elements_text(v_bucket -> 'types')),
        (v_bucket->>'best')::INT, (v_bucket->>'always')::BOOLEAN, v_idx;
    END LOOP;

    RETURN;
  END IF;

  IF v_schema_version <> 2 THEN
    RAISE EXCEPTION 'Unsupported ranking rules schema_version: %', v_schema_version;
  END IF;

  v_sections       := v_rules -> 'season_scoring_rules';
  v_display_groups := v_rules -> 'display_groups';
  v_views          := v_rules -> 'views';

  -- Section <-> display-group agreement: a section's own "group" field must
  -- match the (exactly one) display_groups entry that lists it.
  FOR v_key IN SELECT jsonb_object_keys(v_sections) LOOP
    v_section_obj   := v_sections -> v_key;
    v_section_group := v_section_obj ->> 'group';
    v_matched_group := NULL;

    FOR v_dg_key IN SELECT jsonb_object_keys(v_display_groups) LOOP
      IF (v_display_groups -> v_dg_key -> 'sections') @> to_jsonb(v_key) THEN
        IF v_matched_group IS NOT NULL THEN
          RAISE EXCEPTION 'Ranking section % is assigned to conflicting display groups', v_key;
        END IF;
        v_matched_group := v_dg_key;
      END IF;
    END LOOP;

    IF v_matched_group IS NULL OR v_matched_group <> v_section_group THEN
      RAISE EXCEPTION 'Ranking section % is assigned to conflicting display groups', v_key;
    END IF;
  END LOOP;

  -- Double-count guard: within any one view, no tournament type may be
  -- reachable through two different sections.
  FOR v_view_key IN SELECT jsonb_object_keys(v_views) LOOP
    v_view_groups := v_views -> v_view_key;
    v_seen_types := '{}'::JSONB;

    FOR v_dg_key IN SELECT jsonb_array_elements_text(v_view_groups) LOOP
      FOR v_key IN SELECT jsonb_array_elements_text(v_display_groups -> v_dg_key -> 'sections') LOOP
        FOR v_type IN SELECT jsonb_array_elements_text(v_sections -> v_key -> 'types') LOOP
          IF v_seen_types ? v_type THEN
            RAISE EXCEPTION 'Tournament type % is double-counted within view %', v_type, v_view_key;
          END IF;
          v_seen_types := v_seen_types || jsonb_build_object(v_type, TRUE);
        END LOOP;
      END LOOP;
    END LOOP;
  END LOOP;

  -- Per-bucket validation and emission.
  FOR v_key IN SELECT jsonb_object_keys(v_sections) LOOP
    v_section_obj   := v_sections -> v_key;
    v_section_group := v_section_obj ->> 'group';

    FOR v_bucket, v_idx IN
      SELECT b.value, b.ordinality::INT
        FROM jsonb_array_elements(COALESCE(v_section_obj -> 'buckets', '[]'::JSONB))
             WITH ORDINALITY AS b(value, ordinality)
    LOOP
      IF (v_bucket ? 'best') = (v_bucket ? 'always') THEN
        RAISE EXCEPTION 'Ranking bucket must declare exactly one of best or always';
      END IF;
      IF (v_bucket ? 'best') AND (v_bucket->>'best')::INT <= 0 THEN
        RAISE EXCEPTION 'Ranking bucket best must be positive, got %', v_bucket->>'best';
      END IF;
      FOR v_type IN SELECT jsonb_array_elements_text(v_bucket -> 'types') LOOP
        IF NOT EXISTS (SELECT 1 FROM unnest(enum_range(NULL::enum_tournament_type)) t WHERE t::TEXT = v_type) THEN
          RAISE EXCEPTION 'Unknown tournament type in ranking rules: %', v_type;
        END IF;
      END LOOP;
      RETURN QUERY SELECT v_key, v_section_group,
        ARRAY(SELECT jsonb_array_elements_text(v_bucket -> 'types')),
        (v_bucket->>'best')::INT, (v_bucket->>'always')::BOOLEAN, v_idx;
    END LOOP;
  END LOOP;

  RETURN;
END;
$$;

COMMENT ON FUNCTION fn_ranking_rules_canonical(JSONB) IS
  'Reads EITHER json_ranking_rules shape (schema v1 domestic/international, '
  'or schema v2 season_scoring_rules/display_groups/views) and returns one '
  'row per bucket: section, display group, types, best/always, bucket '
  'index. Validates as it goes and RAISEs before returning anything on any '
  'violation. Internal helper -- no anon/authenticated grant.';

-- Postgres grants a brand-new function EXECUTE=PUBLIC on CREATE regardless of
-- ADR-083's Block 6 (that default-privilege change only removed a stale
-- custom default-ACL entry for anon/authenticated specifically; it never
-- touched the standard implicit PUBLIC grant). Verified live: a first
-- version of this migration without this line left fn_ranking_rules_canonical
-- anon-executable, caught by 52.7 rather than assumed away -- exactly why
-- every other new internal helper in 20260919000005/6
-- (fn_raise_scoring_locked, fn_guard_scoring_config_write,
-- fn_backfill_scoring_lock, fn_apply_scoring_config_write) carries this same
-- explicit REVOKE.
REVOKE EXECUTE ON FUNCTION fn_ranking_rules_canonical(JSONB) FROM PUBLIC, anon, authenticated;

-- -----------------------------------------------------------------------------
-- fn_ranking_full_event_code_matching -- EVENT_CODE_MATCHING carry-over
-- engine body. Generalizes fn_ranking_kadra_event_code_matching's own JSONB
-- path (current_eligible/carried_eligible/bucket_results/selected/totals)
-- from two hardcoded groups to N groups sourced from fn_ranking_rules_
-- canonical. PPS/MPS are explicitly excluded from carried_eligible
-- regardless of section membership -- design §07: "future PPS/MPS
-- carry-over... begins disabled" (SS26.RANK.12).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_ranking_full_event_code_matching(
  p_weapon   enum_weapon_type,
  p_gender   enum_gender_type,
  p_category enum_age_category,
  p_season   INT DEFAULT NULL,
  p_rolling  BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
  rank               INT,
  id_fencer          INT,
  fencer_name        TEXT,
  spws_total         NUMERIC,
  evf_plus_total     NUMERIC,
  total_score        NUMERIC,
  bool_has_carryover BOOLEAN
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_season_id      INT;
  v_rules          JSONB;
  v_prev_season_id INT;
  v_season_end_yr  INT;
BEGIN
  v_season_id := COALESCE(
    p_season,
    (SELECT s.id_season FROM tbl_season s WHERE s.bool_active LIMIT 1)
  );

  SELECT sc.json_ranking_rules INTO v_rules
    FROM tbl_scoring_config sc WHERE sc.id_season = v_season_id;

  SELECT EXTRACT(YEAR FROM s.dt_end)::INT INTO v_season_end_yr
    FROM tbl_season s WHERE s.id_season = v_season_id;

  IF p_rolling THEN
    SELECT s.id_season INTO v_prev_season_id
      FROM tbl_season s
     WHERE s.dt_end < (SELECT s2.dt_start FROM tbl_season s2 WHERE s2.id_season = v_season_id)
     ORDER BY s.dt_end DESC
     LIMIT 1;
  END IF;

  RETURN QUERY
  WITH
    raw_buckets AS (
      SELECT section, grp, types, best, always_include, bucket_idx
        FROM fn_ranking_rules_canonical(v_rules)
    ),
    rules_types AS (
      SELECT DISTINCT unnest(types) AS type_code FROM raw_buckets
    ),
    completed_positions AS (
      SELECT DISTINCT fn_event_position(ev.txt_code) AS pos
      FROM tbl_event ev
      JOIN tbl_tournament t ON t.id_event = ev.id_event
      JOIN tbl_result r ON r.id_tournament = t.id_tournament
     WHERE ev.id_season = v_season_id
       AND t.enum_weapon = p_weapon
       AND t.enum_gender = p_gender
       AND r.num_final_score IS NOT NULL
    ),
    current_eligible AS (
      SELECT
        r.id_fencer            AS fid,
        r.num_final_score      AS score,
        t.enum_type::TEXT      AS type_code,
        FALSE                  AS is_carried
      FROM tbl_result r
      JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
      JOIN tbl_event e      ON e.id_event = t.id_event
      JOIN tbl_fencer f     ON f.id_fencer = r.id_fencer
      JOIN tbl_season s     ON s.id_season = e.id_season
      WHERE e.id_season = v_season_id
        AND t.enum_weapon = p_weapon
        AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender
        AND COALESCE(
          fn_age_category(f.int_birth_year, EXTRACT(YEAR FROM s.dt_end)::INT),
          t.enum_age_category
        ) = p_category
        AND r.num_final_score IS NOT NULL
        AND r.id_fencer IS NOT NULL
    ),
    carried_eligible AS (
      SELECT
        r.id_fencer            AS fid,
        r.num_final_score      AS score,
        t.enum_type::TEXT      AS type_code,
        TRUE                   AS is_carried
      FROM tbl_result r
      JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
      JOIN tbl_event e      ON e.id_event = t.id_event
      JOIN tbl_fencer f     ON f.id_fencer = r.id_fencer
      WHERE p_rolling
        AND v_prev_season_id IS NOT NULL
        AND e.id_season = v_prev_season_id
        AND t.enum_weapon = p_weapon
        AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender
        AND COALESCE(fn_age_category(f.int_birth_year, v_season_end_yr), t.enum_age_category) = p_category
        AND r.num_final_score IS NOT NULL
        AND r.id_fencer IS NOT NULL
        AND t.enum_type::TEXT IN (SELECT type_code FROM rules_types)
        AND t.enum_type::TEXT NOT IN ('PPS', 'MPS')  -- SS26.RANK.12: begins disabled
        AND fn_event_position(e.txt_code) NOT IN (SELECT pos FROM completed_positions)
    ),
    eligible AS (
      SELECT fid, score, type_code, is_carried FROM current_eligible
      UNION ALL
      SELECT fid, score, type_code, is_carried FROM carried_eligible
    ),
    bucket_results AS (
      SELECT
        e.fid, e.score, e.is_carried,
        b.grp, b.section, b.bucket_idx, b.best, b.always_include,
        ROW_NUMBER() OVER (
          PARTITION BY b.section, b.bucket_idx, e.fid ORDER BY e.score DESC
        ) AS rn
      FROM eligible e CROSS JOIN raw_buckets b
      WHERE e.type_code = ANY(b.types)
    ),
    selected AS (
      SELECT fid, score, grp, is_carried
      FROM bucket_results
      WHERE COALESCE(always_include, FALSE) OR rn <= best
    ),
    all_fencers AS (
      SELECT DISTINCT fid FROM eligible
    ),
    totals AS (
      SELECT
        af.fid,
        COALESCE(SUM(sel.score) FILTER (WHERE sel.grp = 'spws'), 0) AS spws_total,
        COALESCE(SUM(sel.score) FILTER (WHERE sel.grp = 'evf_plus'), 0) AS evf_plus_total,
        BOOL_OR(sel.is_carried) AS has_carry
      FROM all_fencers af
      LEFT JOIN selected sel ON sel.fid = af.fid
      GROUP BY af.fid
    )
  SELECT
    ROW_NUMBER() OVER (ORDER BY (t.spws_total + t.evf_plus_total) DESC)::INT AS rank,
    t.fid AS id_fencer,
    COALESCE(fe.txt_surname || ' ' || fe.txt_first_name, '') AS fencer_name,
    t.spws_total,
    t.evf_plus_total,
    (t.spws_total + t.evf_plus_total) AS total_score,
    COALESCE(t.has_carry, FALSE) AS bool_has_carryover
  FROM totals t
  LEFT JOIN tbl_fencer fe ON fe.id_fencer = t.fid
  WHERE (t.spws_total + t.evf_plus_total) > 0
  ORDER BY (t.spws_total + t.evf_plus_total) DESC;
END;
$$;

COMMENT ON FUNCTION fn_ranking_full_event_code_matching(enum_weapon_type, enum_gender_type, enum_age_category, INT, BOOLEAN) IS
  'Design step 4: generalized full ranking (spws_total/evf_plus_total/total_score) '
  'for the EVENT_CODE_MATCHING carry-over engine. Reads season_scoring_rules '
  'v1 or v2 via fn_ranking_rules_canonical.';

-- -----------------------------------------------------------------------------
-- fn_ranking_full_event_fk_matching -- EVENT_FK_MATCHING carry-over engine
-- body. Generalizes fn_ranking_kadra_event_fk_matching's own JSONB path
-- (vw_eligible_event + bucket_results/selected/totals) the same way.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_ranking_full_event_fk_matching(
  p_weapon   enum_weapon_type,
  p_gender   enum_gender_type,
  p_category enum_age_category,
  p_season   INT DEFAULT NULL,
  p_rolling  BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
  rank               INT,
  id_fencer          INT,
  fencer_name        TEXT,
  spws_total         NUMERIC,
  evf_plus_total     NUMERIC,
  total_score        NUMERIC,
  bool_has_carryover BOOLEAN
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_season_id     INT;
  v_rules         JSONB;
  v_season_end_yr INT;
BEGIN
  v_season_id := COALESCE(
    p_season,
    (SELECT s.id_season FROM tbl_season s WHERE s.bool_active LIMIT 1)
  );

  SELECT sc.json_ranking_rules INTO v_rules
    FROM tbl_scoring_config sc WHERE sc.id_season = v_season_id;

  SELECT EXTRACT(YEAR FROM dt_end)::INT INTO v_season_end_yr
    FROM tbl_season WHERE id_season = v_season_id;

  RETURN QUERY
  WITH
    raw_buckets AS (
      SELECT section, grp, types, best, always_include, bucket_idx
        FROM fn_ranking_rules_canonical(v_rules)
    ),
    eligible AS (
      SELECT
        r.id_fencer       AS fid,
        r.num_final_score AS score,
        t.enum_type::TEXT AS type_code,
        v.is_carried      AS is_carried
      FROM vw_eligible_event v
      JOIN tbl_tournament t ON t.id_event = v.id_event
      JOIN tbl_result r     ON r.id_tournament = t.id_tournament
      JOIN tbl_fencer f     ON f.id_fencer = r.id_fencer
      WHERE v.effective_season_id = v_season_id
        AND (NOT v.is_carried OR p_rolling)
        AND t.enum_weapon = p_weapon
        AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender
        AND COALESCE(fn_age_category(f.int_birth_year, v_season_end_yr), t.enum_age_category) = p_category
        AND r.num_final_score IS NOT NULL
        AND r.id_fencer IS NOT NULL
        AND (NOT v.is_carried OR t.enum_type::TEXT NOT IN ('PPS', 'MPS'))  -- SS26.RANK.12
    ),
    bucket_results AS (
      SELECT
        e.fid, e.score, e.is_carried,
        b.grp, b.section, b.bucket_idx, b.best, b.always_include,
        ROW_NUMBER() OVER (
          PARTITION BY b.section, b.bucket_idx, e.fid ORDER BY e.score DESC
        ) AS rn
      FROM eligible e CROSS JOIN raw_buckets b
      WHERE e.type_code = ANY(b.types)
    ),
    selected AS (
      SELECT fid, score, grp, is_carried
      FROM bucket_results
      WHERE COALESCE(always_include, FALSE) OR rn <= best
    ),
    all_fencers AS (
      SELECT DISTINCT fid FROM eligible
    ),
    totals AS (
      SELECT
        af.fid,
        COALESCE(SUM(sel.score) FILTER (WHERE sel.grp = 'spws'), 0) AS spws_total,
        COALESCE(SUM(sel.score) FILTER (WHERE sel.grp = 'evf_plus'), 0) AS evf_plus_total,
        BOOL_OR(sel.is_carried) AS has_carry
      FROM all_fencers af
      LEFT JOIN selected sel ON sel.fid = af.fid
      GROUP BY af.fid
    )
  SELECT
    ROW_NUMBER() OVER (ORDER BY (t.spws_total + t.evf_plus_total) DESC)::INT AS rank,
    t.fid AS id_fencer,
    COALESCE(f.txt_surname || ' ' || f.txt_first_name, '') AS fencer_name,
    t.spws_total,
    t.evf_plus_total,
    (t.spws_total + t.evf_plus_total) AS total_score,
    COALESCE(t.has_carry, FALSE) AS bool_has_carryover
  FROM totals t
  LEFT JOIN tbl_fencer f ON f.id_fencer = t.fid
  WHERE (t.spws_total + t.evf_plus_total) > 0
  ORDER BY (t.spws_total + t.evf_plus_total) DESC;
END;
$$;

COMMENT ON FUNCTION fn_ranking_full_event_fk_matching(enum_weapon_type, enum_gender_type, enum_age_category, INT, BOOLEAN) IS
  'Design step 4: generalized full ranking (spws_total/evf_plus_total/total_score) '
  'for the EVENT_FK_MATCHING carry-over engine. Reads season_scoring_rules '
  'v1 or v2 via fn_ranking_rules_canonical.';

-- -----------------------------------------------------------------------------
-- fn_ranking_full -- thin dispatcher, ADR-042/045 pattern (fourth instance
-- in this codebase after fn_ranking_ppw/fn_ranking_kadra/fn_fencer_scores_
-- rolling).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_ranking_full(
  p_weapon   enum_weapon_type,
  p_gender   enum_gender_type,
  p_category enum_age_category,
  p_season   INT DEFAULT NULL,
  p_rolling  BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
  rank               INT,
  id_fencer          INT,
  fencer_name        TEXT,
  spws_total         NUMERIC,
  evf_plus_total     NUMERIC,
  total_score        NUMERIC,
  bool_has_carryover BOOLEAN
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_engine          enum_event_carryover_engine;
  v_resolved_season INT;
BEGIN
  v_resolved_season := COALESCE(
    p_season,
    (SELECT s.id_season FROM tbl_season s WHERE s.bool_active LIMIT 1)
  );

  SELECT s.enum_carryover_engine INTO v_engine
    FROM tbl_season s WHERE s.id_season = v_resolved_season;

  CASE v_engine
    WHEN 'EVENT_CODE_MATCHING' THEN
      RETURN QUERY SELECT * FROM fn_ranking_full_event_code_matching(
        p_weapon, p_gender, p_category, p_season, p_rolling
      );
    WHEN 'EVENT_FK_MATCHING' THEN
      RETURN QUERY SELECT * FROM fn_ranking_full_event_fk_matching(
        p_weapon, p_gender, p_category, p_season, p_rolling
      );
    ELSE
      RAISE EXCEPTION 'Unknown carryover engine: % for season %', v_engine, v_resolved_season;
  END CASE;
END;
$$;

COMMENT ON FUNCTION fn_ranking_full(enum_weapon_type, enum_gender_type, enum_age_category, INT, BOOLEAN) IS
  'Design step 4: the generalized public ranking RPC. Returns spws_total, '
  'evf_plus_total and total_score, aggregating Season Scoring Rules (schema '
  'v1 or v2) into exactly two display groups. Not yet called from any UI -- '
  'that wiring is design step 7, together with the SPWS-2026-2027 cutover '
  'to schema v2.';

-- -----------------------------------------------------------------------------
-- Grants -- identical public-read posture to fn_ranking_ppw/fn_ranking_kadra.
-- These three postdate ADR-083's default-revoke, so the grant is explicit,
-- exactly like tbl_scoring_engine's own explicit grant (20260919000005).
-- -----------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION fn_ranking_full(enum_weapon_type, enum_gender_type, enum_age_category, INT, BOOLEAN)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_ranking_full_event_code_matching(enum_weapon_type, enum_gender_type, enum_age_category, INT, BOOLEAN)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_ranking_full_event_fk_matching(enum_weapon_type, enum_gender_type, enum_age_category, INT, BOOLEAN)
  TO anon, authenticated;
