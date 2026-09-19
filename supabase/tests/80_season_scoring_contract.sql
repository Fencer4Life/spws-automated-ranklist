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

SELECT plan(73);

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
-- with no exception raised (§02). This used PPS as the honest probe -- a type
-- that was in the enum but genuinely unconfigured, before the normalized type
-- policy landed. It cannot any more: 20260919000004 (PPS/MPS multipliers,
-- pulled forward from delivery step 6) backfills PPS into every season's
-- configuration, so probing it here would test the wrong thing. p_type is
-- TEXT specifically so a value that is not a tournament type at all can be
-- probed without an enum cast error; SS26.TYPE.03 uses the same string for
-- fn_get_min_participants's equivalent fail-closed gate.
SELECT throws_like(
  $$SELECT fn_assert_type_configured(
      (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'), 'NOT_A_TYPE')$$,
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

-- =============================================================================
-- SS26.TYPE — normalized per-type policy (§11 step 3, first half).
--
-- The migration preflight proved that per-season multipliers genuinely differ
-- (SPWS-2023-2024 MEW 2.0 against SPWS-2024-2025 MEW 1.2; MSW moves 2.0 -> 1.2),
-- so a migration writing column DEFAULTS instead of STORED values would silently
-- rescore history. SS26.HIST.07 above pins two of those values by name; these
-- assert the property over every season and every type at once.
-- =============================================================================

-- Mismatch counter, guarded the same way as the other RED helpers so a missing
-- table produces one clean failure rather than aborting the file.
CREATE FUNCTION pg_temp.type_cfg_mismatches()
RETURNS BIGINT
LANGUAGE plpgsql AS $mm$
DECLARE v BIGINT;
BEGIN
  SELECT count(*) INTO v
    FROM tbl_scoring_config c
    CROSS JOIN LATERAL (VALUES
        ('PPW', c.num_ppw_multiplier), ('MPW', c.num_mpw_multiplier),
        ('PEW', c.num_pew_multiplier), ('MEW', c.num_mew_multiplier),
        ('MSW', c.num_msw_multiplier), ('PSW', c.num_psw_multiplier),
        ('PPS', c.num_pps_multiplier), ('MPS', c.num_mps_multiplier)
      ) AS legacy(ttype, mult)
    LEFT JOIN tbl_scoring_type_config tc
           ON tc.id_config = c.id_config AND tc.enum_type::TEXT = legacy.ttype
   WHERE tc.id_type_config IS NULL OR tc.num_multiplier <> legacy.mult;
  RETURN v;
EXCEPTION WHEN undefined_table OR undefined_column THEN
  RETURN NULL;
END $mm$;

-- SS26.TYPE.01 — every season/type pair is present and carries that season's
-- OWN stored multiplier.
SELECT is(pg_temp.type_cfg_mismatches(), 0::BIGINT,
  'SS26.TYPE.01 every season/type pair migrated with its own stored multiplier, none defaulted');

-- SS26.TYPE.02 — the threshold routing is NOT what the column labels suggest,
-- and normalizing must preserve it exactly. PSW is domestic and gates on the
-- _ppw column (ADR-066, python/pipeline/db_connector.py:590-594), so a
-- normalization that routed by name would silently retighten PSW from 1 to 5.
CREATE FUNCTION pg_temp.threshold_mismatches()
RETURNS BIGINT
LANGUAGE plpgsql AS $th$
DECLARE v BIGINT;
BEGIN
  SELECT count(*) INTO v
    FROM tbl_scoring_config c
    CROSS JOIN LATERAL (VALUES
        ('PPW', c.int_min_participants_ppw), ('MPW', c.int_min_participants_ppw),
        ('PSW', c.int_min_participants_ppw), ('PEW', c.int_min_participants_evf),
        ('MEW', c.int_min_participants_evf), ('MSW', c.int_min_participants_evf),
        -- PPS/MPS threshold is hardcoded to 1, not routed from any legacy
        -- column (§07: no Admin field, no result-counting buckets).
        ('PPS', 1), ('MPS', 1)
      ) AS legacy(ttype, threshold)
    LEFT JOIN tbl_scoring_type_config tc
           ON tc.id_config = c.id_config AND tc.enum_type::TEXT = legacy.ttype
   WHERE tc.id_type_config IS NULL OR tc.int_min_participants <> legacy.threshold;
  RETURN v;
EXCEPTION WHEN undefined_table OR undefined_column THEN
  RETURN NULL;
END $th$;

SELECT is(pg_temp.threshold_mismatches(), 0::BIGINT,
  'SS26.TYPE.02 threshold routing preserved: {PPW,MPW,PSW}->ppw and {PEW,MEW,MSW}->evf');

-- SS26.TYPE.03 — the fail-closed gate §07 requires. get_min_participants
-- currently returns 1 for an unrecognised type and for a season with no config
-- at all, so a missing configuration lets everything through rather than
-- stopping it. The SQL reader must raise.
SELECT throws_like(
  $$SELECT fn_get_min_participants(
      (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'), 'NOT_A_TYPE')$$,
  '%No scoring configuration for tournament type%',
  'SS26.TYPE.03 an unrecognised tournament type raises instead of defaulting to 1'
);

-- SS26.TYPE.04 — the normalized rows track ordinary configuration edits, so a
-- pre-lock Admin change still reaches scoring through one path rather than two
-- that agree only by luck.
CREATE FUNCTION pg_temp.type_cfg_tracks_edit()
RETURNS NUMERIC
LANGUAGE plpgsql AS $tr$
DECLARE v_season INT; v_out NUMERIC;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024';
  UPDATE tbl_scoring_config SET num_mpw_multiplier = 1.7 WHERE id_season = v_season;
  SELECT tc.num_multiplier INTO v_out
    FROM tbl_scoring_type_config tc
    JOIN tbl_scoring_config c ON c.id_config = tc.id_config
   WHERE c.id_season = v_season AND tc.enum_type = 'MPW';
  RETURN v_out;
EXCEPTION WHEN undefined_table OR undefined_column THEN
  RETURN NULL;
END $tr$;

SELECT is(pg_temp.type_cfg_tracks_edit(), 1.7::NUMERIC,
  'SS26.TYPE.04 a configuration edit propagates to the normalized type rows');

-- SS26.TYPE.05 — the normalized table is what SCORING actually reads. Without
-- this, the table could be a decorative copy that happens to agree. The edit
-- above left SPWS-2023-2024 MPW at 1.7; scoring an MPW tournament in that
-- season must now use it.
CREATE FUNCTION pg_temp.scored_with_normalized()
RETURNS NUMERIC
LANGUAGE plpgsql AS $sw$
DECLARE v_season INT; v_org INT; v_event INT; v_t INT; v_f INT; v_out NUMERIC;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  -- Move the NORMALIZED row away from the legacy column's value. SS26.TYPE.04
  -- left both at 1.7; if this test scored at 1.7 it would pass whichever source
  -- scoring read, and prove nothing. At 1.9 only the normalized table gives the
  -- expected answer, so this discriminates rather than merely agreeing.
  UPDATE tbl_scoring_type_config tc SET num_multiplier = 1.9
    FROM tbl_scoring_config c
   WHERE c.id_config = tc.id_config AND c.id_season = v_season AND tc.enum_type = 'MPW';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('SS26-TYPE-EVT', 'SS26 type authority fixture', v_season, v_org, 'PLANNED')
  RETURNING id_event INTO v_event;

  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon,
    enum_gender, enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_event, 'SS26-TYPE-MPW-N24', 'SS26 MPW N=24', 'MPW', 'EPEE', 'M', 'V2',
          '2023-10-01', 24, 'IMPORTED')
  RETURNING id_tournament INTO v_t;

  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year)
  VALUES ('SS26-TYPE-1', 'Test', 1970) RETURNING id_fencer INTO v_f;

  INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES (v_f, v_t, 1);

  PERFORM fn_calc_tournament_scores(v_t);

  SELECT r.num_final_score INTO v_out FROM tbl_result r WHERE r.id_tournament = v_t;
  RETURN v_out;
EXCEPTION WHEN undefined_table OR undefined_column OR undefined_function THEN
  RETURN NULL;
END $sw$;

-- Classic engine, N=24 place 1: components 50 + 50 + 25.9604965 = 125.9604965.
-- The legacy column says 1.7 (-> 214.13); the normalized row says 1.9. Only
-- 239.32 proves scoring read the normalized table.
SELECT is(pg_temp.scored_with_normalized(), 239.32::NUMERIC,
  'SS26.TYPE.05 scoring reads its multiplier from the normalized table, not the legacy column'
);

-- =============================================================================
-- SS26.TYPE.06 — PPS/MPS enum and normalized settings.
--
-- Pulled forward per doc/plans/did-you-plan-to-optimized-penguin.md: the
-- design's §11 delivery sequence puts PPS/MPS in step 6, but the Admin UI has
-- no way to enter their multipliers, and steps 2-3a already removed the
-- hardcoded six-way CASE blocks that made a new type expensive. SENIOR
-- tournament/result-category acceptance (the rest of this ID's design-table
-- row) is PZSz ingestion, step 6, and stays out of scope here -- it gets its
-- own IDs when that flow is built.
-- =============================================================================

-- SS26.TYPE.06a — a PPS multiplier set through the ordinary write surface
-- (tbl_scoring_config) reaches the normalized type table via the existing
-- projection trigger, exactly as the six legacy types already do.
CREATE FUNCTION pg_temp.pps_reaches_type_config()
RETURNS NUMERIC
LANGUAGE plpgsql AS $pps_a$
DECLARE v_season INT; v_out NUMERIC;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027';
  UPDATE tbl_scoring_config SET num_pps_multiplier = 1.55 WHERE id_season = v_season;
  SELECT tc.num_multiplier INTO v_out
    FROM tbl_scoring_type_config tc
    JOIN tbl_scoring_config c ON c.id_config = tc.id_config
   WHERE c.id_season = v_season AND tc.enum_type = 'PPS';
  RETURN v_out;
EXCEPTION WHEN undefined_table OR undefined_column OR invalid_text_representation THEN
  RETURN NULL;
END $pps_a$;

SELECT is(pg_temp.pps_reaches_type_config(), 1.55::NUMERIC,
  'SS26.TYPE.06a a PPS multiplier set in config reaches the normalized type table');

-- SS26.TYPE.06b — fn_assert_type_configured resolves the same value for PPS
-- that 06a just wrote, reusing this transaction's state as SS26.TYPE.04/05 do.
CREATE FUNCTION pg_temp.pps_assert_type_configured()
RETURNS NUMERIC
LANGUAGE plpgsql AS $pps_b$
DECLARE v_season INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027';
  RETURN fn_assert_type_configured(v_season, 'PPS');
EXCEPTION WHEN undefined_function THEN
  RETURN NULL;
END $pps_b$;

SELECT is(pg_temp.pps_assert_type_configured(), 1.55::NUMERIC,
  'SS26.TYPE.06b fn_assert_type_configured resolves the PPS multiplier set above');

-- SS26.TYPE.06c — a PPS tournament scores end to end with its configured
-- multiplier. Classic engine (SPWS-2023-2024), N=24 place 1: raw components
-- sum to 125.9604965 (same base fixture as SS26.TYPE.05). The multiplier is
-- applied to the summed RAW components (SS26.HIST.06), so
-- round(125.9604965 * 1.55, 2) = 195.24.
CREATE FUNCTION pg_temp.pps_scored_end_to_end()
RETURNS NUMERIC
LANGUAGE plpgsql AS $pps_c$
DECLARE v_season INT; v_org INT; v_event INT; v_t INT; v_f INT; v_out NUMERIC;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  UPDATE tbl_scoring_config SET num_pps_multiplier = 1.55 WHERE id_season = v_season;

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('SS26-TYPE-PPS-EVT', 'SS26 PPS authority fixture', v_season, v_org, 'PLANNED')
  RETURNING id_event INTO v_event;

  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon,
    enum_gender, enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_event, 'SS26-TYPE-PPS-N24', 'SS26 PPS N=24', 'PPS', 'EPEE', 'M', 'V2',
          '2023-10-01', 24, 'IMPORTED')
  RETURNING id_tournament INTO v_t;

  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year)
  VALUES ('SS26-TYPE-PPS', 'Test', 1970) RETURNING id_fencer INTO v_f;

  INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES (v_f, v_t, 1);

  PERFORM fn_calc_tournament_scores(v_t);

  SELECT r.num_final_score INTO v_out FROM tbl_result r WHERE r.id_tournament = v_t;
  RETURN v_out;
EXCEPTION WHEN undefined_table OR undefined_column OR undefined_function OR invalid_text_representation THEN
  RETURN NULL;
END $pps_c$;

SELECT is(pg_temp.pps_scored_end_to_end(), 195.24::NUMERIC,
  'SS26.TYPE.06c a PPS tournament scores end-to-end with its configured multiplier'
);

-- SS26.TYPE.06d — the fixed fn_auto_populate_multiplier (live defect 1 in
-- doc/plans/did-you-plan-to-optimized-penguin.md) caches a non-NULL
-- multiplier for both PSW (previously missing, latent at 0 PSW tournaments)
-- and PPS (would otherwise hit the same gap immediately). A regression back
-- to no ELSE branch would RAISE inside the INSERT rather than return NULL, so
-- this catches WHEN OTHERS too, matching the file's "one clean failure"
-- convention for the RED-safety guards elsewhere in this file.
CREATE FUNCTION pg_temp.auto_multiplier_psw_pps()
RETURNS TEXT
LANGUAGE plpgsql AS $pps_d$
DECLARE v_season INT; v_org INT; v_event INT; v_psw NUMERIC; v_pps NUMERIC;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES ('SS26-TYPE-CACHE-EVT', 'SS26 multiplier cache fixture', v_season, v_org, 'PLANNED')
  RETURNING id_event INTO v_event;

  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon,
    enum_gender, enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_event, 'SS26-TYPE-CACHE-PSW', 'SS26 cache PSW', 'PSW', 'EPEE', 'M', 'V2',
          '2023-10-01', 8, 'IMPORTED')
  RETURNING num_multiplier INTO v_psw;

  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon,
    enum_gender, enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_event, 'SS26-TYPE-CACHE-PPS', 'SS26 cache PPS', 'PPS', 'EPEE', 'M', 'V2',
          '2023-10-01', 30, 'IMPORTED')
  RETURNING num_multiplier INTO v_pps;

  IF v_psw IS NULL OR v_pps IS NULL THEN
    RETURN 'NULL_FOUND';
  END IF;
  RETURN 'BOTH_NON_NULL';
EXCEPTION WHEN undefined_table OR undefined_column THEN
  RETURN NULL;
WHEN OTHERS THEN
  RETURN 'ERROR: ' || SQLERRM;
END $pps_d$;

SELECT is(pg_temp.auto_multiplier_psw_pps(), 'BOTH_NON_NULL',
  'SS26.TYPE.06d fn_auto_populate_multiplier caches a non-NULL multiplier for PSW and PPS'
);

-- =============================================================================
-- SS26.LOCK — the governance lock (design step 3b, first half).
-- doc/plans/scoring-governance-lock-2026-09-19.html
--
-- SS26.LOCK.01/02 aggregate one pgTAP assertion each over every governed
-- field, following this file's own type_cfg_mismatches()/threshold_mismatches()
-- convention: the per-field check happens inside the pg_temp helper so a
-- future field addition needs one array entry, not a new top-level test.
-- SS26.LOCK.11/12 are Vitest (frontend/tests/ScoringConfigEditor.test.ts,
-- SeasonManager.test.ts) and are not in this file.
-- =============================================================================

-- Attempt one field change via fn_import_scoring_config and classify the
-- result. Shared by SS26.LOCK.01 (expects OK) and .02 (expects REJECTED).
CREATE FUNCTION pg_temp.lock_try_field(p_season INT, p_key TEXT, p_new_value NUMERIC)
RETURNS TEXT
LANGUAGE plpgsql AS $ltf$
BEGIN
  PERFORM fn_import_scoring_config(
    jsonb_build_object('id_season', p_season, p_key, p_new_value));
  RETURN 'OK';
EXCEPTION WHEN OTHERS THEN
  RETURN 'REJECTED:' || SQLERRM;
END $ltf$;

-- SS26.LOCK.01 — every governed field is writable before the season's first
-- scored result. SPWS-2026-2027 carries zero scores in the base seed
-- (confirmed by scripts/check-scoring-migration-preflight.sh's SSP-06).
CREATE FUNCTION pg_temp.lock01_all_editable_unlocked()
RETURNS TEXT
LANGUAGE plpgsql AS $l01$
DECLARE
  v_season INT;
  v_field  TEXT;
  v_fields TEXT[] := ARRAY['mp_value','podium_gold','podium_silver','podium_bronze',
    'ppw_multiplier','mpw_multiplier','pew_multiplier','mew_multiplier',
    'msw_multiplier','psw_multiplier','pps_multiplier','mps_multiplier',
    'min_participants_evf','min_participants_ppw'];
  v_result   TEXT;
  v_failures TEXT := '';
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027';
  FOREACH v_field IN ARRAY v_fields LOOP
    v_result := pg_temp.lock_try_field(v_season, v_field, 9);
    IF v_result <> 'OK' THEN
      v_failures := v_failures || v_field || '=' || v_result || '; ';
    END IF;
  END LOOP;

  BEGIN
    PERFORM fn_import_scoring_config(jsonb_build_object(
      'id_season', v_season, 'engine_code', 'EVF_CLASSIC_V1_2025_2026'));
  EXCEPTION WHEN OTHERS THEN v_failures := v_failures || 'engine_code=REJECTED:' || SQLERRM || '; ';
  END;
  BEGIN
    PERFORM fn_import_scoring_config(jsonb_build_object(
      'id_season', v_season, 'ranking_rules', '{"domestic":[],"international":[]}'::jsonb));
  EXCEPTION WHEN OTHERS THEN v_failures := v_failures || 'ranking_rules=REJECTED:' || SQLERRM || '; ';
  END;

  IF v_failures = '' THEN RETURN 'ALL_OK'; ELSE RETURN v_failures; END IF;
EXCEPTION WHEN undefined_function OR undefined_column THEN
  RETURN NULL;
END $l01$;

SELECT is(pg_temp.lock01_all_editable_unlocked(), 'ALL_OK',
  'SS26.LOCK.01 every governed field is writable before the season''s first scored result');

-- SS26.LOCK.02 — the same fields, rejected individually once a score exists.
-- SPWS-2023-2024 is real seed data, already scored -- locked as soon as the
-- backfill in 20260919000005 runs. 777 is chosen to differ from every real
-- stored value (all small round numbers: 50, 3, 2, 1, 1.0, 1.2, 2.0, 5) and
-- to be a whole number so it casts cleanly to both INT and NUMERIC columns.
CREATE FUNCTION pg_temp.lock02_all_rejected_locked()
RETURNS TEXT
LANGUAGE plpgsql AS $l02$
DECLARE
  v_season INT;
  v_field  TEXT;
  v_fields TEXT[] := ARRAY['mp_value','podium_gold','podium_silver','podium_bronze',
    'ppw_multiplier','mpw_multiplier','pew_multiplier','mew_multiplier',
    'msw_multiplier','psw_multiplier','pps_multiplier','mps_multiplier',
    'min_participants_evf','min_participants_ppw'];
  v_result   TEXT;
  v_failures TEXT := '';
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024';
  FOREACH v_field IN ARRAY v_fields LOOP
    v_result := pg_temp.lock_try_field(v_season, v_field, 777);
    IF v_result NOT LIKE 'REJECTED:%locked%' THEN
      v_failures := v_failures || v_field || '=' || v_result || '; ';
    END IF;
  END LOOP;

  BEGIN
    PERFORM fn_import_scoring_config(jsonb_build_object(
      'id_season', v_season, 'engine_code', 'SPWS_FIELD_SCALED_V1_2026_2027'));
    v_failures := v_failures || 'engine_code=NOT_REJECTED; ';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%locked%' THEN v_failures := v_failures || 'engine_code=OTHER:' || SQLERRM || '; '; END IF;
  END;
  BEGIN
    PERFORM fn_import_scoring_config(jsonb_build_object(
      'id_season', v_season, 'ranking_rules', '{"domestic":[],"international":[]}'::jsonb));
    v_failures := v_failures || 'ranking_rules=NOT_REJECTED; ';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%locked%' THEN v_failures := v_failures || 'ranking_rules=OTHER:' || SQLERRM || '; '; END IF;
  END;

  IF v_failures = '' THEN RETURN 'ALL_REJECTED'; ELSE RETURN v_failures; END IF;
EXCEPTION WHEN undefined_function OR undefined_column THEN
  RETURN NULL;
END $l02$;

SELECT is(pg_temp.lock02_all_rejected_locked(), 'ALL_REJECTED',
  'SS26.LOCK.02 every governed field is rejected once the season has a scored result');

-- SS26.LOCK.03 — the trigger is the first scored RESULT, not dt_end. A
-- past-dated, unscored season stays editable; a future-dated, scored one locks.
CREATE FUNCTION pg_temp.lock03_date_independent()
RETURNS TEXT
LANGUAGE plpgsql AS $l03$
DECLARE
  v_org INT; v_engine INT;
  v_past INT; v_future INT;
  v_event INT; v_t INT; v_f INT;
  v_locked_past BOOLEAN; v_locked_future BOOLEAN;
BEGIN
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';
  SELECT id_engine INTO v_engine FROM tbl_scoring_engine
   WHERE bool_active ORDER BY ts_created DESC, id_engine DESC LIMIT 1;

  INSERT INTO tbl_season (txt_code, dt_start, dt_end, id_scoring_engine)
    VALUES ('SS26-LOCK03-PAST', '2010-01-01', '2010-12-31', v_engine)
    RETURNING id_season INTO v_past;
  INSERT INTO tbl_season (txt_code, dt_start, dt_end, id_scoring_engine)
    VALUES ('SS26-LOCK03-FUTURE', '2099-01-01', '2099-12-31', v_engine)
    RETURNING id_season INTO v_future;

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
    VALUES ('SS26-LOCK03-EVT', 'lock03 fixture', v_future, v_org, 'PLANNED')
    RETURNING id_event INTO v_event;
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon,
    enum_gender, enum_age_category, dt_tournament, int_participant_count, enum_import_status)
    VALUES (v_event, 'SS26-LOCK03-T', 'lock03', 'PPW', 'EPEE', 'M', 'V2', '2099-06-01', 10, 'IMPORTED')
    RETURNING id_tournament INTO v_t;
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year)
    VALUES ('SS26-LOCK03', 'Test', 1970) RETURNING id_fencer INTO v_f;
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES (v_f, v_t, 1);
  PERFORM fn_calc_tournament_scores(v_t);

  SELECT (ts_scoring_locked_at IS NOT NULL) INTO v_locked_past   FROM tbl_season WHERE id_season = v_past;
  SELECT (ts_scoring_locked_at IS NOT NULL) INTO v_locked_future FROM tbl_season WHERE id_season = v_future;

  IF v_locked_past = FALSE AND v_locked_future = TRUE THEN
    RETURN 'OK';
  END IF;
  RETURN format('past_unscored_locked=%s future_scored_locked=%s', v_locked_past, v_locked_future);
EXCEPTION WHEN undefined_column THEN
  RETURN NULL;
END $l03$;

SELECT is(pg_temp.lock03_date_independent(), 'OK',
  'SS26.LOCK.03 the lock trigger is the first scored result, not dt_start/dt_end');

-- SS26.LOCK.04 — direct UPDATE on tbl_scoring_config bypassing the RPC is
-- rejected post-lock by the trigger guard (defense in depth). pgTAP itself
-- runs as postgres, which the guard always lets through by design (see the
-- migration's own header) -- authenticated is genuinely reachable here
-- (it holds table-level UPDATE on tbl_scoring_config, unlike LOCK.05's
-- table below), so this simulates it exactly as 1.11 in
-- 01_database_foundation.sql already does: both the PG role (what the
-- trigger checks) and the JWT claim (what RLS's auth.role() checks).
CREATE FUNCTION pg_temp.lock04_direct_update_rejected()
RETURNS TEXT
LANGUAGE plpgsql AS $l04$
DECLARE v_season INT; v_result TEXT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024';

  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claim.role', 'authenticated', TRUE);
  PERFORM set_config('request.jwt.claims', '{"role":"authenticated","sub":"test-user"}', TRUE);
  BEGIN
    UPDATE tbl_scoring_config SET num_ppw_multiplier = 7.7777 WHERE id_season = v_season;
    v_result := 'NOT_REJECTED';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%locked%' THEN v_result := 'REJECTED'; ELSE v_result := 'OTHER:' || SQLERRM; END IF;
  END;
  RESET ROLE;
  RETURN v_result;
END $l04$;

SELECT is(pg_temp.lock04_direct_update_rejected(), 'REJECTED',
  'SS26.LOCK.04 a direct UPDATE on tbl_scoring_config is rejected on a locked season');

-- SS26.LOCK.05 — tbl_scoring_type_config was never a direct write surface
-- (trigger-owned since 20260919000002). Two independent layers close it:
-- authenticated holds no table-level UPDATE grant at all (checked directly,
-- matching 52_security_posture.sql's own convention, rather than simulating
-- a write that grants would refuse before the trigger is ever reached), and
-- the trigger itself exists as a second, redundant-by-design layer in case
-- a future migration ever adds that grant without realizing the implication.
SELECT ok(
  NOT has_table_privilege('authenticated', 'tbl_scoring_type_config', 'UPDATE'),
  'SS26.LOCK.05a authenticated holds no UPDATE grant on tbl_scoring_type_config'
);
SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_trigger
     WHERE tgrelid = 'tbl_scoring_type_config'::regclass
       AND tgname = 'trg_guard_type_config_direct_write'
  ),
  'SS26.LOCK.05b the direct-write guard trigger exists as a second, defense-in-depth layer'
);

-- SS26.LOCK.06 — ts_scoring_locked_at is set once and never moves, including
-- across a same-revision rescore of an already-locked season.
CREATE FUNCTION pg_temp.lock06_timestamp_stable()
RETURNS BOOLEAN
LANGUAGE plpgsql AS $l06$
DECLARE v_season INT; v_t INT; v_before TIMESTAMPTZ; v_after TIMESTAMPTZ;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024';
  SELECT ts_scoring_locked_at INTO v_before FROM tbl_season WHERE id_season = v_season;
  SELECT t.id_tournament INTO v_t
    FROM tbl_tournament t JOIN tbl_event e ON e.id_event = t.id_event
   WHERE e.id_season = v_season AND t.enum_import_status = 'SCORED' LIMIT 1;
  PERFORM fn_calc_tournament_scores(v_t);
  SELECT ts_scoring_locked_at INTO v_after FROM tbl_season WHERE id_season = v_season;
  RETURN v_before IS NOT NULL AND v_before = v_after;
EXCEPTION WHEN undefined_column THEN
  RETURN NULL;
END $l06$;

SELECT is(pg_temp.lock06_timestamp_stable(), TRUE,
  'SS26.LOCK.06 ts_scoring_locked_at is stable across a same-revision rescore');

-- SS26.LOCK.07 — the regression test for field-level (not whole-function)
-- authorization: handleUpdateSeason (App.svelte:1169-1197) resends the
-- FULL config with only show_evf_toggle changed. That must keep working on
-- a locked season.
CREATE FUNCTION pg_temp.lock07_toggle_only_succeeds()
RETURNS TEXT
LANGUAGE plpgsql AS $l07$
DECLARE v_season INT; v_cfg JSONB;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024';
  v_cfg := fn_export_scoring_config(v_season);
  PERFORM fn_import_scoring_config(
    v_cfg || jsonb_build_object('show_evf_toggle', NOT COALESCE((v_cfg->>'show_evf_toggle')::BOOLEAN, FALSE)));
  RETURN 'OK';
EXCEPTION WHEN OTHERS THEN
  RETURN 'REJECTED:' || SQLERRM;
END $l07$;

SELECT is(pg_temp.lock07_toggle_only_succeeds(), 'OK',
  'SS26.LOCK.07 a toggle-only resave (full payload, only show_evf_toggle changed) succeeds on a locked season');

-- SS26.LOCK.08 — the carry-over engine write path (a separate PATCH on
-- tbl_season, not part of fn_import_scoring_config) is untouched by this lock.
CREATE FUNCTION pg_temp.lock08_carryover_unaffected()
RETURNS TEXT
LANGUAGE plpgsql AS $l08$
DECLARE v_season INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-2023-2024';
  UPDATE tbl_season SET enum_carryover_engine = enum_carryover_engine WHERE id_season = v_season;
  RETURN 'OK';
EXCEPTION WHEN OTHERS THEN
  RETURN 'REJECTED:' || SQLERRM;
END $l08$;

SELECT is(pg_temp.lock08_carryover_unaffected(), 'OK',
  'SS26.LOCK.08 the carry-over engine write path stays available regardless of lock state');

-- SS26.LOCK.09 — repair (same-revision rescore) remains available: scoring
-- itself never touches tbl_scoring_config, so it is untouched by construction.
SELECT lives_ok(
  $$SELECT fn_calc_tournament_scores(
      (SELECT t.id_tournament FROM tbl_tournament t
         JOIN tbl_event e ON e.id_event = t.id_event
         JOIN tbl_season s ON s.id_season = e.id_season
        WHERE s.txt_code = 'SPWS-2023-2024' AND t.enum_import_status = 'SCORED' LIMIT 1))$$,
  'SS26.LOCK.09 same-revision rescore remains available on a locked season'
);

-- SS26.LOCK.10 — the partial unique index is the concurrency safety net: two
-- racing writers cannot both leave an active revision for the same season.
CREATE FUNCTION pg_temp.lock10_unique_active_revision()
RETURNS TEXT
LANGUAGE plpgsql AS $l10$
DECLARE v_season INT; v_engine INT;
BEGIN
  SELECT id_season, id_scoring_engine INTO v_season, v_engine
    FROM tbl_season WHERE txt_code = 'SPWS-2023-2024';
  INSERT INTO tbl_scoring_config_revision
    (id_season, id_engine, json_snapshot, txt_actor, txt_reason, bool_active)
  VALUES (v_season, v_engine, '{}'::jsonb, 'pgtap', 'lock10 duplicate probe', TRUE);
  RETURN 'NOT_REJECTED';
EXCEPTION WHEN unique_violation THEN RETURN 'REJECTED';
WHEN undefined_table THEN RETURN NULL;
END $l10$;

SELECT is(pg_temp.lock10_unique_active_revision(), 'REJECTED',
  'SS26.LOCK.10 the partial unique index rejects a second active revision for one season');

-- =============================================================================
-- SS26.REVISION — the privileged audited whole-season revision/rescore path.
-- fn_revise_and_rescore_season does not exist yet -- RED until the second
-- migration (20260919000006_scoring_privileged_revision.sql) lands. Design
-- doc/plans/scoring-governance-lock-2026-09-19.html §07/§09.
-- =============================================================================

-- Fixture builder: a fresh scratch season with one scored tournament, two
-- results (place 1 and 2) -- establishes an initial revision via the
-- ORDINARY lock path (fn_ensure_active_scoring_revision, called from
-- fn_calc_tournament_scores), exactly like a real season's first score.
-- Plain fn_create_season (unlike fn_create_season_with_skeletons) never
-- assigns id_scoring_engine -- LIVE DEFECT 2 in 20260919000004 fixed that
-- gap only for the wizard's own creation path -- so this helper assigns the
-- same newest-active-engine default by hand, or fn_calc_tournament_scores
-- would raise "Unknown scoring engine" before the fixture even exists.
CREATE FUNCTION pg_temp.revision_build_season(
  p_code TEXT, p_dt_start DATE, p_dt_end DATE, p_tourn_type TEXT
) RETURNS INT
LANGUAGE plpgsql AS $rbs$
DECLARE
  v_season INT;
  v_org    INT;
  v_event  INT;
  v_tourn  INT;
  v_fencer1 INT;
  v_fencer2 INT;
BEGIN
  v_season := fn_create_season(p_code, p_dt_start, p_dt_end);

  UPDATE tbl_season SET id_scoring_engine = (
    SELECT se.id_engine FROM tbl_scoring_engine se
     WHERE se.bool_active
     ORDER BY se.ts_created DESC, se.id_engine DESC LIMIT 1
  ) WHERE id_season = v_season;

  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES (p_code || '-EVT', p_code || ' event', v_season, v_org, 'PLANNED')
  RETURNING id_event INTO v_event;

  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count,
    enum_import_status)
  VALUES (v_event, p_code || '-T1', p_code || ' tournament', p_tourn_type::enum_tournament_type,
    'EPEE', 'M', 'V2', p_dt_start + 30, 8, 'IMPORTED')
  RETURNING id_tournament INTO v_tourn;

  INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality, int_birth_year, enum_gender)
  VALUES (p_code || '-F1', 'Tester', 'PL', EXTRACT(YEAR FROM p_dt_end)::INT - 55, 'M')
  RETURNING id_fencer INTO v_fencer1;
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality, int_birth_year, enum_gender)
  VALUES (p_code || '-F2', 'Tester', 'PL', EXTRACT(YEAR FROM p_dt_end)::INT - 55, 'M')
  RETURNING id_fencer INTO v_fencer2;

  INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES
    (v_fencer1, v_tourn, 1),
    (v_fencer2, v_tourn, 2);

  PERFORM fn_calc_tournament_scores(v_tourn);

  RETURN v_season;
END;
$rbs$;

SELECT pg_temp.revision_build_season('SS26-REV-OK', '2040-08-01', '2041-07-15', 'PPW');
SELECT pg_temp.revision_build_season('SS26-REV-FAIL', '2042-08-01', '2043-07-15', 'MSW');

-- REV-FAIL's tournament scored fine at fixture-build time. The plan's own
-- prose (§09) illustrates REVISION.07 with "a tournament with a deliberately
-- unconfigured type" -- tried first as a DELETEd tbl_scoring_type_config row,
-- but fn_apply_scoring_config_write's own UPDATE on tbl_scoring_config
-- re-fires the sync trigger (fn_sync_scoring_type_config) before the rescore
-- loop ever runs, which resurrects every type row -- including the deleted
-- one -- from the still-present scalar column. Every revision necessarily
-- re-syncs first, so a config-level injection can never survive to the loop.
-- A data-level corruption survives it instead: fn_resolve_scoring_params's
-- own guard ("Tournament % has no participant count") fires unconditionally,
-- independent of type configuration, and is exactly as valid an injected
-- mid-rescore failure for what REVISION.07 actually tests -- atomic rollback
-- of the whole call when ANY exception reaches the loop, not specifically a
-- type-config gap.
UPDATE tbl_tournament
   SET int_participant_count = NULL
 WHERE id_event = (SELECT id_event FROM tbl_event
                     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SS26-REV-FAIL'));

-- SS26.REVISION.01 — the one function in this codebase revoked from
-- `authenticated` too, not just PUBLIC/anon: reachable only as postgres/
-- service_role outside the web session entirely (§07).
SELECT ok(
  NOT has_function_privilege('authenticated',
    'fn_revise_and_rescore_season(integer, jsonb, text, text, text, text)', 'EXECUTE'),
  'SS26.REVISION.01 authenticated cannot execute fn_revise_and_rescore_season'
);

-- SS26.REVISION.02 — empty p_reason/p_actor raise before anything is written.
SELECT throws_like(
  $$SELECT fn_revise_and_rescore_season(
      (SELECT id_season FROM tbl_season WHERE txt_code = 'SS26-REV-OK'),
      '{}'::jsonb, NULL, '', 'test-operator', NULL)$$,
  '%reason%',
  'SS26.REVISION.02a empty p_reason raises before anything is written'
);
SELECT throws_like(
  $$SELECT fn_revise_and_rescore_season(
      (SELECT id_season FROM tbl_season WHERE txt_code = 'SS26-REV-OK'),
      '{}'::jsonb, NULL, 'Board correction', '', NULL)$$,
  '%actor%',
  'SS26.REVISION.02b empty p_actor raises before anything is written'
);

-- SS26.REVISION.03 — the prior active revision survives, deactivated,
-- snapshot untouched -- append-only, never deleted or overwritten.
CREATE FUNCTION pg_temp.revision03_prior_survives() RETURNS TEXT
LANGUAGE plpgsql AS $r3$
DECLARE
  v_season INT; v_old_revision INT; v_old_snapshot JSONB; v_new_revision INT;
  v_check_active BOOLEAN; v_check_snapshot JSONB;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SS26-REV-OK';
  SELECT id_revision, json_snapshot INTO v_old_revision, v_old_snapshot
    FROM tbl_scoring_config_revision WHERE id_season = v_season AND bool_active;

  SELECT id_revision INTO v_new_revision FROM fn_revise_and_rescore_season(
    v_season, jsonb_build_object('mp_value', 111), NULL,
    'REVISION.03 probe', 'test-operator', 'BOARD-03');

  SELECT bool_active, json_snapshot INTO v_check_active, v_check_snapshot
    FROM tbl_scoring_config_revision WHERE id_revision = v_old_revision;

  IF v_check_active IS DISTINCT FROM FALSE THEN RETURN 'FAIL:old still active'; END IF;
  IF v_check_snapshot IS DISTINCT FROM v_old_snapshot THEN RETURN 'FAIL:old snapshot mutated'; END IF;
  IF v_new_revision = v_old_revision THEN RETURN 'FAIL:no new revision created'; END IF;
  RETURN 'OK';
END;
$r3$;

SELECT is(pg_temp.revision03_prior_survives(), 'OK',
  'SS26.REVISION.03 the prior active revision survives, deactivated, snapshot intact');

-- SS26.REVISION.04 — an engine code identical to the current one is a
-- data-only revision: the existing engine row is reused, never re-created.
CREATE FUNCTION pg_temp.revision04_same_engine_no_new_row() RETURNS TEXT
LANGUAGE plpgsql AS $r4$
DECLARE
  v_season INT; v_engine_code TEXT; v_count_before INT; v_count_after INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SS26-REV-OK';
  SELECT se.txt_code INTO v_engine_code
    FROM tbl_season s JOIN tbl_scoring_engine se ON se.id_engine = s.id_scoring_engine
   WHERE s.id_season = v_season;

  SELECT COUNT(*) INTO v_count_before FROM tbl_scoring_engine;

  PERFORM fn_revise_and_rescore_season(
    v_season, '{}'::jsonb, v_engine_code,
    'REVISION.04 probe', 'test-operator', NULL);

  SELECT COUNT(*) INTO v_count_after FROM tbl_scoring_engine;

  IF v_count_after <> v_count_before THEN RETURN 'FAIL:new engine row created'; END IF;
  RETURN 'OK';
END;
$r4$;

SELECT is(pg_temp.revision04_same_engine_no_new_row(), 'OK',
  'SS26.REVISION.04 passing the current engine code is a data-only revision, no new engine row');

-- SS26.REVISION.05 — a multiplier/threshold-only revision (no engine
-- change) is permitted and rescoring actually reflects it.
CREATE FUNCTION pg_temp.revision05_rescore_reflects_change() RETURNS TEXT
LANGUAGE plpgsql AS $r5$
DECLARE
  v_season INT; v_tourn INT;
  v_score_before NUMERIC; v_score_after NUMERIC;
  v_engine_before INT; v_engine_after INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SS26-REV-OK';
  SELECT id_scoring_engine INTO v_engine_before FROM tbl_season WHERE id_season = v_season;
  SELECT t.id_tournament INTO v_tourn
    FROM tbl_tournament t JOIN tbl_event e ON e.id_event = t.id_event
   WHERE e.id_season = v_season;
  SELECT num_final_score INTO v_score_before
    FROM tbl_result WHERE id_tournament = v_tourn AND int_place = 1;

  PERFORM fn_revise_and_rescore_season(
    v_season, jsonb_build_object('podium_gold', 999), NULL,
    'REVISION.05 probe', 'test-operator', NULL);

  SELECT id_scoring_engine INTO v_engine_after FROM tbl_season WHERE id_season = v_season;
  SELECT num_final_score INTO v_score_after
    FROM tbl_result WHERE id_tournament = v_tourn AND int_place = 1;

  IF v_engine_after IS DISTINCT FROM v_engine_before THEN RETURN 'FAIL:engine changed unexpectedly'; END IF;
  IF v_score_after IS NOT DISTINCT FROM v_score_before THEN RETURN 'FAIL:score unchanged after revision'; END IF;
  RETURN 'OK';
END;
$r5$;

SELECT is(pg_temp.revision05_rescore_reflects_change(), 'OK',
  'SS26.REVISION.05 multiplier/threshold-only revision is permitted and rescoring reflects it');

-- SS26.REVISION.06 — after a successful call, every result in the season
-- references the new revision id; zero rows reference the old one.
CREATE FUNCTION pg_temp.revision06_all_results_stamped() RETURNS TEXT
LANGUAGE plpgsql AS $r6$
DECLARE
  v_season INT; v_new_revision INT; v_bad_count INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SS26-REV-OK';

  SELECT id_revision INTO v_new_revision FROM fn_revise_and_rescore_season(
    v_season, jsonb_build_object('mp_value', 222), NULL,
    'REVISION.06 probe', 'test-operator', NULL);

  SELECT COUNT(*) INTO v_bad_count
    FROM tbl_result r
    JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
    JOIN tbl_event e ON e.id_event = t.id_event
   WHERE e.id_season = v_season
     AND r.id_scoring_revision IS NOT NULL
     AND r.id_scoring_revision <> v_new_revision;

  IF v_new_revision IS NULL THEN RETURN 'FAIL:no revision returned'; END IF;
  IF v_bad_count > 0 THEN RETURN 'FAIL:' || v_bad_count || ' stale-revision result(s)'; END IF;
  RETURN 'OK';
END;
$r6$;

SELECT is(pg_temp.revision06_all_results_stamped(), 'OK',
  'SS26.REVISION.06 after a successful call every result references the new revision id');

-- SS26.REVISION.07 — an injected mid-rescore failure (SS26-REV-FAIL's
-- tournament, its participant count corrupted to NULL above) leaves the
-- prior revision active and every score at its pre-revision value: the
-- whole transaction, including the new revision row's own INSERT, rolls
-- back. The inner
-- BEGIN/EXCEPTION block is a PL/pgSQL implicit SAVEPOINT -- it undoes only
-- the failed call's effects, not this probe function's own SELECTs before
-- and after, which is what lets one function assert both sides.
CREATE FUNCTION pg_temp.revision07_mid_rescore_rollback() RETURNS TEXT
LANGUAGE plpgsql AS $r7$
DECLARE
  v_season INT;
  v_revision_before INT; v_score_before NUMERIC;
  v_revision_after INT; v_score_after NUMERIC;
  v_revision_count_after INT;
  v_raised BOOLEAN := FALSE;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SS26-REV-FAIL';
  SELECT id_active_scoring_revision INTO v_revision_before FROM tbl_season WHERE id_season = v_season;
  SELECT r.num_final_score INTO v_score_before
    FROM tbl_result r JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
    JOIN tbl_event e ON e.id_event = t.id_event
   WHERE e.id_season = v_season AND r.int_place = 1;

  BEGIN
    PERFORM fn_revise_and_rescore_season(
      v_season, jsonb_build_object('mp_value', 333), NULL,
      'REVISION.07 probe (expected to fail)', 'test-operator', NULL);
  EXCEPTION WHEN OTHERS THEN
    v_raised := TRUE;
  END;

  IF NOT v_raised THEN RETURN 'FAIL:did not raise'; END IF;

  SELECT id_active_scoring_revision INTO v_revision_after FROM tbl_season WHERE id_season = v_season;
  SELECT r.num_final_score INTO v_score_after
    FROM tbl_result r JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
    JOIN tbl_event e ON e.id_event = t.id_event
   WHERE e.id_season = v_season AND r.int_place = 1;
  SELECT COUNT(*) INTO v_revision_count_after
    FROM tbl_scoring_config_revision WHERE id_season = v_season;

  IF v_revision_after IS DISTINCT FROM v_revision_before THEN RETURN 'FAIL:active revision changed'; END IF;
  IF v_score_after IS DISTINCT FROM v_score_before THEN RETURN 'FAIL:score changed despite rollback'; END IF;
  IF v_revision_count_after <> 1 THEN RETURN 'FAIL:revision row count is ' || v_revision_count_after; END IF;
  RETURN 'OK';
END;
$r7$;

SELECT is(pg_temp.revision07_mid_rescore_rollback(), 'OK',
  'SS26.REVISION.07 a mid-rescore failure rolls back the whole transaction, prior revision and scores intact');

-- SS26.REVISION.08 — a successful call is atomic end to end: season
-- pointer, revision activation and every rescored result's stamp all agree
-- in one post-call snapshot (the single-transaction-assertion alternative
-- §11 names, matching evf_historical_event_fragment_repair.sql's pattern
-- for a comparable all-or-nothing migration).
CREATE FUNCTION pg_temp.revision08_atomic_consistency() RETURNS TEXT
LANGUAGE plpgsql AS $r8$
DECLARE
  v_season INT; v_new_revision INT;
  v_season_active INT; v_revision_flag BOOLEAN;
  v_old_flag_count INT; v_mismatched_results INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SS26-REV-OK';

  SELECT id_revision INTO v_new_revision FROM fn_revise_and_rescore_season(
    v_season, jsonb_build_object('mp_value', 444), NULL,
    'REVISION.08 probe', 'test-operator', NULL);

  SELECT id_active_scoring_revision INTO v_season_active FROM tbl_season WHERE id_season = v_season;
  SELECT bool_active INTO v_revision_flag FROM tbl_scoring_config_revision WHERE id_revision = v_new_revision;
  SELECT COUNT(*) INTO v_old_flag_count FROM tbl_scoring_config_revision
   WHERE id_season = v_season AND bool_active AND id_revision <> v_new_revision;
  SELECT COUNT(*) INTO v_mismatched_results
    FROM tbl_result r JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
    JOIN tbl_event e ON e.id_event = t.id_event
   WHERE e.id_season = v_season AND r.id_scoring_revision IS DISTINCT FROM v_new_revision;

  IF v_season_active IS DISTINCT FROM v_new_revision THEN RETURN 'FAIL:season not pointing at new revision'; END IF;
  IF v_revision_flag IS NOT TRUE THEN RETURN 'FAIL:new revision not active'; END IF;
  IF v_old_flag_count <> 0 THEN RETURN 'FAIL:more than one active revision'; END IF;
  IF v_mismatched_results <> 0 THEN RETURN 'FAIL:result stamps disagree with active revision'; END IF;
  RETURN 'OK';
END;
$r8$;

SELECT is(pg_temp.revision08_atomic_consistency(), 'OK',
  'SS26.REVISION.08 a successful call flips season pointer, revision activation and result stamps together');

-- =============================================================================
-- SS26.LOCK.13 / SS26.REVISION.09 -- default_ranking_mode joins both governed
-- surfaces. doc/plans/ranking-schema-v2-2026-09-19.html §05/§09. RED until
-- 20260919000007 lands (enum_ranking_mode, tbl_scoring_config.enum_default_
-- ranking_mode do not exist yet).
-- =============================================================================

-- SS26.LOCK.13 -- editable before the first score (real, unlocked
-- SPWS-2026-2027), rejected once locked (real, seed-scored SPWS-2023-2024).
-- Same two seasons SS26.LOCK.01/02 already use.
CREATE FUNCTION pg_temp.lock13_default_ranking_mode() RETURNS TEXT
LANGUAGE plpgsql AS $l13$
DECLARE
  v_unlocked INT;
  v_locked   INT;
BEGIN
  SELECT id_season INTO v_unlocked FROM tbl_season WHERE txt_code = 'SPWS-2026-2027';
  SELECT id_season INTO v_locked   FROM tbl_season WHERE txt_code = 'SPWS-2023-2024';

  PERFORM fn_import_scoring_config(jsonb_build_object(
    'id_season', v_unlocked, 'default_ranking_mode', 'PPW'));
  IF (SELECT enum_default_ranking_mode FROM tbl_scoring_config WHERE id_season = v_unlocked) <> 'PPW' THEN
    RETURN 'FAIL:unlocked write did not apply';
  END IF;

  BEGIN
    PERFORM fn_import_scoring_config(jsonb_build_object(
      'id_season', v_locked, 'default_ranking_mode', 'RANKING'));
    RETURN 'FAIL:locked season accepted a default_ranking_mode change';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%locked%' THEN RETURN 'FAIL:OTHER:' || SQLERRM; END IF;
  END;

  RETURN 'OK';
EXCEPTION WHEN undefined_function OR undefined_column THEN
  RETURN NULL;
END $l13$;

SELECT is(pg_temp.lock13_default_ranking_mode(), 'OK',
  'SS26.LOCK.13 default_ranking_mode is editable before first score and rejected after');

-- SS26.REVISION.09 -- the privileged revision path can change
-- default_ranking_mode on its own, independent of any engine/multiplier
-- change. Reuses the already-built, already-scored SS26-REV-OK fixture.
CREATE FUNCTION pg_temp.revision09_default_ranking_mode() RETURNS TEXT
LANGUAGE plpgsql AS $r9$
DECLARE
  v_season      INT;
  v_mode_before TEXT;
  v_mode_after  TEXT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SS26-REV-OK';
  SELECT enum_default_ranking_mode::TEXT INTO v_mode_before FROM tbl_scoring_config WHERE id_season = v_season;

  PERFORM fn_revise_and_rescore_season(
    v_season,
    jsonb_build_object('default_ranking_mode',
      CASE WHEN v_mode_before = 'RANKING' THEN 'PPW' ELSE 'RANKING' END),
    NULL, 'REVISION.09 probe', 'test-operator', NULL);

  SELECT enum_default_ranking_mode::TEXT INTO v_mode_after FROM tbl_scoring_config WHERE id_season = v_season;

  IF v_mode_after IS NOT DISTINCT FROM v_mode_before THEN RETURN 'FAIL:mode unchanged'; END IF;
  RETURN 'OK';
EXCEPTION WHEN undefined_function OR undefined_column THEN
  RETURN NULL;
END $r9$;

SELECT is(pg_temp.revision09_default_ranking_mode(), 'OK',
  'SS26.REVISION.09 the privileged revision path can change default_ranking_mode independent of engine/multiplier changes');

-- =============================================================================
-- SS26.RANK -- Season Scoring Rules v2: three sections, two display groups,
-- fn_ranking_full. doc/plans/ranking-schema-v2-2026-09-19.html §06/§09.
-- ADR-098 (drafted, sign-off obtained 19 Sep 2026, file pending). RED until
-- 20260919000008 lands (fn_ranking_rules_canonical, fn_ranking_full and its
-- two per-engine bodies do not exist yet).
--
-- RANK.01, 04-07 are pure canonicalization/validation -- literal JSONB in,
-- no season/tournament fixture needed. RANK.02/03/08/09/10/11/12 need scored
-- results, built below as small dedicated scratch seasons (never the shared
-- active season -- same discipline SS26.REVISION already established).
-- =============================================================================

-- SS26.RANK.01 -- three Season Scoring Rules sections resolve to exactly two
-- display groups.
CREATE FUNCTION pg_temp.rank01_two_groups() RETURNS TEXT[]
LANGUAGE plpgsql AS $rk1$
BEGIN
  RETURN (
    SELECT array_agg(DISTINCT grp ORDER BY grp)
      FROM fn_ranking_rules_canonical($j$
        {
          "schema_version": 2,
          "season_scoring_rules": {
            "spws":    {"group":"spws",     "types":["PPW","MPW"],             "buckets":[{"best":2,"types":["PPW"]},{"always":true,"types":["MPW"]}]},
            "evf_fie": {"group":"evf_plus", "types":["PEW","MEW","MSW","PSW"], "buckets":[{"always":true,"types":["PEW","MEW","MSW","PSW"]}]},
            "pzsz":    {"group":"evf_plus", "types":["PPS","MPS"],             "buckets":[{"always":true,"types":["PPS","MPS"]}]}
          },
          "display_groups": {"spws":{"sections":["spws"]}, "evf_plus":{"sections":["evf_fie","pzsz"]}},
          "views": {"PPW":["spws"], "RANKING":["spws","evf_plus"]}
        }
      $j$::jsonb)
  );
EXCEPTION WHEN undefined_function THEN
  RETURN NULL;
END $rk1$;

SELECT is(pg_temp.rank01_two_groups(), ARRAY['evf_plus','spws']::TEXT[],
  'SS26.RANK.01 three Season Scoring Rules sections resolve to exactly two display groups');

-- SS26.RANK.04 -- a bucket declaring neither best nor always is rejected.
SELECT throws_like(
  $$SELECT count(*) FROM fn_ranking_rules_canonical('
    {"schema_version":2,
     "season_scoring_rules":{"spws":{"group":"spws","types":["PPW"],"buckets":[{"types":["PPW"]}]}},
     "display_groups":{"spws":{"sections":["spws"]}},
     "views":{"PPW":["spws"]}}
  '::jsonb)$$,
  '%exactly one of best or always%',
  'SS26.RANK.04 a bucket declaring neither best nor always is rejected'
);

-- SS26.RANK.05 -- a bucket type outside enum_tournament_type is rejected.
SELECT throws_like(
  $$SELECT count(*) FROM fn_ranking_rules_canonical('
    {"schema_version":2,
     "season_scoring_rules":{"spws":{"group":"spws","types":["ZZZ"],"buckets":[{"always":true,"types":["ZZZ"]}]}},
     "display_groups":{"spws":{"sections":["spws"]}},
     "views":{"PPW":["spws"]}}
  '::jsonb)$$,
  '%Unknown tournament type%',
  'SS26.RANK.05 a bucket type outside enum_tournament_type is rejected'
);

-- SS26.RANK.06 -- a non-positive best is rejected.
SELECT throws_like(
  $$SELECT count(*) FROM fn_ranking_rules_canonical('
    {"schema_version":2,
     "season_scoring_rules":{"spws":{"group":"spws","types":["PPW"],"buckets":[{"best":0,"types":["PPW"]}]}},
     "display_groups":{"spws":{"sections":["spws"]}},
     "views":{"PPW":["spws"]}}
  '::jsonb)$$,
  '%must be positive%',
  'SS26.RANK.06 a non-positive best is rejected'
);

-- SS26.RANK.07 -- the same tournament type declared in two sections that both
-- feed one view is rejected (the double-count guard).
SELECT throws_like(
  $$SELECT count(*) FROM fn_ranking_rules_canonical('
    {"schema_version":2,
     "season_scoring_rules":{
       "evf_fie":{"group":"evf_plus","types":["PSW"],"buckets":[{"always":true,"types":["PSW"]}]},
       "pzsz":{"group":"evf_plus","types":["PSW"],"buckets":[{"always":true,"types":["PSW"]}]}
     },
     "display_groups":{"evf_plus":{"sections":["evf_fie","pzsz"]}},
     "views":{"RANKING":["evf_plus"]}}
  '::jsonb)$$,
  '%double-counted%',
  'SS26.RANK.07 the same tournament type declared in two sections feeding one view is rejected'
);

-- Shared fixture helper: one tournament (one event) plus one result, exact
-- score set directly rather than computed by fn_calc_tournament_scores --
-- these tests are about bucket AGGREGATION, not the scoring formula (already
-- covered by SS26.NEW/SS26.HIST), so a literal num_final_score is deliberate.
--
-- enum_status = 'COMPLETED', not the column's own 'PLANNED' default: every
-- scratch season fn_create_season builds defaults to enum_carryover_engine
-- = EVENT_FK_MATCHING (ADR-045 flipped the season-level default after the
-- column itself was added with 'EVENT_CODE_MATCHING' -- verified live, not
-- assumed, after this fixture first returned zero rows through
-- fn_ranking_full_event_fk_matching). That engine's eligibility comes from
-- vw_eligible_event, whose branch 1 excludes CREATED/PLANNED/SCHEDULED/
-- CHANGED/CANCELLED events -- a event left at its column default is
-- invisible to it.
CREATE FUNCTION pg_temp.rank_add_result(
  p_season INT, p_org INT, p_code TEXT,
  p_type TEXT, p_weapon TEXT, p_gender TEXT, p_cat TEXT,
  p_fencer INT, p_score NUMERIC
) RETURNS INT  -- the created id_event, so a caller can link a later season's
               -- id_prior_event to it (SS26.RANK.12's FK carry-over fixture)
LANGUAGE plpgsql AS $rar$
DECLARE
  v_event INT;
  v_tourn INT;
BEGIN
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
  VALUES (p_code, p_code || ' event', p_season, p_org, 'COMPLETED')
  RETURNING id_event INTO v_event;

  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon,
    enum_gender, enum_age_category, dt_tournament, int_participant_count, enum_import_status)
  VALUES (v_event, p_code || '-T', p_code || ' tournament', p_type::enum_tournament_type,
    p_weapon::enum_weapon_type, p_gender::enum_gender_type, p_cat::enum_age_category,
    CURRENT_DATE, 8, 'IMPORTED')
  RETURNING id_tournament INTO v_tourn;

  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
  VALUES (p_fencer, v_tourn, 1, p_score);

  RETURN v_event;
END $rar$;

-- SS26.RANK.02/03 fixture -- one isolated season per property, so the
-- best-N cap and the always-include lack-of-cap are proven independently
-- rather than conflated in one combined total.
CREATE FUNCTION pg_temp.rank_setup_best_always() RETURNS VOID
LANGUAGE plpgsql AS $rksba$
DECLARE
  v_org INT;
  v_season_best   INT;
  v_season_always INT;
  v_fencer_best   INT;
  v_fencer_always INT;
BEGIN
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  -- best:2 of three PPW scores {30,20,10} must sum to 50, dropping the 10.
  v_season_best := fn_create_season('SS26-RANK-BEST', '2044-08-01', '2045-07-15');
  UPDATE tbl_scoring_config SET json_ranking_rules = $j$
    {"schema_version":2,
     "season_scoring_rules":{"spws":{"group":"spws","types":["PPW"],"buckets":[{"best":2,"types":["PPW"]}]}},
     "display_groups":{"spws":{"sections":["spws"]}},
     "views":{"PPW":["spws"],"RANKING":["spws"]}}
  $j$::jsonb WHERE id_season = v_season_best;

  INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality, int_birth_year, enum_gender)
  VALUES ('RankBest', 'Tester', 'PL', 1990, 'M') RETURNING id_fencer INTO v_fencer_best;

  PERFORM pg_temp.rank_add_result(v_season_best, v_org, 'RB1', 'PPW', 'EPEE', 'M', 'V2', v_fencer_best, 30);
  PERFORM pg_temp.rank_add_result(v_season_best, v_org, 'RB2', 'PPW', 'EPEE', 'M', 'V2', v_fencer_best, 20);
  PERFORM pg_temp.rank_add_result(v_season_best, v_org, 'RB3', 'PPW', 'EPEE', 'M', 'V2', v_fencer_best, 10);

  -- always:true over two MPW scores {5,7} must sum to 12 -- both counted,
  -- proving there is no implicit top-1 cap on an always-include bucket.
  v_season_always := fn_create_season('SS26-RANK-ALWAYS', '2045-08-01', '2046-07-15');
  UPDATE tbl_scoring_config SET json_ranking_rules = $j$
    {"schema_version":2,
     "season_scoring_rules":{"spws":{"group":"spws","types":["MPW"],"buckets":[{"always":true,"types":["MPW"]}]}},
     "display_groups":{"spws":{"sections":["spws"]}},
     "views":{"PPW":["spws"],"RANKING":["spws"]}}
  $j$::jsonb WHERE id_season = v_season_always;

  INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality, int_birth_year, enum_gender)
  VALUES ('RankAlways', 'Tester', 'PL', 1990, 'M') RETURNING id_fencer INTO v_fencer_always;

  PERFORM pg_temp.rank_add_result(v_season_always, v_org, 'RA1', 'MPW', 'EPEE', 'M', 'V2', v_fencer_always, 5);
  PERFORM pg_temp.rank_add_result(v_season_always, v_org, 'RA2', 'MPW', 'EPEE', 'M', 'V2', v_fencer_always, 7);
END $rksba$;

SELECT pg_temp.rank_setup_best_always();

CREATE FUNCTION pg_temp.rank02_best_n_caps() RETURNS NUMERIC
LANGUAGE plpgsql AS $rk2$
BEGIN
  RETURN (
    SELECT spws_total FROM fn_ranking_full('EPEE', 'M', 'V2',
      (SELECT id_season FROM tbl_season WHERE txt_code = 'SS26-RANK-BEST'), FALSE)
     WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'RankBest')
  );
EXCEPTION WHEN undefined_function OR undefined_column THEN
  RETURN NULL;
END $rk2$;

SELECT is(pg_temp.rank02_best_n_caps(), 50.00,
  'SS26.RANK.02 a best:2 bucket sums only the top two of three scores, dropping the weakest');

CREATE FUNCTION pg_temp.rank03_always_no_cap() RETURNS NUMERIC
LANGUAGE plpgsql AS $rk3$
BEGIN
  RETURN (
    SELECT spws_total FROM fn_ranking_full('EPEE', 'M', 'V2',
      (SELECT id_season FROM tbl_season WHERE txt_code = 'SS26-RANK-ALWAYS'), FALSE)
     WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'RankAlways')
  );
EXCEPTION WHEN undefined_function OR undefined_column THEN
  RETURN NULL;
END $rk3$;

SELECT is(pg_temp.rank03_always_no_cap(), 12.00,
  'SS26.RANK.03 an always:true bucket sums every eligible score unconditionally, with no cap');

-- SS26.RANK.08/09/10 fixture -- all three sections populated for one fencer,
-- plus a second, V0-category fencer with only an spws-group result.
CREATE FUNCTION pg_temp.rank_setup_groups() RETURNS VOID
LANGUAGE plpgsql AS $rksg$
DECLARE
  v_org INT;
  v_season  INT;
  v_fencer1 INT;
  v_fencer_v0 INT;
BEGIN
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  v_season := fn_create_season('SS26-RANK-GROUPS', '2046-08-01', '2047-07-15');
  UPDATE tbl_scoring_config SET json_ranking_rules = $j$
    {"schema_version":2,
     "season_scoring_rules":{
       "spws":    {"group":"spws",     "types":["PPW"], "buckets":[{"always":true,"types":["PPW"]}]},
       "evf_fie": {"group":"evf_plus", "types":["PEW"], "buckets":[{"always":true,"types":["PEW"]}]},
       "pzsz":    {"group":"evf_plus", "types":["PPS"], "buckets":[{"always":true,"types":["PPS"]}]}
     },
     "display_groups":{"spws":{"sections":["spws"]}, "evf_plus":{"sections":["evf_fie","pzsz"]}},
     "views":{"PPW":["spws"],"RANKING":["spws","evf_plus"]}}
  $j$::jsonb WHERE id_season = v_season;

  -- 2047 - 1992 = 55 -> V2.
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality, int_birth_year, enum_gender)
  VALUES ('RankGroupsV2', 'Tester', 'PL', 1992, 'M') RETURNING id_fencer INTO v_fencer1;
  PERFORM pg_temp.rank_add_result(v_season, v_org, 'RG-PPW', 'PPW', 'EPEE', 'M', 'V2', v_fencer1, 10);
  PERFORM pg_temp.rank_add_result(v_season, v_org, 'RG-PEW', 'PEW', 'EPEE', 'M', 'V2', v_fencer1, 15);
  PERFORM pg_temp.rank_add_result(v_season, v_org, 'RG-PPS', 'PPS', 'EPEE', 'M', 'V2', v_fencer1, 8);

  -- 2047 - 2012 = 35 -> V0. Only an spws-group result; no PEW/PPS at all --
  -- V0 has no EVF equivalent, exactly as design §06 describes.
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality, int_birth_year, enum_gender)
  VALUES ('RankGroupsV0', 'Tester', 'PL', 2012, 'M') RETURNING id_fencer INTO v_fencer_v0;
  PERFORM pg_temp.rank_add_result(v_season, v_org, 'RG-V0-PPW', 'PPW', 'EPEE', 'M', 'V0', v_fencer_v0, 12);
END $rksg$;

SELECT pg_temp.rank_setup_groups();

CREATE FUNCTION pg_temp.rank08_combined_evf_plus() RETURNS NUMERIC
LANGUAGE plpgsql AS $rk8$
BEGIN
  RETURN (
    SELECT evf_plus_total FROM fn_ranking_full('EPEE', 'M', 'V2',
      (SELECT id_season FROM tbl_season WHERE txt_code = 'SS26-RANK-GROUPS'), FALSE)
     WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'RankGroupsV2')
  );
EXCEPTION WHEN undefined_function OR undefined_column THEN
  RETURN NULL;
END $rk8$;

-- evf_fie's PEW (15) and pzsz's PPS (8) combine into one evf_plus_total (23).
-- The return row has exactly rank/id_fencer/fencer_name/spws_total/
-- evf_plus_total/total_score/bool_has_carryover -- no third, per-section
-- subtotal column exists for this value to come from, by the function's own
-- fixed RETURNS TABLE signature.
SELECT is(pg_temp.rank08_combined_evf_plus(), 23.00,
  'SS26.RANK.08 evf_fie and pzsz scores combine into one evf_plus_total');

CREATE FUNCTION pg_temp.rank09_total_is_sum() RETURNS BOOLEAN
LANGUAGE plpgsql AS $rk9$
DECLARE
  v_spws NUMERIC; v_evf NUMERIC; v_total NUMERIC;
BEGIN
  SELECT spws_total, evf_plus_total, total_score
    INTO v_spws, v_evf, v_total
    FROM fn_ranking_full('EPEE', 'M', 'V2',
      (SELECT id_season FROM tbl_season WHERE txt_code = 'SS26-RANK-GROUPS'), FALSE)
   WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'RankGroupsV2');
  RETURN v_total = (v_spws + v_evf);
EXCEPTION WHEN undefined_function OR undefined_column THEN
  RETURN NULL;
END $rk9$;

SELECT is(pg_temp.rank09_total_is_sum(), TRUE,
  'SS26.RANK.09 total_score always equals spws_total plus evf_plus_total');

CREATE FUNCTION pg_temp.rank10_v0_not_shortcircuited() RETURNS TEXT
LANGUAGE plpgsql AS $rk10$
DECLARE
  v_spws NUMERIC; v_evf NUMERIC;
BEGIN
  SELECT spws_total, evf_plus_total
    INTO v_spws, v_evf
    FROM fn_ranking_full('EPEE', 'M', 'V0',
      (SELECT id_season FROM tbl_season WHERE txt_code = 'SS26-RANK-GROUPS'), FALSE)
   WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'RankGroupsV0');
  IF v_spws IS NULL THEN RETURN 'FAIL:no row -- V0 was short-circuited'; END IF;
  IF v_spws <> 12.00 THEN RETURN 'FAIL:spws_total=' || v_spws; END IF;
  IF COALESCE(v_evf, 0) <> 0 THEN RETURN 'FAIL:evf_plus_total=' || v_evf; END IF;
  RETURN 'OK';
EXCEPTION WHEN undefined_function OR undefined_column THEN
  RETURN NULL;
END $rk10$;

SELECT is(pg_temp.rank10_v0_not_shortcircuited(), 'OK',
  'SS26.RANK.10 V0 is not short-circuited: spws/pzsz can still contribute while evf_fie is naturally empty');

-- SS26.RANK.11 fixture -- a schema-v1 (legacy) season, built the way the real
-- system actually stores it: "international" DUPLICATES "domestic"'s own
-- PPW/MPW buckets verbatim alongside the genuinely-international one (verified
-- against the real stored SPWS-2024/2025-2026/2027 rows -- fn_ranking_kadra's
-- JSONB path reads "international" ALONE and splits ppw_total/pew_total
-- afterward by ARRAY['PEW','MEW','MSW','PSW'] membership, which only works
-- because "international" already contains the domestic buckets too). The
-- canonicalization adapter must therefore drop an "international" bucket
-- whose types are already wholly covered by "domestic", or evf_plus_total
-- would double-count PPW/MPW.
CREATE FUNCTION pg_temp.rank_setup_legacy() RETURNS INT
LANGUAGE plpgsql AS $rksl$
DECLARE
  v_org INT;
  v_season INT;
  v_fencer INT;
BEGIN
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  v_season := fn_create_season('SS26-RANK-LEGACY', '2048-08-01', '2049-07-15');
  UPDATE tbl_scoring_config SET json_ranking_rules = $j$
    {"domestic":[{"best":2,"types":["PPW"]},{"types":["MPW"],"always":true}],
     "international":[{"best":2,"types":["PPW"]},{"types":["MPW"],"always":true},{"best":2,"types":["PEW"]}]}
  $j$::jsonb WHERE id_season = v_season;

  -- 2049 - 1994 = 55 -> V2.
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality, int_birth_year, enum_gender)
  VALUES ('RankLegacy', 'Tester', 'PL', 1994, 'M') RETURNING id_fencer INTO v_fencer;

  PERFORM pg_temp.rank_add_result(v_season, v_org, 'RL-PPW1', 'PPW', 'EPEE', 'M', 'V2', v_fencer, 40);
  PERFORM pg_temp.rank_add_result(v_season, v_org, 'RL-PPW2', 'PPW', 'EPEE', 'M', 'V2', v_fencer, 30);
  PERFORM pg_temp.rank_add_result(v_season, v_org, 'RL-PPW3', 'PPW', 'EPEE', 'M', 'V2', v_fencer, 20);
  PERFORM pg_temp.rank_add_result(v_season, v_org, 'RL-MPW', 'MPW', 'EPEE', 'M', 'V2', v_fencer, 6);
  PERFORM pg_temp.rank_add_result(v_season, v_org, 'RL-PEW1', 'PEW', 'EPEE', 'M', 'V2', v_fencer, 25);
  PERFORM pg_temp.rank_add_result(v_season, v_org, 'RL-PEW2', 'PEW', 'EPEE', 'M', 'V2', v_fencer, 18);
  PERFORM pg_temp.rank_add_result(v_season, v_org, 'RL-PEW3', 'PEW', 'EPEE', 'M', 'V2', v_fencer, 9);

  RETURN v_season;
END $rksl$;

SELECT pg_temp.rank_setup_legacy();

CREATE FUNCTION pg_temp.rank11_legacy_parity() RETURNS TEXT
LANGUAGE plpgsql AS $rk11$
DECLARE
  v_season INT;
  v_fencer INT;
  v_full_spws NUMERIC; v_full_evf NUMERIC;
  v_ppw_total NUMERIC;
  v_kadra_pew NUMERIC;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SS26-RANK-LEGACY';
  SELECT id_fencer INTO v_fencer FROM tbl_fencer WHERE txt_surname = 'RankLegacy';

  SELECT spws_total, evf_plus_total INTO v_full_spws, v_full_evf
    FROM fn_ranking_full('EPEE', 'M', 'V2', v_season, FALSE) WHERE id_fencer = v_fencer;

  SELECT total_score INTO v_ppw_total
    FROM fn_ranking_ppw('EPEE', 'M', 'V2', v_season, FALSE) WHERE id_fencer = v_fencer;

  SELECT pew_total INTO v_kadra_pew
    FROM fn_ranking_kadra('EPEE', 'M', 'V2', v_season, FALSE) WHERE id_fencer = v_fencer;

  IF v_full_spws IS DISTINCT FROM v_ppw_total THEN
    RETURN 'FAIL:spws_total=' || v_full_spws || ' fn_ranking_ppw.total_score=' || v_ppw_total;
  END IF;
  IF v_full_evf IS DISTINCT FROM v_kadra_pew THEN
    RETURN 'FAIL:evf_plus_total=' || v_full_evf || ' fn_ranking_kadra.pew_total=' || v_kadra_pew;
  END IF;
  RETURN 'OK';
EXCEPTION WHEN undefined_function OR undefined_column THEN
  RETURN NULL;
END $rk11$;

SELECT is(pg_temp.rank11_legacy_parity(), 'OK',
  'SS26.RANK.11 legacy (schema-v1) adapter parity: fn_ranking_full matches fn_ranking_ppw/fn_ranking_kadra exactly');

-- SS26.RANK.12 fixture -- a prior season with a scored PPS result, and a
-- current (rolling) season whose pzsz section declares PPS, linked to the
-- prior event via id_prior_event (the season default carry-over engine is
-- EVENT_FK_MATCHING -- ADR-045 -- so vw_eligible_event's branch 2, not
-- event-code prefix matching, is what must be proven not to carry PPS).
-- The current event is left at its 'PLANNED' default status (NOT
-- SCORED/COMPLETED), which is exactly what marks a slot as "not yet
-- resulted" to vw_eligible_event, and carries no tournament/result of its
-- own. Design §07: "future PPS/MPS carry-over... begins disabled" -- proven
-- here as a behavior, not left to be true by accident.
CREATE FUNCTION pg_temp.rank_setup_pzsz_carry() RETURNS INT
LANGUAGE plpgsql AS $rkspc$
DECLARE
  v_org INT;
  v_prev INT;
  v_curr INT;
  v_fencer INT;
  v_prev_event INT;
BEGIN
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  v_prev := fn_create_season('SS26-RANK-CARRYPREV', '2050-08-01', '2051-07-15');
  v_curr := fn_create_season('SS26-RANK-CARRYCURR', '2051-08-01', '2052-07-15');

  UPDATE tbl_scoring_config SET json_ranking_rules = $j$
    {"schema_version":2,
     "season_scoring_rules":{"pzsz":{"group":"evf_plus","types":["PPS"],"buckets":[{"always":true,"types":["PPS"]}]}},
     "display_groups":{"evf_plus":{"sections":["pzsz"]}},
     "views":{"RANKING":["evf_plus"]}}
  $j$::jsonb WHERE id_season = v_curr;

  -- 2052 - 1997 = 55 -> V2 (category resolved against the CURRENT/carrying
  -- season's end year, per the existing rolling convention).
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality, int_birth_year, enum_gender)
  VALUES ('RankPzszCarry', 'Tester', 'PL', 1997, 'M') RETURNING id_fencer INTO v_fencer;

  v_prev_event := pg_temp.rank_add_result(v_prev, v_org, 'CARRYPOS-PREV', 'PPS', 'EPEE', 'M', 'V2', v_fencer, 20);

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, id_prior_event)
  VALUES ('CARRYPOS-CURR', 'CARRYPOS-CURR event', v_curr, v_org, v_prev_event);

  RETURN v_curr;
END $rkspc$;

SELECT pg_temp.rank_setup_pzsz_carry();

CREATE FUNCTION pg_temp.rank12_pzsz_carry_disabled() RETURNS INT
LANGUAGE plpgsql AS $rk12$
BEGIN
  RETURN (
    SELECT count(*)::INT FROM fn_ranking_full('EPEE', 'M', 'V2',
      (SELECT id_season FROM tbl_season WHERE txt_code = 'SS26-RANK-CARRYCURR'), TRUE)
     WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'RankPzszCarry')
  );
EXCEPTION WHEN undefined_function OR undefined_column THEN
  RETURN NULL;
END $rk12$;

SELECT is(pg_temp.rank12_pzsz_carry_disabled(), 0,
  'SS26.RANK.12 PPS/MPS carry-over is disabled by default, even with rolling=true and the type declared in the current section');

SELECT * FROM finish();
ROLLBACK;
