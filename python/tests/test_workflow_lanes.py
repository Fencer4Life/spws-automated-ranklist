"""WFLANE.01 — every member of a lane two workflows share keeps its place in the queue.

A concurrency group is a lane: GitHub runs one job of it at a time. By default it keeps
only one waiting job per lane and cancels the older one when another arrives, and a
cancelled run alerts nobody. `queue: max` keeps every waiting job. prod-write set it on
every member; cert-write (ingest-event.yml, recompute-drain.yml) did not, so a waiting
ingest could be cancelled by the next drain. A lane used by one workflow only (release,
pzsz-start-lists) may keep the default: the newer run covers the older one.
"""

from __future__ import annotations

from collections import defaultdict
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = ROOT / ".github" / "workflows"


def _members() -> dict[str, list[tuple[str, dict[str, object]]]]:
    lanes: dict[str, list[tuple[str, dict[str, object]]]] = defaultdict(list)
    for path in sorted(WORKFLOWS.glob("*.yml")):
        spec = yaml.safe_load(path.read_text(encoding="utf-8"))
        blocks = [("(workflow)", spec.get("concurrency"))]
        blocks += [(name, job.get("concurrency")) for name, job in (spec.get("jobs") or {}).items()]
        for where, block in blocks:
            if isinstance(block, dict):
                lanes[str(block["group"])].append((f"{path.name}:{where}", block))
    return lanes


def test_WFLANE_01_shared_lanes_queue_every_waiting_job():
    lanes = _members()
    shared = {g: m for g, m in lanes.items() if len({w.split(":")[0] for w, _ in m}) > 1}
    assert {"prod-write", "cert-write"} <= set(shared)
    missing = [
        w for members in shared.values() for w, block in members if block.get("queue") != "max"
    ]
    assert missing == []
    cancelling = [
        w
        for members in shared.values()
        for w, block in members
        if block.get("cancel-in-progress") is not False
    ]
    assert cancelling == []


# --------------------------------------------------------------------------
# WFLANE.02, SYNC.CYCLE.07 — the results sync and the two workflows it calls
# (ADR-119 §4, S3, S4, S6, S8, G28 A)
# --------------------------------------------------------------------------


def _spec(name: str) -> dict:
    return yaml.safe_load((WORKFLOWS / name).read_text(encoding="utf-8"))


def _on(spec: dict) -> dict:
    """PyYAML reads the key `on` as True."""
    return spec.get("on") or spec.get(True) or {}


def _lane(job: dict) -> str | None:
    block = job.get("concurrency")
    return block.get("group") if isinstance(block, dict) else None


def _step(job: dict, step_id: str) -> dict:
    (step,) = [s for s in job.get("steps") or [] if s.get("id") == step_id]
    return step


def test_WFLANE_02_the_sync_and_the_two_workflows_it_calls():
    from python.pipeline.promotion import results_sync as rs

    ingest, promote, sync = (
        _spec("ingest-event.yml"),
        _spec("promote.yml"),
        _spec("results-sync.yml"),
    )
    for spec in (ingest, promote):
        assert {"workflow_dispatch", "workflow_call"} <= set(_on(spec))
    # A called workflow's job keeps its lane, queue: max included (WFLANE.01).
    assert _lane(ingest["jobs"]["ingest-event"]) == "cert-write"
    assert _lane(promote["jobs"]["promote"]) == "prod-write"
    on = _on(sync)
    assert [s["cron"] for s in on["schedule"]] == [rs.MORNING, rs.HOURLY]
    assert set(on["workflow_dispatch"]["inputs"]) == {"event_code", "dry_run"}
    # The sync itself holds no lane; the cycles take the called workflows' lanes.
    assert sync.get("concurrency") is None
    assert all(_lane(job) is None for job in sync["jobs"].values())


def test_SYNC_CYCLE_07_the_cycle_job_takes_one_event_at_a_time():
    cycle = _spec("results-sync.yml")["jobs"]["cycle"]
    assert cycle["uses"] == "./.github/workflows/ingest-event.yml"
    assert cycle["name"] == "${{ matrix.cycle.event_code }}"
    assert cycle["if"] == "needs.select.outputs.count != '0'"  # an empty matrix fails its job
    assert cycle["strategy"]["fail-fast"] is False and cycle["strategy"]["max-parallel"] == 1
    assert cycle["strategy"]["matrix"]["cycle"] == "${{ fromJSON(needs.select.outputs.events) }}"
    assert cycle["permissions"] == {"contents": "write"}  # promote's seed export pushes
    assert cycle["secrets"] == "inherit"
    assert cycle["with"]["mode"] == "sync"
    assert cycle["with"]["moment"] == "${{ needs.select.outputs.moment }}"


def test_SYNC_CYCLE_07_the_select_reads_the_switch_and_the_line_that_fired():
    select = _spec("results-sync.yml")["jobs"]["select"]
    env = _step(select, "select")["env"]
    assert env["RESULTS_SYNC"] == "${{ vars.RESULTS_SYNC }}"
    assert env["CRON"] == "${{ github.event.schedule }}"
    last = select["steps"][-1]
    assert "failure()" in last["if"] and "steps.select.outputs.reported != 'true'" in last["if"]


def test_SYNC_CYCLE_07_in_sync_mode_the_ingest_compares_first_and_is_quiet():
    job = _spec("ingest-event.yml")["jobs"]["ingest-event"]
    compare = _step(job, "compare")
    assert compare["if"] == "inputs.mode == 'sync'"
    assert "results_sync compare" in compare["run"]
    gate = "inputs.mode != 'sync' || (steps.compare.outputs.changed == 'true' && !inputs.dry_run)"
    (refresh,) = [s for s in job["steps"] if str(s.get("name", "")).startswith("Refresh CERT")]
    assert refresh["if"] == gate and _step(job, "ingest")["if"] == gate
    ingest = _step(job, "ingest")["run"]
    assert "--quiet" in ingest and "--send-telegram" in ingest  # one for each mode
    notify = job["steps"][-1]
    assert "inputs.mode != 'sync'" in notify["if"]  # sync mode: the outcome job speaks
    for key in ("changed", "promote_only", "previous_run", "new", "error", "run_id", "finished"):
        assert key in job["outputs"], key
    assert {"refresh_status", "refresh_counts", "gate"} <= set(job["outputs"])


def test_SYNC_CYCLE_07_promote_follows_a_finished_run_whose_gate_passed():
    jobs = _spec("ingest-event.yml")["jobs"]
    promote = jobs["promote"]
    assert promote["uses"] == "./.github/workflows/promote.yml"
    assert promote["permissions"] == {"contents": "write"}
    assert promote["secrets"] == "inherit" and promote["with"]["quiet"] is True
    for part in (
        "inputs.mode == 'sync'",
        "!inputs.dry_run",
        "needs.ingest-event.outputs.finished == 'true'",
        "needs.ingest-event.outputs.gate == 'passed'",
        "needs.ingest-event.outputs.promote_only == 'true'",
    ):
        assert part in promote["if"], part
    outcome = jobs["outcome"]
    assert outcome["needs"] == ["ingest-event", "promote"]
    assert "always()" in outcome["if"] and "inputs.mode == 'sync'" in outcome["if"]
    run = str(outcome["steps"])
    assert "python.pipeline.promotion.results_sync" in run and "ARGS=(outcome" in run
    assert "SYNC_PROMOTE_WRITES" in str(outcome["steps"])  # G30 A


def test_SYNC_CYCLE_07_a_called_promote_is_quiet_and_hands_back_its_writes():
    promote = _spec("promote.yml")
    call = _on(promote)["workflow_call"]
    assert {"event_code", "dry_run", "quiet"} <= set(call["inputs"])
    assert {"applied", "writes"} <= set(call["outputs"])
    assert promote["jobs"]["promote"]["outputs"]["writes"] == "${{ steps.replay.outputs.writes }}"
    assert "!inputs.quiet" in promote["jobs"]["notify"]["if"]
    assert "--quiet" in _step(promote["jobs"]["promote"], "replay")["run"]
