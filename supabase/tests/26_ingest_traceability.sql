-- =============================================================================
-- ADR-055 (Ingest traceability stamp + history, 2026-05-01):
-- Per-parser provenance on tbl_event and tbl_tournament + bounded history.
--
-- Decisions D1-D8 from the brainstorm:
--   D1  Stamp at both event AND tournament level
--   D2  Each stamp = parser + timestamp + source URL
--   D3  Current stamp on parent row + append to history
--   D4  Two separate history tables (events / tournaments)
--   D5  Per-parent cap of 6 latest; older auto-deleted on insert
--   D6  Only successful commits trigger a history row
--   D7  History row carries stamp + run_id (UUID -> Phase 2 draft tables)
--   D8  Lands in Phase 1 (this migration: 20260501000003_phase1_ingest_traceability.sql)
--
-- Tests 26.1-26.2  : enum_parser_kind type + 8 values
-- Tests 26.3-26.5  : tbl_event stamp columns
-- Tests 26.6-26.8  : tbl_tournament stamp columns
-- Tests 26.9-26.13 : tbl_event_ingest_history shape + FK + unique
-- Tests 26.14-26.18: tbl_tournament_ingest_history shape + FK + unique
-- Tests 26.19-26.23: behaviour (cascade, unique, cap-of-6, per-parent isolation)
-- =============================================================================

BEGIN;
SELECT plan(23);


-- =============================================================================
-- Section 1: enum_parser_kind type (mirrors IR SourceKind)
-- =============================================================================

-- ===== 26.1 — enum type exists =====
SELECT has_type(
  'enum_parser_kind',
  '26.1: enum_parser_kind type exists'
);


-- ===== 26.2 — enum has all 8 source kinds =====
SELECT is(
  (SELECT array_agg(enumlabel::TEXT ORDER BY enumsortorder)
     FROM pg_enum
    WHERE enumtypid = 'enum_parser_kind'::regtype),
  ARRAY['FENCINGTIME_XML','FTL','ENGARDE','FOURFENCE',
        'DARTAGNAN','EVF_API','FILE_IMPORT','OPHARDT_HTML'],
  '26.2: enum_parser_kind has the 8 source kinds in declared order'
);


-- =============================================================================
-- Section 2: tbl_event stamp columns
-- =============================================================================

-- ===== 26.3 — tbl_event.enum_parser_kind =====
SELECT col_type_is(
  'tbl_event', 'enum_parser_kind', 'enum_parser_kind',
  '26.3: tbl_event.enum_parser_kind is enum_parser_kind (nullable)'
);


-- ===== 26.4 — tbl_event.dt_last_scraped =====
SELECT col_type_is(
  'tbl_event', 'dt_last_scraped', 'timestamp with time zone',
  '26.4: tbl_event.dt_last_scraped is TIMESTAMPTZ (nullable)'
);


-- ===== 26.5 — tbl_event.txt_source_url_used =====
SELECT col_type_is(
  'tbl_event', 'txt_source_url_used', 'text',
  '26.5: tbl_event.txt_source_url_used is TEXT (nullable)'
);


-- =============================================================================
-- Section 3: tbl_tournament stamp columns
-- =============================================================================

-- ===== 26.6 — tbl_tournament.enum_parser_kind =====
SELECT col_type_is(
  'tbl_tournament', 'enum_parser_kind', 'enum_parser_kind',
  '26.6: tbl_tournament.enum_parser_kind is enum_parser_kind (nullable)'
);


-- ===== 26.7 — tbl_tournament.dt_last_scraped =====
SELECT col_type_is(
  'tbl_tournament', 'dt_last_scraped', 'timestamp with time zone',
  '26.7: tbl_tournament.dt_last_scraped is TIMESTAMPTZ (nullable)'
);


-- ===== 26.8 — tbl_tournament.txt_source_url_used =====
SELECT col_type_is(
  'tbl_tournament', 'txt_source_url_used', 'text',
  '26.8: tbl_tournament.txt_source_url_used is TEXT (nullable)'
);


-- =============================================================================
-- Section 4: tbl_event_ingest_history shape
-- =============================================================================

-- ===== 26.9 — table exists =====
SELECT has_table(
  'tbl_event_ingest_history',
  '26.9: tbl_event_ingest_history table exists'
);


-- ===== 26.10 — id_event FK column type =====
SELECT col_type_is(
  'tbl_event_ingest_history', 'id_event', 'integer',
  '26.10: tbl_event_ingest_history.id_event is INTEGER (FK to tbl_event.id_event)'
);


-- ===== 26.11 — txt_run_id column type =====
SELECT col_type_is(
  'tbl_event_ingest_history', 'txt_run_id', 'uuid',
  '26.11: tbl_event_ingest_history.txt_run_id is UUID (links to draft run)'
);


-- ===== 26.12 — enum_parser_kind column type =====
SELECT col_type_is(
  'tbl_event_ingest_history', 'enum_parser_kind', 'enum_parser_kind',
  '26.12: tbl_event_ingest_history.enum_parser_kind uses enum_parser_kind'
);


-- ===== 26.13 — dt_committed column type =====
SELECT col_type_is(
  'tbl_event_ingest_history', 'dt_committed', 'timestamp with time zone',
  '26.13: tbl_event_ingest_history.dt_committed is TIMESTAMPTZ'
);


-- =============================================================================
-- Section 5: tbl_tournament_ingest_history shape
-- =============================================================================

-- ===== 26.14 — table exists =====
SELECT has_table(
  'tbl_tournament_ingest_history',
  '26.14: tbl_tournament_ingest_history table exists'
);


-- ===== 26.15 — id_tournament FK column type =====
SELECT col_type_is(
  'tbl_tournament_ingest_history', 'id_tournament', 'integer',
  '26.15: tbl_tournament_ingest_history.id_tournament is INTEGER (FK to tbl_tournament.id_tournament)'
);


-- ===== 26.16 — txt_run_id column type =====
SELECT col_type_is(
  'tbl_tournament_ingest_history', 'txt_run_id', 'uuid',
  '26.16: tbl_tournament_ingest_history.txt_run_id is UUID'
);


-- ===== 26.17 — enum_parser_kind column type =====
SELECT col_type_is(
  'tbl_tournament_ingest_history', 'enum_parser_kind', 'enum_parser_kind',
  '26.17: tbl_tournament_ingest_history.enum_parser_kind uses enum_parser_kind'
);


-- ===== 26.18 — dt_committed column type =====
SELECT col_type_is(
  'tbl_tournament_ingest_history', 'dt_committed', 'timestamp with time zone',
  '26.18: tbl_tournament_ingest_history.dt_committed is TIMESTAMPTZ'
);


-- =============================================================================
-- Section 6: Behaviour
-- =============================================================================

-- Fixture: a fresh event + tournament we can hammer with history rows.
-- All inserts are namespaced via TRACE26-* codes so they're easy to clean
-- if the rollback ever fails to fire.
DO $fix$
DECLARE
  v_season   INT;
  v_org      INT;
  v_event_a  INT;
  v_event_b  INT;
  v_tour     INT;
BEGIN
  SELECT id_season   INTO v_season FROM tbl_season ORDER BY id_season LIMIT 1;
  SELECT id_organizer INTO v_org   FROM tbl_organizer ORDER BY id_organizer LIMIT 1;

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end)
       VALUES ('TRACE26-A','Trace fixture event A', v_season, v_org,
               '2026-01-01', '2026-01-02')
    RETURNING id_event INTO v_event_a;

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end)
       VALUES ('TRACE26-B','Trace fixture event B', v_season, v_org,
               '2026-01-03', '2026-01-04')
    RETURNING id_event INTO v_event_b;

  -- Tournament lives under event_b so event_a stays childless for the
  -- 26.19 cascade test (tbl_tournament.id_event has no ON DELETE CASCADE).
  INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon,
                              enum_gender, enum_age_category, dt_tournament)
       VALUES (v_event_b, 'TRACE26-B-T1', 'PPW', 'EPEE', 'M', 'V2', '2026-01-03')
    RETURNING id_tournament INTO v_tour;

  -- Stash IDs in temp table for the per-test queries below.
  CREATE TEMP TABLE trace26_ids (
    event_a_id   INT,
    event_b_id   INT,
    tour_id      INT
  ) ON COMMIT DROP;
  INSERT INTO trace26_ids VALUES (v_event_a, v_event_b, v_tour);
END;
$fix$;


-- A scratch outcome table so behaviour-block results pass back to file-level
-- SELECT ok()/is() calls (PERFORM ok() inside DO doesn't emit TAP cleanly).
CREATE TEMP TABLE trace26_outcome (
  test_id   TEXT PRIMARY KEY,
  passed    BOOLEAN
) ON COMMIT DROP;


-- ===== 26.19 — FK CASCADE: deleting an event sweeps its history rows =====
DO $$
DECLARE
  v_evt   INT;
  v_after INT;
BEGIN
  SELECT event_a_id INTO v_evt FROM trace26_ids;
  -- Insert one history row, delete the event, then count surviving rows.
  INSERT INTO tbl_event_ingest_history
    (id_event, txt_run_id, enum_parser_kind, txt_source_url)
  VALUES
    (v_evt, gen_random_uuid(), 'OPHARDT_HTML', 'https://example/r1');

  DELETE FROM tbl_event WHERE id_event = v_evt;

  SELECT COUNT(*) INTO v_after
    FROM tbl_event_ingest_history
   WHERE id_event = v_evt;

  INSERT INTO trace26_outcome VALUES ('26.19', v_after = 0);
END;
$$;

SELECT ok(
  (SELECT passed FROM trace26_outcome WHERE test_id = '26.19'),
  '26.19: deleting an event cascades to tbl_event_ingest_history (zero survivors)'
);


-- ===== 26.20 — UNIQUE (id_event, txt_run_id) =====
DO $$
DECLARE
  v_evt INT;
  v_run UUID := gen_random_uuid();
BEGIN
  SELECT event_b_id INTO v_evt FROM trace26_ids;
  INSERT INTO tbl_event_ingest_history
    (id_event, txt_run_id, enum_parser_kind, dt_committed, txt_source_url)
  VALUES
    (v_evt, v_run, 'FTL',
     NOW() - INTERVAL '1 hour',  -- guarantee oldest for 26.22
     'https://example/initial-r2');

  -- Duplicate (id_event, txt_run_id) — must raise unique_violation.
  BEGIN
    INSERT INTO tbl_event_ingest_history
      (id_event, txt_run_id, enum_parser_kind, txt_source_url)
    VALUES
      (v_evt, v_run, 'FTL', 'https://example/initial-r2-dup');
    INSERT INTO trace26_outcome VALUES ('26.20', FALSE);
  EXCEPTION WHEN unique_violation THEN
    INSERT INTO trace26_outcome VALUES ('26.20', TRUE);
  END;
END;
$$;

SELECT ok(
  (SELECT passed FROM trace26_outcome WHERE test_id = '26.20'),
  '26.20: duplicate (id_event, txt_run_id) raises unique_violation'
);


-- ===== 26.21 — Cap-of-6: inserting 7 history rows for one event leaves 6 =====
DO $$
DECLARE
  v_evt INT;
  i     INT;
BEGIN
  SELECT event_b_id INTO v_evt FROM trace26_ids;
  -- event_b already has one row from 26.20. Add 6 more (total = 7 attempted),
  -- each with a slight clock advance so dt_committed is monotonically distinct.
  FOR i IN 1..6 LOOP
    INSERT INTO tbl_event_ingest_history
      (id_event, txt_run_id, enum_parser_kind, dt_committed, txt_source_url)
    VALUES
      (v_evt, gen_random_uuid(), 'FTL',
       NOW() + (i * INTERVAL '1 second'),
       'https://example/r' || i);
  END LOOP;
END;
$$;

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event_ingest_history
    WHERE id_event = (SELECT event_b_id FROM trace26_ids)),
  6,
  '26.21: cap-of-6 trigger keeps exactly 6 rows after 7 inserts'
);


-- ===== 26.22 — Cap evicts the OLDEST row (the very first one) =====
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event_ingest_history
    WHERE id_event = (SELECT event_b_id FROM trace26_ids)
      AND txt_source_url = 'https://example/initial-r2'),
  0,
  '26.22: oldest history row (the original from 26.20) is the one evicted'
);


-- ===== 26.23 — Cap is per-parent (tournament-side mirror) =====
-- Insert 7 history rows into the tournament side; assert count = 6.
DO $$
DECLARE
  v_tour INT;
  i      INT;
BEGIN
  SELECT tour_id INTO v_tour FROM trace26_ids;
  FOR i IN 1..7 LOOP
    INSERT INTO tbl_tournament_ingest_history
      (id_tournament, txt_run_id, enum_parser_kind, dt_committed, txt_source_url)
    VALUES
      (v_tour, gen_random_uuid(), 'OPHARDT_HTML',
       NOW() + (i * INTERVAL '1 second'),
       'https://example/t' || i);
  END LOOP;
END;
$$;

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_tournament_ingest_history
    WHERE id_tournament = (SELECT tour_id FROM trace26_ids)),
  6,
  '26.23: cap-of-6 trigger fires for tbl_tournament_ingest_history too'
);


SELECT * FROM finish();
ROLLBACK;
