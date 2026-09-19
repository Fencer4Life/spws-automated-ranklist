-- =============================================================================
-- SS26 — Versioned season scoring: contract tests and golden fixtures
-- =============================================================================
-- Acceptance IDs for doc/plans/versioned-season-scoring-and-pzsz-ranking-design.html,
-- §11 step 1 ("Contract tests and preflight"). Written BEFORE any production
-- code, per §10: "Each group must be observed RED for the intended reason, then
-- flipped GREEN by the smallest implementation."
--
-- WHAT IS GREEN HERE AND WHAT IS RED, AND WHY THE MIX IS DELIBERATE
-- -----------------------------------------------------------------------------
-- SS26.HIST.01-06 are GOLDEN FIXTURES. They pin what the CURRENT engine
-- produces today, so they pass from the moment this file lands and must never
-- stop passing. Their whole purpose is to make "historical scores stay
-- explainable" (§01) a mechanically checked property rather than an intention:
-- the versioned-scoring work refactors one inline function into a dispatcher
-- plus immutable strategies, and these assertions are what proves the 2025/2026
-- numbers survived that surgery byte for byte.
--
-- SS26.DB.*, SS26.NEW.* and SS26.PARITY.* are RED on purpose. They name objects
-- that do not exist yet — the engine registry, the season's engine assignment,
-- the two immutable strategies, the preview facade. They fail with a value of
-- NULL or an "undefined function" error, which is the intended reason. They go
-- GREEN in §11 step 2 ("Engine foundation") and not before.
--
-- WHY THE RED ASSERTIONS ARE WRAPPED
-- -----------------------------------------------------------------------------
-- A missing function raises 42883 at runtime, which would abort the whole file
-- and cost every assertion after it — including the golden ones. The pg_temp
-- helpers below catch exactly that error class and yield NULL instead, so a
-- missing engine produces one clean named failure ("have NULL, want 19.00")
-- rather than a cascade. They are pass-through once the engine exists: the
-- helper adds no arithmetic of its own, so it cannot make a broken engine pass.
--
-- GOLDEN VALUES ARE DERIVED, NOT GUESSED
-- -----------------------------------------------------------------------------
-- Every expectation below was computed from the formula in §04 and cross-checked
-- against fn_calc_tournament_scores' own output. The N=24 / place=1 triple
-- (50.00, 50.00, 25.96 -> 125.96) is independently asserted by 02_scoring_engine
-- test 2.1, so the two files agree by derivation rather than by copying.
--
-- THE CONFIG THESE NUMBERS DEPEND ON
-- -----------------------------------------------------------------------------
-- Pinned to SPWS-2025-2026, the season EVF_CLASSIC_V1_2025_2026 is named for.
-- Unlike 02_scoring_engine, this file does NOT follow the active season: a
-- golden fixture that moves when the season rolls over is not a golden fixture.
-- SS26.HIST.01 is the config contract; if it fails, an administrator changed
-- that season's stored configuration and every expectation below needs
-- recomputing deliberately. mp_value and the podium coefficients are SEASON
-- CONFIGURATION, not engine constants (§04, reversed 19 September 2026), which
-- is precisely why they are asserted rather than assumed.
-- =============================================================================

BEGIN;

-- Same targeted bypass 02_scoring_engine uses: these fixtures carry dummy
-- V-cats that predate the FATAL invariant guard. Targeted rather than
-- session_replication_role so audit and status triggers stay live.
ALTER TABLE tbl_result DISABLE TRIGGER trg_assert_result_vcat;

SELECT plan(30);

-- -----------------------------------------------------------------------------
-- Canonical error contracts. Named here because the tests pin them, so the
-- implementation must adopt these exact phrases. "Unknown scoring engine"
-- deliberately mirrors the existing "Unknown carryover engine" raised by the
-- ADR-042/ADR-045 carry-over dispatcher, which §03 tells us to follow rather
-- than reinvent.
-- -----------------------------------------------------------------------------
--   'Unknown scoring engine'                     -- §03 dispatcher ELSE branch
--   'Invalid scoring input'                      -- §04 place/N range rejection
--   'No scoring configuration for tournament type' -- §02/§07 fail-closed gate

-- =============================================================================
-- FIXTURES — a deterministic 2025/2026 event scored by the CURRENT engine.
-- =============================================================================
DO $fixture$
DECLARE
  v_season INT;
  v_org    INT;
  v_event  INT;
  v_f      INT[] := '{}';
  v_id     INT;
  v_t_n24_ppw INT; v_t_n24_mpw INT; v_t_n1 INT; v_t_n16 INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026';
  IF v_season IS NULL THEN
    RAISE EXCEPTION 'SS26 fixtures require season SPWS-2025-2026 to exist';
  END IF;
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('SS26-GOLD-EVT', 'SS26 golden scoring fixture', v_season, v_org, 'PLANNED')
  RETURNING id_event INTO v_event;

  -- Five fencers, created here rather than looked up by surname: a lookup
  -- silently binds the first row when two fencers share a name (the defect
  -- fixed in export_seed.py::fencer_lookup()).
  FOR i IN 1..5 LOOP
    INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year)
    VALUES ('SS26-GOLD-' || i, 'Test', 1970) RETURNING id_fencer INTO v_id;
    v_f := v_f || v_id;
  END LOOP;

  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon,
    enum_gender, enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES
    (v_event, 'SS26-PPW-N24', 'SS26 PPW N=24', 'PPW', 'EPEE', 'M', 'V2', '2025-10-01', 24, 'IMPORTED'),
    (v_event, 'SS26-MPW-N24', 'SS26 MPW N=24', 'MPW', 'EPEE', 'M', 'V2', '2025-10-02', 24, 'IMPORTED'),
    (v_event, 'SS26-PPW-N1',  'SS26 PPW N=1',  'PPW', 'FOIL', 'M', 'V2', '2025-10-03',  1, 'IMPORTED'),
    (v_event, 'SS26-PPW-N16', 'SS26 PPW N=16', 'PPW', 'SABRE','M', 'V2', '2025-10-04', 16, 'IMPORTED');

  SELECT id_tournament INTO v_t_n24_ppw FROM tbl_tournament WHERE txt_code = 'SS26-PPW-N24';
  SELECT id_tournament INTO v_t_n24_mpw FROM tbl_tournament WHERE txt_code = 'SS26-MPW-N24';
  SELECT id_tournament INTO v_t_n1      FROM tbl_tournament WHERE txt_code = 'SS26-PPW-N1';
  SELECT id_tournament INTO v_t_n16     FROM tbl_tournament WHERE txt_code = 'SS26-PPW-N16';

  -- PPW N=24: places 1 and 24 (first and last, the two ends of the curve).
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
  VALUES (v_f[1], v_t_n24_ppw, 1), (v_f[5], v_t_n24_ppw, 24);

  -- MPW N=24: the same placement, so the only difference in the final score is
  -- the multiplier. That is what makes SS26.HIST.06 a multiplier assertion.
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
  VALUES (v_f[1], v_t_n24_mpw, 1);

  -- N=1: the walkover ADR-066 admits deliberately (§04, walkthrough A3).
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES (v_f[1], v_t_n1, 1);

  -- N=16: the three podium places plus last, an exact power of two so the
  -- power-of-two adjustment term is 0.
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
  VALUES (v_f[1], v_t_n16, 1), (v_f[2], v_t_n16, 2), (v_f[3], v_t_n16, 3), (v_f[5], v_t_n16, 16);
END;
$fixture$;

SELECT fn_calc_tournament_scores(id_tournament) FROM tbl_tournament
 WHERE txt_code IN ('SS26-PPW-N24','SS26-MPW-N24','SS26-PPW-N1','SS26-PPW-N16');

-- Read one scored component back by tournament code and place.
CREATE FUNCTION pg_temp.comp(p_code TEXT, p_place INT)
RETURNS TABLE (place_pts NUMERIC, de NUMERIC, podium NUMERIC, final NUMERIC)
LANGUAGE sql STABLE AS $$
  SELECT r.num_place_pts, r.num_de_bonus, r.num_podium_bonus, r.num_final_score
    FROM tbl_result r JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   WHERE t.txt_code = p_code AND r.int_place = p_place;
$$;

-- =============================================================================
-- SS26.HIST — golden fixtures. GREEN now; must stay GREEN forever.
-- =============================================================================

-- SS26.HIST.01 — config contract for the season this file is pinned to.
SELECT results_eq(
  $$SELECT c.int_mp_value, c.int_podium_gold, c.int_podium_silver, c.int_podium_bronze,
           c.num_ppw_multiplier::NUMERIC(10,4), c.num_mpw_multiplier::NUMERIC(10,4)
      FROM tbl_scoring_config c JOIN tbl_season s ON s.id_season = c.id_season
     WHERE s.txt_code = 'SPWS-2025-2026'$$,
  $$VALUES (50, 3, 2, 1, 1.0000::NUMERIC(10,4), 1.2000::NUMERIC(10,4))$$,
  'SS26.HIST.01 SPWS-2025-2026 stores the configuration the classic engine reproduces'
);

-- SS26.HIST.02 — every component at the top of a 24-entry field.
SELECT results_eq(
  $$SELECT * FROM pg_temp.comp('SS26-PPW-N24', 1)$$,
  $$VALUES (50.00::NUMERIC, 50.00::NUMERIC, 25.96::NUMERIC, 125.96::NUMERIC)$$,
  'SS26.HIST.02 classic N=24 place 1 = (50.00, 50.00, 25.96) -> 125.96'
);

-- SS26.HIST.03 — the bottom of the same field. Last place scores exactly one
-- place point, no DE rounds and no podium, under any base: the formula reduces
-- to B - (B-1)*ln(N)/ln(N) = 1. An engine-independent invariant.
SELECT results_eq(
  $$SELECT * FROM pg_temp.comp('SS26-PPW-N24', 24)$$,
  $$VALUES (1.00::NUMERIC, 0.00::NUMERIC, 0.00::NUMERIC, 1.00::NUMERIC)$$,
  'SS26.HIST.03 classic N=24 last place = (1.00, 0.00, 0.00) -> 1.00'
);

-- SS26.HIST.04 — the walkover, pinned on the CLASSIC side of the §04
-- re-pricing. SS26.NEW.01 pins the same bracket at 19.00 under the field-scaled
-- engine; the pair is what makes the 59 -> 19 change deliberate and visible
-- rather than something that falls out of a division-by-zero guard.
SELECT results_eq(
  $$SELECT * FROM pg_temp.comp('SS26-PPW-N1', 1)$$,
  $$VALUES (50.00::NUMERIC, 0.00::NUMERIC, 9.00::NUMERIC, 59.00::NUMERIC)$$,
  'SS26.HIST.04 classic N=1 walkover = (50.00, 0.00, 9.00) -> 59.00'
);

-- SS26.HIST.05 — the three podium places of an exact power-of-two field.
SELECT results_eq(
  $$SELECT r.int_place, r.num_place_pts, r.num_de_bonus, r.num_podium_bonus
      FROM tbl_result r JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
     WHERE t.txt_code = 'SS26-PPW-N16' AND r.int_place <= 3 ORDER BY r.int_place$$,
  $$VALUES (1, 50.00::NUMERIC, 40.00::NUMERIC, 22.68::NUMERIC),
           (2, 37.75::NUMERIC, 30.00::NUMERIC, 15.12::NUMERIC),
           (3, 30.58::NUMERIC, 20.00::NUMERIC,  7.56::NUMERIC)$$,
  'SS26.HIST.05 classic N=16 podium places preserve every component'
);

-- SS26.HIST.06 — the multiplier is applied to the summed RAW components and
-- rounded once, not applied to already-rounded parts. 125.9604965 x 1.2
-- rounds to 151.15; rounding first would give 151.152 -> 151.15 as well, so
-- the assertion is paired with HIST.02 to pin both the parts and the product.
SELECT is(
  (SELECT final FROM pg_temp.comp('SS26-MPW-N24', 1)),
  151.15::NUMERIC,
  'SS26.HIST.06 classic MPW multiplier 1.2 applied exactly -> 151.15'
);

-- =============================================================================
-- SS26.DB — engine architecture. RED until §11 step 2.
-- =============================================================================

-- SS26.DB.01 — the registry exists.
SELECT has_table('public', 'tbl_scoring_engine',
  'SS26.DB.01 tbl_scoring_engine exists');

-- SS26.DB.01b — and is METADATA ONLY. §03 rejected dispatch through a stored
-- function reference: it needs dynamic EXECUTE inside SECURITY DEFINER, makes a
-- writable row an execution path, defeats Postgres dependency tracking (DROP
-- FUNCTION on a live strategy would succeed and break a closed season at
-- runtime), and hides the call edge from postgrestools and the knowledge graph.
-- This assertion is what stops that alternative being reintroduced quietly.
-- Requires the table to EXIST as well as to name no function. Asserting only
-- the absence of a function column would pass trivially while the table itself
-- is missing -- a false green, which is how this assertion first read.
SELECT ok(
  EXISTS (SELECT 1 FROM information_schema.tables
           WHERE table_schema = 'public' AND table_name = 'tbl_scoring_engine')
  AND NOT EXISTS (SELECT 1 FROM information_schema.columns
           WHERE table_schema = 'public' AND table_name = 'tbl_scoring_engine'
             AND (column_name ILIKE '%function%' OR column_name ILIKE '%proc%'
                  OR column_name ILIKE '%handler%' OR column_name ILIKE '%dispatch%')),
  'SS26.DB.01b tbl_scoring_engine exists and names no function: dispatch is a static CASE, not a stored reference'
);

-- SS26.DB.02 — the season names its engine explicitly. Nothing chooses an
-- algorithm at calculation time (§03).
SELECT has_column('public', 'tbl_season', 'id_scoring_engine',
  'SS26.DB.02 tbl_season.id_scoring_engine assigns an engine per season');

-- SS26.DB.03 — both immutable strategies exist with the uniform signature the
-- dispatcher calls. Uniform across engines on purpose: the classic engine
-- ignores p_base_slope, which is what keeps "adding a branch edits the
-- dispatcher, never a strategy" true. p_base_slope and p_de_round are the "two
-- unrelated tens" of §04 and must stay separately named.
SELECT has_function('public', 'fn_score_evf_classic_v1_2025_2026',
  ARRAY['integer','integer','numeric','numeric','numeric','numeric','numeric','numeric'],
  'SS26.DB.03a classic strategy exists with the uniform dispatcher signature');
SELECT has_function('public', 'fn_score_spws_field_scaled_v1_2026_2027',
  ARRAY['integer','integer','numeric','numeric','numeric','numeric','numeric','numeric'],
  'SS26.DB.03b field-scaled strategy exists with the uniform dispatcher signature');

-- SS26.DB.04 — an unrecognised engine fails closed, exactly as the carry-over
-- dispatcher's ELSE RAISE EXCEPTION 'Unknown carryover engine' already does.
SELECT throws_like(
  $$SELECT fn_score_by_engine('NO_SUCH_ENGINE_V9', 16, 1, 50, 10, 10, 3, 2, 1)$$,
  '%Unknown scoring engine%',
  'SS26.DB.04 an unrecognised engine raises instead of scoring'
);

-- SS26.DB.05 — the fail-closed type gate. Today the six-way multiplier CASE has
-- no ELSE, so a tournament type it does not list writes num_final_score = NULL
-- with no exception raised (§02). PSW is the honest probe: it is declared in
-- enum_tournament_type and carries a multiplier, so this test uses a type that
-- is in the enum but has no configured settings once the normalized type policy
-- lands. Until then it fails because fn_assert_type_configured does not exist.
SELECT throws_like(
  $$SELECT fn_assert_type_configured(
      (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'), 'PPS')$$,
  '%No scoring configuration for tournament type%',
  'SS26.DB.05 a tournament type with no configured settings raises instead of writing NULL'
);

-- =============================================================================
-- SS26.NEW — the field-scaled engine. RED until §11 step 2.
-- =============================================================================
-- Pass-through helper: yields the engine's own numbers, or NULL when the engine
-- does not exist yet. It performs no arithmetic, so it cannot mask a wrong
-- implementation — only a missing one.
CREATE FUNCTION pg_temp.nw(p_n INT, p_place INT, p_mult NUMERIC DEFAULT 1.0)
RETURNS TABLE (place_pts NUMERIC, de NUMERIC, podium NUMERIC, final NUMERIC)
LANGUAGE plpgsql AS $$
DECLARE c RECORD;
BEGIN
  SELECT * INTO c FROM fn_score_spws_field_scaled_v1_2026_2027(
    p_n, p_place, 50::NUMERIC, 10::NUMERIC, 10::NUMERIC, 3::NUMERIC, 2::NUMERIC, 1::NUMERIC);
  RETURN QUERY SELECT c.num_place_pts, c.num_de_bonus, c.num_podium_bonus,
                      ROUND((c.num_place_pts + c.num_de_bonus + c.num_podium_bonus) * p_mult, 2);
EXCEPTION WHEN undefined_function OR undefined_column OR undefined_table THEN
  RETURN QUERY SELECT NULL::NUMERIC, NULL::NUMERIC, NULL::NUMERIC, NULL::NUMERIC;
END $$;

-- SS26.NEW.01 — the re-priced walkover. 50 + 0 + 9 = 59 becomes 10 + 0 + 9 = 19,
-- because max(2, N) gives the one-competitor bracket the N=2 base of 10. §04
-- requires this pinned explicitly so it cannot regress silently.
SELECT results_eq(
  $$SELECT * FROM pg_temp.nw(1, 1)$$,
  $$VALUES (10.00::NUMERIC, 0.00::NUMERIC, 9.00::NUMERIC, 19.00::NUMERIC)$$,
  'SS26.NEW.01 field-scaled N=1 = (10.00, 0.00, 9.00) -> 19.00, where the classic engine scores 59.00'
);

-- SS26.NEW.02 — at N=32 the base reaches mpValue (10 x log2(32) = 50), so the
-- two engines agree exactly. This is the upper boundary of the entire
-- difference between them.
SELECT is(
  (SELECT final FROM pg_temp.nw(32, 1)),
  128.57::NUMERIC,
  'SS26.NEW.02 field-scaled N=32 place 1 -> 128.57, identical to the classic engine'
);

-- SS26.NEW.03 — one competitor fewer and they diverge: base 49.54, not 50.
-- Pins 32 as an exact crossover rather than an approximate one.
SELECT is(
  (SELECT final FROM pg_temp.nw(31, 1)),
  127.81::NUMERIC,
  'SS26.NEW.03 field-scaled N=31 place 1 -> 127.81, strictly below the classic 128.27'
);

-- SS26.NEW.04 — the cap holds above the crossover: the base never exceeds
-- mpValue however large the field.
SELECT is(
  (SELECT place_pts FROM pg_temp.nw(1000, 1)),
  50.00::NUMERIC,
  'SS26.NEW.04 field-scaled base caps at mpValue for a 1000-entry field'
);

-- SS26.NEW.05 — the §07 PZSz case: a known veteran 34th of a 107-strong senior
-- field, scored on the original place against the full field. Above the
-- crossover, so both engines agree at 23.02.
SELECT is(
  (SELECT final FROM pg_temp.nw(107, 34)),
  23.02::NUMERIC,
  'SS26.NEW.05 field-scaled 34th of 107 -> 23.02 (full field, original place)'
);

-- SS26.NEW.06 — a place larger than the field is corrupt data. Zero is the one
-- value that hides it: it sorts to the bottom and reads as an ordinary weak
-- result. The present function scores it as 0; the new engine must raise.
SELECT throws_like(
  $$SELECT fn_score_spws_field_scaled_v1_2026_2027(107, 120, 50, 10, 10, 3, 2, 1)$$,
  '%Invalid scoring input%',
  'SS26.NEW.06 place > N raises instead of scoring a silent zero'
);

-- SS26.NEW.07
SELECT throws_like(
  $$SELECT fn_score_spws_field_scaled_v1_2026_2027(16, 0, 50, 10, 10, 3, 2, 1)$$,
  '%Invalid scoring input%',
  'SS26.NEW.07 place < 1 raises');

-- SS26.NEW.08
SELECT throws_like(
  $$SELECT fn_score_spws_field_scaled_v1_2026_2027(0, 1, 50, 10, 10, 3, 2, 1)$$,
  '%Invalid scoring input%',
  'SS26.NEW.08 N < 1 raises');

-- SS26.NEW.09 — closes the live leak in §04: num_podium_bonus carries no
-- place > N guard, only WHEN place = 1/2/3, so N=2 with place=3 awards a bronze
-- podium bonus for a place that does not exist in the bracket while its place
-- points correctly collapse to zero. Rejection must reach the podium term too.
SELECT throws_like(
  $$SELECT fn_score_spws_field_scaled_v1_2026_2027(2, 3, 50, 10, 10, 3, 2, 1)$$,
  '%Invalid scoring input%',
  'SS26.NEW.09 no podium bonus survives an out-of-range place (N=2, place=3)'
);

-- SS26.NEW.10 — the engine-independent invariant, asserted on the new engine so
-- the refactor cannot quietly change it.
SELECT is(
  (SELECT place_pts FROM pg_temp.nw(16, 16)),
  1.00::NUMERIC,
  'SS26.NEW.10 last place scores exactly 1.00 place point under the field-scaled base'
);

-- SS26.NEW.11 — monotonicity: place points strictly decrease as place worsens.
SELECT ok(
  (SELECT (SELECT place_pts FROM pg_temp.nw(16, 1))
        > (SELECT place_pts FROM pg_temp.nw(16, 2))
      AND (SELECT place_pts FROM pg_temp.nw(16, 2))
        > (SELECT place_pts FROM pg_temp.nw(16, 3))
      AND (SELECT place_pts FROM pg_temp.nw(16, 3))
        > (SELECT place_pts FROM pg_temp.nw(16, 16))),
  'SS26.NEW.11 field-scaled place points decrease strictly as place worsens'
);

-- SS26.NEW.12 — the base is monotonically non-decreasing in field size, which
-- is the stated purpose of the curve: small fields are worth less.
SELECT ok(
  (SELECT (SELECT place_pts FROM pg_temp.nw(2, 1))
        < (SELECT place_pts FROM pg_temp.nw(16, 1))
      AND (SELECT place_pts FROM pg_temp.nw(16, 1))
        < (SELECT place_pts FROM pg_temp.nw(32, 1))
      AND (SELECT place_pts FROM pg_temp.nw(32, 1))
        = (SELECT place_pts FROM pg_temp.nw(107, 1))),
  'SS26.NEW.12 the field-scaled base grows with N and then holds flat at the cap'
);

-- =============================================================================
-- SS26.PARITY — preview and persistence are one implementation. RED until §11
-- step 2 delivers the facade.
-- =============================================================================

-- SS26.PARITY.01 — the public read-only facade exists.
SELECT has_function('public', 'fn_preview_tournament_score',
  'SS26.PARITY.01 fn_preview_tournament_score exists as a read-only facade');

-- SS26.PARITY.02 — it is STABLE, which is what makes "it cannot update a
-- tournament or result" (§03) a property Postgres enforces rather than a
-- promise the body keeps. §08 requires STABLE explicitly.
SELECT is(
  (SELECT p.provolatile FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_preview_tournament_score' LIMIT 1),
  's'::"char",
  'SS26.PARITY.02 the preview facade is STABLE and so cannot write'
);

-- SS26.PARITY.03 — it has a pinned search_path, per §08.
SELECT ok(
  (SELECT p.proconfig::TEXT LIKE '%search_path%' FROM pg_proc p
     JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_preview_tournament_score' LIMIT 1),
  'SS26.PARITY.03 the preview facade pins its search_path'
);

-- SS26.PARITY.04 — preview returns the same components the writer persisted,
-- for the classic engine over a real scored tournament. This is the assertion
-- that makes "one dispatcher and the same immutable strategy" (§01) checkable.
-- Guarded for the same reason as pg_temp.nw: results_eq OPENs a cursor over the
-- query, so a missing facade raises and aborts every assertion after it.
-- Returning no rows instead makes this one clean named failure.
CREATE FUNCTION pg_temp.preview(p_code TEXT, p_place INT)
RETURNS TABLE (place_pts NUMERIC, de NUMERIC, podium NUMERIC, final NUMERIC)
LANGUAGE plpgsql AS $pv$
BEGIN
  RETURN QUERY
    SELECT pv.num_place_pts, pv.num_de_bonus, pv.num_podium_bonus, pv.num_final_score
      FROM tbl_tournament t
      CROSS JOIN LATERAL fn_preview_tournament_score(t.id_tournament, p_place) pv
     WHERE t.txt_code = p_code;
EXCEPTION WHEN undefined_function OR undefined_column OR undefined_table THEN
  RETURN;
END $pv$;

SELECT results_eq(
  $$SELECT * FROM pg_temp.preview('SS26-PPW-N24', 1)$$,
  $$SELECT place_pts, de, podium, final FROM pg_temp.comp('SS26-PPW-N24', 1)$$,
  'SS26.PARITY.04 preview components equal the persisted components (classic engine)'
);

-- =============================================================================
-- SS26.HIST.07 — the normalized type policy must migrate each season's OWN
-- multipliers. The preflight recorded that they differ between seasons
-- (SPWS-2023-2024 mew=2.0 vs SPWS-2024-2025 mew=1.2; msw 2.0 vs 1.2), so a
-- migration that writes column defaults instead of stored values would silently
-- rescore history. RED until tbl_scoring_type_config exists.
-- =============================================================================
CREATE FUNCTION pg_temp.type_cfg()
RETURNS TABLE (season TEXT, ttype TEXT, mult NUMERIC(10,4))
LANGUAGE plpgsql AS $tc$
BEGIN
  RETURN QUERY
    SELECT s.txt_code, tc.enum_type::TEXT, tc.num_multiplier::NUMERIC(10,4)
      FROM tbl_scoring_type_config tc
      JOIN tbl_scoring_config c ON c.id_config = tc.id_config
      JOIN tbl_season s ON s.id_season = c.id_season
     WHERE s.txt_code IN ('SPWS-2023-2024','SPWS-2024-2025')
       AND tc.enum_type IN ('MEW','MSW')
     ORDER BY s.txt_code, tc.enum_type::TEXT;
EXCEPTION WHEN undefined_table OR undefined_column THEN
  RETURN;
END $tc$;

SELECT results_eq(
  $$SELECT * FROM pg_temp.type_cfg()$$,
  $$VALUES ('SPWS-2023-2024', 'MEW', 2.0000::NUMERIC(10,4)),
           ('SPWS-2023-2024', 'MSW', 2.0000::NUMERIC(10,4)),
           ('SPWS-2024-2025', 'MEW', 1.2000::NUMERIC(10,4)),
           ('SPWS-2024-2025', 'MSW', 2.0000::NUMERIC(10,4))$$,
  'SS26.HIST.07 normalized type config preserves each season''s own multipliers, not column defaults'
);

SELECT * FROM finish();
ROLLBACK;
