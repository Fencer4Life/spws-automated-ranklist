# ADR-022: Ingestion DB Transaction Strategy

**Status:** Accepted
**Date:** 2026-04-05 (Go-to-PROD)

## Context

The ingestion pipeline needs to atomically: delete old results → insert new results → create match candidates → run scoring engine → update import status — all for a single tournament. This must happen in one database transaction so that a failure at any step rolls back everything (per ADR-014).

The Python orchestrator handles XML parsing, combined-category splitting, and fuzzy matching (CPU-bound, already tested). The question is how to execute the DB operations transactionally.

Key constraints:
- Supabase PostgREST does not support multi-statement transactions
- `psycopg2` direct connections bypass RLS and the Supabase Auth security model
- The existing `fn_calc_tournament_scores` pattern uses server-side Postgres functions called via `.rpc()`

## Decision

Use a **server-side Postgres function** `fn_ingest_tournament_results(p_tournament_id INT, p_results JSONB)` that performs the entire ingest atomically in one implicit transaction. Python calls this single RPC via the Supabase client after completing all parsing and matching in memory.

The function:
1. Deletes existing `tbl_match_candidate` rows for the tournament's results
2. Deletes existing `tbl_result` rows for the tournament
3. Inserts new `tbl_result` rows from the JSONB array
4. Inserts `tbl_match_candidate` entries for each result
5. Calls `fn_calc_tournament_scores(p_tournament_id)`
6. Updates `tbl_tournament.enum_import_status` to `'IMPORTED'` and `int_participant_count`
7. Returns a summary JSONB object

Pattern: `SECURITY DEFINER` + `REVOKE EXECUTE FROM anon` + `GRANT EXECUTE TO authenticated` (same as all T9.1 CRUD functions).

## Alternatives Considered

1. **`psycopg2` direct connection** — Allows explicit `BEGIN`/`COMMIT` in Python. But bypasses RLS policies and Supabase Auth, breaking the security model. Would require maintaining a separate connection string and credential management.

2. **Multiple PostgREST calls** — Call `.insert()`, `.delete()`, `.rpc()` separately via the Supabase client. Each call is its own transaction — a failure partway through leaves the DB in an inconsistent state. No way to wrap multiple PostgREST calls in a single transaction.

3. **Edge Function with `pg` client** — A Supabase Edge Function (Deno) with direct Postgres access. Adds a deployment dependency, a new runtime (Deno), and moves logic away from the tested Python codebase.

## Consequences

- Clean separation: Python does compute (parsing, matching), Postgres does data (insert, score, status)
- Single RPC call = single network round-trip = single transaction
- Rollback is automatic on any error (Postgres function = implicit transaction)
- Match candidates are created alongside results, enabling immediate admin review
- Scoring runs within the same transaction, so `num_final_score` is always consistent with results
- The function can be called from any client (CLI, GitHub Actions, future Admin UI) with the same guarantees
