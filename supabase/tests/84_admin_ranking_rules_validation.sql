-- =============================================================================
-- ADM27 — ranking buckets are validated when an admin writes them
-- =============================================================================
-- Acceptance IDs for doc/plans/admin-ui-ranking-buckets-and-skeletons-2026-09-28
-- .html (Part 2 · A and D).
--
-- WHY
-- -----------------------------------------------------------------------------
-- fn_import_scoring_config stored any ranking_rules it was given. A bucket the
-- two-pool adapter cannot use was dropped without a word when the ranking was
-- read: PROD's SPWS-2026-2027 carried an international "PPW best 1" and
-- "MPW best 0" that no ranking ever used. A type in two buckets would count
-- one score twice. The write now refuses both, but only when the incoming
-- rules differ from the stored rules: 2024/25 and 2025/26 repeat their domestic
-- buckets in the international pool by design (the adapter drops the copies),
-- and every Admin save re-sends the whole configuration, so an unconditional
-- check would make those seasons unsavable.
--
-- RED-SAFE WRAPPER
-- -----------------------------------------------------------------------------
-- pg_temp.try_import returns 'ok' or the error text, so a missing validator
-- produces named failures instead of aborting the file. Everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(11);

CREATE TEMP TABLE adm27_season AS
SELECT fn_create_season('ADM27-RULES', '2052-08-01', '2053-07-15') AS id_season;

CREATE FUNCTION pg_temp.try_import(p_rules JSONB) RETURNS TEXT
LANGUAGE plpgsql AS $ti$
BEGIN
  PERFORM fn_import_scoring_config(jsonb_build_object(
    'id_season', (SELECT id_season FROM adm27_season),
    'ranking_rules', p_rules));
  RETURN 'ok';
EXCEPTION WHEN OTHERS THEN
  RETURN SQLERRM;
END $ti$;

-- -----------------------------------------------------------------------------
-- A domestic type in the international pool: the bucket PROD carried, which
-- the adapter drops when the ranking is read.
-- -----------------------------------------------------------------------------
SELECT matches(
  pg_temp.try_import($j$
    {"domestic":[{"types":["PPW"],"best":2},{"types":["MPW"],"always":true}],
     "international":[{"types":["PPW"],"best":1}]}
  $j$::jsonb),
  'PPW is not allowed in the international pool',
  'ADM27.RULES.01 an international bucket of only PPW is refused');

-- A mixed bucket would keep PPW and so count a PPW score in both pools.
SELECT matches(
  pg_temp.try_import($j$
    {"domestic":[{"types":["MPW"],"always":true}],
     "international":[{"types":["PPW","PEW"],"best":3}]}
  $j$::jsonb),
  'PPW is not allowed in the international pool',
  'ADM27.RULES.02 a mixed PPW + PEW international bucket is refused');

SELECT matches(
  pg_temp.try_import($j$
    {"domestic":[{"types":["PPW"],"best":2},{"types":["MPW"],"best":0}],
     "international":[]}
  $j$::jsonb),
  'best 0',
  'ADM27.RULES.03 MPW best 0 is refused');

SELECT matches(
  pg_temp.try_import($j$
    {"domestic":[{"types":["PPW"],"best":2,"always":true}],
     "international":[]}
  $j$::jsonb),
  'exactly one of best or always',
  'ADM27.RULES.04 a bucket with both best and always is refused');

SELECT matches(
  pg_temp.try_import($j$
    {"domestic":[{"types":["PPW"],"best":2},{"types":["PPW","MPW"],"always":true}],
     "international":[]}
  $j$::jsonb),
  'PPW appears in more than one bucket',
  'ADM27.RULES.05 a type in two buckets is refused');

SELECT matches(
  pg_temp.try_import($j$
    {"domestic":[{"types":["PEW"],"best":2}],
     "international":[]}
  $j$::jsonb),
  'PEW is not allowed in the domestic pool',
  'ADM27.RULES.06 PEW in the domestic pool is refused');

-- The 2026/27 rules the user chose on 28 Sep 2026 (Part 1 of the plan).
SELECT is(
  pg_temp.try_import($j$
    {"domestic":[{"types":["PPW"],"best":2},{"types":["MPW"],"always":true}],
     "international":[{"types":["PEW","MEW","MSW","PSW","PPS","MPS"],"best":5}],
     "entry_types":["PPW","MPW"]}
  $j$::jsonb),
  'ok',
  'ADM27.RULES.07 the 2026/27 target rules are accepted');

-- A 2025/26-style season re-saved unchanged, as every Admin save does. The
-- stored rules are written directly, as the season holds them today.
UPDATE tbl_scoring_config SET json_ranking_rules = $j$
  {"domestic":[{"types":["PPW"],"best":4},{"types":["MPW"],"always":true}],
   "international":[{"types":["PPW"],"best":4},{"types":["MPW"],"always":true},{"types":["PEW","MEW","MSW"],"best":3}]}
$j$::jsonb
 WHERE id_season = (SELECT id_season FROM adm27_season);

SELECT is(
  pg_temp.try_import($j$
    {"domestic":[{"types":["PPW"],"best":4},{"types":["MPW"],"always":true}],
     "international":[{"types":["PPW"],"best":4},{"types":["MPW"],"always":true},{"types":["PEW","MEW","MSW"],"best":3}]}
  $j$::jsonb),
  'ok',
  'ADM27.RULES.08 unchanged legacy-shaped rules are re-saved without complaint');

SELECT ok(
  CASE WHEN to_regprocedure('fn_validate_ranking_rules_write(jsonb)') IS NULL THEN FALSE
       ELSE NOT has_function_privilege('anon', 'fn_validate_ranking_rules_write(jsonb)', 'EXECUTE')
        AND NOT has_function_privilege('authenticated', 'fn_validate_ranking_rules_write(jsonb)', 'EXECUTE')
  END,
  'ADM27.RULES.09 the validator exists and neither anon nor authenticated can execute it');

-- -----------------------------------------------------------------------------
-- Part 1: SPWS-2026-2027 carries the rules chosen on 28 Sep 2026. Migration
-- 20260928000003 sets them on CERT and PROD; on a fresh LOCAL/CI rebuild the
-- migration runs before the seed creates the season, so seed_post_backfill.sql
-- applies the same rules after the seed. This pins that LOCAL result. Since
-- 2026-10-04 (ADR-110, the audited revision on CERT and PROD) the rules carry
-- no entry_types: everyone in the fencer table with points in the window is
-- ranked.
-- -----------------------------------------------------------------------------
SELECT is(
  (SELECT sc.json_ranking_rules FROM tbl_scoring_config sc
     JOIN tbl_season s ON s.id_season = sc.id_season
    WHERE s.txt_code = 'SPWS-2026-2027'),
  $j$
    {"domestic":[{"types":["PPW"],"best":2},{"types":["MPW"],"always":true}],
     "international":[{"types":["PEW","MEW","MSW","PSW","PPS","MPS"],"best":5}]}
  $j$::jsonb,
  'ADM27.RULES.14 SPWS-2026-2027 carries best 2 PPW + MPW and the best 5 of the six international and PZSz types');

-- -----------------------------------------------------------------------------
-- Part 2 · D: the stub-tournament helper retained as a fixture on 27 Jun is gone.
-- -----------------------------------------------------------------------------
SELECT ok(
  to_regprocedure('_fn_create_skeleton_children(integer,text,enum_tournament_type)') IS NULL,
  'ADM27.SKEL.04 _fn_create_skeleton_children no longer exists');

SELECT * FROM finish();

ROLLBACK;
