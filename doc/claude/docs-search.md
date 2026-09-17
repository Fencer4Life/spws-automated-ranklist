# Documentation search (Meilisearch over MCP)

The documentation corpus is indexed into a local Meilisearch instance and
reached through the `spws-docs` MCP server. It is **local and gitignored data**
— a search index over `doc/`, not a committed artifact, and not a second source
of truth. Two standing rules govern it, deliberately shaped like the two that
govern the graphify graph (see [graph-analysis.md](graph-analysis.md)).

## Rule 1 — Search the index FIRST for any documentation question

Before grepping `doc/` or opening a file by guessed name, query the index.
It covers 202 files and ~2,140 KB of extracted text: the handbook, governance,
every ADR (Markdown sources), every plan, evidence, and the agent procedures in
`doc/claude/`.

Use the `spws-docs` MCP `search` tool with `indexUid: "spws_docs"`, and **query
with keywords rather than sentences**. Meilisearch ranks first on how many query
words a document matched, so a question is diluted by its own grammar. Measured
2026-09-16 against this very page: `re-index documentation` scored 0.988 at rank
one, while "when must I re-index the documentation search" missed the top three
entirely. Stop words are configured for English and Polish, which removes the
worst of it; the effect remains. Two to five distinctive nouns is the shape that
works, and `matchingStrategy: "frequency"` helps when a sentence is unavoidable.

Useful filters, because `kind` is filterable:

```
kind = "adr"                       # decisions only
kind = "handbook"                  # current behaviour only
kind IN ["handbook", "governance"] # canonical pages only
```

Each hit carries `path`, `kind`, `title`, `heading` and the matching passage, so
the result tells you which file to open and where in it to look. `path` is the
distinct attribute — one hit per document, never the same page three times.

**Grep is the fallback, not the first move.** Grep confirms that a literal
string exists in a specific file. It cannot rank, it cannot tolerate a typo, and
it will not find the passage whose wording you did not guess. If a search
returns nothing, that is evidence — but re-index (Rule 2) before treating it as
proof, exactly as with a stale graph.

**This does not replace graphify.** Lexical search over prose cannot answer
`affected fn_commit_event_draft`. Code structure, call edges and blast radius
stay graphify's job; this index answers "what did we decide, and where is it
written down".

**It does not replace the canonical pages either.** The handbook, governance and
ADRs remain the record. This is an index over them — a hit is a pointer to the
owning page, not a substitute for reading it.

## Rule 2 — Re-index whenever documentation changes

Any change under `doc/` — a new plan, an amended ADR, an updated handbook page —
leaves the index stale, and a stale index reads as "that decision does not
exist". After the documentation coherence gate and **before committing**:

```bash
python3 tools/docs-search/ingest.py
```

It is a full rebuild by design: 202 files, ~2,760 chunks, a few seconds, zero
tokens, no model, no network. There is no incremental path because at this size
one is not worth the complexity.

Pair it with the graph refresh — the two go together at the same checkpoint:

```bash
./scripts/refresh-graph.sh && python3 tools/docs-search/ingest.py
```

## Operating the stack

```bash
tools/docs-search/setup.sh        # from nothing, or after `down -v`
python3 tools/docs-search/ingest.py    # re-index after doc changes
docker compose -f tools/docs-search/docker-compose.yml down     # stop, keep data
docker compose -f tools/docs-search/docker-compose.yml down -v  # stop, destroy data
```

`down -v` destroys the Meilisearch API keys with the volume, which would leave
`~/.claude.json` holding a dead key. `setup.sh` re-mints the key and re-registers
the MCP server, so use it rather than `up` alone after a `-v` teardown.

## Design notes — why it is built this way

- **No model, nothing metered.** Lexical search with typo tolerance: no
  embedding model, no LLM, no API key, and no component capable of billing.
  Verified: the container's only connections are inbound from the host.
- **Lexical suits this corpus.** Our documentation is made of exact tokens —
  `ADR-084`, `fn_commit_event_draft`, `arr_weapons`, `vw_calendar` — and exact
  tokens are where BM25 beats embeddings. Vector search can be added later with
  a local embedder if paraphrase recall ever proves missing; it is additive.
- **The HTML has to be stripped, not indexed.** Every hand-written page inlines
  its full stylesheet; `doc/plans` alone holds ~330 KB of CSS. `ingest.py`
  reduces pages to text and splits them on their own headings. Raw markup would
  put `prefers-color-scheme` into the results for every query.
- **Polish needs an explicit fold.** Meilisearch folds ordinary accents but not
  `Ł`, which is its own letter rather than a decorated `L` — measured
  2026-09-16: `Łomianki` returned 12 hits, `Lomianki` zero. Every chunk
  therefore carries a folded ASCII copy in a `folded` field, ranked last so it
  only ever adds matches an accented query would have missed. Both spellings now
  return the same ten documents.
- **ADRs are indexed from Markdown only.** The HTML twins are generated
  duplicates; indexing both doubles every hit.
- **`doc/archive/` is excluded**, the same rule and the same reason as
  `.graphifyignore` — archived narratives are never current-behaviour evidence.
  Templates (`PAGE_TEMPLATE.html`) are excluded too, or their placeholder prose
  ranks against real content.
- **The MCP server holds a read-only key.** It exposes 26 tools including
  `delete-index` and `create-key`; the key scoped to it permits search and reads
  only, and a `delete-index` attempt through MCP is refused. Indexing uses the
  master key, and only from `ingest.py`.
- **Loopback only.** Published on `127.0.0.1:7700`, not reachable from the LAN.
