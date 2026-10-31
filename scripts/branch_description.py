#!/usr/bin/env python3
"""Every branch, merge and release says what it changes.

A worker branch (claude/<what-it-changes> or codex/<what-it-changes>) carries
its explanation in git's own branch description (`git branch
--edit-description`, stored in the repository config that every worktree
shares): a title of up to 72 characters, then a few sentences on why, what
was wrong and what it does now. scripts/preflight.sh and
scripts/integrate-agent-branch.sh both run this one check, so they cannot
disagree, and the integrate script merges with `message` as the merge commit,
whose first line GitHub shows as the title of the CI run and, through
release.yml's run-name, the Release run.

Usage: see USAGE below.

Plan: doc/plans/branch-names-and-merge-messages-2026-10-31.html (B1–B3 A).
"""

from __future__ import annotations

import re
import subprocess
import sys

TITLE_MAX = 72
WORKER = re.compile(r"^(claude|codex)/([a-z0-9][a-z0-9-]*)$")
DATE = re.compile(r"(?:^|-)(?:\d{4}-\d{2}-\d{2}|\d{8})(?:-|$)")
TRAILER = re.compile(r"^[A-Za-z][A-Za-z0-9-]*: \S")
SENTENCE_END = re.compile(r"[.!?](?:\s|$)")
USAGE = """usage:
  branch_description.py check [<branch>]    the rules; prints the names the push carries
  branch_description.py message <branch>    the merge message: the description and Branch:"""


def _git(*args: str, input_text: str | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args], input=input_text, text=True, capture_output=True, check=False
    )


def _description(branch: str) -> str:
    return _git("config", "--get", f"branch.{branch}.description").stdout.strip()


def _explanation(body: str) -> str:
    """The body without its closing trailer block (Co-Authored-By: and the like)."""
    paragraphs = [p for p in re.split(r"\n\s*\n", body.strip()) if p.strip()]
    if paragraphs and all(TRAILER.match(line) for line in paragraphs[-1].splitlines()):
        paragraphs = paragraphs[:-1]
    return "\n\n".join(paragraphs)


def problems(branch: str) -> list[str]:
    """Why <branch> may not be merged as it stands; empty when it may."""
    found: list[str] = []
    name = WORKER.match(branch)
    if not name:
        found.append(f"{branch}: not a worker branch (claude/<what-it-changes> or codex/<…>)")
    else:
        task = name.group(2)
        if task.startswith("session") or "-session-" in task:
            found.append(f"{branch}: a session name says nothing about the change")
        if DATE.search(task):
            found.append(f"{branch}: a date in the name says when, not what")
        if len([w for w in task.split("-") if w]) < 3:
            found.append(f"{branch}: fewer than three words cannot say what changes")

    description = _description(branch)
    if not description:
        found.append(
            f"{branch}: no branch description (git branch --edit-description {branch}): "
            "a title, a blank line, then a few sentences on what changes and why"
        )
        return found
    title, _, body = description.partition("\n")
    title = title.strip()
    if len(title) > TITLE_MAX:
        found.append(f"title is {len(title)} characters, longer than {TITLE_MAX}: {title}")
    if title.lower().startswith("merge"):
        found.append(f'title starts with "Merge": {title}')
    sentences = len(SENTENCE_END.findall(_explanation(body)))
    if sentences < 2:
        found.append(
            f"the explanation under the title has {sentences} sentence(s); "
            "it needs at least two sentences: what was wrong, what it does now"
        )
    return found


def message(branch: str) -> str:
    """The merge commit message: the description, with Branch: added as a trailer."""
    result = _git(
        "interpret-trailers",
        "--if-exists",
        "replace",
        "--trailer",
        f"Branch: {branch}",
        input_text=_description(branch) + "\n",
    )
    if result.returncode != 0:
        raise SystemExit(result.stderr.strip() or "git interpret-trailers failed")
    return result.stdout


def _current_branch() -> str:
    return _git("symbolic-ref", "--quiet", "--short", "HEAD").stdout.strip()


def main(argv: list[str]) -> int:
    if not argv or argv[0] not in {"check", "message"}:
        print(USAGE, file=sys.stderr)
        return 2
    branch = argv[1] if len(argv) > 1 else _current_branch()
    found = problems(branch)
    for problem in found:
        print(f"branch description: {problem}", file=sys.stderr)
    if found:
        return 1
    if argv[0] == "message":
        sys.stdout.write(message(branch))
        return 0
    title = _description(branch).partition("\n")[0].strip()
    print(f"Branch:       {branch}")
    print(f"Merge title:  {title}")
    print(f"CI run:       {title}")
    print(f"Release run:  Release · {title}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
