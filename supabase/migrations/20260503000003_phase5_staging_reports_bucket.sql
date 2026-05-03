-- =============================================================================
-- Phase 5.5 — staging-reports Storage bucket for verdict .md files (ADR-058)
-- =============================================================================
-- Persists per-event verdict markdown to Supabase Storage so CERT/PROD
-- operators can read them via Telegram (ADR-059) without local repo access.
--
-- Path scheme:
--   staging-reports/{event_code}/full.md             — replace-on-regen
--   staging-reports/{event_code}/deltas/{ts}.md      — append-only EVF deltas
--
-- RLS:
--   * service_role bypasses RLS (CI workflows + edge functions write here)
--   * authenticated reads are allowed (admin auth handled at app layer)
--   * anon has no access
--   * No INSERT/UPDATE/DELETE for authenticated — writes are service_role only
--
-- LOCAL note: storage is disabled in supabase/config.toml on LOCAL.
-- The storage schema does not exist on LOCAL; this migration is a no-op there
-- (guarded by a DO block that uses EXECUTE for dynamic SQL so PL/pgSQL parsing
-- doesn't fail on missing storage.buckets / storage.objects). LOCAL operators
-- continue using --md-target=local (filesystem) — no behavioural change.
-- ADR-061 — LOCAL operator workflow preserved verbatim.
-- =============================================================================

BEGIN;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
     WHERE table_schema = 'storage' AND table_name = 'buckets'
  ) THEN
    -- 1. Bucket — EXECUTE keeps PL/pgSQL parser from binding storage.buckets at function creation
    EXECUTE $sql$
      INSERT INTO storage.buckets (id, name, public)
      VALUES ('staging-reports', 'staging-reports', false)
      ON CONFLICT (id) DO NOTHING
    $sql$;

    -- 2. RLS policy — authenticated SELECT only (no insert/update/delete)
    EXECUTE $sql$
      DROP POLICY IF EXISTS "staging_reports_authenticated_read" ON storage.objects
    $sql$;

    EXECUTE $sql$
      CREATE POLICY "staging_reports_authenticated_read" ON storage.objects
        FOR SELECT
        TO authenticated
        USING (bucket_id = 'staging-reports')
    $sql$;

    -- COMMENT ON POLICY ... ON storage.objects requires ownership of
    -- storage.objects, which the Supabase Management API role lacks
    -- (CERT deploy fails with 42501 must be owner of relation objects).
    -- The policy itself is the source of truth; rationale lives in
    -- this migration's header + ADR-058. Skipping the COMMENT.
  ELSE
    RAISE NOTICE 'Phase 5.5 (ADR-058+061): storage schema not present (LOCAL); '
                 'staging-reports bucket migration is a no-op. CERT/PROD will '
                 'apply it via the dashboard or `supabase db push`.';
  END IF;
END
$$;

COMMIT;
