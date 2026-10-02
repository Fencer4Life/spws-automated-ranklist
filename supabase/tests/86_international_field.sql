-- =============================================================================
-- INTL — an international result keeps the whole source field (ADR-105)
-- =============================================================================
-- Acceptance IDs for doc/plans/international-field-size-root-cause-fix-
-- 2026-10-01.html, release 1 steps 3-4.
--
-- Only Polish fencers are written for PEW/MEW/MSW/PSW (ADR-038), so the rows a
-- tournament holds are never its bracket. Two database paths used to recount
-- them anyway and stored the Polish head-count as N:
--   * fn_commit_event_draft overwrote every joint sibling's N with COUNT(rows)
--     (the ADR-049 2026-06-04 per-V-cat rule, which is domestic only);
--   * fn_ingest_tournament_results fell back to jsonb_array_length(p_results)
--     when no count was passed.
-- INTL.RPC pins both fixes; the Python side is python/tests/
-- test_international_field.py.
--
-- Everything rolls back.
-- =============================================================================

BEGIN;

-- Fixtures carry V-cats that do not follow from the dummy birth years.
ALTER TABLE tbl_result DISABLE TRIGGER trg_assert_result_vcat;

SELECT plan(6);

CREATE TEMP TABLE intl_ids (k TEXT PRIMARY KEY, v INT) ON COMMIT DROP;

DO $fx$
DECLARE v_evf INT; v_spws INT; v_s26 INT; v_e INT; v_d INT; v_t INT; v_f INT;
BEGIN
  SELECT id_organizer INTO v_evf FROM tbl_organizer WHERE txt_code = 'EVF';
  SELECT id_organizer INTO v_spws FROM tbl_organizer WHERE txt_code = 'SPWS';
  SELECT id_season INTO v_s26 FROM tbl_season WHERE txt_code = 'SPWS-2025-2026';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('PEW96e-2025-2026', 'INTL draft', v_s26, v_evf, 'PLANNED') RETURNING id_event INTO v_e;
  INSERT INTO intl_ids VALUES ('pew_event', v_e);
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('PPW96-2025-2026', 'INTL domestic draft', v_s26, v_spws, 'PLANNED') RETURNING id_event INTO v_d;
  INSERT INTO intl_ids VALUES ('ppw_event', v_d);

  -- A PEW tournament for the ingest RPC: Vet-50 Women's Épée, 60 fenced.
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
    enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_e, 'INTL-PEW-LIVE', 'INTL PEW live', 'PEW', 'EPEE', 'F', 'V2', '2025-11-12', NULL, 'PLANNED')
  RETURNING id_tournament INTO v_t;
  INSERT INTO intl_ids VALUES ('pew_live', v_t);
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
    enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_d, 'INTL-PPW-LIVE', 'INTL PPW live', 'PPW', 'EPEE', 'F', 'V2', '2025-11-12', NULL, 'PLANNED')
  RETURNING id_tournament INTO v_t;
  INSERT INTO intl_ids VALUES ('ppw_live', v_t);

  FOR k IN 1..3 LOOP
    INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality, int_birth_year, enum_gender)
    VALUES ('INTL-F' || k, 'Test', 'PL', 1972, 'F') RETURNING id_fencer INTO v_f;
    INSERT INTO intl_ids VALUES ('f' || k, v_f);
  END LOOP;
END $fx$;

CREATE FUNCTION pg_temp.id(p_k TEXT) RETURNS INT LANGUAGE sql AS $$
  SELECT v FROM intl_ids WHERE k = p_k;
$$;

-- The rows for two Poles: 31st and 48th (MSW Manama 2025, STAŃCZYK/GANSZCZYK).
CREATE FUNCTION pg_temp.two_poles(p_places INT[]) RETURNS JSONB LANGUAGE sql AS $$
  SELECT jsonb_agg(jsonb_build_object('id_fencer', pg_temp.id('f' || i), 'int_place', p_places[i],
                                      'txt_scraped_name', 'INTL-F' || i || ' Test')
                   ORDER BY i)
    FROM generate_subscripts(p_places, 1) AS i;
$$;

-- The error text of a statement, or 'OK' when it runs.
CREATE FUNCTION pg_temp.err(p_sql TEXT) RETURNS TEXT LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE p_sql;
  RETURN 'OK';
EXCEPTION WHEN OTHERS THEN
  RETURN SQLERRM;
END $$;

-- A draft commit of one joint-pool sibling holding ``p_rows`` rows whose draft
-- N is ``p_n``; returns the committed N.
CREATE FUNCTION pg_temp.commit_sibling(p_event TEXT, p_code TEXT, p_type TEXT, p_n INT, p_places INT[])
RETURNS TEXT LANGUAGE plpgsql AS $dc$
DECLARE v_run UUID := gen_random_uuid(); v_td INT; v_out TEXT;
BEGIN
  INSERT INTO tbl_tournament_draft (id_event, txt_code, enum_type, enum_weapon, enum_gender,
    enum_age_category, dt_tournament, url_results, int_participant_count, enum_parser_kind,
    txt_source_url_used, txt_run_id, bool_joint_pool_split)
  VALUES (pg_temp.id(p_event), p_code, p_type::enum_tournament_type, 'EPEE', 'F', 'V2', '2025-11-12',
          'https://test/' || p_code, p_n, 'FENCINGTIME_XML', 'https://test/' || p_code, v_run, TRUE)
  RETURNING id_tournament_draft INTO v_td;
  FOR i IN 1..array_length(p_places, 1) LOOP
    INSERT INTO tbl_result_draft (id_fencer, id_tournament_draft, int_place, txt_run_id)
    VALUES (pg_temp.id('f' || i), v_td, p_places[i], v_run);
  END LOOP;
  PERFORM fn_commit_event_draft(v_run);
  SELECT int_participant_count::TEXT INTO v_out FROM tbl_tournament WHERE txt_code = p_code;
  RETURN v_out;
EXCEPTION WHEN OTHERS THEN
  RETURN 'ERROR: ' || SQLERRM;
END $dc$;

-- =============================================================================
-- INTL.RPC.01-02 — the commit's joint-sibling recount is domestic only
-- =============================================================================
SELECT is(pg_temp.commit_sibling('pew_event', 'INTL-PEW-DRAFT', 'PEW', 60, ARRAY[31, 48]), '60',
  'INTL.RPC.01 an international joint sibling keeps its source N (60), not the 2 Poles it holds');

SELECT is(pg_temp.commit_sibling('ppw_event', 'INTL-PPW-DRAFT', 'PPW', 10, ARRAY[1, 2, 3]), '3',
  'INTL.RPC.02 a domestic joint sibling is still recounted to its own rows (ADR-049 2026-06-04)');

-- =============================================================================
-- INTL.RPC.03-06 — the ingest RPC never guesses an international N
-- =============================================================================
SELECT ok(pg_temp.err(format('SELECT fn_ingest_tournament_results(%s, %L::jsonb, NULL)',
            pg_temp.id('pew_live'), pg_temp.two_poles(ARRAY[31, 48]))) LIKE '%source bracket%',
  'INTL.RPC.03 an international write without a participant count is refused');

SELECT ok(pg_temp.err(format('SELECT fn_ingest_tournament_results(%s, %L::jsonb, 60)',
            pg_temp.id('pew_live'), pg_temp.two_poles(ARRAY[31, 61]))) LIKE '%exceeds the source bracket%',
  'INTL.RPC.04 an international place above its source N is refused');

CREATE FUNCTION pg_temp.ingest_ok() RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE v_out TEXT;
BEGIN
  PERFORM fn_ingest_tournament_results(pg_temp.id('pew_live'), pg_temp.two_poles(ARRAY[31, 48]), 60);
  SELECT t.int_participant_count || '|' || string_agg(r.int_place::TEXT, ',' ORDER BY r.int_place)
    INTO v_out
    FROM tbl_tournament t JOIN tbl_result r ON r.id_tournament = t.id_tournament
   WHERE t.id_tournament = pg_temp.id('pew_live')
   GROUP BY t.int_participant_count;
  RETURN v_out;
EXCEPTION WHEN OTHERS THEN
  RETURN 'ERROR: ' || SQLERRM;
END $$;

SELECT is(pg_temp.ingest_ok(), '60|31,48',
  'INTL.RPC.05 an international write stores the source N and each Pole''s own place');

CREATE FUNCTION pg_temp.domestic_fallback() RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE v_out TEXT;
BEGIN
  PERFORM fn_ingest_tournament_results(pg_temp.id('ppw_live'), pg_temp.two_poles(ARRAY[1, 2, 3]), NULL);
  SELECT int_participant_count::TEXT INTO v_out FROM tbl_tournament WHERE id_tournament = pg_temp.id('ppw_live');
  RETURN v_out;
EXCEPTION WHEN OTHERS THEN
  RETURN 'ERROR: ' || SQLERRM;
END $$;

SELECT is(pg_temp.domestic_fallback(), '3',
  'INTL.RPC.06 a domestic write without a count still stores its rows as N, as before');

SELECT * FROM finish();
ROLLBACK;
