# ADR-035: Fencers View with Tabs

**Status:** Implemented  
**Date:** 2026-04-12  
**Source:** FR-56, FR-93, UC4, UC16

## Context

The admin Identity Manager (`admin_identities`) was a single-purpose view for match resolution. UC16 (Fencer Master Table Update) requires birth year review and editing capabilities. Rather than adding a separate admin view, we consolidate all fencer-related admin work into a tabbed "Fencers" view.

Additionally, many auto-created fencers have `bool_birth_year_estimated = TRUE` (estimated from tournament age category) or NULL birth years. Admins need a way to review, verify, and correct these birth years using tournament history as context.

## Decision

1. **Rename** `admin_identities` → `admin_fencers` across the entire stack (types, sidebar, locale keys, navigation).
2. **Tab bar inlined in `App.svelte`** (a separate `FencerView.svelte` wrapper was attempted but caused `state_unsafe_mutation` errors because Svelte 5 mounts both tab panels simultaneously and `$derived` blocks in BirthYearReview ran `Array.sort()` which mutates reactive state). The inline approach is simpler and proven:
   - **Tab 1: "Identities"** — existing `IdentityManager.svelte` with zero logic changes
   - **Tab 2: "Birth year review"** — new `BirthYearReview.svelte`
3. **Tab count badges** show pending work: Identities (actionable candidates), Birth year review (estimated + missing).
4. **Fencer count** in header: "Fencers (215)" / "Szermierze (215)".
5. **Birth year review** features:
   - Full fencer list with filters (birth year status, gender) and search
   - Click to expand edit form with read-only fencer info + editable birth year/accuracy + gender dropdown
   - Tournament history grouped by season (age category, weapon, place, score)
   - Birth year range hint derived from tournament age categories
   - Birth year auto-suggest (youngest boundary of youngest competed category)
   - Age category inconsistency flag (confirmed birth year contradicts tournament categories)
   - Sticky tab bar and filter row (anchored to top when scrolling)
   - Form closes on Save or Cancel
6. **New RPC** `fn_update_fencer_birth_year(p_fencer_id, p_birth_year, p_estimated)`.
7. **All UI text** uses `t()` for EN/PL internationalization.

## Related ADRs

- **ADR-010** (Age Category by Birth Year) — birth year is authoritative for ranking; this ADR adds admin editing + auto-suggest using the same age thresholds in reverse
- **ADR-015** (M8 UI Design) — sidebar nav design; rename from Identities to Fencers is safe refactor
- **ADR-016** (Supabase Auth MFA) — `fn_update_fencer_birth_year` follows same SECURITY DEFINER + REVOKE/GRANT pattern
- **ADR-019** (Domestic-Only Fencer Seed) — auto-created fencers have `bool_birth_year_estimated = TRUE`; the new tab lets admin confirm these
- **ADR-024** (Combined Category Splitting) — age category inconsistency handling precedent; extended to birth year vs. category detection
- **ADR-031** (Auto-Active Season by Date) — tournament history uses season scoping via auto-derived `bool_active`
- **ADR-033** (Fencer Gender + Identity Enhancements) — same pattern: wrappable IdentityManager, inline edit forms, gender mismatch warning; this ADR adds age category inconsistency warning analogously
- **ADR-034** (Cross-Gender Tournament Scoring) — gender mismatch is informational; same principle for age category inconsistency

Conflict scan: all 34 existing ADRs reviewed — zero conflicts.

## Alternatives

- **Separate "Fencer Review" admin view** — rejected; muddies sidebar with too many admin items. Tabs keep related concerns together.
- **Quick confirm button for estimated rows** — rejected per user preference ("no rush").
- **Server-side fencer search** — deferred; client-side filtering sufficient for current data volume.

## Consequences

- `admin_identities` completely removed from codebase (replaced by `admin_fencers`)
- IdentityManager.svelte preserved with zero changes
- Tab bar inlined in App.svelte (FencerView.svelte wrapper removed due to Svelte 5 `state_unsafe_mutation` — `Array.sort()` in `$derived` mutates reactive state)
- New component: `BirthYearReview.svelte` with gender edit, sticky filters, form auto-close
- New RPC: `fn_update_fencer_birth_year` (migration `20260412000004`)
- Svelte 5 lesson: never call `.sort()` on reactive arrays inside `$derived` — use `[...array].sort()` instead
- UC16 partially implemented (birth year + gender editing done; club/nationality editing and fencer merge deferred)
- Test count: pgTAP 254→259 (+5), vitest 241→255 (+14)

## UI Flow: New Fencer from Event Ingestion

### Step 1 — Ingestion (automated)
GitHub Actions scrapes tournament results → Python fuzzy matcher assigns status:
- **AUTO_MATCHED** (≥95%) — auto-linked, no action needed
- **PENDING** (50–94%) — provisionally linked, needs review
- **UNMATCHED** (<50%) — domestic PPW/MPW: auto-creates; international: skipped

### Step 2 — Admin opens Fencers → Identities tab
Default filter: PENDING. Each card shows scraped name, tournament, confidence, suggested match, status.

### Step 3 — Resolution
- **PENDING**: expand → verify → Save (approve) or switch to Create new / Search
- **UNMATCHED**: expand → Create new fencer (SURNAME ALL CAPS, gender, birth year)
- **AUTO_MATCHED**: expand → confirm or override
- **DISMISSED**: click Undo → back to PENDING

### Step 4 — Birth year confirmation (Fencers → Birth year review tab)
1. Switch to "Daty urodzenia" tab
2. Filter by "Estimated" or "Missing"
3. Click fencer → review tournament history + hint
4. Set correct birth year + accuracy "Exact (verified)"
5. Save
