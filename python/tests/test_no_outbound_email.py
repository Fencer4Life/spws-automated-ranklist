"""NOMAIL — the system has no outbound e-mail path (ADR-080 amendment 2026-10-24).

The FTL seed e-mail delivery was removed for good: the association holds no
registered sending identity, and the organizer downloads the seed files from the
capability-link page instead. These tests fail if that delivery, or any other
outbound e-mail code, comes back. Sending e-mail needs a new ADR first.
"""

from __future__ import annotations

import importlib.util
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = ROOT / ".github" / "workflows"
WHY = "outbound e-mail was removed (ADR-080 amendment 2026-10-24); a new ADR comes first"

_EMAIL_IMPORT = re.compile(r"^\s*(?:import|from)\s+(?:smtplib|email\.message|email\.mime)\b", re.M)


def test_NOMAIL_01_no_workflow_sends_or_schedules_email():
    """NOMAIL.01: the delivery workflow is gone and no workflow carries a mail credential,
    the deadline-sweep switch, the sender module or SMTP."""
    assert not (WORKFLOWS / "ftl-seed.yml").exists(), WHY
    for workflow in sorted(WORKFLOWS.glob("*.y*ml")):
        text = workflow.read_text(encoding="utf-8").lower()
        for needle in ("spws_gmail", "enable_ftl_deadline_send", "ftl_feed_seed_send", "smtp"):
            assert needle not in text, f"{workflow.name} names {needle}: {WHY}"


def test_NOMAIL_02_no_module_sends_email():
    """NOMAIL.02: the sender module is gone and no module outside the tests imports
    smtplib, email.message or email.mime."""
    assert importlib.util.find_spec("python.pipeline.ftl_feed_seed_send") is None, WHY
    offenders = [
        str(path.relative_to(ROOT))
        for base in (ROOT / "python", ROOT / "scripts")
        for path in sorted(base.rglob("*.py"))
        if "tests" not in path.relative_to(ROOT).parts
        and "__pycache__" not in path.parts
        and _EMAIL_IMPORT.search(path.read_text(encoding="utf-8"))
    ]
    assert offenders == [], f"{offenders}: {WHY}"


def test_NOMAIL_03_dispatch_endpoint_cannot_start_an_email_workflow():
    """NOMAIL.03: the dispatch-workflow allowlist names no delivery workflow, and every
    workflow it names exists."""
    edge = (ROOT / "supabase/functions/dispatch-workflow/index.ts").read_text(encoding="utf-8")
    allowlist = re.search(r"ALLOWED_WORKFLOWS = new Set\(\[(.*?)\]\)", edge, re.S)
    assert allowlist is not None, "ALLOWED_WORKFLOWS not found"
    names: list[str] = re.findall(r'"([^"]+\.yml)"', allowlist.group(1))
    assert names, "ALLOWED_WORKFLOWS is empty"
    assert "ftl-seed.yml" not in names, WHY
    for name in names:
        assert (WORKFLOWS / name).exists(), f"allowlisted {name} has no workflow file"


def test_NOMAIL_04_no_apps_script_mail_and_no_frontend_route_to_it():
    """NOMAIL.04: no Apps Script source sends mail, and the front end dispatches no
    delivery workflow."""
    for script in sorted((ROOT / "scripts").glob("*.js")):
        source = script.read_text(encoding="utf-8")
        for needle in ("GmailApp.sendEmail", "GmailApp.createDraft", "MailApp."):
            assert needle not in source, f"{script.name} calls {needle}: {WHY}"
    for path in sorted((ROOT / "frontend" / "src").rglob("*")):
        if path.suffix in {".ts", ".svelte", ".js"}:
            assert "ftl-seed.yml" not in path.read_text(encoding="utf-8"), (
                f"{path.relative_to(ROOT)} names ftl-seed.yml: {WHY}"
            )
