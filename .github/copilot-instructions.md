## Repository authority

- Use `doc/handbook/index.html` for current-system behavior and `doc/handbook/documentation-map.html` to identify the owning page for a change.
- Use `doc/adr/index.html` for decision rationale, `doc/governance/index.html` for requirements, and `doc/archive/legacy-2026-07/` only for history.
- Human-facing documents and development plans are HTML. Every plan includes the documentation coherence gate from `doc/handbook/reference/documentation-standard.html`.

## GitHub operations

- Use the configured GitHub integration for API operations and normal terminal Git commands for local status, diff, staging and commits.
- Never read, quote, copy, log or embed a token from `.vscode/mcp.json`, environment files, local settings or git remotes.
- Never place credentials in a remote URL. Use the configured credential/OAuth flow.
- Stage explicit intended paths and preserve unrelated worktree changes.
- Do not push, run workflows, or mutate CERT/PROD unless the user explicitly authorizes that operation.

## Completion

- Run affected tests and repository coherence checks.
- Update current handbook/runbook pages in present tense when their owned behavior changes.
- Run `python scripts/check_docs.py --changed-from <base>` and the applicable HTML render checks.
- Run `scripts/refresh-graph.sh` before committing.
