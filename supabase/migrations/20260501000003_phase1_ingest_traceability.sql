-- =============================================================================
-- Phase 1 — Ingest Traceability (ADR-055, P1 of
-- /Users/aleks/.claude/plans/now-we-have-a-precious-wren.md)
--
-- Adds per-parser provenance to tbl_event and tbl_tournament:
--   - enum_parser_kind enum (mirrors IR SourceKind from python/pipeline/ir.py)
--   - "current stamp" columns on tbl_event and tbl_tournament
--   - tbl_event_ingest_history + tbl_tournament_ingest_history tables
--   - Per-parent cap of 6 history rows enforced by BEFORE INSERT triggers
--
-- Design comes from the 8 brainstorm decisions captured in ADR-055:
--   D1  Stamp at both event AND tournament level
--   D2  Each stamp = parser + timestamp + source URL
--   D3  Current stamp on parent row + append to history
--   D4  Two separate history tables (no polymorphic FK)
--   D5  Per-parent cap of 6; older auto-deleted on insert
--   D6  Only successful commits trigger a history row
--   D7  History row carries stamp + run_id (UUID -> Phase 2 draft tables)
--   D8  Lands in Phase 1 (this migration)
--
-- Tests: supabase/tests/26_ingest_traceability.sql (23 assertions).
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. enum_parser_kind — mirrors python/pipeline/ir.py SourceKind enum
--    (8 values; kept in declared order so the IR enum and DB enum align)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'enum_parser_kind') THEN
    CREATE TYPE enum_parser_kind AS ENUM (
      'FENCINGTIME_XML',
      'FTL',
      'ENGARDE',
      'FOURFENCE',
      'DARTAGNAN',
      'EVF_API',
      'FILE_IMPORT',
      'OPHARDT_HTML'
    );
  END IF;
END$$;

COMMENT ON TYPE enum_parser_kind IS
  'Identifies which parser produced an ingestion. Mirrors the Python '
  'SourceKind enum in python/pipeline/ir.py — keep in lockstep when '
  'adding a new source.';


-- ---------------------------------------------------------------------------
-- 2. Current-stamp columns on tbl_event (D1, D2)
--    All nullable: events may exist before any scrape (CREATED status)
--    and FROZEN_SNAPSHOT events have no live source.
-- ---------------------------------------------------------------------------
ALTER TABLE tbl_event
  ADD COLUMN IF NOT EXISTS enum_parser_kind     enum_parser_kind,
  ADD COLUMN IF NOT EXISTS dt_last_scraped      TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS txt_source_url_used  TEXT;

COMMENT ON COLUMN tbl_event.enum_parser_kind IS
  'Which parser produced the most recent successful ingest of this event. '
  'NULL until first scrape commits.';
COMMENT ON COLUMN tbl_event.dt_last_scraped IS
  'Timestamp of the most recent successful ingest commit. NULL until first scrape.';
COMMENT ON COLUMN tbl_event.txt_source_url_used IS
  'Source URL the parser actually fetched for the most recent ingest. May '
  'differ from url_event (admin-entered) if the parser follows a redirect '
  'or uses a sub-page.';


-- ---------------------------------------------------------------------------
-- 3. Current-stamp columns on tbl_tournament (D1, D2)
-- ---------------------------------------------------------------------------
ALTER TABLE tbl_tournament
  ADD COLUMN IF NOT EXISTS enum_parser_kind     enum_parser_kind,
  ADD COLUMN IF NOT EXISTS dt_last_scraped      TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS txt_source_url_used  TEXT;

COMMENT ON COLUMN tbl_tournament.enum_parser_kind IS
  'Which parser produced the most recent successful ingest of this tournament''s '
  'results. May differ from tbl_event.enum_parser_kind when an event mixes '
  'sources (e.g. FTL primary + EVF API re-fix on a single tournament).';
COMMENT ON COLUMN tbl_tournament.dt_last_scraped IS
  'Timestamp of the most recent successful ingest commit for this tournament.';
COMMENT ON COLUMN tbl_tournament.txt_source_url_used IS
  'Source URL the parser actually fetched for this tournament''s most recent '
  'successful ingest. May differ from url_results (admin-entered).';


-- ---------------------------------------------------------------------------
-- 4. tbl_event_ingest_history — append-only audit trail (D3, D4, D7)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_event_ingest_history (
  id_event_ingest_history  SERIAL PRIMARY KEY,
  id_event                 INT NOT NULL
                             REFERENCES tbl_event(id_event)
                             ON DELETE CASCADE,
  txt_run_id               UUID NOT NULL,
  enum_parser_kind         enum_parser_kind NOT NULL,
  dt_committed             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  txt_source_url           TEXT,
  UNIQUE (id_event, txt_run_id)
);

CREATE INDEX IF NOT EXISTS idx_tbl_event_ingest_history_event_committed
  ON tbl_event_ingest_history (id_event, dt_committed DESC);

COMMENT ON TABLE tbl_event_ingest_history IS
  'Per-event ingest audit trail. One row per successful commit (D6). '
  'Capped at 6 rows per parent event by trg_enforce_event_history_cap (D5). '
  'txt_run_id links back to the Phase 2 draft tables (tbl_*_draft.txt_run_id). '
  'See ADR-055 for the full design rationale.';


-- ---------------------------------------------------------------------------
-- 5. tbl_tournament_ingest_history — mirror of #4 (D3, D4, D7)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_tournament_ingest_history (
  id_tournament_ingest_history  SERIAL PRIMARY KEY,
  id_tournament                 INT NOT NULL
                                  REFERENCES tbl_tournament(id_tournament)
                                  ON DELETE CASCADE,
  txt_run_id                    UUID NOT NULL,
  enum_parser_kind              enum_parser_kind NOT NULL,
  dt_committed                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  txt_source_url                TEXT,
  UNIQUE (id_tournament, txt_run_id)
);

CREATE INDEX IF NOT EXISTS idx_tbl_tournament_ingest_history_tour_committed
  ON tbl_tournament_ingest_history (id_tournament, dt_committed DESC);

COMMENT ON TABLE tbl_tournament_ingest_history IS
  'Per-tournament ingest audit trail. One row per successful commit. '
  'Capped at 6 rows per parent tournament by trg_enforce_tour_history_cap. '
  'See ADR-055.';


-- ---------------------------------------------------------------------------
-- 6. Cap-of-6 trigger function for events (D5)
--    BEFORE INSERT: delete any rows for this parent beyond the 5 newest.
--    After NEW row is inserted, total = 6 (cap holds).
--
--    Tie-breaker (when dt_committed is identical): newer SERIAL id wins.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_enforce_event_history_cap()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM tbl_event_ingest_history
   WHERE id_event = NEW.id_event
     AND id_event_ingest_history IN (
       SELECT id_event_ingest_history
         FROM tbl_event_ingest_history
        WHERE id_event = NEW.id_event
        ORDER BY dt_committed DESC,
                 id_event_ingest_history DESC
        OFFSET 5
     );
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_enforce_event_history_cap() IS
  'BEFORE INSERT trigger: enforces the 6-row cap on tbl_event_ingest_history '
  'per parent event by deleting older rows. See ADR-055 D5.';

DROP TRIGGER IF EXISTS trg_enforce_event_history_cap
  ON tbl_event_ingest_history;
CREATE TRIGGER trg_enforce_event_history_cap
  BEFORE INSERT ON tbl_event_ingest_history
  FOR EACH ROW
  EXECUTE FUNCTION fn_enforce_event_history_cap();


-- ---------------------------------------------------------------------------
-- 7. Cap-of-6 trigger function for tournaments (D5) — mirror of #6
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_enforce_tournament_history_cap()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM tbl_tournament_ingest_history
   WHERE id_tournament = NEW.id_tournament
     AND id_tournament_ingest_history IN (
       SELECT id_tournament_ingest_history
         FROM tbl_tournament_ingest_history
        WHERE id_tournament = NEW.id_tournament
        ORDER BY dt_committed DESC,
                 id_tournament_ingest_history DESC
        OFFSET 5
     );
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_enforce_tournament_history_cap() IS
  'BEFORE INSERT trigger: enforces the 6-row cap on '
  'tbl_tournament_ingest_history per parent tournament. See ADR-055 D5.';

DROP TRIGGER IF EXISTS trg_enforce_tour_history_cap
  ON tbl_tournament_ingest_history;
CREATE TRIGGER trg_enforce_tour_history_cap
  BEFORE INSERT ON tbl_tournament_ingest_history
  FOR EACH ROW
  EXECUTE FUNCTION fn_enforce_tournament_history_cap();

COMMIT;
