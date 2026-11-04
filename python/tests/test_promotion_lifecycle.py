"""PROMO.LIFE.01–16 — the event lifecycle rule and the daily close (ADR-108 §7, build step 11).

A listing is final only when its FTL schedule row says Finished. A domestic
ingestion skips a listing that is not final and lists it, which keeps the event
IN_PROGRESS. An event is COMPLETED once every listing is final and read and
today in Warsaw is later than the end date. The same rule runs on CERT (the
ingestion), in promote's plan, and in the daily close, which completes an event
on CERT and then PROD once both hold the CERT run's result and the organiser
has published nothing new.
"""

from __future__ import annotations

import datetime as dt
from pathlib import Path

import pytest

from python.pipeline.promotion import close, lifecycle
from python.pipeline.promotion.run_record import ListingLog, schedule_sha256
from python.tests.test_promotion_plan import (
    SCHEDULE,
    MemoryDb,
    _event,
    _fencer,
    _Ftl,
    _ReadOnly,
)
from python.tools.scrape_ftl_event_urls import parse_event_schedule

FIXTURE = Path(__file__).parent / "fixtures" / "ftl" / "event_schedule_PPW2.html"

FINISHED = '<i class="fas fa-check green-text mr-1"></i>Finished at 12:53 PM<span class="ml-3">(10 competitors)</span>'
POOLS = 'Pools<span class="ml-3">(10 competitors)</span>'


def _row(uuid: str, name: str, status: str) -> str:
    return (
        f'<tr id="ev_{uuid}" class="clickable-row" data-href="/events/view/{uuid}">'
        f'<td>10:00 AM</td><td><a href="/events/view/{uuid}"><strong>{name}</strong></a></td>'
        f"<td>{status}</td></tr>"
    )


def _day(heading: str, *rows: str) -> str:
    return f'<h5>{heading}</h5><table class="scheduleTable"><tbody>{"".join(rows)}</tbody></table>'


def _page(*days: str) -> str:
    return f"<html><body><h3>Event Schedule</h3><br />{''.join(days)}</body></html>"


# ---------------------------------------------------------------------------
# The schedule: Finished and the day of each listing
# ---------------------------------------------------------------------------


class TestSchedule:
    def test_a_real_schedule_reads_finished_and_the_day(self):
        """PROMO.LIFE.01 — PPW2 2025/26: every row says Finished; the day comes
        from the heading above its table."""
        kept, _ = parse_event_schedule(FIXTURE.read_text(encoding="utf-8"), with_skips=True)
        assert kept and all(k["finished"] for k in kept)
        assert {k["day"] for k in kept} <= {"2025-10-25", "2025-10-26"}
        assert {k["day"] for k in kept} == {"2025-10-25", "2025-10-26"}

    def test_a_row_without_finished_is_not_final(self):
        """PROMO.LIFE.02"""
        html = _page(
            _day(
                "Saturday September 26, 2026",
                _row("A1", "SZPADA WETERANI mężczyźni 2", FINISHED),
                _row("A2", "FLORET WETERANI kobiety 1", POOLS),
            )
        )
        kept, _ = parse_event_schedule(html, with_skips=True)
        assert {k["uuid"]: k["finished"] for k in kept} == {"A1": True, "A2": False}
        assert {k["day"] for k in kept} == {"2026-09-26"}

    def test_a_two_day_listing_is_final_when_its_last_day_says_finished(self):
        """PROMO.LIFE.03 — one link listed on two days is one bracket: the first
        day holds the pools, the last day the direct elimination (EMW Plovdiv
        2025, men's épée V1–V3; closing plan rev 5, G65 R1). It is final when
        the row of its last listed day says Finished, whatever the earlier rows
        say, and its day is that last day."""
        pools_then_de = _page(
            _day(
                "Saturday September 26, 2026",
                _row("B1", "SZABLA WETERANI mężczyźni 3 (Day 1)", POOLS),
            ),
            _day(
                "Sunday September 27, 2026",
                _row("B1", "SZABLA WETERANI mężczyźni 3 (Day 2)", FINISHED),
            ),
        )
        kept, _ = parse_event_schedule(pools_then_de, with_skips=True)
        assert len(kept) == 1
        assert kept[0]["finished"] is True
        assert kept[0]["day"] == "2026-09-27"

        de_not_finished = _page(
            _day(
                "Saturday September 26, 2026",
                _row("B1", "SZABLA WETERANI mężczyźni 3 (Day 1)", FINISHED),
            ),
            _day(
                "Sunday September 27, 2026",
                _row("B1", "SZABLA WETERANI mężczyźni 3 (Day 2)", POOLS),
            ),
        )
        kept, _ = parse_event_schedule(de_not_finished, with_skips=True)
        assert len(kept) == 1
        assert kept[0]["finished"] is False
        assert kept[0]["day"] == "2026-09-27"

    def test_split_final_lists_a_listing_that_is_not_final(self):
        """PROMO.LIFE.04"""
        kept = [
            {"uuid": "A1", "name": "a", "finished": True, "day": "2026-09-26"},
            {"uuid": "A2", "name": "b", "finished": False, "day": "2026-09-27"},
            {"uuid": "A3", "name": "c"},
        ]
        final, skips = lifecycle.split_final(kept)
        assert [k["uuid"] for k in final] == ["A1"]
        assert [(s["uuid"], s["reason"]) for s in skips] == [
            ("A2", lifecycle.NOT_FINAL),
            ("A3", lifecycle.NOT_FINAL),
        ]
        assert skips[0]["day"] == "2026-09-27"


# ---------------------------------------------------------------------------
# The rule
# ---------------------------------------------------------------------------

END = dt.date(2026, 9, 27)


def _listings(*, kept=2, not_final=(), unread=0, last_day="2026-09-27", committed=True) -> dict:
    log = ListingLog()
    final = [
        {"uuid": f"K{i}", "name": f"listing {i}", "finished": True, "day": last_day}
        for i in range(kept)
    ]
    skips = [
        {"uuid": f"N{i}", "name": n, "reason": lifecycle.NOT_FINAL, "day": last_day}
        for i, n in enumerate(not_final)
    ]
    log.add_schedule(final, skips)
    for k in final[: kept - unread]:
        log.rounds.append(
            {
                "name": k["name"],
                "uuid": k["uuid"],
                "status": "committed" if committed else "skipped",
            }
        )
    return log.listings()


class TestRule:
    def test_every_listing_final_and_read_after_the_end_date_is_completed(self):
        """PROMO.LIFE.05"""
        v = lifecycle.event_status(_listings(), dt_end=END, today=END + dt.timedelta(days=1))
        assert v.status == "COMPLETED"
        assert v.reasons == []

    def test_everything_in_on_the_last_day_stays_in_progress(self):
        """PROMO.LIFE.06 — organisers sometimes add a tournament the next day."""
        v = lifecycle.event_status(_listings(), dt_end=END, today=END)
        assert v.status == "IN_PROGRESS"
        assert any("end date" in r for r in v.reasons)

    def test_a_listing_that_is_not_final_keeps_the_event_in_progress(self):
        """PROMO.LIFE.07, amended by G44 A (3): through the day after the end
        date; from the next day the event completes without it, named."""
        listings = _listings(not_final=["FLORET WETERANI kobiety 1"])
        v = lifecycle.event_status(listings, dt_end=END, today=END + dt.timedelta(days=1))
        assert v.status == "IN_PROGRESS"
        assert any("FLORET WETERANI kobiety 1" in r for r in v.reasons)
        v = lifecycle.event_status(listings, dt_end=END, today=END + dt.timedelta(days=3))
        assert v.status == "COMPLETED"
        assert v.left_out == ["FLORET WETERANI kobiety 1"]

    def test_a_listing_dated_after_the_end_date_keeps_it_in_progress(self):
        """PROMO.LIFE.08 — the event's dates need correcting."""
        v = lifecycle.event_status(
            _listings(last_day="2026-09-28"), dt_end=END, today=END + dt.timedelta(days=3)
        )
        assert v.status == "IN_PROGRESS"
        assert any("2026-09-28" in r for r in v.reasons)

    def test_a_listing_the_run_did_not_read_keeps_it_in_progress(self):
        """PROMO.LIFE.09"""
        v = lifecycle.event_status(
            _listings(unread=1), dt_end=END, today=END + dt.timedelta(days=3)
        )
        assert v.status == "IN_PROGRESS"

    def test_nothing_committed_leaves_the_status_alone(self):
        """PROMO.LIFE.09 — an event with no result is not moved to IN_PROGRESS."""
        assert (
            lifecycle.target_status(
                _listings(committed=False), dt_end=END, today=END + dt.timedelta(days=3)
            )
            is None
        )

    def test_today_is_the_date_in_warsaw(self):
        """PROMO.LIFE.10 — 22:30 UTC on 27 September is 28 September in Warsaw."""
        now = dt.datetime(2026, 9, 27, 22, 30, tzinfo=dt.UTC)
        assert lifecycle.warsaw_today(now) == dt.date(2026, 9, 28)

    def test_the_steps_go_through_the_validator_pairs(self):
        """PROMO.LIFE.10 — PLANNED never jumps to COMPLETED."""
        assert lifecycle.steps("PLANNED", "COMPLETED") == ["IN_PROGRESS", "COMPLETED"]
        assert lifecycle.steps("IN_PROGRESS", "COMPLETED") == ["COMPLETED"]
        assert lifecycle.steps("COMPLETED", "IN_PROGRESS") == ["IN_PROGRESS"]
        assert lifecycle.steps("COMPLETED", "COMPLETED") == []


# ---------------------------------------------------------------------------
# The ingestion and the plan set the status by the rule
# ---------------------------------------------------------------------------


def _db(end: str) -> MemoryDb:
    e = _event(8, "PPW4-2026-2027", end, 2)
    return MemoryDb(
        [_fencer(201, "ADAMSKI", "Jan", 1980), _fencer(202, "BORSUK", "Adam", 1972)], [e]
    )


FTL = _Ftl(
    {
        "U3": ("Szpada Mężczyzn kat. 1-2", [("BORSUK Adam", 1), ("ADAMSKI Jan", 2)]),
        "U4": ("Szabla Mężczyzn kat. 2", [("BORSUK Adam", 1)]),
    }
)


def _drive_schedule(fn, *args, finished=("U3", "U4"), day="2027-02-13", today=None, **kwargs):
    from unittest.mock import patch

    kept = [
        {"uuid": u, "name": name, "finished": u in finished, "day": day}
        for u, (name, _) in FTL.listings.items()
    ]
    with (
        patch("python.scrapers.ftl_auth.get_authed_ftl_client", return_value=FTL),
        patch("python.scrapers.ftl_auth.normalize_ftl_url", side_effect=lambda u: u),
        patch("python.tools.scrape_ftl_event_urls.parse_event_schedule", return_value=(kept, [])),
        patch("python.pipeline.ingest_cli._fire_staging_report", return_value=None),
        patch("python.pipeline.ingest_cli._after_event_run"),
        patch.object(lifecycle, "warsaw_today", return_value=today or dt.date(2027, 2, 20)),
    ):
        return fn(*args, **kwargs)


class TestIngestionSetsTheStatus:
    def test_a_listing_not_final_is_skipped_listed_and_keeps_the_event_in_progress(self):
        """PROMO.LIFE.11, on the day after the end date: the last day a listing
        not final holds the event (G44 A (3))."""
        from python.pipeline import ingest_cli

        db = _db("2027-02-13")
        _drive_schedule(
            ingest_cli.ingest_event_from_url,
            finished=("U3",),
            today=dt.date(2027, 2, 14),
            event_code="PPW4-2026-2027",
            season_end_year=2027,
            db=db,
        )
        assert db.events[8]["enum_status"] == "IN_PROGRESS"
        reasons = {s["name"]: s["status"] for s in db.events[8]["json_ingest_sources"]}
        assert "Szabla Mężczyzn kat. 2" in reasons
        assert all(t["enum_weapon"] != "SABRE" for t in db.tournaments.values())

    def test_every_listing_final_after_the_end_date_completes_the_event(self):
        """PROMO.LIFE.12"""
        from python.pipeline import ingest_cli

        db = _db("2027-02-13")
        _drive_schedule(
            ingest_cli.ingest_event_from_url,
            event_code="PPW4-2026-2027",
            season_end_year=2027,
            db=db,
        )
        assert db.events[8]["enum_status"] == "COMPLETED"
        assert db.status_writes == ["IN_PROGRESS", "COMPLETED"]

    def test_the_plan_carries_the_same_status_and_its_apply_equals_the_live_run(self):
        """PROMO.LIFE.13 — promote passes the rule's status to its apply."""
        from python.pipeline import ingest_cli
        from python.pipeline.promotion import plan as pl

        live = _db("2027-02-13")
        _drive_schedule(
            ingest_cli.ingest_event_from_url,
            finished=("U3",),
            today=dt.date(2027, 2, 14),
            event_code="PPW4-2026-2027",
            season_end_year=2027,
            db=live,
        )
        planned = _db("2027-02-13")
        plan = _drive_schedule(
            pl.plan_event,
            "PPW4-2026-2027",
            2027,
            _ReadOnly(planned),
            finished=("U3",),
            today=dt.date(2027, 2, 14),
            url_event=SCHEDULE,
            created=[],
        )
        assert plan.status == "IN_PROGRESS"
        pl.apply_plan(plan.ops, planned, status=plan.status, event_code="PPW4-2026-2027")
        assert planned.state() == live.state()


# ---------------------------------------------------------------------------
# The daily close
# ---------------------------------------------------------------------------

FP = "f" * 64
CLOSE_TODAY = dt.date(2026, 9, 29)


class FakeEnv:
    def __init__(
        self, name, status="IN_PROGRESS", fingerprint=FP, run=None, fail=False, order=None
    ):
        self.name = name
        self.order = order if order is not None else []
        self.status = status
        self.fingerprint = fingerprint
        self.run = run
        self.fail = fail
        self.writes: list[str] = []

    def events_to_close(self, today):
        if self.status == "IN_PROGRESS" and END < today:
            return ["PPW1-2026-2027"]
        return []

    def event(self, code):
        return {"code": code, "status": self.status, "dt_end": END, "url_event": SCHEDULE}

    def result_fingerprint(self, code):  # noqa: ARG002
        return self.fingerprint

    def latest_finished_run(self, code):  # noqa: ARG002
        return self.run

    def set_status(self, code, status):  # noqa: ARG002
        if self.fail:
            raise RuntimeError(f"{self.name} refused the write")
        self.writes.append(status)
        self.order.append(self.name)
        self.status = status


class FakeNotifier:
    def __init__(self):
        self.messages: list[tuple[str, str]] = []

    def warning(self, message: str) -> None:
        self.messages.append(("warning", message))

    def success(self, message: str) -> None:
        self.messages.append(("success", message))

    def error(self, message: str) -> None:
        self.messages.append(("error", message))


KEPT = [
    {"uuid": "K0", "name": "SZPADA WETERANI mężczyźni 2", "finished": True, "day": "2026-09-27"},
    {"uuid": "K1", "name": "FLORET WETERANI kobiety 1", "finished": True, "day": "2026-09-27"},
]


def _run(kept=KEPT) -> dict:
    log = ListingLog()
    log.add_schedule(kept, [])
    for k in kept:
        log.rounds.append({"name": k["name"], "uuid": k["uuid"], "status": "committed"})
    return {"url_event": SCHEDULE, "listings": log.listings(), "result_fingerprint": FP}


def _close(cert, prod, schedule=(KEPT, [])):
    notifier = FakeNotifier()
    outcomes = close.close_events(
        cert, prod, read_schedule=lambda url: schedule, notifier=notifier, today=CLOSE_TODAY
    )
    return outcomes, notifier


class TestDailyClose:
    def test_everything_in_on_both_environments_completes_cert_then_prod(self):
        """PROMO.LIFE.14"""
        order: list[str] = []
        cert = FakeEnv("cert", run=_run(), order=order)
        prod = FakeEnv("prod", order=order)
        outcomes, notifier = _close(cert, prod)
        assert [o.closed for o in outcomes] == [True]
        assert order == ["cert", "prod"]
        assert (cert.status, prod.status) == ("COMPLETED", "COMPLETED")
        assert notifier.messages[0][0] == "success"

    def test_a_listing_published_after_the_cert_run_blocks_the_close(self):
        """PROMO.LIFE.15"""
        cert, prod = FakeEnv("cert", run=_run()), FakeEnv("prod")
        newer = [
            *KEPT,
            {
                "uuid": "K9",
                "name": "SZABLA WETERANI mężczyźni 4",
                "finished": True,
                "day": "2026-09-27",
            },
        ]
        outcomes, notifier = _close(cert, prod, schedule=(newer, []))
        assert [o.closed for o in outcomes] == [False]
        assert cert.writes == [] and prod.writes == []
        kind, message = notifier.messages[0]
        assert kind == "warning" and "PPW1-2026-2027" in message and "ingest" in message

    def test_prod_without_the_cert_result_is_not_closed(self):
        """PROMO.LIFE.15 — promote it first."""
        cert, prod = FakeEnv("cert", run=_run()), FakeEnv("prod", fingerprint="0" * 64)
        outcomes, notifier = _close(cert, prod)
        assert [o.closed for o in outcomes] == [False]
        assert cert.writes == [] and prod.writes == []
        assert "promote" in notifier.messages[0][1]

    def test_a_refused_promote_is_quoted_from_the_ledger(self, capsys):
        """LEDGER.04 — ADR-119 §3 (D10): the close says why PROD lacks the run,
        from the ledger on the CERT run's row. Telegram gets the reason whole;
        the public log only its time (D12: no fencer name in a log line)."""
        run = _run()
        run["promote"] = {
            "outcome": "refused",
            "fingerprint": None,
            "reason": "[identity] PROD would create KOWALSKI Jan (1972); the CERT run did not.",
            "run_url": None,
            "ts": "2026-09-28T13:08:41.5+00:00",
        }
        cert, prod = FakeEnv("cert", run=run), FakeEnv("prod", fingerprint="0" * 64)
        outcomes, notifier = _close(cert, prod)
        (outcome,) = outcomes
        assert not outcome.closed
        quoted = "promote refused at 2026-09-28 15:08: [identity] PROD would create KOWALSKI Jan"
        assert any(r.startswith(quoted) for r in outcome.reasons)
        assert quoted in notifier.messages[0][1]
        out = capsys.readouterr().out
        assert "promote refused at 2026-09-28 15:08" in out and "KOWALSKI" not in out

    @pytest.mark.parametrize("promote", [None, {"outcome": "applied", "fingerprint": "f" * 64}])
    def test_without_a_refusal_on_the_ledger_the_close_asks_for_a_promote(self, promote):
        """LEDGER.04 — no entry, or an applied one PROD no longer holds."""
        run = _run()
        run["promote"] = promote
        cert, prod = FakeEnv("cert", run=run), FakeEnv("prod", fingerprint="0" * 64)
        (outcome,), _ = _close(cert, prod)
        assert "PROD does not hold the CERT run's result: promote it" in outcome.reasons

    def test_a_listing_not_final_or_dated_after_the_end_date_is_not_closed(self):
        """PROMO.LIFE.15"""
        cert, prod = FakeEnv("cert", run=_run()), FakeEnv("prod")
        late = [KEPT[0], {**KEPT[1], "day": "2026-09-28"}]
        outcomes, notifier = _close(cert, prod, schedule=(late, []))
        assert [o.closed for o in outcomes] == [False]
        assert "2026-09-28" in notifier.messages[0][1]

        # G44 A (3): two days after the end date a listing still not final no
        # longer holds the event by itself (STUCK.04); this one was final when
        # CERT ran, so the schedule changed since the run, and that holds it.
        cert, prod = FakeEnv("cert", run=_run()), FakeEnv("prod")
        open_ = [KEPT[0], {**KEPT[1], "finished": False}]
        outcomes, notifier = _close(cert, prod, schedule=(open_, []))
        assert [o.closed for o in outcomes] == [False]
        assert "not final yet" not in notifier.messages[0][1]
        assert "the schedule changed since the CERT run" in notifier.messages[0][1]

    def test_it_is_idempotent_and_finishes_a_half_done_close(self):
        """PROMO.LIFE.16 — CERT set, PROD failed: the next day's run finishes it."""
        cert, prod = FakeEnv("cert", run=_run()), FakeEnv("prod", fail=True)
        with pytest.raises(close.CloseFailed):
            _close(cert, prod)
        assert cert.status == "COMPLETED" and prod.status == "IN_PROGRESS"

        prod.fail = False
        outcomes, _ = _close(cert, prod)
        assert [o.closed for o in outcomes] == [True]
        assert cert.writes == ["COMPLETED"] and prod.writes == ["COMPLETED"]

        outcomes, notifier = _close(cert, prod)
        assert outcomes == [] and notifier.messages == []

    def test_the_schedule_hash_is_the_runs(self):
        """PROMO.LIFE.16 — the close compares the schedule exactly as the run hashed it."""
        assert _run()["listings"]["schedule"]["sha256"] == schedule_sha256(KEPT, [])


class _PastSeasonEnv:
    """An environment whose past seasons still hold open events."""

    def __init__(self, name, open_events, fail=False):
        self.name = name
        self.open_events = dict(open_events)  # code → status
        self.fail = fail
        self.asked: list[tuple[dt.date, dt.date]] = []
        self.writes: list[str] = []

    def past_season_open(self, ended_from, ended_to):
        self.asked.append((ended_from, ended_to))
        return [{"code": c, "status": s} for c, s in self.open_events.items()]

    def event(self, code):
        return {"code": code, "status": self.open_events.get(code)}

    def set_status(self, code, status):
        if self.fail:
            raise RuntimeError("the Management API is down")
        self.writes.append(f"{code}:{status}")
        self.open_events[code] = status


class TestPastSeasonsAreClosed:
    """CLOSE.PAST.01–05 — the user's rule of 4 Nov 2026 (closing plan rev 5,
    N1): an open event is permitted only in the active season. Each morning,
    before closing anything, the daily close completes every open event of a
    past season, on CERT then PROD, through the validator's steps, touching no
    result, and says so. This replaces ADR-119 G64 A, which only named them."""

    def test_each_open_event_is_completed_on_cert_then_prod(self, capsys):
        """CLOSE.PAST.01"""
        cert = _PastSeasonEnv("cert", {"IMSW-2025-2026": "IN_PROGRESS"})
        prod = _PastSeasonEnv(
            "prod", {"IMSW-2025-2026": "IN_PROGRESS", "PEW9f-2024-2025": "PLANNED"}
        )
        notifier = FakeNotifier()
        closed = close.close_past_season_events(cert, prod, notifier=notifier, today=CLOSE_TODAY)
        assert closed == {
            "IMSW-2025-2026": ["cert:COMPLETED", "prod:COMPLETED"],
            "PEW9f-2024-2025": ["prod:IN_PROGRESS", "prod:COMPLETED"],
        }
        window = (CLOSE_TODAY - dt.timedelta(days=3), CLOSE_TODAY - dt.timedelta(days=1))
        assert cert.asked == [window] and prod.asked == [window]
        assert cert.writes == ["IMSW-2025-2026:COMPLETED"]
        assert prod.writes == [
            "IMSW-2025-2026:COMPLETED",
            "PEW9f-2024-2025:IN_PROGRESS",
            "PEW9f-2024-2025:COMPLETED",
        ]
        out = capsys.readouterr().out
        for line in (
            "Daily close: IMSW-2025-2026 of a past season was IN_PROGRESS on CERT and PROD: "
            "COMPLETED.",
            "Daily close: PEW9f-2024-2025 of a past season was PLANNED on PROD: COMPLETED.",
        ):
            assert line in out
            assert any(kind == "success" and line in m for kind, m in notifier.messages)

    def test_a_dry_run_names_and_writes_nothing(self, capsys):
        """CLOSE.PAST.02"""
        cert = _PastSeasonEnv("cert", {"IMSW-2025-2026": "IN_PROGRESS"})
        prod = _PastSeasonEnv("prod", {})
        notifier = FakeNotifier()
        closed = close.close_past_season_events(
            cert, prod, notifier=notifier, today=CLOSE_TODAY, write=False
        )
        assert closed == {"IMSW-2025-2026": ["cert:COMPLETED"]}
        assert cert.writes == [] and notifier.messages == []
        assert (
            "(dry run) Daily close: IMSW-2025-2026 of a past season was IN_PROGRESS on CERT: "
            "COMPLETED." in capsys.readouterr().out
        )

    def test_none_says_nothing(self, capsys):
        """CLOSE.PAST.03"""
        notifier = FakeNotifier()
        closed = close.close_past_season_events(
            _PastSeasonEnv("cert", {}),
            _PastSeasonEnv("prod", {}),
            notifier=notifier,
            today=CLOSE_TODAY,
        )
        assert closed == {} and notifier.messages == [] and capsys.readouterr().out == ""

    def test_a_failed_write_is_reported_and_the_rest_still_runs(self, capsys):
        """CLOSE.PAST.04 — CERT done, PROD down: the failure is said, the morning's
        close goes on, and the run ends red."""
        cert = _PastSeasonEnv("cert", {"IMSW-2025-2026": "IN_PROGRESS"})
        prod = _PastSeasonEnv("prod", {"IMSW-2025-2026": "IN_PROGRESS"}, fail=True)
        notifier = FakeNotifier()
        with pytest.raises(close.CloseFailed):
            close.close_past_season_events(cert, prod, notifier=notifier, today=CLOSE_TODAY)
        assert cert.writes == ["IMSW-2025-2026:COMPLETED"] and prod.writes == []
        assert any(
            kind == "error" and "IMSW-2025-2026 on prod" in m for kind, m in notifier.messages
        )
        assert "IMSW-2025-2026 on prod: RuntimeError" in capsys.readouterr().err

    def test_the_sql_reads_every_open_event_of_a_past_season(self):
        """CLOSE.PAST.05 — every event, of every organizer and code; closed means
        COMPLETED, SCORED or CANCELLED; past means the season ended one to three
        days ago (S1 A, 4 Nov 2026; N3 A: a future season's PLANNED events stay
        as they are)."""
        seen: list[str] = []

        class _Transport:
            def fetch_json(self, sql):
                seen.append(sql)
                return [{"code": "IMSW-2025-2026", "status": "IN_PROGRESS"}]

        env = close.SqlEnv("prod", _Transport())
        assert env.past_season_open(dt.date(2026, 9, 26), dt.date(2026, 9, 28)) == [
            {"code": "IMSW-2025-2026", "status": "IN_PROGRESS"}
        ]
        (sql,) = seen
        assert "e.enum_status NOT IN ('COMPLETED', 'SCORED', 'CANCELLED')" in sql
        assert "s.dt_end BETWEEN DATE '2026-09-26' AND DATE '2026-09-28'" in sql
        assert "bool_active" not in sql
        assert close.route_code_regex() not in sql


class TestWorkflow:
    def test_the_daily_close_runs_in_prod_write_every_morning(self):
        """PROMO.LIFE.17 — serialised with promote; a manual run is a dry run by default."""
        import yaml

        wf = yaml.safe_load(
            (Path(__file__).parents[2] / ".github/workflows/event-close.yml").read_text()
        )
        assert wf["concurrency"] == {
            "group": "prod-write",
            "cancel-in-progress": False,
            "queue": "max",
        }
        triggers = wf[True]  # PyYAML reads the key `on` as True
        assert triggers["schedule"] == [{"cron": "17 4 * * *"}]  # off the hour (WFCRON.01)
        assert triggers["workflow_dispatch"]["inputs"]["dry_run"]["default"] is True
        runs = " ".join(s.get("run") or "" for s in wf["jobs"]["close"]["steps"])
        assert "python -m python.pipeline.promotion.close --dry-run" in runs
