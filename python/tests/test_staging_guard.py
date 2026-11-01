"""P3.D13 (ADR-119 G25): no test writes the repository's doc/staging.

The 3-way diff (`three_way_diff.write_diff`) and the staging report
(`md_writer.write_for_event`, `write_reconcile`) fall back to the repository's own
doc/staging when they are given no folder. A unit test that gave none rewrote the
committed doc/staging/PPW4-SPWS-2025-2026.diff.md on every run, preflight's
included. The autouse fixture in conftest.py points both fallbacks at each test's
own temporary folder.
"""

from __future__ import annotations

from pathlib import Path

REPO_STAGING = Path(__file__).resolve().parents[2] / "doc" / "staging"


def test_no_test_writes_the_repositorys_staging_folder(tmp_path):
    """P3.D13"""
    from python.pipeline import md_writer, three_way_diff

    # Checked before anything is written, so a failure leaves the repository alone.
    assert three_way_diff._project_root() == tmp_path
    assert md_writer.DEFAULT_STAGING_DIR.resolve().is_relative_to(tmp_path)

    diff = three_way_diff.write_diff("P3-D13-GUARD", "diff")
    report = md_writer.write_for_event("P3-D13-GUARD", "report")
    assert report is not None
    for written in (diff, Path(report)):
        assert written.resolve().is_relative_to(tmp_path)
    assert not list(REPO_STAGING.glob("P3-D13-GUARD*"))
