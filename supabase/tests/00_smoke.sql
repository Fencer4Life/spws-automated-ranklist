-- pgTAP smoke test: verifies test infrastructure is working
BEGIN;
SELECT plan(1);

SELECT pass('pgTAP is working');

SELECT * FROM finish();
ROLLBACK;
