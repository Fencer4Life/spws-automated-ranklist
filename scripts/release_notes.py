#!/usr/bin/env python3
"""What a Release run carries: every commit on main since PROD last deployed.

GitHub shows only a merge commit's first line, so a Release run's page held its job
boxes and nothing else. release.yml's `notes` job runs this script and appends what
it prints to the run's Summary page: each merge with its title, explanation and
Branch: line, each commit pushed straight to main, and the workflows' own [skip ci]
commits counted by kind. The range comes from the gate (scripts/release-gate.sh
outputs base and head), so the two never measure differently.

Every text is written as HTML that GitHub reads as plain text, through
scripts/github_text.py (shared with scripts/ci_summary.py), so nothing becomes a tag,
a mention or an issue link. GitHub takes at most 1 MiB per step; past BUDGET the list
gives titles only, then a count.

Run locally for any past range (the run's own page lasts as long as its logs):
    python3 scripts/release_notes.py --base <sha> --head <sha> [--repo owner/name]

Plan: doc/plans/release-notes-on-every-release-run-2026-11-01.html (R1–R4 A).
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

from github_text import text

BUDGET = 900_000
BOT = "github-actions[bot]"
TRAILER = re.compile(r"^[A-Za-z][A-Za-z0-9-]*: \S")
LEGACY_MERGE = re.compile(r"^Merge branch '([^']+)'")
LIST_ITEM = re.compile(r"^\s*(?:[-*]|\d+[.)])\s")


@dataclass
class Entry:
    """One commit on main's first-parent line."""

    sha: str
    kind: str  # "merge", "direct" or "workflow"
    title: str
    paragraphs: list[str] = field(default_factory=list)
    branch: str = ""
    branch_commits: list[str] = field(default_factory=list)
    late: bool = False


@dataclass
class Context:
    """What the run knows besides the commits."""

    base: str
    head: str
    repo: str = ""
    deployed: bool | None = None
    event: str = "workflow_run"
    actor: str = ""
    prod_at: str = ""
    ancestor: bool = True


def _git(*args: str) -> str:
    result = subprocess.run(["git", *args], text=True, capture_output=True, check=False)
    if result.returncode != 0:
        raise SystemExit(f"git {' '.join(args)}: {result.stderr.strip()}")
    return result.stdout


def _is_ancestor(base: str, head: str) -> bool:
    command = ["git", "merge-base", "--is-ancestor", base, head]
    return subprocess.run(command, capture_output=True, check=False).returncode == 0


def _paragraphs(body: str) -> list[str]:
    """The explanation without its closing trailer block, one string per paragraph."""
    blocks = [b.strip("\n") for b in re.split(r"\n\s*\n", body.strip()) if b.strip()]
    if blocks and all(TRAILER.match(line) for line in blocks[-1].splitlines()):
        blocks = blocks[:-1]
    return blocks


def _trailer(body: str, key: str) -> str:
    for line in reversed(body.strip().splitlines()):
        if line.startswith(f"{key}: "):
            return line.partition(": ")[2].strip()
    return ""


def _workflow_kind(subject: str) -> str:
    plain = subject.replace("[skip ci]", "").strip()
    plain = re.sub(r"^chore:\s*", "", plain)
    if "reconcile run log" in plain:
        return "reconcile log"
    if "export seed" in plain:
        return "seed export"
    return re.sub(r"^update\s+", "", plain)


def collect(base: str, head: str, gate_head: str = "") -> list[Entry]:
    """Every first-parent commit in base..head, oldest first."""
    late: set[str] = set()
    if gate_head and gate_head != head:
        late = set(_git("rev-list", "--first-parent", f"{gate_head}..{head}").split())
    entries: list[Entry] = []
    for sha in _git("rev-list", "--first-parent", "--reverse", f"{base}..{head}").split():
        parents, author, message = _git("log", "-1", "--format=%P%x00%an%x00%B", sha).split("\0", 2)
        subject, _, body = message.partition("\n")
        if author == BOT:
            entries.append(Entry(sha=sha, kind="workflow", title=_workflow_kind(subject)))
            continue
        entry = Entry(sha=sha, kind="direct", title=subject, late=sha in late)
        if len(parents.split()) > 1:
            entry.kind = "merge"
            entry.branch = _trailer(body, "Branch")
            if not entry.branch:
                legacy = LEGACY_MERGE.match(subject)
                entry.branch = legacy.group(1) if legacy else ""
                own = _git("log", "--reverse", "--format=%s", f"{sha}^1..{sha}^2")
                entry.branch_commits = [s for s in own.splitlines() if s]
        entry.paragraphs = _paragraphs(body)
        entries.append(entry)
    return entries


def _paragraph_html(paragraph: str) -> str:
    """Wrapped lines join with a space; a list item keeps its own line."""
    lines = paragraph.splitlines()
    out = text(lines[0].strip())
    for line in lines[1:]:
        out += ("<br>" if LIST_ITEM.match(line) else " ") + text(line.strip())
    return f"<p>{out}</p>"


def _commit_link(sha: str, repo: str) -> str:
    code = f"<code>{sha[:8]}</code>"
    return f'<a href="https://github.com/{repo}/commit/{sha}">{code}</a>' if repo else code


def _block(entry: Entry, repo: str, full: bool) -> str:
    late = " — reached main after this run's CI" if entry.late else ""
    parts = [f"<h3>{text(entry.title)} · {_commit_link(entry.sha, repo)}{late}</h3>"]
    if full:
        parts += [_paragraph_html(p) for p in entry.paragraphs]
        if entry.branch_commits:
            items = "".join(f"<li>{text(s)}</li>" for s in entry.branch_commits)
            parts.append(f"<p><sub>Branch: {text(entry.branch)} · its commits:</sub></p>")
            parts.append(f"<ul>{items}</ul>")
        elif entry.branch:
            parts.append(f"<p><sub>Branch: {text(entry.branch)}</sub></p>")
        elif entry.kind == "direct":
            parts.append("<p><sub>Pushed straight to main</sub></p>")
    return "\n\n".join(parts) + "\n\n"


def _count(n: int, one: str, many: str) -> str:
    return f"{n} {one if n == 1 else many}"


def _workflow_line(workflow: list[Entry]) -> str:
    kinds: dict[str, int] = {}
    for entry in workflow:
        kinds[entry.title] = kinds.get(entry.title, 0) + 1
    named = ", ".join(k if n == 1 else f"{k} ×{n}" for k, n in kinds.items())
    return f"{_count(len(workflow), 'commit the workflows pushed', 'commits the workflows pushed')} ({named})"


def _intro(entries: list[Entry], context: Context) -> str:
    sentences: list[str] = []
    if context.event == "workflow_dispatch":
        who = f" by <code>{text(context.actor)}</code>" if context.actor else ""
        sentences.append(
            f"Started by hand{who}: a manual start deploys whatever main holds (ADR-094)."
        )
    if not context.base:
        sentences.append(
            "The commit PROD last deployed is not recorded, so there is no range to list."
        )
        return " ".join(sentences)
    when = f" on {context.prod_at}" if context.prod_at else ""
    sentences.append(f"PROD last deployed <code>{context.base[:8]}</code>{when}.")
    if not context.ancestor:
        sentences.append(
            "That commit is not an ancestor of this one, so the list shows what this one has that it lacks."
        )
    merges = sum(e.kind == "merge" for e in entries)
    direct = sum(e.kind == "direct" for e in entries)
    workflow = [e for e in entries if e.kind == "workflow"]
    if not entries:
        sentences.append(
            f"Nothing has reached main since: PROD already runs <code>{context.head[:8]}</code>; "
            "this run deploys it again (ADR-094 fails open)."
        )
        return " ".join(sentences)
    found = [_count(merges, "merge", "merges")]
    if direct:
        found.append(
            _count(direct, "commit pushed straight to main", "commits pushed straight to main")
        )
    since = "Since then main has " + ", ".join(found)
    if workflow:
        since += ", plus " + _workflow_line(workflow)
    sentences.append(since + ".")
    if context.deployed is False:
        sentences.append(
            "Nothing is deployed by this run; these commits stay in the range until a release deploys."
        )
    if context.repo:
        compare = f"https://github.com/{context.repo}/compare/{context.base}...{context.head}"
        sentences.append(f'<a href="{compare}">Compare {context.base[:8]}…{context.head[:8]}</a>')
    return " ".join(sentences)


def render(entries: list[Entry], context: Context, budget: int = BUDGET) -> str:
    """The notes as HTML blocks that GitHub's Markdown passes through: full text up to
    `budget` bytes, then titles only up to a twentieth more, then a count."""
    limit = budget + budget // 20
    out = f"## What this release carries\n\n<p>{_intro(entries, context)}</p>\n\n"
    listed = [e for e in entries if e.kind != "workflow"]
    full = True
    for index, entry in enumerate(listed):
        block = _block(entry, context.repo, full)
        if full and len((out + block).encode("utf-8")) > budget:
            full = False
            out += (
                "<p><i>From here on, titles only: the full text would pass GitHub's limit "
                "of 1 MiB for one step. The compare link has every commit.</i></p>\n\n"
            )
            block = _block(entry, context.repo, full)
        if len((out + block).encode("utf-8")) > limit:
            out += f"<p><i>…and {len(listed) - index} more; the compare link has them.</i></p>\n"
            break
        out += block
    return out


def _prod_at(tracking: Path, base: str) -> str:
    """When PROD last deployed `base`, from the tracking file, or "" if it says otherwise."""
    try:
        prod = json.loads(tracking.read_text(encoding="utf-8")).get("prod", {})
        if prod.get("last_sha") != base or not prod.get("last_updated"):
            return ""
        at = datetime.datetime.fromisoformat(prod["last_updated"].replace("Z", "+00:00"))
    except (OSError, ValueError, AttributeError):
        return ""
    return f"{at.day} {at:%b %Y, %H:%M} UTC"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="What a Release run carries since PROD last deployed."
    )
    parser.add_argument(
        "--base", required=True, help="the commit PROD last deployed (may be empty)"
    )
    parser.add_argument("--head", required=True, help="the commit this run deploys")
    parser.add_argument("--gate-head", default="", help="the CI run's commit, when build moved on")
    parser.add_argument("--deployed", choices=["true", "false", ""], default="")
    parser.add_argument("--event", default="workflow_run")
    parser.add_argument("--actor", default="")
    parser.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY", ""))
    parser.add_argument("--tracking", type=Path, default=Path("deployed_migrations.json"))
    args = parser.parse_args(argv)

    context = Context(
        base=args.base,
        head=args.head,
        repo=args.repo,
        deployed={"true": True, "false": False}.get(args.deployed),
        event=args.event,
        actor=args.actor,
        prod_at=_prod_at(args.tracking, args.base) if args.base else "",
    )
    entries: list[Entry] = []
    if args.base:
        context.ancestor = _is_ancestor(args.base, args.head)
        entries = collect(args.base, args.head, args.gate_head)
    sys.stdout.write(render(entries, context))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
