-- pgTAP smoke test: verifies test infrastructure + seed data integrity
BEGIN;
SELECT plan(3);

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

SELECT * FROM finish();
ROLLBACK;
