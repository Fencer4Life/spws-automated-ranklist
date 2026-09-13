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


def report_identity_overrides(db, *, notifier=None) -> int:
    """Announce every CONFIRMED birth year overwritten through the public form.

    Returns the number of alerts actually sent.

    These are PROPOSALS, not completed changes. A public caller cannot alter a
    confirmed birth year at all (migration 20260912000003) — `ADOPT_DECLARED` is
    a parameter rather than a click, so the server cannot tell a fencer pressing
    the button from a crafted RPC call, and the capability was removed instead
    of narrowed. What the caller can do is ask, and this is the asking reaching
    somebody who can answer.

    That makes the alert load-bearing rather than informational: until it is
    read, a genuine fencer's correction sits unapplied.

    Deliberately quiet otherwise: populating a NULL or correcting an estimate
    raises nothing. An alert that fires routinely is an alert nobody reads, and
    the one that matters would then arrive into a muted channel.

    The claim is what stamps the rows, so it happens even with no notifier
    configured (LOCAL has no Telegram token) — otherwise a developer's machine
    would accumulate a backlog that PROD then re-reports.
    """
    rows = db.claim_identity_override_alerts()
    if not rows:
        return 0

    sent = 0
    for r in rows:
        if notifier is None:
            continue
        try:
            notifier.warning(
                "Birth-year change PROPOSED from a public registration — "
                "nothing has been changed yet: "
                f"{r['txt_surname']} {r['txt_first_name']} (fencer #{r['id_fencer']}) "
                f"{r['int_birth_year_before']} -> {r['int_birth_year_after']}. "
                f"Approve or reject proposal #{r['id_override']}."
            )
            sent += 1
        except Exception:
            # The recompute is the load-bearing work here. Losing an alert is
            # bad; losing the self-heal that keeps the ranking consistent
            # because Telegram was down is worse.
            continue
    return sent


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

    # Reported BEFORE the drain and independently of it. An override always
    # enqueues a recompute, but the debounce can hold that queue for several
    # ticks — and the operator should not learn that a confirmed birth year was
    # rewritten only once the roster happens to go quiet.
    notifier = _build_notifier()
    overrides = report_identity_overrides(db, notifier=notifier)
    if overrides:
        print(f"reported {overrides} confirmed-birth-year override(s)")

    events = drain_recompute_queue(db, debounce_window=args.debounce)
    if events:
        print(f"recomputed {len(events)} event(s): {events}")
    else:
        print("queue quiescent (nothing drained)")
    return 0


def _build_notifier():
    """Telegram notifier from the environment, or None where it is unconfigured.

    None is the normal LOCAL case, not an error: the overrides are still claimed
    and printed, they simply are not pushed anywhere.
    """
    import os

    token = os.environ.get("TELEGRAM_BOT_TOKEN")
    chat_id = os.environ.get("TELEGRAM_CHAT_ID")
    if not token or not chat_id:
        return None
    from python.pipeline.notifications import TelegramNotifier

    return TelegramNotifier(token, chat_id)


if __name__ == "__main__":
    raise SystemExit(main())
