---
name: release
description: Safely diagnose, validate, commit, push, run, and repair SPWS GitHub Actions CI and release workflows while preserving concurrent user and Claude changes. Use for releases, CI failures, release failures, workflow reruns, release manifests, deployment checks, preflight, branch names and descriptions, CI and Release run titles, or requests to commit and push this repository.
---

# Operate SPWS releases

Execute release work sequentially and evidence every claim. Treat the repository as concurrently
edited unless proven otherwise.

## Establish ownership and scope

- Read `AGENTS.md`, `CLAUDE.md`, `doc/handbook/operations/environments-and-release.html`, `doc/handbook/reference/workflow-catalog.html`, and relevant workflow sources.
- Inspect the branch, worktree, staged diff, remotes, and recent commits.
- Treat unfamiliar modifications and untracked files as user- or Claude-owned.
- Identify exact authorized paths. Stage only those paths.
- Stop if intended paths overlap concurrent edits that cannot be separated safely.

## Diagnose before changing

- Inspect the failing run, job, step, and complete relevant logs.
- Reproduce the failure locally when possible.
- Distinguish deterministic code/config failures from transient infrastructure failures.
- Rerun without code changes only when evidence supports a transient failure.
- For deterministic failures, add or adjust a test first and confirm RED before implementation.

## Name the change before preflight

GitHub titles every CI and Release run from the merge commit on `main`, so the branch carries
the explanation (NFR-16, NAMING.01–05; `doc/plans/branch-names-and-merge-messages-2026-10-31.html`).

- Name the branch after what it changes: `claude/<what-it-changes>` or `codex/<what-it-changes>`,
  e.g. `claude/weapon-from-title-every-engine`. Never a session name, a date or fewer than three
  words. Rename it with `git branch -m` once its purpose is known; the description moves with it.
- Write its description with `git branch --edit-description` (stored in the repository config
  every worktree shares): a title of up to 72 characters that does not start with "Merge", a
  blank line, at least two sentences on what was wrong and what it does now, then the trailers
  (`Co-Authored-By: …`).
- Preflight's "branch, merge and release named (integrate)" gate runs
  `python3 scripts/branch_description.py check`, which refuses a weak name or description and
  prints what GitHub will show for the push:

  ```text
  Branch:       claude/adr118-f9-release-record
  Merge title:  ADR-118 F9 recorded as released and verified on PROD
  CI run:       ADR-118 F9 recorded as released and verified on PROD
  Release run:  Release · ADR-118 F9 recorded as released and verified on PROD
  ```

  Read those titles before integrating. If they do not say what changes, rewrite the
  description, never the check. On `main` or `integration/main` the gate shows SKIP, and
  `--ci-only` leaves it out.
- `scripts/integrate-agent-branch.sh` runs the same check, merges nothing when it fails, and
  merges with `scripts/branch_description.py message <branch>`: the description plus a
  `Branch: <name>` trailer.
- Where the titles come from: the CI run takes the merge commit's first line; `release.yml`'s
  `run-name` makes the Release run "Release · <CI run title>", or "Release · manual dispatch by
  <who>" for a manual dispatch.
- Say in the description whether the Release deploys. Only `doc/`, `CLAUDE.md`, `AGENTS.md`,
  `README.md` and the two tracking files skip it (ADR-094); preview the decision with
  `RELEASE_GATE_EVENT=workflow_run RELEASE_GATE_HEAD_SHA=$(git rev-parse HEAD)
  GITHUB_OUTPUT=<temp file> bash scripts/release-gate.sh`.

## Validate locally

Run narrow checks while iterating. Then, before staging and again before
pushing, run the whole gate set with one command:

```bash
scripts/preflight.sh
```

**Do not hand-pick gates from a list, including the list below.** Preflight runs
every CI job's checks plus the AGENTS.md gates CI does not run, continues past
the first failure, and prints a pass/fail line per gate — so you see everything
wrong at once rather than serially from a red CI run. On 2026-09-13 a subset was
run by hand instead; CI then failed on `main` for `basedpyright` and
`check-coherence.sh`, and each remaining gate surfaced one at a time afterwards.
A push to `main` auto-deploys PROD, so that discovery order is a release hazard.

What preflight covers: ruff (lint + format), basedpyright, `render_adrs.py
--check`, `render_docs.py --check`, `render_handbook_frame.py --check`,
`check_docs.py`, pytest, Vitest, `check-coherence.sh`, the LOCAL stack matching
CI's (CLI pin, extensions), the postgrestools hard gate
(`scripts/check-postgrestools.sh`), `supabase test db`, `check-spec-sync.sh`, the
anon allowlist, `svelte-check`, the published scoring pages matching `scoring.ts`,
and the two checks `integrate-agent-branch.sh` enforces: `git diff --check` and
"branch, merge and release named" (above).

Still owed separately, because they are per-change rather than global:

- `postgrestools check <path>` for every touched `.sql` the hard gate does not
  cover (it checks every migration after the config's `migrations.after` and
  every pgTAP file; seeds and other SQL are not in it).
- `scripts/refresh-graph.sh` before committing.
- Playwright (`npm run test:e2e`) when browser behavior changed.

Never report a command as passing unless it completed successfully in this run.
`scripts/preflight.sh` exiting 0 is the only evidence that counts for "gates
pass"; quote its summary rather than asserting it.

## Prepare the release change

- Recheck the worktree immediately before staging.
- Stage explicit authorized paths only.
- Review `git diff --cached --check`, the staged summary, and complete staged diff.
- Verify release manifests, migration tracking, documentation totals, and traceability when affected.
- Complete the documentation coherence gate; update current handbook/runbook pages in present tense and archive superseded operational prose.
- A workflow added, removed or renamed, or a change to a workflow's schedule, the workflow it
  calls or is triggered by, its concurrency group, its failure conditions or who dispatches it:
  update its block on `doc/handbook/reference/workflow-catalog.html` in the same commit.
  `python/tests/test_github_workflows_page.py` (GHWF.01–06) fails until the page lists every
  workflow file with its name, schedule, calls and lanes.
- Use a focused commit message that describes the actual change; the branch description
  (see "Name the change before preflight") becomes the merge on `main`.

## Push and operate workflows

- Recheck branch and remote immediately before pushing.
- Push the integration branch to main with `git push origin <integration-branch>:main`
  (`integration/main:main` in the dedicated integration worktree); the pre-push hook refuses
  `HEAD:main` there.
- Push only the intended commit or branch.
- Observe all triggered CI and release runs to completion.
- Check each run's title against what preflight printed: the CI run reads the merge title and
  the Release run "Release · <merge title>". A run titled "Merge branch …" or a bare "Release"
  means the merge did not come from the integrate script.
- For failures, fetch failing job logs and return to diagnosis.
- Never bypass required checks, force-push, rewrite history, or mutate CERT/PROD without explicit
  authorization for that exact action.

## Handoff

- Report commit SHA and pushed branch.
- Link each workflow run with its title and state its final conclusion.
- List commands actually run, files changed, and checks not run.
- State deployment status and remaining risks explicitly.
