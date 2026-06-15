"""Debounced recompute worker (ADR-072, design §8).

Drains `tbl_recompute_queue` and runs `RECOMPUTE_DOMESTIC` per affected event —
but only once the roster has been **quiet ≥ DEBOUNCE_WINDOW** since the last
master-data edit, so a `DEDUP_SWEEP` touching many fencers coalesces into one
rerun per event instead of dozens. Convergent: the queue dedups by id_event and
recompute is idempotent, so the loop settles to a fixpoint.

Invoked periodically (pg_cron → Edge Function, ADR-041). Pure enough to unit-test:
the clock, the flow runner, and the DB are all injected.
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Callable

DEBOUNCE_WINDOW_SECONDS = 120  # ~2 min (design §11 knob)


def _default_run_recompute(id_event: int, *, db, svc=None) -> None:
    """Run RECOMPUTE_DOMESTIC for one event via the single entry point."""
    from python.pipeline.core.contract import Services
    from python.pipeline.engine.flows import Flow, FlowParams
    from python.pipeline.run import run_flow

    svc = svc or Services(db=db, config={})
    cfg = dict(svc.config or {})
    cfg["id_event"] = id_event
    run_flow(FlowParams(Flow.RECOMPUTE_DOMESTIC, id_event=id_event),
             svc=Services(db=db, config=cfg, notifier=svc.notifier))


def drain_recompute_queue(
    db,
    *,
    now: datetime | None = None,
    debounce_window: int = DEBOUNCE_WINDOW_SECONDS,
    run_recompute: Callable[..., None] | None = None,
    svc=None,
) -> list[int]:
    """Drain the queue if quiet long enough; recompute each affected event once.

    Returns the list of id_events recomputed (empty if still within the debounce
    window or the queue is empty — the quiescent state).
    """
    now = now or datetime.now(timezone.utc)
    watermark = db.recompute_watermark()
    if watermark is not None:
        if isinstance(watermark, str):
            watermark = datetime.fromisoformat(watermark.replace("Z", "+00:00"))
        if (now - watermark).total_seconds() < debounce_window:
            return []  # not quiet yet — hold for the next tick

    events = db.claim_recompute_batch()
    if not events:
        return []  # quiescent

    run = run_recompute or _default_run_recompute
    for id_event in events:
        run(id_event, db=db, svc=svc)
    db.mark_recompute_done(events)
    return events
