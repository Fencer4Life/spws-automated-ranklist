# ADR-026: CERT → PROD Event Promotion via Python Script

**Status:** Accepted  
**Date:** 2026-04-05  
**Relates to:** ADR-025 (Event-Centric Ingestion + Telegram Admin), ADR-011 (Three-Tier Release Pipeline)

## Context

After ingesting XML results into CERT and validating them (via Telegram commands, admin UI, and ranklist review), the admin needs to push the event data to PROD. The `promote` Telegram command triggers a GitHub Actions workflow, but the actual data transfer mechanism needs to be defined.

Event data includes: tournaments (auto-created during ingestion), results, match candidates, and scoring. A typical event has 20-30 tournaments and 50-100 results.

## Decision

Use a **Python promotion script** (`python/pipeline/promote.py`) that:

1. Reads all tournaments + results for an event from CERT via Supabase Management API SQL queries
2. For each tournament on CERT:
   - Calls `fn_find_or_create_tournament()` on PROD to create the tournament if it doesn't exist
   - Calls `fn_ingest_tournament_results()` on PROD with the results (atomic delete+insert+score)
3. Updates the PROD event status to `COMPLETED`
4. Sends a Telegram summary notification
5. Handles errors per-tournament (continues on failure, reports which failed)

Triggered by: `promote.yml` GitHub Actions workflow, dispatched from Telegram `promote <event>` command.

Both CERT and PROD are accessed via the Supabase Management API (`POST /v1/projects/{ref}/database/query`), which requires the `SUPABASE_ACCESS_TOKEN` (org-level token). No direct database connections needed.

After successful promotion, the script **auto-exports seed SQL files** to `supabase/data/{season}/` matching the existing seed file convention. The workflow commits these files to `main` with `[skip ci]` to prevent CI loops. This ensures `supabase db reset` always includes the latest promoted data.

## Alternatives Considered

1. **SQL-only (fn_export + fn_import):** Single JSON blob transferred via bash curl. Rejected: JSON can be 50KB+, bash string handling is fragile, no per-tournament error recovery.
2. **Direct database connection (psycopg2):** Bypasses the Management API. Rejected: port 5432 is blocked on cloud Supabase, requires connection pooling setup.
3. **Supabase REST API (PostgREST):** Use the service_role key to call RPCs directly. Rejected: service_role key is blocked in browser-like contexts (discovered during GAS script testing).

## Consequences

### Positive
- Per-tournament error handling — one failed tournament doesn't block the rest
- Reuses existing `fn_find_or_create_tournament` and `fn_ingest_tournament_results` on PROD
- Telegram progress notification
- No new infrastructure — uses existing Management API access pattern

### Negative
- Requires `SUPABASE_ACCESS_TOKEN` in GitHub Actions secrets (already configured)
- Sequential per-tournament processing (not parallel) — acceptable for 20-30 tournaments
- Management API has rate limits (unlikely to hit for this volume)
