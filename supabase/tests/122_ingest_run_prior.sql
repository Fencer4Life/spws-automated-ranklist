-- =============================================================================
-- RUN.PRIOR — the run records the prior it started from (ADR-119 §3, G17)
-- =============================================================================
-- A recorded CERT run applies against what CERT held when it began (B3): its
-- own result fingerprint, or none. fn_ingest_run_open stores that prior on the
-- row (tbl_ingest_run.txt_prior_fingerprint), so promote can accept PROD
-- holding exactly it: the same change, made from the same start, even after a
-- recompute moved both sides away from every earlier run's fingerprint. A
-- caller that names no prior (the code before release 2) keeps working and
-- stores NULL. Everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(4);

INSERT INTO tbl_season (txt_code, dt_start, dt_end) VALUES ('SPWS-2085-2086', DATE '2085-09-01', DATE '2086-06-30');
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, enum_status)
SELECT 'PPW7-2085-2086', 'RUN.PRIOR fixture', id_season, (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
       DATE '2085-10-10', DATE '2085-10-11', 'PLANNED'
  FROM tbl_season WHERE txt_code = 'SPWS-2085-2086';

-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT fn_ingest_run_open('PPW7-2085-2086', 'cert', repeat('a', 40), 2086,
                          'https://www.fencingtimelive.com/tournaments/eventSchedule/PRIOR', NULL, NULL,
                          repeat('b', 64)) AS with_prior \gset

SELECT is((SELECT txt_prior_fingerprint FROM tbl_ingest_run WHERE id_ingest_run = :with_prior), repeat('b', 64),
  'RUN.PRIOR.01 the run records the prior it started from');

-- As the code before release 2 calls it: by name, without a prior.
-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT fn_ingest_run_open(p_event_code => 'PPW7-2085-2086', p_environment => 'cert', p_git_commit => repeat('c', 40),
                          p_season_end_year => 2086,
                          p_url_event => 'https://www.fencingtimelive.com/tournaments/eventSchedule/PRIOR',
                          p_run_url => NULL, p_override_sha256 => NULL) AS without_prior \gset

SELECT ok((SELECT txt_prior_fingerprint IS NULL FROM tbl_ingest_run WHERE id_ingest_run = :without_prior),
  'RUN.PRIOR.02 a caller that names no prior still opens a run, with none recorded');

SELECT throws_ok($$SELECT fn_ingest_run_open('PPW7-2085-2086', 'cert', repeat('d', 40), 2086,
                                             'https://www.fencingtimelive.com/tournaments/eventSchedule/PRIOR',
                                             NULL, NULL, 'not-a-fingerprint')$$,
  '23514', NULL,
  'RUN.PRIOR.03 a prior that is not a result fingerprint is refused');

SELECT ok((SELECT count(*) FROM pg_proc WHERE proname = 'fn_ingest_run_open') = 1
      AND NOT has_function_privilege('anon', 'fn_ingest_run_open(text,text,text,integer,text,text,text,text)', 'EXECUTE')
      AND NOT has_function_privilege('authenticated', 'fn_ingest_run_open(text,text,text,integer,text,text,text,text)', 'EXECUTE')
      AND has_function_privilege('service_role', 'fn_ingest_run_open(text,text,text,integer,text,text,text,text)', 'EXECUTE'),
  'RUN.PRIOR.04 one fn_ingest_run_open, for the service role only');

SELECT * FROM finish();
ROLLBACK;
