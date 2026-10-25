"""The documentation search index must be able to shrink, not only grow.

`tools/docs-search/ingest.py` writes chunks with a deterministic id derived from
the document's path and its ordinal within that document, and posts them as an
upsert. That alone can never remove anything: shortening a page strands its
surplus tail chunks, and deleting or renaming a page leaves every one of its
chunks in the index under a path that no longer exists on disk. A search then
returns superseded prose that reads exactly like current documentation.

These tests pin the pruning half of the rebuild: what the index holds minus what
the corpus produced is precisely what must be deleted.
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
INGEST = ROOT / "tools/docs-search/ingest.py"


@pytest.fixture(scope="module")
def ingest():
    spec = importlib.util.spec_from_file_location("docs_search_ingest", INGEST)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    # `dataclasses` resolves a field's annotations through
    # `sys.modules[cls.__module__]`, so a module executed outside the import
    # system has to be registered before its `@dataclass` bodies run.
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def test_chunk_id_is_deterministic_per_path_and_order(ingest) -> None:
    assert ingest.chunk_id("doc/plans/a.html", 3) == ingest.chunk_id("doc/plans/a.html", 3)
    assert ingest.chunk_id("doc/plans/a.html", 3) != ingest.chunk_id("doc/plans/a.html", 4)
    assert ingest.chunk_id("doc/plans/a.html", 3) != ingest.chunk_id("doc/plans/b.html", 3)


def test_unchanged_corpus_prunes_nothing(ingest) -> None:
    live = {("doc/plans/a.html", 0), ("doc/plans/a.html", 1)}
    assert ingest.stale_ids(sorted(live), live) == []


def test_shortened_document_loses_its_tail_chunks(ingest) -> None:
    indexed = [("doc/plans/a.html", i) for i in range(4)]
    live = {("doc/plans/a.html", 0), ("doc/plans/a.html", 1)}

    assert ingest.stale_ids(indexed, live) == [
        ingest.chunk_id("doc/plans/a.html", 2),
        ingest.chunk_id("doc/plans/a.html", 3),
    ]


def test_deleted_or_renamed_document_loses_every_chunk(ingest) -> None:
    indexed = [
        ("doc/plans/old-name.html", 0),
        ("doc/plans/old-name.html", 1),
        ("doc/plans/kept.html", 0),
    ]
    live = {("doc/plans/new-name.html", 0), ("doc/plans/kept.html", 0)}

    assert ingest.stale_ids(indexed, live) == [
        ingest.chunk_id("doc/plans/old-name.html", 0),
        ingest.chunk_id("doc/plans/old-name.html", 1),
    ]


def test_stale_paths_reports_the_documents_that_left_the_corpus(ingest) -> None:
    """The run has to be able to say which pages it dropped, not just how many.

    A silent count is how a wrongly-excluded directory gets mistaken for a
    tidy-up.
    """
    indexed = [
        ("doc/plans/gone.html", 0),
        ("doc/plans/shortened.html", 0),
        ("doc/plans/shortened.html", 1),
    ]
    live = {("doc/plans/shortened.html", 0)}

    assert ingest.stale_paths(indexed, live) == [
        "doc/plans/gone.html",
        "doc/plans/shortened.html",
    ]


def test_a_page_only_another_worktree_holds_is_kept(ingest) -> None:
    """The index is shared by every worktree of the repository. A page a
    parallel session wrote in its own worktree is not in this checkout, and
    pruning it deleted that session's work from search (25 Oct 2026: two
    frontend-toolchain plan pages)."""
    indexed = [
        ("doc/plans/theirs.html", 0),
        ("doc/plans/theirs.html", 1),
        ("doc/plans/gone.html", 0),
    ]
    live = set()
    held = {"doc/plans/theirs.html"}

    assert ingest.stale_ids(indexed, live, held) == [ingest.chunk_id("doc/plans/gone.html", 0)]
    assert ingest.stale_paths(indexed, live, held) == ["doc/plans/gone.html"]


def test_a_page_this_checkout_holds_still_loses_its_tail(ingest) -> None:
    """Another worktree holding the same page does not protect the tail of the
    version this run produced: the run's own corpus decides that page."""
    indexed = [("doc/plans/shared.html", i) for i in range(3)]
    live = {("doc/plans/shared.html", 0)}
    held = {"doc/plans/shared.html"}

    assert ingest.stale_ids(indexed, live, held) == [
        ingest.chunk_id("doc/plans/shared.html", 1),
        ingest.chunk_id("doc/plans/shared.html", 2),
    ]


def test_paths_held_by_other_worktrees(ingest, tmp_path: Path) -> None:
    """Only a page that exists as a file in another worktree counts."""
    here, there = tmp_path / "here", tmp_path / "there"
    (there / "doc/plans").mkdir(parents=True)
    (there / "doc/plans/theirs.html").write_text("x")
    here.mkdir()

    held = ingest.paths_in_other_worktrees(
        ["doc/plans/theirs.html", "doc/plans/gone.html"], [here, there], here=here
    )
    assert held == {"doc/plans/theirs.html"}
