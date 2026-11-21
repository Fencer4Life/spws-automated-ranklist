"""WSGATE.01–06 — preflight's whitespace gate sees every change the branch would carry.

doc/plans/i24-preflight-checks-uncommitted-whitespace-2026-11-21.html (I24, 21 Nov 2026).
The gate ran `git diff --check origin/main...HEAD`, which sees commits only, and
preflight runs before the commit. A blank line at the end of a staged or new file
passed it twice on 21 Nov and was caught only by the integrate script's check.
Each test builds a throwaway repository and runs the gate's script inside it.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/check-diff-whitespace.sh"
PREFLIGHT = (ROOT / "scripts/preflight.sh").read_text(encoding="utf-8")


def _git(repo: Path, *args: str) -> None:
    _ = subprocess.run(["git", "-C", str(repo), *args], check=True, capture_output=True, text=True)


def _repo(tmp_path: Path) -> Path:
    """A repository with `main` holding one clean file, and a work branch on it."""
    repo = tmp_path / "repo"
    repo.mkdir()
    _git(repo, "init", "-q", "-b", "main")
    _git(repo, "config", "user.email", "gate@example.invalid")
    _git(repo, "config", "user.name", "gate")
    _git(repo, "config", "commit.gpgsign", "false")
    _ = (repo / "a.ts").write_text("x\n", encoding="utf-8")
    _ = (repo / ".gitignore").write_text("ignored/\n", encoding="utf-8")
    _git(repo, "add", "a.ts", ".gitignore")
    _git(repo, "commit", "-q", "-m", "base")
    _git(repo, "switch", "-q", "-c", "work")
    return repo


def _gate(repo: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["bash", str(SCRIPT), "main"], cwd=repo, capture_output=True, text=True)


def _fails_naming(r: subprocess.CompletedProcess[str], name: str) -> None:
    """Exit 1 means problems were found; anything else (127, 2) is the gate breaking."""
    assert r.returncode == 1, (r.returncode, r.stdout + r.stderr)
    assert name in r.stdout + r.stderr


def test_WSGATE_01_an_unstaged_blank_line_at_eof_fails(tmp_path: Path) -> None:
    repo = _repo(tmp_path)
    _ = (repo / "a.ts").write_text("x\ny\n\n", encoding="utf-8")
    _fails_naming(_gate(repo), "a.ts")


def test_WSGATE_02_a_staged_blank_line_at_eof_fails(tmp_path: Path) -> None:
    repo = _repo(tmp_path)
    _ = (repo / "a.ts").write_text("x\ny\n\n", encoding="utf-8")
    _git(repo, "add", "a.ts")
    _fails_naming(_gate(repo), "a.ts")


def test_WSGATE_02_a_staged_line_still_fails_when_the_file_is_fixed_but_not_restaged(
    tmp_path: Path,
) -> None:
    """The commit would carry the staged content, not the fixed file."""
    repo = _repo(tmp_path)
    _ = (repo / "a.ts").write_text("x\ny\n\n", encoding="utf-8")
    _git(repo, "add", "a.ts")
    _ = (repo / "a.ts").write_text("x\ny\n", encoding="utf-8")
    _fails_naming(_gate(repo), "a.ts")


def test_WSGATE_03_a_committed_blank_line_at_eof_fails(tmp_path: Path) -> None:
    repo = _repo(tmp_path)
    _ = (repo / "a.ts").write_text("x\ny\n\n", encoding="utf-8")
    _git(repo, "commit", "-q", "-am", "work")
    _fails_naming(_gate(repo), "a.ts")


def test_WSGATE_03_a_committed_line_still_fails_when_only_the_worktree_is_fixed(
    tmp_path: Path,
) -> None:
    """The integrate script merges the commit, not the worktree."""
    repo = _repo(tmp_path)
    _ = (repo / "a.ts").write_text("x\ny\n\n", encoding="utf-8")
    _git(repo, "commit", "-q", "-am", "work")
    _ = (repo / "a.ts").write_text("x\ny\n", encoding="utf-8")
    _fails_naming(_gate(repo), "a.ts")


def test_WSGATE_04_a_new_untracked_file_fails_and_is_named(tmp_path: Path) -> None:
    repo = _repo(tmp_path)
    _ = (repo / "new.ts").write_text("z\n\n", encoding="utf-8")
    _fails_naming(_gate(repo), "new.ts")


def test_WSGATE_05_a_clean_worktree_with_new_files_passes(tmp_path: Path) -> None:
    """A clean new file differs from nothing and must still pass: `git diff --no-index`
    exits 1 for any difference, so the gate judges by the problems it prints."""
    repo = _repo(tmp_path)
    _ = (repo / "a.ts").write_text("x\ny\n", encoding="utf-8")
    _ = (repo / "new.ts").write_text("z\n", encoding="utf-8")
    _ = (repo / "staged.ts").write_text("s\n", encoding="utf-8")
    _git(repo, "add", "staged.ts")
    r = _gate(repo)
    assert r.returncode == 0, r.stdout + r.stderr


def test_WSGATE_05_an_ignored_file_is_not_checked(tmp_path: Path) -> None:
    repo = _repo(tmp_path)
    (repo / "ignored").mkdir()
    _ = (repo / "ignored/junk.ts").write_text("z\n\n", encoding="utf-8")
    r = _gate(repo)
    assert r.returncode == 0, r.stdout + r.stderr


def test_WSGATE_06_preflight_runs_the_script_as_its_integrate_gate() -> None:
    line = next(ln for ln in PREFLIGHT.splitlines() if 'gate "git diff --check (integrate)"' in ln)
    assert "scripts/check-diff-whitespace.sh" in line
    assert "origin/main...HEAD" not in line
