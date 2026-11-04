-- =============================================================================
-- ADR-120 §2: one FencingTimeLive session, reused by every run
-- =============================================================================
-- FTL's session cookie (connect.sid) is valid a fixed 10 days from its sign-in
-- and not extended by use (ADR-068). Until now each process signed in afresh.
-- The pipeline now stores the cookie right after a sign-in, before any other
-- request, and every later run, CI or LOCAL, loads it instead of signing in:
-- at most one sign-in per 10 days. One row; a newer sign-in replaces it; a run
-- whose cookie bounced to the login page drops it only if it is still the one
-- stored, so it never drops a newer session another run stored.
--
-- The cookie is a credential: service_role only, never in the PROD seed export
-- (it names its tables one by one), never printed. Not the password: that stays
-- in .env and the repository secrets.
--
-- Plan: doc/plans/ftl-daily-read-budget-2026-11-04.html (S2).
-- Tests: supabase/tests/126_ftl_session.sql (FTL.SESSION).
-- =============================================================================

CREATE TABLE IF NOT EXISTS tbl_ftl_session (
  id_session       SMALLINT PRIMARY KEY DEFAULT 1 CONSTRAINT ck_ftl_session_one CHECK (id_session = 1),
  txt_cookie       TEXT NOT NULL,
  ts_expires_at    TIMESTAMPTZ NOT NULL,
  ts_signed_in_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE tbl_ftl_session IS
  'ADR-120 §2: the FencingTimeLive session cookie of the latest sign-in and its fixed expiry, reused by every run. A credential: service_role only; CERT only.';

ALTER TABLE tbl_ftl_session ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON tbl_ftl_session FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON tbl_ftl_session TO service_role;

-- The stored session ({"cookie", "expires_at"}), or NULL.
CREATE OR REPLACE FUNCTION fn_ftl_session_get()
RETURNS JSONB
LANGUAGE sql STABLE
SET search_path = public
AS $$
  SELECT jsonb_build_object('cookie', txt_cookie, 'expires_at', ts_expires_at)
    FROM tbl_ftl_session
   WHERE id_session = 1;
$$;

COMMENT ON FUNCTION fn_ftl_session_get() IS
  'ADR-120 §2: the stored FTL session cookie and its expiry, or NULL.';

REVOKE ALL ON FUNCTION fn_ftl_session_get() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_ftl_session_get() TO service_role;

-- Stores the session of a sign-in, replacing any older one.
CREATE OR REPLACE FUNCTION fn_ftl_session_put(
  p_cookie     TEXT,
  p_expires_at TIMESTAMPTZ)
RETURNS JSONB
LANGUAGE plpgsql VOLATILE
SET search_path = public
AS $$
BEGIN
  IF COALESCE(p_cookie, '') = '' OR p_expires_at IS NULL OR p_expires_at <= now() THEN
    RAISE EXCEPTION 'FTL_SESSION: a session is stored with its cookie and an expiry in the future';
  END IF;

  INSERT INTO tbl_ftl_session (id_session, txt_cookie, ts_expires_at, ts_signed_in_at)
  VALUES (1, p_cookie, p_expires_at, now())
  ON CONFLICT (id_session) DO UPDATE
    SET txt_cookie = EXCLUDED.txt_cookie,
        ts_expires_at = EXCLUDED.ts_expires_at,
        ts_signed_in_at = EXCLUDED.ts_signed_in_at;

  RETURN jsonb_build_object('stored', TRUE, 'expires_at', p_expires_at);
END;
$$;

COMMENT ON FUNCTION fn_ftl_session_put(TEXT, TIMESTAMPTZ) IS
  'ADR-120 §2: store the FTL session of a sign-in (cookie, expiry in the future), replacing the older one.';

REVOKE ALL ON FUNCTION fn_ftl_session_put(TEXT, TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_ftl_session_put(TEXT, TIMESTAMPTZ) TO service_role;

-- Drops the stored session only if it is the cookie the caller used.
CREATE OR REPLACE FUNCTION fn_ftl_session_drop(p_cookie TEXT)
RETURNS JSONB
LANGUAGE plpgsql VOLATILE
SET search_path = public
AS $$
DECLARE
  v_dropped INTEGER;
BEGIN
  DELETE FROM tbl_ftl_session WHERE id_session = 1 AND txt_cookie = p_cookie;
  GET DIAGNOSTICS v_dropped = ROW_COUNT;
  RETURN jsonb_build_object('dropped', v_dropped > 0);
END;
$$;

COMMENT ON FUNCTION fn_ftl_session_drop(TEXT) IS
  'ADR-120 §2: drop the stored FTL session if it is still the cookie the caller used (a newer one is kept).';

REVOKE ALL ON FUNCTION fn_ftl_session_drop(TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_ftl_session_drop(TEXT) TO service_role;
