-- =============================================================================
-- NAT.SEASON / NAT.EVID / ADM.ID.09 — nationality per season, fixed for the season
-- =============================================================================
-- ADR-106 §3 (decided 2 Oct 2026): a fencer may represent different
-- federations in different seasons, never within one. Each stored result keeps
-- the federation its source printed (tbl_result.txt_entered_for); the season's
-- nationality (tbl_fencer_nationality, one row per fencer and season) is the
-- federation of the season's earliest-dated result that carries one. A later
-- start printing another federation does not change it: it is listed in
-- vw_fencer_nationality_conflict. A trigger on tbl_result keeps the table, so
-- every path that stores, moves or deletes a result keeps it too.
-- ADM.ID.09: fn_spws_starter_ids lists the fencers with a PPW or MPW result,
-- the set ADR-106 §1 admits international results for.
-- doc/plans/adr-106-identity-intake-and-season-nationality-plan-2026-10-02.html.
-- Rolls back.
-- =============================================================================

BEGIN;

ALTER TABLE tbl_result DISABLE TRIGGER trg_assert_result_vcat;

SELECT plan(13);

CREATE TEMP TABLE nat_ids (k TEXT PRIMARY KEY, v INT) ON COMMIT DROP;

DO $fx$
DECLARE v_evf INT; v_spws INT; v_s INT; v_e INT; v_d INT; v_t INT; v_f INT;
BEGIN
  SELECT id_organizer INTO v_evf FROM tbl_organizer WHERE txt_code = 'EVF';
  SELECT id_organizer INTO v_spws FROM tbl_organizer WHERE txt_code = 'SPWS';
  SELECT id_season INTO v_s FROM tbl_season WHERE txt_code = 'SPWS-2025-2026';
  INSERT INTO nat_ids VALUES ('season', v_s);

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('PEW97e-2025-2026', 'NAT international', v_s, v_evf, 'COMPLETED') RETURNING id_event INTO v_e;
  INSERT INTO nat_ids VALUES ('pew_event', v_e);
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('PPW97-2025-2026', 'NAT domestic', v_s, v_spws, 'COMPLETED') RETURNING id_event INTO v_d;
  INSERT INTO nat_ids VALUES ('ppw_event', v_d);

  -- Three dated international tournaments of one season, and one domestic.
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
    enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_e, 'NAT-NOV', 'NAT November', 'PEW', 'EPEE', 'M', 'V1', '2025-11-15', 30, 'PLANNED')
  RETURNING id_tournament INTO v_t;
  INSERT INTO nat_ids VALUES ('t_nov', v_t);
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
    enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_e, 'NAT-MAR', 'NAT March', 'PEW', 'EPEE', 'M', 'V1', '2026-03-08', 30, 'PLANNED')
  RETURNING id_tournament INTO v_t;
  INSERT INTO nat_ids VALUES ('t_mar', v_t);
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
    enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_e, 'NAT-SEP', 'NAT September', 'PEW', 'EPEE', 'M', 'V1', '2025-09-20', 30, 'PLANNED')
  RETURNING id_tournament INTO v_t;
  INSERT INTO nat_ids VALUES ('t_sep', v_t);
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
    enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_d, 'NAT-PPW', 'NAT PPW', 'PPW', 'EPEE', 'M', 'V1', '2025-10-04', 12, 'PLANNED')
  RETURNING id_tournament INTO v_t;
  INSERT INTO nat_ids VALUES ('t_ppw', v_t);

  INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality, int_birth_year, enum_gender)
  VALUES ('NAT-KULKA', 'Test', 'PL', 1979, 'M') RETURNING id_fencer INTO v_f;
  INSERT INTO nat_ids VALUES ('kulka', v_f);
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality, int_birth_year, enum_gender)
  VALUES ('NAT-KOLLAR', 'Test', 'PL', 1950, 'M') RETURNING id_fencer INTO v_f;
  INSERT INTO nat_ids VALUES ('kollar', v_f);
END $fx$;

CREATE FUNCTION pg_temp.id(p_k TEXT) RETURNS INT LANGUAGE sql AS $$
  SELECT v FROM nat_ids WHERE k = p_k;
$$;

CREATE FUNCTION pg_temp.season_country(p_f TEXT) RETURNS TEXT LANGUAGE sql AS $$
  SELECT txt_country FROM tbl_fencer_nationality
   WHERE id_fencer = pg_temp.id(p_f) AND id_season = pg_temp.id('season');
$$;

CREATE FUNCTION pg_temp.conflicts(p_f TEXT) RETURNS TEXT LANGUAGE sql AS $$
  SELECT COALESCE(string_agg(txt_entered_for, ',' ORDER BY txt_entered_for), '')
    FROM vw_fencer_nationality_conflict
   WHERE id_fencer = pg_temp.id(p_f) AND id_season = pg_temp.id('season');
$$;

-- NAT.SEASON.01 — the shape
SELECT col_is_pk('tbl_fencer_nationality', ARRAY['id_fencer', 'id_season'],
  'NAT.SEASON.01 one nationality per fencer and season: the key is (id_fencer, id_season)');
SELECT throws_ok(
  format($$INSERT INTO tbl_fencer_nationality (id_fencer, id_season, txt_country, enum_source)
           VALUES (%s, %s, 'Poland', 'ADMIN')$$, pg_temp.id('kollar'), pg_temp.id('season')),
  '23514', NULL,
  'NAT.SEASON.01 a federation is a three-letter code: "Poland" is refused');

-- NAT.EVID.03 — the ingest RPC (EVF sync, Admin scrape, recompute) stores the evidence
SELECT fn_ingest_tournament_results(pg_temp.id('t_nov'),
  jsonb_build_array(jsonb_build_object('id_fencer', pg_temp.id('kulka'), 'int_place', 10,
    'txt_scraped_name', 'NAT-KULKA Test', 'txt_entered_for', 'IRL')), 30);
SELECT is(
  (SELECT txt_entered_for FROM tbl_result WHERE id_tournament = pg_temp.id('t_nov')
      AND id_fencer = pg_temp.id('kulka')),
  'IRL',
  'NAT.EVID.03 fn_ingest_tournament_results stores txt_entered_for');

-- NAT.SEASON.02 — the first result with a federation sets the season
SELECT is(pg_temp.season_country('kulka'), 'IRL',
  'NAT.SEASON.02 a stored international result with a federation creates the season row');

-- NAT.SEASON.03 — a later start printing another federation changes nothing
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name, txt_entered_for)
VALUES (pg_temp.id('kulka'), pg_temp.id('t_mar'), 12, 'NAT-KULKA Test', 'POL');
SELECT is(pg_temp.season_country('kulka'), 'IRL',
  'NAT.SEASON.03 a later-dated start printing POL leaves the season IRL');
SELECT is(pg_temp.conflicts('kulka'), 'POL',
  'NAT.SEASON.03 the later start is listed as a conflict');

-- NAT.SEASON.04 — an earlier start stored afterwards takes over
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name, txt_entered_for)
VALUES (pg_temp.id('kulka'), pg_temp.id('t_sep'), 6, 'NAT-KULKA Test', 'GBR');
SELECT is(pg_temp.season_country('kulka') || '|' || pg_temp.conflicts('kulka'), 'GBR|IRL,POL',
  'NAT.SEASON.04 the earliest-dated start fixes the season whatever the order of ingestion');

-- NAT.SEASON.05 — deleting the result that fixed it recomputes; none left removes it
DELETE FROM tbl_result WHERE id_tournament = pg_temp.id('t_sep');
SELECT is(pg_temp.season_country('kulka'), 'IRL',
  'NAT.SEASON.05 deleting the fixing result recomputes the season from the rest');
DELETE FROM tbl_match_candidate WHERE id_result IN (
  SELECT r.id_result FROM tbl_result r JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   WHERE t.id_event = pg_temp.id('pew_event'));
DELETE FROM tbl_result
 WHERE id_tournament IN (SELECT id_tournament FROM tbl_tournament WHERE id_event = pg_temp.id('pew_event'));
SELECT is(pg_temp.season_country('kulka'), NULL,
  'NAT.SEASON.05 with no result left the season row goes');
INSERT INTO tbl_fencer_nationality (id_fencer, id_season, txt_country, enum_source)
VALUES (pg_temp.id('kollar'), pg_temp.id('season'), 'SVK', 'ADMIN');
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name, txt_entered_for)
VALUES (pg_temp.id('kollar'), pg_temp.id('t_ppw'), 3, 'NAT-KOLLAR Test', 'CZE');
DELETE FROM tbl_result WHERE id_tournament = pg_temp.id('t_ppw');
SELECT is(pg_temp.season_country('kollar'), 'SVK',
  'NAT.SEASON.05 an admin entry is kept as entered');

-- NAT.EVID.02 — a committed draft carries the evidence into tbl_result
DO $draft$
DECLARE v_run UUID := gen_random_uuid(); v_td INT;
BEGIN
  INSERT INTO tbl_tournament_draft (id_event, txt_code, enum_type, enum_weapon, enum_gender,
    enum_age_category, dt_tournament, url_results, int_participant_count, enum_parser_kind,
    txt_source_url_used, txt_run_id)
  VALUES (pg_temp.id('pew_event'), 'NAT-DRAFT', 'PEW', 'FOIL', 'M', 'V1', '2025-12-06',
          'https://test/nat', 20, 'FENCINGTIME_XML', 'https://test/nat', v_run)
  RETURNING id_tournament_draft INTO v_td;
  INSERT INTO tbl_result_draft (id_fencer, id_tournament_draft, int_place, txt_run_id,
    txt_scraped_name, enum_match_method, txt_entered_for)
  VALUES (pg_temp.id('kulka'), v_td, 4, v_run, 'NAT-KULKA Test', 'AUTO_MATCH', 'IRL');
  PERFORM fn_commit_event_draft(v_run);
END $draft$;
SELECT is(
  (SELECT r.txt_entered_for FROM tbl_result r JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
    WHERE t.txt_code = 'NAT-DRAFT'),
  'IRL',
  'NAT.EVID.02 fn_commit_event_draft copies txt_entered_for into tbl_result');

-- ADM.ID.09 — the SPWS starters: a PPW or MPW result, any season
INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
  enum_age_category, dt_tournament, int_participant_count, enum_import_status)
VALUES (pg_temp.id('ppw_event'), 'NAT-PPW2', 'NAT PPW 2', 'PPW', 'FOIL', 'M', 'V1', '2025-10-05', 12, 'PLANNED');
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
VALUES (pg_temp.id('kollar'), (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'NAT-PPW2'), 2, 'NAT-KOLLAR Test');
SELECT ok(
  pg_temp.id('kollar') = ANY (fn_spws_starter_ids())
  AND NOT (pg_temp.id('kulka') = ANY (fn_spws_starter_ids())),
  'ADM.ID.09 fn_spws_starter_ids lists a fencer with a PPW result, not one with international results only');

-- NAT.SEASON.06 — grants
SELECT ok(
  NOT has_table_privilege('anon', 'tbl_fencer_nationality', 'SELECT')
  AND NOT has_table_privilege('anon', 'vw_fencer_nationality_conflict', 'SELECT')
  AND NOT has_function_privilege('anon', 'fn_spws_starter_ids()', 'EXECUTE')
  AND NOT has_table_privilege('authenticated', 'tbl_fencer_nationality', 'INSERT'),
  'NAT.SEASON.06 anon reads nothing and runs nothing; only the trigger writes the table');

SELECT * FROM finish();
ROLLBACK;
