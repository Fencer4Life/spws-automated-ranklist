-- =============================================================================
-- EVFCTRY.01 — the EVF ranking's fencers are kept, and nobody reads them (FR-171)
-- =============================================================================
-- tbl_evf_ranking_fencer holds what the monthly read keeps of each ranked
-- fencer: EVF id, names, gender, category and country. Only the jobs that fill
-- and read it (Management API, LOCAL's postgres) touch it; a visitor and a
-- signed-in user read nothing.
--
-- Everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(7);

SELECT has_table('tbl_evf_ranking_fencer', 'EVFCTRY.01 tbl_evf_ranking_fencer exists');
SELECT columns_are('tbl_evf_ranking_fencer',
  ARRAY['id_evf', 'txt_surname', 'txt_first_name', 'enum_gender', 'int_category', 'txt_country', 'ts_read'],
  'EVFCTRY.01 it keeps the EVF id, names, gender, category, country and when it was read; nothing else');
SELECT col_type_is('tbl_evf_ranking_fencer', 'id_evf', 'uuid',
  'EVFCTRY.01 the EVF id is the UUID EVF publishes');
SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid = 'tbl_evf_ranking_fencer'::regclass),
  'EVFCTRY.01 row security is on');

INSERT INTO tbl_evf_ranking_fencer (id_evf, txt_surname, txt_first_name, enum_gender, int_category, txt_country)
VALUES ('13400000-0000-4000-8000-000000000001', 'EVFCTRYTEST', 'Ann', 'F', 2, 'OTH');
SELECT is((SELECT txt_country FROM tbl_evf_ranking_fencer WHERE id_evf = '13400000-0000-4000-8000-000000000001'), 'OTH',
  'EVFCTRY.01 the country is kept as EVF wrote it, OTH included');

SELECT throws_ok(
  $$SET LOCAL ROLE anon;
    SELECT set_config('request.jwt.claims', '{"role":"anon"}', TRUE);
    SELECT count(*) FROM tbl_evf_ranking_fencer$$,
  '42501', NULL,
  'EVFCTRY.01 a visitor cannot read it');
RESET ROLE;

SELECT throws_ok(
  $$SET LOCAL ROLE authenticated;
    SELECT set_config('request.jwt.claims', '{"role":"authenticated","sub":"test-admin"}', TRUE);
    SELECT count(*) FROM tbl_evf_ranking_fencer$$,
  '42501', NULL,
  'EVFCTRY.01 a signed-in user cannot read it either');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
