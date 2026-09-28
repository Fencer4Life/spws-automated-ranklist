"""SE27.ING — joined-bracket modules paired with scoring engines (ADR-103 §4).

A joined bracket is one listing fenced by two or more age categories. Which
module files it is decided by the engine assigned to the tournament type:

- ``PER_CATEGORY_RENUMBER`` ↔ EVF classic: split per category, dense-renumber
  places 1..K, store the category's own size as N (ADR-049). Byte-identical to
  the behaviour before ADR-103.
- ``JOINED_BRACKET_CATEGORY_PLACE`` ↔ the 2026/2027 engine: keep the joined
  place and the joined N, file each fencer under their own category's
  tournament, and write K, m and the count of fencers below.

The database is mocked here (RPC-argument contract); the SQL side of the same
contract is pinned by supabase/tests/83_spws_place_medal_engine.sql.
"""

from __future__ import annotations

from datetime import date
from unittest.mock import MagicMock

import pytest

from python.pipeline.core.contract import Context, Services
from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind
from python.pipeline.joined_brackets import (
    JOINED_BRACKET_CATEGORY_PLACE,
    MODULE_BY_ENGINE,
    NOT_USED,
    PER_CATEGORY_RENUMBER,
    BracketField,
    JoinedBracketNotAllowed,
    UnknownScoringEngine,
    module_for,
)
from python.pipeline.plugins.bridge import LEGACY
from python.pipeline.plugins.ingest import Commit
from python.pipeline.plugins.pzsz_commit import CommitPzszSenior
from python.pipeline.types import Overrides, PipelineContext, StageMatchResult

CLASSIC = "EVF_CLASSIC_V1_2025_2026"
PLACE_MEDAL = "SPWS_PLACE_MEDAL_V1_2026_2027"

# The signed-off 10-fencer example: categories by joined place.
EXAMPLE = {"V1": [1, 4], "V2": [2, 3, 6, 9], "V3": [5, 7, 8, 10]}


def _match(id_fencer, place, name=None, method="AUTO_MATCHED", **kw):
    return StageMatchResult(
        scraped_name=name or f"FENCER {id_fencer}",
        place=place,
        id_fencer=id_fencer,
        confidence=100.0,
        method=method,
        **kw,
    )


def _parsed(places):
    return ParsedTournament(
        source_kind=SourceKind.FENCINGTIME_XML,
        results=[
            ParsedResult(source_row_id=str(i), fencer_name=f"R{i}", place=p)
            for i, p in enumerate(places)
        ],
        parsed_date=date(2026, 10, 11),
        weapon="EPEE",
        gender="M",
        season_end_year=2027,
    )


def _db(engine):
    db = MagicMock()
    db.get_type_engine.return_value = engine
    db.find_or_create_tournament.side_effect = [301, 302, 303, 304]
    db.ingest_results.return_value = {"ok": True}
    return db


def _ctx(final_vcats, parsed, *, ttype_code="PPW1-2026-2027"):
    ctx = Context()
    event = {"id_event": 9, "txt_code": ttype_code, "id_season": 4}
    pctx = PipelineContext(
        parsed=parsed, overrides=Overrides(), season_end_year=2027, event_code=ttype_code
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


def _run(plugin, ctx, db):
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


# ---------------------------------------------------------------------------
# SE27.ING.01 — the registry: one module per engine, fail closed otherwise
# ---------------------------------------------------------------------------


class TestRegistry:
    def test_every_engine_has_exactly_one_module(self):
        """SE27.ING.01 each released engine maps to one module; the module names
        are the two values tbl_scoring_engine.txt_joined_bracket_module admits."""
        assert MODULE_BY_ENGINE == {
            CLASSIC: PER_CATEGORY_RENUMBER,
            PLACE_MEDAL: JOINED_BRACKET_CATEGORY_PLACE,
        }
        assert module_for(CLASSIC, "PPW").name == PER_CATEGORY_RENUMBER
        assert module_for(PLACE_MEDAL, "PPW").name == JOINED_BRACKET_CATEGORY_PLACE

    def test_unknown_engine_raises(self):
        """SE27.ING.01 an engine the pipeline does not know is refused, never
        defaulted — the same fail-closed rule as the SQL dispatcher."""
        with pytest.raises(UnknownScoringEngine):
            module_for("SPWS_FIELD_SCALED_V1_2026_2027", "PPW")
        with pytest.raises(UnknownScoringEngine):
            module_for(None, "PPW")


# ---------------------------------------------------------------------------
# SE27.ING.02 — PER_CATEGORY_RENUMBER is today's behaviour
# ---------------------------------------------------------------------------


class TestPerCategoryRenumber:
    def test_dense_renumber_and_own_count(self):
        """SE27.ING.02 whole-pool places {1,4,4,7} of one category become
        {1,2,2,3}; N is the category's own row count; K, m and b are not used."""
        plan = module_for(CLASSIC, "PPW").plan_category(
            [1, 4, 4, 7], [1, 4, 4, 7], BracketField.from_places(range(1, 11))
        )
        assert [r.place for r in plan.rows] == [1, 2, 2, 3]
        assert plan.participant_count == 4
        assert {(r.category_count, r.category_place, r.below_count) for r in plan.rows} == {
            (NOT_USED, NOT_USED, NOT_USED)
        }
        assert all(r.columns() == {} for r in plan.rows)

    def test_commit_rows_byte_identical_under_classic(self):
        """SE27.ING.02 Commit under EVF classic writes exactly the rows and the
        per-category count it wrote before ADR-103 — no K, m or b keys."""
        fv = {"V1": [_match(101, 1), _match(102, 4)], "V2": [_match(201, 2), _match(202, 3)]}
        db = _db(CLASSIC)
        _run(Commit(), _ctx(fv, _parsed([1, 2, 3, 4])), db)
        written = _written(db)
        assert written[301] == (
            [
                {
                    "id_fencer": 101,
                    "int_place": 1,
                    "txt_scraped_name": "FENCER 101",
                    "num_confidence": 100.0,
                    "enum_match_status": "AUTO_MATCHED",
                },
                {
                    "id_fencer": 102,
                    "int_place": 2,
                    "txt_scraped_name": "FENCER 102",
                    "num_confidence": 100.0,
                    "enum_match_status": "AUTO_MATCHED",
                },
            ],
            2,
        )


# ---------------------------------------------------------------------------
# SE27.ING.03-04 — JOINED_BRACKET_CATEGORY_PLACE
# ---------------------------------------------------------------------------


class TestJoinedBracketCategoryPlace:
    def test_joined_example_keeps_place_and_n(self):
        """SE27.ING.03 the V1+V2+V3 bracket of 10: each category keeps the
        joined places and N = 10, with K, m and fencers below per fencer."""
        field = BracketField.from_places(range(1, 11))
        plan = module_for(PLACE_MEDAL, "PPW").plan_category(EXAMPLE["V2"], EXAMPLE["V2"], field)
        assert plan.participant_count == 10
        assert [
            (r.place, r.category_count, r.category_place, r.below_count) for r in plan.rows
        ] == [
            (2, 4, 1, 8),
            (3, 4, 2, 7),
            (6, 4, 3, 4),
            (9, 4, 4, 1),
        ]

    def test_ties_run_1_2_3_3_5(self):
        """SE27.ING.04 tied fencers share m, the next is m + 2, and a tied
        fencer is not below the other (§8 ust. 6)."""
        places = [1, 2, 3, 3, 5]
        plan = module_for(PLACE_MEDAL, "PPW").plan_category(
            places, places, BracketField.from_places(places)
        )
        assert [r.category_place for r in plan.rows] == [1, 2, 3, 3, 5]
        assert [r.below_count for r in plan.rows] == [4, 3, 1, 1, 0]

    def test_a_place_outside_the_field_is_refused(self):
        """SE27.ING.04 a joined place beyond the listing is corrupt input."""
        with pytest.raises(ValueError, match="exceeds the bracket"):
            module_for(PLACE_MEDAL, "PPW").plan_category(
                [12], [12], BracketField.from_places(range(1, 11))
            )

    def test_commit_files_each_category_with_the_joined_bracket(self):
        """SE27.ING.03 Commit under the new engine writes the joined places,
        N = the whole listing, and K, m, b on every row."""
        ids = iter(range(1, 100))
        fv = {
            vcat: [_match(next(ids), p) for p in places] for vcat, places in sorted(EXAMPLE.items())
        }
        db = _db(PLACE_MEDAL)
        _run(Commit(), _ctx(fv, _parsed(range(1, 11))), db)
        written = _written(db)
        rows_v1, n_v1 = written[301]
        assert n_v1 == 10
        assert [
            (r["int_place"], r["int_category_count"], r["int_category_place"], r["int_below_count"])
            for r in rows_v1
        ] == [
            (1, 2, 1, 9),
            (4, 2, 2, 6),
        ]
        assert {n for _, n in written.values()} == {10}
        db.get_type_engine.assert_called_once_with(4, "PPW")


# ---------------------------------------------------------------------------
# SE27.ING.05 — PZSz senior brackets: K = N, m = place
# ---------------------------------------------------------------------------


class TestPzszSenior:
    def test_rows_and_queue_carry_k_m_b(self):
        """SE27.ING.05 a senior bracket is one category to the engine: K = the
        full field, m = the original place, b from the full field — for written
        rows and for a queued review alike."""
        parsed = _parsed(range(1, 13))
        parsed.gender = "M"
        ctx = _ctx({}, parsed, ttype_code="PPS1e-2026-2027")
        matches = [
            _match(501, 3, governed_birth_year=1960),
            _match(
                None, 7, name="Uncertain Name", method="PENDING", alternatives=[{"id_fencer": 55}]
            ),
        ]
        ctx.data["matches"] = matches
        db = _db(PLACE_MEDAL)
        db.find_or_create_tournament.side_effect = [601]
        _run(CommitPzszSenior(), ctx, db)
        (_, rows), kwargs = db.ingest_results.call_args
        assert kwargs["participant_count"] == 12
        assert (
            rows[0]["int_category_count"],
            rows[0]["int_category_place"],
            rows[0]["int_below_count"],
        ) == (12, 3, 9)
        db.queue_pzsz_match_review.assert_called_once_with(601, "Uncertain Name", 7, 55, 100.0, 5)


# ---------------------------------------------------------------------------
# SE27.ING.06 — RECOMPUTE_DOMESTIC uses the paired module
# ---------------------------------------------------------------------------


def _rmatch(id_fencer, place, by, *, n=10, below=None, url="https://example.test/ppw1"):
    return StageMatchResult(
        scraped_name=str(id_fencer),
        place=place,
        id_fencer=id_fencer,
        confidence=100.0,
        method="AUTO_MATCHED",
        governed_birth_year=by,
        weapon="EPEE",
        gender="M",
        tournament_date=date(2026, 10, 11),
        bracket_size=n,
        below_count=(n - place) if below is None else below,
        bracket_key=url,
    )


class TestRecompute:
    def _recompute(self, matches, engine):
        ctx = Context()
        event = {"id_event": 9, "txt_code": "PPW1-2026-2027", "id_season": 4}
        pctx = PipelineContext(
            parsed=None, overrides=Overrides(), season_end_year=2027, event_code="PPW1-2026-2027"
        )
        pctx.event = event
        pctx.matches = matches
        ctx.data[LEGACY] = pctx
        ctx.data["event"] = event
        ctx.data["matches"] = matches
        db = _db(engine)
        db.fetch_event_tournaments.return_value = []
        _run(Commit(), ctx, db)
        return db

    def test_joined_recompute_keeps_places_n_and_below(self):
        """SE27.ING.06 a birth-year relocation re-files a fencer but keeps the
        joined place, N and stored b; K and m follow the new categories."""
        # Born 1980 -> 47 in 2027 -> V1; born 1970 -> 57 -> V2.
        matches = [
            _rmatch(1, 1, 1980),
            _rmatch(2, 2, 1980),
            _rmatch(3, 3, 1970, below=6),
            _rmatch(4, 5, 1970),
        ]
        db = self._recompute(matches, PLACE_MEDAL)
        written = sorted(_written(db).values(), key=lambda w: w[0][0]["int_place"])
        (v1_rows, v1_n), (v2_rows, v2_n) = written
        assert (v1_n, v2_n) == (10, 10)
        assert [
            (r["int_place"], r["int_category_count"], r["int_category_place"], r["int_below_count"])
            for r in v1_rows
        ] == [
            (1, 2, 1, 9),
            (2, 2, 2, 8),
        ]
        assert [
            (r["int_place"], r["int_category_count"], r["int_category_place"], r["int_below_count"])
            for r in v2_rows
        ] == [
            (3, 2, 1, 6),
            (5, 2, 2, 5),
        ]

    def test_classic_recompute_still_renumbers(self):
        """SE27.ING.06 under EVF classic a recompute renumbers 1..K, as before."""
        matches = [_rmatch(1, 4, 1970), _rmatch(2, 9, 1970)]
        db = self._recompute(matches, CLASSIC)
        ((rows, n),) = _written(db).values()
        assert n == 2
        assert [r["int_place"] for r in rows] == [1, 2]
        assert "int_category_count" not in rows[0]

    def test_joined_recompute_refuses_to_merge_two_brackets(self):
        """SE27.ING.06 one category tournament cannot hold two joined brackets:
        their places and N are not comparable, so recompute stops."""
        matches = [
            _rmatch(1, 1, 1970, url="https://example.test/a"),
            _rmatch(2, 1, 1970, url="https://example.test/b"),
        ]
        with pytest.raises(ValueError, match="two joined brackets"):
            self._recompute(matches, PLACE_MEDAL)


# ---------------------------------------------------------------------------
# SE27.ING.07-08 — the joined N is what the count check and the gate see
# ---------------------------------------------------------------------------


class TestJoinedN:
    def test_committed_count_is_the_whole_listing(self):
        """SE27.ING.07 the participant count Commit records — the number the
        ADR-069 URL check compares — is the whole listing, not a slice."""
        fv = {"V1": [_match(1, 1)], "V2": [_match(2, 2)]}
        db = _db(PLACE_MEDAL)
        ctx = _run(Commit(), _ctx(fv, _parsed([1, 2, 3, 4, 5])), db)
        assert {t["n"] for t in ctx.get("committed")["tournaments"]} == {5}

    def test_unmatched_fencers_count_in_n_and_below(self):
        """SE27.ING.08 a listed fencer who is not written (no match, no
        category) still counts in N and in b: the gate and the engine read the
        listing, len(parsed.results), not the rows stored."""
        fv = {"V2": [_match(1, 1), _match(None, 2, method="EXCLUDED")]}
        db = _db(PLACE_MEDAL)
        _run(Commit(), _ctx(fv, _parsed([1, 2, 3, 4])), db)
        ((rows, n),) = _written(db).values()
        assert n == 4
        assert (rows[0]["int_category_count"], rows[0]["int_below_count"]) == (2, 3)


# ---------------------------------------------------------------------------
# SE27.ING.09 — international results never reach the joined module
# ---------------------------------------------------------------------------


class TestInternational:
    @pytest.mark.parametrize("ttype", ["PEW", "MEW", "MSW", "PSW"])
    def test_international_type_refuses_the_joined_module(self, ttype):
        """SE27.ING.09 EVF and FIE publish per category; an international type
        assigned the new engine is refused rather than re-joined."""
        with pytest.raises(JoinedBracketNotAllowed):
            module_for(PLACE_MEDAL, ttype)
        assert module_for(CLASSIC, ttype).name == PER_CATEGORY_RENUMBER
