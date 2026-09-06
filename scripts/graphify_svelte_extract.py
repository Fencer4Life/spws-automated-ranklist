#!/usr/bin/env python3
"""Deterministic, zero-LLM extraction of `.svelte` script bodies for the graph.

WHY THIS EXISTS
---------------
graphify hands a whole `.svelte` file to a JavaScript tree-sitter parser. The
HTML markup is not valid JavaScript, so the parse produces a top-level ERROR
node and almost nothing survives. graphify knows: its own `extract_svelte`
docstring says static imports "are silently dropped (#713)" for exactly this
reason and regex-rescues them. It does not rescue *declarations*.

Measured 2026-09-06 against `frontend/src`:

    36 .svelte files -> 54 nodes in graph.json, 610 available from their
    <script> bodies. 556 missing, about 91% of the frontend's component logic.

`App.svelte` alone held 2 nodes where its script body yields 110. A query for
`handleWizardCommit` or `loadCalendar` returned nothing, which reads as "does
not exist" rather than "the extractor could not see it" — and this repository's
own rule is to query the graph before analysis.

WHAT IT DOES
------------
Cuts each `<script>` body out, hands *that* to graphify's ordinary JS extractor,
and reattributes the result to the `.svelte` file: `source_file` back to the
component, `source_location` offset by the line the block starts on, and node
ids built on the prefix graphify derives from the component's own path so the
rescued declarations land under the existing file node.

WHAT IT DELIBERATELY DOES NOT DO
--------------------------------
Imports. graphify's own pass already rescues those, correctly, and a second
opinion would fight it. This module keeps only nodes belonging to the component
itself and drops every cross-file stub the JS extractor emits — which also keeps
it clear of the import-stub defect that makes an incremental refresh replace an
imported file's whole node set with a single stub.

Same contract and same cost as `graphify_docs_extract`: the standard
`{nodes, edges, hyperedges, input_tokens, output_tokens}` fragment, zero tokens.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import tempfile
from collections.abc import Callable, Sequence
from pathlib import Path

SVELTE_SUFFIX = ".svelte"

# `<script>`, `<script lang="ts">`, `<script module>` — all of them, and nothing
# that merely starts with "script" (`<scriptish>` must not match).
_SCRIPT_RE = re.compile(r"<script\b[^>]*>([\s\S]*?)</script\s*>", re.IGNORECASE)


def script_blocks(source: str) -> list[tuple[str, int]]:
    """Return `(body, tag_line)` for every script block, in file order.

    `tag_line` is the 1-based line the opening `<script ...>` sits on, and the
    line delta for the body is `tag_line - 1`.

    The delta is zero for a block whose tag is on line 1, and that is correct
    rather than an off-by-one: the captured body BEGINS with the newline that
    ends the tag's own line, so body line 1 is the empty remainder of the tag
    line and body line N lines up with file line N. Getting this wrong would
    produce citations that look right and point at the wrong line, which is
    worse than no line at all.
    """
    blocks: list[tuple[str, int]] = []
    for match in _SCRIPT_RE.finditer(source):
        tag_line = source.count("\n", 0, match.start(1)) + 1
        blocks.append((match.group(1), tag_line))
    return blocks


def _id_prefix(rel_path: str) -> str:
    """The id prefix graphify derives from a path: parent directory + stem.

    `frontend/src/App.svelte` -> `src_app`;
    `frontend/src/components/EventCard.svelte` -> `components_eventcard`.
    Mirroring it is what makes the rescued nodes attach to the existing file
    node instead of forming a parallel island.
    """
    p = Path(rel_path)
    parent = p.parent.name or "root"
    return re.sub(r"[^a-z0-9]+", "_", f"{parent}_{p.stem}".lower()).strip("_")


def _offset_location(location: object, delta: int) -> object:
    """Shift a `L<n>` source_location by `delta` lines, leaving anything else."""
    if not isinstance(location, str):
        return location
    m = re.fullmatch(r"L(\d+)", location.strip())
    if not m:
        return location
    return f"L{int(m.group(1)) + delta}"


def _default_js_extract(paths: list[Path], *, cache_root: Path) -> dict:
    """graphify's own JS/TS extractor. Imported late and behind a seam.

    graphify is installed in its OWN isolated interpreter, not the project venv
    (`scripts/refresh-graph.sh` resolves it), so importing it at module scope
    would make this file unimportable under pytest. The seam also lets the
    reattribution logic below — the part written here, and the part that can be
    wrong — be tested without graphify present.
    """
    from graphify.extract import extract

    return extract(paths, cache_root=cache_root, parallel=False)


def extract_svelte_scripts(
    paths: Sequence[Path],
    *,
    root: Path,
    js_extract: Callable[..., dict] = _default_js_extract,
) -> dict:
    """Build a graphify extraction fragment from `.svelte` script bodies."""
    root = root.resolve()
    nodes: list[dict] = []
    edges: list[dict] = []
    seen: set[str] = set()

    components = [p for p in paths if p.suffix.lower() == SVELTE_SUFFIX and p.is_file()]

    with tempfile.TemporaryDirectory(prefix="graphify-svelte-") as tmp:
        tmp_root = Path(tmp)
        for comp in components:
            rel = str(comp.resolve().relative_to(root))
            blocks = script_blocks(comp.read_text(encoding="utf-8", errors="replace"))
            if not blocks:
                continue

            prefix = _id_prefix(rel)
            # The temp file's own parent+stem must reproduce `prefix`, because
            # that is what graphify will build its ids from.
            staged_dir = tmp_root / Path(rel).parent.name
            staged_dir.mkdir(parents=True, exist_ok=True)
            staged = staged_dir / (Path(rel).stem + ".ts")
            if _id_prefix(str(staged.relative_to(tmp_root))) != prefix:  # pragma: no cover
                raise AssertionError(
                    f"staged path {staged} would not reproduce graphify's id prefix "
                    f"{prefix!r} for {rel}; the rescued nodes would not attach"
                )

            for body, tag_line in blocks:
                staged.write_text(body, encoding="utf-8")
                fragment = js_extract([staged], cache_root=tmp_root)

                staged_str = str(staged)
                # Keep only what belongs to this component. Everything else the
                # JS extractor emits is a cross-file import stub; graphify's own
                # svelte pass owns those.
                kept: set[str] = set()
                delta = tag_line - 1
                for node in fragment.get("nodes", []):
                    if node.get("source_file") != staged_str:
                        continue
                    node_id = str(node.get("id", ""))
                    if not node_id or node_id in seen:
                        continue
                    if node_id == prefix:
                        # The file-level node. graphify's own svelte pass already
                        # creates it, correctly labelled; ours would carry the
                        # staged name ("App.ts") and overwrite that on merge.
                        # Its edges still resolve — the id is the same one.
                        continue
                    node = dict(node)
                    node["source_file"] = rel
                    node["source_location"] = _offset_location(node.get("source_location"), delta)
                    node.setdefault("file_type", "code")
                    node["confidence"] = "EXTRACTED"
                    nodes.append(node)
                    seen.add(node_id)
                    kept.add(node_id)

                for edge in fragment.get("edges", []):
                    src, tgt = edge.get("source"), edge.get("target")
                    # No dangling endpoints: build_merge drops those silently, so
                    # an edge that survives here must land. The component's own
                    # file node counts as an endpoint even though it is not in
                    # this fragment — graphify's svelte pass contributes it under
                    # the same id.
                    if src in kept | {prefix} and tgt in kept | {prefix}:
                        edge = dict(edge)
                        edge["source_file"] = rel
                        edge["confidence"] = "EXTRACTED"
                        edges.append(edge)

    return {
        "nodes": nodes,
        "edges": edges,
        "hyperedges": [],
        "input_tokens": 0,
        "output_tokens": 0,
    }


def main(argv: Sequence[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("paths", nargs="*", type=Path, help="`.svelte` files (default: all)")
    ap.add_argument("--root", type=Path, default=Path("."))
    ap.add_argument("--json", action="store_true", help="print the fragment")
    args = ap.parse_args(argv)

    root = args.root.resolve()
    paths = args.paths or sorted((root / "frontend" / "src").rglob("*.svelte"))
    fragment = extract_svelte_scripts(paths, root=root)
    if args.json:
        json.dump(fragment, sys.stdout, indent=2, ensure_ascii=False)
        print()
    else:
        print(
            f"svelte: {len(fragment['nodes'])} nodes, "
            f"{len(fragment['edges'])} edges from {len(paths)} file(s), 0 tokens"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
