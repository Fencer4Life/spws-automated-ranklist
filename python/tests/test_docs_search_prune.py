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
