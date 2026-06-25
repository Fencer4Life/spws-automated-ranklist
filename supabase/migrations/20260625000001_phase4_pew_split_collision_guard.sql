-- =============================================================================
-- ADR-046 (amended): collision-resilient PEW weapon splitter
-- =============================================================================
-- fn_split_pew_by_weapon() renames each PEW event to a weapon-letter-suffixed
-- code derived from its children's weapons (Step 2). A malformed EVF placeholder
-- export can make two events resolve to the SAME target code — e.g. the 06-19
-- PROD export carried PEW3s/PEW5s events (real Munich/Stockholm sabre weekends)
-- with empty EPEE/FOIL placeholder child slots, so the splitter derived 'efs'
-- and tried to rename them onto the existing PEW3efs/PEW5ef → `duplicate key
-- value violates unique constraint "idx_event_code"`, which aborted the ENTIRE
-- seed load (run from seed_post_backfill.sql), half-populating the DB and
-- cascading into 14 scoring-test failures.
--
-- This re-defines the function identically EXCEPT for two additions that make it
-- self-healing WITHOUT discarding any results:
--   * Step 1.5 PRUNE — drop child tournaments that have NO results and whose
--     weapon is absent from the event's explicit `[efs]+` code suffix (spurious
--     empty placeholder slots; trust the admin-set code).
--   * Step 2 collision RESOLUTION by provenance — if the weapon-derived target
--     code already belongs to a DIFFERENT event: an EMPTY (0-result) holder is a
--     duplicate and is merged away so this (result-bearing) event takes the code;
--     a RESULT-BEARING holder is a genuine conflict, skipped with a WARNING for
--     operator review. Never deletes a result row.
--
-- Genuinely distinct events are untouched (they derive different codes). See
-- pgTAP test 47_pew_split_collision.sql. The PEW3s/PEW5s data is preserved, not
-- dropped — these are real EVF circuit legs whose results just hadn't all been
-- ingested at export time.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_split_pew_by_weapon()
 RETURNS TABLE(events_split integer, events_renamed integer, tournaments_renamed integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_evt              RECORD;
  v_cluster          RECORD;
  v_split            INT := 0;
  v_renamed          INT := 0;
  v_t_renamed        INT := 0;
  v_letters          TEXT;
  v_new_code         TEXT;
  v_old_kind         TEXT;
  v_new_kind         TEXT;
  v_season_suffix    TEXT;
  v_n                INT;
  v_next_n           INT;
  v_new_event_id     INT;
  v_t                RECORD;
  v_t_new_code       TEXT;
  v_age_part         TEXT;
  v_temp_marker      TEXT;
  v_clash_id         INT;
  v_clash_rows       INT;
BEGIN
  v_temp_marker := '__phase4tmp__';

  -- ============================================================
  -- Step 1: Split bundled events (date span > 3 days = bundled)
  -- ============================================================
  FOR v_evt IN
    SELECT e.id_event, e.txt_code, e.id_season, e.id_organizer,
           e.dt_start, e.dt_end, e.txt_location, e.txt_country,
           s.txt_code AS season_code,
           regexp_replace(e.txt_code, '^(PEW\d+)[efs]*-.*$', '\1') AS pew_prefix,
           ((regexp_match(e.txt_code, '^PEW(\d+)'))[1])::INT AS pew_n
      FROM tbl_event e JOIN tbl_season s ON s.id_season = e.id_season
     WHERE e.txt_code ~ '^PEW\d+[efs]*-'
       AND EXISTS (
         SELECT 1 FROM tbl_tournament t
         WHERE t.id_event = e.id_event
           AND t.dt_tournament IS NOT NULL
       )
     ORDER BY e.id_season, e.txt_code
  LOOP
    -- Detect clusters in child tournament dates: gap >3 days = cluster boundary.
    -- The keep-cluster (kept under original event id) is the LARGEST by row count.
    -- Each other cluster gets a new event with next-free PEW{N}.
    DECLARE
      v_clusters JSONB := '[]'::JSONB;
      v_iter INT;
      v_cluster_count INT;
      v_cluster_min DATE;
      v_cluster_max DATE;
      v_prev_dt DATE := NULL;
      v_curr_dates DATE[] := ARRAY[]::DATE[];
      v_curr_count INT := 0;
      v_dt RECORD;
    BEGIN
      -- Build cluster list ordered by date
      FOR v_dt IN
        SELECT t.dt_tournament AS dt, COUNT(*) AS cnt
          FROM tbl_tournament t
         WHERE t.id_event = v_evt.id_event AND t.dt_tournament IS NOT NULL
         GROUP BY t.dt_tournament
         ORDER BY t.dt_tournament
      LOOP
        IF v_prev_dt IS NULL OR v_dt.dt - v_prev_dt <= 3 THEN
          v_curr_dates := v_curr_dates || v_dt.dt;
          v_curr_count := v_curr_count + v_dt.cnt;
        ELSE
          v_clusters := v_clusters || jsonb_build_object(
            'min', (SELECT MIN(d) FROM unnest(v_curr_dates) AS d),
            'max', (SELECT MAX(d) FROM unnest(v_curr_dates) AS d),
            'count', v_curr_count
          );
          v_curr_dates := ARRAY[v_dt.dt];
          v_curr_count := v_dt.cnt;
        END IF;
        v_prev_dt := v_dt.dt;
      END LOOP;

      IF v_curr_count > 0 THEN
        v_clusters := v_clusters || jsonb_build_object(
          'min', (SELECT MIN(d) FROM unnest(v_curr_dates) AS d),
          'max', (SELECT MAX(d) FROM unnest(v_curr_dates) AS d),
          'count', v_curr_count
        );
      END IF;

      v_cluster_count := jsonb_array_length(v_clusters);

      -- Single cluster → no split, fall through to step 2 rename phase
      IF v_cluster_count <= 1 THEN
        CONTINUE;
      END IF;

      -- Keep the EARLIEST chronological cluster under the original event id.
      -- Reasoning: EVF circuit numbering is chronological — PEW3 = the 3rd
      -- weekend in the season's circuit. The first cluster that originally
      -- got numbered PEW{N} is the canonical one that keeps that number.
      -- Subsequent clusters bundled under the same code are mis-bundled
      -- additions and get next-free numbers.
      v_cluster_min := ((v_clusters -> 0) ->> 'min')::DATE;
      v_cluster_max := ((v_clusters -> 0) ->> 'max')::DATE;
      UPDATE tbl_event
         SET dt_start = v_cluster_min, dt_end = v_cluster_max
       WHERE id_event = v_evt.id_event;

      -- For each subsequent cluster, allocate next PEW{N} and reparent.
      -- Leave txt_location/country NULL on new events — they were misbundled
      -- so the parent's location field doesn't apply; admin must fill in.
      FOR v_iter IN 1..v_cluster_count-1 LOOP
        v_cluster_min := ((v_clusters -> v_iter) ->> 'min')::DATE;
        v_cluster_max := ((v_clusters -> v_iter) ->> 'max')::DATE;

        SELECT COALESCE(MAX(((regexp_match(e.txt_code, '^PEW(\d+)[efs]*-'))[1])::INT), 0) + 1
          INTO v_next_n
          FROM tbl_event e
         WHERE e.id_season = v_evt.id_season
           AND e.txt_code ~ '^PEW\d+[efs]*-';

        v_season_suffix := regexp_replace(v_evt.season_code, '^SPWS-', '');
        v_new_code := 'PEW' || v_next_n::TEXT || '-' || v_season_suffix;

        INSERT INTO tbl_event (
          txt_code, txt_name, id_season, id_organizer,
          dt_start, dt_end, txt_location, txt_country,
          enum_status, id_prior_event
        ) VALUES (
          v_new_code, v_new_code, v_evt.id_season, v_evt.id_organizer,
          v_cluster_min, v_cluster_max, NULL, NULL,
          'COMPLETED', NULL
        ) RETURNING id_event INTO v_new_event_id;

        UPDATE tbl_tournament
           SET id_event = v_new_event_id
         WHERE id_event = v_evt.id_event
           AND dt_tournament BETWEEN v_cluster_min AND v_cluster_max;

        v_split := v_split + 1;
      END LOOP;
    END;
  END LOOP;

  -- ============================================================
  -- Step 1.5: Prune spurious empty placeholder child slots
  -- ============================================================
  -- EVF event import can attach all-weapon×gender child tournaments to an event
  -- that is deliberately coded for a narrower weapon set — e.g. the sabre-only
  -- weekends `PEW3s-2025-2026` (Munich) / `PEW5s-2025-2026` (Stockholm) that
  -- received empty EPEE/FOIL slots. Those 0-result slots (a) make Step 2 derive
  -- a wider suffix (`efs`) that collides with the existing `PEW{N}efs`/`PEW{N}ef`
  -- event, and (b) violate the "child weapon ∈ parent suffix" invariant (test 20
  -- ph4.8). Trust the admin-set code: drop child tournaments that have NO results
  -- AND whose weapon letter is absent from the event's EXPLICIT `[efs]+` suffix.
  -- Only events already carrying a letter suffix are touched — legacy `PEW{N}-`
  -- codes (no letters) fall through to Step 2's derive-from-children behaviour.
  -- Slots that carry results are NEVER dropped: a real weapon/code conflict is
  -- left for the collision guard below + operator review, not silently deleted.
  WITH pruned AS (
    DELETE FROM tbl_tournament t
     USING tbl_event e
     WHERE t.id_event = e.id_event
       AND e.txt_code ~ '^PEW\d+[efs]+-'
       AND position(lower(left(t.enum_weapon::TEXT, 1))
                    IN regexp_replace(e.txt_code, '^PEW\d+([efs]+)-.*$', '\1')) = 0
       AND NOT EXISTS (SELECT 1 FROM tbl_result r WHERE r.id_tournament = t.id_tournament)
    RETURNING 1
  )
  SELECT count(*) INTO v_n FROM pruned;
  IF v_n > 0 THEN
    RAISE NOTICE 'fn_split_pew_by_weapon: pruned % empty placeholder child slot(s) not matching event code suffix', v_n;
  END IF;

  -- ============================================================
  -- Step 2: Apply weapon-letter suffix to every PEW event
  -- ============================================================
  -- Pass 1: rename children with temp marker to avoid uniqueness collisions
  -- Pass 2: rename event with new suffix
  -- Pass 3: rename children to final code
  FOR v_evt IN
    SELECT e.id_event, e.txt_code, e.id_season,
           ((regexp_match(e.txt_code, '^PEW(\d+)'))[1])::INT AS pew_n,
           regexp_replace(e.txt_code, '^PEW\d+[efs]*-', '') AS season_suffix
      FROM tbl_event e
     WHERE e.txt_code ~ '^PEW\d+[efs]*-'
     ORDER BY e.id_season, e.id_event
  LOOP
    -- Determine current weapons present in children
    SELECT fn_pew_weapon_letters(array_agg(DISTINCT t.enum_weapon))
      INTO v_letters
      FROM tbl_tournament t
     WHERE t.id_event = v_evt.id_event;

    -- Skip events with no children (shouldn't happen but defensive)
    IF v_letters IS NULL OR v_letters = '' THEN
      CONTINUE;
    END IF;

    v_new_code := 'PEW' || v_evt.pew_n::TEXT || v_letters || '-' || v_evt.season_suffix;

    -- Skip if already correctly suffixed (idempotent)
    IF v_evt.txt_code = v_new_code THEN
      CONTINUE;
    END IF;

    -- ADR-046 (amended 2026-06-25): collision resolution by provenance. The
    -- weapon-derived target code may already belong to a DIFFERENT event. Rather
    -- than abort the whole seed load on idx_event_code, resolve by who holds real
    -- results:
    --   * target held by an EMPTY (0-result) placeholder → it is a spurious
    --     duplicate of THIS event (same circuit number + weapon set + season);
    --     delete it and proceed, so this (result-bearing) event takes the clean
    --     code. Never discards results — only empty duplicate placeholders.
    --   * target held by a RESULT-BEARING event → genuine conflict; skip this
    --     rename with a WARNING for operator review (no silent data change).
    -- Genuinely distinct events are untouched: they derive different codes and
    -- never collide (e.g. PEW3s Munich vs PEW3efs Guildford).
    SELECT x.id_event INTO v_clash_id
      FROM tbl_event x
     WHERE x.txt_code = v_new_code AND x.id_event <> v_evt.id_event
     LIMIT 1;
    IF v_clash_id IS NOT NULL THEN
      SELECT count(*) INTO v_clash_rows
        FROM tbl_result r
        JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
       WHERE t.id_event = v_clash_id;
      IF v_clash_rows = 0 THEN
        DELETE FROM tbl_tournament WHERE id_event = v_clash_id;
        DELETE FROM tbl_event      WHERE id_event = v_clash_id;
        RAISE NOTICE 'fn_split_pew_by_weapon: merged empty duplicate event % into % (code %)',
          v_clash_id, v_evt.id_event, v_new_code;
      ELSE
        RAISE WARNING 'fn_split_pew_by_weapon: target code % held by result-bearing event %; skipping rename of % (event %)',
          v_new_code, v_clash_id, v_evt.txt_code, v_evt.id_event;
        CONTINUE;
      END IF;
    END IF;

    -- Rename children to temp codes first to avoid uniqueness conflicts
    UPDATE tbl_tournament
       SET txt_code = v_temp_marker || id_tournament::TEXT
     WHERE id_event = v_evt.id_event;

    -- Rename event
    UPDATE tbl_event SET txt_code = v_new_code WHERE id_event = v_evt.id_event;
    v_renamed := v_renamed + 1;

    -- Rebuild child codes from new parent + enum fields
    -- PEW children pattern: {parent_kind}-V{age_n}-{gender}-{weapon}-{season}
    FOR v_t IN
      SELECT id_tournament, enum_weapon, enum_gender, enum_age_category
        FROM tbl_tournament WHERE id_event = v_evt.id_event
    LOOP
      v_age_part := v_t.enum_age_category::TEXT;
      v_t_new_code := 'PEW' || v_evt.pew_n::TEXT || v_letters
                      || '-' || v_age_part
                      || '-' || v_t.enum_gender::TEXT
                      || '-' || v_t.enum_weapon::TEXT
                      || '-' || v_evt.season_suffix;
      UPDATE tbl_tournament
         SET txt_code = v_t_new_code
       WHERE id_tournament = v_t.id_tournament;
      v_t_renamed := v_t_renamed + 1;
    END LOOP;
  END LOOP;

  events_split := v_split;
  events_renamed := v_renamed;
  tournaments_renamed := v_t_renamed;
  RETURN NEXT;
END;
$function$;

REVOKE EXECUTE ON FUNCTION fn_split_pew_by_weapon() FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_split_pew_by_weapon() TO authenticated;
