"""ROUTE — ingest for CERT, promote for PROD, for every organizer (ADR-113).

Telegram `ingest <code>` runs the ingestion on CERT and `promote <code>` runs
the same ingestion on PROD (ADR-108, ADR-111 §6). EVF events (PEW, MEW, the
IMEW code) and FIE events (MSW, PSW, the IMSW code) take that route too:

  ROUTE.FLOW   the international flow and its steps;
  ROUTE.SRC    every bracket of an international event, from every result URL
               of the event, or from EVF's results when it has none;
  ROUTE.INTL   the event driver ingest and promote's plan both run.
"""

from __future__ import annotations

from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import pytest

from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind

SCHEDULE = "https://www.fencingtimelive.com/tournaments/eventSchedule/CD17"
ENGARDE = "https://engarde-service.com/competition/evf/budapest2025"


def _rows(*places, country="ITA"):
    return [
        ParsedResult(
            source_row_id=f"r{p}", fencer_name=f"FENCER{p} Jan", place=p, fencer_country=country
        )
        for p in places
    ]


def _parsed(
    category: str | None = "V1", weapon="FOIL", gender="M", url="https://x/1", places=(1, 2, 3)
):
    return ParsedTournament(
        source_kind=SourceKind.ENGARDE,
        results=_rows(*places),
        raw_pool_size=len(places),
        weapon=weapon,
        gender=gender,
        category_hint=category,
        source_url=url,
        tournament_name=f"{weapon} {gender} {category}",
    )


# --------------------------------------------------------------------------
# ROUTE.FLOW — the international flow
# --------------------------------------------------------------------------


class TestInternationalFlow:
    def test_the_flow_plans_from_the_real_rulebook_as_a_valid_dag(self):
        """ROUTE.FLOW.01 INGEST_INTERNATIONAL is the domestic flow's parse,
        event, identity, count and commit steps, without the steps that split
        or renumber a bracket, and files by the source category."""
        from python.pipeline.engine.flows import Flow, FlowParams
        from python.pipeline.engine.rule_engine import RuleEngine
        from python.pipeline.engine.rulebook import PLUGINS, RULEBOOK

        plan = RuleEngine(RULEBOOK, PLUGINS).plan(FlowParams(Flow.INGEST_INTERNATIONAL))
        assert plan.names == [
            "ParseSource",
            "ValidateIR",
            "ResolveEvent",
            "ResolveFencers",
            "ValidateCounts",
            "AssignSourceVcat",
            "Commit",
        ]

    def test_every_admitted_fencer_is_filed_under_the_brackets_own_category(self):
        """ROUTE.FLOW.02 a fencer whose birth year gives another category in our
        season (fenced V1, SPWS V2) stays in the bracket he fenced (ADR-105)."""
        from python.pipeline.core.contract import Context, Services
        from python.pipeline.plugins.ingest import AssignSourceVcat

        a = SimpleNamespace(id_fencer=1, place=2, governed_birth_year=1977, method="AUTO_MATCHED")
        b = SimpleNamespace(id_fencer=2, place=5, governed_birth_year=1984, method="AUTO_MATCHED")
        pctx = SimpleNamespace(parsed=_parsed("V1"), matches=[a, b], season_end_year=2027)
        ctx = Context()
        ctx.set("matches", [a, b])
        with patch("python.pipeline.plugins.ingest.get_pctx", return_value=pctx):
            AssignSourceVcat().run(ctx, Services(db=MagicMock()))
        assert ctx.get("final_vcats") == {"V1": [a, b]}

    def test_a_bracket_without_one_source_category_is_refused(self):
        """ROUTE.FLOW.03 no category is invented from a birth year (ADR-105 §5.3)."""
        from python.pipeline.core.contract import Context, Services
        from python.pipeline.plugins.ingest import AssignSourceVcat

        pctx = SimpleNamespace(parsed=_parsed(None), matches=[], season_end_year=2027)
        ctx = Context()
        ctx.set("matches", [])
        with (
            patch("python.pipeline.plugins.ingest.get_pctx", return_value=pctx),
            pytest.raises(ValueError, match="no single source category"),
        ):
            AssignSourceVcat().run(ctx, Services(db=MagicMock()))

    def test_an_international_row_carries_its_source_category(self):
        """ROUTE.FLOW.04 Commit writes the bracket's category on every row of an
        international bracket, so the V-category guard trusts the bracket over
        a birth year that points elsewhere (ADR-056 revision)."""
        from python.pipeline.joined_brackets import SOURCE_FIELD_PLACE
        from python.pipeline.plugins.ingest import Commit

        m = SimpleNamespace(
            id_fencer=7,
            place=2,
            method="AUTO_MATCHED",
            confidence=100.0,
            scraped_name="FENCER2 Jan",
            entered_for="POL",
            governed_birth_year=1977,
        )
        rows = Commit._source_category_rows([{"id_fencer": 7}], SOURCE_FIELD_PLACE, "V1")
        assert rows == [{"id_fencer": 7, "enum_source_age_category": "V1"}]
        assert Commit._source_category_rows([{"id_fencer": 7}], "OTHER", "V1") == [{"id_fencer": 7}]
        assert m.place == 2


# --------------------------------------------------------------------------
# ROUTE.SRC — the brackets of an international event
# --------------------------------------------------------------------------


class TestEventSourceUrls:
    def test_every_result_slot_is_read_once_in_order(self):
        """ROUTE.SRC.01 url_event … url_event_5, blanks and repeats dropped."""
        from python.pipeline.international_sources import event_source_urls

        event = {
            "url_event": SCHEDULE,
            "url_event_2": "",
            "url_event_3": ENGARDE,
            "url_event_4": SCHEDULE,
            "url_event_5": None,
        }
        assert event_source_urls(event) == [SCHEDULE, ENGARDE]
        assert event_source_urls(event, override="https://y") == ["https://y"]


class _Resp:
    def __init__(self, text="", js=None):
        self.text = text
        self._js = js

    def raise_for_status(self):
        pass

    def json(self):
        return self._js


class _Client:
    def __init__(self, data):
        self.data = data
        self.got: list[str] = []

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False

    def get(self, url):
        self.got.append(url)
        if "eventSchedule" in url:
            return _Resp(text="<schedule/>")
        uuid = url.rsplit("/", 1)[-1]
        return _Resp(js=self.data[uuid])


def _ftl_rows(n, *, pol_at=()):
    return [
        {
            "id": f"f{p}",
            "name": f"SURNAME{p} Jan",
            "place": str(p),
            "country": "POL" if p in pol_at else "ITA",
        }
        for p in range(1, n + 1)
    ]


def _read_schedule(kept, skipped, data):
    from python.pipeline import international_sources as src

    client = _Client(data)
    with (
        patch("python.scrapers.ftl_auth.get_authed_ftl_client", return_value=client),
        patch("python.scrapers.ftl_auth.normalize_ftl_url", side_effect=lambda u: u),
        patch(
            "python.tools.scrape_ftl_event_urls.parse_event_schedule",
            return_value=(kept, skipped),
        ),
    ):
        return src.read_brackets({"txt_code": "MSW-2026-2027"}, [SCHEDULE]), client


class TestFtlSchedule:
    KEPT = [
        {"uuid": "A1", "name": "Vet-40 Men's Foil", "finished": True, "day": "2026-10-10"},
        {"uuid": "A2", "name": "Vet-50 Women's Sabre", "finished": True, "day": "2026-10-11"},
        {"uuid": "A3", "name": "Vet-60 Men's Epee", "finished": False, "day": "2026-10-17"},
    ]
    SKIPPED = [{"uuid": "T1", "name": "Vet Team Men's Foil", "reason": "team event"}]

    def test_each_finished_bracket_is_one_listing_with_its_category_and_whole_n(self):
        """ROUTE.SRC.02 one listing per finished bracket: the category its name
        carries, every fencer of the bracket (N), keyed by its FTL id."""
        (recs, kept, skipped), _ = _read_schedule(
            self.KEPT,
            self.SKIPPED,
            {"A1": _ftl_rows(62, pol_at=(2,)), "A2": _ftl_rows(45, pol_at=(12,))},
        )
        assert [(r["uuid"], r["weapon"], r["gender"], r["cats"], r["count"]) for r in recs] == [
            ("A1", "FOIL", "M", ["V1"], 62),
            ("A2", "SABRE", "F", ["V2"], 45),
        ]
        first = recs[0]["_base"]
        assert first.category_hint == "V1" and first.raw_pool_size == 62
        assert first.source_url == "https://www.fencingtimelive.com/events/results/A1"
        assert str(first.parsed_date) == "2026-10-10"
        assert [k["uuid"] for k in kept] == ["A1", "A2"]

    def test_team_and_unfinished_brackets_are_skipped_and_listed(self):
        """ROUTE.SRC.03 a team bracket lists teams, not places (ADR-105 §5.5); an
        unfinished one keeps the event IN_PROGRESS (ADR-108 §7)."""
        (recs, _, skipped), client = _read_schedule(
            self.KEPT, self.SKIPPED, {"A1": _ftl_rows(3), "A2": _ftl_rows(3)}
        )
        assert [s["name"] for s in skipped] == ["Vet Team Men's Foil", "Vet-60 Men's Epee"]
        assert not any("A3" in u for u in client.got)

    def test_a_bracket_without_one_category_refuses_the_event_before_any_write(self):
        """ROUTE.SRC.04 ADR-105 §5.3."""
        kept = [{"uuid": "C1", "name": "Vet Combined Men's Foil", "finished": True, "day": None}]
        with (
            patch(
                "python.tools.scrape_ftl_event_urls.parse_tournament_name",
                return_value=[("FOIL", "M", "V1"), ("FOIL", "M", "V2")],
            ),
            pytest.raises(ValueError, match="single source category"),
        ):
            _read_schedule(kept, [], {"C1": _ftl_rows(3)})


class TestOtherSources:
    def test_a_non_ftl_url_is_read_by_the_phase_5_reader(self):
        """ROUTE.SRC.05 Engarde, 4fence, Ophardt, d'Artagnan: the reader Phase 5
        uses, each bracket keyed by its own results URL."""
        from python.pipeline import international_sources as src

        fetcher = MagicMock()
        fetcher.fetch_event_url_with_skips.return_value = (
            [
                _parsed("V2", "EPEE", "F", "https://e/1", (1, 2)),
                _parsed("V3", "EPEE", "M", "https://e/2"),
            ],
            [{"name": "Equipes", "url": "https://e/t", "reason": "team event"}],
        )
        recs, kept, skipped = src.read_brackets(
            {"txt_code": "PEW3-2026-2027"}, [ENGARDE], fetcher=fetcher
        )
        fetcher.fetch_event_url_with_skips.assert_called_once_with(ENGARDE)
        assert [(r["uuid"], r["cats"], r["count"]) for r in recs] == [
            ("https://e/1", ["V2"], 2),
            ("https://e/2", ["V3"], 3),
        ]
        assert [k["uuid"] for k in kept] == ["https://e/1", "https://e/2"]
        assert skipped == [{"name": "Equipes", "url": "https://e/t", "reason": "team event"}]

    def test_two_sources_for_one_bracket_refuse_the_event(self):
        """ROUTE.SRC.06 a tournament holds one source bracket's N (ADR-105 §5.4)."""
        from python.pipeline import international_sources as src

        fetcher = MagicMock()
        fetcher.fetch_event_url_with_skips.return_value = (
            [_parsed("V2", url="https://e/1"), _parsed("V2", url="https://e/9")],
            [],
        )
        with pytest.raises(ValueError, match="two sources"):
            src.read_brackets({"txt_code": "PEW3-2026-2027"}, [ENGARDE], fetcher=fetcher)

    def test_without_a_url_the_evf_results_are_read(self):
        """ROUTE.SRC.07 (Q3 A) EVF's own results, when the event has no result
        URL (ADR-105 §1.5): one bracket per weapon, gender and category, N its
        size."""
        from python.pipeline import international_sources as src

        rows = [
            {
                "fencer_name": "ROSSI Mario",
                "place": 1,
                "country": "ITA",
                "weapon": "FOIL",
                "gender": "M",
                "category": "V2",
            },
            {
                "fencer_name": "NOWAK Jan",
                "place": 2,
                "country": "POL",
                "weapon": "FOIL",
                "gender": "M",
                "category": "V2",
            },
            {
                "fencer_name": "KOWALSKA Anna",
                "place": 1,
                "country": "POL",
                "weapon": "SABRE",
                "gender": "F",
                "category": "V1",
            },
        ]
        event = {"txt_code": "PEW3-2026-2027", "id_evf_event": 85}
        # The EVF results are a source of their own, so the run records them
        # and promote and the daily close read the same thing.
        assert src.event_sources(event) == [{"slot": "evf", "url": "evf:85"}]
        scrape = MagicMock(return_value=rows)
        recs, kept, skipped = src.read_brackets(event, ["evf:85"], evf_scrape=scrape)
        scrape.assert_called_once_with(85)
        assert [(r["weapon"], r["gender"], r["cats"], r["count"]) for r in recs] == [
            ("FOIL", "M", ["V2"], 2),
            ("SABRE", "F", ["V1"], 1),
        ]
        assert recs[0]["_base"].source_kind == SourceKind.EVF_API
        assert recs[0]["_base"].results[1].fencer_country == "POL"
        assert [k["uuid"] for k in kept] == ["evf:85:FOIL:M:V2", "evf:85:SABRE:F:V1"]

    def test_no_url_and_no_evf_event_refuses(self):
        """ROUTE.SRC.08"""
        from python.pipeline import international_sources as src

        assert src.event_sources({"txt_code": "MSW-2026-2027"}) == []
        with pytest.raises(ValueError, match="no result URL"):
            src.read_brackets({"txt_code": "MSW-2026-2027"}, [])

    def test_an_unparseable_bracket_name_is_listed_as_such(self):
        """ROUTE.SRC.09 a finished FTL bracket whose name is not understood is
        kept in the schedule and marked, so the run records it as not read and
        the event stays IN_PROGRESS (ADR-108 §7)."""
        from python.pipeline import international_sources as src

        kept = [{"uuid": "Z1", "name": "Something odd", "finished": True, "day": None}]
        with patch("python.tools.scrape_ftl_event_urls.parse_tournament_name", return_value=None):
            (recs, kept_out, skipped), _ = _read_schedule(kept, [], {})
        assert recs == [] and [k["uuid"] for k in kept_out] == ["Z1"]
        assert skipped == [{"uuid": "Z1", "name": "Something odd", "reason": src.UNPARSEABLE}]

    def test_the_schedule_reread_hashes_as_the_run_recorded_it(self):
        """ROUTE.SRC.10 the daily close re-reads an international run's sources:
        FTL's schedule as listed, with its Finished flags, and every other
        source's brackets as final."""
        from python.pipeline import international_sources as src
        from python.pipeline.promotion import lifecycle
        from python.pipeline.promotion.run_record import schedule_sha256

        listed = TestFtlSchedule.KEPT
        fetcher = MagicMock()
        fetcher.fetch_event_url_with_skips.return_value = ([_parsed("V2", url="https://e/1")], [])
        with (
            patch("python.scrapers.ftl_auth.get_authed_ftl_client", return_value=_Client({})),
            patch("python.scrapers.ftl_auth.normalize_ftl_url", side_effect=lambda u: u),
            patch(
                "python.tools.scrape_ftl_event_urls.parse_event_schedule",
                return_value=(listed, TestFtlSchedule.SKIPPED),
            ),
        ):
            kept, skipped = src.read_schedule([SCHEDULE, ENGARDE], fetcher=fetcher)
        final, not_final = lifecycle.split_final(kept)
        assert [k["uuid"] for k in final] == ["A1", "A2", "https://e/1"]
        assert [k["uuid"] for k in not_final] == ["A3"]
        assert schedule_sha256(final, [*skipped, *not_final]) == schedule_sha256(
            [*listed[:2], {"uuid": "https://e/1", "name": "FOIL M V2"}],
            [*TestFtlSchedule.SKIPPED, {**listed[2], "reason": lifecycle.NOT_FINAL}],
        )


# --------------------------------------------------------------------------
# ROUTE.INTL — the driver ingest and promote's plan run
# --------------------------------------------------------------------------


def _intl_db(code="MSW-2026-2027"):
    db = MagicMock()
    db.find_event_by_code.return_value = {
        "id_event": 77,
        "txt_code": code,
        "url_event": SCHEDULE,
        "dt_start": "2026-10-09",
        "dt_end": "2026-10-17",
    }
    db.open_ingest_run.return_value = 5
    db.finish_ingest_run.return_value = {}
    return db


def _committed(*a, **k):
    ctx = MagicMock(faults=[], report=[])
    ctx.get = lambda key, default=None: (
        {"tournaments": [{"vcat": "V1", "id_tournament": 1, "n": 62}]}
        if key == "committed"
        else default
    )
    return ctx


def _recs():
    out = []
    for uuid, cat, n in (("A1", "V1", 62), ("A2", "V2", 45)):
        parsed = _parsed(
            cat,
            url=f"https://www.fencingtimelive.com/events/results/{uuid}",
            places=range(1, n + 1),
        )
        out.append(
            dict(
                name=parsed.tournament_name,
                uuid=uuid,
                url=parsed.source_url,
                weapon=parsed.weapon,
                gender=parsed.gender,
                cats=[cat],
                count=n,
                has_de=True,
                _base=parsed,
            )
        )
    return out


class TestDriver:
    def _ingest(self, db, flow, *, record_run="cert", code="MSW-2026-2027"):
        from python.pipeline import ingest_cli

        kept = [{"uuid": "A1", "name": "x"}, {"uuid": "A2", "name": "y"}]
        with (
            patch(
                "python.pipeline.international_sources.read_brackets",
                return_value=(_recs(), kept, []),
            ) as read,
            patch("python.pipeline.ingest_cli._run_parsed_through_flow", side_effect=flow),
            patch("python.pipeline.ingest_cli._fire_staging_report", return_value=None),
            patch("python.pipeline.ingest_cli._after_event_run"),
        ):
            ingest_cli.ingest_event_from_url(
                event_code=code, season_end_year=2027, db=db, replace=True, record_run=record_run
            )
        return read

    @pytest.mark.parametrize(
        "code", ["MSW-2026-2027", "IMSW-2026-2027", "PEW3-2026-2027", "IMEW-2026-2027"]
    )
    def test_an_international_event_is_ingested_not_refused(self, code):
        """ROUTE.INTL.01 (replaces INTL.URL.01's refusal) every bracket goes
        through INGEST_INTERNATIONAL, with the event's organizer."""
        from python.pipeline.engine.flows import Flow

        db = _intl_db(code)
        flow = MagicMock(side_effect=_committed)
        self._ingest(db, flow, code=code)
        assert flow.call_count == 2
        for call in flow.call_args_list:
            assert call.kwargs["flow"] == Flow.INGEST_INTERNATIONAL
            parsed = call.args[0]
            assert parsed.organizer_hint == ("FIE" if "MSW" in code else "EVF")
            assert parsed.season_end_year == 2027

    def test_the_run_records_the_brackets_for_promote(self):
        """ROUTE.INTL.02 the run record holds the brackets read and each
        listing's hash, which promote's source check compares."""
        db = _intl_db()
        self._ingest(db, MagicMock(side_effect=_committed))
        run_id, listings = db.finish_ingest_run.call_args.args
        assert run_id == 5
        assert [r["uuid"] for r in listings["rounds"]] == ["A1", "A2"]
        assert all(r["status"] == "committed" for r in listings["rounds"])
        assert listings["rounds"][0]["committed_categories"] == ["V1"]
        assert listings["schedule"]["kept"] == 2

    def test_a_refused_bracket_fails_the_run(self):
        """ROUTE.INTL.03 a PENDING row refuses its listing, and the run closes
        FAILED (ADR-106 §1: a PENDING row is a person's decision)."""
        db = _intl_db()

        def refuse(*a, **k):
            raise ValueError("international PENDING rows must be resolved before commit")

        with pytest.raises(ValueError, match="PENDING"):
            self._ingest(db, MagicMock(side_effect=refuse))
        db.fail_ingest_run.assert_called_once()
        db.finish_ingest_run.assert_not_called()

    def test_a_bracket_with_no_fencer_of_ours_is_dropped_not_failed(self):
        """ROUTE.INTL.04 (found by the LOCAL promote rehearsal, Tbilisi Vet-70
        Women's Saber) a bracket none of our fencers fenced stores nothing
        (ADR-105: only our fencers' rows). The run records it as dropped with
        the reason, so promote's gate does not read it as a failed commit."""
        from python.pipeline.core.contract import FaultKind
        from python.pipeline.promotion import gate

        def flow(parsed, *a, **k):
            if parsed.category_hint == "V1":
                return _committed()
            ctx = MagicMock(
                faults=[SimpleNamespace(kind=FaultKind.BELOW_MIN, detail="0<1 participants")],
                report=[],
            )
            ctx.get = lambda key, default=None: (
                {"skipped": True, "tournaments": []} if key == "committed" else default
            )
            return ctx

        db = _intl_db()
        self._ingest(db, MagicMock(side_effect=flow))
        _, listings = db.finish_ingest_run.call_args.args
        ours, none = listings["rounds"]
        assert ours["status"] == "committed"
        assert (none["status"], none["reason"], none["committed_categories"]) == (
            "dropped",
            "no fencer of ours",
            [],
        )
        out: list = []
        run = {"txt_status": "FINISHED", "jsonb_input_parts": {}, "txt_git_commit": "c"}
        prod = SimpleNamespace(parts={}, taken_ids=set())
        gate._preconditions(out, run, listings, listings["rounds"], {}, {}, prod, "c")
        assert not [f for f in out if f.check == "run.listing_not_committed"]


# --------------------------------------------------------------------------
# ROUTE.PLAN — promote replays an international CERT run on PROD
# --------------------------------------------------------------------------

SOURCES = [
    {"slot": "url_event", "url": SCHEDULE},
    {"slot": "url_event_2", "url": ENGARDE},
]


class _Prod:
    """PROD read through the recording connector (reads only)."""

    def __init__(self, **slots):
        self.event = {
            "id_event": 77,
            "txt_code": "MSW-2026-2027",
            "dt_start": "2026-10-09",
            "dt_end": "2026-10-17",
            "enum_status": "PLANNED",
            "url_event": None,
            "url_event_2": None,
            **slots,
        }

    def find_event_by_code(self, code):
        return dict(self.event) if code == self.event["txt_code"] else None


def _plan(prod, sources=SOURCES):
    from python.pipeline.promotion import plan as pl

    with patch("python.pipeline.ingest_cli._ingest_event_rounds", return_value=[]) as rounds:
        result = pl.plan_event(
            "MSW-2026-2027", 2027, prod, url_event=SCHEDULE, created=[], sources=sources
        )
    return result, rounds


class TestPromotePlan:
    def test_an_international_event_is_planned_from_the_cert_runs_sources(self):
        """ROUTE.PLAN.01 (replaces PROMO.PLAN.12's international refusal) the
        plan reads exactly the URLs the CERT run read."""
        _, rounds = _plan(_Prod())
        assert rounds.call_args.kwargs["sources"] == SOURCES

    def test_a_blank_prod_slot_takes_the_cert_runs_url(self):
        """ROUTE.PLAN.02 ADR-086's fill-blank tier, for every result slot."""
        result, _ = _plan(_Prod())
        assert {
            "op": "set_event_source_url",
            "id_event": 77,
            "slot": "url_event_2",
            "url_event": ENGARDE,
        } in result.ops
        same, _ = _plan(_Prod(url_event_2=ENGARDE))
        assert not [o for o in same.ops if o["op"] == "set_event_source_url"]

    def test_a_different_prod_slot_refuses(self):
        """ROUTE.PLAN.03"""
        from python.pipeline.promotion.plan import PlanRefused

        with pytest.raises(PlanRefused, match="url_event_2"):
            _plan(_Prod(url_event_2="https://other.example/x"))

    def test_the_reference_apply_writes_the_slot(self):
        """ROUTE.PLAN.04"""
        from python.pipeline.promotion.plan import apply_plan

        db = MagicMock()
        op = {"op": "set_event_source_url", "id_event": 77, "slot": "url_event_2"}
        apply_plan([{**op, "url_event": ENGARDE}], db)
        db.set_event_source_url.assert_called_once_with(77, "url_event_2", ENGARDE)

    def test_the_run_record_keeps_the_sources_it_read(self):
        """ROUTE.PLAN.05 the driver records the slots and URLs it read, which
        promote's replay hands to the plan."""
        from python.pipeline.promotion.run_record import ListingLog

        log = ListingLog()
        log.add_sources(SOURCES)
        assert log.listings()["sources"] == SOURCES
        db = _intl_db()
        db.find_event_by_code.return_value = {
            **db.find_event_by_code.return_value,
            "url_event_2": ENGARDE,
        }
        TestDriver()._ingest(db, MagicMock(side_effect=_committed))
        _, listings = db.finish_ingest_run.call_args.args
        assert listings["sources"] == SOURCES


# --------------------------------------------------------------------------
# ROUTE.LIFE / ROUTE.CLOSE — the event's status, for every organizer
# --------------------------------------------------------------------------


class TestLifecycle:
    def test_an_unparseable_bracket_keeps_the_event_in_progress(self):
        """ROUTE.LIFE.01 the driver records a bracket whose name is not
        understood as not read, so the lifecycle never completes the event."""
        from python.pipeline import ingest_cli
        from python.pipeline.international_sources import UNPARSEABLE
        from python.pipeline.promotion import lifecycle

        db = _intl_db()
        kept = [
            {"uuid": "A1", "name": "x"},
            {"uuid": "A2", "name": "y"},
            {"uuid": "Z1", "name": "odd"},
        ]
        skipped = [{"uuid": "Z1", "name": "odd", "reason": UNPARSEABLE}]
        with (
            patch(
                "python.pipeline.international_sources.read_brackets",
                return_value=(_recs(), kept, skipped),
            ),
            patch("python.pipeline.ingest_cli._run_parsed_through_flow", side_effect=_committed),
            patch("python.pipeline.ingest_cli._fire_staging_report", return_value=None),
            patch("python.pipeline.ingest_cli._after_event_run"),
        ):
            ingest_cli.ingest_event_from_url(
                event_code="MSW-2026-2027", season_end_year=2027, db=db, record_run="cert"
            )
        _, listings = db.finish_ingest_run.call_args.args
        assert sorted(r["status"] for r in listings["rounds"]) == [
            "committed",
            "committed",
            "unparseable",
        ]
        assert listings["schedule"]["kept"] == 3 and listings["schedule"]["skipped"] == []
        verdict = lifecycle.event_status(
            listings, dt_end=lifecycle.as_date("2026-10-17"), today=lifecycle.as_date("2026-10-20")
        )
        assert verdict.status == "IN_PROGRESS"
        assert "odd" in verdict.reasons[0]


class _Env:
    def __init__(self, name, run=None, fingerprint="f" * 64):
        self.name, self.run, self.fingerprint = name, run, fingerprint
        self.status = "IN_PROGRESS"
        self.writes: list[str] = []

    def events_to_close(self, today):
        return ["MSW-2026-2027"]

    def event(self, code):
        return {"code": code, "status": self.status, "dt_end": "2026-10-17", "url_event": SCHEDULE}

    def result_fingerprint(self, code):
        return self.fingerprint

    def latest_finished_run(self, code):
        return self.run

    def set_status(self, code, status):
        self.writes.append(status)
        self.status = status


class TestDailyClose:
    @pytest.mark.parametrize(
        "code",
        [
            "PPW1-2026-2027",
            "MPW-2026-2027",
            "PPS3s-2026-2027",
            "MPS-2026-2027",
            "PEW10efs-2026-2027",
            "MEW-2026-2027",
            "IMEW-2026-2027",
            "MSW-2026-2027",
            "IMSW-2026-2027",
            "PSW-2026-2027",
        ],
    )
    def test_every_organizers_event_is_a_candidate(self, code):
        """ROUTE.CLOSE.01 (ADR-113) the daily close takes the events of every
        organizer, not only PPW and MPW."""
        import re

        from python.pipeline.promotion import close

        assert re.match(close.ROUTE_CODES, code)

    def test_an_international_run_is_checked_against_its_own_sources(self):
        """ROUTE.CLOSE.02 the close re-reads the result slots the CERT run read
        and completes the event on CERT, then PROD."""
        from python.pipeline.promotion import close
        from python.pipeline.promotion.run_record import ListingLog

        kept = [{"uuid": "A1", "name": "x", "finished": True, "day": "2026-10-10"}]
        log = ListingLog()
        log.add_sources(SOURCES)
        log.add_schedule(kept, [])
        log.rounds.append({"name": "x", "uuid": "A1", "status": "committed"})
        run = {"url_event": SCHEDULE, "listings": log.listings(), "result_fingerprint": "f" * 64}
        cert, prod = _Env("cert", run=run), _Env("prod")
        read_sources = MagicMock(return_value=(kept, []))
        outcomes = close.close_events(
            cert,
            prod,
            read_schedule=MagicMock(side_effect=AssertionError("the FTL-only reader")),
            read_sources=read_sources,
            notifier=MagicMock(),
            today=lifecycle_date("2026-10-20"),
        )
        read_sources.assert_called_once_with([SCHEDULE, ENGARDE])
        assert [o.closed for o in outcomes] == [True]
        assert (cert.status, prod.status) == ("COMPLETED", "COMPLETED")


def lifecycle_date(text):
    from python.pipeline.promotion import lifecycle

    return lifecycle.as_date(text)


# --------------------------------------------------------------------------
# ROUTE.REPORT — the staging report `ingest` sends shows each bracket
# --------------------------------------------------------------------------


def _bracket_ctx():
    """One FIE bracket: 6 rows, 5 printed ITA, one Pole stored, one rejected."""
    rows = _rows(1, 2, 3, 4, 5)
    rows.append(
        ParsedResult(source_row_id="r6", fencer_name="NOWAK Jan", place=6, fencer_country="POL")
    )
    parsed = _parsed("V1", "FOIL", "M", "https://ftl/A1")
    parsed = ParsedTournament(**{**parsed.__dict__, "results": rows, "raw_pool_size": 6})
    stored = SimpleNamespace(
        method="AUTO_MATCHED", entered_for="POL", id_fencer=30, place=6, scraped_name="NOWAK Jan"
    )
    pctx = SimpleNamespace(parsed=parsed, matches=[stored], rejected=[object()] * 5)
    return parsed, pctx


class TestStagingReport:
    def test_the_international_table_flags_more_than_four_of_one_federation(self):
        """ROUTE.REPORT.01 the table Phase 5 showed (INTL.INV.02, ADM.FIE.10),
        from one shared function."""
        from python.pipeline.international_report import section_lines

        lines = section_lines("MSW-2026-2027", [_bracket_ctx()])
        assert lines[0].startswith("## International brackets")
        row = next(line for line in lines if "FOIL" in line)
        assert (
            "| V1 | FOIL | M | 6 | 6 | 1 | 0 | 0 | 5 | ⚠ more than 4 fencers of one federation (ITA 5)"
            in row
        )
        assert section_lines("PPW1-2026-2027", [_bracket_ctx()]) == []

    def test_ingest_seeds_the_section_into_the_report(self):
        """ROUTE.REPORT.02 the CERT ingest's report carries the section."""
        from python.pipeline import ingest_cli

        parsed, pctx = _bracket_ctx()
        bracket = MagicMock(report=[])
        seen = {}

        def fake_run_flow(params, *, ctx, svc, react):
            seen.update(ctx.data)

        with (
            patch("python.pipeline.plugins.bridge.get_pctx", return_value=pctx),
            patch("python.pipeline.run.run_flow", side_effect=fake_run_flow),
        ):
            ingest_cli._fire_staging_report(
                {"txt_code": "MSW-2026-2027", "id_event": 77}, [bracket], None
            )
        assert any("FOIL" in line for line in seen["_international_section"])

    def test_the_formatter_renders_the_section(self):
        """ROUTE.REPORT.03"""
        from python.pipeline.plugins.staging_formatter import render_staging_md

        md = render_staging_md(
            "MSW-2026-2027",
            None,
            [],
            [],
            "stamp",
            extra_sections=["## International brackets", "| x |"],
        )
        assert "## International brackets\n| x |" in md


# --------------------------------------------------------------------------
# ROUTE.WRITERS — results reach CERT through ingest and PROD through promote
# --------------------------------------------------------------------------

_EVF_EVENT = {"name": "EVF Circuit Budapest", "date": "2026-11-07", "evf_id": 91}
_SPWS_ROW = {
    "spws_id": 30,
    "place": 2,
    "category": "V2",
    "gender": "M",
    "weapon": "FOIL",
    "spws_surname": "NOWAK",
    "country": "POL",
    "match_confidence": 100.0,
}


class TestEvfSyncWritesNoResult:
    def _compare(self, monkeypatch, *, match):
        from python.scrapers import evf_sync

        sent: list[str] = []
        sql_run: list[str] = []

        def query(_r, _t, sql):
            sql_run.append(sql)
            return [{"txt_code": "PEW5-2026-2027"}] if "id_event = 501" in sql else []

        monkeypatch.setattr(evf_sync, "_telegram", lambda _b, _c, text: sent.append(text))
        monkeypatch.setattr(evf_sync, "is_in_scope", lambda _e: True)
        monkeypatch.setattr(
            "python.scrapers.evf_calendar._find_existing_match", lambda _s, _p: match
        )
        monkeypatch.setattr(evf_sync, "_create_cert_event", lambda *_a: 501)
        monkeypatch.setattr(evf_sync, "_management_query", query)
        evf_sync._compare_and_ingest(
            "ref", "token", _EVF_EVENT, [_SPWS_ROW], False, "bot", "chat", cert_events_pool=[]
        )
        return sql_run, sent

    @staticmethod
    def _writes_no_result(sql_run):
        from python.scrapers import evf_sync

        assert not hasattr(evf_sync, "_ingest_evf_results")
        assert not any(
            "fn_ingest_tournament_results" in s or "fn_find_or_create_tournament" in s
            for s in sql_run
        )

    def test_results_missing_on_cert_are_reported_not_written(self, monkeypatch):
        """ROUTE.WRITERS.01 (Q1 A) the daily sync compares and tells the
        operator to ingest; it writes no result."""
        match = {"id_event": 7, "txt_code": "PEW4-2026-2027", "txt_name": "Budapest"}
        sql_run, sent = self._compare(monkeypatch, match=match)
        self._writes_no_result(sql_run)
        assert "ingest PEW4-2026-2027" in sent[-1]

    def test_a_new_event_is_created_without_results(self, monkeypatch):
        """ROUTE.WRITERS.02 (Q1 A) the calendar side still creates the event;
        its results wait for `ingest`."""
        sql_run, sent = self._compare(monkeypatch, match=None)
        self._writes_no_result(sql_run)
        assert "ingest PEW5-2026-2027" in sent[-1]


def test_the_evf_sync_sends_pending_rows_to_ingest_not_phase5():
    """ROUTE.WRITERS.04 (Q5 A) a new event's PENDING rows are decided in its
    override file and loaded by `ingest`, not by the Phase 5 runner."""
    from pathlib import Path

    src = (Path(__file__).resolve().parents[2] / "python/scrapers/evf_sync.py").read_text()
    assert "Resolve through the Phase 5 runner" not in src
    assert "then send <code>ingest</code>" in src
    assert "optionally ingest" not in src


class TestScrapeTournamentNeverWritesProd:
    def test_the_workflow_holds_no_prod_secret_and_refuses_prod(self):
        """ROUTE.WRITERS.03 (Q2 A) PROD gets results only through promote: the
        per-tournament scrape cannot reach PROD, and asking for it is refused
        with the way to get there."""
        from pathlib import Path

        import yaml

        path = Path(__file__).resolve().parents[2] / ".github/workflows/scrape-tournament.yml"
        text = path.read_text()
        assert "SUPABASE_PROD" not in text
        wf = yaml.safe_load(text)
        (job,) = wf["jobs"].values()
        guard = next(s for s in job["steps"] if s.get("name") == "Validate inputs")
        assert "promote" in guard["run"] and '"cert"' in guard["run"]


class TestIngestRefreshesFirst:
    def test_the_ingest_workflow_refreshes_cert_from_prod_first(self):
        """ROUTE.REFRESH.04 (Q4 A) `ingest` runs the PROD→CERT master-data
        refresh before the ingestion, in the automatic mode that stops on any
        renumbering, so CERT ingests against PROD's fencers."""
        from pathlib import Path

        import yaml

        path = Path(__file__).resolve().parents[2] / ".github/workflows/ingest-event.yml"
        wf = yaml.safe_load(path.read_text())
        (job,) = wf["jobs"].values()
        runs = [s.get("run", "") for s in job["steps"]]
        refresh = next(i for i, r in enumerate(runs) if "python.pipeline.promotion.refresh" in r)
        ingest = next(i for i, r in enumerate(runs) if "python.pipeline.ingest_cli" in r)
        assert refresh < ingest
        cmd = runs[refresh]
        for part in ("--target cert", "--mode apply", '--event "$EVENT_CODE"', "--auto"):
            assert part in cmd
        env = job["steps"][refresh]["env"]
        assert env["SUPABASE_URL"] == "${{ secrets.SUPABASE_CERT_URL }}"
        assert "SUPABASE_ACCESS_TOKEN" in env
