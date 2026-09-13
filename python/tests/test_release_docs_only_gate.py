"""ADR-094 — Release skips deployment when a CI run carried documentation only.

`release.yml` is driven by `workflow_run` on CI, whose payload has no `before`
SHA, so the deployable/non-deployable decision is made by
`scripts/release-gate.sh` over an explicit commit range. These tests pin both
the classifier's behaviour and the workflow wiring that consumes it.

The gate fails OPEN: anything it cannot classify with confidence deploys.
"""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
GATE = ROOT / "scripts/release-gate.sh"


def _git(repo: Path, *args: str) -> str:
    return subprocess.run(
        ["git", *args],
        cwd=repo,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def _commit(repo: Path, paths: list[str], message: str) -> str:
    """Write every path (creating parents) and commit them; return the SHA."""
    for relative in paths:
        target = repo / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(f"{message}\n")
    _git(repo, "add", "-A")
    _git(repo, "commit", "-m", message)
    return _git(repo, "rev-parse", "HEAD")


@pytest.fixture
def repo(tmp_path: Path) -> Path:
    """A throwaway git repo with one baseline commit."""
    work = tmp_path / "repo"
    work.mkdir()
    _git(work, "init", "-q", "-b", "main")
    _git(work, "config", "user.email", "test@example.invalid")
    _git(work, "config", "user.name", "Test")
    _commit(work, ["README.md", "python/app.py"], "baseline")
    return work


def _run_gate(repo: Path, tmp_path: Path, **env_overrides: str) -> tuple[str, str]:
    """Run the gate in `repo`; return (deploy output value, combined log)."""
    output_file = tmp_path / "github_output"
    output_file.write_text("")
    env = {
        **os.environ,
        "GITHUB_OUTPUT": str(output_file),
        "RELEASE_GATE_EVENT": "workflow_run",
        **env_overrides,
    }
    completed = subprocess.run(
        ["bash", str(GATE)],
        cwd=repo,
        env=env,
        capture_output=True,
        text=True,
        timeout=60,
    )
    log = completed.stdout + completed.stderr
    assert completed.returncode == 0, log
    values = dict(
        line.split("=", 1) for line in output_file.read_text().splitlines() if "=" in line
    )
    return values.get("deploy", ""), log


def _range_env(base: str, head: str) -> dict[str, str]:
    return {"RELEASE_GATE_BASE_SHA": base, "RELEASE_GATE_HEAD_SHA": head}


# ─── Classifier behaviour ────────────────────────────────────────────


def test_documentation_only_range_skips_deployment(repo: Path, tmp_path: Path) -> None:
    """A range touching only doc/ and root Markdown must not deploy."""
    base = _git(repo, "rev-parse", "HEAD")
    head = _commit(
        repo,
        ["doc/handbook/index.html", "doc/adr/094-release-gate.md", "CLAUDE.md"],
        "docs only",
    )
    deploy, log = _run_gate(repo, tmp_path, **_range_env(base, head))
    assert deploy == "false", log


def test_generated_html_twin_only_range_skips_deployment(repo: Path, tmp_path: Path) -> None:
    """The generated HTML side of the Markdown-source docs standard (ADR-082)
    is still under doc/ and still non-deployable — with NO .md file in the
    range, to prove the classifier keys on path prefix, not extension."""
    base = _git(repo, "rev-parse", "HEAD")
    head = _commit(
        repo,
        ["doc/handbook/index.html", "doc/adr/index.html", "doc/governance/index.html"],
        "regenerate HTML twins",
    )
    deploy, log = _run_gate(repo, tmp_path, **_range_env(base, head))
    assert deploy == "false", log


def test_mixed_documentation_and_code_deploys(repo: Path, tmp_path: Path) -> None:
    """One deployable path in the range is enough to release."""
    base = _git(repo, "rev-parse", "HEAD")
    head = _commit(repo, ["doc/handbook/index.html", "python/app.py"], "docs plus code")
    deploy, log = _run_gate(repo, tmp_path, **_range_env(base, head))
    assert deploy == "true", log


def test_migration_only_deploys(repo: Path, tmp_path: Path) -> None:
    """Schema changes are the whole point of the pipeline."""
    base = _git(repo, "rev-parse", "HEAD")
    head = _commit(repo, ["supabase/migrations/20260913000001_x.sql"], "migration")
    deploy, log = _run_gate(repo, tmp_path, **_range_env(base, head))
    assert deploy == "true", log


def test_published_static_page_under_frontend_deploys(repo: Path, tmp_path: Path) -> None:
    """frontend/public/*.html is shipped to Pages — it is not documentation."""
    base = _git(repo, "rev-parse", "HEAD")
    head = _commit(repo, ["frontend/public/tabela-punktacji.html"], "annex page edit")
    deploy, log = _run_gate(repo, tmp_path, **_range_env(base, head))
    assert deploy == "true", log


def test_workflow_file_change_deploys(repo: Path, tmp_path: Path) -> None:
    """Changing the pipeline itself must exercise the pipeline."""
    base = _git(repo, "rev-parse", "HEAD")
    head = _commit(repo, [".github/workflows/release.yml"], "workflow edit")
    deploy, log = _run_gate(repo, tmp_path, **_range_env(base, head))
    assert deploy == "true", log


# ─── Fail-open guarantees ────────────────────────────────────────────


def test_manual_dispatch_always_deploys(repo: Path, tmp_path: Path) -> None:
    """An operator asking for a release gets one, whatever the diff says."""
    base = _git(repo, "rev-parse", "HEAD")
    head = _commit(repo, ["doc/handbook/index.html"], "docs only")
    deploy, log = _run_gate(
        repo,
        tmp_path,
        RELEASE_GATE_EVENT="workflow_dispatch",
        **_range_env(base, head),
    )
    assert deploy == "true", log


def test_unresolvable_base_fails_open(repo: Path, tmp_path: Path) -> None:
    """No usable base commit means no confident verdict — deploy."""
    head = _commit(repo, ["doc/handbook/index.html"], "docs only")
    deploy, log = _run_gate(
        repo,
        tmp_path,
        RELEASE_GATE_BASE_SHA="0000000000000000000000000000000000000000",
        RELEASE_GATE_HEAD_SHA=head,
    )
    assert deploy == "true", log


def test_empty_base_fails_open(repo: Path, tmp_path: Path) -> None:
    """An unset base (first run, pruned history) deploys rather than guessing."""
    head = _commit(repo, ["doc/handbook/index.html"], "docs only")
    deploy, log = _run_gate(
        repo,
        tmp_path,
        RELEASE_GATE_BASE_SHA="",
        RELEASE_GATE_HEAD_SHA=head,
    )
    assert deploy == "true", log


def test_empty_diff_fails_open(repo: Path, tmp_path: Path) -> None:
    """Base equal to head yields no evidence of a docs-only change."""
    head = _git(repo, "rev-parse", "HEAD")
    deploy, log = _run_gate(repo, tmp_path, **_range_env(head, head))
    assert deploy == "true", log


# ─── Workflow wiring contract ────────────────────────────────────────


def test_release_workflow_gates_build_on_the_relevance_job() -> None:
    """release.yml must run the gate and hang the build off its verdict."""
    workflow = (ROOT / ".github/workflows/release.yml").read_text()

    assert "scripts/release-gate.sh" in workflow
    assert "gate:" in workflow
    assert "needs: gate" in workflow
    assert "needs.gate.outputs.deploy == 'true'" in workflow
    # Reading the previous CI run needs the Actions API.
    assert "actions: read" in workflow
    # The CI-conclusion condition moved onto the gate; build must not keep a
    # second copy that could let it run when the gate said no.
    assert workflow.count("github.event.workflow_run.conclusion == 'success'") == 1


def test_deploy_jobs_inherit_the_gate_through_build() -> None:
    """Every deploying job depends on build, so skipping build skips them all."""
    workflow = (ROOT / ".github/workflows/release.yml").read_text()

    assert "needs: build" in workflow
    assert "needs: [build, deploy-cert, deploy-pages]" in workflow
