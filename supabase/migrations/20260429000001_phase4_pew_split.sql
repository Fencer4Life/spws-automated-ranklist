-- =============================================================================
-- Phase 4 (ADR-046) — PEW per-weapon-suffix codes + splitter for bundled events
-- =============================================================================
-- Reshapes EVF circuit codes from `PEW{N}-{season}` to `PEW{N}{letters}-{season}`
-- where letters ∈ {e,f,s}+ alphabetical, listing weapons actually hosted.
--
-- Splits each bundled PEW event (multiple physical weekends under one txt_code)
-- by date-cluster (gap > 3 days = cluster boundary). The largest cluster keeps
-- the original id_event; secondary clusters get next-free PEW{N} codes.
--
-- Idempotent: a re-run is safe and is a no-op when the child weapon set hasn't
-- changed since last run.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Helper: build alphabetical weapon-letter suffix from an array of weapon enums
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_pew_weapon_letters(p_weapons enum_weapon_type[])
RETURNS TEXT
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE
  v_has_e BOOLEAN := FALSE;
  v_has_f BOOLEAN := FALSE;
  v_has_s BOOLEAN := FALSE;
  v_w     enum_weapon_type;
  v_out   TEXT := '';
BEGIN
  IF p_weapons IS NULL THEN
    RETURN '';
  END IF;
  FOREACH v_w IN ARRAY p_weapons LOOP
    IF v_w = 'EPEE'  THEN v_has_e := TRUE; END IF;
    IF v_w = 'FOIL'  THEN v_has_f := TRUE; END IF;
    IF v_w = 'SABRE' THEN v_has_s := TRUE; END IF;
  END LOOP;
  IF v_has_e THEN v_out := v_out || 'e'; END IF;
  IF v_has_f THEN v_out := v_out || 'f'; END IF;
  IF v_has_s THEN v_out := v_out || 's'; END IF;
  RETURN v_out;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_pew_weapon_letters(enum_weapon_type[]) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_pew_weapon_letters(enum_weapon_type[]) TO authenticated;


-- -----------------------------------------------------------------------------
-- Replace fn_allocate_evf_event_code: regex now allows optional [efs]+ suffix
-- and emits the suffix when called with a non-empty letter string
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_allocate_evf_event_code(INT, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION fn_allocate_evf_event_code(
  p_id_season INT,
  p_kind      TEXT,
  p_location  TEXT,
  p_country   TEXT,
  p_letters   TEXT DEFAULT ''
)
RETURNS TABLE(
  txt_code        TEXT,
  id_prior_event  INT,
  alloc_path      TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_season_suffix TEXT;
  v_prior_season  INT;
  v_loc_key       TEXT;
  v_ctry_key      TEXT;
  v_match_count   INT;
  v_match_id      INT;
  v_match_code    TEXT;
  v_match_prior   INT;
  v_n             INT;
  v_prior_n       INT;
  v_code          TEXT;
  v_letters       TEXT := COALESCE(p_letters, '');
BEGIN
  SELECT regexp_replace(s.txt_code, '^SPWS-', '') INTO v_season_suffix
    FROM tbl_season s WHERE s.id_season = p_id_season;
  IF v_season_suffix IS NULL THEN
    RAISE EXCEPTION 'fn_allocate_evf_event_code: unknown id_season=%', p_id_season;
  END IF;

  -- Singleton kinds (IMEW / DMEW) — unchanged behavior
  IF p_kind IN ('IMEW', 'DMEW') THEN
    v_code := p_kind || '-' || v_season_suffix;

    SELECT e.id_prior_event INTO v_match_prior
      FROM tbl_event e
     WHERE e.txt_code = v_code AND e.id_season = p_id_season;
    IF FOUND THEN
      txt_code       := v_code;
      id_prior_event := v_match_prior;
      alloc_path     := 'CURRENT_SLOT_REUSE';
      RETURN NEXT; RETURN;
    END IF;

    SELECT s.id_season INTO v_prior_season
      FROM tbl_season s WHERE s.id_season < p_id_season
      ORDER BY s.id_season DESC LIMIT 1;
    IF v_prior_season IS NOT NULL THEN
      SELECT e.id_event INTO v_match_id
        FROM tbl_event e
       WHERE e.id_season = v_prior_season
         AND e.txt_code LIKE p_kind || '-%';
      IF FOUND THEN
        txt_code       := v_code;
        id_prior_event := v_match_id;
        alloc_path     := 'PRIOR_SEASON_MATCH';
        RETURN NEXT; RETURN;
      END IF;
    END IF;

    txt_code       := v_code;
    id_prior_event := NULL;
    alloc_path     := 'NEXT_FREE_ALLOC';
    RETURN NEXT; RETURN;
  END IF;

  IF p_kind <> 'PEW' THEN
    RAISE EXCEPTION 'fn_allocate_evf_event_code: unsupported p_kind=% (expected PEW/IMEW/DMEW)', p_kind;
  END IF;

  SELECT n.loc_key, n.country_key INTO v_loc_key, v_ctry_key
    FROM fn_normalize_city_key(p_location, p_country) n;

  -- Step A: current-season CREATED slot reuse (matches PEW{N} or PEW{N}{letters})
  IF v_loc_key <> '' THEN
    SELECT COUNT(*)::INT, MAX(e.txt_code), MAX(e.id_prior_event)
      INTO v_match_count, v_match_code, v_match_prior
      FROM tbl_event e,
           LATERAL fn_normalize_city_key(e.txt_location, e.txt_country) n
     WHERE e.id_season = p_id_season
       AND e.enum_status = 'CREATED'
       AND e.txt_code ~ '^PEW\d+[efs]*-'
       AND n.loc_key    = v_loc_key
       AND n.country_key = v_ctry_key;

    IF v_match_count > 1 THEN
      RAISE EXCEPTION 'fn_allocate_evf_event_code: % CREATED PEW slots match (location=%, country=%) in season %',
        v_match_count, p_location, p_country, p_id_season;
    END IF;
    IF v_match_count = 1 THEN
      txt_code       := v_match_code;
      id_prior_event := v_match_prior;
      alloc_path     := 'CURRENT_SLOT_REUSE';
      RETURN NEXT; RETURN;
    END IF;
  END IF;

  -- Step B: prior-season city match (regex captures N stripping any letters)
  SELECT s.id_season INTO v_prior_season
    FROM tbl_season s WHERE s.id_season < p_id_season
    ORDER BY s.id_season DESC LIMIT 1;

  IF v_prior_season IS NOT NULL AND v_loc_key <> '' THEN
    WITH cands AS (
      SELECT e.id_event,
             ((regexp_match(e.txt_code, '^PEW(\d+)[efs]*-'))[1])::INT AS pew_n
        FROM tbl_event e,
             LATERAL fn_normalize_city_key(e.txt_location, e.txt_country) n
       WHERE e.id_season = v_prior_season
         AND e.txt_code ~ '^PEW\d+[efs]*-'
         AND n.loc_key    = v_loc_key
         AND n.country_key = v_ctry_key
    )
    SELECT COUNT(*)::INT, MAX(id_event), MAX(pew_n)
      INTO v_match_count, v_match_id, v_prior_n
      FROM cands;

    IF v_match_count > 1 THEN
      RAISE EXCEPTION 'fn_allocate_evf_event_code: % prior PEW events match (location=%, country=%) in season %',
        v_match_count, p_location, p_country, v_prior_season;
    END IF;
    IF v_match_count = 1 THEN
      txt_code       := 'PEW' || v_prior_n::TEXT || v_letters || '-' || v_season_suffix;
      id_prior_event := v_match_id;
      alloc_path     := 'PRIOR_SEASON_MATCH';
      RETURN NEXT; RETURN;
    END IF;
  END IF;

  -- Step C: next-free PEW{N+1}
  SELECT COALESCE(MAX(((regexp_match(e.txt_code, '^PEW(\d+)[efs]*-'))[1])::INT), 0) + 1
    INTO v_n
    FROM tbl_event e
   WHERE e.id_season = p_id_season
     AND e.txt_code ~ '^PEW\d+[efs]*-';

  txt_code       := 'PEW' || v_n::TEXT || v_letters || '-' || v_season_suffix;
  id_prior_event := NULL;
  alloc_path     := 'NEXT_FREE_ALLOC';
  RETURN NEXT; RETURN;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_allocate_evf_event_code(INT, TEXT, TEXT, TEXT, TEXT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_allocate_evf_event_code(INT, TEXT, TEXT, TEXT, TEXT) TO authenticated;


-- -----------------------------------------------------------------------------
-- Replace fn_import_evf_events_v2: compute letter string from weapons[] JSONB
-- and pass to allocator
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_import_evf_events_v2(
  p_events    JSONB,
  p_id_season INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_evt          JSONB;
  v_evf_org      INT;
  v_alloc        RECORD;
  v_event_id     INT;
  v_kind         TEXT;
  v_weapon       TEXT;
  v_letters      TEXT;
  v_weapons_arr  enum_weapon_type[];
  v_w_text       TEXT;
  v_created      INT := 0;
  v_slot_reused  INT := 0;
  v_prior_match  INT := 0;
  v_alerts       JSONB := '[]'::JSONB;
BEGIN
  LOCK TABLE tbl_event IN SHARE ROW EXCLUSIVE MODE;

  SELECT id_organizer INTO v_evf_org FROM tbl_organizer WHERE txt_code = 'EVF';
  IF v_evf_org IS NULL THEN
    RAISE EXCEPTION 'fn_import_evf_events_v2: EVF organizer not found in tbl_organizer';
  END IF;

  FOR v_evt IN SELECT * FROM jsonb_array_elements(p_events)
  LOOP
    DECLARE
      v_name     TEXT    := v_evt ->> 'name';
      v_dt_start DATE    := (v_evt ->> 'dt_start')::DATE;
      v_dt_end   DATE    := COALESCE((v_evt ->> 'dt_end')::DATE, (v_evt ->> 'dt_start')::DATE);
      v_location TEXT    := COALESCE(v_evt ->> 'location', '');
      v_country  TEXT    := COALESCE(v_evt ->> 'country', '');
      v_weapons  JSONB   := COALESCE(v_evt -> 'weapons', '[]'::JSONB);
      v_is_team  BOOLEAN := COALESCE((v_evt ->> 'is_team')::BOOLEAN, FALSE);
      v_url_event TEXT   := COALESCE(v_evt ->> 'url_event', '');
      v_url_inv   TEXT   := COALESCE(v_evt ->> 'url_invitation', '');
      v_url_reg   TEXT   := COALESCE(v_evt ->> 'url_registration', '');
      v_addr      TEXT   := COALESCE(v_evt ->> 'address', '');
    BEGIN
      v_kind := fn_classify_evf_event(v_name, v_is_team);

      -- Compute weapons array + letter suffix
      v_weapons_arr := ARRAY[]::enum_weapon_type[];
      FOR v_w_text IN SELECT jsonb_array_elements_text(v_weapons)
      LOOP
        v_weapons_arr := v_weapons_arr || v_w_text::enum_weapon_type;
      END LOOP;

      v_letters := CASE WHEN v_kind = 'PEW'
                        THEN fn_pew_weapon_letters(v_weapons_arr)
                        ELSE '' END;

      SELECT * INTO v_alloc
        FROM fn_allocate_evf_event_code(p_id_season, v_kind, v_location, v_country, v_letters);

      IF v_alloc.alloc_path = 'CURRENT_SLOT_REUSE' THEN
        UPDATE tbl_event SET
          txt_name      = v_name,
          dt_start      = v_dt_start,
          dt_end        = v_dt_end,
          txt_location  = NULLIF(v_location, ''),
          txt_country   = NULLIF(v_country, ''),
          txt_venue_address = COALESCE(NULLIF(v_addr, ''), txt_venue_address),
          url_event     = COALESCE(NULLIF(v_url_event, ''), url_event),
          url_invitation = COALESCE(NULLIF(v_url_inv, ''), url_invitation),
          enum_status   = 'PLANNED'
        WHERE txt_code = v_alloc.txt_code AND id_season = p_id_season
        RETURNING id_event INTO v_event_id;
        v_slot_reused := v_slot_reused + 1;
      ELSE
        IF EXISTS (SELECT 1 FROM tbl_event
                    WHERE txt_code = v_alloc.txt_code AND id_season = p_id_season) THEN
          CONTINUE;
        END IF;

        INSERT INTO tbl_event (
          txt_code, txt_name, id_season, id_organizer,
          dt_start, dt_end, txt_location, txt_country,
          txt_venue_address, url_event, url_invitation,
          enum_status, id_prior_event
        ) VALUES (
          v_alloc.txt_code, v_name, p_id_season, v_evf_org,
          v_dt_start, v_dt_end,
          NULLIF(v_location, ''), NULLIF(v_country, ''),
          NULLIF(v_addr, ''), NULLIF(v_url_event, ''), NULLIF(v_url_inv, ''),
          'PLANNED', v_alloc.id_prior_event
        ) RETURNING id_event INTO v_event_id;

        IF v_alloc.alloc_path = 'PRIOR_SEASON_MATCH' THEN
          v_prior_match := v_prior_match + 1;
        ELSE
          v_created := v_created + 1;
          v_alerts := v_alerts || jsonb_build_object(
            'code',     v_alloc.txt_code,
            'location', v_location,
            'country',  v_country
          );
        END IF;
      END IF;

      -- Create child tournaments (idempotent)
      FOR v_weapon IN SELECT jsonb_array_elements_text(v_weapons)
      LOOP
        INSERT INTO tbl_tournament (
          id_event, txt_code, txt_name, enum_type,
          enum_weapon, enum_gender, enum_age_category,
          dt_tournament, int_participant_count, enum_import_status
        )
        SELECT
          v_event_id,
          v_alloc.txt_code || '-M-' || v_weapon,
          v_name,
          v_kind::enum_tournament_type,
          v_weapon::enum_weapon_type, 'M', 'V2',
          v_dt_start, 0, 'PLANNED'
        WHERE NOT EXISTS (
          SELECT 1 FROM tbl_tournament
          WHERE txt_code = v_alloc.txt_code || '-M-' || v_weapon
        );

        INSERT INTO tbl_tournament (
          id_event, txt_code, txt_name, enum_type,
          enum_weapon, enum_gender, enum_age_category,
          dt_tournament, int_participant_count, enum_import_status
        )
        SELECT
          v_event_id,
          v_alloc.txt_code || '-F-' || v_weapon,
          v_name,
          v_kind::enum_tournament_type,
          v_weapon::enum_weapon_type, 'F', 'V2',
          v_dt_start, 0, 'PLANNED'
        WHERE NOT EXISTS (
          SELECT 1 FROM tbl_tournament
          WHERE txt_code = v_alloc.txt_code || '-F-' || v_weapon
        );
      END LOOP;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'created',       v_created,
    'slot_reused',   v_slot_reused,
    'prior_matched', v_prior_match,
    'alerts',        v_alerts
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_import_evf_events_v2(JSONB, INT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_import_evf_events_v2(JSONB, INT) TO authenticated;


-- -----------------------------------------------------------------------------
-- Replace fn_init_season's regex to allow weapon-suffix in PEW codes
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_init_season(p_id_season INT)
RETURNS TABLE(skeletons_created INT, by_kind JSONB)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_season       tbl_season%ROWTYPE;
  v_prior_id     INT;
  v_suffix       TEXT;
  v_count        INT := 0;
  v_ppw          INT := 0;
  v_pew          INT := 0;
  v_mpw          INT := 0;
  v_msw          INT := 0;
  v_eu           INT := 0;
  v_spws_org     INT;
  v_evf_org      INT;
  v_fie_org      INT;
  v_default_org  INT;
  v_prior        RECORD;
  v_prior_mpw    INT;
  v_prior_msw    INT;
  v_prior_eu     INT;
  v_new_id       INT;
  v_new_code     TEXT;
  v_european     TEXT;
BEGIN
  SELECT * INTO v_season FROM tbl_season WHERE id_season = p_id_season;
  IF v_season.id_season IS NULL THEN
    RAISE EXCEPTION 'fn_init_season: season % not found', p_id_season;
  END IF;

  IF EXISTS (SELECT 1 FROM tbl_event WHERE id_season = p_id_season) THEN
    RAISE EXCEPTION 'fn_init_season: season % already has events', p_id_season;
  END IF;

  v_european := v_season.enum_european_event_type;
  v_suffix := regexp_replace(v_season.txt_code, '^SPWS-', '');

  SELECT id_season INTO v_prior_id
    FROM tbl_season
   WHERE dt_end < v_season.dt_start
   ORDER BY dt_end DESC LIMIT 1;

  SELECT id_organizer INTO v_spws_org FROM tbl_organizer WHERE txt_code = 'SPWS';
  SELECT id_organizer INTO v_evf_org  FROM tbl_organizer WHERE txt_code = 'EVF';
  SELECT id_organizer INTO v_fie_org  FROM tbl_organizer WHERE txt_code = 'FIE';

  v_default_org := COALESCE(
    v_spws_org,
    (SELECT id_organizer FROM tbl_organizer ORDER BY id_organizer LIMIT 1)
  );

  IF v_default_org IS NULL THEN
    RAISE EXCEPTION 'fn_init_season: no organizers exist; cannot create skeleton events';
  END IF;

  IF v_prior_id IS NOT NULL THEN
    FOR v_prior IN
      SELECT id_event, txt_code FROM tbl_event
       WHERE id_season = v_prior_id AND txt_code ~ '^PPW\d+-'
       ORDER BY txt_code
    LOOP
      v_new_code := regexp_replace(v_prior.txt_code, '\d{4}-\d{4}$', v_suffix);
      INSERT INTO tbl_event (
        txt_code, txt_name, id_season, id_organizer,
        txt_location, txt_country, enum_status, id_prior_event
      ) VALUES (
        v_new_code, v_new_code, p_id_season, v_default_org,
        NULL, NULL, 'CREATED', v_prior.id_event
      ) RETURNING id_event INTO v_new_id;
      PERFORM _fn_create_skeleton_children(v_new_id, v_new_code, 'PPW');
      v_ppw := v_ppw + 1;
      v_count := v_count + 1;
    END LOOP;

    -- PEW skeletons — regex now accepts optional [efs]+ suffix
    FOR v_prior IN
      SELECT id_event, txt_code, txt_location, txt_country FROM tbl_event
       WHERE id_season = v_prior_id AND txt_code ~ '^PEW\d+[efs]*-'
       ORDER BY txt_code
    LOOP
      v_new_code := regexp_replace(v_prior.txt_code, '\d{4}-\d{4}$', v_suffix);
      INSERT INTO tbl_event (
        txt_code, txt_name, id_season, id_organizer,
        txt_location, txt_country, enum_status, id_prior_event
      ) VALUES (
        v_new_code, v_new_code, p_id_season,
        COALESCE(v_evf_org, v_default_org),
        v_prior.txt_location, v_prior.txt_country, 'CREATED', v_prior.id_event
      ) RETURNING id_event INTO v_new_id;
      PERFORM _fn_create_skeleton_children(v_new_id, v_new_code, 'PEW');
      v_pew := v_pew + 1;
      v_count := v_count + 1;
    END LOOP;
  END IF;

  v_new_code := 'MPW-' || v_suffix;
  IF v_prior_id IS NOT NULL THEN
    SELECT id_event INTO v_prior_mpw FROM tbl_event
     WHERE id_season = v_prior_id AND txt_code ~ '^MPW-' LIMIT 1;
  END IF;
  INSERT INTO tbl_event (
    txt_code, txt_name, id_season, id_organizer,
    txt_location, txt_country, enum_status, id_prior_event
  ) VALUES (
    v_new_code, v_new_code, p_id_season, v_default_org,
    NULL, NULL, 'CREATED', v_prior_mpw
  ) RETURNING id_event INTO v_new_id;
  PERFORM _fn_create_skeleton_children(v_new_id, v_new_code, 'MPW');
  v_mpw := 1;
  v_count := v_count + 1;

  v_new_code := 'MSW-' || v_suffix;
  IF v_prior_id IS NOT NULL THEN
    SELECT id_event INTO v_prior_msw FROM tbl_event
     WHERE id_season = v_prior_id AND txt_code ~ '^I?MSW-' LIMIT 1;
  END IF;
  INSERT INTO tbl_event (
    txt_code, txt_name, id_season, id_organizer,
    txt_location, txt_country, enum_status, id_prior_event
  ) VALUES (
    v_new_code, v_new_code, p_id_season, COALESCE(v_fie_org, v_default_org),
    NULL, NULL, 'CREATED', v_prior_msw
  ) RETURNING id_event INTO v_new_id;
  PERFORM _fn_create_skeleton_children(v_new_id, v_new_code, 'MSW');
  v_msw := 1;
  v_count := v_count + 1;

  IF v_european IS NOT NULL THEN
    v_new_code := v_european || '-' || v_suffix;
    SELECT e.id_event INTO v_prior_eu
      FROM tbl_event e JOIN tbl_season s ON s.id_season = e.id_season
     WHERE e.txt_code ~ ('^' || v_european || '-')
       AND s.dt_end < v_season.dt_start
     ORDER BY s.dt_end DESC, e.id_event DESC LIMIT 1;

    INSERT INTO tbl_event (
      txt_code, txt_name, id_season, id_organizer,
      txt_location, txt_country, enum_status, id_prior_event
    ) VALUES (
      v_new_code, v_new_code, p_id_season, COALESCE(v_evf_org, v_default_org),
      NULL, NULL, 'CREATED', v_prior_eu
    ) RETURNING id_event INTO v_new_id;
    PERFORM _fn_create_skeleton_children(v_new_id, v_new_code, 'MEW');
    v_eu := 1;
    v_count := v_count + 1;
  END IF;

  DECLARE
    v_by_kind JSONB;
  BEGIN
    v_by_kind := jsonb_build_object('PPW', v_ppw, 'PEW', v_pew,
                                    'MPW', v_mpw, 'MSW', v_msw);
    IF v_european IS NOT NULL THEN
      v_by_kind := v_by_kind || jsonb_build_object(v_european, v_eu);
    END IF;
    RETURN QUERY SELECT v_count, v_by_kind;
  END;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_init_season(INT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_init_season(INT) TO authenticated;


-- -----------------------------------------------------------------------------
-- Splitter helper: split bundled events + apply weapon-letter suffix to all PEW
-- -----------------------------------------------------------------------------
-- Idempotent: re-running rebuilds the suffix from current child weapons.
-- Returns counts (split, renamed) for telemetry.
CREATE OR REPLACE FUNCTION fn_split_pew_by_weapon()
RETURNS TABLE(events_split INT, events_renamed INT, tournaments_renamed INT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
$$;

REVOKE EXECUTE ON FUNCTION fn_split_pew_by_weapon() FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_split_pew_by_weapon() TO authenticated;


-- -----------------------------------------------------------------------------
-- Run the splitter once at migration apply time
-- -----------------------------------------------------------------------------
DO $run_splitter$
DECLARE
  v_result RECORD;
BEGIN
  SELECT * INTO v_result FROM fn_split_pew_by_weapon();
  RAISE NOTICE 'Phase 4 splitter: split=%, renamed=%, tournaments_renamed=%',
    v_result.events_split, v_result.events_renamed, v_result.tournaments_renamed;

  -- Re-run the FK backfill so new weapon-suffixed codes get linked across seasons
  PERFORM fn_backfill_id_prior_event();
END;
$run_splitter$;
