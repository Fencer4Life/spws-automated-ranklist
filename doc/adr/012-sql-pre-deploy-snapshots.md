# ADR-012: SQL-Level Pre-Deploy Snapshots for PROD

**Status:** Deferred
**Date:** 2026-03-23 (M7)

## Context

The three-tier release pipeline (ADR-011) uses forward-only rollback — corrective
migrations pushed through the pipeline. This covers schema issues but not data
corruption caused by migrations (DELETE, UPDATE with wrong values, etc.). A mechanism
was designed to restore PROD data to its pre-migration state.

Key constraint: the Supabase Management API only supports running SQL queries — no
pg_dump, no PITR, no filesystem access.

## Decision

**Deferred.** After thorough design and analysis, the snapshot mechanism was deemed
too complex relative to its practical value:

- Most migrations in this project change the schema (new functions, views, columns),
  which blocks rollback entirely via the fingerprint gate
- The mechanism is primarily valuable for data-only migrations, which are rare
  outside the ingestion pipeline (M7)
- Forward-only corrective migrations (ADR-011) remain sufficient for the POC phase

The full technical design is preserved below for future implementation if data-only
migrations become common.

### Deferred design summary

Automated SQL-level snapshots in a `_backup` schema before each PROD migration deploy.
Snapshots are data-only (no schema state). Restorability gated by schema fingerprint:

- **Data-only migration** (fingerprint unchanged): snapshot marked restorable
- **Schema-changing migration** (fingerprint changed): snapshot marked non-restorable

Key mechanisms:
- `_snapshot_registry` table in `_backup` schema with pre_fingerprint, restorable flag, tables JSONB
- Dynamic table discovery (all public BASE TABLEs except tbl_audit_log)
- Restore as single SQL statement (Management API creates new connection per call — session_replication_role doesn't persist)
- Concurrency group shared between restore.yml and release.yml
- Partial snapshot cleanup via trap on failure
- On-demand snapshots via workflow_dispatch
- Retention: last 3 snapshots (~4.5-5 MB each at 30 categories × 5 seasons)
- Safety layers: CONFIRM-RESTORE input, production environment approval, restorable flag check

### Weaknesses identified during design

1. **Narrow restore window:** Schema changes (most migrations) mark ALL snapshots
   non-restorable. Effective pool is 0-1 usable snapshots most of the time.
2. **No transactional consistency:** Each CREATE TABLE AS SELECT is a separate API call.
   Concurrent writes produce inconsistent cross-table snapshots.
3. **No pre-restore safety net:** Restore overwrites current data with no undo.
4. **No CERT snapshots:** CERT auto-deploys with no rollback capability.
5. **No verification:** Snapshot correctness not validated after creation.
6. **NULL restorable flag:** If mark-snapshot-restorable fails, snapshot is stuck as
   NULL (unknown) forever.
7. **Management API rate limits:** 20+ API calls per snapshot at scale.
8. **No alerting:** No notification when all snapshots become non-restorable.

### Storage estimate (30 categories × 5 seasons)

Per snapshot: ~4.5-5 MB (tbl_result dominates at 70%)
3 snapshots: ~13-15 MB (~2.5-3% of Supabase free tier 500 MB)

## Alternatives Considered

1. **pg_dump** — Management API cannot run pg_dump. No filesystem access.
2. **PITR (Point-in-Time Recovery)** — Requires Supabase Pro plan ($25/mo).
   Restores entire database (not selective). Overkill for POC.
3. **Blue-green (credential swap)** — 2x cost (two Supabase projects). Operational
   complexity for a single-operator system.
4. **Application-level backup** — Custom API endpoint. Adds attack surface.
   Requires service_role key in client — security risk.
5. **Additive-safe restore (column matching)** — Intersection of backup/current
   columns for INSERT. Produces partial state — unpredictable results.

## Consequences

- Forward-only corrective migrations remain the only rollback mechanism (ADR-011)
- No additional complexity, scripts, or workflows to maintain
- Data corruption from migrations requires manual investigation + corrective SQL
- If data-only migrations become common (M7 ingestion pipeline), revisit this ADR
- Zero implementation cost — design preserved for future reference
