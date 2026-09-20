# ADR-102: The Published Pages Share One Scoring Module and Read Season Parameters

**Status:** Draft (proposed 2026-09-20; awaiting sign-off)
**Date:** 2026-09-20
**Supersedes:** [ADR-085](085-points-calculator-temporary-static-page.md) §3 (Expiry condition) — its *intent* is fulfilled and its *mechanism* is reversed: the calculator is driven by the ranklist scoring engine as §3 required, but it is **kept at its address** rather than removed, and plan test 8.88 is kept rather than deleted. §§1–2 (publication mechanism, exception-not-pattern) are untouched and still bind.
**Amends:** [ADR-092](092-scoring-table-annex-bilingual-static-page.md) — the scoring-table annex stops carrying its own copy of the formula and computes from the shared module. Its identity is unchanged: it stays *Załącznik nr 1* pinned to `SPWS-2026-2027`, by season code, and does not follow the active season.
**Relates to:** [ADR-083](083-server-enforced-authorization.md) (deny-by-default: the new function is granted to `anon` in both copies of the allowlist), [ADR-097](097-scoring-governance-lock-and-privileged-revision.md) (the lock that freezes these pages along with the scorer), [ADR-011](011-artifact-release-pipeline.md) (both pages still ride the same Pages artifact), [ADR-090](090-prod-surface-as-wordpress-menu-item.md) (the WordPress destination), [ADR-066](066-min-participants-ingestion-gate.md) (walkover brackets, which the new base re-prices)
**Source:** `doc/plans/versioned-season-scoring-and-pzsz-ranking-design.html` §08 and §11 step 8

## Context

The scoring formula was written **three times** in browser JavaScript:

- `doc/tools/kalkulator-punktow-za-wynik-spws.v2.html` — `fN` / `rundy` / `parts` / `total`
- `doc/tools/WP-kalkulator-punktow-za-wynik-spws.html` — a byte-identical copy
- `doc/tools/Tabela-punktacji-SPWS_2026-2027.html` — `firstPlaceBase` / `wonRounds` / `scoreParts` / `totalScore`

ADR-085 accepted this duplication explicitly and bounded it in time: "the scoring function now
exists in two implementations … and it ends with the page, under §3". Two things have since
changed.

**The duplication stopped being two and stopped being identical.** ADR-092 added the annex,
independently implemented, making three. They had already drifted where nobody would look: the
annex refuses fields below `MIN_PARTICIPANTS = 4` while the calculator accepts `N = 1`. Nothing
compared them, because plan test 8.88 asserts that the calculator's three *copies* match each
other — not that the annex agrees with the calculator, and not that either agrees with the
database.

**The proposal became the rule.** ADR-085 §3's trigger has fired: the field-scaled formula is
adopted for 2026/2027 and implemented in the database as
`fn_score_spws_field_scaled_v1_2026_2027`, assigned to that season and dispatched to by engine
code (ADR-097). ADR-085's alternative 2 was rejected because "wiring the proposal into the engine
before the board decides would change ranking results" — the board has decided, so that reason
has expired.

What §3 did **not** anticipate is that the page is worth keeping. It is linked from the
navigation drawer, it is the artefact the board and fencers actually open, and deleting it would
remove the only place where the two engines can be compared side by side.

## Decision

### 1 · One formula, generated into the pages

`frontend/src/lib/scoring.ts` is the single browser-side implementation. Both published pages
carry a **generated build artefact** of it, written between fixed markers by
`frontend/scripts/build-scoring-pages.mjs`, which bundles the module with esbuild and then copies
the `doc/tools/` source byte-for-byte to its published and WordPress destinations. Nothing else
may write between the markers. `--check` fails when a page is stale — the same contract
`scripts/render_docs.py --check` provides for the generated HTML twins — and it is a
`scripts/preflight.sh` gate.

The formula consequently lives in exactly **two** places: this module and the SQL strategies.
`frontend/tests/scoring.test.ts` is the pin between them, with all 27 expectations derived by
calling `fn_score_by_engine` against a live database rather than written by hand.

### 2 · The numbers come from the season, not from the page

`fn_public_scoring_params(p_season_code TEXT DEFAULT NULL)` publishes one season's assigned
engine code and label together with its own `int_mp_value` and podium coefficients, plus
`base_slope` and `de_round` as **separate** parameters — the two unrelated tens that merely
coincide at 10. `STABLE`, `SECURITY DEFINER` (because `tbl_scoring_engine` carries RLS with no
policy), pinned `search_path`, and it exposes no mutable registry field. An unknown season code
returns zero rows rather than raising, so the page renders its own message instead of surfacing
an opaque 400 to an anonymous visitor.

A `NULL` code means the active season. The calculator passes `NULL`; the annex passes
`SPWS-2026-2027` explicitly.

This is what makes a pre-lock Admin edit reach the engine, the calculator and the annex alike.
It also means the freeze is free: once ADR-097's lock closes the season's configuration, the
parameters stop changing and all three surfaces freeze together. **The database lock is the only
lock**; neither page needs a freezing mechanism of its own.

### 3 · The two pages bind to different seasons, deliberately

The calculator follows the **active** season. The annex stays **pinned to 2026/2027** by season
code. A regulation annex that silently re-rendered itself under the same title when the season
rolled over would no longer be the document it declares itself to be.

### 4 · Credentials are embedded, as they already are elsewhere

Both pages carry a hidden `#spws-env` element whose attributes
`.github/workflows/release.yml` rewrites from GitHub Secrets at build time, exactly as it already
does for `index.html` and `register.html`. The repository holds LOCAL placeholders; the existing
*no localhost in dist* guard fails the build if the rewrite is skipped. The `anon` key is a public
credential protected by RLS and the 52.7 allowlist rather than by secrecy.

### 5 · `fn_preview_tournament_score` stays revoked from `anon`

It takes an `id_tournament`, which neither published page has — both take N and place as user
input. Publishing it would widen the anon surface to per-tournament previews for no gain. The
invariant that matters is that whatever the pages *do* call is granted in **both** copies of the
allowlist in the same change: `supabase/tests/52_security_posture.sql` and
`scripts/check-security-posture.sh`, which drifted on 2026-09-12 and blocked a PROD deploy.

## Alternatives considered

1. **Delete the calculator, as ADR-085 §3 directed.** Rejected. §3 assumed the page's only
   purpose was to preview a proposal, so adoption would retire it. In practice it is the
   artefact the board and fencers open, it is linked from the drawer (ADR-085 §1, ADR-092), and
   it is the only surface where the classic and field-scaled engines can be compared directly.
   Its *intent* — "driven by the ranklist scoring engine" — is met without deleting anything.
2. **Make the pages Vite entry points.** Rejected: they would leave `frontend/public/` and their
   published paths would change, which §08 forbids. This is also ADR-085 alternative 1, whose
   stated objection was that building would "split one hand-maintained file into an input and an
   output, while the same file must stay directly uploadable to the SPWS WordPress site". Half of
   that objection now stands answered and half is accepted: the file *does* become a generated
   output, which is the price of having one formula — but it stays **one file**, still directly
   uploadable, which is exactly why alternative 3 was rejected too.
3. **Emit one shared `.js` beside the pages and `import` it.** Rejected: it turns the
   hand-carried WordPress calculator into two files that must travel together, and that page
   exists precisely to be carried as one.
4. **Have the pages call a score RPC per value, or fetch a whole precomputed grid.** Rejected:
   the annex renders up to 300 × 300 cells and re-renders on every rank-coefficient change. A
   round trip per value is unusable, and a grid response is roughly a megabyte per change.
5. **Keep the annex's numbers static and regenerate them at deploy.** Rejected: an administrator
   editing configuration before the season's first scored result would not see the annex change
   until someone rebuilt, which is the failure this step exists to remove.

## Consequences

- **New files:** `frontend/src/lib/scoring.ts`, `frontend/tests/scoring.test.ts`,
  `frontend/scripts/build-scoring-pages.mjs`,
  `supabase/migrations/20260920000003_public_scoring_params.sql`,
  `supabase/tests/82_published_page_params.sql`.
- **Deleted:** no file. The three page copies and plan test 8.88 are all retained, reversing
  ADR-085 §3's removal list. `assets.test.ts` keeps its three-way byte-identity assertion
  unchanged, because the generator writes the source and copies it verbatim.
- **Tests:** SS26.CALC.01–09 (pgTAP, +9 → 1132 total) and 27 Vitest parity cases. A new
  `scripts/preflight.sh` gate, *published pages match scoring.ts*, fails on a stale page.
- **The anon surface grows by one**, documented in
  `doc/handbook/reference/security-posture.html`, whose count moves from nineteen to twenty-nine
  — most of that drift predates this change and is corrected here rather than left standing.
- **The published pages now require network access.** `doc/tools/WP-instrukcja-wgrania.txt` no
  longer promises otherwise. Offline, each page renders and reads, and shows a
  parameters-unavailable message in place of a figure. That is deliberate: a number computed from
  stale constants is worse than an honest absence.
- **Two defects were found by loading the pages in a browser**, after every unit test, pgTAP
  assertion and type check was already green — a dangling comment terminator left by the
  generator's marker constant, and a null dereference on the first render before parameters
  arrive, which made each page show its startup-failure banner and never issue the fetch. Both
  are fixed. They are recorded here because they are the argument for verifying a published page
  by opening it, not only by testing its parts.
- **Walkover re-pricing becomes visible to the public.** With the annex driven by the 2026/2027
  engine, a one-competitor bracket now reads 19 points where the classic engine gives 59
  (ADR-066 records six of seven FOIL brackets in `PPW2-2025-2026` as single-competitor). The
  arithmetic is unchanged by this ADR; only its visibility is new.

## Open items

1. **ADR-092's `robots` meta.** The annex still carries `noindex, nofollow` as the only thing
   keeping an unadopted regulation draft out of search results (ADR-092 §4). Adoption is a
   deliberate act and is not part of this change. **Recommendation:** leave it, and lift it in
   the same change that adopts the annex.
2. **ADR-085 §2 — "no other static page is expected to be published this way".** There are now
   two, and both are generated. **Recommendation:** treat §2 as still binding for *new* pages and
   revisit it only if a third is proposed.
