"""COH.01–04 — coherence gate 4: a migration change ships with a documentation change.

Gate 4 of ``scripts/check-coherence.sh`` diffed the working tree against
``origin/main``. On a push to ``main`` CI checks out the pushed commit, which
``origin/main`` already is, so the diff was empty and the gate never fired where
it mattered. It was also only a warning, and every static check is a hard gate
with zero findings (NFR-15). It now reads the range the push or pull request
brings (``COHERENCE_BASE``, which ``ci.yml`` passes) and fails the run.

Each case builds a throwaway repository that passes gates 1–3 trivially.
"""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "check-coherence.sh"
SPEC = "doc/Project Specification. SPWS Automated Ranklist System.md"


def _git(repo: Path, *args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=repo, check=True, capture_output=True, text=True
    ).stdout.strip()


def _commit(repo: Path, paths: list[str], message: str) -> str:
    for relative in paths:
        target = repo / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        _ = target.write_text(f"-- {message}\n")
    _ = _git(repo, "add", "-A")
    _ = _git(repo, "commit", "-q", "-m", message)
    return _git(repo, "rev-parse", "HEAD")


@pytest.fixture
def repo(tmp_path: Path) -> Path:
    """A clone of a bare `origin` holding one baseline commit on main."""
    origin = tmp_path / "origin.git"
    _ = subprocess.run(["git", "init", "-q", "--bare", "-b", "main", str(origin)], check=True)
    work = tmp_path / "work"
    work.mkdir()
    _ = _git(work, "init", "-q", "-b", "main")
    _ = _git(work, "config", "user.email", "test@example.invalid")
    _ = _git(work, "config", "user.name", "Test")
    _ = _git(work, "remote", "add", "origin", str(origin))
    (work / "scripts").mkdir()
    _ = shutil.copy(SCRIPT, work / "scripts" / "check-coherence.sh")
    _ = (work / "pyproject.toml").write_text('version = "1.0.0"\n')
    (work / "frontend").mkdir()
    _ = (work / "frontend" / "package.json").write_text('{"version": "1.0.0"}\n')
    (work / "doc" / "adr").mkdir(parents=True)
    _ = (work / "doc" / "adr" / "001-one.md").write_text("# ADR-001: One\n")
    _ = (work / SPEC).write_text(
        "| [ADR-001](adr/001-one.md) | One |\n\npgTAP total: 0 assertions\n"
    )
    _ = _commit(work, ["supabase/migrations/20260101000001_base.sql"], "baseline")
    _ = _git(work, "push", "-q", "origin", "main")
    return work


def _check(repo: Path, base: str | None = None) -> subprocess.CompletedProcess[str]:
    env = {k: v for k, v in os.environ.items() if k not in ("COHERENCE_BASE", "GITHUB_ACTIONS")}
    if base is not None:
        env["COHERENCE_BASE"] = base
    return subprocess.run(
        ["bash", "scripts/check-coherence.sh"],
        cwd=repo,
        env=env,
        capture_output=True,
        text=True,
        timeout=60,
    )


def _push(repo: Path) -> None:
    """CI on a push to main: origin/main is the pushed commit itself."""
    _ = _git(repo, "push", "-q", "origin", "main")
    _ = _git(repo, "fetch", "-q", "origin")


def test_COH_01_a_main_push_bringing_a_bare_migration_fails(repo: Path) -> None:
    before = _git(repo, "rev-parse", "HEAD")
    _ = _commit(repo, ["supabase/migrations/20260102000001_new.sql"], "migration only")
    _push(repo)
    result = _check(repo, base=before)
    assert result.returncode == 1, result.stdout
    assert "20260102000001_new.sql" in result.stdout


def test_COH_02_a_push_whose_later_commit_documents_the_migration_passes(repo: Path) -> None:
    before = _git(repo, "rev-parse", "HEAD")
    _ = _commit(repo, ["supabase/migrations/20260102000001_new.sql"], "migration")
    _ = _commit(repo, ["doc/handbook/data/model.html"], "its documentation")
    _push(repo)
    result = _check(repo, base=before)
    assert result.returncode == 0, result.stdout


def test_COH_03_a_branch_with_a_bare_migration_fails_without_a_given_base(repo: Path) -> None:
    """Preflight on a work branch: the range is the branch's fork point from origin/main."""
    _ = _git(repo, "switch", "-q", "-c", "work")
    _ = _commit(repo, ["supabase/migrations/20260102000001_new.sql"], "migration only")
    result = _check(repo)
    assert result.returncode == 1, result.stdout


@pytest.mark.parametrize("base", ["0" * 40, "f" * 40])
def test_COH_04_an_unusable_base_still_checks_the_last_commit(repo: Path, base: str) -> None:
    """A new branch pushes `before` as zeros; a rewritten history leaves it unknown."""
    _ = _commit(repo, ["supabase/migrations/20260102000001_new.sql"], "migration only")
    _push(repo)
    result = _check(repo, base=base)
    assert result.returncode == 1, result.stdout


def test_COH_05_ci_passes_the_range_of_the_push_or_pull_request() -> None:
    ci = yaml.safe_load((ROOT / ".github" / "workflows" / "ci.yml").read_text())
    (step,) = [
        s for s in ci["jobs"]["coherence"]["steps"] if "check-coherence.sh" in str(s.get("run"))
    ]
    base = str((step.get("env") or {}).get("COHERENCE_BASE", ""))
    assert "github.event.pull_request.base.sha" in base
    assert "github.event.before" in base
