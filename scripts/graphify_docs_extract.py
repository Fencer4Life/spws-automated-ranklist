#!/usr/bin/env python3
"""Deterministic, zero-LLM doc extraction for the graphify graph.

Why this exists
---------------
`graphify_refresh.py` used to bail out with exit 10 whenever a doc changed,
telling the agent to run `/graphify . --update`, which dispatches LLM subagents
over every changed document. In this repo a routine documentation pass touches
dozens of files, so "refresh the graph" became a multi-million-token operation
for a local, gitignored developer aid.

It does not need to be. The docs here are unusually machine-readable: they cite
repo-relative source paths, ADR ids, and sibling documents *literally*, in the
prose. That is enough to build an honest doc layer with a parser — and every
edge it produces is EXTRACTED, because it is written in the file rather than
inferred by a model.

What it deliberately does NOT do
--------------------------------
No semantic concepts, no INFERRED edges, no rationale mining. Those need a
model and they are the expensive part. If someone genuinely wants that layer
they can still run `/graphify . --update` by hand. This module covers the 90%
that is free: which document talks about which file, ADR, and section.

Every edge is only emitted when its target already exists in the graph, so a
mention of a path that was never indexed produces nothing rather than a ghost.
"""
from __future__ import annotations

import json
import re
from collections.abc import Sequence
from html.parser import HTMLParser
from pathlib import Path

# Only paths with one of these suffixes are treated as source references. A
# bare word with a dot in it ("e.g", "v0.2") must never become an edge.
SOURCE_SUFFIXES = (
    "ts", "tsx", "js", "mjs", "svelte", "py", "sql", "md", "html",
    "json", "sh", "yml", "yaml", "toml", "css",
)
PATH_RE = re.compile(
    r"(?<![\w./-])((?:[\w.-]+/)+[\w.-]+\.(?:" + "|".join(SOURCE_SUFFIXES) + r"))(?![\w/])"
)
ADR_RE = re.compile(r"\bADR-(\d{3})\b")
MD_HEADING_RE = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")
MD_LINK_RE = re.compile(r"\]\(([^)\s]+)\)")
HREF_RE = re.compile(r"""href\s*=\s*["']([^"'#]+)""", re.I)

DOC_SUFFIXES = {".md", ".html", ".htm", ".txt"}


def _slug(text: str) -> str:
    """Lowercase, `[a-z0-9_]` only — the id alphabet graphify's AST pass uses."""
    s = re.sub(r"[^a-z0-9]+", "_", text.lower())
    return s.strip("_")


def node_id_for_path(rel_path: str) -> str:
    """`{immediate parent dir}_{filename stem}`, matching the AST extractor.

    `frontend/src/lib/api.ts` -> `lib_api`. Only ONE level of parent is used;
    the full path would create a duplicate of the node the AST pass already
    made, and the bare stem would collide across directories.
    """
    p = Path(rel_path)
    stem = _slug(p.stem)
    parent = p.parent.name
    return f"{_slug(parent)}_{stem}" if parent else stem


class _Html(HTMLParser):
    """Pulls the title, the h1-h3 headings and the tag-stripped text."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.title: str | None = None
        self.headings: list[str] = []
        self.text: list[str] = []
        self._capture: str | None = None
        self._buf: list[str] = []

    def handle_starttag(self, tag: str, attrs) -> None:  # noqa: ANN001
        if tag in ("title", "h1", "h2", "h3"):
            self._capture = tag
            self._buf = []

    def handle_endtag(self, tag: str) -> None:
        if tag != self._capture:
            return
        value = " ".join("".join(self._buf).split())
        if value:
            if tag in ("title", "h1"):
                if self.title is None:
                    self.title = value
                if tag != "h1":
                    pass
                elif self.title != value:
                    self.headings.append(value)
            else:
                self.headings.append(value)
        self._capture = None
        self._buf = []

    def handle_data(self, data: str) -> None:
        if self._capture:
            self._buf.append(data)
        self.text.append(data)


def _parse(path: Path) -> tuple[str, list[str], str]:
    """-> (title, headings, plain text). Never raises on malformed input."""
    raw = path.read_text(encoding="utf-8", errors="replace")
    if path.suffix.lower() in (".html", ".htm"):
        p = _Html()
        try:
            p.feed(raw)
        except Exception:  # noqa: BLE001 — a broken doc must not fail a refresh
            pass
        # Attribute values (href=…) are dropped by the text handler, so keep the
        # raw source alongside it: a path may only appear inside an attribute.
        return (p.title or path.stem), p.headings, " ".join(p.text) + "\n" + raw

    title, headings = path.stem, []
    for line in raw.splitlines():
        m = MD_HEADING_RE.match(line)
        if not m:
            continue
        level, text = len(m.group(1)), m.group(2).strip()
        if level == 1 and title == path.stem:
            title = text
        elif 2 <= level <= 3:
            headings.append(text)
    return title, headings, raw


def _adr_index(root: Path) -> dict[str, str]:
    """`040` -> `doc/adr/040-event-results-urls.md`, from what is on disk."""
    out: dict[str, str] = {}
    adr_dir = root / "doc" / "adr"
    if not adr_dir.is_dir():
        return out
    for f in adr_dir.glob("*.md"):
        m = re.match(r"(\d{3})", f.name)
        if m:
            out[m.group(1)] = str(f.relative_to(root))
    return out


def _known_node_ids(graph_path: Path) -> set[str]:
    if not graph_path.exists():
        return set()
    data = json.loads(graph_path.read_text(encoding="utf-8"))
    return {n["id"] for n in data.get("nodes", [])}


def extract_docs(
    paths: Sequence[Path],
    *,
    graph_path: Path,
    root: Path,
) -> dict:
    """Build a graphify extraction fragment from documentation files.

    Returns the standard `{nodes, edges, hyperedges, input_tokens, output_tokens}`
    shape, with both token counts zero — that is the whole point of this module.
    """
    root = root.resolve()
    known = _known_node_ids(graph_path)
    adrs = _adr_index(root)

    nodes: list[dict] = []
    edges: list[dict] = []
    seen_nodes: set[str] = set()

    docs = [p for p in paths if p.suffix.lower() in DOC_SUFFIXES]
    # A doc referenced by another doc in the same batch is a valid target even
    # though the graph has not seen it yet.
    batch_ids = {node_id_for_path(str(p.resolve().relative_to(root))) for p in docs}

    def add_node(node: dict) -> None:
        if node["id"] not in seen_nodes:
            seen_nodes.add(node["id"])
            nodes.append(node)

    def add_edge(src: str, tgt: str, relation: str, source_file: str) -> None:
        if tgt == src or (tgt not in known and tgt not in seen_nodes and tgt not in batch_ids):
            return
        if any(e["source"] == src and e["target"] == tgt and e["relation"] == relation
               for e in edges):
            return
        edges.append({
            "source": src, "target": tgt, "relation": relation,
            "confidence": "EXTRACTED", "confidence_score": 1.0,
            "source_file": source_file, "source_location": None, "weight": 1.0,
        })

    for path in docs:
        rel = str(path.resolve().relative_to(root))
        doc_id = node_id_for_path(rel)
        title, headings, text = _parse(path)

        add_node({
            "id": doc_id, "label": title, "file_type": "document",
            "source_file": rel, "source_location": None, "source_url": None,
            "captured_at": None, "author": None, "contributor": None,
        })

        for h in headings:
            slug = _slug(h)
            if not slug:
                continue
            sec_id = f"{doc_id}_{slug}"
            add_node({
                "id": sec_id, "label": h, "file_type": "concept",
                "source_file": rel, "source_location": None, "source_url": None,
                "captured_at": None, "author": None, "contributor": None,
            })
            add_edge(doc_id, sec_id, "references", rel)

        # Literal repo-relative source paths written in the prose.
        for m in PATH_RE.finditer(text):
            add_edge(doc_id, node_id_for_path(m.group(1)), "references", rel)

        # ADR-NNN citations, resolved against the ADR files actually on disk.
        for m in ADR_RE.finditer(text):
            target = adrs.get(m.group(1))
            if target:
                add_edge(doc_id, node_id_for_path(target), "cites", rel)

        # Links to sibling documents, resolved relative to this file.
        for m in list(MD_LINK_RE.finditer(text)) + list(HREF_RE.finditer(text)):
            href = m.group(1)
            if "://" in href or href.startswith(("mailto:", "#")):
                continue
            try:
                target = (path.parent / href).resolve().relative_to(root)
            except (ValueError, OSError):
                continue
            if target.suffix.lower() in DOC_SUFFIXES:
                add_edge(doc_id, node_id_for_path(str(target)), "references", rel)

    return {
        "nodes": nodes,
        "edges": edges,
        "hyperedges": [],
        "input_tokens": 0,
        "output_tokens": 0,
    }


def main(argv: Sequence[str] | None = None) -> int:
    import argparse

    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("paths", nargs="+", type=Path)
    ap.add_argument("--graph", type=Path, default=Path("graphify-out/graph.json"))
    ap.add_argument("--root", type=Path, default=Path("."))
    ap.add_argument("-o", "--out", type=Path)
    args = ap.parse_args(argv)

    result = extract_docs(args.paths, graph_path=args.graph, root=args.root)
    text = json.dumps(result, ensure_ascii=False, indent=2)
    if args.out:
        args.out.write_text(text, encoding="utf-8")
        print(f"docs-extract: {len(result['nodes'])} nodes, {len(result['edges'])} edges "
              f"-> {args.out} (0 tokens)")
    else:
        print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
