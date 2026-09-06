"""Tests for scripts/graphify_svelte_extract.py — plan-test IDs sv.1-sv.9.

graphify feeds a whole `.svelte` file to a JavaScript tree-sitter parser. The
HTML markup is not valid JS, so the parse yields a top-level ERROR node and
almost nothing is recovered: measured 2026-09-06, the code graph held 54 nodes
for the 36 `.svelte` files under `frontend/src`, against 610 available from
their `<script>` bodies — 556 missing, about 91% of the frontend's component
logic. graphify's own extractor already regex-rescues *imports* for this exact
reason (its `extract_svelte` docstring cites the ERROR node); it does not rescue
declarations.

This module rescues the declarations, locally and deterministically, the same
way `graphify_docs_extract` handles documentation.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))

from graphify_svelte_extract import (  # noqa: E402
    extract_svelte_scripts,
    script_blocks,
)

SAMPLE = """\
<script lang="ts">
  import { onMount } from 'svelte'
  let count = $state(0)

  function increment() {
    count += 1
  }

  async function loadThings(): Promise<void> {
    await Promise.resolve()
  }
</script>

<div class="wrap">
  <button onclick={increment}>{count}</button>
</div>

<style>
  .wrap { display: flex; }
</style>
"""


def fake_js_extract(paths: list[Path], *, cache_root: Path) -> dict:
    """Stand in for graphify's JS extractor, in its output shape.

    graphify lives in its own isolated interpreter (`scripts/refresh-graph.sh`
    resolves it) and is not importable from the project venv, so the logic this
    module actually owns — reattribution, line offsets, id prefixes, edge
    filtering — is tested against a fake rather than left untested. The real
    extractor is exercised by `test_real_graphify_recovers_what_the_file_loses`
    when it happens to be importable.

    Deliberately emits a cross-file import stub too: dropping those is a
    behaviour worth pinning, not an implementation detail.
    """
    staged = paths[0]
    body = staged.read_text(encoding="utf-8")
    stem_prefix = f"{staged.parent.name}_{staged.stem}".lower()
    nodes: list[dict] = [
        {
            "id": stem_prefix,
            "label": staged.stem,
            "file_type": "code",
            "source_file": str(staged),
            "source_location": "L1",
        }
    ]
    edges: list[dict] = []
    for lineno, line in enumerate(body.splitlines(), start=1):
        m = re.search(r"\bfunction\s+([A-Za-z_$][\w$]*)", line)
        if not m:
            continue
        name = m.group(1)
        node_id = f"{stem_prefix}_{name.lower()}"
        nodes.append(
            {
                "id": node_id,
                "label": name,
                "file_type": "code",
                "source_file": str(staged),
                "source_location": f"L{lineno}",
            }
        )
        edges.append(
            {
                "source": stem_prefix,
                "target": node_id,
                "relation": "contains",
                "confidence": "EXTRACTED",
                "source_file": str(staged),
            }
        )
    # An import stub, attributed to ANOTHER file — must not survive.
    nodes.append(
        {
            "id": "lib_other",
            "label": "./other",
            "file_type": "code",
            "source_file": "/somewhere/else/other.ts",
            "source_location": "L1",
        }
    )
    edges.append(
        {
            "source": stem_prefix,
            "target": "lib_other",
            "relation": "imports",
            "confidence": "EXTRACTED",
            "source_file": str(staged),
        }
    )
    return {"nodes": nodes, "edges": edges, "hyperedges": [], "input_tokens": 0, "output_tokens": 0}


def run(component: Path) -> dict:
    """Call the extractor with the fake, rooted at the component's tmp_path."""
    return extract_svelte_scripts(
        [component], root=component.parents[2], js_extract=fake_js_extract
    )


@pytest.fixture
def sample_component(tmp_path: Path) -> Path:
    comp = tmp_path / "src" / "components" / "Widget.svelte"
    comp.parent.mkdir(parents=True)
    comp.write_text(SAMPLE, encoding="utf-8")
    return comp


def test_script_blocks_returns_body_and_line_offset(sample_component: Path) -> None:
    """sv.1 — the body is returned with the line the body starts on."""
    blocks = script_blocks(sample_component.read_text(encoding="utf-8"))
    assert len(blocks) == 1
    body, tag_line = blocks[0]
    assert "function increment()" in body
    # The tag is on line 1, so the delta is 0 — the captured body starts with
    # the newline ending the tag's line, which makes body line N == file line N.
    assert tag_line == 1
    # The markup and the <style> block must not leak into the JS we hand over.
    assert "<div" not in body
    assert "display: flex" not in body


def test_style_block_is_not_mistaken_for_script(tmp_path: Path) -> None:
    """sv.2 — a component with only a <style> block yields no blocks."""
    comp = tmp_path / "Styled.svelte"
    comp.write_text("<div>hi</div>\n<style>.a { color: red }</style>\n", encoding="utf-8")
    assert script_blocks(comp.read_text(encoding="utf-8")) == []


def test_module_context_script_is_included(tmp_path: Path) -> None:
    """sv.3 — `<script module>` is a second block, not a different element."""
    comp = tmp_path / "Two.svelte"
    comp.write_text(
        "<script module>\n  export const KEY = 1\n</script>\n"
        '<script lang="ts">\n  function go() {}\n</script>\n',
        encoding="utf-8",
    )
    blocks = script_blocks(comp.read_text(encoding="utf-8"))
    assert len(blocks) == 2
    assert blocks[0][1] == 1  # <script module> on line 1
    assert blocks[1][1] == 4  # <script lang="ts"> on line 4


def test_extracts_the_declarations_the_whole_file_loses(sample_component: Path) -> None:
    """sv.4 — the functions the JS parser drops are recovered."""
    result = run(sample_component)
    labels = {n["label"] for n in result["nodes"]}
    assert "increment" in labels
    assert "loadThings" in labels
    # The cross-file import stub is dropped: graphify's own svelte pass owns
    # imports, and a second opinion here is what produces stub collisions.
    assert "lib_other" not in {n["id"] for n in result["nodes"]}


@pytest.mark.skipif(
    __import__("importlib.util", fromlist=["util"]).find_spec("graphify") is None,
    reason="graphify lives in its own interpreter; not importable from the project venv",
)
def test_real_graphify_recovers_what_the_file_loses(sample_component: Path) -> None:
    """sv.4b — against the REAL extractor, when it is importable.

    The fake pins this module's logic; only this pins the premise the module
    exists for — that the whole `.svelte` file yields almost nothing while its
    script body yields the declarations.
    """
    from graphify.extract import extract  # type: ignore[import-not-found]

    whole = extract([sample_component], cache_root=sample_component.parents[2], parallel=False)
    whole_own = [n for n in whole["nodes"] if str(sample_component) in (n.get("source_file") or "")]
    rescued = extract_svelte_scripts([sample_component], root=sample_component.parents[2])
    assert len(rescued["nodes"]) > len(whole_own)
    assert "increment" in {n["label"] for n in rescued["nodes"]}


def test_nodes_are_attributed_to_the_svelte_file(sample_component: Path) -> None:
    """sv.5 — source_file is the component, never the temporary .ts file.

    A node attributed to a temp path is worse than a missing node: build_merge
    keys replacement on source_file, so it would claim a file that does not
    exist and could never be refreshed.
    """
    result = run(sample_component)
    assert result["nodes"], "expected nodes"
    for node in result["nodes"]:
        assert node["source_file"] == "src/components/Widget.svelte"
        assert ".ts" not in node["source_file"]


def test_node_ids_match_graphify_s_own_convention(sample_component: Path) -> None:
    """sv.6 — ids share the prefix graphify derives from the .svelte path.

    They must, or the rescued declarations land beside the file node instead of
    under it and every existing edge misses them.
    """
    result = run(sample_component)
    ids = {n["id"] for n in result["nodes"]}
    assert any(i.startswith("components_widget") for i in ids), sorted(ids)[:5]


def test_line_numbers_point_into_the_svelte_file(sample_component: Path) -> None:
    """sv.7 — source_location is offset by where the script block starts.

    Un-offset lines would point at the wrong line of the real file, which is
    worse than no line at all: a citation that looks right and is not.
    """
    result = run(sample_component)
    by_label = {n["label"]: n for n in result["nodes"]}
    assert by_label["increment"]["source_location"] == "L5"
    assert by_label["loadThings"]["source_location"] == "L9"


def test_edges_only_reference_nodes_that_were_kept(sample_component: Path) -> None:
    """sv.8 — no edge may dangle; build_merge would drop it silently.

    The component's own file node is a legitimate endpoint even though this
    fragment does not contain it: graphify's svelte pass contributes it under
    the same id, correctly labelled `Widget.svelte` rather than the staged
    `Widget.ts`, which is why this module does not emit it.
    """
    result = run(sample_component)
    ids = {n["id"] for n in result["nodes"]} | {"components_widget"}
    for edge in result["edges"]:
        assert edge["source"] in ids, edge
        assert edge["target"] in ids, edge


def test_the_file_node_is_left_to_graphify(sample_component: Path) -> None:
    """sv.10 — emitting it would relabel the component after the staged file."""
    result = run(sample_component)
    assert "components_widget" not in {n["id"] for n in result["nodes"]}
    assert not any(str(n.get("label", "")).endswith(".ts") for n in result["nodes"])


def test_returns_the_standard_zero_token_shape(sample_component: Path) -> None:
    """sv.9 — same contract as graphify_docs_extract, and free."""
    result = run(sample_component)
    assert set(result) >= {"nodes", "edges", "hyperedges", "input_tokens", "output_tokens"}
    assert result["input_tokens"] == 0
    assert result["output_tokens"] == 0
