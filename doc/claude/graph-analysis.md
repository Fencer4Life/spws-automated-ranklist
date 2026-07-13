# Graph-Analysis & Refresh (graphify knowledge graph)

The repo has a graphify knowledge graph in `graphify-out/` (≈4,970 nodes /
≈9,900 edges / ≈248 communities). It is **local and gitignored** — a map of the
codebase, not a committed artifact. Two standing rules govern it.

## Rule 1 — Consult the graph FIRST for codebase analysis

Before (or alongside) grepping for any *analysis* question — architecture, "how
does X work", what-calls-what, where a feature lives, the blast radius of a
change — query the graph. It already encodes call/contains/implements edges plus
an LLM-extracted semantic doc layer (ADR concepts, rationale).

```bash
graphify query "how does the ingestion pipeline commit a draft"   # BFS context
graphify explain "ParsedTournament"                                # node + neighbours
graphify affected "fn_commit_event_draft"                          # reverse impact
graphify path "ingest_cli" "DbConnector"                           # shortest path
```

Also read `graphify-out/GRAPH_REPORT.md` for god nodes (core abstractions),
community map, and surprising cross-module connections. The graph can lag the
working tree — if it looks stale, refresh it (Rule 2) before trusting it.

**Pair with the Python LSP.** The graph gives structure and relationships;
for the exact Python symbols in scope, also use the `LSP` tool
(`findReferences`, `goToDefinition`, `hover`, `workspaceSymbol`,
`incomingCalls`/`outgoingCalls`) for compiler-verified facts the graph doesn't
carry — real call sites (not name collisions), exact types, actual
implementations. This pairing is enforced automatically by the
`.claude/skills/pre-analysis-check/SKILL.md` project skill, which triggers on
analysis and planning requests. If `LSP` errors with an executable-not-found
message, the environment needs repair — see the `python-lsp-setup` memory —
don't silently fall back to grep.

## Rule 2 — Refresh the graph before every commit

After finishing new work, updating the owning current handbook pages, and **always before committing**,
run the refresh command and act on its exit code:

```bash
scripts/refresh-graph.sh            # add --skip-whitespace for pure-format commits
```

Exit-code contract:

| Exit | Meaning | Action |
|------|---------|--------|
| `0`  | Graph current (refreshed headlessly, or nothing relevant changed) | Commit. |
| `10` | Doc/paper/image files changed — needs LLM re-extraction | Run `/graphify . --update` (dispatches extraction subagents), then commit. |
| `3`  | No graph yet (`graphify-out/graph.json` missing) | Run a full `/graphify .`, then commit. |
| `2`  | Environment error / shrink guard | Read stderr; usually run a full `/graphify .`. |

Skip the refresh only for pure-formatting / no-op commits (or pass
`--skip-whitespace`).

### Cost model — why it's split this way
- **Code changes = free.** The script AST-extracts only the *changed* code files
  and `build_merge`s them in (`scripts/graphify_refresh.py`). No LLM. It
  deliberately does **not** call `graphify update .`, which re-extracts the whole
  tree structurally (markdown headings + docstrings) and would overwrite the
  LLM-extracted semantic doc layer.
- **Doc changes = LLM.** Re-extracting docs needs the `/graphify . --update`
  subagent flow, which only the agent can drive — hence exit 10 signals it
  rather than attempting it headlessly.

### Notes
- `doc/archive/` is excluded from the graph via `.graphifyignore`; archived narratives are never current architecture evidence.
- There is intentionally **no git pre-commit hook**: semantic extraction needs
  the agent, so a headless hook would silently skip doc re-extraction and give a
  false sense of freshness. This is an agent-run command.
- Interpreter is graphify's isolated env, pinned in
  `graphify-out/.graphify_python` (never the project `.venv`); the wrapper
  resolves it.
