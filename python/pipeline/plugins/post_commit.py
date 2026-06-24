"""POST_COMMIT plugins — validate + notify + escalate (ADR-069/059/074).

Fired by the PostCommit reactor on `live.committed`. `ParticipantCount` is the
ADR-069 URL count validator, now a non-blocking fault (ADR-074). `Notify` sends
the Telegram summary and then escalates — `Escalate` is the "error plugin": it
sends Telegram ONLY for faults whose policy is ALWAYS, or ON_LOSS when an inline
fix actually dropped data. It is informational and never blocks.
"""

from __future__ import annotations

from python.pipeline.core.contract import Context, Fault, FaultKind, PluginKind, Services
from python.pipeline.plugins.base import BasePlugin
from python.pipeline.plugins.remediation import Escalation, escalation_for


def escalate_faults(ctx: Context, svc: Services) -> list[Fault]:
    """Return (and, if a notifier is present, send) the faults that need eyes.

    ALWAYS faults always escalate; ON_LOSS faults escalate only if the inline fix
    dropped data (`_dropped_brackets` non-empty). NEVER never escalates.
    """
    lost = bool(ctx.get("_dropped_brackets"))
    to_send: list[Fault] = []
    for fault in ctx.faults:
        policy = escalation_for(fault.kind)
        if policy == Escalation.ALWAYS or (policy == Escalation.ON_LOSS and lost):
            to_send.append(fault)
    notifier = svc.notifier
    if notifier is not None and to_send and hasattr(notifier, "send"):
        for fault in to_send:
            notifier.send(f"[escalate:{fault.kind.value}] {fault.plugin}: {fault.detail}")
    return to_send


class ParticipantCount(BasePlugin):
    """ADR-069 URL participant-count validator — now a fault, not a halt."""

    name = "ParticipantCount"
    kind = PluginKind.GATE
    reads = frozenset({"event"})

    def run(self, ctx: Context, svc: Services) -> None:
        cfg = svc.config or {}
        expected = cfg.get("url_participant_count")
        actual = cfg.get("committed_participant_count")
        if expected is not None and actual is not None and expected != actual:
            ctx.fault(FaultKind.COUNT_MISMATCH, f"URL {expected} != committed {actual}")
        self.report(ctx, "VALIDATION", check="participant_count", expected=expected, actual=actual)


class Notify(BasePlugin):
    """Telegram summary + last-resort escalation per REMEDIATIONBOOK policy."""

    name = "Notify"
    kind = PluginKind.MUTATOR
    reads = frozenset({"event"})
    effects = frozenset({"external"})

    def run(self, ctx: Context, svc: Services) -> None:
        notifier = svc.notifier
        sent = False
        if notifier is not None and hasattr(notifier, "send"):
            notifier.send(self._summary(ctx))
            sent = True
        escalated = escalate_faults(ctx, svc)
        self.report(ctx, "REACTION", sent=sent, escalated=[f.kind.value for f in escalated])

    @staticmethod
    def _summary(ctx: Context) -> str:
        committed = ctx.get("committed") or {}
        if committed.get("skipped"):
            return f"event committed: SKIPPED (dropped {committed.get('dropped')})"
        return f"event committed: {committed.get('vcat_groups', [])}"
