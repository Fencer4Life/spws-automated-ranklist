"""GHWF.01–06 — the GitHub Actions workflows page describes every workflow, completely.

doc/handbook/reference/workflow-catalog.html ("GitHub Actions workflows") is the one page that says, for each
file in .github/workflows/, what it does, how often it runs, what it depends on, the
process it supports and what a red run usually means. A workflow added, removed or
renamed, a schedule changed, or a new call or shared lane without the page following
fails here, and so in preflight and CI. The release skill tells the author to update it.
"""

from __future__ import annotations

import re
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
PAGE = ROOT / "doc" / "handbook" / "reference" / "workflow-catalog.html"
WORKFLOWS = ROOT / ".github" / "workflows"
FIELDS = ("process", "often", "depends", "what", "red")
ROW = re.compile(r'<tbody id="wf-([a-z0-9-]+)" data-workflow="([^"]+)">(.*?)</tbody>', re.S)
CELL = re.compile(r'<(?:td|th)[^>]*data-field="([a-z]+)"[^>]*>(.*?)</(?:td|th)>', re.S)
TAG = re.compile(r"<[^>]+>")


def _text(fragment: str) -> str:
    return " ".join(TAG.sub(" ", fragment).split())


def _rows() -> dict[str, dict[str, str]]:
    html = PAGE.read_text(encoding="utf-8")
    rows: dict[str, dict[str, str]] = {}
    for stem, file, body in ROW.findall(html):
        assert stem == Path(file).stem, f"row id wf-{stem} does not match {file}"
        assert file not in rows, f"{file} has two rows"
        rows[file] = {field: inner for field, inner in CELL.findall(body)}
    return rows


def _workflow(file: str) -> dict:
    return yaml.safe_load((WORKFLOWS / file).read_text(encoding="utf-8"))


def _triggers(spec: dict) -> dict:
    on = spec.get(True, spec.get("on")) or {}
    return on if isinstance(on, dict) else {name: None for name in on}


def test_GHWF_01_one_row_per_workflow_file():
    files = sorted(p.name for p in WORKFLOWS.glob("*.yml"))
    assert sorted(_rows()) == files


def test_GHWF_02_row_names_the_file_and_its_workflow_name():
    for file, cells in _rows().items():
        name = _text(cells.get("name", ""))
        assert file in name, (file, name)
        assert str(_workflow(file)["name"]) in name, (file, name)


def test_GHWF_03_every_field_is_filled():
    for file, cells in _rows().items():
        for field in FIELDS:
            assert _text(cells.get(field, "")), f"{file}: empty {field}"
        assert len(_text(cells["what"])) >= 300, (
            f"{file}: 'What it does' is not an elaborate description"
        )
        assert len(_text(cells["red"])) >= 120, f"{file}: 'A red run usually means' is too thin"


def test_GHWF_04_every_schedule_is_stated():
    for file, cells in _rows().items():
        schedule = _triggers(_workflow(file)).get("schedule") or []
        for entry in schedule:
            assert f"<code>{entry['cron']}</code>" in cells["often"], (
                f"{file}: cron {entry['cron']} missing"
            )


def test_GHWF_05_calls_triggers_and_shared_lanes_are_stated():
    for file, cells in _rows().items():
        spec = _workflow(file)
        depends = _text(cells["depends"])
        needed: set[str] = set()
        run = _triggers(spec).get("workflow_run") or {}
        for source in run.get("workflows", []):
            needed |= {
                p.name for p in WORKFLOWS.glob("*.yml") if _workflow(p.name)["name"] == source
            }
        groups = [spec.get("concurrency")]
        for job in (spec.get("jobs") or {}).values():
            if isinstance(job.get("uses"), str) and job["uses"].startswith("./.github/workflows/"):
                needed.add(Path(job["uses"]).name)
            groups.append(job.get("concurrency"))
        for group in groups:
            if isinstance(group, dict):
                needed.add(group["group"])
        for item in sorted(needed):
            assert item in depends, f"{file}: 'Depends on' does not mention {item}"


def test_GHWF_06_release_skills_and_github_card_point_to_the_page():
    for skill in (".claude/skills/release/SKILL.md", ".agents/skills/release/SKILL.md"):
        assert "doc/handbook/reference/workflow-catalog.html" in (ROOT / skill).read_text(
            encoding="utf-8"
        ), skill
    context = (ROOT / "doc/handbook/architecture/system-context.html").read_text(encoding="utf-8")
    card = re.search(r"<small>Automation</small><h3>GitHub</h3>.*?</article>", context, re.S)
    assert card and 'href="../reference/workflow-catalog.html"' in card.group(0)
