---
name: docs-search
description: "MANDATORY gate for this repo (SPWS Automated Ranklist System) before ANY documentation search, and MANDATORY after ANY change under doc/. Enforces querying the local Meilisearch index through the `spws-docs` MCP server instead of grepping doc/ or guessing filenames, and re-indexing with `python3 tools/docs-search/ingest.py` once documentation changes. Triggers on: what did we decide about X, which ADR covers Y, where is this documented, find the handover, read the handbook page about Z, what does governance say, search the docs, grep doc/, looking for a plan by date — and on: wrote or edited an ADR, plan, handbook or governance page, rendered HTML twins, finished a documentation coherence gate, preparing to commit after touching doc/."
---

# Documentation search gate

The corpus under `doc/` is 202 files. Finding the right one by filename or by
grepping for a guessed phrase is how a session ends up quoting a superseded plan
or re-deriving a decision that was written down in March. There is an index for
exactly this, and it is not optional.

Full reference: [doc/claude/docs-search.md](../../../doc/claude/docs-search.md).

## Rule 1 — Search before you grep, always

For any question of the form "what did we decide", "which ADR", "where is it
documented", "what does the handbook say", "find the handover for X": call the
`spws-docs` MCP `search` tool with `indexUid: "spws_docs"` **first**.

```
search  indexUid="spws_docs"  q="<2-5 distinctive keywords>"  limit=5
```

**Query with keywords, not sentences.** This is a lexical engine: its first
ranking rule counts how many query words a document matched, so a full question
is diluted by its own grammar. Measured 2026-09-16 against the page that
defines these very rules:

| Query | Score for the right page |
|---|---|
| `re-index documentation` | **0.988** — rank 1 |
| `explicit fold` | **0.971** — rank 1 |
| `documentation search rules` | **0.969** — rank 1 |
| `when must I re-index the documentation search` | missed the top 3 |

Stop words are configured, which removes the worst of it, but the effect
remains. Strip the question down to its nouns. If you must pass a sentence, add
`matchingStrategy: "frequency"` so rare words outweigh common ones.

Narrow with the filterable `kind` when the answer's authority matters:

| Need | Filter |
|---|---|
| A decision and its rationale | `kind = "adr"` |
| Current behaviour | `kind = "handbook"` |
| Normative requirements | `kind = "governance"` |
| A session handover or design thread | `kind = "plan"` |
| An agent procedure (`doc/claude/`) | `kind = "procedure"` |

Each hit gives `path`, `kind`, `title`, `heading` and the matching passage —
enough to open the right file at the right section. Then **read the file**: the
index points at the canonical page, it does not replace it.

**Grep is the fallback.** Use it to confirm a literal string in a known file,
never as the first move to locate a document. If the search returns nothing,
check Rule 2 before concluding the thing does not exist — a stale index and an
absent decision look identical.

**Do not use this for code.** Call edges, blast radius and "what calls X" stay
with graphify and the LSP, per `pre-analysis-check`. This index is prose only.

## Rule 2 — Re-index after any documentation change

A new plan, an amended ADR, an edited handbook page: all of them leave the index
stale, and a stale index silently answers "no such decision". After the
documentation coherence gate and **before committing**:

```bash
python3 tools/docs-search/ingest.py
```

Full rebuild, a few seconds, zero tokens, no model, no network. Expect it to
report a document count; if the count did not move after you added a page,
something is wrong — check that the file is under an indexed directory and is
not inside `doc/archive/`.

At the pre-push checkpoint, the index and the graph refresh together:

```bash
./scripts/refresh-graph.sh && python3 tools/docs-search/ingest.py
```

## If the MCP server is not answering

The stack is one container. Diagnose in this order, and do not fall back to grep
without saying so out loud:

```bash
curl -fsS http://127.0.0.1:7700/health          # is Meilisearch up?
tools/docs-search/setup.sh                       # bring it up, index, re-register
```

`setup.sh` is idempotent and is also the correct recovery after
`docker compose ... down -v`, because that teardown destroys the Meilisearch API
keys along with the volume and leaves the registered MCP key dead. A newly
registered or re-registered MCP server needs a Claude Code restart before its
tools appear.
