-- =============================================================================
-- ADR-017: Season-configurable EVF toggle
--
-- Adds bool_show_evf_toggle to tbl_scoring_config (default FALSE).
-- When FALSE, the PPW/+EVF toggle is hidden in the web UI.
-- When TRUE, the toggle appears with PPW as the default selection.
--
-- Updates fn_export_scoring_config and fn_import_scoring_config to include
-- the new column.
-- =============================================================================

ALTER TABLE tbl_scoring_config
  ADD COLUMN bool_show_evf_toggle BOOLEAN NOT NULL DEFAULT FALSE;


-- -----------------------------------------------------------------------------
-- fn_export_scoring_config — add show_evf_toggle to JSONB output
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_export_scoring_config(p_id_season INT)
RETURNS JSONB
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT jsonb_build_object(
    'id_season',              sc.id_season,
    'season_code',            s.txt_code,
    'mp_value',               sc.int_mp_value,
    'podium_gold',            sc.int_podium_gold,
    'podium_silver',          sc.int_podium_silver,
    'podium_bronze',          sc.int_podium_bronze,
    'ppw_multiplier',         sc.num_ppw_multiplier,
    'ppw_best_count',         sc.int_ppw_best_count,
    'ppw_total_rounds',       sc.int_ppw_total_rounds,
    'mpw_multiplier',         sc.num_mpw_multiplier,
    'mpw_droppable',          sc.bool_mpw_droppable,
    'pew_multiplier',         sc.num_pew_multiplier,
    'pew_best_count',         sc.int_pew_best_count,
    'mew_multiplier',         sc.num_mew_multiplier,
    'mew_droppable',          sc.bool_mew_droppable,
    'msw_multiplier',         sc.num_msw_multiplier,
    'psw_multiplier',         sc.num_psw_multiplier,
    'min_participants_evf',   sc.int_min_participants_evf,
    'min_participants_ppw',   sc.int_min_participants_ppw,
    'show_evf_toggle',        sc.bool_show_evf_toggle,
    'ranking_rules',          sc.json_ranking_rules,
    'extra',                  sc.json_extra
  )
  FROM tbl_scoring_config sc
  JOIN tbl_season s ON s.id_season = sc.id_season
  WHERE sc.id_season = p_id_season;
$$;


-- -----------------------------------------------------------------------------
-- fn_import_scoring_config — accept show_evf_toggle in JSONB input
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
    int_min_participants_evf, int_min_participants_ppw,
    bool_show_evf_toggle,
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
    COALESCE((p_config->>'min_participants_evf')::INT,   5),
    COALESCE((p_config->>'min_participants_ppw')::INT,   1),
    COALESCE((p_config->>'show_evf_toggle')::BOOLEAN,    FALSE),
    p_config->'ranking_rules',
    COALESCE(p_config->'extra', '{}'::JSONB),
    NOW()
  )
  ON CONFLICT (id_season) DO UPDATE SET
    int_mp_value              = COALESCE((p_config->>'mp_value')::INT,              tbl_scoring_config.int_mp_value),
    int_podium_gold           = COALESCE((p_config->>'podium_gold')::INT,            tbl_scoring_config.int_podium_gold),
    int_podium_silver         = COALESCE((p_config->>'podium_silver')::INT,          tbl_scoring_config.int_podium_silver),
    int_podium_bronze         = COALESCE((p_config->>'podium_bronze')::INT,          tbl_scoring_config.int_podium_bronze),
    num_ppw_multiplier        = COALESCE((p_config->>'ppw_multiplier')::NUMERIC,     tbl_scoring_config.num_ppw_multiplier),
    int_ppw_best_count        = COALESCE((p_config->>'ppw_best_count')::INT,         tbl_scoring_config.int_ppw_best_count),
    int_ppw_total_rounds      = COALESCE((p_config->>'ppw_total_rounds')::INT,       tbl_scoring_config.int_ppw_total_rounds),
    num_mpw_multiplier        = COALESCE((p_config->>'mpw_multiplier')::NUMERIC,     tbl_scoring_config.num_mpw_multiplier),
    bool_mpw_droppable        = COALESCE((p_config->>'mpw_droppable')::BOOLEAN,      tbl_scoring_config.bool_mpw_droppable),
    num_pew_multiplier        = COALESCE((p_config->>'pew_multiplier')::NUMERIC,     tbl_scoring_config.num_pew_multiplier),
    int_pew_best_count        = COALESCE((p_config->>'pew_best_count')::INT,         tbl_scoring_config.int_pew_best_count),
    num_mew_multiplier        = COALESCE((p_config->>'mew_multiplier')::NUMERIC,     tbl_scoring_config.num_mew_multiplier),
    bool_mew_droppable        = COALESCE((p_config->>'mew_droppable')::BOOLEAN,      tbl_scoring_config.bool_mew_droppable),
    num_msw_multiplier        = COALESCE((p_config->>'msw_multiplier')::NUMERIC,     tbl_scoring_config.num_msw_multiplier),
    num_psw_multiplier        = COALESCE((p_config->>'psw_multiplier')::NUMERIC,     tbl_scoring_config.num_psw_multiplier),
    int_min_participants_evf  = COALESCE((p_config->>'min_participants_evf')::INT,   tbl_scoring_config.int_min_participants_evf),
    int_min_participants_ppw  = COALESCE((p_config->>'min_participants_ppw')::INT,   tbl_scoring_config.int_min_participants_ppw),
    bool_show_evf_toggle      = COALESCE((p_config->>'show_evf_toggle')::BOOLEAN,    tbl_scoring_config.bool_show_evf_toggle),
    json_ranking_rules        = COALESCE(p_config->'ranking_rules',                  tbl_scoring_config.json_ranking_rules),
    json_extra                = COALESCE(p_config->'extra',                          tbl_scoring_config.json_extra),
    ts_updated                = NOW();
END;
$$;
