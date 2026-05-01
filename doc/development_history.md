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

### Server-Side Workflow Dispatch via Edge Function (ADR-041) — 2026-04-25

| Feature | Description | Date | ADR |
|---------|-------------|------|-----|
| `dispatch-workflow` Edge Function | Deno function holds the GH PAT as a Supabase env secret (`GH_DISPATCH_PAT`, `GH_REPO`); accepts `{ workflow, inputs }` from authenticated callers; allowlist of two workflows (`populate-urls.yml`, `scrape-tournament.yml`); returns sync `{ ok, runs_url }` after calling GitHub's dispatches API. PAT never appears in browser. | 2026-04-25 | ADR-041 |
| `requestDispatch()` API | Frontend helper calling `supabase.functions.invoke('dispatch-workflow', ...)`. Caller's session JWT auto-attached. Returns `DispatchResult` typed union. | 2026-04-25 | ADR-041 |
| EventManager inline status | Per-event-row dispatch status (pending → success-with-link → error) rendered below the event-row, above the tournament-list. Auto-clears 5 minutes after terminal state. Multiple events can show independent statuses. | 2026-04-25 | ADR-041 |
| Removed: `github-pat` / `github-repo` HTML attributes | Stripped from `<spws-ranklist>` web component (App.svelte props + index.html). PAT never lives in HTML again. `triggerGitHubWorkflow` still exported from api.ts as legacy API but no longer called from App.svelte. | 2026-04-25 | ADR-041 |
| `release.yml` Edge Function deploy | New step in deploy-cert + deploy-prod jobs: `supabase functions deploy dispatch-workflow --project-ref ...`. Idempotent; replaces function on each release. | 2026-04-25 | ADR-041 |

**Problem:** The admin UI's ⬇ buttons triggered GitHub workflows by reading a PAT from a `github-pat` HTML attribute on `<spws-ranklist>` and POSTing to GitHub's dispatches API directly from the browser. The deployed `index.html` is served by GitHub Pages at a public URL — embedding a PAT in that HTML means anyone with View Source could scrape it. The release pipeline already declined to populate the attribute (the four `sed` lines covered `supabase-*` only, deliberately not `github-*`), which made the button effectively dev-only on cloud and pushed admins to use the secure Telegram path. Admins wanted both surfaces working, securely.

**Approach:** Server-side workflow dispatch via Supabase Edge Function. Browser invokes `supabase.functions.invoke('dispatch-workflow', ...)` with the user's session JWT auto-attached; the function (Deno, ~100 lines including CORS + validation) reads the PAT from `Deno.env.get('GH_DISPATCH_PAT')` and forwards a `workflow_dispatch` call to GitHub. Allowlist of two workflows narrows the function's blast radius even if the auth check is bypassed — only `populate-urls.yml` and `scrape-tournament.yml` are reachable through it. Sub-second click-to-dispatch latency.

**Why not the cron-poller queue I drafted first:** rejected after re-evaluation. The "uses zero PATs" framing was rhetorical (Supabase env secret is not meaningfully less secure than `GITHUB_TOKEN` inside a runner); the queue added a `tbl_dispatch_request` table + RLS + 2 RPCs + a workflow YAML + frontend polling logic for no security advantage and worse UX (60s worst-case latency, 1440 wasted runs/day). The Edge Function is ~100 LoC for the same security guarantee at sub-second latency.

**Changes:**
- New `supabase/functions/dispatch-workflow/index.ts` (Deno, ~100 lines).
- `supabase/config.toml`: declare `[functions.dispatch-workflow] verify_jwt = true`.
- `frontend/src/lib/api.ts`: `requestDispatch()` + `DispatchResult` type.
- `frontend/src/components/EventManager.svelte`: `dispatchAndTrack` helper, `handleDispatchEvent`, `handleDispatchTournament`, per-event `dispatchStatus: Map<id, DispatchState>`, inline status block in template, dispatch CSS.
- `frontend/src/components/EventManager.svelte`: removed `onimportevent` and `onimporttournament` props; ⬇ buttons call internal handlers directly.
- `frontend/src/App.svelte`: removed `handleImportEvent`, `handleImportTournament`, `triggerGitHubWorkflow` import, `github-pat` / `github-repo` props.
- `frontend/index.html`: removed `github-pat=""` and `github-repo=""` attributes.
- `frontend/tests/EventManager.test.ts`: 6 new vitest cases (9.45a–9.45f) with `vi.mock('../src/lib/api')` for `requestDispatch`.
- `.github/workflows/release.yml`: `supabase functions deploy dispatch-workflow` step in `deploy-cert` and `deploy-prod`.

**One-time setup per environment** (admin runs once, manually):
```
supabase secrets set --project-ref <CERT_REF> GH_DISPATCH_PAT=<fine-grained-pat> GH_REPO=Fencer4Life/spws-automated-ranklist
supabase secrets set --project-ref <PROD_REF> GH_DISPATCH_PAT=<fine-grained-pat> GH_REPO=Fencer4Life/spws-automated-ranklist
```

The PAT should be **fine-grained, scoped to this repo only, with `Actions: read and write` permission and nothing else**.

**TDD:**
- **RED:** 5/6 vitest assertions failed (the 6th — button hidden when `url_event` null — was already passing; treated as regression guard).
- **GREEN:** 293 pgTAP + 314 pytest (9 skipped) + 279 vitest pass.
- **RTM:** FR-99 added; ADR-041 in Appendix C; Appendix D: vitest 273→279, total 887→893.
- **Coverage:** FR-99 fully covered (9.45a–9.45f).

#### Amendment 2026-04-25 — Refresh-on-dispatch UX (8 tests)

**Problem:** the dispatch returns instantly (workflow accepted by GitHub Actions) but the actual `url_results` PATCH lands ~20-30 seconds later when the script runs. Admin clicked ⬇, saw `✓ Triggered`, but the tournament list still showed empty URLs because the frontend never re-fetched. Manual hard-refresh of the browser was the only way to see the new data.

**Approach:** Two complementary refresh triggers, both calling existing `App.reloadAdminEvents` via a new `onrefresh` prop:

1. **Auto-refresh ~40s after dispatch success.** `setTimeout(onrefresh, 40_000)` scheduled in `dispatchAndTrack`'s success branch, per-event timer ID tracked so a second dispatch on the same event resets the clock (latest wins, no double-fire).
2. **Refetch on every accordion expand (▶ → ▼).** `toggleExpand` calls `runRefreshFor(eventId)` on the collapsed→expanded transition; collapsing is a no-op for refresh. Maps to natural admin intent ("show me this event's tournaments now"). Always fires regardless of whether a dispatch happened — consistent semantics, no stale-tracking state.

**Spinner UX (clever, not generic — see [`doc/archive/adr041_refresh_ux_plan.md`](archive/adr041_refresh_ux_plan.md)):**

- **Delayed-show ≥200 ms** — sub-200ms refreshes (the 95% case on CERT) render zero spinner. No flicker on fast networks.
- **Per-event `Map<id_event, RefreshPhase>`** — no global overlay. A slow refresh on one event doesn't blank-out the rest of the calendar.
- **Banner lifecycle morph** for dispatch-triggered auto-refresh — the existing dispatch-status banner reuses its slot to morph through `Triggering → Triggered → Refreshing → Refreshed at HH:MM:SS`. One coherent timeline; CSS animates the colour transition for free.
- **Triangle morph** for expand-triggered refresh on events with no dispatch banner — the expand triangle itself morphs `▶ → ◐ (CSS-spun) → ✓ (1.5s) → ▼`. Co-located with the action that triggered it; zero new UI elements.

**State machine (per event):**
```
idle ──[refresh starts]──→ pending ──[<200ms]──→ success-flash (1.5s) ──→ idle
                              ↘[≥200ms]──→ visible ──[done]──→ success-flash ──→ idle
                                                  ↘[error]──→ failed (3s) ──→ idle
```

One state machine, two render targets (banner-morph or triangle-morph) depending on whether a dispatch banner already exists for that event.

**Changes:**
- `frontend/src/components/EventManager.svelte`: new `onrefresh` prop, `refreshState: Map<number, RefreshPhase>`, `dispatchTimers: Map<number, Timeout>`, `runRefreshFor(eventId)` helper with delayed-show pattern, auto-refresh `setTimeout` in `dispatchAndTrack` success branch, `toggleExpand` fires refresh on collapsed→expanded only, expand-button class morph (`refreshing` / `refresh-success` / `refresh-failed`) + glyph morph (◐/✓/⚠), dispatch-banner content morph during refresh phases.
- `frontend/src/App.svelte`: pass `onrefresh={reloadAdminEvents}` to `<EventManager>`.
- `frontend/tests/EventManager.test.ts`: 8 new vitest cases (9.45g–9.45n) using `vi.useFakeTimers` + `vi.advanceTimersByTimeAsync` for deterministic timing.

**TDD:**
- **RED:** 6/8 new tests failed (9.45j and 9.45k passed vacuously pre-implementation — collapse never called onrefresh because no impl existed; spinner-not-rendered passed because no spinner element existed).
- **GREEN:** 293 pgTAP + 314 pytest (9 skipped) + 287 vitest pass.
- **Appendix D:** vitest 279→287, total 893→901.
- **Coverage:** FR-99 extended with refresh UX coverage (9.45g–9.45n).

#### Amendment 2026-04-25 — Banner clears after refresh + PROD target

Two small follow-ups:

1. **Dispatch banner clears 1.5s after a successful refresh.** Previously the banner stayed for the full 5-minute auto-clear window; visually screwed up the accordion long after the dispatch + downstream refresh had completed. Now `runRefreshFor`'s success branch — at the end of the 1.5s success-flash — also removes the dispatch banner, guarded by a `dispatchTsAtStart` comparison so a fresh dispatch on the same event during the success-flash window doesn't get its banner prematurely wiped. Test 9.45o asserts banner is gone 1.5s after refresh resolves.

2. **PROD target threading.** The `populate-urls.yml` workflow already accepted `target: cert | prod`; the frontend wasn't passing it, so PROD admin clicks always wrote to CERT. Now `EventManager` accepts an `activeEnv: 'CERT' | 'PROD'` prop and threads `target: activeEnv.toLowerCase()` into both populate-urls and scrape-tournament dispatches. `scrape-tournament.yml` extended with the same `target` input + ternary `SUPABASE_URL/KEY` selection (mirrors populate-urls.yml). Telegram path untouched — GAS doesn't pass `target`, so the workflow's `default: 'cert'` kicks in (backward-compatible). Tests 9.45p (target=cert) and 9.45q (target=prod). 9.45a updated to use `objectContaining` since inputs now carry an extra `target` field.

**Files modified:**
- `frontend/src/components/EventManager.svelte` — banner-clear in `runRefreshFor` success; new `activeEnv` prop; `target` in dispatch inputs.
- `frontend/src/App.svelte` — pass `activeEnv` to `<EventManager>`.
- `.github/workflows/scrape-tournament.yml` — `target` input + ternary env vars.
- `frontend/tests/EventManager.test.ts` — 3 new tests (9.45o, 9.45p, 9.45q); 9.45a softened to `objectContaining`.

**TDD:**
- **GREEN:** 293 pgTAP + 314 pytest (9 skipped) + 290 vitest pass.
- **Appendix D:** vitest 287→290, total 901→904.

#### Amendment 2026-04-26 — Phase 3a carry-over admin RPCs (25 new pgTAP)

Phase 3a turns the carry-over admin runbook into point-and-click. Six new migrations, one new test file, the column DEFAULT flipped to FK for greenfield seasons, and three baseline-restore items rolled in.

**Backend RPCs** (all in `supabase/migrations/20260428000001`–`20260428000006`):

1. `tbl_season.enum_carryover_engine` DEFAULT flipped `EVENT_CODE_MATCHING` → `EVENT_FK_MATCHING`. Existing rows untouched. ADR-045.
2. `fn_update_event` v2 — adds `p_code` (cascade rename) and `p_id_prior_event` (admin picker). Cascade rebuilds child tournament codes from `(enum_age_category, enum_gender, enum_weapon)` so PPW/PEW (`-V{age}-` infix) and MEW/MSW/MPW (appended `-G-W`) styles both work. Detection key on a sample child: `~ '-V\d-'`.
3. `fn_init_season(p_id_season)` + helper `_fn_create_skeleton_children`. Iterates `^PPW\d+-` and `^PEW\d+-` priors, always inserts MPW + MSW (matches `^I?MSW-` to cover the IMSW seed inconsistency), inserts a single IMEW/DMEW per `enum_european_event_type` with biennial-aware lookup. First-ever season creates singletons only with NULL `id_prior_event`. Idempotency-guarded.
4. `fn_create_season_with_skeletons` — wizard's atomic RPC. INSERT season → `fn_import_scoring_config` overwrite of trigger defaults → `fn_init_season`. Implicit transaction = "cancel = nothing persists".
5. `fn_revert_season_init(p_id_season)` — refuses if any skeleton has advanced past CREATED. Otherwise children → events → scoring_config → season.
6. `fn_copy_prior_scoring_config(p_dt_start)` — read-only helper for wizard step-2 pre-fill. Returns NULL if no chronological prior.

**Path A baseline restoration** (rolled into the same commit):
- Test 9.05 in `07_auth_revoke.sql` was hardcoded to `fn_calc_tournament_scores(1)` = DMEW-F-EPEE = intentionally empty team placeholder. Switched to tournament 7 (`GP1-V0-F-EPEE-2023-2024` — historical seed with results). Path A reasoning: never delete data; pick a tournament that always has results.
- `seed_post_backfill.sql` walks `PEW-LIÈGE-2025-2026` `PLANNED → IN_PROGRESS → SCORED → COMPLETED` so the empty F-SABRE / M-SABRE child tournaments match the SPORTHALLE/SALLEJEANZ pattern (held event, weapon slot had zero entrants). Required walk-through-trigger because direct `PLANNED → COMPLETED` is rejected by `fn_validate_event_transition`.
- `10_ingest_pipeline.sql` regression: test 10.24 was written for CODE engine semantics (no `id_prior_event` linkage on its in-test fixture); the Phase 3 default flip to FK silently broke it. Pinned the in-test `CARRY-CURR` season explicitly to `EVENT_CODE_MATCHING` to keep the test scope honest.

**ADRs:**
- **ADR-044** Phase 3 Admin UI + Season-Init Wizard (atomic transaction model)
- **ADR-045** Carry-over Engine Selectable Per-Season + Default Flipped to FK
- **ADR-042** amended — engine selection now admin-configurable; default flipped to FK; existing rows untouched (admin opts in via UI)

**Test counts:**
- pgTAP: 344 → **369** (+25 in `19_phase3_wizard.sql`: ph3.1–22 + ph3.22a/b/c)
- pytest: **317** unchanged
- vitest: **293** unchanged
- Appendix D total: 961 → **986**

**Notable design calls:**
- `p_id_prior_event` semantics = `COALESCE(p_id_prior_event, id_prior_event)` — NULL leaves unchanged, matches `p_id_organizer` pattern. Backward-compat with App.svelte 19-arg callers preserved until Phase 3c.
- ph3.12 (Day-1 parity) relaxed from exact-equality to "≥ prior count − 5". Under FK rolling, a new season's carry chain includes prior + prior-of-prior within the 366-day cap, which the prior's final ranklist excludes by definition.
- `fn_init_season` is intentionally idempotency-guarded. The wizard never calls it twice (atomic RPC); admin re-init = `fn_revert_season_init` first, then wizard again.

**TDD:**
- **RED:** 23/25 new pgTAP failed initially. Two false starts (jsonb NULL key in `fn_init_season`'s `by_kind` return, IMSW-vs-MSW prior regex) found and fixed.
- **GREEN:** 369 pgTAP + 317 pytest (9 skipped) + 293 vitest pass.
- **Coherence**: caught Gate 3 on the first push (`4da1659` failed CI on missing Appendix D bump); fixed forward in `bbd6c7a`. Memory rule `feedback_coherence_check.md` re-affirmed.

**Pending follow-ups (Phase 3b + 3c):**
- SeasonManager 3-step wizard component + skeleton inventory rendering
- ScoringConfigEditor Section 4b "🔀 Silnik carry-over" engine dropdown + 🎯 button visibility rule
- EventManager season selector at top + `txt_code` editable + `id_prior_event` picker + Skeletons collapsible panel
- App.svelte rewires `fn_update_event` callsites to the v2 21-arg signature
- ~34 vitest assertions ph3.23–ph3.37g + EventManager extensions

#### Amendment 2026-04-26 — Phase 3b carry-over admin UI (24 new vitest)

Phase 3b lands the admin-facing UI on top of Phase 3a's RPCs. Two commits:

**Phase 3b.1 (commit 4b18a93) — engine dropdown + 🎯 button visibility (8 vitest):**
- ScoringConfigEditor gains Section 4b "🔀 Silnik carry-over" between Intake and Rules. Dropdown lists every value of `CARRYOVER_ENGINE_VALUES` (extensible — new engines added to the SQL enum auto-appear after a `types.ts` update). Default for new seasons = FK; existing seasons reflect their `tbl_season.enum_carryover_engine`. (legacy) tag + amber warning when CODE selected. `onsave` payload carries `engine` so App.svelte's handler can patch `tbl_season.enum_carryover_engine` separately from the scoring config (instant flip, no migration).
- SeasonManager `🎯 Konfiguracja punktacji` button hidden entirely for past-complete (`dt_end < today`) seasons; future + active seasons render it as before. The existing `readonly` prop on the editor stays as defense-in-depth.
- api.ts: `fetchScoringConfig` joins `tbl_season.enum_carryover_engine` into the returned config; new `updateSeasonCarryoverEngine` does a direct PostgREST PATCH on `tbl_season`. `EventStatus` type extended with `CREATED` + `SCORED` (drift fix from Phase 1B).
- Tests: ph3.37a (dropdown lists all enum values), ph3.37b ×2 (default-FK + reflects existing), ph3.37c (legacy tag), ph3.37d (`onsave` payload carries engine), ph3.37e (existing season editor shows current engine), ph3.37f (past-complete hides button), ph3.37g (future renders button).

**Phase 3b.2 (commit 64e6f52) — SeasonManager 3-step wizard + skeleton inventory (16 vitest):**
- New `SeasonManagerWizard.svelte` (~650 lines) — 3-step modal state machine: Identity (code/dates/int_carryover_days/enum_european_event_type segmented) → Scoring (embedded ScoringConfigEditor pre-filled via `fn_copy_prior_scoring_config(dtStart)` or static defaults if no prior) → Confirm (skeleton breakdown count from prior season's events). Atomic-cancel: `oncommit` fires only on ✓ Utwórz at step 3.
- SeasonManager: hosts the wizard via `wizardOpen` state. EDIT form gains a 🔁 Carry-over section (days input + IMEW/DMEW segmented) and a 🦴 Skeleton inventory grouped by kind (PPW / PEW / Mistrzostwa) with calendar-style purple boxes. "↶ Cofnij całość" link confirms then calls `fn_revert_season_init`.
- api.ts: 5 new functions — `copyPriorScoringConfig`, `createSeasonWithSkeletons`, `revertSeasonInit`, `updateSeasonCarryoverFields`, plus the engine helper from 3b.1.
- App.svelte: 4 new wizard handlers (`handleWizardLoadPrior`, `handleWizardCommit`, `handleFetchSkeletons`, `handleRevertSeasonInit`); `handleUpdateSeason` widened from 5 to 7 args (+ `carryoverDays`, `europeanType`).
- Tests: 16 wizard tests (`SeasonManagerWizard.test.ts`) covering open/close, validation gates (duplicate code, dt_end<dt_start), step transitions, cancel-at-each-step (3 cases), ← Wstecz preservation, IMEW/DMEW segmented, commit payload assembly. 4 existing SeasonManager tests (9.38 / 9.39 / 8.81 / 8.83) updated to track the architectural change called out in the plan ("now opens 3-step wizard instead of inline form").

**i18n:** +56 keys per locale (PL + EN), all wizard / engine / skeleton inventory labels.

**TDD:**
- **GREEN:** 369 pgTAP + 317 pytest (9 skipped) + 317 vitest pass (vitest 293 → 317, +24 across 3b.1 + 3b.2).
- **Coherence**: caught Gate 3 once during 3a (commit 4da1659 → bbd6c7a fix-forward); 3b.1 + 3b.2 ran clean pre-push.

#### Amendment 2026-04-26 — Phase 3c EventManager extensions (14 new vitest)

Phase 3c (commit 29afa4b) finishes the trilogy. The EventManager admin page gains a season selector, surfaces the v2 `fn_update_event` extras (`txt_code` cascade rename + `id_prior_event` picker), and renders a collapsible Skeletons panel.

**EventManager.svelte additions:**
- Season selector dropdown in the header lists every season; change fires `onseasonchange` callback so App.svelte can update `selectedSeasonId` and refetch events. Callback pattern matches CalendarView.
- Edit form: `form-event-code` input pre-fills `txt_code`; cascade hint (⚠️ "Renaming cascades to related tournaments") surfaces only when the value differs from the original. `fn_update_event` v2's cascade rebuilds child codes from enum fields on save.
- Edit form: `form-prior-event` dropdown picker filtered to events from chronologically-prior seasons (`s.dt_end < currentSeason.dt_start`). Empty option = "(none)"; selected value flips `id_prior_event`.
- Collapsible Skeletons panel below the event list — purple-bordered, count badge ("N pending"), CREATED-only filter (PLANNED/SCORED/COMPLETED rows hidden). Empty state when no skeletons exist.
- `handleSave` passes `code` only when changed (no-op rename avoided); always passes `priorEventId` (NULL = leave unchanged).

**api.ts:** `updateEvent` now passes `p_code` + `p_id_prior_event` to `fn_update_event` v2. Both default to null so legacy callers are unaffected. `UpdateEventParams` type widened with `code?` + `priorEventId?` fields.

**App.svelte:** EventManager mount adds `onseasonchange={(id) => { selectedSeasonId = id; handleSeasonChange() }}` reusing the existing flow that refetches calendarEvents + scoring config.

**i18n:** +10 keys per locale for season selector / event code / prior event / skeleton panel labels.

**Tests:** 14 new in `EventManager.test.ts` — ph3c.1 (selector renders), ph3c.2 (selector fires callback), ph3c.3 (code pre-fill), ph3c.4 (cascade hint), ph3c.5 (picker filter), ph3c.6 ×2 (code only when changed), ph3c.7 ×2 (priorEventId always threaded), ph3c.8 (panel collapsed by default), ph3c.9 (expand on click), ph3c.10 (CREATED-only filter), ph3c.11 (status badge), ph3c.12 (empty state).

**TDD:**
- **GREEN:** 369 pgTAP + 317 pytest (9 skipped) + 331 vitest pass (vitest 317 → 331, +14).
- **Coherence:** all 4 gates green pre-push.

**Phase 3 trilogy complete.** Total deltas across 3a/3b/3c: pgTAP 344 → 369 (+25), vitest 293 → 331 (+38), pytest unchanged. Carry-over admin runbook §3 (manual FK linkage), §4 (biennial placeholder), §5 (engine flip via SQL), §6 (instant rollback), §9 (pre-create CREATED slot) all superseded by point-and-click UI.

### V-cat Invariant Trigger + Combined-Pool Splitter Consolidation (ADR-047) — 2026-04-29 → 2026-04-30

**Problem.** Combined-pool ingestion (V0+V1 pools, etc.) had a working splitter only on the FencingTime XML path; FTL JSON, Engarde, 4Fence, Dartagnan and CSV/xlsx paths dumped the entire pool into whichever V-cat tournament admin had pasted the URL onto. Result: 209 V-cat-mismatched rows on LOCAL (and the same on CERT/PROD), where `enum_age_category` of the tournament disagreed with `fn_age_category(fencer.int_birth_year, season_end_year)`.

**Fix (Layers 1–3).** `python/pipeline/age_split.py` now hosts the splitter, exporting `split_combined_results()` (ADR-024 logic) and `birth_year_to_vcat()` helper. Every ingestion path imports from there: `python/scrapers/fencingtime_xml.py` re-exports for backward compatibility, `python/tools/scrape_tournament.py` finds sibling V-cat tournaments sharing a URL and ingests per-V-cat, `python/scrapers/evf_sync.py` adds a defensive WARN cross-check (no reassignment — EVF API is per-category). DB-side: migration `20260429000004_assert_result_vcat_trigger.sql` adds `fn_vcat_violation_msg(...)` (pure helper) + `fn_assert_result_vcat()` BEFORE INSERT/UPDATE trigger on `tbl_result` (NOTICE-only mode).

**Layer 5 admin surface.** Migration `20260430000001_vw_vcat_violation.sql` adds the read-only view `vw_vcat_violation` exposing every existing violator. CLI `python/tools/audit_vcat_violations.py` queries it for LOCAL or via Management API for CERT/PROD.

**Layer 6 cleanup attempt + reversal.** `python/tools/replay_vcat_violations.py` performed an in-DB redo (round 1: 22 BY-derived moves + 178 dupe-deletes; round 2: 9 orphan moves + creation of 7 missing-sibling tournaments). The FATAL flip migration (`20260430000002_assert_result_vcat_fatal.sql`) was applied. The replay's BY-derived logic was then proven partially wrong — Stockholm-class fabricated rows surfaced. Round 2 was fully reversed; the 7 phantom tournaments were dropped. Eight remaining V-cat violators were resolved by per-row admin-approved deletes (GRODNER 7913, NOWAK 8010, KAZIK 10096, BORKOWSKI 10410, BAZAK 10472, OWCZAREK 9217, LIPKOWSKA 9298, KOWALSKA 9299) plus one BY revert + ineligible-row delete (PAWŁOWSKI 8014). Final state: 0 V-cat invariant violators on LOCAL; FATAL trigger active and validated by smoke test.

**Test fixture bypass.** Nine pgTAP test files (01, 02, 03, 07, 08, 09, 10, 11, 19) gained a `ALTER TABLE tbl_result DISABLE TRIGGER trg_assert_result_vcat;` to keep their arbitrary-V-cat fixtures functional. Targeted disable preserves audit + status-transition triggers.

### Source-vs-DB Audit + Phantom-Row Discovery (ADR-048) — 2026-04-30

**Problem.** Layer 2 trigger catches V-cat-vs-BY mismatch; it does not catch fencers who never appeared in the source URL at all (Stockholm-class fabrication). GRODNER's PEW5ef row was the discovery vehicle: BY=1960 → V3 by math, but Engarde's vet2026 results contain no GRODNER in any V-cat — the row was wholly fabricated by some prior ingest.

**Audit.** Full vendor-source cross-check on LOCAL (2655 result rows × 538 unique URLs across FTL / Engarde / 4Fence / Dartagnan / EVF API). Result: 1948 OK matches, 37 weak matches (diacritic noise), **670 phantom rows** (URL fetched + parsed but DB fencer not present, OR URL missing/broken). Phantoms are not international-only — domestic events held 309, international 317.

**Decision.** Verdict policy: any condition where the source can't confirm the fencer (URL error, no URL, parse error, fencer not in parsed list) collapses into PHANTOM. No auto-deletes — every phantom resolution requires per-row admin approval. Bulk phantom-row resolution deferred to the from-scratch re-scrape that will replace all result data with vendor-verified ingestion.

### LOCAL → CERT → PROD Replication (2026-04-30)

**Goal.** CERT and PROD were holding the original 209 violators plus their own pre-existing fabrications. LOCAL was post-cleanup (0 V-cat violators, the 670 audit phantoms documented but not yet deleted). The user chose to replicate LOCAL state to both cloud envs as the new baseline before the from-scratch re-scrape.

**Tooling.** `python/pipeline/export_seed_local.py` wraps `export_seed.py`'s schema-driven monolithic format but reads from LOCAL via `docker exec psql` (Management API is cloud-only). Patches: strip `id_prior_event` from `tbl_event` INSERTs (FK to other rows whose ids change after `TRUNCATE RESTART IDENTITY`) and append `fn_backfill_id_prior_event()` at end; normalise array literals to PG `'{a,b,c}'` text format for clean enum implicit-cast.

**Execution.** Migrations applied to CERT/PROD via Management API: NOTICE-only V-cat trigger + `vw_vcat_violation` view. **FATAL flip not applied** to CERT/PROD — premature until phantoms are cleared by the re-scrape. `seed-remote.sh`'s shell-arg-limit hit on the 2.1 MB seed file was bypassed via `jq --rawfile` + `curl --data-binary @file`. Final state on CERT and PROD identical to LOCAL: 3 seasons / 329 fencers / 60 events / 756 tournaments / 2655 results / 18 carry-over FKs (from `fn_backfill_id_prior_event()`) / 0 V-cat violators.

### Joint-Pool Split Flag (ADR-049) — 2026-04-30

**Problem.** Two related joint-pool bugs surfaced after the V-cat trigger landed. PPW4 women epee ran V0+V1 as one 7-fencer pool with both DB rows sharing the same FTL URL, but `int_participant_count` on each row stored the per-V-cat slice (4 and 3) instead of the full pool (7) — Gabriela KAMIŃSKA's V1 ranking points were 96.35 instead of 97.22. PPW5 women epee ran V0/V1/V2/V4 as one 11-fencer pool whose source published per-V-cat URLs, so the splitter never even ran. Pre-this-change there was no schema relationship marking sibling V-cat rows as one physical pool — membership was inferable only from URL equality, which is brittle and silent on per-V-cat URL cases.

**Rejected first attempt.** A self-referential FK `tbl_tournament.id_joint_pool_parent` was drafted, applied to LOCAL, and reverted within the same session. Reasons: introduces parent/child asymmetry where none exists in the domain (every V-cat slice is equally a "child"), arbitrary lowest-id tie-break, regex-on-scraped-names backfill, harder admin UI.

**Decision.** Single boolean flag `tbl_tournament.bool_joint_pool_split BOOLEAN NOT NULL DEFAULT FALSE`, set by the ingester at write time. All siblings of a joint pool share `(id_event, enum_weapon, enum_gender, url_results)` and carry the flag TRUE; `int_participant_count` on each = full physical pool size. No parent row, no FK, all siblings equal.

**Schema migrations.** `20260430000003_joint_pool_split.sql` adds the column + partial index `idx_tbl_tournament_joint_split`. `20260430000004_fn_backfill_joint_pool_split.sql` provides idempotent retroactive remediation (shared-URL detection only — PPW5-class needs re-scrape).

**Ingester contract.** `python/tools/scrape_tournament.py` now: (1) extracts pure helper `plan_joint_pool_actions(siblings, buckets)` that classifies the sibling set after the V-cat split; (2) DELETEs sibling rows whose buckets are empty (admin-registration mistake — admin pasted URL on a V-cat with no actual entrants), with Telegram alert per delete; (3) PATCHes `bool_joint_pool_split=TRUE` on every non-empty sibling of a joint pool; (4) passes `p_participant_count = len(parsed_rows)` for joint pools (full physical pool size) instead of `len(bucket_rows)`. Solo tournament behaviour unchanged.

**Backfill execution (2026-04-30).** Function applied + run on LOCAL/CERT/PROD: 86 PPW4-class joint-pool groups detected on each, 206 sibling rows flagged TRUE per env, 186 `int_participant_count` values rewritten on CERT/PROD (LOCAL was net-zero because the rejected FK design's backfill had already corrected counts earlier the same day). 206 affected tournaments re-scored on each via `fn_calc_tournament_scores`. Verification: `PPW4-V1-F-EPEE-2025-2026` row N=7, points=97.22 on all three envs.

**Tests.** pgTAP `25_joint_pool_split.sql` — 7 assertions (column shape, partial index, function existence, sibling flag, count rewrite, standalone untouched, idempotence). pytest `test_scrape_tournament_joint_pool.py` — 4 tests (3 unit on `plan_joint_pool_actions`, 1 main() integration asserting DELETE on empty sibling + PATCH `bool_joint_pool_split=TRUE` + POST `p_participant_count = len(parsed_rows)`). pgTAP file 25: 7/7 GREEN; pytest 354 passed / 9 skipped; vitest 332/332 GREEN.

**ADR-048 update.** Its "Joint-pool reference field — also deferred" subsection now reads "superseded by ADR-049." MEMORY.md ADR registry updated.

**Scope unchanged.** PPW5-class on all three envs is still broken — no DB signal exists for retroactive detection. Will be corrected by the from-scratch re-scrape, where the new ingester contract above writes the flag at ingestion time.

---

## Archived Documents

The following documents contain the original detailed plans. They are superseded by this history and the Project Specification:

- `doc/archive/POC_development_plan.md` — POC milestones M0–M6 (archived)
- `doc/archive/MVP_development_plan.md` — MVP milestones M8–M10 (archived)
- `doc/archive/Go-to-PROD.md` — Go-to-PROD items 2.1–2.9 (archived)
