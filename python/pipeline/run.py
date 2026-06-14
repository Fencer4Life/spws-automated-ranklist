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
) -> Context:
    # Imported lazily so the registry can be patched/injected in tests.
    from python.pipeline.engine.rulebook import PLUGINS, RULEBOOK

    rulebook = rulebook if rulebook is not None else RULEBOOK
    plugins = plugins if plugins is not None else PLUGINS
    ctx = ctx if ctx is not None else Context()
    svc = svc if svc is not None else Services()

    plan = RuleEngine(rulebook, plugins).plan(params)
    return Orchestrator(middleware or []).execute(plan, ctx, svc)
