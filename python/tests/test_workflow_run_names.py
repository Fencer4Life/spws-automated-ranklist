"""RUNNAME — an ingest and a promote run are titled by their event (ADR-119 §5, gap G6).

Neither workflow set a run name, so GitHub's Actions list read "Ingest event
(NEW pipeline, from URL)" twenty times over (31 Oct 2026). Each run now names
its event, the rule NAMING.01-07 set for CI and the Release.
"""

from pathlib import Path

import yaml

WORKFLOWS = Path(__file__).resolve().parents[2] / ".github" / "workflows"


def _run_name(name: str) -> str:
    return str(yaml.safe_load((WORKFLOWS / name).read_text(encoding="utf-8")).get("run-name") or "")


def test_RUNNAME_01_an_ingest_run_names_its_event():
    assert _run_name("ingest-event.yml") == "Ingest · ${{ inputs.event_code }}"


def test_RUNNAME_02_a_promote_run_names_its_event_and_a_dry_run():
    assert _run_name("promote.yml") == (
        "Promote · ${{ inputs.event_code }}${{ inputs.dry_run && ' · dry run' || '' }}"
    )
