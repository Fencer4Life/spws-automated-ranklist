"""
Tests for python/pipeline/types.py — Phase 3 (ADR-050) shared dataclasses.

Plan IDs P3.T1-P3.T8.
"""

from __future__ import annotations

import pytest


class TestHaltError:
    def test_halt_error_carries_reason_and_detail(self):
        """P3.T1 HaltError.reason and .detail are accessible."""
        from python.pipeline.types import HaltError, HaltReason
        err = HaltError(HaltReason.IR_INVALID, "missing parsed_date")
        assert err.reason == HaltReason.IR_INVALID
        assert err.detail == "missing parsed_date"
        assert "IR_INVALID" in str(err)
        assert "missing parsed_date" in str(err)


class TestOverrides:
    def test_empty_overrides_constructible(self):
        """P3.T2 Overrides() with no args constructs with empty defaults."""
        from python.pipeline.types import Overrides
        o = Overrides()
        assert o.identity == []
        assert o.splitter.birth_year_overrides == {}
        assert o.splitter.vcat_overrides == {}
        assert o.url is None
        assert o.match_method == []
        assert o.joint_pool == []

    def test_identity_for_case_insensitive_match(self):
        """P3.T3 identity_for() matches case-insensitively."""
        from python.pipeline.types import IdentityOverride, Overrides
        o = Overrides(identity=[IdentityOverride(scraped_name="J SMITH", id_fencer=42)])
        assert o.identity_for("j smith").id_fencer == 42
        assert o.identity_for("J Smith").id_fencer == 42
        assert o.identity_for("UNKNOWN") is None

    def test_match_method_for_lookup(self):
        """P3.T4 match_method_for() returns override if any."""
        from python.pipeline.types import MatchMethodOverride, Overrides
        o = Overrides(match_method=[
            MatchMethodOverride(scraped_name="X", force_method="PENDING"),
        ])
        assert o.match_method_for("x").force_method == "PENDING"
        assert o.match_method_for("y") is None

    def test_joint_pool_for_lookup(self):
        """P3.T5 joint_pool_for() finds by tournament_code."""
        from python.pipeline.types import JointPoolOverride, Overrides
        o = Overrides(joint_pool=[
            JointPoolOverride(tournament_code="A-V0", siblings=["A-V1"]),
        ])
        assert o.joint_pool_for("A-V0").siblings == ["A-V1"]
        assert o.joint_pool_for("B-V0") is None


class TestPipelineContext:
    def test_context_constructible_with_minimum(self):
        """P3.T6 PipelineContext constructs with parsed + overrides + season_end_year."""
        from python.pipeline.types import Overrides, PipelineContext
        ctx = PipelineContext(parsed=None, overrides=Overrides(), season_end_year=2026)
        assert ctx.event is None
        assert ctx.is_combined_pool is False
        assert ctx.splits is None
        assert ctx.matches == []
        assert ctx.warnings == []
        assert ctx.halted is False
        assert ctx.halted_at_stage is None

    def test_halted_property_reflects_halted_at_stage(self):
        """P3.T7 ctx.halted is True iff halted_at_stage is set."""
        from python.pipeline.types import HaltReason, Overrides, PipelineContext
        ctx = PipelineContext(parsed=None, overrides=Overrides(), season_end_year=2026)
        assert not ctx.halted
        ctx.halted_at_stage = "s3_detect_combined_pool"
        ctx.halt_reason = HaltReason.IR_INVALID
        assert ctx.halted

    def test_stage_match_result_holds_alternatives(self):
        """P3.T8 StageMatchResult.alternatives defaults to [] and accepts list of dicts."""
        from python.pipeline.types import StageMatchResult
        r = StageMatchResult(
            scraped_name="X", place=1, id_fencer=42,
            confidence=92.5, method="AUTO_MATCHED",
        )
        assert r.alternatives == []
        r.alternatives.append({"id_fencer": 99, "confidence": 88.0})
        assert len(r.alternatives) == 1
