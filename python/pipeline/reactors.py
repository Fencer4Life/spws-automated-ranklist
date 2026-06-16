"""Reactors — turn a Mutator's signal into a new Flow, outside the plan (ADR-073/074).

A reactor observes a signal a committing flow emits and emits a follow-up Flow, with
**no back-edge** in the plan itself (design §2.6, §6). Step D realizes the
**PostCommit** reactor: when `INGEST_DOMESTIC` or `RECOMPUTE_DOMESTIC` reaches
`Commit` (which declares `effects=live` and records the `live.committed` signal in
its `committed` outcome), `run_flow` fires `POST_COMMIT` — the participant-count
check + Telegram summary + per-policy escalation — carrying over the committed
event, the faults, and any dropped brackets so the escalation policy (ALWAYS /
ON_LOSS) sees the same context the commit produced.

The loop converges with no back-edge: `POST_COMMIT` has no `Commit`, so it emits no
`live.committed` and never re-fires (`should_react_post_commit` returns False for it).
"""
from __future__ import annotations

from python.pipeline.core.contract import Context
from python.pipeline.engine.flows import Flow


def should_react_post_commit(flow: Flow, ctx: Context, rulebook: dict) -> bool:
    """True iff a committing flow produced a `committed` outcome (Commit's
    live.committed signal) and the rulebook offers a POST_COMMIT rule to fire.

    POST_COMMIT itself is excluded — it has no Commit, so it never re-fires; the
    rulebook guard keeps custom/partial rulebooks (tests, future flows) from
    triggering a plan they don't define.
    """
    if flow == Flow.POST_COMMIT:
        return False
    if Flow.POST_COMMIT not in rulebook:
        return False
    return ctx.get("committed") is not None


def build_post_commit_context(parent: Context) -> Context:
    """Seed a fresh Context for the POST_COMMIT run from the committed flow.

    Carries the committed `event` (the flow's seed), the `committed` outcome (for
    the Notify summary), the dropped-bracket record and the faults (so
    `escalate_faults` applies ALWAYS / ON_LOSS policy against the real loss).
    """
    child = Context()
    child.data["event"] = parent.get("event")
    child.data["committed"] = parent.get("committed")
    dropped = parent.get("_dropped_brackets")
    if dropped is not None:
        child.data["_dropped_brackets"] = list(dropped)
    child.faults = list(parent.faults)
    return child
