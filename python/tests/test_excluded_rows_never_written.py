"""EXCLUDED — a row nobody linked is never written (ADR-119 G50 A).

doc/plans/partial-ingest-promote-results-sync-2026-10-31.html, G50.

An international row that is neither admitted nor named by an identity entry
is EXCLUDED, and keeps its nearest fuzzy candidate's id (a `match_method`
override keeps it too; a PZSz row the admission skips is EXCLUDED as well).
The commits wrote every row that had an id and was not PENDING, so the
EXCLUDED row reached fn_ingest_tournament_results, which casts its status to
enum_match_status; that enum has no EXCLUDED, so the whole apply failed. The
re-plan of Madrid 2024 (PEW2efs-2024-2025) showed it: a man in men's épée V3,
excluded by his override, carried a woman's id at confidence 54.

Every commit now writes only rows a rule or a person linked (AUTO_MATCHED,
AUTO_CREATED, USER_CONFIRMED); the staging report keeps listing the others.

  EXCLUDED.01  international: an excluded row with a candidate is not written,
               and N stays the whole source bracket;
  EXCLUDED.02  domestic: a match_method EXCLUDED row with a candidate is not
               written, and the others keep their places;
  EXCLUDED.03  a listing whose only candidate row is excluded writes no
               tournament;
  EXCLUDED.04  PZSz: a skipped row that carries an id is not written.
"""

from __future__ import annotations

from datetime import date
from unittest.mock import MagicMock

from python.pipeline.core.contract import Context, Services
from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind
from python.pipeline.plugins.bridge import LEGACY
from python.pipeline.plugins.ingest import Commit
from python.pipeline.plugins.pzsz_commit import CommitPzszSenior
from python.pipeline.types import Overrides, PipelineContext, StageMatchResult


def _db(engine: str) -> MagicMock:
    db = MagicMock()
    db.get_type_engine.return_value = engine
    db.find_or_create_tournament.side_effect = [501, 502, 503]
    db.ingest_results.return_value = {"ok": True}
    return db


def _match(id_fencer: int | None, place: int, method: str = "AUTO_MATCHED", conf: float = 100.0):
    return StageMatchResult(
        scraped_name=f"FENCER {place}",
        place=place,
        id_fencer=id_fencer,
        confidence=conf,
        method=method,
    )


def _parsed(n: int, places: list[int], source_kind=SourceKind.FTL, **kw) -> ParsedTournament:
    return ParsedTournament(
        source_kind=source_kind,
        results=[ParsedResult(source_row_id=str(p), fencer_name=f"R{p}", place=p) for p in places],
        raw_pool_size=n,
        parsed_date=date(2025, 11, 12),
        weapon=kw.pop("weapon", "EPEE"),
        gender=kw.pop("gender", "M"),
        season_end_year=kw.pop("season_end_year", 2026),
        **kw,
    )


def _ctx(final_vcats, parsed, code: str, event_type: str | None = None) -> Context:
    ctx = Context()
    event = {"id_event": 41, "txt_code": code, "id_season": 3}
    if event_type:
        event["enum_type"] = event_type
    pctx = PipelineContext(
        parsed=parsed, overrides=Overrides(), season_end_year=2026, event_code=code
    )
    pctx.event = event
    pctx.vcat_groups = final_vcats
    matches = [m for ms in final_vcats.values() for m in ms]
    pctx.matches = matches
    ctx.data[LEGACY] = pctx
    ctx.data["event"] = event
    ctx.data["matches"] = matches
    ctx.data["final_vcats"] = final_vcats
    return ctx


def _run(plugin, ctx: Context, db: MagicMock) -> Context:
    ctx._begin(plugin)
    plugin.run(ctx, Services(db=db))
    ctx._end()
    return ctx


def _written(db: MagicMock) -> list[tuple[list[tuple], int | None]]:
    out = []
    for call in db.ingest_results.call_args_list:
        (_tid, rows), kwargs = call
        out.append(
            (
                [(r["id_fencer"], r["int_place"], r["enum_match_status"]) for r in rows],
                kwargs.get("participant_count"),
            )
        )
    return out


def test_EXCLUDED_01_an_excluded_international_row_is_never_written():
    """Madrid 2024's shape: an excluded row carrying a fuzzy candidate's id."""
    fv = {"V3": [_match(7, 6), _match(98, 32, method="EXCLUDED", conf=54.05)]}
    db = _db("EVF_CLASSIC_V1_2025_2026")
    _run(Commit(), _ctx(fv, _parsed(32, [6, 32]), "PEW1-2025-2026"), db)
    assert _written(db) == [([(7, 6, "AUTO_MATCHED")], 32)]


def test_EXCLUDED_02_an_excluded_domestic_row_is_never_written():
    fv = {
        "V1": [
            _match(101, 1),
            _match(98, 2, method="EXCLUDED", conf=60.0),
            _match(102, 3, method="AUTO_CREATED"),
        ]
    }
    parsed = _parsed(3, [1, 2, 3], source_kind=SourceKind.FENCINGTIME_XML, category_hint="V1")
    db = _db("EVF_CLASSIC_V1_2025_2026")
    _run(Commit(), _ctx(fv, parsed, "PPW3-2025-2026", "PPW"), db)
    ((rows, _n),) = _written(db)
    assert [(f, s) for f, _p, s in rows] == [(101, "AUTO_MATCHED"), (102, "NEW_FENCER")]


def test_EXCLUDED_03_a_listing_whose_only_candidate_is_excluded_writes_nothing():
    fv = {"V1": [_match(358, 3, method="EXCLUDED", conf=60.0), _match(None, 1, method="EXCLUDED")]}
    db = _db("EVF_CLASSIC_V1_2025_2026")
    _run(Commit(), _ctx(fv, _parsed(4, [1, 3]), "PEW8es-2025-2026"), db)
    db.find_or_create_tournament.assert_not_called()
    db.ingest_results.assert_not_called()


def test_EXCLUDED_04_a_pzsz_row_the_admission_skipped_is_never_written():
    matches = [_match(101, 3), _match(156, 2, method="EXCLUDED", conf=0.0)]
    parsed = _parsed(3, [1, 2, 3], weapon="SABRE", organizer_hint="PZSz", season_end_year=2027)
    ctx = _ctx({}, parsed, "PPS1s-2026-2027", "PPS")
    ctx.data["matches"] = matches
    db = _db("EVF_CLASSIC_V1_2025_2026")
    _run(CommitPzszSenior(), ctx, db)
    assert _written(db) == [([(101, 3, "AUTO_MATCHED")], 3)]
