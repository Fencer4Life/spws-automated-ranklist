"""INTL — an international result keeps the whole source field and its place.

ADR-105 (doc/plans/international-field-size-root-cause-fix-2026-10-01.html):
only Polish fencers are written for PEW/MEW/MSW/PSW (ADR-038), but the
tournament's N is the whole source bracket and each place is the fencer's own
place in it. Neither is ever recounted from the rows SPWS keeps — not at
commit, not in recompute. Before this, EVF classic's ``PER_CATEGORY_RENUMBER``
stored the Polish head-count as N and renumbered the Poles 1..K (MSW Manama
2025: STAŃCZYK 31st of 60 stored as 2nd of 3).

The database is mocked (RPC-argument contract); the SQL side is pinned by
supabase/tests/86_international_field.sql.
"""

from __future__ import annotations

from datetime import date
from unittest.mock import MagicMock

import pytest

from python.pipeline.core.contract import Context, Services
from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind
from python.pipeline.joined_brackets import (
    INTERNATIONAL_TYPES,
    PER_CATEGORY_RENUMBER,
    SOURCE_FIELD_PLACE,
    BracketField,
    JoinedBracketNotAllowed,
    UnknownScoringEngine,
    module_for,
)
from python.pipeline.plugins.bridge import LEGACY
from python.pipeline.plugins.ingest import Commit
from python.pipeline.types import Overrides, PipelineContext, StageMatchResult

CLASSIC = "EVF_CLASSIC_V1_2025_2026"
JOINED = "SPWS_EVF_JOINED_V1_2026_2027"
EVENT_CODE = "PEW1-2025-2026"


def _db(engine=CLASSIC, tournament_ids=(501, 502, 503)):
    db = MagicMock()
    db.get_type_engine.return_value = engine
    db.find_or_create_tournament.side_effect = list(tournament_ids)
    db.ingest_results.return_value = {"ok": True}
    return db


def _run(ctx, db):
    plugin = Commit()
    ctx._begin(plugin)
    plugin.run(ctx, Services(db=db))
    ctx._end()
    return ctx


def _written(db):
    """{tournament_id: (rows, participant_count)} from the ingest_results calls."""
    out = {}
    for call in db.ingest_results.call_args_list:
        (tid, rows), kwargs = call
        out[tid] = (rows, kwargs["participant_count"])
    return out


def _match(id_fencer, place, method="AUTO_MATCHED", **kw):
    return StageMatchResult(
        scraped_name=f"FENCER {id_fencer}",
        place=place,
        id_fencer=id_fencer,
        confidence=100.0,
        method=method,
        **kw,
    )


def _parsed(n, *, keep_rows=None):
    """A source bracket of ``n`` fencers. ``keep_rows`` limits the rows left in
    ``results`` (as if a POL filter had dropped the rest) while
    ``raw_pool_size`` still records the whole bracket."""
    places = list(range(1, n + 1)) if keep_rows is None else keep_rows
    return ParsedTournament(
        source_kind=SourceKind.FTL,
        results=[ParsedResult(source_row_id=str(p), fencer_name=f"R{p}", place=p) for p in places],
        raw_pool_size=n,
        parsed_date=date(2025, 11, 12),
        weapon="EPEE",
        gender="F",
        season_end_year=2026,
    )


def _ingest_ctx(final_vcats, parsed, *, code=EVENT_CODE):
    ctx = Context()
    event = {"id_event": 41, "txt_code": code, "id_season": 3}
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


# ---------------------------------------------------------------------------
# INTL.MOD — which module an international bracket uses, and what it plans
# ---------------------------------------------------------------------------


class TestModule:
    @pytest.mark.parametrize("ttype", sorted(INTERNATIONAL_TYPES))
    def test_international_types_keep_the_source_field(self, ttype):
        """INTL.MOD.01 every international type is filed by the source-field
        module, whatever engine scores it."""
        module = module_for(CLASSIC, ttype)
        assert module.name == SOURCE_FIELD_PLACE
        plan = module.plan_category([31, 48], [31, 48], BracketField(size=60, places=(31, 48)))
        assert plan.participant_count == 60
        assert [r.place for r in plan.rows] == [31, 48]
        assert module.listing_order([(31, "V2"), (48, "V2")], [31, 48]) is None

    @pytest.mark.parametrize("ttype", ["PPW", "MPW"])
    def test_domestic_selection_is_unchanged(self, ttype):
        """INTL.MOD.02 a domestic split under EVF classic still renumbers 1..K
        and stores its own count, as before."""
        module = module_for(CLASSIC, ttype)
        assert module.name == PER_CATEGORY_RENUMBER
        plan = module.plan_category([4, 9], [4, 9], BracketField.from_places(range(1, 11)))
        assert plan.participant_count == 2
        assert [r.place for r in plan.rows] == [1, 2]

    def test_international_still_fails_closed(self):
        """INTL.MOD.03 an unknown engine is still refused, and so is the joined
        engine on an international type."""
        with pytest.raises(UnknownScoringEngine):
            module_for("NO_SUCH_ENGINE", "MSW")
        with pytest.raises(JoinedBracketNotAllowed):
            module_for(JOINED, "PEW")

    def test_a_place_outside_the_source_field_is_refused(self):
        """INTL.MOD.04 a place above the source bracket's size is corrupt input."""
        module = module_for(CLASSIC, "MEW")
        with pytest.raises(ValueError, match="exceeds"):
            module.plan_category([61], [61], BracketField(size=60, places=(61,)))


class TestCommitIngest:
    def test_two_poles_in_a_bracket_of_sixty(self):
        """INTL.MOD.05 Commit writes N = the whole bracket and each Pole's own
        place (MSW Manama 2025, Vet-50 Women's Épée)."""
        fv = {"V2": [_match(11, 31), _match(12, 48)]}
        db = _db()
        ctx = _run(_ingest_ctx(fv, _parsed(60)), db)
        ((rows, n),) = _written(db).values()
        assert n == 60
        assert [r["int_place"] for r in rows] == [31, 48]
        assert {t["n"] for t in ctx.get("committed")["tournaments"]} == {60}

    def test_the_source_size_survives_a_filtered_listing(self):
        """INTL.MOD.06 even if only the Polish rows reached Commit, N is the
        source bracket's recorded size, never the rows left."""
        fv = {"V2": [_match(11, 31), _match(12, 48)]}
        db = _db()
        _run(_ingest_ctx(fv, _parsed(60, keep_rows=[31, 48])), db)
        ((rows, n),) = _written(db).values()
        assert n == 60
        assert [r["int_place"] for r in rows] == [31, 48]


# ---------------------------------------------------------------------------
# INTL.RECOMP — recompute never re-partitions or recounts an international event
# ---------------------------------------------------------------------------


def _rmatch(id_fencer, place, by, *, vcat="V2", n=60):
    return StageMatchResult(
        scraped_name=str(id_fencer),
        place=place,
        id_fencer=id_fencer,
        confidence=100.0,
        method="AUTO_MATCHED",
        governed_birth_year=by,
        weapon="EPEE",
        gender="F",
        tournament_date=date(2025, 11, 12),
        bracket_size=n,
        bracket_key=None,
        stored_vcat=vcat,
    )


def _recompute(matches, *, code=EVENT_CODE, existing=None, engine=CLASSIC):
    ctx = Context()
    event = {"id_event": 41, "txt_code": code, "id_season": 3}
    pctx = PipelineContext(
        parsed=None, overrides=Overrides(), season_end_year=2026, event_code=code
    )
    pctx.event = event
    pctx.matches = matches
    ctx.data[LEGACY] = pctx
    ctx.data["event"] = event
    ctx.data["matches"] = matches
    db = _db(engine)
    db.fetch_event_tournaments.return_value = existing or []
    _run(ctx, db)
    return db


class TestRecompute:
    def test_n_and_places_are_kept(self):
        """INTL.RECOMP.01 recompute writes back the stored N and places."""
        db = _recompute([_rmatch(11, 31, 1972), _rmatch(12, 48, 1971)])
        ((rows, n),) = _written(db).values()
        assert n == 60
        assert [r["int_place"] for r in rows] == [31, 48]

    def test_a_changed_birth_year_does_not_move_the_result(self):
        """INTL.RECOMP.02 a fencer whose re-derived category changed (born 1962,
        now V3) stays in the stored V2 tournament: one tournament cannot hold two
        source brackets' sizes, so an international event is never re-partitioned."""
        existing = [
            {
                "id_tournament": 501,
                "enum_weapon": "EPEE",
                "enum_gender": "F",
                "enum_age_category": "V2",
                "enum_type": "PEW",
            }
        ]
        db = _recompute([_rmatch(11, 31, 1962), _rmatch(12, 48, 1971)], existing=existing)
        vcats = [c.args[3] for c in db.find_or_create_tournament.call_args_list]
        assert vcats == ["V2"]
        ((rows, n),) = _written(db).values()
        assert (n, [r["int_place"] for r in rows]) == (60, [31, 48])
        db.clear_tournament_results.assert_not_called()

    def test_each_stored_tournament_keeps_its_own_n(self):
        """INTL.RECOMP.03 two stored tournaments of one event keep their own
        source sizes (Vet-50 of 60, Vet-60 of 71)."""
        db = _recompute(
            [_rmatch(11, 31, 1972, vcat="V2", n=60), _rmatch(21, 5, 1961, vcat="V3", n=71)]
        )
        sizes = sorted(n for _, n in _written(db).values())
        assert sizes == [60, 71]

    def test_the_stored_bracket_is_written_as_the_source_category(self):
        """INTL.RECOMP.04 each row is written with its stored bracket as
        enum_source_age_category. The result V-cat guard trusts a bracket label
        (ADR-056 revision), so a fencer born 1962 stays in the Vet-50 bracket
        they fenced instead of failing the BY-derived check and halting the
        drain (found on LOCAL, PEW7es-2024-2025, 1 October 2026)."""
        db = _recompute([_rmatch(11, 31, 1962), _rmatch(12, 48, 1971)])
        ((rows, _),) = _written(db).values()
        assert [r.get("enum_source_age_category") for r in rows] == ["V2", "V2"]
