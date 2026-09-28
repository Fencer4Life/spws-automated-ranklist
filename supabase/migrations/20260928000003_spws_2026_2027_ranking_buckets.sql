-- =============================================================================
-- SPWS-2026-2027 ranking buckets
-- =============================================================================
-- Plan: doc/plans/admin-ui-ranking-buckets-and-skeletons-2026-09-28.html,
-- Part 1. The user's choice of 28 Sep 2026:
--   * PPW ranking  = the best 2 PPW results + every MPW result;
--   * full ranking = those + the best 5 of PEW, MEW, MSW, PSW, PPS, MPS (EVF+);
--   * no result counts twice: each type sits in exactly one bucket, and PPW
--     results beyond the best 2 count in neither total.
--
-- Before this migration CERT carried PPW best 4 (+ ignored international
-- PPW/MPW copies, PEW/MEW/MSW best 3) and PROD carried PPW best 3 (+ an ignored
-- international "PPW best 1" and "MPW best 0", PEW/MEW/MSW best 4); both
-- unlocked with 0 scored results on 28 Sep 2026. entry_types is unchanged.
--
-- Written through fn_import_scoring_config, the admin contract, so the
-- ADR-097 lock and the ADM27 validation (20260928000002) both apply. Once a
-- 2026/2027 result is scored the lock refuses the change and this migration
-- fails the deploy loudly: the rules must then go through the privileged
-- fn_revise_and_rescore_season instead. Re-running it is a no-op.
--
-- On a fresh bootstrap (CI, LOCAL reset) the migrations run before the seed
-- creates the season, so this is a no-op there and seed_post_backfill.sql
-- applies the same rules after the seed (pinned by ADM27.RULES.14).
-- =============================================================================

DO $$
DECLARE
  c_rules CONSTANT JSONB := $j$
    {"domestic": [{"types": ["PPW"], "best": 2}, {"types": ["MPW"], "always": true}],
     "international": [{"types": ["PEW", "MEW", "MSW", "PSW", "PPS", "MPS"], "best": 5}],
     "entry_types": ["PPW", "MPW"]}
  $j$;
  v_season INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027';
  IF v_season IS NULL THEN
    RETURN;
  END IF;

  PERFORM fn_import_scoring_config(jsonb_build_object('id_season', v_season, 'ranking_rules', c_rules));
END;
$$;
