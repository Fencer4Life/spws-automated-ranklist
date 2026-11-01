"""RELNOTES.01–11 — every Release run's Summary page says what it carries and deployed.

GitHub shows a merge commit's first line only, so a Release run's page held five job
boxes and nothing else, and a docs-only run's reason sat in the gate's log (31 Oct
2026). Plan doc/plans/release-notes-on-every-release-run-2026-11-01.html (R1–R4 A):
scripts/release_notes.py lists every commit since PROD last deployed in a `notes` job
no deploy waits for, and scripts/release-section.sh writes what CERT and PROD
deployed. The range and the gate's verdict are RELNOTES.12–13, in
test_release_docs_only_gate.py.

The script tests run in throwaway repositories, as test_release_docs_only_gate.py
builds them; the workflow tests read release.yml, as test_github_workflows_page.py does.
"""

from __future__ import annotations

import importlib.util
import os
import re
import subprocess
import sys
from pathlib import Path
from types import ModuleType
from typing import Any

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[2]
NOTES = ROOT / "scripts" / "release_notes.py"
SECTION = ROOT / "scripts" / "release-section.sh"
RELEASE = ROOT / ".github" / "workflows" / "release.yml"
SLUG = "owner/repo"
BOT = ("github-actions[bot]", "github-actions[bot]@users.noreply.github.com")
MIB = 1024 * 1024


def _git(repo: Path, *args: str, author: tuple[str, str] | None = None) -> str:
    env = {**os.environ}
    if author:
        env.update(
            GIT_AUTHOR_NAME=author[0],
            GIT_AUTHOR_EMAIL=author[1],
            GIT_COMMITTER_NAME=author[0],
            GIT_COMMITTER_EMAIL=author[1],
        )
    return subprocess.run(
        ["git", *args], cwd=repo, env=env, check=True, capture_output=True, text=True
    ).stdout.strip()


def _commit(repo: Path, path: str, message: str, *, author: tuple[str, str] | None = None) -> str:
    target = repo / path
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open("a", encoding="utf-8") as handle:
        handle.write(f"{message}\n")
    _git(repo, "add", "-A")
    _git(repo, "commit", "-q", "-m", message, author=author)
    return _git(repo, "rev-parse", "HEAD")


def _merge(repo: Path, branch: str, message: str, subjects: tuple[str, ...] = ("work",)) -> str:
    """A branch with its own commits, merged into main with `message`, as the integrate
    script does (--no-ff -F)."""
    _git(repo, "checkout", "-q", "-b", branch)
    for subject in subjects:
        _commit(repo, f"python/{branch.replace('/', '_')}.py", subject)
    _git(repo, "checkout", "-q", "main")
    message_file = repo.parent / "merge-message.txt"
    message_file.write_text(message, encoding="utf-8")
    _git(repo, "merge", "-q", "--no-ff", "-F", str(message_file), branch)
    return _git(repo, "rev-parse", "HEAD")


def _described(title: str, explanation: str, branch: str) -> str:
    return (
        f"{title}\n\n{explanation}\n\n"
        f"Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\nBranch: {branch}\n"
    )


@pytest.fixture
def repo(tmp_path: Path) -> Path:
    work = tmp_path / "repo"
    work.mkdir()
    _git(work, "init", "-q", "-b", "main")
    _git(work, "config", "user.email", "test@example.invalid")
    _git(work, "config", "user.name", "Test")
    _commit(work, "README.md", "baseline")
    return work


def _notes(repo: Path, *args: str) -> str:
    env = {**os.environ}
    env.pop("GITHUB_REPOSITORY", None)
    completed = subprocess.run(
        [sys.executable, str(NOTES), "--repo", SLUG, *args],
        cwd=repo,
        env=env,
        capture_output=True,
        text=True,
        timeout=60,
    )
    assert completed.returncode == 0, completed.stdout + completed.stderr
    return completed.stdout


def _module() -> ModuleType:
    spec = importlib.util.spec_from_file_location("release_notes", NOTES)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


# ─── What the list holds ─────────────────────────────────────────────


def test_RELNOTES_01_merges_oldest_first_with_title_explanation_and_branch(
    repo: Path,
) -> None:
    base = _git(repo, "rev-parse", "HEAD")
    (repo / "deployed_migrations.json").write_text(
        f'{{"prod": {{"last_sha": "{base}", "last_updated": "2026-11-01T09:00:26Z"}}}}\n'
    )
    merges = [
        _merge(
            repo,
            f"claude/change-number-{n}",
            _described(
                f"Change number {n}",
                f"Explanation {n} says why. It says what.",
                f"claude/change-number-{n}",
            ),
        )
        for n in (1, 2, 3)
    ]
    out = _notes(repo, "--base", base, "--head", merges[-1])
    positions = [out.index(f"Change number {n}") for n in (1, 2, 3)]
    assert positions == sorted(positions), out
    for n, sha in zip((1, 2, 3), merges, strict=True):
        assert f"Explanation {n} says why. It says what." in out
        assert f"Branch: claude/change-number-{n}" in out
        assert f"https://github.com/{SLUG}/commit/{sha}" in out
        assert f"<code>{sha[:8]}</code>" in out
    assert "Co-Authored-By" not in out and "noreply" not in out
    assert "3 merges" in out
    assert "1 Nov 2026, 09:00 UTC" in out
    assert f"https://github.com/{SLUG}/compare/{base}...{merges[-1]}" in out


def test_RELNOTES_02_workflow_commits_counted_and_a_direct_commit_listed(repo: Path) -> None:
    base = _git(repo, "rev-parse", "HEAD")
    _commit(repo, "deployed_migrations.json", "chore: update CERT tracking [skip ci]", author=BOT)
    _commit(repo, "deployed_migrations.json", "chore: update PROD tracking [skip ci]", author=BOT)
    _commit(repo, "log/a.json", "chore: CERT→PROD reconcile run log (PZSz) [skip ci]", author=BOT)
    _commit(repo, "log/b.json", "chore: CERT→PROD reconcile run log [skip ci]", author=BOT)
    _commit(
        repo,
        "frontend/public/annex.html",
        "Fix the annex's footnote\n\nThe footnote named the wrong season. It names 2026/27 now.",
    )
    head = _git(repo, "rev-parse", "HEAD")
    out = _notes(repo, "--base", base, "--head", head)
    assert "4 commits the workflows pushed (CERT tracking, PROD tracking, reconcile log ×2)" in out
    assert "chore:" not in out, out
    assert "Fix the annex's footnote" in out
    assert "The footnote named the wrong season. It names 2026/27 now." in out
    assert "Pushed straight to main" in out
    assert "1 commit pushed straight to main" in out


def test_RELNOTES_03_text_reaches_github_as_plain_text(repo: Path) -> None:
    """Release 3b's explanation (e7f8a3a3) holds `sync [<code>]`: as Markdown, GitHub
    would read a tag there. `@word` would link an account and `#4` an issue."""
    base = _git(repo, "rev-parse", "HEAD")
    head = _merge(
        repo,
        "claude/plain-text-reaches-github",
        _described(
            "Fix #12 for @owner & co",
            "Needs @types/node; see W2 #4. Telegram's sync [<code>] runs it & more.",
            "claude/plain-text-reaches-github",
        ),
    )
    out = _notes(repo, "--base", base, "--head", head)
    assert "@" not in out, out
    assert re.search(r"(?<!&)#\d", out) is None, out
    assert "<code>]" not in out
    assert "[&lt;code&gt;]" in out
    assert "&amp; more" in out and "&amp; co" in out
    assert "&#64;&#8288;types/node" in out and "&#64;&#8288;owner" in out
    assert "W2 &#35;&#8288;4" in out and "Fix &#35;&#8288;12" in out


def test_RELNOTES_04_a_merge_from_before_branch_lines(repo: Path) -> None:
    base = _git(repo, "rev-parse", "HEAD")
    head = _merge(
        repo,
        "claude/old-style",
        "Merge branch 'claude/old-style' into integration/main\n",
        subjects=("First step of the old change", "Second step of the old change"),
    )
    out = _notes(repo, "--base", base, "--head", head)
    assert "Branch: claude/old-style" in out
    first = out.index("First step of the old change")
    assert first < out.index("Second step of the old change")


def test_RELNOTES_05_merges_after_the_ci_run_are_marked(repo: Path) -> None:
    base = _git(repo, "rev-parse", "HEAD")
    gate_head = _merge(
        repo, "claude/seen-by-ci", _described("Seen by CI", "One. Two.", "claude/seen-by-ci")
    )
    head = _merge(
        repo, "claude/landed-later", _described("Landed later", "One. Two.", "claude/landed-later")
    )
    out = _notes(repo, "--base", base, "--head", head, "--gate-head", gate_head)
    later = out[out.index("Landed later") :]
    earlier = out[out.index("Seen by CI") : out.index("Landed later")]
    assert "reached main after this run's CI" in later
    assert "reached main after this run's CI" not in earlier


def test_RELNOTES_06_a_manual_start_and_nothing_new(repo: Path) -> None:
    head = _git(repo, "rev-parse", "HEAD")
    out = _notes(
        repo,
        "--base", head, "--head", head,
        "--event", "workflow_dispatch", "--actor", "Fencer4Life", "--deployed", "true",
    )  # fmt: skip
    assert "Started by hand by <code>Fencer4Life</code>" in out
    assert f"PROD already runs <code>{head[:8]}</code>; this run deploys it again" in out
    assert "/compare/" not in out


def test_RELNOTES_07_a_docs_only_range_deploys_nothing(repo: Path) -> None:
    base = _git(repo, "rev-parse", "HEAD")
    head = _merge(
        repo,
        "claude/docs-only-change",
        _described("Docs only", "One. Two.", "claude/docs-only-change"),
    )
    out = _notes(repo, "--base", base, "--head", head, "--deployed", "false")
    assert "Nothing is deployed by this run" in out
    assert "stay in the range until a release deploys" in out


def test_RELNOTES_07_an_unknown_base_says_so(repo: Path) -> None:
    head = _git(repo, "rev-parse", "HEAD")
    out = _notes(repo, "--base", "", "--head", head)
    assert "not recorded" in out


# ─── GitHub's 1 MiB per step ─────────────────────────────────────────


def test_RELNOTES_08_a_long_range_stays_under_one_mib() -> None:
    notes = _module()
    entries = [
        notes.Entry(
            sha=f"{n:040x}",
            kind="merge",
            title=f"Change {n:03d}",
            paragraphs=["word " * 1000],
            branch=f"claude/change-{n:03d}",
        )
        for n in range(300)
    ]
    context = notes.Context(base="a" * 40, head="b" * 40, repo=SLUG)
    out = notes.render(entries, context)
    assert len(out.encode("utf-8")) < MIB
    assert "titles only" in out
    for n in range(300):
        assert f"Change {n:03d}" in out


def test_RELNOTES_08_past_the_budget_every_commit_is_named_or_counted() -> None:
    notes = _module()
    entries = [
        notes.Entry(sha=f"{n:040x}", kind="merge", title=f"Change {n:03d}", paragraphs=["x"])
        for n in range(300)
    ]
    out = notes.render(entries, notes.Context(base="a" * 40, head="b" * 40), budget=4000)
    named = sum(f"Change {n:03d}" in out for n in range(300))
    more = re.search(r"and (\d+) more", out)
    assert more is not None, out
    assert named + int(more.group(1)) == 300


# ─── release.yml ─────────────────────────────────────────────────────


def _jobs() -> dict[str, Any]:
    return yaml.safe_load(RELEASE.read_text(encoding="utf-8"))["jobs"]


def _needs(job: dict[str, Any]) -> list[str]:
    needs = job.get("needs") or []
    return [needs] if isinstance(needs, str) else list(needs)


def _alerts(step: dict[str, Any]) -> bool:
    return "failure()" in str(step.get("if", "")) and "api.telegram.org" in str(step.get("run", ""))


def _writes_summary(step: dict[str, Any]) -> bool:
    run = str(step.get("run", ""))
    return "GITHUB_STEP_SUMMARY" in run or "release-section.sh" in run


def test_RELNOTES_09_the_notes_job_reads_only_and_nothing_waits_for_it() -> None:
    jobs = _jobs()
    notes = jobs["notes"]
    assert sorted(_needs(notes)) == ["build", "gate"]
    condition = str(notes.get("if", ""))
    assert "always()" in condition and "needs.gate.result == 'success'" in condition
    assert notes.get("permissions") == {"contents": "read"}
    checkout = notes["steps"][0]
    assert str(checkout.get("uses", "")).startswith("actions/checkout@")
    assert checkout.get("with", {}).get("fetch-depth") == 0
    assert any("scripts/release_notes.py" in str(s.get("run", "")) for s in notes["steps"])
    assert _alerts(notes["steps"][-1])
    assert [name for name, job in jobs.items() if "notes" in _needs(job)] == []


def test_RELNOTES_10_every_notes_value_arrives_through_env() -> None:
    jobs = _jobs()
    steps = [s for s in jobs["notes"]["steps"] if "run" in s]
    steps += [s for job in jobs.values() for s in job.get("steps") or [] if _writes_summary(s)]
    assert steps
    for step in steps:
        assert "${{" not in str(step["run"]), step.get("name")


def test_RELNOTES_11_pages_cert_and_prod_each_write_their_section() -> None:
    jobs = _jobs()
    pages = jobs["deploy-pages"]["steps"][-1]
    assert "always()" in str(pages.get("if", "")) and _writes_summary(pages)
    for name in ("deploy-cert", "deploy-prod"):
        steps = jobs[name]["steps"]
        assert _alerts(steps[-1]), f"{name}: the Telegram alert must stay last (WFALERT.01)"
        section = steps[-2]
        assert "always()" in str(section.get("if", "")), name
        assert "scripts/release-section.sh" in str(section.get("run", "")), name


def _section(tmp_path: Path, environment: str, **values: str) -> str:
    summary = tmp_path / "summary.md"
    summary.write_text("")
    env = {
        **os.environ,
        "GITHUB_STEP_SUMMARY": str(summary),
        "GITHUB_REPOSITORY": SLUG,
        "DEPLOYED_SHA": "e7f8a3a37dd266d00bab5fd37e915ebdad7cbd79",
        "FINGERPRINT": "17bf0b3531fcfb60ddaa56a88944d187",
        "HAS_NEW_MIGRATIONS": "false",
        "NEW_MIGRATIONS": "[]",
        "OUTCOME_CHECK": "success",
        "OUTCOME_APPLY": "skipped",
        "OUTCOME_VERIFY": "success",
        "OUTCOME_FUNCTIONS": "success",
        "OUTCOME_POSTURE": "success",
        "OUTCOME_RECORD": "success",
        **values,
    }
    completed = subprocess.run(
        ["bash", str(SECTION), environment],
        env=env,
        capture_output=True,
        text=True,
        timeout=60,
    )
    assert completed.returncode == 0, completed.stdout + completed.stderr
    return summary.read_text()


def test_RELNOTES_11_a_cert_deploy_without_migrations(tmp_path: Path) -> None:
    out = _section(tmp_path, "cert")
    assert "<b>CERT</b> runs" in out and "e7f8a3a3" in out
    assert "No new migration" in out
    assert "17bf0b35" in out and "matches the build" in out
    assert "Security posture verified" in out and "Recorded on main" in out
    assert "PROD waits for approval" in out


def test_RELNOTES_11_a_prod_deploy_with_migrations(tmp_path: Path) -> None:
    out = _section(
        tmp_path,
        "prod",
        HAS_NEW_MIGRATIONS="true",
        NEW_MIGRATIONS='["20261101000001_a.sql","20261101000002_b.sql"]',
        OUTCOME_APPLY="success",
        OUTCOME_VERIFY="skipped",
    )
    assert "<b>PROD</b> runs" in out
    assert "2 migrations applied" in out
    assert "20261101000001_a.sql" in out and "20261101000002_b.sql" in out
    assert "PROD waits" not in out


def test_RELNOTES_11_a_failed_step_is_named(tmp_path: Path) -> None:
    out = _section(
        tmp_path,
        "cert",
        HAS_NEW_MIGRATIONS="true",
        NEW_MIGRATIONS='["20261101000001_a.sql"]',
        OUTCOME_APPLY="failure",
        OUTCOME_VERIFY="skipped",
        OUTCOME_FUNCTIONS="skipped",
        OUTCOME_POSTURE="skipped",
        OUTCOME_RECORD="skipped",
    )
    assert "failed at: applying the migrations" in out
    assert "PROD was not deployed" in out
    assert "<b>CERT</b> runs" not in out
