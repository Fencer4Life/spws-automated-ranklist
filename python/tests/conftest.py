"""Fixtures shared by every test under python/tests."""

from __future__ import annotations

from pathlib import Path

import pytest


@pytest.fixture(autouse=True)
def staging_writes_stay_in_the_test(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """ADR-119 G25: the 3-way diff and the staging report fall back to the
    repository's own doc/staging when they are given no folder, so a test that
    gave none rewrote a committed file. Both fallbacks now point at the test's
    own temporary folder; a test that names a folder is unaffected (P3.D13)."""
    from python.pipeline import md_writer, three_way_diff

    monkeypatch.setattr(three_way_diff, "_project_root", lambda: tmp_path)
    monkeypatch.setattr(md_writer, "DEFAULT_STAGING_DIR", tmp_path / "doc" / "staging")
