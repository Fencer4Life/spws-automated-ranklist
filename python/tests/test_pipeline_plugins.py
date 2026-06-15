"""M2 — plugins wrap stages + no-halt + parity gate.

Plan IDs N2.1–N2.9. Maps to FR-112 (ADR-073 wiring) and FR-116 (ADR-074 no-halt:
former HaltErrors become non-blocking ctx.fault resolved inline via the
REMEDIATIONBOOK; the flow always reaches Commit; Escalate fires only per policy).

The parity gate proves the new plugin wiring drives the SAME stage functions on
the SAME bridged PipelineContext as today's `run_pipeline`, yielding an identical
context (real per-stage behaviour is already covered by test_pipeline_stages.py).
"""
from __future__ import annotations

from datetime import date
from unittest.mock import MagicMock

import pytest

from python.pipeline.core.contract import Context, FaultKind, Outcome, Services
from python.pipeline.engine.flows import Flow, FlowParams
from python.pipeline import run as run_module
from python.pipeline.types import HaltError, HaltReason, Overrides


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

def _make_parsed(results=None):
    from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind
    return ParsedTournament(
        source_kind=SourceKind.CERT_REF,
        results=results or [
            ParsedResult(source_row_id="t:1", fencer_name="KOWALSKI Jan", place=1,
                         birth_year=1970, fencer_country="POL"),
            ParsedResult(source_row_id="t:2", fencer_name="NOWAK Adam", place=2,
                         birth_year=1968, fencer_country="POL"),
        ],
        parsed_date=date(2026, 4, 1), weapon="EPEE", gender="M",
        organizer_hint="SPWS", category_hint="V1", raw_pool_size=2,
        season_end_year=2026,
    )


def _deterministic_stages(monkeypatch):
    """Patch every stage with a deterministic recorder that mutates pctx the same
    way regardless of call order, so run_pipeline and run_flow converge to an
    identical PipelineContext."""
    from python.pipeline import stages

    def stub(name):
        def fn(pctx, db):
            if name == "s2_resolve_event":
                pctx.event = {"id_event": 7, "txt_code": "PPW3-2025-2026", "enum_type": "PPW"}
            elif name == "s3_detect_combined_pool":
                pctx.is_combined_pool = False
            elif name == "s4_split_via_batch":
                pctx.splits = None
            elif name == "s5_detect_joint_pool":
                pctx.joint_pool_siblings = []
            elif name == "s6_resolve_identity":
                pctx.matches = [("KOWALSKI Jan", 1), ("NOWAK Adam", 2)]
            elif name == "s7_validate":
                pctx.count_validation = {"expected": 2, "actual": 2, "ok": True}
            elif name == "s7_split_by_vcat":
                pctx.vcat_groups = {"V1": [("KOWALSKI Jan", 1), ("NOWAK Adam", 2)]}
        return fn

    for name in ("s0_reconcile_roster", "s1_validate_ir", "s2_resolve_event",
                 "s3_detect_combined_pool", "s4_split_via_batch", "s5_detect_joint_pool",
                 "s6_resolve_identity", "s7_validate", "s7_pool_round_check",
                 "s7_split_by_vcat"):
        monkeypatch.setattr(stages, name, stub(name))


def _ingest(svc_config_extra=None, ctx=None):
    cfg = {"parsed": _make_parsed(), "overrides": Overrides(),
           "season_end_year": 2026, "event_code": "PPW3-2025-2026"}
    if svc_config_extra:
        cfg.update(svc_config_extra)
    svc = Services(db=MagicMock(), config=cfg)
    return run_module.run_flow(FlowParams(Flow.INGEST_DOMESTIC), ctx=ctx or Context(), svc=svc)


# ---------------------------------------------------------------------------
# Parity gate
# ---------------------------------------------------------------------------

class TestParityGate:
    def test_new_path_yields_same_pipeline_context(self, monkeypatch):
        """N2.1 run_flow(INGEST_DOMESTIC) drives the same stages to the same pctx."""
        _deterministic_stages(monkeypatch)
        from python.pipeline.orchestrator import run_pipeline

        old = run_pipeline(_make_parsed(), Overrides(), MagicMock(),
                           season_end_year=2026, event_code="PPW3-2025-2026")
        new_ctx = _ingest()
        new = new_ctx.get("_legacy")

        assert new.event == old.event
        assert new.is_combined_pool == old.is_combined_pool
        assert new.splits == old.splits
        assert new.joint_pool_siblings == old.joint_pool_siblings
        assert new.matches == old.matches
        assert new.count_validation == old.count_validation
        assert new.vcat_groups == old.vcat_groups

    def test_public_keys_mirror_pctx(self, monkeypatch):
        """N2.2 plugins mirror their bridged pctx field into the public Context key."""
        _deterministic_stages(monkeypatch)
        ctx = _ingest()
        assert ctx.get("event")["id_event"] == 7
        assert ctx.get("matches") == [("KOWALSKI Jan", 1), ("NOWAK Adam", 2)]
        assert ctx.get("combined") is False
        assert ctx.get("final_vcats") == {"V1": [("KOWALSKI Jan", 1), ("NOWAK Adam", 2)]}

    def test_flow_reaches_commit(self, monkeypatch):
        """N2.3 a clean INGEST run reaches Commit RAN with no faults."""
        _deterministic_stages(monkeypatch)
        ctx = _ingest()
        assert ctx.trace.outcome_of("Commit") == Outcome.RAN
        assert ctx.faults == []
        assert ctx.get("committed")["skipped"] is False


# ---------------------------------------------------------------------------
# No-halt: faults resolve inline, the flow still commits
# ---------------------------------------------------------------------------

class TestNoHalt:
    def test_splitter_halt_becomes_fault_and_continues(self, monkeypatch):
        """N2.4 a former SPLITTER_UNRESOLVED halt -> fault(keep_combined) -> Commit."""
        _deterministic_stages(monkeypatch)
        from python.pipeline import stages

        def boom(pctx, db):
            raise HaltError(HaltReason.SPLITTER_UNRESOLVED, "no birth_year")
        monkeypatch.setattr(stages, "s4_split_via_batch", boom)

        ctx = _ingest()
        assert ctx.trace.outcome_of("ResolveFencers") == Outcome.FAULT
        assert any(f.kind == FaultKind.SPLITTER_UNRESOLVED for f in ctx.faults)
        # keep_combined does not drop data, so the flow commits normally
        assert ctx.trace.outcome_of("Commit") == Outcome.RAN
        assert ctx.get("committed")["skipped"] is False

    def test_below_min_drops_bracket_then_commits(self, monkeypatch):
        """N2.5 below-min -> fault(BELOW_MIN) -> drop_bracket -> Commit skipped."""
        _deterministic_stages(monkeypatch)
        ctx = _ingest(svc_config_extra={"min_participants": 5})  # only 2 matched
        assert any(f.kind == FaultKind.BELOW_MIN for f in ctx.faults)
        assert ctx.trace.outcome_of("ValidateCounts") == Outcome.FAULT
        assert ctx.trace.outcome_of("Commit") == Outcome.RAN     # reaches Commit
        committed = ctx.get("committed")
        assert committed["skipped"] is True
        assert committed["dropped"]                              # data loss recorded

    def test_event_not_resolved_aborts(self, monkeypatch):
        """N2.6 EVENT_NOT_RESOLVED is unrecoverable -> Abort stops the run."""
        _deterministic_stages(monkeypatch)
        from python.pipeline import stages

        def boom(pctx, db):
            raise HaltError(HaltReason.EVENT_NOT_RESOLVED, "no such event")
        monkeypatch.setattr(stages, "s2_resolve_event", boom)

        ctx = _ingest()
        assert ctx.trace.outcome_of("ResolveEvent") == Outcome.ABORTED
        assert ctx.trace.outcome_of("Commit") is None  # never reached


# ---------------------------------------------------------------------------
# Escalation policy (Escalate = last-resort Telegram, never blocks)
# ---------------------------------------------------------------------------

class TestEscalationPolicy:
    def test_always_escalates_on_loss_only_with_loss(self):
        """N2.7 ALWAYS faults always escalate; ON_LOSS only when data was dropped."""
        from python.pipeline.core.contract import Fault
        from python.pipeline.plugins.post_commit import escalate_faults

        # With a drop recorded: COUNT_MISMATCH (ALWAYS) + BELOW_MIN (ON_LOSS) both fire
        ctx = Context()
        ctx.data["_dropped_brackets"] = ["V4 dropped"]
        ctx.faults.append(Fault("ValidateCounts", FaultKind.COUNT_MISMATCH, "x"))
        ctx.faults.append(Fault("ValidateCounts", FaultKind.BELOW_MIN, "y"))
        notifier = MagicMock()
        sent = escalate_faults(ctx, Services(notifier=notifier))
        kinds = {f.kind for f in sent}
        assert kinds == {FaultKind.COUNT_MISMATCH, FaultKind.BELOW_MIN}
        assert notifier.send.call_count == 2

    def test_on_loss_suppressed_without_loss(self):
        """N2.8 an ON_LOSS fault with no data drop does NOT escalate."""
        from python.pipeline.core.contract import Fault
        from python.pipeline.plugins.post_commit import escalate_faults

        ctx = Context()  # no _dropped_brackets
        ctx.faults.append(Fault("DetectPoolRound", FaultKind.POOL_ROUND, "z"))
        notifier = MagicMock()
        sent = escalate_faults(ctx, Services(notifier=notifier))
        assert sent == []
        notifier.send.assert_not_called()

    def test_escalation_is_post_commit_not_blocking(self, monkeypatch):
        """N2.9 escalation runs in POST_COMMIT/Notify, after commit — never blocks."""
        from python.pipeline.plugins.post_commit import Notify

        ctx = Context()
        ctx.data["event"] = {"id_event": 1}
        ctx.data["committed"] = {"skipped": False, "vcat_groups": ["V1"]}
        ctx.data["_dropped_brackets"] = []
        from python.pipeline.core.contract import Fault
        ctx.faults.append(Fault("ValidateCounts", FaultKind.COUNT_MISMATCH, "flag"))
        notifier = MagicMock()
        Notify().run(ctx, Services(notifier=notifier))
        # one summary + one escalation, and run() returned (did not raise/block)
        assert notifier.send.call_count == 2
