"""WFALERT.01–03, WFPUSH.01 — a red workflow run reaches Telegram, and a push race retries.

GitHub marks a failed run red and tells nobody: Telegram is the channel this project
reads. A step guarded by ``if: failure()`` sees only the steps before it, so the alert
has to be a job's LAST step (or a later job that needs it). Before these tests:

- ``promote-season.yml`` had no alert at all;
- ``release.yml``'s build job had none, and each deploy job's only alert sat before its
  tracking push while saying "SECURITY POSTURE REGRESSION" for any earlier failure, such
  as a migration that failed to apply;
- ``pzsz-sync.yml`` and ``pzsz-start-lists.yml`` leave the alert to their Python run
  (one digest, ADR-116 §11–§12), so a failed install before it was silent;
- two alerts put raw log lines inside ``<pre>`` in HTML mode, and Telegram rejects a
  message holding a tag it does not know, such as ``<module>`` from a traceback;
- ``promote-season.yml`` and ``export-seed.yml`` pushed once, so a commit landing on
  ``main`` while they ran failed them.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import yaml

ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = ROOT / ".github" / "workflows"


def _specs() -> dict[str, dict[str, Any]]:
    return {
        p.name: yaml.safe_load(p.read_text(encoding="utf-8"))
        for p in sorted(WORKFLOWS.glob("*.yml"))
    }


def _jobs(spec: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return spec.get("jobs") or {}


def _steps(job: dict[str, Any]) -> list[dict[str, Any]]:
    return job.get("steps") or []


def _alerts_on_failure(block: dict[str, Any]) -> bool:
    """A step or job that runs after a failure and calls the Telegram Bot API."""
    condition = str(block.get("if", ""))
    body = str(block.get("run", "")) + str(block.get("steps", ""))
    return ("failure()" in condition or "always()" in condition) and "api.telegram.org" in body


def _writes(job: dict[str, Any]) -> bool:
    """A job that holds a credential other than Telegram's, or pushes to the repository."""
    text = str(job).replace("{", " ").replace("}", " ")
    secret = any(t.startswith("secrets.") and "TELEGRAM" not in t for t in text.split())
    return secret or "git push" in text


def _needs(job: dict[str, Any]) -> list[str]:
    needs = job.get("needs") or []
    return [needs] if isinstance(needs, str) else list(needs)


def test_WFALERT_01_every_writing_job_ends_in_a_failure_alert():
    silent: list[str] = []
    for name, spec in _specs().items():
        jobs = _jobs(spec)
        for job_name, job in jobs.items():
            if not _writes(job):
                continue
            steps = _steps(job)
            last_step_alerts = bool(steps) and _alerts_on_failure(steps[-1])
            later_job_alerts = any(
                job_name in _needs(other) and _alerts_on_failure(other) for other in jobs.values()
            )
            if not (last_step_alerts or later_job_alerts):
                silent.append(f"{name}:{job_name}")
    assert silent == []


def test_WFALERT_02_the_posture_alert_fires_for_the_posture_check_only():
    jobs = _jobs(_specs()["release.yml"])
    for job_name in ("deploy-cert", "deploy-prod"):
        steps = _steps(jobs[job_name])
        posture_ids = [
            s.get("id") for s in steps if "check-security-posture.sh" in str(s.get("run", ""))
        ]
        assert posture_ids and posture_ids[0], f"{job_name}: the posture step needs an id"
        (notify,) = [s for s in steps if "SECURITY POSTURE REGRESSION" in str(s.get("run", ""))]
        assert f"steps.{posture_ids[0]}.outcome == 'failure'" in str(notify.get("if", "")), job_name


def test_WFALERT_03_html_alerts_escape_the_log_lines_they_quote():
    raw: list[str] = []
    for name, spec in _specs().items():
        for job_name, job in _jobs(spec).items():
            for step in _steps(job):
                run = str(step.get("run", ""))
                if "parse_mode=HTML" in run and "tail " in run and "&lt;" not in run:
                    raw.append(f"{name}:{job_name}:{step.get('name')}")
    assert raw == []


def test_WFPUSH_01_every_push_retries_a_race():
    once: list[str] = []
    for name, spec in _specs().items():
        for job_name, job in _jobs(spec).items():
            for step in _steps(job):
                run = str(step.get("run", ""))
                if "git push" in run and "for attempt in" not in run:
                    once.append(f"{name}:{job_name}:{step.get('name')}")
    assert once == []
