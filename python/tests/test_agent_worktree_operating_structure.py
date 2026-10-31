"""Acceptance tests for the Codex/Claude Git worktree operating structure.

NAMING.01–06 (plan doc/plans/branch-names-and-merge-messages-2026-10-31.html,
signed 31 Oct 2026, B1–B3 A, N1 A): a worker branch is named after what it
changes and described in git's branch description; scripts/branch_description.py
checks both, preflight and the integrate script run that one check, the merge
on main carries the description and a Branch: line, release.yml names its run
after the merge title, and Claude's and Codex's release skills teach it alike.
"""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[2]

GOOD_DESCRIPTION = (
    "Sample file lands where the task wants it\n"
    "\n"
    "The task needs a file in the root of the checkout. This change adds it, so the\n"
    "next step can read it.\n"
    "\n"
    "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\n"
)


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
        "scripts/branch_description.py",
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


def _worker(tmp_path: Path, integration: Path, agent: str, task: str) -> Path:
    """A worker worktree on <agent>/<task> with one commit, not yet described."""
    worktree_root = tmp_path / "worktrees"
    _run(
        "bash",
        "scripts/start-agent-worktree.sh",
        agent,
        task,
        "--worktree-root",
        str(worktree_root),
        cwd=integration,
    )
    worker = worktree_root / f"SPWSranklist-{agent}-{task}"
    (worker / "task.txt").write_text("isolated\n")
    _git(worker, "add", "task.txt")
    _git(worker, "commit", "-m", "task")
    return worker


def _describe(repository: Path, branch: str, description: str) -> None:
    # What `git branch --edit-description` stores; the config is shared by worktrees.
    _git(repository, "config", f"branch.{branch}.description", description)


def test_integrate_merges_one_clean_worker_branch_without_pushing(tmp_path: Path):
    integration, remote = _repository(tmp_path)
    _run("bash", "scripts/install-agent-worktree-guards.sh", "--integration", cwd=integration)
    _worker(tmp_path, integration, "codex", "add-sample-file")
    _describe(integration, "codex/add-sample-file", GOOD_DESCRIPTION)
    remote_before = _run(
        "git", "--git-dir", str(remote), "rev-parse", "refs/heads/main", cwd=tmp_path
    ).stdout.strip()

    result = _run(
        "bash",
        "scripts/integrate-agent-branch.sh",
        "codex/add-sample-file",
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


def test_NAMING_01_the_merge_carries_the_branch_description_and_branch_line(tmp_path: Path):
    integration, _ = _repository(tmp_path)
    _run("bash", "scripts/install-agent-worktree-guards.sh", "--integration", cwd=integration)
    _worker(tmp_path, integration, "claude", "add-sample-file")
    _describe(integration, "claude/add-sample-file", GOOD_DESCRIPTION)

    _run("bash", "scripts/integrate-agent-branch.sh", "claude/add-sample-file", cwd=integration)

    assert _git(integration, "show", "-s", "--format=%s", "HEAD") == (
        "Sample file lands where the task wants it"
    )
    body = _git(integration, "show", "-s", "--format=%b", "HEAD")
    assert "The task needs a file in the root of the checkout." in body
    trailers = _run(
        "git", "interpret-trailers", "--parse", cwd=integration, input_text=body + "\n"
    ).stdout
    assert "Branch: claude/add-sample-file" in trailers
    assert "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" in trailers


@pytest.mark.parametrize(
    ("description", "reason"),
    [
        (None, "no branch description"),
        ("T" * 73 + "\n\nIt does one thing. It does it well.\n", "longer than 72"),
        ("Merge branch 'x'\n\nIt does one thing. It does it well.\n", "starts with"),
        ("Adds a sample file\n\nIt adds a file.\n", "two sentences"),
    ],
)
def test_NAMING_02_integrate_refuses_a_missing_or_weak_description(
    tmp_path: Path, description: str | None, reason: str
):
    integration, _ = _repository(tmp_path)
    _run("bash", "scripts/install-agent-worktree-guards.sh", "--integration", cwd=integration)
    _worker(tmp_path, integration, "codex", "add-sample-file")
    if description is not None:
        _describe(integration, "codex/add-sample-file", description)
    head_before = _git(integration, "rev-parse", "HEAD")

    result = _run(
        "bash",
        "scripts/integrate-agent-branch.sh",
        "codex/add-sample-file",
        cwd=integration,
        check=False,
    )

    assert result.returncode != 0
    assert reason in result.stderr
    assert _git(integration, "rev-parse", "HEAD") == head_before


@pytest.mark.parametrize(
    ("task", "reason"),
    [
        ("session-20261031-1059-3818cd", "session"),
        ("fix-2026-10-31-letter", "date"),
        ("fix-letter", "three words"),
    ],
)
def test_NAMING_03_integrate_refuses_a_session_date_or_two_word_branch_name(
    tmp_path: Path, task: str, reason: str
):
    integration, _ = _repository(tmp_path)
    _run("bash", "scripts/install-agent-worktree-guards.sh", "--integration", cwd=integration)
    _worker(tmp_path, integration, "claude", task)
    _describe(integration, f"claude/{task}", GOOD_DESCRIPTION)
    head_before = _git(integration, "rev-parse", "HEAD")

    result = _run(
        "bash",
        "scripts/integrate-agent-branch.sh",
        f"claude/{task}",
        cwd=integration,
        check=False,
    )

    assert result.returncode != 0
    assert reason in result.stderr
    assert _git(integration, "rev-parse", "HEAD") == head_before


def test_NAMING_04_the_preflight_check_prints_the_names_the_push_will_carry(tmp_path: Path):
    integration, _ = _repository(tmp_path)
    _run("bash", "scripts/install-agent-worktree-guards.sh", "--integration", cwd=integration)
    worker = _worker(tmp_path, integration, "claude", "add-sample-file")
    check = ("python3", "scripts/branch_description.py", "check")

    undescribed = _run(*check, cwd=worker, check=False)
    _describe(integration, "claude/add-sample-file", GOOD_DESCRIPTION)
    described = _run(*check, cwd=worker, check=False)

    assert undescribed.returncode != 0
    assert "no branch description" in undescribed.stderr
    assert described.returncode == 0, described.stderr
    title = "Sample file lands where the task wants it"
    assert f"Merge title:  {title}" in described.stdout
    assert f"CI run:       {title}" in described.stdout
    assert f"Release run:  Release · {title}" in described.stdout
    # Preflight runs this same check on the current branch.
    preflight = (ROOT / "scripts" / "preflight.sh").read_text(encoding="utf-8")
    assert "scripts/branch_description.py check" in preflight


def test_NAMING_05_the_release_run_is_named_after_the_merge_title():
    spec = yaml.safe_load((ROOT / ".github" / "workflows" / "release.yml").read_text("utf-8"))
    run_name = spec.get("run-name", "")

    assert "github.event.workflow_run.display_title" in run_name
    assert "Release · " in run_name
    assert "manual dispatch by" in run_name and "github.actor" in run_name


RELEASE_SKILLS = (".claude/skills/release/SKILL.md", ".agents/skills/release/SKILL.md")


def test_NAMING_06_claude_and_codex_release_skills_teach_the_same_naming():
    """The release skill runs preflight for Claude and, as a second copy, for
    Codex. Codex's copy drifted twice unnoticed (no preflight, then no naming;
    plan §09 G1), so the two must stay byte-identical and carry the procedure."""
    claude, codex = ((ROOT / path).read_text(encoding="utf-8") for path in RELEASE_SKILLS)

    assert codex == claude, "the Codex release skill differs from Claude's; copy one over the other"
    for step in (
        "## Name the change before preflight",
        "scripts/preflight.sh",
        "scripts/branch_description.py check",
        "Release · ",
    ):
        assert step in claude, step
