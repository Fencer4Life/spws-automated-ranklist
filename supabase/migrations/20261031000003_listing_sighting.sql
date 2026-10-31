-- =============================================================================
-- ADR-119 §1 (D2 B): when a bracket from an engine without a finished signal
-- may be taken
-- =============================================================================
-- FTL marks each listing Finished and Engarde gives each competition a state,
-- so the ingest knows when a bracket is final. 4fence, Ophardt, d'Artagnan,
-- EVF's results API and a lone results page say nothing, and Ophardt transmits
-- while a competition runs. The CERT ingest therefore records the first time it
-- sees each bracket's content, and takes the bracket once that content has
-- been unchanged for 60 minutes, or once the event's end date has passed.
--
-- One row per event, bracket and content hash: the first sighting is kept,
-- the last one moves, and nothing is ever deleted. It holds keys and hashes,
-- never a person. Rows are written on CERT (and LOCAL) only: promote's plan on
-- PROD replays the CERT run's decision and never reads or writes this table.
--
-- Plan: doc/plans/partial-ingest-promote-results-sync-2026-10-31.html (D2 B).
-- Tests: supabase/tests/119_listing_sighting.sql (FINAL.05).
-- =============================================================================

CREATE TABLE IF NOT EXISTS tbl_listing_sighting (
  id_listing_sighting BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  txt_event_code      TEXT NOT NULL,
  txt_listing_key     TEXT NOT NULL,
  txt_sha256          TEXT NOT NULL CONSTRAINT ck_listing_sighting_sha256
                        CHECK (txt_sha256 ~ '^[0-9a-f]{64}$'),
  ts_first_seen       TIMESTAMPTZ NOT NULL DEFAULT now(),
  ts_last_seen        TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_listing_sighting UNIQUE (txt_event_code, txt_listing_key, txt_sha256)
);

COMMENT ON TABLE tbl_listing_sighting IS
  'ADR-119 §1 (D2 B): the first and last time the CERT ingest saw each bracket''s content, for engines without a finished signal. A bracket is taken once its content is 60 minutes old or the event has ended. Never deleted; keys and hashes only.';

ALTER TABLE tbl_listing_sighting ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON tbl_listing_sighting FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE ON tbl_listing_sighting TO service_role;

-- Records one sighting and answers when this content was first seen.
CREATE OR REPLACE FUNCTION fn_listing_sighting_record(
  p_event_code  TEXT,
  p_listing_key TEXT,
  p_sha256      TEXT)
RETURNS TIMESTAMPTZ
LANGUAGE sql VOLATILE
SET search_path = public
AS $$
  INSERT INTO tbl_listing_sighting (txt_event_code, txt_listing_key, txt_sha256)
  VALUES (p_event_code, p_listing_key, p_sha256)
  ON CONFLICT (txt_event_code, txt_listing_key, txt_sha256)
    DO UPDATE SET ts_last_seen = now()
  RETURNING ts_first_seen;
$$;

COMMENT ON FUNCTION fn_listing_sighting_record(TEXT, TEXT, TEXT) IS
  'ADR-119 §1 (D2 B): record that the CERT ingest saw this content of this bracket now; returns when it was first seen.';

REVOKE ALL ON FUNCTION fn_listing_sighting_record(TEXT, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_listing_sighting_record(TEXT, TEXT, TEXT) TO service_role;
