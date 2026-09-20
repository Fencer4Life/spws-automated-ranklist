-- =============================================================================
-- Normalized per-type scoring policy
-- =============================================================================
-- Delivery step 3 (first half) of
-- doc/plans/versioned-season-scoring-and-pzsz-ranking-design.html.
-- Closes SS26.HIST.07 and SS26.TYPE.01-05.
--
-- WHY A TABLE INSTEAD OF SIX COLUMNS.
--
-- tbl_scoring_config carries one multiplier column per tournament type and two
-- minimum-participant columns for all six types between them. That shape has
-- three problems the design names:
--
--   1. Adding PPS and MPS means adding columns and editing every reader,
--      including a six-way CASE that has no ELSE and therefore writes a NULL
--      score for a type it does not list.
--   2. The threshold columns are NOT routed the way their names suggest. PSW is
--      domestic and gates on int_min_participants_ppw, so the Admin screen
--      labels a field "PPW" while it silently governs PSW as well (ADR-066,
--      python/pipeline/db_connector.py:590-594). Normalizing by NAME rather
--      than by the ACTUAL routing would retighten PSW from 1 to 5 in silence.
--   3. Per-season values genuinely differ — SPWS-2023-2024 has MEW 2.0 where
--      SPWS-2024-2025 has 1.2, and MSW moves 2.0 -> 1.2. A migration writing
--      column DEFAULTS instead of STORED values would rescore history.
--      SS26.HIST.07 and SS26.TYPE.01 exist to catch exactly that.
--
-- WHAT IS AUTHORITATIVE, AND WHAT IS NOT YET.
--
-- This table is the authority every READER uses: scoring resolves its multiplier
-- here (SS26.TYPE.05 proves it, by disagreeing with the legacy column on
-- purpose), and ingestion resolves its threshold here.
--
-- The ordinary WRITE surface is still tbl_scoring_config, because
-- fn_import_scoring_config is a single flat-JSONB upsert over those columns and
-- rewriting it is entangled with the governance lock — §05 requires the lock to
-- be FIELD-LEVEL authorization inside that one function, which is the second
-- half of step 3 and has its own acceptance group (SS26.LOCK.01-12). Until then
-- a trigger projects the columns onto this table on every write, so there is one
-- source of truth at read time rather than two that agree by luck.
-- =============================================================================

CREATE TABLE IF NOT EXISTS tbl_scoring_type_config (
  id_type_config       SERIAL PRIMARY KEY,
  id_config            INT NOT NULL REFERENCES tbl_scoring_config(id_config) ON DELETE CASCADE,
  enum_type            enum_tournament_type NOT NULL,
  num_multiplier       NUMERIC NOT NULL,
  int_min_participants INT NOT NULL,
  ts_created           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ts_updated           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (id_config, enum_type)
);

COMMENT ON TABLE tbl_scoring_type_config IS
  'Authoritative multiplier and minimum-participant threshold per scoring '
  'configuration and tournament type. Every reader resolves here. Adding a '
  'tournament type becomes a row, not a column plus an edit to every CASE.';
COMMENT ON COLUMN tbl_scoring_type_config.int_min_participants IS
  'Strict less-than gate: a bracket with fewer competitors than this is skipped '
  'at ingestion (ADR-066). Threshold 1 admits single-competitor walkovers.';

CREATE INDEX IF NOT EXISTS idx_scoring_type_config_config
  ON tbl_scoring_type_config (id_config);

-- -----------------------------------------------------------------------------
-- Project one configuration's legacy columns onto its normalized rows.
--
-- The VALUES list below is the ONE place the old shape's routing is written
-- down. Note that the threshold column is chosen by ADR-066's actual routing,
-- not by matching names: PSW is domestic and takes the _ppw threshold.
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
        ('MSW', c.num_msw_multiplier, c.int_min_participants_evf)
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
  '{PEW,MEW,MSW} -> evf), which is NOT what the column names suggest.';

CREATE OR REPLACE FUNCTION fn_sync_scoring_type_config_trg()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM fn_sync_scoring_type_config(NEW.id_config);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_scoring_type_config ON tbl_scoring_config;
CREATE TRIGGER trg_sync_scoring_type_config
  AFTER INSERT OR UPDATE ON tbl_scoring_config
  FOR EACH ROW EXECUTE FUNCTION fn_sync_scoring_type_config_trg();

-- -----------------------------------------------------------------------------
-- Backfill. Idempotent and extracted into a function for the same reason
-- fn_backfill_scoring_engines() is: `supabase db reset` applies migrations
-- BEFORE loading the seed dump, so on LOCAL this runs against an empty
-- tbl_scoring_config. The trigger above covers seeded rows as they are
-- inserted; this call covers CERT and PROD, where the rows already exist.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_backfill_scoring_type_config()
RETURNS VOID
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT id_config FROM tbl_scoring_config LOOP
    PERFORM fn_sync_scoring_type_config(r.id_config);
  END LOOP;
END;
$$;

SELECT fn_backfill_scoring_type_config();

-- -----------------------------------------------------------------------------
-- Readers. Both resolve from the normalized table and both fail closed.
--
-- fn_assert_type_configured is redefined here to read the new table rather than
-- the legacy CASE it used when it landed with the engine foundation. It keeps
-- its TEXT parameter so it still fails closed for a type that is not in the
-- enum at all — which is the state PPS and MPS are in until their own migration.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_assert_type_configured(p_id_season INT, p_type TEXT)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_multiplier NUMERIC;
BEGIN
  SELECT tc.num_multiplier INTO v_multiplier
    FROM tbl_scoring_type_config tc
    JOIN tbl_scoring_config c ON c.id_config = tc.id_config
   WHERE c.id_season = p_id_season AND tc.enum_type::TEXT = p_type;

  IF v_multiplier IS NULL THEN
    RAISE EXCEPTION
      'No scoring configuration for tournament type % in season %. Refusing to write a NULL score.',
      p_type, p_id_season;
  END IF;

  RETURN v_multiplier;
END;
$$;

-- The fail-closed threshold gate §07 requires. It replaces a Python helper that
-- returned 1 — include everything — for an unrecognised type AND for a season
-- with no configuration at all. Both of those are failing OPEN: a missing
-- configuration let every bracket through instead of stopping it, and
-- derive_tourn_type_from_event_code returns None for an unmatched event code,
-- which landed on the same fallback. Putting the rule here rather than in Python
-- means the routing is written down once and both callers obey it.
CREATE OR REPLACE FUNCTION fn_get_min_participants(p_id_season INT, p_type TEXT)
RETURNS INT
LANGUAGE plpgsql
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_threshold INT;
BEGIN
  SELECT tc.int_min_participants INTO v_threshold
    FROM tbl_scoring_type_config tc
    JOIN tbl_scoring_config c ON c.id_config = tc.id_config
   WHERE c.id_season = p_id_season AND tc.enum_type::TEXT = p_type;

  IF v_threshold IS NULL THEN
    RAISE EXCEPTION
      'No scoring configuration for tournament type % in season %. Refusing to admit a bracket ungated.',
      p_type, p_id_season;
  END IF;

  RETURN v_threshold;
END;
$$;

COMMENT ON FUNCTION fn_get_min_participants(INT, TEXT) IS
  'Per-season, per-type minimum-participant threshold (ADR-066). Raises rather '
  'than defaulting, so a type with no configured settings stops ingestion '
  'instead of being admitted ungated. Called from Python via PostgREST so the '
  'routing and the fail-closed rule live in exactly one place.';

-- -----------------------------------------------------------------------------
-- ADR-083 deny-by-default. Every table in schema public needs RLS (52.1), and
-- Postgres grants EXECUTE on a new function to PUBLIC unless told otherwise,
-- which 52.7 asserts as a set EQUALITY.
--
-- fn_get_min_participants is called by the ingestion pipeline, which
-- authenticates with the service role, so it does NOT need an anon grant.
-- -----------------------------------------------------------------------------
ALTER TABLE tbl_scoring_type_config ENABLE ROW LEVEL SECURITY;

REVOKE EXECUTE ON FUNCTION fn_sync_scoring_type_config(INT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_sync_scoring_type_config_trg() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_backfill_scoring_type_config() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_get_min_participants(INT, TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_assert_type_configured(INT, TEXT) FROM PUBLIC, anon;
