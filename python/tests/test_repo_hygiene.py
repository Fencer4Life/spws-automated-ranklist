"""REPO.01 — dependency folders are installed, never tracked.

G1 A on doc/plans/evf-closed-events-differences-2026-10-25.html (25 Oct 2026): 4,577
files of frontend/node_modules were tracked (added in 3b029e44, 02550d90 and
323d685e) although .gitignore lists node_modules/. Every new worktree checked out
that partial copy, without @supabase/supabase-js, so Vitest and svelte-check failed
there, and scripts/session_start.py could not link the shared folder in its place,
because the path already existed. CI and the release install with `npm ci`.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_REPO_01_no_dependency_folder_is_tracked():
    tracked = subprocess.run(
        ["git", "ls-files", "-z"], cwd=ROOT, capture_output=True, text=True, check=True
    ).stdout.split("\0")
    offenders = [
        path
        for path in tracked
        if "node_modules" in Path(path).parts or Path(path).parts[:1] == (".venv",)
    ]
    assert offenders == [], f"{len(offenders)} tracked, e.g. {offenders[:3]}"
