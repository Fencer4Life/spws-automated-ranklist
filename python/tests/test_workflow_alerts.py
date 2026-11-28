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

import subprocess
from pathlib import Path
from typing import Any

import yaml

ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = ROOT / ".github" / "workflows"
SEND = ROOT / "scripts" / "telegram-send.sh"
SEND_CALL = '"$GITHUB_WORKSPACE/scripts/telegram-send.sh"'


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
    """A step or job that runs after a failure and sends a Telegram message, which
    every workflow does through scripts/telegram-send.sh (LOG.PRIV.07)."""
    condition = str(block.get("if", ""))
    body = str(block.get("run", "")) + str(block.get("steps", ""))
    return ("failure()" in condition or "always()" in condition) and "telegram-send.sh" in body


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
    quoting = 0
    for name, spec in _specs().items():
        for job_name, job in _jobs(spec).items():
            for step in _steps(job):
                run = str(step.get("run", ""))
                html = "parse_mode=HTML" in run or 'telegram-send.sh" --html' in run
                if html and "tail " in run:
                    quoting += 1
                    if "&lt;" not in run:
                        raw.append(f"{name}:{job_name}:{step.get('name')}")
    assert quoting, "no HTML alert quotes a log: the check found nothing to check"
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


# --------------------------------------------------------------------------
# LOG.PRIV.07-08 — no run log prints Telegram's reply (mailbox errors plan of
# 2026-11-28, E5, D4 B). Telegram answers an accepted message with the chat it
# reached, the chat owner's first and last name included. GitHub hides the chat
# id, a secret, and not the name, and this repository's run logs are public.
# 11 of the 31 Telegram curl calls printed that answer.
# --------------------------------------------------------------------------


def test_LOG_PRIV_07_every_workflow_message_goes_through_the_shared_script():
    """LOG.PRIV.07: no workflow file writes Telegram's address; each Telegram step
    calls scripts/telegram-send.sh after its job's checkout, with the bot token and
    the chat id in the step's env and no Telegram secret in its run body."""
    addressed = [p.name for p in WORKFLOWS.glob("*.yml") if "api.telegram.org" in p.read_text()]
    assert addressed == []
    wrong: list[str] = []
    found = 0
    for name, spec in _specs().items():
        for job_name, job in _jobs(spec).items():
            checked_out = False
            for step in _steps(job):
                if "actions/checkout" in str(step.get("uses", "")):
                    checked_out = True
                run = str(step.get("run", ""))
                if "telegram-send.sh" not in run:
                    continue
                found += 1
                env = step.get("env") or {}
                where = f"{name}:{job_name}:{step.get('name')}"
                if SEND_CALL not in run:
                    wrong.append(f"{where}: not called as {SEND_CALL}")
                if "secrets." in run:
                    wrong.append(f"{where}: a secret in the run body")
                if env.get("TELEGRAM_BOT_TOKEN") != "${{ secrets.TELEGRAM_BOT_TOKEN }}":
                    wrong.append(f"{where}: TELEGRAM_BOT_TOKEN not in env")
                if env.get("TELEGRAM_CHAT_ID") != "${{ secrets.TELEGRAM_CHAT_ID }}":
                    wrong.append(f"{where}: TELEGRAM_CHAT_ID not in env")
                if not checked_out:
                    wrong.append(f"{where}: no checkout before the step")
    assert found, "no workflow step sends a Telegram message"
    assert wrong == []


TOKEN = "123456:harness-token"

FAKE_CURL = r"""#!/bin/bash
# Stands for curl: records its arguments, writes FAKE_BODY where -o points (or to
# stdout without -o), then prints FAKE_CODE as -w '%{http_code}' would.
out=""
prev=""
for a in "$@"; do
  if [ "$prev" = "-o" ]; then out="$a"; fi
  prev="$a"
  printf '%s\n' "$a" >> "$FAKE_ARGS"
done
if [ -n "$out" ]; then printf '%s' "$FAKE_BODY" > "$out"; else printf '%s' "$FAKE_BODY"; fi
printf '%s' "$FAKE_CODE"
"""


def _send(tmp_path: Path, code: int, body: str, *args: str) -> tuple[str, list[str], int]:
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir(parents=True)
    curl = bin_dir / "curl"
    curl.write_text(FAKE_CURL)
    curl.chmod(0o755)
    recorded = tmp_path / "args"
    env = {
        "PATH": f"{bin_dir}:/usr/bin:/bin",
        "TELEGRAM_BOT_TOKEN": TOKEN,
        "TELEGRAM_CHAT_ID": "42",
        "FAKE_CODE": str(code),
        "FAKE_BODY": body,
        "FAKE_ARGS": str(recorded),
    }
    done = subprocess.run(
        ["bash", str(SEND), *args], env=env, capture_output=True, text=True, timeout=30
    )
    sent = recorded.read_text().splitlines() if recorded.exists() else []
    return done.stdout + done.stderr, sent, done.returncode


def test_LOG_PRIV_08_the_script_prints_the_status_and_never_the_reply(tmp_path: Path):
    """LOG.PRIV.08: an accepted message prints its HTTP status only, never Telegram's
    reply and never the token; a refusal prints Telegram's reason, which names no one,
    so the run log says why a message did not arrive (TG.01-07). --html sends HTML."""
    reply = '{"ok":true,"result":{"chat":{"id":42,"first_name":"Ada","last_name":"Lovelace"}}}'
    printed, sent, code = _send(tmp_path / "ok", 200, reply, "--html", "<b>hello</b>")
    assert code == 0
    assert "HTTP 200" in printed
    assert "Lovelace" not in printed and "Ada" not in printed
    assert TOKEN not in printed
    assert "chat_id=42" in sent and "text=<b>hello</b>" in sent and "parse_mode=HTML" in sent

    refusal = '{"ok":false,"error_code":400,"description":"Bad Request: can\'t parse entities"}'
    printed, sent, code = _send(tmp_path / "refused", 400, refusal, "plain text")
    assert code == 0
    assert "HTTP 400" in printed and "can't parse entities" in printed
    assert "parse_mode=HTML" not in sent
    assert TOKEN not in printed
