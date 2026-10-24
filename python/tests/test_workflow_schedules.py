"""WFCRON.01–02 — scheduled workflows avoid the start of the hour; the start-list flags follow the crons.

WFCRON.01: GitHub delays scheduled runs under load, most at the start of an hour, and
drops some (its documentation for the `schedule` event). Every cron here was set on the
hour; measured 10–24 Oct 2026 the daily runs started 4–9 hours late and the 15-minute
drains ran 5–6 times a day. No cron fires at minute 0.

WFCRON.02: pzsz-start-lists.yml tells the capture which run is the day's first and which
its final by the cron string that fired, so those strings are its earliest and latest crons.
"""

from __future__ import annotations

import re
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = ROOT / ".github" / "workflows"


def _crons() -> dict[str, list[str]]:
    out: dict[str, list[str]] = {}
    for path in sorted(WORKFLOWS.glob("*.yml")):
        spec = yaml.safe_load(path.read_text(encoding="utf-8"))
        on = spec.get(True, spec.get("on")) or {}
        if isinstance(on, dict) and on.get("schedule"):
            out[path.name] = [entry["cron"] for entry in on["schedule"]]
    return out


def _fires_at_minute_zero(minute_field: str) -> bool:
    for part in minute_field.split(","):
        if part == "*" or part == "0":
            return True
        step = re.fullmatch(r"(\*|\d+(?:-\d+)?)/(\d+)", part)
        if step:
            start = 0 if step.group(1) == "*" else int(step.group(1).split("-")[0])
            if start == 0:
                return True
        span = re.fullmatch(r"(\d+)-(\d+)", part)
        if span and int(span.group(1)) == 0:
            return True
    return False


def test_WFCRON_01_no_cron_fires_at_the_start_of_an_hour():
    crons = _crons()
    assert len(crons) >= 7
    on_the_hour = {
        f: [c for c in cs if _fires_at_minute_zero(c.split()[0])] for f, cs in crons.items()
    }
    assert {f: cs for f, cs in on_the_hour.items() if cs} == {}


def test_WFCRON_02_start_list_first_and_final_flags_name_its_own_crons():
    crons = sorted(
        _crons()["pzsz-start-lists.yml"], key=lambda c: (int(c.split()[1]), int(c.split()[0]))
    )
    workflow = (WORKFLOWS / "pzsz-start-lists.yml").read_text(encoding="utf-8")
    assert f'"{crons[0]}")  FLAGS="--first-run"' in workflow
    assert f'"{crons[-1]}") FLAGS="--final-run"' in workflow


def _cron_times(cron: str) -> set[str]:
    """Every HH:MM UTC a cron with plain minute and hour lists fires at."""
    minute, hour = cron.split()[:2]
    if not re.fullmatch(r"[\d,|]+", minute) or not re.fullmatch(r"[\d,|]+", hour):
        return set()
    return {
        f"{int(h):02d}:{int(m):02d}"
        for h in re.split(r"[,|]", hour)
        for m in re.split(r"[,|]", minute)
    }


def test_WFCRON_03_a_time_a_workflow_names_is_one_of_its_crons():
    """WFCRON.01 moved every cron off the hour; three comments kept the old hour
    ("Daily at 06:00 UTC" over a '23 6 * * *' cron). Any HH:MM UTC a scheduled
    workflow names must be a time one of its own crons fires at."""
    stale: list[str] = []
    for name, crons in _crons().items():
        times: set[str] = set().union(*(_cron_times(c) for c in crons))
        text = (WORKFLOWS / name).read_text(encoding="utf-8")
        for named in re.findall(r"\b(\d{1,2}:\d{2}) UTC\b", text):
            hour, minute = named.split(":")
            if f"{int(hour):02d}:{minute}" not in times:
                stale.append(f"{name}: {named} UTC")
    assert stale == []
