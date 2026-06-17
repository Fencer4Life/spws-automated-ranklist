"""NEW ingestion pipeline — rule engine + planner + DAG validation.

Milestone 1 (core + engine), plan IDs N1.1–N1.10.
Maps to FR-112 / ADR-073 (plugin + rule-engine architecture).

The planner resolves a Flow into an ordered, DAG-validated ExecutionPlan
*before* execution. These tests pin: exact resolved sequences (design §6.4),
the ResolveFencers-before-SplitByAge ordering enforced by data, plan-time
`when` pruning, and DAG rejection of mis-ordered / unsatisfiable rules.
"""
from __future__ import annotations

import pytest

from python.pipeline.core.contract import PluginKind
from python.pipeline.engine.flows import Flow, FlowParams, Rule, Step
from python.pipeline.engine.rulebook import PLUGINS, RULEBOOK, PluginSpec
from python.pipeline.engine.rule_engine import (
    ExecutionPlan,
    PlanValidationError,
    RuleEngine,
)


def _engine(rulebook=None, plugins=None) -> RuleEngine:
    return RuleEngine(rulebook or RULEBOOK, plugins or PLUGINS)


# ---------------------------------------------------------------------------
# Resolved sequences (design §6.4)
# ---------------------------------------------------------------------------

class TestResolvedSequences:
    def test_ingest_domestic_exact_sequence(self):
        """N1.1 plan(INGEST_DOMESTIC) -> exact 11-name ordered sequence."""
        plan = _engine().plan(FlowParams(Flow.INGEST_DOMESTIC))
        assert plan.names == [
            "ParseSource",
            "ValidateIR",
            "ResolveEvent",
            "ResolveFencers",
            "DetectCombinedPool",
            "SplitByAge",
            "DetectJointPool",
            "ValidateCounts",
            "DetectPoolRound",
            "AssignFinalVcat",
            "Commit",
        ]

    def test_resolve_fencers_before_split_and_commit(self):
        """N1.2 ResolveFencers < SplitByAge < Commit in the INGEST plan."""
        names = _engine().plan(FlowParams(Flow.INGEST_DOMESTIC)).names
        assert names.index("ResolveFencers") < names.index("SplitByAge")
        assert names.index("SplitByAge") < names.index("Commit")

    def test_recompute_domestic_sequence(self):
        """N1.3 plan(RECOMPUTE_DOMESTIC) -> LoadCommitted..Commit."""
        plan = _engine().plan(FlowParams(Flow.RECOMPUTE_DOMESTIC))
        assert plan.names == [
            "LoadCommitted",
            "AssignFinalVcat",
            "ValidateCounts",
            "Commit",
        ]

    def test_dedup_sweep_sequence(self):
        """N1.4 plan(DEDUP_SWEEP) -> ResolveFencers(whole_roster) -> Notify."""
        plan = _engine().plan(FlowParams(Flow.DEDUP_SWEEP))
        assert plan.names == ["ResolveFencers", "Notify"]
        # the whole-roster scope travels as a step param
        assert plan.steps[0].params.get("scope") == "whole_roster"

    def test_post_commit_sequence(self):
        """N1.5 plan(POST_COMMIT) -> ParticipantCount -> Notify -> StagingFormatter (ADR-075)."""
        plan = _engine().plan(FlowParams(Flow.POST_COMMIT))
        assert plan.names == ["ParticipantCount", "Notify", "StagingFormatter"]


# ---------------------------------------------------------------------------
# Inspectability + plan-time pruning
# ---------------------------------------------------------------------------

class TestInspectability:
    def test_describe_is_pure(self):
        """N1.6 plan.describe() returns the ordered names without DB/Services."""
        plan = _engine().plan(FlowParams(Flow.INGEST_DOMESTIC))
        described = plan.describe()
        assert described.startswith("ParseSource")
        assert "ResolveFencers" in described
        # describe is just string assembly over step names
        assert described == " → ".join(plan.names)

    def test_when_pruning_drops_gated_step(self):
        """N1.7 a plan-time `when` predicate drops a step for non-matching params."""
        evf_only = lambda p: p.organizer_hint == "EVF"  # noqa: E731
        rb = {
            Flow.INGEST_DOMESTIC: Rule(
                Flow.INGEST_DOMESTIC,
                "fixture: a gated ResolveEvent step",
                steps=(
                    Step("ParseSource"),
                    Step("ValidateIR"),
                    Step("ResolveEvent", when=evf_only),
                ),
            )
        }
        eng = _engine(rulebook=rb)
        domestic = eng.plan(FlowParams(Flow.INGEST_DOMESTIC, organizer_hint="SPWS"))
        assert "ResolveEvent" not in domestic.names
        intl = eng.plan(FlowParams(Flow.INGEST_DOMESTIC, organizer_hint="EVF"))
        assert "ResolveEvent" in intl.names


# ---------------------------------------------------------------------------
# DAG validation (reads subset of earlier writes)
# ---------------------------------------------------------------------------

class TestDagValidation:
    @pytest.mark.parametrize("flow", list(Flow))
    def test_all_real_flows_validate(self, flow):
        """N1.8 validate_dag accepts every real RULEBOOK flow."""
        plan = _engine().plan(FlowParams(flow))  # plan() validates internally
        plan.validate_dag()  # idempotent re-check

    def test_rejects_split_before_resolve_fencers(self):
        """N1.9 SplitByAge before ResolveFencers fails, naming `matches`."""
        rb = {
            Flow.INGEST_DOMESTIC: Rule(
                Flow.INGEST_DOMESTIC,
                "fixture: mis-ordered split-before-resolve",
                steps=(Step("ParseSource"), Step("SplitByAge"), Step("ResolveFencers")),
            )
        }
        with pytest.raises(PlanValidationError) as exc:
            _engine(rulebook=rb).plan(FlowParams(Flow.INGEST_DOMESTIC))
        assert "matches" in str(exc.value)
        assert "SplitByAge" in str(exc.value)

    def test_rejects_read_of_never_written_key(self):
        """N1.10 a plugin reading a key no plugin ever writes is rejected."""
        plugins = dict(PLUGINS)
        plugins["Ghost"] = PluginSpec(
            "Ghost", PluginKind.TRANSFORM, reads=frozenset({"nonexistent"})
        )
        rb = {
            Flow.INGEST_DOMESTIC: Rule(
                Flow.INGEST_DOMESTIC,
                "fixture: ghost reads an unproduced key",
                steps=(Step("ParseSource"), Step("Ghost")),
            )
        }
        with pytest.raises(PlanValidationError) as exc:
            _engine(rulebook=rb, plugins=plugins).plan(FlowParams(Flow.INGEST_DOMESTIC))
        assert "nonexistent" in str(exc.value)
