# MVP Development Plan — SPWS Automated Ranklist System

## 1. MVP Overview

### 1.1 Goals

Replace the Excel system for all 30 sub-rankings with a fully operational web-based ranking system deployed on the SPWS WordPress site.

### 1.2 Scope

All 30 sub-rankings (3 Weapons × 2 Genders × 5 Categories V0–V4). Combined V3+4-F category for women. V0 is domestic-only — no Kadra ranking.

### 1.3 Pre-requisites (from POC — completed 2026-03-25)

The POC (M0-M6) established the foundation. **236 test assertions** across 3 suites:

| Suite | Count | Files |
|-------|-------|-------|
| pgTAP | 117 | `supabase/tests/` — 00_smoke, 01_database_foundation, 02_scoring_engine, 03_views_api |
| pytest | 91 | `python/tests/` — test_smoke, test_calibration, test_scrapers, test_matcher |
| vitest | 28 | `frontend/tests/` — smoke, api, export, FilterBar, RanklistTable, DrilldownModal |
| **Post-M8** | **331** | **+95 assertions (135 pgTAP, 94 pytest, 95 vitest, 7 Playwright)** |

**Validated capabilities:**
- **Scoring engine** — log-formula place points, DE bonus, podium bonus, multipliers; calibrated against `reference/SZPADA-2-2024-2025.xlsx` within 0.01 tolerance
- **Scrapers** — FTL (JSON+CSV), Engarde (HTML), 4Fence (HTML), CSV upload
- **Identity resolution** — RapidFuzz matching, alias support, age-category disambiguation, domestic auto-create, international skip
- **Web Component** — PPW/Kadra toggle, V0 guard, drilldown modal, ODS export, EN/PL i18n
- **Ranking views** — `fn_ranking_ppw` (best-K domestic + always-include MPW), `fn_ranking_kadra` (domestic + best-J international), JSONB bucket rules
- **Release pipeline** — LOCAL→CERT→PROD with schema fingerprinting (ADR-011)
- **Schema** — 14 SQL migrations, `tbl_event`/`tbl_tournament` hierarchy, audit logging, RLS policies

### 1.4 Milestones

| # | Milestone | Key Deliverables |
|---|-----------|-----------------|
| M8 | Multi-Category Data + Calendar UI + Schema Extensions | 30-category seed data, Calendar view (`<spws-calendar>`), 4 new `tbl_event` columns, Shadow DOM for `<spws-ranklist>` + `<spws-calendar>`, admin password gate, scoring config editor |
| M9 | Ingestion Pipeline + Admin CRUD + Identity Resolution Admin | `ingest.yml`, orchestration script, CRUD UI for seasons/events/tournaments, identity admin UI, re-import, Discord alerts |

### 1.5 Architecture Decisions

| ADR | Title | Scope |
|-----|-------|-------|
| [ADR-013](adr/013-poc-mvp-transition.md) | POC-to-MVP Transition | Project phasing |
| [ADR-014](adr/014-delete-reimport-strategy.md) | Delete + Re-import in Transaction | UC23 re-import |
| [ADR-004](adr/004-single-admin-account.md) | ~~Single Admin Account~~ (Superseded by ADR-016) | Auth model |
| [ADR-016](adr/016-supabase-auth-totp-mfa.md) | Supabase Auth + TOTP MFA for Admin Access | Auth model |
| [ADR-007](adr/007-shadow-dom-deferred.md) | Shadow DOM (target: M8) | CSS isolation |
| [ADR-015](adr/015-m8-ui-design-decisions.md) | M8 UI Design Decisions | All 7 approved mockups |

### 1.6 POC Test Gaps Carried Forward

These items from the POC Known Test Gaps carry forward to MVP milestones:

| RTM ID | Requirement | Target |
|--------|-------------|--------|
| FR-10 | Birth year estimation (V1, V3 untested) | M9 |
| FR-14 | Tournament multipliers (no MSW scoring test) | M9 |
| FR-23 | Event lifecycle (CHANGED state untested) | M9 |
| FR-40 | Import status transition to IMPORTED | M9 |
| FR-42 | CERT/PROD env toggle tests | ~~M8~~ **DONE** (T8.0) |
| NFR-10 | Pipeline observability (structured logs) | M9 |
| NFR-13 | Shadow DOM isolation | ~~M8~~ **DONE** (T8.7) |

---

## 2. Milestone Details

### M8: Multi-Category Data + Calendar UI + Schema Extensions

**Status: COMPLETED (2026-03-26)**

**Implementation notes:**
- 9 tasks (T8.0–T8.8) executed sequentially in strict TDD (RED→GREEN→refactor)
- Detailed plan in `.claude/plans/rosy-bouncing-kitten.md` — 75 acceptance tests defined, 72 implemented (3 integration tests deferred)
- Sidebar admin items (Sezony, Wydarzenia, Tożsamości) are navigation placeholders for M9

**Test results after M8:**

| Suite | POC | M8 New | Total |
|-------|-----|--------|-------|
| pgTAP | 117 | 18 | 135 |
| pytest | 91 | 3 | 94 |
| vitest | 28 | 69 | 97 |
| Playwright | 0 | 7 | 7 |
| **Total** | **236** | **97** | **333** |

**Tasks completed:**

| Task | Scope | Key Files |
|------|-------|-----------|
| T8.0 | CERT/PROD env toggle tests (FR-42) | `tests/env-toggle.test.ts` |
| T8.1 | tbl_event schema extension (FR-48) | `migrations/20260326000001_event_schema_extension.sql`, `tests/04_event_schema_extension.sql` |
| T8.2 | Calendar API view (FR-43, FR-44) | `migrations/20260326000002_calendar_view.sql`, `tests/05_calendar_view.sql` |
| T8.3 | Multi-category seed data (FR-52) | `data/2024_25/*.sql` (27 files), `tests/06_multi_category.sql` |
| T8.4 | App shell + sidebar (FR-59) | `Sidebar.svelte`, `App.svelte` refactor, `tests/Sidebar.test.ts`, `tests/AppShell.test.ts` |
| T8.5 | Calendar view component (FR-43–45) | `CalendarView.svelte`, `tests/CalendarView.test.ts` |
| T8.6 | Admin password gate (FR-46) | `AdminPasswordModal.svelte`, `AdminFloatingToolbar.svelte`, `tests/admin.test.ts` |
| T8.8 | Scoring config editor (FR-61) | `ScoringConfigEditor.svelte`, `tests/ScoringConfigEditor.test.ts` |
| T8.7 | Shadow DOM + CE build (NFR-13) | `vite.config.ce.ts`, `src/ce/`, `main.ce.ts`, `e2e/shadow-dom.spec.ts` |

**Scope:**
- Seed data for all 30 categories (3 weapons × 2 genders × 5 age categories) from `doc/external_files/` Excel files
- Calendar view: vertical chronological event browser, season filter, past/future/all toggle
- `<spws-calendar>` custom element with Shadow DOM
- `<spws-ranklist>` rebuilt as custom element with Shadow DOM (ADR-007)
- 4 new `tbl_event` columns: `txt_country`, `txt_venue_address`, `url_invitation`, `num_entry_fee`
- Admin password gate (ADR-004 pattern) for edit access — **superseded by ADR-016 (Supabase Auth + TOTP MFA) in M9**
- Two-view app navigation: Ranklist | Calendar
- CERT/PROD env toggle tests (FR-42)
- Scoring config editor: structured form with 5 sections, per-season, bucket editor for ranking rules

**UI design (all mockups APPROVED — see `doc/mockups/`):**

| Mockup | File | Key Decisions |
|--------|------|---------------|
| App Shell | `m8_app_shell.html` | Sidebar drawer via ☰, "SPWS" brand, Ranklista + Kalendarz items |
| Calendar View | `m8_calendar_view.html` | Vertical timeline with month headers, color-coded dots, "Komunikat organizatora" link |
| Admin Gate | `m8_admin_gate_v2.html` | `?admin=1` URL param, password modal, 120min timeout, floating toolbar + sidebar admin section |
| EVF Import | `m8_evf_import.html` | Gold "🌍 Import EVF" button on Calendar, checklist modal, deduplication *(implementation: M9)* |
| Tournament Mgmt | `m8_tournaments.html` | Accordion layout, two import paths (event-level batch + tournament-level single), manual "+ Dodaj turniej" *(implementation: M9)* |
| Identity Resolution | `m8_identity_resolution.html` | Match candidate queue, approve/disambiguate/create-new/dismiss modals, confidence color-coding *(implementation: M9)* |
| Scoring Config | `m8_scoring_config_A_form.html` | Structured form with 5 collapsible sections, per-season config, bucket editor |
| Auth MFA Flow | `m9_auth_mfa_flow.html` | Sign-in (email+password), MFA enrollment (QR), TOTP challenge (6-digit), authenticated admin session (ADR-016) |

**Key UI/UX decisions from mockups:**
- **Sidebar navigation:** Ranklista, Kalendarz, hr divider, Administracja (Sezony, Wydarzenia, Tożsamości), session timer + Wyloguj
- **Two import paths:** Event-level ⬇ Import (multi-select modal with event URL) + Tournament-level ⬇ (single tournament's own URL/file)
- **Both import modals** have two tabs: 🔗 Z adresu URL and 📁 Z pliku (Excel/JSON/CSV)
- **Manual tournament creation** supported via "+ Dodaj turniej" inside expanded event
- **Identity resolution queue:** Default filter PENDING, stats bar, three actions (Zatwierdź, Nowy zawodnik, Odrzuć), disambiguation modal for same-name fencers
- **Polish UI terminology:** "Ranklista" (not "Ranklist"), "Komunikat organizatora" (not "Zaproszenie")

### M9: Ingestion Pipeline + Admin CRUD + Identity Resolution Admin

**TBD** — Detailed acceptance tests, implementation plan, and verification criteria to be defined in a separate planning session.

**High-level scope:**
- **Admin auth migration (ADR-016):** Replace client-side password gate with Supabase Auth + TOTP MFA. REVOKE write functions from `anon`/`PUBLIC`. Multi-admin support. 59-min inactivity timeout. Rewrite tests 8.48–8.54. Mockup: `m9_auth_mfa_flow.html`
- Automated ingestion pipeline (`ingest.yml`): scheduled + manual dispatch
- Orchestration script: scrape → match → score for all categories
- Discord alerting on failure or new pending matches
- Run summary JSON artifact
- Admin CRUD UI for seasons, events, tournaments (auth-gated via ADR-016) — UI designed in M8 mockups (`m8_tournaments.html`)
- Identity resolution admin UI (approve/dismiss/create-new from `tbl_match_candidate`) — UI designed in M8 mockups (`m8_identity_resolution.html`)
- Tournament re-import: delete + re-import in transaction (ADR-014) — two paths: event-level batch + tournament-level single
- Import from file (Excel/JSON/CSV) alongside URL scraping
- Delete cascade (event → tournaments → results)
- Manual tournament creation (+ Dodaj turniej)
- EVF calendar import: fetch veteransfencing.eu, deduplication, create events+tournaments — UI designed in M8 mockups (`m8_evf_import.html`)
- POC test gap coverage (FR-10, FR-14, FR-23, FR-40, NFR-10)

---

## 3. FR-to-Milestone Mapping

Quick reference — full details in [RTM (Appendix C)](Project%20Specification.%20SPWS%20Automated%20Ranklist%20System.md#appendix-c--requirements-traceability-matrix).

### M8 Requirements

| FR | Requirement | Source |
|----|-------------|--------|
| FR-42 | CERT/PROD env toggle tests (POC gap) | §2.2 |
| FR-43 | Calendar view: chronological event list with season filter | UC21(a,b) |
| FR-44 | Calendar view: past/future/all toggle | UC21(c) |
| FR-45 | Calendar view: mobile-friendly layout | UC21(e) |
| FR-46 | Admin auth: Supabase Auth + TOTP MFA (ADR-016, supersedes client-side gate) | UC22(a) |
| FR-48 | tbl_event schema extension: 4 new columns | UC22(c), UC21(d) |
| FR-52 | Multi-category expansion (30 sub-rankings) | §6.2 |
| FR-59 | Two-view app shell: sidebar drawer | UC12, UC21 |
| FR-61 | Scoring config editor (admin, per-season) | UC22(f) |
| FR-62 | Calendar view: completed events show "Wyniki" link to results URL | UC21 |
| NFR-13 | Shadow DOM isolation (POC gap) | §5 |

### M9 Requirements

| FR | Requirement | Source |
|----|-------------|--------|
| FR-46 | Admin auth: Supabase Auth + TOTP MFA (rewrite from M8 client-side gate) | UC22(a), ADR-016 |
| FR-10 | Birth year estimation V1, V3 (POC gap) | §8.5 |
| FR-14 | Tournament multipliers MSW (POC gap) | §8.2 |
| FR-23 | Event lifecycle CHANGED state (POC gap) | UC10 |
| FR-40 | Import status IMPORTED transition (POC gap) | UC1(b) |
| FR-47 | Season CRUD via web UI | UC22(b) |
| FR-49 | Tournament CRUD nested under events | UC22(d) |
| FR-50 | Delete cascade (event → tournaments → results) | UC22(e) |
| FR-51 | Tournament re-import in single transaction | UC23(a-f) |
| FR-53 | Event-level batch import | UC22(g) |
| FR-54 | Tournament-level single import | UC22(h) |
| FR-55 | File import (.xlsx, .xls, .json, .csv) | UC22(i), UC23(c) |
| FR-56 | Identity resolution admin UI | UC4(a-e) |
| FR-57 | Disambiguation modal (same-name fencers) | UC3(f), UC4(b) |
| FR-58 | EVF calendar import | UC8, UC9 |
| FR-60 | Event CRUD via web UI | UC22(c) |
| NFR-10 | Pipeline observability (POC gap) | §10 |

---

## 4. Cross-References

- [Project Specification](Project%20Specification.%20SPWS%20Automated%20Ranklist%20System.md) — Full spec (§6.2 = MVP scope, Appendix C = RTM with FR-01 to FR-60)
- [CI/CD Operations Manual](cicd-operations-manual.md) — Release pipeline (LOCAL→CERT→PROD)
- [POC Development Plan](POC_development_plan.md) — Historical reference only (M0-M6 archived)
- `doc/mockups/` — 7 approved HTML mockups (see §2 M8 mockup table)
- `doc/adr/` — 15 ADRs (see §1.5 for MVP-relevant subset)
