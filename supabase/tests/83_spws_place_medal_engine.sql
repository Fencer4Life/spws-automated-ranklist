-- =============================================================================
-- SE27 — the 2026/2027 SPWS place-and-medal engine (ADR-103)
-- =============================================================================
-- Acceptance IDs for doc/plans/scoring-engine-2026-2027-implementation-plan-
-- 2026-09-28.html §4, registered in the RTM before the migration landed.
--
-- WHERE THE EXPECTED VALUES COME FROM
-- -----------------------------------------------------------------------------
-- The signed-off points table (doc/plans/tabela-punktacji-propozycja-2026-09-27
-- .html), whose numbers were verified on PROD on 28 Sep 2026: the N = 8 row
-- 53.5 / 38.0 / 26.5 / 17.0 / 13.5 / 10.0 / 6.5 / 3.0, the N = 31 winner 150.8
-- and the 10-fencer joined example. Each is re-derived beside its assertion.
--
-- ORDER MATTERS
-- -----------------------------------------------------------------------------
-- Scoring a 2026/2027 result locks that season (ADR-097). The pure-function
-- group (ENG) and the groups that need 2026/2027 unlocked (TYPE, CALC) run
-- before the fixtures that score 2026/2027 results (STORE, RANK). Everything
-- rolls back.
--
-- RED-SAFE WRAPPERS
-- -----------------------------------------------------------------------------
-- As in 80_season_scoring_contract.sql, helpers catch "undefined object"
-- errors and yield NULL, so a missing engine produces named failures instead
-- of aborting the file. They add no arithmetic, so they cannot make a broken
-- engine pass — only a missing one fail cleanly.
-- =============================================================================

BEGIN;

-- Fixtures carry V-cats that do not follow from the dummy birth years; the
-- same targeted bypass 80_season_scoring_contract.sql uses.
ALTER TABLE tbl_result DISABLE TRIGGER trg_assert_result_vcat;

SELECT plan(35);

-- -----------------------------------------------------------------------------
-- The strategy, called directly with the season's EVF settings (50, 10, 3/2/1).
-- total = the non-NULL raw components summed and rounded once, as the writer
-- does; method is what the strategy reports.
-- -----------------------------------------------------------------------------
CREATE FUNCTION pg_temp.pm(p_n INT, p_place INT, p_k INT, p_m INT, p_below INT)
RETURNS TABLE (place_pts NUMERIC, de NUMERIC, podium NUMERIC,
               field NUMERIC, below_pts NUMERIC, medal NUMERIC,
               method TEXT, total NUMERIC)
LANGUAGE plpgsql AS $$
DECLARE b RECORD;
BEGIN
  EXECUTE 'SELECT (fn_score_spws_place_medal_v1_2026_2027($1,$2,$3,$4,$5,50,10,3,2,1)).*'
     INTO b USING p_n, p_place, p_k, p_m, p_below;
  RETURN QUERY SELECT
    ROUND(b.num_place_pts, 2), ROUND(b.num_de_bonus, 2), ROUND(b.num_podium_bonus, 2),
    ROUND(b.num_field_pts, 2), ROUND(b.num_below_pts, 2), ROUND(b.num_medal_bonus, 2),
    b.enum_score_method::TEXT,
    ROUND(COALESCE(b.num_place_pts, 0) + COALESCE(b.num_de_bonus, 0)
        + COALESCE(b.num_podium_bonus, 0) + COALESCE(b.num_field_pts, 0)
        + COALESCE(b.num_below_pts, 0) + COALESCE(b.num_medal_bonus, 0), 2);
EXCEPTION WHEN undefined_function OR undefined_column OR undefined_object THEN
  RETURN QUERY SELECT NULL::NUMERIC, NULL::NUMERIC, NULL::NUMERIC, NULL::NUMERIC,
                      NULL::NUMERIC, NULL::NUMERIC, NULL::TEXT, NULL::NUMERIC;
END $$;

-- The classic strategy's total for the same (N, place), for ENG.09.
CREATE FUNCTION pg_temp.classic_total(p_n INT, p_place INT)
RETURNS NUMERIC LANGUAGE sql AS $$
  SELECT ROUND(c.num_place_pts + c.num_de_bonus + c.num_podium_bonus, 2)
    FROM fn_score_evf_classic_v1_2025_2026(p_n, p_place, 50, 10, 10, 3, 2, 1) c;
$$;

-- Evaluate a SQL expression, yielding NULL when it names a missing object, so
-- the assertion fails by name rather than aborting the file.
CREATE FUNCTION pg_temp.safe_bool(p_sql TEXT)
RETURNS BOOLEAN LANGUAGE plpgsql AS $$
DECLARE v BOOLEAN;
BEGIN
  EXECUTE p_sql INTO v;
  RETURN v;
EXCEPTION WHEN undefined_function OR undefined_column OR undefined_table
            OR undefined_object OR invalid_text_representation THEN
  RETURN NULL;
END $$;

CREATE FUNCTION pg_temp.safe_text(p_sql TEXT)
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE v TEXT;
BEGIN
  EXECUTE p_sql INTO v;
  RETURN v;
EXCEPTION WHEN undefined_function OR undefined_column OR undefined_table
            OR undefined_object OR invalid_text_representation THEN
  RETURN NULL;
END $$;

-- The eight types and the engine FR-137 assigns to each in 2026/2027. PPS and
-- MPS stay on EVF classic (ADR-103 amendment, 2026-09-28): only PPW and MPW
-- move to the new engine.
CREATE FUNCTION pg_temp.expected_2026_2027_engines() RETURNS TEXT LANGUAGE sql AS $$
  SELECT 'MEW=EVF_CLASSIC_V1_2025_2026,MPS=EVF_CLASSIC_V1_2025_2026,'
      || 'MPW=SPWS_PLACE_MEDAL_V1_2026_2027,MSW=EVF_CLASSIC_V1_2025_2026,'
      || 'PEW=EVF_CLASSIC_V1_2025_2026,PPS=EVF_CLASSIC_V1_2025_2026,'
      || 'PPW=SPWS_PLACE_MEDAL_V1_2026_2027,PSW=EVF_CLASSIC_V1_2025_2026';
$$;

-- =============================================================================
-- SE27.ENG — the strategy
-- =============================================================================

-- SE27.ENG.01 — a fencer alone scores 1 (§8 ust. 7: N − place + 1).
SELECT is(
  (SELECT ROW(total, method)::TEXT FROM pg_temp.pm(1, 1, 1, 1, 0)),
  ROW(1.00::NUMERIC, 'TABLE')::TEXT,
  'SE27.ENG.01 N = 1 scores 1.00 by the table');

-- SE27.ENG.02 — a bracket of two scores 2 and 1.
SELECT is(
  (SELECT string_agg(x.total::TEXT, ',' ORDER BY p)
     FROM generate_series(1, 2) p, LATERAL pg_temp.pm(2, p, 2, p, 2 - p) x),
  '2.00,1.00',
  'SE27.ENG.02 N = 2 scores 2, 1');

-- SE27.ENG.03 — a bracket of three scores 3, 2, 1.
SELECT is(
  (SELECT string_agg(x.total::TEXT, ',' ORDER BY p)
     FROM generate_series(1, 3) p, LATERAL pg_temp.pm(3, p, 3, p, 3 - p) x),
  '3.00,2.00,1.00',
  'SE27.ENG.03 N = 3 scores 3, 2, 1');

-- SE27.ENG.04 — the N = 8 row of the signed-off table (one category, K = 8).
-- log2 8 = 3. Place 1: 3 + 7 × 3.5 + 13 × ∛8 = 3 + 24.5 + 26 = 53.5; place 2:
-- 3 + 21 + 14 = 38; place 3: 3 + 17.5 + 6 = 26.5; place 4: 3 + 14 = 17; then
-- 13.5, 10, 6.5 and 3 (no medal from place 4 on).
SELECT is(
  (SELECT string_agg(x.total::TEXT, ',' ORDER BY p)
     FROM generate_series(1, 8) p, LATERAL pg_temp.pm(8, p, 8, p, 8 - p) x),
  '53.50,38.00,26.50,17.00,13.50,10.00,6.50,3.00',
  'SE27.ENG.04 the N = 8 row is 53.50 38.00 26.50 17.00 13.50 10.00 6.50 3.00');

-- SE27.ENG.05 — the 10-fencer joined example (V1 × 2, V2 × 4, V3 × 4), coefficient
-- 1.0. Order V1 V2 V2 V1 V3 V2 V3 V3 V2 V3. log2 10 = 3.3219; the medal is
-- 13/7/3 × ∛K (∛2 = 1.2599, ∛4 = 1.5874). Place 2 (V2, 1st of 4) = 3.3219 + 28
-- + 20.6362 = 51.96 → 52.0. Place 4 (V1, 2nd of 2) earns no medal: 24.3.
SELECT is(
  (SELECT string_agg(ROUND(x.total, 1)::TEXT, ',' ORDER BY v.p)
     FROM (VALUES (1, 2, 1), (2, 4, 1), (3, 4, 2), (4, 2, 2), (5, 4, 1),
                  (6, 4, 3), (7, 4, 2), (8, 4, 3), (9, 4, 4), (10, 4, 4)) v(p, k, m),
          LATERAL pg_temp.pm(10, v.p, v.k, v.m, 10 - v.p) x),
  '51.2,52.0,38.9,24.3,41.5,22.1,24.9,15.1,6.8,3.3',
  'SE27.ENG.05 the 10-fencer joined example matches the signed-off table');

-- SE27.ENG.06 — no medal for the last of one's own category (§8 ust. 5): the
-- V1 fencer 4th of the joined 10 is 2nd of K = 2.
SELECT is(
  (SELECT medal FROM pg_temp.pm(10, 4, 2, 2, 6)),
  0.00::NUMERIC,
  'SE27.ENG.06 the medal is 0 when m = K');

-- SE27.ENG.07 — ties: two fencers tied 3rd of 10 each have 6 fencers below,
-- not 7, because a tied fencer is not „z gorszym wynikiem” (§8 ust. 6). The
-- engine scores the count it is given; the joined-bracket module computes it.
SELECT is(
  (SELECT below_pts FROM pg_temp.pm(10, 3, 4, 2, 6)),
  21.00::NUMERIC,
  'SE27.ENG.07 a tie at 3rd of 10 is scored on 6 fencers below (21.00), not 7');

-- SE27.ENG.08 — the largest bracket on the new formula: 31 fencers, the winner.
-- log2 31 = 4.9542, + 30 × 3.5 = 105, + 13 × ∛31 = 40.8380 → 150.79.
SELECT is(
  (SELECT total FROM pg_temp.pm(31, 1, 31, 1, 30)),
  150.79::NUMERIC,
  'SE27.ENG.08 the winner of N = 31 scores 150.79');

-- SE27.ENG.09 — from 32 the engine IS EVF classic, for every place, with no
-- category medal and none of the new components.
SELECT ok(
  (SELECT bool_and(x.total = pg_temp.classic_total(32, p)
                   AND x.method = 'EVF_CLASSIC'
                   AND x.field IS NULL AND x.below_pts IS NULL AND x.medal IS NULL)
     FROM generate_series(1, 32) p, LATERAL pg_temp.pm(32, p, 32, p, 32 - p) x),
  'SE27.ENG.09 N = 32 equals fn_score_evf_classic_v1_2025_2026 for every place, with no medal');

-- SE27.ENG.10 — an unknown engine raises, through the new dispatcher signature.
SELECT throws_like(
  $$SELECT fn_score_by_engine('NO_SUCH_ENGINE_V9', 16, 1, 16, 1, 15, 50, 10, 3, 2, 1)$$,
  '%Unknown scoring engine%',
  'SE27.ENG.10 an unknown engine raises instead of scoring');

-- SE27.ENG.11 — field-scaled is gone: no registry row, no strategy function,
-- and no function in schema public names it (the dispatcher included).
SELECT ok(
  NOT EXISTS (SELECT 1 FROM tbl_scoring_engine WHERE txt_code = 'SPWS_FIELD_SCALED_V1_2026_2027')
  AND NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                   WHERE n.nspname = 'public'
                     AND (p.proname = 'fn_score_spws_field_scaled_v1_2026_2027'
                          OR p.prosrc LIKE '%SPWS_FIELD_SCALED%')),
  'SE27.ENG.11 SPWS_FIELD_SCALED_V1_2026_2027 is absent from the registry, the dispatcher and the catalogue');

-- SE27.ENG.12 — EVF classic through the dispatcher is unchanged: N = 24 place 1
-- = (50.00, 50.00, 25.96), reported as EVF_CLASSIC with no new component.
-- SS26.HIST pins the stored history separately.
SELECT is(
  pg_temp.safe_text($$SELECT ROW(ROUND(b.num_place_pts, 2), ROUND(b.num_de_bonus, 2),
                            ROUND(b.num_podium_bonus, 2), b.num_field_pts, b.enum_score_method)::TEXT
                       FROM fn_score_by_engine('EVF_CLASSIC_V1_2025_2026', 24, 1, -1, -1, -1,
                                               50, 10, 3, 2, 1) b$$),
  ROW(50.00::NUMERIC, 50.00::NUMERIC, 25.96::NUMERIC, NULL::NUMERIC, 'EVF_CLASSIC')::TEXT,
  'SE27.ENG.12 EVF classic through the dispatcher is unchanged: N = 24 place 1 = 50.00 / 50.00 / 25.96');

-- SE27.ENG.13 — the middle range needs K, m and the count below. A row written
-- without them (−1) is refused, never scored as if they were zero.
SELECT throws_like(
  $$SELECT fn_score_spws_place_medal_v1_2026_2027(10, 3, -1, -1, -1, 50, 10, 3, 2, 1)$$,
  '%Invalid scoring input%',
  'SE27.ENG.13 a 4–31 bracket without K, m and fencers below raises');

-- SE27.ENG.14 — the cube root of a perfect cube is exact, as in the signed-off
-- table and the browser module. POWER(8, 1.0/3) is 1.999…9 in numeric, which
-- sends a tie at the final ROUND down: N = 8, place 3 of a single category is
-- 26.5 raw, and at a 0.75 coefficient must store 19.88, not 19.87.
SELECT is(
  (SELECT ROUND(b.num_medal_bonus, 20)::TEXT || ' / '
          || ROUND((b.num_field_pts + b.num_below_pts + b.num_medal_bonus) * 0.75, 2)::TEXT
     FROM fn_score_spws_place_medal_v1_2026_2027(8, 3, 8, 3, 5, 50, 10, 3, 2, 1) b),
  '6.00000000000000000000 / 19.88',
  'SE27.ENG.14 the medal on K = 8 is exactly 3 x 2, and a tie at the final rounding goes up');

-- =============================================================================
-- SE27.TYPE — the engine per tournament type (2026/2027 still unlocked here)
-- =============================================================================

-- SE27.TYPE.01 — the type rows carry the engine.
SELECT has_column('public', 'tbl_scoring_type_config', 'id_scoring_engine',
  'SE27.TYPE.01 tbl_scoring_type_config.id_scoring_engine exists');

-- SE27.TYPE.02 — 2026/2027 is assigned per FR-137; every type of 2025/2026
-- stays on EVF classic.
SELECT is(
  pg_temp.safe_text($$
    SELECT string_agg(t || '=' || fn_get_type_engine(s.id_season, t), ',' ORDER BY t)
      FROM tbl_season s, unnest(ARRAY['MEW','MPS','MPW','MSW','PEW','PPS','PPW','PSW']) t
     WHERE s.txt_code = 'SPWS-2026-2027'
       AND (SELECT bool_and(fn_get_type_engine(s2.id_season, t2) = 'EVF_CLASSIC_V1_2025_2026')
              FROM tbl_season s2, unnest(ARRAY['MEW','MPS','MPW','MSW','PEW','PPS','PPW','PSW']) t2
             WHERE s2.txt_code = 'SPWS-2025-2026')$$),
  pg_temp.expected_2026_2027_engines(),
  'SE27.TYPE.02 2026/2027 puts PPW and MPW on the new engine and PPS, MPS, PEW, MEW, MSW, PSW on EVF classic; 2025/2026 stays classic');

-- SE27.TYPE.03 — a locked season refuses a change of a type's engine (ADR-097).
SELECT throws_like(
  $$SELECT fn_import_scoring_config(jsonb_build_object(
      'id_season', (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
      'type_engines', jsonb_build_object('PPW', 'SPWS_PLACE_MEDAL_V1_2026_2027')))$$,
  '%is locked%',
  'SE27.TYPE.03 a locked season rejects a change of a type''s engine');

-- SE27.TYPE.04 — export and import round-trip the engine per type: the export
-- names every type's engine, a locked season accepts an unchanged full resend,
-- and a change on an unlocked season lands on the one type it names.
CREATE FUNCTION pg_temp.type_engines_round_trip() RETURNS TEXT
LANGUAGE plpgsql AS $rt$
DECLARE v_open INT; v_locked INT; v_cfg JSONB;
BEGIN
  SELECT id_season INTO v_open   FROM tbl_season WHERE txt_code = 'SPWS-2026-2027';
  SELECT id_season INTO v_locked FROM tbl_season WHERE txt_code = 'SPWS-2025-2026';

  v_cfg := fn_export_scoring_config(v_open);
  IF (SELECT string_agg(key || '=' || value, ',' ORDER BY key)
        FROM jsonb_each_text(v_cfg -> 'type_engines')) IS DISTINCT FROM pg_temp.expected_2026_2027_engines() THEN
    RETURN 'export: ' || COALESCE((v_cfg -> 'type_engines')::TEXT, 'no type_engines');
  END IF;

  PERFORM fn_import_scoring_config(fn_export_scoring_config(v_locked));

  PERFORM fn_import_scoring_config(jsonb_build_object('id_season', v_open,
    'type_engines', jsonb_build_object('PEW', 'SPWS_PLACE_MEDAL_V1_2026_2027')));
  IF fn_get_type_engine(v_open, 'PEW') <> 'SPWS_PLACE_MEDAL_V1_2026_2027'
     OR fn_get_type_engine(v_open, 'MEW') <> 'EVF_CLASSIC_V1_2025_2026' THEN
    RETURN 'import did not land on PEW alone';
  END IF;

  PERFORM fn_import_scoring_config(jsonb_build_object('id_season', v_open,
    'type_engines', jsonb_build_object('PEW', 'EVF_CLASSIC_V1_2025_2026')));
  RETURN 'OK';
EXCEPTION WHEN OTHERS THEN
  RETURN 'ERROR: ' || SQLERRM;
END $rt$;

SELECT is(pg_temp.type_engines_round_trip(), 'OK',
  'SE27.TYPE.04 export/import round-trip type_engines; a locked resend is accepted, an unlocked change lands on one type');

-- SE27.TYPE.05 — a revision snapshot records the engine of each type. A
-- scratch season's first revision snapshots fn_export_scoring_config.
CREATE FUNCTION pg_temp.snapshot_has_type_engines() RETURNS TEXT
LANGUAGE plpgsql AS $sn$
DECLARE v_season INT; v_snap JSONB;
BEGIN
  v_season := fn_create_season('SE27-SNAPSHOT', '2033-08-01', '2034-07-15');
  UPDATE tbl_season SET id_scoring_engine =
    (SELECT id_engine FROM tbl_scoring_engine WHERE txt_code = 'EVF_CLASSIC_V1_2025_2026')
   WHERE id_season = v_season;
  PERFORM fn_ensure_active_scoring_revision(v_season);
  SELECT json_snapshot INTO v_snap FROM tbl_scoring_config_revision
   WHERE id_season = v_season AND bool_active;
  IF v_snap -> 'type_engines' ->> 'PPW' IS NOT DISTINCT FROM fn_get_type_engine(v_season, 'PPW')
     AND v_snap -> 'type_engines' ->> 'PPW' IS NOT NULL THEN
    RETURN 'OK';
  END IF;
  RETURN 'snapshot: ' || COALESCE((v_snap -> 'type_engines')::TEXT, 'no type_engines');
EXCEPTION WHEN OTHERS THEN
  RETURN 'ERROR: ' || SQLERRM;
END $sn$;

SELECT is(pg_temp.snapshot_has_type_engines(), 'OK',
  'SE27.TYPE.05 a revision snapshot records the engine of each type');

-- =============================================================================
-- SE27.CALC — the published parameters, per type
-- =============================================================================

-- SE27.CALC.01 — 2026/2027 publishes one row per type with its engine.
SELECT is(
  pg_temp.safe_text($$SELECT string_agg(type_code || '=' || engine_code, ',' ORDER BY type_code)
                        FROM fn_public_scoring_params('SPWS-2026-2027')$$),
  pg_temp.expected_2026_2027_engines(),
  'SE27.CALC.01 fn_public_scoring_params reports the engine of every 2026/2027 type');

-- SE27.CALC.02 — each row's coefficient is that type's stored multiplier.
SELECT ok(
  pg_temp.safe_bool($$
    SELECT count(*) = 8 AND bool_and(p.multiplier = tc.num_multiplier)
      FROM fn_public_scoring_params('SPWS-2026-2027') p
      JOIN tbl_season s ON s.txt_code = 'SPWS-2026-2027'
      JOIN tbl_scoring_config c ON c.id_season = s.id_season
      JOIN tbl_scoring_type_config tc ON tc.id_config = c.id_config AND tc.enum_type::TEXT = p.type_code$$),
  'SE27.CALC.02 each published coefficient equals the type''s stored multiplier');

-- SE27.CALC.03 — anon may execute it: the pages hold only the anon key.
SELECT ok(
  COALESCE((SELECT has_function_privilege('anon', p.oid, 'EXECUTE')
              FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
             WHERE n.nspname = 'public' AND p.proname = 'fn_public_scoring_params' LIMIT 1), FALSE),
  'SE27.CALC.03 anon holds EXECUTE on fn_public_scoring_params');

-- SE27.CALC.04 — every row publishes the season's EVF settings, which feed EVF
-- classic and the new engine's range from 32.
SELECT ok(
  pg_temp.safe_bool($$
    SELECT count(*) > 0
       AND bool_and(p.mp_value = c.int_mp_value AND p.de_round = 10
                    AND p.podium_gold = c.int_podium_gold AND p.podium_silver = c.int_podium_silver
                    AND p.podium_bronze = c.int_podium_bronze)
      FROM fn_public_scoring_params('SPWS-2026-2027') p
      JOIN tbl_season s ON s.txt_code = 'SPWS-2026-2027'
      JOIN tbl_scoring_config c ON c.id_season = s.id_season$$),
  'SE27.CALC.04 every row carries the season''s stored EVF settings and DE round 10');

-- =============================================================================
-- FIXTURES — scored results (this locks 2026/2027; everything rolls back)
-- =============================================================================
-- Events are COMPLETED: the 2026/2027 ranking (EVENT_FK_MATCHING) reads events
-- through vw_eligible_event, which hides planned ones. Category in a ranking
-- follows the birth year (fn_age_category against the season's end year), so
-- each ranked fixture fencer's birth year puts them in the category queried.
--
-- Fencers:
--   SE27-11  EVF only: PEW 2026/2027, foil M, b. 1970 (V2 in 2027).
--   SE27-12  a foreigner (CZ) who fenced PPW 2026/2027, foil M V4, b. 1950.
--   SE27-13  PPW 2025/2026 (épée) + PEW 2026/2027 (foil), b. 1970.
--   SE27-14  PPW 2024/2025 (épée) + PEW 2026/2027 (foil), b. 1970.
--   SE27-15  PPW 2025/2026 sabre F V1, b. 1977: V2 in 2027 (§8 ust. 13).
--   SE27-16, SE27-17  fillers: the second of the bracket of 2, the bracket of 34.
CREATE TEMP TABLE se27_fx (fixture TEXT PRIMARY KEY, detail TEXT);

DO $fx$
DECLARE
  v_s27 INT; v_s26 INT; v_s25 INT; v_org INT;
  v_e27 INT; v_pew INT; v_e26 INT; v_e25 INT;
  v_t INT; f INT[] := '{}'; v_id INT;
BEGIN
  SELECT id_season INTO v_s27 FROM tbl_season WHERE txt_code = 'SPWS-2026-2027';
  SELECT id_season INTO v_s26 FROM tbl_season WHERE txt_code = 'SPWS-2025-2026';
  SELECT id_season INTO v_s25 FROM tbl_season WHERE txt_code = 'SPWS-2024-2025';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  FOR i IN 1..17 LOOP
    INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality, int_birth_year, enum_gender)
    VALUES ('SE27-' || i, 'Test', CASE WHEN i = 12 THEN 'CZ' ELSE 'PL' END,
            CASE WHEN i IN (12, 16) THEN 1950 WHEN i = 15 THEN 1977 ELSE 1970 END,
            (CASE WHEN i = 15 THEN 'F' ELSE 'M' END)::enum_gender_type)
    RETURNING id_fencer INTO v_id;
    f := f || v_id;
  END LOOP;

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('PPW98-2026-2027', 'SE27 PPW 2026/27', v_s27, v_org, 'COMPLETED') RETURNING id_event INTO v_e27;
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('PEW98-2026-2027', 'SE27 PEW 2026/27', v_s27, v_org, 'COMPLETED') RETURNING id_event INTO v_pew;
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('PPW97-2025-2026', 'SE27 PPW 2025/26', v_s26, v_org, 'COMPLETED') RETURNING id_event INTO v_e26;
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('PPW96-2024-2025', 'SE27 PPW 2024/25', v_s25, v_org, 'COMPLETED') RETURNING id_event INTO v_e25;

  -- A bracket of 2 (TABLE).
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
    enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_e27, 'SE27-N2', 'SE27 N=2', 'PPW', 'FOIL', 'M', 'V4', '2026-10-01', 2, 'IMPORTED')
  RETURNING id_tournament INTO v_t;
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES (f[12], v_t, 1), (f[16], v_t, 2);

  -- PEW 2026/2027, EVF classic.
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
    enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_pew, 'SE27-PEW', 'SE27 PEW', 'PEW', 'FOIL', 'M', 'V2', '2026-10-05', 10, 'IMPORTED')
  RETURNING id_tournament INTO v_t;
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
  VALUES (f[11], v_t, 1), (f[13], v_t, 2), (f[14], v_t, 3);

  -- PPW 2025/2026: SE27-13 (épée) and SE27-15 (sabre F V1).
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
    enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_e26, 'SE27-PPW26-E', 'SE27 PPW 2025/26 epee', 'PPW', 'EPEE', 'M', 'V2', '2026-03-01', 4, 'IMPORTED')
  RETURNING id_tournament INTO v_t;
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES (f[13], v_t, 1);
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
    enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_e26, 'SE27-PPW26-S', 'SE27 PPW 2025/26 sabre', 'PPW', 'SABRE', 'F', 'V1', '2026-03-01', 4, 'IMPORTED')
  RETURNING id_tournament INTO v_t;
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES (f[15], v_t, 1);

  -- PPW 2024/2025: SE27-14, outside every 2026/2027 window.
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
    enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_e25, 'SE27-PPW25-E', 'SE27 PPW 2024/25 epee', 'PPW', 'EPEE', 'M', 'V2', '2025-03-01', 4, 'IMPORTED')
  RETURNING id_tournament INTO v_t;
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES (f[14], v_t, 1);

  INSERT INTO se27_fx VALUES ('base', 'ok');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO se27_fx VALUES ('base', SQLERRM);
END $fx$;

-- The joined example and a bracket of 34 need K, m and the count below, so
-- they are a separate block: before the migration it fails on its own and
-- leaves the ranking fixtures above intact.
DO $fxj$
DECLARE
  v_e27 INT; v_t INT; v_id INT;
  -- The joined example, four values per fencer: place, category index, K, m.
  ex CONSTANT INT[] := ARRAY[1,1,2,1, 2,2,4,1, 3,2,4,2, 4,1,2,2, 5,3,4,1,
                             6,2,4,3, 7,3,4,2, 8,3,4,3, 9,2,4,4, 10,3,4,4];
  cats CONSTANT TEXT[] := ARRAY['V1','V2','V3'];
  t_by_cat INT[] := '{}';
BEGIN
  SELECT id_event INTO v_e27 FROM tbl_event WHERE txt_code = 'PPW98-2026-2027';

  FOR c IN 1..3 LOOP
    INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
      enum_age_category, dt_tournament, int_participant_count, enum_import_status)
    VALUES (v_e27, 'SE27-J10-' || cats[c], 'SE27 joined N=10 ' || cats[c], 'PPW', 'EPEE', 'M',
      cats[c]::enum_age_category, '2026-10-01', 10, 'IMPORTED')
    RETURNING id_tournament INTO v_t;
    t_by_cat := t_by_cat || v_t;
  END LOOP;

  FOR i IN 0..9 LOOP
    INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality, int_birth_year, enum_gender)
    VALUES ('SE27-J' || (i + 1), 'Test', 'PL', 1970, 'M') RETURNING id_fencer INTO v_id;
    EXECUTE 'INSERT INTO tbl_result (id_fencer, id_tournament, int_place, int_category_count,
               int_category_place, int_below_count) VALUES ($1, $2, $3, $4, $5, $6)'
      USING v_id, t_by_cat[ex[i * 4 + 2]], ex[i * 4 + 1], ex[i * 4 + 3], ex[i * 4 + 4], 10 - ex[i * 4 + 1];
  END LOOP;

  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
    enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_e27, 'SE27-N34', 'SE27 N=34', 'PPW', 'SABRE', 'M', 'V0', '2026-10-01', 34, 'IMPORTED')
  RETURNING id_tournament INTO v_t;
  EXECUTE 'INSERT INTO tbl_result (id_fencer, id_tournament, int_place, int_category_count,
             int_category_place, int_below_count)
           SELECT id_fencer, $1, 1, 34, 1, 33 FROM tbl_fencer WHERE txt_surname = ''SE27-17'''
    USING v_t;

  INSERT INTO se27_fx VALUES ('joined', 'ok');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO se27_fx VALUES ('joined', SQLERRM);
END $fxj$;

-- Score every fixture tournament; a failure is recorded, not raised, so the
-- assertions below still report by name.
DO $sc$
BEGIN
  PERFORM fn_calc_tournament_scores(t.id_tournament)
     FROM tbl_tournament t WHERE t.txt_code LIKE 'SE27-%';
  INSERT INTO se27_fx VALUES ('scored', 'ok');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO se27_fx VALUES ('scored', SQLERRM);
END $sc$;

-- =============================================================================
-- SE27.STORE — explicit components, −1 for "not used"
-- =============================================================================

-- SE27.STORE.01 — the seven new columns exist on tbl_result.
SELECT is(
  (SELECT count(*)::INT FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'tbl_result'
      AND column_name IN ('int_category_count', 'int_category_place', 'int_below_count',
                          'num_field_pts', 'num_below_pts', 'num_medal_bonus', 'enum_score_method')),
  7,
  'SE27.STORE.01 tbl_result has K, m, fencers below, the three new components and the method');

-- SE27.STORE.02 — no scored row holds NULL in any component, K, m, below or
-- method column.
SELECT is(
  pg_temp.safe_text($$
    SELECT count(*)::TEXT FROM tbl_result
     WHERE ts_points_calc IS NOT NULL
       AND (num_place_pts IS NULL OR num_de_bonus IS NULL OR num_podium_bonus IS NULL
            OR num_field_pts IS NULL OR num_below_pts IS NULL OR num_medal_bonus IS NULL
            OR int_category_count IS NULL OR int_category_place IS NULL OR int_below_count IS NULL
            OR enum_score_method IS NULL)$$),
  '0',
  'SE27.STORE.02 no scored result holds NULL in a component, K, m, below or method column');

-- SE27.STORE.03 — −1 exactly where the method does not use a component.
SELECT is(
  pg_temp.safe_text($$
    SELECT count(*)::TEXT FROM tbl_result r
     WHERE r.ts_points_calc IS NOT NULL AND NOT CASE r.enum_score_method::TEXT
       WHEN 'EVF_CLASSIC' THEN r.num_place_pts >= 0 AND r.num_de_bonus >= 0 AND r.num_podium_bonus >= 0
                           AND r.num_field_pts = -1 AND r.num_below_pts = -1 AND r.num_medal_bonus = -1
       WHEN 'PLACE_MEDAL' THEN r.num_place_pts = -1 AND r.num_de_bonus = -1 AND r.num_podium_bonus = -1
                           AND r.num_field_pts >= 0 AND r.num_below_pts >= 0 AND r.num_medal_bonus >= 0
       WHEN 'TABLE'       THEN r.num_place_pts >= 1 AND r.num_de_bonus = -1 AND r.num_podium_bonus = -1
                           AND r.num_field_pts = -1 AND r.num_below_pts = -1 AND r.num_medal_bonus = -1
       ELSE FALSE
     END$$),
  '0',
  'SE27.STORE.03 every scored row holds −1 exactly in the components its method does not use');

-- SE27.STORE.04 — the CHECKs admit only real values or −1.
CREATE FUNCTION pg_temp.rejects(p_sql TEXT) RETURNS BOOLEAN LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE p_sql;
  RETURN FALSE;
EXCEPTION WHEN check_violation THEN RETURN TRUE;
          WHEN OTHERS THEN RETURN FALSE;
END $$;
SELECT ok(
  pg_temp.rejects($$UPDATE tbl_result SET num_field_pts = -2 WHERE id_result = (SELECT min(id_result) FROM tbl_result)$$)
  AND pg_temp.rejects($$UPDATE tbl_result SET num_below_pts = -0.5 WHERE id_result = (SELECT min(id_result) FROM tbl_result)$$)
  AND pg_temp.rejects($$UPDATE tbl_result SET int_category_count = -2 WHERE id_result = (SELECT min(id_result) FROM tbl_result)$$)
  AND pg_temp.rejects($$UPDATE tbl_result SET int_category_place = 0 WHERE id_result = (SELECT min(id_result) FROM tbl_result)$$),
  'SE27.STORE.04 the CHECKs reject −2, −0.5 and a category place of 0');

-- SE27.STORE.05 — history is backfilled: every stored 2025/2026 score is
-- EVF_CLASSIC with −1 in the new components and in K, m and below.
SELECT is(
  pg_temp.safe_text($$
    SELECT (count(*) > 0 AND count(*) = count(*) FILTER (WHERE r.enum_score_method = 'EVF_CLASSIC'
              AND r.num_field_pts = -1 AND r.num_below_pts = -1 AND r.num_medal_bonus = -1
              AND r.int_category_count = -1 AND r.int_category_place = -1 AND r.int_below_count = -1))::TEXT
      FROM tbl_result r JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
      JOIN tbl_event e ON e.id_event = t.id_event JOIN tbl_season s ON s.id_season = e.id_season
     WHERE s.txt_code = 'SPWS-2025-2026' AND r.ts_points_calc IS NOT NULL AND t.txt_code NOT LIKE 'SE27-%'$$),
  'true',
  'SE27.STORE.05 every stored 2025/2026 score is EVF_CLASSIC with −1 in the new columns');

-- SE27.STORE.06 — the method recorded matches the range that scored the row.
SELECT is(
  pg_temp.safe_text($$
    SELECT string_agg(DISTINCT t.txt_code || '=' || r.enum_score_method::TEXT, ',')
      FROM tbl_result r JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
     WHERE t.txt_code IN ('SE27-N2', 'SE27-J10-V2', 'SE27-N34', 'SE27-PEW')$$),
  'SE27-J10-V2=PLACE_MEDAL,SE27-N2=TABLE,SE27-N34=EVF_CLASSIC,SE27-PEW=EVF_CLASSIC',
  'SE27.STORE.06 PPW brackets of 2, 10 and 34 are TABLE, PLACE_MEDAL and EVF_CLASSIC; PEW is EVF_CLASSIC');

-- SE27.STORE.07 — end to end through fn_calc_tournament_scores: the stored
-- joined example equals the signed-off table (PPW coefficient 1.0).
SELECT is(
  pg_temp.safe_text($$
    SELECT string_agg(ROUND(r.num_final_score, 1)::TEXT, ',' ORDER BY r.int_place)
      FROM tbl_result r JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
     WHERE t.txt_code LIKE 'SE27-J10-%'$$),
  '51.2,52.0,38.9,24.3,41.5,22.1,24.9,15.1,6.8,3.3',
  'SE27.STORE.07 the stored joined example scores 51.2 … 3.3 across its three category tournaments');

-- =============================================================================
-- SE27.RANK — ranking entry through PPW or MPW (§8 ust. 13–14)
-- =============================================================================
CREATE FUNCTION pg_temp.in_ranking(p_fencer TEXT, p_weapon TEXT, p_gender TEXT, p_cat TEXT,
                                   p_rolling BOOLEAN)
RETURNS BOOLEAN LANGUAGE sql AS $$
  SELECT EXISTS (
    SELECT 1 FROM fn_ranking_full(p_weapon::enum_weapon_type, p_gender::enum_gender_type,
                                  p_cat::enum_age_category,
                                  (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027'),
                                  p_rolling) rk
      JOIN tbl_fencer f ON f.id_fencer = rk.id_fencer
     WHERE f.txt_surname = p_fencer);
$$;

-- SE27.RANK.01 — a fencer with only EVF results is absent from 2026/2027.
-- Guarded on the fixture so an absent fixture cannot pass it.
SELECT is(
  ROW((SELECT detail FROM se27_fx WHERE fixture = 'base'),
      pg_temp.in_ranking('SE27-11', 'FOIL', 'M', 'V2', FALSE))::TEXT,
  ROW('ok', FALSE)::TEXT,
  'SE27.RANK.01 a fencer with only EVF results is absent from the 2026/2027 ranking');

-- SE27.RANK.02 — a foreigner who fenced PPW is ranked.
SELECT is(
  pg_temp.in_ranking('SE27-12', 'FOIL', 'M', 'V4', FALSE),
  TRUE,
  'SE27.RANK.02 a foreign PPW participant is ranked');

-- SE27.RANK.03 — a 2025/2026 PPW start, in any weapon, admits a fencer to the
-- rolling 2026/2027 ranking only.
SELECT is(
  ROW(pg_temp.in_ranking('SE27-13', 'FOIL', 'M', 'V2', TRUE),
      pg_temp.in_ranking('SE27-13', 'FOIL', 'M', 'V2', FALSE))::TEXT,
  ROW(TRUE, FALSE)::TEXT,
  'SE27.RANK.03 a 2025/2026 PPW start admits to the rolling 2026/2027 ranking, not the non-rolling one');

-- SE27.RANK.04 — a last PPW start in 2024/2025 admits to neither.
SELECT is(
  ROW((SELECT detail FROM se27_fx WHERE fixture = 'base'),
      pg_temp.in_ranking('SE27-14', 'FOIL', 'M', 'V2', TRUE),
      pg_temp.in_ranking('SE27-14', 'FOIL', 'M', 'V2', FALSE))::TEXT,
  ROW('ok', FALSE, FALSE)::TEXT,
  'SE27.RANK.04 a last PPW start in 2024/2025 admits to neither 2026/2027 ranking');

-- SE27.RANK.05 — §8 ust. 13: a fencer V1 in 2025/2026 and V2 in 2026/2027
-- carries the 2025/2026 points into the V2 ranking. Pins existing behaviour
-- (the ranked season's category decides) on the EVENT_CODE_MATCHING body,
-- which carries by event position; the entry gate must not remove it.
SELECT is(
  (SELECT bool_or(rk.bool_has_carryover AND rk.total_score > 0)
     FROM fn_ranking_full_event_code_matching('SABRE', 'F', 'V2',
            (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027'), TRUE) rk
     JOIN tbl_fencer f ON f.id_fencer = rk.id_fencer
    WHERE f.txt_surname = 'SE27-15'),
  TRUE,
  'SE27.RANK.05 a V1 → V2 move carries the previous season''s points into the V2 ranking');

SELECT * FROM finish();

ROLLBACK;
