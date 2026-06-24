"""Step D — chain the PostCommit reactor (ADR-074/069/059, design §2.6).

Plan IDs N10.1–N10.6. Maps to FR-112 (Reactors observe a signal → emit a Flow)
+ FR-116 (Escalate fires Telegram only per policy, post-commit, never blocks).
After Commit emits live.committed, `run_flow` auto-fires POST_COMMIT (participant
count + Telegram summary + escalation). Acceptance: an ingest that dropped a
below-min bracket automatically sends the ON_LOSS Telegram.
"""

from __future__ import annotations

from datetime import date
from unittest.mock import MagicMock

from python.pipeline import run as run_module
from python.pipeline.core.contract import Context, Outcome, Services
from python.pipeline.engine.flows import Flow, FlowParams
from python.pipeline.reactors import (
    build_post_commit_context,
    should_react_post_commit,
)
from python.pipeline.types import Overrides

# ---------------------------------------------------------------------------
# Reactor predicate / context carry-over (pure)
# ---------------------------------------------------------------------------


class TestReactorFunctions:
    def _rb(self):
        from python.pipeline.engine.rulebook import RULEBOOK

        return RULEBOOK

    def test_reacts_when_committed(self):
        """N10.1 a committing flow with a `committed` outcome reacts."""
        ctx = Context()
        ctx.data["committed"] = {"skipped": False}
        assert should_react_post_commit(Flow.INGEST_DOMESTIC, ctx, self._rb()) is True

    def test_no_react_for_post_commit_itself(self):
        """N10.2 POST_COMMIT never re-fires (no back-edge -> converges)."""
        ctx = Context()
        ctx.data["committed"] = {"skipped": False}
        assert should_react_post_commit(Flow.POST_COMMIT, ctx, self._rb()) is False

    def test_no_react_without_committed_or_rule(self):
        """N10.3 no commit outcome, or a rulebook without POST_COMMIT -> no react."""
        empty = Context()
        assert should_react_post_commit(Flow.INGEST_DOMESTIC, empty, self._rb()) is False
        committed = Context()
        committed.data["committed"] = {"skipped": True}
        assert should_react_post_commit(Flow.INGEST_DOMESTIC, committed, {}) is False

    def test_carries_event_faults_drops(self):
        """N10.4 the POST_COMMIT context carries event + committed + drops + faults."""
        from python.pipeline.core.contract import FaultKind

        parent = Context()
        parent.data["event"] = {"id_event": 7}
        parent.data["committed"] = {"skipped": True, "dropped": ["V1: 2<5"]}
        parent.data["_dropped_brackets"] = ["V1: 2<5"]
        parent._begin(MagicMock(name="X", writes=frozenset()))
        parent.fault(FaultKind.BELOW_MIN, "V1")
        parent._end()
        child = build_post_commit_context(parent)
        assert child.get("event") == {"id_event": 7}
        assert child.get("_dropped_brackets") == ["V1: 2<5"]
        assert [f.kind for f in child.faults] == [FaultKind.BELOW_MIN]


# ---------------------------------------------------------------------------
# Integration through run_flow (real rulebook + plugins, stubbed stages)
# ---------------------------------------------------------------------------


def _make_parsed(results):
    from python.pipeline.ir import ParsedTournament, SourceKind

    return ParsedTournament(
        source_kind=SourceKind.CERT_REF,
        results=results,
        parsed_date=date(2026, 4, 1),
        weapon="EPEE",
        gender="M",
        organizer_hint="SPWS",
        category_hint="V1",
        raw_pool_size=len(results),
        season_end_year=2026,
    )


def _fencer(id_, surname, first, by):
    return {
        "id_fencer": id_,
        "txt_surname": surname,
        "txt_first_name": first,
        "int_birth_year": by,
        "bool_birth_year_estimated": False,
        "txt_nationality": "POL",
        "enum_gender": "M",
        "json_name_aliases": [],
    }


def _stub_stages(monkeypatch):
    from python.pipeline import stages

    def stub(name):
        def fn(pctx, db):
            if name == "s2_resolve_event":
                pctx.event = {"id_event": 7, "txt_code": "PPW3-2025-2026", "enum_type": "PPW"}
            elif name == "s7_split_by_vcat":
                pctx.vcat_groups = {"V1": list(pctx.matches)}

        return fn

    for name in (
        "s1_validate_ir",
        "s2_resolve_event",
        "s5_detect_joint_pool",
        "s7_validate",
        "s7_pool_round_check",
        "s7_split_by_vcat",
    ):
        monkeypatch.setattr(stages, name, stub(name))


def _db(fencer_db):
    db = MagicMock()
    db.fetch_fencer_db.return_value = fencer_db
    db.fetch_birth_years_batch.return_value = {
        f["id_fencer"]: f["int_birth_year"] for f in fencer_db
    }
    db.find_or_create_tournament.return_value = 555
    db.ingest_results.return_value = {"ok": True}
    return db


class TestChainThroughRunFlow:
    def test_below_min_drop_escalates_on_loss_telegram(self, monkeypatch):
        """N10.5 (acceptance) an ingest that DROPPED a below-min bracket auto-fires
        POST_COMMIT, which sends the ON_LOSS escalation Telegram for BELOW_MIN."""
        _stub_stages(monkeypatch)
        notifier = MagicMock()
        parsed = _make_parsed(
            [
                __import__("python.pipeline.ir", fromlist=["ParsedResult"]).ParsedResult(
                    source_row_id="t:1", fencer_name="KOWALSKI Jan", place=1, fencer_country="POL"
                ),
            ]
        )
        svc = Services(
            db=_db([_fencer(101, "KOWALSKI", "Jan", 1980)]),
            config={
                "parsed": parsed,
                "overrides": Overrides(),
                "season_end_year": 2026,
                "event_code": "PPW3-2025-2026",
                "min_participants": 5,
            },
            notifier=notifier,
        )
        ctx = run_module.run_flow(FlowParams(Flow.INGEST_DOMESTIC), svc=svc)
        # the parent committed-skipped (whole bracket dropped)
        assert ctx.get("committed")["skipped"] is True
        # POST_COMMIT was chained
        pc = ctx.get("_post_commit")
        assert pc is not None
        assert pc.trace.outcome_of("ParticipantCount") == Outcome.RAN
        assert pc.trace.outcome_of("Notify") == Outcome.RAN
        # ... and it escalated the BELOW_MIN (ON_LOSS, data was dropped)
        sent = [c.args[0] for c in notifier.send.call_args_list]
        assert any("escalate:BELOW_MIN" in s for s in sent), sent

    def test_clean_ingest_chains_post_commit_without_escalation(self, monkeypatch):
        """N10.6 a clean ingest still fires POST_COMMIT (summary), but escalates
        nothing (no faults, no loss)."""
        _stub_stages(monkeypatch)
        notifier = MagicMock()
        from python.pipeline.ir import ParsedResult

        parsed = _make_parsed(
            [
                ParsedResult(
                    source_row_id="t:1", fencer_name="KOWALSKI Jan", place=1, fencer_country="POL"
                ),
                ParsedResult(
                    source_row_id="t:2", fencer_name="NOWAK Adam", place=2, fencer_country="POL"
                ),
            ]
        )
        svc = Services(
            db=_db([_fencer(101, "KOWALSKI", "Jan", 1980), _fencer(102, "NOWAK", "Adam", 1982)]),
            config={
                "parsed": parsed,
                "overrides": Overrides(),
                "season_end_year": 2026,
                "event_code": "PPW3-2025-2026",
            },
            notifier=notifier,
        )
        ctx = run_module.run_flow(FlowParams(Flow.INGEST_DOMESTIC), svc=svc)
        assert ctx.get("committed")["persisted"] is True
        assert ctx.get("_post_commit") is not None
        sent = [c.args[0] for c in notifier.send.call_args_list]
        assert not any("escalate" in s for s in sent), sent
        assert any("event committed" in s for s in sent), sent

    def test_react_false_suppresses_chain(self, monkeypatch):
        """N10.7 react=False (the reactor's own recursive call) suppresses chaining."""
        _stub_stages(monkeypatch)
        from python.pipeline.ir import ParsedResult

        parsed = _make_parsed(
            [
                ParsedResult(
                    source_row_id="t:1", fencer_name="KOWALSKI Jan", place=1, fencer_country="POL"
                )
            ]
        )
        svc = Services(
            db=_db([_fencer(101, "KOWALSKI", "Jan", 1980)]),
            config={
                "parsed": parsed,
                "overrides": Overrides(),
                "season_end_year": 2026,
                "event_code": "PPW3-2025-2026",
            },
        )
        ctx = run_module.run_flow(FlowParams(Flow.INGEST_DOMESTIC), svc=svc, react=False)
        assert ctx.get("_post_commit") is None
