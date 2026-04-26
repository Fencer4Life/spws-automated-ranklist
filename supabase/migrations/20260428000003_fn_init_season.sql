-- =============================================================================
-- Phase 3a — fn_init_season: pre-allocate skeleton events for a new season
-- =============================================================================
-- Walks the chronologically-prior season and produces one CREATED-status event
-- per recurring kind, plus 6 child tournaments (M/F × EPEE/FOIL/SABRE) on each.
--   * PPWn — one per prior PPWn, NULL location (rotating venues each season)
--   * PEWn — one per prior numbered PEWn, location/country copied from prior
--   * MPW  — always exactly one (linked to prior MPW if any)
--   * MSW  — always exactly one (linked to prior MSW if any)
--   * IMEW or DMEW — exactly one if season's enum_european_event_type is set;
--     linked to most-recent prior matching event regardless of season distance
--     (covers IMEW biennial alternation, ADR-021)
--
-- Slug-style PEW codes (PEW-LIÈGE, PEW-SPORTHALLE, PEW-SALLEJEANZ, …) are
-- excluded from the iteration: they are non-repeating venue events and admin
-- creates them ad-hoc. Only the `^PEW\d+-` family is replicated.
--
-- For the first-ever season (no chronological prior), only the singletons
-- (MPW + MSW + optional European) are created with id_prior_event = NULL.
--
-- Returns (skeletons_created, by_kind) where by_kind is a JSONB breakdown.
-- =============================================================================

-- Private helper: insert 6 V2 child tournaments for a freshly-created skeleton
-- event. The child code convention differs by kind (PPW/PEW use a -V2- infix
-- and trailing season suffix; MEW/MSW/MPW append -G-W to the event code).
CREATE OR REPLACE FUNCTION _fn_create_skeleton_children(
  p_id_event   INT,
  p_event_code TEXT,
  p_kind       enum_tournament_type
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_w           enum_weapon_type;
  v_g           enum_gender_type;
  v_prefix      TEXT;
  v_suffix      TEXT;
  v_child_code  TEXT;
BEGIN
  IF p_kind IN ('PPW', 'PEW') THEN
    v_prefix := regexp_replace(p_event_code, '-\d{4}-\d{4}$', '');
    v_suffix := COALESCE(
      (regexp_match(p_event_code, '(\d{4}-\d{4})$'))[1],
      ''
    );
  END IF;

  FOREACH v_g IN ARRAY ARRAY['F','M']::enum_gender_type[] LOOP
    FOREACH v_w IN ARRAY ARRAY['EPEE','FOIL','SABRE']::enum_weapon_type[] LOOP
      IF p_kind IN ('PPW', 'PEW') THEN
        v_child_code := v_prefix || '-V2-' || v_g::TEXT || '-' || v_w::TEXT
                        || CASE WHEN v_suffix = '' THEN '' ELSE '-' || v_suffix END;
      ELSE
        v_child_code := p_event_code || '-' || v_g::TEXT || '-' || v_w::TEXT;
      END IF;

      INSERT INTO tbl_tournament (
        id_event, txt_code, enum_type,
        enum_weapon, enum_gender, enum_age_category
      ) VALUES (
        p_id_event, v_child_code, p_kind,
        v_w, v_g, 'V2'
      );
    END LOOP;
  END LOOP;
END;
$$;


-- Main RPC.
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

  -- Fallback: if no SPWS org exists (very fresh DB), use the lowest id we have.
  v_default_org := COALESCE(
    v_spws_org,
    (SELECT id_organizer FROM tbl_organizer ORDER BY id_organizer LIMIT 1)
  );

  IF v_default_org IS NULL THEN
    RAISE EXCEPTION 'fn_init_season: no organizers exist; cannot create skeleton events';
  END IF;

  -- ---- PPW skeletons (only when prior season exists) ----
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

    -- ---- PEW skeletons (numbered only) ----
    FOR v_prior IN
      SELECT id_event, txt_code, txt_location, txt_country FROM tbl_event
       WHERE id_season = v_prior_id AND txt_code ~ '^PEW\d+-'
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

  -- ---- MPW (always one) ----
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

  -- ---- MSW (always one) ----
  -- Match both 'MSW-' and 'IMSW-' on the prior side; the carry-over chain is
  -- by FK so the historical naming inconsistency doesn't matter. Skeleton is
  -- always coded as `MSW-{suffix}` (canonical form).
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

  -- ---- IMEW or DMEW (singleton, biennial-aware lookup) ----
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
