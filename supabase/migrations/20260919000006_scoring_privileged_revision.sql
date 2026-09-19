-- =============================================================================
-- Privileged audited whole-season revision/rescore procedure
-- =============================================================================
-- Design step 3b, second half. doc/plans/scoring-governance-lock-2026-09-19.html
-- §07/§09. Closes SS26.REVISION.01-08. Depends on 20260919000005 for the
-- schema (tbl_scoring_config_revision, ts_scoring_locked_at) and the
-- role-based trigger-bypass mechanism.
--
-- WHAT THIS MIGRATION DOES.
--
-- The prior migration closed ordinary Admin editing the moment a season
-- scores its first result. This migration adds the one authorized way past
-- that lock: fn_revise_and_rescore_season, an operator procedure reachable
-- only as postgres/service_role (docker exec / scripts/cloud-sql.sh),
-- never through PostgREST -- REVOKEd from authenticated as well as anon,
-- unlike every other function in this codebase. It applies a new
-- configuration with no lock check (it IS the authorized exception),
-- records an append-only revision row, rescores every already-scored
-- tournament in the season under the new configuration, and asserts before
-- returning that every result now references the new revision -- a
-- violation raises, rolling back the whole call including the activation.
--
-- SHARED WRITE PATH, NOT A SECOND COPY.
--
-- fn_import_scoring_config's field-level guard (20260919000005) is a
-- gatekeeper wrapped around one big COALESCE-over-current UPSERT into
-- tbl_scoring_config plus engine_code resolution onto tbl_season. This
-- migration extracts that UPSERT into fn_apply_scoring_config_write, which
-- carries no lock check of its own -- fn_import_scoring_config calls it only
-- after its own guard passes, and fn_revise_and_rescore_season calls it
-- directly, skipping the guard entirely by design. The alternative -- a
-- second overload of fn_import_scoring_config, or duplicating the ~20-field
-- statement inline here -- was rejected: this codebase already hit and fixed
-- exactly this class of drift once (ADR-096 §2, two independently-drifting
-- copies of the tournament-code formula), and a locked-out field that only
-- one of two copies remembers to accept would be a silent, security-relevant
-- gap. fn_apply_scoring_config_write is REVOKEd from authenticated as well as
-- PUBLIC/anon (defense in depth: it has no lock check, so if it were ever
-- reachable via PostgREST it would be a bypass) even though nothing grants
-- it in the first place under ADR-083's deny-by-default default privileges.
--
-- NO SESSION FLAG NEEDED FOR THE TRIGGER BYPASS.
--
-- The plan's §07 draft described a session-local GUC
-- (app.privileged_revision) the two trigger guards would check. That never
-- shipped: 20260919000005 redesigned the guards to check current_user <>
-- 'authenticated' instead (see that migration's own header for the two dead
-- ends tried first). fn_revise_and_rescore_season is SECURITY DEFINER, owned
-- by postgres like every other privileged function here, so its own writes
-- to tbl_scoring_config and tbl_scoring_type_config (via
-- fn_sync_scoring_type_config's trigger) already execute as current_user =
-- 'postgres' -- the same mechanism that already lets fn_import_scoring_config
-- and the five SECURITY DEFINER cascade-deletes through. No flag to set, no
-- flag to remember to reset.
-- =============================================================================

SET LOCAL lock_timeout = '2s';

-- -----------------------------------------------------------------------------
-- fn_apply_scoring_config_write -- the unconditional write mechanics,
-- extracted verbatim from fn_import_scoring_config's own INSERT/ON CONFLICT
-- block and engine_code branch below. No lock check here at all: the two
-- callers decide separately whether reaching this point is allowed.
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
    json_ranking_rules            = COALESCE(NULLIF(p_config->'ranking_rules', 'null'::jsonb), tbl_scoring_config.json_ranking_rules),
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
-- fn_import_scoring_config -- unchanged guard logic (field-level comparison,
-- engine_code lock check), but the actual write is now delegated to
-- fn_apply_scoring_config_write instead of an inline duplicate of it. The
-- engine_code branch keeps its lookup/raise-if-unknown/raise-if-locked-and-
-- different checks; the "apply the resolved value" step moves into the
-- shared helper, called unconditionally at the end alongside the rest of
-- the config.
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

-- -----------------------------------------------------------------------------
-- fn_revise_and_rescore_season -- the privileged, audited exception to the
-- lock. Reachable only as postgres/service_role.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_revise_and_rescore_season(
  p_id_season   INT,
  p_new_config  JSONB,   -- fn_import_scoring_config's shape (governed fields only)
  p_new_engine  TEXT,    -- NULL keeps the current engine
  p_reason      TEXT,    -- NOT NULL, non-empty
  p_actor       TEXT,    -- NOT NULL, non-empty -- no session identity exists to infer this from
  p_board_ref   TEXT DEFAULT NULL
)
RETURNS TABLE(id_revision INT, rescored_count INT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_engine_id     INT;
  v_config        JSONB;
  v_new_revision  INT;
  v_rescored      INT := 0;
  v_tournament    RECORD;
  v_bad_count     INT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM tbl_season WHERE id_season = p_id_season) THEN
    RAISE EXCEPTION 'Season % does not exist', p_id_season;
  END IF;
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'p_reason is required and must not be empty';
  END IF;
  IF p_actor IS NULL OR btrim(p_actor) = '' THEN
    RAISE EXCEPTION 'p_actor is required and must not be empty';
  END IF;

  -- Resolve p_new_engine to an EXISTING engine id -- this function never
  -- creates one. A new formula is a code change (a new released engine
  -- version), not something a data revision can conjure.
  IF p_new_engine IS NOT NULL THEN
    SELECT id_engine INTO v_engine_id
      FROM tbl_scoring_engine WHERE txt_code = p_new_engine;
    IF v_engine_id IS NULL THEN
      RAISE EXCEPTION 'Unknown scoring engine: %', p_new_engine;
    END IF;
  END IF;

  -- Apply the new config -- same COALESCE-over-current semantics as
  -- ordinary import, but through the lock-free write path: this function
  -- IS the authorized exception to the lock fn_import_scoring_config
  -- enforces for everyone else.
  v_config := p_new_config || jsonb_build_object('id_season', p_id_season);
  IF p_new_engine IS NOT NULL THEN
    v_config := v_config || jsonb_build_object('engine_code', p_new_engine);
  END IF;
  PERFORM fn_apply_scoring_config_write(v_config);

  -- New revision row, activated right after deactivating its sibling.
  -- Deliberately TWO sequential statements, not one WITH-CTE combining both:
  -- Postgres does not guarantee a data-modifying CTE's effects are visible
  -- to the main statement's own constraint checks within that same
  -- statement, and uq_scoring_config_revision_active (a partial unique
  -- index) reproducibly raised a duplicate-key violation here when both
  -- were combined -- the deactivating UPDATE and the activating INSERT must
  -- run as separate statements so the index sees them in order. One rescore
  -- pass below either way, not two.
  UPDATE tbl_scoring_config_revision
     SET bool_active = FALSE
   WHERE id_season = p_id_season AND bool_active;

  INSERT INTO tbl_scoring_config_revision
    (id_season, id_engine, json_snapshot, txt_actor, txt_reason, txt_board_ref, bool_active)
  VALUES (
    p_id_season,
    COALESCE(v_engine_id, (SELECT id_scoring_engine FROM tbl_season WHERE id_season = p_id_season)),
    fn_export_scoring_config(p_id_season),
    p_actor, p_reason, p_board_ref, TRUE
  )
  RETURNING tbl_scoring_config_revision.id_revision INTO v_new_revision;

  UPDATE tbl_season
     SET id_active_scoring_revision = v_new_revision
   WHERE id_season = p_id_season;

  -- Rescore every already-scored tournament -- fn_calc_tournament_scores
  -- stamps each touched result with whichever revision is CURRENTLY active,
  -- which is now the new one (activated above).
  FOR v_tournament IN
    SELECT t.id_tournament
      FROM tbl_tournament t
      JOIN tbl_event e ON e.id_event = t.id_event
     WHERE e.id_season = p_id_season
       AND t.enum_import_status = 'SCORED'
  LOOP
    PERFORM fn_calc_tournament_scores(v_tournament.id_tournament);
    v_rescored := v_rescored + 1;
  END LOOP;

  -- SS26.REVISION.06's invariant, asserted inline: no result in this season
  -- references any revision other than the new one. A mismatch raises --
  -- the whole transaction, including the activation above, rolls back
  -- (SS26.REVISION.07/.08).
  SELECT COUNT(*) INTO v_bad_count
    FROM tbl_result r
    JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
    JOIN tbl_event e ON e.id_event = t.id_event
   WHERE e.id_season = p_id_season
     AND r.id_scoring_revision IS NOT NULL
     AND r.id_scoring_revision <> v_new_revision;

  IF v_bad_count > 0 THEN
    RAISE EXCEPTION
      'Revision activation invariant violated: % result(s) in season % still reference a stale revision',
      v_bad_count, p_id_season;
  END IF;

  RETURN QUERY SELECT v_new_revision, v_rescored;
END;
$$;

COMMENT ON FUNCTION fn_revise_and_rescore_season(INT, JSONB, TEXT, TEXT, TEXT, TEXT) IS
  'The one function in this codebase revoked from authenticated as well as '
  'PUBLIC/anon -- reachable only as postgres/service_role, outside the web '
  'Admin session entirely (design doc §05''s "operator procedure outside '
  'Admin"). Bypasses the scoring-config lock by construction: applies the '
  'new configuration with no lock check, records an append-only revision, '
  'rescores every already-scored tournament, and asserts every result now '
  'references the new revision before returning -- a mismatch raises and '
  'the whole call (including the activation) rolls back atomically.';

-- -----------------------------------------------------------------------------
-- ADR-083 deny-by-default. CREATE OR REPLACE preserves fn_import_scoring_config's
-- existing grants; the other two are new objects.
-- -----------------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION fn_apply_scoring_config_write(JSONB) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION fn_revise_and_rescore_season(INT, JSONB, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
