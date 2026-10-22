"""The start-list capture orchestration (ADR-112 §2, ADR-116; RTM PZSZ.SL.05-09).

Check 1 of the window rule is the run's selection: only PZSz events, not
COMPLETED/CANCELLED, with D-4 <= today <= D-1. The capture then reads each
selected event best-effort (check 2 lives in the reader) and stores every new
version. One event never stops another; a gated event is recorded, not raised.

The red line: on the last attempt of D-1, an event missing a start list for a
tournament it is known to have is fatal — the result ingest for it will stop
(ADR-111). Everything else is green, with warnings. These tests drive the pure
core with fake fetch/store and the stored state as data.
"""

from __future__ import annotations

from datetime import date
from pathlib import Path

from python.scrapers.pzsz_start_list import PZSZ_EVENT_PAGE
from python.scrapers.pzsz_start_list_store import (
    CaptureOutcome,
    capture_window,
    run_capture,
    select_window_events,
    window_report,
)

FIXTURES = Path(__file__).parent / "fixtures"


def _read(name: str) -> str:
    return (FIXTURES / name).read_text(encoding="utf-8")


def _fetch(pages: dict[tuple[str, int], str]):
    def fetch(url: str, params: dict) -> str:
        kind = "event" if url == PZSZ_EVENT_PAGE else "tournament"
        return pages[(kind, params["id"])]

    return fetch


POZNAN_PAGES = {
    ("event", 4588): "pzsz_event_poznan_tournaments.html",
    ("tournament", 10628): "pzsz_start_list_sabre_men.html",
    ("tournament", 10629): "pzsz_start_list_sabre_women.html",
}
TODAY = date(2026, 10, 21)
# Poznań event 4588 used as the sample; pretend its first day is 24 Oct so the
# 21 Oct run is inside the window (D-3).
ROW = {
    "txt_code": "PPS1s-2026-2027",
    "id_pzsz_event": 4588,
    "dt_start": "2026-10-24",
    "dt_end": "2026-10-25",
    "enum_status": "SCHEDULED",
}


class _Store:
    """Stores a payload as new unless its (tournament, sha) was seen before."""

    def __init__(self) -> None:
        self.seen: set[tuple[int, str]] = set()
        self.calls: list[dict] = []

    def store(self, payload: dict) -> bool:
        self.calls.append(payload)
        key = (payload["id_pzsz_tournament"], payload["txt_sha256"])
        new = key not in self.seen
        self.seen.add(key)
        return new


class TestSelectWindowEvents:
    def test_selects_only_in_window_non_terminal_pzsz_events(self):
        """PZSZ.SL.05 (check 1): D-4..D-1 only; COMPLETED/CANCELLED and
        non-PZSz rows are left out."""
        rows = [
            {**ROW, "txt_code": "in-d3", "dt_start": "2026-10-24"},  # D-3 in
            {**ROW, "txt_code": "d4-edge", "dt_start": "2026-10-25"},  # D-4 in
            {**ROW, "txt_code": "d5-early", "dt_start": "2026-10-26"},  # D-5 out
            {**ROW, "txt_code": "d-day", "dt_start": "2026-10-21"},  # D today, out
            {**ROW, "txt_code": "done", "dt_start": "2026-10-24", "enum_status": "COMPLETED"},
            {**ROW, "txt_code": "not-pzsz", "dt_start": "2026-10-24", "id_pzsz_event": None},
        ]
        chosen = {r["txt_code"] for r in select_window_events(rows, TODAY)}
        assert chosen == {"in-d3", "d4-edge"}


class TestCaptureWindow:
    def test_stores_each_list_and_marks_new_versus_unchanged(self):
        """PZSZ.SL.06: every tournament's list stored; a second run of the
        same unchanged pages stores nothing new."""
        store = _Store()
        fetch = _fetch({k: _read(v) for k, v in POZNAN_PAGES.items()})
        first = capture_window([ROW], TODAY, fetch, store.store)
        assert len(first) == 1
        out = first[0]
        assert {(w, g) for w, g, _ in out.stored} == {("SABRE", "M"), ("SABRE", "F")}
        assert out.missing == []
        assert out.not_served is False
        again = capture_window([ROW], TODAY, fetch, store.store)[0]
        assert again.stored == []
        assert {(w, g) for w, g, _ in again.unchanged} == {("SABRE", "M"), ("SABRE", "F")}

    def test_one_gated_tournament_is_named_the_rest_stored(self):
        """PZSZ.SL.06: a tournament page that will not render is named missing
        with its weapon and gender; the other list is stored."""
        pages = {k: _read(v) for k, v in POZNAN_PAGES.items()}
        pages[("tournament", 10629)] = _read("pzsz_js_check.html")
        out = capture_window([ROW], TODAY, _fetch(pages), _Store().store)[0]
        assert {(w, g) for w, g, _ in out.stored} == {("SABRE", "M")}
        assert [(w, g) for w, g, _ in out.missing] == [("SABRE", "F")]

    def test_a_gated_event_page_is_recorded_not_raised(self):
        """PZSZ.SL.06: the event page itself gated serves nothing; the event
        is 'not served' and the run goes on to the next event."""
        pages = {k: _read(v) for k, v in POZNAN_PAGES.items()}
        pages[("event", 4588)] = _read("pzsz_js_check.html")
        other = {**ROW, "txt_code": "PPS9z-2026-2027"}
        outs = capture_window([ROW, other], TODAY, _fetch(pages), _Store().store)
        assert outs[0].not_served is True
        assert outs[0].error is not None
        assert len(outs) == 2  # the second event was still attempted


class TestWindowReport:
    def _outcome(self, **kw) -> CaptureOutcome:
        base = dict(
            code="PPS1s-2026-2027",
            id_pzsz_event=4588,
            first_day=date(2026, 10, 24),
            stored=[],
            unchanged=[],
            missing=[],
            not_served=False,
            error=None,
        )
        base.update(kw)
        return CaptureOutcome(**base)  # type: ignore[arg-type]

    def test_fatal_on_the_last_attempt_when_a_known_tournament_has_nothing_stored(self):
        """PZSZ.SL.09: D-1 final run, the women's foil never stored anywhere in
        the window → fatal; the ingest for it will stop."""
        out = self._outcome(
            stored=[], unchanged=[("FOIL", "M", 58)], missing=[("FOIL", "F", "check")]
        )
        report = window_report(
            [out],
            today=date(2026, 10, 23),  # D-1
            first_run=False,
            final_run=True,
            stored_keys={4588: {("FOIL", "M")}},  # only the men's stored across the window
        )
        assert report.fatal == ["PPS1s-2026-2027"]
        assert any("❌" in line and "PPS1s" in line for line in report.lines)

    def test_not_fatal_when_everything_known_is_stored(self):
        """PZSZ.SL.09: both lists stored somewhere in the window → green, even
        if this last attempt stored nothing new."""
        out = self._outcome(unchanged=[("FOIL", "M", 58), ("FOIL", "F", 24)])
        report = window_report(
            [out],
            today=date(2026, 10, 23),
            first_run=False,
            final_run=True,
            stored_keys={4588: {("FOIL", "M"), ("FOIL", "F")}},
        )
        assert report.fatal == []

    def test_open_line_on_the_first_run_of_d_minus_4(self):
        """PZSZ.SL.08: the D-4 first run announces the window opening."""
        out = self._outcome(stored=[("FOIL", "M", 58)])
        report = window_report(
            [out],
            today=date(2026, 10, 20),  # D-4
            first_run=True,
            final_run=False,
            stored_keys={4588: {("FOIL", "M")}},
        )
        assert any("📋" in line and "window open" in line.lower() for line in report.lines)

    def test_stored_line_when_a_new_version_lands(self):
        """PZSZ.SL.08: a fresh capture is acknowledged with its counts."""
        out = self._outcome(stored=[("FOIL", "M", 58), ("FOIL", "F", 24)])
        report = window_report(
            [out], today=TODAY, first_run=False, final_run=False, stored_keys={4588: set()}
        )
        assert any("✅" in line and "58" in line for line in report.lines)


class TestRunCapture:
    """PZSZ.SL.09: the CERT orchestration — selection, store, one digest, exit
    status — driven with injected query/store/telegram/fetch, no browser."""

    def _query(self, stored_rows: list[dict]):
        season = {"id_season": 7, "txt_code": "2026/2027"}
        event_rows = [
            {
                "txt_code": "PPS1s-2026-2027",
                "id_pzsz_event": 4588,
                "dt_start": "2026-10-24",
                "enum_status": "SCHEDULED",
            }
        ]

        def query(ref: str, token: str, sql: str) -> list[dict]:
            if "bool_active" in sql:
                return [season]
            if "tbl_pzsz_start_list" in sql:
                return stored_rows
            return event_rows

        return query

    def test_captures_in_window_stores_and_returns_green(self):
        sent: list[str] = []
        store = _Store()
        fetch = _fetch({k: _read(v) for k, v in POZNAN_PAGES.items()})
        code = run_capture(
            "ref",
            "tok",
            "bot",
            "chat",
            today=TODAY,
            query=self._query([]),
            telegram=lambda b, c, m: sent.append(m),
            store=store.store,
            fetch=fetch,
            season={"id_season": 7, "txt_code": "2026/2027"},
        )
        assert code == 0
        assert len(store.calls) == 2  # both start lists stored
        assert sent and "✅" in sent[0]

    def test_returns_red_when_fatal_on_the_final_run(self):
        """A known tournament with nothing stored, on the D-1 final run, is
        fatal → exit 1, and the digest says the ingest will stop."""
        sent: list[str] = []
        pages = {k: _read(v) for k, v in POZNAN_PAGES.items()}
        pages[("tournament", 10629)] = _read("pzsz_js_check.html")  # women's never renders
        code = run_capture(
            "ref",
            "tok",
            "bot",
            "chat",
            today=date(2026, 10, 23),  # D-1
            final_run=True,
            query=self._query(
                [{"id_pzsz_event": 4588, "enum_weapon": "SABRE", "enum_gender": "M"}]
            ),
            telegram=lambda b, c, m: sent.append(m),
            store=_Store().store,
            fetch=_fetch(pages),
            season={"id_season": 7, "txt_code": "2026/2027"},
        )
        assert code == 1
        assert sent and "❌" in sent[0]
