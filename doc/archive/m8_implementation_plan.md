# M8 Implementation Plan — Multi-Category Data + Calendar UI + Schema Extensions

## Context

POC (M0-M6) is complete with 236 test assertions. M8 is the first MVP milestone, expanding from 1 category (Male Epee V2) to all 30 sub-rankings, adding a Calendar view, admin password gate, two-view app shell, and Shadow DOM packaging. All 6 UI mockups are approved and locked.

**10 requirements in scope:** FR-42, FR-43, FR-44, FR-45, FR-46, FR-48, FR-52, FR-59, FR-61, NFR-13

**New ADR required:** ADR-015 — M8 UI Design Decisions (records all approved mockup choices)

---

## Dependency Graph

```
T8.1 Schema Extension ──► T8.2 Calendar API View ──► T8.5 Calendar UI ──┐
        │                                                                 │
        └──► T8.3 Seed Data (30 cats)                                    ├──► T8.7 Shadow DOM Build
                                                                         │
T8.0 Env Toggle Tests (independent)    T8.4 App Shell ──► T8.6 Admin Gate ┘
                                                              │
                                                              └──► T8.8 Scoring Config Editor
```

**Execution order:** T8.0 + T8.1 (parallel) → T8.2 + T8.3 (parallel) → T8.4 → T8.5 + T8.6 (parallel) → T8.8 → T8.7

---

## T8.0 — CERT/PROD Env Toggle Tests (FR-42)

**Goal:** Close POC test gap — env toggle exists in App.svelte but has zero assertions.

**Files:**
- `frontend/tests/env-toggle.test.ts` — NEW

| ID | Assertion | Suite |
|----|-----------|-------|
| 8.01 | Both CERT + PROD creds → env toggle (CT/PD) rendered | vitest |
| 8.02 | Only CERT creds → env toggle hidden | vitest |
| 8.03 | Click PD → `activeEnv = PROD`, client re-init with PROD URL | vitest |
| 8.04 | Click CT → `activeEnv = CERT`, client re-init with CERT URL | vitest |

---

## T8.1 — tbl_event Schema Extension (FR-48)

**Goal:** Add 4 new nullable columns to `tbl_event` for calendar display and admin event management.

**Files:**
- `supabase/migrations/20260326000001_event_schema_extension.sql` — NEW
- `supabase/tests/04_event_schema_extension.sql` — NEW

**Migration:**
```sql
ALTER TABLE tbl_event ADD COLUMN IF NOT EXISTS txt_country TEXT;
ALTER TABLE tbl_event ADD COLUMN IF NOT EXISTS txt_venue_address TEXT;
ALTER TABLE tbl_event ADD COLUMN IF NOT EXISTS url_invitation TEXT;
ALTER TABLE tbl_event ADD COLUMN IF NOT EXISTS num_entry_fee NUMERIC;
```

| ID | Assertion | Suite |
|----|-----------|-------|
| 8.05 | `txt_country` column exists (TEXT, nullable) | pgTAP |
| 8.06 | `txt_venue_address` column exists (TEXT, nullable) | pgTAP |
| 8.07 | `url_invitation` column exists (TEXT, nullable) | pgTAP |
| 8.08 | `num_entry_fee` column exists (NUMERIC, nullable) | pgTAP |
| 8.09 | Existing `tbl_event` rows unaffected after migration | pgTAP |
| 8.10 | INSERT with all 4 new columns populated succeeds | pgTAP |

**Notes:** All columns nullable, no defaults — backward compatible. `num_entry_fee` is NUMERIC for decimal amounts. No RLS changes needed (tbl_event already has anon SELECT + authenticated CRUD).

---

## T8.2 — Calendar API View (FR-43, FR-44)

**Goal:** SQL view providing events + tournament counts for the Calendar, plus frontend fetch function.

**Files:**
- `supabase/migrations/20260326000002_calendar_view.sql` — NEW
- `supabase/tests/05_calendar_view.sql` — NEW
- `frontend/src/lib/api.ts` — MODIFY (add `fetchCalendarEvents`)
- `frontend/src/lib/types.ts` — MODIFY (add `CalendarEvent` interface)
- `frontend/tests/api.test.ts` — MODIFY (add calendar tests)

**SQL design:**
```sql
CREATE OR REPLACE VIEW vw_calendar AS
SELECT
  e.id_event, e.txt_code, e.txt_name, e.id_season,
  s.txt_code AS txt_season_code,
  e.txt_location, e.txt_country, e.txt_venue_address,
  e.url_invitation, e.num_entry_fee,
  e.dt_start, e.dt_end, e.url_event, e.enum_status,
  COUNT(t.id_tournament) AS num_tournaments,
  BOOL_OR(t.enum_type IN ('PEW','MEW','MSW','PSW')) AS bool_has_international
FROM tbl_event e
JOIN tbl_season s ON s.id_season = e.id_season
LEFT JOIN tbl_tournament t ON t.id_event = e.id_event
GROUP BY e.id_event, s.txt_code
ORDER BY e.dt_start ASC;
```

| ID | Assertion | Suite |
|----|-----------|-------|
| 8.11 | `vw_calendar` view exists | pgTAP |
| 8.12 | Returns events ordered by `dt_start` ASC | pgTAP |
| 8.13 | `num_tournaments` correctly counts child tournaments | pgTAP |
| 8.14 | Includes 4 new columns (txt_country, url_invitation, etc.) | pgTAP |
| 8.15 | Accessible to `anon` role (public read) | pgTAP |
| 8.16 | Events with 0 tournaments show `num_tournaments = 0` | pgTAP |
| 8.17 | `bool_has_international` TRUE when event has PEW/MEW/MSW/PSW tournaments | pgTAP |
| 8.18 | `fetchCalendarEvents(seasonId)` calls `vw_calendar` with season filter | vitest |
| 8.19 | `CalendarEvent` type includes all required fields | vitest |

**Notes:** Past/future/all toggle is client-side (compare `dt_start` to `Date.now()`). PPW/+EVF filter uses `bool_has_international`. RLS inherited from tbl_event — no new policy.

---

## T8.3 — Multi-Category Seed Data (FR-52)

**Goal:** Expand from 1 seeded category to all 30 sub-rankings using `generate_season_seed.py`.

**Files:**
- `supabase/data/2024_25/*.sql` — 26 NEW files (1 existing `v2_m_epee.sql`)
- `python/tools/generate_season_seed.py` — MODIFY (handle missing sheets, combined V3+4-F)
- `supabase/tests/06_multi_category.sql` — NEW

**The 27 seed files:**
- Male: V0/V1/V2/V3/V4 × EPEE/FOIL/SABRE = 15 files
- Female: V0/V1/V2/V3+4 × EPEE/FOIL/SABRE = 12 files (V3+V4 combined per spec)

| ID | Assertion | Suite |
|----|-----------|-------|
| 8.20 | After db reset, tbl_tournament has rows for all 3 weapons | pgTAP |
| 8.21 | After db reset, tbl_tournament has rows for both genders | pgTAP |
| 8.22 | After db reset, tbl_tournament has rows for all 5 age categories | pgTAP |
| 8.23 | `fn_ranking_ppw` returns rows for a non-V2 category (e.g. V1 M FOIL) | pgTAP |
| 8.24 | `fn_ranking_ppw` returns rows for a female category (e.g. V2 F EPEE) | pgTAP |
| 8.25 | `generate_season_seed.py` exits 0 for a valid combination | pytest |
| 8.26 | `generate_season_seed.py` produces valid SQL (no syntax errors) | pytest |

**Risk:** Reference Excel may not have data for all 30 categories. For empty sheets, create minimal manual seed (1 event, 2-3 results) to verify the ranking pipeline works end-to-end.

---

## T8.4 — App Shell: Sidebar + Two-View Navigation (FR-59)

**Goal:** Restructure App.svelte from single-view ranklist into two-view app with sidebar drawer.

**Files:**
- `frontend/src/App.svelte` — MAJOR REFACTOR
- `frontend/src/components/Sidebar.svelte` — NEW
- `frontend/src/components/AppHeader.svelte` — NEW (extracted from App.svelte)
- `frontend/src/lib/types.ts` — MODIFY (add `AppView`)
- `frontend/src/lib/locales/en.json` — MODIFY
- `frontend/src/lib/locales/pl.json` — MODIFY
- `frontend/tests/Sidebar.test.ts` — NEW
- `frontend/tests/AppShell.test.ts` — NEW

**Architecture after refactor:**
```
App.svelte
├── AppHeader (☰, env toggle, season selector, lang toggle)
├── Sidebar (slide-in: Ranklista, Kalendarz, [admin: Sezony, Wydarzenia, Tożsamości, Punktacja])
├── {#if currentView === 'ranklist'} FilterBar + RanklistTable + DrilldownModal
├── {#if currentView === 'calendar'} CalendarFilterBar + CalendarView
├── {#if admin} AdminPasswordModal
└── {#if admin} AdminFloatingToolbar
```

| ID | Assertion | Suite |
|----|-----------|-------|
| 8.27 | Hamburger button opens sidebar | vitest |
| 8.28 | Sidebar shows "SPWS" brand + Ranklista + Kalendarz items | vitest |
| 8.29 | Clicking Ranklista → ranklist view, sidebar closes | vitest |
| 8.30 | Clicking Kalendarz → calendar view, sidebar closes | vitest |
| 8.31 | Sidebar overlay dims content | vitest |
| 8.32 | Clicking overlay closes sidebar | vitest |
| 8.33 | Default view is ranklist (POC backward compatible) | vitest |
| 8.34 | Header title updates when view changes | vitest |
| 8.35 | When admin active, sidebar shows admin section (Sezony, Wydarzenia, Tożsamości, Punktacja) | vitest |
| 8.36 | When admin NOT active, sidebar hides admin section | vitest |
| 8.37 | Season selector shared between both views | vitest |

**i18n keys (pl.json):** `"nav_ranklist": "Ranklista"`, `"nav_calendar": "Kalendarz"`, `"nav_admin_seasons": "Sezony"`, `"nav_admin_events": "Wydarzenia"`, `"nav_admin_identities": "Tożsamości"`, `"nav_admin_scoring": "Punktacja"`, `"admin_section": "Administracja"`, `"admin_logout": "Wyloguj"`, `"admin_session": "Sesja"`

**Notes:** Existing vitest tests (FilterBar, RanklistTable, DrilldownModal) test individual components and don't import App.svelte — should remain stable. smoke.test.ts has no component assertions.

---

## T8.5 — Calendar View Component (FR-43, FR-44, FR-45)

**Goal:** Build CalendarView implementing the approved timeline mockup (`m8_calendar_view.html`).

**Files:**
- `frontend/src/components/CalendarView.svelte` — NEW
- `frontend/src/components/CalendarFilterBar.svelte` — NEW
- `frontend/src/components/EventCard.svelte` — NEW
- `frontend/src/lib/locales/en.json` — MODIFY
- `frontend/src/lib/locales/pl.json` — MODIFY
- `frontend/tests/CalendarView.test.ts` — NEW

**Design (from mockup):** Vertical timeline with color-coded status dots, month headers, event cards showing date/name/location/tournament count/status badge/"Komunikat organizatora" link. International events get gold left border in +EVF mode.

| ID | Assertion | Suite |
|----|-----------|-------|
| 8.38 | Renders events in chronological order | vitest |
| 8.39 | Groups events by month with month headers | vitest |
| 8.40 | Event card shows date, name, location, tournament count | vitest |
| 8.41 | Status badge color-coded (completed=green, planned=gray, etc.) | vitest |
| 8.42 | "Komunikat organizatora" link present when url_invitation set | vitest |
| 8.43 | "Komunikat organizatora" link absent when url_invitation null | vitest |
| 8.44 | Past/future/all toggle filters events relative to today | vitest |
| 8.45 | PPW shows domestic only; +EVF shows all events | vitest |
| 8.46 | Mobile layout: cards stack at 375px viewport | vitest |
| 8.47 | Season filter changes displayed events | vitest |

**i18n keys (pl.json):** `"calendar_title": "Kalendarz"`, `"filter_all": "Wszystkie"`, `"filter_past": "Minione"`, `"filter_future": "Przyszłe"`, `"status_completed": "Zakończone"`, `"status_scheduled": "Potwierdzone"`, `"status_planned": "Zaplanowane"`, `"status_cancelled": "Odwołane"`, `"status_in_progress": "W trakcie"`, `"organizer_announcement": "Komunikat organizatora"`, `"tournaments_count": "turniejów"`

---

## T8.6 — Admin Password Gate (FR-46)

**Goal:** Client-side admin mode: `?admin=1` URL param → password modal → 120min session → floating toolbar.

**Files:**
- `frontend/src/lib/admin.svelte.ts` — NEW (admin state with $state rune)
- `frontend/src/components/AdminPasswordModal.svelte` — NEW
- `frontend/src/components/AdminFloatingToolbar.svelte` — NEW
- `frontend/tests/admin.test.ts` — NEW

**Admin flow (from mockup `m8_admin_gate_v2.html`):**
1. URL has `?admin=1` → password modal overlays app
2. Enter password → compared client-side to `admin-password` prop (ADR-004)
3. Success → `isAdmin = true`, floating toolbar (ADMIN badge + "1h 47m" timer + Wyloguj)
4. Sidebar gains admin section (Sezony, Wydarzenia, Tożsamości — placeholders for M9)
5. 120min inactivity → modal reappears
6. "Wyloguj" → `isAdmin = false`, toolbar hides

| ID | Assertion | Suite |
|----|-----------|-------|
| 8.48 | `?admin=1` → password modal appears | vitest |
| 8.49 | No `?admin=1` → no password modal | vitest |
| 8.50 | Correct password → `isAdmin = true` | vitest |
| 8.51 | Wrong password → error "Nieprawidłowe hasło", modal stays | vitest |
| 8.52 | Admin toolbar shows ADMIN badge + timer + Wyloguj | vitest |
| 8.53 | Click Wyloguj → `isAdmin = false`, toolbar hidden | vitest |
| 8.54 | 120min timeout → modal reappears (fake timers) | vitest |

---

## T8.7 — Shadow DOM + Custom Element Build (NFR-13)

**Goal:** Dual-build: dev/test uses regular Svelte, production outputs `<spws-ranklist>` + `<spws-calendar>` as custom elements with Shadow DOM.

**Files:**
- `frontend/vite.config.ce.ts` — NEW (CE build config)
- `frontend/src/main.ce.ts` — NEW (CE entry point, registers both elements)
- `frontend/package.json` — MODIFY (add `"build:ce"` script)
- `frontend/playwright.config.ts` — NEW
- `frontend/e2e/shadow-dom.spec.ts` — NEW

**Dual-build strategy:**
1. **Dev/Test** (`vite.config.ts` unchanged): `compatibility.componentApi: 4` → @testing-library/svelte works for vitest
2. **Production CE** (`vite.config.ce.ts`): no compatibility flag, `customElement: true` → outputs bundle registering both custom elements
3. **Playwright E2E**: loads CE build in real browser, asserts Shadow DOM isolation

| ID | Assertion | Suite |
|----|-----------|-------|
| 8.55 | `<spws-ranklist>` registered in CustomElementRegistry | Playwright |
| 8.56 | `<spws-calendar>` registered in CustomElementRegistry | Playwright |
| 8.57 | `<spws-ranklist>` has non-null shadowRoot | Playwright |
| 8.58 | `<spws-calendar>` has non-null shadowRoot | Playwright |
| 8.59 | Host page CSS does not leak into Shadow DOM | Playwright |
| 8.60 | `<spws-ranklist demo>` renders ranklist table | Playwright |
| 8.61 | `<spws-calendar demo>` renders calendar view | Playwright |

**Risk:** Svelte 5 CE API still maturing. Mitigation: dual-build isolates CE from dev workflow. If CE mode fails, regular build still works and Playwright tests can be skipped temporarily.

---

## T8.8 — Scoring Config Editor (FR-61)

**Goal:** Admin UI for editing `tbl_scoring_config` per season — structured form with collapsible sections (Approach A approved).

**Files:**
- `frontend/src/components/ScoringConfigEditor.svelte` — NEW
- `frontend/src/lib/api.ts` — MODIFY (add `fetchScoringConfig`, `saveScoringConfig`)
- `frontend/src/lib/types.ts` — MODIFY (add `ScoringConfig` interface)
- `frontend/src/lib/locales/en.json` — MODIFY
- `frontend/src/lib/locales/pl.json` — MODIFY
- `frontend/tests/ScoringConfigEditor.test.ts` — NEW

**Design (from approved mockup `m8_scoring_config_A_form.html`):**
5 collapsible sections:
1. **Parametry bazowe** — MP value (numeric input)
2. **Bonus podium** — Gold/Silver/Bronze (3 numeric inputs)
3. **Mnożniki turniejów** — 2×3 grid: domestic (PPW/MPW) green, international (PEW/MEW/MSW/PSW) gold
4. **Reguły kwalifikacji** — Min participants, total rounds (intake rules)
5. **Reguły rankingowe** — Bucket editor for `json_ranking_rules` (domestic + international pools, each with type checkboxes + best-N/always toggle, add/remove bucket rows)

Season context: loads config for the season selected in the header dropdown. Banner: "Konfiguracja punktacji dla sezonu {season_code}".
Footer: Export JSON / Import z pliku + Anuluj / Zapisz i przelicz.

**Existing code to reuse:**
- `fn_export_scoring_config(p_id_season)` — returns full config as JSONB (already exists)
- `fn_import_scoring_config(p_config JSONB)` — upserts with COALESCE for partial updates (already exists)
- `tbl_scoring_config` — 19 columns already defined, auto-created per season via trigger
- `python/calibration/calibrate_config.py` — CLI export/import (reference for JSON structure)

| ID | Assertion | Suite |
|----|-----------|-------|
| 8.62 | Scoring config view accessible from sidebar "Punktacja" (admin only) | vitest |
| 8.63 | Loads config for currently selected season | vitest |
| 8.64 | Displays MP value in base params section | vitest |
| 8.65 | Displays podium bonuses (gold/silver/bronze) | vitest |
| 8.66 | Displays 6 tournament multipliers in 2×3 grid | vitest |
| 8.67 | Displays intake rules (min participants, total rounds) | vitest |
| 8.68 | Displays ranking rule buckets (domestic + international pools) | vitest |
| 8.69 | Can edit multiplier value and see change reflected | vitest |
| 8.70 | Can add a new bucket to domestic pool | vitest |
| 8.71 | Can remove a bucket from a pool | vitest |
| 8.72 | "Zapisz i przelicz" calls `fn_import_scoring_config` with updated config | vitest |
| 8.73 | "Anuluj" reverts to last saved state | vitest |
| 8.74 | "Eksport JSON" downloads config as .json file | vitest |
| 8.75 | Season banner shows correct season code | vitest |

**Notes:** Uses existing RPCs — no new migrations needed. Config auto-created on season insert, so there's always a row to load. `json_ranking_rules` bucket structure: `{ "domestic": [{ "types": ["PPW","MPW"], "best": 4 }], "international": [...] }`.

---

## ADR-015 — M8 UI Design Decisions

**Goal:** Record all approved mockup decisions as an architectural decision record.

**File:** `doc/adr/015-m8-ui-design-decisions.md` — NEW

**Content to record:**

| Decision | Choice | Alternatives Rejected | Mockup |
|----------|--------|-----------------------|--------|
| App navigation | Sidebar drawer (☰) | Tab bar, top nav dropdown | `m8_app_shell.html` |
| Calendar layout | Vertical timeline with month headers | Table/grid, horizontal timeline, card grid | `m8_calendar_view.html` |
| Admin access | `?admin=1` + password modal + floating toolbar + sidebar section | Visible lock icon, login page, header badge | `m8_admin_gate_v2.html` |
| EVF import entry | Gold button on Calendar (admin only) | Sidebar item, separate page | `m8_evf_import.html` |
| Tournament management | Accordion layout, dual import paths (event-level batch + tournament-level single) | Flat table, modal-only | `m8_tournaments.html` |
| Identity resolution | Queue table with filter bar, 3 actions (approve/create/dismiss), disambiguation modal | Inline editing, wizard flow | `m8_identity_resolution.html` |
| Scoring config editor | Structured form with 5 collapsible sections (Approach A) | Visual tournament cards (B), Split-pane JSON editor (C) | `m8_scoring_config_A_form.html` |

**Cross-cutting design rules:**
- Light theme: `#f0f2f5` bg, `#fff` cards, `#4a90d9` accent, `#ff6b35` admin orange
- Header pattern: `☰ | CT/PD | Title | Season Select | spacer | 🇬🇧/🇵🇱`
- Sidebar admin items: Sezony, Wydarzenia, Tożsamości, Punktacja (orange, hidden when not admin)
- Floating toolbar: bottom-left, `fixed`, ADMIN badge + timer + Wyloguj
- Polish UI terminology: "Ranklista", "Kalendarz", "Komunikat organizatora", "Punktacja"
- All admin views scoped to currently selected season

---

## Test Summary

| Suite | POC | M8 New | M8 Total |
|-------|-----|--------|----------|
| pgTAP | 117 | 17 | 134 |
| pytest | 91 | 2 | 93 |
| vitest | 28 | 46 | 74 |
| Playwright | 0 | 7 | 7 |
| **Total** | **236** | **72** | **308** |

---

## FR-to-Test Traceability

| FR/NFR | Tasks | Test IDs |
|--------|-------|----------|
| FR-42 | T8.0 | 8.01–8.04 |
| FR-43 | T8.2, T8.5 | 8.11–8.19, 8.38–8.40, 8.42–8.43, 8.47 |
| FR-44 | T8.5 | 8.44, 8.45 |
| FR-45 | T8.5 | 8.46 |
| FR-46 | T8.6 | 8.48–8.54 |
| FR-48 | T8.1 | 8.05–8.10 |
| FR-52 | T8.3 | 8.20–8.26 |
| FR-59 | T8.4 | 8.27–8.37 |
| FR-61 | T8.8 | 8.62–8.75 |
| NFR-13 | T8.7 | 8.55–8.61 |

All 10 requirements → 75 test assertions → full traceability.

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Shadow DOM + Svelte 5 CE instability | NFR-13 blocked | Dual-build isolates dev from CE. Fallback: skip Playwright, ship without Shadow DOM |
| Reference Excel missing categories | FR-52 partially blocked | Create minimal manual seed for empty sheets (1 event, 2-3 results) |
| App.svelte refactor breaks POC tests | Regression | Existing tests mock individual components, not App.svelte. Run all 3 suites after T8.4 |
| Client-side password in JS bundle | Low security | Acceptable per ADR-004. Document clearly. Full auth deferred to Phase 3 |

---

## Verification

After all tasks complete:
1. `supabase test db` → 134 pgTAP pass
2. `source .venv/bin/activate && python -m pytest python/tests/ -v` → 93 pytest pass
3. `cd frontend && npm test` → 74 vitest pass
4. `cd frontend && npx playwright test` → 7 Playwright pass
5. `supabase db reset` → all 27 seed files load without errors
6. Manual: open app in browser, toggle Ranklista/Kalendarz, verify calendar timeline renders
7. Manual: add `?admin=1`, enter password, verify floating toolbar + admin sidebar
8. Manual: navigate to Punktacja, verify config loads for selected season, edit a multiplier, save
9. ADR-015 created in `doc/adr/015-m8-ui-design-decisions.md`
10. RTM updated: FR-42 through FR-61 + NFR-13 status → Covered, test IDs filled in
