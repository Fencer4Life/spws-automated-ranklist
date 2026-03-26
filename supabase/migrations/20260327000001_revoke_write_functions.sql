-- =============================================================================
-- T9.0: Revoke write functions from anon/PUBLIC, grant to authenticated
-- =============================================================================
-- ADR-016: Supabase Auth + TOTP MFA for Admin Access
-- Security fix: all SECURITY DEFINER write functions were callable by anon
-- because PostgreSQL defaults GRANT EXECUTE TO PUBLIC.
--
-- Write functions: fn_import_scoring_config, fn_calc_tournament_scores
-- Read-only functions stay anon-accessible: fn_export_scoring_config,
--   fn_ranking_ppw, fn_ranking_kadra, fn_age_category
-- Trigger functions: no change needed (invoked by trigger, not direct call)
-- =============================================================================

-- Revoke from anon and PUBLIC
REVOKE EXECUTE ON FUNCTION fn_import_scoring_config(JSONB) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_calc_tournament_scores(INT) FROM anon, PUBLIC;

-- Grant only to authenticated role
GRANT EXECUTE ON FUNCTION fn_import_scoring_config(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION fn_calc_tournament_scores(INT) TO authenticated;
