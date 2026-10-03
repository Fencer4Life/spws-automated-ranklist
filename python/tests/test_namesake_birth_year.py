"""NAMESAKE.01–09 — namesakes are told apart by birth year on every domestic path.

The exact-name step (`stages._lookup_exact_fencer`) used to return the first
roster fencer whose name matched, without looking at the birth year. PROD holds
two live same-name pairs, KRAWCZYK Paweł (1954 and 1989) and MŁYNEK Janusz (1951
and 1984). The 1 Oct 2026 PPW1 trial filed both V4 results under the young
namesakes and overwrote their confirmed birth years with 1957.

The rule now:
  - several namesakes: the one whose birth year fits the row's category; when
    none or several fit, the row is undecided and waits for a person;
  - one fencer: his stored birth year may sit at most one category away from
    the row's category (ADR-056 moves it). Two or more categories away is a
    data error: the row is undecided and nothing is written (decision D1 A,
    3 Oct 2026).
An undecided domestic row is PENDING, and Commit refuses its listing.
"""

from __future__ import annotations

from datetime import date
from unittest.mock import MagicMock

import pytest

from python.pipeline import stages
from python.pipeline.core.contract import Context, Services
from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind
from python.pipeline.plugins import resolve_fencers as rf
from python.pipeline.plugins.bridge import LEGACY, ensure_pctx
from python.pipeline.plugins.ingest import Commit
from python.pipeline.types import Overrides, PipelineContext, StageMatchResult

SEASON_END = 2027  # SPWS-2026-2027
EVENT = "PPW1-2026-2027"
JOINED = "SPWS_EVF_JOINED_V1_2026_2027"
CLASSIC = "EVF_CLASSIC_V1_2025_2026"


def _fencer(id_, surname, first, by, *, estimated=False, gender="M"):
    return {
        "id_fencer": id_,
        "txt_surname": surname,
        "txt_first_name": first,
        "int_birth_year": by,
        "bool_birth_year_estimated": estimated,
        "txt_nationality": "POL",
        "enum_gender": gender,
        "json_name_aliases": [],
    }


# The PROD pairs, the young namesake read first (ids as on PROD, 3 Oct 2026).
KRAWCZYK_1989 = _fencer(354, "KRAWCZYK", "Paweł", 1989)
KRAWCZYK_1954 = _fencer(355, "KRAWCZYK", "Paweł", 1954)
MLYNEK_1984 = _fencer(356, "MŁYNEK", "Janusz", 1984)
MLYNEK_1951 = _fencer(197, "MŁYNEK", "Janusz", 1951)


def _result(name, place=1, country="POL"):
    return ParsedResult(
        source_row_id=f"t:{name}:{place}",
        fencer_name=name,
        place=place,
        fencer_country=country,
    )


def _parsed(results, category_hint="V4", gender="M"):
    return ParsedTournament(
        source_kind=SourceKind.FTL,
        results=results,
        parsed_date=date(2026, 9, 26),
        weapon="EPEE",
        gender=gender,
        organizer_hint="SPWS",
        category_hint=category_hint,
        season_end_year=SEASON_END,
    )


# ---------------------------------------------------------------------------
# NAMESAKE.01–04, 09 — the lookup itself
# ---------------------------------------------------------------------------


class TestLookup:
    def test_krawczyk_v4_is_the_1954_namesake(self):
        """NAMESAKE.01 the 1989 namesake is read first; V4 is the 1954 one."""
        lk = stages._lookup_exact_fencer(
            "KRAWCZYK Paweł", "POL", [KRAWCZYK_1989, KRAWCZYK_1954], "V4", SEASON_END
        )
        assert lk.id_fencer == 355
        assert lk.reason is None

    def test_mlynek_v4_is_the_1951_namesake(self):
        """NAMESAKE.02 the 1984 namesake is read first; V4 is the 1951 one,
        and a source without Polish letters still finds him."""
        for name in ("MŁYNEK Janusz", "MLYNEK Janusz"):
            lk = stages._lookup_exact_fencer(
                name, "POL", [MLYNEK_1984, MLYNEK_1951], "V4", SEASON_END
            )
            assert lk.id_fencer == 197, name

    @pytest.mark.parametrize(
        ("fencers", "vcat"),
        [
            # both fit V2
            ([_fencer(1, "NOWAK", "Jan", 1970), _fencer(2, "NOWAK", "Jan", 1972)], "V2"),
            # neither fits V3
            ([KRAWCZYK_1989, KRAWCZYK_1954], "V3"),
            # no category for the row
            ([KRAWCZYK_1989, KRAWCZYK_1954], None),
            # one has no birth year: it cannot be shown to fit, the other fits;
            # still two candidates where one cannot be excluded
            ([_fencer(1, "NOWAK", "Jan", None), _fencer(2, "NOWAK", "Jan", 1970)], "V2"),
        ],
    )
    def test_undecided_namesakes_are_never_the_first_one_read(self, fencers, vcat):
        """NAMESAKE.03 none or several fit: undecided, with every namesake listed."""
        name = f"{fencers[0]['txt_surname']} {fencers[0]['txt_first_name']}"
        lk = stages._lookup_exact_fencer(name, "POL", fencers, vcat, SEASON_END)
        assert lk.id_fencer is None
        assert lk.reason == "namesakes_undecided"
        assert sorted(f["id_fencer"] for f in lk.namesakes) == sorted(
            f["id_fencer"] for f in fencers
        )

    def test_one_fencer_one_category_away_is_that_fencer(self):
        """NAMESAKE.04 one roster fencer, one category from the bracket: him
        (ADR-056 then moves his birth year)."""
        lk = stages._lookup_exact_fencer(
            "KOWALSKI Jan", "POL", [_fencer(7, "KOWALSKI", "Jan", 1990)], "V1", SEASON_END
        )
        assert lk.id_fencer == 7  # 1990 is V0 in 2027, the bracket is V1
        assert (
            stages._find_exact_fencer("KOWALSKI Jan", "POL", [_fencer(7, "KOWALSKI", "Jan", 1990)])
            == 7
        )

    @pytest.mark.parametrize(
        ("by", "estimated", "vcat"),
        [
            (1989, False, "V4"),  # V0 -> V4, confirmed
            (1989, True, "V4"),  # V0 -> V4, estimated
            (1987, False, "V3"),  # V1 -> V3
            (1954, False, "V2"),  # V4 -> V2, two categories down
        ],
    )
    def test_two_categories_away_is_a_data_error(self, by, estimated, vcat):
        """NAMESAKE.09 (D1 A) one roster fencer two or more categories from the
        bracket: never linked, never moved."""
        lk = stages._lookup_exact_fencer(
            "KRAWCZYK Paweł",
            "POL",
            [_fencer(354, "KRAWCZYK", "Paweł", by, estimated=estimated)],
            vcat,
            SEASON_END,
        )
        assert lk.id_fencer is None
        assert lk.reason == "category_gap"
        assert [f["id_fencer"] for f in lk.namesakes] == [354]


# ---------------------------------------------------------------------------
# NAMESAKE.05–06, 09 — ResolveFencers (INGEST_DOMESTIC, ingest-event.yml)
# ---------------------------------------------------------------------------


def _db(fencer_db, next_id=900):
    db = MagicMock()
    db.fetch_fencer_db.return_value = [dict(f) for f in fencer_db]
    seq = iter(range(next_id, next_id + 100))
    db.insert_fencer.side_effect = lambda payload: next(seq)
    return db


def _resolve(parsed, db):
    ctx = Context()
    pctx = ensure_pctx(
        ctx,
        parsed=parsed,
        overrides=Overrides(),
        season_end_year=SEASON_END,
        event_code=EVENT,
    )
    pctx.event = {"txt_code": EVENT, "enum_type": "PPW"}
    plugin = rf.ResolveFencers()
    ctx._begin(plugin)
    try:
        plugin.run(ctx, Services(db=db, config={}))
    finally:
        ctx._end()
    return ctx, pctx


class TestResolveFencers:
    def test_v4_result_goes_to_the_1954_namesake(self):
        """NAMESAKE.05 linked to 1954; no birth year written; nothing created."""
        db = _db([KRAWCZYK_1989, KRAWCZYK_1954])
        ctx, _ = _resolve(_parsed([_result("KRAWCZYK Paweł", 2)]), db)
        (m,) = ctx.get("matches")
        assert (m.id_fencer, m.method) == (355, "AUTO_MATCHED")
        db.update_fencer_birth_year.assert_not_called()
        db.insert_fencer.assert_not_called()

    def test_undecided_namesakes_wait(self):
        """NAMESAKE.06 both fit: PENDING with both as alternatives; no birth
        year written; nothing created; the conflict is reported."""
        pair = [_fencer(1, "NOWAK", "Jan", 1970), _fencer(2, "NOWAK", "Jan", 1972)]
        db = _db(pair)
        ctx, pctx = _resolve(_parsed([_result("NOWAK Jan")], category_hint="V2"), db)
        (m,) = ctx.get("matches")
        assert m.id_fencer is None
        assert m.method == "PENDING"
        assert sorted(a["id_fencer"] for a in m.alternatives) == [1, 2]
        db.update_fencer_birth_year.assert_not_called()
        db.insert_fencer.assert_not_called()
        assert [c["reason"] for c in pctx.reconcile_conflicts] == ["namesakes_undecided"]

    def test_category_gap_waits(self):
        """NAMESAKE.09 (D1 A) the only KRAWCZYK is 1989 and the bracket is V4:
        PENDING, his birth year untouched, nothing created."""
        db = _db([KRAWCZYK_1989])
        ctx, pctx = _resolve(_parsed([_result("KRAWCZYK Paweł", 2)]), db)
        (m,) = ctx.get("matches")
        assert (m.id_fencer, m.method) == (None, "PENDING")
        db.update_fencer_birth_year.assert_not_called()
        db.insert_fencer.assert_not_called()
        assert [c["reason"] for c in pctx.reconcile_conflicts] == ["category_gap"]


# ---------------------------------------------------------------------------
# NAMESAKE.07 — Commit refuses a domestic listing holding a PENDING row
# ---------------------------------------------------------------------------


def _commit_ctx(final_vcats, places):
    ctx = Context()
    event = {"id_event": 85, "txt_code": EVENT, "id_season": 5}
    parsed = ParsedTournament(
        source_kind=SourceKind.FTL,
        results=[
            ParsedResult(source_row_id=str(i), fencer_name=f"R{i}", place=p)
            for i, p in enumerate(places)
        ],
        parsed_date=date(2026, 9, 26),
        weapon="EPEE",
        gender="M",
        category_hint="V4",
        season_end_year=SEASON_END,
    )
    pctx = PipelineContext(
        parsed=parsed, overrides=Overrides(), season_end_year=SEASON_END, event_code=EVENT
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


@pytest.mark.parametrize("engine", [JOINED, CLASSIC])
def test_commit_refuses_a_domestic_listing_with_a_pending_row(engine):
    """NAMESAKE.07 the fencer and his namesakes are named; nothing is written."""
    pending = StageMatchResult(
        scraped_name="KRAWCZYK Paweł",
        place=2,
        id_fencer=None,
        confidence=100.0,
        method="PENDING",
        alternatives=[
            {"id_fencer": 354, "birth_year": 1989},
            {"id_fencer": 355, "birth_year": 1954},
        ],
    )
    ok = StageMatchResult(
        scraped_name="SOBIERAJ Wojciech",
        place=1,
        id_fencer=40,
        confidence=100.0,
        method="AUTO_MATCHED",
    )
    db = MagicMock()
    db.get_type_engine.return_value = engine
    db.find_or_create_tournament.side_effect = [301, 302]
    plugin = Commit()
    ctx = _commit_ctx({"V4": [ok, pending]}, [1, 2])
    ctx._begin(plugin)
    with pytest.raises(ValueError, match="KRAWCZYK Paweł"):
        plugin.run(ctx, Services(db=db))
    db.ingest_results.assert_not_called()


# ---------------------------------------------------------------------------
# NAMESAKE.08 — Stage 0 and S6 (the Phase 5 runner path)
# ---------------------------------------------------------------------------


class FakeDB:
    def __init__(self, fencers):
        self._fencers = [dict(f) for f in fencers]
        self.inserted: list[dict] = []
        self.updated: list[dict] = []

    def fetch_fencer_db(self):
        return [dict(f) for f in self._fencers]

    def fetch_registration_birth_years(self, _event_code):
        return []

    def insert_fencer(self, payload):
        rec = dict(payload, id_fencer=1000 + len(self.inserted))
        self._fencers.append(rec)
        self.inserted.append(rec)
        return rec["id_fencer"]

    def update_fencer_birth_year(self, fencer_id, birth_year, estimated=False):
        self.updated.append({"id_fencer": fencer_id, "int_birth_year": birth_year})
        for f in self._fencers:
            if f["id_fencer"] == fencer_id:
                f["int_birth_year"] = birth_year
                f["bool_birth_year_estimated"] = estimated


def _s_ctx(results, category_hint="V4"):
    ctx = PipelineContext(
        parsed=_parsed(results, category_hint=category_hint),
        overrides=Overrides(),
        season_end_year=SEASON_END,
        event_code=EVENT,
    )
    ctx.event = {"txt_code": EVENT, "enum_type": "PPW"}
    return ctx


class TestStage0AndS6:
    def test_stage0_touches_only_the_namesake_who_fits(self):
        """NAMESAKE.08a decided: no insert, the 1989 namesake untouched."""
        db = FakeDB([KRAWCZYK_1989, KRAWCZYK_1954])
        stages.s0_reconcile_roster(_s_ctx([_result("KRAWCZYK Paweł", 2)]), db)
        assert db.inserted == []
        assert db.updated == []

    def test_stage0_undecided_neither_creates_nor_moves(self):
        """NAMESAKE.08b undecided / category gap: no insert, no write, reported."""
        pair = [_fencer(1, "NOWAK", "Jan", 1970), _fencer(2, "NOWAK", "Jan", 1972)]
        db = FakeDB(pair)
        ctx = _s_ctx([_result("NOWAK Jan")], category_hint="V2")
        stages.s0_reconcile_roster(ctx, db)
        assert db.inserted == [] and db.updated == []
        assert [c["reason"] for c in ctx.reconcile_conflicts] == ["namesakes_undecided"]

        db = FakeDB([KRAWCZYK_1989])
        ctx = _s_ctx([_result("KRAWCZYK Paweł", 2)])
        stages.s0_reconcile_roster(ctx, db)
        assert db.inserted == [] and db.updated == []
        assert [c["reason"] for c in ctx.reconcile_conflicts] == ["category_gap"]

    def test_s6_holds_a_category_gap_even_on_an_estimated_year(self):
        """NAMESAKE.08c the matcher accepts an estimated year it cannot verify;
        a two-category gap is still PENDING on a domestic event."""
        db = FakeDB([_fencer(354, "KRAWCZYK", "Paweł", 1989, estimated=True)])
        ctx = _s_ctx([_result("KRAWCZYK Paweł", 2)])
        stages.s6_resolve_identity(ctx, db)
        (m,) = ctx.matches
        assert m.method == "PENDING"
        assert m.id_fencer is None


def test_report_names_the_waiting_row_and_its_namesakes():
    """NAMESAKE.10 the staging report says why the row waits and lists the
    namesakes with their birth years."""
    from python.pipeline.plugins.staging_formatter import _render_reconciled

    ctx = _s_ctx([_result("KRAWCZYK Paweł", 2)], category_hint="V3")
    stages.s0_reconcile_roster(ctx, FakeDB([KRAWCZYK_1989, KRAWCZYK_1954]))
    text = _render_reconciled({"reconciled": [], "conflicts": ctx.reconcile_conflicts})
    assert "KRAWCZYK Paweł" in text
    assert "1989" in text and "1954" in text
    assert "#None" not in text
