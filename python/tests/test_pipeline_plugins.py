"""M2/M3 — plugin wiring, no-halt fault resolution, escalation policy.

Plan IDs N2.1–N2.9. Maps to FR-112 (ADR-073 wiring) and FR-116 (ADR-074 no-halt).

Since M3 (ADR-070) the `ResolveFencers` plugin runs the REAL merged two-phase
identity logic (see test_resolve_fencers.py), so these tests drive it against a
proper fencer-db mock and stub only the still-wrapped stages (s1/s2/s5/s7/s7b/s7c).
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

def _make_parsed(results=None, category_hint="V1"):
    from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind
    return ParsedTournament(
        source_kind=SourceKind.CERT_REF,
        results=results or [
            ParsedResult(source_row_id="t:1", fencer_name="KOWALSKI Jan", place=1,
                         fencer_country="POL"),
            ParsedResult(source_row_id="t:2", fencer_name="NOWAK Adam", place=2,
                         fencer_country="POL"),
        ],
        parsed_date=date(2026, 4, 1), weapon="EPEE", gender="M",
        organizer_hint="SPWS", category_hint=category_hint, raw_pool_size=2,
        season_end_year=2026,
    )


def _fencer(id_, surname, first, by, gender="M"):
    return {"id_fencer": id_, "txt_surname": surname, "txt_first_name": first,
            "int_birth_year": by, "bool_birth_year_estimated": False,
            "txt_nationality": "POL", "enum_gender": gender, "json_name_aliases": []}


def _make_db(fencer_db):
    db = MagicMock()
    db.fetch_fencer_db.return_value = fencer_db
    db.fetch_birth_years_batch.return_value = {f["id_fencer"]: f["int_birth_year"]
                                               for f in fencer_db}
    db.ingest_results.return_value = {"inserted": len(fencer_db), "scored": True}
    return db


def _stub_wrapped_stages(monkeypatch):
    """Stub the still-wrapped stages so the chain runs without a live DB. Leaves
    ResolveFencers / DetectCombinedPool / SplitByAge to run their real M3 logic."""
    from python.pipeline import stages

    def stub(name):
        def fn(pctx, db):
            if name == "s2_resolve_event":
                pctx.event = {"id_event": 7, "txt_code": "PPW3-2025-2026", "enum_type": "PPW"}
            elif name == "s7_validate":
                pctx.count_validation = {"expected": 2, "actual": 2, "ok": True}
            elif name == "s7_split_by_vcat":
                pctx.vcat_groups = {"V1": list(pctx.matches)}
        return fn

    for name in ("s1_validate_ir", "s2_resolve_event", "s5_detect_joint_pool",
                 "s7_validate", "s7_pool_round_check", "s7_split_by_vcat"):
        monkeypatch.setattr(stages, name, stub(name))


def _ingest(monkeypatch, *, fencer_db=None, parsed=None, config_extra=None, ctx=None):
    _stub_wrapped_stages(monkeypatch)
    fencer_db = fencer_db if fencer_db is not None else [
        _fencer(101, "KOWALSKI", "Jan", 1980), _fencer(102, "NOWAK", "Adam", 1982)]
    cfg = {"parsed": parsed or _make_parsed(), "overrides": Overrides(),
           "season_end_year": 2026, "event_code": "PPW3-2025-2026"}
    if config_extra:
        cfg.update(config_extra)
    svc = Services(db=_make_db(fencer_db), config=cfg)
    return run_module.run_flow(FlowParams(Flow.INGEST_DOMESTIC), ctx=ctx or Context(), svc=svc)


# ---------------------------------------------------------------------------
# Happy path through the real chain
# ---------------------------------------------------------------------------

class TestHappyPath:
    def test_all_exact_matched(self, monkeypatch):
        """N2.1 a domestic bracket of known fencers resolves all to AUTO_MATCHED."""
        ctx = _ingest(monkeypatch)
        matches = ctx.get("matches")
        assert [m.id_fencer for m in matches] == [101, 102]
        assert all(m.method == "AUTO_MATCHED" for m in matches)
        assert [m.governed_birth_year for m in matches] == [1980, 1982]

    def test_public_keys_mirror_pctx(self, monkeypatch):
        """N2.2 plugins mirror their bridged pctx field into the public Context key."""
        ctx = _ingest(monkeypatch)
        assert ctx.get("event")["id_event"] == 7
        assert ctx.get("matches") == ctx.get("_legacy").matches
        assert ctx.get("combined") is False

    def test_flow_reaches_commit(self, monkeypatch):
        """N2.3 a clean INGEST run reaches Commit RAN with no faults."""
        ctx = _ingest(monkeypatch)
        assert ctx.trace.outcome_of("Commit") == Outcome.RAN
        assert ctx.faults == []
        assert ctx.get("committed")["skipped"] is False


# ---------------------------------------------------------------------------
# No-halt: faults resolve inline, the flow still commits
# ---------------------------------------------------------------------------

class TestNoHalt:
    def test_count_mismatch_accepts_and_continues(self, monkeypatch):
        """N2.4 a former COUNT_MISMATCH halt -> fault(accept_parsed) -> Commit."""
        _stub_wrapped_stages(monkeypatch)
        from python.pipeline import stages

        def boom(pctx, db):
            raise HaltError(HaltReason.COUNT_MISMATCH, "count off by 3")
        monkeypatch.setattr(stages, "s7_validate", boom)

        db = _make_db([_fencer(101, "KOWALSKI", "Jan", 1980),
                       _fencer(102, "NOWAK", "Adam", 1982)])
        svc = Services(db=db, config={"parsed": _make_parsed(), "overrides": Overrides(),
                                      "season_end_year": 2026, "event_code": "PPW3-2025-2026"})
        ctx = run_module.run_flow(FlowParams(Flow.INGEST_DOMESTIC), svc=svc)

        assert any(f.kind == FaultKind.COUNT_MISMATCH for f in ctx.faults)
        assert ctx.trace.outcome_of("ValidateCounts") == Outcome.FAULT
        assert ctx.trace.outcome_of("Commit") == Outcome.RAN     # reaches Commit
        assert ctx.get("committed")["skipped"] is False          # accept_parsed: no drop

    def test_below_min_drops_bracket_then_commits(self, monkeypatch):
        """N2.5 below-min -> fault(BELOW_MIN) -> drop_bracket -> Commit skipped."""
        ctx = _ingest(monkeypatch, config_extra={"min_participants": 5})  # only 2 matched
        assert any(f.kind == FaultKind.BELOW_MIN for f in ctx.faults)
        assert ctx.trace.outcome_of("ValidateCounts") == Outcome.FAULT
        assert ctx.trace.outcome_of("Commit") == Outcome.RAN
        committed = ctx.get("committed")
        assert committed["skipped"] is True
        assert committed["dropped"]

    def test_event_not_resolved_aborts(self, monkeypatch):
        """N2.6 EVENT_NOT_RESOLVED is unrecoverable -> Abort stops the run."""
        _stub_wrapped_stages(monkeypatch)
        from python.pipeline import stages

        def boom(pctx, db):
            raise HaltError(HaltReason.EVENT_NOT_RESOLVED, "no such event")
        monkeypatch.setattr(stages, "s2_resolve_event", boom)

        svc = Services(db=_make_db([]), config={"parsed": _make_parsed(),
                       "overrides": Overrides(), "season_end_year": 2026,
                       "event_code": "PPW3-2025-2026"})
        ctx = run_module.run_flow(FlowParams(Flow.INGEST_DOMESTIC), svc=svc)
        assert ctx.trace.outcome_of("ResolveEvent") == Outcome.ABORTED
        assert ctx.trace.outcome_of("Commit") is None  # never reached


# ---------------------------------------------------------------------------
# Escalation policy (Escalate = last-resort Telegram, never blocks)
# ---------------------------------------------------------------------------

class TestEscalationPolicy:
    def test_always_and_on_loss_with_loss(self):
        """N2.7 ALWAYS faults always escalate; ON_LOSS only when data was dropped."""
        from python.pipeline.core.contract import Fault
        from python.pipeline.plugins.post_commit import escalate_faults

        ctx = Context()
        ctx.data["_dropped_brackets"] = ["V4 dropped"]
        ctx.faults.append(Fault("ValidateCounts", FaultKind.COUNT_MISMATCH, "x"))
        ctx.faults.append(Fault("ValidateCounts", FaultKind.BELOW_MIN, "y"))
        notifier = MagicMock()
        sent = escalate_faults(ctx, Services(notifier=notifier))
        assert {f.kind for f in sent} == {FaultKind.COUNT_MISMATCH, FaultKind.BELOW_MIN}
        assert notifier.send.call_count == 2

    def test_on_loss_suppressed_without_loss(self):
        """N2.8 an ON_LOSS fault with no data drop does NOT escalate."""
        from python.pipeline.core.contract import Fault
        from python.pipeline.plugins.post_commit import escalate_faults

        ctx = Context()
        ctx.faults.append(Fault("DetectPoolRound", FaultKind.POOL_ROUND, "z"))
        notifier = MagicMock()
        sent = escalate_faults(ctx, Services(notifier=notifier))
        assert sent == []
        notifier.send.assert_not_called()

    def test_escalation_is_post_commit_not_blocking(self):
        """N2.9 escalation runs in POST_COMMIT/Notify, after commit — never blocks."""
        from python.pipeline.core.contract import Fault
        from python.pipeline.plugins.post_commit import Notify

        ctx = Context()
        ctx.data["event"] = {"id_event": 1}
        ctx.data["committed"] = {"skipped": False, "vcat_groups": ["V1"]}
        ctx.data["_dropped_brackets"] = []
        ctx.faults.append(Fault("ValidateCounts", FaultKind.COUNT_MISMATCH, "flag"))
        notifier = MagicMock()
        Notify().run(ctx, Services(notifier=notifier))
        assert notifier.send.call_count == 2  # summary + escalation, returned (no block)
