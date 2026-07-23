-- =============================================================================
-- ADR-083 (server-enforced authorization; deny-by-default grants)
--
-- Tests 52.1-52.12: the standing security posture of the public schema.
--
-- These are CATALOG assertions, not behavioural ones. The exposure they guard
-- against was not a coding mistake: ALTER DEFAULT PRIVILEGES on schema public
-- auto-granted `anon` every privilege on every new table, function and
-- sequence, so the hole opened once per object as the schema grew. A
-- behavioural test only ever covers the objects somebody remembered to write a
-- case for; a catalog assertion quantified over the whole schema also covers
-- the objects nobody thought about — which is exactly the set that produced
-- this finding.
--
-- 52.10/52.11 are the self-guard. Without them, restoring the default
-- privileges would leave every other assertion in this file passing until the
-- next table happened to be created.
-- =============================================================================

BEGIN;
SELECT plan(12);

-- ===== RLS coverage =========================================================

-- 52.1 — no table in public may have RLS disabled. `service_role` bypasses RLS
-- inherently, which is how the Python pipeline reaches the staging tables; RLS
-- with zero policies therefore denies anon/authenticated and nobody else.
SELECT is_empty(
  $$SELECT c.relname::TEXT
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public'
       AND c.relkind = 'r'
       AND NOT c.relrowsecurity$$,
  '52.1: every table in schema public has row level security enabled'
);

-- 52.2 — the six pipeline/staging tables specifically. Named explicitly so a
-- regression that drops RLS from one of these fails by name, not as a count.
SELECT is(
  (SELECT count(*)::INT
     FROM pg_class c
     JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind = 'r'
      AND c.relrowsecurity
      AND c.relname IN ('tbl_result_draft',
                        'tbl_tournament_draft',
                        'tbl_event_ingest_history',
                        'tbl_tournament_ingest_history',
                        'tbl_recompute_queue',
                        'tbl_recompute_watermark')),
  6,
  '52.2: all six pipeline/staging tables have RLS enabled'
);

-- ===== anon holds no write privilege on any table ===========================
-- has_table_privilege (rather than parsing relacl) is deliberate: it resolves
-- the PUBLIC pseudo-role grant, which is where several of these actually came
-- from and which a text scan of relacl would miss.

-- 52.3
SELECT is_empty(
  $$SELECT c.relname::TEXT
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public'
       AND c.relkind = 'r'
       AND has_table_privilege('anon', c.oid, 'INSERT')$$,
  '52.3: anon holds INSERT on no table in schema public'
);

-- 52.4
SELECT is_empty(
  $$SELECT c.relname::TEXT
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public'
       AND c.relkind = 'r'
       AND has_table_privilege('anon', c.oid, 'UPDATE')$$,
  '52.4: anon holds UPDATE on no table in schema public'
);

-- 52.5
SELECT is_empty(
  $$SELECT c.relname::TEXT
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public'
       AND c.relkind = 'r'
       AND has_table_privilege('anon', c.oid, 'DELETE')$$,
  '52.5: anon holds DELETE on no table in schema public'
);

-- 52.6 — TRUNCATE is called out separately because it is not covered by RLS at
-- all: a TRUNCATE grant defeats row level security entirely.
SELECT is_empty(
  $$SELECT c.relname::TEXT
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public'
       AND c.relkind = 'r'
       AND has_table_privilege('anon', c.oid, 'TRUNCATE')$$,
  '52.6: anon holds TRUNCATE on no table in schema public'
);

-- ===== the anon-executable allowlist ========================================
-- 52.7 asserts set EQUALITY, not absence of known-bad names. A deny-list would
-- have caught none of the ADR-083 findings, because every offending function
-- was created after such a list would have been written.
--
-- Scope: directly-callable functions only. Trigger functions (prorettype =
-- trigger) are excluded because Postgres refuses to call them outside a
-- trigger context, so a grant on one is not reachable surface. Extension-owned
-- functions (btree_gist ships ~200 into public) are excluded because their
-- grants are managed by the extension, not by this project.
--
-- Everything on this list is either an intentionally-public read path for the
-- ranklist/calendar, or part of the ADR-079 public self-registration flow.
SELECT set_eq(
  $$SELECT p.proname::TEXT
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.prokind = 'f'
       AND p.prorettype <> 'trigger'::regtype
       AND NOT EXISTS (SELECT 1 FROM pg_depend d
                        WHERE d.objid = p.oid AND d.deptype = 'e')
       AND has_function_privilege('anon', p.oid, 'EXECUTE')$$,
  ARRAY[
    -- public ranking + calendar read surface (20260327000001 documents these
    -- as deliberately anon-callable; the public ranklist depends on them)
    'fn_age_category',
    'fn_compare_carryover_engines',
    'fn_copy_prior_scoring_config',
    'fn_effective_gender',
    'fn_event_position',
    'fn_export_scoring_config',
    'fn_fencer_scores_rolling',
    'fn_fencer_scores_rolling_event_code_matching',
    'fn_fencer_scores_rolling_event_fk_matching',
    'fn_ranking_kadra',
    'fn_ranking_kadra_event_code_matching',
    'fn_ranking_kadra_event_fk_matching',
    'fn_ranking_ppw',
    'fn_ranking_ppw_event_code_matching',
    'fn_ranking_ppw_event_fk_matching',
    'fn_season_summary',
    'fn_vcat_violation_msg',
    -- ADR-079 / FR-122 public self-registration: register.html is served to
    -- anonymous visitors and these two are its entire server surface.
    -- fn_create_registration is SECURITY DEFINER precisely so that anon can
    -- write a registration without holding INSERT on tbl_registration
    -- (asserted from the other side by 49.13/49.14).
    'fn_create_registration',
    'fn_match_registration_fencer'
  ],
  '52.7: the anon-EXECUTEable function set equals the documented allowlist'
);

-- ===== vw_fencer_aliases ====================================================
-- The view is owner-rights (owner=postgres, no security_invoker reloption), so
-- RLS on the tables beneath it does nothing at all — grants are the only
-- control. It exposes fencer identities, which makes this an ADR-078 (GDPR)
-- surface as well as an authorization one.

-- 52.8
SELECT is_empty(
  $$SELECT p.priv
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     CROSS JOIN LATERAL (VALUES ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'),
                                ('TRUNCATE'), ('REFERENCES'), ('TRIGGER')) AS p(priv)
     WHERE n.nspname = 'public'
       AND c.relname = 'vw_fencer_aliases'
       AND has_table_privilege('anon', c.oid, p.priv)$$,
  '52.8: vw_fencer_aliases grants nothing to anon'
);

-- 52.9
SELECT set_eq(
  $$SELECT p.priv
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     CROSS JOIN LATERAL (VALUES ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'),
                                ('TRUNCATE'), ('REFERENCES'), ('TRIGGER')) AS p(priv)
     WHERE n.nspname = 'public'
       AND c.relname = 'vw_fencer_aliases'
       AND has_table_privilege('authenticated', c.oid, p.priv)$$,
  ARRAY['SELECT'],
  '52.9: vw_fencer_aliases grants only SELECT to authenticated'
);

-- ===== the self-guard: default privileges ===================================
-- Root cause of ADR-083. aclexplode is used rather than a LIKE over the acl
-- text so the grantee is matched exactly and not by substring.

-- 52.10
SELECT is_empty(
  $$SELECT a.privilege_type
      FROM pg_default_acl d
      JOIN pg_namespace n ON n.oid = d.defaclnamespace
     CROSS JOIN LATERAL aclexplode(d.defaclacl) a
     WHERE n.nspname = 'public'
       AND pg_get_userbyid(d.defaclrole) = 'postgres'
       AND pg_get_userbyid(a.grantee) = 'anon'$$,
  '52.10: role postgres grants no default privileges to anon in schema public'
);

-- 52.11
SELECT is_empty(
  $$SELECT a.privilege_type
      FROM pg_default_acl d
      JOIN pg_namespace n ON n.oid = d.defaclnamespace
     CROSS JOIN LATERAL aclexplode(d.defaclacl) a
     WHERE n.nspname = 'public'
       AND pg_get_userbyid(d.defaclrole) = 'postgres'
       AND pg_get_userbyid(a.grantee) = 'authenticated'$$,
  '52.11: role postgres grants no default privileges to authenticated in schema public'
);

-- ===== trigger reachability =================================================
-- 52.12 — trg_fencer_change_enqueue fires fn_enqueue_affected_events on
-- tbl_fencer and INSERTs into tbl_recompute_queue. Once 52.3 holds, an
-- INVOKER function on that trigger would fail for any authenticated-context
-- write to tbl_fencer. The eight admin fencer RPCs are all SECURITY DEFINER so
-- today's path is safe either way, but making this one DEFINER removes the
-- latent trap. Mirrors fn_audit_log, DEFINER on three triggers for the same
-- reason.
SELECT ok(
  (SELECT p.prosecdef
     FROM pg_proc p
     JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'fn_enqueue_affected_events'),
  '52.12: fn_enqueue_affected_events is SECURITY DEFINER'
);

SELECT * FROM finish();
ROLLBACK;
