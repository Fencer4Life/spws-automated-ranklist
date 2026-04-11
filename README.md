# SPWS Automated Ranklist System

Automated ranking system for the **Polish Veterans Fencing Association** (Stowarzyszenie Polskich Weteranow Szermierki). Computes and publishes live rankings across 30 weapon-gender-cathegory-rankings (3 weapons, 2 genders, 5 age categories V0-V4) with rolling score carry-over from previous seasons.

## Live

- **Production:** Embedded on the SPWS website via `<spws-ranklist>` Web Component. Tobe rolled out at the beginning of 2026-2027 season. MVP version published on GitHub page for certification testing.
- [**CERT (staging)**](https://fencer4life.github.io/spws-automated-ranklist/)
- [**Admin UI**](https://fencer4life.github.io/spws-automated-ranklist/?admin=1)

## Features

### Public Views
- **Ranklist** — filterable by weapon/gender/category/season with PPW (domestic) and +EVF/Kadra (international) ranking modes
- **Calendar** — chronological event list with color-coded cards (PEW blue, IMEW/MSW gold), rolling progress bar, 3-line slot boxes with city names
- **Drilldown Modal** — per-fencer score breakdown with carried-over scores from previous season
- **Dynamic age cathegory selection** — determining eligible birth years for selected category and season

### Admin (Authenticated)
- **Season/Event/Tournament CRUD** — inline edit/create forms in accordion UI with tooltips and confirmation dialogs
- **Identity Resolution** — match candidate queue with approve/dismiss/create-new actions
- **Scoring Config Editor** — per-season scoring parameters with JSON export/import
- **Tournament URL Auto-Population** — discovers result URLs from FTL, Engarde, 4Fence event pages
- **Import via URL Scrape** — triggers GitHub Actions to scrape and ingest results

### Pipeline (Automated)
- **Email Ingestion** — Google Apps Script polls Gmail for .zip/.xml, uploads to Supabase Storage, triggers GitHub Actions
- **FTL XML Parser** — FencingTime Live XML with combined category splitting (v0v1, v0v1v2)
- **EVF Scraper** — JSON API + HTML calendar from veteransfencing.eu, cron every 3 days
- **Fuzzy Matching** — RapidFuzz identity resolution with diacritic folding, alias support
- **Atomic Ingestion** — single-transaction delete + insert + score per tournament
- **CERT -> PROD Promotion** — per-tournament transfer with url_results carry

### Operations (Telegram)
20+ admin commands: lifecycle (status, complete, rollback, promote), review (results, pending, missing), EVF (evf-cal-import, evf-results-import), URLs (populate-urls, t-scrape), PROD read-only queries, emergency pause/resume.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Database | PostgreSQL via Supabase (RLS, SECURITY DEFINER functions) |
| Backend | Python 3.11+ (scrapers, matcher, pipeline, CLI tools) |
| Frontend | Svelte 5 Web Component (Shadow DOM, PL/EN i18n) |
| Auth | Supabase Auth + TOTP MFA |
| CI/CD | GitHub Actions (8 workflows), three-tier: LOCAL -> CERT -> PROD |
| Admin | Google Apps Script (email polling) + Telegram Bot API (20+ commands) |

## Architecture

```
Email (.zip) -> GAS -> Supabase Storage -> GitHub Actions -> Python Pipeline
                                                              |
                                                    Parse XML -> Match Fencers -> Ingest (atomic)
                                                              |
                                                    Telegram Notifications
                                                              |
                                                    CERT -> validate -> PROD (promote)
```

## Test Coverage

| Suite | Assertions | Files |
|-------|-----------|-------|
| pgTAP | 236 | 13 SQL test files |
| pytest | 269 | 20 Python test files |
| vitest | 201 | 21 TypeScript test files |
| Playwright | 7 | 1 E2E file |
| **Total** | **713** | |

**Requirements:** 83 Covered + 2 Partial out of 89 Functional Requirements. 29 Architecture Decision Records.

## Project Structure

```
supabase/
  migrations/     # 15 SQL migrations
  tests/          # pgTAP tests (236 assertions)
  seed.sql        # Base seed data
  data/           # Season-specific seed files (exported from CERT)
python/
  scrapers/       # FTL, Engarde, 4Fence, EVF, FencingTime XML parsers
  matcher/        # RapidFuzz identity resolution pipeline
  pipeline/       # Orchestrator, DB connector, notifications, promote, export
  tools/          # URL population, tournament scraping, seed generation
  tests/          # pytest (269 assertions)
frontend/
  src/            # Svelte 5 components (App, FilterBar, CalendarView, etc.)
  tests/          # vitest (201 assertions)
scripts/
  gas_email_ingestion.js  # Google Apps Script (email + Telegram)
  check-coherence.sh      # CI coherence gates
doc/
  Project Specification. SPWS Automated Ranklist System.md  # Single source of truth
  development_history.md  # Chronological archive (POC -> MVP -> Go-to-PROD)
  adr/                    # 29 Architecture Decision Records
  mockups/                # HTML mockups for UI features
.github/
  workflows/      # 8 GitHub Actions workflows (CI, release, ingest, EVF, promote, etc.)
```

## Development

```bash
# Prerequisites: Docker, Node 25+, Python 3.11+, Supabase CLI

# Start local Supabase
supabase start
supabase db reset

# Frontend dev server
cd frontend && npm install && npm run dev

# Run tests
supabase test db                                    # pgTAP (236)
source .venv/bin/activate && python -m pytest -v    # pytest (269)
cd frontend && npm test                             # vitest (201)

# Coherence check (same as CI)
bash scripts/check-coherence.sh
```

## Documentation

- [Project Specification](doc/Project%20Specification.%20SPWS%20Automated%20Ranklist%20System.md) — requirements, use cases, RTM, ADR registry, test baseline
- [Development History](doc/development_history.md) — chronological archive of POC/MVP/Go-to-PROD phases
- [ADR Index](doc/adr/) — 29 Architecture Decision Records
- [CI/CD Operations Manual](doc/cicd-operations-manual.md) — deployment guide

## Authors

- **Aleksander Atanassow** ([@Fencer4Life](https://github.com/Fencer4Life)) — Project owner, domain expert, system requirements owner
- **Claude Opus 4.6** (Anthropic) — Co-author, solution architecture and implementation partner

## License

Public repository.
