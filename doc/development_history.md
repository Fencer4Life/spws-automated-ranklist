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
| Date-aware event status transitions | Replace static `VALID_TRANSITIONS` map in EventManager with date-aware logic: future events allow all statuses, past events lock status. Aligns UI with DB rollback support (ADR-025). Fixes spec state diagram. +3 vitest assertions | 2026-04-11 | — (aligns with ADR-025) |

### Date-Aware Event Status Transitions — Implementation Plan

**Problem:** An IMSW event on CERT was accidentally marked COMPLETED despite being a future event. The frontend `VALID_TRANSITIONS` map has `COMPLETED: []`, blocking all transitions from COMPLETED. The DB trigger (`fn_validate_event_transition`) already permits `COMPLETED → PLANNED` and `COMPLETED → IN_PROGRESS` per ADR-025, but the UI never exposed these.

**Approach:** Replace static transition map with `getAvailableStatuses(event)` function:
- **Future event** (`dt_start >= today` or `dt_start` is null): offer ALL statuses except current
- **Past event** (`dt_start < today`): no dropdown (locked)
- DB trigger remains the authoritative safety net for invalid transitions

#### Tests (TDD — RED phase first)

| Test ID | File | Assertion |
|---------|------|-----------|
| 9.49 | `frontend/tests/EventManager.test.ts` | **REWRITE:** past event (dt_start='2025-01-15') shows NO status dropdown |
| 9.87 | `frontend/tests/EventManager.test.ts` | Future COMPLETED event (dt_start='2027-10-15') shows dropdown with 5 statuses (all except COMPLETED) |
| 9.88 | `frontend/tests/EventManager.test.ts` | Event with dt_start=null shows dropdown (all except current) |
| 9.89 | `frontend/tests/EventManager.test.ts` | Future CANCELLED event shows dropdown with 5 statuses |

#### Implementation (GREEN phase)

| File | Change |
|------|--------|
| `frontend/src/components/EventManager.svelte` | Remove `VALID_TRANSITIONS` (lines 222–229); add `ALL_STATUSES` + `getAvailableStatuses(event)` function; update template (lines 64–71) |

#### Documentation

| File | Change |
|------|--------|
| `doc/Project Specification. SPWS Automated Ranklist System.md` (lines 1340–1354) | Update mermaid state diagram: add `PLANNED→IN_PROGRESS`, `IN_PROGRESS→PLANNED`, `COMPLETED→IN_PROGRESS`, `COMPLETED→PLANNED`; remove `COMPLETED→[*]`; add note about UI date-aware locking |
| `doc/Project Specification. SPWS Automated Ranklist System.md` (Appendix D) | vitest count +3 (net: rewrite 9.49 + add 9.87–9.89) |
| RTM FR-23 | No change needed — already references 9.86–9.90 |

#### Execution Order

1. Write tests → run → confirm RED
2. Implement `getAvailableStatuses()` → run → confirm GREEN
3. Update spec state diagram + Appendix D
4. Update this development_history.md entry with implementation notes

#### Implementation Notes (2026-04-11)

- **RED:** 4 tests failed as expected (9.49 rewrite + 9.87–9.89 new)
- **GREEN:** All 215 vitest tests pass after replacing `VALID_TRANSITIONS` with `getAvailableStatuses(event)`
- **Spec:** Updated mermaid state diagram (added ADR-025 rollback transitions, `PLANNED→IN_PROGRESS` auto-ingestion); added UI date-aware locking note
- **Appendix D:** vitest 212→215, total 727→730
- **RTM FR-23:** No change needed — already references 9.86–9.90
- **No new ADR:** UI bugfix aligning with existing ADR-025 DB capabilities

### Bug Fix: Season scoring config inheritance (2026-04-11)

**Problem:** New seasons created via `fn_create_season` got `json_ranking_rules = NULL` in their auto-created `tbl_scoring_config` row. This caused rolling carry-over (ADR-018) to never activate — the ranking function fell into the legacy code path where rolling is not supported.

**Root cause:** The `fn_auto_create_scoring_config` trigger only inserted `id_season`, relying on column defaults. Since `json_ranking_rules` defaults to NULL, new seasons always lacked the JSONB bucket rules required for rolling.

**Fix:** Migration `20260411000002` — trigger now copies `json_ranking_rules` and `bool_show_evf_toggle` from the most recent previous season. Includes data patch for existing season SPWS-2026-2027.

- **RED:** Test 9.40 failed (`json_ranking_rules not copied to new season`)
- **GREEN:** All 240 pgTAP assertions pass after migration applied
- **RTM:** FR-21 tests column updated (added 9.40)
- **Appendix D:** pgTAP 239→240, T9.1 23→24
- **ADR-018:** Added prerequisite note about `fn_auto_create_scoring_config` copying rules

### Auto-Active Season by Date + Overlap Constraint + Punktacja Relocation (2026-04-11)

**ADR-031:** `bool_active` on `tbl_season` is now auto-derived from dates. Primary rule: `dt_start <= TODAY <= dt_end`. Fallback: nearest future season. Eliminates admin overhead for season transitions.

**Changes:**
- Migration `20260411000003`: `fn_refresh_active_season()` function + `trg_season_refresh_active` trigger + `excl_season_date_overlap` exclusion constraint (btree_gist). Dropped `idx_season_active` partial unique index.
- Frontend: `refreshActiveSeason()` called on app load for midnight boundary handling
- Frontend: Punktacja menu item removed from sidebar; gear button added to each season row in SeasonManager, opens ScoringConfigEditor inline below the season list
- Frontend: Friendly error message for overlapping season dates
- Updated tests: 1.7 (exclusion constraint check), 1.15 (overlap rejection), 9.41-9.46 (auto-active logic), 10.23-10.24 (explicit season ID for carry-over)

**TDD:**
- **RED:** 6 new pgTAP tests failed (fn_refresh_active_season not found, exclusion_violation not raised)
- **GREEN:** All 246 pgTAP + 215 vitest tests pass
- **RTM:** FR-21, FR-22 updated; Appendix C: added ADR-031; Appendix D: pgTAP 240->246, T9.1 24->30
- **ADRs updated:** ADR-018 (prerequisite note + ADR-031 ref), ADR-025 (ADR-031 note), ADR-027 (ADR-031 note)

**Design decision:** Future (not yet active) seasons intentionally show an empty ranklist. Rolling carry-over only kicks in when the season actually becomes active. This is by design — documented in ADR-018 (point 6), ADR-031 (consequences), and FR-65 (RTM).

---

### Drilldown Mobile Card Layout (ADR-032) — 2026-04-11

| Feature | Description | Date | ADR |
|---------|-------------|------|-----|
| Drilldown Mobile Card Layout | Dual-render table + card layout in DrilldownModal; CSS media query (`max-width: 600px`) shows cards on mobile, hides table; all 11 data fields preserved; 14 new vitest assertions (C.1–C.14) | 2026-04-11 | ADR-032 |

**Problem:** The 7-column tournament table in DrilldownModal overflows on 375px mobile screens (`min-width: 480px`), especially in +EVF mode with two tables. Users must rotate to landscape.

**Approach:** Render both `<table>` and `.card-list` in DOM. CSS media query swaps visibility. No JS viewport detection. Existing tests unaffected (jsdom ignores CSS).

**Changes:**
- `DrilldownModal.svelte`: New `{#snippet tournamentCards(rows)}` with `.result-card` per tournament; card CSS (65 lines); `@media (max-width: 600px)` hides table, shows cards; removed `table { min-width: 480px }` mobile override
- `DrilldownModal.test.ts`: 14 new tests (C.1–C.14) covering all card elements: tournament code (text + link), location, date, type badge, place/N, multiplier, points+marker, carried class, carried badge, KADRA vs PPW card-list count

**TDD:**
- **RED:** 14 new tests failed (`.card-list` not found, `.result-card` elements missing)
- **GREEN:** All 229 vitest tests pass (215 existing + 14 new)
- **RTM:** NFR-09 updated (Not tested → Covered); Appendix C: added ADR-032; Appendix D: vitest 215→229, total 730→744
- **Coverage:** NFR-09 (Mobile responsive ≥ 375px) now covered by C.1–C.14

---

## Archived Documents

The following documents contain the original detailed plans. They are superseded by this history and the Project Specification:

- `doc/POC_development_plan.md` — POC milestones M0–M6 (archived)
- `doc/MVP_development_plan.md` — MVP milestones M8–M10 (archived)
- `doc/Go-to-PROD.md` — Go-to-PROD items 2.1–2.9 (archived)
