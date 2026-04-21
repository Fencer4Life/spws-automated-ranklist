-- pgTAP smoke test: verifies test infrastructure + seed data integrity
BEGIN;
SELECT plan(4);

SELECT pass('pgTAP is working');

-- Seed data integrity: match candidates must exist for Identity Manager UI
SELECT ok(
  (SELECT COUNT(*)::INT > 0 FROM tbl_match_candidate),
  'Seed data: tbl_match_candidate has rows (Identity Manager needs them)'
);

-- Seed data integrity: results must reference fencers
SELECT ok(
  (SELECT COUNT(*)::INT > 0 FROM tbl_result WHERE id_fencer IS NOT NULL),
  'Seed data: tbl_result has fencer-linked rows'
);

-- Seed data integrity: every tournament must have a date (drilldown UI relies
-- on dt_tournament; NULL collapses the "Data" column to an em-dash and also
-- breaks per-weekend filters). Backfilled 2026-04-21 from event dt_start.
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_tournament WHERE dt_tournament IS NULL),
  0,
  'Seed data: every tbl_tournament row has dt_tournament populated'
);

SELECT * FROM finish();
ROLLBACK;
