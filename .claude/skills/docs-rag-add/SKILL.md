---
name: docs-rag-add
description: "MANDATORY when a document must become findable in the local documentation RAG for this repo (SPWS Automated Ranklist System) — the Meilisearch `spws_docs` index served over the `spws-docs` MCP server. Places the file under an indexed root (or extends the ingest source list when it cannot move), rebuilds with `python3 tools/docs-search/ingest.py`, and proves the document is retrievable by searching a phrase unique to it before calling it done. Also covers removing one, because the rebuild is authoritative in both directions. Triggers on: add this to the RAG, add a document to the index, index this plan, make this searchable, put the handover in the search index, why can't you find my page, this document isn't in the index, ingest this doc, register a new plan / ADR / handbook page for search, re-index after writing a document, remove this page from the index, the search still returns a file I deleted."
---

# Adding a document to the documentation RAG

The index is a **pure function of the files under a fixed set of roots**. There
is no such thing as adding a document to it by hand — you add the document to
the repository, in a place the ingest walks, and then rebuild.

Contract and rationale: [doc/claude/docs-search.md](../../../doc/claude/docs-search.md).
Searching the index is the sibling skill `docs-search`; this one is the write path.

## Never add through MCP

The `spws-docs` server exposes `add-documents`, `create-index` and
`delete-index`. **Do not use them.** Two independent reasons:

1. The key registered to that server is scoped read-only, so the call is
   refused. Reporting "the index rejected my write" as a blocker is wrong — the
   write path was never MCP.
2. Even with a privileged key it would be wrong. `ingest.py` rebuilds every
   chunk from the files on disk, so a hand-posted document survives exactly
   until the next re-index, then vanishes with no error. That is a decision
   silently disappearing from the corpus — the precise failure the index exists
   to prevent.

The write path is `python3 tools/docs-search/ingest.py`, and nothing else.

## Step 1 — Is the file inside an indexed root?

Six roots, defined in [tools/docs-search/ingest.py](../../../tools/docs-search/ingest.py)
as `SOURCES`. Check the file's path against them before anything else:

| `kind` | Root | Glob |
|---|---|---|
| `handbook` | `doc/handbook` | `**/*.html` |
| `governance` | `doc/governance` | `**/*.html` |
| `adr` | `doc/adr` | `**/*.md` |
| `plan` | `doc/plans` | `**/*.html` |
| `evidence` | `doc/evidence` | `**/*.html` |
| `procedure` | `doc/claude` | `**/*.md` |

The extension is part of the contract, not decoration. A `.md` file dropped in
`doc/plans` is walked by `**/*.html` and silently skipped; so is a `.html` file
in `doc/adr`. ADRs are indexed from their Markdown source only — never add the
generated HTML twin, it doubles every hit.

Also excluded, deliberately: anything under `doc/archive/` (superseded narrative
is never current-behaviour evidence) and the template files `PAGE_TEMPLATE.html`,
`TEMPLATE.md`, `TEMPLATE.html`.

**In an indexed root already → go to step 3.** This is the common case: you
just wrote a plan into `doc/plans/`, and "adding it to the RAG" is one rebuild.

## Step 2 — Only if the file is outside those roots

Three options, in order of preference. Do not pick silently — say which one you
took and why.

**(a) Move it to where it belongs.** A design document living in the scratch
directory, the repo root, or `doc/` loose belongs in `doc/plans/` as HTML.
Usually this is the right answer and the question answers itself.

**(b) Extend `SOURCES` in `ingest.py`.** Correct when a whole *category* of
document should be searchable from now on — not for one file. Adding a row is a
one-line change plus a `kind` label, and the new `kind` becomes a filter value,
so it needs to mean something. Note that `doc/external_files/` is gitignored by
design (campaign material) — indexing it is possible, since the index is local
and gitignored too, but it mixes one-off correspondence with the documentation
corpus, so confirm before doing it.

**(c) Say it cannot be indexed.** PDFs, spreadsheets and images are not
extracted: only `.md` and `.html` are parsed, everything else yields nothing.
The honest outcome is to say so rather than to run an ingest that reports
success while indexing nothing of the file.

## Step 3 — Rebuild, and read what it prints

```bash
python3 tools/docs-search/ingest.py
```

A few seconds, zero tokens, no model, no network. Note the file and chunk counts
it prints **before** the rebuild starts, and compare against the previous run:

- **File count did not move** after adding a page → the file is outside an
  indexed root, has the wrong extension, or is excluded. Go back to step 1.
  Do not proceed; the rebuild "succeeded" and indexed nothing new.
- **`! <directory> missing, skipped`** on stderr → a root does not exist. The
  rebuild continues and silently drops that whole category.

`--dry-run` reports the same counts and sends nothing, which is the cheap way to
check that a new file is picked up before touching the index.

## Step 4 — Prove retrieval, do not assume it

A document count is not evidence that *this* document is findable. Search for a
phrase that occurs in the new file and essentially nowhere else, and confirm the
hit's `path` is the file you added:

```
search  indexUid="spws_docs"  q="<2-5 distinctive keywords from the new page>"
        filter="path = 'doc/plans/<file>.html'"
```

`path` is filterable, so the filter turns this into a direct existence check
rather than a ranking exercise. An empty result after a rebuild that reported
success means the file was walked but produced no chunks — typically an HTML
page whose text sits outside the elements the extractor reads, or sections under
40 characters with no heading, which are dropped by design.

## Removing a document

A rebuild is authoritative in both directions, so removal needs nothing special:
delete or rename the file, run the ingest, and the chunks go with it. Chunks are
upserted under an id derived from path and ordinal, and whatever the index still
holds that the run did not produce is deleted afterwards. Shortening a page
drops its tail; deleting or renaming one leaves nothing behind under the old
path.

The run says what it removed:

```
Pruned 3 stale chunk(s) across 1 document(s):
    doc/plans/superseded-handover.html
```

Read that line. Pruning is how a **wrongly excluded** directory announces itself
— if a rebuild reports dropping documents you did not touch, a root is missing
or a path moved out of scope, and the fix is to restore the scope rather than to
accept the deletion. `! <directory> missing, skipped` on stderr in the same run
is the confirming symptom.

## Commit checkpoint

The index itself is local and gitignored — there is nothing to commit about it.
The **document** is committed normally, and the index is refreshed alongside the
graph at the same checkpoint:

```bash
./scripts/refresh-graph.sh && python3 tools/docs-search/ingest.py
```

Definition of done for the surrounding change remains `scripts/preflight.sh`
exiting 0.
