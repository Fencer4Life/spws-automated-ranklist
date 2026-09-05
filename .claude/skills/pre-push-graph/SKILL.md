---
name: pre-push-graph
description: "MANDATORY before any `git push` in this repo (SPWS Automated Ranklist System), and the ONLY correct way to refresh the graphify knowledge graph after ANY change including documentation. Brings graphify-out/ (gitignored) up to HEAD so later `graphify query/explain/affected/path` calls reflect reality instead of stale structure. Triggers on: preparing to push, `git push`, 'push to main', releasing, finishing a batch of commits, or any request to refresh/rebuild/update the knowledge graph after code, SQL or doc changes. It is one command — `./scripts/refresh-graph.sh` — which extracts code, SQL AND docs locally for zero tokens. Never dispatch `/graphify . --update` or extraction subagents for a routine refresh."
---

# Pre-push graph refresh

The graphify graph in `graphify-out/` is a **local-only developer aid** —
`graphify-out/` is gitignored (`.gitignore:30`), so it is never committed or
pushed. Its only job is to make `graphify query`, `explain`, `affected` and
`path` accurate for whoever is working in this checkout. That accuracy decays
every time code or docs change and the graph is not refreshed.

Push is the natural checkpoint: it is the moment a batch of work is declared
"done", and the moment the next person (or the next session) is most likely to
query the graph and be misled by stale structure. So the contract is: **refresh
the graph to match `HEAD` before you push.**

This is *not* about committing anything — the graph stays local. It is about not
leaving a stale graph behind for the next query.

## What to do, in order

### 1. Guarantee SQL is parseable (one-time, but always verify)

This repo's real logic is PL/pgSQL, and graphify only produces SQL nodes when
`tree_sitter_sql` is importable in graphify's **isolated** interpreter (the uv
tool env, NOT the project `.venv`). Without it, `extract_sql()` returns empty
and every migration and pgTAP file silently yields zero graph nodes even though
they appear in the manifest.

```bash
GPY="$(cat graphify-out/.graphify_python 2>/dev/null || echo /Users/aleks/.local/share/uv/tools/graphifyy/bin/python)"
"$GPY" -c "import tree_sitter_sql" 2>/dev/null \
  || uv tool install graphifyy --with tree-sitter-sql
```

If it had to install, the ~203 historical `.sql` files are still absent from
the graph (they were manifested empty). Force them back in for free — SQL is
AST-extracted, deterministic, no LLM — by invalidating their manifest entries
so the next update re-extracts them:

```bash
python3 - <<'PY'
import json, pathlib
p = pathlib.Path("graphify-out/manifest.json")
if p.exists():
    m = json.loads(p.read_text())
    before = len(m)
    m = {k: v for k, v in m.items() if not k.endswith(".sql")}
    p.write_text(json.dumps(m))
    print(f"invalidated {before - len(m)} .sql entries for free AST re-extraction")
PY
```

### 2. Run the refresh and read its exit code (not its stdout)

```bash
./scripts/refresh-graph.sh --quiet >/tmp/refresh.out 2>&1; echo "exit=$?"
```

**Read the real exit code**, not a piped one — `... | tail` reports `tail`'s
exit, which is how a stale graph gets mistaken for a current one. The contract
(`scripts/refresh-graph.sh` header):

| Exit | Meaning | Action |
| --- | --- | --- |
| `0` | Graph current — code, SQL **and docs** merged headlessly for free, or nothing relevant changed. | Push. |
| `3` | No graph yet (`graphify-out/graph.json` missing). | Run a full `/graphify .` once to seed it, then push. |
| `2` | Environment error (graphify interpreter missing, shrink guard). | Fix the environment; do not push a stale graph silently. |

**Exit `0` is the only outcome you should normally see, and it needs nothing
further.** Docs included. Stop here and push.

### 3. Do NOT dispatch subagents for documentation

This is the trap this skill exists to close. A docs pass in this repo routinely
touches 40+ files; `/graphify . --update` batches those into `general-purpose`
subagents that each read every file in full. That is millions of tokens to
refresh a **local, gitignored developer aid**, and it is never the right trade.

`scripts/graphify_docs_extract.py` replaced it. Docs here cite repo-relative
source paths, `ADR-NNN` ids and sibling documents *literally in the prose*, so a
parser recovers the useful structure — which document talks about which file,
ADR and section — deterministically, with every edge marked `EXTRACTED` because
it is written in the file rather than guessed. 40 documents extract in about
four seconds for **zero tokens**, and `refresh-graph.sh` merges the result in
alongside the code AST automatically. There is nothing to invoke by hand.

What it deliberately skips: semantic concepts, `INFERRED` edges and rationale
mining. Those genuinely need a model. If someone explicitly asks for that layer,
`/graphify . --update` still exists — but it is an opt-in request, never a step
in a routine refresh, and never something to reach for on your own initiative.
Images and papers are the same: reported and skipped, not blocking.

If you catch yourself about to spawn an extraction subagent, stop. Run
`./scripts/refresh-graph.sh` instead.

### 4. Verify SQL actually landed, then push

```bash
python3 - <<'PY'
import json
g = json.load(open("graphify-out/graph.json"))
sql = [n for n in g["nodes"] if str(n.get("source_file","")).endswith(".sql")]
print(f"SQL nodes in graph: {len(sql)}  (0 means tree_sitter_sql is still missing — see Step 1)")
PY
```

A healthy graph has SQL nodes (tables, views, functions from the migrations).
Zero after a refresh means Step 1 did not take — fix it before relying on
`graphify affected` for any SQL-touching change.

## Corpus hygiene (already configured; keep it that way)

`.graphifyignore` deliberately excludes, and the graph must stay clear of:

- `doc/staging/` — the daily CERT→PROD reconcile logs are churn, not source,
  and would burn LLM budget on ~22 throwaway files per refresh.
- `doc/plans/msw-tbilisi-handover-2026-07-19-evening.html` — MŚW campaign
  correspondence naming individuals, deliberately untracked in git and promised
  for deletion (privacy variant A). It must never enter even the local graph,
  where a `grep graph.json` could resurface it.
- `doc/archive/` and the three generated HTML twins (ADR-082) — build
  artifacts, not source.

If a new class of generated or sensitive file appears, add it to
`.graphifyignore` **before** the next refresh, not after — the graph embeds file
contents, and removing them after the fact means rebuilding.

## Why this exists

The graph silently drifted from 14 July to 23 July across an entire security
release (ADR-083) — SQL was invisible the whole time because `tree_sitter_sql`
was never installed, and doc changes accumulated because the semantic pass only
runs on demand. Tying the refresh to push makes "the graph reflects what I just
shipped" the default instead of something remembered occasionally. See
`[[feedback_graph_analysis_first]]` and `[[feedback_graph_refresh_precommit]]`
in memory — this skill is how that pre-commit/pre-push intent is actually
carried out for a corpus that includes SQL.
