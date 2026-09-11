# ADR-092: A Second Standalone Static Page — the Scoring-Table Annex, Published Bilingually

**Status:** Accepted (proposed 2026-09-11, signed off 2026-09-11)
**Date:** 2026-09-11
**Amends:** [ADR-015](015-m8-ui-design-decisions.md) §1 (App Navigation — Sidebar Drawer) — the drawer gains a **fourth** entry, again an external link rather than a view switch; §§2–9 untouched. [ADR-085](085-points-calculator-temporary-static-page.md) — its *Tests* consequence only: plan test 8.84 pins the drawer's entry list as an equality, so a fourth entry necessarily extends that assertion. ADR-085 §§1–3 — the calculator's publication mechanism, its status as an exception and its expiry condition — are untouched.
**Relates to:** [ADR-085](085-points-calculator-temporary-static-page.md) §2, which requires any further standalone page to carry its own decision — this is that decision; [ADR-011](011-artifact-release-pipeline.md) (the page rides the existing Pages artifact, unchanged); [ADR-090](090-prod-surface-as-wordpress-menu-item.md) (the eventual WordPress destination); [ADR-079](079-event-self-registration-identity.md) and [ADR-007](007-shadow-dom-deferred.md) (`register.html`, built as a custom element through `vite.config.ce.ts` — deliberately *not* the mechanism used here)
**Source:** `doc/plans/tabela-punktacji-2026-09-11.html` §6

## Context

`doc/tools/Tabela-punktacji-SPWS_2026-2027.html` is **Załącznik nr 1** to the Regulation on
selecting the Polish veterans national team. It carries a single-result calculator, the full
scoring table for fields of 4 to 300 entries across places 1 to 300, and a CSV export. It is one
self-contained file: styles, script and all content inline, with no external requests.

It has to be reachable **at an address**, for the reason ADR-085 recorded and verified on
2026-08-15: messenger and iOS Files previews open HTML with JavaScript disabled, and this document
computes its entire table in the browser. Sent as an attachment it arrives blank. The ranklist is
already built to `frontend/dist` and published to GitHub Pages by `.github/workflows/release.yml`
(jobs `build` → `deploy-pages`), so the address exists at no additional cost.

**The annex and the calculator implement the same formula, and this was verified rather than
assumed.** The annex's `firstPlaceBase` (`:233`) matches the calculator's `fN`, including the
`max(2, n)` floor; `wonRounds` matches `rundy`, including the `(n & (n − 1))` power-of-two test;
`scoreParts` matches `parts`, including the place formula `base − (base − 1)·ln(m)/ln(N)`, the
`{1:3, 2:2, 3:1}` podium factors and the `3·∛N` unit; and the rank slider matches `#fW` at
`min=1 max=3 step=0.1`. One difference is deliberate and stated in the annex's own heading: its
domain starts at `N ≥ 4` (`:209`) where the calculator accepts `N ≥ 2`.

Two facts shape the decision beyond publication. First, the annex is destined for
`weteraniszermierki.pl` as a PROD deployment once it is adopted (ADR-090), so nothing in its design
may depend on the ranklist application around it — a WordPress page has no `Sidebar.svelte` and no
`?lang=` contract. Second, it must serve fencers who read Polish and an audience abroad who do not,
which the calculator solves with a JavaScript string dictionary (`:272`) that this document cannot
reuse: it is prose as well as UI, and a dictionary renders an **empty page** when JavaScript does
not run — the exact failure that made hosting necessary.

## Decision

### 1 · Publication mechanism

The annex ships as a static page at `frontend/public/tabela-punktacji.html`. Vite copies `public/`
into `dist/` on its own, so no workflow step and no build-configuration entry is required. The
ranklist links to it from the navigation drawer as a **fourth** entry, directly after the
calculator, with a plain relative `<a href>` carrying the application's active locale as
`?lang=pl` or `?lang=en`, opened in a new tab so the ranking view keeps its filters — the same
shape as the calculator entry (`Sidebar.svelte:40`).

The published name is lowercase and hyphenated, matching `kalkulator-punktow.html`, because it
becomes a permanent public URL and later a WordPress slug. The hand-maintained source of truth
stays at `doc/tools/Tabela-punktacji-SPWS_2026-2027.html`, with the published copy held
byte-identical to it by test, as ADR-085 §3 does for the calculator.

### 2 · Bilingual in one file, switched by CSS

Polish and English both live in the markup as sibling blocks, each carrying its own `lang`
attribute, and the PL/EN toggle is a radio pair switched by **CSS alone**:

```
#langPl:checked ~ main .copy-en { display: none }
#langEn:checked ~ main .copy-pl { display: none }
```

JavaScript adds enhancements only, never preconditions: it honours `?lang=pl|en` when present,
remembers the choice, and corrects `document.documentElement.lang` and `document.title`. It reuses
the calculator's hand-rolled `param()` helper (`:421`) and its `try/catch` around `localStorage`
(`:431`) — that guard exists because storage access *throws* when the file is opened over `file:`.

Three properties follow, and all three are the point:

- The document works **with JavaScript disabled**, in either language. The previews that render the
  calculator blank still show a readable annex.
- It works **opened cold at any address**, with or without a query string. It depends on nothing
  around it, which is what the WordPress destination requires.
- Only the static copy is duplicated. The table, the calculator logic and the script stay single;
  `numberPl` gains an English branch for the decimal separator, mirroring the calculator's `num()`.

English terminology is carried over verbatim from the calculator's `T.en` (`:272`) — *Number of
entries*, *Finishing place*, *Competition rank coefficient*, *Base for 1st place*, *Round bonus*,
*Podium bonus* and the rest. Two documents describing one formula must not ship two competing
English vocabularies for it.

### 3 · This remains an exception

Two pages now use this route. Both are informational documents about the scoring formula, both are
hand-maintained single files, and both have a known destination outside the application. **This
still establishes no general pattern.** A third standalone page requires its own decision. The
default routes remain a view inside the application, or the mechanism used for `register.html`.

### 4 · `noindex` while unadopted, and succession

The page carries `<meta name="robots" content="noindex, nofollow">` for as long as the annex is not
adopted.

This is **load-bearing, not boilerplate**. The document's header originally displayed
*Wersja 0.1 · Status: projekt*; that was removed on 2026-09-11 at the user's request, so the page no
longer states anywhere that it is a draft. The `noindex` meta is now the only thing keeping an
unadopted regulation annex out of search results, where it could be found and read as adopted
policy. Removing it is a deliberate act performed at adoption, not a tidy-up.

On adoption the annex moves to `weteraniszermierki.pl` as a PROD deployment. The file transfers
unchanged, because it never depended on the drawer, the `?lang=` parameter or any relative path; the
drawer entry is replaced by a WordPress menu item built by hand in `wp-admin`, which is the only
route available since menu items cannot be verified over XML-RPC. **This ADR is revisited at that
point rather than silently outlived.**

## Alternatives considered

1. **Reuse the existing calculator entry, serving the annex when a desktop browser is detected.**
   Proposed and rejected on 2026-09-11. A single entry labelled "Kalkulator punktów" that opens a
   different document on desktop misdescribes itself on half of all visits; viewport width is not
   device, so an iPad in landscape, a narrowed window or Android's "Request desktop site" each
   misfire and leave the visitor with no route at all to the other document; and a shared URL stops
   being shareable. Decisively, the drawer exists only in the Pages copy of the application, so
   branching logic written into it is scaffolding discarded at the WordPress migration while the
   document survives. Behaviour that matters long-term belongs inside the file.
2. **One drawer entry opening an index page listing both documents.** Rejected for now: it keeps the
   drawer at three entries but adds a layer to solve a problem two documents do not yet have, and it
   costs the calculator — the more frequently used of the two — an extra click. Worth revisiting at
   a third document.
3. **Two files, one per language, cross-linked.** Rejected: duplicated chrome and CSS, two permanent
   URLs and two WordPress slugs to keep alive, and nothing mechanically prevents the versions
   drifting apart.
4. **The calculator's JavaScript string dictionary.** Rejected: it would put whole paragraphs of
   prose into JavaScript string literals and render an empty page when JavaScript does not run,
   which is the failure this publication exists to avoid.
5. **Build it through `vite.config.ce.ts`, as `register.html` is built.** Rejected for the reason
   ADR-085 gave: it adds a build step and a workflow copy step for a file that needs neither, splits
   one hand-maintained file into an input and an output, and the same file must stay directly
   uploadable to the SPWS WordPress site.

## Consequences

- **The scoring function now exists in three implementations.** The ranklist engine
  (`fn_calc_tournament_scores`, the scoring in force), the calculator page and this annex — the
  latter two both expressing the proposal. The two pages are **verified identical by reading, not by
  a test**, because they are independent documents rather than copies of one file; a byte-identity
  assertion of the kind that guards the calculator's three copies cannot express this. ADR-085 §3
  already commits to collapsing the duplication when the proposal becomes the scoring in force.
- **A pinned test changes rather than being deleted.** Plan test 8.84 (`Sidebar.test.ts:86`) asserts
  the drawer's entries as an **equality**, so the fourth entry necessarily extends it. The assertion
  is extended, not loosened to a containment, because the *order* is the property worth holding.
- **The file bypasses the build pipeline**, so type checking and minification do not cover it — the
  same accepted cost as ADR-085. Correctness is held by the byte-identity test against the
  `doc/tools/` source, by assertions that both language blocks and the CSS switch rules are present,
  and by the verified parity recorded in *Context*.
- **A silent failure mode is introduced and recorded.** The CSS switch uses the general sibling
  combinator, which requires the radio inputs to precede the content blocks and share a parent with
  `<main>`. Reordering the markup later breaks the switch with no error — the page simply sticks in
  one language. `:has()` would lift the constraint and is deliberately not used, consistent with the
  conservative-API house style of these files.
- **New files:** `frontend/public/tabela-punktacji.html`, `doc/plans/tabela-punktacji-2026-09-11.html`.
  **Changed:** `doc/tools/Tabela-punktacji-SPWS_2026-2027.html` (`noindex`, bilingual layer, English
  copy), `frontend/src/components/Sidebar.svelte` (fourth entry),
  `frontend/src/lib/locales/{pl,en}.json` (`nav_points_table`), RTM FR-59.
- **Tests:** 8.84 extended; 8.90–8.96 added; no test removed.
- **Publication is public.** GitHub Pages serves the page to anyone with the address. The `noindex`
  meta keeps search engines away, but the drawer entry makes it reachable by every ranklist visitor
  while the annex is still a draft. This is the same trade the user accepted for the calculator on
  2026-08-15, made again here knowingly.
- **A dependency on an absolute URL is accepted.** The annex links to the calculator at its full
  Pages address rather than relatively, which is correct for the WordPress destination — a relative
  link would 404 under a WordPress path. It follows that when the *calculator* moves to WordPress,
  this link must be updated; nothing detects that automatically.
- **Known divergence, deliberately not fixed:** the approved mockup `doc/mockups/m8_app_shell.html`
  (ADR-015) shows a two-entry drawer and was already divergent after ADR-085. It remains a record of
  what was approved in M8; this ADR is the current statement.
- **Observed and deliberately not addressed here:** the annex renders roughly 89,100 table cells
  (297 rows × 300 columns) as DOM nodes in twelve-row chunks, and its print stylesheet lifts the
  container's `max-height`, so printing yields the entire table. The user has tested the document as
  it stands. If either is ever addressed, the fix belongs **inside** the document — fewer default
  columns, virtualised rows, a bounded print range — and never in drawer navigation.
