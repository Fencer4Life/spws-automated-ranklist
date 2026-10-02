"""SE27.ING / JB27.ING / JB27.CLEAN — joined-bracket modules paired with engines.

A joined bracket is one listing fenced by two or more age categories. Which
module files it is decided by the engine assigned to the tournament type
(ADR-103 §4, as amended by ADR-104):

- ``PER_CATEGORY_RENUMBER`` ↔ EVF classic: split per category, dense-renumber
  places 1..K, store the category's own size as N (ADR-049). Byte-identical to
  the behaviour before ADR-103.
- ``JOINED_BRACKET_CATEGORY_PLACE`` ↔ ``SPWS_EVF_JOINED_V1_2026_2027``: keep the
  joined place and the joined N, file each fencer under their own category's
  tournament, and write the listing's category order — one digit per place —
  to every one of them, so the database scores the whole bracket from it.

The database is mocked here (RPC-argument contract); the SQL side of the same
contract is pinned by supabase/tests/85_spws_evf_joined_engine.sql.
"""

from __future__ import annotations

import dataclasses
import pathlib
from datetime import date
from unittest.mock import MagicMock

import pytest

from python.pipeline.core.contract import Context, Services
from python.pipeline.db_connector import DbConnector
from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind
from python.pipeline.joined_brackets import (
    JOINED_BRACKET_CATEGORY_PLACE,
    MODULE_BY_ENGINE,
    PER_CATEGORY_RENUMBER,
    SOURCE_FIELD_PLACE,
    BracketField,
    JoinedBracketNotAllowed,
    RowPlan,
    UnknownScoringEngine,
    module_for,
)
from python.pipeline.plugins.bridge import LEGACY
from python.pipeline.plugins.ingest import Commit
from python.pipeline.plugins.pzsz_commit import CommitPzszSenior
from python.pipeline.types import Overrides, PipelineContext, StageMatchResult

CLASSIC = "EVF_CLASSIC_V1_2025_2026"
PLACE_MEDAL = "SPWS_PLACE_MEDAL_V1_2026_2027"  # removed by ADR-104
JOINED = "SPWS_EVF_JOINED_V1_2026_2027"

# The columns ADR-104 drops with the place-and-medal engine.
RETIRED_KEYS = frozenset(
    {
        "int_category_count",
        "int_category_place",
        "int_below_count",
        "num_field_pts",
        "num_below_pts",
        "num_medal_bonus",
    }
)


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
            JOINED: JOINED_BRACKET_CATEGORY_PLACE,
        }
        assert module_for(CLASSIC, "PPW").name == PER_CATEGORY_RENUMBER
        # JB27.ING.01 the joined engine is filed by the joined module.
        assert module_for(JOINED, "PPW").name == JOINED_BRACKET_CATEGORY_PLACE

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
        {1,2,2,3}; N is the category's own row count."""
        plan = module_for(CLASSIC, "PPW").plan_category(
            [1, 4, 4, 7], [1, 4, 4, 7], BracketField.from_places(range(1, 11))
        )
        assert [r.place for r in plan.rows] == [1, 2, 2, 3]
        assert plan.participant_count == 4

    def test_commit_rows_byte_identical_under_classic(self):
        """SE27.ING.02 Commit under EVF classic writes exactly the rows and the
        per-category count it wrote before ADR-103 (each row now also carries
        ADR-106's printed federation, None for a domestic source)."""
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
                    "txt_entered_for": None,
                },
                {
                    "id_fencer": 102,
                    "int_place": 2,
                    "txt_scraped_name": "FENCER 102",
                    "num_confidence": 100.0,
                    "enum_match_status": "AUTO_MATCHED",
                    "txt_entered_for": None,
                },
            ],
            2,
        )
        # JB27.ING.06 no order goes with a classic write: the call is unchanged.
        assert [c.kwargs for c in db.ingest_results.call_args_list] == [
            {"participant_count": 2},
            {"participant_count": 2},
        ]


# ---------------------------------------------------------------------------
# SE27.ING.03-04 — JOINED_BRACKET_CATEGORY_PLACE
# ---------------------------------------------------------------------------


class TestJoinedBracketCategoryPlace:
    def test_joined_example_keeps_place_and_n(self):
        """SE27.ING.03 the V1+V2+V3 bracket of 10: each category keeps the
        joined places and N = 10."""
        field = BracketField.from_places(range(1, 11))
        plan = module_for(JOINED, "PPW").plan_category(EXAMPLE["V2"], EXAMPLE["V2"], field)
        assert plan.participant_count == 10
        assert [r.place for r in plan.rows] == [2, 3, 6, 9]

    def test_a_place_outside_the_field_is_refused(self):
        """SE27.ING.04 a joined place beyond the listing is corrupt input."""
        with pytest.raises(ValueError, match="exceeds the bracket"):
            module_for(JOINED, "PPW").plan_category(
                [12], [12], BracketField.from_places(range(1, 11))
            )

    def test_commit_files_each_category_with_the_joined_bracket(self):
        """SE27.ING.03 Commit under the joined module writes the joined places
        and N = the whole listing in every category's tournament."""
        ids = iter(range(1, 100))
        fv = {
            vcat: [_match(next(ids), p) for p in places] for vcat, places in sorted(EXAMPLE.items())
        }
        db = _db(JOINED)
        _run(Commit(), _ctx(fv, _parsed(range(1, 11))), db)
        written = _written(db)
        rows_v1, n_v1 = written[301]
        assert n_v1 == 10
        assert [r["int_place"] for r in rows_v1] == [1, 4]
        assert {n for _, n in written.values()} == {10}
        db.get_type_engine.assert_called_once_with(4, "PPW")


# ---------------------------------------------------------------------------
# SE27.ING.06 — RECOMPUTE_DOMESTIC uses the paired module
# ---------------------------------------------------------------------------


def _rmatch(id_fencer, place, by, *, n=10, url="https://example.test/ppw1", order=None):
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
        bracket_key=url,
        joined_order=order,
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

    def test_joined_recompute_keeps_places_and_n(self):
        """SE27.ING.06 a birth-year relocation re-files a fencer but keeps the
        joined place and N."""
        # Born 1980 -> 47 in 2027 -> V1; born 1970 -> 57 -> V2.
        order = "1122211111"
        matches = [
            _rmatch(1, 1, 1980, order=order),
            _rmatch(2, 2, 1980, order=order),
            _rmatch(3, 3, 1970, order=order),
            _rmatch(4, 5, 1970, order=order),
        ]
        db = self._recompute(matches, JOINED)
        written = sorted(_written(db).values(), key=lambda w: w[0][0]["int_place"])
        (v1_rows, v1_n), (v2_rows, v2_n) = written
        assert (v1_n, v2_n) == (10, 10)
        assert [r["int_place"] for r in v1_rows] == [1, 2]
        assert [r["int_place"] for r in v2_rows] == [3, 5]

    def test_classic_recompute_still_renumbers(self):
        """SE27.ING.06 under EVF classic a recompute renumbers 1..K, as before."""
        matches = [_rmatch(1, 4, 1970), _rmatch(2, 9, 1970)]
        db = self._recompute(matches, CLASSIC)
        ((rows, n),) = _written(db).values()
        assert n == 2
        assert [r["int_place"] for r in rows] == [1, 2]

    def test_joined_recompute_refuses_to_merge_two_brackets(self):
        """SE27.ING.06 one category tournament cannot hold two joined brackets:
        their places and N are not comparable, so recompute stops."""
        matches = [
            _rmatch(1, 1, 1970, url="https://example.test/a", order="2222222222"),
            _rmatch(2, 1, 1970, url="https://example.test/b", order="2222222222"),
        ]
        with pytest.raises(ValueError, match="two joined brackets"):
            self._recompute(matches, JOINED)


# ---------------------------------------------------------------------------
# SE27.ING.07-08 — the joined N is what the count check and the gate see
# ---------------------------------------------------------------------------


class TestJoinedN:
    def test_committed_count_is_the_whole_listing(self):
        """SE27.ING.07 the participant count Commit records — the number the
        ADR-069 URL check compares — is the whole listing, not a slice."""
        fv = {
            "V1": [_match(1, 1), _match(None, 3, method="EXCLUDED")],
            "V2": [
                _match(2, 2),
                _match(None, 4, method="EXCLUDED"),
                _match(None, 5, method="EXCLUDED"),
            ],
        }
        db = _db(JOINED)
        ctx = _run(Commit(), _ctx(fv, _parsed([1, 2, 3, 4, 5])), db)
        assert {t["n"] for t in ctx.get("committed")["tournaments"]} == {5}

    def test_unmatched_fencers_count_in_n(self):
        """SE27.ING.08 a listed fencer who is not written (no match) but has a
        category still counts in N and in the order: the gate and the engine
        read the listing, len(parsed.results), not the rows stored."""
        fv = {"V2": [_match(1, 1), _match(None, 2, method="EXCLUDED"), _match(3, 3)]}
        db = _db(JOINED)
        _run(Commit(), _ctx(fv, _parsed([1, 2, 3])), db)
        ((rows, n),) = _written(db).values()
        assert n == 3
        assert [r["int_place"] for r in rows] == [1, 3]
        assert db.ingest_results.call_args.kwargs["joined_order"] == "222"


# ---------------------------------------------------------------------------
# SE27.ING.09 — international results never reach the joined module
# ---------------------------------------------------------------------------


class TestInternational:
    @pytest.mark.parametrize("ttype", ["PEW", "MEW", "MSW", "PSW"])
    def test_international_type_refuses_the_joined_module(self, ttype):
        """SE27.ING.09 EVF and FIE publish per category; an international type
        assigned the joined module is refused rather than re-joined. Amended by
        ADR-105: under EVF classic it is filed by the source-field module (whole
        source bracket as N, own place), never PER_CATEGORY_RENUMBER —
        python/tests/test_international_field.py INTL.MOD.01."""
        with pytest.raises(JoinedBracketNotAllowed):
            module_for(JOINED, ttype)
        assert module_for(CLASSIC, ttype).name == SOURCE_FIELD_PLACE


# ---------------------------------------------------------------------------
# JB27.CLEAN.05 — no Python path sends K, m or b (ADR-104 §1, §4)
# ---------------------------------------------------------------------------


class TestPlaceMedalRemoved:
    def test_registry_names_no_removed_engine(self):
        """JB27.CLEAN.05 the removed engine has no module: the pipeline refuses
        it exactly as the SQL dispatcher does."""
        assert PLACE_MEDAL not in MODULE_BY_ENGINE
        with pytest.raises(UnknownScoringEngine):
            module_for(PLACE_MEDAL, "PPW")

    def test_row_plan_is_the_place_alone(self):
        """JB27.CLEAN.05 a planned row carries its place and nothing else."""
        assert [f.name for f in dataclasses.fields(RowPlan)] == ["place"]

    def test_pzsz_rows_and_queue_carry_no_k_m_b(self):
        """JB27.CLEAN.05 a senior bracket writes its rows and queues its
        uncertain matches without K, m or b; the queue takes five values."""
        parsed = _parsed(range(1, 13))
        parsed.gender = "M"
        ctx = _ctx({}, parsed, ttype_code="PPS1e-2026-2027")
        ctx.data["matches"] = [
            _match(501, 3, governed_birth_year=1960),
            _match(
                None, 7, name="Uncertain Name", method="PENDING", alternatives=[{"id_fencer": 55}]
            ),
        ]
        db = _db(CLASSIC)
        db.find_or_create_tournament.side_effect = [601]
        _run(CommitPzszSenior(), ctx, db)
        (_, rows), kwargs = db.ingest_results.call_args
        assert kwargs["participant_count"] == 12
        assert rows[0]["int_place"] == 3
        assert not RETIRED_KEYS & rows[0].keys()
        db.queue_pzsz_match_review.assert_called_once_with(601, "Uncertain Name", 7, 55, 100.0)

    def test_queue_rpc_sends_five_parameters(self):
        """JB27.CLEAN.05 the review-queue RPC is called with the five
        parameters ADR-100 defined, and no count of fencers below."""
        sb = MagicMock()
        sb.rpc.return_value.execute.return_value.data = 77
        assert DbConnector(sb).queue_pzsz_match_review(601, "Uncertain Name", 7, 55, 100.0) == 77
        (name, params), _ = sb.rpc.call_args
        assert name == "fn_queue_pzsz_match_review"
        assert set(params) == {
            "p_id_tournament",
            "p_txt_scraped_name",
            "p_int_place",
            "p_id_candidate_fencer",
            "p_num_confidence",
        }

    def test_recompute_fetch_reads_no_below(self):
        """JB27.CLEAN.05 the recompute fetch neither selects nor returns b."""
        sb = MagicMock()
        tournaments = MagicMock()
        tournaments.data = [
            {
                "id_tournament": 1,
                "enum_weapon": "EPEE",
                "enum_gender": "M",
                "enum_age_category": "V2",
                "dt_tournament": "2026-10-11",
                "int_participant_count": 10,
                "url_results": "https://example.test/ppw1",
            }
        ]
        results = MagicMock()
        results.data = [{"id_fencer": 5, "int_place": 3, "id_tournament": 1}]
        sb.table.return_value.select.return_value.eq.return_value.execute.return_value = tournaments
        sb.table.return_value.select.return_value.in_.return_value.execute.return_value = results
        db = DbConnector(sb)
        db.fetch_birth_years_batch = MagicMock(return_value={5: 1970})
        rows = db.fetch_event_results(9)
        selected = " ".join(str(c.args[0]) for c in sb.table.return_value.select.call_args_list)
        assert "int_below_count" not in selected
        assert rows and "below_count" not in rows[0]

    def test_no_pipeline_source_names_a_retired_column(self):
        """JB27.CLEAN.05 no pipeline module writes, reads or exports a column
        ADR-104 dropped."""
        root = pathlib.Path(__file__).resolve().parents[1] / "pipeline"
        offenders = sorted(
            f"{path.relative_to(root)}: {key}"
            for path in root.rglob("*.py")
            for key in RETIRED_KEYS
            if key in path.read_text(encoding="utf-8")
        )
        assert offenders == []


# ---------------------------------------------------------------------------
# JB27.ING.02-05 — the listing's category order (ADR-104 §3, §4)
# ---------------------------------------------------------------------------


class TestJoinedOrder:
    def test_order_holds_every_categorised_fencer_and_reaches_every_sibling(self):
        """JB27.ING.02 the order has one digit per place of the listing — an
        unmatched fencer with a category included — and every category's
        tournament receives the same order and the joined N."""
        ids = iter(range(1, 100))
        fv = {
            vcat: [_match(next(ids), p) for p in places] for vcat, places in sorted(EXAMPLE.items())
        }
        fv["V3"][1] = _match(None, 7, method="EXCLUDED")
        db = _db(JOINED)
        _run(Commit(), _ctx(fv, _parsed(range(1, 11))), db)
        calls = {c.args[0]: c.kwargs for c in db.ingest_results.call_args_list}
        assert calls == {
            301: {"participant_count": 10, "joined_order": "1221323323"},
            302: {"participant_count": 10, "joined_order": "1221323323"},
            303: {"participant_count": 10, "joined_order": "1221323323"},
        }

    def test_a_joined_listing_with_a_repeated_place_is_refused(self):
        """JB27.ING.03 two categories share place 2: nothing says which of the
        two fenced ahead, so the listing is refused and nothing is written."""
        fv = {"V1": [_match(1, 1), _match(2, 2)], "V2": [_match(3, 2), _match(4, 4)]}
        db = _db(JOINED)
        with pytest.raises(ValueError, match="fenced order"):
            _run(Commit(), _ctx(fv, _parsed([1, 2, 2, 4])), db)
        db.ingest_results.assert_not_called()

    def test_a_tie_in_a_single_category_is_accepted(self):
        """JB27.ING.03 a tie inside one category scores as EVF classic always
        has: the order is that category's digit at every place."""
        fv = {"V2": [_match(1, 1), _match(2, 2), _match(3, 3), _match(4, 3), _match(5, 5)]}
        db = _db(JOINED)
        _run(Commit(), _ctx(fv, _parsed([1, 2, 3, 3, 5])), db)
        ((rows, n),) = _written(db).values()
        assert n == 5
        assert [r["int_place"] for r in rows] == [1, 2, 3, 3, 5]
        assert db.ingest_results.call_args.kwargs["joined_order"] == "22222"

    def test_a_fencer_without_a_category_is_refused(self):
        """JB27.ING.04 place 3 has no category (a pending match or no birth
        year): the order cannot be written, so the listing waits."""
        fv = {"V2": [_match(1, 1), _match(2, 2)]}
        db = _db(JOINED)
        with pytest.raises(ValueError, match="no category"):
            _run(Commit(), _ctx(fv, _parsed([1, 2, 3])), db)
        db.ingest_results.assert_not_called()

    def test_recompute_patches_only_the_stored_digits_that_moved(self):
        """JB27.ING.05 after a birth-year correction the fencer at place 4
        moves from V1 to V2: that digit changes, the digits of places never
        stored stay, and both category tournaments get the patched order."""
        order = "1221323323"
        # Born 1980 -> 47 in 2027 -> V1; born 1970 -> 57 -> V2.
        matches = [_rmatch(1, 1, 1980, order=order), _rmatch(2, 4, 1970, order=order)]
        db = TestRecompute()._recompute(matches, JOINED)
        calls = sorted(
            ((c.args[1][0]["int_place"], c.kwargs) for c in db.ingest_results.call_args_list),
            key=lambda x: x[0],
        )
        assert calls == [
            (1, {"participant_count": 10, "joined_order": "1222323323"}),
            (4, {"participant_count": 10, "joined_order": "1222323323"}),
        ]

    def test_the_connector_sends_the_order_to_the_rpc(self):
        """JB27.ING.02 the order reaches fn_ingest_tournament_results as
        p_joined_order; a classic write sends no such key."""
        sb = MagicMock()
        db = DbConnector(sb)
        db.ingest_results(
            301, [{"id_fencer": 1, "int_place": 1}], participant_count=10, joined_order="12"
        )
        db.ingest_results(302, [{"id_fencer": 2, "int_place": 1}], participant_count=2)
        (first, second) = [c.args for c in sb.rpc.call_args_list]
        assert first[1]["p_joined_order"] == "12"
        assert "p_joined_order" not in second[1]

    def test_the_recompute_fetch_reads_the_stored_order(self):
        """JB27.ING.05 the recompute fetch returns each row's stored order."""
        sb = MagicMock()
        tournaments = MagicMock()
        tournaments.data = [
            {
                "id_tournament": 1,
                "enum_weapon": "EPEE",
                "enum_gender": "M",
                "enum_age_category": "V2",
                "dt_tournament": "2026-10-11",
                "int_participant_count": 4,
                "url_results": "https://example.test/ppw1",
                "txt_joined_order": "2322",
            }
        ]
        results = MagicMock()
        results.data = [{"id_fencer": 5, "int_place": 3, "id_tournament": 1}]
        sb.table.return_value.select.return_value.eq.return_value.execute.return_value = tournaments
        sb.table.return_value.select.return_value.in_.return_value.execute.return_value = results
        db = DbConnector(sb)
        db.fetch_birth_years_batch = MagicMock(return_value={5: 1970})
        (row,) = db.fetch_event_results(9)
        assert row["joined_order"] == "2322"


# ---------------------------------------------------------------------------
# JB27.STORE.04 — the seed export carries the input, never the outputs
# ---------------------------------------------------------------------------


class TestSeedExport:
    def test_scoring_outputs_are_skipped_and_the_order_is_not(self):
        """JB27.STORE.04 the premium, the cap reduction and d are recomputed by
        the post-seed rescore, like every other scoring output, so the export
        skips them; the order is an input and is exported with the tournament."""
        from python.pipeline.export_seed import RESULT_SKIP_COLUMNS

        assert {"num_joined_premium", "num_cap_reduction", "int_category_steps"} <= (
            RESULT_SKIP_COLUMNS
        )
        assert "txt_joined_order" not in RESULT_SKIP_COLUMNS
        assert {"num_final_score", "enum_score_method", "id_scoring_revision"} <= (
            RESULT_SKIP_COLUMNS
        )
