"""WFPIPE.01, WFINJ.01 — a workflow step fails when its command fails, and no input runs as code.

WFPIPE.01: a `run:` step without `shell:` runs under `bash -e`, without pipefail, so in
`python … | tee log` the step's status is tee's, always 0: scrape-tournament.yml and
populate-urls.yml stayed green, Telegram status "success", when their script failed. A step
that pipes into tee must run with `shell: bash` (GitHub's `bash -eo pipefail`).

WFINJ.01: `${{ inputs.x }}` inside a `run:` script is pasted into the script text before the
shell reads it, so an input with shell syntax would run as a command. Inputs reach a script
only through `env:`, where the shell sees them as data (GitHub's script-injection guidance).
"""

from __future__ import annotations

import re
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = ROOT / ".github" / "workflows"
INPUT_EXPR = re.compile(r"\$\{\{[^}]*\b(?:github\.event\.)?inputs\.\w+[^}]*\}\}")


def _steps() -> list[tuple[str, str, dict]]:
    steps: list[tuple[str, str, dict]] = []
    for path in sorted(WORKFLOWS.glob("*.yml")):
        spec = yaml.safe_load(path.read_text(encoding="utf-8"))
        for job_name, job in (spec.get("jobs") or {}).items():
            for step in job.get("steps") or []:
                if step.get("run"):
                    steps.append((path.name, f"{job_name}/{step.get('name', '?')}", step))
    return steps


def test_WFPIPE_01_a_step_piping_into_tee_fails_when_its_command_fails():
    offenders = [
        f"{file}:{where}"
        for file, where, step in _steps()
        if re.search(r"\|\s*tee\b", step["run"])
        and step.get("shell") != "bash"
        and "pipefail" not in step["run"]
    ]
    assert offenders == []


def test_WFINJ_01_no_script_expands_a_workflow_input():
    offenders = [
        f"{file}:{where}: {INPUT_EXPR.findall(step['run'])}"
        for file, where, step in _steps()
        if INPUT_EXPR.search(step["run"])
    ]
    assert offenders == []


def _pushes(job: dict) -> bool:
    runs = " ".join(str(step.get("run", "")) for step in job.get("steps") or [])
    return "git push" in runs or "commit-tracking.sh" in runs


def test_WFPERM_01_write_access_at_the_top_only_where_a_job_uses_it():
    """WFPERM.01 (ADR-083, least privilege): a top-level `contents: write` reaches every
    job that sets no permissions of its own, so it is there only if such a job pushes.
    evf-sync.yml kept it for "the reconcile run log", whose push had moved into the
    promote-calendar job, which grants itself write."""
    offenders: list[str] = []
    for path in sorted(WORKFLOWS.glob("*.yml")):
        spec = yaml.safe_load(path.read_text(encoding="utf-8"))
        if (spec.get("permissions") or {}).get("contents") != "write":
            continue
        inheriting = [j for j in (spec.get("jobs") or {}).values() if "permissions" not in j]
        if not any(_pushes(job) for job in inheriting):
            offenders.append(path.name)
    assert offenders == []
