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


def test_RUNNAME_03_a_results_sync_run_says_what_started_it():
    """G32 A: a run's title is fixed before the select counts anything, so it
    says what started the run: "scheduled" (GitHub's cron, or the Telegram
    bot's hourly trigger, G47 A), the code of a manual run, or "manual" without
    one, and " · dry run" for a dry run. A cron run has no inputs, so its
    dry-run part is empty."""
    assert _run_name("results-sync.yml") == (
        "Results sync · ${{ (github.event_name == 'schedule' || inputs.scheduled) && 'scheduled'"
        " || inputs.event_code || 'manual' }}"
        "${{ inputs.dry_run && ' · dry run' || '' }}"
    )
