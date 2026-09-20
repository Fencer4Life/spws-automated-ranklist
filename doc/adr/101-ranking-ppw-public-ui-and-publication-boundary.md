# ADR-101: The public ranking switch is Ranking / PPW; publication capability is read, not re-decided, by the UI

**Status:** Accepted (drafted in [doc/plans/admin-public-ranking-ui-2026-09-20.html](../plans/admin-public-ranking-ui-2026-09-20.html) §03, signed off 2026-09-20). Implemented and verified on LOCAL against a live browser preview (`frontend/index.ce.html` via `vite --config vite.config.ce.ts`): the FULL-publication season shows the switch and defaults to Ranking with `SPWS`/`EVF+`/`Razem` columns and populated rows; selecting the `PPW_ONLY` season hides the switch and forces a single `Punkty` column; returning to the FULL season restores the switch and the Ranking default; the drilldown modal shows the same switch, the SPWS/EVF+ bar breakdown and the three-figure compact summary. 912 Vitest cases and 11 Playwright cases (7 existing + 4 new) pass; `svelte-check` reports 0 errors (20 pre-existing, unrelated warnings).
**Date:** 2026-09-20
**Extends:** [ADR-045](045-engine-selector-default-flip.md)/[ADR-042](042-carryover-engine-dispatcher.md) (the `carryover_engine` naming this ADR finishes at the frontend's last remaining ambiguous site)
**Relates to:** [ADR-098](098-ranking-schema-v2-and-generalized-ranking-rpc.md) (this ADR is the frontend cutover onto `fn_ranking_full` that step 4 deferred), [ADR-099](099-ranking-publication-boundary.md) (this ADR is the frontend enforcement/presentation step 7 deferred — `enum_ranking_publication` read for the first time here), [ADR-100](100-pzsz-senior-result-ingestion.md) (PZSz results now render with distinct bar provenance in the drilldown this ADR changes)
**Source:** `frontend/src/lib/types.ts`, `frontend/src/lib/api.ts`, `frontend/src/lib/export.ts`, `frontend/src/lib/mock-data.ts`, `frontend/src/App.svelte`, `frontend/src/ce/RanklistElement.svelte`, `frontend/src/ce/CalendarElement.svelte`, `frontend/src/components/FilterBar.svelte`, `frontend/src/components/RanklistTable.svelte`, `frontend/src/components/DrilldownModal.svelte`, `frontend/src/components/ScoringConfigEditor.svelte`, `frontend/src/components/SeasonManagerWizard.svelte`, `frontend/src/lib/locales/{pl,en}.json`, `supabase/seed_prod_2026-09-12.sql`, `frontend/e2e/ranking-publication-boundary.spec.ts`

## Context

Design steps 4/5/6 (ADR-098/099/100) built the schema-v2 ranking RPC, the immutable per-season publication capability, and PZSz senior ingestion — all backend-only, all deliberately deferring frontend consumption. The frontend still called the legacy `fn_ranking_kadra`, had never read `enum_ranking_publication`, and still called its combined ranking mode `KADRA` with button labels "SPWS"/"EVF+". Separately, the Admin scoring-lock UI the original design's step-7 prose assumed this step would build had already shipped in step 3, ahead of schedule (confirmed live before drafting the plan) — so this ADR's scope is narrower than the design doc's own step-7 description: the *public* ranking UI, publication enforcement, staleness handling and the last `carryover_engine` naming cleanup, not the Admin lock UI.

## Decision

### 1 · The combined mode is renamed, not just relabeled

`RankingMode` becomes `'PPW' | 'RANKING'` (was `'PPW' | 'KADRA'`) everywhere — type, component props, locale keys, test fixtures. `RANKING` calls the new `fetchRankingFull`/`fn_ranking_full`; `PPW` keeps calling `fetchRankingPpw`/`fn_ranking_ppw` unchanged. `fn_ranking_kadra` is no longer called by the frontend but stays in the database — pgTAP's own parity tests still need it as the independent oracle for `fn_ranking_full`.

### 2 · Publication capability and the season's default mode are read with no new RPC

`fetchSeasons()`'s column list gains `enum_ranking_publication` (same table, same query). The season's `default_ranking_mode` is read by reusing the already anon-executable `fn_export_scoring_config(id_season)` — the same call `refreshEvfToggle()` already made for the `show_evf_toggle`/`show_evf_toggle_calendar` flags already carries `default_ranking_mode` in its JSON, unused until this step typed it. A narrower dedicated RPC was considered and rejected as premature surface addition matching this codebase's established pattern (steps 4–6: reuse an existing anon-executable RPC over adding a new one).

### 3 · The UI normalizes and hides; it does not additionally gate

When the selected season's `enum_ranking_publication = 'PPW_ONLY'`, `App.svelte` forces `filters.mode = 'PPW'` before issuing any ranking fetch and does not render the switch at all (absent, not disabled). This is presentation of a capability the backend already enforces (`fn_ranking_full`'s own exception, ADR-099) — removing this JS entirely would still leave the RPC refusing the request.

### 4 · V0's three duplicated guards are deleted, not consolidated

There is no remaining reason to disable Ranking for V0 (§06 of the design: its EVF/FIE subsection is naturally empty, while SPWS and PZSz can contribute), and a PZSz senior field admits any age including V0. All three sites (`FilterBar`'s button `disabled`, `App.svelte`'s `refreshEvfToggle`, the inherited `kadraDisabled` prop threaded through `DrilldownModal`) are deleted outright. `showEvfToggle` (publication AND config-driven) remains the sole gate on whether the switch renders.

### 5 · Two independent request-generation counters, not one

The design sketched a single monotonic counter guarding every async ranking/drilldown load. Implementation uses **two** — `rankingGen` for `loadRanking()`, `drilldownGen` for `openDrilldown()`/`closeDrilldown()` — because they write disjoint state (`ppwRows`/`fullRows`/`rankingRules` vs. `modalScores`/`modalContext`), and a single shared counter would let opening or closing an unrelated drilldown wrongly discard an in-flight, unrelated ranklist load. Each captures `const gen = ++theirGen` before its first `await` and checks `gen === theirGen` before applying a resolved value to state.

### 6 · EVF+ bar coloring is provenance-only, computed from `enum_type`

`DrilldownModal.svelte`'s `INTL_TYPES` splits into `EVF_TYPES = ['PEW','MEW','MSW','PSW']` (orange) and `PZSZ_TYPES = ['PPS','MPS']` (red, the same PZSz brand red already used in `EventCard.svelte`/`CalendarBarrel.svelte`); both still sum into the one `evf_plus_total`/international column total. A provenance legend (EVF/FIE, PZSz swatches) renders only when a PZSz result is actually present, alongside the existing current/carried markers — color never creates a separate subtotal.

### 7 · `ScoringConfig.engine` is renamed to `ScoringConfig.carryover_engine`

The last frontend site using the bare, ambiguous `engine` name for the carry-over matcher (the database column, the `CarryoverEngine` type and the Admin selector's own variable names were already unambiguous). Renamed across `types.ts`, `ScoringConfigEditor.svelte`'s save-payload construction, `SeasonManagerWizard.svelte`'s default-config object, and `App.svelte`'s save-handler read site. `engine_code` (the scoring engine) is unaffected and independently settable — pinned by new `SS26.CARRY` test coverage.

### 8 · The seed's `SPWS-2026-2027` row gains an explicit `enum_default_ranking_mode`

Same fix shape as ADR-099's own seed amendment for `enum_ranking_publication`: migrations run before the seed dump, so a plain re-`INSERT` in `supabase/seed_prod_2026-09-12.sql` (the file `seed_prod_latest.sql` actually symlinks to — the stale, unused `seed_prod_2026-07-19.sql` was checked and discarded as a candidate) silently regressed this column to its default. Fixed by adding `enum_default_ranking_mode = 'RANKING'` to the season's own `UPDATE`.

## Alternatives considered

1. **A new, narrower public RPC exposing only `enum_ranking_publication` + `default_ranking_mode`.** Rejected per point 2 above — premature surface addition when the existing anon-executable RPC already carries the field needed.
2. **`AbortController`-based request cancellation.** Rejected: Supabase's JS client does not expose per-call cancellation cleanly through the existing `api.ts` wrapper functions, and a discard-on-arrival counter needs no change to those signatures.
3. **Keeping `KADRA` as the internal value, renaming only the display label.** Rejected: the design's own definition-of-done treats the mode name itself, not just its label, as part of the "Ranking/PPW" contract; a display-only rename would leave code and fixtures asserting a name that no longer means what it says.
4. **One shared request-generation counter (as originally sketched).** Rejected during implementation per point 5 above — a correctness fix, not a simplification.

## Consequences

`fn_ranking_kadra` becomes dead code from the frontend's perspective but stays in the database, still tested, still `fn_ranking_full`'s parity oracle. The public ranklist page now makes one additional RPC call per season change (`fetchScoringConfig`) it never made before — accepted per point 2. Every test file asserting `'KADRA'`/"EVF+ button" text was rewritten, not extended (`FilterBar.test.ts`, `RanklistTable.test.ts`, `DrilldownModal.test.ts`, `export.test.ts`) — a mechanical but wide-surface diff.

Three corrections made during implementation, not assumed at plan time:

- **A demo-mode-only reactive loop.** `App.svelte`'s root `$effect` calling `initDemo()` (and, symmetrically, `init()`) both writes state (`filters`, via `{...filters, mode: ...}`) and, transitively through `refreshEvfToggle()`, reads that same state — entirely inside the effect's own synchronous execution window, since the demo path has no `await` to leave that window before touching it. Svelte attributes any state read during an effect's synchronous run to that effect, so the write-of-a-fresh-object-every-run kept re-triggering the same effect indefinitely (`effect_update_depth_exceeded`). The real-client `init()` path never hit this because its first `await` (`refreshActiveSeason()`) already left the tracking window before the same reads/writes occurred. Fixed by wrapping both call sites in `untrack()`. This is a Svelte 5 reactivity pitfall specific to fully-synchronous effect bodies, not a defect in the publication-boundary logic itself.
- **A pre-existing custom-element boolean-attribute gap, unmasked by the fix above.** `<spws-ranklist demo>`/`<spws-calendar demo>` set the HTML `demo` attribute to `""`; Svelte's custom-element wrapper reflects an unconfigured attribute as a raw string by default, so `if (demo)` evaluated the falsy empty string and neither `initDemo()` nor the real-client `init()` branch ever ran — the demo page silently rendered nothing. This predates this ADR (present on `main` before this branch) and was masked precisely because the untriggered `initDemo()` also could not hit the reactive loop above. Fixed by declaring `demo` as a typed boolean prop (`<svelte:options customElement={{ tag: '...', props: { demo: { type: 'Boolean' } } }} />`) on both `RanklistElement.svelte` and `CalendarElement.svelte`.
- **`initDemo()` never populated `fullRows`.** It set `ppwRows` directly and left row-loading in Ranking mode to nothing, since `loadRanking()` — the only function that populates `fullRows` — was never called from the demo init path. Fixed by having `initDemo()` call `refreshEvfToggle()` (which settles `filters.mode`) followed by `loadRanking()` (whose existing demo branch already picks `MOCK_PPW_ROWS` vs. `MOCK_FULL_ROWS` from that mode) instead of assigning `ppwRows` directly.

A fourth, non-reactive bug was also found and fixed: `DrilldownModal.svelte`'s legacy (non-JSONB `rankingRules`) chart branch handled only `MEW`/`PEW` explicitly and silently dropped `MSW`/`PSW`/`PPS`/`MPS` scores from the chart entirely. Fixed with a generic fallback loop over the remaining international types, needed for PZSz results (ADR-100) to render in the drilldown when JSONB ranking rules are not loaded.

**New:** `frontend/e2e/ranking-publication-boundary.spec.ts` (4 new Playwright cases covering design §09 scenario E). **Modified:** every file listed under Source above, plus `frontend/tests/FilterBar.test.ts`, `RanklistTable.test.ts`, `DrilldownModal.test.ts`, `export.test.ts`, `ScoringConfigEditor.test.ts`, `SeasonManagerWizard.test.ts`, `SeasonManager.test.ts`, `AppShell.test.ts` (new `SS26.UIHIST` describe block), `EventManager.test.ts`.

**Test impact.** Frontend-only — no new pgTAP (1123 assertions unchanged). Vitest: 912 passing (up from before this step; existing suites rewritten, not extended, for the mode rename). Playwright: 11 passing (7 existing `shadow-dom.spec.ts` + 4 new). `svelte-check`: 0 errors, 20 pre-existing unrelated warnings.

**Verified on LOCAL (2026-09-20).** Live browser walkthrough against `frontend/index.ce.html` (`vite --config vite.config.ce.ts`, demo mode): the FULL season (2024/25) opens on Ranking with `SPWS`/`EVF+`/`Razem` columns and 12 populated rows; clicking PPW switches to a single `Punkty` column with the same rows; selecting the PPW_ONLY season (2023/24) hides the switch entirely and shows only `Punkty`; returning to the FULL season restores the switch, defaulting back to Ranking; opening a drilldown row shows the same PPW/Ranking switch, the SPWS (blue) / EVF+ (orange) bar breakdown and the three-figure compact summary (`PPW Suma` / `EVF+ Suma` / `Razem`). No console errors on a clean page load after the fixes above.
