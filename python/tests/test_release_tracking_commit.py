"""RELTRACK.01–05 — every deploy job applies the commit build fingerprinted, and records it on main.

``build`` checks out main and fingerprints it. ``deploy-cert`` checked out the
triggering commit and ``deploy-prod`` pulled main again after its approval wait, so
a migration that landed in between was applied without being fingerprinted: PROD
failed "Fingerprint mismatch after applying migrations" on 28 Aug 2026 (run
33143154193) and 5 Sep 2026 (run 33985677430), each time with the migration already
applied and the tracking left behind. Now ``build`` hands its commit on
(``outputs.sha``), both deploy jobs check out exactly that commit, and
``scripts/commit-tracking.sh`` writes the record on top of main as it is when the
deploy finishes, in a separate worktree, retrying when another push got there first.
"""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path
from typing import Any

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[2]
RELEASE = ROOT / ".github" / "workflows" / "release.yml"
SCRIPTS = ("commit-tracking.sh", "update-tracking.sh", "generate-manifest.sh")


def _git(repo: Path, *args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=repo, check=True, capture_output=True, text=True
    ).stdout.strip()


def _write(repo: Path, files: dict[str, str]) -> None:
    for relative, text in files.items():
        target = repo / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        _ = target.write_text(text)


def _commit(repo: Path, files: dict[str, str], message: str) -> str:
    _write(repo, files)
    _ = _git(repo, "add", "-A")
    _ = _git(repo, "commit", "-q", "-m", message)
    return _git(repo, "rev-parse", "HEAD")


TRACKING: dict[str, dict[str, Any]] = {
    "cert": {"last_sha": "c0", "applied": ["a.sql"], "schema_fingerprint": "f0"},
    "prod": {"last_sha": "p0", "applied": ["a.sql"], "schema_fingerprint": "f0"},
}
MANIFEST: dict[str, Any] = {
    "version": "0.0.1",
    "sha": "old",
    "migrations": {"total": 1, "new_since_last": []},
    "deployed": {
        "cert": {"at": None, "sha": "c0", "schema_fingerprint": "f0"},
        "prod": {"at": None, "sha": "p0", "schema_fingerprint": "f0"},
    },
}


@pytest.fixture
def world(tmp_path: Path) -> dict[str, Any]:
    """origin (bare) whose main moved past the deployed commit, and a runner on that commit."""
    origin = tmp_path / "origin.git"
    _ = subprocess.run(["git", "init", "-q", "--bare", "-b", "main", str(origin)], check=True)
    dev = tmp_path / "dev"
    _ = subprocess.run(
        ["git", "clone", "-q", str(origin), str(dev)], check=True, capture_output=True
    )
    _ = _git(dev, "config", "user.email", "dev@example.invalid")
    _ = _git(dev, "config", "user.name", "Dev")
    _ = _git(dev, "switch", "-q", "-c", "main")
    files = {f"scripts/{name}": (ROOT / "scripts" / name).read_text() for name in SCRIPTS}
    files |= {
        "pyproject.toml": 'version = "1.2.3"\n',
        "deployed_migrations.json": json.dumps(TRACKING, indent=2) + "\n",
        "release-manifest.json": json.dumps(MANIFEST, indent=2) + "\n",
        "supabase/migrations/a.sql": "-- a\n",
        "supabase/tests/t.sql": "SELECT plan(2);\n",
        "python/tests/test_x.py": "\n",
        "frontend/tests/x.test.ts": "\n",
    }
    _ = _commit(dev, files, "baseline")
    deployed = _commit(dev, {"supabase/migrations/b.sql": "-- b\n"}, "migration b")
    _ = _git(dev, "push", "-q", "origin", "main")
    # The runner: the deploy job's checkout of exactly the commit build fingerprinted.
    runner = tmp_path / "runner"
    _ = subprocess.run(
        ["git", "clone", "-q", str(origin), str(runner)], check=True, capture_output=True
    )
    _ = _git(runner, "checkout", "-q", "--detach", deployed)
    # Meanwhile main moves on: a later migration and a seed commit nobody deployed yet.
    moved = _commit(
        dev, {"supabase/migrations/c.sql": "-- c\n", "supabase/seed.sql": "x\n"}, "later"
    )
    _ = _git(dev, "push", "-q", "origin", "main")
    return {"origin": origin, "dev": dev, "runner": runner, "deployed": deployed, "moved": moved}


def _record(
    runner: Path, env: str, sha: str, applied: str, **extra: str
) -> subprocess.CompletedProcess[str]:
    environ = {**os.environ, "COMMIT_TRACKING_PAUSE": "0", **extra}
    return subprocess.run(
        ["bash", "scripts/commit-tracking.sh", env, sha, "fp1", applied],
        cwd=runner,
        env=environ,
        capture_output=True,
        text=True,
        timeout=120,
    )


def _main_file(world: dict[str, Any], name: str) -> dict[str, Any]:
    text = _git(world["origin"], "show", f"main:{name}")
    data: dict[str, Any] = json.loads(text)
    return data


def test_RELTRACK_01_deploy_jobs_apply_the_commit_build_fingerprinted() -> None:
    jobs: dict[str, Any] = yaml.safe_load(RELEASE.read_text())["jobs"]
    build_steps = jobs["build"]["steps"]
    assert "steps.head.outputs.sha" in str(jobs["build"]["outputs"]["sha"])
    (head,) = [s for s in build_steps if s.get("id") == "head"]
    assert "git rev-parse HEAD" in head["run"]
    for name in ("deploy-cert", "deploy-prod"):
        steps = jobs[name]["steps"]
        checkout = steps[0]
        assert checkout["uses"].startswith("actions/checkout@")
        assert checkout.get("with", {}).get("ref") == "${{ needs.build.outputs.sha }}", name
        runs = " ".join(str(s.get("run", "")) for s in steps)
        assert "git pull" not in runs, f"{name} moves its tree off the fingerprinted commit"
        (record,) = [s for s in steps if "scripts/commit-tracking.sh" in str(s.get("run", ""))]
        assert "needs.build.outputs.sha" in record["run"], name
        assert "has_new_migrations" not in str(record.get("if", "")), name


def test_RELTRACK_02_the_prod_record_lands_on_top_of_a_main_that_moved(
    world: dict[str, Any],
) -> None:
    result = _record(world["runner"], "prod", world["deployed"], '["b.sql"]')
    assert result.returncode == 0, result.stdout + result.stderr
    log = _git(world["origin"], "log", "--format=%s", "main", "-3").splitlines()
    assert log[0] == "chore: update PROD tracking [skip ci]"
    assert log[1] == "later", "the record must sit on top of what main already had"
    tracking = _main_file(world, "deployed_migrations.json")
    assert tracking["prod"]["last_sha"] == world["deployed"]
    assert tracking["prod"]["applied"] == ["a.sql", "b.sql"]
    assert tracking["cert"] == TRACKING["cert"]
    # The job's own tree stays the deployed commit.
    assert _git(world["runner"], "rev-parse", "HEAD") == world["deployed"]


def test_RELTRACK_03_the_cert_record_writes_the_manifest_of_the_deployed_tree(
    world: dict[str, Any],
) -> None:
    result = _record(world["runner"], "cert", world["deployed"], '["b.sql"]')
    assert result.returncode == 0, result.stdout + result.stderr
    manifest = _main_file(world, "release-manifest.json")
    assert manifest["version"] == "1.2.3"
    assert manifest["sha"] == world["deployed"]
    assert manifest["migrations"]["total"] == 2, (
        "a.sql and b.sql: the deployed tree, not main's c.sql"
    )
    assert manifest["schema_fingerprint"] == "fp1"
    assert manifest["deployed"]["cert"]["sha"] == world["deployed"]
    assert manifest["deployed"]["prod"] == MANIFEST["deployed"]["prod"]
    assert _main_file(world, "deployed_migrations.json")["cert"]["last_sha"] == world["deployed"]


def _reject_pushes(origin: Path, times: int) -> None:
    """A pre-receive hook refusing the next `times` pushes, as a concurrent push would."""
    counter = origin / "rejects-left"
    _ = counter.write_text(str(times))
    hook = origin / "hooks" / "pre-receive"
    _ = hook.write_text(
        "#!/bin/sh\n"
        f'n=$(cat "{counter}")\n'
        'if [ "$n" -gt 0 ]; then\n'
        f'  echo $((n - 1)) > "{counter}"\n'
        '  echo "rejected for the test" >&2\n'
        "  exit 1\n"
        "fi\n"
    )
    hook.chmod(0o755)


def test_RELTRACK_04_a_rejected_push_is_written_again_on_the_new_tip(world: dict[str, Any]) -> None:
    _reject_pushes(world["origin"], 1)
    result = _record(world["runner"], "prod", world["deployed"], "[]")
    assert result.returncode == 0, result.stdout + result.stderr
    assert "Pushed on attempt 2" in result.stdout
    subjects = _git(world["origin"], "log", "--format=%s", "main").splitlines()
    assert subjects.count("chore: update PROD tracking [skip ci]") == 1


def test_RELTRACK_05_it_gives_up_red_after_its_last_attempt(world: dict[str, Any]) -> None:
    _reject_pushes(world["origin"], 99)
    result = _record(world["runner"], "prod", world["deployed"], "[]", COMMIT_TRACKING_ATTEMPTS="2")
    assert result.returncode == 1
    assert "after 2 attempts" in result.stderr
    assert _git(world["origin"], "log", "-1", "--format=%s", "main") == "later"
