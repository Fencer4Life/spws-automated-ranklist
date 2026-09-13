# ADR-036: PROD Export & Local Mirror (Single Monolithic Dump)

**Status:** Implemented (amended 2026-07-14 and 2026-09-12; see the amendments)
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

See **`doc/archive/legacy-2026-07/cicd-operations-manual.md` §11 (Environment Sync)** for complete step-by-step procedures for all sync operations (PROD → local, PROD → CERT, data audit).

## Amendment (2026-07-14) — name-lookup reconstruction & fresh-bootstrap migration ordering

Two latent constraints on this dump surfaced during the 2026-07 fencer birth-year
reconciliation (worked example and evidence: `doc/plans/fencer-birth-year-master-list-2026-07.html`).
Neither changes the export design; both make explicit a property it always had.

### 1. Name-based FK reconstruction must disambiguate duplicate names

The dump resolves `tbl_result` (and `tbl_match_candidate`) fencer FKs by name lookup —
`(SELECT id_fencer FROM tbl_fencer WHERE txt_surname = … AND txt_first_name = … LIMIT 1)`
— see *Tables exported* (rows 7–8). This is safe only while `(surname, first_name)` is
unique. When master data legitimately contains two different people who share both —
e.g. `MŁYNEK Janusz` born 1951 (SABRE veteran) and `MŁYNEK Janusz` born 1984, or the two
`KRAWCZYK Paweł` (1954 / 1989) — that `LIMIT 1` has no `ORDER BY` and resolves to an
**arbitrary** one of them. On a fresh `supabase db reset` the wrong pick lands a historical
result in a bracket its birth year does not support, and the fail-loud `fn_assert_result_vcat`
trigger (ADR-047) correctly aborts the seed load.

**Rule:** whenever the roster contains a duplicate `surname+first_name` pair, every
name-based lookup for those fencers in the dump must carry a disambiguating
`AND int_birth_year = <year>` qualifier. `export_seed_local` must emit the qualified form
for any name it detects more than once. (Applied 2026-07-14: 38 `MŁYNEK Janusz` lookups in
`seed_prod_2026-06-28.sql` were birth-year-qualified.)

### 2. Data migrations that reference seeded rows must no-op safely on a fresh bootstrap

*Step 2* records the ordering: `supabase db reset` **applies all migrations first, then loads
this dump.** So a migration timestamped *after* the dump runs against **empty** tables on a
from-scratch build — which is exactly what CI's `supabase start` does — even though every
referenced row exists on the long-running LOCAL/CERT/PROD tiers (those apply migrations
incrementally *onto* already-seeded data and never rebuild from zero).

**Rule:** a data migration that resolves pre-existing rows by name (or otherwise assumes
seeded data) must **guard the lookup and skip with a `NOTICE`** when the row is absent, rather
than call a fail-loud RPC (e.g. `fn_update_fencer_birth_year`, which `RAISE EXCEPTION`s on a
NULL id) directly. On the seeded tiers the guard is a harmless no-op; on the fresh-bootstrap
build it lets the migration sequence complete. (Applied 2026-07-14: the 10 birth-year
corrections were wrapped in a guarded `DO` block — commit `57655a4`.)

## Amendment (2026-09-12) — the seed must be idempotent against the migrations that precede it

The 2026-07-14 amendment established that a fresh bootstrap runs **every migration
before this dump**. It drew one consequence — name lookups must disambiguate duplicate
names — and stopped one step short of the general rule. Three defects found while
rebuilding LOCAL from a dump taken on 2026-09-12, the first PROD export after PZSz
reached the organizer table:

### 1. The seed could not load at all

Migration `20260903000001` inserts the PZSz organizer, and does so idempotently — its
own comment says this is so *"the seed dump that follows on a fresh bootstrap cannot
duplicate it"*. But the guard was only on the migration's side. The dump emitted a
plain `INSERT INTO tbl_organizer`, so the migration inserted PZSz, the seed inserted it
again, and the whole seed aborted on `idx_organizer_code`. **Two idempotent halves are
not idempotent together unless both guard.** The dump now upserts on `txt_code`, and
the dump wins, because it *is* the PROD truth: a migration seeding a placeholder must
not mask the real payee and IBAN behind it.

### 2. LOCAL was never a copy of PROD, and was wrong where it mattered most

Three data migrations add fencers by hand (`20260714000003`'s fifteen reconciled rows,
plus KOSZYK and CISZEWSKA/SZUMIELEWICZ). All three carry `WHERE NOT EXISTS` guards —
which pass, because on a fresh bootstrap they run against an **empty table**. The seed
then inserted the same eighteen people a second time.

| | LOCAL, before | PROD |
| --- | --- | --- |
| Fencers | 385 | 367 |
| Same-name pairs | 17 | 2 |
| Duplicate exact triples | 17 | 0 |

Those phantom pairs are not inert: same-name collisions are exactly the input that
makes identity resolution ambiguous (ADR-093), so every local test of duplicate-name
behaviour had been running against eight times the collisions PROD actually has. The
dump now skips anyone already present on the identity triple, comparing birth years
with `IS NOT DISTINCT FROM` — `= NULL` is never true, so the nine fencers with no birth
year would otherwise duplicate on every reset.

A guard on the migration protects against re-running the migration. Only a guard on the
**seed** protects against the seed.

### 3. The suite was calibrated to a seed snapshot

Refreshing the dump from 2026-08-08 to 2026-09-12 turned six pgTAP files red, none of
them because code had changed. Four were latent defects the old snapshot had hidden:
`19_phase3_wizard` and `74_no_evf_season_skeletons` deleted a season's events without
clearing the tournaments that now hang off them, and `54_evf_calendar_prior_link_reassignment`
and `63_prod_mirror_rename` looked up events by EVF calendar id with no season scope —
so `SELECT INTO` silently bound a **real** PROD event and renamed it. Two were genuine
data drift: `56.25`'s PEW count (PROD consolidated PEW9/11/12/14) and `67.4`, which
asserted that *no* event shows the moved-date pill — true in August, and false since
EVF moved PEW14ef-2026-2027. All six are fixed; `67.4` is restated as "nothing
*unexpected*", which survives both a genuine mover appearing and this one ageing out.

The rule this amendment adds: **a refresh of the dump is a change to the test suite's
inputs, and must be run through the full suite before the `seed_prod_latest.sql`
pointer is moved.** `scripts/mirror-prod-local.sh` rebuilds LOCAL as a faithful PROD
copy for exactly this check, and deliberately restores that pointer on any exit so a
local experiment cannot silently become a CI change.

## Related ADRs

- **ADR-027** (Full-Season Seed Export) — superseded by this ADR for local mirroring
- **ADR-026** (CERT→PROD Promotion) — data promotion workflow this export complements
- **ADR-014** (Delete-Reimport Strategy) — idempotent INSERT patterns reused
- **ADR-047** (V-cat invariant trigger) — the fail-loud `fn_assert_result_vcat` that the
  amendment's disambiguation rule keeps satisfiable on a fresh reset
- **ADR-056** (correction-migration pattern) — the guarded no-op rule extends its
  skip-true-no-ops precedent to fresh-bootstrap absence
