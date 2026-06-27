-- =============================================================================
-- ADR-044 (amend) — childless season-init skeletons (user requirement 2026-06-27)
--
-- When creating an empty season, the pre-allocated events must have ZERO child
-- tournaments. The events exist purely as a CALENDAR skeleton; the actual
-- tournaments are ingested per event later (each event's results arrive after
-- it happens). Pre-creating 6 V2 child tournaments (M/F × EPEE/FOIL/SABRE) per
-- event made no sense — those placeholders never matched the real, per-event
-- bracket structure and had to be reconciled away on ingestion.
--
-- This redefines fn_init_season (last authoritative version: phase4 PEW-split,
-- migration 20260429000001) verbatim EXCEPT it drops the five
-- `_fn_create_skeleton_children` calls. The helper itself is RETAINED (unused by
-- fn_init_season) as a fixture builder for the cascade-rename pgTAP tests.
-- =============================================================================

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
      -- childless: tournaments are ingested per event later
      v_ppw := v_ppw + 1;
      v_count := v_count + 1;
    END LOOP;

    -- PEW skeletons — regex accepts optional [efs]+ suffix
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
