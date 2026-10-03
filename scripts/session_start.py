#!/usr/bin/env python3
"""SPWS session-start protocol, run by the SessionStart and SessionEnd hooks.

Plan: doc/plans/session-start-protocol-2026-10-03.html (signed off 2026-10-03,
D2 = 30 days). Procedure for agents: doc/claude/session-start.md.

    python3 scripts/session_start.py        # SessionStart: hook JSON in, hook JSON out
    python3 scripts/session_start.py --end  # SessionEnd: record the session as ended

At session start, in order:

  1. Isolate   A session that starts or /clears in a SHARED checkout (the primary
               checkout or the registered integration checkout) gets its own worker
               worktree on a new claude/session-* branch from origin/main, created by
               scripts/start-agent-worktree.sh. Two sessions in one folder share one
               set of files, so parallel work needs one folder per session.
  2. Baseline  Fetch origin (bounded), report ahead/behind origin/main, and
               fast-forward a clean worker that has no commits of its own.
  3. Clean up  Remove Claude's finished worktrees: branch claude/*, clean (untracked
               files included), wholly contained in origin/main, and not in use (its
               session ended, or idle for IDLE_DAYS). Never --force; never codex/*,
               the primary, the integration checkout or the session's own worktree.
  4. Graph     refresh-graph.sh --full-code in the working checkout (zero tokens).
  5. RAG       Rebuild the shared spws_docs index, but only from a checkout that is
               not behind origin/main: ingest.py deletes whatever its tree lacks, so
               a stale checkout would strip newer documents from every session.

Standard library only: this runs in a brand-new worktree before any project
environment exists. It never blocks a session — failures become report lines.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import traceback
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

IDLE_DAYS = 30  # decision D2
DAY = 86_400
FETCH_TIMEOUT = 20
STEP_TIMEOUT = 240
LOCK_STALE_SECONDS = 15 * 60
RAG_CMD = "python3 tools/docs-search/ingest.py"
HERE = Path(__file__).resolve().parent
# The graph is refreshed with THIS copy of graphify_refresh.py, run inside the
# working checkout: a new worker is cut from origin/main, whose copy may predate
# the protocol, and the protocol must not depend on what the worker happens to hold.
GRAPH_REFRESH = HERE / "graphify_refresh.py"
# Same fallback as scripts/refresh-graph.sh: graphify's own isolated interpreter.
# The interpreter pin is read from the checkout that has one; it is never copied.
GRAPHIFY_PYTHON_FALLBACK = "/Users/aleks/.local/share/uv/tools/graphifyy/bin/python"
# Shared from the primary checkout into a new worker, as the existing workers do.
# The RAG's key lives in an untracked .env beside ingest.py, so it is shared too.
SHARED_LINKS = (".venv", "frontend/node_modules", "tools/docs-search/.env")
# The portable baseline a new worker is seeded with — exactly the handbook's list
# (claude-codex-collaboration, "Give each worker its own Graphify cache"). Never
# .graphify_root, which names the source checkout, nor .graphify_python, logs or cost.
GRAPH_PORTABLE = ("graph.json", "manifest.json", ".graphify_labels.json", "GRAPH_REPORT.md")
RESEARCH_RULE = (
    "Research rule: documentation -> mcp__spws-docs__search (2-5 keywords, open the hit's "
    "path); code -> graphify query/explain (symbol names) and the LSP; grep or git show "
    "only confirm a literal already located. Skill: research-gate."
)


# --- small helpers ------------------------------------------------------------


def run(args: list[str], cwd: Path, timeout: int = 60) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return subprocess.CompletedProcess(args, 124, "", f"timed out after {timeout}s")


def git(cwd: Path, *args: str, timeout: int = 60) -> subprocess.CompletedProcess[str]:
    return run(["git", *args], cwd, timeout)


def real(path: str | Path) -> Path:
    return Path(os.path.realpath(path))


def last_line(text: str) -> str:
    lines = [line for line in text.strip().splitlines() if line.strip()]
    return lines[-1].strip() if lines else ""


@dataclass
class Worktree:
    path: Path
    branch: str | None
    prunable: bool


def list_worktrees(repo: Path) -> list[Worktree]:
    found: list[Worktree] = []
    for block in git(repo, "worktree", "list", "--porcelain").stdout.split("\n\n"):
        fields = dict(
            (line.split(" ", 1) + [""])[:2] for line in block.strip().splitlines() if line
        )
        if "worktree" not in fields:
            continue
        branch = fields.get("branch", "").removeprefix("refs/heads/") or None
        found.append(Worktree(Path(fields["worktree"]), branch, "prunable" in fields))
    return found


def marks_dir(repo: Path) -> Path:
    common = Path(
        git(repo, "rev-parse", "--path-format=absolute", "--git-common-dir").stdout.strip()
    )
    marks = common / "spws-sessions"
    for sub in ("ended", "created"):
        (marks / sub).mkdir(parents=True, exist_ok=True)
    return marks


def mark_key(path: Path) -> str:
    return re.sub(r"[^A-Za-z0-9._-]", "_", str(real(path)))


def last_activity(path: Path) -> float:
    gitdir = Path(git(path, "rev-parse", "--absolute-git-dir").stdout.strip())
    times = [
        p.stat().st_mtime
        for p in (gitdir / "index", gitdir / "HEAD", gitdir / "logs" / "HEAD")
        if p.exists()
    ]
    return max(times) if times else time.time()


def is_clean(path: Path) -> bool:
    status = git(path, "status", "--porcelain")
    return status.returncode == 0 and status.stdout.strip() == ""


def is_merged(repo: Path, branch: str) -> bool:
    return git(repo, "merge-base", "--is-ancestor", branch, "origin/main").returncode == 0


def ahead_behind(path: Path) -> tuple[int, int] | None:
    counts = git(path, "rev-list", "--left-right", "--count", "HEAD...origin/main")
    if counts.returncode != 0:
        return None
    ahead, behind = counts.stdout.split()
    return int(ahead), int(behind)


# --- the protocol steps ---------------------------------------------------------


def isolate(
    source: str,
    session_id: str,
    root: Path,
    shared: set[Path],
    primary: Path,
    integration: Path | None,
    notes: list[str],
) -> Path | None:
    """Step 1: a new worker worktree for a session starting in a shared checkout."""
    if source not in ("startup", "clear") or real(root) not in shared:
        return None
    if os.environ.get("SPWS_NO_ISOLATE") == "1":
        notes.append(
            "Isolation: skipped (SPWS_NO_ISOLATE=1); this session works in a shared checkout."
        )
        return None
    if integration is None:
        notes.append(
            "Isolation: NOT isolated - no integration checkout is registered (spws.integrationWorktree)."
        )
        return None
    script = integration / "scripts" / "start-agent-worktree.sh"
    if not script.exists():
        notes.append(f"Isolation: NOT isolated - {script} is missing.")
        return None
    suffix = re.sub(r"[^a-z0-9]", "", session_id.lower())[:6]
    task = f"session-{datetime.now():%Y%m%d-%H%M}" + (f"-{suffix}" if suffix else "")
    made = run(["bash", str(script), "claude", task], integration, timeout=120)
    match = re.search(r"^\s*path:\s+(.+)$", made.stdout, re.MULTILINE)
    if made.returncode != 0 or not match:
        reason = last_line(made.stderr) or last_line(made.stdout) or f"exit {made.returncode}"
        notes.append(
            f"Isolation: NOT isolated - start-agent-worktree.sh refused: {reason}. "
            "This session works in a shared checkout; do not switch its branch."
        )
        return None
    new = Path(match.group(1).strip())
    seed_worktree(new, [root, primary, integration], primary)
    (marks_dir(primary) / "created" / mark_key(new)).write_text(session_id)
    return new


def seed_worktree(new: Path, graph_sources: list[Path], primary: Path) -> None:
    """Give a new worker the newest existing graph and the primary's shared environments."""
    graphs = [
        s / "graphify-out" for s in graph_sources if (s / "graphify-out" / "graph.json").exists()
    ]
    if graphs and not (new / "graphify-out").exists():
        newest = max(graphs, key=lambda g: (g / "graph.json").stat().st_mtime)
        (new / "graphify-out").mkdir()
        for name in GRAPH_PORTABLE:
            if (newest / name).is_file():
                shutil.copy2(newest / name, new / "graphify-out" / name)
    for rel in SHARED_LINKS:
        src, dst = primary / rel, new / rel
        if src.exists() and dst.parent.is_dir() and not os.path.lexists(dst):
            dst.symlink_to(src)
    # Anchored, without a trailing slash, so the SYMLINKS are ignored too: the
    # repository's `.venv/` and `node_modules/` patterns match directories only.
    exclude = (
        Path(git(new, "rev-parse", "--path-format=absolute", "--git-common-dir").stdout.strip())
        / "info"
        / "exclude"
    )
    exclude.parent.mkdir(parents=True, exist_ok=True)
    lines = exclude.read_text().splitlines() if exclude.exists() else []
    wanted = [f"/{rel}" for rel in SHARED_LINKS if f"/{rel}" not in lines]
    if wanted:
        with exclude.open("a") as handle:
            handle.write(
                "\n# session_start.py: shared environment symlinks\n" + "\n".join(wanted) + "\n"
            )


def baseline(
    work: Path, shared: set[Path], notes: list[str]
) -> tuple[str, int | None, int | None, int]:
    """Step 2: fetch, ahead/behind, and a fast-forward when nothing of the worker's own is at stake."""
    if os.environ.get("SPWS_NO_FETCH") != "1":
        fetched = git(work, "fetch", "--quiet", "origin", timeout=FETCH_TIMEOUT)
        if fetched.returncode != 0:
            notes.append(
                f"Fetch: failed ({last_line(fetched.stderr) or 'offline?'}); "
                "ahead/behind is measured against the last fetched origin/main."
            )
    branch = git(work, "branch", "--show-current").stdout.strip() or "(detached)"
    counts = ahead_behind(work)
    if counts and real(work) not in shared and counts[0] == 0 and counts[1] > 0 and is_clean(work):
        if git(work, "merge", "--ff-only", "--quiet", "origin/main").returncode == 0:
            notes.append(
                f"Baseline: fast-forwarded {counts[1]} commit(s) to origin/main "
                "(clean worker, no commits of its own)."
            )
            counts = ahead_behind(work)
    dirty = len([line for line in git(work, "status", "--porcelain").stdout.splitlines() if line])
    ahead, behind = counts if counts else (None, None)
    if behind:
        notes.append(
            f"STALE: this checkout is {behind} commit(s) behind origin/main, so the graph "
            "describes older code. Merge origin/main into this branch before analysing."
        )
    return branch, ahead, behind, dirty


def cleanup(repo: Path, keep: set[Path], notes: list[str]) -> tuple[int, int]:
    """Step 3: remove only what can lose nothing; report what needs the user."""
    marks = marks_dir(repo)
    removed: list[str] = []
    decide: list[str] = []
    waiting = codex = gone = 0
    now = time.time()
    for wt in list_worktrees(repo):
        if wt.prunable or not wt.path.exists():
            gone += 1
            continue
        if real(wt.path) in keep or not wt.branch:
            continue
        if wt.branch.startswith("codex/"):
            codex += 1  # decision D3: Codex owns these
            continue
        if not wt.branch.startswith("claude/"):
            continue
        # Activity first: `git status` below may rewrite the index and its mtime.
        idle = (now - last_activity(wt.path)) / DAY
        clean = is_clean(wt.path)
        merged = is_merged(repo, wt.branch)
        ended = (marks / "ended" / mark_key(wt.path)).exists()
        if clean and merged and (ended or idle >= IDLE_DAYS):
            gone_tree = git(repo, "worktree", "remove", str(wt.path))  # never --force
            if gone_tree.returncode == 0:
                git(repo, "branch", "-D", wt.branch)  # safe: every commit is on origin/main
                for sub in ("ended", "created"):
                    (marks / sub / mark_key(wt.path)).unlink(missing_ok=True)
                removed.append(
                    f"{wt.branch} ({'session ended' if ended else f'{idle:.0f} days idle'})"
                )
            else:
                decide.append(
                    f"{wt.branch} at {wt.path}: git refused removal ({last_line(gone_tree.stderr)})"
                )
        elif not clean or not merged:
            why = []
            if not clean:
                why.append("uncommitted or untracked files")
            if not merged:
                count = git(repo, "rev-list", "--count", f"origin/main..{wt.branch}").stdout.strip()
                why.append(f"{count} commit(s) not on origin/main")
            decide.append(f"{wt.branch} at {wt.path}: {', '.join(why)}; idle {idle:.0f} days")
        else:
            waiting += 1
    if gone:
        git(repo, "worktree", "prune")
    parts = [f"removed {len(removed)}" + (f" ({'; '.join(removed)})" if removed else "")]
    if decide:
        parts.append("kept for the user's decision: " + " | ".join(decide))
    if waiting:
        parts.append(
            f"{waiting} clean and merged, removed after {IDLE_DAYS} days idle or when their session ends"
        )
    if codex:
        parts.append(f"{codex} codex/* worktree(s) never touched")
    if gone:
        parts.append(f"pruned registry entries of {gone} worktree(s) whose folder is gone")
    notes.append("Cleanup: " + "; ".join(parts) + ".")
    return len(removed), len(decide)


def run_graph(work: Path, primary: Path, notes: list[str]) -> str:
    """Step 4: the full-code graph refresh."""
    override = os.environ.get("SPWS_GRAPH_CMD")
    if override:
        args = ["bash", "-c", override]
    else:
        if not (work / "graphify-out" / "graph.json").exists():
            notes.append(
                "Graph: no graphify-out/graph.json in this checkout - run a full /graphify . once."
            )
            return "missing"
        python = GRAPHIFY_PYTHON_FALLBACK
        for pin in (
            work / "graphify-out" / ".graphify_python",
            primary / "graphify-out" / ".graphify_python",
        ):
            pinned = pin.read_text().strip() if pin.exists() else ""
            if pinned and Path(pinned).exists():
                python = pinned
                break
        args = [python, str(GRAPH_REFRESH), "--full-code", "--quiet"]
    started = time.time()
    done = run(args, work, STEP_TIMEOUT)
    if done.returncode != 0:
        notes.append(
            f"Graph: refresh FAILED (exit {done.returncode}): "
            f"{last_line(done.stderr) or last_line(done.stdout)}. Do not trust the graph until fixed."
        )
        return "FAILED"
    graph = work / "graphify-out" / "graph.json"
    nodes = len(json.loads(graph.read_text())["nodes"]) if graph.exists() else 0
    audit = [line for line in done.stdout.splitlines() if "lost nodes" in line]
    notes.append(
        f"Graph: refreshed (full code) in {time.time() - started:.0f}s - {nodes:,} nodes."
        + (f" AUDIT: {audit[0].removeprefix('refresh-graph: ')}" if audit else "")
    )
    return f"{nodes:,} nodes"


def run_rag(work: Path, behind: int | None, notes: list[str]) -> str:
    """Step 5: rebuild the shared documentation index, only from an up-to-date tree."""
    cmd = os.environ.get("SPWS_RAG_CMD", RAG_CMD)
    if behind is None:
        notes.append("RAG: not re-indexed - origin/main is unknown in this checkout.")
        return "not re-indexed"
    if behind > 0:
        notes.append(
            f"RAG: NOT re-indexed - this checkout is {behind} commit(s) behind origin/main, "
            "and rebuilding the shared index from it would delete newer documents."
        )
        return "not re-indexed"
    if cmd == RAG_CMD and not (work / "tools" / "docs-search" / "ingest.py").exists():
        notes.append(
            "RAG: tools/docs-search/ingest.py is missing in this checkout - not re-indexed."
        )
        return "not re-indexed"
    lock = Path(
        os.environ.get("SPWS_RAG_LOCK", Path(tempfile.gettempdir()) / "spws-rag-ingest.lock")
    )
    if lock.exists() and time.time() - lock.stat().st_mtime > LOCK_STALE_SECONDS:
        lock.rmdir()
    try:
        lock.mkdir()
    except FileExistsError:
        notes.append("RAG: another session is re-indexing right now - skipped.")
        return "busy"
    try:
        started = time.time()
        done = run(["bash", "-c", cmd], work, STEP_TIMEOUT)
    finally:
        lock.rmdir()
    found = re.search(r"Indexed\.\s+(\d+)\s+documents", done.stdout)
    if done.returncode != 0 or not found:
        notes.append(
            f"RAG: re-index FAILED (exit {done.returncode}): "
            f"{last_line(done.stderr) or last_line(done.stdout)}. Is Meilisearch running?"
        )
        return "FAILED"
    notes.append(
        f"RAG: re-indexed in {time.time() - started:.0f}s - {int(found.group(1)):,} chunks."
    )
    return f"{int(found.group(1)):,} chunks"


# --- entry points ---------------------------------------------------------------


def shared_checkouts(primary: Path, integration: Path | None) -> set[Path]:
    return {real(primary)} | ({real(integration)} if integration else set())


def locate(cwd: Path) -> tuple[Path, Path, Path | None] | None:
    top = git(cwd, "rev-parse", "--show-toplevel")
    if top.returncode != 0:
        return None
    root = Path(top.stdout.strip())
    worktrees = list_worktrees(root)
    primary = worktrees[0].path if worktrees else root
    registered = git(root, "config", "--get", "spws.integrationWorktree").stdout.strip()
    integration = Path(registered) if registered and Path(registered).exists() else None
    return root, primary, integration


def start(payload: dict) -> dict:
    cwd = Path(payload.get("cwd") or os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd())
    found = locate(cwd)
    if found is None:
        return {}
    root, primary, integration = found
    shared = shared_checkouts(primary, integration)
    notes: list[str] = []

    new = isolate(
        payload.get("source", ""),
        payload.get("session_id", ""),
        root,
        shared,
        primary,
        integration,
        notes,
    )
    work = new or root
    if real(work) not in shared:  # in use again: an earlier end record no longer applies
        (marks_dir(primary) / "ended" / mark_key(work)).unlink(missing_ok=True)

    branch, ahead, behind, dirty = baseline(work, shared, notes)
    removed, decide = cleanup(primary, shared | {real(root), real(work)}, notes)
    graph = run_graph(work, primary, notes)
    rag = run_rag(work, behind, notes)

    head: list[str] = [
        f"SPWS session-start protocol (scripts/session_start.py), {datetime.now():%Y-%m-%d %H:%M}."
    ]
    if new:
        head.append(
            f"FIRST ACTION, before anything else: call EnterWorktree with path={new} . "
            f"This session works ONLY there, on branch {branch}; never edit files in {root}. "
            "Rename the branch to the task once it is clear: git branch -m claude/<task>."
        )
    head.append(
        f"Checkout: {work} - branch {branch} - {ahead} ahead / {behind} behind origin/main - "
        f"{dirty} uncommitted path(s)."
    )
    message = (
        f"SPWS session · {branch} · graph {graph} · RAG {rag} · "
        f"cleanup {removed} removed"
        + (f", {decide} need you" if decide else "")
        + (" · new worktree, entering it" if new else "")
    )
    return {
        "systemMessage": message,
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": "\n".join(head + notes + [RESEARCH_RULE]),
        },
    }


def end(payload: dict) -> None:
    cwd = Path(payload.get("cwd") or os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd())
    found = locate(cwd)
    if found is None:
        return
    root, primary, integration = found
    marks = marks_dir(primary)
    if real(root) not in shared_checkouts(primary, integration):
        (marks / "ended" / mark_key(root)).touch()
    session_id = payload.get("session_id", "")
    for created in (marks / "created").iterdir():
        if session_id and created.read_text().strip() == session_id:
            (marks / "ended" / created.name).touch()


def main() -> int:
    try:
        raw = sys.stdin.read() if not sys.stdin.isatty() else ""
        payload = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        payload = {}
    try:
        if "--end" in sys.argv[1:]:
            end(payload)
            return 0
        print(json.dumps(start(payload)))
    except Exception as exc:  # noqa: BLE001 — the hook must never block a session
        print(
            json.dumps(
                {
                    "systemMessage": f"SPWS session-start FAILED: {exc}",
                    "hookSpecificOutput": {
                        "hookEventName": "SessionStart",
                        "additionalContext": "SPWS session-start protocol FAILED - run "
                        "python3 scripts/session_start.py by hand before analysing.\n"
                        + traceback.format_exc(limit=3)
                        + "\n"
                        + RESEARCH_RULE,
                    },
                }
            )
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
