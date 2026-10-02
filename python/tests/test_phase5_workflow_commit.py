"""WF.P5.01 — the Phase 5 runner workflow commits a staged run on its target.

doc/plans/criterium-2026-add-on-all-environments-2026-10-02.html, decision P A.
CERT and PROD receive committed results by staging and committing with the
same runner as LOCAL: ``commit_run_id`` set means commit that run, through the
runner's sign-off checks and its replace path (rollback by exact event code
and commit, one transaction). ``promote.yml`` reaches the active season only,
so it cannot carry a past-season event. Every input reaches the shell through
the environment and is validated before use (ADR-083).
"""

from __future__ import annotations

import re
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github/workflows/phase5-event-runner.yml"


def _workflow() -> dict:
    return yaml.safe_load(WORKFLOW.read_text())


def _steps() -> list[dict]:
    jobs = _workflow()["jobs"]
    assert len(jobs) == 1
    return next(iter(jobs.values()))["steps"]


def _inputs() -> dict:
    # PyYAML reads the bare key `on` as True.
    trigger = _workflow().get("on") or _workflow()[True]
    return trigger["workflow_dispatch"]["inputs"]


def test_WF_P5_01_commit_run_id_is_an_optional_input():
    inputs = _inputs()
    assert inputs["commit_run_id"].get("required", False) is False
    assert inputs["commit_run_id"].get("default", "") == ""
    assert inputs["event_code"]["required"] is True


def test_WF_P5_01_a_run_id_is_validated_as_a_uuid_before_use():
    steps = _steps()
    names = [s.get("name", "") for s in steps]
    validate = steps[names.index("Validate inputs")]
    assert "COMMIT_RUN_ID" in validate["run"]
    assert re.search(r"\[0-9a-f\]\{8\}-\[0-9a-f\]\{4\}", validate["run"])
    first_use = min(i for i, s in enumerate(steps) if "--commit-run-id" in s.get("run", ""))
    assert names.index("Validate inputs") < first_use


def test_WF_P5_01_commit_mode_commits_the_run_through_the_replace_path():
    steps = _steps()
    commit = [s for s in steps if "--commit-run-id" in s.get("run", "")]
    stage = [s for s in steps if "--md-target storage" in s.get("run", "")]
    assert len(commit) == 1 and len(stage) == 1
    run = commit[0]["run"]
    assert '--commit-run-id "$COMMIT_RUN_ID"' in run
    assert '--event-code "$EVENT_CODE"' in run
    assert "--replace-event" in run
    assert "inputs.commit_run_id != ''" in commit[0]["if"]
    assert "inputs.commit_run_id == ''" in stage[0]["if"]
    # Both modes write to the target with its own service-role credentials.
    for step in (commit[0], stage[0]):
        assert "SUPABASE_PROD_SERVICE_ROLE_KEY" in step["env"]["SUPABASE_KEY"]
        assert "SUPABASE_CERT_SERVICE_ROLE_KEY" in step["env"]["SUPABASE_KEY"]


def test_WF_P5_01_no_input_is_interpolated_into_a_shell_script():
    for step in _steps():
        assert "${{ inputs." not in step.get("run", ""), step.get("name")
