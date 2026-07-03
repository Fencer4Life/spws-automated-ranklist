---
name: pre-analysis-check
description: "MANDATORY gate for this repo (SPWS Automated Ranklist System) before any code analysis, architecture question, impact/blast-radius check, refactor investigation, code review, or before writing an implementation Plan. Enforces querying the graphify knowledge graph AND the Python LSP (basedpyright) first — never grep/find alone as the first move. Triggers on: analyze, explain how X works, what calls Y, trace, plan, refactor, review architecture, impact of a change, blast radius, where is X used, find references, dependencies, understand this module."
---

# Pre-Analysis Check — graphify + LSP before grep

This repo maintains two live, queryable sources of ground truth. Grepping first
gives worse answers than either of these: text matches with no relationships,
no types, no call-graph, and no ranking of what actually matters. Grep is the
**last** resort, not the first.

Do NOT respond to a code-analysis or planning request — and do NOT enter Plan
mode — until both steps below have been done for the symbols/files in scope.

## Step 1 — graphify (structure, relationships, architecture)

The graph lives at `graphify-out/graph.json`, already built. Query it directly:

```bash
graphify query "<question>"                    # broad context, BFS traversal
graphify explain "<ConceptOrFile>"              # plain-language node explanation
graphify affected "<file-or-symbol>"            # blast radius / impact — required before any plan touching that symbol
graphify path "<A>" "<B>"                       # how two concepts/files connect
```

Also skim `graphify-out/GRAPH_REPORT.md` for god nodes and community structure
when the question is architectural rather than symbol-specific. Full rules
(refresh cadence, exit codes, staleness handling): `doc/claude/graph-analysis.md`
— read it if the graph looks stale or `graphify-out/` is missing.

## Step 2 — Python LSP (exact, compiler-verified facts)

For every Python symbol touched by the analysis or plan, use the `LSP` tool
(operations: `goToDefinition`, `findReferences`, `hover`, `documentSymbol`,
`workspaceSymbol`, `goToImplementation`, `prepareCallHierarchy`,
`incomingCalls`, `outgoingCalls`) — not grep:

- `findReferences` / `incomingCalls` — every real call site. Grepping a common
  name like `run`, `commit`, or `validate` returns noise across unrelated
  modules; LSP resolves the actual symbol.
- `goToDefinition` — the real implementation, not a same-named function
  shadowed in another file.
- `hover` — parameter/return types and docstring without opening the file.
- `workspaceSymbol` — locate a symbol by name across the whole tree fast.
- `outgoingCalls` — what a function actually depends on, for impact analysis.

If `LSP` errors with an executable-not-found message, the environment is
broken — fix it (see `[[python-lsp-setup]]` memory for the known-good repair:
`uv tool install basedpyright` + symlink `basedpyright-langserver` as
`pyright-langserver` on `$PATH`), don't silently fall back to grep and treat
that as normal.

## When grep/find is still fine

- Non-code text: SQL literals inside migrations, YAML/JSON config values,
  markdown prose, commit messages, seed data.
- Confirming a literal string exists somewhere (e.g. a specific error message
  or magic constant).
- Svelte/TypeScript frontend files — the Python LSP doesn't cover them and
  they may not be fully represented in the graph; check `graphify-out/` first,
  fall back to grep only if the graph has no node for it.

## Why this exists

Grepping first has repeatedly given incomplete or misleading results in this
repo — dead code masquerading as live, name collisions across the 30
sub-ranking modules, missed call sites — and the user had to redirect back to
the graph every time. This skill removes the need to ask twice. See
`[[feedback_graph_analysis_first]]` in memory.
