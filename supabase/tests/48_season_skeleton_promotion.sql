-- =============================================================================
-- ADR-077 §5/§7 — CERT→PROD season-skeleton promotion RPCs
-- =============================================================================
-- fn_promote_season_skeleton(JSONB) / fn_delete_season_skeleton(INT)
-- Migration 20260628000002, slimmed by 20260711000001 (reconciler ADR
-- pending sign-off): event promotion moved to fn_mirror_events_to_prod
-- (see 51_prod_event_reconcile.sql). This RPC now promotes season row +
-- scoring_config ONLY — 48.2/48.4 (event-copy + id_prior_event resolution)
-- retired; id_prior_event-by-code resolution coverage migrated to
-- 51_prod_event_reconcile.sql. Guards: not-active, idempotency.
-- =============================================================================

BEGIN;
SELECT plan(8);

-- Build a realistic promotion payload for a far-future season SPWS-2099-2100
-- with explicit ids beyond the current max, a real scoring_config (re-keyed),
-- and an event whose id_prior_event is target-resolved to the live MPW event.
CREATE TEMP TABLE _payload AS
SELECT jsonb_build_object(
  'source_childless', TRUE,
  'season', jsonb_build_object(
    'id_season', 9990,
    'txt_code', 'SPWS-2099-2100',
    'dt_start', '2099-08-01',
    'dt_end', '2100-07-15',
    'bool_active', FALSE,
    'enum_carryover_engine', 'EVENT_FK_MATCHING',
    'int_carryover_days', 366,
    'enum_european_event_type', 'IMEW'
  ),
  'scoring_config', (
    SELECT to_jsonb(sc) - 'id_season' || jsonb_build_object('id_season', 9990)
      FROM tbl_scoring_config sc WHERE id_season = 3
  ),
  'events', jsonb_build_array(
    jsonb_build_object(
      'id_event', 99001, 'id_season', 9990,
      'id_organizer', (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
      'txt_code', 'PPW1-2099-2100', 'txt_name', 'PPW1',
      'enum_status', 'CREATED', 'txt_source_status', 'ENGINE_COMPUTED'
    ),
    jsonb_build_object(
      'id_event', 99002, 'id_season', 9990,
      'id_organizer', (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
      'txt_code', 'MPW-2099-2100', 'txt_name', 'MPW',
      'enum_status', 'CREATED', 'txt_source_status', 'ENGINE_COMPUTED',
      'id_prior_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'MPW-2025-2026')
    )
  )
) AS p;

SAVEPOINT s_promote;

SELECT fn_promote_season_skeleton((SELECT p FROM _payload));

-- 48.1 — season inserted with the EXPLICIT id
SELECT is(
  (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2099-2100'),
  9990,
  '48.1: fn_promote_season_skeleton inserts the season with its explicit id'
);

-- 48.2 — the payload's events array is ignored: no tbl_event rows are
-- created by the season-skeleton RPC (event C/U/D is now owned entirely
-- by fn_mirror_events_to_prod — regression guard against re-introducing
-- event promotion here)
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event WHERE id_event IN (99001, 99002) AND id_season = 9990),
  0,
  '48.2: fn_promote_season_skeleton ignores the events array — no event rows created'
);

-- 48.3 — scoring_config replaced with the promoted values (not the trigger default)
SELECT is(
  (SELECT int_ppw_best_count FROM tbl_scoring_config WHERE id_season = 9990),
  (SELECT int_ppw_best_count FROM tbl_scoring_config WHERE id_season = 3),
  '48.3: scoring_config carries the promoted values'
);

-- 48.5 — idempotency: re-promoting the same season is refused
SELECT throws_ok(
  $$SELECT fn_promote_season_skeleton((SELECT p FROM _payload))$$,
  NULL, NULL,
  '48.5: fn_promote_season_skeleton refuses a season that already exists on target'
);

ROLLBACK TO SAVEPOINT s_promote;

-- 48.6 — childless guard: source_childless=false is refused
SELECT throws_ok(
  $$SELECT fn_promote_season_skeleton(
      (SELECT p FROM _payload) || jsonb_build_object('source_childless', FALSE))$$,
  NULL, NULL,
  '48.6: fn_promote_season_skeleton refuses a non-childless source season'
);

-- 48.7 — delete removes a childless, non-active promoted season
SAVEPOINT s_delete;
SELECT fn_promote_season_skeleton((SELECT p FROM _payload));
SELECT fn_delete_season_skeleton(9990);
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_season WHERE id_season = 9990),
  0,
  '48.7: fn_delete_season_skeleton removes a childless non-active season'
);
ROLLBACK TO SAVEPOINT s_delete;

-- 48.8 — not-active guard: refuses the active season (id 3)
SELECT throws_ok(
  $$SELECT fn_delete_season_skeleton(3)$$,
  NULL, NULL,
  '48.8: fn_delete_season_skeleton refuses the active season'
);

-- 48.9 — childless guard: refuses a season whose events have tournament children (season 1)
SELECT throws_ok(
  $$SELECT fn_delete_season_skeleton(1)$$,
  NULL, NULL,
  '48.9: fn_delete_season_skeleton refuses a season with tournament children'
);

SELECT * FROM finish();
ROLLBACK;
