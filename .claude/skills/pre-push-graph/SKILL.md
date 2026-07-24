---
name: pre-push-graph
description: "MANDATORY before any `git push` in this repo (SPWS Automated Ranklist System). Brings the local graphify knowledge graph (graphify-out/, gitignored) up to the commits about to be pushed, so later `graphify query/explain/affected/path` calls reflect reality instead of stale July-era structure. Triggers on: preparing to push, `git push`, 'push to main', releasing, finishing a batch of commits, or any request to refresh/rebuild the knowledge graph. Runs the free SQL + code AST pass always; dispatches doc semantic extraction only when docs changed."
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
| `0` | Graph current — refreshed headlessly (code/SQL AST merged for free), or nothing relevant changed. | Push. |
| `10` | Doc/paper/image files changed — semantic re-extraction needs an LLM. Prints the changed files + `GRAPHIFY_NEEDS_SEMANTIC=<n>`. | Go to Step 3, then push. |
| `3` | No graph yet (`graphify-out/graph.json` missing). | Run a full `/graphify .` (Step 3 covers the semantic half), then push. |
| `2` | Environment error (graphify interpreter missing, shrink guard). | Fix the environment; do not push a stale graph silently. |

Exit `0` is the common case for code-only work and needs nothing further — the
SQL/code AST merge already ran. Stop here and push.

### 3. Only when exit was 10 (or 3): the semantic doc pass

Doc extraction is the one step that costs tokens. Invoke the `graphify` skill
with `--update` (incremental — only the changed docs) or, on exit 3, a full
`/graphify .`:

```
/graphify . --update
```

- If `GEMINI_API_KEY` or `GOOGLE_API_KEY` is set, graphify runs the doc
  extraction headlessly through Gemini — cheap, no subagents.
- If neither is set (current state of this repo), the `graphify` skill
  dispatches `general-purpose` subagents in batches of ~15 files. **This is the
  only expensive part of a push.** State the batch size before dispatching, so
  the cost is visible.

The AST half (all `.sql` invalidated in Step 1, plus any changed code) runs in
the same pass for free, in parallel with the doc subagents.

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
