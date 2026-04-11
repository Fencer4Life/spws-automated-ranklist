# Development History — SPWS Automated Ranklist System

**This is a read-only archive.** For the living specification, see [Project Specification](Project%20Specification.%20SPWS%20Automated%20Ranklist%20System.md).

---

## Phase 1: Proof of Concept (M0–M6)

**Completed:** 2026-03-25
**Scope:** Male Epee V2 (50+) only — single sub-ranking end-to-end
**Assertions at completion:** 236 (pgTAP + pytest + vitest)

### Milestones

| Milestone | Description | Date |
|-----------|-------------|------|
| M0 | Project setup: Supabase, Python venv, Svelte 5, pgTAP | 2026-03-01 |
| M1 | Database foundation: 8 tables, enums, indexes, audit trigger, RLS | 2026-03-05 |
| M2 | Scoring engine: `fn_calc_tournament_scores` with place points, DE bonus, podium bonus, multiplier | 2026-03-08 |
| M3 | Data ingestion: FTL (JSON+CSV), Engarde (HTML), 4Fence (HTML) scrapers + URL dispatcher | 2026-03-10 |
| M4 | Identity resolution: RapidFuzz matching, alias support, disambiguation pipeline | 2026-03-14 |
| M5 | Ranking views: `fn_ranking_ppw` (domestic) + `fn_ranking_kadra` (international pool) | 2026-03-18 |
| M6 | Frontend: Svelte 5 Web Component with FilterBar, RanklistTable, DrilldownModal, ScoreChart | 2026-03-25 |

### Key Decisions (POC)
- ADR-001: Hybrid scoring config (DB + JSONB rules)
- ADR-002: Calculate once, store forever
- ADR-003: Identity by FK (not name)
- ADR-005: Svelte $state for i18n
- ADR-006: JSONB ranking rules
- ADR-007: Shadow DOM isolation

---

## Phase 2: Minimum Viable Product (M8–M10)

**Completed:** 2026-04-04
**Scope:** All 30 sub-rankings (3 weapons x 2 genders x 5 categories V0-V4)
**Assertions at completion:** 544 (192 pgTAP + 104 pytest + 166 vitest + 7 Playwright + 75 new)

### Milestones

| Milestone | Description | Date |
|-----------|-------------|------|
| M8 | Multi-category data + Calendar UI + Schema extensions (arr_weapons, organizer, entry_fee) | 2026-03-26 |
| M9 | Admin CRUD (seasons, events, tournaments) + Identity resolution UI + File import parsers + Ingestion pipeline | 2026-04-04 |
| M10 | Rolling score for active season: carry-over from previous season, birth year subtitle, progress bar | 2026-03-29 |

### Key Decisions (MVP)
- ADR-008: PSW/MSW in international pool
- ADR-009: CERT/PROD runtime toggle
- ADR-010: Age category by birth year
- ADR-011: Three-tier release pipeline (LOCAL→CERT→PROD)
- ADR-013: POC→MVP transition strategy
- ADR-014: Delete-reimport strategy
- ADR-015: M8 UI design decisions
- ADR-016: Supabase Auth + TOTP MFA
- ADR-017: Season-configurable EVF toggle
- ADR-018: Rolling score for active season
- ADR-019: Domestic-only fencer seed
- ADR-020: Seed generator domestic auto-create
- ADR-021: IMEW biennial carry-over

---

## Phase 3: Go-to-Production

**Completed:** 2026-04-07
**Scope:** Full ingestion pipeline, EVF scraping, admin CRUD, CERT→PROD promotion
**Assertions at completion:** 713 (236 pgTAP + 269 pytest + 201 vitest + 7 Playwright)

### Deliverables

| Item | Description | ADRs |
|------|-------------|------|
| Pipeline Orchestration | FTL XML parsing, combined-category splitting, fuzzy matching, atomic ingest | ADR-022, 024 |
| Email Ingestion | GAS polls Gmail → Supabase Storage → GitHub Actions ingest.yml | ADR-023 |
| Event-Centric Ingestion | Match XML to event by date, create tournaments on-the-fly, 20+ Telegram commands | ADR-025 |
| CERT → PROD Promotion | Per-tournament transfer with url_results carry, error recovery | ADR-026 |
| Seed Export | Full-season export from CERT, name-based lookups, auto-commit | ADR-027 |
| EVF Calendar + Results | JSON API scraper, calendar HTML parser, cron every 3 days, 7 events/64 results ingested | ADR-028 |
| Tournament URL Auto-Population | FTL/Engarde/4Fence discovery, Admin UI ⬇ buttons, PROD commands | ADR-029 |
| Identity Resolution DB Wiring | fn_approve/dismiss/create RPCs, match candidates view, integration tests | — |
| Calendar UI Color Coding | PEW blue, IMEW/MSW gold, 3-line slot boxes with city | — |
| Admin Tournament CRUD | Inline edit/create forms, delete with confirm, tooltips, import via GHA | ADR-029 |
| UI Layout Improvements | Season selector + env toggle moved to filter bars/footers | — |

### Key Decisions (Go-to-PROD)
- ADR-022: Ingestion DB transaction (single Postgres function)
- ADR-023: Email ingestion via GAS + Supabase Storage
- ADR-024: Combined category splitting (DOB-based)
- ADR-025: Event-centric ingestion + Telegram admin
- ADR-026: CERT → PROD promotion
- ADR-027: Full-season seed export
- ADR-028: EVF calendar + results import (JSON API)
- ADR-029: Tournament URL auto-population + admin CRUD

---

## Infrastructure

### GitHub Actions Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci.yml` | Push to main | pgTAP + pytest + vitest + coherence checks |
| `release.yml` | CI success | Deploy to CERT (auto) + PROD (manual approval) |
| `ingest.yml` | GAS / manual | Process XML from Supabase Storage staging |
| `evf-sync.yml` | Cron (3 days) / manual | EVF calendar + results scraping |
| `export-seed.yml` | Telegram / manual | Full-season seed export from CERT |
| `promote.yml` | Telegram / manual | CERT → PROD event promotion |
| `populate-urls.yml` | Admin UI / Telegram | Discover tournament URLs from event page |
| `scrape-tournament.yml` | Admin UI / Telegram | Scrape results from tournament URL |

### Telegram Commands (20+)

**Lifecycle:** status, complete, rollback, promote
**Review:** results, pending, missing
**Storage:** staging, cleanup
**Season:** season, ranking, ingest, export-seed
**EVF:** evf-cal-import, evf-results-import, evf-status
**URLs:** populate-urls, populate-urls-prod, t-scrape
**PROD:** status-prod, results-prod, evf-status-prod
**Emergency:** pause, resume

### Environments

| Env | Supabase Ref | Purpose |
|-----|-------------|---------|
| LOCAL | `127.0.0.1:54321` | Development + testing |
| CERT | `sdomfjncmfydlkygzpgw` | Staging / validation |
| PROD | `ywgymtgcyturldazcpmw` | Public-facing |

---

## Post-MVP Enhancements

| Feature | Description | Date | ADR |
|---------|-------------|------|-----|
| Event Registration URL + Deadline | Two new fields on `tbl_event` (`url_registration`, `dt_registration_deadline`); conditional display in Calendar (deadline + link hide after cutoff date); admin edit form; 3 pgTAP + 8 vitest assertions | 2026-04-11 | ADR-030 |
| Local dev reset script | `scripts/reset-dev.sh` — combines `supabase db reset` with admin user recreation via GoTrue API (LOCAL ONLY) | 2026-04-11 | — |

---

## Archived Documents

The following documents contain the original detailed plans. They are superseded by this history and the Project Specification:

- `doc/POC_development_plan.md` — POC milestones M0–M6 (archived)
- `doc/MVP_development_plan.md` — MVP milestones M8–M10 (archived)
- `doc/Go-to-PROD.md` — Go-to-PROD items 2.1–2.9 (archived)
