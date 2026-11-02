"""PLAN.LINE — a run that writes nothing says so, bracket by bracket (ADR-119 G62 A).

doc/plans/partial-ingest-promote-results-sync-2026-10-31.html, G62.

The second source re-read (1 Nov 2026) writes nothing, yet it printed each
bracket as an ingest does: "committed 1 bracket(s): V3→t2190(n=44)", which
reads as a write, and, for an international bracket in which no row is a
fencer of ours, "SKIPPED (dropped ['0<1 participants']) faults=['BELOW_MIN']",
which reads as a bracket nobody fenced. The run record already called the
second one "no fencer of ours". Each bracket line now says what happened,
still without a name (D12):

  PLAN.LINE.01  a plan's bracket line says "planned", never "committed";
  PLAN.LINE.02  an actual write still says "committed";
  PLAN.LINE.03  an international bracket without a fencer of ours says so, with
                the source N, in a plan and in a write alike;
  PLAN.LINE.04  the source N is the size the parser recorded when the listing
                is shorter;
  PLAN.LINE.05  every other skip keeps its "SKIPPED (dropped …)" line.
"""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from python.pipeline import ingest_cli
from python.pipeline.core.contract import Context, Fault, FaultKind
from python.pipeline.engine.flows import Flow
from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind
from python.pipeline.promotion.plan import RecordingConnector

FOIL = "Vet-40    Men's Foil [FOIL/M V1, FIE]"
DAMES = "Fleuret Dames V1 [FOIL/F V1, EVF]"


def _plan_db():
    return RecordingConnector(MagicMock(), None, target="CERT", reserve=False)


def _parsed(rows: int, *, raw_pool_size: int | None = None) -> ParsedTournament:
    return ParsedTournament(
        source_kind=SourceKind.FTL,
        results=[
            ParsedResult(
                source_row_id=str(i),
                fencer_name=f"DUPONT{i} Marie",
                place=i,
                fencer_country="FRA",
            )
            for i in range(1, rows + 1)
        ],
        raw_pool_size=raw_pool_size,
        weapon="FOIL",
        gender="F",
        category_hint="V1",
    )


def _line(capsys, ctx, db, *, label, parsed=None, flow=None) -> str:
    with patch("python.pipeline.run.run_flow", return_value=ctx):
        ingest_cli._run_parsed_through_flow(
            parsed or _parsed(44), "EVENT-2025-2026", 2026, {}, db, label=label, flow=flow
        )
    return capsys.readouterr().out


def _committed() -> Context:
    ctx = Context()
    ctx.data["committed"] = {"tournaments": [{"vcat": "V1", "id_tournament": 2211, "n": 44}]}
    return ctx


def _skipped(detail: str, kind: FaultKind = FaultKind.BELOW_MIN) -> Context:
    ctx = Context()
    ctx.data["committed"] = {"skipped": True, "dropped": [detail]}
    ctx.faults.append(Fault("ValidateCounts", kind, detail))
    return ctx


def test_PLAN_LINE_01_a_plans_bracket_line_says_planned(capsys):
    out = _line(capsys, _committed(), _plan_db(), label=FOIL)
    assert out == f"  {FOIL}: planned 1 bracket(s): V1→t2211(n=44) faults=[]\n"
    assert "committed" not in out


def test_PLAN_LINE_02_an_actual_write_still_says_committed(capsys):
    out = _line(capsys, _committed(), MagicMock(), label=FOIL)
    assert out == f"  {FOIL}: committed 1 bracket(s): V1→t2211(n=44) faults=[]\n"


@pytest.mark.parametrize("db", [_plan_db, MagicMock], ids=["plan", "write"])
def test_PLAN_LINE_03_a_bracket_without_a_fencer_of_ours_says_so(capsys, db):
    out = _line(
        capsys,
        _skipped("0<1 participants"),
        db(),
        label=DAMES,
        parsed=_parsed(14),
        flow=Flow.INGEST_INTERNATIONAL,
    )
    assert out == f"  {DAMES}: no fencer of ours (14 in the source)\n"
    assert "0<1" not in out and "DUPONT" not in out


def test_PLAN_LINE_04_the_source_n_is_the_size_the_parser_recorded(capsys):
    out = _line(
        capsys,
        _skipped("0<1 participants"),
        _plan_db(),
        label=DAMES,
        parsed=_parsed(3, raw_pool_size=44),
        flow=Flow.INGEST_INTERNATIONAL,
    )
    assert out == f"  {DAMES}: no fencer of ours (44 in the source)\n"


@pytest.mark.parametrize(
    ("flow", "detail", "kind"),
    [
        (None, "0<1 participants", FaultKind.BELOW_MIN),
        (Flow.INGEST_INTERNATIONAL, "pool round", FaultKind.POOL_ROUND),
    ],
    ids=["domestic", "international pool round"],
)
def test_PLAN_LINE_05_every_other_skip_keeps_its_line(capsys, flow, detail, kind):
    out = _line(capsys, _skipped(detail, kind), _plan_db(), label=DAMES, flow=flow)
    assert out == f"  {DAMES}: SKIPPED (dropped [{detail!r}]) faults=[{kind.value!r}]\n"
