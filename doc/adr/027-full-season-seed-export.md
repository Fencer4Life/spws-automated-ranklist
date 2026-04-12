# ADR-027: Full-Season Seed Export

**Status:** Superseded by ADR-036  
**Date:** 2026-04-06 (original) · 2026-04-12 (superseded)  
**Relates to:** ADR-025 (Event-Centric Ingestion), ADR-026 (CERT→PROD Promotion), ADR-036 (PROD Export & Local Mirror)

## Context

Seed files serve as disaster recovery — `supabase db reset` rebuilds the entire DB from them. After ingesting event data and promoting to PROD, the seed files must be updated to reflect the current state.

## Original Decision (2026-04-06)

Export from **CERT** on `/complete` and `/rollback` commands. Per-category SQL files overwrite existing seed data. CERT was the source of truth.

## Superseded Decision (2026-04-12, ADR-036)

### Single monolithic PROD dump

ADR-036 replaces the multi-file per-category approach with a single timestamped SQL file exported from **PROD** (not CERT). PROD is now the source of truth for seed data.

### Export triggers — NEW flow

| Command | Action | Seed export? |
|---------|--------|-------------|
| `/complete <event>` | Mark event COMPLETED on CERT | **No** — CERT-only change |
| `/rollback <event>` | Delete event data on CERT, reset to PLANNED | **No** — CERT-only change |
| `/promote <event>` | Copy CERT → PROD | **Yes** — after PROD is updated, export PROD to git |
| `/export-seed` | Manual trigger | **Yes** — ad-hoc export from PROD |

### Why the change

1. **PROD is the source of truth** — seed files should reflect what's deployed, not an intermediate CERT state
2. **Monolithic dump is simpler** — one file, no directory naming issues, no duplicate INSERTs
3. **Schema-driven export** — discovers columns at runtime, future-proof (ADR-036)
4. **Fewer unnecessary exports** — `/complete` and `/rollback` happen frequently during ingestion; only `/promote` changes PROD

### Name-based fencer lookups (unchanged)

Seed files use name-based subselect lookups (not hardcoded IDs):
```sql
(SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KOWALSKI' AND txt_first_name = 'Jan' LIMIT 1)
```

### Auto-resume email polling on event day (unchanged)

The GAS script's `checkEmailForResults()` checks if any event is scheduled today. If so, it auto-clears the `PAUSED` flag and notifies via Telegram.

## Consequences

- Seed export no longer fires on `/complete` or `/rollback`
- Seed export fires after `/promote` completes (PROD updated)
- Seed file format: single `supabase/seed_prod_YYYY-MM-DD.sql` (ADR-036)
- Old per-category files (`supabase/data/`, `seed.sql`, `seed_tbl_fencer.sql`) removed
- `config.toml` points to `seed_prod_latest.sql` symlink
