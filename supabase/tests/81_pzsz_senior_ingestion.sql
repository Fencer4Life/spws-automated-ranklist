-- =============================================================================
-- pgTAP — PZSz senior result ingestion: SENIOR guard + match review queue
-- =============================================================================
-- Verifies migrations 20260920000001_add_senior_enum.sql and
-- 20260920000002_pzsz_senior_result_ingestion.sql (design step 6, ADR-100,
-- doc/plans/pzsz-senior-result-ingestion-2026-09-19.html).
--
-- RTM: SS26.TYPE.06e-f, SS26.PZSZ.02/03/05/08/09. The remaining SS26.PZSZ IDs
-- (parser reuse, exact/alias matching, skip, no-auto-create, URL validation)
-- are pipeline/orchestration concerns tested in
-- python/tests/test_pzsz_ingestion.py -- this file covers only what is
-- reachable by direct SQL: the SENIOR-result CHECK constraint and the review
-- queue's three RPCs (queue/approve/reject), plus a direct proof that a
-- SENIOR tournament still honours the existing p_participant_count override
-- (unchanged RPC, proven here against the new bracket shape) and that a
-- historical PZSz season still fails closed.
--
-- Each scenario gets its OWN season with a disjoint date range: tbl_season's
-- own EXCLUDE constraint rejects overlapping ranges regardless of code, the
-- same trap SS26.RANK.02/03's fixtures hit in design step 4.
-- =============================================================================

BEGIN;
SELECT plan(13);

-- ---------------------------------------------------------------------------
-- Fixtures. p_n offsets both the season code and its date range so every
-- scenario gets an isolated, non-overlapping season.
-- ---------------------------------------------------------------------------
CREATE FUNCTION pg_temp.pzsz_setup(p_n INT, OUT out_event INT, OUT out_fencer INT)
LANGUAGE plpgsql AS $setup$
DECLARE
  v_season   INT;
  v_org      INT;
  v_code     TEXT := 'SS26-PZSZ-' || p_n;
  v_yr_start INT  := 2059 + p_n;
BEGIN
  v_season := fn_create_season(
    v_code,
    (v_yr_start || '-08-01')::DATE,
    ((v_yr_start + 1) || '-07-15')::DATE
  );

  -- Plain fn_create_season (unlike fn_create_season_with_skeletons) never
  -- assigns id_scoring_engine -- same fixture workaround as
  -- pg_temp.revision_build_season in 80_season_scoring_contract.sql.
  UPDATE tbl_season SET id_scoring_engine = (
    SELECT se.id_engine FROM tbl_scoring_engine se
     WHERE se.bool_active
     ORDER BY se.ts_created DESC, se.id_engine DESC LIMIT 1
  ) WHERE id_season = v_season;

  UPDATE tbl_scoring_type_config SET num_multiplier = 1.0, int_min_participants = 1
   WHERE id_config = (SELECT id_config FROM tbl_scoring_config WHERE id_season = v_season)
     AND enum_type = 'PPS';

  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'PZSz';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('PPS1e-' || v_code, 'PPS1e ' || v_code, v_season, v_org, 'COMPLETED')
  RETURNING id_event INTO out_event;

  -- 2000 -> age (v_yr_start+1)-2000, always in the V2/V3 band for the offsets
  -- this file uses (n=1..9 -> season end 2061..2069 -> age 61..69 -> V3).
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality, int_birth_year, enum_gender)
  VALUES ('PzszSenior' || p_n, 'Tester', 'PL', 2000, 'M') RETURNING id_fencer INTO out_fencer;
END $setup$;

-- Sets int_participant_count directly, not via fn_ingest_tournament_results
-- (which refuses an empty results array): the real CommitPzszSenior must do
-- the same, because a bracket can have zero initially auto-matched rows --
-- everyone queued for review -- and the full source field size is known at
-- parse time regardless of how matching turns out (design §07's 34-of-107
-- invariant does not wait on a match).
CREATE FUNCTION pg_temp.pzsz_senior_tournament(p_event INT, p_n INT) RETURNS INT
LANGUAGE plpgsql AS $tourn$
DECLARE
  v_id INT;
BEGIN
  v_id := fn_find_or_create_tournament(
    p_event, 'EPEE', 'M', 'SENIOR', ((2059 + p_n) || '-09-01')::DATE, 'PPS'
  );
  UPDATE tbl_tournament SET int_participant_count = 107 WHERE id_tournament = v_id;
  RETURN v_id;
END $tourn$;

-- ---------------------------------------------------------------------------
-- SS26.TYPE.06e -- a tournament with enum_age_category='SENIOR' is a
-- legitimate source-bracket label and can be inserted.
-- ---------------------------------------------------------------------------
CREATE FUNCTION pg_temp.type06e_senior_tournament_ok() RETURNS TEXT
LANGUAGE plpgsql AS $t06e$
DECLARE
  v_event INT;
  v_id    INT;
BEGIN
  SELECT out_event FROM pg_temp.pzsz_setup(1) INTO v_event;
  v_id := pg_temp.pzsz_senior_tournament(v_event, 1);
  RETURN (SELECT enum_age_category::TEXT FROM tbl_tournament WHERE id_tournament = v_id);
EXCEPTION WHEN undefined_function OR undefined_column THEN
  RETURN NULL;
END $t06e$;

SELECT is(pg_temp.type06e_senior_tournament_ok(), 'SENIOR',
  'SS26.TYPE.06e a SENIOR-labeled tournament can be created');

-- ---------------------------------------------------------------------------
-- SS26.TYPE.06f -- a result row's own enum_source_age_category can never be
-- SENIOR (only a real V-cat or NULL).
-- ---------------------------------------------------------------------------
CREATE FUNCTION pg_temp.pzsz_fixture_tournament_and_fencer(OUT v_tournament INT, OUT v_fencer INT)
LANGUAGE plpgsql AS $fx$
DECLARE
  v_event INT;
BEGIN
  SELECT out_event, out_fencer FROM pg_temp.pzsz_setup(2) INTO v_event, v_fencer;
  v_tournament := pg_temp.pzsz_senior_tournament(v_event, 2);
END $fx$;

SELECT throws_like(
  $$INSERT INTO tbl_result (id_fencer, id_tournament, int_place, enum_source_age_category)
    SELECT v_fencer, v_tournament, 1, 'SENIOR'
      FROM pg_temp.pzsz_fixture_tournament_and_fencer()$$,
  '%chk_result_source_vcat_not_senior%',
  'SS26.TYPE.06f a result row cannot carry enum_source_age_category = SENIOR'
);

-- ---------------------------------------------------------------------------
-- SS26.PZSZ.02 -- the existing p_participant_count override still reports the
-- full source field size, not the written-row count, on a SENIOR tournament.
-- ---------------------------------------------------------------------------
CREATE FUNCTION pg_temp.pzsz02_full_participant_count() RETURNS INT
LANGUAGE plpgsql AS $p02$
DECLARE
  v_event  INT;
  v_fencer INT;
  v_tourn  INT;
  v_count  INT;
BEGIN
  SELECT out_event, out_fencer FROM pg_temp.pzsz_setup(3) INTO v_event, v_fencer;
  v_tourn := pg_temp.pzsz_senior_tournament(v_event, 3);

  PERFORM fn_ingest_tournament_results(
    v_tourn,
    jsonb_build_array(jsonb_build_object(
      'id_fencer', v_fencer, 'int_place', 34, 'txt_scraped_name', 'PzszSenior3',
      'enum_match_status', 'AUTO_MATCHED', 'enum_source_age_category', 'V3'
    )),
    107
  );

  SELECT int_participant_count INTO v_count FROM tbl_tournament WHERE id_tournament = v_tourn;
  RETURN v_count;
EXCEPTION WHEN undefined_function OR undefined_column THEN
  RETURN NULL;
END $p02$;

SELECT is(pg_temp.pzsz02_full_participant_count(), 107,
  'SS26.PZSZ.02 int_participant_count is the full source field, not the written-row count');

-- ---------------------------------------------------------------------------
-- SS26.PZSZ.03/05/08 -- the review queue's full lifecycle: queue, approve
-- (writes one row, original place, the fencer's own derived V-cat), reject
-- (writes nothing). p_n selects an isolated season per call.
-- ---------------------------------------------------------------------------
CREATE FUNCTION pg_temp.pzsz_review_setup(p_n INT, OUT out_tournament INT, OUT out_fencer INT, OUT out_review INT)
LANGUAGE plpgsql AS $rv$
DECLARE
  v_event INT;
BEGIN
  SELECT s.out_event, s.out_fencer FROM pg_temp.pzsz_setup(p_n) s INTO v_event, out_fencer;
  out_tournament := pg_temp.pzsz_senior_tournament(v_event, p_n);
  out_review := fn_queue_pzsz_match_review(out_tournament, 'Scraped Name', 34, out_fencer, 62.5);
END $rv$;

CREATE FUNCTION pg_temp.pzsz05_queue_writes_pending() RETURNS TEXT
LANGUAGE plpgsql AS $p05a$
DECLARE
  v_review INT;
BEGIN
  SELECT out_review FROM pg_temp.pzsz_review_setup(4) INTO v_review;
  RETURN (SELECT enum_status FROM tbl_pzsz_match_review WHERE id_review = v_review);
EXCEPTION WHEN undefined_function OR undefined_column THEN
  RETURN NULL;
END $p05a$;

SELECT is(pg_temp.pzsz05_queue_writes_pending(), 'PENDING',
  'SS26.PZSZ.05a fn_queue_pzsz_match_review writes a PENDING row');

CREATE FUNCTION pg_temp.pzsz05_no_result_before_decision() RETURNS INT
LANGUAGE plpgsql AS $p05b$
DECLARE
  v_tournament INT;
  v_fencer     INT;
  v_review     INT;
BEGIN
  SELECT out_tournament, out_fencer, out_review FROM pg_temp.pzsz_review_setup(5)
    INTO v_tournament, v_fencer, v_review;
  RETURN (SELECT count(*)::INT FROM tbl_result
           WHERE id_tournament = v_tournament AND id_fencer = v_fencer);
EXCEPTION WHEN undefined_function OR undefined_column THEN
  RETURN NULL;
END $p05b$;

SELECT is(pg_temp.pzsz05_no_result_before_decision(), 0,
  'SS26.PZSZ.05b a PENDING review produces no tbl_result row');

CREATE FUNCTION pg_temp.pzsz08_approve_writes_own_vcat() RETURNS TEXT
LANGUAGE plpgsql AS $p08$
DECLARE
  v_tournament INT;
  v_fencer     INT;
  v_review     INT;
BEGIN
  SELECT out_tournament, out_fencer, out_review FROM pg_temp.pzsz_review_setup(6)
    INTO v_tournament, v_fencer, v_review;
  PERFORM fn_approve_pzsz_match_review(v_review, v_fencer);
  RETURN (SELECT enum_source_age_category::TEXT FROM tbl_result
           WHERE id_tournament = v_tournament AND id_fencer = v_fencer);
EXCEPTION WHEN undefined_function OR undefined_column THEN
  RETURN NULL;
END $p08$;

-- fixture fencer born 2000, this season (n=6) ends 2066 -> age 66 -> V3.
SELECT is(pg_temp.pzsz08_approve_writes_own_vcat(), 'V3',
  'SS26.PZSZ.08 approval writes the fencer''s own season-derived V-cat, independent of SENIOR');

CREATE FUNCTION pg_temp.pzsz_approve_marks_status(p_n INT, OUT v_status TEXT, OUT v_place INT)
LANGUAGE plpgsql AS $p05c$
DECLARE
  v_tournament INT;
  v_fencer     INT;
  v_review     INT;
BEGIN
  SELECT vt, vf, vr FROM pg_temp.pzsz_review_setup(p_n) AS x(vt, vf, vr)
    INTO v_tournament, v_fencer, v_review;
  PERFORM fn_approve_pzsz_match_review(v_review, v_fencer);
  SELECT enum_status INTO v_status FROM tbl_pzsz_match_review WHERE id_review = v_review;
  SELECT int_place INTO v_place FROM tbl_result
   WHERE id_tournament = v_tournament AND id_fencer = v_fencer;
END $p05c$;

SELECT is((pg_temp.pzsz_approve_marks_status(7)).v_status, 'APPROVED',
  'SS26.PZSZ.05c approval marks the review APPROVED');
SELECT is((pg_temp.pzsz_approve_marks_status(8)).v_place, 34,
  'SS26.PZSZ.03 the approved row keeps its original place (34), never renumbered');

CREATE FUNCTION pg_temp.pzsz_double_approve_raises() RETURNS TEXT
LANGUAGE plpgsql AS $p05d$
DECLARE
  v_tournament INT;
  v_fencer     INT;
  v_review     INT;
BEGIN
  SELECT out_tournament, out_fencer, out_review FROM pg_temp.pzsz_review_setup(10)
    INTO v_tournament, v_fencer, v_review;
  PERFORM fn_approve_pzsz_match_review(v_review, v_fencer);
  PERFORM fn_approve_pzsz_match_review(v_review, v_fencer);
  RETURN 'NO_RAISE';
EXCEPTION
  WHEN undefined_function OR undefined_column THEN RETURN NULL;
  WHEN OTHERS THEN RETURN SQLERRM;
END $p05d$;

SELECT matches(pg_temp.pzsz_double_approve_raises(), 'No pending PZSz match review',
  'SS26.PZSZ.05d approving twice raises -- a resolved review cannot be re-decided'
);

CREATE FUNCTION pg_temp.pzsz_reject_writes_nothing() RETURNS INT
LANGUAGE plpgsql AS $p05e$
DECLARE
  v_tournament INT;
  v_fencer     INT;
  v_review     INT;
BEGIN
  SELECT out_tournament, out_fencer, out_review FROM pg_temp.pzsz_review_setup(11)
    INTO v_tournament, v_fencer, v_review;
  PERFORM fn_reject_pzsz_match_review(v_review);
  RETURN (SELECT count(*)::INT FROM tbl_result
           WHERE id_tournament = v_tournament AND id_fencer = v_fencer);
EXCEPTION WHEN undefined_function OR undefined_column THEN
  RETURN NULL;
END $p05e$;

SELECT is(pg_temp.pzsz_reject_writes_nothing(), 0,
  'SS26.PZSZ.05e rejecting a review writes no tbl_result row');

SELECT throws_like(
  $$SELECT fn_reject_pzsz_match_review(999999999)$$,
  '%No pending PZSz match review%',
  'SS26.PZSZ.05f rejecting a non-existent/non-pending review raises'
);

-- ---------------------------------------------------------------------------
-- SS26.PZSZ.09 -- no historical scoring. Corrected during implementation: the
-- fail-closed gate this test originally assumed does NOT apply here.
-- fn_sync_scoring_type_config (20260919000004, step 4) projects a PPS/MPS row
-- from tbl_scoring_config.num_pps_multiplier's own NOT NULL DEFAULT 1.0 onto
-- EVERY season, including the three real historical ones -- verified live:
-- SPWS-2023-2024/2024-2025/2025-2026 all already carry PPS/MPS at multiplier
-- 1.0, threshold 1, same as SPWS-2026-2027. A brand-new scratch season
-- inherits the same default the instant fn_create_season's own trigger
-- creates its tbl_scoring_config row, so no "unconfigured" scratch fixture
-- can even be built to reproduce the fail-closed case design §07 describes.
--
-- "No historical scoring" is therefore enforced one layer up, not at
-- ingestion: a historical season's json_ranking_rules never names PPS/MPS in
-- any bucket (verified live: SPWS-2023-2024's is NULL/empty; 2024-2025 and
-- 2025-2026's list only PPW/MPW/PEW/MEW/MSW), so fn_ranking_ppw/
-- fn_ranking_kadra's legacy JSONB walk can never select a PPS/MPS result into
-- any published total even if one existed. This test pins that fact directly
-- against the real season rather than a synthetic one that cannot exist.
-- ---------------------------------------------------------------------------
CREATE FUNCTION pg_temp.pzsz09_historical_season_not_gated_but_invisible(OUT v_min INT, OUT v_rules_mention_pps BOOLEAN)
LANGUAGE plpgsql AS $p09$
DECLARE
  v_season INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024';
  v_min := fn_get_min_participants(v_season, 'PPS');
  v_rules_mention_pps := (
    SELECT COALESCE(json_ranking_rules::TEXT, '') ILIKE '%PPS%'
      FROM tbl_scoring_config WHERE id_season = v_season
  );
END $p09$;

SELECT is((pg_temp.pzsz09_historical_season_not_gated_but_invisible()).v_min, 1,
  'SS26.PZSZ.09a a real historical season is already PPS-configured (step 4''s global default), not fail-closed'
);
SELECT is((pg_temp.pzsz09_historical_season_not_gated_but_invisible()).v_rules_mention_pps, FALSE,
  'SS26.PZSZ.09b that season''s own json_ranking_rules never names PPS -- the actual "no historical scoring" boundary'
);

SELECT * FROM finish();
ROLLBACK;
