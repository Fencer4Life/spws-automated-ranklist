"""WFSETUP.01, WFRUN.01 — what a workflow job boots on is named, not left to a moving label.

WFSETUP.01 (N1 A on doc/plans/w2-follow-up-2026-10-25.html, 25 Oct 2026): every CI
and Release run warned that supabase/setup-cli@v1 targets Node.js 20, which GitHub
has deprecated. v3 is a composite action that needs no Node. The CLI version stays
pinned at one value in every use (ci.yml says why: it decides which Postgres boots).

WFRUN.01 (N2 A): `ubuntu-latest` moves to Ubuntu 26 from 19 October 2026 without
notice, so a release could change image mid-way. Every job names ubuntu-24.04, what
the runs used until then; a move to 26.04 is made deliberately, on a pull request.
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


def test_WFRUN_01_every_job_names_ubuntu_24_04():
    offenders = [
        f"{file}:{job_name} runs-on {job.get('runs-on')!r}"
        for file, job_name, job in _jobs()
        if "uses" not in job and job.get("runs-on") != "ubuntu-24.04"
    ]
    assert offenders == []
