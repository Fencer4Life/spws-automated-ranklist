-- =============================================================================
-- LEDGER.01 — the promote ledger on the CERT run row (ADR-119 §3, D10)
-- =============================================================================
-- Promote records the outcome of every attempt on PROD on the CERT run it
-- replayed: tbl_ingest_run.jsonb_promote, written by fn_ingest_run_promote
-- (service role only) through a writable Management-API transport. One entry
-- per run, the latest attempt: applied, skipped or refused, the fingerprint
-- PROD reached, the reason, the Actions run, and the database's time. The
-- daily close quotes it. Everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(8);

INSERT INTO tbl_season (txt_code, dt_start, dt_end) VALUES ('SPWS-2087-2088', DATE '2087-09-01', DATE '2088-06-30');
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, enum_status)
SELECT 'PPW7-2087-2088', 'LEDGER fixture', id_season, (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
       DATE '2087-10-10', DATE '2087-10-11', 'PLANNED'
  FROM tbl_season WHERE txt_code = 'SPWS-2087-2088';

-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT fn_ingest_run_open('PPW7-2087-2088', 'cert', repeat('a', 40), 2088,
                          'https://www.fencingtimelive.com/tournaments/eventSchedule/LEDGER', NULL, NULL) AS run_id \gset

SELECT ok(NOT has_function_privilege('anon', 'fn_ingest_run_promote(bigint,jsonb)', 'EXECUTE')
      AND NOT has_function_privilege('authenticated', 'fn_ingest_run_promote(bigint,jsonb)', 'EXECUTE')
      AND has_function_privilege('service_role', 'fn_ingest_run_promote(bigint,jsonb)', 'EXECUTE'),
  'LEDGER.01 only the service role writes the ledger');

SELECT fn_ingest_run_promote(:run_id, jsonb_build_object(
  'outcome', 'refused', 'fingerprint', NULL,
  'reason', 'The gate blocks promote of PPW7-2087-2088 (CERT run 1).',
  'run_url', 'https://github.com/Fencer4Life/SPWSranklist/actions/runs/1'));

SELECT ok((SELECT jsonb_promote->>'outcome' FROM tbl_ingest_run WHERE id_ingest_run = :run_id) = 'refused'
      AND (SELECT jsonb_promote->>'reason' FROM tbl_ingest_run WHERE id_ingest_run = :run_id)
          = 'The gate blocks promote of PPW7-2087-2088 (CERT run 1).'
      AND (SELECT jsonb_promote->>'run_url' FROM tbl_ingest_run WHERE id_ingest_run = :run_id)
          = 'https://github.com/Fencer4Life/SPWSranklist/actions/runs/1'
      AND (SELECT (jsonb_promote->>'ts')::TIMESTAMPTZ FROM tbl_ingest_run WHERE id_ingest_run = :run_id) = now(),
  'LEDGER.01 a refusal is stored with its reason, the Actions run and the database''s time');

SELECT fn_ingest_run_promote(:run_id, jsonb_build_object(
  'outcome', 'applied', 'fingerprint', repeat('f', 64), 'reason', NULL, 'run_url', NULL));

SELECT ok((SELECT jsonb_promote->>'outcome' FROM tbl_ingest_run WHERE id_ingest_run = :run_id) = 'applied'
      AND (SELECT jsonb_promote->>'fingerprint' FROM tbl_ingest_run WHERE id_ingest_run = :run_id) = repeat('f', 64)
      AND (SELECT jsonb_promote ? 'reason' FROM tbl_ingest_run WHERE id_ingest_run = :run_id),
  'LEDGER.01 the latest attempt replaces the entry');

SELECT throws_like(format($$SELECT fn_ingest_run_promote(%s, '{"outcome": "maybe", "fingerprint": null}')$$, :run_id::BIGINT),
  'INGEST_RUN_PROMOTE_OUTCOME%',
  'LEDGER.01 an unknown outcome is refused');

SELECT throws_like(format($$SELECT fn_ingest_run_promote(%s, '{"outcome": "refused", "reason": " "}')$$, :run_id::BIGINT),
  'INGEST_RUN_PROMOTE_REASON%',
  'LEDGER.01 a refusal without a reason is refused');

SELECT throws_like(format($$SELECT fn_ingest_run_promote(%s, '{"outcome": "skipped", "fingerprint": "abc"}')$$, :run_id::BIGINT),
  'INGEST_RUN_PROMOTE_FINGERPRINT%',
  'LEDGER.01 an applied or skipped entry carries the fingerprint PROD holds');

SELECT throws_like(format($$SELECT fn_ingest_run_promote(%s, '{"outcome": "refused", "reason": "x", "run_url": "https://evil.example/r"}')$$, :run_id::BIGINT),
  'INGEST_RUN_PROMOTE_URL%',
  'LEDGER.01 the run URL is an Actions run on github.com or nothing');

SELECT throws_like($$SELECT fn_ingest_run_promote(-1, '{"outcome": "refused", "reason": "x"}')$$,
  'INGEST_RUN_NOT_FOUND%',
  'LEDGER.01 an unknown run is refused');

SELECT * FROM finish();
ROLLBACK;
