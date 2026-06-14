"""NEW ingestion pipeline — plugin contract + orchestrator + run_flow.

Milestone 1 (core + engine), plan IDs N1.11–N1.18.
Maps to FR-112 / ADR-073 (architecture) and orchestrator-level FR-116 / ADR-074
(no hard halt: ctx.fault records and the run continues; only Abort breaks it).

These tests use test-double plugins so the orchestrator is exercised in
isolation from real domain logic (which lands in M2).
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Callable

import pytest

from python.pipeline.core.contract import (
    Abort,
    Context,
    FaultKind,
    Outcome,
    PluginKind,
    Services,
    WriteDisciplineError,
    compose,
)
from python.pipeline.core.orchestrator import Orchestrator
from python.pipeline.engine.flows import Flow, FlowParams
from python.pipeline.engine.rule_engine import ExecutionPlan
from python.pipeline import run as run_module


# ---------------------------------------------------------------------------
# Test-double plugin
# ---------------------------------------------------------------------------

@dataclass
class _Plugin:
    name: str
    reads: frozenset = field(default_factory=frozenset)
    writes: frozenset = field(default_factory=frozenset)
    effects: frozenset = field(default_factory=frozenset)
    kind: Any = PluginKind.TRANSFORM
    will_apply: bool = True
    body: Callable[[Context, Services], None] | None = None
    ran: bool = False

    def applies(self, ctx: Context) -> bool:
        return self.will_apply

    def run(self, ctx: Context, svc: Services) -> None:
        self.ran = True
        if self.body is not None:
            self.body(ctx, svc)


def _plan(plugins: list[_Plugin]) -> ExecutionPlan:
    from python.pipeline.engine.flows import Step

    registry = {p.name: p for p in plugins}
    steps = tuple(Step(p.name) for p in plugins)
    # generous seeds — orchestrator tests don't exercise DAG validation
    seeds = frozenset({"parsed", "event", "matches", "combined", "final_vcats"})
    return ExecutionPlan(
        FlowParams(Flow.INGEST_DOMESTIC), Flow.INGEST_DOMESTIC, steps, registry, seeds
    )


# ---------------------------------------------------------------------------
# Orchestrator behaviour
# ---------------------------------------------------------------------------

class TestOrchestrator:
    def test_skipped_when_not_applicable(self):
        """N1.11 applies()==False -> SKIPPED, run() never called."""
        p = _Plugin("Skip", will_apply=False)
        ctx = Orchestrator().execute(_plan([p]), Context(), Services())
        assert p.ran is False
        assert ctx.trace.outcome_of("Skip") == Outcome.SKIPPED

    def test_normal_plugin_runs_and_writes(self):
        """N1.12 a normal plugin -> RAN, declared writes land in ctx."""
        p = _Plugin("W", writes=frozenset({"matches"}),
                    body=lambda ctx, svc: ctx.set("matches", [1, 2, 3]))
        ctx = Orchestrator().execute(_plan([p]), Context(), Services())
        assert ctx.trace.outcome_of("W") == Outcome.RAN
        assert ctx.get("matches") == [1, 2, 3]

    def test_fault_does_not_halt_run(self):
        """N1.13 ctx.fault does not stop the run; later plugins still execute."""
        faulter = _Plugin("Gate",
                          body=lambda ctx, svc: ctx.fault(FaultKind.BELOW_MIN, "2<min"))
        after = _Plugin("After")
        ctx = Orchestrator().execute(_plan([faulter, after]), Context(), Services())
        assert ctx.trace.outcome_of("Gate") == Outcome.FAULT
        assert after.ran is True
        assert ctx.trace.outcome_of("After") == Outcome.RAN
        assert len(ctx.faults) == 1
        assert ctx.faults[0].kind == FaultKind.BELOW_MIN
        assert ctx.faults[0].plugin == "Gate"

    def test_abort_stops_run(self):
        """N1.14 Abort stops the run; later plugins are not executed."""
        def boom(ctx, svc):
            raise Abort("DbDown", "connection refused")

        aborter = _Plugin("DbDown", body=boom)
        after = _Plugin("After")
        ctx = Orchestrator().execute(_plan([aborter, after]), Context(), Services())
        assert ctx.trace.outcome_of("DbDown") == Outcome.ABORTED
        assert after.ran is False
        assert ctx.trace.outcome_of("After") is None

    def test_write_discipline_enforced(self):
        """N1.15 writing a key outside `writes` raises WriteDisciplineError."""
        rogue = _Plugin("Rogue", writes=frozenset(),
                        body=lambda ctx, svc: ctx.set("ghost", 1))
        with pytest.raises(WriteDisciplineError):
            Orchestrator().execute(_plan([rogue]), Context(), Services())

    def test_middleware_wraps_run_in_order(self):
        """N1.16 middleware compose wraps each run() outer-to-inner."""
        log: list[str] = []

        def mw_a(ctx, svc, nxt):
            log.append("A>")
            nxt(ctx, svc)
            log.append("A<")

        def mw_b(ctx, svc, nxt):
            log.append("B>")
            nxt(ctx, svc)
            log.append("B<")

        p = _Plugin("R", body=lambda ctx, svc: log.append("RUN"))
        Orchestrator(middleware=[mw_a, mw_b]).execute(_plan([p]), Context(), Services())
        assert log == ["A>", "B>", "RUN", "B<", "A<"]

    def test_warn_is_soft(self):
        """N1.17 ctx.warn records a diagnostic without changing the outcome."""
        p = _Plugin("Soft", body=lambda ctx, svc: ctx.warn("heads up"))
        ctx = Orchestrator().execute(_plan([p]), Context(), Services())
        assert ctx.warnings == ["heads up"]
        assert ctx.trace.outcome_of("Soft") == Outcome.RAN


# ---------------------------------------------------------------------------
# compose() unit
# ---------------------------------------------------------------------------

class TestCompose:
    def test_empty_middleware_is_identity(self):
        """N1.16 compose([]) returns the run callable unchanged in behaviour."""
        seen = []
        handler = compose([], lambda ctx, svc: seen.append("ran"))
        handler(Context(), Services())
        assert seen == ["ran"]


# ---------------------------------------------------------------------------
# run_flow end-to-end wiring
# ---------------------------------------------------------------------------

class TestRunFlow:
    def test_run_flow_wires_plan_and_execute(self):
        """N1.18 run_flow resolves a plan and executes it, tracing each plugin."""
        plugins = {
            "ParticipantCount": _Plugin("ParticipantCount", reads=frozenset({"event"})),
            "Notify": _Plugin("Notify", reads=frozenset({"event"}),
                              effects=frozenset({"external"})),
        }
        ctx = Context()
        ctx.data["event"] = {"id_event": 1}
        out = run_module.run_flow(
            FlowParams(Flow.POST_COMMIT), ctx=ctx, svc=Services(), plugins=plugins
        )
        assert out.trace.names == ["ParticipantCount", "Notify"]
        assert out.trace.outcome_of("ParticipantCount") == Outcome.RAN
        assert out.trace.outcome_of("Notify") == Outcome.RAN
