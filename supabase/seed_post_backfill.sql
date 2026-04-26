-- =============================================================================
-- Post-seed: Phase 1B FK backfill
-- =============================================================================
-- Runs after seed_prod_latest.sql via config.toml [db.seed].sql_paths order.
-- In PROD/CERT, run this manually once via SQL editor after Phase 1B deploys.
-- Idempotent: safe to run multiple times.
-- =============================================================================

SELECT fn_backfill_id_prior_event();
