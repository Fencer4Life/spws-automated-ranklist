"""The start-list capture window and its best-effort reader (ADR-112 §2-§3,
ADR-116; RTM PZSZ.SL.05-08, PZSZ.SL.13).

The capture reads a PZSz start list from four days before an event's first day
to the morning of its last day: a run due before noon (Warsaw) on the last day
still captures, so an entry added late is caught (K2 A, 25 Oct 2026; pzszerm.pl
still served PPS1e's lists on its last day). The run's due moment decides, not
the moment it started. Two independent checks: the run selects in-window
events, and the reader refuses any page of an out-of-window event whoever asks.

The capture is best-effort per tournament — one tournament page that will not
render does not drop the others; the missing ones are named — unlike the
ingest's all-or-nothing read, which never admits a field with some birth years
missing. These tests keep the reader pure with a fake fetch.
"""

from __future__ import annotations

from datetime import date, datetime
from pathlib import Path
from zoneinfo import ZoneInfo

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
GDANSK_LAST = date(2026, 10, 25)  # its last day
WARSAW = ZoneInfo("Europe/Warsaw")


def _due(day: int, hour: int, minute: int = 11) -> datetime:
    """A run due on that October 2026 day at that Warsaw time."""
    return datetime(2026, 10, day, hour, minute, tzinfo=WARSAW)


def _fetch(pages: dict[tuple[str, int], str]):
    calls: list[tuple[str, dict]] = []

    def fetch(url: str, params: dict) -> str:
        calls.append((url, params))
        kind = "event" if url == PZSZ_EVENT_PAGE else "tournament"
        return pages[(kind, params["id"])]

    fetch.calls = calls  # type: ignore[attr-defined]
    return fetch


class TestWindow:
    def test_window_runs_from_d_minus_4_to_the_last_day(self):
        """PZSZ.SL.05 (K2 A): D-4 to the event's last day."""
        assert start_list_window(GDANSK_D, GDANSK_LAST) == (date(2026, 10, 20), GDANSK_LAST)
        assert start_list_window(GDANSK_D, GDANSK_D) == (date(2026, 10, 20), GDANSK_D)

    @pytest.mark.parametrize(
        ("due", "inside"),
        [
            (_due(19, 21), False),  # D-5, too early
            (_due(20, 7), True),  # D-4, opens
            (_due(23, 21), True),  # D-1, evening
            (_due(24, 15), True),  # D, the first day, afternoon
            (_due(25, 7), True),  # the last day, morning
            (_due(25, 11, 59), True),  # the last day, just before noon
            (_due(25, 12, 0), False),  # the last day, noon: closed
            (_due(25, 15), False),  # the last day, afternoon
            (_due(26, 7), False),  # after
        ],
    )
    def test_in_window(self, due: datetime, inside: bool):
        """PZSZ.SL.05 (K2 A): never before D-4, never from noon of the last day."""
        assert in_start_list_window(GDANSK_D, GDANSK_LAST, due) is inside

    def test_a_one_day_event_closes_at_noon_of_its_only_day(self):
        """PZSZ.SL.13: first day and last day the same: its morning is the
        last chance, its afternoon is closed."""
        assert in_start_list_window(GDANSK_D, GDANSK_D, _due(24, 11)) is True
        assert in_start_list_window(GDANSK_D, GDANSK_D, _due(24, 15)) is False

    def test_the_due_moment_decides_in_utc_too(self):
        """PZSZ.SL.13: 09:11 UTC on the last day is 10:11 Warsaw (winter time
        from 25 Oct 2026): inside; 13:11 UTC is 14:11 Warsaw: closed."""
        from datetime import UTC

        assert in_start_list_window(
            GDANSK_D, GDANSK_LAST, datetime(2026, 10, 25, 9, 11, tzinfo=UTC)
        )
        assert not in_start_list_window(
            GDANSK_D, GDANSK_LAST, datetime(2026, 10, 25, 13, 11, tzinfo=UTC)
        )


class TestCaptureReader:
    def test_reads_every_tournament_inside_the_window(self):
        """PZSZ.SL.06: in the window, each tournament's list comes back keyed
        by weapon and gender, with nothing missing."""
        fetch = _fetch({k: _read(v) for k, v in POZNAN.items()})
        result = read_event_start_lists_for_capture(
            4588, fetch, first_day=GDANSK_D, last_day=GDANSK_LAST, due=_due(21, 10)
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
            4588, _fetch(pages), first_day=GDANSK_D, last_day=GDANSK_LAST, due=_due(21, 10)
        )
        assert set(result.captured) == {("SABRE", "M")}
        assert [t.id_pzsz_tournament for t, _ in result.missing] == [10629]

    def test_outside_the_window_refuses_before_any_fetch(self):
        """PZSZ.SL.07 (check 2): an event whose window is closed — here the
        afternoon of its last day — is refused by the reader itself; no page
        of it is ever requested, whoever asked."""
        fetch = _fetch({k: _read(v) for k, v in POZNAN.items()})
        with pytest.raises(PzszWindowError, match="window"):
            read_event_start_lists_for_capture(
                4588, fetch, first_day=GDANSK_D, last_day=GDANSK_LAST, due=_due(25, 15)
            )
        assert fetch.calls == []  # type: ignore[attr-defined]

    def test_the_first_day_is_read(self):
        """PZSZ.SL.13 (K2 A): day D is inside the window now."""
        fetch = _fetch({k: _read(v) for k, v in POZNAN.items()})
        result = read_event_start_lists_for_capture(
            4588, fetch, first_day=GDANSK_D, last_day=GDANSK_LAST, due=_due(24, 15)
        )
        assert set(result.captured) == {("SABRE", "M"), ("SABRE", "F")}

    def test_a_gated_event_page_serves_nothing(self):
        """PZSZ.SL.06: the event page itself answering the check means no
        tournament ids were read; the whole event is 'not served' this run."""
        pages = {k: _read(v) for k, v in POZNAN.items()}
        pages[("event", 4588)] = _read("pzsz_js_check.html")
        with pytest.raises(PzszGateError, match="JavaScript check"):
            read_event_start_lists_for_capture(
                4588, _fetch(pages), first_day=GDANSK_D, last_day=GDANSK_LAST, due=_due(21, 10)
            )

    def test_the_event_page_is_requested_before_the_tournaments(self):
        """PZSZ.SL.06: event page first (for the ids), then each tournament."""
        fetch = _fetch({k: _read(v) for k, v in POZNAN.items()})
        read_event_start_lists_for_capture(
            4588, fetch, first_day=GDANSK_D, last_day=GDANSK_LAST, due=_due(21, 10)
        )
        assert fetch.calls[0] == (PZSZ_EVENT_PAGE, {"id": 4588})  # type: ignore[attr-defined]
        assert all(u == PZSZ_TOURNAMENT_PAGE for u, _ in fetch.calls[1:])  # type: ignore[attr-defined]
