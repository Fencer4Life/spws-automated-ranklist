"""WFSETUP.01, WFRUN.01 — what a workflow job boots on is named, not left to a moving label.

WFSETUP.01 (N1 A on doc/plans/w2-follow-up-2026-10-25.html, 25 Oct 2026): every CI
and Release run warned that supabase/setup-cli@v1 targets Node.js 20, which GitHub
has deprecated. v3 is a composite action that needs no Node. The CLI version stays
pinned at one value in every use (ci.yml says why: it decides which Postgres boots).

WFRUN.01 (N2 A): `ubuntu-latest` moves to Ubuntu 26 from 19 October 2026 without
notice, so a release could change image mid-way. Every job names ubuntu-24.04, what
the runs used until then; a move to 26.04 is made deliberately, on a pull request.

WFNODE.01 (the user, 25 Oct 2026: "lets bump up the Node.js version"): the Release
build warned that actions/configure-pages@v5 and actions/upload-artifact@v4 (inside
actions/upload-pages-artifact@v3) target Node.js 20, which GitHub has deprecated and
already overrides with Node 24; actions/deploy-pages@v4 targets it too. Node 20 itself
reached its end of life in April 2026, and the frontend was built and tested on it.
Every setup-node step now runs Node 24, and every action is at a release whose
action.yml runs on Node 24 or is a composite of such actions (read from each action's
repository, 25 Oct 2026). An action not in the table fails the test until its runtime
has been read and it is added.

WFNODE.02 (F11 on doc/plans/frontend-toolchain-before-after-2026-10-25.html): after
WFNODE.01 the logs still printed `[DEP0040] punycode` and `[DEP0169] url.parse()`, from
actions/setup-node@v5's own step and post-step. setup-node runs at a release that
prints neither.

WFSETUP.02 (F10 on doc/plans/frontend-toolchain-before-after-2026-10-25.html): CLI
2.116.0 warned in pgTAP, the build and both deploys that `[inbucket]` in
supabase/config.toml is deprecated. The section is `[local_smtp]`, with the same keys.

WFSETUP.03 (F12, same sheet): this Mac ran CLI 2.84.2 from Homebrew while CI pinned
2.116.0, so LOCAL booted other images than CI and nothing said so. Preflight now
fails unless the local CLI is the version every setup-cli step pins.
"""

from __future__ import annotations

import os
import subprocess
import sys
import tomllib
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = ROOT / ".github" / "workflows"
CLI_GATE = ROOT / "scripts" / "check_supabase_cli.py"


def _jobs() -> list[tuple[str, str, dict]]:
    jobs: list[tuple[str, str, dict]] = []
    for path in sorted(WORKFLOWS.glob("*.yml")):
        spec = yaml.safe_load(path.read_text(encoding="utf-8"))
        for name, job in (spec.get("jobs") or {}).items():
            jobs.append((path.name, name, job))
    return jobs


def test_WFSETUP_01_the_supabase_cli_comes_from_setup_cli_v3_at_one_pinned_version():
    uses = [
        (f"{file}:{job_name}", step)
        for file, job_name, job in _jobs()
        for step in job.get("steps") or []
        if str(step.get("uses", "")).startswith("supabase/setup-cli@")
    ]
    assert len(uses) == 4
    assert {step["uses"] for _, step in uses} == {"supabase/setup-cli@v3"}
    assert {str((step.get("with") or {}).get("version")) for _, step in uses} == {"2.116.0"}


# The first major of each action whose action.yml runs on Node 24 (or, for a
# composite, whose inner actions do).
NODE24_FROM = {
    "actions/checkout": 5,
    "actions/setup-node": 5,
    "actions/setup-python": 6,
    "actions/configure-pages": 6,
    "actions/upload-pages-artifact": 5,
    "actions/deploy-pages": 5,
    "supabase/setup-cli": 3,
}


def test_WFNODE_01_node_24_and_no_action_on_the_node_20_runtime():
    steps = [
        (f"{file}:{job_name}", step)
        for file, job_name, job in _jobs()
        for step in job.get("steps") or []
        if "uses" in step
    ]
    node = {
        str((step.get("with") or {}).get("node-version"))
        for _, step in steps
        if str(step["uses"]).startswith("actions/setup-node@")
    }
    assert node == {"24"}
    offenders = []
    for where, step in steps:
        action, _, ref = str(step["uses"]).partition("@")
        major = int(ref.lstrip("v").split(".")[0]) if ref.lstrip("v")[:1].isdigit() else -1
        if action not in NODE24_FROM or major < NODE24_FROM[action]:
            offenders.append(f"{where}: {step['uses']}")
    assert offenders == []


# The first major of an action whose own bundled code prints no Node deprecation on
# Node 24 (read from each release's dist, 25 Oct 2026). setup-node v5 bundles a cache
# library that requires the core punycode module (DEP0040) and an Azure SDK whose
# URLBuilder calls url.parse (DEP0169), both printed in every CI and Release job that
# sets up Node; v7.1.0 bundles neither. deploy-pages v5.0.1, the newest release,
# still requires punycode, so it is not listed until GitHub releases a fix.
QUIET_FROM = {"actions/setup-node": 7}


def test_WFNODE_02_no_action_at_a_release_that_prints_node_deprecations():
    offenders = []
    for file, job_name, job in _jobs():
        for step in job.get("steps") or []:
            action, _, ref = str(step.get("uses", "")).partition("@")
            if action in QUIET_FROM:
                major = int(ref.lstrip("v").split(".")[0]) if ref.lstrip("v")[:1].isdigit() else -1
                if major < QUIET_FROM[action]:
                    offenders.append(f"{file}:{job_name}: {step['uses']}")
    assert offenders == []


def test_WFRUN_01_every_job_names_ubuntu_24_04():
    offenders = [
        f"{file}:{job_name} runs-on {job.get('runs-on')!r}"
        for file, job_name, job in _jobs()
        if "uses" not in job and job.get("runs-on") != "ubuntu-24.04"
    ]
    assert offenders == []


def test_WFSETUP_02_config_toml_holds_no_section_the_pinned_cli_calls_deprecated():
    config = tomllib.loads((ROOT / "supabase" / "config.toml").read_text(encoding="utf-8"))
    assert "inbucket" not in config
    assert config["local_smtp"] == {"enabled": False, "port": 54324}


def test_WFSETUP_03_preflight_fails_unless_the_local_cli_is_the_pinned_one():
    preflight = (ROOT / "scripts" / "preflight.sh").read_text(encoding="utf-8")
    call = "python scripts/check_supabase_cli.py"
    assert call in preflight
    # Before the stack's own gates, and outside every mode-dependent block.
    at = preflight.index(call)
    assert at < preflight.index("bash scripts/check-postgrestools.sh")
    assert at < preflight.index("if [[ $FAST -eq 1 ]]")
    assert at < preflight.index("if [[ $CI_ONLY -eq 0 ]]")


def _fake(bin_dir: Path, name: str, body: str) -> None:
    path = bin_dir / name
    _ = path.write_text("#!/bin/sh\n" + body)
    path.chmod(0o755)


def _run_gate(
    tmp_path: Path, cli_version: str | None, ext_rows: str = "", db_up: bool = True
) -> subprocess.CompletedProcess[str]:
    """Run the gate with a fake CLI and a fake docker; docker's arguments land in docker.args."""
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir(parents=True)
    if cli_version is not None:
        _fake(
            bin_dir,
            "supabase",
            f'echo "{cli_version}"\necho "A new version of Supabase CLI is available" >&2\n',
        )
    # PATH holds only bin_dir, so the fakes use shell builtins alone.
    _fake(
        bin_dir,
        "docker",
        f'echo "$@" > "{tmp_path}/docker.args"\n'
        + (f"printf '%s' '{ext_rows}'\n" if db_up else 'echo "No such container" >&2\nexit 1\n'),
    )
    env = {**os.environ, "PATH": str(bin_dir)}
    return subprocess.run(
        [sys.executable, str(CLI_GATE)],
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )


@pytest.mark.parametrize(
    ("cli_version", "passes"),
    [("2.116.0", True), ("2.84.2", False), ("2.122.0", False), (None, False)],
)
def test_WFSETUP_03_the_gate_compares_the_local_cli_with_the_workflow_pin(
    tmp_path: Path, cli_version: str | None, passes: bool
):
    result = _run_gate(tmp_path, cli_version)
    assert (result.returncode == 0) is passes, result.stdout + result.stderr
    if not passes:
        assert "2.116.0" in result.stdout + result.stderr


def test_WFSETUP_04_the_gate_reads_the_database_of_this_project_s_stack(tmp_path: Path):
    result = _run_gate(tmp_path, "2.116.0")
    assert result.returncode == 0, result.stdout + result.stderr
    args = (tmp_path / "docker.args").read_text()
    # As the image's superuser: listing the library folder needs it.
    assert args.startswith("exec supabase_db_SPWSranklist psql -U supabase_admin -d postgres"), args


# Rows: name|schema|installed|image|update path|a member function's library is missing
def test_WFSETUP_04_an_extension_older_than_its_image_fails_with_its_update(tmp_path: Path):
    result = _run_gate(tmp_path, "2.116.0", "pgtap|extensions|1.3.2|1.3.3|t|f\n")
    out = result.stdout + result.stderr
    assert result.returncode == 1, out
    assert "pgtap 1.3.2, image 1.3.3" in out
    # As the owner: postgres is no superuser on Supabase's image, and its
    # ALTER EXTENSION fails with "pgaudit stack is not empty" (tried 25 Oct 2026).
    assert "psql -U supabase_admin -d postgres -c 'ALTER EXTENSION pgtap UPDATE'" in out


def test_WFSETUP_04_a_missing_library_fails_with_a_fresh_create_in_its_schema(tmp_path: Path):
    # F16: after the CLI switch LOCAL kept plpgsql_check 2.7, whose library
    # (plpgsql_check-2.7.so) the 2.116.0 image does not ship, so postgrestools
    # skipped plpgsql_check without a word. ALTER EXTENSION ... UPDATE moved the
    # version to 2.8 and left all 22 functions pointing at the old file.
    for i, row in enumerate(
        ("plpgsql_check|extensions|2.7|2.8|t|t\n", "plpgsql_check|extensions|2.8|2.8|t|t\n")
    ):
        result = _run_gate(tmp_path / str(i), "2.116.0", row)
        out = result.stdout + result.stderr
        assert result.returncode == 1, out
        assert "plpgsql_check" in out and "cannot load its library" in out
        assert (
            "psql -U supabase_admin -d postgres -1 -c 'DROP EXTENSION plpgsql_check'"
            " -c 'CREATE EXTENSION plpgsql_check WITH SCHEMA extensions'" in out
        )
        assert "UPDATE'" not in out


def test_WFSETUP_04_an_extension_with_no_update_path_names_both_ways_back(tmp_path: Path):
    result = _run_gate(tmp_path, "2.116.0", "pg_graphql|graphql|1.5.11|1.6.1|f|f\n")
    out = result.stdout + result.stderr
    assert result.returncode == 1, out
    assert "pg_graphql 1.5.11, image 1.6.1" in out and "no update path" in out
    assert (
        "psql -U supabase_admin -d postgres -1 -c 'DROP EXTENSION pg_graphql'"
        " -c 'CREATE EXTENSION pg_graphql WITH SCHEMA graphql'" in out
    )
    assert "./scripts/reset-dev.sh" in out


def test_WFSETUP_04_an_unreadable_database_fails(tmp_path: Path):
    result = _run_gate(tmp_path, "2.116.0", db_up=False)
    out = result.stdout + result.stderr
    assert result.returncode == 1, out
    assert "cannot read LOCAL's database" in out
