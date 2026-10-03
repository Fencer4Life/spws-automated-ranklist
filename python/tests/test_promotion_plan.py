"""PROMO.PLAN.01–12 — plan mode: the recording connector (ADR-108 §6, build step 8).

Promote runs the CERT run's ingestion again, against PROD, with a recording
connector in place of the database connector. It reads PROD and records every
write; a read of something the run itself wrote is answered from the record,
so the flow decides exactly what a live run would. A new fencer takes the id
the CERT run gave it (ADR-108 §2). The plan is the ordered list of writes, and
`apply_plan` is the reference apply that fn_promote_event_apply (build step 9)
reproduces in one transaction.

The acceptance test is "plan, then apply, equals a live run". Here it runs the
real INGEST_DOMESTIC flow on an in-memory database with the connector's
semantics (PROMO.PLAN.10–11); on LOCAL against FTL it is
`python -m python.pipeline.promotion.plan_check`.
"""

from __future__ import annotations

import copy
import json
from unittest.mock import patch

import pytest

from python.pipeline.promotion import plan as pl
from python.pipeline.stages import vcat_for_age

SCHEDULE = "https://www.fencingtimelive.com/tournaments/eventSchedule/ABC"

SEASONS = [
    {
        "id_season": 1,
        "txt_code": "SPWS-2025-2026",
        "dt_start": "2025-09-01",
        "dt_end": "2026-08-31",
        "engine": "EVF_CLASSIC_V1_2025_2026",
    },
    {
        "id_season": 2,
        "txt_code": "SPWS-2026-2027",
        "dt_start": "2026-09-01",
        "dt_end": "2027-08-31",
        "engine": "SPWS_EVF_JOINED_V1_2026_2027",
    },
]


def _fencer(id_, surname, first, by, *, estimated=False, gender="M") -> dict:
    return {
        "id_fencer": id_,
        "txt_surname": surname,
        "txt_first_name": first,
        "int_birth_year": by,
        "bool_birth_year_estimated": estimated,
        "txt_nationality": "PL",
        "enum_gender": gender,
        "json_name_aliases": [],
    }


def _event(id_, code, start, season, url=SCHEDULE) -> dict:
    return {
        "id_event": id_,
        "txt_code": code,
        "dt_start": start,
        "dt_end": start,
        "id_season": season,
        "url_event": url,
        "json_source_overrides": None,
        "json_ingest_sources": None,
        "enum_status": "PLANNED",
    }


class MemoryDb:
    """The connector's surface over in-memory tables, with the database's
    semantics: SERIAL ids that explicit inserts do not advance, find-or-create
    on (event, weapon, gender, category), and a results write that replaces
    the tournament's rows."""

    WRITES = (
        "insert_fencer",
        "update_fencer_birth_year",
        "find_or_create_tournament",
        "ingest_results",
        "set_event_url_event",
        "set_event_ingest_sources",
    )

    def __init__(self, fencers, events, registrations=(), tournaments=()):
        self.fencers = {f["id_fencer"]: dict(f) for f in fencers}
        self.events = {e["id_event"]: dict(e) for e in events}
        self.registrations = [dict(r) for r in registrations]
        self.tournaments = {t["id_tournament"]: dict(t) for t in tournaments}
        self.results: dict[int, list[dict]] = {}
        self.inserted: list[int] = []
        self._seq = 1000
        self._tseq = 500

    # reads
    def fetch_spws_starter_ids(self):
        return set()

    def fetch_fencer_db(self):
        return [copy.deepcopy(f) for f in self.fencers.values()]

    def fetch_registration_birth_years(self, event_code):
        return [
            {k: r[k] for k in ("txt_surname", "txt_first_name", "int_birth_year")}
            for r in self.registrations
            if r["event"] == event_code
        ]

    def find_event_by_code(self, event_code):
        for e in self.events.values():
            if e["txt_code"] == event_code:
                return copy.deepcopy(e)
        return None

    def find_event_by_date(self, _date):
        return None

    def find_seasons_containing_dates(self, start, end):
        return [
            {k: s[k] for k in ("id_season", "txt_code", "dt_start", "dt_end")}
            for s in SEASONS
            if s["dt_start"] <= start and end <= s["dt_end"]
        ]

    def fetch_event_tournaments(self, id_event):
        return [
            {
                k: t[k]
                for k in (
                    "id_tournament",
                    "enum_weapon",
                    "enum_gender",
                    "enum_age_category",
                    "enum_type",
                )
            }
            for t in self.tournaments.values()
            if t["id_event"] == id_event
        ]

    def fetch_genders_batch(self, ids):
        return {i: self.fencers[i]["enum_gender"] for i in ids if i in self.fencers}

    def fetch_birth_years_batch(self, ids):
        return {i: self.fencers[i]["int_birth_year"] for i in ids if i in self.fencers}

    def fetch_fencer_basics_batch(self, ids):
        return {i: copy.deepcopy(self.fencers[i]) for i in ids if i in self.fencers}

    def call_age_categories_batch(self, birth_years, season_end_year):
        return {by: vcat_for_age(season_end_year - by) for by in birth_years}

    def get_type_engine(self, id_season, _ttype):
        return next(s["engine"] for s in SEASONS if s["id_season"] == id_season)

    # writes
    def insert_fencer(self, payload):
        id_ = payload.get("id_fencer")
        if id_ is None:
            id_ = self._seq
            self._seq += 1
        if id_ in self.fencers:
            raise ValueError(f"duplicate key id_fencer={id_}")
        row = {
            "json_name_aliases": [],
            "enum_gender": None,
            "txt_nationality": "PL",
            "bool_birth_year_estimated": False,
        }
        row.update(payload)
        row["id_fencer"] = id_
        self.fencers[id_] = row
        self.inserted.append(id_)
        return id_

    def update_fencer_birth_year(self, fencer_id, birth_year, estimated=False):
        self.fencers[fencer_id]["int_birth_year"] = birth_year
        self.fencers[fencer_id]["bool_birth_year_estimated"] = estimated

    def find_or_create_tournament(
        self, event_id, weapon, gender, category, date, tournament_type, url_results=None
    ):
        for t in self.tournaments.values():
            if (t["id_event"], t["enum_weapon"], t["enum_gender"], t["enum_age_category"]) == (
                event_id,
                weapon,
                gender,
                category,
            ):
                if url_results is not None:
                    t["url_results"] = url_results
                return t["id_tournament"]
        tid = self._tseq
        self._tseq += 1
        self.tournaments[tid] = {
            "id_tournament": tid,
            "id_event": event_id,
            "enum_weapon": weapon,
            "enum_gender": gender,
            "enum_age_category": category,
            "enum_type": tournament_type,
            "dt_tournament": date,
            "url_results": url_results,
            "int_participant_count": 0,
            "txt_joined_order": None,
        }
        return tid

    def ingest_results(
        self, tournament_id, results_json, participant_count=None, joined_order=None
    ):
        if not results_json:
            raise ValueError("empty results")
        t = self.tournaments[tournament_id]
        self.results[tournament_id] = copy.deepcopy(results_json)
        t["int_participant_count"] = participant_count or len(results_json)
        t["txt_joined_order"] = joined_order
        return {"inserted": len(results_json)}

    def set_event_url_event(self, id_event, url_event):
        self.events[id_event]["url_event"] = url_event

    def set_event_ingest_sources(self, id_event, sources):
        self.events[id_event]["json_ingest_sources"] = copy.deepcopy(sources)

    def state(self) -> dict:
        """Everything a run can change, keyed by what does not depend on
        generated tournament ids."""
        tournaments = {}
        for tid, t in self.tournaments.items():
            key = f"{t['id_event']}/{t['enum_weapon']}/{t['enum_gender']}/{t['enum_age_category']}"
            body = {k: v for k, v in t.items() if k != "id_tournament"}
            body["results"] = sorted(
                self.results.get(tid, []), key=lambda r: (r["int_place"], r["id_fencer"])
            )
            tournaments[key] = body
        return {
            "fencers": copy.deepcopy(self.fencers),
            "events": copy.deepcopy(self.events),
            "tournaments": tournaments,
        }


class _ReadOnly:
    """PROD as plan mode sees it: a write is a test failure."""

    def __init__(self, db: MemoryDb):
        self._db = db

    def __getattr__(self, name):
        if name in MemoryDb.WRITES:
            raise AssertionError(f"plan mode wrote to PROD: {name}")
        return getattr(self._db, name)


def _created(*pairs) -> list[dict]:
    return [{"id_fencer": i, "surname": s, "first_name": f} for i, s, f in pairs]


def _classic_db() -> MemoryDb:
    return MemoryDb(
        [
            _fencer(101, "KOWALSKI", "Jan", 1972),
            _fencer(102, "NOWAK", "Adam", 1970, estimated=True),
            _fencer(103, "WIŚNIEWSKI", "Piotr", 1968),
        ],
        [_event(7, "PPW3-2025-2026", "2026-03-14", 1)],
        registrations=[
            {
                "event": "PPW3-2025-2026",
                "txt_surname": "NOWAK",
                "txt_first_name": "Adam",
                "int_birth_year": 1971,
            }
        ],
    )


# ---------------------------------------------------------------------------
# The recording connector
# ---------------------------------------------------------------------------


class TestRecordingConnector:
    def test_reads_pass_through_and_a_write_is_only_recorded(self):
        """PROMO.PLAN.01"""
        db = _classic_db()
        rec = pl.RecordingConnector(_ReadOnly(db), created=[])
        assert rec.fetch_fencer_db() == db.fetch_fencer_db()
        assert rec.find_event_by_code("PPW3-2025-2026") == db.find_event_by_code("PPW3-2025-2026")
        rec.update_fencer_birth_year(102, 1971, estimated=False)
        assert rec.ops == [
            {
                "op": "update_fencer_birth_year",
                "id_fencer": 102,
                "birth_year": 1971,
                "estimated": False,
            }
        ]
        assert db.fencers[102]["int_birth_year"] == 1970

    def test_a_new_fencer_takes_the_cert_runs_id_and_later_reads_see_it(self):
        """PROMO.PLAN.02 — ids stay identical; a second listing finds the fencer."""
        db = _classic_db()
        rec = pl.RecordingConnector(_ReadOnly(db), created=_created((368, "ZIELIŃSKI", "Marek")))
        new = rec.insert_fencer(
            {
                "txt_surname": "ZIELIŃSKI",
                "txt_first_name": "Marek",
                "int_birth_year": 1971,
                "bool_birth_year_estimated": True,
                "txt_nationality": "PL",
                "enum_gender": "M",
            }
        )
        assert new == 368
        assert [f["id_fencer"] for f in rec.fetch_fencer_db()][-1] == 368
        assert rec.fetch_birth_years_batch([101, 368]) == {101: 1972, 368: 1971}
        assert rec.fetch_genders_batch([368]) == {368: "M"}
        assert rec.fetch_fencer_basics_batch([368])[368]["txt_surname"] == "ZIELIŃSKI"
        assert rec.ops[0]["op"] == "insert_fencer" and rec.ops[0]["id_fencer"] == 368
        assert rec.created == [{"id_fencer": 368, "surname": "ZIELIŃSKI", "first_name": "Marek"}]

    def test_a_fencer_the_cert_run_did_not_create_refuses(self):
        """PROMO.PLAN.03 — PROD diverged from CERT; nothing has been written."""
        rec = pl.RecordingConnector(_ReadOnly(_classic_db()), created=[])
        with pytest.raises(pl.PlanRefused, match="ZIELIŃSKI Marek") as e:
            rec.insert_fencer(
                {"txt_surname": "ZIELIŃSKI", "txt_first_name": "Marek", "int_birth_year": 1971}
            )
        assert e.value.kind == "identity"

    def test_a_cert_id_taken_on_prod_refuses(self):
        """PROMO.PLAN.04"""
        rec = pl.RecordingConnector(
            _ReadOnly(_classic_db()), created=_created((103, "ZIELIŃSKI", "Marek"))
        )
        with pytest.raises(pl.PlanRefused, match="103") as e:
            rec.insert_fencer(
                {"txt_surname": "ZIELIŃSKI", "txt_first_name": "Marek", "int_birth_year": 1971}
            )
        assert e.value.kind == "precondition"

    def test_a_moved_birth_year_is_what_later_reads_return(self):
        """PROMO.PLAN.05"""
        rec = pl.RecordingConnector(_ReadOnly(_classic_db()), created=[])
        rec.update_fencer_birth_year(102, 1971, estimated=False)
        row = next(f for f in rec.fetch_fencer_db() if f["id_fencer"] == 102)
        assert (row["int_birth_year"], row["bool_birth_year_estimated"]) == (1971, False)
        assert rec.fetch_birth_years_batch([102]) == {102: 1971}
        assert rec.fetch_fencer_basics_batch([102])[102]["int_birth_year"] == 1971

    def test_a_tournament_is_prods_or_a_placeholder_and_every_call_is_recorded(self):
        """PROMO.PLAN.06"""
        db = _classic_db()
        db.find_or_create_tournament(7, "EPEE", "M", "V2", "2026-03-14", "PPW")
        rec = pl.RecordingConnector(_ReadOnly(db), created=[])
        assert rec.find_or_create_tournament(7, "EPEE", "M", "V2", "2026-03-14", "PPW") == 500
        new = rec.find_or_create_tournament(
            7, "SABRE", "M", "V2", "2026-03-14", "PPW", url_results="u"
        )
        assert new < 0
        assert rec.find_or_create_tournament(7, "SABRE", "M", "V2", "2026-03-14", "PPW") == new
        assert [o["ref"] for o in rec.ops] == [500, new, new]
        assert rec.ops[1]["url_results"] == "u"
        rec.ingest_results(new, [{"id_fencer": 101, "int_place": 1}], participant_count=1)
        assert rec.ops[-1] == {
            "op": "ingest_results",
            "tournament": new,
            "rows": [{"id_fencer": 101, "int_place": 1}],
            "participant_count": 1,
            "joined_order": None,
        }

    def test_writes_outside_a_domestic_ingestion_are_refused(self):
        """PROMO.PLAN.07 — and the alias write-back stays absent, as on the live connector."""
        rec = pl.RecordingConnector(_ReadOnly(_classic_db()), created=[])
        for call in (
            lambda: rec.merge_fencers(101, 102),
            lambda: rec.clear_tournament_results(500),
            lambda: rec.set_tournament_participant_count(500, 3),
            lambda: rec.upsert_joining_check(7, "EPEE", "M", True, {}),
        ):
            with pytest.raises(pl.PlanRefused) as e:
                call()
            assert e.value.kind == "precondition"
        assert not hasattr(rec, "update_fencer_aliases")
        assert not hasattr(rec, "_sb")

    def test_the_event_reads_back_its_url_and_sources(self):
        """PROMO.PLAN.08"""
        db = _classic_db()
        db.events[7]["url_event"] = None
        rec = pl.RecordingConnector(_ReadOnly(db), created=[])
        rec.set_event_url_event(7, SCHEDULE)
        rec.set_event_ingest_sources(7, [{"name": "Szpada", "status": "committed"}])
        ev = rec.find_event_by_code("PPW3-2025-2026")
        assert ev is not None
        assert ev["url_event"] == SCHEDULE
        assert ev["json_ingest_sources"] == [{"name": "Szpada", "status": "committed"}]
        assert db.events[7]["url_event"] is None


class TestApply:
    def test_apply_maps_placeholders_and_keeps_explicit_ids(self):
        """PROMO.PLAN.09"""
        db = _classic_db()
        rec = pl.RecordingConnector(_ReadOnly(db), created=_created((368, "ZIELIŃSKI", "Marek")))
        rec.insert_fencer(
            {"txt_surname": "ZIELIŃSKI", "txt_first_name": "Marek", "int_birth_year": 1971}
        )
        ref = rec.find_or_create_tournament(7, "SABRE", "M", "V2", "2026-03-14", "PPW")
        rec.ingest_results(ref, [{"id_fencer": 368, "int_place": 1}], participant_count=1)
        refs = pl.apply_plan(rec.ops, db)
        assert db.inserted == [368]
        assert refs == {ref: 500}
        assert db.results[500] == [{"id_fencer": 368, "int_place": 1}]

    def test_apply_refuses_a_tournament_that_moved_since_the_plan(self):
        """PROMO.PLAN.09 — a PROD tournament id the plan read must still be the one found."""
        db = _classic_db()
        db.find_or_create_tournament(7, "EPEE", "M", "V2", "2026-03-14", "PPW")
        rec = pl.RecordingConnector(_ReadOnly(db), created=[])
        rec.find_or_create_tournament(7, "EPEE", "M", "V2", "2026-03-14", "PPW")
        db.tournaments[501] = dict(db.tournaments.pop(500), id_tournament=501)
        with pytest.raises(pl.PlanRefused, match="500"):
            pl.apply_plan(rec.ops, db)


# ---------------------------------------------------------------------------
# Plan, then apply, equals a live run — through the real INGEST_DOMESTIC flow
# ---------------------------------------------------------------------------


class _Resp:
    def __init__(self, text="", js=None):
        self.text = text
        self._js = js or []

    def raise_for_status(self):
        pass

    def json(self):
        return self._js


class _Ftl:
    """FTL as the driver reads it: a schedule and one data page per listing."""

    def __init__(self, listings: dict[str, tuple[str, list[tuple[str, int]]]]):
        self.listings = listings

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False

    def get(self, url):
        if "/results/data/" in url:
            uuid = url.rsplit("/", 1)[-1]
            return _Resp(
                js=[
                    {"id": f"{uuid}{p}", "name": n, "place": str(p), "country": "POL"}
                    for n, p in self.listings[uuid][1]
                ]
            )
        return _Resp(text="<li>Tableau</li>")


def _drive(ftl: _Ftl, fn, *args, **kwargs):
    kept = [{"uuid": u, "name": name} for u, (name, _) in ftl.listings.items()]
    with (
        patch("python.scrapers.ftl_auth.get_authed_ftl_client", return_value=ftl),
        patch("python.scrapers.ftl_auth.normalize_ftl_url", side_effect=lambda u: u),
        patch("python.tools.scrape_ftl_event_urls.parse_event_schedule", return_value=(kept, [])),
        patch("python.pipeline.ingest_cli._fire_staging_report", return_value=None) as staging,
        patch("python.pipeline.ingest_cli._after_event_run") as joining,
    ):
        out = fn(*args, **kwargs)
    return out, staging, joining


def _live(db: MemoryDb, ftl: _Ftl, event_code: str, season_end: int) -> None:
    from python.pipeline import ingest_cli

    _drive(
        ftl,
        ingest_cli.ingest_event_from_url,
        event_code=event_code,
        season_end_year=season_end,
        db=db,
    )


def _plan_then_apply(db: MemoryDb, ftl: _Ftl, event_code: str, season_end: int, created) -> pl.Plan:
    before = db.state()
    plan, staging, joining = _drive(
        ftl,
        pl.plan_event,
        event_code,
        season_end,
        _ReadOnly(db),
        url_event=SCHEDULE,
        created=created,
    )
    assert db.state() == before, "planning wrote to the database"
    staging.assert_not_called()
    joining.assert_not_called()
    pl.apply_plan(json.loads(json.dumps(plan.to_json()))["ops"], db)
    return plan


def _created_by(db: MemoryDb) -> list[dict]:
    return [
        {
            "id_fencer": i,
            "surname": db.fencers[i]["txt_surname"],
            "first_name": db.fencers[i]["txt_first_name"],
        }
        for i in db.inserted
    ]


class TestPlanThenApplyEqualsLive:
    def test_per_category_engine_with_a_new_fencer_and_a_declared_year(self):
        """PROMO.PLAN.10 — 2025/26: the second listing finds the fencer the
        first created, and Stage 0's declared year is read back."""
        ftl = _Ftl(
            {
                "U1": (
                    "Szpada Mężczyzn kat. 2",
                    [("KOWALSKI Jan", 1), ("ZIELIŃSKI Marek", 2), ("NOWAK Adam", 3)],
                ),
                "U2": (
                    "Szabla Mężczyzn kat. 2",
                    [("ZIELIŃSKI Marek", 1), ("WIŚNIEWSKI Piotr", 2), ("NOWAK Adam", 3)],
                ),
            }
        )
        live = _classic_db()
        _live(live, ftl, "PPW3-2025-2026", 2026)
        assert len(live.inserted) == 1, "the fixture must create exactly one fencer"
        assert live.fencers[102]["int_birth_year"] == 1971, "the fixture must move a declared year"

        planned = _classic_db()
        plan = _plan_then_apply(planned, ftl, "PPW3-2025-2026", 2026, _created_by(live))
        assert planned.state() == live.state()
        assert [o["op"] for o in plan.ops].count("insert_fencer") == 1
        assert [r["status"] for r in plan.listings["rounds"]] == ["committed", "committed"]

    def test_joined_engine_keeps_the_order_and_the_joined_n(self):
        """PROMO.PLAN.11 — 2026/27: one combined listing, both slices with the
        listing's order."""

        def db() -> MemoryDb:
            return MemoryDb(
                [_fencer(201, "ADAMSKI", "Jan", 1980), _fencer(202, "BORSUK", "Adam", 1972)],
                [_event(8, "PPW4-2026-2027", "2027-02-13", 2)],
            )

        ftl = _Ftl({"U3": ("Szpada Mężczyzn kat. 1-2", [("BORSUK Adam", 1), ("ADAMSKI Jan", 2)])})
        live = db()
        _live(live, ftl, "PPW4-2026-2027", 2027)
        orders = {t["txt_joined_order"] for t in live.tournaments.values()}
        assert orders == {"21"}, "the fixture must write the joined order"

        planned = db()
        plan = _plan_then_apply(planned, ftl, "PPW4-2026-2027", 2027, [])
        assert planned.state() == live.state()
        assert {o["joined_order"] for o in plan.ops if o["op"] == "ingest_results"} == {"21"}


# ---------------------------------------------------------------------------
# plan_event: what promote calls
# ---------------------------------------------------------------------------


class TestPlanEvent:
    FTL = _Ftl({"U1": ("Szpada Mężczyzn kat. 2", [("KOWALSKI Jan", 1), ("WIŚNIEWSKI Piotr", 2)])})

    def test_a_blank_prod_url_takes_the_cert_runs_url(self):
        """PROMO.PLAN.12 — ADR-086's fill-blank tier."""
        db = _classic_db()
        db.events[7]["url_event"] = None
        plan, _, _ = _drive(
            self.FTL,
            pl.plan_event,
            "PPW3-2025-2026",
            2026,
            _ReadOnly(db),
            url_event=SCHEDULE,
            created=[],
        )
        assert {"op": "set_event_url_event", "id_event": 7, "url_event": SCHEDULE} in plan.ops
        assert plan.url_event == SCHEDULE

    def test_an_equal_url_is_left_alone(self):
        """PROMO.PLAN.12"""
        plan, _, _ = _drive(
            self.FTL,
            pl.plan_event,
            "PPW3-2025-2026",
            2026,
            _ReadOnly(_classic_db()),
            url_event=SCHEDULE,
            created=[],
        )
        assert all(o["op"] != "set_event_url_event" for o in plan.ops)

    def test_a_different_prod_url_refuses(self):
        """PROMO.PLAN.12"""
        db = _classic_db()
        db.events[7]["url_event"] = SCHEDULE + "X"
        with pytest.raises(pl.PlanRefused, match="url_event") as e:
            _drive(
                self.FTL,
                pl.plan_event,
                "PPW3-2025-2026",
                2026,
                _ReadOnly(db),
                url_event=SCHEDULE,
                created=[],
            )
        assert e.value.kind == "precondition"

    def test_an_unknown_or_international_event_refuses(self):
        """PROMO.PLAN.12"""
        db = _classic_db()
        with pytest.raises(pl.PlanRefused, match="PPW9-2025-2026"):
            pl.plan_event("PPW9-2025-2026", 2026, _ReadOnly(db), url_event=SCHEDULE, created=[])
        db.events[9] = _event(9, "PEW3-2025-2026", "2026-03-14", 1)
        with pytest.raises(pl.PlanRefused, match="international"):
            pl.plan_event("PEW3-2025-2026", 2026, _ReadOnly(db), url_event=SCHEDULE, created=[])

    def test_the_plan_carries_every_listings_hash(self):
        """PROMO.PLAN.12 — promote compares them with the CERT run's."""
        plan, _, _ = _drive(
            self.FTL,
            pl.plan_event,
            "PPW3-2025-2026",
            2026,
            _ReadOnly(_classic_db()),
            url_event=SCHEDULE,
            created=[],
        )
        (round_,) = plan.listings["rounds"]
        assert len(round_["sha256"]) == 64
        assert plan.listings["schedule"]["kept"] == 1
        assert json.loads(json.dumps(plan.to_json()))["event_code"] == "PPW3-2025-2026"
