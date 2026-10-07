-- =============================================================================
-- PZSz start lists are stored inputs (ADR-112)
-- =============================================================================
-- The PZSz admission (ADR-111) takes each starter's birth year from the PZSz
-- start list on pzszerm.pl. pzszerm.pl puts a JavaScript cookie gate in front
-- of its pages and switches it on and off; our client runs no JavaScript, so a
-- list read at the moment of the ingest fails whenever the gate is on. The
-- list is therefore captured on the days pzszerm.pl serves it and stored here;
-- the CERT ingest reads the newest stored version, and the PROD promote reads
-- the version the CERT run used, never pzszerm.pl.
--
-- One row per version of a tournament's start list. Rows are insert-only: a
-- version is appended only when it differs from the newest version for the
-- same event, weapon and gender, and the newest is the highest id, so a list
-- that goes A -> B -> A ends on A.
--
-- Personal data (ADR-078 §1): the printed name and the birth YEAR of every
-- starter, never the birth date; most starters are juniors who are not our
-- members. service_role only (ADR-083). Filled on CERT only; the table exists
-- everywhere for schema parity. Retention: fn_pzsz_start_list_purge() deletes
-- the lists of events outside the active season, run by the daily capture.
--
-- Plan: doc/plans/pzsz-start-lists-stored-2026-10-07.html.
-- Tests: supabase/tests/109_pzsz_start_list.sql (109.1-109.6).
-- =============================================================================

BEGIN;

SET LOCAL lock_timeout = '2s';

CREATE TABLE IF NOT EXISTS tbl_pzsz_start_list (
  id_pzsz_start_list   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_pzsz_event        INT NOT NULL,
  id_pzsz_tournament   INT NOT NULL,
  enum_weapon          enum_weapon_type NOT NULL,
  enum_gender          enum_gender_type NOT NULL,
  txt_sha256           TEXT NOT NULL CONSTRAINT ck_pzsz_start_list_sha256
                         CHECK (txt_sha256 ~ '^[0-9a-f]{64}$'),
  jsonb_starters       JSONB NOT NULL CONSTRAINT ck_pzsz_start_list_starters
                         CHECK (jsonb_typeof(jsonb_starters) = 'array'
                                AND jsonb_array_length(jsonb_starters) > 0),
  txt_source           TEXT NOT NULL CONSTRAINT ck_pzsz_start_list_source
                         CHECK (txt_source IN ('pzszerm.pl', 'saved page')),
  ts_captured          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pzsz_start_list_series
  ON tbl_pzsz_start_list (id_pzsz_event, enum_weapon, enum_gender, id_pzsz_start_list DESC);

COMMENT ON TABLE tbl_pzsz_start_list IS
  'ADR-112: PZSz start lists as captured, one insert-only row per version: [printed name, birth year] in page order, never the birth date. Filled on CERT by the daily capture, the CERT ingest or a saved page; read by the CERT ingest (newest) and by promote (the version the CERT run used). service_role only.';

ALTER TABLE tbl_pzsz_start_list ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON tbl_pzsz_start_list FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT, INSERT, DELETE ON tbl_pzsz_start_list TO service_role;

-- Appends a version only when it differs from the newest one for the same
-- event, weapon and gender. The advisory lock makes two captures at once (the
-- daily job and an ingest) agree on what "newest" is.
CREATE OR REPLACE FUNCTION fn_pzsz_start_list_store(p_list JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_event   INT := (p_list ->> 'id_pzsz_event')::INT;
  v_weapon  enum_weapon_type := (p_list ->> 'enum_weapon')::enum_weapon_type;
  v_gender  enum_gender_type := (p_list ->> 'enum_gender')::enum_gender_type;
  v_newest  TEXT;
  v_id      BIGINT;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('tbl_pzsz_start_list'), v_event);

  SELECT l.txt_sha256 INTO v_newest
    FROM tbl_pzsz_start_list l
   WHERE l.id_pzsz_event = v_event
     AND l.enum_weapon = v_weapon
     AND l.enum_gender = v_gender
   ORDER BY l.id_pzsz_start_list DESC
   LIMIT 1;

  IF v_newest IS NOT DISTINCT FROM (p_list ->> 'txt_sha256') THEN
    RETURN jsonb_build_object('stored', FALSE, 'txt_sha256', v_newest);
  END IF;

  INSERT INTO tbl_pzsz_start_list (
    id_pzsz_event, id_pzsz_tournament, enum_weapon, enum_gender,
    txt_sha256, jsonb_starters, txt_source
  ) VALUES (
    v_event, (p_list ->> 'id_pzsz_tournament')::INT, v_weapon, v_gender,
    p_list ->> 'txt_sha256', p_list -> 'jsonb_starters', p_list ->> 'txt_source'
  )
  RETURNING id_pzsz_start_list INTO v_id;

  RETURN jsonb_build_object('stored', TRUE, 'id_pzsz_start_list', v_id,
                            'txt_sha256', p_list ->> 'txt_sha256');
END;
$$;

-- Retention (ADR-078 §1, ADR-112 §7): a start list is used only to admit rows
-- of its event, and closed seasons are never re-ingested.
CREATE OR REPLACE FUNCTION fn_pzsz_start_list_purge()
RETURNS INT
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_deleted INT;
BEGIN
  DELETE FROM tbl_pzsz_start_list l
   WHERE NOT EXISTS (
     SELECT 1
       FROM tbl_event e
       JOIN tbl_season s ON s.id_season = e.id_season
      WHERE s.bool_active
        AND e.id_pzsz_event = l.id_pzsz_event
   );
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_pzsz_start_list_store(JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_pzsz_start_list_store(JSONB) TO service_role;
REVOKE EXECUTE ON FUNCTION fn_pzsz_start_list_purge() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_pzsz_start_list_purge() TO service_role;

COMMIT;
