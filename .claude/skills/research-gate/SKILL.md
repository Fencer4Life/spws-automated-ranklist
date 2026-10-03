---
name: research-gate
description: "MANDATORY first step for ANY investigation in this repo (SPWS Automated Ranklist System): brainstorms, UI or architecture design, plans, answering a question, checking a claim, and EVERY prompt written for an Explore/Plan/general-purpose agent. Documentation is read through the spws-docs RAG (mcp__spws-docs__search), code through the graphify graph (graphify query/explain/path/affected, plus the LSP for Python). grep, sed, git show and curl only confirm a literal already located. Also checks that the session-start report says the graph and RAG are current. Triggers on: brainstorm, let's think about, design, propose, plan, how does X work, what do we have for Y, is this what the code does, investigate, research, explore, look into, spawn an agent, delegate a search, compare options, what did we decide."
---

# Research gate: the RAG for documentation, the graph for code

This gate exists because of what happened on 2026-10-03. A WordPress UI brainstorm was
researched with `grep`, `sed`, `git show`, `curl` and two Explore agents told to grep;
neither the RAG nor the graph was touched. On top of that, the checkout was 182 commits
behind `origin/main` and the graph was a week old. As a result the session called the
Points Calculator "redundant" and proposed pasting or porting the Points Table. The RAG
returns ADR-102 on the first query: the scoring engine, the Table and the Calculator share
one module and are not separable by design.

The two narrower gates, `docs-search` and `pre-analysis-check`, already existed. They were
skipped because the work was called a "brainstorm". This gate has no such loophole:
**every** kind of investigation starts here.

## 0 · Are the graph and the RAG current?

The `SessionStart` hook runs `scripts/session_start.py` and injects a report beginning with
`SPWS session-start protocol` (procedure: `doc/claude/session-start.md`).

- `FIRST ACTION … EnterWorktree` → do it before anything else.
- `STALE`, `Graph: … FAILED`, or `RAG: … NOT re-indexed` / `FAILED` → fix that first, or
  tell the user that the analysis rests on an out-of-date graph or index. Never present
  stale analysis as current.
- No report at all → run the protocol by hand:
  `echo '{"source":"resume","cwd":"'"$PWD"'"}' | python3 scripts/session_start.py`.

## 1 · Documentation goes to the RAG

```
mcp__spws-docs__search  query: "<2–5 keywords>"   (index spws_docs)
```

- Use keywords, not sentences. When the topic has several facets, run several queries in
  parallel. To stay with the authorities, filter by kind: `kind IN [adr, handbook, governance]`.
- Read the hit's `path` and `heading`, then open that canonical page. ADRs and the handbook
  outrank plans, and `doc/archive/` never describes current behaviour.
- `grep doc/` is allowed only to confirm a literal string in a file the RAG already pointed
  to.

## 2 · Code goes to the graph

```bash
graphify query "<symbol or short phrase>"
graphify explain "<NodeName>"
graphify path "<A>" "<B>"
graphify affected "<NodeName>"
```

- Query symbol names (`scoring.ts`, `ScoreComponents`, `RanklistElement`), not sentences.
  A sentence returns noise.
- For Python symbols, add the `LSP` tool (`findReferences`, `incomingCalls`).
- A symbol you know exists returns "No matching nodes" → the graph is stale. Refresh it
  with `./scripts/refresh-graph.sh --full-code` (zero tokens, about 10 s) and query again.
  Do not quietly fall back to grep.
- `grep`, `sed` and `git show origin/main:<file>` may **confirm** a literal the graph
  located, such as a marker, a constant or an error message. Never use them to read or
  trace logic.

## 3 · Delegated agents inherit this gate

Every prompt for an Explore, Plan or general-purpose agent contains this paragraph,
verbatim:

> Research rule for this repo: search documentation with `mcp__spws-docs__search`
> (2–5 keywords; open the hit's path). Query code with `graphify query` /
> `graphify explain` first (symbol names, not sentences). Use grep or `git show`
> only to confirm a literal you already located. Report which RAG hits and graph
> nodes your answer rests on.

An agent's report that cites no RAG hit and no graph node is unverified. Check it before
relying on it.

## 4 · Before presenting any recommendation

- [ ] Every claim about **what was decided** cites an ADR or handbook page found through
      the RAG.
- [ ] Every claim about **what the code does** cites a graph node, or a literal confirmed
      after the graph located it.
- [ ] Every recommendation to **remove, merge, copy, port or paste** something was checked
      against the RAG for a design invariant that forbids it. Known invariant: ADR-102,
      the one shared scoring module behind the engine, the Table and the Calculator. They
      are kept and changed as a group, tied to the season by the engine code.
