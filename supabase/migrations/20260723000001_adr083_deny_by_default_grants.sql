-- =============================================================================
-- ADR-083: server-enforced authorization — deny-by-default grants
-- =============================================================================
-- This mirrors 20260327000001_revoke_write_functions.sql, which fixed this
-- exact bug class in March 2026 for two functions. The pattern was never
-- carried into the May/June work — and not because anyone forgot. Postgres was
-- re-opening the hole automatically: ALTER DEFAULT PRIVILEGES on schema public
-- grants `anon` and `authenticated` every privilege on every NEW table,
-- function and sequence. Every object added after March arrived world-writable.
--
-- Block 6 removes that generator. Blocks 1-5 close what it already produced.
--
-- Verified live against CERT and PROD on 2026-07-23
-- (doc/plans/security-case-cert-prod-2026-07-23.html):
--   * 6 public tables with RLS disabled and anon holding full DML + TRUNCATE;
--     an anon INSERT reached the not-null constraint (SQLSTATE 23502, a DATA
--     error) rather than 42501 permission denied — i.e. the write was allowed.
--   * vw_fencer_aliases is owner-rights, serving 365 fencer identities to anon
--     on PROD (ADR-078 / GDPR surface).
--   * 13 write-capable RPCs anon-EXECUTEable, 3 of them SECURITY DEFINER.
--
-- Standing guard: supabase/tests/52_security_posture.sql (52.1-52.12).
-- =============================================================================


-- =============================================================================
-- BLOCK 1 — fn_enqueue_affected_events becomes SECURITY DEFINER
-- =============================================================================
-- Must precede the REVOKEs below. This function runs from
-- trg_fencer_change_enqueue on tbl_fencer and INSERTs into tbl_recompute_queue.
--
-- Today's admin path reaches tbl_fencer only through SECURITY DEFINER RPCs
-- (fn_update_fencer_birth_year and its seven siblings), so the queue INSERT
-- already succeeds in the definer's context and nothing is broken by Block 2.
-- Making the trigger function DEFINER removes the latent trap: a future
-- authenticated-context write to tbl_fencer would otherwise fail after Block 2,
-- surfacing as a baffling permission error on an unrelated fencer edit.
--
-- Mirrors fn_audit_log, which is DEFINER on three triggers for this reason.
--
-- SET search_path is mandatory, not decorative: a SECURITY DEFINER function
-- without a pinned search_path is a privilege-escalation vector, because the
-- caller controls which schema its unqualified identifiers resolve to.
CREATE OR REPLACE FUNCTION fn_enqueue_affected_events(p_id_fencer INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    v_inserted INT;
BEGIN
    INSERT INTO tbl_recompute_queue (id_event)
    SELECT DISTINCT t.id_event
    FROM tbl_result r
    JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
    WHERE r.id_fencer = p_id_fencer
      AND t.id_event IS NOT NULL
    ON CONFLICT (id_event) WHERE enum_status = 'PENDING' DO NOTHING;
    GET DIAGNOSTICS v_inserted = ROW_COUNT;

    -- clock_timestamp() (not now()) so the debounce watermark advances even
    -- within a single transaction / test run.
    UPDATE tbl_recompute_watermark SET ts_last_master_change = clock_timestamp() WHERE id;
    RETURN v_inserted;
END;
$function$;


-- =============================================================================
-- BLOCK 2 — the six pipeline/staging tables: RLS on, all grants off
-- =============================================================================
-- No policy is created, deliberately. RLS with zero policies denies everyone
-- except roles that bypass RLS — and `service_role` bypasses it inherently,
-- which is how the entire Python pipeline reaches these tables. Verified:
-- 11 workflows pass SUPABASE_*_SERVICE_ROLE_KEY, and no file under
-- frontend/src or supabase/functions references any of the six.
--
-- lock_timeout matches the 20250301000002_rls_policies.sql convention. Every
-- statement from here to the end of the migration takes ACCESS EXCLUSIVE;
-- failing fast is strictly better than queueing behind a live recompute drain
-- and blocking every reader that arrives after us.
SET LOCAL lock_timeout = '2s';

ALTER TABLE tbl_result_draft              ENABLE ROW LEVEL SECURITY;
ALTER TABLE tbl_tournament_draft          ENABLE ROW LEVEL SECURITY;
ALTER TABLE tbl_event_ingest_history      ENABLE ROW LEVEL SECURITY;
ALTER TABLE tbl_tournament_ingest_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE tbl_recompute_queue           ENABLE ROW LEVEL SECURITY;
ALTER TABLE tbl_recompute_watermark       ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON tbl_result_draft, tbl_tournament_draft,
              tbl_event_ingest_history, tbl_tournament_ingest_history,
              tbl_recompute_queue, tbl_recompute_watermark
  FROM anon, authenticated, PUBLIC;


-- =============================================================================
-- BLOCK 3 — the remaining ten tables: anon keeps SELECT, loses every write
-- =============================================================================
-- These ten DO have RLS enabled and policies, so anon writes are already
-- refused at the row level. The GRANTS, however, were never removed — RLS was
-- the only thing standing between anon and full DML on tbl_result, tbl_fencer
-- and tbl_scoring_config. One mis-written policy, or one ALTER TABLE ...
-- DISABLE ROW LEVEL SECURITY, and the exposure is live. Defence in depth: take
-- the grant away too, so the policy is the second line rather than the only
-- one.
--
-- TRUNCATE matters most here: it is not filtered by RLS at all, so the grant
-- defeated row level security outright on all ten.
--
-- anon RETAINS SELECT. The public ranklist and calendar read tbl_season,
-- tbl_tournament, tbl_event, tbl_scoring_config, tbl_organizer and tbl_fencer
-- directly (frontend/src/lib/api.ts), and nothing here changes that.
-- `authenticated` is untouched: api.ts:279, :296 and :528 are direct
-- authenticated writes to tbl_season / tbl_event.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
    ON tbl_season, tbl_event, tbl_tournament, tbl_result, tbl_fencer,
       tbl_organizer, tbl_scoring_config, tbl_audit_log,
       tbl_match_candidate, tbl_registration
  FROM anon, PUBLIC;


-- =============================================================================
-- BLOCK 4 — vw_fencer_aliases
-- =============================================================================
-- The view is owner-rights (owner = postgres, no security_invoker reloption),
-- so RLS on the tables beneath it does nothing whatsoever — grants are the
-- only control that applies. It exposes fencer identities, making this an
-- ADR-078 (GDPR) surface as much as an authorization one.
--
-- The admin UI reads aliases through fn_list_fencer_aliases; SELECT for
-- `authenticated` preserves any direct read.
REVOKE ALL ON vw_fencer_aliases FROM anon, PUBLIC;
REVOKE ALL ON vw_fencer_aliases FROM authenticated;
GRANT SELECT ON vw_fencer_aliases TO authenticated;


-- =============================================================================
-- BLOCK 5 — the write-capable RPCs anon must not reach
-- =============================================================================
-- FROM anon, PUBLIC — both are required. The grant on these came from the
-- PUBLIC default (the bare `=X/postgres` entry in proacl), so revoking from
-- `anon` alone leaves every one of them callable.
--
-- `authenticated` and `service_role` hold their own explicit proacl entries,
-- which these statements do not touch. That is what keeps the admin UI
-- (fn_refresh_active_season, fn_set_event_source_override) and the Python
-- pipeline (everything else here) working without a single re-GRANT.
--
-- NOT revoked, deliberately:
--   fn_create_registration      — ADR-079 / FR-122. register.html is served to
--                                 anonymous visitors and this SECURITY DEFINER
--                                 RPC is the sole public write path; pgTAP
--                                 49.13/49.14 assert exactly that pairing
--                                 (direct anon INSERT denied, RPC allowed).
--   fn_match_registration_fencer— the same public form's lookup call.
--   the public ranking/calendar read functions (fn_ranking_ppw,
--                                 fn_ranking_kadra, fn_season_summary,
--                                 fn_export_scoring_config,
--                                 fn_fencer_scores_rolling and variants) —
--                                 20260327000001 documents these as deliberate.
-- The full surviving set is pinned by test 52.7 as a set EQUALITY.

-- pipeline: draft lifecycle (python/pipeline/draft_store.py, orchestrator.py)
REVOKE EXECUTE ON FUNCTION fn_commit_event_draft(UUID)         FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_discard_event_draft(UUID)        FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_dry_run_event_draft(JSONB)       FROM anon, PUBLIC;

-- pipeline: ingestion + recompute (python/pipeline/db_connector.py, promote.py)
REVOKE EXECUTE ON FUNCTION fn_find_or_create_tournament(
    INTEGER, enum_weapon_type, enum_gender_type, enum_age_category,
    DATE, enum_tournament_type, INTEGER, TEXT)                 FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_enqueue_affected_events(INTEGER) FROM anon, PUBLIC;

-- identity: destructive. fn_merge_fencers (ADR-071) deletes a fencer row and
-- re-points its results and aliases onto the survivor.
REVOKE EXECUTE ON FUNCTION fn_merge_fencers(INTEGER, INTEGER)  FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_update_fencer_aliases(INTEGER, TEXT)
                                                               FROM anon, PUBLIC;

-- admin/season state. fn_refresh_active_season is SECURITY DEFINER and UPDATEs
-- tbl_season.bool_active — it moves the whole system's active season. The
-- frontend already calls it best-effort and tolerates failure for anon
-- (api.ts / App.svelte:467), so revoking is invisible to the public site.
REVOKE EXECUTE ON FUNCTION fn_refresh_active_season()          FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_set_event_source_override(INTEGER, JSONB)
                                                               FROM anon, PUBLIC;

-- one-shot backfills and internal helpers: no caller outside migrations
REVOKE EXECUTE ON FUNCTION fn_backfill_id_prior_event()        FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_backfill_joint_pool_split()      FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION _fn_create_skeleton_children(
    INTEGER, TEXT, enum_tournament_type)                       FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION _resolve_event_prefix(TEXT)         FROM anon, PUBLIC;


-- =============================================================================
-- BLOCK 6 — kill the generator
-- =============================================================================
-- The root cause. Before this, pg_default_acl carried:
--   role postgres, schema public, TABLES    -> anon=arwdDxtm/postgres
--   role postgres, schema public, FUNCTIONS -> anon=X/postgres
--   role postgres, schema public, SEQUENCES -> anon=rwU/postgres
-- ...so every object the migration path created was granted to anon on
-- creation. All three object types are required; anon was granted on all three.
--
-- FOR ROLE postgres is what makes this bite. ALTER DEFAULT PRIVILEGES applies
-- per creating role, and without the qualifier it silently targets the
-- executing role's own defaults instead. Migrations run as postgres and all 23
-- public tables/views are owner=postgres, so postgres is the correct — and
-- sufficient — target for everything this project can create.
--
-- Residual, recorded in ADR-083: `supabase_admin` holds a second, identical
-- set of defaults on schema public. It is not reachable from the migration
-- path (nothing here creates objects as supabase_admin) and on hosted Supabase
-- the `postgres` role cannot alter another role's defaults, so it is left
-- alone rather than attempted-and-failed at deploy time.
--
-- Blast radius on existing objects: ZERO. ALTER DEFAULT PRIVILEGES affects
-- only objects created after it runs, which is why Block 6 is safe to ship in
-- the same migration as blocks 1-5.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL     ON TABLES    FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL     ON SEQUENCES FROM anon, authenticated;
