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
| **Post-M8** | **333** | **+97 assertions (135 pgTAP, 94 pytest, 97 vitest, 7 Playwright)** |
| **Post-T9.2** | **370** | **+37 assertions (159 pgTAP, 94 pytest, 110 vitest, 7 Playwright)** |

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

- Detailed plan in `.claude/plans/rosy-bouncing-kitten.md` — 125 acceptance tests across M9a (UI) + M9b (Pipeline)
- Split: **M9a** (T9.0–T9.8) Auth + CRUD SQL + Admin UI; **M9b** (T9.9–T9.14) Pipeline + Test Gaps

**Test results after T9.5:**

| Suite | Post-M8 | M9 New | Total |
|-------|---------|--------|-------|
| pgTAP | 135 | 24 | 159 |
| pytest | 94 | 0 | 94 |
| vitest | 97 | 34 | 131 |
| Playwright | 7 | 0 | 7 |
| **Total** | **333** | **58** | **391**

**Test results after T9.6:**

| Suite | Post-M8 | M9 New | Total |
|-------|---------|--------|-------|
| pgTAP | 135 | 24 | 159 |
| pytest | 94 | 0 | 94 |
| vitest | 97 | 40 | 137 |
| Playwright | 7 | 0 | 7 |
| **Total** | **333** | **64** | **397** |

**Test results after T9.10:**

| Suite | Post-M8 | M9 New | Total |
|-------|---------|--------|-------|
| pgTAP | 135 | 32 | 167 |
| pytest | 94 | 10 | 104 |
| vitest | 97 | 55 | 152 |
| Playwright | 7 | 0 | 7 |
| **Total** | **333** | **97** | **430** |

**Test results after EVF toggle scope change (current):**

| Suite | Post-T9.10 | EVF Toggle | Total |
|-------|------------|------------|-------|
| pgTAP | 167 | +4 | 171 |
| pytest | 104 | 0 | 104 |
| vitest | 152 | +7 | 159 |
| Playwright | 7 | 0 | 7 |
| **Total** | **430** | **+11** | **441** |

**Tasks completed:**

| Task | Scope | Key Files |
|------|-------|-----------|
| T9.0 | Admin Auth Migration (FR-46, ADR-016): REVOKE write functions from anon, Supabase Auth + TOTP MFA sign-in flow, 59min timeout | `migrations/20260327000001_revoke_write_functions.sql`, `tests/07_auth_revoke.sql`, `admin-auth.svelte.ts`, `AdminSignInModal.svelte`, `AdminMfaEnrollModal.svelte`, `AdminMfaChallengeModal.svelte` |
| T9.1 | CRUD SQL + Delete Cascade (FR-47, FR-49, FR-50, FR-60): 7 CRUD functions + 2 cascade functions, all SECURITY DEFINER + REVOKE/GRANT | `migrations/20260327000002_crud_functions.sql`, `migrations/20260327000003_delete_cascade.sql`, `tests/08_crud_functions.sql` |
| T9.2 | Season CRUD UI (FR-47): SeasonManager component with list/create/edit/delete, 3 API functions, admin guard | `SeasonManager.svelte`, `SeasonManager.test.ts`, `api.ts` |
| T9.3 | Event CRUD UI (FR-60): EventManager component with list/create/edit/delete, status transitions, organizer select, 5 API functions, admin guard | `EventManager.svelte`, `EventManager.test.ts`, `api.ts`, `types.ts` |
| T9.4 | Tournament CRUD UI (FR-49): TournamentManager component with list/create/edit/delete, enum selects, import status badges, edit restricted to import fields, 4 API functions, admin guard | `TournamentManager.svelte`, `TournamentManager.test.ts`, `api.ts`, `types.ts` |
| T9.5 | Tournament File Import UI (FR-54 partial): TournamentImportModal with file drop zone, NOWY/REIMPORT badges, ADR-014 warning banner, drag-and-drop + browse, .xlsx/.xls/.json/.csv support | `TournamentImportModal.svelte`, `TournamentImportModal.test.ts`, `pl.json`, `en.json` |
| T9.6 | Event Batch Import UI | `EventImportModal.svelte` | 6 vitest (9.62–9.67) |
| T9.7 | Identity Resolution Admin UI | IdentityManager.svelte, DisambiguationModal.svelte | 10 vitest (9.68–9.77) |
| T9.8 | Sidebar Wiring + Admin View Routing: Extended AppView type, added click handlers to 4 admin sidebar buttons, active state highlighting | `Sidebar.svelte`, `types.ts`, `AdminRouting.test.ts` | 5 vitest (9.78–9.82) |
| T9.9 | POC Test Gap Coverage: V1/V3 birth year (FR-10), MSW multiplier (FR-14), CHANGED event state (FR-23), import status transitions (FR-40) | `test_matcher.py`, `01_database_foundation.sql`, `02_scoring_engine.sql` | 2 pytest (9.83–9.84), 8 pgTAP (9.85–9.92) |
| T9.10 | File Import Parsers (FR-55): parse_file dispatcher (.csv/.xlsx/.xls/.json), xlsx_parser (openpyxl + xlrd), json_parser with key normalization, xlrd dep added | `file_import.py`, `xlsx_parser.py`, `json_parser.py`, `test_file_import.py` | 8 pytest (9.93–9.100) |

**Implementation notes (T9.4):**
- Props-driven component pattern (same as EventManager): `tournaments`, `eventId`, `isAdmin`, `oncreate`/`onupdate`/`ondelete` callbacks
- Create form has 6 enum selects (type, weapon, gender, age_category) + code, name, date, participants, url_results
- Edit form restricted to import-related fields only: `url_results`, `import_status`, `status_reason` (core metadata immutable)
- Import status badges: SCORED=green, IMPORTED=blue, PENDING=yellow, PLANNED=gray, REJECTED=red

**Implementation notes (T9.5):**
- File-only import modal (URL scraping deferred to later task)
- Props: `tournament`, `open`, `onimport(tournamentId, file)`, `onclose` — callback passes file to parent for actual parsing/DB work
- `isReimport` derived from `enum_import_status === 'IMPORTED' || 'SCORED'` — shows yellow ADR-014 warning banner explaining existing results will be deleted before re-import
- File drop zone with drag-and-drop + click-to-browse, hidden `<input type="file">` with accept=".xlsx,.xls,.json,.csv"
- 8 new i18n keys (import_title, import_file_drop, import_file_formats, import_btn, import_cancel, import_status_new, import_status_reimport, import_reimport_warning)
- Type badges: PPW=green, MPW=blue, PEW/MEW/MSW/PSW=gold
- 4 new API functions: `fetchTournaments`, `createTournament`, `updateTournament`, `deleteTournamentCascade`
- 4 new types: `Tournament`, `ImportStatus`, `CreateTournamentParams`, `UpdateTournamentParams`
- 14 new i18n keys in both `pl.json` and `en.json`
- Component not yet wired into App.svelte routing (deferred to T9.8)

**T9.6 — Event Batch Import UI (2026-03-26)**
- Created `EventImportModal.svelte` — multi-select tournament checklist with file drop zone
- Props-driven: `event`, `tournaments[]`, `open`, `onimport(ids[], file)`, `onclose`
- Features: select-all toggle, per-tournament NOWY/REIMPORT badges, ADR-014 warning when reimport selected
- Selection summary in footer, import button disabled when no file or no tournaments selected
- URL scraping deferred (consistent with T9.5)
- 5 new i18n keys in both pl.json and en.json
- 6 vitest assertions (9.62–9.67), 397 total (159 pgTAP + 94 pytest + 137 vitest + 7 Playwright)

**T9.7 — Identity Resolution Admin UI (2026-03-26)**
- Created `IdentityManager.svelte` — match candidate queue with status filter, confidence color coding, approve/dismiss/create-new actions
- Created `DisambiguationModal.svelte` — fencer selection with radio buttons, birth year display, age category match indicator
- Added `MatchStatus`, `MatchCandidate`, `FencerCandidate` types to `types.ts`
- Props-driven: callbacks for `onapprove`, `oncreatenew`, `ondismiss` — DB wiring deferred to orchestration
- 10 new i18n keys in both pl.json and en.json
- 10 vitest assertions (9.68–9.77), 407 total (159 pgTAP + 94 pytest + 147 vitest + 7 Playwright)

**Implementation notes (T9.3):**
- Props-driven component pattern (same as SeasonManager): `events`, `organizers`, `seasons`, `selectedSeasonId`, `isAdmin`, callbacks
- Status transition map mirrors `fn_validate_event_transition` trigger (PLANNED→SCHEDULED/CANCELLED, etc.)
- Status dropdown shows only valid next states per current status
- 5 new API functions: `fetchOrganizers`, `createEvent`, `updateEvent`, `updateEventStatus`, `deleteEventCascade`
- 3 new types: `Organizer`, `CreateEventParams`, `UpdateEventParams`
- 12 new i18n keys in both `pl.json` and `en.json`
- `updateEventStatus` uses direct table UPDATE (trigger validates transitions)
- Component not yet wired into App.svelte routing (deferred to T9.8)

**Implementation notes (T9.2):**
- Props-driven component pattern (same as ScoringConfigEditor): `seasons`, `isAdmin`, `oncreate`/`onupdate`/`ondelete` callbacks
- `data-field` attributes on all interactive elements for test selection
- 3 new API functions: `createSeason`, `updateSeason`, `deleteSeason` using `.rpc()` to T9.1 SQL functions
- 8 new i18n keys in both `pl.json` and `en.json`
- Component not yet wired into App.svelte routing (deferred to T9.8)

**Implementation notes (T9.1):**
- `fn_delete_season` deletes `tbl_scoring_config` first (auto-created by trigger), then season row; FK RESTRICT on `tbl_event` raises if events exist
- `fn_delete_event_cascade` loops child tournaments via `fn_delete_tournament_cascade` (manual cascade, not FK CASCADE, preserves audit trail per ADR-014)
- All 9 functions: REVOKE from `anon, PUBLIC`, GRANT to `authenticated` (ADR-016)

**Scope change (2026-03-29): Season-configurable EVF toggle (ADR-017)**
- FR-34 modified: PPW/Kadra toggle conditional on `bool_show_evf_toggle` in `tbl_scoring_config` (default FALSE = hidden)
- FR-44 modified: Calendar scope filter conditional on same flag
- FR-63 added: Calendar event links (Wyniki + Komunikat) stacked vertically
- FR-64 added: `bool_show_evf_toggle` column + export/import support; admin checkbox in SeasonManager edit form
- New tests: 9.37–9.39 (pgTAP), 8.78–8.83 (vitest); existing 6.10, 6.12, 8.45 modified for config flag
- 8.81–8.83: SeasonManager edit-form checkbox for `show_evf_toggle` (render unchecked, render checked, toggle+save payload)
- Migration: `20260329000002_evf_toggle_config.sql`
- **UI behavior rules** (see ADR-017 for full matrix):
  - Toggle OFF (default): all PPW/Kadra toggles hidden; Ranklist locked to PPW; Calendar shows PPW events only
  - Toggle ON: toggles appear in FilterBar, CalendarView, DrilldownModal; **PPW always default**
  - Mode resets to PPW on every state transition (season change, config save, page load)
  - CalendarView: `!showEvfToggle || scopeFilter === 'ppw'` → filter out international events
  - Admin checkbox lives in SeasonManager edit form (not ScoringConfigEditor); only visible in edit mode, not create

**Post-T9.10 schema extensions (2026-03-27):**
- Added `txt_entry_fee_currency TEXT` to `tbl_event` (migration 000004) + updated CRUD functions (migration 000005)
- Added `arr_weapons enum_weapon_type[]` to `tbl_event` with default `{EPEE,FOIL,SABRE}` (migration 000006) + updated CRUD functions (migration 000007)
- Recreated `vw_calendar` to include both new columns + organizer name join
- Updated `EventManager.svelte`: weapon checkboxes (3× EPEE/FOIL/SABRE), currency select (PLN/EUR/USD), weapons display in event rows
- Updated `CalendarView.svelte`: weapons display below location ("Szpada + Floret + Szabla" format)
- Updated `api.ts` and `types.ts`: `p_weapons` and `p_entry_fee_currency` params in create/update RPC calls
- FR-48 expanded from 4 to 6 columns (RTM updated)

**Admin view wiring completion (2026-03-27):**
- Wired all 4 admin views in `App.svelte` with actual data loading (seasons, events, scoring config, identity candidates)
- Admin session timer moved from `AdminFloatingToolbar` to `Sidebar` (59min countdown + logout button)
- `ScoringConfigEditor` fully i18n-ized (34 new `sc_*` keys in pl.json/en.json)
- Season selector context-aware: triggers appropriate reload per active view

**Remaining scope (M9b):**
- Automated ingestion pipeline (`ingest.yml`): scheduled + manual dispatch (T9.14)
- Orchestration script: scrape → match → score (T9.11)
- EVF calendar import (T9.12, T9.13) — UI designed in M8 mockups (`m8_evf_import.html`)
- Tournament import UI: URL scraping tab (deferred from T9.5/T9.6)

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
