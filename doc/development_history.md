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

### Fencer Gender + Identity Manager Enhancement (ADR-033, ADR-034) — 2026-04-11

| Feature | Description | Date | ADR |
|---------|-------------|------|-----|
| Fencer Gender Column | `enum_gender` on `tbl_fencer`, backfilled from tournament participation (majority vote); authoritative source — never overwritten by import | 2026-04-11 | ADR-033 |
| Identity Manager Redesign | Card-based layout with inline edit form: fencer dropdown (suggested/create new/search), always-editable fields (SURNAME forced ALL CAPS, first name, gender, birth year), inline error display, form stays open on error, auto-closes on success | 2026-04-12 | ADR-033 |
| Widened Identity RPCs | `fn_approve_match`, `fn_dismiss_match`, `fn_create_fencer_from_match` now accept AUTO_MATCHED status; `fn_create_fencer_from_match` accepts gender parameter; new `fn_update_fencer_gender` RPC | 2026-04-11 | ADR-033 |
| Cross-Gender Scoring Rules | Documented asymmetric rules: man in women's → never counts; woman in men's → moved to women's ranklist if no women's tournament exists, else dropped. Enforcement deferred. | 2026-04-11 | ADR-034 |

**Problem:** The Identity Manager had limited actions (approve only PENDING, create-new only UNMATCHED domestic). No way to reassign matches to different fencers. No gender tracking on fencers led to a woman appearing in men's sabre rankings.

**Approach:** Add `enum_gender` column with backfill. Redesign Identity Manager as card-based layout with unified inline edit form per candidate (replaces separate modal dialogs). Dropdown selects fencer source (suggested match / create new / search), all fields always editable, surname forced ALL CAPS. Form stays open on error, auto-closes on successful status change. Document cross-gender scoring rules as ADR-034 (deferred enforcement, gender mismatch is informational per ADR-034).

**Changes:**
- Migration `20260412000001`: ALTER TABLE + backfill + 4 RPCs (CREATE OR REPLACE + new fn_update_fencer_gender) + updated vw_match_candidates
- `IdentityManager.svelte`: complete rewrite — card layout, inline edit form with fencer dropdown + search panel, always-editable fields, SURNAME ALL CAPS, error banner, auto-close on status change
- `CreateFencerModal.svelte` (new): standalone form modal (kept for potential reuse)
- `FencerSearchModal.svelte` (new): standalone search modal (kept for potential reuse)
- `App.svelte`: allFencers state, loadAllFencers, handleAssignFencer, handleUpdateFencerGender, handleCreateNewFencer (now accepts form data), identityError state
- `api.ts`: fetchAllFencers, updateFencerGender, createFencerFromMatch with gender
- `types.ts`: FencerListItem, MatchCandidate + gender fields
- Locale keys: 11 new identity_ keys (en + pl)
- Mockup: `doc/mockups/identity-edit-form.html`

**TDD:**
- **RED:** 8 pgTAP + 12 vitest new assertions failed
- **GREEN:** All 254 pgTAP + 241 vitest pass
- **RTM:** FR-07 tests updated; FR-56 tests expanded (9.83–9.88, 11.13–11.19); new FR-92 added; ADR-033+034 in Appendix C; Appendix D: pgTAP 246→254, vitest 229→241, total 744→771
- **Coverage:** FR-92 (Fencer gender) covered by 11.16–11.19, 9.85–9.86, 9.89–9.94

### Fencers View with Tabs (ADR-035) — 2026-04-12

| Feature | Description | Date | ADR |
|---------|-------------|------|-----|
| Fencers View | Renamed `admin_identities` → `admin_fencers`; tab bar inlined in App.svelte with fencer count header; sticky tab bar + filter rows | 2026-04-12 | ADR-035 |
| Identities Tab | Existing IdentityManager preserved with zero logic changes, rendered as Tab 1 | 2026-04-12 | ADR-035 |
| Birth Year Review Tab | Full fencer list with filters (birth year status + gender), search, expandable edit form with gender dropdown + birth year + accuracy, tournament history grouped by season, birth year hints + auto-suggest, age category inconsistency flag, form closes on Save/Cancel | 2026-04-12 | ADR-035 |
| fn_update_fencer_birth_year | New RPC for admin birth year + estimated flag edits | 2026-04-12 | ADR-035 |

**Problem:** Auto-created fencers had estimated or missing birth years with no admin workflow to review and confirm them. The Identity Manager was a single-purpose view that couldn't accommodate fencer data quality tasks.

**Approach:** Consolidate fencer-related admin work into a tabbed "Fencers" view. Tab bar inlined in App.svelte (a separate FencerView.svelte wrapper was attempted but caused Svelte 5 `state_unsafe_mutation` — `Array.sort()` inside `$derived` mutates reactive state; fixed with `[...list].sort()` and inlined approach). Tab 1 renders IdentityManager (zero changes). Tab 2 adds BirthYearReview with tournament history context, age category hints, gender edit, and inconsistency detection. All UI text internationalized via `t()`. Conflict-scanned all 34 existing ADRs — zero conflicts.

**Changes:**
- `BirthYearReview.svelte` (new): fencer list with filters/search, expandable edit form (gender dropdown + birth year + accuracy), tournament history grouped by season, birth year hint + auto-suggest, inconsistency flag, sticky filter bar, form closes on Save/Cancel
- `App.svelte`: tab bar with Identities/Birth year review, fencer count header, sticky positioning; new handlers for birth year update + gender update + tournament history fetch
- Migration `20260412000004`: `fn_update_fencer_birth_year(p_fencer_id, p_birth_year, p_estimated)`
- `Sidebar.svelte`: `admin_identities` → `admin_fencers`
- `IdentityManager.svelte`: sticky filter bar added
- `types.ts`: AppView updated, new `FencerTab`, `BirthYearFilter`, `FencerTournamentRow` types; `FencerListItem` extended with `bool_birth_year_estimated`, `txt_nationality`
- `api.ts`: `fetchFencerTournamentHistory`, `updateFencerBirthYear`, extended `fetchAllFencers`
- Locale keys: 16 new keys (en + pl), `nav_admin_identities` removed
- **Svelte 5 lesson:** Never call `.sort()` on reactive arrays inside `$derived` — use `[...array].sort()` to avoid `state_unsafe_mutation`

**TDD:**
- **RED:** 5 pgTAP + 14 vitest new assertions failed
- **GREEN:** All 259 pgTAP + 255 vitest pass
- **RTM:** FR-56 updated (tab in App.svelte); new FR-93 added; ADR-035 in Appendix C; Appendix D: pgTAP 254→259, vitest 241→255, total 771→790
- **Coverage:** FR-93 covered by 9.100–9.113, 13.1–13.4; UC16 partially implemented (birth year + gender editing; merge deferred)

### Cross-Gender Scoring Enforcement (ADR-034) — 2026-04-12

| Feature | Description | Date | ADR |
|---------|-------------|------|-----|
| fn_effective_gender | Pure SQL helper computing effective ranklist gender per ADR-034 asymmetric rules: normal match, man-in-F (dropped), woman-in-M without F sibling (reassigned to F), woman-in-M with F sibling (dropped) | 2026-04-12 | ADR-034 |
| Ranking function updates | All 4 ranking functions (`fn_ranking_ppw`, `fn_ranking_kadra`, `fn_fencer_scores_rolling`, `fn_category_ranking`) filter on `fn_effective_gender()` instead of raw `t.enum_gender` | 2026-04-12 | ADR-034 |
| PPW5 sabre seed data | PPW5-V1-M-SABRE-2025-2026 (Gdańsk, 2026-04-11): SAMECKA-NACZYŃSKA Martyna as sole participant — first real cross-gender case in seed data | 2026-04-12 | ADR-034 |
| Calendar filter fix | Time filter dropdown (All/Past/Future) now also filters event boxes at the top, matching the SPWS/+EVF toggle behaviour | 2026-04-12 | — |

**Problem:** SAMECKA-NACZYŃSKA Martyna (F) appeared in the M sabre V1 ranklist on CERT because she was the sole participant in PPW5-V1-M-SABRE-2025-2026 (a joined tournament). ADR-034 documented the rules but enforcement was deferred to manual admin review.

**Approach:** Automated enforcement at ranking query time via `fn_effective_gender` helper function. The helper encodes all 4 ADR-034 rules in a single CASE expression. The EXISTS subquery (sibling tournament check) only fires for the rare cross-gender mismatch case — normal results short-circuit. Scores are not recalculated (ADR-002 respected); only ranklist assignment changes. Each ranking function's `AND t.enum_gender = p_gender` replaced with a one-line `fn_effective_gender(...)` call (10 filter sites across 4 functions).

**Changes:**
- Migration `20260412000005`: `fn_effective_gender` + DROP/CREATE of `fn_ranking_ppw`, `fn_ranking_kadra`, `fn_fencer_scores_rolling`; CREATE OR REPLACE of `fn_category_ranking` (added `tbl_fencer` join). Includes IN_PROGRESS carry-over fix from migration `000006` (which the DROP/CREATE would otherwise undo).
- `supabase/data/2025_2026/v1_m_sabre.sql`: PPW5 seed data with Martyna's cross-gender result
- `supabase/data/2025_2026/zz_events_metadata.sql`: PPW5 status SCHEDULED → COMPLETED
- `supabase/tests/09_rolling_score.sql`: cascade-safe DELETE for PPW5 event (FK from new tournament)
- `frontend/src/components/CalendarView.svelte`: time filter applied to event boxes (positionSlots)

**TDD:**
- **RED:** 9 pgTAP tests failed (fn_effective_gender does not exist)
- **GREEN:** All 268 pgTAP + 269 pytest + 255 vitest pass
- **RTM:** FR-92 tests expanded (14.CG1–14.CG9); ADR-034 status Deferred→Implemented in Appendix C; Appendix D: pgTAP 259→268, total 790→799
- **Coverage:** FR-92 (Cross-gender scoring) fully covered by fn_effective_gender unit tests + ranking integration tests

### Multi-Slot Event Result URLs (ADR-040) — 2026-04-25

| Feature | Description | Date | ADR |
|---------|-------------|------|-----|
| `tbl_event.url_event_2..5` | 4 nullable TEXT columns alongside the existing `url_event`. Up to 5 result-platform URL slots per event. Slots are equal-status — no role labels, no per-slot enum, no primary pointer. | 2026-04-25 | ADR-040 |
| `fn_compact_urls(VARIADIC TEXT[])` | Pure helper. Trim → drop empty → dedupe first-occurrence → pad NULL to length 5. Shared by `fn_create_event`, `fn_update_event`, `fn_refresh_evf_event_urls`. Compact-on-save guarantees: *if any URL is set, slot #1 (`url_event`) is set.* | 2026-04-25 | ADR-040 |
| EventManager.svelte form | URL section with slot #1 visible (primary cyan border) and slots #2–5 behind a disclosure (auto-opens when any of #2–5 has content; filled-count display). Save handler compacts before calling `oncreate`/`onupdate`. | 2026-04-25 | ADR-040 |
| `discover_tournament_urls_for_event` | New entry point in `populate_tournament_urls.py`. Iterates non-null slots, runs platform-detect-and-discover per URL, merges per-(weapon,gender,category) results dedupe-first-occurrence. Logs warning on collision. | 2026-04-25 | ADR-040 |
| promote.py calendar mode | `_read_cert_evf_events` SQL extended to select all 5 slots; `_build_refresh_payload` ships `url_event_2..5` keys to PROD. Per-slot NULL-only invariant + post-write recompact preserve admin-edit protection. | 2026-04-25 | ADR-040 |

**Problem:** EVF Circuit Budapest 2025-09-20/21 had three organiser-published Engarde URLs (one per weapon: `pbt`/`kard`/`tor`). Our schema modelled `tbl_event.url_event` as a single TEXT column, so ADR-029's `populate-urls.yml` could only auto-populate one weapon's tournaments; the other ~20 had to be entered manually. The same shape recurs for any event the organiser splits across multiple platform URLs (per-weapon, per-day, or per-day×weapon).

**Approach:** Additive schema extension — 4 nullable columns, not an array or child table. Compact-on-save makes "URL #1 = canonical primary" a structural invariant rather than coincidence, so every existing `url_event`-dependent code path (calendar 🔗 link, ⬇ Import button, ADR-029 auto-populate seed, ADR-028 refresh write order) keeps working unchanged. Slot positions are non-semantic; admin's choice of "which slot got cleared" carries no information worth preserving across edits.

**Changes:**
- Migration `20260425000001_event_multi_url.sql`: 4 ALTER TABLEs, `fn_compact_urls`, fn_create_event/fn_update_event recreated with 4 new params, fn_refresh_evf_event_urls extended with per-slot NULL-only invariant + post-write compact.
- `supabase/tests/15_event_multi_url.sql`: 6 new pgTAP assertions (15.1–15.6).
- `frontend/src/lib/types.ts`: 4 fields on `CalendarEvent`, 4 on `Create/UpdateEventParams`.
- `frontend/src/lib/api.ts`: pass `p_url_event_2..5` in createEvent / updateEvent.
- `frontend/src/lib/locales/{en,pl}.json`: 5 new keys.
- `frontend/src/components/EventManager.svelte`: 5-slot URL section, disclosure, filled-count, `compactUrls` helper, primary marker on slot #1.
- `frontend/tests/EventManager.test.ts`: 6 new vitest cases (9.44a–9.44f).
- `python/tools/populate_tournament_urls.py`: `discover_tournament_urls_for_event` + main() reads all 5 slots.
- `python/pipeline/promote.py`: SQL select extended; `_build_refresh_payload` ships all 5 slots.
- `python/tests/test_url_discovery.py`: 3 new pytest cases (3.16k–3.16m).
- `python/tests/test_promote.py`: 1 new case (prom.8).
- `doc/mockups/m12_event_edit_multi_url.html`: dual-state mockup (typical 1-URL + Budapest 3-URL).

**TDD:**
- **RED:** 6 pgTAP + 6 vitest + 4 pytest assertions failed (column missing, fn_compact_urls absent, form lacks slots #2–5, multi-slot discovery absent, refresh payload missing keys).
- **GREEN:** 292 pgTAP + 314 pytest (9 skipped) + 273 vitest pass.
- **RTM:** FR-48 updated (12 tbl_event extension columns); FR-98 added; ADR-040 in Appendix C; Appendix D: pgTAP 286→292, pytest 310→314, vitest 267→273, total 870→886.
- **Coverage:** FR-98 fully covered (15.1–15.6 + 9.44a–f + 3.16k–m + prom.8).

---

## Archived Documents

The following documents contain the original detailed plans. They are superseded by this history and the Project Specification:

- `doc/POC_development_plan.md` — POC milestones M0–M6 (archived)
- `doc/MVP_development_plan.md` — MVP milestones M8–M10 (archived)
- `doc/Go-to-PROD.md` — Go-to-PROD items 2.1–2.9 (archived)
