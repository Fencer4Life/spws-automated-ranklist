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
"""

from __future__ import annotations

from pathlib import Path

import yaml

WORKFLOWS = Path(__file__).resolve().parents[2] / ".github" / "workflows"


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
