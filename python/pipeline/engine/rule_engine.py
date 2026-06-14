"""The RuleEngine: resolve a FlowParams into a DAG-validated ExecutionPlan (ADR-073).

Sequencing is **declarative and inspectable before execution**. `RuleEngine.plan`
looks up the flow's Rule, prunes steps by their plan-time `when` predicate, builds
an immutable `ExecutionPlan`, and validates the DAG (`reads` of every plugin must
be satisfied by the flow's seeds plus an earlier plugin's `writes`). Mis-ordering
therefore fails *before a single row is touched*.

`ExecutionPlan.plugins` returns the ordered objects from the registry — in M1 that
is metadata-only `PluginSpec`s for planning; the orchestrator consumes the same
shape once the registry holds runnable plugins (M2).
"""
from __future__ import annotations

from dataclasses import dataclass

from python.pipeline.engine.flows import Flow, FlowParams, Rule, Step


class PlanValidationError(Exception):
    """The resolved plan is not a valid DAG (a plugin reads an unproduced key)."""


@dataclass(frozen=True)
class ExecutionPlan:
    """Immutable, inspectable, DAG-validated ordered plan."""
    params: FlowParams
    flow: Flow
    steps: tuple[Step, ...]
    registry: dict
    seeds: frozenset[str] = frozenset()

    @property
    def names(self) -> list[str]:
        return [s.plugin for s in self.steps]

    @property
    def plugins(self) -> list:
        """Ordered registry objects (PluginSpec in M1, runnable plugins in M2)."""
        return [self.registry[s.plugin] for s in self.steps]

    def describe(self) -> str:
        """Render the resolved sequence WITHOUT running anything (no Services)."""
        return " → ".join(self.names)

    def validate_dag(self) -> None:
        available: set[str] = set(self.seeds)
        for step in self.steps:
            spec = self.registry.get(step.plugin)
            if spec is None:
                raise PlanValidationError(f"unknown plugin {step.plugin!r}")
            missing = set(spec.reads) - available
            if missing:
                raise PlanValidationError(
                    f"plugin {step.plugin!r} reads {sorted(missing)} not produced by "
                    f"an earlier plugin (available so far: {sorted(available)})"
                )
            available |= set(spec.writes)


class RuleEngine:
    """Executes a Rule from the RuleBook into an ExecutionPlan (plan time only)."""

    def __init__(self, rulebook: dict[Flow, Rule], plugins: dict) -> None:
        self.rulebook = rulebook
        self.plugins = plugins

    def plan(self, params: FlowParams) -> ExecutionPlan:
        rule = self.rulebook[params.flow]
        steps = tuple(s for s in rule.steps if s.when(params))  # plan-time pruning
        plan = ExecutionPlan(
            params, rule.flow, steps, self.plugins, frozenset(rule.seeds)
        )
        plan.validate_dag()  # reads ⊆ seeds ∪ earlier writes; fail fast
        return plan
