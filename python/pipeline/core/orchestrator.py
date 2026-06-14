"""The generic, domain-ignorant Orchestrator (ADR-073 / ADR-074).

It runs an ExecutionPlan **one direction only**, plugin by plugin:

    for plugin in plan.plugins:
        applies(ctx)?  -> SKIPPED
        else middleware-wrapped run(ctx, svc)
              -> FAULT if the plugin recorded a ctx.fault (run continued)
              -> RAN   otherwise
        Abort         -> ABORTED + break   (the ONLY thing that stops a run)

A plugin never calls another plugin or the orchestrator (Mediator pattern).
Faults never halt — they are recorded on the Context and resolved inline by the
REMEDIATIONBOOK in M2, so the flow always reaches Commit (ADR-074).
"""
from __future__ import annotations

from python.pipeline.core.contract import (
    Abort,
    Context,
    Middleware,
    Outcome,
    Services,
    compose,
)


class Orchestrator:
    def __init__(self, middleware: list[Middleware] | None = None) -> None:
        self.middleware = list(middleware or [])

    def execute(self, plan, ctx: Context, svc: Services) -> Context:
        for plugin in plan.plugins:
            if not plugin.applies(ctx):
                ctx.trace.record(plugin.name, Outcome.SKIPPED)
                continue

            ctx._begin(plugin)
            aborted = False
            try:
                compose(self.middleware, plugin.run)(ctx, svc)
            except Abort:
                aborted = True
            finally:
                faulted = ctx._end()

            if aborted:
                ctx.trace.record(plugin.name, Outcome.ABORTED)
                break  # genuine infra failure — stop; the run is retried, never gated
            ctx.trace.record(plugin.name, Outcome.FAULT if faulted else Outcome.RAN)

        return ctx
