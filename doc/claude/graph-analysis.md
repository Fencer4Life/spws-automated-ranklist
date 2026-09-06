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
| `0`  | Graph current — code **and** docs refreshed headlessly, or nothing relevant changed | Commit. |
| `3`  | No graph yet (`graphify-out/graph.json` missing) | Run a full `/graphify .`, then commit. |
| `2`  | Environment error / shrink guard | Read stderr. If the shrink guard fired and the reduction is a deletion you made on purpose, verify that and re-run with `--force`; otherwise run a full `/graphify .`. |

Exit `10` is retired. It meant "doc/paper/image files changed — needs LLM
re-extraction"; docs are now extracted locally, so the script no longer emits it.

Skip the refresh only for pure-formatting / no-op commits (or pass
`--skip-whitespace`).

### Cost model — why it's split this way
- **Code changes = free.** The script AST-extracts only the *changed* code files
  and `build_merge`s them in (`scripts/graphify_refresh.py`). No LLM. It
  deliberately does **not** call `graphify update .`, which re-extracts the whole
  tree structurally (markdown headings + docstrings) and would overwrite the
  LLM-extracted semantic doc layer.
- **Doc changes = free too.** `scripts/graphify_docs_extract.py` derives the
  cheap 90% of the doc layer — which document cites which file, ADR and section —
  deterministically from the text at zero token cost, and merges it alongside the
  code AST. A routine docs pass touches dozens of files; under the old exit-10
  flow that dispatched a subagent per ~20 documents, so refreshing a local,
  gitignored developer aid cost millions of tokens.
- **Svelte components need a second local pass, and get one.** graphify hands a
  whole `.svelte` file to a JavaScript tree-sitter parser; the markup is not
  valid JS, so the parse errors at the top level and the declarations are lost.
  graphify says as much about *imports* in its own extractor (#713) and rescues
  those by regex, but not declarations. Measured 2026-09-06, before the fix: 36
  components held **54** nodes against **610** available from their `<script>`
  bodies — `App.svelte` had 2, so a query for `loadCalendar` or
  `handleWizardCommit` returned nothing and read as "does not exist".
  `scripts/graphify_svelte_extract.py` cuts each script body out, extracts that,
  and reattributes the result to the component with the line numbers offset.
  Deterministic, zero tokens, wired into the same refresh. If a frontend query
  comes back empty, that is now evidence rather than a known blind spot.
- **Images and papers still need the LLM.** They are reported and skipped rather
  than blocking; run `/graphify . --update` only when their semantic layer
  matters.

### Notes
- `doc/archive/` is excluded from the graph via `.graphifyignore`; archived narratives are never current architecture evidence.
- There is intentionally **no git pre-commit hook**. Code and text docs now
  refresh headlessly, but images and papers still need the agent, and a hook that
  silently skipped them would give a false sense of freshness. This stays an
  agent-run command.
- Interpreter is graphify's isolated env, pinned in
  `graphify-out/.graphify_python` (never the project `.venv`); the wrapper
  resolves it.
