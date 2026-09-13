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
    -- anonymous visitors and these three are its entire server surface.
    -- fn_create_registration is SECURITY DEFINER precisely so that anon can
    -- write a registration without holding INSERT on tbl_registration
    -- (asserted from the other side by 49.13/49.14).
    'fn_create_registration',
    -- fn_update_registration (2026-08-28) is the EDIT half of the same
    -- surface, and is deliberately anon-callable for the same reason. It is
    -- not an unguarded write: every call must present the row's
    -- uuid_edit_token, which the client generated and which no public
    -- projection returns. id_registration alone cannot authorise it — that
    -- column IS published by vw_registration_entry_list.
    'fn_update_registration',
    'fn_match_registration_fencer',
    -- The identity block (2026-09-12). fn_registration_identity_candidates is
    -- a read of tbl_fencer, which anon can already SELECT directly under the
    -- "Public read fencers" policy — it exposes no column the fencer table
    -- does not already publish, and it is STABLE with no SECURITY DEFINER.
    'fn_registration_identity_candidates',
    -- fn_confirm_registration_identity is the one genuinely new capability on
    -- this surface: it is SECURITY DEFINER and it can write tbl_fencer, which
    -- deliberately reverses ADR-079's read-only-birth-year invariant. It is
    -- anon-callable because the fencer correcting their own entry IS the
    -- anonymous visitor. It is not an unguarded write — the caller must
    -- present the row's uuid_edit_token (as fn_update_registration does), and
    -- the fencer named must fall inside a candidate set the function
    -- recomputes server-side from that registration's own declared name, so
    -- the reachable set is the handful of people sharing the registrant's
    -- name rather than all of tbl_fencer. A confirmed birth year is never
    -- overwritten without an explicit human answer, and trg_audit_fencer
    -- records every such write. Asserted from the other side by 75.10.
    'fn_confirm_registration_identity',
    -- The FTL export page (2026-09-12) is public, so its data source is
    -- anon-callable. fn_ftl_export_entries is SECURITY DEFINER — it has to be,
    -- because tbl_registration's RLS admits only `authenticated` — but what it
    -- publishes is strictly the columns vw_registration_entry_list already
    -- serves anonymously (name, gender, weapon, age category) plus one integer:
    -- the fencer's resolved position inside their own sub-ranking, which is a
    -- projection of fn_ranking_ppw, itself already on this list. It returns no
    -- birth year, no id_fencer, no id_registration, no uuid_edit_token and no
    -- e-mail hash — asserted from the function signature by 76.4 — and it is
    -- STABLE, so it can read nothing into existence and write nothing.
    -- fn_ftl_export_use_rolling is deliberately absent: it is composed into
    -- this one and is not part of the public surface (76.6).
    'fn_ftl_export_entries',
    -- fn_ftl_export_events is the same surface's event picker: code, name, city,
    -- date and entry count for every event with entries whose end date has not
    -- passed. Every one of those facts is already public through vw_calendar and
    -- vw_registration_entry_list. Both functions are gated on a capability token
    -- (tbl_ftl_export_token) checked inside them — the page is public and its
    -- bundle is readable, so a check in the client would be decoration. An
    -- absent, unknown or revoked token returns no rows rather than raising
    -- (76.21-76.24). fn_ftl_export_token_valid is deliberately absent from this
    -- list: it is composed into these two and is not itself callable from a
    -- browser (76.29).
    'fn_ftl_export_events',
    -- fn_ftl_roster is the third function of the same surface: the organizer's
    -- pick-list, so a fencer who turns up unannounced is ticked in rather than
    -- typed (typing is what creates a duplicate identity — ADR-065's amendment
    -- records fencer #330). It publishes name, gender, weapon and age category
    -- for fencers who already have a public result in that weapon, which is
    -- strictly less than the ranklist shows about the same people, and no birth
    -- year or fencer id (77.2). Same capability token, same silent refusal.
    'fn_ftl_roster'
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
