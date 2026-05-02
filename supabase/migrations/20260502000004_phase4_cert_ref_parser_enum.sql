-- =============================================================================
-- Phase 4 (ADR-050) — Add CERT_REF to enum_parser_kind
--
-- Mirrors python/pipeline/ir.py SourceKind.CERT_REF (9th source kind).
-- Cert_ref is a parser, not a special pipeline branch — when an event has
-- no live URL, operator picks `[5]` in review CLI; orchestrator queries
-- cert_ref schema, hands rows to python/scrapers/cert_ref.py::parse,
-- pipeline runs Stages 1-11 normally; engine still computes points.
--
-- Cross-language enum sync test (test_ir.py::test_source_kind_matches_postgres_enum)
-- enforces this mirror.
-- =============================================================================

BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typname = 'enum_parser_kind' AND e.enumlabel = 'CERT_REF'
  ) THEN
    ALTER TYPE enum_parser_kind ADD VALUE 'CERT_REF';
  END IF;
END$$;

COMMIT;
