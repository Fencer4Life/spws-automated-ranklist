-- =============================================================================
-- PPS/MPS multiplier columns, wiring, and two live-defect fixes
-- =============================================================================
-- Second half of adding PPS/MPS (see 20260919000003 for why this is split).
-- Delivery steps 6+7 pulled forward per
-- doc/plans/did-you-plan-to-optimized-penguin.md.
--
-- STORAGE SHAPE: WIDE COLUMNS, NOT tbl_scoring_type_config ROWS.
--
-- tbl_scoring_type_config (20260919000002) is currently a PROJECTION:
-- trg_sync_scoring_type_config rewrites its rows from tbl_scoring_config's own
-- columns via fn_sync_scoring_type_config's VALUES list, with ON CONFLICT DO
-- UPDATE. Making PPS/MPS the first two NATIVELY row-stored types while the
-- other six stay trigger-owned would let a projection sync silently clobber a
-- directly-written PPS/MPS row (or vice versa) the moment anyone touches that
-- VALUES list. Columns reuse export, import, fn_copy_prior_scoring_config and
-- the wizard defaults UNCHANGED and already tested. Design step 7 retires all
-- eight multiplier columns together, once the lock (step 3b) makes the write
-- surface single-owner.
--
-- THRESHOLD: HARDCODED TO 1, NOT A UI FIELD.
--
-- Per instruction, PPS/MPS fields are always > 16 competitors, so 1 and 16
-- behave identically today. 1 is chosen anyway: 16 carries a silent-drop risk
-- if a weapon/gender bracket ever comes in smaller, and ADR-066's ingestion
-- gate skips such a bracket with no tbl_tournament row and no error at all.
-- 1 admits everything and cannot lose data; there is deliberately no Admin
-- threshold field for these two types (§07: "no ... result-counting buckets").
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Columns. Same shape as PSW's own precedent (20250305000002:24).
-- -----------------------------------------------------------------------------
SET LOCAL lock_timeout = '2s';
ALTER TABLE tbl_scoring_config
  ADD COLUMN IF NOT EXISTS num_pps_multiplier NUMERIC(8,4) NOT NULL DEFAULT 1.0,
  ADD COLUMN IF NOT EXISTS num_mps_multiplier NUMERIC(8,4) NOT NULL DEFAULT 1.0;

COMMENT ON COLUMN tbl_scoring_config.num_pps_multiplier IS
  'Score multiplier for PPS (Puchar Polski Seniorow, PZSz senior cup). '
  'Placeholder default 1.0 -- SS26 design SS07 requires a reviewed CERT value '
  'before any PZSz result is scored.';
COMMENT ON COLUMN tbl_scoring_config.num_mps_multiplier IS
  'Score multiplier for MPS (Mistrzostwa Polski Seniorow, PZSz senior '
  'championship). Placeholder default 1.0 -- see num_pps_multiplier.';

-- -----------------------------------------------------------------------------
-- Extend the projection (20260919000002:71-94). Threshold hardcoded to 1 per
-- the note above -- there is no int_min_participants_pps/_mps column to read.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_sync_scoring_type_config(p_id_config INT)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO tbl_scoring_type_config (id_config, enum_type, num_multiplier, int_min_participants)
  SELECT c.id_config, v.ttype::enum_tournament_type, v.mult, v.threshold
    FROM tbl_scoring_config c
    CROSS JOIN LATERAL (VALUES
        ('PPW', c.num_ppw_multiplier, c.int_min_participants_ppw),
        ('MPW', c.num_mpw_multiplier, c.int_min_participants_ppw),
        ('PSW', c.num_psw_multiplier, c.int_min_participants_ppw),
        ('PEW', c.num_pew_multiplier, c.int_min_participants_evf),
        ('MEW', c.num_mew_multiplier, c.int_min_participants_evf),
        ('MSW', c.num_msw_multiplier, c.int_min_participants_evf),
        ('PPS', c.num_pps_multiplier, 1),
        ('MPS', c.num_mps_multiplier, 1)
      ) AS v(ttype, mult, threshold)
   WHERE c.id_config = p_id_config
  ON CONFLICT (id_config, enum_type) DO UPDATE
     SET num_multiplier       = EXCLUDED.num_multiplier,
         int_min_participants = EXCLUDED.int_min_participants,
         ts_updated           = NOW();
END;
$$;

COMMENT ON FUNCTION fn_sync_scoring_type_config(INT) IS
  'Projects tbl_scoring_config''s legacy per-type columns onto the normalized '
  'rows. Carries ADR-066''s real threshold routing ({PPW,MPW,PSW} -> ppw, '
  '{PEW,MEW,MSW} -> evf), which is NOT what the column names suggest. PPS/MPS '
  'threshold is hardcoded to 1 -- there is no Admin field for it (§07).';

-- Re-project every existing configuration so its PPS/MPS rows exist at 1.0/1.
SELECT fn_backfill_scoring_type_config();

-- -----------------------------------------------------------------------------
-- fn_export_scoring_config (live: 20260627000002:31-63) -- add pps/mps to the
-- JSONB output. This alone fixes fn_copy_prior_scoring_config, which
-- delegates to it (20260428000006:13-36) and therefore carries PPS/MPS
-- forward to a new season with no separate change.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_export_scoring_config(p_id_season INT)
RETURNS JSONB
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT jsonb_build_object(
    'id_season',                sc.id_season,
    'season_code',              s.txt_code,
    'mp_value',                 sc.int_mp_value,
    'podium_gold',              sc.int_podium_gold,
    'podium_silver',            sc.int_podium_silver,
    'podium_bronze',            sc.int_podium_bronze,
    'ppw_multiplier',           sc.num_ppw_multiplier,
    'ppw_best_count',           sc.int_ppw_best_count,
    'ppw_total_rounds',         sc.int_ppw_total_rounds,
    'mpw_multiplier',           sc.num_mpw_multiplier,
    'mpw_droppable',            sc.bool_mpw_droppable,
    'pew_multiplier',           sc.num_pew_multiplier,
    'pew_best_count',           sc.int_pew_best_count,
    'mew_multiplier',           sc.num_mew_multiplier,
    'mew_droppable',            sc.bool_mew_droppable,
    'msw_multiplier',           sc.num_msw_multiplier,
    'psw_multiplier',           sc.num_psw_multiplier,
    'pps_multiplier',           sc.num_pps_multiplier,
    'mps_multiplier',           sc.num_mps_multiplier,
    'min_participants_evf',     sc.int_min_participants_evf,
    'min_participants_ppw',     sc.int_min_participants_ppw,
    'show_evf_toggle',          sc.bool_show_evf_toggle,
    'show_evf_toggle_calendar', sc.bool_show_evf_toggle_calendar,
    'ranking_rules',            sc.json_ranking_rules,
    'extra',                    sc.json_extra
  )
  FROM tbl_scoring_config sc
  JOIN tbl_season s ON s.id_season = sc.id_season
  WHERE sc.id_season = p_id_season;
$$;

-- -----------------------------------------------------------------------------
-- fn_import_scoring_config (live: 20260627000002:69-147) -- three sites:
-- column list, VALUES with COALESCE default, ON CONFLICT DO UPDATE SET.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_import_scoring_config(p_config JSONB)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_season INT := (p_config->>'id_season')::INT;
BEGIN
  IF v_season IS NULL THEN
    RAISE EXCEPTION 'id_season is required in the config JSON';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM tbl_season WHERE id_season = v_season) THEN
    RAISE EXCEPTION 'Season % does not exist', v_season;
  END IF;

  INSERT INTO tbl_scoring_config (
    id_season,
    int_mp_value,
    int_podium_gold, int_podium_silver, int_podium_bronze,
    num_ppw_multiplier, int_ppw_best_count, int_ppw_total_rounds,
    num_mpw_multiplier, bool_mpw_droppable,
    num_pew_multiplier, int_pew_best_count,
    num_mew_multiplier, bool_mew_droppable,
    num_msw_multiplier, num_psw_multiplier,
    num_pps_multiplier, num_mps_multiplier,
    int_min_participants_evf, int_min_participants_ppw,
    bool_show_evf_toggle,
    bool_show_evf_toggle_calendar,
    json_ranking_rules, json_extra,
    ts_updated
  ) VALUES (
    v_season,
    COALESCE((p_config->>'mp_value')::INT,              50),
    COALESCE((p_config->>'podium_gold')::INT,            3),
    COALESCE((p_config->>'podium_silver')::INT,          2),
    COALESCE((p_config->>'podium_bronze')::INT,          1),
    COALESCE((p_config->>'ppw_multiplier')::NUMERIC,     1.0),
    COALESCE((p_config->>'ppw_best_count')::INT,         4),
    COALESCE((p_config->>'ppw_total_rounds')::INT,       5),
    COALESCE((p_config->>'mpw_multiplier')::NUMERIC,     1.2),
    COALESCE((p_config->>'mpw_droppable')::BOOLEAN,      TRUE),
    COALESCE((p_config->>'pew_multiplier')::NUMERIC,     1.0),
    COALESCE((p_config->>'pew_best_count')::INT,         3),
    COALESCE((p_config->>'mew_multiplier')::NUMERIC,     2.0),
    COALESCE((p_config->>'mew_droppable')::BOOLEAN,      TRUE),
    COALESCE((p_config->>'msw_multiplier')::NUMERIC,     2.0),
    COALESCE((p_config->>'psw_multiplier')::NUMERIC,     2.0),
    COALESCE((p_config->>'pps_multiplier')::NUMERIC,     1.0),
    COALESCE((p_config->>'mps_multiplier')::NUMERIC,     1.0),
    COALESCE((p_config->>'min_participants_evf')::INT,   5),
    COALESCE((p_config->>'min_participants_ppw')::INT,   1),
    COALESCE((p_config->>'show_evf_toggle')::BOOLEAN,    FALSE),
    COALESCE((p_config->>'show_evf_toggle_calendar')::BOOLEAN, TRUE),
    p_config->'ranking_rules',
    COALESCE(p_config->'extra', '{}'::JSONB),
    NOW()
  )
  ON CONFLICT (id_season) DO UPDATE SET
    int_mp_value                  = COALESCE((p_config->>'mp_value')::INT,              tbl_scoring_config.int_mp_value),
    int_podium_gold               = COALESCE((p_config->>'podium_gold')::INT,            tbl_scoring_config.int_podium_gold),
    int_podium_silver             = COALESCE((p_config->>'podium_silver')::INT,          tbl_scoring_config.int_podium_silver),
    int_podium_bronze             = COALESCE((p_config->>'podium_bronze')::INT,          tbl_scoring_config.int_podium_bronze),
    num_ppw_multiplier            = COALESCE((p_config->>'ppw_multiplier')::NUMERIC,     tbl_scoring_config.num_ppw_multiplier),
    int_ppw_best_count            = COALESCE((p_config->>'ppw_best_count')::INT,         tbl_scoring_config.int_ppw_best_count),
    int_ppw_total_rounds          = COALESCE((p_config->>'ppw_total_rounds')::INT,       tbl_scoring_config.int_ppw_total_rounds),
    num_mpw_multiplier            = COALESCE((p_config->>'mpw_multiplier')::NUMERIC,     tbl_scoring_config.num_mpw_multiplier),
    bool_mpw_droppable            = COALESCE((p_config->>'mpw_droppable')::BOOLEAN,      tbl_scoring_config.bool_mpw_droppable),
    num_pew_multiplier            = COALESCE((p_config->>'pew_multiplier')::NUMERIC,     tbl_scoring_config.num_pew_multiplier),
    int_pew_best_count            = COALESCE((p_config->>'pew_best_count')::INT,         tbl_scoring_config.int_pew_best_count),
    num_mew_multiplier            = COALESCE((p_config->>'mew_multiplier')::NUMERIC,     tbl_scoring_config.num_mew_multiplier),
    bool_mew_droppable            = COALESCE((p_config->>'mew_droppable')::BOOLEAN,      tbl_scoring_config.bool_mew_droppable),
    num_msw_multiplier            = COALESCE((p_config->>'msw_multiplier')::NUMERIC,     tbl_scoring_config.num_msw_multiplier),
    num_psw_multiplier            = COALESCE((p_config->>'psw_multiplier')::NUMERIC,     tbl_scoring_config.num_psw_multiplier),
    num_pps_multiplier            = COALESCE((p_config->>'pps_multiplier')::NUMERIC,     tbl_scoring_config.num_pps_multiplier),
    num_mps_multiplier            = COALESCE((p_config->>'mps_multiplier')::NUMERIC,     tbl_scoring_config.num_mps_multiplier),
    int_min_participants_evf      = COALESCE((p_config->>'min_participants_evf')::INT,   tbl_scoring_config.int_min_participants_evf),
    int_min_participants_ppw      = COALESCE((p_config->>'min_participants_ppw')::INT,   tbl_scoring_config.int_min_participants_ppw),
    bool_show_evf_toggle          = COALESCE((p_config->>'show_evf_toggle')::BOOLEAN,    tbl_scoring_config.bool_show_evf_toggle),
    bool_show_evf_toggle_calendar = COALESCE((p_config->>'show_evf_toggle_calendar')::BOOLEAN, tbl_scoring_config.bool_show_evf_toggle_calendar),
    json_ranking_rules            = COALESCE(p_config->'ranking_rules',                  tbl_scoring_config.json_ranking_rules),
    json_extra                    = COALESCE(p_config->'extra',                          tbl_scoring_config.json_extra),
    ts_updated                    = NOW();
END;
$$;

-- -----------------------------------------------------------------------------
-- LIVE DEFECT 1: fn_auto_populate_multiplier has no PSW branch and no ELSE
-- (20250301000003_lifecycle_triggers.sql:47-53). Confirmed latent -- 0 PSW
-- tournaments exist -- but PPS/MPS would hit it immediately and write
-- num_multiplier = NULL. This trigger only caches a display value on
-- tbl_tournament; fn_calc_tournament_scores resolves the authoritative
-- multiplier itself via fn_assert_type_configured / tbl_scoring_type_config
-- and does not read this column, so the defect was cosmetic, not a scoring
-- bug. Fixed here rather than left for step 7 because PPS/MPS would hit it at
-- once. An unrecognised type still raises rather than silently writing NULL.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_auto_populate_multiplier()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_season_id INT;
    v_config RECORD;
BEGIN
    -- Get the season via the event
    SELECT e.id_season INTO v_season_id
    FROM tbl_event e
    WHERE e.id_event = NEW.id_event;

    -- Get the scoring config for this season
    SELECT * INTO v_config
    FROM tbl_scoring_config
    WHERE id_season = v_season_id;

    -- Resolve multiplier based on tournament type
    NEW.num_multiplier := CASE NEW.enum_type
        WHEN 'PPW' THEN v_config.num_ppw_multiplier
        WHEN 'MPW' THEN v_config.num_mpw_multiplier
        WHEN 'PEW' THEN v_config.num_pew_multiplier
        WHEN 'MEW' THEN v_config.num_mew_multiplier
        WHEN 'MSW' THEN v_config.num_msw_multiplier
        WHEN 'PSW' THEN v_config.num_psw_multiplier
        WHEN 'PPS' THEN v_config.num_pps_multiplier
        WHEN 'MPS' THEN v_config.num_mps_multiplier
        ELSE NULL
    END;

    IF NEW.num_multiplier IS NULL THEN
      RAISE EXCEPTION
        'No display multiplier resolved for tournament type % (season %). '
        'Refusing to cache a NULL multiplier.', NEW.enum_type, v_season_id;
    END IF;

    RETURN NEW;
END;
$$;

-- -----------------------------------------------------------------------------
-- LIVE DEFECT 2: fn_create_season_with_skeletons never sets
-- tbl_season.id_scoring_engine (20260428000004_fn_create_season_with_skeletons.sql).
-- Regression introduced by design step 2: fn_resolve_scoring_params now raises
-- "Unknown scoring engine" for a season with no assignment, so a season
-- created through the wizard today cannot be scored at all, with no UI to fix
-- it. Fixed here by assigning the newest bool_active engine on insert -- a
-- deliberate DEFAULT, not inference from a prior season (§05 forbids that
-- specifically). The Admin engine selector can still override it before the
-- first score; after the first score the assignment locks (§05, step 3b).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_create_season_with_skeletons(
  p_code              TEXT,
  p_dt_start          DATE,
  p_dt_end            DATE,
  p_carryover_days    INT,
  p_european_type     TEXT,
  p_carryover_engine  enum_event_carryover_engine,
  p_scoring_config    JSONB,
  p_show_evf          BOOLEAN
)
RETURNS TABLE(id_season INT, skeletons_created INT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_id        INT;
  v_count     INT;
  v_engine_id INT;
BEGIN
  -- id_engine DESC breaks ties: both released engines were inserted by the
  -- same migration statement (20260919000001) and share one ts_created value
  -- to the microsecond, so "ORDER BY ts_created DESC" alone is not
  -- deterministic and was observed picking the RETIRED classic engine for a
  -- brand-new season. SERIAL strictly increases with insertion order, so
  -- id_engine DESC is the correct, stable tie-break to the actually-newest row.
  SELECT se.id_engine INTO v_engine_id
    FROM tbl_scoring_engine se
   WHERE se.bool_active
   ORDER BY se.ts_created DESC, se.id_engine DESC
   LIMIT 1;

  INSERT INTO tbl_season (
    txt_code, dt_start, dt_end,
    int_carryover_days, enum_european_event_type, enum_carryover_engine,
    id_scoring_engine
  ) VALUES (
    p_code, p_dt_start, p_dt_end,
    COALESCE(p_carryover_days, 366), p_european_type, p_carryover_engine,
    v_engine_id
  ) RETURNING tbl_season.id_season INTO v_id;

  -- Overwrite the trigger-inserted defaults with wizard payload + show_evf.
  PERFORM fn_import_scoring_config(
    COALESCE(p_scoring_config, '{}'::JSONB)
      || jsonb_build_object('id_season', v_id, 'show_evf_toggle', p_show_evf)
  );

  SELECT (fn_init_season(v_id)).skeletons_created INTO v_count;

  RETURN QUERY SELECT v_id, v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_create_season_with_skeletons(
  TEXT, DATE, DATE, INT, TEXT, enum_event_carryover_engine, JSONB, BOOLEAN
) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION fn_create_season_with_skeletons(
  TEXT, DATE, DATE, INT, TEXT, enum_event_carryover_engine, JSONB, BOOLEAN
) TO authenticated;

-- -----------------------------------------------------------------------------
-- ADR-083 deny-by-default. CREATE OR REPLACE preserves existing grants, so
-- none of the redefinitions above actually reset anything -- these REVOKEs
-- are defensive re-assertion, matching every prior migration in this branch,
-- since 52_security_posture.sql 52.7 asserts the anon-EXECUTEable set as a
-- SET EQUALITY and has caught a missed one three times already.
--
-- fn_export_scoring_config is DELIBERATELY NOT revoked here: 20260327000001
-- documents it as a read-only function that stays anon-accessible, and 52.7's
-- allowlist names it explicitly. Revoking it would both break the public
-- surface that reads it and turn 52.7 itself RED by shrinking the actual set
-- below the documented one. fn_auto_populate_multiplier is a trigger function
-- -- 52.7's own scope note excludes trigger functions because Postgres
-- refuses to call them outside a trigger context, so a grant on one is not
-- reachable surface; 20260327000001 makes the same call ("no change needed").
-- -----------------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION fn_sync_scoring_type_config(INT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_import_scoring_config(JSONB) FROM PUBLIC, anon;
