"""Every workflow that checks its event_code input accepts real event codes.

An event code carries lower-case weapon letters (ADR-046): ``PPS1s-2026-2027``,
``PEW16efs-2026-2027``. On 2026-10-06 ``ingest PPS1s-2026-2027`` from Telegram
failed at ingest-event.yml's input check, ``^[A-Z0-9_-]+$``, before anything ran.
The check exists to keep shell metacharacters out, so it still refuses those.
"""

import re
from pathlib import Path

WORKFLOWS = Path(__file__).resolve().parents[2] / ".github" / "workflows"
CHECK = re.compile(r'\[\[ "\$EVENT_CODE" =~ (\^\S+\$) \]\]')

REAL_CODES = (
    "PPS1s-2026-2027",
    "PEW16efs-2026-2027",
    "PEW2efs-2026-2027",
    "PPW1-2026-2027",
    "IMEW-2026-2027",
    "MPW-2025-2026",
)
REFUSED = ("PPW1-2026-2027; rm -rf /", "PPW1 2026", "PPW1'2026", "$(id)", "")


def _checks() -> list[tuple[str, str]]:
    found = []
    for wf in sorted(WORKFLOWS.glob("*.yml")):
        for pattern in CHECK.findall(wf.read_text(encoding="utf-8")):
            found.append((wf.name, pattern))
    return found


def test_event_code_checks_exist():
    """WF.CODE.01: the workflows that take an event code still check it."""
    names = {name for name, _ in _checks()}
    assert {"ingest-event.yml", "promote.yml", "regen-report.yml"} <= names, names


def test_event_code_checks_accept_weapon_suffixes():
    """WF.CODE.02: every event_code check accepts codes with lower-case weapon letters."""
    for name, pattern in _checks():
        for code in REAL_CODES:
            assert re.fullmatch(pattern, code), (name, pattern, code)


def test_event_code_checks_refuse_shell_text():
    """WF.CODE.03: every event_code check still refuses spaces, quotes and shell syntax."""
    for name, pattern in _checks():
        for text in REFUSED:
            assert not re.fullmatch(pattern, text), (name, pattern, text)
