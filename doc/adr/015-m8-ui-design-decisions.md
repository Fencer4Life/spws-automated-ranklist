# ADR-015: M8 UI Design Decisions

**Status:** Accepted
**Date:** 2026-03-26 (M8)

## Context

M8 is the first MVP milestone, introducing multiple new UI views: app shell with sidebar navigation, calendar view, admin password gate, EVF import, tournament management, identity resolution admin, and scoring config editor. Each view required choosing between 2-4 design approaches, prototyped as HTML mockups and reviewed interactively.

All mockups live in `doc/mockups/` and follow the same design system.

## Decisions

### 1. App Navigation — Sidebar Drawer

**Choice:** Slide-in sidebar via ☰ hamburger (top-left), with "SPWS" branding, Ranklista + Kalendarz items, and admin section when authenticated.

**Rejected:** Tab bar (cluttered with admin items), top nav dropdown (poor mobile experience).

**Mockup:** `m8_app_shell.html`

### 2. Calendar Layout — Vertical Timeline

**Choice:** Vertical timeline with connected dots, month headers (e.g., "Wrzesień 2025"), color-coded status dots, event cards with date/name/location/tournament count/status badge/"Komunikat organizatora" link.

**Rejected:** Table/grid (poor for sparse data), horizontal timeline (poor mobile), card grid without timeline (loses chronological context).

**Mockup:** `m8_calendar_view.html`

### 3. Admin Access — Hidden URL + Password Modal + Floating Toolbar

**Choice:** `?admin=1` URL parameter triggers password modal; on success, floating toolbar (bottom-left) shows ADMIN badge + session timer + Wyloguj; sidebar gains admin section (Sezony, Wydarzenia, Tożsamości, Punktacja). 120-minute inactivity timeout.

**Rejected:** Visible lock icon (exposes admin to end users), dedicated login page (over-engineered for single admin), header badge (clutters header).

**Mockup:** `m8_admin_gate_v2.html`

### 4. EVF Calendar Import — Calendar Button

**Choice:** Gold "🌍 Import EVF" button below "+ Dodaj wydarzenie" on Calendar view (admin only). Opens modal fetching veteransfencing.eu/calendar with checklist and deduplication.

**Rejected:** Sidebar item (not frequent enough), separate page (breaks calendar context).

**Mockup:** `m8_evf_import.html`

### 5. Tournament Management — Accordion with Dual Import

**Choice:** Accordion layout with events as expandable cards, tournaments nested inside. Two import paths: event-level batch (multi-select modal) + tournament-level single. Both modals have two tabs: URL scrape + file upload.

**Rejected:** Flat table (loses hierarchy), modal-only (can't see context).

**Mockup:** `m8_tournaments.html`

### 6. Identity Resolution — Queue Table with Actions

**Choice:** Filterable table of `tbl_match_candidate` rows with stats bar, confidence color-coding, and three actions: Zatwierdź (approve), Nowy zawodnik (create new), Odrzuć (dismiss). Disambiguation modal for same-name fencers with age category fit indicator.

**Rejected:** Inline editing (too complex for disambiguation), wizard flow (too many clicks for bulk operations).

**Mockup:** `m8_identity_resolution.html`

### 7. Scoring Config Editor — Structured Form (Approach A)

**Choice:** 5 collapsible sections: base params (MP value), podium bonuses, tournament multipliers (2×3 grid), intake rules, ranking rule bucket editor. Season-scoped via header dropdown.

**Rejected:** Visual tournament cards (B) — too abstract for editing numeric values; Split-pane JSON editor (C) — requires JSON literacy from admin.

**Mockup:** `m8_scoring_config_A_form.html`

## Cross-Cutting Design Rules

These rules apply to ALL views and mockups:

- **Light theme:** `#f0f2f5` background, `#fff` cards, `#4a90d9` accent blue, `#ff6b35` admin orange
- **Header pattern:** `☰ | CT/PD env toggle | Title (h2) | Season Select | spacer | 🇬🇧/🇵🇱 lang toggle`
- **Sidebar admin items:** Sezony, Wydarzenia, Tożsamości, Punktacja (orange text, hidden when not admin)
- **Floating toolbar:** `position: fixed; bottom: 60px; left: 20px` — ADMIN badge + timer + Wyloguj
- **Polish UI terminology:** "Ranklista" (not "Ranklist"), "Kalendarz", "Komunikat organizatora" (not "Zaproszenie"), "Punktacja"
- **All admin views scoped** to the currently selected season in the header dropdown
- **No emoji icons** in sidebar menu items

## Consequences

- 7 HTML mockups locked as design reference — implementation must match approved mockups
- Cross-cutting rules ensure visual consistency across all views
- Admin UI views (Sezony, Wydarzenia, Tożsamości) are sidebar placeholders in M8; implementation deferred to M9
- Scoring config editor (Punktacja) is the only admin CRUD view implemented in M8
- EVF import, tournament management, and identity resolution UI designed in M8 but implemented in M9

## Mockup Registry

| Mockup | File | Status | Implementation |
|--------|------|--------|----------------|
| App Shell | `doc/mockups/m8_app_shell.html` | APPROVED | M8 (T8.4) |
| Calendar View | `doc/mockups/m8_calendar_view.html` | APPROVED | M8 (T8.5) |
| Admin Gate | `doc/mockups/m8_admin_gate_v2.html` | APPROVED | M8 (T8.6) |
| EVF Import | `doc/mockups/m8_evf_import.html` | APPROVED | M9 |
| Tournament Mgmt | `doc/mockups/m8_tournaments.html` | APPROVED | M9 |
| Identity Resolution | `doc/mockups/m8_identity_resolution.html` | APPROVED | M9 |
| Scoring Config | `doc/mockups/m8_scoring_config_A_form.html` | APPROVED | M8 (T8.8) |
