"""The start-list capture window and its best-effort reader (ADR-112 §2-§3,
ADR-116; RTM PZSZ.SL.05-08).

A PZSz start list exists only from four days before an event's first day to
one day before (D-4..D-1), and is closed afterwards. The capture reads it only
inside that window, with two independent checks: the run selects in-window
events, and the reader refuses any page of an out-of-window event whoever asks.

The capture is best-effort per tournament — one tournament page that will not
render does not drop the others; the missing ones are named — unlike the
ingest's all-or-nothing read, which never admits a field with some birth years
missing. These tests keep the reader pure with a fake fetch.
"""

from __future__ import annotations

from datetime import date
from pathlib import Path

import pytest

from python.scrapers.pzsz_start_list import (
    PZSZ_EVENT_PAGE,
    PZSZ_TOURNAMENT_PAGE,
    PzszGateError,
    PzszWindowError,
    in_start_list_window,
    read_event_start_lists_for_capture,
    start_list_window,
)

FIXTURES = Path(__file__).parent / "fixtures"


def _read(name: str) -> str:
    return (FIXTURES / name).read_text(encoding="utf-8")


POZNAN = {
    ("event", 4588): "pzsz_event_poznan_tournaments.html",
    ("tournament", 10628): "pzsz_start_list_sabre_men.html",
    ("tournament", 10629): "pzsz_start_list_sabre_women.html",
}
GDANSK_D = date(2026, 10, 24)  # the event's first day


def _fetch(pages: dict[tuple[str, int], str]):
    calls: list[tuple[str, dict]] = []

    def fetch(url: str, params: dict) -> str:
        calls.append((url, params))
        kind = "event" if url == PZSZ_EVENT_PAGE else "tournament"
        return pages[(kind, params["id"])]

    fetch.calls = calls  # type: ignore[attr-defined]
    return fetch


class TestWindow:
    def test_window_is_four_days_down_to_one_day_before(self):
        """PZSZ.SL.05: D-4..D-1 inclusive; the list is gone on day D."""
        assert start_list_window(GDANSK_D) == (date(2026, 10, 20), date(2026, 10, 23))

    @pytest.mark.parametrize(
        ("today", "inside"),
        [
            (date(2026, 10, 19), False),  # D-5, too early
            (date(2026, 10, 20), True),  # D-4, opens
            (date(2026, 10, 21), True),
            (date(2026, 10, 23), True),  # D-1, last day
            (date(2026, 10, 24), False),  # D, closed
            (date(2026, 10, 25), False),  # after
        ],
    )
    def test_in_window(self, today: date, inside: bool):
        """PZSZ.SL.05: never before D-4, never on or after D."""
        assert in_start_list_window(GDANSK_D, today) is inside


class TestCaptureReader:
    def test_reads_every_tournament_inside_the_window(self):
        """PZSZ.SL.06: in the window, each tournament's list comes back keyed
        by weapon and gender, with nothing missing."""
        fetch = _fetch({k: _read(v) for k, v in POZNAN.items()})
        result = read_event_start_lists_for_capture(
            4588, fetch, first_day=GDANSK_D, today=date(2026, 10, 21)
        )
        assert set(result.captured) == {("SABRE", "M"), ("SABRE", "F")}
        assert len(result.captured[("SABRE", "M")][1]) == 53
        assert result.missing == []

    def test_one_unrendered_tournament_does_not_drop_the_others(self):
        """PZSZ.SL.06: the women's page answering the check stores the men's
        list anyway and names the women's as missing — another attempt in the
        window catches it. (The ingest's all-or-nothing read differs.)"""
        pages = {k: _read(v) for k, v in POZNAN.items()}
        pages[("tournament", 10629)] = _read("pzsz_js_check.html")
        result = read_event_start_lists_for_capture(
            4588, _fetch(pages), first_day=GDANSK_D, today=date(2026, 10, 21)
        )
        assert set(result.captured) == {("SABRE", "M")}
        assert [t.id_pzsz_tournament for t, _ in result.missing] == [10629]

    def test_outside_the_window_refuses_before_any_fetch(self):
        """PZSZ.SL.07 (check 2): an event whose window is closed is refused by
        the reader itself — no page of it is ever requested — whoever asked."""
        fetch = _fetch({k: _read(v) for k, v in POZNAN.items()})
        with pytest.raises(PzszWindowError, match="window"):
            read_event_start_lists_for_capture(
                4588, fetch, first_day=GDANSK_D, today=date(2026, 10, 24)
            )
        assert fetch.calls == []  # type: ignore[attr-defined]

    def test_a_gated_event_page_serves_nothing(self):
        """PZSZ.SL.06: the event page itself answering the check means no
        tournament ids were read; the whole event is 'not served' this run."""
        pages = {k: _read(v) for k, v in POZNAN.items()}
        pages[("event", 4588)] = _read("pzsz_js_check.html")
        with pytest.raises(PzszGateError, match="JavaScript check"):
            read_event_start_lists_for_capture(
                4588, _fetch(pages), first_day=GDANSK_D, today=date(2026, 10, 21)
            )

    def test_the_event_page_is_requested_before_the_tournaments(self):
        """PZSZ.SL.06: event page first (for the ids), then each tournament."""
        fetch = _fetch({k: _read(v) for k, v in POZNAN.items()})
        read_event_start_lists_for_capture(
            4588, fetch, first_day=GDANSK_D, today=date(2026, 10, 21)
        )
        assert fetch.calls[0] == (PZSZ_EVENT_PAGE, {"id": 4588})  # type: ignore[attr-defined]
        assert all(u == PZSZ_TOURNAMENT_PAGE for u, _ in fetch.calls[1:])  # type: ignore[attr-defined]
