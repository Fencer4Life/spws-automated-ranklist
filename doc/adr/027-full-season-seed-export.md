# ADR-027: Full-Season Seed Export from CERT

**Status:** Accepted  
**Date:** 2026-04-06  
**Relates to:** ADR-025 (Event-Centric Ingestion), ADR-026 (CERT→PROD Promotion)

## Context

Seed files in `supabase/data/{season}/` serve as disaster recovery — `supabase db reset` rebuilds the entire DB from them. After ingesting event data into CERT and validating it, the seed files must be updated to reflect the current state.

The Phase 9 approach (appending event data to seed files during promotion) causes duplicates on re-promotion and doesn't update `seed_tbl_fencer.sql` with auto-created fencers.

## Decision

### Full-season overwrite on `complete` and `rollback`

When the admin sends `complete <event>` or `rollback <event>` on Telegram, regenerate **all** seed files for the active season by reading the full dataset from CERT via the Management API. This produces a complete snapshot that overwrites existing files — no duplicates, no stale data.

### Export triggers

- **`complete <event>`**: Event finalized on CERT → regenerate seeds → auto-commit `[skip ci]`
- **`rollback <event>`**: Data deleted from CERT → regenerate seeds → auto-commit `[skip ci]` (rolled-back event data absent)
- **`export-seed`**: Manual trigger via Telegram for ad-hoc regeneration

### Name-based fencer lookups

Existing seed files use hardcoded `id_fencer` integers. The export uses name-based subselect lookups instead:
```sql
(SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOWALSKI' AND txt_first_name = 'Jan' LIMIT 1)
```
This ensures seed files work correctly after `db reset` where fencer IDs are reassigned by the Postgres sequence.

### Auto-resume email polling on event day

The GAS script's `checkEmailForResults()` checks if any event is scheduled today. If so, it auto-clears the `PAUSED` flag and notifies via Telegram. This means `pause` is safe to leave on indefinitely.

### Source of truth

CERT is the source of truth for seed data (not PROD). CERT always has the most recent validated state. PROD is a copy of CERT.

## Alternatives Considered

1. **Append-based export (Phase 9):** Causes duplicates on re-promotion, doesn't include new fencers. Rejected.
2. **Export from PROD:** Adds a dependency on promotion before seeds update. CERT data is validated first. Rejected.
3. **Auto-revert git commits on rollback:** Complex — requires finding the specific seed commit to revert. Simpler to just regenerate from CERT's current state. Rejected.

## Consequences

### Positive
- Seed files always reflect CERT's validated state
- Full overwrite = no duplicates, no stale data
- Git history = versioned backup of every state
- Auto-resume eliminates risk of forgetting to re-enable polling

### Negative
- Full-season export queries many tables (acceptable — runs infrequently)
- Existing hardcoded-ID seed files will be replaced with name-lookup format (one-time format change)
- `[skip ci]` commits mean LOCAL doesn't auto-reset (by design — manual `db reset` when needed)

### Note (ADR-031)
"Active season" in the export trigger context (line 17) is derived from the event's `id_season`, not the global `bool_active` flag. Season activation is now auto-managed per ADR-031.
