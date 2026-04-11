# ADR-032: Drilldown Mobile Card Layout

**Status:** Implemented  
**Date:** 2026-04-11  
**Source:** NFR-09, FR-36, FR-66

## Context

The DrilldownModal's 7-column tournament table (`Tournament`, `Date`, `Type`, `Place`, `N`, `Mult`, `Points`) requires `min-width: 480px` which overflows on mobile screens (375px). Users must rotate their phone to landscape to view the data, especially in +EVF/KADRA mode where two tables (domestic + international) are rendered. This is the only component in the web widget that breaks on mobile.

Four alternatives were evaluated via HTML mockups (`doc/mockups/drilldown-mobile-options.html`) with real data (KORONA Przemyslaw, V2 EPEE, +EVF mode, 11 tournament results):
- **Option A: Responsive Card Layout** (selected)
- Option B: Column Hiding + Expand Row
- Option C: Sticky First Column + Horizontal Scroll
- Option D: Transposed Vertical Layout

## Decision

Use **dual rendering with CSS show/hide**: render both the existing `<table>` and a new card layout (`.card-list`) in the DOM. A CSS media query (`@media max-width: 600px`) hides the table and shows cards on mobile, and vice versa on desktop.

### Card layout structure

Each tournament result renders as a `.result-card`:

```
┌──────────────────────────────────────────────┐
│ PPW4-V2-M-EPEE-2025-2026         110.02 ★   │  .card-top: code (link?) + points+marker
│ Gdansk · 21 Feb 26 · PPW · 1/11 · x1.0     │  .card-meta: location · date · type · place/N · mult
│ ↩ SPWS-2024-2025                             │  .card-carried-badge (conditional)
└──────────────────────────────────────────────┘
```

All 11 data fields from the table are preserved: tournament code (text or link with `target=_blank`), location, carried badge, formatted date, type badge (`.domestic`/`.international`), place, participant count, multiplier, points with marker, and carried-row styling.

### Why dual rendering

- **No JS viewport detection** — pure CSS media query, zero runtime cost
- **Existing tests preserved** — jsdom does not evaluate CSS, so both layouts are always queryable; all 24 existing DrilldownModal tests pass unchanged
- **New tests independent** — 14 new tests query card elements by CSS class without needing media query simulation

## Alternatives Considered

| Option | Pros | Cons | Rejected because |
|--------|------|------|------------------|
| B: Column Hiding + Expand | Keeps tabular feel, compact | Extra tap for details, discoverability poor | Not all data visible at a glance |
| C: Sticky First Column | Minimal code change | Still requires horizontal swiping | Doesn't solve the core problem |
| D: Transposed Vertical | Max readability | Most vertical space, loses comparison | Too much scrolling for 11 results |
| JS `matchMedia` listener | Only renders one layout | Complicates testing, needs resize listener | More complexity for no user benefit |

## Consequences

- **Positive:** Drilldown fits on 375px screens without rotation; no information loss; desktop unchanged
- **Positive:** 14 new vitest assertions cover every card field (C.1–C.14)
- **Negative:** DOM contains both layouts (~2x markup in `.table-section`); negligible perf impact since tables have max ~15 rows
- **Constraint:** Future table column additions must be mirrored in the card snippet
