#!/usr/bin/env python3
"""Incremental graphify refresh — keep graphify-out/ current before committing.

Driven by scripts/refresh-graph.sh (which resolves the graphify interpreter).
Do not run with the project venv: import graphify must resolve to graphify's
own isolated environment (the wrapper passes the pinned interpreter).

What it does, by what changed since the last graph build (via
detect_incremental, which honours .graphifyignore):

  * nothing changed        -> exit 0  (no-op)
  * whitespace-only & code  -> exit 0  (only with --skip-whitespace)
  * doc/paper/image changed -> exit 10 (needs the LLM /graphify . --update flow;
                                        prints the files + GRAPHIFY_NEEDS_SEMANTIC=n)
  * code-only / deletions   -> AST-extract ONLY the changed code files and
                               build_merge into the existing graph. This is the
                               free, headless path; it preserves the semantic
                               doc layer because merge only replaces the nodes of
                               files it re-extracts. exit 0.
  * graph.json missing      -> exit 3  (run a full /graphify . first)

Crucially this does NOT call `graphify update .`, which re-extracts the whole
tree structurally (markdown headings + docstrings) and overwrites the
LLM-extracted doc concepts. We re-extract only the changed code files.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from collections import Counter
from pathlib import Path

GRAPH_JSON = "graphify-out/graph.json"
REPORT_MD = "graphify-out/GRAPH_REPORT.md"
HTML = "graphify-out/graph.html"
LABELS_JSON = "graphify-out/.graphify_labels.json"
HTML_NODE_LIMIT = 5000

DOC_CATEGORIES = ("document", "paper", "image", "video")


def main() -> int:
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--skip-whitespace", action="store_true",
                    help="skip refresh when only whitespace changed vs HEAD")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    def say(*a):
        if not args.quiet:
            print(*a)

    import json

    if not Path(GRAPH_JSON).exists():
        print(f"refresh-graph: no graph yet ({GRAPH_JSON} missing).", file=sys.stderr)
        print("  Run a full build first:  /graphify .", file=sys.stderr)
        return 3

    from graphify.detect import detect_incremental

    r = detect_incremental(Path("."))
    new_files = r.get("new_files", {})
    changed_code = list(new_files.get("code", []))
    changed_docs = [f for cat in DOC_CATEGORIES for f in new_files.get(cat, [])]
    deleted = list(r.get("deleted_files", []))

    # (4) no-op
    if r.get("new_total", 0) == 0 and not deleted:
        say("refresh-graph: graph already current — nothing to update.")
        return 0

    # (5) whitespace-only skip (opt-in, code-only)
    if args.skip_whitespace and not changed_docs:
        ws = subprocess.run(["git", "diff", "-w", "--quiet", "HEAD"])
        if ws.returncode == 0:
            say("refresh-graph: whitespace-only change vs HEAD — skipping refresh.")
            return 0

    # (7) doc changes -> needs the LLM flow, which only the agent can drive
    if changed_docs:
        print(f"refresh-graph: {len(changed_docs)} content file(s) changed — "
              "semantic re-extraction needed.")
        print("  Run:  /graphify . --update   (dispatches extraction subagents), then commit.")
        print("  Changed content files:")
        root = str(Path(".").resolve())
        for f in changed_docs:
            rel = f[len(root) + 1:] if f.startswith(root + "/") else f
            print(f"    {rel}")
        print(f"GRAPHIFY_NEEDS_SEMANTIC={len(changed_docs)}")
        return 10

    # (6) code-only / deletions-only -> targeted AST merge (free, headless)
    say("refresh-graph: code-only changes — targeted AST merge (no LLM)…")
    from graphify.extract import extract, collect_files
    from graphify.build import build_merge, build_from_json
    from graphify.cluster import cluster, score_all
    from graphify.analyze import god_nodes, surprising_connections, suggest_questions
    from graphify.export import to_json, to_html
    from graphify.report import generate
    from graphify.detect import save_manifest

    before = len(json.loads(Path(GRAPH_JSON).read_text())["nodes"])

    files: list[Path] = []
    for f in changed_code:
        p = Path(f)
        files.extend(collect_files(p) if p.is_dir() else [p])

    if files:
        ext = extract(files, cache_root=Path("."))
    else:  # deletions only
        ext = {"nodes": [], "edges": [], "hyperedges": [], "input_tokens": 0, "output_tokens": 0}

    # Carry over prior community labels by membership overlap so curated names
    # ("Pipeline Stages S1–S7", …) stay stable across incremental refreshes.
    old_graph = json.loads(Path(GRAPH_JSON).read_text())
    old_members: dict[str, set[str]] = {}
    for n in old_graph["nodes"]:
        cid = n.get("community")
        if cid is not None:
            old_members.setdefault(str(cid), set()).add(n["id"])
    old_labels = {}
    if Path(LABELS_JSON).exists():
        old_labels = json.loads(Path(LABELS_JSON).read_text())

    G = build_merge([ext], graph_path=GRAPH_JSON,
                    prune_sources=(deleted or None), root=".", directed=False)

    communities = cluster(G)
    cohesion = score_all(G, communities)

    # label carry-over: best Jaccard match to an old community, else auto
    deg = dict(G.degree())
    node_attr = {n: d for n, d in G.nodes(data=True)}

    def auto_label(members: list[str]) -> str:
        dirs = Counter()
        for nid in members:
            sf = (node_attr.get(nid, {}) or {}).get("source_file") or ""
            if sf:
                parts = sf.split("/")
                dirs["/".join(parts[:-1]) if len(parts) > 1 else parts[0]] += 1
        topdir = dirs.most_common(1)[0][0].split("/")[-1] if dirs else "misc"
        best = max(members, key=lambda n: deg.get(n, 0))
        blabel = " ".join(((node_attr.get(best, {}) or {}).get("label", best)).split())
        if len(blabel) > 28:
            blabel = blabel[:28] + "…"
        return f"{topdir}: {blabel}"

    labels: dict[int, str] = {}
    for cid, members in communities.items():
        mset = set(members)
        best_old, best_j = None, 0.0
        for ocid, omset in old_members.items():
            inter = len(mset & omset)
            if not inter:
                continue
            j = inter / len(mset | omset)
            if j > best_j:
                best_j, best_old = j, ocid
        if best_old is not None and best_j >= 0.5 and best_old in old_labels:
            labels[cid] = old_labels[best_old]
        else:
            labels[cid] = auto_label(members)

    gods = god_nodes(G)
    surprises = surprising_connections(G, communities)
    questions = suggest_questions(G, communities, labels)

    wrote = to_json(G, communities, GRAPH_JSON, community_labels=labels)
    if not wrote:
        print("refresh-graph: refused to shrink graph.json (existing has more nodes).",
              file=sys.stderr)
        print("  If you deleted code on purpose, run a full /graphify . rebuild.",
              file=sys.stderr)
        return 2

    detection = {
        "files": r.get("files", {}),
        "total_files": r.get("total_files", 0),
        "total_words": r.get("total_words", 0),
        "skipped_sensitive": r.get("skipped_sensitive", []),
    }
    report = generate(G, communities, cohesion, labels, gods, surprises,
                      detection, {"input": 0, "output": 0}, ".",
                      suggested_questions=questions)
    Path(REPORT_MD).write_text(report)
    Path(LABELS_JSON).write_text(json.dumps({str(k): v for k, v in labels.items()},
                                            ensure_ascii=False))
    save_manifest(r.get("files", {}), root=".")

    after = G.number_of_nodes()
    if after <= HTML_NODE_LIMIT:
        try:
            to_html(G, communities, HTML, community_labels=labels)
        except Exception as e:  # noqa: BLE001 — html is best-effort
            say(f"refresh-graph: graph.html skipped ({e}); graph.json + report updated.")
    else:
        say(f"refresh-graph: graph.html skipped ({after} > {HTML_NODE_LIMIT} nodes); "
            "graph.json + report updated. Run a full /graphify . to regenerate viz.")

    say(f"refresh-graph: graph updated (nodes {before} → {after}). Safe to commit.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
