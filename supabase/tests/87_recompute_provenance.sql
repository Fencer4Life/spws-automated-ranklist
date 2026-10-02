-- =============================================================================
-- RECOMP.PROV — the ingest RPC writes a recompute's stored provenance verbatim
-- =============================================================================
-- RECOMPUTE_DOMESTIC (ADR-072) rewrites each result through
-- fn_ingest_tournament_results with the name, confidence and match method it
-- read back from the row (python/tests/test_recompute_provenance.py). For that
-- write to be verbatim, the RPC must keep a NULL it is handed:
--   * a "num_confidence": null stays NULL; it became 100 before. No caller
--     sends an explicit null except the recompute; an absent key still means
--     100.
--   * a "txt_scraped_name": null is stored as NULL with no match candidate,
--     whose name is NOT NULL. The rows stored that way (early EVF imports)
--     have no candidate today; the write used to fail on them.
--
-- Everything rolls back.
-- =============================================================================

BEGIN;

-- Fixtures carry V-cats that do not follow from the dummy birth years.
ALTER TABLE tbl_result DISABLE TRIGGER trg_assert_result_vcat;

SELECT plan(5);

CREATE TEMP TABLE prov_ids (k TEXT PRIMARY KEY, v INT) ON COMMIT DROP;

DO $fx$
DECLARE v_spws INT; v_s26 INT; v_e INT; v_t INT; v_f INT;
BEGIN
  SELECT id_organizer INTO v_spws FROM tbl_organizer WHERE txt_code = 'SPWS';
  SELECT id_season INTO v_s26 FROM tbl_season WHERE txt_code = 'SPWS-2025-2026';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('PPW97-2025-2026', 'PROV recompute', v_s26, v_spws, 'PLANNED') RETURNING id_event INTO v_e;
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
    enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_e, 'PROV-PPW', 'PROV PPW', 'PPW', 'EPEE', 'M', 'V1', '2025-11-12', NULL, 'PLANNED')
  RETURNING id_tournament INTO v_t;
  INSERT INTO prov_ids VALUES ('t', v_t);

  FOR k IN 1..2 LOOP
    INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality, int_birth_year, enum_gender)
    VALUES ('PROV-F' || k, 'Test', 'PL', 1980, 'M') RETURNING id_fencer INTO v_f;
    INSERT INTO prov_ids VALUES ('f' || k, v_f);
  END LOOP;
END $fx$;

CREATE FUNCTION pg_temp.id(p_k TEXT) RETURNS INT LANGUAGE sql AS $$
  SELECT v FROM prov_ids WHERE k = p_k;
$$;

-- What a recompute sends: the stored provenance, NULLs included, and no
-- enum_match_status.
SELECT lives_ok(
  format($q$SELECT fn_ingest_tournament_results(%s, %L::jsonb, 2)$q$, pg_temp.id('t'),
    jsonb_build_array(
      jsonb_build_object('id_fencer', pg_temp.id('f1'), 'int_place', 1,
        'txt_scraped_name', 'KOWALSKI Jan', 'num_confidence', 87.5,
        'enum_match_method', 'USER_CONFIRMED'),
      jsonb_build_object('id_fencer', pg_temp.id('f2'), 'int_place', 2,
        'txt_scraped_name', NULL, 'num_confidence', NULL, 'enum_match_method', NULL))),
  'RECOMP.PROV.RPC.01 a row with no scraped name is written instead of failing on its match candidate');

SELECT is(
  (SELECT txt_scraped_name || '|' || num_match_confidence || '|' || enum_match_method
     FROM tbl_result WHERE id_tournament = pg_temp.id('t') AND id_fencer = pg_temp.id('f1')),
  'KOWALSKI Jan|87.50|USER_CONFIRMED',
  'RECOMP.PROV.RPC.02 a stored name, confidence and method are written verbatim');

SELECT is(
  (SELECT row(txt_scraped_name, num_match_confidence, enum_match_method)::TEXT
     FROM tbl_result WHERE id_tournament = pg_temp.id('t') AND id_fencer = pg_temp.id('f2')),
  '(,,)',
  'RECOMP.PROV.RPC.03 a null name, confidence and method stay NULL; the confidence does not become 100');

SELECT is(
  (SELECT string_agg(mc.txt_scraped_name || ':' || mc.enum_status, ',')
     FROM tbl_match_candidate mc JOIN tbl_result r USING (id_result)
    WHERE r.id_tournament = pg_temp.id('t')),
  'KOWALSKI Jan:APPROVED',
  'RECOMP.PROV.RPC.04 the named row keeps a candidate whose status follows its method; the unnamed row gets none');

-- An absent confidence key still means 100, as every source write relies on.
SELECT fn_ingest_tournament_results(pg_temp.id('t'),
  jsonb_build_array(jsonb_build_object('id_fencer', pg_temp.id('f1'), 'int_place', 1,
    'txt_scraped_name', 'KOWALSKI Jan')), 1);
SELECT is(
  (SELECT num_match_confidence FROM tbl_result WHERE id_tournament = pg_temp.id('t')),
  100.00::NUMERIC(5,2),
  'RECOMP.PROV.RPC.05 a row without a confidence key is still written at 100');

SELECT * FROM finish();
ROLLBACK;
