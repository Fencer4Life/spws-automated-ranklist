# ADR-094: Release Gate Skips Build/Deploy for Documentation-Only CI Runs

**Status:** Draft (proposed 2026-09-13; awaiting sign-off)
**Date:** 2026-09-13
**Amends:** [ADR-011](011-artifact-release-pipeline.md) — the release trigger is no longer "CI success on `main`" alone; a `gate` job now decides whether `build` runs. ADR-011's four-job description (build, deploy-pages, deploy-cert, deploy-prod) is otherwise unchanged.
**Relates to:** [ADR-083](083-server-enforced-authorization.md) (security posture checks stay inside `deploy-cert`/`deploy-prod`, unaffected by this gate, which runs strictly before `build`)
**Source:** `.github/workflows/release.yml`, `scripts/release-gate.sh`, `python/tests/test_release_docs_only_gate.py`

## Context

`release.yml` runs on every completed `CI` run on `main` (`workflow_run`), and
`build` had `if: github.event_name == 'workflow_dispatch' ||
github.event.workflow_run.conclusion == 'success'` — i.e. it ran whenever CI
passed, with no regard for what the run actually changed. A commit touching
only `doc/` (handbook prose, an ADR, its generated HTML twin) or root
Markdown (`CLAUDE.md`, `AGENTS.md`, `README.md`) still walked the entire
build → deploy-pages/deploy-cert/deploy-prod chain: a fresh frontend build,
CERT/PROD fingerprint verification, Edge Function redeploys, and the
security-posture check on both cloud environments — none of which differ
from what is already live, since nothing deployable changed.

This is pure cost with no corresponding benefit: extra CI minutes, extra
Supabase CLI invocations against CERT/PROD credentials, and extra noise in
`deployed_migrations.json`/`release-manifest.json` history for a change that
altered no shipped artifact. It also matters for the association's WordPress
embed (ADR-011's guarded `assets/main.ce.js`) and CERT/PROD fingerprint
verification — both of which are unaffected by documentation changes but were
run anyway.

`workflow_run`'s payload has no `before` SHA (unlike the `push` event
`ci.yml` reads via `github.event.before` for `check_docs.py
--changed-from`), so there was no existing commit range to classify a run
against.

## Decision

### 1 · A `gate` job runs before `build`

`release.yml` gains a `gate` job with the same trigger condition `build` used
to carry (`workflow_dispatch` or `github.event.workflow_run.conclusion ==
'success'` — moved here, not duplicated). `build` now reads `needs: gate` and
`if: needs.gate.outputs.deploy == 'true'`. Because `deploy-pages`,
`deploy-cert`, and `deploy-prod` all depend (directly or transitively) on
`build`, GitHub Actions skips the whole chain for free when `build` is
skipped — no other job needed its own condition changed.

### 2 · The base commit is the previous completed CI run's head

`gate` resolves the diff range itself: `head` is
`github.event.workflow_run.head_sha`; `base` is the `head_sha` of the most
recent other *completed* run of `ci.yml` on `main`, fetched via
`gh api repos/.../actions/workflows/ci.yml/runs?branch=main&status=completed`.
This reads as "everything since CI last finished on `main`", which is correct
whether the intervening push carried one commit or several, and requires the
new `actions: read` permission on `release.yml` (the workflow previously
needed none beyond `contents`, `pages`, `id-token`).

### 3 · `scripts/release-gate.sh` classifies the range and fails open

The script takes an event name and a base/head SHA pair (env-overridable,
which is what makes it unit-testable without a GitHub Actions runner) and
`git diff --name-only`s the range. A path is **non-deployable** only if it
matches `^(doc/|CLAUDE\.md$|AGENTS?\.md$|README\.md$|deployed_migrations\.json$|release-manifest\.json$)`
— this is a path-prefix test, not an extension test, so it catches both the
Markdown source and the generated HTML twin (ADR-082) under `doc/`, without
needing to enumerate extensions. The two root-level JSON files are the
Release workflow's own tracking bookkeeping (§2026-09-13 amendment below).
Everything else — including `frontend/public/*.html`
(`tabela-punktacji.html`, `kalkulator-punktow.html`; ADR-085, ADR-092), which
*is* built into the Pages artifact — counts as deployable. `deploy=false` only
when every changed path matches the non-deployable pattern; any single
deployable path, or any of the following, deploys unconditionally:

- `workflow_dispatch` (an operator asked for a release — never second-guess it)
- an empty, missing, or unresolvable base/head SHA
- base equal to head (no diff evidence)
- an empty diff

This mirrors the fail-open posture the codebase already uses for FTL delivery
guards and the CERT/PROD fingerprint checks: an unclassifiable input runs the
expensive path rather than silently skipping a real change.

## Alternatives considered

1. **Filter on the `CI` job names that ran** (skip if only `coherence`
   succeeded) — CI's four jobs (`test-db`, `test-python`, `test-frontend`,
   `coherence`) all run on every push regardless of what changed; the run's
   job list carries no information about which files moved. Rejected.
2. **Path filters via `paths-ignore` on `push`, directly on `release.yml`** —
   `release.yml` is not triggered by `push`; it is triggered by
   `workflow_run` on `CI`'s completion, specifically so a single CI success
   gates all three environments' deploys together (ADR-011). `paths-ignore`
   only exists for `push`/`pull_request` triggers. Rejected.
3. **Diff against `HEAD^` (the immediate parent commit)** — correct only for
   a single-commit push; a multi-commit push would see just the last
   commit's diff and could wrongly classify an earlier code commit in the
   same push as covered. Rejected in favor of walking back to the last
   completed CI run, which is correct regardless of commit count per push.
4. **Diff against `release-manifest.json`'s last deployed SHA** — that field
   is only updated by `update-tracking.sh` when a migration was applied
   (`deploy-cert`/`deploy-prod`'s "Update tracking files" step is itself
   conditional on `has_new_migrations == 'true'`), so it can lag many
   already-deployed non-migration releases behind. Using it as the base would
   make the gate see a growing, stale range and default to `deploy=true`
   indefinitely after any migration-free release — defeating the feature.
   Rejected.
5. **Classify by extension (`.md`/`.html`) instead of path prefix** — would
   wrongly treat `frontend/public/tabela-punktacji.html` (a deployed static
   page) as documentation, and would need a second rule anyway to exclude
   `doc/`'s own non-`.md`/`.html` assets (CSS, images). A path-prefix test on
   `doc/` handles the Markdown-source/generated-HTML-twin split (ADR-082)
   without an extension list at all. Rejected.

## Consequences

- New files: `scripts/release-gate.sh`,
  `python/tests/test_release_docs_only_gate.py` (13 cases: the classifier's
  doc-only/generated-twin/tracking-files-only/mixed/migration/
  published-static-page/workflow-file paths, five fail-open guarantees, and
  two assertions on the workflow's job wiring).
- `release.yml` gains a `gate` job and the `actions: read` permission; `build`
  moves its trigger condition into `needs.gate.outputs.deploy == 'true'`.
- A documentation-only push now completes CI and stops — no frontend build,
  no CERT/PROD fingerprint check, no Edge Function redeploy, no
  `deployed_migrations.json`/`release-manifest.json` churn, no security
  posture re-check on either cloud environment.
- `deployed_migrations.json` and `release-manifest.json` no longer gain an
  entry for every green CI run — only for runs that actually deployed. This
  is a narrowing of an existing implicit assumption (every CI success ⇒ a
  release-manifest touch); nothing currently reads the manifest expecting one
  row per CI run rather than one per release.
- Known gap, deliberately not fixed here: the classifier is repo-root-only —
  a change under `frontend/` that happens to touch only comments or a
  `*.md` file inside `frontend/` still deploys, because `frontend/` is not in
  the non-deployable pattern. Narrowing further was judged not worth the
  risk of a false skip inside the one directory that actually builds the
  shipped artifact.

## Amendment (2026-09-13): exempt the Release workflow's own tracking files

Observed live the same day this ADR was drafted: a purely documentation
follow-up commit (updating ADR-096 and a plan page to record a just-completed
deploy) was gated as **deployable** — `release-gate: at least one deployable
path changed`, naming `deployed_migrations.json` and `release-manifest.json`.
Neither file was touched by that commit's own author; both were swept into
the diff range because an unrelated Release run (a manually re-run EVF sync,
minutes earlier) had committed its own tracking update in between, and the
range this gate computes is "everything since CI last completed on `main`,"
not "only the paths this specific push introduced."

Both files are written exclusively by `release.yml`'s own `build`
(`release-manifest.json`) and `deploy-cert`/`deploy-prod`
(`deployed_migrations.json`, conditionally) jobs, as pure post-deploy
bookkeeping — nothing reads either expecting it to gate a future decision
about code or schema. Because they live at the repo root rather than under
`doc/`, the original pattern could never exempt them, which meant *any* two
Release-triggering events landing close enough together — routine given
`evf-sync.yml`/`pzsz-sync.yml`'s own promotion jobs, scheduled
`recompute-drain*.yml` runs, and manual dispatches all sharing `main` —
would silently defeat this ADR's entire purpose for the second push, with no
error and no visible sign beyond a longer-than-expected Release run.

**Decision:** add both filenames as literal exact-match alternatives in
`non_deployable_pattern`. `scripts/release-gate.sh` and the pattern quoted in
§3 above are both updated; `python/tests/test_release_docs_only_gate.py`
gains `test_release_tracking_files_only_range_skips_deployment`, pinning a
range of `doc/handbook/index.html` + both tracking files as `deploy=false`.
No other file in the classifier's scope changes shape or risk: both
additions are exact filenames, not prefixes, so they cannot accidentally
swallow a real deployable path the way a broader `^release-` or `.json$`
pattern could.

The commit that landed this fix itself touched `scripts/release-gate.sh` and
a Python test — genuinely deployable — so it correctly triggered a full
deploy and proved nothing about the skip path on its own via live CI. This
paragraph is itself that live proof: a follow-up, docs-only-by-construction
commit, pushed to observe the gate's actual verdict on `main` with no other
Release run's tracking commit interleaved.

## Open items

- Whether the same gate should also suppress `evf-sync.yml`/`pzsz-sync.yml`'s
  calendar promotion jobs on a documentation-only CERT tracking commit is out
  of scope here — those workflows run on their own schedule, not on CI
  completion, and were not part of this request. Recommendation: leave as is
  unless a concrete cost is observed.
