# Architecture

## Data flow

```
Email (.zip/.xml)  →  Google Apps Script (gas_email_ingestion.js)
                          ↓ uploads to Supabase Storage
                          ↓ triggers GitHub Actions (ingest.yml via PAT)
                      Python pipeline (orchestrator.py)
                          ↓ Parse (scrapers/) → Match (matcher/) → Ingest (atomic txn)
                          ↓ Telegram notifications
                      LOCAL → CERT → PROD (per-tournament promotion)
```

EVF calendar/results are pulled by [python/scrapers/evf_sync.py](../../python/scrapers/evf_sync.py) on a 3-day cron (`evf-sync.yml`). Ingestion of every other source (FTL/Engarde/4Fence/FencingTime/CSV/XLSX) is **atomic per-tournament** via `fn_ingest_tournament_results` in a single SQL transaction (delete → insert → score).

## Database (Supabase / PostgreSQL)

- 78 numbered SQL migrations in [supabase/migrations/](../../supabase/migrations/) (date-prefixed `YYYYMMDDNNNNNN_*.sql`); never edit a migration after it has been deployed — always add a new one.
- 25 pgTAP test files in [supabase/tests/](../../supabase/tests/) numbered `00`–`25`. Each starts with `SELECT plan(N);` — the **sum across all files** must equal the documented total (Gate 3 in `check-coherence.sh`).
- Two-tier event model: `tbl_event` (parent, calendar entry) → `tbl_tournament` (child, weapon/gender/category slot, created at ingestion only — never at event creation).
- Scoring engine is in SQL (`fn_*` SECURITY DEFINER functions). Ranking config is JSONB per season. Rolling carry-over for active season is rules-based with a 366-day cap (`tbl_season.int_carryover_days`) — see ADR-018, ADR-021.
- Carry-over engine is per-season selectable (legacy heuristic vs FK-linked); dispatcher pattern (ADR-042/045).
- All public-facing reads go through `vw_*` views; admin writes through SECURITY DEFINER `fn_*` RPCs (write-permission revoked from anon — ADR-016).

## Python ([python/](../../python/))

- `scrapers/` — source-specific parsers, all subclass `base.py`. EVF has split modules: `evf_calendar.py`, `evf_results.py`, `evf_sync.py`.
- `matcher/` — RapidFuzz fuzzy identity resolution with diacritic folding + alias support; `pipeline.py` orchestrates AUTO_MATCHED / PENDING / UNMATCHED states. **For international ingest (PEW/MEW/MSW), only AUTO_MATCHED rows are stored** — PENDING/UNMATCHED are dismissed (no identity-queue pollution).
- `pipeline/` — `orchestrator.py` is the single entrypoint; `db_connector.py` wraps Supabase RPCs; `notifications.py` is Telegram (never Discord); `promote.py` handles CERT→PROD per-tournament transfer; `export_seed_local.py` rebuilds LOCAL from a PROD/CERT seed.
- `tools/` — one-off CLI utilities (URL population, ad-hoc imports, audits, season-seed generation).

## Frontend ([frontend/](../../frontend/))

Svelte 5 with runes (`$state`, `$derived`). Two build targets:

- **SPA** — [frontend/src/main.ts](../../frontend/src/main.ts) → `index.html` → `npm run build`
- **Web Component** — [frontend/src/main.ce.ts](../../frontend/src/main.ce.ts) → `index.ce.html` → `npm run build:ce` → produces `<spws-ranklist>` Shadow-DOM-isolated bundle for embedding (ADR-007). The CE wrapper components are in [frontend/src/ce/](../../frontend/src/ce/).

Admin UI is gated on `?admin=1` query param + Supabase Auth + TOTP MFA (ADR-016). Components in [frontend/src/components/](../../frontend/src/components/) handle CRUD (Season/Event/Tournament/Fencer Manager), import flows (TournamentImport, EventImport), identity resolution queue (IdentityManager), and scoring config editor.

i18n is reactive Svelte $state (ADR-005); locale files in [frontend/src/lib/locales/](../../frontend/src/lib/locales/). **Every mockup/UI header must include the 🇬🇧/🇵🇱 toggle.**

## CI/CD ([.github/workflows/](../../.github/workflows/))

Eight workflows: `ci.yml` (lint+test on PR), `release.yml` (LOCAL→CERT→PROD pipeline), `ingest.yml` (Python pipeline trigger from GAS), `evf-sync.yml` (cron), `populate-urls.yml`, `scrape-tournament.yml`, `promote.yml`, `export-seed.yml`. Workflows are dispatched from the admin UI via the `dispatch-workflow` Edge Function so the GitHub PAT never leaves the server (ADR-041).

CERT/PROD environment IDs and runtime-toggle details: see auto-memory `cert-prod-environments.md` (and ADR-009/011/026).
