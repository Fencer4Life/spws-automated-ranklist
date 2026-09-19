-- =============================================================================
-- Scoring governance lock — schema, revision history, ordinary enforcement
-- =============================================================================
-- Design step 3b, first half. doc/plans/scoring-governance-lock-2026-09-19.html
-- Closes SS26.LOCK.01-10 (SS26.LOCK.11-12 are Vitest, frontend-only).
--
-- WHAT THIS MIGRATION DOES.
--
-- Today, ordinary Admin editing of scoring configuration is stopped only by
-- the client hiding a button when dt_end is in the past (SeasonManager.svelte
-- :264-266). Nothing on the server enforces anything. This migration makes
-- the boundary real: the moment a season's FIRST result is scored -- not its
-- start or end date -- fn_import_scoring_config starts rejecting changes to
-- every governed field, a trigger backstops direct table writes, and an
-- append-only revision table starts recording which configuration produced
-- which stored score.
--
-- FIELD-LEVEL, NOT WHOLE-FUNCTION.
--
-- fn_import_scoring_config is a single flat-JSONB upsert. A whole-function
-- guard would also block a legitimate, always-permitted edit: App.svelte
-- :1169-1197 handleUpdateSeason resends the ENTIRE config with only
-- show_evf_toggle/show_evf_toggle_calendar changed, every time an operator
-- flips the +EVF switch. Verified by reading that call site, not assumed.
-- So the guard compares each governed field's RESOLVED new value against
-- the CURRENTLY STORED one and raises only when they differ while the
-- season is locked -- an unchanged resend of a locked field is not a
-- violation, and the two toggles plus json_extra are never checked at all.
--
-- DEFENSE IN DEPTH, ROLE-BASED.
--
-- A BEFORE UPDATE trigger on tbl_scoring_config repeats the same OLD-vs-NEW
-- comparison for any writer that bypasses the RPC entirely. A second trigger
-- on tbl_scoring_type_config rejects every direct INSERT/UPDATE -- that
-- table has been trigger-owned since 20260919000002 and was never a write
-- surface at all, locked season or not. Both check current_user, not a
-- session flag: fn_import_scoring_config is SECURITY DEFINER, so its own
-- write (and everything it triggers, including the type-config projection)
-- executes as the function owner, never as the calling role, while a raw
-- PostgREST PATCH bypassing the RPC genuinely runs as `authenticated` with
-- no escalation. Checking current_user <> 'authenticated' therefore lets
-- through pgTAP fixtures, migrations, every SECURITY DEFINER cascade-delete
-- of tbl_scoring_config (five call sites, none needed touching) and the
-- privileged revision procedure (next migration) alike, with no flag to
-- remember to set anywhere -- see §06 of the plan for the two dead ends
-- (a session GUC; scoping to authenticated at all) tried before this.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Schema
-- -----------------------------------------------------------------------------
SET LOCAL lock_timeout = '2s';

CREATE TABLE IF NOT EXISTS tbl_scoring_config_revision (
  id_revision    SERIAL PRIMARY KEY,
  id_season      INT NOT NULL REFERENCES tbl_season(id_season),
  id_engine      INT NOT NULL REFERENCES tbl_scoring_engine(id_engine),
  json_snapshot  JSONB NOT NULL,
  ts_effective   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  txt_actor      TEXT NOT NULL,
  txt_reason     TEXT NOT NULL,
  txt_board_ref  TEXT,
  bool_active    BOOLEAN NOT NULL DEFAULT FALSE
);

COMMENT ON TABLE tbl_scoring_config_revision IS
  'Append-only audit snapshot of engine selection, multipliers, thresholds and '
  'ranking rules, one row per configuration revision a season has ever had. '
  'The first row is created automatically at first scoring (reason ''initial '
  '-- first scored result''); every row after that is created only by the '
  'privileged fn_revise_and_rescore_season. Never UPDATEd or DELETEd.';
COMMENT ON COLUMN tbl_scoring_config_revision.txt_actor IS
  'Who made this revision. An explicit required parameter, not derived from '
  'session identity -- this codebase has no auth.uid()/role table; every '
  'Admin RPC shares one authenticated login (verified: zero auth.uid() call '
  'sites in supabase/migrations/*.sql).';

CREATE UNIQUE INDEX IF NOT EXISTS uq_scoring_config_revision_active
  ON tbl_scoring_config_revision (id_season) WHERE bool_active;

ALTER TABLE tbl_season
  ADD COLUMN IF NOT EXISTS ts_scoring_locked_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS id_active_scoring_revision INT
    REFERENCES tbl_scoring_config_revision(id_revision);

COMMENT ON COLUMN tbl_season.ts_scoring_locked_at IS
  'Evidence ordinary Admin editing has crossed its boundary. Set once, '
  'transactionally, by the season''s first successful fn_calc_tournament_scores '
  'call. Never cleared, including by the privileged revision procedure.';
COMMENT ON COLUMN tbl_season.id_active_scoring_revision IS
  'The one revision every new score is stamped with. NULL until the season''s '
  'first score creates the initial revision.';

ALTER TABLE tbl_result
  ADD COLUMN IF NOT EXISTS id_scoring_revision INT
    REFERENCES tbl_scoring_config_revision(id_revision);

COMMENT ON COLUMN tbl_result.id_scoring_revision IS
  'Which configuration revision produced this stored score. Written only by '
  'fn_calc_tournament_scores, from the season''s currently active revision.';

-- tbl_result_draft mirrors every tbl_result column column-for-column (27.6:
-- "tbl_result_draft mirrors tbl_result + txt_run_id" in
-- supabase/tests/27_draft_tables.sql, which already holds mirrors of every
-- other scoring column -- num_place_pts, num_de_bonus, num_final_score,
-- ts_points_calc). Always NULL pre-promotion: scoring, and therefore a
-- revision stamp, happens only after a draft row is promoted into
-- tbl_result and fn_calc_tournament_scores runs against it.
--
-- NO REFERENCES here, deliberately, unlike the live column above:
-- 27_draft_tables.sql's own 27.10 asserts tbl_result_draft carries ZERO FK
-- constraints at all ("drafts can stage unresolved id_fencer") -- draft rows
-- are allowed to be provisional/unresolved before validation, and every
-- other mirrored column on this table is similarly unconstrained.
ALTER TABLE tbl_result_draft
  ADD COLUMN IF NOT EXISTS id_scoring_revision INT;

ALTER TABLE tbl_scoring_config_revision ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- Backfill: seasons already carrying scored results are locked administratively,
-- with an initial revision synthesized from their current stored configuration
-- and ts_scoring_locked_at taken from the EARLIEST surviving ts_points_calc in
-- that season, per design §05 -- not NOW(), so the audit trail reflects when
-- scoring actually happened.
--
-- Unlike fn_backfill_scoring_engines, this one needs NO companion call in
-- supabase/seed_post_backfill.sql. `supabase db reset` applies migrations
-- BEFORE the seed loads, so on LOCAL this runs against an empty tbl_result
-- and locks nothing -- but seed_post_backfill.sql's own 777-tournament
-- rescore loop then calls fn_calc_tournament_scores per tournament, which
-- now calls fn_ensure_active_scoring_revision as an ordinary side effect of
-- scoring: each LOCAL season gets its revision 1 and its lock the same way
-- a genuinely new season would, through the normal path, no special-casing
-- needed. This function's "earliest ts_points_calc" precision is what CERT
-- and PROD need, where real historical scoring timestamps already exist
-- when this migration runs there -- exactly what the migration-time call
-- below is for.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_backfill_scoring_lock()
RETURNS VOID
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  r RECORD;
  v_revision INT;
BEGIN
  FOR r IN
    SELECT s.id_season, s.id_scoring_engine, MIN(res.ts_points_calc) AS earliest_score
      FROM tbl_season s
      JOIN tbl_event e ON e.id_season = s.id_season
      JOIN tbl_tournament t ON t.id_event = e.id_event
      JOIN tbl_result res ON res.id_tournament = t.id_tournament
     WHERE res.ts_points_calc IS NOT NULL
       AND s.ts_scoring_locked_at IS NULL
       AND s.id_scoring_engine IS NOT NULL
     GROUP BY s.id_season, s.id_scoring_engine
  LOOP
    INSERT INTO tbl_scoring_config_revision
      (id_season, id_engine, json_snapshot, txt_actor, txt_reason, bool_active)
    VALUES (
      r.id_season, r.id_scoring_engine,
      fn_export_scoring_config(r.id_season),
      'migration:20260919000005',
      'initial -- backfilled from configuration already stored at migration time',
      TRUE
    )
    RETURNING id_revision INTO v_revision;

    UPDATE tbl_season
       SET ts_scoring_locked_at = r.earliest_score,
           id_active_scoring_revision = v_revision
     WHERE id_season = r.id_season;

    UPDATE tbl_result res
       SET id_scoring_revision = v_revision
      FROM tbl_tournament t, tbl_event e
     WHERE res.id_tournament = t.id_tournament
       AND t.id_event = e.id_event
       AND e.id_season = r.id_season
       AND res.ts_points_calc IS NOT NULL
       AND res.id_scoring_revision IS NULL;
  END LOOP;
END;
$$;

COMMENT ON FUNCTION fn_backfill_scoring_lock() IS
  'Idempotent. Locks every season that already has a scored result and has '
  'no lock yet, synthesizing its initial revision from currently-stored '
  'configuration. See fn_backfill_scoring_engines for why this is split out '
  'of the migration body (seed loads AFTER migrations on `supabase db reset`).';

SELECT fn_backfill_scoring_lock();

-- -----------------------------------------------------------------------------
-- fn_ensure_active_scoring_revision — called once per scoring operation.
-- Idempotent: a season with an active revision already returns it unchanged.
-- A season with none gets one created from its CURRENT stored configuration,
-- and is locked in the same statement that creates it.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_ensure_active_scoring_revision(p_id_season INT)
RETURNS INT
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_revision INT;
  v_engine   INT;
BEGIN
  SELECT id_active_scoring_revision INTO v_revision
    FROM tbl_season WHERE id_season = p_id_season;
  IF v_revision IS NOT NULL THEN
    RETURN v_revision;
  END IF;

  SELECT id_scoring_engine INTO v_engine FROM tbl_season WHERE id_season = p_id_season;
  IF v_engine IS NULL THEN
    RAISE EXCEPTION
      'Unknown scoring engine: season % has no engine assigned. An engine is assigned deliberately, never inferred.',
      p_id_season;
  END IF;

  INSERT INTO tbl_scoring_config_revision
    (id_season, id_engine, json_snapshot, txt_actor, txt_reason, bool_active)
  VALUES (
    p_id_season, v_engine, fn_export_scoring_config(p_id_season),
    'system:fn_calc_tournament_scores',
    'initial -- first scored result',
    TRUE
  )
  RETURNING id_revision INTO v_revision;

  UPDATE tbl_season
     SET id_active_scoring_revision = v_revision,
         ts_scoring_locked_at = COALESCE(ts_scoring_locked_at, NOW())
   WHERE id_season = p_id_season;

  RETURN v_revision;
END;
$$;

COMMENT ON FUNCTION fn_ensure_active_scoring_revision(INT) IS
  'The season''s first score creates its initial revision and locks it, '
  'transactionally, in the same call. Every later score reuses the same '
  'revision id until a privileged whole-season revision replaces it.';

-- -----------------------------------------------------------------------------
-- fn_calc_tournament_scores — stamp every scored result with the season's
-- active revision. Everything else about the dispatcher is unchanged.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_calc_tournament_scores(p_tournament_id INT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  p RECORD;
  v_season   INT;
  v_revision INT;
BEGIN
  SELECT * INTO p FROM fn_resolve_scoring_params(p_tournament_id);

  SELECT e.id_season INTO v_season
    FROM tbl_tournament t JOIN tbl_event e ON e.id_event = t.id_event
   WHERE t.id_tournament = p_tournament_id;

  v_revision := fn_ensure_active_scoring_revision(v_season);

  UPDATE tbl_result r
     SET num_place_pts     = ROUND(c.num_place_pts, 2),
         num_de_bonus      = ROUND(c.num_de_bonus, 2),
         num_podium_bonus  = ROUND(c.num_podium_bonus, 2),
         -- Rounded ONCE, from the raw terms, exactly as before this migration.
         num_final_score   = ROUND(
           (c.num_place_pts + c.num_de_bonus + c.num_podium_bonus) * p.multiplier, 2),
         ts_points_calc    = NOW(),
         id_scoring_revision = v_revision
    FROM (
      SELECT r2.id_result, (x.comp).*
        FROM tbl_result r2
        CROSS JOIN LATERAL (
          SELECT fn_score_by_engine(
                   p.engine_code, p.n, r2.int_place, p.mp_value, p.base_slope,
                   p.de_round, p.podium_gold, p.podium_silver, p.podium_bronze) AS comp
        ) x
       WHERE r2.id_tournament = p_tournament_id
    ) c
   WHERE r.id_result = c.id_result;

  UPDATE tbl_tournament
     SET enum_import_status = 'SCORED',
         ts_updated = NOW()
   WHERE id_tournament = p_tournament_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- fn_export_scoring_config — add engine_code and the two server-authority
-- fields §05 requires the season/config API to expose. engine_code was
-- entirely absent from this JSONB before; the frontend previously had no way
-- to read or round-trip the scoring engine at all.
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
-- fn_import_scoring_config — field-level authorization. Governed fields
-- reject a CHANGE while locked; an unchanged resend (the toggle-only save
-- path) and the two toggles/json_extra always succeed. engine_code is new:
-- writes tbl_season.id_scoring_engine from inside the same call, since the
-- scoring engine is governed by this same lock and design §03 forbids ever
-- reusing the carry-over engine's own separate, always-editable write path
-- for it.
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

  -- One evaluation per governed field: NEW value (COALESCE'd default applied,
  -- matching the INSERT branch below exactly) vs the CURRENTLY STORED value.
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

  -- v_current.id_config IS NOT NULL, not "v_current IS NOT NULL": Postgres
  -- composite-row NULL tests require EVERY field non-null to read as "not
  -- null" (SQL standard row-comparison semantics). json_ranking_rules is
  -- legitimately NULL for a legacy-mode season (SPWS-2023-2024, no JSONB
  -- buckets), which silently made "v_current IS NOT NULL" false for a row
  -- that plainly exists -- caught by manual reproduction, not by the test
  -- suite: SS26.LOCK.02 reported "OK" (not rejected) for every field on a
  -- season confirmed locked, because this whole guard block was never
  -- entered. id_config is the PK and is never null when a row exists.
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
    -- NULLIF(..., 'null'::jsonb): jsonb_build_object('ranking_rules', x)
    -- turns a SQL NULL x into the JSON VALUE null, not an absent key. A
    -- caller resending fn_export_scoring_config's own output unmodified
    -- (the toggle-only save path, handleUpdateSeason) would otherwise
    -- COALESCE past the real stored NULL every time, since JSON null is
    -- non-SQL-NULL and therefore "present" to COALESCE. Found via
    -- SS26.LOCK.07 raising on an unmodified resend -- not new to this
    -- lock, but this is the first path that round-trips the value through
    -- fn_export_scoring_config and back and therefore the first to expose it.
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

  -- engine_code: governed the same way, but lives on tbl_season, not
  -- tbl_scoring_config, so it is resolved and checked separately.
  --
  -- `->>` (not `?`) IS NOT NULL: the same JSON-null-vs-absent-key gap as
  -- ranking_rules above, hitting a different symptom. fn_export_scoring_config
  -- LEFT JOINs tbl_scoring_engine, so a season with NO engine assigned
  -- round-trips engine_code as a PRESENT key holding JSON null. `?` only
  -- checks key existence and would try to resolve that null into an engine,
  -- raising "Unknown scoring engine: <NULL>" on every resave of such a
  -- season -- caught by 42_min_participants_threshold.sql, an unrelated
  -- pre-existing test that happens to resend an exported config for a
  -- scratch season it never assigned an engine to. `->>` already converts
  -- JSON null to SQL NULL, so IS NOT NULL correctly reads it as "no change
  -- requested", matching what an unmodified resend means everywhere else.
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
    ELSE
      UPDATE tbl_season SET id_scoring_engine = v_new_engine_id WHERE id_season = v_season;
    END IF;
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
    -- NULLIF: see the matching comment on v_rules above -- the same
    -- JSON-null-vs-SQL-NULL gap applies to the actual stored value, not
    -- just the lock comparison, and predates this migration.
    json_ranking_rules            = COALESCE(NULLIF(p_config->'ranking_rules', 'null'::jsonb), tbl_scoring_config.json_ranking_rules),
    json_extra                    = COALESCE(p_config->'extra',                          tbl_scoring_config.json_extra),
    ts_updated                    = NOW();
END;
$$;

-- Shared exception text so the SQL message, the pgTAP throws_like patterns
-- and the frontend's stable-marker detection ("is locked") all agree.
CREATE OR REPLACE FUNCTION fn_raise_scoring_locked(p_id_season INT, p_field TEXT)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  RAISE EXCEPTION
    'Scoring configuration for season % is locked: cannot change "%" after the first scored result. Use the audited revision procedure.',
    p_id_season, p_field;
END;
$$;

-- -----------------------------------------------------------------------------
-- Trigger guards (defense in depth) -- ROLE-BASED, not a session flag.
--
-- fn_import_scoring_config is SECURITY DEFINER, so its own internal UPDATE
-- (and anything IT triggers, including fn_sync_scoring_type_config's write)
-- executes as the function's OWNER (postgres), never as the calling role.
-- The one write these triggers actually need to catch -- a raw PostgREST
-- PATCH on tbl_scoring_config bypassing the RPC entirely -- runs with NO
-- SECURITY DEFINER escalation at all, so it genuinely executes as the
-- `authenticated` role. Checking current_user therefore distinguishes
-- exactly the case design §05 means by "direct browser/Admin table writes":
-- it fires for `authenticated`, and steps aside for everything that already
-- runs as postgres -- pgTAP fixtures, migrations, cascade deletes from
-- fn_delete_season/fn_revert_season_init/etc (all SECURITY DEFINER), the
-- projection trigger, and the privileged revision procedure alike. No
-- session-local flag needed anywhere. `anon` is not listed because RLS
-- already denies it write access to both tables before a trigger ever runs.
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

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_scoring_config_write ON tbl_scoring_config;
CREATE TRIGGER trg_guard_scoring_config_write
  BEFORE UPDATE ON tbl_scoring_config
  FOR EACH ROW EXECUTE FUNCTION fn_guard_scoring_config_write();

-- INSERT/UPDATE only -- not DELETE. Five different functions cascade-delete
-- tbl_scoring_config rows (fn_delete_season, fn_revert_season_init,
-- season-skeleton-promotion revert, fn_revert_guard_childless, the PROD
-- reconciler), which cascades into this table by FK; that is a legitimate
-- consequence of deleting the parent config, not a silent multiplier change,
-- and none of those five needed touching because they are all SECURITY
-- DEFINER and the role check above already lets them through. A row
-- deleted out from under a still-existing config is already caught
-- elsewhere: fn_get_min_participants/fn_assert_type_configured raise
-- "No scoring configuration for tournament type" the next time anything
-- reads it (SS26.TYPE.03, SS26.DB.05) -- fail-closed, not a silent gap.
CREATE OR REPLACE FUNCTION fn_guard_type_config_direct_write()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF current_user <> 'authenticated' THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION
    'tbl_scoring_type_config is not a direct write surface -- it is a projection owned by fn_sync_scoring_type_config. Edit tbl_scoring_config through fn_import_scoring_config instead.';
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_type_config_direct_write ON tbl_scoring_type_config;
CREATE TRIGGER trg_guard_type_config_direct_write
  BEFORE INSERT OR UPDATE ON tbl_scoring_type_config
  FOR EACH ROW EXECUTE FUNCTION fn_guard_type_config_direct_write();

-- fn_sync_scoring_type_config is unchanged from 20260919000004 -- it already
-- runs as SECURITY DEFINER context inherited from its trigger's caller, so
-- the role check above already lets it through with no changes needed here.
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

-- -----------------------------------------------------------------------------
-- SS26.LOCK.01/§05: the Admin scoring-engine selector needs to read the
-- released engine codes to populate its dropdown. tbl_scoring_engine has RLS
-- ENABLED since 20260919000001 with no policy yet defined -- default-deny,
-- so even `authenticated` currently gets zero rows. Only the Admin UI reads
-- this table (no public/anon surface needs it), so this matches the
-- "Admin read audit" idiom in 20250301000002_rls_policies.sql rather than
-- the unrestricted "Public read" ones. RLS is necessary but not sufficient:
-- tbl_scoring_engine was created after ADR-083 (20260723000001), whose
-- Block 6 revoked the default table GRANT postgres-created objects used to
-- pick up automatically, so an explicit GRANT is required too, matching the
-- GRANT SELECT ... TO anon, authenticated precedent that migration and later
-- ones (20260807000001, 20260902000001) already use for the same reason.
-- -----------------------------------------------------------------------------
CREATE POLICY "Admin read scoring engines" ON tbl_scoring_engine
  FOR SELECT USING (auth.role() = 'authenticated');
GRANT SELECT ON tbl_scoring_engine TO authenticated;

-- -----------------------------------------------------------------------------
-- ADR-083 deny-by-default. CREATE OR REPLACE preserves existing grants for
-- every redefined function; these are new objects only.
-- -----------------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION fn_ensure_active_scoring_revision(INT)  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_raise_scoring_locked(INT, TEXT)      FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_guard_scoring_config_write()         FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_guard_type_config_direct_write()     FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_backfill_scoring_lock()              FROM PUBLIC, anon;
