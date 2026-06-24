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

from collections.abc import Callable
from datetime import UTC, datetime

# Module-level so a scheduled `main()` run can build a live connector, and tests
# can monkeypatch it. The heavy `supabase` import stays lazy inside the factory.
from python.pipeline.db_connector import create_db_connector

DEBOUNCE_WINDOW_SECONDS = 120  # ~2 min (design §11 knob)


def _default_run_recompute(id_event: int, *, db, svc=None) -> None:
    """Run RECOMPUTE_DOMESTIC for one event via the single entry point."""
    from python.pipeline.core.contract import Services
    from python.pipeline.engine.flows import Flow, FlowParams
    from python.pipeline.run import run_flow

    svc = svc or Services(db=db, config={})
    cfg = dict(svc.config or {})
    cfg["id_event"] = id_event
    run_flow(
        FlowParams(Flow.RECOMPUTE_DOMESTIC, id_event=id_event),
        svc=Services(db=db, config=cfg, notifier=svc.notifier),
    )


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
    now = now or datetime.now(UTC)
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


def main(argv: list[str] | None = None) -> int:
    """CLI entry for the scheduled self-heal drain (ADR-072, Step C scheduling).

    Invoked by `recompute-drain.yml` on a GitHub Actions cron against CERT (the
    repo's established scheduler pattern; the worker's own DEBOUNCE_WINDOW
    coalesces bursts, so a coarse cron is fine). LOCAL stays manual.
    """
    import argparse

    parser = argparse.ArgumentParser(
        description="Drain the recompute queue once if the roster is quiescent."
    )
    parser.add_argument(
        "--drain", action="store_true", help="Drain the queue once (required — the only action)."
    )
    parser.add_argument(
        "--debounce",
        type=int,
        default=DEBOUNCE_WINDOW_SECONDS,
        help="Seconds of roster quiet required before draining.",
    )
    args = parser.parse_args(argv)
    if not args.drain:
        parser.error("nothing to do; pass --drain")

    db = create_db_connector()
    events = drain_recompute_queue(db, debounce_window=args.debounce)
    if events:
        print(f"recomputed {len(events)} event(s): {events}")
    else:
        print("queue quiescent (nothing drained)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
