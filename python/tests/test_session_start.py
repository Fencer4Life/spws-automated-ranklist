"""Tests for scripts/session_start.py — the session-start protocol.

Plan: doc/plans/session-start-protocol-2026-10-03.html (signed off 3 Oct 2026,
D2 = 30 days). Every test builds a real, throwaway Git setup — a bare origin,
a primary checkout on a claude/* branch, a registered integration checkout and,
where needed, worker worktrees — and runs the script exactly as the hook does:
hook JSON on stdin, hook JSON on stdout. The graph refresh and the RAG ingest
are replaced by stand-in commands so the tests stay fast and offline.

Cleanup deletes things, so its safety rules are pinned one by one: a worktree
is removed only when it is Claude's, clean (untracked files included), wholly
contained in origin/main and not in use (ended, or idle for 30 days).
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "scripts" / "session_start.py"
START_AGENT = REPO / "scripts" / "start-agent-worktree.sh"
DAY = 86_400


def git(*args: str, cwd: Path) -> str:
    return subprocess.run(
        ["git", *args], cwd=cwd, check=True, capture_output=True, text=True
    ).stdout.strip()


@dataclass
class Setup:
    tmp: Path
    origin: Path
    primary: Path
    integration: Path

    def worker(self, name: str, *, agent: str = "claude") -> Path:
        """A worker worktree on <agent>/<name>, cut from origin/main."""
        path = self.tmp / f"SPWSranklist-{agent}-{name}"
        git(
            "worktree",
            "add",
            "-q",
            "-b",
            f"{agent}/{name}",
            str(path),
            "origin/main",
            cwd=self.primary,
        )
        return path

    def advance_main(self) -> None:
        """Land a new commit on origin/main and fetch it everywhere."""
        seed = self.tmp / "seed"
        (seed / "CHANGELOG").write_text(f"{time.time()}\n")
        git("add", "CHANGELOG", cwd=seed)
        git("commit", "-q", "-m", "advance main", cwd=seed)
        git("push", "-q", "origin", "main", cwd=seed)
        git("fetch", "-q", "origin", cwd=self.primary)

    def age(self, worktree: Path, days: int) -> None:
        """Make a worktree look untouched for `days` days."""
        gitdir = Path(git("rev-parse", "--absolute-git-dir", cwd=worktree))
        when = time.time() - days * DAY
        for name in ("index", "HEAD", "logs/HEAD"):
            target = gitdir / name
            if target.exists():
                os.utime(target, (when, when))


@pytest.fixture
def setup(tmp_path: Path) -> Setup:
    origin = tmp_path / "origin.git"
    git("init", "-q", "--bare", "-b", "main", str(origin), cwd=tmp_path)

    seed = tmp_path / "seed"
    seed.mkdir()
    git("init", "-q", "-b", "main", cwd=seed)
    git("config", "user.email", "t@example.invalid", cwd=seed)
    git("config", "user.name", "Test", cwd=seed)
    (seed / "scripts").mkdir()
    shutil.copy2(START_AGENT, seed / "scripts" / "start-agent-worktree.sh")
    (seed / "README").write_text("seed\n")
    # The real repository's ignore rules for everything the protocol seeds or links.
    (seed / ".gitignore").write_text(".env\n.venv/\nnode_modules/\ngraphify-out/\n")
    git("add", ".", cwd=seed)
    git("commit", "-q", "-m", "seed", cwd=seed)
    git("remote", "add", "origin", str(origin), cwd=seed)
    git("push", "-q", "origin", "main", cwd=seed)

    primary = tmp_path / "SPWSranklist"
    git("clone", "-q", str(origin), str(primary), cwd=tmp_path)
    git("config", "user.email", "t@example.invalid", cwd=primary)
    git("config", "user.name", "Test", cwd=primary)
    git("checkout", "-q", "-b", "claude/work", cwd=primary)

    integration = tmp_path / "SPWSranklist-integration"
    git(
        "worktree",
        "add",
        "-q",
        "-b",
        "integration/main",
        str(integration),
        "origin/main",
        cwd=primary,
    )
    git("config", "spws.integrationWorktree", str(integration.resolve()), cwd=primary)
    return Setup(tmp_path, origin, primary, integration)


def run(
    setup: Setup,
    cwd: Path,
    *,
    source: str = "startup",
    session: str = "abc123def456",
    end: bool = False,
    env: dict[str, str] | None = None,
) -> dict:
    rag_marker = setup.tmp / "rag-ran"
    full_env = (
        os.environ
        | {
            "SPWS_GRAPH_CMD": "true",
            "SPWS_RAG_CMD": f"touch '{rag_marker}' && echo \"Indexed. 7 documents in 'spws_docs'.\"",
            "SPWS_RAG_LOCK": str(setup.tmp / "rag.lock"),
        }
        | (env or {})
    )
    payload = {
        "session_id": session,
        "source": source,
        "cwd": str(cwd),
        "hook_event_name": "SessionEnd" if end else "SessionStart",
    }
    args = [sys.executable, str(SCRIPT)] + (["--end"] if end else [])
    done = subprocess.run(
        args,
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        cwd=cwd,
        env=full_env,
        timeout=120,
    )
    assert done.returncode == 0, done.stderr
    return json.loads(done.stdout) if done.stdout.strip() else {}


def context(out: dict) -> str:
    return out["hookSpecificOutput"]["additionalContext"]


def worktree_paths(setup: Setup) -> list[str]:
    listing = git("worktree", "list", "--porcelain", cwd=setup.primary)
    return [line.split(" ", 1)[1] for line in listing.splitlines() if line.startswith("worktree ")]


def branches(setup: Setup) -> list[str]:
    return git("branch", "--format=%(refname:short)", cwd=setup.primary).splitlines()


# --- isolation --------------------------------------------------------------


def test_startup_in_primary_gets_its_own_worktree(setup: Setup):
    """SS.01 — a session starting in the primary checkout gets a new worker from origin/main."""
    out = run(setup, setup.primary)
    made = [p for p in worktree_paths(setup) if "SPWSranklist-claude-session-" in p]
    assert len(made) == 1
    new = Path(made[0])
    assert git("rev-parse", "HEAD", cwd=new) == git("rev-parse", "origin/main", cwd=setup.primary)
    assert git("branch", "--show-current", cwd=new).startswith("claude/session-")
    assert "EnterWorktree" in context(out) and str(new) in context(out)
    assert out["systemMessage"].startswith("SPWS session")


def test_resume_never_creates_a_worktree(setup: Setup):
    """SS.02 — resume keeps the session where it was."""
    run(setup, setup.primary, source="resume")
    assert not any("session-" in p for p in worktree_paths(setup))


def test_startup_inside_a_worker_stays_there(setup: Setup):
    """SS.03 — a session opened in a worker worktree is not moved."""
    worker = setup.worker("task-a")
    out = run(setup, worker)
    assert not any("session-" in p for p in worktree_paths(setup))
    assert "EnterWorktree" not in context(out)


def test_clear_in_primary_starts_a_fresh_worktree(setup: Setup):
    """SS.04 — /clear in a shared checkout means a new task (decision D5)."""
    run(setup, setup.primary, source="clear")
    assert any("SPWSranklist-claude-session-" in p for p in worktree_paths(setup))


def test_dirty_integration_checkout_leaves_the_session_in_place(setup: Setup):
    """SS.05 — start-agent-worktree.sh refuses; the report says so and nothing breaks."""
    (setup.integration / "stray.txt").write_text("x")
    out = run(setup, setup.primary)
    assert not any("session-" in p for p in worktree_paths(setup))
    assert "not isolated" in context(out).lower()


def test_new_worktree_has_shared_venv_and_stays_clean(setup: Setup):
    """SS.06 — .venv is symlinked from the primary and excluded, so cleanup can still see it as clean."""
    (setup.primary / ".venv").mkdir()
    graph = setup.primary / "graphify-out"
    graph.mkdir()
    for name in (
        "graph.json",
        "manifest.json",
        ".graphify_labels.json",
        "GRAPH_REPORT.md",
        ".graphify_root",
        ".graphify_python",
        "cost.json",
    ):
        (graph / name).write_text("{}")
    run(setup, setup.primary)
    new = next(Path(p) for p in worktree_paths(setup) if "session-" in p)
    assert (new / ".venv").is_symlink()
    assert git("status", "--porcelain", cwd=new) == ""
    # Handbook (claude-codex-collaboration, "Give each worker its own Graphify cache"):
    # only the portable baseline files travel; .graphify_root would point the
    # worker's graph tools back at the primary checkout.
    seeded = sorted(p.name for p in (new / "graphify-out").iterdir())
    assert seeded == [".graphify_labels.json", "GRAPH_REPORT.md", "graph.json", "manifest.json"]


# --- cleanup ----------------------------------------------------------------


def test_ended_clean_merged_claude_worktree_is_removed_with_its_branch(setup: Setup):
    """SS.07 — the one case cleanup acts on immediately."""
    worker = setup.worker("done-task")
    run(setup, worker, end=True)
    run(setup, setup.primary, source="resume")
    assert str(worker) not in worktree_paths(setup)
    assert "claude/done-task" not in branches(setup)


def test_untracked_file_keeps_a_worktree(setup: Setup):
    """SS.08 — an untracked plan is exactly what cleanup must never lose."""
    worker = setup.worker("has-plan")
    (worker / "plan.html").write_text("<p>draft</p>")
    run(setup, worker, end=True)
    out = run(setup, setup.primary, source="resume")
    assert str(worker) in worktree_paths(setup)
    # The script's own rule must hold it back; git's refusal is only the second lock.
    assert "claude/has-plan" in context(out)
    assert "uncommitted or untracked files" in context(out)
    assert "git refused removal" not in context(out)


def test_unmerged_commit_keeps_a_worktree(setup: Setup):
    """SS.09 — a commit missing from origin/main is never thrown away."""
    worker = setup.worker("unmerged")
    (worker / "work.txt").write_text("x")
    git("add", "work.txt", cwd=worker)
    git("commit", "-q", "-m", "work", cwd=worker)
    run(setup, worker, end=True)
    run(setup, setup.primary, source="resume")
    assert str(worker) in worktree_paths(setup)
    assert "claude/unmerged" in branches(setup)


def test_codex_worktrees_are_never_touched(setup: Setup):
    """SS.10 — Codex owns its worktrees (decision D3), however old and clean."""
    codex = setup.worker("old-codex", agent="codex")
    setup.age(codex, 90)
    out = run(setup, setup.primary, source="resume")
    assert str(codex) in worktree_paths(setup)
    assert "codex/old-codex" in branches(setup)
    assert "1 codex/* worktree(s) never touched" in context(out)


def test_idle_threshold_is_thirty_days(setup: Setup):
    """SS.11 — without an end record, a clean merged worktree goes at 30 days idle, not 29."""
    young = setup.worker("idle-29")
    old = setup.worker("idle-31")
    setup.age(young, 29)
    setup.age(old, 31)
    run(setup, setup.primary, source="resume")
    paths = worktree_paths(setup)
    assert str(young) in paths
    assert str(old) not in paths


def test_the_sessions_own_worktree_is_never_removed(setup: Setup):
    """SS.12 — starting in an ended, clean, merged worktree re-claims it instead."""
    worker = setup.worker("reopened")
    run(setup, worker, end=True)
    run(setup, worker, source="resume")
    assert str(worker) in worktree_paths(setup)
    run(setup, setup.primary, source="resume")
    assert str(worker) in worktree_paths(setup)


def test_an_idle_worktree_the_session_starts_in_is_kept(setup: Setup):
    """SS.16 — clean, merged and 31 days idle, but it is where this session works."""
    worker = setup.worker("old-but-mine")
    setup.age(worker, 31)
    run(setup, worker, source="resume")
    assert str(worker) in worktree_paths(setup)


def test_shared_checkouts_are_never_cleanup_candidates(setup: Setup):
    """SS.17 — the primary is on a claude/* branch and looks removable; it is never a candidate."""
    setup.age(setup.primary, 31)
    setup.age(setup.integration, 31)
    worker = setup.worker("launcher")
    out = run(setup, worker, source="resume")
    assert str(setup.primary) in worktree_paths(setup)
    assert str(setup.integration) in worktree_paths(setup)
    assert "claude/work" not in context(out)


# --- baseline and RAG ---------------------------------------------------------


def test_rag_is_not_rebuilt_from_a_checkout_behind_main(setup: Setup):
    """SS.13 — the shared index is only ever rebuilt from an up-to-date tree."""
    worker = setup.worker("behind")
    (worker / "mine.txt").write_text("x")
    git("add", "mine.txt", cwd=worker)
    git("commit", "-q", "-m", "mine", cwd=worker)
    setup.advance_main()
    out = run(setup, worker)
    assert not (setup.tmp / "rag-ran").exists()
    assert "not re-indexed" in context(out).lower()
    assert "STALE" in context(out)


def test_rag_is_rebuilt_from_an_up_to_date_checkout(setup: Setup):
    """SS.14 — not behind origin/main: the index is rebuilt and its size reported."""
    worker = setup.worker("current")
    out = run(setup, worker)
    assert (setup.tmp / "rag-ran").exists()
    assert "7" in out["systemMessage"]


def test_clean_worker_with_no_commits_is_fast_forwarded(setup: Setup):
    """SS.15 — nothing of its own to lose, so it is brought up to origin/main."""
    worker = setup.worker("ff")
    setup.advance_main()
    run(setup, worker)
    assert git("rev-parse", "HEAD", cwd=worker) == git(
        "rev-parse", "origin/main", cwd=setup.primary
    )
