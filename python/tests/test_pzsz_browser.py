"""The PZSz browser fetcher (ADR-116; RTM PZSZ.BR.01-04).

Since 2026-10-06 pzszerm.pl answers a plain HTTP client with a JavaScript
"check" page (`<p id="pzs-m">`) that sets a cookie and reloads to the real
page. httpx cannot run that script. ``pzsz_browser`` renders the page with a
real browser engine so the site's own JavaScript runs and the real content
appears, and exposes ``fetch(url, params) -> html`` — the contract the PZSz
readers already expect.

The browser work lives behind one seam, ``render(full_url) -> html`` (one page
load). These tests inject a fake ``render`` and never launch Chromium, so the
test gate stays hermetic; the real browser runs only in the scheduled workflow.
"""

from __future__ import annotations

from collections.abc import Callable
from pathlib import Path

import pytest

from python.scrapers.pzsz_browser import GatedFetcher, browser_fetch, with_params
from python.scrapers.pzsz_start_list import (
    PZSZ_EVENT_PAGE,
    PzszGateError,
    parse_event_tournaments,
    read_event_start_lists,
)

FIXTURES = Path(__file__).parent / "fixtures"


def _read(name: str) -> str:
    return (FIXTURES / name).read_text(encoding="utf-8")


GATE = "pzsz_js_check.html"
EVENT = "pzsz_event_poznan_tournaments.html"


class _Render:
    """A fake one-load render: the gate page for the first ``gate_times``
    calls, then the served page. Records every URL it is asked for."""

    def __init__(self, gate_html: str, real_html: str, gate_times: int = 0) -> None:
        self.gate_html = gate_html
        self.real_html = real_html
        self.gate_times = gate_times
        self.calls: list[str] = []

    def __call__(self, full_url: str) -> str:
        self.calls.append(full_url)
        return self.gate_html if len(self.calls) <= self.gate_times else self.real_html


def _sleeps() -> tuple[list[float], Callable[[float], None]]:
    waited: list[float] = []
    return waited, waited.append


class TestWithParams:
    def test_appends_the_query_string(self):
        """PZSZ.BR.01: the reader calls fetch(PAGE, {'id': N}); the fetcher
        builds the same URL pzszerm.pl serves."""
        assert with_params(PZSZ_EVENT_PAGE, {"id": 4588}) == f"{PZSZ_EVENT_PAGE}?id=4588"

    def test_no_params_leaves_the_url_unchanged(self):
        """PZSZ.BR.01: the calendar listing has no query of its own."""
        assert with_params("https://pzszerm.pl/", {}) == "https://pzszerm.pl/"


class TestGatedFetch:
    def test_served_first_try_returns_the_page(self):
        """PZSZ.BR.02: the real page on the first load is returned as-is, and
        the parsers read it."""
        render = _Render(_read(GATE), _read(EVENT), gate_times=0)
        fetch = GatedFetcher(render=render).fetch
        html = fetch(PZSZ_EVENT_PAGE, {"id": 4588})
        assert render.calls == [f"{PZSZ_EVENT_PAGE}?id=4588"]
        assert len(parse_event_tournaments(html)) == 2

    def test_retries_past_the_gate_then_returns_the_real_page(self):
        """PZSZ.BR.02: the site's check reloads to the real page; the fetcher
        loads again (as a browser would) until it is served, backing off
        between tries. The real page comes back and parses."""
        waited, record = _sleeps()
        render = _Render(_read(GATE), _read(EVENT), gate_times=2)
        fetch = GatedFetcher(render=render, sleep=record).fetch
        html = fetch(PZSZ_EVENT_PAGE, {"id": 4588})
        assert len(render.calls) == 3
        assert len(waited) == 2  # slept once between each pair of tries
        assert len(parse_event_tournaments(html)) == 2

    def test_a_persistent_gate_is_returned_for_the_parser_to_refuse(self):
        """PZSZ.BR.03: when the check never clears, the fetcher gives up and
        returns the check page. It never fabricates content; the parser's
        own guard refuses it (PzszGateError), so a run writes nothing."""
        waited, record = _sleeps()
        render = _Render(_read(GATE), _read(EVENT), gate_times=99)
        fetch = GatedFetcher(render=render, max_attempts=4, sleep=record).fetch
        html = fetch(PZSZ_EVENT_PAGE, {"id": 4588})
        assert len(render.calls) == 4
        assert len(waited) == 3
        with pytest.raises(PzszGateError, match="JavaScript check"):
            parse_event_tournaments(html)

    def test_a_render_failure_propagates(self):
        """PZSZ.BR.03: Chromium unavailable (or a load error) is not a quiet
        empty page — it raises, so the workflow reports source-down and never
        reads an event as having no tournaments."""

        def boom(_full_url: str) -> str:
            raise RuntimeError("chromium missing")

        with pytest.raises(RuntimeError, match="chromium missing"):
            GatedFetcher(render=boom).fetch(PZSZ_EVENT_PAGE, {"id": 4588})


class TestFetchContract:
    def test_drives_read_event_start_lists_end_to_end(self):
        """PZSZ.BR.04: GatedFetcher.fetch is exactly the fetch(url, params)
        seam read_event_start_lists expects — event page then each tournament
        page, one gated on its first load."""
        pages = {
            f"{PZSZ_EVENT_PAGE}?id=4588": _read(EVENT),
            "https://pzszerm.pl/zawody/kalendarium-zawodow/turniej/?id=10628": _read(
                "pzsz_start_list_sabre_men.html"
            ),
            "https://pzszerm.pl/zawody/kalendarium-zawodow/turniej/?id=10629": _read(
                "pzsz_start_list_sabre_women.html"
            ),
        }
        gate = _read(GATE)
        state = {"gated_once": False}

        def render(full_url: str) -> str:
            # The men's page answers the gate the first time, then serves.
            if "id=10628" in full_url and not state["gated_once"]:
                state["gated_once"] = True
                return gate
            return pages[full_url]

        _waited, record = _sleeps()
        fetch = GatedFetcher(render=render, sleep=record).fetch
        lists = read_event_start_lists(4588, fetch)
        assert set(lists) == {("SABRE", "M"), ("SABRE", "F")}
        assert len(lists[("SABRE", "M")][1]) == 53
        assert len(lists[("SABRE", "F")][1]) == 46


class TestBrowserFetch:
    def test_browser_fetch_yields_a_gated_fetch_over_an_injected_render(self):
        """PZSZ.BR.04: browser_fetch is the production entry point; with a
        fake render factory it wires a GatedFetcher without launching a
        browser (the real factory lazily imports Playwright)."""
        render = _Render(_read(GATE), _read(EVENT), gate_times=0)
        with browser_fetch(_render_factory=lambda: render) as fetch:
            html = fetch(PZSZ_EVENT_PAGE, {"id": 4588})
        assert len(parse_event_tournaments(html)) == 2
