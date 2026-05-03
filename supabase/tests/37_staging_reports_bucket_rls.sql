-- =============================================================================
-- pgTAP — Phase 5.5: staging-reports Storage bucket exists with correct RLS
-- =============================================================================
-- Plan-test-ID 5.12 (per /Users/aleks/.claude/plans/tingly-strolling-stearns.md)
-- Verifies migration 20260503000003_phase5_staging_reports_bucket.sql.
--
-- LOCAL behaviour: storage.buckets is absent on LOCAL (config.toml disables
-- storage). All 5 emit `ok # SKIP` lines on LOCAL, real assertions on
-- CERT/PROD. ADR-061 — LOCAL operator workflow preserved verbatim.
-- =============================================================================

BEGIN;

SELECT plan(5);

-- Build a function that returns 5 TAP-shaped rows. EXECUTE keeps the
-- planner from binding storage.buckets / pg_policies(storage,objects)
-- statically — required because LOCAL doesn't have those tables.
CREATE OR REPLACE FUNCTION pg_temp._spws_test_5_12() RETURNS SETOF TEXT
LANGUAGE plpgsql AS $fn$
DECLARE
  v_present BOOLEAN := (to_regclass('storage.buckets') IS NOT NULL);
  v_bool    BOOLEAN;
BEGIN
  -- 5.12.1 — bucket exists
  IF NOT v_present THEN
    RETURN NEXT skip('5.12.1 LOCAL: storage disabled (ADR-061)', 1);
  ELSE
    EXECUTE 'SELECT EXISTS(SELECT 1 FROM storage.buckets WHERE id = ''staging-reports'')' INTO v_bool;
    RETURN NEXT ok(v_bool, '5.12.1 — staging-reports bucket exists');
  END IF;

  -- 5.12.2 — bucket is private
  IF NOT v_present THEN
    RETURN NEXT skip('5.12.2 LOCAL: storage disabled (ADR-061)', 1);
  ELSE
    EXECUTE 'SELECT public FROM storage.buckets WHERE id = ''staging-reports''' INTO v_bool;
    RETURN NEXT is(v_bool, false, '5.12.2 — staging-reports bucket is private (public=false)');
  END IF;

  -- 5.12.3 — authenticated SELECT policy exists
  IF NOT v_present THEN
    RETURN NEXT skip('5.12.3 LOCAL: storage disabled (ADR-061)', 1);
  ELSE
    EXECUTE $q$
      SELECT EXISTS (
        SELECT 1 FROM pg_policies
         WHERE schemaname='storage' AND tablename='objects'
           AND policyname='staging_reports_authenticated_read'
           AND cmd='SELECT'
      )
    $q$ INTO v_bool;
    RETURN NEXT ok(v_bool, '5.12.3 — RLS policy staging_reports_authenticated_read exists for SELECT');
  END IF;

  -- 5.12.4 — no authenticated INSERT policy
  IF NOT v_present THEN
    RETURN NEXT skip('5.12.4 LOCAL: storage disabled (ADR-061)', 1);
  ELSE
    EXECUTE $q$
      SELECT EXISTS (
        SELECT 1 FROM pg_policies
         WHERE schemaname='storage' AND tablename='objects'
           AND policyname LIKE 'staging_reports%'
           AND cmd='INSERT'
           AND 'authenticated' = ANY(roles)
      )
    $q$ INTO v_bool;
    RETURN NEXT ok(NOT v_bool, '5.12.4 — no authenticated INSERT policy (service_role only)');
  END IF;

  -- 5.12.5 — no authenticated DELETE policy
  IF NOT v_present THEN
    RETURN NEXT skip('5.12.5 LOCAL: storage disabled (ADR-061)', 1);
  ELSE
    EXECUTE $q$
      SELECT EXISTS (
        SELECT 1 FROM pg_policies
         WHERE schemaname='storage' AND tablename='objects'
           AND policyname LIKE 'staging_reports%'
           AND cmd='DELETE'
           AND 'authenticated' = ANY(roles)
      )
    $q$ INTO v_bool;
    RETURN NEXT ok(NOT v_bool, '5.12.5 — no authenticated DELETE policy (service_role only)');
  END IF;
END
$fn$;

SELECT pg_temp._spws_test_5_12();

SELECT * FROM finish();

ROLLBACK;
