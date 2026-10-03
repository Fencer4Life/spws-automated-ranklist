-- =============================================================================
-- ADR-108 §4: the record of one CERT ingestion, which promote replays
-- =============================================================================
-- ingest-event.yml with target cert opens a tbl_ingest_run row before the
-- ingestion writes anything and closes it when the run ends. Promote reads it:
-- the commit to check out, the URL the run ingested, the hash of every source
-- listing, the input fingerprint PROD must still match, and the master-data
-- changes PROD's plan must repeat. The result fingerprint (build step 9) and
-- the gate outcome (build step 7) are written by those steps.
--
-- Fingerprints and changes are computed here, in SQL, never in Python, so CERT
-- and PROD compute them the same way:
--
--   fn_schema_fingerprint       scripts/schema-fingerprint.sh's query, over RPC
--   fn_event_input_fingerprint  what the ingestion reads, by person, never by id
--   fn_roster_snapshot          the roster as a run found it
--   fn_roster_changes           what changed between two snapshots
--
-- Service role only (ADR-083).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- The release's schema fingerprint
-- ---------------------------------------------------------------------------
-- The query is scripts/schema-fingerprint.sh's, unchanged (test_ingest_run.py
-- keeps the two identical). SECURITY DEFINER because information_schema shows
-- a routine's definition only to its owner: run as the service role, every
-- definition would read NULL and the fingerprint would describe nothing.
CREATE OR REPLACE FUNCTION fn_schema_fingerprint()
RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
WITH func_hash AS (
  SELECT md5(string_agg(
    coalesce(routine_name,'') || '|' || coalesce(routine_definition,''),
    E'\n' ORDER BY routine_name, routine_definition
  )) AS h
  FROM information_schema.routines
  WHERE routine_schema = 'public'
),
col_hash AS (
  SELECT md5(string_agg(
    table_name || '|' || column_name || '|' || data_type || '|' || coalesce(column_default,''),
    E'\n' ORDER BY table_name, ordinal_position
  )) AS h
  FROM information_schema.columns
  WHERE table_schema = 'public'
)
SELECT md5(coalesce(f.h,'') || coalesce(c.h,'')) AS schema_fingerprint
FROM func_hash f, col_hash c;
$$;

COMMENT ON FUNCTION fn_schema_fingerprint() IS
  'ADR-108 §4: scripts/schema-fingerprint.sh''s fingerprint, callable over RPC. Equal on CERT and PROD once both run the same migrations.';

-- ---------------------------------------------------------------------------
-- What the ingestion of one event reads
-- ---------------------------------------------------------------------------
-- One part per input, each a hash, so a refusal can name the part that moved:
--   schema         fn_schema_fingerprint()
--   roster         every fencer, every column the CERT refresh copies (all but
--                  the id and the timestamps)
--   registrations  the event's entries, the columns the CERT refresh copies,
--                  the fencer link as that fencer's name and birth year
--   season         the season's dates and engines, its scoring settings and
--                  per-type settings, engines by code. Not the display
--                  switches (the EVF toggles, the default ranking mode).
--   lock           'locked' or 'unlocked'. Its own part because the season's
--                  first scored result locks it (fn_ensure_active_scoring_revision):
--                  the ingestion of a season's first event changes it, so a
--                  CERT re-run starts locked while PROD is not. How promote
--                  compares it is build step 7's to decide.
--   event          code, dates, season, previous edition, the admin's
--                  skip/process choices. Not the event URL: promote writes
--                  CERT's URL on PROD.
-- jsonb text is canonical and its dates are ISO whatever the session's
-- DateStyle; no timestamp is hashed, so the time zone changes nothing.
CREATE OR REPLACE FUNCTION fn_event_input_fingerprint(p_event_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql STABLE
SET search_path = public
AS $$
DECLARE
  v_event tbl_event%ROWTYPE;
  v_parts JSONB;
BEGIN
  SELECT * INTO v_event FROM tbl_event WHERE txt_code = p_event_code;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'INGEST_RUN_EVENT_NOT_FOUND: %', p_event_code;
  END IF;

  v_parts := jsonb_build_object(
    'schema', fn_schema_fingerprint(),

    'roster', (
      SELECT encode(sha256(convert_to(COALESCE(string_agg(j, E'\n' ORDER BY j), ''), 'UTF8')), 'hex')
        FROM (SELECT (to_jsonb(f) - 'id_fencer' - 'ts_created' - 'ts_updated')::TEXT AS j
                FROM tbl_fencer f) x),

    'registrations', (
      SELECT encode(sha256(convert_to(COALESCE(string_agg(j, E'\n' ORDER BY j), ''), 'UTF8')), 'hex')
        FROM (SELECT jsonb_build_object(
                       'surname', r.txt_surname, 'first_name', r.txt_first_name, 'gender', r.enum_gender,
                       'birth_year', r.int_birth_year, 'weapons', to_jsonb(r.arr_weapons),
                       'ftl_name', r.txt_ftl_name, 'club', r.txt_club,
                       'fencer', CASE WHEN f.id_fencer IS NOT NULL THEN
                                   jsonb_build_object('surname', f.txt_surname, 'first_name', f.txt_first_name,
                                                      'birth_year', f.int_birth_year) END)::TEXT AS j
                FROM tbl_registration r
                LEFT JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
               WHERE r.id_event = v_event.id_event) x),

    'season', (
      SELECT encode(sha256(convert_to(jsonb_build_object(
               'season', jsonb_build_object(
                  'code', s.txt_code, 'dt_start', s.dt_start, 'dt_end', s.dt_end,
                  'carryover_engine', s.enum_carryover_engine, 'carryover_days', s.int_carryover_days,
                  'european_event_type', s.enum_european_event_type, 'engine', se.txt_code),
               'config', (SELECT to_jsonb(c) - 'id_config' - 'id_season' - 'ts_created' - 'ts_updated'
                                 - 'bool_show_evf_toggle' - 'bool_show_evf_toggle_calendar'
                                 - 'enum_default_ranking_mode'
                            FROM tbl_scoring_config c WHERE c.id_season = s.id_season),
               'types', (SELECT COALESCE(jsonb_agg(jsonb_build_object(
                                   'type', t.enum_type, 'multiplier', t.num_multiplier,
                                   'min_participants', t.int_min_participants, 'engine', te.txt_code)
                                 ORDER BY t.enum_type), '[]'::JSONB)
                           FROM tbl_scoring_type_config t
                           JOIN tbl_scoring_config c ON c.id_config = t.id_config
                           LEFT JOIN tbl_scoring_engine te ON te.id_engine = t.id_scoring_engine
                          WHERE c.id_season = s.id_season))::TEXT, 'UTF8')), 'hex')
        FROM tbl_season s
        LEFT JOIN tbl_scoring_engine se ON se.id_engine = s.id_scoring_engine
       WHERE s.id_season = v_event.id_season),

    'lock', (SELECT CASE WHEN ts_scoring_locked_at IS NULL THEN 'unlocked' ELSE 'locked' END
               FROM tbl_season WHERE id_season = v_event.id_season),

    'event', (
      SELECT encode(sha256(convert_to(jsonb_build_object(
               'code', v_event.txt_code, 'dt_start', v_event.dt_start, 'dt_end', v_event.dt_end,
               'season', (SELECT txt_code FROM tbl_season WHERE id_season = v_event.id_season),
               'prior_event', (SELECT txt_code FROM tbl_event WHERE id_event = v_event.id_prior_event),
               'source_overrides', v_event.json_source_overrides)::TEXT, 'UTF8')), 'hex'))
  );

  RETURN jsonb_build_object(
    'fingerprint', (SELECT encode(sha256(convert_to(string_agg(key || '=' || COALESCE(value, ''), E'\n' ORDER BY key), 'UTF8')), 'hex')
                      FROM jsonb_each_text(v_parts)),
    'parts', v_parts);
END;
$$;

COMMENT ON FUNCTION fn_event_input_fingerprint(TEXT) IS
  'ADR-108 §4–§5: a hash of everything the ingestion of one event reads (schema, roster, the event''s registrations, the season''s scoring settings and lock, the event row), by person, never by id. {fingerprint, parts}.';

-- ---------------------------------------------------------------------------
-- The roster as a run found it, and what changed
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_roster_snapshot()
RETURNS JSONB
LANGUAGE sql STABLE
SET search_path = public
AS $$
  SELECT COALESCE(jsonb_agg(to_jsonb(f) - 'ts_created' - 'ts_updated' ORDER BY f.id_fencer), '[]'::JSONB)
    FROM tbl_fencer f;
$$;

COMMENT ON FUNCTION fn_roster_snapshot() IS
  'ADR-108 §4: every fencer, every column but the timestamps, by id. The before half of fn_roster_changes.';

-- Five lists, each ordered by fencer id: fencers created (with the id they got),
-- fencers deleted, birth years moved (or their estimated flag), aliases added,
-- and any other column that changed, an alias removed included. Pure, so
-- promote can compare PROD's changes with CERT's the same way.
CREATE OR REPLACE FUNCTION fn_roster_changes(p_before JSONB, p_after JSONB)
RETURNS JSONB
LANGUAGE sql IMMUTABLE
SET search_path = public
AS $$
  -- A NULL alias column reads as JSON null in a snapshot; it holds no alias.
  WITH b AS (SELECT (e->>'id_fencer')::INT AS id, e AS j,
                    CASE WHEN jsonb_typeof(e->'json_name_aliases') = 'array' THEN e->'json_name_aliases'
                         ELSE '[]'::JSONB END AS al
               FROM jsonb_array_elements(COALESCE(p_before, '[]'::JSONB)) e),
       a AS (SELECT (e->>'id_fencer')::INT AS id, e AS j,
                    CASE WHEN jsonb_typeof(e->'json_name_aliases') = 'array' THEN e->'json_name_aliases'
                         ELSE '[]'::JSONB END AS al
               FROM jsonb_array_elements(COALESCE(p_after, '[]'::JSONB)) e),
       p AS (SELECT b.id, b.j AS bj, a.j AS aj, b.al AS bal, a.al AS aal FROM b JOIN a USING (id)),
       o AS (SELECT p.id, p.aj,
                    (SELECT jsonb_agg(k ORDER BY k) FROM (
                       SELECT key AS k FROM jsonb_object_keys(p.bj || p.aj) key
                        WHERE key NOT IN ('int_birth_year', 'bool_birth_year_estimated', 'json_name_aliases')
                          AND p.bj->key IS DISTINCT FROM p.aj->key
                       UNION ALL
                       SELECT 'json_name_aliases' WHERE NOT (p.aal @> p.bal)) c) AS cols
               FROM p)
  SELECT jsonb_build_object(
    'created', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'id_fencer', a.id, 'surname', a.j->'txt_surname', 'first_name', a.j->'txt_first_name',
               'birth_year', a.j->'int_birth_year', 'estimated', a.j->'bool_birth_year_estimated',
               'gender', a.j->'enum_gender', 'aliases', a.al) ORDER BY a.id)
        FROM a WHERE NOT EXISTS (SELECT 1 FROM b WHERE b.id = a.id)), '[]'::JSONB),
    'deleted', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'id_fencer', b.id, 'surname', b.j->'txt_surname', 'first_name', b.j->'txt_first_name',
               'birth_year', b.j->'int_birth_year') ORDER BY b.id)
        FROM b WHERE NOT EXISTS (SELECT 1 FROM a WHERE a.id = b.id)), '[]'::JSONB),
    'birth_year_moved', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'id_fencer', p.id, 'surname', p.aj->'txt_surname', 'first_name', p.aj->'txt_first_name',
               'from', p.bj->'int_birth_year', 'to', p.aj->'int_birth_year',
               'estimated_from', p.bj->'bool_birth_year_estimated',
               'estimated_to', p.aj->'bool_birth_year_estimated') ORDER BY p.id)
        FROM p
       WHERE p.bj->'int_birth_year' IS DISTINCT FROM p.aj->'int_birth_year'
          OR p.bj->'bool_birth_year_estimated' IS DISTINCT FROM p.aj->'bool_birth_year_estimated'), '[]'::JSONB),
    'aliases_added', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'id_fencer', p.id, 'surname', p.aj->'txt_surname', 'first_name', p.aj->'txt_first_name',
               'alias', al) ORDER BY p.id, al)
        FROM p, jsonb_array_elements_text(p.aal) al
       WHERE NOT (p.bal ? al)), '[]'::JSONB),
    'other', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'id_fencer', o.id, 'surname', o.aj->'txt_surname', 'first_name', o.aj->'txt_first_name',
               'columns', o.cols) ORDER BY o.id)
        FROM o WHERE o.cols IS NOT NULL), '[]'::JSONB));
$$;

COMMENT ON FUNCTION fn_roster_changes(JSONB, JSONB) IS
  'ADR-108 §4: what changed between two fn_roster_snapshot arrays: {created, deleted, birth_year_moved, aliases_added, other}, each by fencer id.';

-- ---------------------------------------------------------------------------
-- The run record
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_ingest_run (
  id_ingest_run          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  txt_event_code         TEXT NOT NULL,
  txt_environment        TEXT NOT NULL CONSTRAINT ck_ingest_run_environment
                           CHECK (txt_environment IN ('local', 'cert')),
  txt_git_commit         TEXT NOT NULL CONSTRAINT ck_ingest_run_commit
                           CHECK (txt_git_commit ~ '^[0-9a-f]{40}$'),
  txt_run_url            TEXT,
  int_season_end_year    SMALLINT NOT NULL,
  url_event              TEXT NOT NULL,
  txt_override_sha256    TEXT CONSTRAINT ck_ingest_run_override_sha256
                           CHECK (txt_override_sha256 ~ '^[0-9a-f]{64}$'),
  txt_status             TEXT NOT NULL DEFAULT 'RUNNING' CONSTRAINT ck_ingest_run_status
                           CHECK (txt_status IN ('RUNNING', 'FINISHED', 'FAILED', 'ABANDONED')),
  txt_input_fingerprint  TEXT NOT NULL,
  jsonb_input_parts      JSONB NOT NULL,
  jsonb_roster_before    JSONB NOT NULL,
  jsonb_listings         JSONB,
  jsonb_master_data      JSONB,
  txt_result_fingerprint TEXT,
  jsonb_gate             JSONB,
  txt_error              TEXT,
  ts_started             TIMESTAMPTZ NOT NULL DEFAULT now(),
  ts_finished            TIMESTAMPTZ,
  CONSTRAINT ck_ingest_run_finished CHECK ((txt_status = 'RUNNING') = (ts_finished IS NULL))
);

CREATE INDEX IF NOT EXISTS idx_ingest_run_event ON tbl_ingest_run (txt_event_code, id_ingest_run DESC);

COMMENT ON TABLE tbl_ingest_run IS
  'ADR-108 §4: one row per recorded ingestion run (ingest-event.yml target cert, or LOCAL). Promote replays the latest FINISHED run of an event. txt_override_sha256 NULL means the event has no override file; txt_result_fingerprint and jsonb_gate are written by build steps 9 and 7.';

ALTER TABLE tbl_ingest_run ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON tbl_ingest_run FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE ON tbl_ingest_run TO service_role;

-- Opens a RUNNING row: the input fingerprint and the roster as the run finds
-- them, before it writes anything. A run of the same event in the same
-- environment still RUNNING is ABANDONED: two runs at once make neither
-- record trustworthy, and the older one can no longer finish.
CREATE OR REPLACE FUNCTION fn_ingest_run_open(
  p_event_code      TEXT,
  p_environment     TEXT,
  p_git_commit      TEXT,
  p_season_end_year INT,
  p_url_event       TEXT,
  p_run_url         TEXT DEFAULT NULL,
  p_override_sha256 TEXT DEFAULT NULL)
RETURNS BIGINT
LANGUAGE plpgsql VOLATILE
SET search_path = public
AS $$
DECLARE
  v_input JSONB;
  v_id    BIGINT;
BEGIN
  v_input := fn_event_input_fingerprint(p_event_code);

  INSERT INTO tbl_ingest_run (txt_event_code, txt_environment, txt_git_commit, txt_run_url, int_season_end_year,
                              url_event, txt_override_sha256, txt_input_fingerprint, jsonb_input_parts,
                              jsonb_roster_before)
  VALUES (p_event_code, p_environment, p_git_commit, p_run_url, p_season_end_year,
          p_url_event, p_override_sha256, v_input->>'fingerprint', v_input->'parts',
          fn_roster_snapshot())
  RETURNING id_ingest_run INTO v_id;

  UPDATE tbl_ingest_run
     SET txt_status = 'ABANDONED', ts_finished = now(),
         txt_error = format('run %s of the same event started before this one finished', v_id)
   WHERE txt_event_code = p_event_code AND txt_environment = p_environment
     AND txt_status = 'RUNNING' AND id_ingest_run <> v_id;

  RETURN v_id;
END;
$$;

-- Closes a RUNNING row as FINISHED or FAILED, with its listings and the
-- master-data changes since it opened. Returns the changes.
CREATE OR REPLACE FUNCTION fn_ingest_run_close(p_id BIGINT, p_status TEXT, p_listings JSONB, p_error TEXT)
RETURNS JSONB
LANGUAGE plpgsql VOLATILE
SET search_path = public
AS $$
DECLARE
  v_changes JSONB;
  v_status  TEXT;
BEGIN
  UPDATE tbl_ingest_run r
     SET txt_status = p_status, ts_finished = now(), jsonb_listings = p_listings, txt_error = p_error,
         jsonb_master_data = fn_roster_changes(r.jsonb_roster_before, fn_roster_snapshot())
   WHERE r.id_ingest_run = p_id AND r.txt_status = 'RUNNING'
  RETURNING r.jsonb_master_data INTO v_changes;

  IF NOT FOUND THEN
    SELECT txt_status INTO v_status FROM tbl_ingest_run WHERE id_ingest_run = p_id;
    RAISE EXCEPTION 'INGEST_RUN_NOT_RUNNING: run % is %', p_id, COALESCE(v_status, 'missing');
  END IF;
  RETURN v_changes;
END;
$$;

CREATE OR REPLACE FUNCTION fn_ingest_run_finish(p_id BIGINT, p_listings JSONB)
RETURNS JSONB
LANGUAGE sql VOLATILE
SET search_path = public
AS $$
  SELECT fn_ingest_run_close(p_id, 'FINISHED', COALESCE(p_listings, '{}'::JSONB), NULL);
$$;

CREATE OR REPLACE FUNCTION fn_ingest_run_fail(p_id BIGINT, p_error TEXT, p_listings JSONB DEFAULT NULL)
RETURNS JSONB
LANGUAGE sql VOLATILE
SET search_path = public
AS $$
  SELECT fn_ingest_run_close(p_id, 'FAILED', p_listings, COALESCE(p_error, 'failed'));
$$;

COMMENT ON FUNCTION fn_ingest_run_open(TEXT, TEXT, TEXT, INT, TEXT, TEXT, TEXT) IS
  'ADR-108 §4: open a RUNNING tbl_ingest_run row before the ingestion writes; abandons an older RUNNING row of the same event and environment. Returns its id.';
COMMENT ON FUNCTION fn_ingest_run_close(BIGINT, TEXT, JSONB, TEXT) IS
  'ADR-108 §4: close a RUNNING run with its listings and master-data changes. Called by fn_ingest_run_finish and fn_ingest_run_fail.';
COMMENT ON FUNCTION fn_ingest_run_finish(BIGINT, JSONB) IS
  'ADR-108 §4: close a run FINISHED with its listings; returns its master-data changes. Raises INGEST_RUN_NOT_RUNNING if it is not RUNNING.';
COMMENT ON FUNCTION fn_ingest_run_fail(BIGINT, TEXT, JSONB) IS
  'ADR-108 §4: close a run FAILED with its error and what it had changed.';

-- ---------------------------------------------------------------------------
-- Grants (ADR-083): service role only
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION fn_schema_fingerprint() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_event_input_fingerprint(TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_roster_snapshot() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_roster_changes(JSONB, JSONB) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_ingest_run_open(TEXT, TEXT, TEXT, INT, TEXT, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_ingest_run_close(BIGINT, TEXT, JSONB, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_ingest_run_finish(BIGINT, JSONB) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_ingest_run_fail(BIGINT, TEXT, JSONB) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION fn_schema_fingerprint() TO service_role;
GRANT EXECUTE ON FUNCTION fn_event_input_fingerprint(TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION fn_roster_snapshot() TO service_role;
GRANT EXECUTE ON FUNCTION fn_roster_changes(JSONB, JSONB) TO service_role;
GRANT EXECUTE ON FUNCTION fn_ingest_run_open(TEXT, TEXT, TEXT, INT, TEXT, TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION fn_ingest_run_close(BIGINT, TEXT, JSONB, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION fn_ingest_run_finish(BIGINT, JSONB) TO service_role;
GRANT EXECUTE ON FUNCTION fn_ingest_run_fail(BIGINT, TEXT, JSONB) TO service_role;
