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

Run narrow checks first, then applicable release gates:

- Python: pytest, `ruff check`, `ruff format --check`, and basedpyright.
- Frontend: Vitest, `svelte-check`, and Playwright when browser behavior changed.
- SQL: targeted postgrestools and pgTAP with local Supabase running.
- Repository: `scripts/check-coherence.sh` and `scripts/check-spec-sync.sh`.
- Run `scripts/refresh-graph.sh` before committing.

Never report a command as passing unless it completed successfully in this run.

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
