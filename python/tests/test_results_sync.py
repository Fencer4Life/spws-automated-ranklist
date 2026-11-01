"""SYNC — the hourly results sync (ADR-119 §4, D5–D9, D12, G7).

doc/plans/partial-ingest-promote-results-sync-2026-10-31.html, release 3 (§03e).

Every hour an event in its window is read, compared with the latest finished
CERT run, ingested on CERT when its listings changed and promoted to PROD. These
are the parts of a cycle and the command line's three steps, with fake SQL and
outputs, no database and no network:

  SYNC.SEL.01  the window by the due moment: first day to the day after the
               end date, in Warsaw, in both DST states;
  SYNC.SEL.02  COMPLETED and CANCELLED are never selected;
  SYNC.SEL.03  the link is the switch (G7): a link on CERT or PROD, or an EVF
               results id on the international route; a manual code is taken
               out of its window, and refused with one line without a link;
  SYNC.SEL.04  a paused event is not selected; a manual code lifts its pause;
  SYNC.SEL.05  the matrix and its count; RESULTS_SYNC=off ends a scheduled
               select and not a manual one;
  SYNC.DUE.01  scheduled_moment reads an hour range (the daily form unchanged:
               PZSZ.SL.10 stays green);
  SYNC.CYCLE.01-04  the compare: nothing changed, promote only, changed, and
               two reads of an unchanged source compare equal;
  SYNC.CYCLE.05  the one line of each outcome (§04.6);
  SYNC.PAUSE.01  every failure pauses the event, with a reason free of names,
               and the database takes exactly the cycle's verdicts;
  SYNC.PAUSE.05  the ☀ line names every event in window, paused or not;
  SYNC.PZSZ.01-02  a start list's hash is part of the compare;
  SYNC.PAUSE.06  RESULTS_SYNC=off ends a scheduled select silently;
  SYNC.CYCLE.08  the compare reads as the ingest reads (G35 A);
  SYNC.CYCLE.09  a dry run says what the cycle would do (G36 A).

The morning cycle is told by the cron line that fired (G28 A), and the select
sends the ☀ line (G29 A).
"""

from __future__ import annotations

import datetime as dt
import json
from unittest.mock import MagicMock

import pytest

from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind
from python.pipeline.promotion import results_sync as rs

UTC = dt.UTC
CRON = "13 8-20 * * *"
PPW = "PPW2-2026-2027"  # domestic
PPS = "PPS2e-2026-2027"  # roster (PZSz)
PEW = "PEW3ef-2026-2027"  # international


def _event(
    code: str = PEW,
    start: str = "2026-11-14",
    end: str | None = "2026-11-15",
    status: str = "PLANNED",
    **links,
):
    return {"txt_code": code, "enum_status": status, "dt_start": start, "dt_end": end, **links}


# --------------------------------------------------------------------------
# SYNC.SEL.01 / SYNC.DUE.01 — the window, by the moment the cron was due
# --------------------------------------------------------------------------


class TestWindow:
    def test_SYNC_SEL_01_a_two_day_event_from_its_first_day_to_the_day_after_its_end(self):
        row = _event(start="2026-11-14", end="2026-11-15")
        days = {d: rs.in_window(row, dt.date(2026, 11, d)) for d in (13, 14, 15, 16, 17)}
        assert days == {13: False, 14: True, 15: True, 16: True, 17: False}

    def test_SYNC_SEL_01_a_one_day_event(self):
        for end in (None, "", "2026-11-22"):
            row = _event(code=PPS, start="2026-11-22", end=end)
            got = [rs.in_window(row, dt.date(2026, 11, d)) for d in (21, 22, 23, 24)]
            assert got == [False, True, True, False], end

    def test_SYNC_SEL_01_winter_a_late_evening_run_after_midnight_is_the_day_it_was_due(self):
        # Due 20:13 UTC on 16 Nov (21:13 Warsaw), started 23:40 UTC (00:40 Warsaw, 17 Nov).
        day = rs.due_day(CRON, dt.datetime(2026, 11, 16, 23, 40, tzinfo=UTC))
        assert day == dt.date(2026, 11, 16)
        assert rs.in_window(_event(), day)

    def test_SYNC_SEL_01_summer_the_last_cycle_of_the_day_after_the_end(self):
        row = _event(start="2027-06-12", end="2027-06-13")
        # Due 20:13 UTC on 14 June (22:13 Warsaw), started 22:30 UTC (00:30 Warsaw, 15 June).
        late = rs.due_day(CRON, dt.datetime(2027, 6, 14, 22, 30, tzinfo=UTC))
        assert late == dt.date(2027, 6, 14) and rs.in_window(row, late)
        # The first cycle on 15 June (10:13 Warsaw) is out.
        morning = rs.due_day(CRON, dt.datetime(2027, 6, 15, 8, 20, tzinfo=UTC))
        assert morning == dt.date(2027, 6, 15) and not rs.in_window(row, morning)

    def test_SYNC_SEL_01_a_manual_run_reads_the_warsaw_clock(self):
        assert rs.due_day(None, dt.datetime(2026, 11, 16, 23, 40, tzinfo=UTC)) == dt.date(
            2026, 11, 17
        )


class TestDueMoment:
    """SYNC.DUE.01: the latest moment at or before now that matches the cron's
    minute and one of its hours in UTC, read in Warsaw."""

    @staticmethod
    def _due(now: dt.datetime) -> dt.datetime:
        from python.scrapers.pzsz_start_list_store import scheduled_moment

        return scheduled_moment(CRON, now).astimezone(UTC)

    def test_SYNC_DUE_01_inside_the_range_the_latest_slot(self):
        assert self._due(dt.datetime(2026, 11, 14, 10, 5, tzinfo=UTC)) == dt.datetime(
            2026, 11, 14, 9, 13, tzinfo=UTC
        )
        assert self._due(dt.datetime(2026, 11, 14, 8, 13, tzinfo=UTC)) == dt.datetime(
            2026, 11, 14, 8, 13, tzinfo=UTC
        )

    def test_SYNC_DUE_01_after_the_range_the_evening_slot(self):
        assert self._due(dt.datetime(2026, 11, 14, 23, 59, tzinfo=UTC)) == dt.datetime(
            2026, 11, 14, 20, 13, tzinfo=UTC
        )

    def test_SYNC_DUE_01_before_the_range_yesterdays_evening_slot(self):
        assert self._due(dt.datetime(2026, 11, 15, 8, 12, tzinfo=UTC)) == dt.datetime(
            2026, 11, 14, 20, 13, tzinfo=UTC
        )
        assert self._due(dt.datetime(2026, 11, 15, 0, 30, tzinfo=UTC)) == dt.datetime(
            2026, 11, 14, 20, 13, tzinfo=UTC
        )

    def test_SYNC_DUE_01_the_daily_form_is_unchanged(self):
        from python.scrapers.pzsz_start_list_store import scheduled_moment

        moment = scheduled_moment("11 9 * * *", dt.datetime(2026, 10, 25, 12, 41, tzinfo=UTC))
        assert (moment.date(), moment.hour, moment.minute) == (dt.date(2026, 10, 25), 10, 11)

    def test_SYNC_DUE_01_a_range_that_is_not_hours_of_one_day_is_refused(self):
        from python.scrapers.pzsz_start_list_store import scheduled_moment

        for cron in ("13 20-8 * * *", "13 8-24 * * *", "60 8 * * *", "13 8-20/2 * * *"):
            with pytest.raises(ValueError):
                scheduled_moment(cron, dt.datetime(2026, 11, 14, 10, 5, tzinfo=UTC))


# --------------------------------------------------------------------------
# SYNC.SEL.02-05 — which events a cycle takes
# --------------------------------------------------------------------------

DAY = dt.date(2026, 11, 14)


def _select(cert, prod=None, pauses=None, **kw):
    kw.setdefault("day", DAY)
    return rs.select(cert, prod or {}, pauses or {}, **kw)


class TestSelect:
    def test_SYNC_SEL_02_completed_and_cancelled_are_never_selected(self):
        rows = [
            _event(code=f"PEW{n}ef-2026-2027", status=s, url_event="https://e/1")
            for n, s in enumerate(
                ("PLANNED", "SCHEDULED", "IN_PROGRESS", "COMPLETED", "CANCELLED"), start=3
            )
        ]
        assert _select(rows).events == ["PEW3ef-2026-2027", "PEW4ef-2026-2027", "PEW5ef-2026-2027"]

    def test_SYNC_SEL_03_the_link_is_the_switch(self):
        rows = [
            _event(code=PPW, url_event="https://ftl/1"),
            _event(code="PPW3-2026-2027"),  # its link is on PROD only
            _event(code="PPW4-2026-2027"),  # no link anywhere
            _event(code=PEW, url_event_3="https://engarde/1"),
            _event(code="PEW4ef-2026-2027", id_evf_event=85),
            _event(code="PPW5-2026-2027", id_evf_event=85),  # domestic: no EVF id route
            _event(code=PPS, url_event="  "),
        ]
        prod = {"PPW3-2026-2027": {"url_event": "https://ftl/3"}}
        got = _select(rows, prod)
        assert got.events == ["PEW3ef-2026-2027", "PEW4ef-2026-2027", PPW, "PPW3-2026-2027"]
        assert got.no_link == [PPS, "PPW4-2026-2027", "PPW5-2026-2027"]
        assert got.refused is None

    def test_SYNC_SEL_03_a_manual_code_is_taken_outside_its_window(self):
        rows = [_event(code=PEW, start="2026-12-01", end="2026-12-02", url_event="https://e/1")]
        got = _select(rows, code=PEW, scheduled=False)
        assert (got.events, got.refused) == ([PEW], None)

    def test_SYNC_SEL_03_a_manual_code_without_a_link_is_refused_and_not_paused(self):
        got = _select([_event(code=PEW)], code=PEW, scheduled=False)
        assert got.events == [] and got.resume == []
        assert got.refused == (
            f"{PEW}: no results link on CERT or PROD; set it in Admin, then sync again"
        )

    @pytest.mark.parametrize("status", ["COMPLETED", "CANCELLED"])
    def test_SYNC_SEL_03_a_manual_code_still_never_takes_a_closed_event(self, status):
        got = _select(
            [_event(code=PEW, status=status, url_event="https://e/1")], code=PEW, scheduled=False
        )
        assert got.events == [] and got.refused == f"{PEW} is {status}: the sync does not take it"

    def test_SYNC_SEL_03_a_manual_code_the_select_does_not_know_is_refused(self):
        got = _select([], code=PEW, scheduled=False)
        assert got.events == []
        assert got.refused == f"{PEW} is not an event of the active season on the route"

    def test_SYNC_SEL_04_a_paused_event_is_not_selected(self):
        rows = [
            _event(code=PEW, url_event="https://e/1"),
            _event(code=PPW, url_event="https://f/1"),
        ]
        pause = {
            "paused_at": "2026-11-13T16:13:00+00:00",
            "paused_reason": "identity, Women's Foil V1",
            "paused_by_run": "https://github.com/o/r/actions/runs/9",
        }
        got = _select(rows, pauses={PEW: pause})
        assert got.events == [PPW]
        assert got.paused == [{"code": PEW, **pause}]
        assert got.resume == []

    def test_SYNC_SEL_04_a_manual_code_lifts_its_pause_first(self):
        pause = {"paused_at": "2026-11-13T16:13:00+00:00", "paused_reason": "x"}
        got = _select(
            [_event(code=PEW, url_event="https://e/1")],
            pauses={PEW: pause},
            code=PEW,
            scheduled=False,
        )
        assert (got.events, got.resume, got.paused) == ([PEW], [PEW], [])

    def test_SYNC_SEL_05_the_matrix_and_its_count(self):
        got = _select([_event(code=PEW, url_event="https://e/1"), _event(code=PPW, url_event="u")])
        # Each cycle is told its event and season end year (ingest-event.yml needs both).
        assert (json.loads(got.matrix()), got.count) == (
            [
                {"event_code": PEW, "season_end_year": 2027},
                {"event_code": PPW, "season_end_year": 2027},
            ],
            2,
        )
        empty = _select([_event(code=PEW, start="2026-12-01", url_event="https://e/1")])
        assert (json.loads(empty.matrix()), empty.count) == ([], 0)

    @pytest.mark.parametrize("value", ["off", "OFF", " off "])
    def test_SYNC_SEL_05_the_switch_ends_a_scheduled_select(self, value):
        rows = [_event(code=PEW, url_event="https://e/1")]
        got = _select(rows, switch=value)
        assert (got.events, got.off) == ([], True)
        manual = _select(rows, switch=value, scheduled=False)
        assert (manual.events, manual.off) == ([PEW], False)

    @pytest.mark.parametrize("value", [None, "", "on", "of"])
    def test_SYNC_SEL_05_absent_or_anything_else_is_on(self, value):
        got = _select([_event(code=PEW, url_event="https://e/1")], switch=value)
        assert (got.events, got.off) == ([PEW], False)


# --------------------------------------------------------------------------
# SYNC.CYCLE.01-04, SYNC.PZSZ.01-02 — the compare
# --------------------------------------------------------------------------


def _parsed(places=(1, 2, 3), url="https://o/1"):
    return ParsedTournament(
        source_kind=SourceKind.FTL,
        results=[
            ParsedResult(source_row_id=f"r{p}", fencer_name=f"FENCER{p} Jan", place=p)
            for p in places
        ],
        raw_pool_size=len(places),
        weapon="EPEE",
        gender="M",
        category_hint="V2",
        source_url=url,
        tournament_name="EPEE M V2",
    )


def _rec(name="Men's Epee V2", uuid="u2", places=(1, 2, 3), start_list=None):
    rec = {
        "name": name,
        "uuid": uuid,
        "url": f"https://ftl/{uuid}",
        "count": len(places),
        "has_de": True,
        "weapon": "EPEE",
        "gender": "M",
        "cats": ["V2"],
        "_base": _parsed(places, url=f"https://ftl/{uuid}"),
    }
    if start_list:
        rec["start_list_sha256"] = start_list
    return rec


def _read(recs, skipped=(), sources=None, pzsz_event=None):
    from python.pipeline.ingest_cli import EventRead

    return EventRead(
        route="domestic",
        kept=[{"uuid": r["uuid"], "name": r["name"]} for r in recs],
        skipped=list(skipped),
        unparseable=[],
        listings=list(recs),
        decisions=[{"status": "committed", "reason": "", "commit_cats": ["V2"]} for _ in recs],
        overrides=None,
        sources=sources,
        pzsz_event=pzsz_event,
    )


def _run_of(read, run_id=14, fingerprint="a" * 64):
    """The latest FINISHED run, as the CERT row stores what the read logged.
    The commit changes a round's verdict; the compare must not read it."""
    from python.pipeline.promotion.run_record import ListingLog

    log = ListingLog()
    log.add_read(read)
    listings = json.loads(json.dumps(log.listings(), default=str))
    for r in listings["rounds"]:
        r["status"] = "dropped"
    return {"id": run_id, "listings": listings, "result_fingerprint": fingerprint}


WAITING = {
    "uuid": "u5",
    "name": "Women's Foil V1",
    "reason": "not final (its schedule row does not say Finished)",
}


class TestCompare:
    def test_SYNC_CYCLE_01_nothing_changed_and_prod_current(self):
        read = _read([_rec()], [WAITING])
        got = rs.compare(read, _run_of(read), "a" * 64)
        assert got == rs.Comparison(changed=False, promote_only=False, previous_run=14, new=[])

    def test_SYNC_CYCLE_02_the_same_hashes_and_prod_behind(self):
        read = _read([_rec()])
        for prod in ("b" * 64, None):
            got = rs.compare(read, _run_of(read), prod)
            assert (got.changed, got.promote_only, got.previous_run) == (False, True, 14)

    def test_SYNC_CYCLE_03_a_first_run_is_a_change(self):
        got = rs.compare(_read([_rec(), _rec("Men's Epee V3", "u3", (1, 2))]), None, None)
        assert (got.changed, got.promote_only, got.previous_run) == (True, False, None)
        assert got.new == [("Men's Epee V2", 3), ("Men's Epee V3", 2)]

    def test_SYNC_CYCLE_03_a_listing_whose_rows_changed(self):
        before = _read([_rec(), _rec("Men's Epee V3", "u3", (1, 2))])
        now = _read([_rec(), _rec("Men's Epee V3", "u3", (1, 2, 3))])
        got = rs.compare(now, _run_of(before), "a" * 64)
        assert (got.changed, got.new) == (True, [("Men's Epee V3", 3)])

    def test_SYNC_CYCLE_03_a_new_round(self):
        before = _read([_rec()], [WAITING])
        now = _read([_rec(), _rec("Women's Foil V1", "u5", (1, 2, 3, 4))])
        got = rs.compare(now, _run_of(before), "a" * 64)
        assert (got.changed, got.new) == (True, [("Women's Foil V1", 4)])

    def test_SYNC_CYCLE_03_the_schedule_alone(self):
        before = _read([_rec()])
        now = _read([_rec()], [WAITING])
        got = rs.compare(now, _run_of(before), "a" * 64)
        assert (got.changed, got.new) == (True, [])

    def test_SYNC_CYCLE_03_the_result_slots_alone(self):
        before = _read([_rec()], sources=[{"slot": "url_event", "url": "https://e/1"}])
        now = _read(
            [_rec()],
            sources=[
                {"slot": "url_event", "url": "https://e/1"},
                {"slot": "url_event_2", "url": "https://e/2"},
            ],
        )
        assert rs.compare(now, _run_of(before), "a" * 64).changed

    def test_SYNC_PZSZ_01_the_compare_reads_the_start_lists_hash(self):
        """§04.9: a PZSz round's start-list hash is part of the comparison."""
        before = _read([_rec(start_list="1" * 64)], pzsz_event=4588)
        same = _read([_rec(start_list="1" * 64)], pzsz_event=4588)
        assert not rs.compare(same, _run_of(before), "a" * 64).changed

    def test_SYNC_PZSZ_02_a_new_stored_start_list_alone_is_a_change(self):
        before = _read([_rec(start_list="1" * 64)], pzsz_event=4588)
        now = _read([_rec(start_list="2" * 64)], pzsz_event=4588)
        got = rs.compare(now, _run_of(before), "a" * 64)
        assert (got.changed, got.new) == (True, [("Men's Epee V2", 3)])

    @pytest.mark.parametrize(
        "url",
        [
            "https://www.4fence.it/FIS/Risultati/2026-11-14-07_Napoli/index.php",
            "https://fencingworldwide.com/en/12345-2026/tournament/",
            "https://dartagnan.live/2026/salzburg/en/index.html",
        ],
    )
    def test_SYNC_CYCLE_04_two_reads_of_an_unchanged_source_compare_equal(self, url):
        """A bracket waiting on the 60-minute rule is skipped with a reason that
        carries no clock, so cycle after cycle the schedule hashes the same."""
        from python.pipeline import international_sources as src

        parsed = _parsed(url="https://o/1")
        fetcher = MagicMock()
        fetcher.fetch_event_url_with_skips.return_value = ([parsed], [])
        first = dt.datetime(2026, 11, 14, 9, 13, tzinfo=UTC)

        def read_at(now: dt.datetime):
            recs, _kept, skipped = src.read_brackets(
                {"txt_code": PEW},
                [url],
                fetcher=fetcher,
                finality=src.Sightings(lambda _k, _s: first, now=now, ended=False),
            )
            assert recs == [] and len(skipped) == 1
            return _read([], skipped, sources=[{"slot": "url_event", "url": url}])

        early = read_at(first + dt.timedelta(minutes=1))
        later = read_at(first + dt.timedelta(minutes=58))
        got = rs.compare(later, _run_of(early), "a" * 64)
        assert (got.changed, got.promote_only) == (False, False)


# --------------------------------------------------------------------------
# SYNC.CYCLE.05, SYNC.PAUSE.01 — what a cycle says, and when it pauses
# --------------------------------------------------------------------------

MOMENT = dt.datetime(2026, 11, 14, 13, 13, tzinfo=UTC)  # 14:13 Warsaw
RUN_URL = "https://github.com/Fencer4Life/SPWSranklist/actions/runs/77"
REFUSAL = "KOWALSKA Anna declared 1979, the bracket allows 1966–1975"  # a name: Telegram only


def _cycle(**kw):
    kw.setdefault("code", PPW)
    kw.setdefault("moment", MOMENT)
    kw.setdefault("run_url", RUN_URL)
    return rs.Cycle(**kw)


def _new_run(status="FINISHED", run_id=15, rounds=(), skipped=(), **kw):
    return {
        "id": run_id,
        "status": status,
        "listings": {
            "schedule": {"skipped": [{"name": n, "reason": r} for n, r in skipped]},
            "rounds": list(rounds),
            **kw.pop("listings", {}),
        },
        **kw,
    }


CHANGED = rs.Comparison(changed=True, promote_only=False, previous_run=14, new=[])


def _lines(cycle) -> list[str]:
    line = rs.cycle_line(cycle)
    assert line is not None
    return line.splitlines()


class TestCycleLine:
    def test_SYNC_CYCLE_05_a_quiet_cycle_says_nothing_and_does_not_pause(self):
        cycle = _cycle(comparison=rs.Comparison(False, False, 14, []))
        assert (rs.cycle_line(cycle), rs.verdict(cycle), rs.pause_for(cycle)) == (
            None,
            "unchanged",
            None,
        )

    def test_SYNC_CYCLE_05_promoted(self):
        cycle = _cycle(
            comparison=rs.Comparison(
                True, False, 14, [("Men's Epee V2", 18), ("Men's Epee V3", 11)]
            ),
            run=_new_run(
                skipped=[("A", "not final (its schedule row does not say Finished)")] * 5
                + [("Team", "team event")],
                gate={"passed": True, "findings": []},
                promote={"outcome": "applied", "fingerprint": "f" * 64},
            ),
            promote={"result": "success", "writes": 41},
        )
        assert rs.cycle_line(cycle) == (
            f"✅ {PPW} · cycle 14:13 · CERT run 15 · promoted to PROD (41 writes)\n"
            "   new: Men's Epee V2 (18), Men's Epee V3 (11) · 5 listings not final: A, A, A, A, A"
            f" · report: staging-reports/{PPW}/full.md"
        )
        assert (rs.verdict(cycle), rs.pause_for(cycle)) == ("promoted", None)

    def test_SYNC_CYCLE_05_promote_only_names_the_run_it_promoted(self):
        cycle = _cycle(
            comparison=rs.Comparison(False, True, 14, []),
            run=_new_run(run_id=14, promote={"outcome": "applied", "fingerprint": "f" * 64}),
            promote={"result": "success", "writes": 1},
        )
        assert rs.cycle_line(cycle) == (
            f"✅ {PPW} · cycle 14:13 · CERT run 14 · promoted to PROD (1 write)\n"
            f"   report: staging-reports/{PPW}/full.md"
        )

    def test_SYNC_CYCLE_05_a_refused_listing(self):
        cycle = _cycle(
            code=PEW,
            moment=dt.datetime(2026, 11, 14, 16, 13, tzinfo=UTC),
            comparison=CHANGED,
            prod_holds_previous=True,
            run=_new_run(
                status="FAILED",
                error=f"ListingRefused: {REFUSAL}",
                listings={
                    "refusal": {
                        "listing": "Women's Foil V1",
                        "kind": "identity",
                        "message": REFUSAL,
                    }
                },
            ),
        )
        assert rs.cycle_line(cycle) == (
            f"❌ {PEW} · cycle 17:13 · CERT run 15 FAILED, CERT unchanged (run 14 stands), "
            "PROD keeps run 14\n"
            f"   ListingRefused [identity] Women's Foil V1: {REFUSAL}\n"
            f"   PAUSED. Fix it, then send: sync {PEW}"
        )
        assert rs.verdict(cycle) == "failed"
        assert rs.pause_for(cycle) == ("identity, Women's Foil V1", RUN_URL)

    def test_SYNC_CYCLE_05_a_failed_first_run(self):
        cycle = _cycle(
            comparison=rs.Comparison(True, False, None, []),
            prod_holds_previous=False,
            run=_new_run(status="FAILED", error="ApplyRefused: The apply of X refused"),
        )
        assert _lines(cycle) == [
            f"❌ {PPW} · cycle 14:13 · CERT run 15 FAILED, CERT unchanged, PROD unchanged",
            "   ApplyRefused: The apply of X refused",
            f"   PAUSED. Fix it, then send: sync {PPW}",
        ]
        assert rs.pause_for(cycle) == ("ApplyRefused", RUN_URL)

    def test_SYNC_CYCLE_05_the_gate_blocks(self):
        cycle = _cycle(
            comparison=CHANGED,
            run=_new_run(
                gate={
                    "passed": False,
                    "findings": [
                        {
                            "check": "birth years",
                            "kind": "identity",
                            "message": "NOWAK Jan: estimated",
                        },
                        {"check": "scores", "kind": "information", "message": "fine"},
                    ],
                }
            ),
        )
        assert _lines(cycle) == [
            f"❌ {PPW} · cycle 14:13 · CERT run 15 · the gate blocks promote, PROD keeps run 14",
            "   [identity] birth years: NOWAK Jan: estimated",
            f"   PAUSED. Fix it, then send: sync {PPW}",
        ]
        assert (rs.verdict(cycle), rs.pause_for(cycle)) == (
            "blocked",
            ("gate: 1 identity", RUN_URL),
        )

    def test_SYNC_CYCLE_05_promote_refused(self):
        cycle = _cycle(
            comparison=CHANGED,
            run=_new_run(
                gate={"passed": True, "findings": []},
                promote={"outcome": "refused", "reason": "The source changed since the CERT run."},
            ),
            promote={"result": "failure"},
        )
        assert _lines(cycle) == [
            f"❌ {PPW} · cycle 14:13 · CERT run 15 · promote to PROD refused, PROD unchanged",
            "   The source changed since the CERT run.",
            f"   PAUSED. Fix it, then send: sync {PPW}",
        ]
        assert (rs.verdict(cycle), rs.pause_for(cycle)) == ("refused", ("promote refused", RUN_URL))

    def test_SYNC_CYCLE_05_promote_failed_without_a_ledger_entry(self):
        cycle = _cycle(
            comparison=CHANGED,
            run=_new_run(gate={"passed": True, "findings": []}),
            promote={"result": "failure"},
        )
        assert _lines(cycle) == [
            f"❌ {PPW} · cycle 14:13 · CERT run 15 · promote to PROD failed, PROD unchanged",
            f"   the promote job failed: {RUN_URL}",
            f"   PAUSED. Fix it, then send: sync {PPW}",
        ]
        assert rs.pause_for(cycle) == ("promote failed", RUN_URL)

    def test_SYNC_CYCLE_05_the_refresh_stopped(self):
        report = (
            "# Refresh cert from PROD · apply · 2026-11-14 09:13 UTC\n\n"
            "status: stopped_renumbering\n"
            'counts: {"renumbered": 2}\n'
        )
        cycle = _cycle(code=PPS, comparison=CHANGED, refresh=report)
        assert _lines(cycle) == [
            f"⏸ {PPS} · cycle 14:13 · nothing written",
            "   the PROD→CERT refresh needs the administrator (stopped_renumbering; 2 renumbered)",
            f"   PAUSED. Apply the refresh, then send: sync {PPS}",
        ]
        assert (rs.verdict(cycle), rs.pause_for(cycle)) == (
            "stopped",
            ("refresh: stopped_renumbering", RUN_URL),
        )

    def test_SYNC_CYCLE_05_a_read_that_failed_before_a_run_opened(self):
        cycle = _cycle(comparison=None, error="FtlAuthError: the FTL session was refused")
        assert _lines(cycle) == [
            f"❌ {PPW} · cycle 14:13 · nothing written, CERT and PROD unchanged",
            "   FtlAuthError: the FTL session was refused",
            f"   PAUSED. Fix it, then send: sync {PPW}",
        ]
        assert rs.pause_for(cycle) == ("read failed: FtlAuthError", RUN_URL)

    def test_SYNC_CYCLE_05_nothing_final_yet(self):
        cycle = _cycle(
            comparison=CHANGED,
            run=_new_run(skipped=[("A", "not final (its schedule row does not say Finished)")] * 3),
        )
        assert rs.cycle_line(cycle) == (
            f"⏳ {PPW} · cycle 14:13 · CERT run 15 · nothing final yet, nothing written"
            " · 3 listings not final: A, A, A"
        )
        assert (rs.verdict(cycle), rs.pause_for(cycle)) == ("nothing_final", None)

    def test_SYNC_PAUSE_01_no_pause_reason_names_a_fencer(self):
        """D12: the reason is shown in the ☀ line and the Actions log; the
        refusal's message stays on the run row and in Telegram."""
        cycle = _cycle(
            comparison=CHANGED,
            run=_new_run(
                status="FAILED",
                error=f"ListingRefused: {REFUSAL}",
                listings={
                    "refusal": {
                        "listing": "Women's Foil V1",
                        "kind": "identity",
                        "message": REFUSAL,
                    }
                },
            ),
        )
        pause = rs.pause_for(cycle)
        assert pause is not None
        reason, _ = pause
        assert "KOWALSKA" not in reason and "1979" not in reason


def test_SYNC_PAUSE_01_the_database_takes_exactly_the_cycles_verdicts():
    """The migration's CHECK on txt_last_verdict lists every verdict a cycle
    can record, and nothing else."""
    import re
    from pathlib import Path

    sql = (
        Path(__file__).resolve().parents[2]
        / "supabase/migrations/20261101000001_results_sync_event.sql"
    ).read_text(encoding="utf-8")
    check = re.search(r"txt_last_verdict IN \(([^)]*)\)", sql)
    assert check is not None
    assert tuple(re.findall(r"'([a-z_]+)'", check.group(1))) == rs.VERDICTS


class TestMorningLine:
    def test_SYNC_PAUSE_05_the_morning_line_names_every_event_in_window(self):
        rows = [
            _event(code=PPW, url_event="https://f/1"),
            _event(code=PEW, url_event="https://e/1"),
            _event(code=PPS),
        ]
        pause = {
            "paused_at": "2026-11-13T16:13:00+00:00",
            "paused_reason": "identity, Women's Foil V1",
        }
        selection = _select(rows, pauses={PEW: pause})
        moment = dt.datetime(2026, 11, 14, 8, 13, tzinfo=UTC)  # 09:13 Warsaw
        assert rs.morning_line(moment, selection) == (
            f"☀ 09:13 · in window: {PPW} (syncing) · "
            f"{PEW} (PAUSED since yesterday 17:13: identity, Women's Foil V1) · "
            f"{PPS} (no results link)"
        )

    def test_SYNC_PAUSE_05_an_empty_window(self):
        assert rs.morning_line(MOMENT, _select([])) == "☀ 14:13 · nothing in window"


# --------------------------------------------------------------------------
# The command line: select, compare and outcome against fake CERT and PROD
# --------------------------------------------------------------------------

RUN_URL_77 = "https://github.com/Fencer4Life/SPWSranklist/actions/runs/77"


class _Sql:
    """CERT or PROD for the sync's command line: what it reads, and every
    write it makes, in order."""

    def __init__(
        self, events=(), pauses=None, links=None, runs=None, latest=None, fingerprints=None
    ):
        self._events = [dict(e) for e in events]
        self._pauses = dict(pauses or {})
        self._links = dict(links or {})
        self._runs = dict(runs or {})
        self._latest = dict(latest or {})
        self._fps = dict(fingerprints or {})
        self.writes: list[tuple] = []

    def events(self):
        return [dict(e) for e in self._events]

    def pauses(self):
        return dict(self._pauses)

    def links(self):
        return dict(self._links)

    def resume(self, code):
        self.writes.append(("resume", code))
        return code in self._pauses

    def pause(self, code, reason, run_url):
        self.writes.append(("pause", code, reason, run_url))

    def cycle(self, code, verdict):
        self.writes.append(("cycle", code, verdict))

    def latest_finished_run(self, code):
        return self._latest.get(code)

    def run(self, run_id):
        return self._runs.get(run_id)

    def result_fingerprint(self, code):
        return self._fps.get(code)


class _Out:
    def __init__(self):
        self.values: dict[str, str] = {}

    def __call__(self, **values):
        self.values.update({k: str(v) for k, v in values.items()})


PAUSED = {
    "paused_at": "2026-11-13T16:13:00+00:00",
    "paused_reason": "identity, Women's Foil V1",
    "paused_by_run": RUN_URL_77,
}
LATE_MORNING = dt.datetime(2026, 11, 14, 9, 40, tzinfo=UTC)  # due 08:13 UTC, 09:13 Warsaw
HOURLY_NOW = dt.datetime(2026, 11, 14, 13, 20, tzinfo=UTC)


def _cli_select(cert, prod=None, **kw):
    sent: list[str] = []
    out = _Out()
    kw.setdefault("now", HOURLY_NOW)
    kw.setdefault("cron", rs.HOURLY)
    code = rs.run_select(cert, prod or _Sql(), send=sent.append, output=out, **kw)
    return code, sent, out.values


class TestMorningCycle:
    def test_SYNC_DUE_01_the_morning_cycle_is_told_by_the_line_that_fired(self):
        """G28 A: the same thirteen cycles as two cron lines; GitHub names the
        line that fired, so a morning run started late is still the morning's."""
        assert (rs.MORNING, rs.HOURLY) == ("13 8 * * *", "13 9-20 * * *")
        assert rs.is_morning(rs.MORNING)
        assert not rs.is_morning(rs.HOURLY) and not rs.is_morning(None)
        from python.scrapers.pzsz_start_list_store import scheduled_moment

        due = scheduled_moment(rs.MORNING, LATE_MORNING)
        assert due.astimezone(UTC) == dt.datetime(2026, 11, 14, 8, 13, tzinfo=UTC)


class TestSelectCli:
    def test_SYNC_SEL_05_the_outputs_of_a_scheduled_select(self):
        cert = _Sql([_event(code=PEW, url_event="https://e/1")])
        code, sent, out = _cli_select(cert)
        assert code == 0 and sent == []
        assert json.loads(out["events"]) == [{"event_code": PEW, "season_end_year": 2027}]
        assert out["count"] == "1"
        assert dt.datetime.fromisoformat(out["moment"]).astimezone(UTC) == dt.datetime(
            2026, 11, 14, 13, 13, tzinfo=UTC
        )
        assert cert.writes == []

    def test_SYNC_PAUSE_05_the_select_sends_the_morning_line_on_the_morning_cycle(self):
        """G29 A: the select sees every event in window, so it sends the ☀
        line, even when everything is paused and nothing cycles."""
        cert = _Sql([_event(code=PEW, url_event="https://e/1")], pauses={PEW: PAUSED})
        code, sent, out = _cli_select(cert, now=LATE_MORNING, cron=rs.MORNING)
        assert (code, out["count"]) == (0, "0")
        assert sent == [
            f"☀ 09:13 · in window: {PEW} (PAUSED since yesterday 17:13: identity, Women's Foil V1)"
        ]

    def test_SYNC_PAUSE_05_no_morning_line_on_another_cycle_or_a_dry_run(self):
        cert = _Sql([_event(code=PEW, url_event="https://e/1")])
        assert _cli_select(cert)[1] == []
        assert _cli_select(cert, now=LATE_MORNING, cron=rs.MORNING, dry_run=True)[1] == []

    def test_SYNC_SEL_04_a_manual_code_lifts_its_pause_on_cert(self):
        cert = _Sql([_event(code=PEW, url_event="https://e/1")], pauses={PEW: PAUSED})
        code, sent, out = _cli_select(cert, cron=None, code=PEW)
        assert (code, sent, out["count"]) == (0, [], "1")
        assert cert.writes == [("resume", PEW)]

    def test_SYNC_SEL_04_a_dry_run_lifts_nothing(self, capsys):
        cert = _Sql([_event(code=PEW, url_event="https://e/1")], pauses={PEW: PAUSED})
        assert _cli_select(cert, cron=None, code=PEW, dry_run=True)[0] == 0
        assert cert.writes == []
        assert f"(dry run) would lift the pause of {PEW}" in capsys.readouterr().out

    def test_SYNC_SEL_03_a_refused_manual_code_is_told_once_and_fails(self):
        cert = _Sql([_event(code=PEW)])
        code, sent, out = _cli_select(cert, cron=None, code=PEW)
        assert (code, out["count"]) == (1, "0")
        assert sent == [f"{PEW}: {rs.NO_LINK}"]
        assert out["reported"] == "true"  # the failure alert does not say it again
        assert cert.writes == []

    def test_SYNC_PAUSE_06_the_switch_ends_a_scheduled_select_silently(self, capsys):
        cert = _Sql([_event(code=PEW, url_event="https://e/1")])
        code, sent, out = _cli_select(cert, now=LATE_MORNING, cron=rs.MORNING, switch="off")
        assert (code, sent, out["count"]) == (0, [], "0")
        assert capsys.readouterr().out.strip() == "RESULTS_SYNC=off: no scheduled cycle runs"


class TestCompareCli:
    def _run(self, read, latest=None, prod_fp=None):
        out = _Out()
        cert = _Sql(latest={PPW: latest} if latest else None)
        prod = _Sql(fingerprints={PPW: prod_fp})
        code = rs.run_compare(PPW, read=read, cert=cert, prod=prod, output=out)
        return code, out.values, cert

    def test_SYNC_CYCLE_01_an_unchanged_event_outputs_nothing_to_do(self):
        read = _read([_rec()])
        code, out, cert = self._run(lambda: read, _run_of(read), "a" * 64)
        assert code == 0 and cert.writes == []
        assert (out["changed"], out["promote_only"], out["previous_run"]) == (
            "false",
            "false",
            "14",
        )
        assert json.loads(out["new"]) == []

    def test_SYNC_CYCLE_02_prod_behind_outputs_promote_only(self):
        read = _read([_rec()])
        _, out, _ = self._run(lambda: read, _run_of(read), "b" * 64)
        assert (out["changed"], out["promote_only"]) == ("false", "true")

    def test_SYNC_CYCLE_03_a_change_outputs_the_new_rounds(self):
        _, out, _ = self._run(lambda: _read([_rec()]), None, None)
        assert (out["changed"], out["previous_run"]) == ("true", "")
        assert json.loads(out["new"]) == [["Men's Epee V2", 3]]

    def test_SYNC_CYCLE_05_a_read_that_fails_outputs_its_kind_only(self):
        from python.scrapers.ftl_auth import FtlAuthError

        def refused():
            raise FtlAuthError("the FTL session was refused")

        def leaking():
            raise ValueError("row 7: KOWALSKA Anna 1979 could not be parsed")

        code, out, _ = self._run(refused)
        assert (code, out["error"]) == (1, "FtlAuthError: the FTL session was refused")
        code, out, _ = self._run(leaking)
        assert (code, out["error"]) == (1, "ValueError")

    def test_SYNC_CYCLE_08_the_compare_reads_as_the_ingest_reads(self, monkeypatch):
        """G35 A: the compare's read is the recorded ingest's own read, through
        the step's CERT connector and with none of promote's plan inputs
        (`sources`, `finality`, stored start lists). So it stores what that read
        stores, and only that: the first sighting of a bracket from an engine
        without a finished signal, which the 60-minute rule counts from, and a
        PZSz start list it captured. It writes no result."""
        from types import SimpleNamespace

        from python.pipeline import db_connector, ingest_cli

        link = "https://www.fencingtimelive.com/tournaments/eventSchedule/" + "a" * 32
        event = {"txt_code": PPW, "url_event": link}
        db = SimpleNamespace(find_event_by_code=lambda code: dict(event) if code == PPW else None)
        calls = []
        monkeypatch.setattr(db_connector, "create_db_connector", lambda: db)
        monkeypatch.setattr(
            ingest_cli, "read_event", lambda *a, **kw: calls.append((a, kw)) or "the read"
        )
        assert rs._read_for(PPW, 2027)() == "the read"
        [(args, kwargs)] = calls
        assert args == (event, PPW, 2027, link, None)
        assert kwargs == {"db": db}


class TestOutcomeCli:
    def _run(self, *, run=None, comparison=None, refresh=None, promote=None, error=None, **kw):
        sent: list[str] = []
        runs = {r["id"]: r for r in ([run] if run else [])}
        runs.setdefault(14, {"id": 14, "status": "FINISHED", "result_fingerprint": "a" * 64})
        cert = _Sql(runs=runs)
        prod = _Sql(fingerprints={PPW: "a" * 64})
        code = rs.run_outcome(
            PPW,
            cert=cert,
            prod=prod,
            moment=MOMENT,
            comparison=comparison if comparison is not None else CHANGED,
            run_id=run["id"] if run else None,
            error=error,
            refresh=refresh,
            promote=promote,
            run_url=RUN_URL_77,
            send=sent.append,
            **kw,
        )
        return code, sent, cert.writes

    def test_SYNC_CYCLE_01_a_quiet_cycle_is_recorded_and_says_nothing(self):
        code, sent, writes = self._run(comparison=rs.Comparison(False, False, 14, []))
        assert (code, sent, writes) == (0, [], [("cycle", PPW, "unchanged")])

    def test_SYNC_CYCLE_05_a_promoted_cycle_says_its_line(self):
        """G30 A: the count is the one the called promote handed back."""
        run = _new_run(
            gate={"passed": True, "findings": []},
            promote={"outcome": "applied", "fingerprint": "f" * 64},
        )
        _, sent, writes = self._run(run=run, promote={"result": "success", "writes": "41"})
        assert writes == [("cycle", PPW, "promoted")]
        assert sent[0].startswith(
            f"✅ {PPW} · cycle 14:13 · CERT run 15 · promoted to PROD (41 writes)"
        )

    def test_SYNC_PAUSE_01_a_failed_run_pauses_with_its_reason_and_run(self, capsys):
        run = _new_run(
            status="FAILED",
            error=f"ListingRefused: {REFUSAL}",
            listings={
                "refusal": {"listing": "Women's Foil V1", "kind": "identity", "message": REFUSAL}
            },
        )
        _, sent, writes = self._run(run=run)
        assert writes == [
            ("cycle", PPW, "failed"),
            ("pause", PPW, "identity, Women's Foil V1", RUN_URL_77),
        ]
        assert len(sent) == 1 and REFUSAL in sent[0]
        log = capsys.readouterr()
        assert "KOWALSKA" not in log.out + log.err and "1979" not in log.out + log.err

    def test_SYNC_PAUSE_02_a_refresh_stop_pauses(self):
        refresh = {"status": "stopped_unpaired", "counts": '{"unpaired": 1}'}
        writes = self._run(refresh=refresh)[2]
        assert writes[-1] == ("pause", PPW, "refresh: stopped_unpaired", RUN_URL_77)

    def test_SYNC_PAUSE_03_a_gate_block_and_a_promote_refusal_pause(self):
        blocked_run = _new_run(
            gate={"passed": False, "findings": [{"check": "c", "kind": "identity", "message": "m"}]}
        )
        assert self._run(run=blocked_run)[2][-1] == ("pause", PPW, "gate: 1 identity", RUN_URL_77)
        refused_run = _new_run(
            gate={"passed": True, "findings": []},
            promote={"outcome": "refused", "reason": "the source changed"},
        )
        writes = self._run(run=refused_run, promote={"result": "failure", "writes": ""})[2]
        assert writes[-1] == ("pause", PPW, "promote refused", RUN_URL_77)

    def test_SYNC_PZSZ_03_no_stored_start_list_pauses_with_the_store_command(self):
        error = "StoredStartListError: no start list of EPEE/F stored; store it with: python -m x"
        _, sent, writes = self._run(comparison=None, error=error)
        assert writes[-1] == ("pause", PPW, "read failed: StoredStartListError", RUN_URL_77)
        assert "store it with" in sent[0]

    def test_SYNC_CYCLE_05_a_dry_run_writes_and_sends_nothing(self):
        run = _new_run(status="FAILED", error="ApplyRefused: x")
        assert self._run(run=run, dry_run=True)[1:] == ([], [])

    def test_SYNC_CYCLE_09_a_dry_run_says_what_the_cycle_would_do(self, capsys):
        """G36 A: a dry run never refreshes, ingests or promotes, so it has no
        CERT run to judge. Its outcome says what the cycle would do, from the
        compare alone, and a failed read as a real cycle reports it, since the
        read is the same. It writes and sends nothing (SYNC.CYCLE.05)."""
        would = "would refresh CERT, ingest, and promote once the run finishes and its gate passes"
        two_new = rs.Comparison(True, False, 14, [("Men's Epee V2", 3), ("Women's Foil V1", 5)])
        cases = [
            (rs.Comparison(False, False, 14, []), None, "unchanged"),
            (rs.Comparison(False, True, 14, []), None, "would promote CERT run 14 to PROD"),
            (two_new, None, f"{would}: 2 new listing(s)"),
            (CHANGED, None, would),
            (
                None,
                "FtlAuthError: the FTL session was refused",
                "would fail and pause: read failed: FtlAuthError",
            ),
        ]
        for comparison, error, said in cases:
            sent: list[str] = []
            cert = _Sql(runs={14: {"id": 14, "status": "FINISHED", "result_fingerprint": "a" * 64}})
            code = rs.run_outcome(
                PPW,
                cert=cert,
                prod=_Sql(fingerprints={PPW: "a" * 64}),
                moment=MOMENT,
                comparison=comparison,
                run_id=None,
                error=error,
                refresh=None,
                promote=None,
                run_url=RUN_URL_77,
                send=sent.append,
                dry_run=True,
            )
            assert (code, sent, cert.writes) == (0, [], [])
            assert capsys.readouterr().out.strip() == f"(dry run) {PPW}: {said}"


def test_SYNC_CYCLE_05_the_public_error_of_a_failure_that_opened_no_run():
    from python.pipeline.promotion.cert_apply import GateUnavailable
    from python.scrapers.ftl_auth import FtlAuthError

    assert rs.public_error(FtlAuthError("refused\nagain")) == "FtlAuthError: refused again"
    assert rs.public_error(GateUnavailable("token")) == "GateUnavailable: token"
    assert rs.public_error(KeyError("KOWALSKA Anna")) == "KeyError"
