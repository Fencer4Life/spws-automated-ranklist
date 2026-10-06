"""PZSz events on ingest for CERT and promote for PROD (ADR-111 §6, ADR-112).

RTM PZSZ.ROUTE.01–07. `ingest <code>` and `promote <code>` run the same
ingestion: both reach `ingest_cli._ingest_event_rounds`, which sends a PZSz
event (PPS, MPS) to the PZSz flow. The bracket name gives weapon and gender
only, never an age category. The birth years come from the PZSz start lists.
The CERT ingest captures them when pzszerm.pl serves them, then reads the
newest stored version, so a gated day does not stop it once a list is stored.
Promote is given the stored lists the CERT run used and never fetches.

The harness is the plan tests' (in-memory database, fake FTL); the PZSz pages
are the saved fixtures, with synthetic people.
"""

from __future__ import annotations

import copy
import json
from pathlib import Path
from unittest.mock import patch

import pytest

from python.pipeline import ingest_cli
from python.pipeline.promotion import plan as pl
from python.pipeline.promotion.replay import source_differences
from python.pipeline.promotion.run_record import start_list_sha256
from python.scrapers.pzsz_start_list import PZSZ_EVENT_PAGE, PzszPageError, parse_start_list
from python.scrapers.pzsz_start_list_store import capture_event_start_lists, newest_by_series
from python.tests.test_promotion_plan import (
    SCHEDULE,
    MemoryDb,
    _classic_db,
    _drive,
    _event,
    _fencer,
    _Ftl,
    _ReadOnly,
)
from python.tests.test_pzsz_start_list_store import MemoryStore

FIXTURES = Path(__file__).parent / "fixtures"
PAGES = {
    ("event", 4588): "pzsz_event_poznan_tournaments.html",
    ("tournament", 10628): "pzsz_start_list_sabre_men.html",
    ("tournament", 10629): "pzsz_start_list_sabre_women.html",
}
CODE = "PPS1s-2026-2027"

# FTL's listings for the event. The fixture start lists hold "Przykładowy Jan"
# (1971) and "Wzorcowy Jakub" (2008) among the men, "Testowska Marta" (2007)
# and "Przykładowa Anna" (1968) among the women.
FTL = _Ftl(
    {
        "UM": (
            "Szabla Mężczyzn Seniorzy",
            [
                ("FIKCYJNY Antoni", 1),
                ("PRZYKŁADOWY Jan", 2),
                ("WZORCOWY Jakub", 3),
                ("OBCY Ktoś", 4),
            ],
        ),
        "UF": ("Szabla Kobiet Seniorki", [("TESTOWSKA Marta", 1), ("PRZYKŁADOWA Anna", 2)]),
    }
)


def _pages(js_check_for: int | None = None):
    def fetch(url: str, params: dict) -> str:
        kind = "event" if url == PZSZ_EVENT_PAGE else "tournament"
        if params["id"] == js_check_for:
            return (FIXTURES / "pzsz_js_check.html").read_text(encoding="utf-8")
        return (FIXTURES / PAGES[(kind, params["id"])]).read_text(encoding="utf-8")

    return fetch


class PzszMemoryDb(MemoryDb):
    """CERT's database with tbl_pzsz_start_list. The stored lists are inputs,
    not results, so `state()` leaves them out."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.start_lists = MemoryStore()

    def store_pzsz_start_list(self, payload):
        return self.start_lists.store(payload)

    def fetch_pzsz_start_lists(self, id_pzsz_event):
        return [r for r in self.start_lists.rows if r["id_pzsz_event"] == int(id_pzsz_event)]


def _pzsz_db(roster=None) -> PzszMemoryDb:
    event = _event(9, CODE, "2026-10-04", 2)
    event["dt_end"] = "2026-10-05"
    event["id_pzsz_event"] = 4588
    return PzszMemoryDb(
        roster
        if roster is not None
        else [
            _fencer(301, "PRZYKŁADOWY", "Jan", 1971),
            _fencer(302, "WZORCOWY", "Jakub", 1976),
            _fencer(303, "PRZYKŁADOWA", "Anna", 1969, gender="F"),
        ],
        [event],
    )


def _gated(url: str, params: dict) -> str:
    """pzszerm.pl with its JavaScript gate on, for every page."""
    return (FIXTURES / "pzsz_js_check.html").read_text(encoding="utf-8")


def _refuse_fetch(url: str, params: dict) -> str:
    raise AssertionError(f"promote fetched {url}")


def _stored_lists():
    """The start lists a CERT run used, as promote reads them back from CERT."""
    store = MemoryStore()
    capture_event_start_lists(4588, _pages(), store.store)
    return newest_by_series(store.rows)


def _with_pages(fetch, fn, *args, **kwargs):
    with patch.object(ingest_cli, "_pzsz_fetch", fetch):
        return _drive(FTL, fn, *args, **kwargs)


def _live(db: MemoryDb, fetch=None):
    return _with_pages(
        fetch or _pages(),
        ingest_cli.ingest_event_from_url,
        event_code=CODE,
        season_end_year=2027,
        db=db,
    )


_GIVEN = object()


def _plan(db: MemoryDb, pzsz_event=None, lists=_GIVEN) -> pl.Plan:
    """Promote's plan, given the CERT run's stored lists. Any fetch fails the
    test: promote never contacts pzszerm.pl (ADR-112 §4)."""
    plan, _, _ = _with_pages(
        _refuse_fetch,
        pl.plan_event,
        CODE,
        2027,
        _ReadOnly(db),
        url_event=SCHEDULE,
        created=[],
        pzsz_event=pzsz_event,
        pzsz_start_lists=_stored_lists() if lists is _GIVEN else lists,
    )
    return plan


class TestIngestRoutesPzsz:
    def test_a_pzsz_event_runs_the_pzsz_flow(self):
        """PZSZ.ROUTE.01: one SENIOR tournament for the men's sabre, the whole
        FTL field as N, the one admitted veteran at his own place; nothing
        created and no birth year moved. The women's field matched nobody, so
        it has no tournament."""
        db = _pzsz_db()
        _live(db)
        (t,) = db.tournaments.values()
        assert (t["enum_weapon"], t["enum_gender"], t["enum_age_category"]) == (
            "SABRE",
            "M",
            "SENIOR",
        )
        assert t["int_participant_count"] == 4
        assert [(r["id_fencer"], r["int_place"]) for r in db.results[t["id_tournament"]]] == [
            (301, 2)
        ]
        assert db.inserted == []
        assert db.fencers[302]["int_birth_year"] == 1976
        assert db.fencers[303]["int_birth_year"] == 1969

    def test_the_bracket_name_never_becomes_an_age_category(self):
        """PZSZ.ROUTE.01: "Seniorzy" is not read as V0 — no V-category
        tournament is created for a PZSz event."""
        db = _pzsz_db()
        _live(db)
        assert {t["enum_age_category"] for t in db.tournaments.values()} == {"SENIOR"}

    def test_the_event_is_closed_when_its_listings_are_read(self):
        """PZSZ.ROUTE.01: every listing final and read, the end date passed:
        COMPLETED, through IN_PROGRESS."""
        db = _pzsz_db()
        _live(db)
        assert db.status_writes == ["IN_PROGRESS", "COMPLETED"]

    def test_nobody_matched_closes_the_event_with_nothing_written(self):
        """PZSZ.ROUTE.01 (Q2 A): no tournament, no result, the event closed."""
        db = _pzsz_db(roster=[_fencer(302, "WZORCOWY", "Jakub", 1976)])
        _live(db)
        assert db.tournaments == {}
        assert db.results == {}
        assert db.events[9]["enum_status"] == "COMPLETED"

    def test_an_unreadable_start_list_writes_nothing(self):
        """PZSZ.ROUTE.01: the JavaScript check on one PZSz page, with nothing
        stored, fails the run before any write."""
        db = _pzsz_db()
        before = db.state()
        with pytest.raises(PzszPageError):
            _live(db, _pages(js_check_for=10629))
        assert db.state() == before

    def test_the_ingest_stores_the_version_it_uses(self):
        """PZSZ.ROUTE.04: on a day pzszerm.pl serves its pages, the ingest
        stores both start lists and admits from them."""
        db = _pzsz_db()
        _live(db)
        assert {(r["enum_weapon"], r["enum_gender"]) for r in db.start_lists.rows} == {
            ("SABRE", "M"),
            ("SABRE", "F"),
        }

    def test_a_gated_day_runs_from_the_stored_list(self):
        """PZSZ.ROUTE.04: the gate on for every page, the lists stored
        earlier: the ingest runs and admits exactly as on an open day."""
        open_day = _pzsz_db()
        _live(open_day)
        db = _pzsz_db()
        capture_event_start_lists(4588, _pages(), db.store_pzsz_start_list)
        _live(db, _gated)
        assert db.state() == open_day.state()

    def test_a_gated_day_with_nothing_stored_stops_and_says_why(self):
        """PZSZ.ROUTE.05: nothing stored and the gate on: the run stops with
        nothing written and says the list is stored on the next open day."""
        db = _pzsz_db()
        before = db.state()
        with pytest.raises(PzszPageError, match="No PZSz start list is stored"):
            _live(db, _gated)
        assert db.state() == before
        assert db.start_lists.rows == []

    def test_the_event_lookup_returns_the_pzsz_event_id(self):
        """PZSZ.ROUTE.01: the database connector's event row carries
        id_pzsz_event, which leads to the start lists. The first LOCAL run
        (6 Oct 2026) stopped on a row without it, though the column was set."""
        from unittest.mock import MagicMock

        from python.pipeline.db_connector import DbConnector

        sb = MagicMock()
        sb.table.return_value.select.return_value.eq.return_value.execute.return_value.data = []
        DbConnector(sb).find_event_by_code(CODE)
        (columns,), _ = sb.table.return_value.select.call_args
        assert "id_pzsz_event" in [c.strip() for c in columns.split(",")]

    def test_the_connector_stores_and_reads_start_lists(self):
        """PZSZ.ROUTE.04: the CERT ingest stores through fn_pzsz_start_list_store
        (the append-if-changed rule lives in the database) and reads every
        stored version of the event, which the ingest narrows to the newest."""
        from unittest.mock import MagicMock

        from python.pipeline.db_connector import DbConnector

        sb = MagicMock()
        sb.rpc.return_value.execute.return_value.data = {"stored": True}
        db = DbConnector(sb)
        assert db.store_pzsz_start_list({"id_pzsz_event": 4588}) is True
        sb.rpc.assert_called_with("fn_pzsz_start_list_store", {"p_list": {"id_pzsz_event": 4588}})

        query = sb.table.return_value.select.return_value.eq.return_value
        query.execute.return_value.data = [{"id_pzsz_start_list": 1}]
        assert db.fetch_pzsz_start_lists(4588) == [{"id_pzsz_start_list": 1}]
        sb.table.assert_called_with("tbl_pzsz_start_list")
        sb.table.return_value.select.return_value.eq.assert_called_with("id_pzsz_event", 4588)

    def test_a_ppw_event_never_reads_pzsz_pages(self):
        """PZSZ.ROUTE.01: the PPW flow is unchanged and reads no start list."""

        def refuse(url, params):
            raise AssertionError(f"a PPW ingest read {url}")

        db = _classic_db()
        ftl = _Ftl({"U1": ("Szpada Mężczyzn kat. 2", [("KOWALSKI Jan", 1)])})
        with patch.object(ingest_cli, "_pzsz_fetch", refuse):
            _drive(
                ftl,
                ingest_cli.ingest_event_from_url,
                event_code="PPW3-2025-2026",
                season_end_year=2026,
                db=db,
            )
        assert {t["enum_age_category"] for t in db.tournaments.values()} == {"V2"}


class TestPromoteRoutesPzsz:
    def test_the_plan_never_fetches_pzszerm(self):
        """PZSZ.ROUTE.06: given the CERT run's stored lists, promote's plan
        admits from them; `_plan` fails the test on any fetch."""
        plan = _plan(_pzsz_db())
        assert [o["op"] for o in plan.ops if o["op"] == "ingest_results"] == ["ingest_results"]

    def test_a_pzsz_plan_without_start_lists_is_refused(self):
        """PZSZ.ROUTE.07: promote reads the lists from CERT; a PZSz plan given
        none is refused rather than fetching."""
        with pytest.raises(pl.PlanRefused, match="start lists"):
            _plan(_pzsz_db(), lists=None)

    def test_the_plan_records_each_start_lists_hash(self):
        """PZSZ.ROUTE.02: promote's plan takes the PZSz flow and keeps the
        start list's hash beside the listing's."""
        plan = _plan(_pzsz_db())
        rounds = {r["weapon"] + r["gender"]: r for r in plan.listings["rounds"]}
        men = parse_start_list((FIXTURES / PAGES[("tournament", 10628)]).read_text("utf-8"))
        assert rounds["SABREM"]["start_list_sha256"] == start_list_sha256(men)
        assert rounds["SABREF"]["start_list_sha256"] != rounds["SABREM"]["start_list_sha256"]
        assert [o["op"] for o in plan.ops if o["op"] == "ingest_results"] == ["ingest_results"]

    def test_the_run_records_the_pzsz_event_it_read(self):
        """PZSZ.ROUTE.02: the listings carry the PZSz event id, so the CERT
        run tells promote which start lists it read."""
        assert _plan(_pzsz_db()).listings["pzsz_event"] == 4588

    def test_a_prod_event_without_the_pzsz_id_takes_the_cert_runs(self):
        """PZSZ.ROUTE.02: PROD's calendar row may lack id_pzsz_event (the
        calendar promotion does not carry it); the plan reads the start lists
        of the PZSz event the CERT run read, and writes nothing for it."""
        db = _pzsz_db()
        db.events[9]["id_pzsz_event"] = None
        plan = _plan(db, pzsz_event=4588)
        assert plan.listings["pzsz_event"] == 4588
        assert [o["op"] for o in plan.ops if o["op"] == "ingest_results"] == ["ingest_results"]

    def test_a_prod_event_with_another_pzsz_id_refuses(self):
        """PZSZ.ROUTE.02: CERT read event 4588, PROD names 9999 — refused."""
        db = _pzsz_db()
        db.events[9]["id_pzsz_event"] = 9999
        with pytest.raises(pl.PlanRefused, match="id_pzsz_event"):
            _plan(db, pzsz_event=4588)

    def test_no_pzsz_id_on_either_side_refuses(self):
        """PZSZ.ROUTE.02: without a PZSz event id there is no start list."""
        db = _pzsz_db()
        db.events[9]["id_pzsz_event"] = None
        with pytest.raises(pl.PlanRefused, match="id_pzsz_event"):
            _plan(db)

    def test_a_start_list_changed_since_the_cert_run_is_refused(self):
        """PZSZ.ROUTE.02: the CERT run read another start list; promote names it."""
        plan = _plan(_pzsz_db())
        run = copy.deepcopy(plan.listings)
        run["rounds"][0]["start_list_sha256"] = "0" * 64
        (difference,) = source_differences(run, plan.listings)
        assert "start list" in difference

    def test_plan_then_apply_equals_the_live_run(self):
        """PZSZ.ROUTE.03: a promote replay of a PZSz run, with an in-memory
        database standing in for PROD, leaves it as the CERT run left CERT."""
        live = _pzsz_db()
        _live(live)
        planned = _pzsz_db()
        before = planned.state()
        plan = _plan(planned)
        assert planned.state() == before, "planning wrote to the database"
        payload = json.loads(json.dumps(plan.to_json()))
        pl.apply_plan(payload["ops"], planned, status=payload["status"], event_code=CODE)
        assert planned.state() == live.state()
        assert plan.status == "COMPLETED"

    def test_nobody_matched_promotes_only_the_closing(self):
        """PZSZ.ROUTE.03 (Q2 A): nothing to write on PROD; the plan closes
        the event."""
        roster = [_fencer(302, "WZORCOWY", "Jakub", 1976)]
        plan = _plan(_pzsz_db(roster))
        assert not [
            o for o in plan.ops if o["op"] in ("find_or_create_tournament", "ingest_results")
        ]
        assert plan.status == "COMPLETED"
