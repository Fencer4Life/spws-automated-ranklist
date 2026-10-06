"""GAS.SRC / GAS.HELP: the Telegram bot has one Apps Script source, and its help matches it.

The live Apps Script project runs `scripts/gas_email_ingestion.js` verbatim (pasted
over the project's Code.gs). These checks keep the help a true list of what the bot
does: every command documented once, every documented command handled, every
workflow it starts declaring the inputs it sends, and every line naming where it acts.
"""

import os
import re
from collections import Counter
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
BOT = ROOT / "scripts" / "gas_email_ingestion.js"
WORKFLOWS = ROOT / ".github" / "workflows"
SKIP_DIRS = {".git", "node_modules", ".venv", "graphify-out", "archive", "dist", ".svelte-kit"}


def _source() -> str:
    return BOT.read_text(encoding="utf-8")


def _handled(src: str) -> list[str]:
    return re.findall(r"^\s*case '([a-z0-9-]+)':", src, re.M)


def _help_lines(src: str) -> list[str]:
    m = re.search(r"case 'help':\s*return \[(.*?)\]\.join", src, re.S)
    assert m, "the help block was not found"
    return re.findall(r"^\s*'((?:[^'\\]|\\.)*)',?\s*$", m.group(1), re.M)


def _help_entries(src: str) -> list[tuple[str, str]]:
    """(command, description) for each `<pre>command …</pre>` line and the line after it."""
    lines = _help_lines(src)
    entries = []
    for i, line in enumerate(lines):
        m = re.match(r"<pre>([a-z0-9-]+)\b.*</pre>$", line)
        if m:
            entries.append((m.group(1), lines[i + 1] if i + 1 < len(lines) else ""))
    return entries


def _dispatches(src: str) -> list[tuple[str, list[str]]]:
    calls = re.findall(
        r"triggerGitHubWorkflow\([^;]*?'([\w.-]+\.yml)'\s*,\s*(\{[^}]*\})", src, re.S
    )
    return [(wf, re.findall(r"(\w+)\s*:", inputs)) for wf, inputs in calls]


def _declared_inputs(workflow: str) -> list[str]:
    y = yaml.safe_load((WORKFLOWS / workflow).read_text(encoding="utf-8"))
    on = y.get("on", y.get(True)) or {}
    dispatch = (on.get("workflow_dispatch") if isinstance(on, dict) else None) or {}
    return list((dispatch.get("inputs") or {}).keys())


def _apps_script_sources() -> list[Path]:
    found = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            p = Path(dirpath) / name
            if name.endswith(".gs"):
                found.append(p)
            elif name.endswith(".js") and "function checkTelegramCommands(" in p.read_text(
                encoding="utf-8", errors="ignore"
            ):
                found.append(p)
    return sorted(found)


def test_one_apps_script_source():
    """GAS.SRC.01: scripts/gas_email_ingestion.js is the only Apps Script source."""
    assert BOT.exists()
    assert _apps_script_sources() == [BOT]


def test_source_keeps_the_live_behaviour():
    """GAS.SRC.02: re-ingest on CERT, the PROD refusal naming promote, exact codes."""
    src = _source()
    assert "'ingest-event.yml'" in src
    assert "A domestic event reaches PROD only through promote" in src
    assert "'promote.yml'" in src
    for entry in (
        "ingest &lt;EVENT-CODE&gt;</pre>",
        "promote &lt;exact code&gt;",
        "complete &lt;exact code&gt;",
    ):
        assert entry in src


def test_ingest_never_takes_a_url():
    """GAS.SRC.04: `ingest` sends the event code only; the URL is the event's own, set in Admin.

    The workflow reads tbl_event.url_event when its url_event input is blank, so the bot
    never sends one. A URL typed after the code is refused, not passed on.
    """
    src = _source()
    calls = [inputs for workflow, inputs in _dispatches(src) if workflow == "ingest-event.yml"]
    assert calls, "ingest-event.yml is not dispatched"
    for inputs in calls:
        assert "url_event" not in inputs, inputs
    assert "&lt;url&gt;" not in src
    assert "iUrl" not in src
    assert "The URL comes from the event" in src


def test_retired_commands_are_gone():
    """GAS.SRC.03: the never-deployed ADR-061 commands, `send` and the e-mail intake are gone."""
    src = _source()
    retired = {
        "stage",
        "regen",
        "parity",
        "verdict",
        "send",
        "staging",
        "cleanup",
        "pause",
        "resume",
    }
    assert retired.isdisjoint(_handled(src))
    for name in (
        "checkEmailForResults",
        "uploadToSupabaseStorage",
        "listStagingFiles",
        "cleanupStaging",
        "downloadFromSupabaseStorage",
        "sendTelegramDocument",
        "'ingest.yml'",
        "'ftl-seed.yml'",
    ):
        assert name not in src, name
    assert not (WORKFLOWS / "ingest.yml").exists()


def test_help_lists_exactly_the_handled_commands():
    """GAS.HELP.01: every handled command has one help entry; every entry is handled."""
    src = _source()
    handled = Counter(_handled(src))
    assert [c for c, n in handled.items() if n > 1] == []
    documented = Counter(cmd for cmd, _ in _help_entries(src))
    assert set(documented) == set(handled) - {"help"}
    assert [c for c, n in documented.items() if n > 1] == []


def test_every_dispatch_names_a_workflow_that_takes_its_inputs():
    """GAS.HELP.02: each workflow the bot starts exists and declares every input it is sent."""
    calls = _dispatches(_source())
    assert calls
    for workflow, inputs in calls:
        assert (WORKFLOWS / workflow).exists(), workflow
        undeclared = sorted(set(inputs) - set(_declared_inputs(workflow)))
        assert undeclared == [], (workflow, undeclared)


def test_every_help_line_names_where_it_acts():
    """GAS.HELP.03: each command's help line says CERT or PROD."""
    entries = _help_entries(_source())
    assert entries
    for cmd, description in entries:
        assert re.search(r"\b(CERT|PROD)\b", description), (cmd, description)


def test_help_fits_one_telegram_message():
    """GAS.HELP.04: help stays under the 4000 characters sendTelegramMessage keeps."""
    text = "\n".join(line.replace("\\'", "'") for line in _help_lines(_source()))
    assert "message.substring(0, 4000)" in _source()
    assert len(text) < 4000, len(text)
