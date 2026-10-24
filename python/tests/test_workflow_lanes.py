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
