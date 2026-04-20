# ADR-036: PROD Export & Local Mirror (Single Monolithic Dump)

**Status:** Implemented  
**Date:** 2026-04-12  
**Source:** ADR-027 (Full-Season Seed Export), ADR-026 (CERT→PROD Promotion)

## Context

After the CERT/PROD data integrity audit (2026-04-12), we needed local DB to be an exact mirror of PROD. The original multi-file approach (per-category SQL files loaded via config.toml glob) was fragile — directory naming mismatches, duplicate INSERTs across files, and complex ordering dependencies.

## Decision

Replace the multi-file seed approach with a **single monolithic SQL dump** — one timestamped file that recreates all data in one shot.

### Schema-driven export (future-proof)

The export script does NOT hardcode column names. For each table it:
1. Queries `information_schema.columns` at runtime to discover ALL columns
2. Skips only auto-generated columns (`id_*` serial PKs, `ts_created`, `ts_updated`)
3. Generates INSERT statements with all remaining columns

Any column added in future migrations is automatically included without code changes.

### Tables exported (in FK-safe order)

| Order | Table | Notes |
|-------|-------|-------|
| 1 | `tbl_season` | All seasons |
| 2 | `tbl_organizer` | All organizers |
| 3 | `tbl_scoring_config` | JSONB ranking rules per season (via UPDATE after trigger-created defaults) |
| 4 | `tbl_fencer` | All columns: surname, first name, birth year, estimated, nationality, gender, club, aliases |
| 5 | `tbl_event` | All columns: code, name, location, country, venue, dates, URLs, registration, fees, weapons, status |
| 6 | `tbl_tournament` | All columns: code, name, type, weapon, gender, category, date, participants, multiplier, URLs, status |
| 7 | `tbl_result` | Fencer FK via name lookup, tournament FK via code lookup, place, score |
| 8 | `tbl_match_candidate` | Identity audit trail for results. FK via result (tournament+place+fencer) + fencer name lookup |

### What's NOT exported (by design)

- `tbl_audit_log` — runtime audit trail
- Auth users — local: `reset-dev.sh`, cloud: Dashboard
- Schema/migrations — code artifacts, not data

### Output

```
supabase/seed_prod_2026-04-12.sql    # timestamped dump
supabase/seed_prod_latest.sql        # symlink to latest dump
```

`config.toml` loads `seed_prod_latest.sql` as the sole seed file during `supabase db reset`.

## Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `scripts/export-prod.sh` | Export PROD → single timestamped SQL file | `./scripts/export-prod.sh` |
| `scripts/mirror-prod.sh` | Export + reset + verify (one command) | `./scripts/mirror-prod.sh` |

## Operations Manual

### Quick: One-command mirror

```bash
./scripts/mirror-prod.sh
```

### Step-by-step

#### Prerequisites
- Supabase CLI running locally (`supabase start`)
- Python venv activated (`source .venv/bin/activate`)
- Docker running (for local PostgreSQL)

#### Step 1: Export PROD

```bash
./scripts/export-prod.sh
```

What happens:
1. Connects to PROD via Supabase Management API
2. Discovers all columns for each table from `information_schema.columns`
3. Queries all rows from each table in FK-safe order
4. Writes `supabase/seed_prod_YYYY-MM-DD.sql` with:
   - Season INSERTs
   - Organizer INSERTs
   - Scoring config UPDATEs (trigger creates defaults, then override with PROD values)
   - Fencer bulk INSERT (all columns)
   - Per-event block: event INSERT + tournament INSERTs + result INSERTs
5. Updates `seed_prod_latest.sql` symlink

#### Step 2: Reset local DB

```bash
./scripts/reset-dev.sh
```

`supabase db reset` applies migrations then loads `seed_prod_latest.sql` via config.toml. Creates admin user.

#### Step 3: Verify

```bash
python -m pytest python/tests/test_prod_mirror.py -v
```

Compares row counts for all 7 tables between PROD (Management API) and local (docker exec). Any mismatch = FAIL.

#### Step 4: Run all test suites

```bash
supabase test db
python -m pytest python/tests/ -v
cd frontend && npm test
```

### Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| Management API 429/502 | Rate limit / outage | Script auto-retries 3x with backoff |
| Mirror test fails | Stale dump | Re-run `./scripts/export-prod.sh` |
| pgTAP tests fail | Test uses hardcoded IDs or stale expected values | Fix test |

## Alternatives Considered

1. **Multi-file per-category approach (ADR-027)** — rejected; directory naming mismatches, duplicate INSERTs, fragile glob ordering
2. **pg_dump/pg_restore** — rejected; port 5432 is blocked on cloud Supabase
3. **Supabase REST API export** — rejected; service_role key blocked in some contexts

## Consequences

- Local DB mirrors PROD with one command
- Schema-driven: future columns auto-included
- Timestamped dumps provide rollback snapshots
- Old per-category seed files (`supabase/data/`, `seed.sql`, `seed_tbl_fencer.sql`) replaced by single file

## Full Operations Guide

See **`doc/cicd-operations-manual.md` §11 (Environment Sync)** for complete step-by-step procedures for all sync operations (PROD → local, PROD → CERT, data audit).

## Related ADRs

- **ADR-027** (Full-Season Seed Export) — superseded by this ADR for local mirroring
- **ADR-026** (CERT→PROD Promotion) — data promotion workflow this export complements
- **ADR-014** (Delete-Reimport Strategy) — idempotent INSERT patterns reused
