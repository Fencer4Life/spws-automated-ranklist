---
name: release
description: Safely diagnose, validate, commit, push, run, and repair SPWS GitHub Actions CI and release workflows while preserving concurrent user and Claude changes. Use for releases, CI failures, release failures, workflow reruns, release manifests, deployment checks, or requests to commit and push this repository.
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
--check`, `render_docs.py --check`, `check_docs.py`, pytest, Vitest,
`check-coherence.sh`, `supabase test db`, `check-spec-sync.sh`, `svelte-check`,
and the `git diff --check` that `integrate-agent-branch.sh` enforces.

Still owed separately, because they are per-change rather than global:

- `postgrestools check <path>` for every `.sql` touched.
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
- Use a focused commit message that describes the actual change.

## Push and operate workflows

- Recheck branch and remote immediately before pushing.
- Push only the intended commit or branch.
- Observe all triggered CI and release runs to completion.
- For failures, fetch failing job logs and return to diagnosis.
- Never bypass required checks, force-push, rewrite history, or mutate CERT/PROD without explicit
  authorization for that exact action.

## Handoff

- Report commit SHA and pushed branch.
- Link each workflow run and state its final conclusion.
- List commands actually run, files changed, and checks not run.
- State deployment status and remaining risks explicitly.
