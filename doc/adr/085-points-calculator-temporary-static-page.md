# ADR-085: Points Calculator as a Temporary Static Page — a One-Off Exception with an Expiry Condition

**Status:** Accepted (signed off 2026-08-15; §2 amended 2026-09-28)
**Date:** 2026-08-15
**Amended by:** [ADR-103](103-spws-place-medal-engine-per-type.md) (the joined mode and the SPWS/EVF toggle).
**Amends:** [ADR-015](015-m8-ui-design-decisions.md) §1 (App Navigation — Sidebar Drawer) — the drawer gains a third entry which is an external link rather than a view switch. §§2–9 are untouched.
**Relates to:** [ADR-011](011-artifact-release-pipeline.md) (frontend built once in CI and deployed to GitHub Pages — unchanged; the page rides the same artifact), [ADR-079](079-event-self-registration-identity.md) and [ADR-007](007-shadow-dom-deferred.md) (`register.html`, the existing standalone page, built through `vite.config.ce.ts` as a custom element — deliberately *not* the mechanism used here)
**Source:** `doc/plans/kalkulator-w-menu-ranklisty-2026-08-15.html` §4

## Amendment (2026-09-28 — the joined mode and the SPWS/EVF toggle)

[ADR-103](103-spws-place-medal-engine-per-type.md) gives the calculator a joined-bracket mode („Stawka łączona”, with K and m) and makes its toggle compare the new SPWS engine with EVF classic. The board preview recorded in the amendment below is deleted in the same release.

## Amendment (2026-09-28 — a third, time-limited page: the board preview of the 2026/2027 engine)

§2 is amended at the user's instruction of 2026-09-28.
[ADR-092](092-scoring-table-annex-bilingual-static-page.md) §3 requires a third standalone page
to carry its own decision, and [ADR-102](102-published-pages-share-one-scoring-module.md) open
item 2 left §2 to be revisited only if a third was proposed. This amendment is that decision.

**What is published.** `frontend/public/tabela-punktacji-projekt-2026-2027.html` is served at
`/tabela-punktacji-projekt-2026-2027.html` on the Pages origin, by the mechanism in §1. It shows
the board the proposed 2026/2027 SPWS formula: the three ranges by bracket size, the rules table,
a calculator with „Stawka łączona”, the medal table, the 64 × 64 grid and a worked example. The
content is the signed-off `doc/plans/tabela-punktacji-propozycja-2026-09-27.html` with one
change. Its footer link to an analysis under `doc/plans/` would return 404 on Pages, so that link
is now plain text.

**Why it may carry its own formula.** ADR-102 §1 ended private formula copies in the published
pages, because those pages show the scoring in force and must agree with the database. This page
shows a formula that no engine implements yet. The engine is drafted as ADR-103 in
`doc/plans/scoring-engine-2026-2027-implementation-plan-2026-09-28.html` and awaits sign-off.
There is nothing in `frontend/src/lib/scoring.ts` to generate the page from, and adding the
proposal there would be the engine work itself. This is the situation this ADR was written for,
and the duplication is bounded the same way, by an expiry.

**Conditions of the exception.** Each condition is held by a test or by the page itself.

1. **Self-contained.** The page computes everything in the browser. It has no `fetch`, no
   `#spws-env` element and no Supabase URL or key. The release workflow's credential step
   (`.github/workflows/release.yml`) therefore does not touch it, and it works offline. It links
   to no unpublished file. Test: SE27.PREVIEW.03.
2. **Not indexed, not linked.** It carries `noindex, nofollow` (test SE27.PREVIEW.02), and its
   footer reads „Projekt — nieprzyjęty”. The drawer does not link to it; the board receives the
   address. It is not Załącznik nr 1: the annex at `/tabela-punktacji.html` and the calculator at
   `/kalkulator-punktow.html` are unchanged, and they keep following the season's assigned engine
   (ADR-102).
3. **It ships.** Test SE27.PREVIEW.01. `frontend/scripts/build-scoring-pages.mjs` deliberately
   does not list the page, because the page carries no generated module.
4. **Expiry.** The page, together with SE27.PREVIEW.01–03, is deleted in the change that releases
   the 2026/2027 engine. That change rebuilds the annex and the calculator around the adopted
   formula, so the preview has nothing left to show. This expiry belongs to the preview alone. §3
   of this ADR was superseded by ADR-102, and this amendment does not revive it.

**§2 otherwise stands.** This page sets no precedent. A fourth page, or keeping this one past its
expiry, needs its own decision.

## Context

The points calculator (`doc/tools/kalkulator-punktow-za-wynik-spws.v2.html`) exists to show
fencers and the board the **proposed** scoring function before it becomes the scoring rule in
force. The proposal keeps the EVF algorithm intact — logarithmic place scale, 10 points per
direct-elimination round won, podium bonus `3·∛N` — and changes exactly one thing: the base for
first place, a flat 50 in EVF §3.2, becomes `f(N) = 10 · log₂N` capped at 50. That is 10 points
for every round of the bracket: 2 entries → 10, 4 → 20, 8 → 30, 16 → 40, 32 → 50. From 32 entries
upwards the base reaches its cap and the scoring is **identical to today's**, to the decimal.
It is one self-contained HTML file: styles, script and the SPWS logo as a `data:` URI, with
no external requests at all.

Distributing it as a file failed in practice. Opened from a messenger attachment or from the
iOS Files app it renders as bare HTML and CSS, because those previews do not execute
JavaScript; the calculator does all of its arithmetic in the browser, so nothing appears.
Verified on 2026-08-15 against two independent files and confirmed the other way round: served
over HTTP to the same iPhone, the same file computes correctly.

The tool therefore has to be reachable **at an address**. The ranklist frontend is already
built to `frontend/dist` and published to GitHub Pages by `.github/workflows/release.yml`
(jobs `build` → `deploy-pages`), so the address exists at no additional cost.

The repository already carries one standalone page next to the application —
`frontend/register.html` (RTM FR-130) — but it is produced from a separate Vite configuration
(`vite.config.ce.ts`) and copied into `dist` by a workflow step, because it embeds a Svelte
component compiled as a custom element. The calculator needs none of that.

## Decision

### 1 · Publication mechanism

The calculator ships as a static page at `frontend/public/kalkulator-punktow.html`. Vite copies
`public/` into `dist/` on its own, so no workflow step and no build-configuration entry is
required. The ranklist links to it from the navigation drawer with a plain relative `<a href>`,
carrying the application's active locale as `?lang=pl` or `?lang=en`, opened in a new tab so the
ranking view keeps its filters.

### 2 · This is an exception, not a pattern

**No other static page is expected to be published this way.** This decision covers one file with
a known lifetime and establishes no rule for future tools. Any further standalone page requires
its own decision; the default routes remain a view inside the application, or the mechanism used
for `register.html`.

### 3 · Expiry condition

When this scoring method is adopted as the SPWS scoring in force for the 2026/2027 season, the
page is **removed** and replaced by a calculator driven by the **ranklist scoring engine** — the
same engine that computes the ranking. Removed with it: the copy under `frontend/public/`, the
copy under `doc/tools/`, and plan test 8.88 which keeps the two in step. This ADR is then marked
superseded.

## Alternatives considered

1. **Build it through `vite.config.ce.ts`, as `register.html` is built.** Rejected: it adds a
   build step and a workflow copy step for a file that needs neither, and which is scheduled for
   deletion. It would also split one hand-maintained file into an input and an output, while the
   same file must stay directly uploadable to the SPWS WordPress site.
2. **Rewrite the calculator now as a Svelte view backed by the ranklist scoring engine.**
   Rejected *for now*, and recorded as the target state in §3. The engine implements the scoring
   currently in force (EVF); the calculator demonstrates a formula that is still a proposal.
   Wiring the proposal into the engine before the board decides would change ranking results.
3. **Host the calculator outside the repository.** Rejected: the ranklist already has a
   publication path, and a separate host is one more thing to keep alive.

## Consequences

- **Accepted duplication, bounded in time.** The scoring function now exists in two
  implementations: the ranklist engine (`fn_calc_tournament_scores`, scoring in force) and this
  page (the proposal). The duplication is small — the two differ only in the base for first place —
  and it ends with the page, under §3.
- **The proposal satisfies EVF §3.5 in full.** The six "Formula Requirements" hold for every field
  size from the minimum measurable up to 1000 — 5748 checks, zero violations, margins 2.9–8.0%,
  the same margins the EVF algorithm itself has. This is a consequence of keeping the round bonus
  as a separate, visible component: those six conditions require a step at each round boundary.
  An earlier draft of the proposal absorbed the round bonus into a smooth curve and broke all six;
  that variant was abandoned on 2026-08-15 for this reason.
- **The departure from EVF §3.2 is deliberate.** That section states the first placed gets 50 points
  whatever the size of the competition. Removing that constant is the entire point of the change:
  today, in a field of two, 70% of the winner's score comes from a component blind to field size.
- **The file bypasses the build pipeline**, so type checking and minification do not cover it.
  Correctness is held by plan test 8.88 — the published copy must be byte-identical to
  `doc/tools/kalkulator-punktow-za-wynik-spws.v2.html` — and by the control values documented in
  the plan. Control value: 3rd place out of 7 entries at rank 1.0 scores 28.5.
- **New files:** `frontend/public/kalkulator-punktow.html`, `frontend/tests/assets.test.ts`.
  **Changed:** `frontend/src/components/Sidebar.svelte` (third entry; the drawer now declares the
  application font stack explicitly, because it renders outside the container that carried it and
  the entries were resolving to different fonts), `frontend/src/lib/locales/{pl,en}.json`
  (`nav_calculator`), RTM FR-59.
- **Tests:** plan tests 8.84–8.88 added; no test removed.
- **Known divergence, deliberately not fixed:** the approved mockup
  `doc/mockups/m8_app_shell.html` (ADR-015) shows a two-entry drawer. It is a record of what was
  approved in M8 and is left as it is; this ADR is the current statement.
- **Defect observed and not fixed here:** the ranklist shows `[object Object]` instead of a
  readable message when it cannot reach the database. Pre-existing, unrelated to this change,
  worth its own fix.
- **Publication is public.** GitHub Pages serves the page to anyone with the address. The file
  carries `noindex, nofollow` so search engines skip it, but the drawer entry makes it reachable
  by every ranklist visitor. This was the user's explicit decision on 2026-08-15. The reservation
  recorded earlier the same day — that the proposal violated EVF §3.5 — no longer applies: the
  formula was reworked to `f(N)` and now satisfies all six conditions.
