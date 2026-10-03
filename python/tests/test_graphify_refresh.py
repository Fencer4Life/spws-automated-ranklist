"""Tests for the code-file selection of scripts/graphify_refresh.py.

The incremental refresh extracts only the changed code files, and graphify's
extract() then emits import STUBS carrying the imported file's path, which
build_merge treats as that file's whole node set. On 2026-10-03 that left
Sidebar.svelte, CalendarView.svelte and RanklistTable.svelte at one node each
after a 182-commit catch-up. `--full-code` re-extracts every code file, so no
stub can be a file's only claim. The selection is pure and tested here; the
graphify calls themselves need graphify's own interpreter.
"""

from __future__ import annotations

from scripts.graphify_refresh import absent_sources, code_files_to_extract, shrunk_files


def test_incremental_extracts_only_the_changed_files():
    """GR.01 — without --full-code the selection is the changed set, unchanged."""
    changed = ["frontend/src/App.svelte"]
    every = ["frontend/src/App.svelte", "frontend/src/lib/types.ts"]
    assert code_files_to_extract(full_code=False, changed=changed, every=every) == changed


def test_full_code_extracts_every_code_file():
    """GR.02 — --full-code selects every code file, so imports cannot stub them."""
    changed = ["frontend/src/App.svelte"]
    every = ["frontend/src/App.svelte", "frontend/src/lib/types.ts"]
    assert code_files_to_extract(full_code=True, changed=changed, every=every) == every


def test_full_code_keeps_a_changed_file_detect_did_not_list():
    """GR.03 — a changed file missing from the full scan is still extracted, once."""
    changed = ["scripts/new_tool.py", "frontend/src/App.svelte"]
    every = ["frontend/src/App.svelte"]
    assert code_files_to_extract(full_code=True, changed=changed, every=every) == [
        "frontend/src/App.svelte",
        "scripts/new_tool.py",
    ]


def test_absent_sources_are_the_files_this_tree_does_not_have():
    """GR.04 — a graph seeded from another checkout names files this tree lacks; they are pruned."""
    on_disk = {"frontend/src/App.svelte", "doc/adr/102.md"}
    sources = {"frontend/src/App.svelte", "doc/adr/102.md", "doc/plans/local-only.html", "", None}
    assert absent_sources(sources, exists=on_disk.__contains__) == {"doc/plans/local-only.html"}


def test_shrunk_files_lists_files_still_on_disk_that_lost_nodes():
    """GR.05 — a full-code shrink is reported per file, never hidden behind a net number."""
    old = {"a.ts": 48, "b.ts": 5, "gone.ts": 9}
    new = {"a.ts": 1, "b.ts": 7}
    on_disk = {"a.ts", "b.ts"}
    assert shrunk_files(old, new, exists=on_disk.__contains__) == [("a.ts", 48, 1)]
