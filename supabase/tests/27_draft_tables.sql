-- =============================================================================
-- Phase 2 — Draft tables + dry-run loop (ADR-050, P2 of
-- /Users/aleks/.claude/plans/now-we-have-a-precious-wren.md)
--
-- Locks the migration 20260501000004_phase2_draft_tables.sql (RED until that
-- migration lands).
--
-- Structure:
--   27.1-27.2   tables exist
--   27.3-27.4   txt_run_id columns (UUID NOT NULL — matches Phase 1 history)
--   27.5-27.6   draft tables mirror live tables column-for-column (+ run_id)
--   27.7-27.8   indexes on (txt_run_id)
--   27.9-27.10  loose: no FK on id_event / id_fencer (drafts stage unresolved)
--   27.11-27.13 the 3 new RPCs exist with the agreed signatures
--   27.14-27.20 fn_commit_event_draft behaviour
--   27.21-27.23 fn_discard_event_draft behaviour
--   27.24-27.25 fn_dry_run_event_draft behaviour (does not persist)
--   27.26       fn_commit_event_draft is idempotent on already-discarded run_id
--
-- Decisions locked 2026-05-01 in conversation:
--   D1  --dry-run = no DB writes; Python computes diff from in-memory IR
--   D2  RPCs return JSONB with counts; never throw on missing run_id
--       (Telegram warns + nonzero CLI exit on zero-count outcomes)
--   D3  Tournament-level diff in Phase 2; per-fencer detail = Phase 3
--   D4  Migration filename: 20260501000004_phase2_draft_tables.sql
--   D5  All txn boundaries inside SQL; no psycopg2 at runtime
-- =============================================================================

BEGIN;
SELECT plan(30);


-- =============================================================================
-- Section 1: tables exist
-- =============================================================================

-- ===== 27.1 — tbl_tournament_draft exists =====
SELECT has_table(
  'tbl_tournament_draft',
  '27.1: tbl_tournament_draft table exists'
);


-- ===== 27.2 — tbl_result_draft exists =====
SELECT has_table(
  'tbl_result_draft',
  '27.2: tbl_result_draft table exists'
);


-- =============================================================================
-- Section 2: txt_run_id columns (UUID NOT NULL — matches Phase 1 history)
-- =============================================================================

-- ===== 27.3 — tbl_tournament_draft.txt_run_id =====
SELECT col_type_is(
  'tbl_tournament_draft', 'txt_run_id', 'uuid',
  '27.3: tbl_tournament_draft.txt_run_id is UUID (matches Phase 1 history schema)'
);

SELECT col_not_null(
  'tbl_tournament_draft', 'txt_run_id',
  '27.3b: tbl_tournament_draft.txt_run_id is NOT NULL'
);


-- ===== 27.4 — tbl_result_draft.txt_run_id =====
SELECT col_type_is(
  'tbl_result_draft', 'txt_run_id', 'uuid',
  '27.4: tbl_result_draft.txt_run_id is UUID (matches Phase 1 history schema)'
);


-- =============================================================================
-- Section 3: column mirrors (draft = live + txt_run_id)
-- =============================================================================

-- ===== 27.5 — tbl_tournament_draft has every column tbl_tournament has =====
-- Draft table re-declares every live column + txt_run_id (PK renamed to
-- id_tournament_draft, but counts the same). Filter to public schema so the
-- cert_ref mirror doesn't double the count.
SELECT cmp_ok(
  (SELECT COUNT(*)::INT FROM information_schema.columns
    WHERE table_name = 'tbl_tournament_draft' AND table_schema = 'public'),
  '>=',
  (SELECT COUNT(*)::INT + 1 FROM information_schema.columns
    WHERE table_name = 'tbl_tournament' AND table_schema = 'public'),
  '27.5: tbl_tournament_draft mirrors tbl_tournament + txt_run_id'
);


-- ===== 27.6 — tbl_result_draft has every column tbl_result has =====
SELECT cmp_ok(
  (SELECT COUNT(*)::INT FROM information_schema.columns
    WHERE table_name = 'tbl_result_draft' AND table_schema = 'public'),
  '>=',
  (SELECT COUNT(*)::INT + 1 FROM information_schema.columns
    WHERE table_name = 'tbl_result' AND table_schema = 'public'),
  '27.6: tbl_result_draft mirrors tbl_result + txt_run_id'
);


-- =============================================================================
-- Section 4: indexes on txt_run_id (resume + list-drafts queries)
-- =============================================================================

-- ===== 27.7 — index on tbl_tournament_draft(txt_run_id) =====
SELECT is(
  (SELECT COUNT(*)::INT FROM pg_indexes
    WHERE tablename = 'tbl_tournament_draft'
      AND indexdef ILIKE '%txt_run_id%'),
  1,
  '27.7: tbl_tournament_draft has an index on (txt_run_id)'
);


-- ===== 27.8 — index on tbl_result_draft(txt_run_id) =====
SELECT is(
  (SELECT COUNT(*)::INT FROM pg_indexes
    WHERE tablename = 'tbl_result_draft'
      AND indexdef ILIKE '%txt_run_id%'),
  1,
  '27.8: tbl_result_draft has an index on (txt_run_id)'
);


-- =============================================================================
-- Section 5: loose drafts (no FKs to live)
-- =============================================================================

-- ===== 27.9 — tbl_tournament_draft.id_event has no FK to tbl_event =====
-- Drafts may stage unresolved id_event values during admin review iterations.
SELECT is(
  (SELECT COUNT(*)::INT FROM information_schema.table_constraints
    WHERE table_name = 'tbl_tournament_draft'
      AND constraint_type = 'FOREIGN KEY'),
  0,
  '27.9: tbl_tournament_draft has no FK constraints (drafts are loose)'
);


-- ===== 27.10 — tbl_result_draft.id_fencer has no FK to tbl_fencer =====
SELECT is(
  (SELECT COUNT(*)::INT FROM information_schema.table_constraints
    WHERE table_name = 'tbl_result_draft'
      AND constraint_type = 'FOREIGN KEY'),
  0,
  '27.10: tbl_result_draft has no FK constraints (drafts can stage unresolved id_fencer)'
);


-- =============================================================================
-- Section 6: RPC signatures
-- =============================================================================

-- ===== 27.11 — fn_commit_event_draft(UUID) =====
SELECT has_function(
  'fn_commit_event_draft',
  ARRAY['uuid'],
  '27.11: fn_commit_event_draft(UUID) exists'
);

SELECT function_returns(
  'fn_commit_event_draft',
  ARRAY['uuid'],
  'jsonb',
  '27.11b: fn_commit_event_draft returns JSONB'
);


-- ===== 27.12 — fn_discard_event_draft(UUID) =====
SELECT has_function(
  'fn_discard_event_draft',
  ARRAY['uuid'],
  '27.12: fn_discard_event_draft(UUID) exists'
);

SELECT function_returns(
  'fn_discard_event_draft',
  ARRAY['uuid'],
  'jsonb',
  '27.12b: fn_discard_event_draft returns JSONB'
);


-- ===== 27.13 — fn_dry_run_event_draft(JSONB) =====
SELECT has_function(
  'fn_dry_run_event_draft',
  ARRAY['jsonb'],
  '27.13: fn_dry_run_event_draft(JSONB) exists'
);

SELECT function_returns(
  'fn_dry_run_event_draft',
  ARRAY['jsonb'],
  'jsonb',
  '27.13b: fn_dry_run_event_draft returns JSONB'
);


-- =============================================================================
-- Section 7: fn_commit_event_draft behaviour
--
-- Fixture: build a season + organizer + event. Insert 2 sibling tournament
-- drafts (V0 + V1) sharing url_results (joint-pool case) plus 1 standalone
-- (V2). Then 7 result drafts across all 3 tournaments.
-- =============================================================================

DO $fix$
DECLARE
  v_season   INT;
  v_org      INT;
  v_event    INT;
  v_run_id   UUID := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  v_f        INT;
  i          INT;
BEGIN
  UPDATE tbl_season SET bool_active = FALSE;
  v_season := fn_create_season('VW-DRAFT-27', '2098-09-01', '2099-06-30');
  UPDATE tbl_season SET bool_active = TRUE WHERE id_season = v_season;

  INSERT INTO tbl_organizer (txt_code, txt_name)
       VALUES ('VW27ORG', 'VW Test 27 Org')
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code='VW27ORG';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer,
                         txt_location, dt_start, dt_end, enum_status)
       VALUES ('VW27E', 'VW 27 event', v_season, v_org,
               'TestCity', '2099-04-15', '2099-04-15', 'COMPLETED')
    RETURNING id_event INTO v_event;

  -- Fencers used by the result drafts (must exist in live; commit copies
  -- result drafts to tbl_result which has FK to tbl_fencer + assert_vcat
  -- trigger). V0 in season 2099 = born 2060-2069 (age 30-39); V1 = born
  -- 2050-2059 (age 40-49).
  FOR i IN 1..4 LOOP
    INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year)
         VALUES ('DRAFT27', 'F'||i, 2069)
      RETURNING id_fencer INTO v_f;
  END LOOP;
  FOR i IN 5..7 LOOP
    INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year)
         VALUES ('DRAFT27', 'F'||i, 2059)
      RETURNING id_fencer INTO v_f;
  END LOOP;

  -- 2 sibling tournament drafts (V0 + V1) — share url_results
  -- 1 standalone (V2) — unique url_results
  -- enum_parser_kind required (Phase 1 history table NOT NULL constraint)
  INSERT INTO tbl_tournament_draft (
    id_event, txt_code, enum_type, enum_weapon, enum_gender,
    enum_age_category, dt_tournament, url_results, int_participant_count,
    enum_parser_kind, txt_source_url_used,
    txt_run_id
  ) VALUES
    (v_event, 'VW27E-V0-F-EPEE', 'PPW', 'EPEE', 'F', 'V0', '2099-04-15',
     'https://test/joint27', 4, 'FENCINGTIME_XML', 'https://test/joint27', v_run_id),
    (v_event, 'VW27E-V1-F-EPEE', 'PPW', 'EPEE', 'F', 'V1', '2099-04-15',
     'https://test/joint27', 3, 'FENCINGTIME_XML', 'https://test/joint27', v_run_id),
    (v_event, 'VW27E-V2-F-EPEE', 'PPW', 'EPEE', 'F', 'V2', '2099-04-15',
     'https://test/standalone27', 5, 'FENCINGTIME_XML', 'https://test/standalone27', v_run_id);

  -- 7 result drafts: 4 in V0, 3 in V1 (no V2 results — keeps fixture small)
  -- We deliberately leave V2 with 0 results to test that empty siblings still commit
  FOR i IN 1..4 LOOP
    INSERT INTO tbl_result_draft (id_fencer, id_tournament_draft, int_place, txt_run_id)
    SELECT (SELECT id_fencer FROM tbl_fencer WHERE txt_surname='DRAFT27' AND txt_first_name='F'||i),
           td.id_tournament_draft, i, v_run_id
      FROM tbl_tournament_draft td
     WHERE td.txt_code = 'VW27E-V0-F-EPEE' AND td.txt_run_id = v_run_id;
  END LOOP;
  FOR i IN 1..3 LOOP
    INSERT INTO tbl_result_draft (id_fencer, id_tournament_draft, int_place, txt_run_id)
    SELECT (SELECT id_fencer FROM tbl_fencer WHERE txt_surname='DRAFT27' AND txt_first_name='F'||(i+4)),
           td.id_tournament_draft, i, v_run_id
      FROM tbl_tournament_draft td
     WHERE td.txt_code = 'VW27E-V1-F-EPEE' AND td.txt_run_id = v_run_id;
  END LOOP;
END;
$fix$;

-- Capture pre-commit live counts for diff assertions
CREATE TEMP TABLE _pre_commit AS
SELECT (SELECT COUNT(*)::INT FROM tbl_tournament WHERE txt_code LIKE 'VW27E-%') AS live_tournaments,
       (SELECT COUNT(*)::INT FROM tbl_result r
          JOIN tbl_tournament t ON r.id_tournament = t.id_tournament
         WHERE t.txt_code LIKE 'VW27E-%') AS live_results,
       (SELECT COUNT(*)::INT FROM tbl_audit_log
         WHERE txt_action = 'DRAFT_COMMIT') AS audit_commits,
       (SELECT COUNT(*)::INT FROM tbl_tournament_ingest_history
         WHERE txt_run_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::UUID) AS history_rows;

-- Run the commit
SELECT fn_commit_event_draft('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::UUID) AS commit_result \gset


-- ===== 27.14 — draft tournament rows moved to live =====
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_tournament WHERE txt_code LIKE 'VW27E-%')
    - (SELECT live_tournaments FROM _pre_commit),
  3,
  '27.14: fn_commit_event_draft moves all 3 draft tournament rows to tbl_tournament'
);


-- ===== 27.15 — draft result rows moved to live =====
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_result r
     JOIN tbl_tournament t ON r.id_tournament = t.id_tournament
    WHERE t.txt_code LIKE 'VW27E-%')
    - (SELECT live_results FROM _pre_commit),
  7,
  '27.15: fn_commit_event_draft moves all 7 draft result rows to tbl_result'
);


-- ===== 27.16 — draft tables emptied for this run_id =====
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_tournament_draft
    WHERE txt_run_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::UUID)
  + (SELECT COUNT(*)::INT FROM tbl_result_draft
    WHERE txt_run_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::UUID),
  0,
  '27.16: fn_commit_event_draft deletes all draft rows for the committed run_id'
);


-- ===== 27.17 — audit log rows written =====
SELECT cmp_ok(
  (SELECT COUNT(*)::INT FROM tbl_audit_log WHERE txt_action = 'DRAFT_COMMIT')
    - (SELECT audit_commits FROM _pre_commit),
  '>=',
  1,
  '27.17: fn_commit_event_draft writes at least one DRAFT_COMMIT audit row'
);


-- ===== 27.18 — ingest history appended with run_id =====
SELECT cmp_ok(
  (SELECT COUNT(*)::INT FROM tbl_tournament_ingest_history
    WHERE txt_run_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::UUID),
  '>=',
  1,
  '27.18: fn_commit_event_draft appends tbl_tournament_ingest_history with the run_id'
);


-- ===== 27.19 — joint-pool flag set on siblings sharing url_results =====
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_tournament
    WHERE txt_code IN ('VW27E-V0-F-EPEE', 'VW27E-V1-F-EPEE')
      AND bool_joint_pool_split = TRUE),
  2,
  '27.19: fn_commit_event_draft sets bool_joint_pool_split=TRUE on the 2 siblings sharing url_results'
);


-- ===== 27.20 — unknown run_id returns counts of 0, no throw =====
SELECT is(
  (fn_commit_event_draft('99999999-9999-9999-9999-999999999999'::UUID)->>'tournaments_committed')::INT,
  0,
  '27.20: fn_commit_event_draft on unknown run_id returns tournaments_committed=0 (no throw)'
);


-- =============================================================================
-- Section 8: fn_discard_event_draft behaviour
--
-- Fixture: insert a fresh draft set under run_id 'bbbb...'. Discard. Verify.
-- =============================================================================

DO $fix$
DECLARE
  v_event  INT := (SELECT id_event FROM tbl_event WHERE txt_code = 'VW27E');
  v_run_id UUID := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
BEGIN
  INSERT INTO tbl_tournament_draft (
    id_event, txt_code, enum_type, enum_weapon, enum_gender,
    enum_age_category, dt_tournament, url_results, int_participant_count,
    enum_parser_kind, txt_run_id
  ) VALUES
    (v_event, 'VW27E-DISCARD-V0', 'PPW', 'EPEE', 'M', 'V0', '2099-04-15',
     'https://test/discard27', 5, 'FENCINGTIME_XML', v_run_id),
    (v_event, 'VW27E-DISCARD-V1', 'PPW', 'EPEE', 'M', 'V1', '2099-04-15',
     'https://test/discard27', 3, 'FENCINGTIME_XML', v_run_id);
  -- A couple of result drafts (orphan id_fencer is fine — no FK on draft tables)
  INSERT INTO tbl_result_draft (id_fencer, id_tournament_draft, int_place, txt_run_id)
  SELECT 999999, td.id_tournament_draft, 1, v_run_id
    FROM tbl_tournament_draft td WHERE td.txt_run_id = v_run_id;
END;
$fix$;

CREATE TEMP TABLE _pre_discard AS
SELECT (SELECT COUNT(*)::INT FROM tbl_audit_log
         WHERE txt_action = 'DRAFT_DISCARD') AS audit_discards;

SELECT fn_discard_event_draft('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::UUID) AS discard_result \gset


-- ===== 27.21 — drafts deleted =====
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_tournament_draft
    WHERE txt_run_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::UUID)
  + (SELECT COUNT(*)::INT FROM tbl_result_draft
    WHERE txt_run_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::UUID),
  0,
  '27.21: fn_discard_event_draft deletes both draft sets for the run_id'
);


-- ===== 27.22 — discard writes audit row =====
SELECT cmp_ok(
  (SELECT COUNT(*)::INT FROM tbl_audit_log WHERE txt_action = 'DRAFT_DISCARD')
    - (SELECT audit_discards FROM _pre_discard),
  '>=',
  1,
  '27.22: fn_discard_event_draft writes at least one DRAFT_DISCARD audit row'
);


-- ===== 27.23 — unknown run_id returns counts of 0, no throw =====
SELECT is(
  (fn_discard_event_draft('77777777-7777-7777-7777-777777777777'::UUID)->>'tournaments_discarded')::INT,
  0,
  '27.23: fn_discard_event_draft on unknown run_id returns tournaments_discarded=0 (no throw)'
);


-- =============================================================================
-- Section 9: fn_dry_run_event_draft behaviour (no persistence)
-- =============================================================================

CREATE TEMP TABLE _pre_dryrun AS
SELECT (SELECT COUNT(*)::INT FROM tbl_tournament_draft) AS tdraft,
       (SELECT COUNT(*)::INT FROM tbl_result_draft)     AS rdraft;

-- Call with a non-trivial payload
SELECT fn_dry_run_event_draft(
  jsonb_build_object(
    'tournaments', jsonb_build_array(
      jsonb_build_object('txt_code', 'DRYTEST-V0', 'enum_weapon', 'EPEE',
                         'enum_gender', 'M', 'enum_age_category', 'V0',
                         'dt_tournament', '2099-05-01',
                         'url_results', 'https://dryrun/test'),
      jsonb_build_object('txt_code', 'DRYTEST-V1', 'enum_weapon', 'EPEE',
                         'enum_gender', 'M', 'enum_age_category', 'V1',
                         'dt_tournament', '2099-05-01',
                         'url_results', 'https://dryrun/test')
    ),
    'results', jsonb_build_array(
      jsonb_build_object('txt_code', 'DRYTEST-V0', 'int_place', 1),
      jsonb_build_object('txt_code', 'DRYTEST-V0', 'int_place', 2),
      jsonb_build_object('txt_code', 'DRYTEST-V1', 'int_place', 1)
    )
  )
) AS dry_result \gset


-- ===== 27.24 — dry-run does not persist anything =====
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_tournament_draft)
    - (SELECT tdraft FROM _pre_dryrun)
  + (SELECT COUNT(*)::INT FROM tbl_result_draft)
    - (SELECT rdraft FROM _pre_dryrun),
  0,
  '27.24: fn_dry_run_event_draft writes nothing to draft tables'
);


-- ===== 27.25 — empty payload returns counts of 0 =====
SELECT is(
  (fn_dry_run_event_draft(
    jsonb_build_object('tournaments', '[]'::JSONB, 'results', '[]'::JSONB)
  )->>'tournaments_would_create')::INT,
  0,
  '27.25: fn_dry_run_event_draft with empty payload returns tournaments_would_create=0'
);


-- =============================================================================
-- Section 10: idempotency
-- =============================================================================

-- ===== 27.26 — second commit on same run_id is a no-op (drafts already gone) =====
SELECT is(
  (fn_commit_event_draft('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::UUID)->>'tournaments_committed')::INT,
  0,
  '27.26: re-committing the same run_id returns tournaments_committed=0 (drafts already gone)'
);


SELECT * FROM finish();
ROLLBACK;
