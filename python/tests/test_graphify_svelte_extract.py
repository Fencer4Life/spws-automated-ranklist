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
import tempfile
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))

from graphify_svelte_extract import (  # noqa: E402
    PREMISE_SAMPLE,
    check_premise,
    extract_svelte_scripts,
    script_blocks,
)

# The premise check's own component (sv.4b), so the fake and the real
# extractor are judged on the same file.
SAMPLE = PREMISE_SAMPLE


def graphify_source_file(path: Path, cache_root: Path) -> str:
    """graphify's own rule for `source_file` (graphifyy 0.8.47, `extract.py`, its
    relativize pass): an absolute path under the RESOLVED cache root becomes
    relative to it; any other path is kept. The path itself is not resolved, so
    under macOS's symlinked temporary folder the rewrite fails and the path stays
    absolute (ADR-119 G26)."""
    try:
        return path.relative_to(cache_root.resolve()).as_posix()
    except ValueError:
        return str(path)


def fake_js_extract(paths: list[Path], *, cache_root: Path) -> dict:
    """Stand in for graphify's JS extractor, in its output shape.

    graphify lives in its own isolated interpreter (`scripts/graphify-python.sh`
    resolves it) and is not importable from the project venv, so the logic this
    module actually owns — reattribution, line offsets, id prefixes, edge
    filtering — is tested against a fake rather than left untested. The real
    extractor is exercised by `test_real_graphify_recovers_what_the_file_loses`,
    which preflight runs under graphify's interpreter.

    The fake returns what graphify returns, as measured on 1 Nov 2026: a
    function's label carries brackets (`increment()`), the file node is labelled
    with the file's name, and `source_file` follows `graphify_source_file`. A
    fake with bare names and absolute paths hid three defects (G26).

    Deliberately emits a cross-file import stub too: dropping those is a
    behaviour worth pinning, not an implementation detail.
    """
    staged = paths[0]
    body = staged.read_text(encoding="utf-8")
    stem_prefix = f"{staged.parent.name}_{staged.stem}".lower()
    source_file = graphify_source_file(staged, cache_root)
    nodes: list[dict] = [
        {
            "id": stem_prefix,
            "label": staged.name,
            "file_type": "code",
            "source_file": source_file,
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
                "label": f"{name}()",
                "file_type": "code",
                "source_file": source_file,
                "source_location": f"L{lineno}",
            }
        )
        edges.append(
            {
                "source": stem_prefix,
                "target": node_id,
                "relation": "contains",
                "confidence": "EXTRACTED",
                "source_file": source_file,
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
            "source_file": source_file,
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
    assert "increment()" in labels
    assert "loadThings()" in labels
    # The cross-file import stub is dropped: graphify's own svelte pass owns
    # imports, and a second opinion here is what produces stub collisions.
    assert "lib_other" not in {n["id"] for n in result["nodes"]}


@pytest.mark.skipif(
    __import__("importlib.util", fromlist=["util"]).find_spec("graphify") is None,
    reason="graphify lives in its own interpreter; preflight runs this check there",
)
def test_real_graphify_recovers_what_the_file_loses() -> None:
    """sv.4b — against the REAL extractor, when it is importable.

    The fake pins this module's logic; only this pins the premise the module
    exists for — that the whole `.svelte` file yields almost nothing while its
    script body yields the declarations. graphify is never importable here, so
    preflight runs the same check under graphify's own interpreter
    (`scripts/graphify-python.sh scripts/graphify_svelte_extract.py
    --check-premise`, ADR-119 G24).
    """
    holds, message = check_premise()
    assert holds, message


def whole_file_loses_everything(paths: list[Path], *, cache_root: Path) -> dict:
    """What graphify's JS parser does to a whole `.svelte` file: the markup fails
    the parse at the top level and only the file node survives. A staged script
    body goes to the ordinary fake."""
    if paths[0].suffix != ".svelte":
        return fake_js_extract(paths, cache_root=cache_root)
    whole = paths[0]
    node = {
        "id": "components_widget",
        "label": whole.name,
        "source_file": graphify_source_file(whole, cache_root),
    }
    return {"nodes": [node], "edges": [], "hyperedges": [], "input_tokens": 0, "output_tokens": 0}


def test_premise_check_holds_when_the_whole_file_loses_the_declarations() -> None:
    """sv.4c — the check passes when the script body yields more than the whole file."""
    holds, message = check_premise(js_extract=whole_file_loses_everything)
    assert holds, message


def test_premise_check_fails_when_the_whole_file_keeps_them() -> None:
    """sv.4d — the check can fail: an extractor that read the whole file's
    declarations itself would leave this module nothing to rescue."""
    holds, message = check_premise(js_extract=fake_js_extract)
    assert not holds
    assert "no longer holds" in message


def test_check_premise_flag_exits_by_the_result(monkeypatch: pytest.MonkeyPatch) -> None:
    """sv.4e — `--check-premise` exits 1 when the premise fails, 0 when it holds;
    preflight's gate reads nothing else."""
    import graphify_svelte_extract as module

    monkeypatch.setattr(module, "check_premise", lambda: (False, "broken"))
    assert module.main(["--check-premise"]) == 1
    monkeypatch.setattr(module, "check_premise", lambda: (True, "fine"))
    assert module.main(["--check-premise"]) == 0


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
    assert by_label["increment()"]["source_location"] == "L5"
    assert by_label["loadThings()"]["source_location"] == "L9"


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


def test_rescue_does_not_depend_on_the_temporary_folders_path(
    sample_component: Path, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """sv.11 (ADR-119 G26) — graphify rewrites a staged path under the resolved
    cache root to a relative one. macOS's temporary folder sits behind a
    symlink, so there the rewrite failed and the staged path matched by
    accident; in a temporary folder with a real path (Linux, or a TMPDIR set to
    one) every node was dropped and the rescue returned nothing, silently.
    """
    real = (tmp_path / "real-tmp").resolve()
    real.mkdir()
    monkeypatch.setattr(tempfile, "tempdir", str(real))
    result = run(sample_component)
    assert {n["label"] for n in result["nodes"]} >= {"increment()", "loadThings()"}


def test_returns_the_standard_zero_token_shape(sample_component: Path) -> None:
    """sv.9 — same contract as graphify_docs_extract, and free."""
    result = run(sample_component)
    assert set(result) >= {"nodes", "edges", "hyperedges", "input_tokens", "output_tokens"}
    assert result["input_tokens"] == 0
    assert result["output_tokens"] == 0
