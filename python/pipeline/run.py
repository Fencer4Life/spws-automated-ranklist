"""`run_flow` — the single entry point for every scenario (ADR-073, design §8).

    run_flow(params) = RuleEngine.plan(params) -> Orchestrator.execute(plan, ctx, svc)

Every trigger (CLI, email→GAS, a tbl_fencer edit via the SelfHealing reactor,
pg_cron, the PostCommit reactor) funnels through here: pick the Flow, resolve a
plan, run it one direction. The rulebook / plugins / middleware are injectable so
tests can supply runnable doubles before the real plugins land (M2).
"""

from __future__ import annotations

from python.pipeline.core.contract import Context, Middleware, Services
from python.pipeline.core.orchestrator import Orchestrator
from python.pipeline.engine.flows import FlowParams
from python.pipeline.engine.rule_engine import RuleEngine


def run_flow(
    params: FlowParams,
    ctx: Context | None = None,
    svc: Services | None = None,
    *,
    rulebook: dict | None = None,
    plugins: dict | None = None,
    middleware: list[Middleware] | None = None,
    react: bool = True,
) -> Context:
    # Imported lazily so the registry can be patched/injected in tests.
    from python.pipeline.engine.rulebook import PLUGINS, RULEBOOK
    from python.pipeline.plugins.remediation import remediation_middleware

    rulebook = rulebook if rulebook is not None else RULEBOOK
    plugins = plugins if plugins is not None else PLUGINS
    ctx = ctx if ctx is not None else Context()
    svc = svc if svc is not None else Services()
    # No-halt: the REMEDIATIONBOOK middleware turns each fault into its inline fix
    # (ADR-074). Tests may pass an explicit middleware list to override.
    if middleware is None:
        middleware = [remediation_middleware]

    plan = RuleEngine(rulebook, plugins).plan(params)
    result = Orchestrator(middleware).execute(plan, ctx, svc)

    # PostCommit reactor (ADR-074, design §2.6): a committing flow emits
    # `live.committed` -> auto-fire POST_COMMIT (participant-count + Telegram
    # summary + per-policy escalation). No back-edge: POST_COMMIT has no Commit,
    # so it sets no `committed` and never re-fires -> the loop converges.
    if react:
        from python.pipeline.engine.flows import Flow
        from python.pipeline.reactors import (
            build_post_commit_context,
            should_react_post_commit,
        )

        if should_react_post_commit(params.flow, result, rulebook):
            child = build_post_commit_context(result)
            id_event = (result.get("event") or {}).get("id_event")
            result.data["_post_commit"] = run_flow(
                FlowParams(Flow.POST_COMMIT, id_event=id_event),
                ctx=child,
                svc=svc,
                rulebook=rulebook,
                plugins=plugins,
                middleware=middleware,
                react=False,
            )
    return result
