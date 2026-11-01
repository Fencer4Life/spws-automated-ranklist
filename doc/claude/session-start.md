# Session start — agent procedure

The canonical description is the handbook:
[operations/claude-codex-collaboration.html#session-start](../handbook/operations/claude-codex-collaboration.html#session-start).
This file is the checklist an agent follows. The decisions behind it are in
`doc/plans/session-start-protocol-2026-10-03.html`, signed off on 2026-10-03.

## What arrives in context

The `SessionStart` hook runs `scripts/session_start.py` and injects a block that begins
with `SPWS session-start protocol`. Read it before doing anything else.

1. **`FIRST ACTION … call EnterWorktree with path=<worker>`.** Do exactly that, as the
   first tool call of the session. This project instruction is what authorises the
   `EnterWorktree` tool. Never edit files in the primary or the integration checkout.
2. **The branch is `claude/session-<date>-<time>-<id>`.** Once the task is clear, rename
   it: `git branch -m claude/<task>`.
3. **`STALE`.** The checkout is behind `origin/main`, so the graph describes older code.
   Merge `origin/main` before analysing anything.
4. **`Graph: … FAILED` or `RAG: … FAILED` / `NOT re-indexed`.** Say so in the first reply
   to the user, and do not present analysis as current until it is fixed. The report
   names the cause.
5. **`kept for the user's decision`.** These are Claude worktrees with uncommitted files
   or unmerged commits. Mention them once. Never remove them yourself.

## If the block is missing

The hook did not run. That happens in a checkout older than the protocol, or when hooks
are disabled. Run it by hand from the session's checkout:

```bash
echo '{"source":"resume","cwd":"'"$PWD"'"}' | python3 scripts/session_start.py
```

## Research rule (skill `research-gate`)

- Documentation goes through `mcp__spws-docs__search`, with 2–5 keywords.
- Code goes through `graphify query/explain` (symbol names) and the LSP.
- grep and `git show` only confirm a literal you have already located.
- Every delegated agent's prompt carries the same rule.

## Supabase token rule (the block's last line)

- Read `SUPABASE_ACCESS_TOKEN` only through `python/supabase_token.py` (Python) or
  `scripts/supabase-token.sh` (shell). Both take the checkout's `.env` before the
  environment; never `os.environ` for it. Preflight fails otherwise (ENVTOKEN.05–06).
- A tool that reads the variable itself, such as the supabase CLI:
  `source scripts/supabase-token.sh && export_supabase_access_token` first, in the
  same command.
- A 401 means the token the helper returned was rejected. Never report the
  environment's copy as the problem, and never print a value. The decision is the
  [ADR-036](../adr/036-prod-export-local-mirror.md) amendment of 2026-11-01.
- Every brief for a session or agent you start names the two helpers.
