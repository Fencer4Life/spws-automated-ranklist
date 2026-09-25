-- =============================================================================
-- pgTAP — every foreign key on a seed-exported table is handled by the exporter
-- =============================================================================
-- This file exists because of a silent two-week outage of the restore path.
--
-- python/pipeline/export_seed.py is SCHEMA-DRIVEN (ADR-036): discover_cols()
-- reads information_schema at runtime, so a column added by a migration starts
-- being emitted the same day, with nobody writing a line of exporter code. That
-- is the property that keeps the dump current, and it is also the failure mode:
-- when a migration adds a FOREIGN KEY column, the exporter cheerfully emits the
-- raw id while knowing nothing about the table it points at.
--
-- That happened on 2026-09-19. The versioned-scoring migrations added
-- tbl_season.id_active_scoring_revision and tbl_result.id_scoring_revision,
-- both referencing tbl_scoring_config_revision — a table the exporter did not
-- emit, and which is CIRCULAR with tbl_season, so no ordering of plain INSERTs
-- could have satisfied it either. Every dump taken from that day on failed to
-- load. Nothing noticed until 2026-09-24, because CI's fresh bootstrap loads
-- the COMMITTED seed_prod_latest.sql symlink — which still pointed at the
-- 12 September file, generated before the migrations landed. CI cannot catch a
-- broken exporter by loading a seed the exporter did not just produce.
--
-- So the gate is here instead, at the moment of the trigger rather than the
-- moment of the symptom: adding a foreign key to a seed-exported table fails
-- this test until somebody states how the exporter carries it. The choices are
-- the three the exporter already uses:
--
--   RESOLVED  — emitted as a sub-SELECT on the target's natural key, the way
--               every portable FK in that file works.
--   DEFERRED  — left out of the INSERT and set by a later UPDATE, for a cycle
--               that no INSERT ordering can satisfy.
--   SKIPPED   — not emitted at all, because it is engine output that the
--               post-seed recompute repopulates.
--
-- If you are reading this because the test just failed: open export_seed.py,
-- decide which of the three applies, implement it, and add the column below
-- with a one-line reason. Do not add it here alone — the list is a record of
-- what the exporter does, not a permission to ignore a column.
--
-- Plan-test-ID 83 (this file).
-- =============================================================================

BEGIN;

SELECT plan(2);

-- ----------------------------------------------------------------------------
-- The tables export_seed.py emits, and every FK column on them that the
-- exporter knowingly handles. Inlined as CTEs rather than TEMP tables so that
-- postgrestools can resolve every relation in this file (it does not see a
-- temp schema, and reports 42P01 for each reference).
-- ----------------------------------------------------------------------------

-- 83.1 — no unhandled foreign key on any exported table.
SELECT is_empty(
  $$
  WITH exported(txt_table) AS (VALUES
    ('tbl_season'), ('tbl_organizer'), ('tbl_fencer'), ('tbl_event'),
    ('tbl_tournament'), ('tbl_result'), ('tbl_scoring_config_revision')
  ),
  handled(txt_table, txt_column, txt_policy) AS (VALUES
    -- Cycle: tbl_season <-> tbl_scoring_config_revision, neither deferrable.
    ('tbl_season',                  'id_active_scoring_revision', 'DEFERRED'),
    -- tbl_scoring_engine is reference data seeded by 20260919000001, so the
    -- ids only line up by insert order. Resolved on txt_code, like every
    -- other FK in that file.
    ('tbl_season',                  'id_scoring_engine',          'RESOLVED'),
    ('tbl_scoring_config_revision', 'id_season',                  'RESOLVED'),
    ('tbl_scoring_config_revision', 'id_engine',                  'RESOLVED'),
    ('tbl_event',                   'id_season',                  'RESOLVED'),
    ('tbl_event',                   'id_organizer',               'RESOLVED'),
    -- Self-reference; rows it cannot resolve are reported as a NOTICE and
    -- left for manual assignment rather than guessed.
    ('tbl_event',                   'id_prior_event',             'RESOLVED'),
    ('tbl_tournament',              'id_event',                   'RESOLVED'),
    ('tbl_result',                  'id_fencer',                  'RESOLVED'),
    ('tbl_result',                  'id_tournament',              'RESOLVED'),
    -- Scoring-engine output, like the four score columns beside it in _R_SKIP:
    -- fn_calc_tournament_scores rewrites it on the post-seed recompute.
    ('tbl_result',                  'id_scoring_revision',        'SKIPPED')
  )
  SELECT c.conrelid::regclass::TEXT || '.' || a.attname AS unhandled
    FROM pg_constraint c
    JOIN unnest(c.conkey) AS k(attnum) ON TRUE
    JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.attnum
   WHERE c.contype = 'f'
     AND c.conrelid::regclass::TEXT IN (SELECT txt_table FROM exported)
     AND NOT EXISTS (
       SELECT 1 FROM handled h
        WHERE h.txt_table  = c.conrelid::regclass::TEXT
          AND h.txt_column = a.attname)
  $$,
  '83.1 every FK on a seed-exported table is declared handled in export_seed.py'
);

-- 83.2 — the list above does not rot in the other direction. A column named
-- there that no longer carries a foreign key means a migration dropped it and
-- the exporter is still working around something that is gone.
SELECT is_empty(
  $$
  WITH handled(txt_table, txt_column) AS (VALUES
    ('tbl_season',                  'id_active_scoring_revision'),
    ('tbl_season',                  'id_scoring_engine'),
    ('tbl_scoring_config_revision', 'id_season'),
    ('tbl_scoring_config_revision', 'id_engine'),
    ('tbl_event',                   'id_season'),
    ('tbl_event',                   'id_organizer'),
    ('tbl_event',                   'id_prior_event'),
    ('tbl_tournament',              'id_event'),
    ('tbl_result',                  'id_fencer'),
    ('tbl_result',                  'id_tournament'),
    ('tbl_result',                  'id_scoring_revision')
  )
  SELECT h.txt_table || '.' || h.txt_column AS stale
    FROM handled h
   WHERE NOT EXISTS (
     SELECT 1
       FROM pg_constraint c
       JOIN unnest(c.conkey) AS k(attnum) ON TRUE
       JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.attnum
      WHERE c.contype = 'f'
        AND c.conrelid::regclass::TEXT = h.txt_table
        AND a.attname = h.txt_column)
  $$,
  '83.2 no declared FK handling refers to a column that is no longer a FK'
);

SELECT * FROM finish();
ROLLBACK;
