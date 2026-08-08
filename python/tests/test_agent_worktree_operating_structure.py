"""Acceptance tests for the Codex/Claude Git worktree operating structure."""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _run(
    *args: str,
    cwd: Path,
    input_text: str | None = None,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        cwd=cwd,
        input=input_text,
        text=True,
        capture_output=True,
        check=check,
        env={**os.environ, "GIT_AUTHOR_NAME": "Test", "GIT_AUTHOR_EMAIL": "test@example.org"},
    )


def _git(cwd: Path, *args: str) -> str:
    return _run("git", *args, cwd=cwd).stdout.strip()


def _repository(tmp_path: Path) -> tuple[Path, Path]:
    remote = tmp_path / "origin.git"
    seed = tmp_path / "seed"
    integration = tmp_path / "SPWSranklist-integration"

    _run("git", "init", "--bare", str(remote), cwd=tmp_path)
    _run("git", "init", "-b", "main", str(seed), cwd=tmp_path)
    _git(seed, "config", "user.name", "Test")
    _git(seed, "config", "user.email", "test@example.org")
    (seed / "README.md").write_text("seed\n")
    _git(seed, "add", "README.md")
    _git(seed, "commit", "-m", "seed")
    _git(seed, "remote", "add", "origin", str(remote))
    _git(seed, "push", "-u", "origin", "main")
    _run("git", "--git-dir", str(remote), "symbolic-ref", "HEAD", "refs/heads/main", cwd=tmp_path)
    _run("git", "clone", str(remote), str(integration), cwd=tmp_path)
    _git(integration, "config", "user.name", "Test")
    _git(integration, "config", "user.email", "test@example.org")

    for relative in (
        ".githooks/pre-push",
        "scripts/install-agent-worktree-guards.sh",
        "scripts/start-agent-worktree.sh",
        "scripts/integrate-agent-branch.sh",
    ):
        source = ROOT / relative
        target = integration / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    _git(integration, "add", ".githooks", "scripts")
    _git(integration, "commit", "-m", "install operating structure")
    _git(integration, "push", "origin", "main")
    return integration, remote


def test_install_registers_integration_checkout_and_hooks(tmp_path: Path):
    integration, _ = _repository(tmp_path)

    result = _run(
        "bash",
        "scripts/install-agent-worktree-guards.sh",
        "--integration",
        cwd=integration,
    )

    assert "Integration checkout registered" in result.stdout
    assert _git(integration, "config", "--get", "core.hooksPath") == ".githooks"
    assert _git(integration, "config", "--get", "spws.integrationWorktree") == str(
        integration.resolve()
    )


def test_install_refuses_dirty_integration_checkout(tmp_path: Path):
    integration, _ = _repository(tmp_path)
    (integration / "unowned.txt").write_text("dirty\n")

    result = _run(
        "bash",
        "scripts/install-agent-worktree-guards.sh",
        "--integration",
        cwd=integration,
        check=False,
    )

    assert result.returncode != 0
    assert "must be clean" in result.stderr


def test_start_creates_named_sibling_agent_branch_from_origin_main(tmp_path: Path):
    integration, _ = _repository(tmp_path)
    _run("bash", "scripts/install-agent-worktree-guards.sh", "--integration", cwd=integration)

    result = _run(
        "bash",
        "scripts/start-agent-worktree.sh",
        "codex",
        "sample-task",
        cwd=integration,
    )

    worker = tmp_path / "SPWSranklist-codex-sample-task"
    assert worker.is_dir()
    assert _git(worker, "branch", "--show-current") == "codex/sample-task"
    assert _git(worker, "rev-parse", "HEAD") == _git(integration, "rev-parse", "origin/main")
    assert str(worker) in result.stdout


def test_pre_push_blocks_worker_to_main_but_allows_own_branch(tmp_path: Path):
    integration, _ = _repository(tmp_path)
    _run("bash", "scripts/install-agent-worktree-guards.sh", "--integration", cwd=integration)
    worktree_root = tmp_path / "worktrees"
    _run(
        "bash",
        "scripts/start-agent-worktree.sh",
        "claude",
        "sample-task",
        "--worktree-root",
        str(worktree_root),
        cwd=integration,
    )
    worker = worktree_root / "SPWSranklist-claude-sample-task"
    sha = _git(worker, "rev-parse", "HEAD")
    zero = "0" * 40

    allowed = _run(
        "bash",
        ".githooks/pre-push",
        "origin",
        "unused",
        cwd=worker,
        input_text=f"refs/heads/claude/sample-task {sha} refs/heads/claude/sample-task {zero}\n",
        check=False,
    )
    blocked = _run(
        "bash",
        ".githooks/pre-push",
        "origin",
        "unused",
        cwd=worker,
        input_text=f"refs/heads/claude/sample-task {sha} refs/heads/main {zero}\n",
        check=False,
    )

    assert allowed.returncode == 0
    assert blocked.returncode != 0
    assert "Only the registered integration checkout may push main" in blocked.stderr


def test_dedicated_integration_branch_can_push_only_its_current_head(tmp_path: Path):
    integration, _ = _repository(tmp_path)
    _git(integration, "branch", "-m", "integration/main")
    _run("bash", "scripts/install-agent-worktree-guards.sh", "--integration", cwd=integration)
    sha = _git(integration, "rev-parse", "HEAD")
    zero = "0" * 40

    allowed = _run(
        "bash",
        ".githooks/pre-push",
        "origin",
        "unused",
        cwd=integration,
        input_text=f"refs/heads/integration/main {sha} refs/heads/main {zero}\n",
        check=False,
    )
    stale_main = _run(
        "bash",
        ".githooks/pre-push",
        "origin",
        "unused",
        cwd=integration,
        input_text=f"refs/heads/main {sha} refs/heads/main {zero}\n",
        check=False,
    )

    assert allowed.returncode == 0
    assert stale_main.returncode != 0
    assert "current integration branch" in stale_main.stderr


def test_integrate_merges_one_clean_worker_branch_without_pushing(tmp_path: Path):
    integration, remote = _repository(tmp_path)
    _run("bash", "scripts/install-agent-worktree-guards.sh", "--integration", cwd=integration)
    worktree_root = tmp_path / "worktrees"
    _run(
        "bash",
        "scripts/start-agent-worktree.sh",
        "codex",
        "sample-task",
        "--worktree-root",
        str(worktree_root),
        cwd=integration,
    )
    worker = worktree_root / "SPWSranklist-codex-sample-task"
    (worker / "task.txt").write_text("isolated\n")
    _git(worker, "add", "task.txt")
    _git(worker, "commit", "-m", "task")
    remote_before = _run(
        "git", "--git-dir", str(remote), "rev-parse", "refs/heads/main", cwd=tmp_path
    ).stdout.strip()

    result = _run(
        "bash",
        "scripts/integrate-agent-branch.sh",
        "codex/sample-task",
        cwd=integration,
    )

    assert (integration / "task.txt").read_text() == "isolated\n"
    assert len(_git(integration, "show", "-s", "--format=%P", "HEAD").split()) == 2
    remote_after = _run(
        "git", "--git-dir", str(remote), "rev-parse", "refs/heads/main", cwd=tmp_path
    ).stdout.strip()
    assert remote_after == remote_before
    assert "not pushed" in result.stdout.lower()


def test_integrate_refuses_dirty_integration_checkout(tmp_path: Path):
    integration, _ = _repository(tmp_path)
    _run("bash", "scripts/install-agent-worktree-guards.sh", "--integration", cwd=integration)
    (integration / "dirty.txt").write_text("do not absorb\n")

    result = _run(
        "bash",
        "scripts/integrate-agent-branch.sh",
        "codex/sample-task",
        cwd=integration,
        check=False,
    )

    assert result.returncode != 0
    assert "integration checkout is not clean" in result.stderr.lower()
