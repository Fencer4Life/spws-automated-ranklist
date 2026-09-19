-- =============================================================================
-- Ranking schema v2 -- default ranking mode column + governance lock addition
-- =============================================================================
-- Design step 4, first half. doc/plans/ranking-schema-v2-2026-09-19.html
-- §05/§09. Closes SS26.LOCK.13 and half of SS26.REVISION.09 (the write path;
-- 20260919000008 is not required for this column, since fn_revise_and_
-- rescore_season and fn_apply_scoring_config_write are extended here too).
--
-- WHAT THIS MIGRATION DOES.
--
-- Adds tbl_scoring_config.enum_default_ranking_mode ('PPW' | 'RANKING'), the
-- column the governance-lock plan's own Flags section deferred ("its column
-- doesn't exist yet -- belongs to ranking schema v2, design step 4, not yet
-- built"). Folds it into the SAME governance lock as every other scoring
-- field, in the same places: fn_export_scoring_config (read), fn_import_
-- scoring_config (field-level guard), fn_guard_scoring_config_write (direct-
-- write trigger backstop), fn_apply_scoring_config_write (the privileged
-- revision's unconditional write path). No new mechanism -- one more line in
-- four already-existing functions, following the exact pattern engine_code
-- established in 20260919000005/6.
--
-- json_ranking_rules ITSELF IS UNCHANGED HERE.
--
-- Schema v2 for json_ranking_rules (season_scoring_rules/display_groups/
-- views) is a new VALUE SHAPE for an already-JSONB column, not a schema
-- change -- fn_export_scoring_config/fn_import_scoring_config already
-- round-trip json_ranking_rules opaquely (COALESCE(NULLIF(...), stored)),
-- so nothing here needs to change for that. The real SPWS-2026-2027 season's
-- json_ranking_rules is deliberately NOT touched by this migration -- see
-- doc/plans/ranking-schema-v2-2026-09-19.html §03: the live frontend still
-- calls fn_ranking_kadra/fn_ranking_ppw against the active season, and they
-- do not understand schema v2. That cutover is design step 7's job, together
-- with the frontend migration to fn_ranking_full (20260919000008).
-- =============================================================================

CREATE TYPE enum_ranking_mode AS ENUM (
  'PPW',
  'RANKING'
);

ALTER TABLE tbl_scoring_config
  ADD COLUMN enum_default_ranking_mode enum_ranking_mode
    NOT NULL DEFAULT 'PPW';

COMMENT ON COLUMN tbl_scoring_config.enum_default_ranking_mode IS
  'Which view (design §06''s Ranking/PPW switch) a FULL-capability season '
  'lands on by default. Governed by the same scoring lock as every other '
  'field in this table (SS26.LOCK.13) -- editable before the season''s '
  'first scored result, read-only after, changeable afterward only via the '
  'privileged fn_revise_and_rescore_season (SS26.REVISION.09).';

-- SPWS-2026-2027 defaults to RANKING per design §06's season matrix. This is
-- an ordinary pre-lock write (the season carries zero scores -- confirmed by
-- scripts/check-scoring-migration-preflight.sh's SSP-06, and independently
-- by SS26.LOCK.01 already exercising this exact season as its "unlocked"
-- fixture), not a privileged one.
UPDATE tbl_scoring_config
   SET enum_default_ranking_mode = 'RANKING'
 WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027');

-- -----------------------------------------------------------------------------
-- fn_export_scoring_config -- add default_ranking_mode. Full redefinition
-- (CREATE OR REPLACE requires the complete body); every other key is
-- unchanged from 20260919000005's version.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_export_scoring_config(p_id_season INT)
RETURNS JSONB
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT jsonb_build_object(
    'id_season',                sc.id_season,
    'season_code',              s.txt_code,
    'engine_code',               se.txt_code,
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
    'default_ranking_mode',     sc.enum_default_ranking_mode,
    'extra',                    sc.json_extra,
    'scoring_admin_locked',     s.ts_scoring_locked_at IS NOT NULL,
    'scoring_locked_at',        s.ts_scoring_locked_at
  )
  FROM tbl_scoring_config sc
  JOIN tbl_season s ON s.id_season = sc.id_season
  LEFT JOIN tbl_scoring_engine se ON se.id_engine = s.id_scoring_engine
  WHERE sc.id_season = p_id_season;
$$;

-- -----------------------------------------------------------------------------
-- fn_guard_scoring_config_write -- direct-write trigger backstop gains the
-- same one-line check as every other governed column.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_guard_scoring_config_write()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE v_locked BOOLEAN;
BEGIN
  IF current_user <> 'authenticated' THEN
    RETURN NEW;
  END IF;

  SELECT ts_scoring_locked_at IS NOT NULL INTO v_locked
    FROM tbl_season WHERE id_season = NEW.id_season;
  IF NOT v_locked THEN
    RETURN NEW;
  END IF;

  IF NEW.int_mp_value               IS DISTINCT FROM OLD.int_mp_value               THEN PERFORM fn_raise_scoring_locked(NEW.id_season, 'mp_value'); END IF;
  IF NEW.int_podium_gold            IS DISTINCT FROM OLD.int_podium_gold            THEN PERFORM fn_raise_scoring_locked(NEW.id_season, 'podium_gold'); END IF;
  IF NEW.int_podium_silver          IS DISTINCT FROM OLD.int_podium_silver          THEN PERFORM fn_raise_scoring_locked(NEW.id_season, 'podium_silver'); END IF;
  IF NEW.int_podium_bronze          IS DISTINCT FROM OLD.int_podium_bronze          THEN PERFORM fn_raise_scoring_locked(NEW.id_season, 'podium_bronze'); END IF;
  IF NEW.num_ppw_multiplier         IS DISTINCT FROM OLD.num_ppw_multiplier         THEN PERFORM fn_raise_scoring_locked(NEW.id_season, 'ppw_multiplier'); END IF;
  IF NEW.num_mpw_multiplier         IS DISTINCT FROM OLD.num_mpw_multiplier         THEN PERFORM fn_raise_scoring_locked(NEW.id_season, 'mpw_multiplier'); END IF;
  IF NEW.num_pew_multiplier         IS DISTINCT FROM OLD.num_pew_multiplier         THEN PERFORM fn_raise_scoring_locked(NEW.id_season, 'pew_multiplier'); END IF;
  IF NEW.num_mew_multiplier         IS DISTINCT FROM OLD.num_mew_multiplier         THEN PERFORM fn_raise_scoring_locked(NEW.id_season, 'mew_multiplier'); END IF;
  IF NEW.num_msw_multiplier         IS DISTINCT FROM OLD.num_msw_multiplier         THEN PERFORM fn_raise_scoring_locked(NEW.id_season, 'msw_multiplier'); END IF;
  IF NEW.num_psw_multiplier         IS DISTINCT FROM OLD.num_psw_multiplier         THEN PERFORM fn_raise_scoring_locked(NEW.id_season, 'psw_multiplier'); END IF;
  IF NEW.num_pps_multiplier         IS DISTINCT FROM OLD.num_pps_multiplier         THEN PERFORM fn_raise_scoring_locked(NEW.id_season, 'pps_multiplier'); END IF;
  IF NEW.num_mps_multiplier         IS DISTINCT FROM OLD.num_mps_multiplier         THEN PERFORM fn_raise_scoring_locked(NEW.id_season, 'mps_multiplier'); END IF;
  IF NEW.int_min_participants_evf   IS DISTINCT FROM OLD.int_min_participants_evf   THEN PERFORM fn_raise_scoring_locked(NEW.id_season, 'min_participants_evf'); END IF;
  IF NEW.int_min_participants_ppw   IS DISTINCT FROM OLD.int_min_participants_ppw   THEN PERFORM fn_raise_scoring_locked(NEW.id_season, 'min_participants_ppw'); END IF;
  IF NEW.json_ranking_rules         IS DISTINCT FROM OLD.json_ranking_rules         THEN PERFORM fn_raise_scoring_locked(NEW.id_season, 'ranking_rules'); END IF;
  IF NEW.enum_default_ranking_mode  IS DISTINCT FROM OLD.enum_default_ranking_mode  THEN PERFORM fn_raise_scoring_locked(NEW.id_season, 'default_ranking_mode'); END IF;

  RETURN NEW;
END;
$$;

-- -----------------------------------------------------------------------------
-- fn_apply_scoring_config_write -- the unconditional write mechanics (shared
-- by fn_import_scoring_config's guarded path and fn_revise_and_rescore_
-- season's privileged path) gain the same field, unconditionally applied
-- like everything else here -- this function carries no lock check of its
-- own by design (ADR-097 §4).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_apply_scoring_config_write(p_config JSONB)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_season INT := (p_config->>'id_season')::INT;
  v_new_engine_id INT;
BEGIN
  IF p_config->>'engine_code' IS NOT NULL THEN
    SELECT id_engine INTO v_new_engine_id
      FROM tbl_scoring_engine WHERE txt_code = p_config->>'engine_code';
    IF v_new_engine_id IS NULL THEN
      RAISE EXCEPTION 'Unknown scoring engine: %', p_config->>'engine_code';
    END IF;
    UPDATE tbl_season SET id_scoring_engine = v_new_engine_id WHERE id_season = v_season;
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
    json_ranking_rules, enum_default_ranking_mode, json_extra,
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
    COALESCE((p_config->>'default_ranking_mode')::enum_ranking_mode, 'PPW'::enum_ranking_mode),
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
    json_ranking_rules            = COALESCE(NULLIF(p_config->'ranking_rules', 'null'::jsonb), tbl_scoring_config.json_ranking_rules),
    enum_default_ranking_mode     = COALESCE((p_config->>'default_ranking_mode')::enum_ranking_mode, tbl_scoring_config.enum_default_ranking_mode),
    json_extra                    = COALESCE(p_config->'extra',                          tbl_scoring_config.json_extra),
    ts_updated                    = NOW();
END;
$$;

COMMENT ON FUNCTION fn_apply_scoring_config_write(JSONB) IS
  'Unconditional COALESCE-over-current write into tbl_scoring_config plus '
  'engine_code resolution onto tbl_season. No lock check -- callers decide '
  'separately whether reaching this point is allowed. Never expose to '
  'authenticated: this is the one function in the scoring-config write path '
  'with no lock check of its own.';

-- -----------------------------------------------------------------------------
-- fn_import_scoring_config -- field-level guard gains one more governed
-- field, following the exact COALESCE-then-compare pattern every other field
-- already uses. Full redefinition; write mechanics are unchanged (still
-- delegated to fn_apply_scoring_config_write).
-- -----------------------------------------------------------------------------
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

  PERFORM fn_apply_scoring_config_write(p_config);
END;
$$;
